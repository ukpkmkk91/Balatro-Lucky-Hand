-- Runtime IDs only; queue edits never touch card collections or saves.
return function(BDC)
    local M = {revision=0}
    local items, session = {}, nil
    local function changed(message)
        M.revision=M.revision+1
        BDC.log.info('queue '..message..'; count='..#items)
    end
    function M.clear(reason)
        if #items==0 then return false end
        items={};changed('cleared ('..(reason or 'user')..')');return true
    end
    local function valid_shape(card)
        return type(card)=='table' and not card.removed and not card.destroyed and not card.shattered
            and not card.getting_sliced and card.dissolve==nil
            and type(card.base)=='table' and card.base.value~=nil and card.base.suit~=nil
    end
    -- Also usable after native remove_card has detached area, before emplace.
    function M.valid_instance(card)
        if not BDC.compatibility.active_run() or not valid_shape(card) then return false end
        for _,value in ipairs(G.playing_cards) do if value==card then return true end end
        return false
    end
    function M.available_card(card,deck)
        if deck~=G.deck or not M.valid_instance(card) or card.area~=deck or type(deck.cards)~='table' then return false end
        for _,value in ipairs(deck.cards) do if value==card then return true end end
        return false
    end
    local function available()
        local result, playing = {}, {}
        if not BDC.compatibility.active_run() or not G.deck or type(G.deck.cards)~='table' then return result end
        for _,card in ipairs(G.playing_cards) do if type(card)=='table' then playing[card]=true end end
        for _,card in ipairs(G.deck.cards) do
            if valid_shape(card) and playing[card] and card.area==G.deck then
                result[BDC.identity.get(card)]=true
            end
        end
        return result
    end
    function M.validate()
        local current=BDC.identity.session()
        if current~=session then M.clear('run/session changed');session=current end
        local valid=available()
        for i=#items,1,-1 do
            if not valid[items[i]] then
                local missing=table.remove(items,i)
                changed('instance missing or unavailable: '..missing)
            end
        end
        return valid
    end
    function M.ids()
        M.validate()
        local copy={};for i,id in ipairs(items) do copy[i]=id end;return copy
    end
    function M.contains(id)
        for _,value in ipairs(items) do if value==id then return true end end
        return false
    end
    function M.count() return #items end
    function M.drop(id,reason)
        for i=#items,1,-1 do
            if items[i]==id then table.remove(items,i);changed((reason or 'removed')..': '..id);return true end
        end
        return false
    end
    function M.editable()
        if BDC.disabled or not BDC.compatibility.active_run() or not G.STATES then return false end
        if BDC.draw and BDC.draw.busy() then return false end
        if G.STATE~=G.STATES.SELECTING_HAND and G.STATE~=G.STATES.BLIND_SELECT then return false end
        if G.STATE_COMPLETE~=true or G.screenwipe then return false end
        for key,value in pairs((G.CONTROLLER and G.CONTROLLER.locks) or {}) do
            -- The panel sets these short-lived locks when rebuilding its own UI.
            if value and key~='frame' and key~='frame_set' then return false end
        end
        return true
    end
    function M.add(id)
        local valid=M.validate()
        if not M.editable() then return false,'unsafe' end
        if type(id)~='string' or not valid[id] then return false,'unavailable' end
        if M.contains(id) then return false,'duplicate' end
        items[#items+1]=id;changed('added '..id);return true
    end
    -- Internal producer-only admission for a confirmed temporary card.
    function M.add_generated(card)
        M.validate()
        if not BDC.temporary or not BDC.temporary.is_temporary(card) or not M.available_card(card,G.deck) then return false end
        local id=BDC.identity.get(card)
        if M.contains(id) then return false end
        table.insert(items,1,id);changed('generated next '..id);return true
    end
    function M.remove(id)
        M.validate()
        if not M.editable() then return false,'unsafe' end
        for i,value in ipairs(items) do
            if value==id then table.remove(items,i);changed('removed '..id);return true end
        end
        return false,'unavailable'
    end
    function M.move(id,delta)
        M.validate()
        if not M.editable() then return false,'unsafe' end
        if delta~=1 and delta~=-1 then return false,'boundary' end
        for i,value in ipairs(items) do
            if value==id then
                local next_i=i+delta
                if next_i<1 or next_i>#items then return false,'boundary' end
                items[i],items[next_i]=items[next_i],items[i];changed('moved '..id..' to '..next_i);return true
            end
        end
        return false,'unavailable'
    end
    function M.clear_by_user()
        M.validate()
        if not M.editable() then return false,'unsafe' end
        return M.clear('user')
    end
    return M
end
