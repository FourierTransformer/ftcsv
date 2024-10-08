local cjson = require("cjson")
local ftcsv = require('ftcsv')

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

describe("csv decode", function()
	for _, value in ipairs(files) do
		it("should handle " .. value, function()
			local json = loadFile("spec/json/" .. value .. ".json")
			json = cjson.decode(json)
			local parse = ftcsv.parse("spec/csvs/" .. value .. ".csv", ",")
			assert.are.same(#json, #parse)
			assert.are.same(json, parse)
		end)
	end
end)

describe("csv parseLine decode", function()
	for _, value in ipairs(files) do
		it("should handle " .. value, function()
			local json = loadFile("spec/json/" .. value .. ".json")
			json = cjson.decode(json)
			local parse = {}
			for i, v in ftcsv.parseLine("spec/csvs/" .. value .. ".csv", ",") do
				parse[i] = v
				assert.are.same(json[i], v)
			end
			assert.are.same(#json, #parse)
			assert.are.same(json, parse)
		end)
	end
end)

describe("csv decode from string", function()
	for _, value in ipairs(files) do
		it("should handle " .. value, function()
			local contents = loadFile("spec/csvs/" .. value .. ".csv")
			local json = loadFile("spec/json/" .. value .. ".json")
			json = cjson.decode(json)
			local parse = ftcsv.parse(contents, ",", {loadFromString=true})
			assert.are.same(json, parse)
		end)
	end
end)

describe("csv encode", function()
	for _, value in ipairs(files) do
		it("should handle " .. value, function()
			local jsonFile = loadFile("spec/json/" .. value .. ".json")
			local jsonDecode = cjson.decode(jsonFile)
			local reEncoded = ftcsv.parse(ftcsv.encode(jsonDecode, ","), ",", {loadFromString=true})
			assert.are.same(jsonDecode, reEncoded)
		end)
	end
end)

describe("csv encode without a delimiter", function()
	for _, value in ipairs(files) do
		it("should handle " .. value, function()
			local jsonFile = loadFile("spec/json/" .. value .. ".json")
			local jsonDecode = cjson.decode(jsonFile)
			local reEncoded = ftcsv.parse(ftcsv.encode(jsonDecode), ",", {loadFromString=true})
			assert.are.same(jsonDecode, reEncoded)
		end)
	end
end)

describe("csv encode with a delimiter specified in options", function()
	for _, value in ipairs(files) do
		it("should handle " .. value, function()
			local jsonFile = loadFile("spec/json/" .. value .. ".json")
			local jsonDecode = cjson.decode(jsonFile)
			local reEncoded = ftcsv.parse(ftcsv.encode(jsonDecode, {delimiter="\t"}), {delimiter="\t", loadFromString=true})
			assert.are.same(jsonDecode, reEncoded)
		end)
	end
end)

describe("csv encode without quotes", function()
	for _, value in ipairs(files) do
		it("should handle " .. value, function()
			local jsonFile = loadFile("spec/json/" .. value .. ".json")
			local jsonDecode = cjson.decode(jsonFile)
			local reEncodedNoQuotes = ftcsv.parse(ftcsv.encode(jsonDecode, ",", {onlyRequiredQuotes=true}), ",", {loadFromString=true})
			assert.are.same(jsonDecode, reEncodedNoQuotes)
		end)
	end
end)
