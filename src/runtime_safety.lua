-- Recovery touches only this Mod's runtime state. Native saves remain untouched.
return function(BDC)
    local M={}
    function M.reset(reason)
        if BDC.ui and (BDC.ui.box or BDC.ui.opening) then pcall(BDC.ui.close) end
        if BDC.identity then pcall(BDC.identity.reset) end
        if BDC.draw then pcall(BDC.draw.reset,reason) end
        if BDC.queue then pcall(BDC.queue.clear,reason) end
        if BDC.search then pcall(BDC.search.blur) end
        if BDC.random then pcall(BDC.random.reset,reason) end
        if BDC.temporary then pcall(BDC.temporary.reset,reason) end
        if BDC.random_ui then pcall(BDC.random_ui.reset) end
        if BDC.joker_ui then pcall(BDC.joker_ui.reset) end
    end
    function M.fail(reason)
        local first=not BDC.disabled
        BDC.disabled=true
        M.reset(reason)
        if first then pcall(BDC.log.warn,'controller disabled: '..tostring(reason)) end
    end
    return M
end
