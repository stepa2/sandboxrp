# BoxRP.SQLite

Formatting syntax:
    - `.Query("{$name}", { name = "blah 1 'DROP TABLE *"})` is same as `.Query("blah 1 'DROP TABLE *", {})`
    - `.Query("{name}", { name = "blah 1 'DROP TABLE *"})` is same as `.Query("'blah 1 ''DROP TABLE *'")`, so SQL injections are not possible

`fn .Query(expr: string, args: table(string, string)) -> array(table(any,any))`
`fn .QuerySingle(expr: string, args: table(string, string)) -> table(any, any)` -- Errors if query results not in a single row