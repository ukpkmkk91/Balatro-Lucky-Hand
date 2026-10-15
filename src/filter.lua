-- Pure snapshot operations. Never receives live Card objects or sorts a game collection.
return function()
    local M = {}
    M.fields = {'suit','rank','enhancement','edition','seal','area_name'}
    function M.options(cards)
        local result = {}
        for _,field in ipairs(M.fields) do
            local seen, values = {}, {}
            for _,row in ipairs(cards or {}) do
                local value = row[field]
                if type(value) == 'string' and not seen[value] then
                    seen[value] = true; values[#values+1] = value
                end
            end
            table.sort(values)
            result[field] = values
        end
        return result
    end
    function M.apply(cards, query, filters)
        local tokens, result = {}, {}
        for token in tostring(query or ''):lower():gmatch('%S+') do tokens[#tokens+1] = token end
        for _,row in ipairs(cards or {}) do
            local matches = true
            for _,field in ipairs(M.fields) do
                if filters and filters[field] and row[field] ~= filters[field] then matches = false; break end
            end
            if matches and #tokens > 0 then
                local parts = {}
                for _,value in pairs(row) do
                    if type(value) == 'string' or type(value) == 'number' then parts[#parts+1] = tostring(value) end
                end
                local text = table.concat(parts, ' '):lower()
                for _,token in ipairs(tokens) do
                    if not text:find(token, 1, true) then matches = false; break end
                end
            end
            if matches then result[#result+1] = row end
        end
        return result
    end
    function M.clip(text, limit)
        local chars = {}
        for char in tostring(text or ''):gmatch('[%z\1-\127\194-\244][\128-\191]*') do
            if #chars >= limit then break end
            chars[#chars+1] = char
        end
        return table.concat(chars)
    end
    function M.backspace(text)
        return (tostring(text or ''):gsub('[%z\1-\127\194-\244][\128-\191]*$', ''))
    end
    return M
end
