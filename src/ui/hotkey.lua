return function(BDC)
    local M={keys={'f6','f7','f8','f9','f10','f11','f12'}}
    function M.available(key)
        local known=false;for _,k in ipairs(M.keys) do if key==k then known=true end end
        if not known then return false,'invalid' end
        for _,binding in pairs(SMODS.Keybinds or {}) do
            if binding~=BDC.keybind and binding.key_pressed==key then return false,'conflict' end
        end
        return true
    end
    function M.set(key)
        local ok,reason=M.available(key)
        if not ok then M.message='hotkey_'..reason;return false end
        local previous=BDC.config.toggle_key
        if key==previous then M.message='hotkey_saved';return true end
        BDC.config.toggle_key=key
        local saved,result=pcall(SMODS.save_mod_config,BDC.mod)
        if saved and result==true and SMODS.NFS and SMODS.NFS.read then
            -- This SMODS version does not assert NFS.write's return value.
            -- Confirm our private preference was actually written before rebinding.
            saved,result=pcall(function()
                local bytes=SMODS.NFS.read('config/'..BDC.mod.id..'.jkr')
                local chunk=type(bytes)=='string' and loadstring(bytes,'BDC saved preferences')
                local config=chunk and setfenv(chunk,{})()
                return type(config)=='table' and config.toggle_key==key
            end)
        end
        if not saved or result~=true then
            BDC.config.toggle_key=previous;M.message='hotkey_save_failed'
            BDC.log.info('hotkey save failed; previous binding retained');return false
        end
        BDC.keybind.key_pressed=key;M.message='hotkey_saved'
        BDC.log.info('panel hotkey changed: '..previous..' -> '..key);return true
    end
    return M
end
