-- Click to expand a bounded choice list; callbacks retain the native cycle argument shape.
-- Owned by the same BDC overlay, so pause/cursor layers and F8 cleanup remain unchanged.
return function(BDC)
    local M={active=nil,page=1}
    local function t(key) return BDC.inspector.t(key) end
    local function line(text,scale)
        return {n=G.UIT.R,config={align='cm',padding=0.06},nodes={{n=G.UIT.T,
            config={text=tostring(text),scale=scale or 0.28,colour=G.C.UI.TEXT_LIGHT}}}}
    end
    function M.dismiss() M.active=nil;M.page=1 end
    function M.node(args)
        local value=(args.options or {})[args.current_option or 1] or t('none')
        return UIBox_button{label={BDC.filter.clip(value,32)..'  [v]'},button='bdctrl_dropdown_open',
            ref_table=args,minw=args.w or 3.2,minh=args.h or 0.5,scale=args.text_scale or 0.28,
            colour=G.C.BLUE,one_press=true}
    end
    function M.definition()
        local a=M.active;local nodes={line(a.title or t('choose_type'),0.4),line(t('dropdown_help'),0.25)}
        local count=#a.options;local pages=math.max(1,math.ceil(count/16))
        M.page=math.max(1,math.min(M.page,pages))
        local first=(M.page-1)*16+1
        for i=first,math.min(first+15,count),2 do
            local cells={}
            for j=i,math.min(i+1,count) do
                cells[#cells+1]={n=G.UIT.C,config={align='cm',padding=0.05},nodes={UIBox_button{
                    label={BDC.filter.clip(a.options[j],34)},button='bdctrl_dropdown_pick',ref_table={index=j},
                    minw=4.4,minh=0.5,scale=0.28,colour=j==a.current_option and G.C.GOLD or G.C.BLUE,one_press=true}}}
            end
            nodes[#nodes+1]={n=G.UIT.R,config={align='cm',padding=0.015},nodes=cells}
        end
        if pages>1 then
            nodes[#nodes+1]=line(t('page')..' '..M.page..' / '..pages,0.24)
            nodes[#nodes+1]={n=G.UIT.R,config={align='cm',padding=0.05},nodes={
                {n=G.UIT.C,config={align='cm'},nodes={UIBox_button{label={t('previous')},button='bdctrl_dropdown_prev',minw=2.5}}},
                {n=G.UIT.C,config={align='cm'},nodes={UIBox_button{label={t('next')},button='bdctrl_dropdown_next',minw=2.5}}}}}
        end
        return create_UIBox_generic_options{contents=nodes,back_func='bdctrl_dropdown_cancel',back_label=t('cancel_choice')}
    end
    G.FUNCS.bdctrl_dropdown_open=function(e)
        BDC.ui.change('dropdown_open',function()
            M.active=e.config.ref_table;M.page=math.floor(((M.active.current_option or 1)-1)/16)+1
        end)
    end
    G.FUNCS.bdctrl_dropdown_cancel=function() BDC.ui.change('dropdown_cancel',M.dismiss) end
    G.FUNCS.bdctrl_dropdown_pick=function(e)
        local a=M.active;local index=e.config.ref_table.index
        if not a or not a.options[index] or type(G.FUNCS[a.opt_callback])~='function' then return end
        M.dismiss()
        G.FUNCS[a.opt_callback]({to_key=index,cycle_config=a})
    end
    G.FUNCS.bdctrl_dropdown_prev=function() BDC.ui.change('dropdown_page',function() M.page=M.page-1 end) end
    G.FUNCS.bdctrl_dropdown_next=function() BDC.ui.change('dropdown_page',function() M.page=M.page+1 end) end
    return M
end
