return function(BDC)
    local M = {}
    function M.lovely_version()
        local ok, lovely = pcall(require, 'lovely')
        return ok and type(lovely) == 'table' and tostring(lovely.version or 'unknown') or 'unknown'
    end
    function M.check()
        -- Missing capabilities disable only this UI, never the game's draw pipeline.
        if not SMODS or not G or not G.UIT or not G.C or not G.ROOM or not G.CONTROLLER
            or not G.FUNCS or type(G.FUNCS.overlay_menu) ~= 'function'
            or not UIBox or type(UIBox_button) ~= 'function'
            or type(create_UIBox_generic_options) ~= 'function' then
            return false, 'required UI API unavailable'
        end
        return true
    end
    function M.active_run()
        return G and G.STAGES and G.STAGE == G.STAGES.RUN and type(G.GAME) == 'table'
            and type(G.playing_cards) == 'table'
    end
    function M.draw_check()
        if not G or G.VERSION~='1.0.1o-FULL' or not SMODS or tostring(SMODS.version)~='26.829.0'
            or M.lovely_version()~='0.10.0' then
            return false,'Unsupported / Untested Version'
        end
        if not G.FUNCS or type(G.FUNCS.draw_from_deck_to_hand)~='function'
            or type(SMODS.draw_cards)~='function' or type(SMODS.calculate_context)~='function'
            or type(draw_card)~='function' or not CardArea or type(CardArea.emplace)~='function'
            or type(CardArea.draw_card_from)~='function' or type(CardArea.remove_card)~='function'
            or type(CardArea.load)~='function'
            or not Game or type(Game.start_run)~='function' or type(Game.delete_run)~='function'
            or type(Game.main_menu)~='function' then
            return false,'required draw API unavailable'
        end
        return true,'ready'
    end
    function M.extension_check()
        local ok,reason=M.draw_check();if not ok then return false,reason end
        for _,name in ipairs({'get_new_blind','create_blind_pool','add_boss_to_used_table','create_card',
            'get_next_vouchers','poll_seal','poll_enhancement','pseudorandom_probability','add_to_pool','showman'}) do
            if type(SMODS[name])~='function' then return false,'required extension API unavailable: '..name end
        end
        for _,name in ipairs({'get_new_boss','get_pack','get_next_voucher_key','get_next_tag_key','create_card',
            'create_playing_card','copy_card','poll_edition','unlock_card','discover_card'}) do
            if type(_G[name])~='function' then return false,'required extension function unavailable: '..name end
        end
        if not Card or type(Card.load)~='function' or type(Card.set_ability)~='function'
            or type(Card.remove)~='function' or type(CardArea.save)~='function' then return false,'required card persistence API unavailable' end
        return true,'ready'
    end
    return M
end
