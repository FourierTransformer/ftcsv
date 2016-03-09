local cjson = require("cjson")
local ftcsv = require('ftcsv')
-- local csv = require('csv')
-- local staecsv = require('state-csv')

local function loadFile(textFile)
    local file = io.open(textFile, "r")
    if not file then error("File not found at " .. textFile) end
    local allLines = file:read("*all")
    file:close()
    return allLines
end

local files = {
	"comma_in_quotes",
	"correctness",
	"empty",
	"empty_no_newline",
	"empty_no_quotes",
	"empty_crlf",
	"escaped_quotes",
	"json",
	"json_no_newline",
	"newlines",
	"newlines_crlf",
	"quotes_and_newlines",
	"simple",
	"simple_crlf",
	"utf8"
}

describe("csv decode", function()
	for _, value in ipairs(files) do
		it("should handle " .. value, function()
			local contents = loadFile("spec/csvs/" .. value .. ".csv")
			local json = loadFile("spec/json/" .. value .. ".json")
			json = cjson.decode(json)
			-- local parse = staecsv:ftcsv(contents, ",")
			local parse = ftcsv.decode(contents, ",")
			-- local f = csv.openstring(contents, {separator=",", header=true})
			-- local parse = {}
			-- for fields in f:lines() do
			  -- parse[#parse+1] = fields
			-- end
			assert.are.same(json, parse)
		end)
	end
end)


describe("csv encode", function()
	for _, value in ipairs(files) do
		it("should handle " .. value, function()
			local originalFile = loadFile("spec/csvs/" .. value .. ".csv")
			local jsonFile = loadFile("spec/json/" .. value .. ".json")
			local jsonDecode = cjson.decode(jsonFile)
			-- local parse = staecsv:ftcsv(contents, ",")
			local reEncoded = ftcsv.decode(ftcsv.encode(jsonDecode, ","), ",")
			-- local f = csv.openstring(contents, {separator=",", header=true})
			-- local parse = {}
			-- for fields in f:lines() do
			  -- parse[#parse+1] = fields
			-- end
			assert.are.same(jsonDecode, reEncoded)
		end)
	end
end)