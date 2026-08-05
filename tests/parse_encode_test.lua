local cjson = require("cjson")
local ftcsv = require('ftcsv')
local tested = require("tested")

local function loadFile(textFile)
    local file = io.open(textFile, "r")
    if not file then error("File not found at " .. textFile) end
    local allLines = file:read("*all")
    file:close()
    return allLines
end

local files = {
    "bom-os9",
    "comma_in_quotes",
    "correctness",
    "empty",
    "empty_no_newline",
    "empty_no_quotes",
    "empty_crlf",
    "escaped_quotes",
    "escaped_quotes_in_header",
    "json",
    "json_no_newline",
    "newlines",
    "newlines_crlf",
    "os9",
    "quotes_and_newlines",
    "quotes_non_escaped",
    "simple",
    "simple_crlf",
    "utf8"
}

tested.test("csv decode", function()
    for _, value in ipairs(files) do
        local json = loadFile("tests/json/" .. value .. ".json")
        json = cjson.decode(json)
        local parse = ftcsv.parse("tests/csvs/" .. value .. ".csv", ",")
        tested.assert({
            given="tests/csvs/" .. value .. ".csv",
            should="handle " .. value,
            expected=json,
            actual=parse
        })
    end
end)

tested.test("csv parseLine decode", function()
    for _, value in ipairs(files) do
        local json = loadFile("tests/json/" .. value .. ".json")
        json = cjson.decode(json)
        local parse = {}
        for i, v in ftcsv.parseLine("tests/csvs/" .. value .. ".csv", ",") do
            parse[i] = v
        end
        tested.assert({
            given="tests/csvs/" .. value .. ".csv",
            should="handle " .. value,
            expected = json,
            actual=parse
        })
    end
end)

tested.test("csv decode from string", function()
    for _, value in ipairs(files) do
        local contents = loadFile("tests/csvs/" .. value .. ".csv")
        local json = loadFile("tests/json/" .. value .. ".json")
        json = cjson.decode(json)
        local parse = ftcsv.parse(contents, ",", {loadFromString=true})
        tested.assert({
            given="tests/csvs/" .. value .. ".csv",
            should="handle " .. value,
            expected = json,
            actual=parse
        })
    end
end)

tested.test("csv reencode", function()
    for _, value in ipairs(files) do
        local jsonFile = loadFile("tests/json/" .. value .. ".json")
        local jsonDecode = cjson.decode(jsonFile)
        local reEncoded = ftcsv.parse(ftcsv.encode(jsonDecode, ","), ",", {loadFromString=true})
        tested.assert({
            given="tests/json/" .. value .. ".json",
            should="handle " .. value,
            expected = jsonDecode,
            actual=reEncoded
        })
    end
end)

tested.test("csv encode without a delimiter", function()
    for _, value in ipairs(files) do
        local jsonFile = loadFile("tests/json/" .. value .. ".json")
        local jsonDecode = cjson.decode(jsonFile)
        local reEncoded = ftcsv.parse(ftcsv.encode(jsonDecode), ",", {loadFromString=true})
        tested.assert({
            given="tests/json/" .. value .. ".json",
            should="handle " .. value,
            expected = jsonDecode,
            actual=reEncoded
        })
    end
end)

tested.test("csv encode with a delimiter specified in options", function()
    for _, value in ipairs(files) do
        local jsonFile = loadFile("tests/json/" .. value .. ".json")
        local jsonDecode = cjson.decode(jsonFile)
        local reEncoded = ftcsv.parse(ftcsv.encode(jsonDecode, {delimiter="\t"}), {delimiter="\t", loadFromString=true})
        tested.assert({
            given="tests/json/" .. value .. ".json",
            should="handle " .. value,
            expected = jsonDecode,
            actual=reEncoded
        })
    end
end)

tested.test("csv encode without quotes", function()
    for _, value in ipairs(files) do
        local jsonFile = loadFile("tests/json/" .. value .. ".json")
        local jsonDecode = cjson.decode(jsonFile)
        local reEncodedNoQuotes = ftcsv.parse(ftcsv.encode(jsonDecode, ",", {onlyRequiredQuotes=true}), ",", {loadFromString=true})
        tested.assert({
            given="tests/json/" .. value .. ".json",
            should="handle " .. value,
            expected = jsonDecode,
            actual=reEncodedNoQuotes
        })
    end
end)

tested.test("csv encode with missing keys", function()
    local jsonFile = loadFile("tests/json/missing_keys.json")
    local jsonDecode = cjson.decode(jsonFile)
    local reEncoded = ftcsv.parse(ftcsv.encode(
        jsonDecode, ",", {
            fieldsToKeep = {"a", "b", "c", "d"},
            allowMissingKeys = true,
        }
    ), ",", {loadFromString=true})
    tested.assert({
        given="tests/json/missing_keys.json",
        should="handle missing_keys",
        expected = jsonDecode,
        actual=reEncoded
    })
end)

tested.test("csv encode with selective omissions", function()
    local jsonFile = loadFile("tests/json/correctness.json")
    local jsonDecode = cjson.decode(jsonFile)
    local reEncoded = ftcsv.parse(ftcsv.encode(
        jsonDecode, ",", {
            fieldsToKeep = {"Model", "Price", "Year"},
            headers = false,
        }
    ), ",", {loadFromString=true, headers=false})
    local exp = ftcsv.parse("tests/csvs/no_headers.csv", {headers = false})
    tested.assert({
        given="spec/csvs/no_header.csv loaded without headers",
        should="be the same as spec/json/correctness.json encoded without headers",
        expected = exp,
        actual = reEncoded
    })
end)

return tested