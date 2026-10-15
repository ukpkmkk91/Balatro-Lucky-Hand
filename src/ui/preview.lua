-- Owned passive Sprites, never Card constructors or native collection callbacks.
return function(BDC)
    local M={pending={}}
    function M.cleanup(objects)
        for _,obj in ipairs(objects or M.pending) do
            if not obj.bdctrl_removed then pcall(function() obj:remove() end);obj.bdctrl_removed=true end
        end
        if not objects then M.pending={} end
    end
    function M.commit() local result=M.pending;M.pending={};return result end
    function M.tooltip(row,title)
        local lines=BDC.presentation.wrap(title or row.localized_name or row.name or row.session_id,48)
        local title_count=#lines
        for _,line in ipairs(row.details or {}) do
            for _,part in ipairs(BDC.presentation.wrap(line,48)) do lines[#lines+1]=part end
        end
        local scale=math.min(0.28,4.3/math.max(1,#lines))
        return {filler={args={},func=function()
            local nodes={}
            for i,line in ipairs(lines) do nodes[i]={n=G.UIT.R,config={align='cm',padding=0.015},nodes={
                {n=G.UIT.T,config={text=line,scale=i<=title_count and scale*1.1 or scale,
                    colour=i<=title_count and G.C.RED or G.C.UI.TEXT_DARK}}}} end
            return {n=G.UIT.C,config={align='cm',padding=0.02},nodes=nodes}
        end}}
    end
    function M.node(row,height)
        local spec=row.preview
        if not spec then return {n=G.UIT.T,config={text='—',scale=0.22,colour=G.C.UI.TEXT_LIGHT}} end
        local h=height or 0.56;local w=spec.square and h or h*71/95
        local objects,layers={},{}
        for _,layer in ipairs(spec.layers or {}) do
            local atlas=layer and (G.ASSET_ATLAS[layer.atlas] or (G.ANIMATION_ATLAS or {})[layer.atlas])
            if atlas then
                local obj=Sprite(0,0,w,h,atlas,{x=layer.pos and layer.pos.x or 0,y=layer.pos and layer.pos.y or 0})
                M.pending[#M.pending+1]=obj;objects[#objects+1]=obj;layers[#layers+1]=layer
                local remove=obj.remove
                obj.remove=function(self)
                    if self.bdctrl_removed then return end
                    self.bdctrl_removed=true;return remove(self)
                end
                obj.states.drag.can=false;obj.states.hover.can=false;obj.states.collide.can=false
            end
        end
        if #objects==0 then return {n=G.UIT.T,config={text='—',scale=0.22,colour=G.C.UI.TEXT_LIGHT}} end
        local root=objects[1];local original_draw=root.draw
        local function draw(self,...)
            local shader=spec.edition=='holo' and 'holo' or spec.edition
            local active=(shader=='foil' or shader=='holo' or shader=='polychrome' or shader=='negative') and G.SHADERS and G.SHADERS[shader]
            local now=G.TIMERS and G.TIMERS.REAL or 0
            local send={now/28,now}
            -- Native order: centre/front, edition overlay, then unaffected seal.
            for i,obj in ipairs(objects) do
                if layers[i].edition~=false then
                    if active and shader=='negative' then obj:draw_shader('negative',nil,send,true,i>1 and self or nil)
                    elseif i==1 then original_draw(self,...)
                    else obj:draw_from(self) end
                end
            end
            if active and shader~='negative' then
                for i,obj in ipairs(objects) do
                    if layers[i].edition~=false then obj:draw_shader(shader,nil,send,true,i>1 and self or nil) end
                end
            elseif active and G.SHADERS.negative_shine then
                self:draw_shader('negative_shine',nil,send,true)
            end
            for i,obj in ipairs(objects) do
                if layers[i].edition==false then obj:draw_from(self) end
            end
        end
        root.draw=function(self,...)
            if self.bdctrl_render_failed then return original_draw(self,...) end
            local graphics=love and love.graphics
            local depth=graphics and graphics.getStackDepth and graphics.getStackDepth()
            local ok,err=pcall(draw,self,...)
            if not ok then
                if graphics then
                    if depth then while graphics.getStackDepth()>depth do graphics.pop() end end
                    if graphics.setShader then graphics.setShader() end
                end
                self.bdctrl_render_failed=true
                BDC.log.once('preview:'..tostring(row.key or row.session_id),'preview effect disabled: '..tostring(err))
                return original_draw(self,...)
            end
        end
        -- The containing row owns hover. A colliding bare Sprite would intercept it.
        return {n=G.UIT.O,config={object=root,hover=false,can_collide=false,
            on_demand_tooltip=M.tooltip(row),bdctrl_preview=true}}
    end
    return M
end
