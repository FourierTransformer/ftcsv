local ftcsv = require "ftcsv"

local BOM = {["NO BOM"] = "", ["BOM"] = string.char(239, 187, 191)}
local newlines = {["LF"] = "\n", ["CRLF"] = "\r\n", ["CR"] = "\r"}
local endlines = {"NONE", "NEWLINE"}
local quotes = {["NO QUOTES"] = "", ["DOUBLE QUOTES"] = '"'}

describe("csv features", function()
    for bom, i in pairs(BOM) do
        for newline, j in pairs(newlines) do
            for quote, k in pairs(quotes) do
                for _, endline in ipairs(endlines) do
                    local name = "should handle loading from string (%s + %s + %s) EOF: %s"
                    it(name:format(bom, newline, quote, endline), function()
                        local expectedHeaders = {"a", "b", "c"}
                        local expected = {}
                        expected[1] = {}
                        expected[1].a = "apple"
                        expected[1].b = "banana"
                        expected[1].c = "carrot"

                        local defaultString = "%s`a`,`b`,`c`%s`apple`,`banana`,`carrot`%s"
                        defaultString = defaultString:gsub("`", k)

                        if endline == "NONE" then
                            defaultString = defaultString:format(i, j, "")
                        else
                            defaultString = defaultString:format(i, j, j)
                        end

                        local options = {loadFromString=true}
                        local actual, actualHeaders = ftcsv.parse(defaultString, ",", options)
                        assert.are.same(expected, actual)
                        assert.are.same(expectedHeaders, actualHeaders)
                    end)
                end
            end
        end
    end

    for bom, i in pairs(BOM) do
        for newline, j in pairs(newlines) do
            for quote, k in pairs(quotes) do
                for _, endline in ipairs(endlines) do
                    local name = "should handle renaming fields (%s + %s + %s) EOF: %s"
                    it(name:format(bom, newline, quote, endline), function()
                        local expectedHeaders = {"d", "e", "f"}
                        local expected = {}
                        expected[1] = {}
                        expected[1].d = "apple"
                        expected[1].e = "banana"
                        expected[1].f = "carrot"

                        local defaultString = "%s`a`,`b`,`c`%s`apple`,`banana`,`carrot`%s"
                        defaultString = defaultString:gsub("`", k)

                        if endline == "NONE" then
                            defaultString = defaultString:format(i, j, "")
                        else
                            defaultString = defaultString:format(i, j, j)
                        end

                        local options = {loadFromString=true, rename={["a"] = "d", ["b"] = "e", ["c"] = "f"}}
                        local actual, actualHeaders = ftcsv.parse(defaultString, ",", options)
                        assert.are.same(expected, actual)
                        assert.are.same(expectedHeaders, actualHeaders)
                    end)
                end
            end
        end
    end

    for bom, i in pairs(BOM) do
        for newline, j in pairs(newlines) do
            for quote, k in pairs(quotes) do
                for _, endline in ipairs(endlines) do
                    local name = "should handle renaming fields to the same out value (%s + %s + %s) EOF: %s"
                    it(name:format(bom, newline, quote, endline), function()
                        local expectedHeaders = {"d", "e"}
                        local expected = {}
                        expected[1] = {}
                        expected[1].d = "apple"
                        expected[1].e = "carrot"

                        local defaultString = "%s`a`,`b`,`c`%s`apple`,`banana`,`carrot`%s"
                        defaultString = defaultString:gsub("`", k)

                        if endline == "NONE" then
                            defaultString = defaultString:format(i, j, "")
                        else
                            defaultString = defaultString:format(i, j, j)
                        end

                        local options = {loadFromString=true, rename={["a"] = "d", ["b"] = "e", ["c"] = "e"}}
                        local actual, actualHeaders = ftcsv.parse(defaultString, ",", options)
                        assert.are.same(expected, actual)
                        assert.are.same(expectedHeaders, actualHeaders)
                    end)
                end
            end
        end
    end

    for bom, i in pairs(BOM) do
        for newline, j in pairs(newlines) do
            for quote, k in pairs(quotes) do
                for _, endline in ipairs(endlines) do
                    local name = "should handle keeping only a few fields (%s + %s + %s) EOF: %s"
                    it(name:format(bom, newline, quote, endline), function()
                        local expectedHeaders = {"a", "b"}
                        local expected = {}
                        expected[1] = {}
                        expected[1].a = "apple"
                        expected[1].b = "banana"

                        local defaultString = "%s`a`,`b`,`c`%s`apple`,`banana`,`carrot`%s"
                        defaultString = defaultString:gsub("`", k)

                        if endline == "NONE" then
                            defaultString = defaultString:format(i, j, "")
                        else
                            defaultString = defaultString:format(i, j, j)
                        end

                        local options = {loadFromString=true, fieldsToKeep={"a", "b"}}
                        local actual, actualHeaders = ftcsv.parse(defaultString, ",", options)
                        assert.are.same(expected, actual)
                        assert.are.same(expectedHeaders, actualHeaders)
                    end)
                end
            end
        end
    end

    for bom, i in pairs(BOM) do
        for newline, j in pairs(newlines) do
            for quote, k in pairs(quotes) do
                for _, endline in ipairs(endlines) do
                    local name = "should handle only keeping a few fields with a rename to an existing field (%s + %s + %s) EOF: %s"
                    it(name:format(bom, newline, quote, endline), function()
                        local expectedHeaders = {"a", "b"}
                        local expected = {}
                        expected[1] = {}
                        expected[1].a = "apple"
                        expected[1].b = "carrot"

                        local defaultString = "%s`a`,`b`,`c`%s`apple`,`banana`,`carrot`%s"
                        defaultString = defaultString:gsub("`", k)

                        if endline == "NONE" then
                            defaultString = defaultString:format(i, j, "")
                        else
                            defaultString = defaultString:format(i, j, j)
                        end

                        local options = {loadFromString=true, rename={["c"] = "b"}, fieldsToKeep={"a","b"}}
                        local actual, actualHeaders = ftcsv.parse(defaultString, ",", options)
                        assert.are.same(expected, actual)
                        assert.are.same(expectedHeaders, actualHeaders)
                    end)
                end
            end
        end
    end

    for bom, i in pairs(BOM) do
        for newline, j in pairs(newlines) do
            for quote, k in pairs(quotes) do
                for _, endline in ipairs(endlines) do
                    local name = "should handle only keeping a few fields with a rename to a new field (%s + %s + %s) EOF: %s"
                    it(name:format(bom, newline, quote, endline), function()
                        local expectedHeaders = {"a", "f"}
                        local expected = {}
                        expected[1] = {}
                        expected[1].a = "apple"
                        expected[1].f = "carrot"

                        local defaultString = "%s`a`,`b`,`c`%s`apple`,`banana`,`carrot`%s"
                        defaultString = defaultString:gsub("`", k)

                        if endline == "NONE" then
                            defaultString = defaultString:format(i, j, "")
                        else
                            defaultString = defaultString:format(i, j, j)
                        end

                        local options = {loadFromString=true, rename={["c"] = "f"}, fieldsToKeep={"a","f"}}
                        local actual, actualHeaders = ftcsv.parse(defaultString, ",", options)
                        assert.are.same(expected, actual)
                        assert.are.same(expectedHeaders, actualHeaders)
                    end)
                end
            end
        end
    end

    for bom, i in pairs(BOM) do
        for newline, j in pairs(newlines) do
            for quote, k in pairs(quotes) do
                for _, endline in ipairs(endlines) do
                    local name = "should apply a function via headerFunc (%s + %s + %s) EOF: %s"
                    it(name:format(bom, newline, quote, endline), function()
                        local expectedHeaders = {"A", "B", "C"}
                        local expected = {}
                        expected[1] = {}
                        expected[1].A = "apple"
                        expected[1].B = "banana"
                        expected[1].C = "carrot"

                        local defaultString = "%s`a`,`b`,`c`%s`apple`,`banana`,`carrot`%s"
                        defaultString = defaultString:gsub("`", k)

                        if endline == "NONE" then
                            defaultString = defaultString:format(i, j, "")
                        else
                            defaultString = defaultString:format(i, j, j)
                        end

                        local options = {loadFromString=true, headerFunc=string.upper}
                        local actual, actualHeaders = ftcsv.parse(defaultString, ",", options)
                        assert.are.same(expected, actual)
                        assert.are.same(expectedHeaders, actualHeaders)
                    end)
                end
            end
        end
    end

    for bom, i in pairs(BOM) do
        for newline, j in pairs(newlines) do
            for quote, k in pairs(quotes) do
                for _, endline in ipairs(endlines) do
                    local name = "should apply a function via headerFunc with rename and fieldsToKeep (%s + %s + %s) EOF: %s"
                    it(name:format(bom, newline, quote, endline), function()
                        local expectedHeaders = {"A", "F"}
                        local expected = {}
                        expected[1] = {}
                        expected[1].A = "apple"
                        expected[1].F = "carrot"

                        local defaultString = "%s`a`,`b`,`c`%s`apple`,`banana`,`carrot`%s"
                        defaultString = defaultString:gsub("`", k)

                        if endline == "NONE" then
                            defaultString = defaultString:format(i, j, "")
                        else
                            defaultString = defaultString:format(i, j, j)
                        end

                        local options = {loadFromString=true, rename={["c"] = "f"}, fieldsToKeep={"A","F"}, headerFunc=string.upper}
                        local actual, actualHeaders = ftcsv.parse(defaultString, ",", options)
                        assert.are.same(expected, actual)
                        assert.are.same(expectedHeaders, actualHeaders)
                    end)
                end
            end
        end
    end

    for bom, i in pairs(BOM) do
        for newline, j in pairs(newlines) do
            for _, endline in ipairs(endlines) do
                local name = "should handle escaped doublequotes (%s + %s) EOF: %s"
                it(name:format(bom, newline, endline), function()
                    local expectedHeaders = {"a", "b", "c"}
                    local expected = {}
                    expected[1] = {}
                    expected[1].a = '"apple"'
                    expected[1].b = '"banana"'
                    expected[1].c = '"carrot"'

                    local defaultString = '%s"a","b","c"%s"""apple""","""banana""","""carrot"""%s'

                    if endline == "NONE" then
                        defaultString = defaultString:format(i, j, "")
                    else
                        defaultString = defaultString:format(i, j, j)
                    end

                    local options = {loadFromString=true}
                    local actual, actualHeaders = ftcsv.parse(defaultString, ",", options)
                    assert.are.same(expected, actual)
                    assert.are.same(expectedHeaders, actualHeaders)
                end)
            end
        end
    end

    -- HEADERLESS TESTS START HERE

    for bom, i in pairs(BOM) do
        for newline, j in pairs(newlines) do
            for quote, k in pairs(quotes) do
                for _, endline in ipairs(endlines) do
                    local name = "should handle files without headers (%s + %s + %s) EOF: %s"
                    it(name:format(bom, newline, quote, endline), function()
                        local expectedHeaders = {1, 2, 3}
                        local expected = {}
                        expected[1] = {}
                        expected[1][1] = "apple"
                        expected[1][2] = "banana"
                        expected[1][3] = "carrot"
                        expected[2] = {}
                        expected[2][1] = "diamond"
                        expected[2][2] = "emerald"
                        expected[2][3] = "pearl"

                        local defaultString = "%s`apple`,`banana`,`carrot`%s`diamond`,`emerald`,`pearl`%s"
                        defaultString = defaultString:gsub("`", k)

                        if endline == "NONE" then
                            defaultString = defaultString:format(i, j, "")
                        else
                            defaultString = defaultString:format(i, j, j)
                        end

                        local options = {loadFromString=true, headers=false}
                        local actual, actualHeaders = ftcsv.parse(defaultString, ",", options)
                        assert.are.same(expected, actual)
                        assert.are.same(expectedHeaders, actualHeaders)
                    end)
                end
            end
        end
    end

    for bom, i in pairs(BOM) do
        for newline, j in pairs(newlines) do
            for quote, k in pairs(quotes) do
                for _, endline in ipairs(endlines) do
                    local name = "should handle files without headers and with one row (%s + %s + %s) EOF: %s"
                    it(name:format(bom, newline, quote, endline), function()
                        local expectedHeaders = {1, 2, 3}
                        local expected = {}
                        expected[1] = {}
                        expected[1][1] = "apple"
                        expected[1][2] = "banana"
                        expected[1][3] = "carrot"

                        local defaultString = "%s`apple`,`banana`,`carrot`%s"
                        defaultString = defaultString:gsub("`", k)

                        if endline == "NONE" then
                            defaultString = defaultString:format(i, "")
                        else
                            defaultString = defaultString:format(i, j)
                        end

                        local options = {loadFromString=true, headers=false}
                        local actual, actualHeaders = ftcsv.parse(defaultString, ",", options)
                        assert.are.same(expected, actual)
                        assert.are.same(expectedHeaders, actualHeaders)
                    end)
                end
            end
        end
    end

    for bom, i in pairs(BOM) do
        for newline, j in pairs(newlines) do
            for quote, k in pairs(quotes) do
                for _, endline in ipairs(endlines) do
                    local name = "should handle renaming fields from files without headers (%s + %s + %s) EOF: %s"
                    it(name:format(bom, newline, quote, endline), function()
                        local expectedHeaders = {"a", "b", "c"}
                        local expected = {}
                        expected[1] = {}
                        expected[1].a = "apple"
                        expected[1].b = "banana"
                        expected[1].c = "carrot"
                        expected[2] = {}
                        expected[2].a = "diamond"
                        expected[2].b = "emerald"
                        expected[2].c = "pearl"

                        local defaultString = "%s`apple`,`banana`,`carrot`%s`diamond`,`emerald`,`pearl`%s"
                        defaultString = defaultString:gsub("`", k)

                        if endline == "NONE" then
                            defaultString = defaultString:format(i, j, "")
                        else
                            defaultString = defaultString:format(i, j, j)
                        end

                        local options = {loadFromString=true, headers=false, rename={"a","b","c"}}
                        local actual, actualHeaders = ftcsv.parse(defaultString, ",", options)
                        assert.are.same(expected, actual)
                        assert.are.same(expectedHeaders, actualHeaders)
                    end)
                end
            end
        end
    end

    for bom, i in pairs(BOM) do
        for newline, j in pairs(newlines) do
            for quote, k in pairs(quotes) do
                for _, endline in ipairs(endlines) do
                    local name = "should handle renaming fields from files without headers and only keeping a few fields (%s + %s + %s) EOF: %s"
                    it(name:format(bom, newline, quote, endline), function()
                        local expectedHeaders = {"a", "b"}
                        local expected = {}
                        expected[1] = {}
                        expected[1].a = "apple"
                        expected[1].b = "banana"
                        expected[2] = {}
                        expected[2].a = "diamond"
                        expected[2].b = "emerald"

                        local defaultString = "%s`apple`,`banana`,`carrot`%s`diamond`,`emerald`,`pearl`%s"
                        defaultString = defaultString:gsub("`", k)

                        if endline == "NONE" then
                            defaultString = defaultString:format(i, j, "")
                        else
                            defaultString = defaultString:format(i, j, j)
                        end

                        local options = {loadFromString=true, headers=false, rename={"a","b","c"}, fieldsToKeep={"a","b"}}
                        local actual, actualHeaders = ftcsv.parse(defaultString, ",", options)
                        assert.are.same(expected, actual)
                        assert.are.same(expectedHeaders, actualHeaders)
                    end)
                end
            end
        end
    end

    for bom, i in pairs(BOM) do
        for newline, j in pairs(newlines) do
            for quote, k in pairs(quotes) do
                for _, endline in ipairs(endlines) do
                    local name = "should handle if the number of renames doesn't equal the number of fields (%s + %s + %s) EOF: %s"
                    it(name:format(bom, newline, quote, endline), function()
                        local expectedHeaders = {"a", "b"}
                        local expected = {}
                        expected[1] = {}
                        expected[1].a = "apple"
                        expected[1].b = "banana"
                        expected[2] = {}
                        expected[2].a = "diamond"
                        expected[2].b = "emerald"

                        local defaultString = "%s`apple`,`banana`,`carrot`%s`diamond`,`emerald`,`pearl`%s"
                        defaultString = defaultString:gsub("`", k)

                        if endline == "NONE" then
                            defaultString = defaultString:format(i, j, "")
                        else
                            defaultString = defaultString:format(i, j, j)
                        end

                        local options = {loadFromString=true, headers=false, rename={"a","b"}, fieldsToKeep={"a","b"}}
                        local actual, actualHeaders = ftcsv.parse(defaultString, ",", options)
                        assert.are.same(expected, actual)
                        assert.are.same(expectedHeaders, actualHeaders)
                    end)
                end
            end
        end
    end

    for bom, i in pairs(BOM) do
        for newline, j in pairs(newlines) do
            for _, endline in ipairs(endlines) do
                local name = "should handle ignoring quotes (%s + %s) EOF: %s"
                it(name:format(bom, newline, endline), function()
                    local expectedHeaders = {"a", "b", "c"}
                    local expected = {}
                    expected[1] = {}
                    expected[1].a = '"apple"'
                    expected[1].b = '"banana"'
                    expected[1].c = '"carrot"'

                    local defaultString = '%sa,b,c%s"apple","banana","carrot"%s'

                    if endline == "NONE" then
                        defaultString = defaultString:format(i, j, "")
                    else
                        defaultString = defaultString:format(i, j, j)
                    end

                    local options = {loadFromString=true, ignoreQuotes=true}
                    local actual, actualHeaders = ftcsv.parse(defaultString, ",", options)
                    assert.are.same(expected, actual)
                    assert.are.same(expectedHeaders, actualHeaders)
                end)
            end
        end
    end

end)