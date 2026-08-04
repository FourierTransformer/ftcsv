local ftcsv = require('ftcsv')
local cjson = require('cjson')
local tested = require("tested")

local function loadFile(textFile)
    local file = io.open(textFile, "r")
    if not file then error("File not found at " .. textFile) end
    local allLines = file:read("*all")
    file:close()
    return allLines
end

tested.test("parseLine features small, working buffer size", function()
    local json = loadFile("tests/json/correctness.json")
    json = cjson.decode(json)
    local parse = {}
    for i, line in ftcsv.parseLine("tests/csvs/correctness.csv", ",", {bufferSize=52}) do
        parse[i] = line
    end
    tested.assert({
        given="tests/json/correctness.json",
        should="handle correctness",
        expected=json,
        actual=parse
    })
end)

tested.test("parseLine features small, nonworking buffer size", function()
    local test = function()
        local parse = {}
        for i, line in ftcsv.parseLine("tests/csvs/correctness.csv", ",", {bufferSize=63}) do
            parse[i] = line
        end
        return parse
    end
    tested.assert_throws_exception({
        given="nonworking buffersize",
        expected="ftcsv: bufferSize needs to be larger to parse this file",
        actual=test
    })
end)

tested.test("parseLine features smaller, nonworking buffer size", function()
    local test = function()
        local parse = {}
        for i, line in ftcsv.parseLine("tests/csvs/correctness.csv", ",", {bufferSize=50}) do
            parse[i] = line
        end
        return parse
    end
    tested.assert_throws_exception({
        given="nonworking buffersize",
        expected="ftcsv: bufferSize needs to be larger to parse this file",
        actual=test
    })
end)

tested.test("smaller bufferSize than header and incorrect number of fields", function()
    local test = function()
        local parse = {}
        for i, line in ftcsv.parseLine("tests/csvs/correctness.csv", ",", {bufferSize=23}) do
            parse[i] = line
        end
        return parse
    end
    tested.assert_throws_exception({
        given="nonworking buffersize",
        expected="ftcsv: bufferSize needs to be larger to parse this file",
        actual=test
    })
end)

tested.test("smaller bufferSize than header, but with correct field numbers", function()
    local test = function()
        local parse = {}
        for i, line in ftcsv.parseLine("tests/csvs/correctness.csv", ",", {bufferSize=30}) do
            parse[i] = line
        end
        return parse
    end
    tested.assert_throws_exception({
        given="nonworking buffersize",
        expected="ftcsv: bufferSize needs to be larger to parse this file",
        actual=test
    })
end)

tested.test("parseLine with options but not bufferSize", function()

    local json = loadFile("tests/json/correctness.json")
    json = cjson.decode(json)

    local parse = {}
    for i, line in ftcsv.parseLine("tests/csvs/correctness.csv", ",", {rename={["Year"] = "Full Year"}}) do
	   parse[i] = line
    end
    tested.assert({
        given="tests/csvs/correctness.csv",
        should="be the same size, even though renamed",
        expected=#json,
        actual=#parse
    })
end)

tested.test("parseLine features small, working buffer size without delimiter", function()
    local json = loadFile("tests/json/correctness.json")
    json = cjson.decode(json)
    local parse = {}
    for i, line in ftcsv.parseLine("tests/csvs/correctness.csv", {bufferSize=52}) do
        parse[i] = line
    end
    tested.assert({
        given="tests/csvs/correctness.csv",
        expected=json,
        actual=parse
    })
end)

tested.test("parseLine features small, nonworking buffer size without delimiter", function()
    local test = function()
        local parse = {}
        for i, line in ftcsv.parseLine("tests/csvs/correctness.csv", {bufferSize=63}) do
            parse[i] = line
        end
        return parse
    end
    tested.assert_throws_exception({
        given="nonworking buffersize",
        expected="ftcsv: bufferSize needs to be larger to parse this file",
        actual=test
    })  
end)

tested.test("parseLine features smaller, nonworking buffer size without delimiter", function()
    local test = function()
        local parse = {}
        for i, line in ftcsv.parseLine("tests/csvs/correctness.csv", {bufferSize=50}) do
            parse[i] = line
        end
        return parse
    end
    tested.assert_throws_exception({
        given="nonworking buffersize",
        expected="ftcsv: bufferSize needs to be larger to parse this file",
        actual=test
    }) 
end)

tested.test("smaller bufferSize than header and incorrect number of fields without delimiter", function()
    local test = function()
        local parse = {}
        for i, line in ftcsv.parseLine("tests/csvs/correctness.csv", {bufferSize=23}) do
            parse[i] = line
        end
        return parse
    end
    tested.assert_throws_exception({
        given="nonworking buffersize",
        expected="ftcsv: bufferSize needs to be larger to parse this file",
        actual=test
    }) 
end)

tested.test("smaller bufferSize than header, but with correct field numbers without delimiter", function()
    local test = function()
        local parse = {}
        for i, line in ftcsv.parseLine("tests/csvs/correctness.csv", {bufferSize=30}) do
            parse[i] = line
        end
        return parse
    end
    tested.assert_throws_exception({
        given="nonworking buffersize",
        expected="ftcsv: bufferSize needs to be larger to parse this file",
        actual=test
    }) 
end)

tested.test("parseLine with options but not bufferSize without delimiter", function()
    local json = loadFile("tests/json/correctness.json")
    json = cjson.decode(json)

    local parse = {}
    for i, line in ftcsv.parseLine("tests/csvs/correctness.csv", {rename={["Year"] = "Full Year"}}) do
        parse[i] = line
    end
    tested.assert({
        given="tests/csvs/correctness.csv",
        should="be the same size, even though renamed",
        expected=#json,
        actual=#parse
    })

end)

return tested