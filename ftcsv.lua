local ftcsv = {
    _VERSION = 'ftcsv 1.1.4',
    _DESCRIPTION = 'CSV library for Lua',
    _URL         = 'https://github.com/FourierTransformer/ftcsv',
    _LICENSE     = [[
        The MIT License (MIT)

        Copyright (c) 2016-2017 Shakil Thakur

        Permission is hereby granted, free of charge, to any person obtaining a copy
        of this software and associated documentation files (the "Software"), to deal
        in the Software without restriction, including without limitation the rights
        to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
        copies of the Software, and to permit persons to whom the Software is
        furnished to do so, subject to the following conditions:

        The above copyright notice and this permission notice shall be included in all
        copies or substantial portions of the Software.

        THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
        IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
        FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
        AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
        LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
        OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
        SOFTWARE.
    ]]
}

-- lua 5.1 load compat
local M = {}
if type(jit) == 'table' or _ENV then
    M.load = _G.load
else
    M.load = loadstring
end

-- perf
local sbyte = string.byte
local ssub = string.sub

-- luajit specific speedups
-- luajit performs faster with iterating over string.byte,
-- whereas vanilla lua performs faster with string.find
if type(jit) == 'table' then
    -- finds the end of an escape sequence
    function M.findClosingQuote(i, inputLength, inputString, quote, doubleQuoteEscape)
        local currentChar, nextChar = sbyte(inputString, i), nil
        while i <= inputLength do
            -- print(i)
            nextChar = sbyte(inputString, i+1)

            -- this one deals with " double quotes that are escaped "" within single quotes "
            -- these should be turned into a single quote at the end of the field
            if currentChar == quote and nextChar == quote then
                doubleQuoteEscape = true
                i = i + 2
                currentChar = sbyte(inputString, i)

            -- identifies the escape toggle
            elseif currentChar == quote and nextChar ~= quote then
                -- print("exiting", i-1)
                return i-1, doubleQuoteEscape
            else
                i = i + 1
                currentChar = nextChar
            end
        end
    end

else
    -- vanilla lua closing quote finder
    function M.findClosingQuote(i, inputLength, inputString, quote, doubleQuoteEscape)
        local j, difference
        i, j = inputString:find('"+', i)
        if j == nil then return end
        if i == nil then
            return inputLength-1, doubleQuoteEscape
        end
        difference = j - i
        -- print("difference", difference, "I", i, "J", j)
        if difference >= 1 then doubleQuoteEscape = true end
        if difference == 1 then
            return M.findClosingQuote(j+1, inputLength, inputString, quote, doubleQuoteEscape)
        end
        return j-1, doubleQuoteEscape
    end

end

-- load an entire file into memory
local function loadFile(textFile)
    local file = io.open(textFile, "r")
    if not file then error("ftcsv: File not found at " .. textFile) end
    local allLines = file:read("*all")
    file:close()
    return allLines
end

-- creates a new field
local function createField(inputString, quote, fieldStart, i, doubleQuoteEscape)
    local field
    -- so, if we just recently de-escaped, we don't want the trailing "
    if sbyte(inputString, i-1) == quote then
        -- print("Skipping last \"")
        field = ssub(inputString, fieldStart, i-2)
    else
        field = ssub(inputString, fieldStart, i-1)
    end
    if doubleQuoteEscape then
        -- print("QUOTE REPLACE")
        -- print(line[fieldNum])
        field = field:gsub('""', '"')
    end
    return field
end

-- main function used to parse
local function parseString(inputString, delimiter, i, headerField, fieldsToKeep, buffered)

    -- keep track of my chars!
    local inputLength = #inputString
    local currentChar, nextChar = sbyte(inputString, i), nil
    local skipChar = 0
    local field
    local fieldStart = i
    local fieldNum = 1
    local lineNum = 1
    local lineStart = i
    local doubleQuoteEscape, emptyIdentified = false, false
    local exit = false

    --bytes
    local CR = sbyte("\r")
    local LF = sbyte("\n")
    local quote = sbyte('"')
    local delimiterByte = sbyte(delimiter)

    local assignValue
    local outResults
    -- outResults[1] = {}
    -- the headers haven't been set yet.
    -- aka this is the first run!
    if headerField == nil then
        headerField = {}
        assignValue = function()
            headerField[fieldNum] = field
            emptyIdentified = false
            return true
        end
    else
        outResults = {}
        outResults[1] = {}
        assignValue = function()
            emptyIdentified = false
            if not pcall(function()
                outResults[lineNum][headerField[fieldNum]] = field
            end) then
                error('ftcsv: too many columns in row ' .. lineNum)
            end
        end
    end

    -- calculate the initial line count (note: this can include duplicates)
    local headerFieldsExist = {}
    local initialLineCount = 0
    for _, value in pairs(headerField) do
        if not headerFieldsExist[value] and (fieldsToKeep == nil or fieldsToKeep[value]) then
            headerFieldsExist[value] = true
            initialLineCount = initialLineCount + 1
        end
    end

    while i <= inputLength do
        -- go by two chars at a time! currentChar is set at the bottom.
        -- currentChar = string.byte(inputString, i)
        nextChar = sbyte(inputString, i+1)
        -- print(i, string.char(currentChar), string.char(nextChar))

        -- empty string
        if currentChar == quote and nextChar == quote then
            skipChar = 1
            fieldStart = i + 2
            emptyIdentified = true
            -- print("fs+2:", fieldStart)

        -- identifies the escape toggle.
        -- This can only happen if fields have quotes around them
        -- so the current "start" has to be where a quote character is.
        elseif currentChar == quote and nextChar ~= quote and fieldStart == i then
            -- print("New Quoted Field", i)
            fieldStart = i + 1

            -- if an empty field was identified before assignment, it means
            -- that this is a quoted field that starts with escaped quotes
            -- ex: """a"""
            if emptyIdentified then
                fieldStart = fieldStart - 2
                emptyIdentified = false
            end

            i, doubleQuoteEscape = M.findClosingQuote(i+1, inputLength, inputString, quote, doubleQuoteEscape)
            -- print("I VALUE", i, doubleQuoteEscape)
            skipChar = 1

        -- create some fields if we can!
        elseif currentChar == delimiterByte then
            -- create the new field
            -- print(headerField[fieldNum])
            if fieldsToKeep == nil or fieldsToKeep[headerField[fieldNum]] then
                field = createField(inputString, quote, fieldStart, i, doubleQuoteEscape)
            -- print("FIELD", field, "FIELDEND", headerField[fieldNum], lineNum)
            -- outResults[headerField[fieldNum]][lineNum] = field
                assignValue()
            end
            doubleQuoteEscape = false

            fieldNum = fieldNum + 1
            fieldStart = i + 1
            -- print("fs+1:", fieldStart)

        -- newline?!
        elseif (currentChar == CR or currentChar == LF) then
            if fieldsToKeep == nil or fieldsToKeep[headerField[fieldNum]] then
                -- create the new field
                field = createField(inputString, quote, fieldStart, i, doubleQuoteEscape)

                exit = assignValue()
                if exit then
                    if (currentChar == CR and nextChar == LF) then
                        return headerField, i + 1
                    else
                        return headerField, i
                    end
                end
            end
            doubleQuoteEscape = false

            -- determine how line ends
            if (currentChar == CR and nextChar == LF) then
                -- print("CRLF DETECTED")
                skipChar = 1
            end

            -- incrememnt for new line
            if fieldNum < initialLineCount then
                -- sometimes in buffered mode, the buffer starts with a newline
                -- this skips the newline and lets the parsing continue.
                if lineNum == 1 and fieldNum == 1 and buffered then
                    -- print("fieldNum", fieldNum)
                    -- print("initialLineCount", initialLineCount)
                    -- print("lineNum", lineNum)
                    -- print(i)
                    fieldStart = i + 1 + skipChar
                    lineStart = fieldStart
                else
                    -- return "YA"
                    error('ftcsv: too few columns in row ' .. lineNum)
                end
            else
                lineNum = lineNum + 1
                outResults[lineNum] = {}
                fieldNum = 1
                fieldStart = i + 1 + skipChar
                lineStart = fieldStart
                -- print("fs:", fieldStart)
            end

        end
        -- this happens when you can't find a closing quote - usually means in the middle of a buffer
        if i == nil and buffered then
            outResults[lineNum] = nil
            return outResults, lineStart
        end
        i = i + 1 + skipChar
        if (skipChar > 0) then
            currentChar = sbyte(inputString, i)
        else
            currentChar = nextChar
        end
        skipChar = 0
    end

    -- create last new field
    if fieldsToKeep == nil or fieldsToKeep[headerField[fieldNum]] then
        field = createField(inputString, quote, fieldStart, i, doubleQuoteEscape)
        assignValue()
    end

    -- check if outResults exists
    if outResults == nil and buffered then
        error("ftcsv: bufferSize needs to be larger to parse this file")
    -- if there's no newline, the parser doesn't return headers correctly...
    -- ex: a,b,c
    else
        return headerField, i-1
    end

    -- clean up last line if it's weird (this happens when there is a CRLF newline at end of file)
    -- doing a count gets it to pick up the oddballs
    local finalLineCount = 0
    local lastValue = nil
    for _, v in pairs(outResults[lineNum]) do
        finalLineCount = finalLineCount + 1
        lastValue = v
    end

    -- this indicates a CRLF
    -- print("Final/Initial", finalLineCount, initialLineCount)
    if finalLineCount == 1 and lastValue == "" then
        outResults[lineNum] = nil

    -- otherwise there might not be enough line
    elseif finalLineCount < initialLineCount then
        if buffered then
            outResults[lineNum] = nil
            -- print(#outResults)
            return outResults, lineStart
        else
            error('ftcsv: too few columns in row ' .. lineNum)
        end
    end

    -- print("Made it to the end?")
    -- print("i", i, "inputLength", inputLength)
    return outResults, i
end

local function handleHeaders(headerField, options)
    -- make sure a header isn't empty
    for _, headerName in ipairs(headerField) do
        if #headerName == 0 then
            error('ftcsv: Cannot parse a file which contains empty headers')
        end
    end

    -- for files where there aren't headers!
    if options.headers == false then
        for j = 1, #headerField do
            headerField[j] = j
        end
    end

    -- rename fields as needed!
    if options.rename then
        -- basic rename (["a" = "apple"])
        for j = 1, #headerField do
            if options.rename[headerField[j]] then
                -- print("RENAMING", headerField[j], options.rename[headerField[j]])
                headerField[j] = options.rename[headerField[j]]
            end
        end
        -- files without headers, but with a options.rename need to be handled too!
        if #options.rename > 0 then
            for j = 1, #options.rename do
                headerField[j] = options.rename[j]
            end
        end
    end

    -- apply some sweet header manipulation
    if options.headerFunc then
        for j = 1, #headerField do
            headerField[j] = options.headerFunc(headerField[j])
        end
    end

    return headerField
end

local function parseOptions(delimiter, options)
    -- delimiter MUST be one character
    assert(#delimiter == 1 and type(delimiter) == "string", "the delimiter must be of string type and exactly one character")

    -- OPTIONS yo
    local fieldsToKeep = nil

    if options then
        if options.headers ~= nil then
            assert(type(options.headers) == "boolean", "ftcsv only takes the boolean 'true' or 'false' for the optional parameter 'headers' (default 'true'). You passed in '" .. tostring(options.headers) .. "' of type '" .. type(options.headers) .. "'.")
        end
        if options.rename ~= nil then
            assert(type(options.rename) == "table", "ftcsv only takes in a key-value table for the optional parameter 'rename'. You passed in '" .. tostring(options.rename) .. "' of type '" .. type(options.rename) .. "'.")
        end
        if options.fieldsToKeep ~= nil then
            assert(type(options.fieldsToKeep) == "table", "ftcsv only takes in a list (as a table) for the optional parameter 'fieldsToKeep'. You passed in '" .. tostring(options.fieldsToKeep) .. "' of type '" .. type(options.fieldsToKeep) .. "'.")
            local ofieldsToKeep = options.fieldsToKeep
            if ofieldsToKeep ~= nil then
                fieldsToKeep = {}
                for j = 1, #ofieldsToKeep do
                    fieldsToKeep[ofieldsToKeep[j]] = true
                end
            end
            if options.headers == false and options.rename == nil then
                error("ftcsv: fieldsToKeep only works with header-less files when using the 'rename' functionality")
            end
        end
        if options.loadFromString ~= nil then
            assert(type(options.loadFromString) == "boolean", "ftcsv only takes a boolean value for optional parameter 'loadFromString'. You passed in '" .. tostring(options.loadFromString) .. "' of type '" .. type(options.loadFromString) .. "'.")
        end
        if options.headerFunc ~= nil then
            assert(type(options.headerFunc) == "function", "ftcsv only takes a function value for optional parameter 'headerFunc'. You passed in '" .. tostring(options.headerFunc) .. "' of type '" .. type(options.headerFunc) .. "'.")
        end
    else
        options = {
            ["headers"] = true,
            ["loadFromString"] = false
        }
    end

    return options, fieldsToKeep

end

-- runs the show!
function ftcsv.parse(inputFile, delimiter, options)
    -- make sure options make sense and get fields to keep
    local options, fieldsToKeep = parseOptions(delimiter, options)

    -- handle input via string or file!
    local inputString
    if options.loadFromString then inputString = inputFile
    else inputString = loadFile(inputFile) end

    -- if they sent in an empty file...
    if inputString == "" then
        error('ftcsv: Cannot parse an empty file')
    end

    -- parse through the headers!
    local headerField, i = parseString(inputString, delimiter, 1)
    -- reset the start if we don't have headers
    if options.headers == false then i = 0 else i = i + 1 end
    -- manipulate the headers as per the options
    headerField = handleHeaders(headerField, options)

    -- actually parse through the whole file
    local output = parseString(inputString, delimiter, i, headerField, fieldsToKeep)
    return output, headerField
end

function ftcsv.parseLine(inputFile, delimiter, bufferSize, options)
    -- make sure options make sense and get fields to keep
    local options, fieldsToKeep = parseOptions(delimiter, options)

    -- handle the file
    if options.loadFromString == true then
        error("ftcsv: parseLine currently doesn't support loading from string")
    end

    -- load it up!
    local file = io.open(inputFile, "r")
    if not file then error("ftcsv: File not found at " .. inputFile) end
    local inputString = file:read(bufferSize)
    -- if they sent in an empty file...
    if inputString == "" then
        error('ftcsv: Cannot parse an empty file')
    end

    -- parse through the headers!
    local headerField, i = parseString(inputString, delimiter, 1, nil, nil, true)
    -- reset the start if we don't have headers
    if options.headers == false then i = 0 else i = i + 1 end
    -- manipulate the headers as per the options
    headerField = handleHeaders(headerField, options)
    -- no longer needed!
    options = nil

    local parsedBuffer, startLine = parseString(inputString, delimiter, i, headerField, fieldsToKeep, true)
    inputString = string.sub(inputString, startLine)
    local parsedBufferIndex = 0

    return function()
        -- check parsed buffer for value
        parsedBufferIndex = parsedBufferIndex + 1
        local out = parsedBuffer[parsedBufferIndex]

        -- the last parsedBuffer value is incomplete, this avoids returning it
        -- if parsedBuffer[parsedBufferIndex+1] then
        if out then
            -- print("returning things")
            return out
        else
            -- reads more of the input
            local newInput = file:read(bufferSize)
            if not newInput then
                -- print("closing file")
                file:close()
                return
            end

            -- appends the new input to what was left over
            inputString = inputString .. newInput
            -- print("input string", #inputString, inputString)

            -- re-analyze and load buffer
            parsedBuffer, startLine = parseString(inputString, delimiter, 1, headerField, fieldsToKeep, true)
            parsedBufferIndex = 1

            -- cut the input string down
            -- print("startLine", startLine)
            inputString = string.sub(inputString, startLine)

            -- print("parsedBufferSize", #parsedBuffer)
            if #parsedBuffer == 0 then
                error("ftcsv: bufferSize needs to be larger to parse this file")
            end
            return parsedBuffer[parsedBufferIndex]
        end
    end
end

-- a function that delimits " to "", used by the writer
local function delimitField(field)
    field = tostring(field)
    if field:find('"') then
        return field:gsub('"', '""')
    else
        return field
    end
end

-- a function that compiles some lua code to quickly print out the csv
local function writer(inputTable, dilimeter, headers)
    -- they get re-created here if they need to be escaped so lua understands it based on how
    -- they came in
    for i = 1, #headers do
        if inputTable[1][headers[i]] == nil then
            error("ftcsv: the field '" .. headers[i] .. "' doesn't exist in the inputTable")
        end
        if headers[i]:find('"') then
            headers[i] = headers[i]:gsub('"', '\\"')
        end
    end

    local outputFunc = [[
        local state, i = ...
        local d = state.delimitField
        i = i + 1;
        if i > state.tableSize then return nil end;
        return i, '"' .. d(state.t[i]["]] .. table.concat(headers, [["]) .. '"]] .. dilimeter .. [["' .. d(state.t[i]["]]) .. [["]) .. '"\r\n']]

    -- print(outputFunc)

    local state = {}
    state.t = inputTable
    state.tableSize = #inputTable
    state.delimitField = delimitField

    return M.load(outputFunc), state, 0

end

-- takes the values from the headers in the first row of the input table
local function extractHeaders(inputTable)
    local headers = {}
    for key, _ in pairs(inputTable[1]) do
        headers[#headers+1] = key
    end

    -- lets make the headers alphabetical
    table.sort(headers)

    return headers
end

-- turns a lua table into a csv
-- works really quickly with luajit-2.1, because table.concat life
function ftcsv.encode(inputTable, delimiter, options)
    local output = {}

    -- dilimeter MUST be one character
    assert(#delimiter == 1 and type(delimiter) == "string", "the delimiter must be of string type and exactly one character")

    -- grab the headers from the options if they are there
    local headers = nil
    if options then
        if options.fieldsToKeep ~= nil then
            assert(type(options.fieldsToKeep) == "table", "ftcsv only takes in a list (as a table) for the optional parameter 'fieldsToKeep'. You passed in '" .. tostring(options.headers) .. "' of type '" .. type(options.headers) .. "'.")
            headers = options.fieldsToKeep
        end
    end
    if headers == nil then
        headers = extractHeaders(inputTable)
    end

    -- newHeaders are needed if there are quotes within the header
    -- because they need to be escaped
    local newHeaders = {}
    for i = 1, #headers do
        if headers[i]:find('"') then
            newHeaders[i] = headers[i]:gsub('"', '""')
        else
            newHeaders[i] = headers[i]
        end
    end
    output[1] = '"' .. table.concat(newHeaders, '"' .. delimiter .. '"') .. '"\r\n'

    -- add each line by line.
    for i, line in writer(inputTable, delimiter, headers) do
        output[i+1] = line
    end
    return table.concat(output)
end

return ftcsv

