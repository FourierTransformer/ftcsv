package = "ftcsv"
version = "1.1.6-1"

source = {
	url = "git://github.com/FourierTransformer/ftcsv.git",
	tag = "1.1.6"
}

description = {
	summary = "A fast pure lua csv library (parser and encoder)",
	detailed = [[
    ftcsv works well for CSVs that can easily be fully loaded into memory (easily up to a hundred MB) and correctly handles `\n` (LF), `\r` (CR) and `\r\n` (CRLF) line endings. It has UTF-8 support, and will strip out the BOM if it exists. ftcsv can also parse headerless csv-like files and supports column remapping, file or string based loading, and more!

    Note: Currently it cannot load CSV files where the file can't fit in memory.
  ]],
	homepage = "https://github.com/FourierTransformer/ftcsv",
	maintainer = "Shakil Thakur <shakil.thakur@gmail.com>",
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