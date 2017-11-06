# ftcsv
[![Build Status](https://travis-ci.org/FourierTransformer/ftcsv.svg?branch=master)](https://travis-ci.org/FourierTransformer/ftcsv) [![Coverage Status](https://coveralls.io/repos/github/FourierTransformer/ftcsv/badge.svg?branch=master)](https://coveralls.io/github/FourierTransformer/ftcsv?branch=master)

ftcsv is a fast csv library written in pure Lua. It's been tested with LuaJIT 2.0/2.1 and Lua 5.1, 5.2, and 5.3

It features two parsing modes, one for CSVs that can easily be loaded into memory (a few hundred MBs), and another for loading files using an iterator - useful for customized loading and manipulating large files. It correctly handles both `\n` (LF) and `\r\n` (CRLF) line endings (ie it should work with Windows and Mac/Linux line endings) and has UTF-8 support.



## Installing
You can either grab `ftcsv.lua` from here or install via luarocks:

```
luarocks install ftcsv
```


## Parsing
There are two main parsing methods: `ftcv.parse` and `ftcsv.parseLine`.
`ftcsv.parse` loads the entire file and parses it, while `ftcsv.parseLine` is intended to be used as an iterator with a for loop returning one parsed line at a time.

### `ftcsv.parse(fileName, delimiter [, options])`

`ftcsv.parse` will load the entire csv file into memory, then parse it in one go, returning a lua table with the parsed data. It has only two required parameters - a file name and delimiter (limited to one character). A few optional parameters can be passed in via a table (examples below).

Just loading a csv file:
```lua
local ftcsv = require("ftcsv")
local zipcodes = ftcsv.parse("free-zipcode-database.csv", ",")
```

### `ftcsv.parseLine(fileName, delimiter, bufferSize [, options])`
`ftcsv.parseLine` will open a file and read `bufferSize` bytes of the file. It parses these lines and returns one line at a time. When all the lines in the buffer are read, it will read in another `bufferSize` bytes of a file and repeat the process until there are no more bytes left in the file to read. The `bufferSize` must be at least the length of the longest row. If the `bufferSize` is too small, an error is returned. If `bufferSize` is the length of the entire file, all of it will be read and returned one line at a time (performance is roughly the same as `ftcsv.parse`). The options are the same for `parseLine` and `parse` and are described below, with the exception of `loadFromString` as `parseLine` currently only works with files.

Parsing through a csv file:
```lua
local ftcsv = require("ftcsv")
for zipcode in ftcsv.parseLine("free-zipcode-database.csv", ",", 10^6) do
    print(zipcode.Zipcode)
    print(zipcode.State)
end
```




### Options
The following are optional parameters passed in via the third argument as a table. For example if you wanted to `loadFromString` and not use `headers`, you could use the following:
```lua
ftcsv.parse("apple,banana,carrot", ",", {loadFromString=true, headers=false})
```
 - `loadFromString`

 	If you want to load a csv from a string instead of a file, set `loadFromString` to `true` (default: `false`)
 	```lua
	ftcsv.parse("a,b,c\r\n1,2,3", ",", {loadFromString=true})
 	```

 - `rename`

 	If you want to rename a field, you can set `rename` to change the field names. The below example will change the headers from `a,b,c` to `d,e,f`

 	Note: You can rename two fields to the same value, ftcsv will keep the field that appears latest in the line.

 	```lua
 	local options = {loadFromString=true, rename={["a"] = "d", ["b"] = "e", ["c"] = "f"}}
	local actual = ftcsv.parse("a,b,c\r\napple,banana,carrot", ",", options)
 	```

 - `fieldsToKeep`

 	If you only want to keep certain fields from the CSV, send them in as a table-list and it should parse a little faster and use less memory.

 	Note: If you want to keep a renamed field, put the new name of the field in `fieldsToKeep`:

 	```lua
	local options = {loadFromString=true, fieldsToKeep={"a","f"}, rename={["c"] = "f"}}
	local actual = ftcsv.parse("a,b,c\r\napple,banana,carrot\r\n", ",", options)
 	```

 - `headerFunc`

 	Applies a function to every field in the header. If you are using `rename`, the function is applied after the rename.

 	Ex: making all fields uppercase
 	```lua
 	local options = {loadFromString=true, headerFunc=string.upper}
	local actual = ftcsv.parse("a,b,c\napple,banana,carrot", ",", options)
 	```

 - `headers`

 	Set `headers` to `false` if the file you are reading doesn't have any headers. This will cause ftcsv to create indexed tables rather than a key-value tables for the output.

 	```lua
	local options = {loadFromString=true, headers=false}
	local actual = ftcsv.parse("apple>banana>carrot\ndiamond>emerald>pearl", ">", options)
 	```

 	Note: Header-less files can still use the `rename` option and after a field has been renamed, it can specified as a field to keep. The `rename` syntax changes a little bit:

 	```lua
	local options = {loadFromString=true, headers=false, rename={"a","b","c"}, fieldsToKeep={"a","b"}}
	local actual = ftcsv.parse("apple>banana>carrot\ndiamond>emerald>pearl", ">", options)
 	```

 	In the above example, the first field becomes 'a', the second field becomes 'b' and so on.

For all tested examples, take a look in /spec/feature_spec.lua


## Encoding
### `ftcsv.encode(inputTable, delimiter[, options])`

ftcsv can also take a lua table and turn it into a text string to be written to a file. It has two required parameters, an inputTable and a delimiter. You can use it to write out a file like this:
```lua
local fileOutput = ftcsv.encode(users, ",")
local file = assert(io.open("ALLUSERS.csv", "w"))
file:write(fileOutput)
file:close()
```

### Options
 - `fieldsToKeep`

	if `fieldsToKeep` is set in the encode process, only the fields specified will be written out to a file.

	```lua
	local output = ftcsv.encode(everyUser, ",", {fieldsToKeep={"Name", "Phone", "City"}})
	```



## Performance
I did some basic testing and found that in lua, if you want to iterate over a string character-by-character and look for single chars, `string.byte` performs better than `string.sub`. As such, ftcsv iterates over the whole file and does byte compares to find quotes and delimiters and then generates a table from it. If you have thoughts on how to improve performance (either big picture or specifically within the code), create a GitHub issue - I'd love to hear about it!



## Error Handling
ftcsv returns a litany of errors when passed a bad csv file or incorrect parameters. You can find a more detailed explanation of the more cryptic errors in [ERRORS.md](ERRORS.md)



## Contributing
Feel free to create a new issue for any bugs you've found or help you need. If you want to contribute back to the project please do the following:

 0. If it's a major change (aka more than a quick bugfix), please create an issue so we can discuss it!
 1. Fork the repo
 2. Create a new branch
 3. Push your changes to the branch
 4. Run the test suite and make sure it still works
 5. Submit a pull request
 6. Wait for review
 7. Enjoy the changes made!



## Licenses
 - The main library is licensed under the MIT License. Feel free to use it!
 - Some of the test CSVs are from [csv-spectrum](https://github.com/maxogden/csv-spectrum) (BSD-2-Clause) which includes some from [csvkit](https://github.com/wireservice/csvkit) (MIT License)
