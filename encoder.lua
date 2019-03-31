-- CSV Encoder for ftcsv

local luaCompatibility = {}
if type(jit) == 'table' or _ENV then
    -- luajit and lua 5.2+
    luaCompatibility.load = _G.load
else
    -- lua 5.1
    luaCompatibility.load = loadstring
end

local function delimitField(field)
    field = tostring(field)
    if field:find('"') then
        return field:gsub('"', '""')
    else
        return field
    end
end

local function escapeHeadersForLuaGenerator(headers)
    local escapedHeaders = {}
    for i = 1, #headers do
        if headers[i]:find('"') then
            escapedHeaders[i] = headers[i]:gsub('"', '\\"')
        else
            escapedHeaders[i] = headers[i]
        end
    end
    return escapedHeaders
end

-- a function that compiles some lua code to quickly print out the csv
local function csvLineGenerator(inputTable, delimiter, headers)
    local escapedHeaders = escapeHeadersForLuaGenerator(headers)

    local outputFunc = [[
        local args, i = ...
        i = i + 1;
        if i > ]] .. #inputTable .. [[ then return nil end;
        return i, '"' .. args.delimitField(args.t[i]["]] ..
            table.concat(escapedHeaders, [["]) .. '"]] ..
            delimiter .. [["' .. args.delimitField(args.t[i]["]]) ..
            [["]) .. '"\r\n']]

    local arguments = {}
    arguments.t = inputTable
    -- we want to use the same delimitField throughout,
    -- so we're just going to pass it in
    arguments.delimitField = delimitField

    return luaCompatibility.load(outputFunc), arguments, 0

end

local function validateHeaders(headers, inputTable)
    for i = 1, #headers do
        if inputTable[1][headers[i]] == nil then
            error("ftcsv: the field '" .. headers[i] .. "' doesn't exist in the inputTable")
        end
    end
end

local function initializeOutputWithEscapedHeaders(escapedHeaders, delimiter)
    local output = {}
    output[1] = '"' .. table.concat(escapedHeaders, '"' .. delimiter .. '"') .. '"\r\n'
    return output
end

local function escapeHeadersForOutput(headers)
    local escapedHeaders = {}
    for i = 1, #headers do
        escapedHeaders[i] = delimitField(headers[i])
    end
    return escapedHeaders
end

local function extractHeadersFromTable(inputTable)
    local headers = {}
    for key, _ in pairs(inputTable[1]) do
        headers[#headers+1] = key
    end

    -- lets make the headers alphabetical
    table.sort(headers)

    return headers
end

local function getHeadersFromOptions(options)
    local headers = nil
    if options then
        if options.fieldsToKeep ~= nil then
            assert(
                type(options.fieldsToKeep) == "table", "ftcsv only takes in a list (as a table) for the optional parameter 'fieldsToKeep'. You passed in '" .. tostring(options.headers) .. "' of type '" .. type(options.headers) .. "'.")
            headers = options.fieldsToKeep
        end
    end
    return headers
end

-- works really quickly with luajit-2.1, because table.concat life
local function encode(inputTable, delimiter, options)
    -- delimiter MUST be one character
    assert(#delimiter == 1 and type(delimiter) == "string", "the delimiter must be of string type and exactly one character")

    local headers = getHeadersFromOptions(options)
    if headers == nil then
        headers = extractHeadersFromTable(inputTable)
    end
    validateHeaders(headers, inputTable)

    local escapedHeaders = escapeHeadersForOutput(headers)
    local output = initializeOutputWithEscapedHeaders(escapedHeaders, delimiter)

    for i, line in csvLineGenerator(inputTable, delimiter, headers) do
        output[i+1] = line
    end

    -- combine and return final string
    return table.concat(output)
end

return encode
