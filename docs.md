## API

### BoxRP

`hook .PreLoadModuleDir(dir: string)`
`hook .PostLoadModuleDir(dir: string)`
`hook .PreFileIncluded(filename: string, realm: "sv"|"sh"|"cl")`

`fn .GetRealmFromFilename(filename: string) -> "sv"|"sh"|"cl"`
`fn .IncludeFile(filename: string) -> file_return: ...|nil`
`fn .IncludeList(files: array(string))`
`fn .IncludeDir(dir: string, recursive: bool|nil=false)`

### BoxRP.SQLite

Formatting syntax:
    - `.Query("{$name}", { name = "blah 1 'DROP TABLE *"})` is same as `.Query("blah 1 'DROP TABLE *", {})`
    - `.Query("{name}", { name = "blah 1 'DROP TABLE *"})` is same as `.Query("'blah 1 ''DROP TABLE *'")`, so SQL injections are not possible

`fn .Query(expr: string, args: table(string, string)) -> array(table(any,any))`
`fn .QuerySingle(expr: string, args: table(string, string)) -> table(any, any)` -- Errors if query results not in a single row


### BoxRP.UData
Unified data system.

-- If obj_type==nil, function is usable on all objects
`fn .RegisterRecipentFunction(obj_type: string|nil, fn_name: string, fn: fn(obj: .Object) -> array(Player))`

```
fn .RegisterObject(obj_type: string, {
    SaveOnClient: bool
    SaveOnServer: bool
    RecipentFns: array(recipentfn_name: string)|nil
})
```

`inferred_type TObjectValue <depends on value of .ValueType from .RegisterValue third parameter>`
`inferred_type TObjectValueItem <element of TObjectValue array, if it is an array`
`fn .CheckValueType(obj_type: string, val_name: string, value: any|nil) -> error_msg: nil|string`

```
fn .RegisterValue(obj_type: string, val_name: string, {
    ValueType: "string"|"number"|"table"|"array(string)"|"array(number)"|"array(table)"
    Required: {
        WhenMissing: "skip_object"|"skip_value"|"set_default",
        Default: <if .WhenMissing == "set_default"> TObjectValue
    }
    SaveOnClient: bool
    SaveOnServer: bool
    RecipentFns: array(recipentfn_name: string)|nil
    ValueChecker: nil|fn(value: TObjectValue) -> error_msg: nil|string
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
    keyvalues: table(string, TObjectValue) -- [TODO:] Using this is faster then setting values after creation
    ) -> Object|nil, error_msg: nil|string
```

`readonly var .Object.Type: string`
`readonly var .Object.Id: .ObjectId`

`fn .LoadObject(oid: .ObjectId) -> Object|nil, error_msg: nil|string`

`fn .Object:GetVal(key: string) -> TObjectValue` -- You can edit returning value, but if you do so, call `:ValUpdated(key)`
`SV fn .Object:ValUpdated(key: string)`

```
-- If `unchecked` == true, value type is not checked
SV fn .Object:SetVal(
    key: string, val: TObjectValue, 
    unchecked: bool|nil=false
    ) -> is_ok: bool, error_msg: nil|string
```

```
-- If `unchecked` == true, value type and index value is not checked
SV fn .Object:SetValIndexed(
    key: string, index: nonzero_uint, val: TObjectValueItem,
    unchecked: bool|nil=false
    ) -> is_ok: bool, error_msg: nil|string
```

`SV fn .Object:Sync(target: Player|array(Player)|CRecipentFilter|nil=players.GetAll())`

`SV fn .Object:SaveServer()`
`fn .Object:SaveClient()`

```
BoxRP.UData.RegisterRecipentFunction(nil, "core.everyone", <...>) -- Send to all players
```

### BoxRP.Char
Character system
Character may be associated with entity (player entity, non-player entity) and may be not (i.e. overwatch voice)
Player may have associated character and may have not (in build mode player may have no character)
