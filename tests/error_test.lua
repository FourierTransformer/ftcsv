local ftcsv = require('ftcsv')
local tested = require("tested")

local files = {
    {"empty_file", "ftcsv: Cannot parse an empty file"},
    {"empty_file_newline", "ftcsv: Cannot parse a file which contains empty headers"},
    {"empty_header", "ftcsv: Cannot parse a file which contains empty headers"},
    {"too_few_cols", "ftcsv: too few columns in row 1"},
    {"too_few_cols_end", "ftcsv: too few columns in row 2"},
    {"too_many_cols", "ftcsv: too many columns in row 2"},
    {"dne", "ftcsv: File not found at spec/bad_csvs/dne.csv"}
}

tested.test("csv decode error", function()
    for _, value in ipairs(files) do
        local filename = "spec/bad_csvs/" .. value[1] .. ".csv"
        tested.assert_throws_exception({
            given=filename,
            should="throw specific exception",
            expected=value[2],
            actual=function() ftcsv.parse(filename, ",") end
        })
    end
end)

tested.test("no headers or renaming", function()
    local test = function()
        local options = {loadFromString=true, headers=false, fieldsToKeep={1, 2}}
        ftcsv.parse("apple>banana>carrot\ndiamond>emerald>pearl", ">", options)
    end
    tested.assert_throws_exception({
        given="no headers and no renaming takes place",
        expected="ftcsv: fieldsToKeep only works with header-less files when using the 'rename' functionality",
        actual=test
    })

end)


tested.test("encode error out with missing field", function()
    local encodeThis = {
        {a = 'herp1', b = 'derp1'},
        {a = 'herp2', b = 'derp2'},
        {a = 'herp3', b = 'derp3'},
    }

    local test = function()
        ftcsv.encode(encodeThis, ">", {fieldsToKeep={"c"}})
    end

    tested.assert_throws_exception({
        given="specify a field that doesn't exist during encode",
        expected="ftcsv: the field 'c' doesn't exist in the inputTable",
        actual=test
    })
end)

tested.test("parseLine and loadFromString", function()
    local test = function()
        local parse = {}
        for i, line in ftcsv.parseLine("a,b,c\n1,2,3", ",", {loadFromString=true}) do
            parse[i] = line
        end
        return parse
    end

    tested.assert_throws_exception({
        given="parseLine and loadFromString",
        expected="ftcsv: parseLine currently doesn't support loading from string",
        actual=test
    })
end)

tested.test("missing quotes", function()
    local test = function()
        local actual = ftcsv.parse('a,b,c\n"apple,banana,carrot', ",", {loadFromString=true})
    end
    tested.assert_throws_exception({
        given="missing quotes",
        expected="ftcsv: can't find closing quote in row 1. Try running with the option ignoreQuotes=true if the source incorrectly uses quotes.",
        actual=test
    })
end)

tested.test("buffersize without parseLine", function()
    local test = function()
        local actual = ftcsv.parse('a,b,c\n"apple,banana,carrot', ",", {loadFromString=true, bufferSize=34})
    end
    tested.assert_throws_exception({
        should="error if bufferSize is set when parsing entire files",
        expected="ftcsv: bufferSize can only be specified using 'parseLine'. When using 'parse', the entire file is read into memory",
        actual=test,
    })
end)

return tested