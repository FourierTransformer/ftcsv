local ftcsv = {}

local function findClosingQuote(i, inputLength, inputString, quote, doubleQuoteEscape)
    local doubleQuoteEscape = doubleQuoteEscape
    while i <= inputLength do
        -- print(i)
        local currentChar = string.byte(inputString, i)
        local nextChar = string.byte(inputString, i+1)
        -- this one deals with " double quotes that are escaped "" within single quotes "
        -- these should be turned into a single quote at the end of the field
        if currentChar == quote and nextChar == quote then
            doubleQuoteEscape = true
            i = i + 2
        -- identifies the escape toggle
        elseif currentChar == quote and nextChar ~= quote then
            return i-1, doubleQuoteEscape
        else
            i = i + 1
        end
    end
end

local function createNewField(inputString, quote, fieldStart, i, line, fieldNum, doubleQuoteEscape, fieldsToKeep)
    -- print(lineNum, fieldNum, fieldStart, i-1)
    -- so, if we just recently de-escaped, we don't want the trailing \"
    -- if fieldsToKeep == nil then
    -- local fieldsToKeep = fieldsToKeep
    if fieldsToKeep == nil or fieldsToKeep[fieldNum] then
        -- print(fieldsToKeep)
        if string.byte(inputString, i-1) == quote then
            -- print("Skipping last \"")
            line[fieldNum] = string.sub(inputString, fieldStart, i-2)
        else
            line[fieldNum] = string.sub(inputString, fieldStart, i-1)
        end
        -- remove the double quotes (if they existed)
        if doubleQuoteEscape then
            -- print("QUOTE REPLACE")
            -- print(line[fieldNum])
            line[fieldNum] = line[fieldNum]:gsub('""', '"')
            return false
        end
    end
end

local function createHeaders(line, rename, fieldsToKeep)
    -- print("CREATING HEADERS")
    local headers = {}
    for i = 1, #line do
        if rename[line[i]] then
            headers[i] = rename[line[i]]
        else
            headers[i] = line[i]
        end
    end
    if fieldsToKeep ~= nil then
        for i = 1, #fieldsToKeep do
            fieldsToKeep[fieldsToKeep[i]] = true
        end
    end
    return headers, 0, true, fieldsToKeep
end

function ftcsv.decode(inputString, separator, options)
    -- each line in outResults holds another table
    local outResults = {}
    outResults[1] = {}

    -- separator MUST be one character
    if #separator ~= 1 and type("separator") ~= "string" then error("the separator must be of string type and exactly one character") end
    local separator = string.byte(separator)

    -- OPTIONS yo
    local header = true
    local rename = {}
    local fieldsToKeep = nil
    local ofieldsToKeep = nil
    if options then
        if options.headers ~= nil then
            if type(options.headers) ~= "boolean" then
                error("ftcsv only takes the boolean 'true' or 'false' for the optional parameter 'headers' (default 'true'). You passed in '" .. options.headers .. "' of type '" .. type(options.headers) .. "'.")
            end
            header = options.headers
        end
        if options.rename ~= nil then
            if type(options.rename) ~= "table" then
                error("ftcsv only takes in a key-value table for the optional parameter 'rename'. You passed in '" .. options.rename .. "' of type '" .. type(options.rename) .. "'.")
            end
            rename = options.rename
        end
        if options.fieldsToKeep ~= nil then
            ofieldsToKeep = options.fieldsToKeep
            if type(options.fieldsToKeep) ~= "table" then
                error("ftcsv only takes in a list (as a table for the optional parameter 'fieldsToKeep'. You passed in '" .. options.fieldsToKeep .. "' of type '" .. type(options.fieldsToKeep) .. "'.")
            end
        end
    end

    local CR = string.byte("\r")
    local LF = string.byte("\n")
    local quote = string.byte("\"")
    local doubleQuoteEscape = false
    local fieldStart = 1
    local fieldNum = 1
    local lineNum = 1
    local skipChar = 0
    local inputLength = #inputString
    local headerField = {}
    local headerSet = false
    local i = 1

    -- keep track of my chars!
    local currentChar, nextChar = string.byte(inputString, i), string.byte(inputString, i+1)

    while i <= inputLength do
        -- go by two chars at a time!
        -- currentChar = string.byte(inputString, i)
        nextChar = string.byte(inputString, i+1)
        -- print(i, string.char(currentChar), string.char(nextChar))

        -- keeps track of characters to "skip" while going through the encoding process
        -- if skipChar == 0 then

            -- empty string
            if currentChar == quote and nextChar == quote then
                -- print("EMPTY STRING")
                skipChar = 1
                fieldStart = i + 2
                -- print("fs+2:", fieldStart)

            -- identifies the escape toggle
            elseif currentChar == quote and nextChar ~= quote then
                -- print("ESCAPE TOGGLE")
                fieldStart = i + 1
                i, doubleQuoteEscape = findClosingQuote(i+1, inputLength, inputString, quote, doubleQuoteEscape)
                -- print("I VALUE", i, doubleQuoteEscape)
                skipChar = 1
            -- end

            -- create some fields if we can!
            elseif currentChar == separator then
                -- for that first field
                if not headerSet and lineNum == 1 then
                    headerField[fieldNum] = fieldNum
                end
                -- create the new field
                -- print(headerField[fieldNum])
                doubleQuoteEscape = createNewField(inputString, quote, fieldStart, i, outResults[lineNum], headerField[fieldNum], doubleQuoteEscape, fieldsToKeep)

                fieldNum = fieldNum + 1
                fieldStart = i + 1
                -- print("fs+1:", fieldStart)
            -- end

            -- newline?!
            elseif ((currentChar == CR and nextChar == LF) or currentChar == LF) then
                -- keep track of headers
                if not headerSet and lineNum == 1 then
                    headerField[fieldNum] = fieldNum
                end

                -- create the new field
                doubleQuoteEscape = createNewField(inputString, quote, fieldStart, i, outResults[lineNum], headerField[fieldNum], doubleQuoteEscape, fieldsToKeep)

                -- if we have headers then we gotta do something about it
                if header and lineNum == 1 and not headerSet then
                    headerField, lineNum, headerSet, fieldsToKeep = createHeaders(outResults[lineNum], rename, ofieldsToKeep)
                end

                lineNum = lineNum + 1
                outResults[lineNum] = {}
                fieldNum = 1
                fieldStart = i + 1
                -- print("fs:", fieldStart)
                if (currentChar == CR and nextChar == LF) then
                    -- print("CRLF DETECTED")
                    skipChar = 1
                    fieldStart = fieldStart + 1
                    -- print("fs:", fieldStart)
                end
            end

        i = i + 1 + skipChar
        if (skipChar > 0) then
            currentChar = string.byte(inputString, i)
        else
            currentChar = nextChar
        end
        skipChar = 0
    end

    -- if the line doesn't end happily (with a quote/newline), the last char will be forgotten.
    -- this should take care of that.
    createNewField(inputString, quote, fieldStart, i, outResults[lineNum], headerField[fieldNum], doubleQuoteEscape, fieldsToKeep)
    -- end

    -- clean up last line if it's weird (this happens when there is a CRLF newline at end of file)
    -- doing a count gets it to pick up the oddballs
    local count = 0
    for _, _ in pairs(outResults[lineNum]) do
        count = count + 1
    end
    if count ~= #headerField then
        outResults[lineNum] = nil
    end

    return outResults
end

local function delimitField(field)
    if field:find('"') then
        return '"' .. field:gsub('"', '""') .. '"'
    elseif field:find(" ") or field:find(",") or field:find("\n") then
        return '"' .. field .. '"'
    elseif field == "" then
        return '""'
    else
        return field
    end
end

function ftcsv.encode(inputTable, separator, headers)
    -- separator MUST be one character
    if #separator ~= 1 and type("separator") ~= "string" then error("the separator must be of string type and exactly one character") end

    -- keep track of me output
    local output = {}

    -- grab the headers from the first file if they are not provided
    -- we'll do this easily and not so quickly...
    local headers = headers
    if headers == nil then
        headers = {}
        for key, _ in pairs(inputTable[1]) do
            headers[#headers+1] = key
        end

        -- lets make the headers alphabetical
        table.sort(headers)
    end

    -- this is for outputting the headers
    local line = {}
    for i, header in ipairs(headers) do
        line[i] = delimitField(header)
    end
    line.length = #line

    -- string the header together yo
    output[1] = table.concat(line, separator)

    -- cheap and fast (because buffers)
    for i, fields in ipairs(inputTable) do
        local numHeaders = 0
        for j = 1, #headers do
            local field = fields[headers[j]]
            line[j] = delimitField(field)
            numHeaders = j
        end
        -- all lines should have the same number of fields
        if line.length ~= numHeaders then
            error("All lines should have the same length. The line at row " .. i .. " is of length " .. numHeaders .. " instead of " .. line.length)
        end
        output[i+1] = table.concat(line, separator)
    end

    return table.concat(output, "\r\n")
end

return ftcsv
