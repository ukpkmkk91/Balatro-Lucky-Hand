return function(BDC)
    local ids = setmetatable({}, {__mode = 'k'})
    local owners = setmetatable({}, {__mode = 'v'})
    local serial, generation = 0, 0
    local M = {}
    function M.reset()
        ids = setmetatable({}, {__mode = 'k'})
        owners = setmetatable({}, {__mode = 'v'})
        local active=BDC.compatibility.active_run()
        owners.run,owners.collection=active and G.GAME or nil,active and G.playing_cards or nil
        owners.deck,owners.hand=active and G.deck or nil,active and G.hand or nil
        serial, generation = 0, generation + 1
    end
    function M.sync()
        local active = BDC.compatibility.active_run()
        local current_run = active and G.GAME or nil
        local current_collection = active and G.playing_cards or nil
        local current_deck = active and G.deck or nil
        local current_hand = active and G.hand or nil
        if current_run ~= owners.run or current_collection ~= owners.collection
            or current_deck ~= owners.deck or current_hand ~= owners.hand then
            -- playing_card is renumbered by the game. Weak keys track object identity
            -- without modifying cards or retaining removed cards indefinitely.
            ids = setmetatable({}, {__mode = 'k'})
            owners.run, owners.collection, serial = current_run, current_collection, 0
            owners.deck, owners.hand = current_deck, current_hand
            generation = generation + 1
        end
    end
    function M.get(card)
        if not ids[card] then serial = serial + 1; ids[card] = serial end
        return string.format('%d:%03d', generation, ids[card])
    end
    function M.session()
        M.sync()
        return generation
    end
    return M
end
