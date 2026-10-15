-- Guard explicitly selected locked/undiscovered objects without Profile writes.
-- Only provenance is saved in the native current-run GAME table; never queues.
return function(BDC)
    local M={}
    local protected,run={},nil
    local provenance_key='bdctrl_run_only_provenance'
    local function pack(...) return {n=select('#',...),...} end
    local function private(obj) return type(obj)=='table' and (obj.unlocked==false or obj.discovered==false) end
    local function eligible(key)
        local obj=type(key)=='string' and G and G.P_CENTERS and G.P_CENTERS[key]
        return private(obj) and obj.key==key and BDC.catalog.official(obj)
    end
    local function sync()
        local current=G and G.GAME
        if run==current then return end
        protected={};run=current
        if type(run)~='table' then return end
        local saved=run[provenance_key]
        if saved==nil then return end
        local valid=type(saved)=='table' and saved.schema==1 and type(saved.centers)=='table'
        local rejected=not valid
        if valid then
            for key,value in pairs(saved.centers) do
                if value==true and eligible(key) then protected[key]=true
                else rejected=true end
            end
        end
        -- Rebuild a value-only whitelist once on a run switch. Unknown schemas,
        -- keys and values cannot turn natural discoveries into protected objects.
        run[provenance_key]=next(protected) and {schema=1,centers=protected} or nil
        if rejected then BDC.log.info('run-only invalid provenance ignored') end
    end
    function M.protect(key)
        sync()
        if not BDC.compatibility.active_run() or not eligible(key) then return end
        protected[key]=true
        run[provenance_key]={schema=1,centers=protected}
    end
    function M.blocked(obj)
        sync()
        if not BDC.compatibility.active_run() or not private(obj) then return false end
        -- Vanilla shop cards also use bypass fields; used_vouchers records native
        -- redemptions too. Neither is evidence that this Mod selected an object.
        return protected[obj.key]==true and G.P_CENTERS[obj.key]==obj
    end
    function M.mark(card)
        if card and card.config and M.blocked(card.config.center) then
            card.bypass_lock=true;card.bypass_discovery_center=true;card.bypass_discovery_ui=true
            card.params=card.params or {};card.params.bypass_lock=true
            card.params.bypass_discovery_center=true;card.params.bypass_discovery_ui=true
        end
        return card
    end
    if not BDC.compatibility.extension_check() then return M end
    for _,name in ipairs({'unlock_card','discover_card'}) do
        local previous=_G[name]
        _G[name]=function(obj,...)
            if M.blocked(obj) then BDC.log.info('run-only '..name..' suppressed: '..obj.key);return end
            return previous(obj,...)
        end
    end
    local previous=Card.load
    Card.load=function(self,data,...)
        local values=pack(previous(self,data,...))
        -- Game.start_run restores saveTable.GAME before loading CardAreas.
        -- Missing provenance (including 0.8.0 saves) deliberately means no guess.
        M.mark(self)
        return unpack(values,1,values.n)
    end
    local previous_ability=Card.set_ability
    Card.set_ability=function(self,...)
        local values=pack(previous_ability(self,...));M.mark(self);return unpack(values,1,values.n)
    end
    return M
end
