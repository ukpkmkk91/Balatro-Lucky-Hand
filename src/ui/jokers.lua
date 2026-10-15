return function(BDC)
    local M={page=1,query='',selection={},message=nil}
    local function t(key) return BDC.inspector.t(key) end
    local function line(text,scale,colour)
        return {n=G.UIT.R,config={align='cm',padding=0.03},nodes={{n=G.UIT.T,config={text=text,scale=scale or 0.27,colour=colour or G.C.UI.TEXT_LIGHT}}}}
    end
    function M.reset() M.selection={};M.message=nil end
    function M.definition()
        local contents={line(t('joker_help'),0.24,G.C.GOLD),line(t('joker_save_hint'),0.22)}
        local rows={};local seen={}
        for _,row in ipairs(BDC.joker_editions.capture()) do
            seen[row.session_id]=true;local match=true
            for word in M.query:lower():gmatch('%S+') do
                if not (row.name..' '..row.key..' '..row.edition):lower():find(word,1,true) then match=false end
            end
            if match then rows[#rows+1]=row end
        end
        for id in pairs(M.selection) do if not seen[id] then M.selection[id]=nil end end
        local editions=BDC.joker_editions.editions();M.edition_keys={}
        local options={};for i,entry in ipairs(editions) do options[i]=entry.name;M.edition_keys[i]=entry.key end
        local pages=math.max(1,math.ceil(#rows/5));M.page=math.max(1,math.min(M.page,pages))
        contents[#contents+1]={n=G.UIT.R,config={align='cm',padding=0.05},nodes={
            {n=G.UIT.C,config={align='cl',padding=0.07,minw=6,maxw=6,minh=0.5,r=0.08,colour=G.C.BLACK,
                button='bdctrl_search_focus',hover=true,one_press=true},nodes={{n=G.UIT.T,
                config={ref_table=BDC.search,ref_value='display',scale=0.26,colour=G.C.UI.TEXT_LIGHT}}}},
            {n=G.UIT.C,config={align='cm'},nodes={UIBox_button{label={t('apply')},button='bdctrl_apply',minw=1.5}}},
            {n=G.UIT.C,config={align='cm'},nodes={UIBox_button{label={t('reset')},button='bdctrl_reset',minw=1.5}}}}}
        for i=(M.page-1)*5+1,math.min(M.page*5,#rows) do
            local row=rows[i];local selected=M.selection[row.session_id]
            local key=selected and selected.key or row.edition_key
            if selected and selected.key==false then key=nil end
            local current=1;for j,entry in ipairs(editions) do if entry.key==key then current=j end end
            local allowed=BDC.joker_editions.allowed(row.session_id,key)
            contents[#contents+1]={n=G.UIT.R,config={align='cm',padding=0.04,minh=0.75,hover=true,
                on_demand_tooltip=BDC.preview.tooltip(row)},nodes={
                {n=G.UIT.C,config={align='cm',minw=0.7},nodes={BDC.preview.node(row,0.65)}},
                {n=G.UIT.C,config={align='cl',minw=3.2,maxw=3.2},nodes={line(BDC.filter.clip(row.name,22)),line(row.edition,0.22,G.C.GOLD)}},
                {n=G.UIT.C,config={align='cm'},nodes={BDC.dropdown.node{title=row.name..' · '..t('edition'),options=options,
                    current_option=current,opt_callback='bdctrl_joker_edition',session_id=row.session_id,w=3.1}}},
                {n=G.UIT.C,config={align='cm'},nodes={UIBox_button{label={t('joker_apply')},button=allowed and 'bdctrl_joker_apply' or 'nil',
                    ref_table={session_id=row.session_id,key=key},minw=1.6,minh=0.5,scale=0.26,
                    colour=allowed and G.C.BLUE or G.C.UI.BACKGROUND_INACTIVE,one_press=true}}}}}
        end
        if #rows==0 then contents[#contents+1]=line(t(BDC.compatibility.active_run() and 'joker_empty' or 'no_run'),0.32) end
        contents[#contents+1]=line(t('card_count')..': '..#rows..' | '..t('page')..' '..M.page..' / '..pages,0.24)
        contents[#contents+1]={n=G.UIT.R,config={align='cm'},nodes={
            {n=G.UIT.C,config={align='cm'},nodes={UIBox_button{label={t('previous')},button='bdctrl_previous',minw=2}}},
            {n=G.UIT.C,config={align='cm'},nodes={UIBox_button{label={t('refresh')},button='bdctrl_refresh',minw=2}}},
            {n=G.UIT.C,config={align='cm'},nodes={UIBox_button{label={t('next')},button='bdctrl_next',minw=2}}}}}
        if M.message then contents[#contents+1]=line(t(M.message),0.24,G.C.GOLD) end
        return contents
    end
    G.FUNCS.bdctrl_jokers=function() BDC.ui.switch_tab('jokers') end
    G.FUNCS.bdctrl_joker_edition=function(args) BDC.ui.change('joker_select_edition',function()
        M.selection[args.cycle_config.session_id]={key=M.edition_keys[args.to_key] or false}
    end) end
    G.FUNCS.bdctrl_joker_apply=function(e) BDC.ui.change('joker_edition_apply',function()
        local _,message=BDC.joker_editions.apply(e.config.ref_table.session_id,e.config.ref_table.key)
        M.message=message
    end) end
    return M
end
