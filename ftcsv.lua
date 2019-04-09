local ftcsv = {
    _VERSION = 'ftcsv 1.2.0',
    _DESCRIPTION = 'CSV library for Lua',
    _URL         = 'https://github.com/FourierTransformer/ftcsv',
    _LICENSE     = [[
        The MIT License (MIT)

        Copyright (c) 2016-2018 Shakil Thakur

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
    ]],
    encode = require("encoder")
}

-- luajit/lua compatability layer
local luaCompatibility = {}

-- perf
local sbyte = string.byte
local ssub = string.sub

-- determine the real headers as opposed to the header mapping
local function determineRealHeaders(headerField, fieldsToKeep) 
    local realHeaders = {}
    local headerSet = {}
    for i = 1, #headerField do
        if not headerSet[headerField[i]] then
            if fieldsToKeep ~= nil and fieldsToKeep[headerField[i]] then
                table.insert(realHeaders, headerField[i])
                headerSet[headerField[i]] = true
            elseif fieldsToKeep == nil then
                table.insert(realHeaders, headerField[i])
                headerSet[headerField[i]] = true
            end
        end
    end
    return realHeaders
end

-- luajit specific speedups
-- luajit performs faster with iterating over string.byte,
-- whereas vanilla lua performs faster with string.find
if type(jit) == 'table' then
    luaCompatibility.LuaJIT = true
    -- finds the end of an escape sequence
    function luaCompatibility.findClosingQuote(i, inputLength, inputString, quote, doubleQuoteEscape)
        local currentChar, nextChar = sbyte(inputString, i), nil
        while i <= inputLength do
            nextChar = sbyte(inputString, i+1)

            -- this one deals with " double quotes that are escaped "" within single quotes "
            -- these should be turned into a single quote at the end of the field
            if currentChar == quote and nextChar == quote then
                doubleQuoteEscape = true
                i = i + 2
                currentChar = sbyte(inputString, i)

            -- identifies the escape toggle
            elseif currentChar == quote and nextChar ~= quote then
                return i-1, doubleQuoteEscape
            else
                i = i + 1
                currentChar = nextChar
            end
        end
    end

else
    luaCompatibility.LuaJIT = false

    -- vanilla lua closing quote finder
    function luaCompatibility.findClosingQuote(i, inputLength, inputString, quote, doubleQuoteEscape)
        local j, difference
        i, j = inputString:find('"+', i)
        if j == nil then return end
        if i == nil then
            return inputLength-1, doubleQuoteEscape
        end
        difference = j - i
        if difference >= 1 then doubleQuoteEscape = true end
        if difference == 1 then
            return luaCompatibility.findClosingQuote(j+1, inputLength, inputString, quote, doubleQuoteEscape)
        end
        return j-1, doubleQuoteEscape
    end
end

local function determineTotalColumnCount(headerField, fieldsToKeep)
    local totalColumnCount = 0
    local headerFieldSet = {}
    for _, header in pairs(headerField) do
        -- count unique columns and
        -- also figure out if it's a field to keep
        if not headerFieldSet[header] and
            (fieldsToKeep == nil or fieldsToKeep[header]) then
            headerFieldSet[header] = true
            totalColumnCount = totalColumnCount + 1
        end
    end
    return totalColumnCount
end

local function createOutputMetaTable(finalHeaders)
    local rawSetup = "local t, k, _ = ... \
    rawset(t, k, {[ [[%s]] ]=true})"
    rawSetup = rawSetup:format(table.concat(finalHeaders, "]] ]=true, [ [["))

    if _ENV then
        return _G.load(rawSetup)
    else
        return loadstring(rawSetup)
    end
end

-- main function used to parse
local function parseString(inputString, i, options)

    -- keep track of my chars!
    local inputLength = options.inputLength or #inputString
    local currentChar, nextChar = sbyte(inputString, i), nil
    local skipChar = 0
    local field
    local fieldStart = i
    local fieldNum = 1
    local lineNum = 1
    local lineStart = i
    local doubleQuoteEscape, emptyIdentified = false, false

    local skipIndex
    local charPatternToSkip = "[" .. options.delimiter .. "\r\n]"

    --bytes
    local CR = sbyte("\r")
    local LF = sbyte("\n")
    local quote = sbyte('"')
    local delimiterByte = sbyte(options.delimiter)

    -- explode most used options
    local fieldsToKeep = options.fieldsToKeep
    local headerField = options.headerField
    local buffered = options.buffered
    local ignoreQuotes = options.ignoreQuotes
    local outputMetaTable = options.outputMetaTable

    local outResults = {}

    -- in the first run, the headers haven't been set yet.
    if headerField == nil then
        headerField = {}
        -- setup a metatable to simply return the key that's passed in
        local headerMeta = {__index = function(_, key) return key end}
        setmetatable(headerField, headerMeta)
    end

    if outputMetaTable then
        setmetatable(outResults, {__newindex = outputMetaTable})
    end
    outResults[1] = {}

    -- totalColumnCount based on unique headers and fieldsToKeep
    local totalColumnCount = options.totalColumnCount or determineTotalColumnCount(headerField, fieldsToKeep)

    local function assignValueToField()
        if fieldsToKeep == nil or fieldsToKeep[headerField[fieldNum]] then

            -- create new field
            if sbyte(inputString, i-1) == quote then
                field = ssub(inputString, fieldStart, i-2)
            else
                field = ssub(inputString, fieldStart, i-1)
            end
            if doubleQuoteEscape then
                field = field:gsub('""', '"')
            end

            -- reset flags
            doubleQuoteEscape = false
            emptyIdentified = false

            -- assign field in output
            if headerField[fieldNum] ~= nil then
                outResults[lineNum][headerField[fieldNum]] = field
            else
                error('ftcsv: too many columns in row ' .. options.rowOffset + lineNum)
            end
        end
    end

    while i <= inputLength do
        -- go by two chars at a time,
        --  currentChar is set at the bottom.
        nextChar = sbyte(inputString, i+1)

        -- empty string
        if ignoreQuotes == false and currentChar == quote and nextChar == quote then
            skipChar = 1
            fieldStart = i + 2
            emptyIdentified = true

        -- escape toggle.
        -- This can only happen if fields have quotes around them
        -- so the current "start" has to be where a quote character is.
        elseif ignoreQuotes == false and currentChar == quote and nextChar ~= quote and fieldStart == i then
            fieldStart = i + 1
            -- if an empty field was identified before assignment, it means
            -- that this is a quoted field that starts with escaped quotes
            -- ex: """a"""
            if emptyIdentified then
                fieldStart = fieldStart - 2
                emptyIdentified = false
            end
            skipChar = 1
            i, doubleQuoteEscape = luaCompatibility.findClosingQuote(i+1, inputLength, inputString, quote, doubleQuoteEscape)

        -- create some fields
        elseif currentChar == delimiterByte then
            assignValueToField()

            -- increaseFieldIndices
            fieldNum = fieldNum + 1
            fieldStart = i + 1

        -- newline
        elseif (currentChar == LF or currentChar == CR) then
            assignValueToField()

            -- handle CRLF
            if (currentChar == CR and nextChar == LF) then
                skipChar = 1
                fieldStart = fieldStart + 1
            end

            -- incrememnt for new line
            if fieldNum < totalColumnCount then
                -- sometimes in buffered mode, the buffer starts with a newline
                -- this skips the newline and lets the parsing continue.
                if lineNum == 1 and fieldNum == 1 and buffered then
                    fieldStart = i + 1 + skipChar
                    lineStart = fieldStart
                else
                    error('ftcsv: too few columns in row ' .. options.rowOffset + lineNum)
                end
            else
                lineNum = lineNum + 1
                outResults[lineNum] = {}
                fieldNum = 1
                fieldStart = i + 1 + skipChar
                lineStart = fieldStart
            end

        elseif luaCompatibility.LuaJIT == false then
            skipIndex = inputString:find(charPatternToSkip, i)
            if skipIndex then
                skipChar = skipIndex - i - 1
            end

        end

        -- in buffered mode and it can't find the closing quote
        -- it usually means in the middle of a buffer and need to backtrack
        if i == nil and buffered then
            outResults[lineNum] = nil
            return outResults, lineStart
        end

        -- Increment Counter
        i = i + 1 + skipChar
        if (skipChar > 0) then
            currentChar = sbyte(inputString, i)
        else
            currentChar = nextChar
        end
        skipChar = 0
        end

    -- create last new field
    assignValueToField()

    -- check if outResults exists
    -- TODO: better buffer handling
    if outResults == nil and buffered then
        error("ftcsv: bufferSize needs to be larger to parse this file")
    end

    -- remove last field if empty
    -- TODO: look into buffered here, as there's likely an edge case here.
    if fieldNum < totalColumnCount then

        -- indicates last field was really just a CRLF,
        -- so, it can be removed
        if fieldNum == 1 and field == "" then
            outResults[lineNum] = nil
        else

            -- TODO: look into buffered... this is basically a side effect right now
            if buffered then
                outResults[lineNum] = nil
                return outResults, lineStart
            else
                error('ftcsv: too few columns in row ' .. options.rowOffset + lineNum)
            end
        end
    end

    return outResults, i, totalColumnCount
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

-- load an entire file into memory
local function loadFile(textFile, amount)
    local file = io.open(textFile, "r")
    if not file then error("ftcsv: File not found at " .. textFile) end
    local lines = file:read(amount)
    if amount == "*all" then
        file:close()
    end
    return lines, file
end

local function initializeInputFromStringOrFile(inputFile, options, amount)
    -- handle input via string or file!
    local inputString, file
    if options.loadFromString then
        inputString = inputFile
    else
        inputString, file = loadFile(inputFile, amount)
    end

    -- if they sent in an empty file...
    if inputString == "" then
        error('ftcsv: Cannot parse an empty file')
    end
    return inputString, file
end

local function parseOptions(delimiter, options)
    -- delimiter MUST be one character
    assert(#delimiter == 1 and type(delimiter) == "string", "the delimiter must be of string type and exactly one character")

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
        if options.ignoreQuotes == nil then
            options.ignoreQuotes = false
        else
            assert(type(options.loadFromString) == "boolean", "ftcsv only takes a boolean value for optional parameter 'ignoreQuotes'. You passed in '" .. tostring(options.ignoreQuotes) .. "' of type '" .. type(options.ignoreQuotes) .. "'.")
        end
    else
        options = {
            ["headers"] = true,
            ["loadFromString"] = false,
            ["ignoreQuotes"] = false
        }
    end

    return options, fieldsToKeep

end

local function findEndOfHeaders(str)
    local i = 1
    local quote = sbyte('"')
    local newlines = {
        [sbyte("\n")] = true,
        [sbyte("\r")] = true
    }
    local quoted = false
    local char = sbyte(str, i)
    local oldchar
    repeat
        -- this should still work for escaped quotes
        -- ex: " a "" b \r\n " -- there is always a pair around the newline
        if char == quote then
            quoted = not quoted
        end
        i = i + 1
        oldchar = char
        char = sbyte(str, i)
    until (newlines[char] and not quoted) or char == nil
    if oldchar == sbyte("\r") and char == sbyte("\n") then
        i = i + 1
    end
    return i
end

local function determineBOMOffset(inputString)
    if sbyte(inputString, 1) == 239
        and sbyte(inputString, 2) == 187
        and sbyte(inputString, 3) == 191 then
        return 4
    else
        return 1
    end
end

local function parseHeadersAndSetupArgs(inputString, delimiter, options, fieldsToKeep)
    local startLine = determineBOMOffset(inputString)

    local endOfHeaderRow = findEndOfHeaders(inputString)

    local parserArgs = {
        delimiter = delimiter,
        headerField = nil,
        fieldsToKeep = nil,
        inputLength = endOfHeaderRow,
        buffered = false,
        ignoreQuotes = options.ignoreQuotes,
        rowOffset = 0
    }

    local rawHeaders, endOfHeaders = parseString(inputString, startLine, parserArgs)

    -- manipulate the headers as per the options
    local modifiedHeaders = handleHeaders(rawHeaders[1], options)
    parserArgs.headerField = modifiedHeaders
    parserArgs.fieldsToKeep = fieldsToKeep
    parserArgs.inputLength = nil

    if options.headers == false then endOfHeaders = startLine end

    local finalHeaders = determineRealHeaders(modifiedHeaders, fieldsToKeep)
    if options.headers ~= false then
        local outputMetaTable = createOutputMetaTable(finalHeaders)
        parserArgs.outputMetaTable = outputMetaTable
    end

    return endOfHeaders, parserArgs, finalHeaders
end

-- runs the show!
function ftcsv.parse(inputFile, delimiter, options)
    local options, fieldsToKeep = parseOptions(delimiter, options)

    local inputString = initializeInputFromStringOrFile(inputFile, options, "*all")

    local endOfHeaders, parserArgs, finalHeaders = parseHeadersAndSetupArgs(inputString, delimiter, options, fieldsToKeep)

    local output = parseString(inputString, endOfHeaders, parserArgs)

    return output, finalHeaders
end

local function initializeInputFile(inputString, options, bufferSize)
    if options.loadFromString == true then
        error("ftcsv: parseLine currently doesn't support loading from string")
    end
    return initializeInputFromStringOrFile(inputString, options, bufferSize)
end

function ftcsv.parseLine(inputFile, delimiter, bufferSize, options)
    -- make sure options make sense and get fields to keep
    local options, fieldsToKeep = parseOptions(delimiter, options)

    local inputString, file = initializeInputFile(inputFile, options, bufferSize)

    local endOfHeaders, parserArgs, _ = parseHeadersAndSetupArgs(inputString, delimiter, options, fieldsToKeep)
    parserArgs.buffered = true

    local parsedBuffer, endOfParsedInput, totalColumnCount = parseString(inputString, endOfHeaders, parserArgs)
    parserArgs.totalColumnCount = totalColumnCount

    inputString = ssub(inputString, endOfParsedInput)
    local bufferIndex, returnedRowsCount = 0, 0
    local currentRow, newInput

    return function()
        -- check parsed buffer for value
        bufferIndex = bufferIndex + 1
        currentRow = parsedBuffer[bufferIndex]
        if currentRow then
            returnedRowsCount = returnedRowsCount + 1
            return returnedRowsCount, currentRow
        end

        -- read more of the input
        newInput = file:read(bufferSize)
        if not newInput then
            file:close()
            return nil
        end

        -- appends the new input to what was left over
        inputString = inputString .. newInput

        -- re-analyze and load buffer
        parserArgs.rowOffset = returnedRowsCount
        parsedBuffer, endOfParsedInput = parseString(inputString, 1, parserArgs)
        bufferIndex = 1

        -- cut the input string down
        inputString = ssub(inputString, endOfParsedInput)

        if #parsedBuffer == 0 then
            error("ftcsv: bufferSize needs to be larger to parse this file")
        end

        returnedRowsCount = returnedRowsCount + 1
        return returnedRowsCount, parsedBuffer[bufferIndex]
    end
end

return ftcsv

