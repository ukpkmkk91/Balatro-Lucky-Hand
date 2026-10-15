-- Execute released preview code with recording Sprites; no Card/game/save mutation.
local passed=0
local function test(name,fn) fn();passed=passed+1;print('PASS stone '..name) end
G={P_CENTERS={
    c_base={key='c_base',set='Default',atlas='centers',pos={x=0,y=0}},
    m_stone={key='m_stone',set='Enhanced',effect='Stone Card',atlas='centers',pos={x=5,y=0},config={bonus=50}},
    m_glass={key='m_glass',set='Enhanced',effect='Glass Card',atlas='centers',pos={x=6,y=0},config={}},
    m_replacement={key='m_replacement',set='Enhanced',replace_base_card=true,atlas='centers',pos={x=7,y=0},config={}},
    e_foil={key='e_foil',set='Edition',config={chips=50}},
    e_holo={key='e_holo',set='Edition',config={mult=10}}},
    P_CARDS={H_A={key='H_A',suit='Hearts',value='Ace',atlas='cards_1',pos={x=12,y=0}}},
    P_SEALS={Gold={key='Gold',name='Gold',set='Seal'}},
    shared_seals={Gold={atlas={name='seals'},sprite_pos={x=2,y=0}}},
    ASSET_ATLAS={centers={name='centers'},cards_1={name='cards_1'},seals={name='seals'}},
    SHADERS={foil={},holo={}},TIMERS={REAL=0},FUNCS={},
    localization={descriptions={},misc={}},C={GOLD={},BLUE={},BLACK={},RED={},
        UI={TEXT_LIGHT={},TEXT_DARK={},BACKGROUND_INACTIVE={}}},UIT={R='R',C='C',T='T',O='O'}}
local B={inspector={t=function(k)return k end},log={once=function(_,msg)error(msg)end}}
local function load(path)return assert(loadfile(ROOT..'/'..path))()(B)end
B.presentation=load('src/presentation.lua')
local ui=load('src/ui/random_controls.lua',B)
B.preview=load('src/ui/preview.lua',B)
local calls={}
function Sprite(x,y,w,h,atlas,pos)
    local function record(kind)calls[#calls+1]=kind..':'..atlas.name..':'..pos.x end
    return {states={drag={},hover={},collide={}},remove=function()end,
        draw=function()record('draw')end,draw_from=function()record('draw')end,
        draw_shader=function(_,shader)record(shader)end}
end
local row={key='H_A',category='Playing',name='Ace of Hearts',details={'Original details'},preview={layers={{atlas='cards_1'}}}}
local function render(display)
    calls={};local node=B.preview.node(display);assert(node.config.object)
    node.config.object:draw();assert(not node.config.object.bdctrl_render_failed)
    return table.concat(calls,'|')
end
local function display(spec)return ui.display_row(row,spec)end
test('Stone hides front even when replace_base_card flag is absent',function()
    local view=display({front='H_A',enhancement='m_stone'})
    assert(#view.preview.layers==1 and render(view)=='draw:centers:5')
    local real=B.presentation.card({config={center=G.P_CENTERS.m_stone,card=G.P_CARDS.H_A},ability={bonus=50}},
        {edition_key='',localized_name=row.name,area_name='deck',attributes=''})
    assert(render(real)==render(view),'candidate and actual-instance previews differ')
end)
test('replacement enhancement hides front using the same instance rule',function()
    assert(render(display({front='H_A',enhancement='m_replacement'}))=='draw:centers:7')
end)
test('normal and non-replacement enhancement keep rank/suit front',function()
    assert(render(display({front='H_A'}))=='draw:centers:0|draw:cards_1:12')
    assert(render(display({front='H_A',enhancement='m_glass'}))=='draw:centers:6|draw:cards_1:12')
end)
test('edition overlays precede unaffected seal with and without front',function()
    local stone=display({front='H_A',enhancement='m_stone',edition='e_foil',seal='Gold'})
    assert(render(stone)=='draw:centers:5|foil:centers:5|draw:seals:2')
    assert(stone.preview.layers[2].edition==false)
    local normal=display({front='H_A',edition='e_foil',seal='Gold'})
    assert(render(normal)=='draw:centers:0|draw:cards_1:12|foil:centers:0|foil:cards_1:12|draw:seals:2')
end)
test('building decorated display preserves catalog row and saved spec',function()
    local spec={front='H_A',enhancement='m_stone',edition='e_foil',seal='Gold'}
    local view=display(spec)
    assert(view~=row and view.preview~=row.preview and view.details~=row.details)
    assert(#row.details==1 and #row.preview.layers==1 and row.preview.layers[1].atlas=='cards_1')
    assert(spec.enhancement=='m_stone' and spec.edition=='e_foil' and spec.seal=='Gold')
end)
-- Exercise full definition: candidate and queue must use distinct specifications.
UIBox_button=function(args)return {button=args}end
B.dropdown={node=function(args)return {dropdown=args}end}
B.catalog={official=function()return true end,filter=function(snapshot)return snapshot.rows end}
B.ui={catalog_snapshot={rows={row}}}
B.filter={clip=function(text)return text end};B.search={display=''}
B.queue={editable=function()return true end};B.draw={supported=true}
B.random={editable=function()return true end,allowed=function()return true end,supported=true,
    list=function()return {'H_A'} end,
    playing_specs={{front='H_A',enhancement='m_stone',edition='e_foil',seal='Gold'}}}
B.temporary={pending={front='H_A',enhancement='m_stone',edition='e_foil',seal='Gold'}}
local captured={};local preview_node=B.preview.node
B.preview.node=function(view,height)captured[#captured+1]=view;return preview_node(view,height)end
test('standard queue retains saved Stone/edition/seal despite current normal selector',function()
    ui.domain='pack_Standard';ui.enhancement=nil;ui.edition='e_holo';ui.seal=nil
    captured={};ui.definition();assert(#captured==2)
    assert(render(captured[1])=='draw:centers:0|draw:cards_1:12|holo:centers:0|holo:cards_1:12')
    assert(render(captured[2])=='draw:centers:5|foil:centers:5|draw:seals:2')
end)
test('temporary pending retains saved Stone/edition/seal despite current Glass selector',function()
    ui.domain='temporary';ui.enhancement='m_glass';ui.edition='e_holo';ui.seal=nil
    captured={};ui.definition();assert(#captured==2)
    assert(render(captured[1])=='draw:centers:6|draw:cards_1:12|holo:centers:6|holo:cards_1:12')
    assert(render(captured[2])=='draw:centers:5|foil:centers:5|draw:seals:2')
end)
test('candidate selector Stone hides front in both temporary and Standard panels',function()
    ui.enhancement='m_stone';ui.edition=nil;ui.seal=nil
    for _,domain in ipairs({'temporary','pack_Standard'})do
        ui.domain=domain;captured={};ui.definition()
        assert(render(captured[1])=='draw:centers:5')
    end
end)
print('Stone preview regressions passed: '..passed..' cases')
