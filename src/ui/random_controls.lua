-- UI snapshots contain keys/text only. Selecting never constructs a Card.
return function(BDC)
    local M={domain='boss',query='',page=1,queue_page=1,confirmation=nil}
    function M.reset()
        M.confirmation=nil;M.message=nil;M.page=1;M.queue_page=1
    end
    local function t(key) return BDC.inspector.t(key) end
    local function line(text,scale,colour)
        return {n=G.UIT.R,config={align='cm',padding=0.025},nodes={{n=G.UIT.T,
            config={text=tostring(text),scale=scale or 0.25,colour=colour or G.C.UI.TEXT_LIGHT}}}}
    end
    local function button(text,callback,width,ref)
        return UIBox_button{label={text},button=callback or 'nil',minw=width or 2,minh=0.4,scale=0.24,
            colour=callback and G.C.BLUE or G.C.UI.BACKGROUND_INACTIVE,ref_table=ref,one_press=true}
    end
    local function columns(nodes) return {n=G.UIT.R,config={align='cm',padding=0.035},nodes=nodes} end
    local function cell(node) return {n=G.UIT.C,config={align='cm',padding=0.03},nodes={node}} end
    function M.domains()
        local domains={'temporary','boss','shop','booster'}
        local kinds={}
        for _,obj in pairs(G.P_CENTERS or {}) do
            if obj.set=='Booster' and obj.kind and BDC.catalog.official(obj) then kinds[obj.kind]=true end
        end
        local ordered={};for kind in pairs(kinds) do ordered[#ordered+1]=kind end;table.sort(ordered)
        for _,kind in ipairs(ordered) do domains[#domains+1]='pack_'..kind end
        for _,domain in ipairs({'voucher','tag','effect','edition','seal','enhancement','probability'}) do domains[#domains+1]=domain end
        return domains
    end
    local function category(row)
        local domain=M.domain
        if domain=='temporary' then return row.category=='Playing' end
        if domain=='boss' then return row.category=='Blind' and G.P_BLINDS[row.key].boss end
        if domain=='shop' then return row.category=='Playing' or row.category=='Joker' or row.category=='Tarot' or row.category=='Planet' or row.category=='Spectral' end
        if domain=='booster' then return row.category=='Booster' end
        if domain=='voucher' then return row.category=='Voucher' end
        if domain=='tag' then return row.category=='Tag' end
        if domain=='edition' then return row.category=='Edition' end
        if domain=='seal' then return row.category=='Seal' end
        if domain=='enhancement' then return row.category=='Enhanced' end
        if domain=='effect' then return row.category=='Joker' or row.category=='Tarot' or row.category=='Planet' or row.category=='Spectral' end
        local kind=domain:sub(6)
        if kind=='Standard' then return row.category=='Playing' end
        if kind=='Buffoon' then return row.category=='Joker' end
        if kind=='Celestial' then return row.category=='Planet' or row.key=='c_black_hole' end
        if kind=='Arcana' then return row.category=='Tarot' or row.category=='Spectral' end
        if kind=='Spectral' then return row.category=='Spectral' end
        return false
    end
    function M.spec(key)
        return {front=key,enhancement=M.enhancement,edition=M.edition,seal=M.seal}
    end
    local function rows()
        if M.domain=='probability' then
            return {{key='success',name=t('probability_success'),details={t('probability_help')}},
                {key='failure',name=t('probability_failure'),details={t('probability_help')}}}
        end
        local out={};local snapshot=BDC.ui.catalog_snapshot or BDC.catalog.capture()
        for _,row in ipairs(BDC.catalog.filter(snapshot,nil,M.query)) do if category(row) then out[#out+1]=row end end
        return out
    end
    local function modifier(field,category_name)
        local opts,keys,current={t('none')},{false},1
        for _,row in ipairs(BDC.ui.catalog_snapshot.rows) do
            if row.category==category_name and row.key~='e_negative' then
                opts[#opts+1]=row.name;keys[#keys+1]=row.key
                if M[field]==row.key then current=#keys end
            end
        end
        M[field..'_keys']=keys
        return cell(BDC.dropdown.node{title=t(field),options=opts,current_option=current,opt_callback='bdctrl_random_modifier',
            bdc_field=field,w=3.2,h=0.5,text_scale=0.28,scale=0.6,no_pips=true})
    end
    local function display_row(row,spec)
        local display={};for k,v in pairs(row) do display[k]=v end
        if not spec or row.category~='Playing' then return display end
        local center=G.P_CENTERS[spec.enhancement or 'c_base'] or {};local front=G.P_CARDS[row.key]
        display.preview={layers={BDC.presentation.layer(center)},
            edition=spec.edition and spec.edition:gsub('^e_','') or nil,seal=spec.seal}
        -- Match presentation.card: Stone/replacement enhancements hide the rank/suit face.
        if front and not center.replace_base_card and center.key~='m_stone' then
            display.preview.layers[#display.preview.layers+1]=BDC.presentation.layer(front,true)
        end
        display.details={};for _,text in ipairs(row.details or {}) do display.details[#display.details+1]=text end
        for _,key in ipairs({spec.enhancement or false,spec.edition or false,spec.seal or false}) do
            if key then
                local obj=G.P_CENTERS[key] or G.P_SEALS[key]
                if obj then
                    display.details[#display.details+1]=BDC.presentation.name(obj.set or 'Seal',key,obj.name)
                    for _,text in ipairs(BDC.presentation.object_description(obj)) do display.details[#display.details+1]=text end
                end
            end
        end
        if spec.seal then
            local shared=G.shared_seals and G.shared_seals[spec.seal]
            if shared then display.preview.layers[#display.preview.layers+1]={atlas=shared.atlas.name,pos=BDC.presentation.copy(shared.sprite_pos),edition=false} end
        end
        return display
    end
    M.display_row=display_row
    local function queue_rows(candidates)
        local q=BDC.random.list(M.domain);local by_key={}
        for _,row in ipairs((BDC.ui.catalog_snapshot or {}).rows or {}) do by_key[row.key]=row end
        for _,row in ipairs(candidates) do by_key[row.key]=row end
        local result={line(t('random_pending')..' ('..#q..')',0.27,G.C.GOLD)}
        local pages=math.max(1,math.ceil(#q/3));M.queue_page=math.max(1,math.min(M.queue_page,pages))
        for i=(M.queue_page-1)*3+1,math.min(M.queue_page*3,#q) do
            local row=by_key[q[i]] or {name=q[i]};local editable=BDC.random.editable();local ref={index=i}
            local display=display_row(row,M.domain=='pack_Standard' and BDC.random.playing_specs[i] or nil)
            local node=columns({cell(BDC.preview.node(display,0.5)),cell(line(i..'. '..BDC.filter.clip(row.name,32),0.23)),
                cell(button(t('up'),editable and i>1 and 'bdctrl_random_up' or nil,0.7,ref)),
                cell(button(t('down'),editable and i<#q and 'bdctrl_random_down' or nil,0.7,ref)),
                cell(button(t('remove'),editable and 'bdctrl_random_remove' or nil,1.2,ref))})
            node.config.hover=true;node.config.on_demand_tooltip=BDC.preview.tooltip(display)
            result[#result+1]=node
        end
        if #q==0 then result[#result+1]=line(t('random_empty'),0.23) end
        result[#result+1]=columns({cell(button(t('previous'),'bdctrl_random_qprev',1.5)),
            cell(line(M.queue_page..' / '..pages,0.23)),cell(button(t('next'),'bdctrl_random_qnext',1.5)),
            cell(button(t('clear_queue'),BDC.random.editable() and #q>0 and 'bdctrl_random_clear' or nil,2.2))})
        return result
    end
    function M.definition()
        local domains,values,current=M.domains(),{},1
        for i,domain in ipairs(domains) do values[i]=t('domain_'..domain);if domain==M.domain then current=i end end
        M.domain_keys=domains
        local content={BDC.dropdown.node{title=t('random_tab'),options=values,current_option=current,opt_callback='bdctrl_random_domain',
            w=7.3,h=0.5,text_scale=0.33,scale=0.65,no_pips=true},
            line(t('random_help'),0.23,G.C.GOLD),line(t('domain_help_'..M.domain),0.21)}
        if M.confirmation then
            content[#content+1]=line(t('temporary_confirm_title'),0.34,G.C.GOLD)
            for _,key in ipairs({'temporary_warning1','temporary_warning2','temporary_warning3'}) do content[#content+1]=line(t(key),0.27) end
            content[#content+1]=line(BDC.presentation.misc('ranks',G.P_CARDS[M.confirmation.front].value)..' / '..
                BDC.presentation.misc('suits_plural',G.P_CARDS[M.confirmation.front].suit),0.32)
            content[#content+1]=columns({cell(button(t('temporary_accept'),'bdctrl_temporary_confirm',3.8)),
                cell(button(t('temporary_cancel'),'bdctrl_temporary_decline',3))})
            return content
        end
        if M.domain=='temporary' or M.domain=='pack_Standard' then
            content[#content+1]=line(t('temporary_modifiers'),0.23)
            content[#content+1]=columns({modifier('enhancement','Enhanced'),modifier('edition','Edition'),modifier('seal','Seal')})
        end
        content[#content+1]=columns({{n=G.UIT.C,config={align='cl',padding=0.07,minw=6,maxw=6,minh=0.45,
            r=0.08,colour=G.C.BLACK,button='bdctrl_search_focus',hover=true,one_press=true},nodes={
                {n=G.UIT.T,config={ref_table=BDC.search,ref_value='display',scale=0.26,colour=G.C.UI.TEXT_LIGHT}}}},
            cell(button(t('apply'),'bdctrl_apply',1.4)),cell(button(t('reset'),'bdctrl_reset',1.4))})
        local candidates=rows();local pages=math.max(1,math.ceil(#candidates/4))
        M.page=math.max(1,math.min(M.page,pages))
        local editable=M.domain=='temporary' and BDC.queue.editable() and BDC.draw.supported or BDC.random.editable()
        content[#content+1]=line(t('matches')..': '..#candidates..' | '..t('page')..' '..M.page..' / '..pages,0.23)
        local list={}
        for i=(M.page-1)*4+1,math.min(M.page*4,#candidates) do
            local row=candidates[i];local legal,reason=true,nil
            if M.domain~='temporary' then legal,reason=BDC.random.allowed(M.domain,row.key) end
            if M.domain=='pack_Standard' then legal=true end
            local status=not legal and t(reason) or row.unlocked==false and t('run_only') or t('random_select')
            local display=display_row(row,(M.domain=='temporary' or M.domain=='pack_Standard') and M.spec(row.key) or nil)
            list[#list+1]={n=G.UIT.R,config={align='cm',padding=0.025,minh=0.65,hover=true,
                on_demand_tooltip=BDC.preview.tooltip(display)},nodes={
                cell(display.preview and BDC.preview.node(display,0.6) or line('?',0.25)),
                {n=G.UIT.C,config={align='cl',minw=5.5,maxw=5.5},nodes={line(BDC.filter.clip(row.name,35),0.27),line(status,0.2,G.C.GOLD)}},
                cell(button(t('random_select'),editable and legal and 'bdctrl_random_select' or nil,1.7,{key=row.key}))}}
        end
        if #list==0 then list[1]=line(t('no_matches'),0.26) end
        content[#content+1]={n=G.UIT.R,config={align='tm',minh=2.8},nodes={{n=G.UIT.C,config={align='tm'},nodes=list}}}
        content[#content+1]=columns({cell(button(t('previous'),'bdctrl_previous',2)),cell(button(t('refresh'),'bdctrl_refresh',2)),cell(button(t('next'),'bdctrl_next',2))})
        if not editable then content[#content+1]=line(t(BDC.random.supported and 'random_unsafe' or 'unsupported'),0.23,G.C.GOLD) end
        if M.message or BDC.random.message then content[#content+1]=line(t(M.message or BDC.random.message),0.23,G.C.GOLD) end
        if M.domain=='temporary' then
            local pending=BDC.temporary.pending
            content[#content+1]=line(t(pending and 'temporary_pending' or 'random_empty')..(pending and ' ['..pending.front..']' or ''),0.24,G.C.GOLD)
            if pending then
                for _,row in ipairs(BDC.ui.catalog_snapshot.rows) do if row.key==pending.front then
                    local display=display_row(row,pending);local node=columns({cell(BDC.preview.node(display,0.6)),cell(line(row.name))})
                    node.config.hover=true;node.config.on_demand_tooltip=BDC.preview.tooltip(display);content[#content+1]=node;break
                end end
            end
            content[#content+1]=button(t('temporary_cancel'),pending and editable and 'bdctrl_temporary_clear' or nil,3)
        else
            for _,node in ipairs(queue_rows(candidates)) do content[#content+1]=node end
            content[#content+1]=button(t(BDC.random.enabled and 'random_enabled' or 'random_disabled'),
                BDC.random.editable() and 'bdctrl_random_toggle' or nil,5)
        end
        return content
    end
    local function change(action,fn) BDC.ui.change('random_'..action,fn) end
    G.FUNCS.bdctrl_random_tab=function() BDC.ui.switch_tab('random') end
    G.FUNCS.bdctrl_random_domain=function(args) change('domain',function()
        M.domain=M.domain_keys[args.to_key];M.page=1;M.queue_page=1;M.confirmation=nil;M.message=nil
    end) end
    G.FUNCS.bdctrl_random_modifier=function(args) change('modifier',function()
        local field=args.cycle_config.bdc_field;M[field]=M[field..'_keys'][args.to_key] or nil
    end) end
    G.FUNCS.bdctrl_random_select=function(e) change('select',function()
        local key=e.config.ref_table.key
        if M.domain=='temporary' then
            local spec=M.spec(key);local ok,message=BDC.temporary.select(spec,false)
            if message=='temporary_confirm' then M.confirmation=spec else M.message=message end
        elseif M.domain=='pack_Standard' then
            local ok,message=BDC.random.add(M.domain,key,M.spec(key))
            M.message=message
        else local _,message=BDC.random.add(M.domain,key);M.message=message end
    end) end
    G.FUNCS.bdctrl_temporary_confirm=function() change('confirm',function()
        local _,message=BDC.temporary.select(M.confirmation,true);M.message=message;M.confirmation=nil
    end) end
    G.FUNCS.bdctrl_temporary_decline=function() change('decline',function() M.confirmation=nil end) end
    G.FUNCS.bdctrl_temporary_clear=function() change('cancel',function() BDC.temporary.cancel() end) end
    for _,pair in ipairs({{'up',-1},{'down',1}}) do
        local name,delta=pair[1],pair[2]
        G.FUNCS['bdctrl_random_'..name]=function(e) change(name,function() BDC.random.move(M.domain,e.config.ref_table.index,delta) end) end
    end
    G.FUNCS.bdctrl_random_remove=function(e) change('remove',function() BDC.random.remove(M.domain,e.config.ref_table.index) end) end
    G.FUNCS.bdctrl_random_clear=function() change('clear',function() BDC.random.clear(M.domain) end) end
    G.FUNCS.bdctrl_random_qprev=function() change('qpage',function() M.queue_page=M.queue_page-1 end) end
    G.FUNCS.bdctrl_random_qnext=function() change('qpage',function() M.queue_page=M.queue_page+1 end) end
    G.FUNCS.bdctrl_random_toggle=function() change('toggle',function() BDC.random.enabled=not BDC.random.enabled end) end
    return M
end
