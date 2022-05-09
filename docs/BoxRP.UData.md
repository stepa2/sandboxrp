# BoxRP.UData
Unified data system.

```
fn .RegisterObject(obj_type: string, {
    Recipents: nil|"none"|"everyone"|"recvlist"
})
```

`inferred_type TVariable <depends on value of .Type from .RegisterValue third parameter>`
`inferred_type TVariableItem <element of TVariable set, if it is a set`
`fn .CheckVarType(obj_type: string, var_name: string, value: any|nil) -> error_msg: nil|string`

```
fn .RegisterVar(obj_type: string, var_name: string, {
    Type: {
        Type: "table"|"Object"
        IsSet: bool
    }
    ErrorHandling: {
        -- "set_default" not available if .Type.Type == "Object"

        WhenMissing: "skip_object"|"set_default"
        WhenMultiple: "skip_object"|"set_default"        <if .Type is not set> 
        Default: TVariable
    }
    SaveOnClient: bool
    SaveOnServer: bool
    Recipents: nil|"none"|"everyone"|"recvlist"

    -- Note nil values should be disallowed
    -- For set variables, this is called on items
    ItemChecker: nil|fn(value: any|nil) -> error_msg: nil|string
})
```
`type .Object`

`type .ObjectId = nonzero_uint31`
`const .OBJECT_ID_BITS = 31`
`const .OBJECT_ID_MAX: uint`
ObjectId is guaranteed to be unique, fit into `net.WriteUInt(31)`.
It is not 32-bits because `bit.` functions handle numbers as signed: if 32-th bit is set, number will be negative after functions.

```
fn .CreateObject(
    obj_type: string, 
    vars: table(string, TVariable)
    ) -> Object|nil, error_msg: nil|string
```

`readonly var .Objects: table(.ObjectId, .Object)`

`readonly var .Object.Type: string`
`readonly var .Object.Id: .ObjectId`

`fn .LoadObject(oid: .ObjectId) -> Object|nil, error_msg: nil|string`

`fn .Object:GetVar(key: string) -> TVariable`   -- Do NOT edit returned value
`SV fn .Object:SetVar(key: string, val: TVariable) -> is_ok: bool, error_msg: nil|string`


-- You can only use index 1..element_count
`SV fn .Object:SetVarIndexed(key: string, index: nonzero_uint, val: TVariableItem) -> is_ok: bool, error_msg: nil|string`
`SV fn .Object:InsertSet(key: string, val: TVariableItem) -> index: nonzero_uint|nil, error_msg: nil|string`
`SV fn .Object:RemoveSet(key: string, idx: nonzero_uint) -> removed: TVariableItem|nil`
`SV fn .Object:FindSet(key: string, search_val: TVariableItem) -> index: nonzero_uint|nil`


`SV fn .Object:Sync(target: Player|array(Player)|CRecipentFilter|nil=players.GetAll())`

`SV fn .Object:SaveServer()`
`fn .Object:SaveClient()`

`fn .Object:IsValid() -> bool`