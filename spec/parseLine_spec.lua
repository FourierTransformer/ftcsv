local ftcsv = require('ftcsv')
local cjson = require('cjson')

local function loadFile(textFile)
    local file = io.open(textFile, "r")
    if not file then error("File not found at " .. textFile) end
    local allLines = file:read("*all")
    file:close()
    return allLines
end

describe("parseLine features", function()
    for i = 52, 52 do
    it("should handle correctness" .. i, function()
        local json = loadFile("spec/json/correctness.json")
        json = cjson.decode(json)
        local parse = {}
        for i, line in ftcsv.parseLine("spec/csvs/correctness.csv", ",", i) do
            assert.are.same(json[i], line)
            parse[i] = line
        end
        assert.are.same(#json, #parse)
        assert.are.same(json, parse)
    end)
    end
end)