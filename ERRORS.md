# Error Handling
Below you can find a more detailed explanation of some of the errors that can be encountered while using ftcsv. For parsing, examples of these files can be found in /spec/bad_csvs/



## Parsing
Note: `[row_number]` indicates the row number of the parsed lua table. As such, it will be one off from the line number in the csv. However, for header-less files, the row returned *will* match the csv line number.

| Error Message  | Detailed Explanation |
| ------------- | ------------- |
| ftcsv: Cannot parse an empty file         | The file passed in contains no information. It is an empty file. |
| ftcsv: Cannot parse a file which contains empty headers | If a header field contains no information, then it can't be parsed <br> (ex: `Name,City,,Zipcode`) |
| ftcsv: too few columns in row [row_number]    | The number of columns is less than the amount in the header after transformations (renaming, keeping certain fields, etc) |
| ftcsv: too many columns in row [row_number]   | The number of columns is greater than the amount in the header after transformations. It can't map the field's count with an existing header. |
| ftcsv: File not found at [path]           | When loading, lua can't open the file at [path] | 
| ftcsv: bufferSize needs to be larger to parse this file  | The buffer size selected is too small to parse the file. It must be at least the length of the longest row (but, for performance, should probably be a bit larger). |
| ftcsv: parseLine currently doesn't support loading from string | `parseLine` relies on reading a file a few bytes at a time and currently doesn't work on strings |
