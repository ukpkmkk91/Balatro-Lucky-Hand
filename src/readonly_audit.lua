return function(BDC)
    local M = {}
    local keys = {'playing_cards','deck','hand','discard','play'}
    local function clone(t, seen)
        if type(t) ~= 'table' then return t end
        seen = seen or {}; if seen[t] then return seen[t] end
        local out = {}; seen[t] = out
        for k,v in pairs(t) do out[k] = clone(v,seen) end
        return out
    end
    local function same(a,b,seen)
        if type(a) ~= type(b) then return false end
        if type(a) ~= 'table' then return a == b end
        seen=seen or {}; if seen[a] == b then return true end; seen[a]=b
        for k,v in pairs(a) do if not same(v,b[k],seen) then return false end end
        for k in pairs(b) do if a[k] == nil then return false end end
        return true
    end
    function M.capture()
        local record={run=G and G.GAME, areas={}}
        for _,key in ipairs(keys) do
            local cards = key == 'playing_cards' and G.playing_cards or (G[key] and G[key].cards)
            local ordered={}; for i,card in ipairs(cards or {}) do ordered[i]=card end
            record.areas[key]=ordered
        end
        record.rng=clone(G and G.GAME and G.GAME.pseudorandom)
        return record
    end
    function M.check(before, action)
        if not before then return end
        local after=M.capture()
        local result={action=action, order=true, counts=true, game_rng=true}
        if before.run ~= after.run then
            result.skipped='run changed'
        else
            for _,key in ipairs(keys) do
                local a,b=before.areas[key],after.areas[key]
                if #a ~= #b then result.counts=false end
                for i,c in ipairs(a) do if b[i] ~= c then result.order=false end end
            end
            result.game_rng=same(before.rng,after.rng)
        end
        BDC.last_audit=result
        local msg='read-only audit '..action..': order='..tostring(result.order)..', counts='..tostring(result.counts)
            ..', game_rng='..tostring(result.game_rng)..(result.skipped and ', skipped='..result.skipped or '')
        if not result.order or not result.counts or not result.game_rng then BDC.log.warn(msg) else BDC.log.info(msg) end
        return result
    end
    return M
end
