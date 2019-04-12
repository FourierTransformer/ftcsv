local ftcsv = require('ftcsv')
local cjson = require('cjson')

local function loadFile(textFile)
    local file = io.open(textFile, "r")
    if not file then error("File not found at " .. textFile) end
    local allLines = file:read("*all")
    file:close()
    return allLines
end

describe("parseLine features small, working buffer size", function()
    it("should handle correctness", function()
        local json = loadFile("spec/json/correctness.json")
        json = cjson.decode(json)
        local parse = {}
        for i, line in ftcsv.parseLine("spec/csvs/correctness.csv", ",", 52) do
            assert.are.same(json[i], line)
            parse[i] = line
        end
        assert.are.same(#json, #parse)
        assert.are.same(json, parse)
    end)
end)

describe("parseLine features small, nonworking buffer size", function()
    it("should handle correctness", function()
        local test = function()
            local parse = {}
            for i, line in ftcsv.parseLine("spec/csvs/correctness.csv", ",", 63) do
                parse[i] = line
            end
            return parse
        end
        assert.has_error(test, "ftcsv: bufferSize needs to be larger to parse this file")
    end)
end)

describe("parseLine features smaller, nonworking buffer size", function()
    it("should handle correctness", function()
        local test = function()
            local parse = {}
            for i, line in ftcsv.parseLine("spec/csvs/correctness.csv", ",", 50) do
                parse[i] = line
            end
            return parse
        end
        assert.has_error(test, "ftcsv: bufferSize needs to be larger to parse this file")
    end)
end)

describe("smaller bufferSize than header and incorrect number of fields", function()
    it("should handle correctness", function()
        local test = function()
            local parse = {}
            for i, line in ftcsv.parseLine("spec/csvs/correctness.csv", ",", 23) do
                parse[i] = line
            end
            return parse
        end
        assert.has_error(test, "ftcsv: bufferSize needs to be larger to parse this file")
    end)
end)

describe("smaller bufferSize than header, but with correct field numbers", function()
    it("should handle correctness", function()
        local test = function()
            local parse = {}
            for i, line in ftcsv.parseLine("spec/csvs/correctness.csv", ",", 30) do
                parse[i] = line
            end
            return parse
        end
        assert.has_error(test, "ftcsv: bufferSize needs to be larger to parse this file")
    end)
end)