## API

### BoxRP

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

### BoxRP.SQLite

Formatting syntax:
    - `.Query("{$name}", { name = "blah 1 'DROP TABLE *"})` is same as `.Query("blah 1 'DROP TABLE *", {})`
    - `.Query("{name}", { name = "blah 1 'DROP TABLE *"})` is same as `.Query("'blah 1 ''DROP TABLE *'")`, so SQL injections are not possible

`fn .Query(expr: string, args: table(string, string)) -> array(table(any,any))`
`fn .QuerySingle(expr: string, args: table(string, string)) -> table(any, any)` -- Errors if query results not in a single row


### BoxRP.UData
Unified data system.
```
fn .RegisterObject(obj_type: string, {
    SaveOnClient: bool
    SaveOnServer: bool
    Recipents: nil|"none"|"everyone"|"recvlist"
})
```

`inferred_type TVariable <depends on value of .Type from .RegisterValue third parameter>`
`inferred_type TVariableItem <element of TVariable array, if it is an array`
`fn .CheckVarType(obj_type: string, var_name: string, value: any|nil) -> error_msg: nil|string`

```
fn .RegisterVar(obj_type: string, var_name: string, {
    Type: "table"|"array(table)"|"Object"|"array(Object)"
    Required: {
        WhenMissing: "skip_object"|"skip_var"|"set_default",
        Default: <if .WhenMissing == "set_default"> TVariable
    }
    SaveOnClient: bool
    SaveOnServer: bool
    Recipents: nil|"none"|"everyone"|"recvlist"
    ValueChecker: nil|fn(value: TVariable) -> error_msg: nil|string
})
```
`type .Object`

`type .ObjectId = nonzero_uint31`
`const .OBJECT_ID_BITS = 31`
ObjectId is guaranteed to be unique, fit into `net.WriteUInt(31)`.
It is not 32-bits because `bit.` functions handle numbers as signed: if 32-th bit is set, number will be negative after functions.

```
fn .CreateObject(
    obj_type: string, 
    vars: table(string, TVariable) -- [TODO:] Using this is faster then setting variables after creation
    ) -> Object|nil, error_msg: nil|string
```

`readonly var .Object.Type: string`
`readonly var .Object.Id: .ObjectId`

`fn .LoadObject(oid: .ObjectId) -> Object|nil, error_msg: nil|string`

`fn .Object:GetVar(key: string) -> TVariable` -- You can edit returning value, but if you do so, call `:ValUpdated(key)`
`SV fn .Object:VarUpdated(key: string)`

```
-- If `unchecked` == true, value type is not checked
SV fn .Object:SetVar(
    key: string, val: TVariable, 
    unchecked: bool|nil=false
    ) -> is_ok: bool, error_msg: nil|string
```

```
-- If `unchecked` == true, value type and index value is not checked
SV fn .Object:SetVarIndexed(
    key: string, index: nonzero_uint, val: TVariableItem,
    unchecked: bool|nil=false
    ) -> is_ok: bool, error_msg: nil|string
```

`SV fn .Object:Sync(target: Player|array(Player)|CRecipentFilter|nil=players.GetAll())`

`SV fn .Object:SaveServer()`
`fn .Object:SaveClient()`


### BoxRP.Char
Character system
Character may be associated with entity (player entity, non-player entity) and may be not (i.e. overwatch voice)
Player may have associated character and may have not (in build mode player may have no character)
