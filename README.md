# ftcsv
[![Run Tests and Code Coverage](https://github.com/FourierTransformer/ftcsv/actions/workflows/test-and-coverage.yml/badge.svg)](https://github.com/FourierTransformer/ftcsv/actions/workflows/test-and-coverage.yml) [![Coverage Status](https://coveralls.io/repos/github/FourierTransformer/ftcsv/badge.svg?branch=master)](https://coveralls.io/github/FourierTransformer/ftcsv?branch=master)

ftcsv is a fast csv library written in pure Lua. It's been tested with LuaJIT 2.0/2.1 and Lua 5.1, 5.2, 5.3, and 5.4

It features two parsing modes, one for CSVs that can easily be loaded into memory (up to a few hundred MBs depending on the system), and another for loading files using an iterator - useful for manipulating large files or processing during load. It correctly handles most csv (and csv-like) files found in the wild, from varying line endings (Windows, Linux, and OS9), UTF-8 BOM support, and odd delimiters. There are also various options that can tweak how a file is loaded, only grabbing a few fields, renaming fields, and parsing header-less files!

## Installing
You can either grab `ftcsv.lua` from here or install via luarocks:

```
luarocks install ftcsv
```


## Parsing
There are two main parsing methods: `ftcv.parse` and `ftcsv.parseLine`.
`ftcsv.parse` loads the entire file and parses it, while `ftcsv.parseLine` is an iterator that parses one line at a time.

### `ftcsv.parse(fileName, delimiter [, options])`
`ftcsv.parse` will load the entire csv file into memory, then parse it in one go, returning a lua table with the parsed data and a lua table containing the column headers. It has only two required parameters - a file name and delimiter (limited to one character). A few optional parameters can be passed in via a table (examples below).

Just loading a csv file:
```lua
local ftcsv = require('ftcsv')
local zipcodes, headers = ftcsv.parse("free-zipcode-database.csv", ",")
```

### `ftcsv.parseLine(fileName, delimiter, [, options])`
`ftcsv.parseLine` will open a file and read `options.bufferSize` bytes of the file. `bufferSize` defaults to 2^16 bytes (which provides the fastest parsing on most unix-based systems), or can be specified in the options. `ftcsv.parseLine` is an iterator and returns one line at a time. When all the lines in the buffer are read, it will read in another `bufferSize` bytes of a file and repeat the process until the entire file has been read.

If specifying `bufferSize` there are a couple of things to remember:
 * `bufferSize` must be at least the length of the longest row.
 * If `bufferSize` is too small, an error is returned. 
 * If `bufferSize` is the length of the entire file, all of it will be read and returned one line at a time (performance is roughly the same as `ftcsv.parse`).

Parsing through a csv file:
```lua
local ftcsv = require("ftcsv")
for zipcode in ftcsv.parseLine("free-zipcode-database.csv", ",") do
    print(zipcode.Zipcode)
    print(zipcode.State)
end
```


### Options
The options are the same for `parseLine` and `parse`, with the exception of `loadFromString` and `bufferSize`. `loadFromString` only works with `parse` and `bufferSize` can only be specified for `parseLine`.

The following are optional parameters passed in via the third argument as a table.
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

 	Also Note: If you apply a function to the headers via headerFunc, and want to select fields from fieldsToKeep, you need to have what the post-modified header would be in fieldsToKeep.

 - `ignoreQuotes`

	If `ignoreQuotes` is `true`, it will leave all quotes in the final parsed output. This is useful in situations where the fields aren't quoted, but contain quotes, or if the CSV didn't handle quotes correctly and you're trying to parse it.
	
	```lua
	local options = {loadFromString=true, ignoreQuotes=true}
	local actual = ftcsv.parse('a,b,c\n"apple,banana,carrot', ",", options)
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

The options can be string together. For example if you wanted to `loadFromString` and not use `headers`, you could use the following:
```lua
ftcsv.parse("apple,banana,carrot", ",", {loadFromString=true, headers=false})
```

## Encoding
### `ftcsv.encode(inputTable, delimiter[, options])`

`ftcsv.encode` takes in a lua table and turns it into a text string that can be written to a file. It has two required parameters, an inputTable and a delimiter. You can use it to write out a file like this:
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

 - `onlyRequiredQuotes`

    if `onlyRequiredQuotes` is set to `true`, the output will only include quotes around fields that are quotes, have newlines, or contain the delimter.

    ```lua
    local output = ftcsv.encode(everyUser, ",", {noQuotes=true})
    ```


## Error Handling
ftcsv returns a litany of errors when passed a bad csv file or incorrect parameters. You can find a more detailed explanation of the more cryptic errors in [ERRORS.md](ERRORS.md)

## Benchmarks
We ran ftcsv against a few different csv parsers ([PIL](http://www.lua.org/pil/20.4.html)/[csvutils](http://lua-users.org/wiki/CsvUtils), [lua_csv](https://github.com/geoffleyland/lua-csv), and [lpeg_josh](http://lua-users.org/lists/lua-l/2009-08/msg00020.html)) for lua and here is what we found:

### 20 MB file, every field is double quoted

| Parser    | Lua                | LuaJIT             |
| --------- | ------------------ | ------------------ |
| PIL/csvutils  | 1.754 +/- 0.136 SD | 1.012 +/- 0.112 SD |
| lua_csv   | 4.191 +/- 0.128 SD | 2.382 +/- 0.133 SD |
| lpeg_josh | **0.996 +/- 0.149 SD** | 0.725 +/- 0.083 SD |
| ftcsv     | 1.342 +/- 0.130 SD | **0.301 +/- 0.099 SD** |


### 12 MB file, some fields are double quoted

| Parser    | Lua                | LuaJIT             |
| --------- | ------------------ | ------------------ |
| PIL/csvutils  | 1.456 +/- 0.083 SD | 0.691 +/- 0.071 SD |
| lua_csv   | 3.738 +/- 0.072 SD | 1.997 +/- 0.075 SD |
| lpeg_josh | **0.638 +/- 0.070 SD** | 0.475 +/- 0.042 SD |
| ftcsv     | 1.307 +/- 0.071 SD | **0.213 +/- 0.062 SD** |

[LuaCSV](http://lua-users.org/lists/lua-l/2009-08/msg00012.html) was also tried, but usually errored out at odd places during parsing.

NOTE: times are measured using `os.clock()`, so they are in CPU seconds. Each test was run 30 times in a randomized order. The file was pre-loaded, and only the csv decoding time was measured.

Benchmarks were run under ftcsv 1.2.0

## Performance
I did some basic testing and found that in lua, if you want to iterate over a string character-by-character and compare chars, `string.byte` performs faster than `string.sub`. As such, ftcsv iterates over the whole file and does byte compares to find quotes and delimiters and then generates a table from it. When using vanilla lua, it proved faster to use `string.find` instead of iterating character by character (which is faster in LuaJIT), so ftcsv accounts for that and will perform the fastest option that is availble. If you have thoughts on how to improve performance (either big picture or specifically within the code), create a GitHub issue - I'd love to hear about it!


## Contributing
Feel free to create a new issue for any bugs you've found or help you need. If you want to contribute back to the project please do the following:

 1. If it's a major change (aka more than a quick bugfix), please create an issue so we can discuss it!
 2. Fork the repo
 3. Create a new branch
 4. Push your changes to the branch
 5. Run the test suite and make sure it still works
 6. Submit a pull request
 7. Wait for review
 8. Enjoy the changes made!



## Licenses
 - The main library is licensed under the MIT License. Feel free to use it!
 - Some of the test CSVs are from [csv-spectrum](https://github.com/maxogden/csv-spectrum) (BSD-2-Clause) which includes some from [csvkit](https://github.com/wireservice/csvkit) (MIT License)
