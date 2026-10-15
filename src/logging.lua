return function(BDC)
    local seen = {}
    local function emit(level, message)
        if level == 'info' and BDC.config.logging == false then return end
        local f = level == 'info' and sendInfoMessage or sendWarnMessage
        if f then pcall(f, message, 'BDC') end
    end
    return {
        info = function(message) emit('info', message) end,
        warn = function(message) emit('warn', message) end,
        once = function(key, message)
            if seen[key] then return end
            seen[key] = true
            emit('warn', message)
        end,
    }
end
