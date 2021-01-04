local ftcsv = {
    _VERSION = 'ftcsv 1.2.0',
    _DESCRIPTION = 'CSV library for Lua',
    _URL         = 'https://github.com/FourierTransformer/ftcsv',
    _LICENSE     = [[
        The MIT License (MIT)

        Copyright (c) 2016-2020 Shakil Thakur

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

-- luajit/lua compatability layer
global jit: table
global _ENV: table
global loadstring: function(string)
local luaCompatibility: {string: function(string)} = {}
if type(jit) == 'table' or _ENV then
    -- luajit and lua 5.2+
    luaCompatibility.load = _G.load
else
    -- lua 5.1
    luaCompatibility.load = loadstring
end

-- The ENCODER code is below here
-- This could be broken out, but is kept here for portability

local type EncoderOptions = record
    fieldsToKeep: {string}
end
local type GeneratorArgs = record
    t: {CSVRow}
    delimitField: function(string): string
end
local type CSVRow = {string: any}


local function delimitField(field: string): string
    field = tostring(field)
    if field:find('"') then
        return field:gsub('"', '""')
    else
        return field
    end
end

local function escapeHeadersForLuaGenerator(headers: {string}): {string}
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
local function csvLineGenerator(inputTable: {CSVRow}, delimiter: string, headers: {string}): (function(string): (number, string), GeneratorArgs, number)
    local escapedHeaders = escapeHeadersForLuaGenerator(headers)

    local outputFunc = [[
        local args, i = ...
        i = i + 1;
        if i > ]] .. #inputTable .. [[ then return nil end;
        return i, '"' .. args.delimitField(args.t[i]["]] ..
            table.concat(escapedHeaders, [["]) .. '"]] ..
            delimiter .. [["' .. args.delimitField(args.t[i]["]]) ..
            [["]) .. '"\r\n']]

    local arguments: GeneratorArgs = {}
    arguments.t = inputTable
    -- we want to use the same delimitField throughout,
    -- so we're just going to pass it in
    arguments.delimitField = delimitField

    return luaCompatibility.load(outputFunc), arguments, 0

end

local function validateHeaders(headers: {string}, inputTable: {CSVRow})
    for i = 1, #headers do
        if inputTable[1][headers[i]] == nil then
            error("ftcsv: the field '" .. headers[i] .. "' doesn't exist in the inputTable")
        end
    end
end

local function initializeOutputWithEscapedHeaders(escapedHeaders: {string}, delimiter: string): {string}
    local output = {}
    output[1] = '"' .. table.concat(escapedHeaders, '"' .. delimiter .. '"') .. '"\r\n'
    return output
end

local function escapeHeadersForOutput(headers: {string}): {string}
    local escapedHeaders = {}
    for i = 1, #headers do
        escapedHeaders[i] = delimitField(headers[i])
    end
    return escapedHeaders
end

local function extractHeadersFromTable(inputTable: {CSVRow}): {string}
    local headers = {}
    for key, _ in pairs(inputTable[1]) do
        headers[#headers+1] = key
    end

    -- lets make the headers alphabetical
    table.sort(headers)

    return headers
end

local function getHeadersFromOptions(options: EncoderOptions): {string}
    local headers: {string} = nil
    if options then
        if options.fieldsToKeep ~= nil then
            assert(
                type(options.fieldsToKeep) == "table", "ftcsv only takes in a list (as a table) for the optional parameter 'fieldsToKeep'. You passed in '" .. tostring(options.fieldsToKeep) .. "' of type '" .. type(options.fieldsToKeep) .. "'.")
            headers = options.fieldsToKeep

        end
    end
    return headers
end

local function initializeGenerator(inputTable: {CSVRow}, delimiter: string, options: EncoderOptions): ({string}, {string})
    -- delimiter MUST be one character
    assert(#delimiter == 1 and type(delimiter) == "string", "the delimiter must be of string type and exactly one character")

    local headers = getHeadersFromOptions(options)
    if headers == nil then
        headers = extractHeadersFromTable(inputTable)
    end
    validateHeaders(headers, inputTable)

    local escapedHeaders = escapeHeadersForOutput(headers)
    local output = initializeOutputWithEscapedHeaders(escapedHeaders, delimiter)
    return output, headers
end

-- works really quickly with luajit-2.1, because table.concat life
function ftcsv.encode(inputTable: {CSVRow}, delimiter: string, options: EncoderOptions): string
    local output, headers = initializeGenerator(inputTable, delimiter, options)

    for i, line in csvLineGenerator(inputTable, delimiter, headers) do
        output[i+1] = line
    end

    -- combine and return final string
    return table.concat(output)
end

return ftcsv

