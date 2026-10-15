-- Runtime-only queue and narrowly scoped draw hooks; no Profile writes.
local mod = SMODS and SMODS.current_mod
if not mod then return end
if rawget(_G, 'BDC') then
    if sendWarnMessage then sendWarnMessage('BDC namespace is already occupied; Inspector disabled', 'BDC') end
    return
end
local BDC = {mod = mod, version = '0.8.1', config = mod.config or {}, disabled = false}
_G.BDC = BDC
local function load_module(path)
    local chunk, err = SMODS.load_file(path, mod.id)
    if not chunk then error(err or path) end
    return chunk()(BDC)
end
local ok, err = pcall(function()
    BDC.log = load_module('src/logging.lua')
    BDC.compatibility = load_module('src/compatibility.lua')
    BDC.identity = load_module('src/instance_identity.lua')
    BDC.inspector = load_module('src/inspector.lua')
    BDC.presentation = load_module('src/presentation.lua')
    BDC.catalog = load_module('src/catalog.lua')
    BDC.preview = load_module('src/ui/preview.lua')
    BDC.hotkey = load_module('src/ui/hotkey.lua')
    BDC.audit = load_module('src/readonly_audit.lua')
    BDC.filter = load_module('src/filter.lua')
    BDC.queue = load_module('src/pending_queue.lua')
    BDC.safety = load_module('src/runtime_safety.lua')
    BDC.draw = load_module('src/draw_override.lua')
    BDC.rules = load_module('src/official_rules.lua')
    BDC.run_only = load_module('src/run_only_objects.lua')
    BDC.random = load_module('src/random_controls.lua')
    BDC.dropdown = load_module('src/ui/dropdown.lua')
    BDC.joker_editions = load_module('src/joker_editions.lua')
    BDC.joker_ui = load_module('src/ui/jokers.lua')
    BDC.random_ui = load_module('src/ui/random_controls.lua')
    BDC.search = load_module('src/ui/search_input.lua')
    BDC.ui = load_module('src/ui/inspector.lua')
    BDC.lifecycle = load_module('src/queue_lifecycle.lua')
    BDC.temporary = load_module('src/temporary_cards.lua')
    BDC.config.toggle_key = type(BDC.config.toggle_key) == 'string' and BDC.config.toggle_key or 'f8'
    BDC.config.page_size = math.floor(math.max(1, math.min(8, tonumber(BDC.config.page_size) or 8)))
    BDC.log.info('BalatroDrawController '..BDC.version..'; Balatro '..tostring(G and G.VERSION)
        ..'; SMODS '..tostring(SMODS.version)..'; Lovely '..BDC.compatibility.lovely_version())
    -- The controller can repeat pressed callbacks while held. Release toggles once.
    if not BDC.hotkey.available(BDC.config.toggle_key) then
        BDC.config.toggle_key='f8'
        for _,key in ipairs({'f8','f9','f10','f11','f12','f6','f7'}) do
            if BDC.hotkey.available(key) then BDC.config.toggle_key=key;break end
        end
    end
    BDC.keybind = SMODS.Keybind{key = 'inspector_toggle', key_pressed = BDC.config.toggle_key, event = 'released',
        action = function() BDC.ui.toggle() end}
    mod.config_tab = function() return BDC.ui.config_tab() end
    BDC.log.info('Inspector and draw controller initialized (override off by default)')
end)
if not ok then
    if BDC.safety then BDC.safety.fail('initialization failure: '..tostring(err)) else BDC.disabled = true end
    if sendErrorMessage then sendErrorMessage('Inspector initialization failure: '..tostring(err), 'BDC') end
end
