return function(BDC)
    local M = {page=1,queue_page=1,tab='cards',query='',filters={},catalog_page=1,catalog_category='Joker',catalog_query='',drafts={}}
    local function t(key) return BDC.inspector.t(key) end
    local function clip(value, limit)
        local chars={}
        for c in tostring(value or t('na')):gmatch('[%z\1-\127\194-\244][\128-\191]*') do
            if #chars == limit then return table.concat(chars)..'…' end
            chars[#chars+1]=c
        end
        return table.concat(chars)
    end
    local function label(value, scale, colour)
        return {n=G.UIT.T,config={text=tostring(value),scale=scale or 0.3,colour=colour or G.C.UI.TEXT_LIGHT}}
    end
    local function line(value, scale, colour)
        return {n=G.UIT.R,config={align='cm',padding=0.035},nodes={label(value,scale,colour)}}
    end
    local function button(value, callback, width)
        return UIBox_button{label={value},button=callback,minw=width or 2.1,minh=0.55,scale=0.3,
            colour=callback~='nil' and G.C.BLUE or G.C.UI.BACKGROUND_INACTIVE,one_press=true}
    end
    local function draw_status()
        if not BDC.draw.supported then return t('unsupported')..' · '..t('draw_disabled') end
        return t(BDC.draw.enabled and 'override_on' or 'override_off')
    end
    local function override_button()
        return button(t(BDC.draw.enabled and 'disable_override' or 'enable_override'),
            M.editable and BDC.draw.supported and 'bdctrl_override' or 'nil',4.2)
    end
    local columns={{'session_id','id',1.05,9},{'suit','suit',1.15,12},{'rank','rank',0.8,9},
        {'enhancement','enhancement',1.5,15},{'edition','edition',1.3,13},{'seal','seal',1.3,13},{'area_name','area',1.15,12}}
    local function small_button(text,callback,id,width)
        return UIBox_button{label={text},button=callback or 'nil',ref_table={session_id=id},
            minw=width or 1.2,minh=0.36,scale=0.23,colour=callback and G.C.BLUE or G.C.UI.BACKGROUND_INACTIVE,one_press=true}
    end
    local function card_row(card, header)
        local cells={}
        if BDC.preview then cells[#cells+1]={n=G.UIT.C,config={align='cm',minw=0.55,maxw=0.55},
            nodes={header and label(t('preview'),0.24,G.C.GOLD) or BDC.preview.node(card,0.55)}} end
        for _,col in ipairs(columns) do
            cells[#cells+1]={n=G.UIT.C,config={align='cl',minw=col[3],maxw=col[3],padding=0.02},
                nodes={label(header and t(col[2]) or card.temporary and col[1]=='session_id' and t('temporary_abbrev') or clip(card[col[1]],col[4]),header and 0.26 or 0.28,
                    header and G.C.GOLD or G.C.UI.TEXT_LIGHT)}}
        end
        local selected=not header and BDC.queue.contains(card.session_id)
        local can_add=not header and M.editable and M.candidates[card.session_id] and not selected
        cells[#cells+1]={n=G.UIT.C,config={align='cm',minw=1.2},nodes={header and label(t('select'),0.25,G.C.GOLD)
            or small_button(t(selected and 'selected' or 'add'),can_add and 'bdctrl_queue_add' or nil,card.session_id)}}
        local tooltip
        if not header then
            local details={card.localized_name or t('unknown'), t('enhancement')..': '..card.enhancement,
                t('edition')..': '..card.edition,t('seal')..': '..card.seal,t('area')..': '..card.area_name}
            if card.attributes and card.attributes ~= '' then details[#details+1]=card.attributes end
            tooltip={title=t('id')..' '..card.session_id,text=card.details or details}
        end
        return {n=G.UIT.R,config={align='cm',minh=BDC.preview and 0.58 or 0.38,padding=0.025,colour=header and G.C.BLACK or G.C.CLEAR,
            tooltip=not BDC.preview and tooltip or nil,on_demand_tooltip=not header and BDC.preview and BDC.preview.tooltip(card,t('id')..' '..card.session_id) or nil,hover=not header},nodes=cells}
    end
    local function rebuild_results()
        M.candidates=BDC.queue.validate();M.editable=BDC.queue.editable()
        M.queue_ids=BDC.queue.ids();M.queue_revision=BDC.queue.revision;M.session=BDC.identity.session()
        M.override_enabled=BDC.draw.enabled;M.override_supported=BDC.draw.supported
        M.random_revision=BDC.random and BDC.random.revision
        M.temporary_revision=BDC.temporary and BDC.temporary.revision
        M.options=BDC.filter.options(M.snapshot.cards)
        for field,value in pairs(M.filters) do
            local found=false
            for _,option in ipairs(M.options[field] or {}) do if option==value then found=true;break end end
            if not found then M.filters[field]=nil end
        end
        M.results=BDC.filter.apply(M.snapshot.cards,M.query,M.filters)
        if BDC.catalog and M.catalog_snapshot then
            M.catalog_results=BDC.catalog.filter(M.catalog_snapshot,M.catalog_category,M.catalog_query)
        end
    end
    local function filter_control(field)
        local values,selected={t('all')},1
        for i,value in ipairs(M.options[field]) do
            values[#values+1]=clip(value,18)
            if M.filters[field]==value then selected=i+1 end
        end
        return {n=G.UIT.C,config={align='cm',minw=3.3},nodes={
            line(t(field=='area_name' and 'area' or field),0.24,G.C.GOLD),
            BDC.dropdown.node{title=t(field=='area_name' and 'area' or field),options=values,current_option=selected,opt_callback='bdctrl_filter',
                filter_key=field,w=3.1,h=0.55,scale=0.7,text_scale=0.38,no_pips=true}}}
    end
    local function queue_row(id,index,total,by_id)
        local card=by_id[id] or {rank=t('unknown'),suit=t('unknown'),enhancement=t('unknown'),edition=t('unknown'),seal=t('unknown')}
        return {n=G.UIT.R,config={align='cm',padding=0.04,minh=0.65,hover=true,
            on_demand_tooltip=BDC.preview and BDC.preview.tooltip(card,t('id')..' '..id) or nil,
            tooltip=not BDC.preview and {title=t('id')..' '..id,text={card.rank..' / '..card.suit,card.enhancement,card.edition,card.seal,card.attributes or ''}} or nil},nodes={
            BDC.preview and {n=G.UIT.C,config={align='cm',minw=0.55},nodes={BDC.preview.node(card)}} or {n=G.UIT.C,config={align='cm'},nodes={}},
            {n=G.UIT.C,config={align='cl',minw=6.5,maxw=6.5},nodes={
                line(index..'. '..clip(card.rank..' / '..card.suit,28)..'   # '..id,0.29),
                line(clip(card.enhancement..' / '..card.edition..' / '..card.seal,46),0.23)}},
            {n=G.UIT.C,config={align='cm'},nodes={small_button(t('up'),M.editable and index>1 and 'bdctrl_queue_up' or nil,id,0.7)}},
            {n=G.UIT.C,config={align='cm'},nodes={small_button(t('down'),M.editable and index<total and 'bdctrl_queue_down' or nil,id,0.7)}},
            {n=G.UIT.C,config={align='cm'},nodes={small_button(t('remove'),M.editable and 'bdctrl_queue_remove' or nil,id,1.4)}}}}
    end
    function M.definition()
        if BDC.dropdown.active then return BDC.dropdown.definition() end
        local snap=M.snapshot
        local pages=math.max(1,math.ceil(#M.results/BDC.config.page_size))
        M.page=math.max(1,math.min(M.page,pages))
        local contents={line(t('title'),0.43,G.C.GOLD),line(draw_status(),0.25),
            {n=G.UIT.R,config={align='cm',padding=0.05},nodes={
                {n=G.UIT.C,config={align='cm'},nodes={button(t('cards_tab'),'bdctrl_cards',2.05)}},
                {n=G.UIT.C,config={align='cm'},nodes={button(t('queue_tab')..' ('..#M.queue_ids..')','bdctrl_queue_tab',2.05)}},
                {n=G.UIT.C,config={align='cm'},nodes={button(t('random_tab'),'bdctrl_random_tab',2.05)}},
                {n=G.UIT.C,config={align='cm'},nodes={button(t('catalog_tab'),'bdctrl_catalog',2.05)}},
                {n=G.UIT.C,config={align='cm'},nodes={button(t('settings_tab'),'bdctrl_settings',1.9)}},
                {n=G.UIT.C,config={align='cm'},nodes={button(t('jokers_tab'),'bdctrl_jokers',1.9)}}}}}
        if M.tab=='queue' then
            local total=#M.queue_ids
            local queue_pages=math.max(1,math.ceil(total/6))
            M.queue_page=math.max(1,math.min(M.queue_page,queue_pages))
            contents[#contents+1]=line(t('queue_mode'),0.3,G.C.GOLD)
            contents[#contents+1]=override_button()
            contents[#contents+1]=line(t(M.editable and 'queue_help' or 'queue_unsafe'),0.26)
            contents[#contents+1]=line(t('card_count')..': '..total..'   |   '..t('page')..' '..M.queue_page..' / '..queue_pages,0.28)
            local rows,by_id={},{}
            for _,card in ipairs(snap.cards) do by_id[card.session_id]=card end
            for i=(M.queue_page-1)*6+1,math.min(M.queue_page*6,total) do rows[#rows+1]=queue_row(M.queue_ids[i],i,total,by_id) end
            if total==0 then rows[#rows+1]=line(t('queue_empty'),0.3) end
            contents[#contents+1]={n=G.UIT.R,config={align='tm',minh=4.2},nodes={{n=G.UIT.C,config={align='tm'},nodes=rows}}}
            contents[#contents+1]={n=G.UIT.R,config={align='cm',padding=0.06},nodes={
                {n=G.UIT.C,config={align='cm'},nodes={button(t('previous'),'bdctrl_previous',2)}},
                {n=G.UIT.C,config={align='cm'},nodes={button(t('refresh'),'bdctrl_refresh',2)}},
                {n=G.UIT.C,config={align='cm'},nodes={button(t('clear_queue'),M.editable and total>0 and 'bdctrl_queue_clear' or 'nil',2)}},
                {n=G.UIT.C,config={align='cm'},nodes={button(t('next'),'bdctrl_next',2)}}}}
        elseif M.tab=='random' and BDC.random_ui then
            for _,node in ipairs(BDC.random_ui.definition()) do contents[#contents+1]=node end
        elseif M.tab=='catalog' and BDC.catalog then
            local total=#M.catalog_results;local catalog_pages=math.max(1,math.ceil(total/6))
            M.catalog_page=math.max(1,math.min(M.catalog_page,catalog_pages))
            contents[#contents+1]=line(t('catalog_help'),0.25,G.C.GOLD)
            local values,current={},1
            for i,category in ipairs(BDC.catalog.categories) do
                values[i]=t('category_'..category);if M.catalog_category==category then current=i end
            end
            contents[#contents+1]=BDC.dropdown.node{title=t('catalog_tab'),options=values,current_option=current,opt_callback='bdctrl_category',
                w=5.5,h=0.55,scale=0.7,text_scale=0.38,no_pips=true}
            contents[#contents+1]={n=G.UIT.R,config={align='cm',padding=0.05},nodes={
                {n=G.UIT.C,config={align='cl',padding=0.08,minw=6.5,maxw=6.5,minh=0.5,r=0.08,
                    colour=G.C.BLACK,button='bdctrl_search_focus',hover=true,one_press=true},nodes={
                        {n=G.UIT.T,config={ref_table=BDC.search,ref_value='display',scale=0.28,colour=G.C.UI.TEXT_LIGHT}}}},
                {n=G.UIT.C,config={align='cm'},nodes={button(t('apply'),'bdctrl_apply',1.5)}},
                {n=G.UIT.C,config={align='cm'},nodes={button(t('reset'),'bdctrl_reset',1.5)}}}}
            contents[#contents+1]=line(t('matches')..': '..total..' / '..(M.catalog_snapshot.counts[M.catalog_category] or 0)
                ..'   |   '..t('page')..' '..M.catalog_page..' / '..catalog_pages,0.27)
            local rows={}
            for i=(M.catalog_page-1)*6+1,math.min(M.catalog_page*6,total) do
                local row=M.catalog_results[i];local status=t(row.unlocked and 'unlocked' or 'locked')
                rows[#rows+1]={n=G.UIT.R,config={align='cm',padding=0.035,minh=0.72,hover=true,
                    on_demand_tooltip=BDC.preview.tooltip(row)},nodes={
                    {n=G.UIT.C,config={align='cm',minw=0.8},nodes={BDC.preview.node(row,0.68)}},
                    {n=G.UIT.C,config={align='cl',minw=3.0,maxw=3.0},nodes={line(clip(row.name,23),0.28),line(status,0.2,G.C.GOLD)}},
                    {n=G.UIT.C,config={align='cl',minw=6.0,maxw=6.0},nodes={line(clip(row.details[1],42),0.24),line(clip(row.details[2] or row.key,42),0.2)}}}}
            end
            if total==0 then rows[1]=line(t('no_matches'),0.3) end
            contents[#contents+1]={n=G.UIT.R,config={align='tm',minh=4.6},nodes={{n=G.UIT.C,config={align='tm'},nodes=rows}}}
            contents[#contents+1]={n=G.UIT.R,config={align='cm',padding=0.06},nodes={
                {n=G.UIT.C,config={align='cm'},nodes={button(t('previous'),'bdctrl_previous')}},
                {n=G.UIT.C,config={align='cm'},nodes={button(t('refresh'),'bdctrl_refresh')}},
                {n=G.UIT.C,config={align='cm'},nodes={button(t('next'),'bdctrl_next')}}}}
        elseif M.tab=='jokers' and BDC.joker_ui then
            for _,node in ipairs(BDC.joker_ui.definition()) do contents[#contents+1]=node end
        elseif M.tab=='settings' then
            contents[#contents+1]=line(t('hotkey')..': '..string.upper(BDC.config.toggle_key),0.35)
            if BDC.hotkey then
                local values,current={},1
                for i,key in ipairs(BDC.hotkey.keys) do
                    local available=BDC.hotkey.available(key)
                    values[i]=key:upper()..(available and '' or ' '..t('hotkey_conflict'))
                    if key==BDC.config.toggle_key then current=i end
                end
                contents[#contents+1]=BDC.dropdown.node{title=t('hotkey'),options=values,current_option=current,opt_callback='bdctrl_hotkey',
                    w=5.5,h=0.55,scale=0.7,text_scale=0.38,no_pips=true}
                if BDC.hotkey.message then contents[#contents+1]=line(t(BDC.hotkey.message),0.25,G.C.GOLD) end
            end
            contents[#contents+1]=line(t('settings_hint'),0.27)
            contents[#contents+1]=line(t('ui_memory_hint'),0.24)
            contents[#contents+1]=line(t('hotkey_help'),0.23)
            contents[#contents+1]=line(t('preview_help'),0.25)
            contents[#contents+1]=line(t('input_hint'),0.25)
            contents[#contents+1]=line('Balatro Draw Controller '..BDC.version,0.28)
            contents[#contents+1]=line(t('queue_mode'),0.28,G.C.GOLD)
            contents[#contents+1]=line(draw_status(),0.26)
            contents[#contents+1]=override_button()
            contents[#contents+1]=line(t('override_help'),0.24)
        else
        contents[#contents+1]={n=G.UIT.R,config={align='cm',padding=0.05},nodes={
            {n=G.UIT.C,config={align='cl',padding=0.08,minw=6.5,maxw=6.5,minh=0.5,r=0.08,
                colour=G.C.BLACK,button='bdctrl_search_focus',hover=true,one_press=true},nodes={
                    {n=G.UIT.T,config={ref_table=BDC.search,ref_value='display',scale=0.28,colour=G.C.UI.TEXT_LIGHT}}}},
            {n=G.UIT.C,config={align='cm'},nodes={button(t('apply'),'bdctrl_apply',1.5)}},
            {n=G.UIT.C,config={align='cm'},nodes={button(t('reset'),'bdctrl_reset',1.5)}}}}
        for group=0,1 do
            local controls={}
            for i=1,3 do controls[#controls+1]=filter_control(BDC.filter.fields[group*3+i]) end
            contents[#contents+1]={n=G.UIT.R,config={align='cm',padding=0.02},nodes=controls}
        end
        contents[#contents+1]=line(t('matches')..': '..#M.results..' / '..#snap.cards..'   |   '..t('page')..' '..M.page..' / '..pages,0.28)
        if not snap.active then contents[#contents+1]=line(t('no_run'),0.4)
        else
            local counts={}
            for _,k in ipairs({'deck','hand','discard','play'}) do counts[#counts+1]=t('area_'..k)..': '..snap.counts[k] end
            contents[#contents+1]=line(table.concat(counts,'   '),0.26)
            contents[#contents+1]=card_row({},true)
            local rows={}
            for i=(M.page-1)*BDC.config.page_size+1,math.min(M.page*BDC.config.page_size,#M.results) do
                rows[#rows+1]=card_row(M.results[i])
            end
            if #M.results == 0 then rows[#rows+1]=line(t(#snap.cards==0 and 'empty' or 'no_matches'),0.3) end
            contents[#contents+1]={n=G.UIT.R,config={align='tm',minh=BDC.config.page_size*(BDC.preview and 0.63 or 0.43)},nodes={
                {n=G.UIT.C,config={align='tm'},nodes=rows}}}
        end
        contents[#contents+1]={n=G.UIT.R,config={align='cm',padding=0.1},nodes={
            {n=G.UIT.C,config={align='cm'},nodes={button(t('previous'),'bdctrl_previous')}},
            {n=G.UIT.C,config={align='cm'},nodes={button(t('refresh'),'bdctrl_refresh')}},
            {n=G.UIT.C,config={align='cm'},nodes={button(t('next'),'bdctrl_next')}}}}
        contents[#contents+1]=line(t(M.editable and 'queue_help' or 'queue_unsafe'),0.23)
        end
        return create_UIBox_generic_options{contents=contents,minw=11.2,padding=0.05,
            back_func='bdctrl_close',back_label=t('close'),no_pip=true}
    end
    local function render()
        BDC.search.blur()
        local old=M.box
        local ok,box=pcall(function() return UIBox{definition=M.definition(),config={align='cm',offset={x=0,y=0},major=G.ROOM_ATTACH,bond='Weak',no_esc=true}} end)
        if not ok then if BDC.preview then BDC.preview.cleanup() end;error(box) end
        local old_previews=M.previews
        M.previews=BDC.preview and BDC.preview.commit()
        G.OVERLAY_MENU=box;M.box=box
        G.CONTROLLER.cursor_down.target=nil
        G.CONTROLLER.locks.frame=true;G.CONTROLLER.locks.frame_set=true
        if old then old:remove() end
        if BDC.preview then BDC.preview.cleanup(old_previews or {}) end
    end
    function M.close()
        if M.box then M.drafts[M.tab]=BDC.search.text end
        if BDC.dropdown then BDC.dropdown.dismiss() end
        if BDC.random_ui then BDC.random_ui.confirmation=nil end
        pcall(BDC.search.blur)
        if not M.box then
            if M.opening then
                G.OVERLAY_MENU=M.parent;G.SETTINGS.paused=M.previous_pause
                if M.layer_added then pcall(function() G.CONTROLLER:mod_cursor_context_layer(-1) end) end
                M.opening,M.layer_added,M.parent,M.snapshot,M.before=nil,nil,nil,nil,nil
            end
            return
        end
        local before=M.before
        local owns=G.OVERLAY_MENU == M.box
        if owns then G.OVERLAY_MENU=M.parent end
        pcall(function() M.box:remove() end)
        if BDC.preview then BDC.preview.cleanup(M.previews or {});BDC.preview.cleanup();M.previews=nil end
        if owns then
            pcall(function() G.CONTROLLER:mod_cursor_context_layer(-1) end)
            G.CONTROLLER.locks.frame_set=true;G.CONTROLLER.locks.frame=true
            G.SETTINGS.paused=M.previous_pause
        end
        M.box,M.parent,M.snapshot,M.before,M.results,M.options=nil,nil,nil,nil,nil,nil
        M.opening,M.layer_added,M.catalog_snapshot,M.catalog_results=nil,nil,nil,nil
        BDC.audit.check(before,'close')
        -- Do not call exit_overlay_menu: it saves settings and would close the parent menu.
    end
    local function guarded(f)
        if BDC.disabled then return end
        local ok,err=pcall(f)
        if not ok then
            if BDC.safety then BDC.safety.fail('UI failure: '..tostring(err)) end
            if M.box then pcall(M.close)
            elseif M.opening then
                G.OVERLAY_MENU=M.parent;G.SETTINGS.paused=M.previous_pause
                if M.layer_added then pcall(function() G.CONTROLLER:mod_cursor_context_layer(-1) end) end
                M.snapshot,M.before,M.parent=nil,nil,nil
            end
            M.opening,M.layer_added=nil,nil;BDC.disabled=true
        end
    end
    function M.open(from_menu)
        guarded(function()
            local ok,reason=BDC.compatibility.check()
            if not ok then BDC.safety.fail(reason);return end
            if G.CONTROLLER.text_input_hook then BDC.log.info('open skipped: text input active');return end
            if G.OVERLAY_MENU and not from_menu then BDC.log.info('open skipped: another overlay active');return end
            M.parent=G.OVERLAY_MENU;M.previous_pause=G.SETTINGS.paused;M.opening=true
            M.before=BDC.audit.capture();M.snapshot=BDC.inspector.capture()
            if BDC.catalog then M.catalog_snapshot=BDC.catalog.capture() end
            BDC.dropdown.dismiss();M.restore_search();rebuild_results()
            -- Use the game's native menu pause convention; never stop the EventManager.
            G.SETTINGS.paused=true
            G.CONTROLLER:mod_cursor_context_layer(1);M.layer_added=true
            render();M.opening=false;M.layer_added=false
            BDC.log.info('snapshot card count='..#M.snapshot.cards)
            BDC.audit.check(M.before,'open')
        end)
    end
    function M.toggle()
        if M.box then guarded(M.close) else M.open(false) end
    end
    local function accept_click()
        local now=love.timer.getTime()
        if M.last_click and now-M.last_click < 0.25 then return false end
        M.last_click=now;return true
    end
    function M.refresh()
        if not accept_click() then return end
        guarded(function()
            if not M.box then return end
            local before=BDC.audit.capture()
            M.snapshot=BDC.inspector.capture()
            if BDC.catalog then M.catalog_snapshot=BDC.catalog.capture() end
            rebuild_results();render()
            BDC.log.info('snapshot refreshed; card count='..#M.snapshot.cards)
            BDC.audit.check(before,'refresh')
        end)
    end
    function M.page_by(delta)
        if not accept_click() then return end
        guarded(function()
            if not M.box then return end
            local before=BDC.audit.capture()
            if BDC.dropdown.active then BDC.dropdown.page=BDC.dropdown.page+delta
            elseif M.tab=='jokers' then BDC.joker_ui.page=BDC.joker_ui.page+delta
            elseif M.tab=='queue' then M.queue_page=M.queue_page+delta
            elseif M.tab=='catalog' then M.catalog_page=M.catalog_page+delta
            elseif M.tab=='random' then BDC.random_ui.page=BDC.random_ui.page+delta else M.page=M.page+delta end
            render();BDC.audit.check(before,'page')
        end)
    end
    local function change(action,fn)
        guarded(function()
            if not M.box or G.OVERLAY_MENU~=M.box then return end
            local before=BDC.audit.capture()
            fn();rebuild_results();render()
            BDC.log.info(action..'; matches='..#M.results..'/'..#M.snapshot.cards)
            BDC.audit.check(before,action)
        end)
    end
    M.change=change
    function M.restore_search()
        local value=M.tab=='catalog' and M.catalog_query or M.tab=='random' and BDC.random_ui.query
            or M.tab=='jokers' and BDC.joker_ui.query or M.query
        BDC.search.set(M.drafts[M.tab] or value or '')
    end
    function M.switch_tab(tab)
        change('tab',function() M.drafts[M.tab]=BDC.search.text;M.tab=tab;M.restore_search();M.snapshot=BDC.inspector.capture() end)
    end
    function M.apply_search()
        change('search',function()
            M.drafts[M.tab]=BDC.search.text
            if M.tab=='jokers' then BDC.joker_ui.query=BDC.search.text;BDC.joker_ui.page=1
            elseif M.tab=='random' then BDC.random_ui.query=BDC.search.text;BDC.random_ui.page=1
            elseif M.tab=='catalog' then M.catalog_query=BDC.search.text;M.catalog_page=1
            else M.query=BDC.search.text;M.page=1 end
        end)
    end
    function M.reset()
        change('reset',function()
            M.drafts[M.tab]=''
            if M.tab=='jokers' then BDC.joker_ui.query='';BDC.joker_ui.page=1
            elseif M.tab=='random' then BDC.random_ui.query='';BDC.random_ui.page=1
            elseif M.tab=='catalog' then M.catalog_query='';M.catalog_page=1
            else M.query='';M.filters={};M.page=1 end
            BDC.search.set('')
        end)
    end
    function M.queue_edit(action,id,delta)
        change('queue_'..action,function()
            M.snapshot=BDC.inspector.capture()
            local ok,reason
            if action=='add' then ok,reason=BDC.queue.add(id)
            elseif action=='remove' then ok,reason=BDC.queue.remove(id)
            elseif action=='move' then ok,reason=BDC.queue.move(id,delta)
            elseif action=='clear' then ok,reason=BDC.queue.clear_by_user() end
            if not ok and reason then BDC.log.info('queue edit rejected: '..reason) end
        end)
    end
    function M.queue_updated()
        if not M.box or G.OVERLAY_MENU~=M.box then return end
        if M.queue_revision==BDC.queue.revision and M.editable==BDC.queue.editable()
            and M.session==BDC.identity.session() and M.override_enabled==BDC.draw.enabled
            and M.override_supported==BDC.draw.supported
            and M.random_revision==(BDC.random and BDC.random.revision)
            and M.temporary_revision==(BDC.temporary and BDC.temporary.revision) then return end
        change('queue_validate',function() M.snapshot=BDC.inspector.capture() end)
    end
    function M.config_tab()
        return {n=G.UIT.ROOT,config={align='cm',padding=0.1,colour=G.C.CLEAR},nodes={
            line(t('read_only'),0.3),button(t('open'),'bdctrl_open',5),
            line(t('hotkey')..': '..string.upper(BDC.config.toggle_key),0.3)}}
    end
    G.FUNCS.bdctrl_open=function() M.open(true) end
    G.FUNCS.bdctrl_close=function() guarded(M.close) end
    G.FUNCS.bdctrl_refresh=function() M.refresh() end
    G.FUNCS.bdctrl_previous=function() M.page_by(-1) end
    G.FUNCS.bdctrl_next=function() M.page_by(1) end
    G.FUNCS.bdctrl_search_focus=function() guarded(BDC.search.focus) end
    G.FUNCS.bdctrl_apply=function() M.apply_search() end
    G.FUNCS.bdctrl_reset=function() M.reset() end
    G.FUNCS.bdctrl_filter=function(args)
        change('filter',function()
            local field=args.cycle_config.filter_key
            M.filters[field]=M.options[field][args.to_key-1];M.page=1
        end)
    end
    G.FUNCS.bdctrl_cards=function() M.switch_tab('cards') end
    G.FUNCS.bdctrl_catalog=function() M.switch_tab('catalog') end
    G.FUNCS.bdctrl_category=function(args)
        change('catalog_category',function() M.catalog_category=BDC.catalog.categories[args.to_key];M.catalog_page=1 end)
    end
    G.FUNCS.bdctrl_hotkey=function(args)
        change('hotkey',function() BDC.hotkey.set(BDC.hotkey.keys[args.to_key]) end)
    end
    G.FUNCS.bdctrl_settings=function() M.switch_tab('settings') end
    G.FUNCS.bdctrl_queue_tab=function() M.switch_tab('queue') end
    G.FUNCS.bdctrl_queue_add=function(e) M.queue_edit('add',e.config.ref_table.session_id) end
    G.FUNCS.bdctrl_queue_remove=function(e) M.queue_edit('remove',e.config.ref_table.session_id) end
    G.FUNCS.bdctrl_queue_up=function(e) M.queue_edit('move',e.config.ref_table.session_id,-1) end
    G.FUNCS.bdctrl_queue_down=function(e) M.queue_edit('move',e.config.ref_table.session_id,1) end
    G.FUNCS.bdctrl_queue_clear=function() M.queue_edit('clear') end
    G.FUNCS.bdctrl_override=function()
        change('override',function() BDC.draw.set_enabled(not BDC.draw.enabled) end)
    end
    return M
end
