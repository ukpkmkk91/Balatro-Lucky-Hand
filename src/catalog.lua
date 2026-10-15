-- Enumerate live registries. No handwritten list of card prototypes.
return function(BDC)
    local M={categories={'Playing','Joker','Tarot','Planet','Spectral','Enhanced','Edition','Seal','Voucher','Booster','Tag','Blind','Back','Stake'}}
    function M.official(obj)
        if type(obj)~='table' then return false end
        -- SMODS takes ownership of some vanilla objects; this does not make them new content.
        return not obj.original_mod and (not obj.mod or obj.taken_ownership==true)
    end
    function M.capture()
        local result={rows={},counts={}}
        local P=BDC.presentation
        local function add(category,key,obj)
            if not M.official(obj) then return end
            local row={category=category,key=key,set=obj.set or category,name=P.name(obj.set or category,key,obj.name),
                unlocked=obj.unlocked~=false,discovered=obj.discovered~=false,order=obj.order or 0,details={}}
            if category=='Playing' then
                if not obj.suit or not obj.value then return end
                row.name=P.misc('ranks',obj.value)..' / '..P.misc('suits_plural',obj.suit)
                row.preview={layers={P.layer(G.P_CENTERS.c_base),P.layer(obj,true)}}
                row.details={BDC.inspector.t('playing_prototype'),row.name}
            else
                row.details=P.object_description(obj)
                local layer=P.layer(obj)
                if category=='Tag' then layer.atlas=obj.atlas or 'tags'
                elseif category=='Blind' then layer.atlas=obj.atlas or 'blind_chips';layer.pos.x=0
                elseif category=='Stake' then layer.atlas=obj.atlas or 'chips'
                elseif category=='Seal' then
                    local shared=G.shared_seals and G.shared_seals[key]
                    if shared then layer={atlas=shared.atlas.name,pos=P.copy(shared.sprite_pos)} end
                    row.name=P.name('Other',key:lower()..'_seal',obj.name)
                elseif category=='Edition' then layer=P.layer(G.P_CENTERS.c_base) end
                row.preview={layers={layer},edition=category=='Edition' and key:gsub('^e_','') or nil,
                    square=category=='Tag' or category=='Blind' or category=='Stake'}
                if obj.soul_pos then row.preview.layers[#row.preview.layers+1]={atlas=obj.atlas or 'Joker',pos=P.copy(obj.soul_pos)} end
            end
            row.search=table.concat({row.name,key,category,table.concat(row.details,' ')},' '):lower()
            result.rows[#result.rows+1]=row;result.counts[category]=(result.counts[category] or 0)+1
        end
        for key,obj in pairs(G.P_CARDS or {}) do add('Playing',key,obj) end
        local sets={};for _,set in ipairs(M.categories) do sets[set]=true end
        for key,obj in pairs(G.P_CENTERS or {}) do if sets[obj.set] then add(obj.set,key,obj) end end
        for _,registry in ipairs({{'Seal',G.P_SEALS},{'Tag',G.P_TAGS},{'Blind',G.P_BLINDS},{'Stake',G.P_STAKES}}) do
            for key,obj in pairs(registry[2] or {}) do add(registry[1],key,obj) end
        end
        table.sort(result.rows,function(a,b)
            if a.category~=b.category then return a.category<b.category end
            if a.order~=b.order then return a.order<b.order end
            return a.key<b.key
        end)
        BDC.log.info('official catalog snapshot count='..#result.rows)
        return result
    end
    function M.filter(snapshot,category,query)
        local out={};query=(query or ''):lower()
        for _,row in ipairs(snapshot.rows) do
            local matches=not category or row.category==category
            for word in query:gmatch('%S+') do if not row.search:find(word,1,true) then matches=false;break end end
            if matches then out[#out+1]=row end
        end
        return out
    end
    return M
end
