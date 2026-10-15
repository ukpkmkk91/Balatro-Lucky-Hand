-- Pinned native pool checks (1.0.1o / SMODS 26.829.0). No RNG or unlock edits.
return function(BDC)
    local M={}
    local function contains(area,key)
        for _,card in ipairs((area and area.cards) or {}) do
            if card.config and card.config.center and card.config.center.key==key then return true end
        end
        return false
    end
    function M.object(key)
        return (G.P_CENTERS or {})[key] or (G.P_CARDS or {})[key]
            or (G.P_BLINDS or {})[key] or (G.P_TAGS or {})[key] or (G.P_SEALS or {})[key]
    end
    local function denied(reason) return false,reason end
    function M.check(key,context)
        context=context or {}
        local obj=M.object(key)
        if not obj or not BDC.catalog.official(obj) then return denied('rule_official') end
        if not BDC.compatibility.active_run() then return denied('no_run') end
        if G.GAME.banned_keys and G.GAME.banned_keys[key] then return denied('rule_banned') end
        if obj.suit and obj.value then
            if context.shop and (G.GAME.playing_card_rate or 0)<=0 then return denied('rule_shop_type') end
            if context.pack and context.pack~='Standard' then return denied('rule_pack_kind') end
            return true
        end
        local add,opts=SMODS.add_to_pool(obj,{source=context.source})
        opts=opts or {}
        if not add then return denied('rule_pool') end
        local flags=G.GAME.pool_flags or {}
        if obj.no_pool_flag and flags[obj.no_pool_flag] or obj.yes_pool_flag and not flags[obj.yes_pool_flag] then
            return denied('rule_prerequisite')
        end
        local set=obj.set or (G.P_TAGS[key]==obj and 'Tag') or (G.P_SEALS[key]==obj and 'Seal')
        if set=='Joker' or obj.consumeable then
            if G.GAME.used_jokers[key] and not opts.allow_duplicates and not SMODS.showman(key) then
                return denied('rule_duplicate')
            end
            if set=='Joker' and (obj.rarity==4)~= (context.legendary==true) then return denied('rule_legendary') end
        end
        if obj.enhancement_gate then
            local found=false
            for _,card in ipairs(G.playing_cards) do if SMODS.has_enhancement(card,obj.enhancement_gate) then found=true;break end end
            if not found then return denied('rule_prerequisite') end
        end
        if set=='Planet' and obj.config and obj.config.softlock then
            local hand=G.GAME.hands[obj.config.hand_type]
            if not hand or hand.played<=0 then return denied('rule_prerequisite') end
        end
        if set=='Voucher' then
            if G.GAME.used_vouchers[key] or contains(G.shop_vouchers,key) or
                context.voucher_reserved and context.voucher_reserved[key] then return denied('rule_duplicate') end
            for _,required in pairs(obj.requires or {}) do
                if not G.GAME.used_vouchers[required] then return denied('rule_prerequisite') end
            end
        elseif set=='Tag' then
            if obj.requires and not (G.P_CENTERS[obj.requires] and G.P_CENTERS[obj.requires].discovered) then
                return denied('rule_prerequisite')
            end
            if obj.min_ante and obj.min_ante>G.GAME.round_resets.ante then return denied('rule_ante') end
        elseif set=='Booster' then
            if context.kind and obj.kind~=context.kind then return denied('rule_pack_kind') end
            if context.first_pack and (obj.kind~='Buffoon' or obj.config.extra~=2 or obj.config.choose~=1) then
                return denied('rule_fixed')
            end
        end
        if context.shop then
            local rate=({Joker='joker_rate',Tarot='tarot_rate',Planet='planet_rate',Spectral='spectral_rate',
                Default='playing_card_rate',Enhanced='playing_card_rate'})[set]
            if not rate or (tonumber(G.GAME[rate]) or 0)<=0 then return denied('rule_shop_type') end
        end
        if context.pack then
            local kind=context.pack
            local legal=(kind=='Buffoon' and set=='Joker') or (kind=='Celestial' and set=='Planet')
                or (kind=='Spectral' and set=='Spectral') or (kind=='Arcana' and set=='Tarot')
                or (kind=='Arcana' and set=='Spectral' and G.GAME.used_vouchers.v_omen_globe)
                or (kind=='Standard' and (set=='Enhanced' or set=='Default'))
            -- Native rare replacements are only Soul in Arcana/Spectral and Black Hole in Celestial/Spectral.
            if key=='c_soul' then legal=kind=='Arcana' or kind=='Spectral'
            elseif key=='c_black_hole' then legal=kind=='Celestial' or kind=='Spectral' end
            if not legal then return denied('rule_pack_kind') end
        elseif (obj.hidden or obj.name=='The Soul' or obj.name=='Black Hole') and not context.soulable then
            return denied('rule_hidden')
        end
        if context.set then
            local expected=context.set
            if set~=expected and not (expected=='Tarot_Planet' and (set=='Tarot' or set=='Planet'))
                and not (expected=='Consumeables' and obj.consumeable)
                and not (context.soulable and key=='c_soul' and (expected=='Tarot' or expected=='Spectral' or expected=='Tarot_Planet'))
                and not (context.soulable and key=='c_black_hole' and (expected=='Planet' or expected=='Spectral')) then
                return denied('rule_source_type')
            end
        end
        return true
    end
    function M.bosses(ante)
        local result,min={},math.huge
        ante=ante or G.GAME.round_resets.ante
        local showdown=ante>=2 and ante%G.GAME.win_ante==0
        for key,obj in pairs(G.P_BLINDS or {}) do
            if obj.boss and BDC.catalog.official(obj) and not G.GAME.banned_keys[key] then
                local add,opts=SMODS.add_to_pool(obj);opts=opts or {}
                local legal=opts.ignore_showdown_check or (obj.in_pool and (obj.boss.showdown or false)==showdown)
                    or (not obj.in_pool and ((obj.boss.showdown==true and showdown)
                        or (not obj.boss.showdown and not showdown and obj.boss.min<=math.max(1,ante))))
                if add and legal then
                    local used=G.GAME.bosses_used[key] or 0
                    result[key]=used;min=math.min(min,used)
                end
            end
        end
        for key,used in pairs(result) do if used>min then result[key]=nil end end
        return result
    end
    return M
end
