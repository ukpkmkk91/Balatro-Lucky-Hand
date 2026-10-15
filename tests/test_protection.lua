-- GUI dependencies are fixture stubs. Card/save_run/discovery functions are
-- extracted without modifications from the installed native Lovely dump.
local passed=0
local KEY='bdctrl_run_only_provenance'
local function test(name,fn) fn();passed=passed+1;print('PASS '..name) end
local function module(B,name) return assert(loadfile(ROOT..'/src/'..name..'.lua'))()(B) end
local function world(install,saved)
    G={GAME=saved or {round_scores={new_collection={amt=0}},used_vouchers={},tags={}},
        P_CENTERS={},P_CENTER_POOLS={Back={}},P_CARDS={},CARD_H=1,CARD_W=1,ID=10000,
        ARGS={},FILE_HANDLER={},VERSION='1.0.1o-FULL',STATE=1,STATES={SELECTING_HAND=1},
        STATE_COMPLETE=true,STAGE='RUN',playing_cards={},save_progress_calls=0}
    local saveable={save=function() return {} end,is=function() return true end}
    G.GAME.blind=saveable;G.GAME.selected_back=saveable;G.GAME.current_scoring_calculation=saveable
    SMODS={mod_list={},config={seeded_unlocks=false},is_playing_card=function()return false end,
        calculate_context=function()end,enh_cache={clear=function()end}}
    function Event(t) return t end
    G.E_MANAGER={add_event=function(_,ev) ev.func() end}
    G.save_progress=function() G.save_progress_calls=G.save_progress_calls+1 end
    G.save_notify=function()end
    function set_discover_tallies()end
    function notify_alert()end
    function remove_all()end
    function Moveable() return {} end
    Card={load=function()end,set_ability=function()end,set_sprites=function()end};Card.__index=Card
    assert(loadstring(NATIVE))()
    CardArea={};Tag={};Object={}
    for _,name in ipairs({'deck','hand','jokers','consumeables','shop_jokers','shop_vouchers','pack_cards','vouchers'}) do
        G[name]={cards={},is=function(_,class)return class==CardArea end,
            save=function(self)local result={cards={}};for _,card in ipairs(self.cards) do
                result.cards[#result.cards+1]=card:save() end;return result end}
    end
    local B={logs={},compatibility={active_run=function()return G.STAGE=='RUN' end,
        extension_check=function()return true end},log={}}
    B.log.info=function(message) B.logs[#B.logs+1]=message end
    B.catalog=module(B,'catalog')
    if install then B.run_only=module(B,'run_only_objects') end
    return B
end
local function center(key,set,discovered,unlocked)
    local obj={key=key,set=set,discovered=discovered,unlocked=unlocked~=false,config={},name='Joker'}
    G.P_CENTERS[key]=obj;return obj
end
local function card_data(obj,edition,added)
    return {save_fields={center=obj.key,card='empty'},params={bypass_discovery_center=true},
        bypass_discovery_center=true,added_to_deck=added,edition=edition,
        ability={set=obj.set,name='Joker',h_size=0,d_size=0},ignore_base_shader={},ignore_shadow={}}
end
local function load_card(data)
    local card=setmetatable({T={},VT={},children={}},Card);card:load(data);return card
end
local function saved_run()
    save_run();assert(G.ARGS.save_run==G.culled_table and G.FILE_HANDLER.run)
    return G.ARGS.save_run
end
local function restore_card(snapshot,area)
    local card=load_card(snapshot.cardAreas[area].cards[1]);G[area].cards={card};card.area=G[area];return card
end
local function base_edition() return center('e_base','Edition',true) end

test('natural saved shop purchase matches native discovery without any Mod choice',function()
    local function buy(install)
        world(install);local obj=center('j_test','Joker',false);base_edition()
        G.shop_jokers.cards={load_card(card_data(obj,nil,false))};local saved=saved_run()
        world(install,saved.GAME);obj=center('j_test','Joker',false);base_edition()
        local card=restore_card(saved,'shop_jokers');G.shop_jokers.cards={};card:add_to_deck();G.jokers.cards={card}
        assert(G.GAME[KEY]==nil)
        return obj.discovered,G.GAME.round_scores.new_collection.amt,G.save_progress_calls
    end
    local a,b,c=buy(false);local x,y,z=buy(true)
    assert(a==true and x==a and b==1 and y==b and z==c)
end)

test('natural undiscovered edition still discovers after saved shop purchase',function()
    world(true);local obj=center('j_test','Joker',true);center('e_negative','Edition',false)
    G.shop_jokers.cards={load_card(card_data(obj,{type='negative',key='e_negative'},false))}
    local saved=saved_run();world(true,saved.GAME);obj=center('j_test','Joker',true)
    local ed=center('e_negative','Edition',false);local card=restore_card(saved,'shop_jokers')
    G.shop_jokers.cards={};card:add_to_deck()
    assert(ed.discovered and G.GAME.round_scores.new_collection.amt==1 and G.GAME[KEY]==nil)
end)

test('explicit Mod center provenance survives native save and loaded purchase',function()
    local B=world(true);local obj=center('j_test','Joker',false,false);base_edition()
    B.run_only.protect(obj.key);G.shop_jokers.cards={load_card(card_data(obj,nil,false))}
    local saved=saved_run();assert(saved.GAME[KEY].centers.j_test==true)
    B=world(true,saved.GAME);obj=center('j_test','Joker',false,false);base_edition()
    local card=restore_card(saved,'shop_jokers');G.shop_jokers.cards={};card:add_to_deck();unlock_card(obj)
    assert(not obj.discovered and not obj.unlocked and G.save_progress_calls==0)
    assert(card.bypass_lock and card.params.bypass_discovery_ui)
end)

test('explicit Mod edition survives fresh session native debuff removal and readdition',function()
    local B=world(true);local obj=center('j_test','Joker',true);center('e_negative','Edition',false)
    B.run_only.protect('e_negative')
    G.jokers.cards={load_card(card_data(obj,{type='negative',key='e_negative'},true))}
    local saved=saved_run();B=world(true,saved.GAME);center('j_test','Joker',true)
    local ed=center('e_negative','Edition',false);local card=restore_card(saved,'jokers')
    card.debuff=false;card:set_debuff(true);card:set_debuff(false)
    assert(not ed.discovered and G.GAME.round_scores.new_collection.amt==0 and G.save_progress_calls==0)
end)

test('explicit redeemed voucher remains protected without any surviving card',function()
    local B=world(true);local obj=center('v_test','Voucher',false,false)
    B.run_only.protect(obj.key);G.GAME.used_vouchers[obj.key]=true
    local saved=saved_run();B=world(true,saved.GAME);obj=center('v_test','Voucher',false,false)
    discover_card(obj);unlock_card(obj)
    assert(not obj.discovered and not obj.unlocked and G.GAME[KEY].centers.v_test)
    assert(G.save_progress_calls==0)
end)

test('natural used_vouchers entry cannot suppress discovery or unlock',function()
    world(true);local obj=center('v_test','Voucher',false,false);G.GAME.used_vouchers[obj.key]=true
    local saved=saved_run();world(true,saved.GAME);obj=center('v_test','Voucher',false,false)
    discover_card(obj);unlock_card(obj);assert(obj.discovered and obj.unlocked and G.GAME[KEY]==nil)
end)

test('run switch clears runtime protection and returning to saved run restores only its keys',function()
    local B=world(true);local obj=center('j_test','Joker',false,false);B.run_only.protect(obj.key)
    local old=G.GAME;G.GAME={};assert(not B.run_only.blocked(obj));assert(G.GAME[KEY]==nil)
    G.GAME=old;assert(B.run_only.blocked(obj))
    G.STAGE='MENU';assert(not B.run_only.blocked(obj))
    G.GAME=nil;assert(not B.run_only.blocked(obj))
    G.STAGE='RUN';G.GAME={};assert(not B.run_only.blocked(obj))
end)

test('provenance stores only schema and consumed keys; actual pending draw queue stays private',function()
    local B=world(true);local obj=center('j_test','Joker',false);B.run_only.protect(obj.key)
    B.identity={session=function()return G.GAME end,get=function()return 'UNSAVED_DRAW_SENTINEL' end}
    B.queue=module(B,'pending_queue')
    local card=load_card(card_data(obj,nil,false));card.base={value='Ace',suit='Hearts'};card.area=G.deck
    G.deck.cards={card};G.playing_cards={card};assert(B.queue.add('UNSAVED_DRAW_SENTINEL'))
    B.random={pending={shop={'UNSAVED_RANDOM_SENTINEL'}}}
    local saved=saved_run();local metadata=saved.GAME[KEY]
    assert(metadata.schema==1 and metadata.centers.j_test==true)
    local count=0;for k in pairs(metadata) do assert(k=='schema' or k=='centers');count=count+1 end;assert(count==2)
    local function inspect(value)
        if type(value)=='table' then for k,v in pairs(value) do
            assert(k~='pending' and k~='queue');inspect(v)
        end else assert(value~='UNSAVED_DRAW_SENTINEL' and value~='UNSAVED_RANDOM_SENTINEL') end
    end
    inspect(saved);assert(B.queue.count()==1)
end)

test('absent legacy provenance never guessed from native bypass flags',function()
    local B=world(true);local obj=center('j_test','Joker',false,false)
    local data=card_data(obj,nil,false);data.bypass_lock=true;G.jokers.cards={load_card(data)}
    assert(not B.run_only.blocked(obj));discover_card(obj);unlock_card(obj)
    assert(obj.discovered and obj.unlocked and G.GAME[KEY]==nil)
end)

test('malformed metadata and unknown schema degrade without blocking natural progress',function()
    for _,bad in ipairs({false,'corrupt',13,{}, {schema=2,centers={j_test=true}}, {schema=1,centers='bad'}}) do
        local B=world(true);local obj=center('j_test','Joker',false)
        G.GAME[KEY]=bad;assert(not B.run_only.blocked(obj));discover_card(obj)
        assert(obj.discovered and G.GAME[KEY]==nil and #B.logs==1)
        B.run_only.blocked(obj);assert(#B.logs==1)
    end
end)

test('metadata whitelists official private registry keys and literal true values',function()
    local B=world(true);local yes=center('j_yes','Joker',false);local natural=center('j_natural','Joker',false)
    local other=center('j_other','Joker',false);other.original_mod={}
    center('j_known','Joker',true)
    local bad={};bad.self=bad
    G.GAME[KEY]={schema=1,centers={j_yes=true,j_natural=1,j_missing=true,j_other=true,j_known=true,[3]=true,j_cycle=bad},unexpected=bad}
    assert(B.run_only.blocked(yes));assert(not B.run_only.blocked(natural));assert(not B.run_only.blocked(other))
    local saved=saved_run();assert(saved.GAME[KEY].unexpected==nil)
    local count=0;for key,value in pairs(saved.GAME[KEY].centers) do assert(key=='j_yes' and value==true);count=count+1 end
    assert(count==1)
end)

test('protect ignores invalid/unofficial/already-known objects and menu calls',function()
    local B=world(true);local obj=center('j_other','Joker',false);obj.mod={}
    center('j_known','Joker',true);B.run_only.protect(nil);B.run_only.protect('missing')
    B.run_only.protect('j_other');B.run_only.protect('j_known');assert(G.GAME[KEY]==nil)
    center('j_private','Joker',false);G.STAGE='MENU';B.run_only.protect('j_private');assert(G.GAME[KEY]==nil)
end)

test('known Mod keys stay protected for the run while unrelated natural keys discover',function()
    local B=world(true);local forced=center('j_forced','Joker',false);local natural=center('j_natural','Joker',false)
    B.run_only.protect(forced.key);discover_card(forced);discover_card(natural)
    assert(not forced.discovered and natural.discovered and G.GAME.round_scores.new_collection.amt==1)
end)

print('Protection regressions passed: '..passed..' cases')
