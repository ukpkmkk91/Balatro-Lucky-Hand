-- Each domain has a private one-shot FIFO. Empty domains delegate unchanged.
return function(BDC)
    local M={revision=0,enabled=true,pending={},message=nil,pack_context=nil,playing_specs={}}
    M.supported,M.reason=BDC.compatibility.extension_check()
    local function pack(...) return {n=select('#',...),...} end
    local function active() return M.supported and M.enabled and not BDC.disabled and BDC.compatibility.active_run() end
    function M.editable()
        if not M.supported or BDC.disabled or not BDC.compatibility.active_run() or BDC.draw.busy()
            or not G.STATES or not G.STATE_COMPLETE or G.screenwipe then return false end
        if G.STATE~=G.STATES.SELECTING_HAND and G.STATE~=G.STATES.BLIND_SELECT and G.STATE~=G.STATES.SHOP then return false end
        for key,value in pairs((G.CONTROLLER and G.CONTROLLER.locks) or {}) do
            if value and key~='frame' and key~='frame_set' then return false end
        end
        return true
    end
    local function changed(message)
        M.revision=M.revision+1;BDC.log.info('random controls '..message)
    end
    function M.reset(reason)
        M.pending={};M.pack_context=nil;M.message=nil;M.enabled=true;M.playing_specs={};changed('reset: '..tostring(reason))
    end
    function M.list(domain) return M.pending[domain] or {} end
    function M.clear(domain)
        if not M.editable() then return false end
        if domain=='pack_Standard' then M.playing_specs={} end
        M.pending[domain]=nil;changed('cleared '..domain);return true
    end
    function M.remove(domain,index)
        if not M.editable() then return false end
        if domain=='pack_Standard' then table.remove(M.playing_specs,index) end
        table.remove(M.list(domain),index);changed('removed '..domain);return true
    end
    function M.move(domain,index,delta)
        if not M.editable() then return false end
        local q=M.list(domain);local target=index+delta
        if target<1 or target>#q then return false end
        if domain=='pack_Standard' then M.playing_specs[index],M.playing_specs[target]=M.playing_specs[target],M.playing_specs[index] end
        q[index],q[target]=q[target],q[index];changed('reordered '..domain);return true
    end
    function M.context(domain)
        if domain=='shop' then return {shop=true,source='sho'} end
        if domain:sub(1,5)=='pack_' then return {pack=domain:sub(6)} end
        if domain=='booster' then return {first_pack=not G.GAME.first_shop_buffoon and not G.GAME.banned_keys.p_buffoon_normal_1} end
        if domain=='effect' then return {soulable=true} end
        return {}
    end
    function M.allowed(domain,key,context)
        if not BDC.compatibility.active_run() then return false,'no_run' end
        if domain=='probability' then return key=='success' or key=='failure' end
        if domain=='boss' then
            local obj=G.P_BLINDS[key]
            if not obj or not obj.boss or not BDC.catalog.official(obj) then return false,'rule_official' end
            if G.GAME.banned_keys[key] then return false,'rule_banned' end
            -- Actual ante/least-used eligibility is checked at generation, never by replacing a displayed Boss.
            return true
        end
        local obj=BDC.rules.object(key)
        local expected=({voucher='Voucher',tag='Tag',booster='Booster',edition='Edition',seal='Seal',enhancement='Enhanced'})[domain]
        if expected and (not obj or (obj.set or (G.P_TAGS[key]==obj and 'Tag') or (G.P_SEALS[key]==obj and 'Seal'))~=expected) then
            return false,'rule_source_type'
        end
        if domain=='effect' and not context then
            context=M.context(domain);context.legendary=obj and obj.rarity==4
        end
        return BDC.rules.check(key,context or M.context(domain))
    end
    function M.add(domain,key,spec)
        if not M.editable() then return false,'random_unsafe' end
        local ok,reason=M.allowed(domain,key)
        if not ok then M.message=reason;return false,reason end
        local q=M.pending[domain] or {};M.pending[domain]=q
        local obj=BDC.rules.object(key)
        if obj and (obj.set=='Joker' or obj.consumeable) and not SMODS.showman(key) then
            for _,item in ipairs(q) do if item==key then M.message='rule_queued';return false,'rule_queued' end end
        end
        q[#q+1]=key
        if domain=='pack_Standard' then
            if spec then M.playing_specs[#q]={front=key,enhancement=spec.enhancement,edition=spec.edition,seal=spec.seal}
            else M.playing_specs[#q]=false end
        end
        M.message=nil;changed('queued '..domain..': '..key);return true
    end
    local function take(domain,context)
        if not active() then return end
        local q=M.list(domain);local key=q[1]
        if not key then return end
        table.remove(q,1)
        if domain=='pack_Standard' then table.remove(M.playing_specs,1) end
        local ok,reason=M.allowed(domain,key,context)
        if not ok then M.message=reason;changed('rejected '..domain..': '..key..' ('..tostring(reason)..')');return end
        if BDC.run_only then BDC.run_only.protect(key) end
        changed('consumed '..domain..': '..key);return key
    end
    local function protect(fn)
        local ok,value=pcall(fn)
        if not ok then
            M.enabled=false;M.pending={};M.message='random_error'
            BDC.log.warn('random controls disabled: '..tostring(value));return nil
        end
        return value
    end
    if not M.supported then return M end
    local previous_boss=get_new_boss
    get_new_boss=function(...)
        local wanted=active() and M.list('boss')[1]
        if not wanted or G.FORCE_BOSS or (G.GAME.perscribed_bosses or {})[G.GAME.round_resets.ante] then
            return previous_boss(...)
        end
        local eligible=protect(function() return BDC.rules.bosses() end)
        local result=previous_boss(...)
        if not eligible then return result end
        local selected=protect(function() return take('boss') end)
        if not selected then return result end
        if eligible[selected]==nil then M.message='rule_boss_pool';changed('boss not eligible; native retained');return result end
        if selected~=result then
            G.GAME.bosses_used[result]=G.GAME.bosses_used[result]-1
            G.GAME.bosses_used[selected]=(G.GAME.bosses_used[selected] or 0)+1
        end
        return selected
    end
    -- The installed loader uses this path for the normal new-ante reset;
    -- get_new_boss remains the native reroll path. Small/Big are delegated intact.
    local previous_blind=SMODS.get_new_blind
    SMODS.get_new_blind=function(kind,...)
        local wanted=active() and M.list('boss')[1]
        if kind~='boss' or not wanted or G.FORCE_BOSS or (G.GAME.perscribed_bosses or {})[G.GAME.round_resets.ante] then
            return previous_blind(kind,...)
        end
        local eligible=protect(function()
            local out={};for _,key in ipairs(SMODS.create_blind_pool('boss')) do out[key]=true end;return out
        end)
        local result=previous_blind(kind,...)
        if not eligible then return result end
        local selected=protect(function() return take('boss') end)
        if not selected then return result end
        if not eligible[selected] then M.message='rule_boss_pool';changed('boss not eligible; native retained');return result end
        if selected~=result then
            local obj=G.P_BLINDS[result]
            local types=obj.boss.allow_others and {'boss'} or obj.blind_types
            for _,blind_type in pairs(types) do G.GAME.bosses_used[blind_type][result]=G.GAME.bosses_used[blind_type][result]-1 end
            SMODS.add_boss_to_used_table(selected,'boss')
        end
        return selected
    end
    local previous_pack=get_pack
    get_pack=function(seed,kind,...)
        if not active() or not M.list('booster')[1] then return previous_pack(seed,kind,...) end
        local first=not G.GAME.first_shop_buffoon and not G.GAME.banned_keys.p_buffoon_normal_1
        local result=previous_pack(seed,kind,...)
        local selected=protect(function() return take('booster',{kind=kind,first_pack=first}) end)
        return selected and G.P_CENTERS[selected] or result
    end
    for _,entry in ipairs({{'get_next_voucher_key','voucher'},{'get_next_tag_key','tag'}}) do
        local previous,name,domain=_G[entry[1]],entry[1],entry[2]
        _G[name]=function(...)
            if not active() or not M.list(domain)[1] or (domain=='tag' and G.FORCE_TAG) then return previous(...) end
            local result=previous(...)
            return protect(function() return take(domain) end) or result
        end
    end
    -- Normal new-ante vouchers use the loader's list factory, not the legacy key helper.
    local previous_vouchers=SMODS.get_next_vouchers
    SMODS.get_next_vouchers=function(vouchers,...)
        if not active() or not M.list('voucher')[1] then return previous_vouchers(vouchers,...) end
        local first=type(vouchers)=='table' and #vouchers or 0
        local result=previous_vouchers(vouchers,...)
        if type(result)~='table' or type(result.spawn)~='table' then return result end
        protect(function()
            local reserved={};for i=1,first do reserved[result[i]]=true end
            for i=first+1,#result do
                local selected=take('voucher',{voucher_reserved=reserved})
                if selected then
                    local old=result[i]
                    -- Swap a later native offer instead of duplicating it.
                    local swapped=false
                    for j=i+1,#result do if result[j]==selected then result[j]=old;swapped=true;break end end
                    result[i]=selected;result.spawn[selected]=true
                    if not swapped and old~=selected then result.spawn[old]=nil end
                end
                reserved[result[i]]=true
            end
        end)
        return result
    end
    local previous_context=SMODS.calculate_context
    SMODS.calculate_context=function(context,...)
        local values=pack(previous_context(context,...))
        if not active() or not context then return unpack(values,1,values.n) end
        if context.create_shop_card and M.list('shop')[1] and type(values[1])=='table' then
            protect(function()
                local key=take('shop',{shop=true,source='sho'})
                if not key then return end
                local obj=BDC.rules.object(key)
                local flags={};for k,v in pairs(values[1].shop_create_flags or {}) do flags[k]=v end
                flags.key=obj.suit and 'c_base' or key;flags.set=obj.suit and 'Base' or obj.set
                if obj.suit then flags.front=key end
                values[1].shop_create_flags=flags
            end)
        elseif context.create_booster_card then
            M.pack_context={booster=context.booster,index=context.index}
        elseif context.modify_booster_card then M.pack_context=nil end
        return unpack(values,1,values.n)
    end
    local previous_factory=SMODS.create_card
    SMODS.create_card=function(args,...)
        local ctx=M.pack_context
        if not active() or not ctx or args.area~=G.pack_cards then
            return BDC.run_only.mark(previous_factory(args,...))
        end
        M.pack_context=nil
        local obj=ctx.booster and ctx.booster.config and ctx.booster.config.center
        local domain=obj and 'pack_'..tostring(obj.kind)
        if not domain or not M.list(domain)[1] then return BDC.run_only.mark(previous_factory(args,...)) end
        -- Telescope (and any native fixed key) is a guarantee, not a random candidate.
        if args.key then return BDC.run_only.mark(previous_factory(args,...)) end
        local spec=domain=='pack_Standard' and M.playing_specs[1]
        local key=protect(function() return take(domain,{pack=obj.kind,source=args.key_append}) end)
        if not key then return BDC.run_only.mark(previous_factory(args,...)) end
        local updated={};for k,v in pairs(args) do updated[k]=v end
        local selected=BDC.rules.object(key)
        updated.key=selected.suit and (updated.set=='Enhanced' and nil or 'c_base') or key
        updated.set=selected.suit and updated.set or selected.set
        if selected.suit then updated.front=key end
        if selected.suit and spec then
            BDC.run_only.protect(spec.enhancement);BDC.run_only.protect(spec.edition)
            if spec.enhancement then updated.key=spec.enhancement;updated.set='Enhanced' else updated.key='c_base';updated.set='Base' end
            updated.edition=spec.edition and {[spec.edition:gsub('^e_','')]=true} or nil
            updated.no_edition=not spec.edition
            updated.seal=spec.seal
        end
        return BDC.run_only.mark(previous_factory(updated,...))
    end
    local previous_create=create_card
    create_card=function(set,area,legendary,rarity,skip,soulable,key,append,...)
        -- Only random official effect-generated cards; never intercept explicit recipes or shop/pack queues.
        if not active() or key or not M.list('effect')[1]
            or (area~=G.jokers and area~=G.consumeables) then
            return previous_create(set,area,legendary,rarity,skip,soulable,key,append,...)
        end
        local wanted=M.list('effect')[1];local obj=G.P_CENTERS[wanted]
        -- A mismatched source keeps the request for the next matching native generation.
        local legal=protect(function() return BDC.rules.check(wanted,{set=set,legendary=legendary==true,soulable=soulable,source=append}) end)
        if not legal then return previous_create(set,area,legendary,rarity,skip,soulable,key,append,...) end
        if set=='Joker' and rarity then
            local expected=type(rarity)=='number' and (rarity>0.95 and 3 or rarity>0.7 and 2 or 1) or rarity
            if obj.rarity~=expected then return previous_create(set,area,legendary,rarity,skip,soulable,key,append,...) end
        end
        local selected=protect(function() return take('effect',{set=set,legendary=legendary==true,soulable=soulable,source=append}) end)
        return BDC.run_only.mark(previous_create(set,area,legendary,rarity,skip,soulable,selected or key,append,...))
    end
    local previous_probability=SMODS.pseudorandom_probability
    SMODS.pseudorandom_probability=function(...)
        if not active() or not M.list('probability')[1] then return previous_probability(...) end
        local result=previous_probability(...)
        local current=SMODS.post_prob and SMODS.post_prob[#SMODS.post_prob]
        if current and (current.denominator<=0 or current.numerator<=0 or current.numerator>=current.denominator) then return result end
        local selected=protect(function() return take('probability') end)
        if not selected then return result end
        result=selected=='success'
        local post=SMODS.post_prob and SMODS.post_prob[#SMODS.post_prob]
        if post then post.result=result end
        return result
    end
    local function in_options(key,options)
        if not options then return true end
        for _,value in ipairs(options) do
            if value==key or type(value)=='table' and (value.key==key or value.name==key) then return true end
        end
        return false
    end
    local previous_edition=poll_edition
    poll_edition=function(seed,mod,no_negative,guaranteed,options,...)
        if not active() or not M.list('edition')[1] then return previous_edition(seed,mod,no_negative,guaranteed,options,...) end
        local result=previous_edition(seed,mod,no_negative,guaranteed,options,...)
        local key=M.list('edition')[1]
        if no_negative and key=='e_negative' or not in_options(key,options) then return result end
        local selected=protect(function() return take('edition') end)
        return selected and {[selected:gsub('^e_','')]=true} or result
    end
    for _,pair in ipairs({{'poll_seal','seal'},{'poll_enhancement','enhancement'}}) do
        local name,domain=pair[1],pair[2];local previous=SMODS[name]
        SMODS[name]=function(args,...)
            if not active() or not M.list(domain)[1] then return previous(args,...) end
            local result=previous(args,...);local key=M.list(domain)[1]
            args=args or {}
            if not in_options(key,args.options) or domain=='enhancement' and args.no_replace and (G.P_CENTERS[key] or {}).replace_base_card then return result end
            return protect(function() return take(domain) end) or result
        end
    end
    return M
end
