-- Scoped UTF-8 input: native Balatro text input splits multibyte characters.
-- All callbacks outside this panel retain the preceding handler and arguments.
return function(BDC)
    local M = {text='', display='', composition='', focused=false}
    local consumed = {}
    local function active()
        return M.focused and not BDC.disabled and BDC.ui and BDC.ui.box
            and G.OVERLAY_MENU == BDC.ui.box
    end
    function M.update()
        local value = BDC.filter.clip(M.text, 34)
        if value ~= M.text then value = value..'…' end
        if M.focused then value = value..M.composition..'_' end
        M.display = value ~= '' and value or BDC.inspector.t('search_hint')
    end
    function M.blur()
        if M.focused then
            M.focused=false;M.composition=''
            love.keyboard.setTextInput(M.previous_text_input or false)
        end
        M.update()
    end
    function M.focus()
        if not M.focused then
            M.previous_text_input=love.keyboard.hasTextInput()
            M.focused=true;love.keyboard.setTextInput(true)
        end
        M.update()
    end
    function M.set(value)
        M.text=BDC.filter.clip(tostring(value or ''):gsub('%c',' '),96);M.composition='';M.update()
    end
    local function protect(fn)
        local ok, err=pcall(fn)
        if not ok then
            if BDC.safety then BDC.safety.fail('search input failure: '..tostring(err))
            else BDC.disabled=true;pcall(M.blur);if BDC.ui then pcall(BDC.ui.close) end end
        end
    end
    local previous_textinput=love.textinput
    love.textinput=function(text,...)
        if active() then protect(function() M.set(M.text..text) end);return end
        if previous_textinput then return previous_textinput(text,...) end
    end
    local previous_textedited=love.textedited
    love.textedited=function(text,start,length,...)
        if active() then protect(function() M.composition=BDC.filter.clip(text,20);M.update() end);return end
        if previous_textedited then return previous_textedited(text,start,length,...) end
    end
    local previous_keypressed=love.keypressed
    love.keypressed=function(key,...)
        if active() and key ~= BDC.config.toggle_key then
            consumed[key]=true
            protect(function()
                local ctrl=love.keyboard.isDown('lctrl','rctrl')
                if key=='escape' then M.blur()
                elseif key=='return' or key=='kpenter' then
                    if M.composition=='' then BDC.ui.apply_search() end
                elseif key=='backspace' and M.composition=='' then
                    M.set(ctrl and '' or BDC.filter.backspace(M.text))
                elseif ctrl and key=='v' then M.set(M.text..love.system.getClipboardText())
                elseif ctrl and key=='a' then M.set('') end
            end)
            return
        end
        if previous_keypressed then return previous_keypressed(key,...) end
    end
    local previous_keyreleased=love.keyreleased
    love.keyreleased=function(key,...)
        if consumed[key] then consumed[key]=nil;return end
        if previous_keyreleased then return previous_keyreleased(key,...) end
    end
    local previous_wheel=love.wheelmoved
    love.wheelmoved=function(x,y,...)
        if not BDC.disabled and BDC.ui and BDC.ui.box and G.OVERLAY_MENU==BDC.ui.box then
            if not M.focused and y~=0 and (BDC.ui.tab=='cards' or BDC.ui.tab=='queue' or BDC.ui.tab=='catalog' or BDC.ui.tab=='random' or BDC.ui.tab=='jokers') then BDC.ui.page_by(y>0 and -1 or 1) end
            return
        end
        if previous_wheel then return previous_wheel(x,y,...) end
    end
    return M
end
