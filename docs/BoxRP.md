# BoxRP

`hook .PreLoadModuleDir(dir: string)`
`hook .PostLoadModuleDir(dir: string)`
`hook .PreFileIncluded(filename: string, realm: "sv"|"sh"|"cl")`

`fn .GetRealmFromFilename(filename: string) -> "sv"|"sh"|"cl"`
`fn .IncludeFile(filename: string) -> file_return: ...|nil`
`fn .IncludeList(files: array(string))`
`fn .IncludeDir(dir: string, recursive: bool|nil=false)`

`fn .Error(parts: ...(any))` -- Unlike GMod Error(), this actually errors and halts execution
`fn .CheckType(val: any|nil, valname: string, allowed_types: array(string)|string) -> val: any|nil`
```
fn .RegisterType(name: string, {
    IsInstance: fn(value: any|nil) -> bool
})
```

`fn .ToString(val: any|nil, pretty_print: bool|nil = false) -> string`
