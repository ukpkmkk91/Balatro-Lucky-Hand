-- Tested SMODS 26.829.0: plan before its capacity scan, commit at hand emplace.
-- Planning uses a private array only during the synchronous producer call.
return function(BDC)
    local M={enabled=false,supported=false,reason='initializing'}
    local stack,reserved,pending={},{},{}
    local executing,active_ticket=nil,nil
    local count,session=0,nil
    local function pack(...) return {n=select('#',...),...} end
    local function member(area,card)
        if not area or type(area.cards)~='table' then return false end
        for _,value in ipairs(area.cards) do if value==card then return true end end
        return false
    end
    local function release(ticket)
        if not ticket then return end
        if ticket.card and reserved[ticket.card]==ticket then reserved[ticket.card]=nil end
        if pending[ticket] then pending[ticket]=nil;count=count-1 end
    end
    local function warn(reason)
        M.enabled=false;M.supported=false;M.reason=reason
        pcall(BDC.log.warn,'draw override disabled: '..reason)
    end
    local function safely(fn,...)
        local ok,result=pcall(fn,...)
        if not ok then warn(tostring(result));return nil end
        return result
    end
    function M.busy() return count>0 or #stack>0 end
    function M.reset()
        reserved,pending={},{};count=0;M.enabled=false
        for _,tx in ipairs(stack) do tx.cancelled=true end
    end
    function M.step()
        local current=BDC.identity.session()
        if current~=session then
            session=current;M.reset()
            BDC.queue.validate()
        end
        if count>0 then
            local events={}
            for _,queue in pairs((G.E_MANAGER and G.E_MANAGER.queues) or {}) do
                for _,event in pairs(queue) do events[event]=true end
            end
            for ticket in pairs(pending) do
                if not ticket.executing and ticket.event and not events[ticket.event] then release(ticket) end
            end
        end
    end
    local function live()
        if BDC.disabled or not M.supported or not M.enabled then return false end
        local ok,result=pcall(function()
            M.step()
            return M.enabled and BDC.compatibility.active_run()
                and G.deck and G.hand and type(G.deck.cards)=='table' and BDC.queue.count()>0
        end)
        if not ok then BDC.safety.fail('draw state check failure: '..tostring(result));return false end
        return result==true
    end
    function M.set_enabled(value)
        M.step()
        if not BDC.queue.editable() or not M.supported or M.busy() then return false end
        M.enabled=value==true
        BDC.log.info('draw override '..(M.enabled and 'enabled' or 'disabled'))
        return true
    end
    local function cost(card)
        if G.hand.config.fixed_limit then return 1 end
        local a=card and card.ability
        if not a or type(a.card_limit)~='number' or type(a.extra_slots_used)~='number' then return nil end
        local n=1-a.card_limit+a.extra_slots_used
        if n~=n or n==math.huge or n==-math.huge then return nil end
        return n
    end
    local function candidates()
        local valid=BDC.queue.validate()
        local by_id={}
        for _,card in ipairs(G.deck.cards) do
            local id=BDC.identity.get(card)
            if valid[id] then by_id[id]=card end
        end
        return BDC.queue.ids(),by_id
    end
    local function restore(tx)
        if not tx.view then return true end
        local view=tx.view;tx.view=nil
        local function reinsert_excluded(target)
            if type(target)~='table' then return end
            for _,card in ipairs(tx.excluded or {}) do
                if card.area==tx.deck and not card.removed and not card.destroyed and not member({cards=target},card) then
                    table.insert(target,1,card)
                end
            end
        end
        local function preserve_conflict()
            reinsert_excluded(view)
            warn('planning array changed; external order preserved and reserved cards retained')
            return false
        end
        if G.deck~=tx.deck or tx.deck.cards~=view then
            if G.deck==tx.deck then reinsert_excluded(tx.deck.cards) end
            warn('deck changed during selection; external changes preserved');return false
        end
        -- Never merge or overwrite a collection edited by another hook.
        if #view~=#tx.expected then
            return preserve_conflict()
        end
        for i,card in ipairs(view) do
            if card~=tx.expected[i] then return preserve_conflict() end
        end
        tx.deck.cards=tx.original
        return true
    end
    local function plan(tx,context,flags)
        if tx.cancelled or tx.session~=BDC.identity.session() or tx.context_done or tx.kind~='standard' or not live() then return end
        tx.context_done=true
        local ids,by_id=candidates()
        if #ids==0 then return end
        local limit=flags and (flags.cards_to_draw or flags.modify) or tx.limit
        if type(limit)~='number' or limit<=0 then return end
        local prefix,picked={},{}
        for _,id in ipairs(ids) do
            local card=by_id[id]
            if not card or reserved[card] then break end
            local c=cost(card)
            if not c then return end
            if limit<=0 or limit-c<0 then break end
            prefix[#prefix+1]=card;picked[card]=true;limit=limit-c
        end
        if #prefix==0 and count==0 then
            M.reason='capacity';BDC.log.info('draw override skipped: queue head unavailable or capacity limited');return
        end
        tx.deck=G.deck;tx.original=G.deck.cards
        local view={};tx.excluded={}
        for _,card in ipairs(tx.original) do
            if reserved[card] then tx.excluded[#tx.excluded+1]=card end
            if not picked[card] and not reserved[card] then view[#view+1]=card end
        end
        for i=#prefix,1,-1 do view[#view+1]=prefix[i] end
        tx.expected={};for i,card in ipairs(view) do tx.expected[i]=card end
        tx.view=view;tx.planned=true;tx.forced=picked;G.deck.cards=view
        M.reason='ready'
        BDC.log.info('draw plan: prioritized='..#prefix..'; pending='..#ids)
    end
    local compatible,reason=BDC.compatibility.draw_check()
    M.supported=compatible;M.reason=reason or 'ready';M.step()
    BDC.log.info('draw hook initialized; supported='..tostring(compatible)..'; enabled=false; '..M.reason)
    if not compatible then return M end
    local old_standard=G.FUNCS.draw_from_deck_to_hand
    local old_helper=SMODS.draw_cards
    local old_context=SMODS.calculate_context
    local old_draw=draw_card
    local old_emplace=CardArea.emplace
    local old_from=CardArea.draw_card_from
    local old_remove=CardArea.remove_card
    local function producer(kind,previous,...)
        if not live() then return previous(...) end
        local tx=safely(function()
            return {kind=kind,tickets={},session=session,deck=G.deck,hand=G.hand,manager=G.E_MANAGER,
                limit=G.hand.config.card_limit-#G.hand.cards-(SMODS.cards_to_draw or 0)}
        end)
        if not tx then return previous(...) end
        stack[#stack+1]=tx
        local values=pack(pcall(previous,...))
        safely(restore,tx);stack[#stack]=nil
        if #tx.tickets>0 then
            -- Tail runs after this producer's transfer events. Canceled draws stay queued.
            tx.manager:add_event(Event{trigger='immediate',func=function()
                -- Retrying transfer callbacks remain reserved until completion/cancel.
                safely(M.step)
                return true
            end})
        end
        if not values[1] then error(values[2],0) end
        return unpack(values,2,values.n)
    end
    G.FUNCS.draw_from_deck_to_hand=function(...) return producer('standard',old_standard,...) end
    SMODS.draw_cards=function(...) return producer('helper',old_helper,...) end
    SMODS.calculate_context=function(context,...)
        local tx=stack[#stack]
        if not tx or not context or not context.drawing_cards then return old_context(context,...) end
        tx.depth=(tx.depth or 0)+1
        local values=pack(pcall(old_context,context,...))
        tx.depth=tx.depth-1
        if not values[1] then error(values[2],0) end
        if tx.depth==0 then safely(plan,tx,context,values[2]) end
        return unpack(values,2,values.n)
    end
    draw_card=function(from,to,percent,dir,sort,card,...)
        local tx=stack[#stack]
        if tx and tx.view then safely(restore,tx) end
        if not tx or tx.cancelled or from~=tx.deck or to~=tx.hand then
            return old_draw(from,to,percent,dir,sort,card,...)
        end
        if card and reserved[card] then
            warn('duplicate scheduled instance');return
        end
        local ticket={tx=tx,card=card,deck=tx.deck,hand=tx.hand,manager=tx.manager,session=tx.session,
            forced=card and tx.forced and tx.forced[card]}
        if card then reserved[card]=ticket end
        pending[ticket]=true;count=count+1;tx.tickets[#tx.tickets+1]=ticket
        local manager=G.E_MANAGER
        local previous_add=manager.add_event
        local captured=0
        manager.add_event=function(self,event,...)
            if self==manager and type(event.func)=='function' then
                captured=captured+1
                ticket.event=event
                local callback=event.func
                event.func=function(...)
                    if ticket.session~=safely(BDC.identity.session) or BDC.disabled
                        or G.deck~=ticket.deck or G.hand~=ticket.hand or G.E_MANAGER~=ticket.manager then
                        release(ticket);return true
                    end
                    if card and not safely(BDC.queue.available_card,card,ticket.deck) then
                        release(ticket);safely(BDC.queue.drop,BDC.identity.get(card),'invalid scheduled draw')
                        BDC.log.info('draw skipped: scheduled instance unavailable');return true
                    end
                    ticket.executing=true
                    local parent_ticket=active_ticket;active_ticket=ticket
                    local drawn=SMODS.drawn_cards
                    local drawn_start=type(drawn)=='table' and #drawn or 0
                    local values=pack(pcall(callback,...))
                    if ticket.rejected_card and type(SMODS.drawn_cards)=='table' then
                        local first=SMODS.drawn_cards==drawn and drawn_start+1 or 1
                        for i=#SMODS.drawn_cards,first,-1 do
                            if SMODS.drawn_cards[i]==ticket.rejected_card then table.remove(SMODS.drawn_cards,i) end
                        end
                    end
                    active_ticket=parent_ticket
                    ticket.executing=false
                    if not values[1] then release(ticket);error(values[2],0) end
                    if values[2] then release(ticket) end
                    return unpack(values,2,values.n)
                end
            end
            return previous_add(self,event,...)
        end
        local values=pack(pcall(old_draw,from,to,percent,dir,sort,card,...))
        manager.add_event=previous_add
        if captured~=1 then warn('unexpected draw event count: '..captured) end
        if not values[1] then release(ticket);error(values[2],0) end
        return unpack(values,2,values.n)
    end
    CardArea.draw_card_from=function(self,area,stay_flipped,discarded_only,...)
        if self~=G.hand or area~=G.deck or not live() then
            return old_from(self,area,stay_flipped,discarded_only,...)
        end
        local ids,by_id=safely(candidates)
        -- safely returns one value; build the map separately below.
        local selected=nil
        if ids then
            by_id={};for _,c in ipairs(G.deck.cards) do by_id[BDC.identity.get(c)]=c end
            local head=by_id[ids[1]]
            local normal=nil
            for i=#area.cards,1,-1 do
                local c=area.cards[i]
                if not reserved[c] and (not discarded_only or (c.ability and c.ability.discarded)) then normal=c;break end
            end
            if head and not reserved[head] and (not discarded_only or head.ability.discarded)
                and normal and cost(head)~=nil and cost(head)==cost(normal) then selected=head end
            selected=selected or normal
        end
        if not selected then
            -- Every remaining candidate is already scheduled; never draw it twice.
            if count>0 then return nil end
            return old_from(self,area,stay_flipped,discarded_only,...)
        end
        local parent=executing
        executing={card=selected,deck=area,hand=self,session=session,forced=ids and ids[1]==BDC.identity.get(selected),used=false}
        local transfer=executing
        local values=pack(pcall(old_from,self,area,stay_flipped,discarded_only,...))
        executing=parent
        if not values[1] then error(values[2],0) end
        if transfer.rejected_card then return nil end
        return unpack(values,2,values.n)
    end
    CardArea.remove_card=function(self,card,discarded_only,...)
        if executing and not executing.used and self==executing.deck and card==nil then
            executing.used=true
            if member(self,executing.card) and executing.card.area==self then card=executing.card end
        end
        local owner=card and (reserved[card] or (active_ticket and active_ticket.card==card and active_ticket)
            or (executing and executing.used and executing.card==card and executing))
        if owner and self==owner.deck then
            for i,value in ipairs(self.cards or {}) do
                if value==card then owner.position=i;owner.before=self.cards[i-1];owner.after=self.cards[i+1];break end
            end
        end
        return old_remove(self,card,discarded_only,...)
    end
    CardArea.emplace=function(self,card,...)
        local ticket=reserved[card] or (active_ticket and active_ticket.card==card and active_ticket)
        local transfer=executing and executing.used and executing.card==card and executing
        if not ticket and not transfer then return old_emplace(self,card,...) end
        local owner=ticket or transfer
        local current=safely(BDC.identity.session)
        -- A blind/Mod callback may destroy or remove the detached card mid-transfer.
        if BDC.disabled or (owner.tx and owner.tx.cancelled) or owner.session~=current
            or not safely(BDC.queue.valid_instance,card) then
            owner.rejected_card=card
            -- Undo only our detached transfer when its original deck still exists.
            -- Removed/destroyed cards are never resurrected.
            if owner.deck==G.deck and card.area==nil and safely(BDC.queue.valid_instance,card)
                and not member(owner.deck,card) then
                old_emplace(owner.deck,card)
                local cards=owner.deck.cards
                for i,value in ipairs(cards) do if value==card then table.remove(cards,i);break end end
                local position=math.min(owner.position or (#cards+1),#cards+1)
                for i,value in ipairs(cards) do
                    if value==owner.after then position=i;break
                    elseif value==owner.before then position=i+1 end
                end
                table.insert(cards,position,card)
                owner.deck:set_ranks();owner.deck:align_cards()
            end
            release(ticket)
            if owner.session==current then safely(BDC.queue.drop,BDC.identity.get(card),'invalid detached draw') end
            return
        end
        local values=pack(old_emplace(self,card,...))
        if self==G.hand and card.area==G.hand and member(G.hand,card) then
            release(ticket)
            if ticket and ticket.forced or transfer and transfer.forced then
                BDC.log.info('draw committed '..BDC.identity.get(card)..'; source='..(ticket and 'standard' or 'deferred'))
            end
            safely(BDC.queue.drop,BDC.identity.get(card),'drawn to hand')
        elseif ticket then release(ticket) end
        return unpack(values,1,values.n)
    end
    return M
end
