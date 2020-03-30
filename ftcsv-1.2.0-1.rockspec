package = "ftcsv"
version = "1.2.0-1"

source = {
	url = "git://github.com/FourierTransformer/ftcsv.git",
	tag = "1.2.0"
}

description = {
	summary = "A fast csv library written in pure Lua",
	detailed = [[
   ftcsv is a fast and easy to use csv library for lua. It can read in CSV files,
   do some basic transformations (rename fields) and can create the csv format.
   It supports UTF-8, header-less CSVs, and maintaining correct line endings for
   multi-line fields.

   It supports loading an entire CSV file into memory and parsing it as well as
   buffered reading of a CSV file.
  ]],
	homepage = "https://github.com/FourierTransformer/ftcsv",
	maintainer = "FourierTransformer",
	license = "MIT"
}

dependencies = {
	"lua >= 5.1, <5.4",
}

build = {
	type = "builtin",
	modules = {
		["ftcsv"] = "ftcsv.lua"
	},
}
