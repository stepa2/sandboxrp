# BoxRP.UData2

```
const .OBJECT_ID_BITS = 31
const .OBJECT_ID_MAX: uint
type .ObjectId = nonzero_uint31

type .FieldKey = string|number

type .FieldTblKey = number|string|Entity
type .FieldTblValue = .FieldTblKey|Vector|VMatrix|Angle|table(.FieldTblKey, .FieldTblValue)
type .FieldTypes = .FieldTblValue|.Object

const .FIELD_TYPE = {
    -- Zero is reserved for nil
    NUM = 1
    STRING = 2
    VECTOR = 3
    VMATRIX = 4
    ANGLE = 5
    ENTITY = 6
    TABLE = 7
    UOBJECT = 8
}

```

Object definition:
```
fn .RegisterObj(obj_ty: string, params: .SharedParams)
fn .RegisterComp(obj_ty: string, comp_name: string, params: .ComponentDefParams)


type .SharedParams = {
    SaveCl: bool,
    SaveSv: bool,
    NetMode: array(string) | string={_value_}
}

type .ComponentDefParams: .SharedParams = {
    FieldParams: fn(name: .FieldKey) -> .FieldParams | nil
}

type .FieldParams: .SharedParams = {
    Type: .FIELD_TYPE
}

fn .RegisterNetMode(netmode: string, obj_ty: string|nil, recipents: fn(obj: .Object) -> CRecipentList)
```

Object instances:
```
fn .Manager(save_set: string, allow_db: bool) -> .Manager
readonly var .Managers: table(save_set: string, .Manager)

type .Manager = {
    fn :LoadObject(oid: .ObjectId) -> .Object|nil
    fn :CreateObject(type: string) -> .Object|nil
    readonly var .Instances: table(.ObjectId, .Object)
    readonly var .SaveSet: string
    readonly var .AllowDatabaseIO: bool

    fn :SaveObjects()

    fn :DeleteUnloadAll()
    fn :Shutdown() -- After this call, manager is no longer valid

    fn :__tostring() -> string
}

type .Object = {
    readonly var .Id: .ObjectId
    readonly var .SaveSet: string
    readonly var .Type: string
    readonly var .Manager: .Manager

    fn :Unload()
    fn :DeleteUnload()

    -- Object becomes invalid after :Unload() or :DeleteUnload() or .Manager:DeleteUnloadAll() or .Manager:Shutdown()
    fn :IsValid() -> bool 

    fn :Save(start_transaction: bool)

    meta var .Components: {
        fn :__index(comp_name: string) -> .ComponentMeta|nil
        fn :__newindex(comp_name: string, component: table(.FieldKey, .FieldTypes)|nil)
    }

    fn :__tostring() -> String
}

meta type .ComponentMeta = {
    -- DO NOT use getter to set anything
    fn :__index(field_name: .FieldKey) -> .FieldTypes|nil
    fn :__setindex(field_name: .FieldKey, value: .FieldTypes|nil)
    fn :__tostring() -> string
}

hook .ObjectCreated(obj: .Object)
hook .ObjectPreRemoved(obj: .Object)

hook .ComponentCreated(obj: .Object, comp_name: string, comp: .ComponentMeta)
hook .ComponentPreRemoved(obj: .Object, comp_name: string, object_removed: bool)

hook .FieldChanged(obj: .Object, comp: string, key: .FieldKey, oldvalue: .FieldTypes|nil, newvalue: .FieldTypes|nil)

```

# BoxRP.UData2._Database - internal


Util:
```
fn .RegisterSupportedComponent(obj_type: string, comp_name: string)
```

Object:
```
fn .CreateSaveObject(save_set: string, obj_type: string) -> .ObjectId
fn .LoadObject(save_set: string, obj_id: .ObjectId) -> obj_type: string|nil
fn .DeleteObject(save_set: string, obj_id: .ObjectId)
fn .DeleteAllObjects(save_set: string)
fn .LoadObjectsRecursive(save_set: string, obj_ids: array(.ObjectId), supported_only: bool) -> array({
        obj_id: .ObjectId,
        obj_type: string
    })
```

Component: 
```
fn .LoadComponents(save_set: string, obj_id: .ObjectId, supported_only: bool) 
    -> array({
        comp_name: string,
        field_name: string|number,
        value: string|number,
        is_xref: bool
    })

-- ! Wrap this function with transaction to achieve peformance
-- If components = { blah = {} }, component 'blah' will be removed
fn .SaveComponents(save_set: string, obj_id: .ObjectId, components: table(comp_name: string, array({
        field_name: string|number,
        value_any: string|number|nil,
        value_xref: number|nil
    })))

type FindConstraint = "AND" | "OR" | "NOT" | "(" | ")" {
        Name: string,
        Value: number|.ObjectId|string,
        IsXRef: bool
    }

-- !! SECURITY WARNING: if .FindConstraint is a string, SQL injection is possible. 
-- Check string arguments if they come from user code
fn .FindObjectByComponent(save_set: string, obj_type: string, comp_name: string, constraints: array(.FindConstraint)) -> array(.ObjectId)
```
