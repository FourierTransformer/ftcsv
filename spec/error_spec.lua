local ftcsv = require('ftcsv')

local files = {
	{"empty_file", "ftcsv: Cannot parse an empty file"},
	{"empty_file_newline", "ftcsv: Cannot parse a file which contains empty headers"},
	{"empty_header", "ftcsv: Cannot parse a file which contains empty headers"},
	{"too_few_cols", "ftcsv: too few columns in row 1"},
	{"too_few_cols_end", "ftcsv: too few columns in row 2"},
	{"too_many_cols", "ftcsv: too many columns in row 2"},
	{"dne", "ftcsv: File not found at spec/bad_csvs/dne.csv"}
}

describe("csv decode error", function()
	for _, value in ipairs(files) do
		it("should error out " .. value[1], function()
			local test = function()
				ftcsv.parse("spec/bad_csvs/" .. value[1] .. ".csv", ",")
			end
			assert.has_error(test, value[2])
		end)
	end
end)

it("should error out for fieldsToKeep if no headers and no renaming takes place", function()
	local test = function()
		local options = {loadFromString=true, headers=false, fieldsToKeep={1, 2}}
		ftcsv.parse("apple>banana>carrot\ndiamond>emerald>pearl", ">", options)
	end
	assert.has_error(test, "ftcsv: fieldsToKeep only works with header-less files when using the 'rename' functionality")
end)

it("should error out when you want to encode a table and specify a field that doesn't exist", function()
	local encodeThis = {
	    {a = 'herp1', b = 'derp1'},
	    {a = 'herp2', b = 'derp2'},
	    {a = 'herp3', b = 'derp3'},
	}

	local test = function()
		ftcsv.encode(encodeThis, ">", {fieldsToKeep={"c"}})
	end

	assert.has_error(test, "ftcsv: the field 'c' doesn't exist in the inputTable")
end)

describe("parseLine features small, nonworking buffer size", function()
    it("should error out when trying to load from string", function()
        local test = function()
            local parse = {}
            for i, line in ftcsv.parseLine("a,b,c\n1,2,3", ",", 63, {loadFromString=true}) do
                parse[i] = line
            end
            return parse
        end
        assert.has_error(test, "ftcsv: parseLine currently doesn't support loading from string")
    end)
end)
