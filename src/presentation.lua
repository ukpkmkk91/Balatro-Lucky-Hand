-- Static, value-only presentation. Never construct a Card/Tag or invoke effects.
return function(BDC)
    local M={}
    local function t(k) return BDC.inspector.t(k) end
    function M.copy(value,seen)
        if type(value)~='table' then
            if type(value)~='function' and type(value)~='userdata' then return value end
            return nil
        end
        seen=seen or {};if seen[value] then return nil end;seen[value]=true
        local out={};for k,v in pairs(value) do
            if type(k)=='string' or type(k)=='number' then out[k]=M.copy(v,seen) end
        end
        seen[value]=nil;return out
    end
    function M.name(set,key,fallback)
        if set=='Seal' then set='Other';key=key:lower()..'_seal' end
        local entry=((G.localization or {}).descriptions or {})[set or '']
        local name=entry and entry[key] and entry[key].name
        return type(name)=='table' and table.concat(name,' ') or name or fallback or key or t('unknown')
    end
    function M.misc(group,key)
        return (((G.localization or {}).misc or {})[group] or {})[key] or key
    end
    function M.wrap(value,width)
        local out,line,size={},'',0
        for c in tostring(value or ''):gmatch('[%z\1-\127\194-\244][\128-\191]*') do
            local cost=#c>1 and 2 or 1
            if c=='\n' or size+cost>(width or 54) then
                out[#out+1]=line;line='';size=0
            end
            if c~='\n' then line=line..c;size=size+cost end
        end
        if line~='' then out[#out+1]=line end
        return out
    end
    function M.description(set,key,vars)
        local entry=(((G.localization or {}).descriptions or {})[set] or {})[key]
        local out={}
        for _,line in ipairs(entry and entry.text or {}) do
            -- Native localization text, with colour/animation markup removed. No DynaText.
            line=line:gsub('{[^}]*}',''):gsub('#(%d+)#',function(i)
                local value=vars and vars[tonumber(i)]
                return (type(value)=='string' or type(value)=='number') and tostring(value) or t('dynamic_value')
            end)
            for _,part in ipairs(M.wrap(line)) do out[#out+1]=part end
        end
        if #out==0 then out[1]=t('no_effect') end
        return out
    end
    function M.vars(obj,ability)
        local cfg=ability or obj.config or {};local name=obj.name;local vars={}
        if obj.set=='Joker' then
            -- Vanilla's vars-only helper works on an isolated plain display table.
            -- Misprint creates random animated DynaText even in vars_only; skip it.
            if name=='Misprint' then return {} end
            if Card and Card.generate_UIBox_ability_table then
                local a=M.copy(cfg);a.set='Joker';a.name=name;a.x_mult=a.x_mult or a.Xmult or 1
                for _,field in ipairs({'mult','h_mult','h_dollars','p_dollars','t_mult','t_chips','h_size','d_size'}) do
                    if a[field]==nil then a[field]=0 end
                end
                a.to_do_poker_hand=a.to_do_poker_hand or 'High Card'
                a.invis_rounds=a.invis_rounds or 0;a.caino_xmult=a.caino_xmult or 1
                if name=='Yorick' then a.yorick_discards=a.yorick_discards or a.extra.discards end
                local shadow={ability=a,config={center=M.copy(obj)},bypass_lock=true,bypass_discovery_ui=true}
                local ok,result=pcall(Card.generate_UIBox_ability_table,shadow,true)
                if ok then return result or {} end
                BDC.log.once('description:'..obj.key,'description values unavailable: '..tostring(obj.key))
            end
        elseif obj.set=='Tag' and Tag and Tag.get_uibox_table then
            local ok,result=pcall(Tag.get_uibox_table,{name=name,config=M.copy(cfg),ability={orbital_hand='['..M.misc('dictionary','k_poker_hand')..']'}},nil,true)
            if ok then return result or {} end
        elseif obj.set=='Planet' then
            local hand=G.GAME and G.GAME.hands and G.GAME.hands[cfg.hand_type] or {}
            vars={hand.level or 1,M.misc('poker_hands',cfg.hand_type),hand.l_mult,hand.l_chips}
        elseif obj.set=='Booster' then vars={cfg.choose,cfg.extra}
        elseif obj.set=='Edition' then vars={cfg.extra or cfg.chips or cfg.mult or cfg.x_mult or cfg.card_limit}
        elseif obj.set=='Enhanced' then
            local probability=G.GAME and G.GAME.probabilities and G.GAME.probabilities.normal or 1
            if obj.effect=='Mult Card' then vars={cfg.mult}
            elseif obj.effect=='Glass Card' then vars={cfg.Xmult,probability,cfg.extra}
            elseif obj.effect=='Steel Card' then vars={cfg.h_x_mult}
            elseif obj.effect=='Stone Card' or obj.effect=='Bonus Card' then vars={cfg.bonus}
            elseif obj.effect=='Gold Card' then vars={cfg.h_dollars}
            elseif obj.effect=='Lucky Card' then vars={probability,cfg.mult,5,cfg.p_dollars,15,probability} end
        elseif obj.set=='Tarot' then
            if cfg.mod_conv then vars={cfg.max_highlighted,M.name('Enhanced',cfg.mod_conv)}
            elseif cfg.suit_conv then vars={cfg.max_highlighted,M.misc('suits_plural',cfg.suit_conv)}
            elseif name=='The High Priestess' then vars={cfg.planets}
            elseif name=='The Emperor' then vars={cfg.tarots}
            elseif name=='The Wheel of Fortune' then vars={G.GAME and G.GAME.probabilities and G.GAME.probabilities.normal or 1,cfg.extra}
            elseif name=='The Fool' then
                local last=G.GAME and G.GAME.last_tarot_planet;local center=last and G.P_CENTERS[last]
                vars={center and M.name(center.set,last) or t('none')}
            elseif name=='Temperance' then
                local total=0;for _,c in ipairs(G.jokers and G.jokers.cards or {}) do total=total+(c.sell_cost or 0) end
                vars={cfg.extra,math.min(cfg.extra or 0,total)}
            else vars={cfg.max_highlighted or cfg.extra} end
        elseif obj.set=='Spectral' then
            if type(cfg.extra)=='table' then vars={cfg.extra.destroy,cfg.extra.dollars}
            elseif name=='Ectoplasm' then vars={G.GAME and G.GAME.ecto_minus or 1}
            else vars={cfg.extra} end
        elseif obj.set=='Voucher' then
            local extra=cfg.extra_disp or cfg.extra
            if name=='Seed Money' or name=='Money Tree' then extra=type(extra)=='number' and extra/5 or extra end
            vars={extra}
        elseif obj.set=='Back' then
            if name=='Blue Deck' then vars={cfg.hands}
            elseif name=='Red Deck' then vars={cfg.discards}
            elseif name=='Yellow Deck' then vars={cfg.dollars}
            elseif name=='Green Deck' then vars={cfg.extra_hand_bonus,cfg.extra_discard_bonus}
            elseif name=='Black Deck' then vars={cfg.joker_slot,-(cfg.hands or 0)}
            elseif name=='Magic Deck' then vars={M.name('Voucher','v_crystal_ball'),M.name('Tarot','c_fool')}
            elseif name=='Nebula Deck' then vars={M.name('Voucher','v_telescope'),-1}
            elseif name=='Zodiac Deck' then vars={M.name('Voucher','v_tarot_merchant'),M.name('Voucher','v_planet_merchant'),M.name('Voucher','v_overstock_norm')}
            elseif name=='Painted Deck' then vars={cfg.hand_size,cfg.joker_slot}
            elseif name=='Anaglyph Deck' then vars={M.name('Tag','tag_double')}
            elseif name=='Plasma Deck' then vars={cfg.ante_scaling} end
        elseif obj.set=='Blind' then
            -- Read-only variables for the native descriptions on this pinned baseline.
            if obj.key=='bl_ox' then vars={M.misc('poker_hands',G.GAME and G.GAME.current_round and G.GAME.current_round.most_played_poker_hand or 'High Card')}
            elseif obj.key=='bl_wheel' then vars={G.GAME and G.GAME.probabilities and G.GAME.probabilities.normal or 1,7}
            elseif obj.key=='bl_arm' then vars={1} end
        end
        return vars
    end
    function M.object_description(obj,ability)
        local set,key=obj.set,obj.key
        if key=='j_misprint' then
            local extra=(ability or obj.config or {}).extra or {}
            return {t('random_range')..': +'..tostring(extra.min or 0)..'–'..tostring(extra.max or 0)..' '..M.misc('dictionary','k_mult')}
        elseif key=='m_bonus' then
            return {'+'..tostring((ability or obj.config or {}).bonus or 0)..' '..M.misc('dictionary','k_chips')}
        end
        if set=='Booster' then
            set='Other';key=key:gsub('_%d+$','')
        elseif set=='Seal' then set='Other';key=key:lower()..'_seal' end
        return M.description(set,key,M.vars(obj,ability))
    end
    function M.layer(obj,front)
        if not obj then return end
        local atlas,pos=obj.atlas,obj.pos
        if front and get_front_spriteinfo then atlas,pos=get_front_spriteinfo(obj) end
        if type(atlas)=='table' then atlas=atlas.name end
        atlas=atlas or (front and 'cards_1') or ((obj.set=='Joker' or obj.set=='Tarot' or obj.set=='Planet' or obj.set=='Spectral' or obj.set=='Voucher') and obj.set) or 'centers'
        return {atlas=atlas,pos={x=pos and pos.x or 0,y=pos and pos.y or 0}}
    end
    function M.card(card,row)
        local center=card.config and card.config.center or {};local front=card.config and card.config.card
        if not front and row.base_key then front=G.P_CARDS[row.base_key] end
        local edition_key=row.edition_key or ''
        row.preview={layers={M.layer(center)},edition=edition_key:match('e_(%w+)') or edition_key:match('(%w+)')}
        if front and not center.replace_base_card and center.key~='m_stone' then row.preview.layers[#row.preview.layers+1]=M.layer(front,true) end
        if card.seal then
            local seal=G.P_SEALS[card.seal];local sprite=G.shared_seals and G.shared_seals[card.seal]
            row.preview.layers[#row.preview.layers+1]=seal and {atlas=seal.atlas or 'centers',pos=M.copy(seal.pos),edition=false}
                or sprite and {atlas=sprite.atlas.name,pos=M.copy(sprite.sprite_pos),edition=false}
        end
        local details={row.localized_name,t('area')..': '..row.area_name}
        local function add(obj,ability)
            if not obj then return end
            details[#details+1]=M.name(obj.set,obj.key,obj.name)
            for _,line in ipairs(M.object_description(obj,ability)) do details[#details+1]=line end
        end
        if center.key~='c_base' then add(center,M.copy(card.ability)) end
        if edition_key~='' then
            local key=edition_key:match('(e_%w+)') or 'e_'..edition_key:match('(%w+)')
            if key=='e_negative' then
                details[#details+1]=M.name('Edition',key)
                for _,line in ipairs(M.description('Edition','e_negative_playing_card',{card.edition and card.edition.card_limit or 1})) do details[#details+1]=line end
            else add(G.P_CENTERS[key]) end
        end
        if card.seal then add(G.P_SEALS[card.seal]) end
        if row.debuffed then details[#details+1]=t('debuffed') end
        if row.attributes~='' then
            for _,line in ipairs(M.wrap(row.attributes)) do details[#details+1]=line end
        end
        row.details=details
        return row
    end
    return M
end
