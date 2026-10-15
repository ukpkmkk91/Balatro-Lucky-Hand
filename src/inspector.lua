return function(BDC)
    local M = {}
    local function field(t, k) return type(t) == 'table' and rawget(t, k) or nil end
    local function scalar(v)
        if type(v) == 'string' or type(v) == 'number' or type(v) == 'boolean' then return tostring(v) end
        return nil
    end
    local function text(v)
        if scalar(v) then return scalar(v) end
        if type(v) == 'table' then
            local parts = {}
            for _, s in ipairs(v) do if type(s) == 'string' then parts[#parts+1] = s end end
            if #parts > 0 then return table.concat(parts, ' ') end
        end
    end
    function M.t(key)
        local d = field(field(G and G.localization, 'misc'), 'dictionary')
        return text(field(d, 'bdctrl_'..key)) or key
    end
    local function loc_misc(group, key)
        return text(field(field(field(G and G.localization, 'misc'), group), key))
    end
    local function loc_object(set, key, fallback)
        -- Read loaded localization, not calculate/loc_vars callbacks from unknown Mods.
        local entry = field(field(field(G and G.localization, 'descriptions'), set), key)
        return text(field(entry, 'name')) or scalar(fallback) or scalar(key) or M.t('na')
    end
    local function object_name(set, key, fallback)
        local center = field(G and G.P_CENTERS, key)
        return loc_object(set or field(center, 'set'), key, fallback or field(center, 'name'))
    end
    local function area_info(card)
        local a = field(card, 'area')
        -- Compare area objects, never screen positions or a guessed string type.
        if not a then return 'None' end
        for _, key in ipairs({'deck','hand','discard','play'}) do
            if G[key] and a == G[key] then return key end
        end
        return 'Other'
    end
    local function row(card, memberships)
        local base, config, ability = field(card,'base'), field(card,'config'), field(card,'ability')
        local center = field(config, 'center')
        local rank, suit = scalar(field(base,'value')), scalar(field(base,'suit'))
        if not rank or not suit then BDC.log.once('base', 'missing field: rank/suit; displaying N/A') end
        local center_key = scalar(field(config,'center_key')) or scalar(field(center,'key'))
        local ed = field(card,'edition')
        local edition_keys = {}
        if type(ed)=='table' then
            for key,value in pairs(ed) do
                if key=='key' and type(value)=='string' then edition_keys[#edition_keys+1]=value
                elseif type(key)=='string' and value==true then edition_keys[#edition_keys+1]=key end
            end
        end
        local edition = M.t('none')
        if type(ed) == 'table' then
            if field(ed,'key') then edition = object_name('Edition', field(ed,'key'))
            else
                local names = {}
                for k,v in pairs(ed) do
                    if type(k) == 'string' and v == true then names[#names+1] = object_name('Edition', 'e_'..k, k) end
                end
                table.sort(names) -- Sort only private display strings, never a game collection.
                edition = #names > 0 and table.concat(names, ', ') or M.t('unknown')
            end
        elseif ed ~= nil then edition = scalar(ed) or M.t('unknown') end
        local seal_key = scalar(field(card,'seal'))
        local seal = M.t('none')
        if seal_key then
            local seal_obj = field(G.P_SEALS,seal_key)
            seal = loc_misc('labels',seal_key:lower()..'_seal')
                or loc_object('Other',seal_key:lower()..'_seal',field(seal_obj,'name') or seal_key)
        end
        local extras = {}
        for key in pairs((SMODS and SMODS.Stickers) or {}) do
            if field(ability,key) then extras[#extras+1] = loc_misc('labels',key) or scalar(key) or '?' end
        end
        for key, enabled in pairs(field(center,'attributes') or {}) do
            if enabled then extras[#extras+1] = M.t('attr_'..key) end
        end
        if type(ability) == 'table' then
            for key,value in pairs(ability) do
                if type(key) == 'string' and key:match('^perma_') and type(value) == 'number' and value ~= 0 then
                    extras[#extras+1] = M.t(key)..'='..value
                end
            end
        end
        table.sort(extras)
        local area = area_info(card)
        local rank_name = (rank and loc_misc('ranks',rank)) or rank or M.t('na')
        local suit_name = (suit and loc_misc('suits_plural',suit)) or suit or M.t('na')
        return {
            session_id=BDC.identity.get(card), rank=rank_name, suit=suit_name,
            rank_key=rank, suit_key=suit, enhancement=center_key == 'c_base' and M.t('none')
                or object_name(field(center,'set'),center_key,field(center,'name')),
            edition=edition, seal=seal, area=area, area_name=M.t('area_'..area:lower()),
            edition_key=table.concat(edition_keys,' '),seal_key=seal_key,
            playing_card_number=scalar(field(card,'playing_card')) or M.t('na'),
            is_in_deck=memberships.deck[card] or false, is_in_hand=memberships.hand[card] or false,
            is_in_discard=memberships.discard[card] or false, is_in_play=memberships.play[card] or false,
            center_key=center_key, base_key=scalar(field(config,'card_key')),
            debuffed=field(card,'debuff') == true, face_down=field(card,'facing') == 'back',
            ability_name=scalar(field(ability,'name')), localized_name=rank_name..' / '..suit_name,
            attributes=table.concat(extras, ', '),
        }
    end
    function M.capture()
        BDC.identity.sync()
        local snapshot = {cards={}, counts={}, active=not not BDC.compatibility.active_run(), errors=0}
        if not snapshot.active then return snapshot end
        local memberships = {}
        for _, key in ipairs({'deck','hand','discard','play'}) do
            memberships[key] = {}
            local cards = field(G[key],'cards') or {}
            snapshot.counts[key] = #cards
            for _, card in ipairs(cards) do memberships[key][card] = true end
        end
        snapshot.counts.playing_cards = #G.playing_cards
        local seen = {}
        -- The UI receives value-only snapshots, so rendering cannot dereference dead cards.
        for _,card in ipairs(G.playing_cards) do
            if type(card) == 'table' and not seen[card] and not field(card,'removed') then
                seen[card] = true
                local ok, result = pcall(row, card, memberships)
                if ok then
                    if BDC.presentation then
                        local display_ok,display=pcall(BDC.presentation.card,card,result)
                        if display_ok then result=display
                        else BDC.log.once('presentation:'..tostring(result.center_key),'card display unavailable: '..tostring(display)) end
                    end
                    if BDC.temporary and BDC.temporary.is_temporary(card) then
                        result.temporary=true
                        result.attributes=M.t('temporary_label')..(result.attributes~='' and ', '..result.attributes or '')
                        if result.details then table.insert(result.details,1,M.t('temporary_label')) end
                    end
                    snapshot.cards[#snapshot.cards+1] = result
                else
                    snapshot.errors = snapshot.errors + 1
                    snapshot.cards[#snapshot.cards+1] = {session_id=BDC.identity.get(card), rank=M.t('na'),
                        suit=M.t('na'), enhancement=M.t('unknown'),edition=M.t('unknown'),seal=M.t('unknown'),
                        area=area_info(card),area_name=M.t('area_'..area_info(card):lower()),attributes=M.t('unknown')}
                    BDC.log.once('unsupported', 'unsupported object: '..tostring(result))
                end
            elseif type(card) ~= 'table' then
                snapshot.errors = snapshot.errors + 1
                BDC.log.once('noncard', 'unsupported object in G.playing_cards; skipped')
            end
        end
        return snapshot
    end
    return M
end
