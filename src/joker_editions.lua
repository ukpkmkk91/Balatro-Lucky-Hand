-- Edit owned official Joker instances with the pinned native setter; no new Card or profile unlocks.
return function(BDC)
    local M={revision=0,message=nil,faulted=false}
    local function t(key) return BDC.inspector.t(key) end
    function M.editable()
        local ok=BDC.compatibility.draw_check()
        return ok and not M.faulted and BDC.random.editable() and Card and type(Card.set_edition)=='function'
    end
    function M.editions()
        local result={{key=false,name=t('joker_base')}}
        for _,row in ipairs((BDC.ui.catalog_snapshot or BDC.catalog.capture()).rows) do
            if row.category=='Edition' and row.key~='e_base' then result[#result+1]={key=row.key,name=row.name} end
        end
        return result
    end
    local function valid(card)
        return type(card)=='table' and card.area==G.jokers and card.config and card.config.center
            and card.config.center.set=='Joker' and BDC.catalog.official(card.config.center)
            and not card.removed and not card.destroyed and not card.getting_sliced and not card.dissolve
    end
    local function find(id)
        BDC.identity.sync()
        for _,card in ipairs((G.jokers and G.jokers.cards) or {}) do
            if valid(card) and BDC.identity.get(card)==id then return card end
        end
    end
    function M.capture()
        BDC.identity.sync();local rows={}
        if not BDC.compatibility.active_run() then return rows end
        for _,card in ipairs((G.jokers and G.jokers.cards) or {}) do
            if valid(card) then
                local center=card.config.center;local name=BDC.presentation.name('Joker',center.key,center.name)
                local key=card.edition and card.edition.key
                local row={session_id=BDC.identity.get(card),key=center.key,name=name,localized_name=name,
                    edition_key=key,edition=key and BDC.presentation.name('Edition',key) or t('joker_base'),details={},
                    area_name=t('jokers_tab'),attributes='',center_key=center.key}
                row=BDC.presentation.card(card,row)
                -- Joker edition descriptions use the Joker slot effect, not the playing-card hand-size effect.
                row.details={name,t('edition')..': '..row.edition}
                for _,text in ipairs(BDC.presentation.object_description(center,BDC.presentation.copy(card.ability))) do row.details[#row.details+1]=text end
                if key then for _,text in ipairs(BDC.presentation.object_description(G.P_CENTERS[key])) do row.details[#row.details+1]=text end end
                rows[#rows+1]=row
            end
        end
        return rows
    end
    function M.allowed(id,key)
        if not M.editable() then return false,'joker_unsafe' end
        local card=find(id);if not card then return false,'joker_missing' end
        if key then
            local obj=G.P_CENTERS[key]
            if not obj or obj.set~='Edition' or key=='e_base' or not BDC.catalog.official(obj) then return false,'rule_official' end
        end
        local area=G.jokers;local limits=area.config.card_limits
        local capacity
        if limits and type(limits.base)=='number' and type(area.count_property)=='function' then
            capacity=limits.base+(limits.mod or 0)+area:count_property('card_limit')-area:count_property('extra_slots_used')
        else capacity=area.config.card_limit end
        if type(capacity)~='number' then return false,'joker_unsafe' end
        local old=card.edition or {};local new=key and G.P_CENTERS[key].config or {}
        local after=capacity-(old.card_limit or 0)+(old.extra_slots_used or 0)+(new.card_limit or 0)-(new.extra_slots_used or 0)
        if after<#area.cards and after<capacity then return false,'joker_capacity' end
        return true,nil,card
    end
    function M.apply(id,key)
        local allowed,reason,card=M.allowed(id,key)
        if not allowed then M.message=reason;return false,reason end
        if (card.edition and card.edition.key or nil)==(key or nil) then M.message='joker_unchanged';return true end
        local original=BDC.presentation.copy(card.edition)
        local original_limit,original_used=card.ability.card_limit,card.ability.extra_slots_used
        local original_shaders=BDC.presentation.copy(card.ignore_base_shader)
        local original_shadow=BDC.presentation.copy(card.ignore_shadow)
        local original_cost,original_sell=card.cost,card.sell_cost
        local discovered,unlock,check=discover_card,unlock_card,check_for_unlock
        -- This synchronous native call does not yield or schedule animations (immediate + silent).
        -- Scope profile side-effect suppression to the edit; restore handlers even on failure.
        discover_card=function() end;unlock_card=function() end;check_for_unlock=function() end
        local ok,err=pcall(card.set_edition,card,key or nil,true,true)
        local rollback,rollback_err
        if not ok then
            rollback,rollback_err=pcall(card.set_edition,card,original,true,true)
            -- A setter error may happen after its slot subtraction. Restore the captured fields
            -- even if the retry failed or subtracted twice; no Card collections are edited.
            card.edition=original;card.ability.card_limit=original_limit;card.ability.extra_slots_used=original_used
            card.ignore_base_shader=original_shaders;card.ignore_shadow=original_shadow
            card.cost,card.sell_cost=original_cost,original_sell
            M.faulted=true
        end
        discover_card,unlock_card,check_for_unlock=discovered,unlock,check
        if not ok then
            BDC.log.warn('Joker edition edit disabled; rollback='..tostring(rollback)..': '..tostring(err)..'; '..tostring(rollback_err))
            M.message='joker_error';return false,M.message
        end
        if BDC.run_only and key then BDC.run_only.protect(key) end
        if type(G.jokers.handle_card_limit)=='function' then G.jokers:handle_card_limit() end
        M.revision=M.revision+1;M.message='joker_applied'
        BDC.log.info('owned Joker edition set: '..id..' '..card.config.center.key..' -> '..tostring(key or 'base'))
        return true,M.message
    end
    return M
end
