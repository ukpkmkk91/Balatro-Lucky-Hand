-- Chain the installed Game:update implementation. Cleanup edits only BDC state.
return function(BDC)
    local M={}
    local previous=Game and Game.update
    if type(previous)~='function' then error('queue lifecycle: Game.update unavailable') end
    local elapsed=0
    local function pack(...) return {n=select('#',...),...} end
    function M.reset(reason)
        BDC.safety.reset(reason)
        M.session=nil;elapsed=0
        pcall(BDC.log.info,'runtime reset: '..reason..'; override=false')
    end
    -- These native boundaries run even when the UI has been disabled by a fault.
    for _,name in ipairs({'start_run','delete_run','main_menu'}) do
        local predecessor=Game[name]
        if type(predecessor)=='function' then
            Game[name]=function(self,...)
                M.reset(name)
                return predecessor(self,...)
            end
        end
    end
    local load_area=CardArea and CardArea.load
    if type(load_area)=='function' then
        CardArea.load=function(self,...)
            if BDC.compatibility.active_run() and (self==G.deck or self==G.hand or self==G.discard or self==G.play) then
                M.reset('run area load')
            end
            return load_area(self,...)
        end
    end
    function M.step(dt)
        if BDC.draw then BDC.draw.step() end
        -- Session checks are constant-time; a changed session clears immediately.
        local session=BDC.identity.session()
        if session~=M.session then
            M.session=session;BDC.queue.validate();elapsed=0
        end
        elapsed=elapsed+(type(dt)=='number' and math.max(0,dt) or 0)
        if elapsed<0.25 then return end
        elapsed=0
        if BDC.queue.count()==0 and not (BDC.ui and BDC.ui.box) then return end
        BDC.queue.validate()
        if BDC.ui and BDC.ui.box then BDC.ui.queue_updated() end
    end
    Game.update=function(self,dt,...)
        local values=pack(previous(self,dt,...))
        if not BDC.disabled then
            local ok,err=pcall(M.step,dt)
            if not ok then
                BDC.safety.fail('queue lifecycle failure: '..tostring(err))
            end
        end
        return unpack(values,1,values.n)
    end
    return M
end
