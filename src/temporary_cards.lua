-- Missing official cards are confirmed separately, then created at a draw producer.
-- Native play/discard processing completes before cleanup. Private state is never saved.
return function(BDC)
    local M={pending=nil,revision=0}
    local function pack(...) return {n=select('#',...),...} end
    M.supported=BDC.compatibility.extension_check()
    local tracked=setmetatable({},{__mode='k'})
    local copy_candidates=setmetatable({},{__mode='k'})
    local function changed(message) M.revision=M.revision+1;BDC.log.info('temporary card '..message) end
    function M.is_temporary(card) return tracked[card]~=nil end
    function M.reset(reason) M.pending=nil;changed('pending reset: '..tostring(reason)) end
    local function shape(spec)
        if type(spec)~='table' or not BDC.catalog.official(G.P_CARDS[spec.front]) then return false end
        if spec.enhancement and (not BDC.catalog.official(G.P_CENTERS[spec.enhancement]) or G.P_CENTERS[spec.enhancement].set~='Enhanced') then return false end
        if spec.edition and (not BDC.catalog.official(G.P_CENTERS[spec.edition]) or G.P_CENTERS[spec.edition].set~='Edition' or spec.edition=='e_negative') then return false end
        if spec.seal and not BDC.catalog.official(G.P_SEALS[spec.seal]) then return false end
        return true
    end
    function M.existing(spec)
        local front=G.P_CARDS[spec.front]
        if not front then return end
        for _,card in ipairs((G.deck and G.deck.cards) or {}) do
            local edition=spec.edition and spec.edition:gsub('^e_','')
            if BDC.queue.available_card(card,G.deck) and card.base.suit==front.suit and card.base.value==front.value
                and card.config.center.key==(spec.enhancement or 'c_base')
                and (edition and card.edition and card.edition[edition] or not edition and not card.edition)
                and card.seal==spec.seal and not BDC.queue.contains(BDC.identity.get(card)) then return card end
        end
    end
    function M.select(spec,confirmed)
        if not BDC.queue.editable() or not M.supported or not BDC.draw.supported or not shape(spec) then return false,'random_unsafe' end
        local card=M.existing(spec)
        if card then
            local ok,reason=BDC.queue.add(BDC.identity.get(card))
            if ok then BDC.draw.set_enabled(true);return true,'temporary_existing' end
            return false,reason
        end
        if not confirmed then return false,'temporary_confirm' end
        if not BDC.draw.set_enabled(true) then return false,'random_unsafe' end
        M.pending={front=spec.front,enhancement=spec.enhancement,edition=spec.edition,seal=spec.seal,run=G.GAME}
        changed('confirmed missing official front '..spec.front);return true,'temporary_pending'
    end
    function M.cancel()
        if not BDC.queue.editable() then return false end
        M.pending=nil;changed('cancelled');return true
    end
    local function remove(card,reason)
        local originals={}
        for _,original in ipairs(G.playing_cards or {}) do if original~=card then originals[original]=original.playing_card end end
        BDC.queue.drop(BDC.identity.get(card),'temporary cleanup')
        local ok,err=pcall(card.remove,card)
        -- Native remove renumbers all playing_card fields. Preserve surviving instance identifiers here.
        for original,id in pairs(originals) do if not original.removed then original.playing_card=id end end
        if not ok then
            -- Retain save filtering if native removal failed partway through.
            tracked[card].cleanup_failed=true;BDC.draw.enabled=false
            BDC.log.warn('temporary cleanup contained; override disabled: '..tostring(err))
            return
        end
        tracked[card]=nil;changed('removed after '..reason)
    end
    local function present(card)
        if card.area then return true end
        for _,instance in ipairs(G.playing_cards or {}) do if instance==card then return true end end
        return false
    end
    local function cleanup()
        for card,state in pairs(tracked) do
            if card.removed and not present(card) then tracked[card]=nil
            elseif state.run~=G.GAME then tracked[card]=nil
            elseif state.cleanup_failed then -- Keep filtering a partially removed temporary instance.
            elseif state.in_hand and card.area~=G.hand and card.area~=G.play then remove(card,'native hand processing')
            elseif not state.in_hand and card.area==G.deck and not BDC.draw.busy() then
                if not M.pending then M.pending=state.spec end
                remove(card,'cancelled draw')
            end
        end
    end
    local function prepare(requested)
        cleanup()
        if BDC.disabled or not M.pending or M.pending.run~=G.GAME or not BDC.draw.enabled or not BDC.draw.supported
            or not BDC.compatibility.active_run() or BDC.draw.busy() or not G.deck or not G.hand then return end
        if type(requested)=='number' and requested<=0 then return end
        if G.hand.config.card_limit-#G.hand.cards-(SMODS.cards_to_draw or 0)<=0 then return end
        local spec=M.pending
        if not shape(spec) then M.pending=nil;changed('invalid prototype; native draw retained');return end
        if BDC.run_only then
            BDC.run_only.protect(spec.enhancement);BDC.run_only.protect(spec.edition)
        end
        local card=create_playing_card({front=G.P_CARDS[spec.front],center=G.P_CENTERS[spec.enhancement or 'c_base']},G.deck,true,true,nil,true)
        tracked[card]={run=G.GAME,spec=spec,in_hand=false}
        if spec.edition then card:set_edition({[spec.edition:gsub('^e_','')]=true},true,true) end
        if spec.seal then card:set_seal(spec.seal,true);card.ability.delay_seal=false end
        G.deck:emplace(card)
        if not BDC.queue.add_generated(card) then remove(card,'queue rejected');return end
        M.pending=nil;changed('created for next draw '..spec.front)
    end
    local function safe_prepare(requested)
        local ok,err=pcall(prepare,requested)
        if not ok then
            M.pending=nil;BDC.draw.enabled=false
            BDC.log.warn('temporary creation disabled; native draw retained: '..tostring(err))
            -- Only remove this module's new cards, never replace native collections.
            for card,state in pairs(tracked) do if not state.in_hand and card.area~=G.play then pcall(remove,card,'creation failure') end end
        end
    end
    if not BDC.draw.supported or not M.supported then return M end
    local previous_standard=G.FUNCS.draw_from_deck_to_hand
    G.FUNCS.draw_from_deck_to_hand=function(...) safe_prepare();return previous_standard(...) end
    local previous_helper=SMODS.draw_cards
    SMODS.draw_cards=function(number,...) safe_prepare(number);return previous_helper(number,...) end
    local previous_emplace=CardArea.emplace
    CardArea.emplace=function(self,card,...)
        local values=pack(previous_emplace(self,card,...))
        -- copy_card also creates title-area previews. Only native gameplay copies
        -- registered in the run and placed into a playing-card area inherit cleanup.
        -- DNA/Cryptid register before emplace; Death edits its existing target.
        local candidate=copy_candidates[card]
        if candidate and candidate.run==G.GAME and card.area==self and
            (self==G.hand or self==G.play or self==G.deck or self==G.discard) then
            for _,instance in ipairs(G.playing_cards or {}) do
                if instance==card then
                    tracked[card]=candidate;copy_candidates[card]=nil
                    break
                end
            end
        end
        if tracked[card] and self==G.hand and card.area==G.hand then
            tracked[card].in_hand=true;changed('entered hand '..BDC.identity.get(card))
        end
        return unpack(values,1,values.n)
    end
    local previous_copy=copy_card
    copy_card=function(source,target,...)
        local result=previous_copy(source,target,...)
        if not target and tracked[source] and result and result~=source then
            copy_candidates[result]={run=G.GAME,spec=tracked[source].spec,in_hand=tracked[source].in_hand}
        end
        return result
    end
    local previous_save=CardArea.save
    CardArea.save=function(self,...)
        local result=previous_save(self,...)
        if type(result)~='table' or type(result.cards)~='table' then return result end
        local filtered,any={},false
        for index,card in ipairs(self.cards or {}) do
            if tracked[card] then any=true else filtered[#filtered+1]=result.cards[index] end
        end
        if any then
            result.cards=filtered
            local config={};for key,value in pairs(result.config or {}) do config[key]=value end
            config.card_count=#filtered;result.config=config
            BDC.log.info('temporary cards omitted from native area save')
        end
        return result
    end
    local previous_update=Game.update
    local function safe_idle()
        return G.STATE_COMPLETE and not BDC.draw.busy() and
            (G.STATE==G.STATES.SELECTING_HAND or G.STATE==G.STATES.BLIND_SELECT or
                G.STATE==G.STATES.SHOP or G.STATE==G.STATES.ROUND_EVAL)
    end
    Game.update=function(self,dt,...)
        local values=pack(previous_update(self,dt,...))
        -- Cleanup is scheduled through the manager, including after a BDC fault.
        if not M.cleanup_scheduled and BDC.compatibility.active_run() and safe_idle() then
            local needed=false
            for card,state in pairs(tracked) do
                if not state.cleanup_failed and (card.removed or state.run~=G.GAME or
                    state.in_hand and card.area~=G.hand and card.area~=G.play) then needed=true;break end
            end
            if needed then
                M.cleanup_scheduled=true
                G.E_MANAGER:add_event(Event{trigger='after',delay=0,blocking=false,func=function()
                    M.cleanup_scheduled=false
                    if safe_idle() then
                        local ok,err=pcall(cleanup);if not ok then BDC.log.warn('temporary cleanup failure: '..tostring(err)) end
                    end
                    return true
                end})
            end
        end
        return unpack(values,1,values.n)
    end
    return M
end
