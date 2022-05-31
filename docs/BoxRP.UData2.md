# BoxRP.UData2

```
const .OBJECT_ID_BITS = 31
const .OBJECT_ID_MAX: uint
registered type .ObjectId = nonzero_uint31

const .FIELD_TYPE = {
    -- Zero is reserved for nil
    BOOL = 1
    NUM = 2
    STRING = 3
    VECTOR = 4
    VMATRIX = 5
    ANGLE = 6
    ENTITY = 7
    TABLE = 8
    UOBJECT = 9
    UOBJECT_SET = 10
}

fn .CheckField(value: any|nil, excepted_type: .FIELD_TYPE, fast_check: bool) -> err_msg: nil|string 

type .FieldTypeVal = .FIELD_TYPE | { .FIELD_TYPE.UOBJECT | .FIELD_TYPE.UOBJECT_SET, objty: string }

type .FieldKey = string|number|bool

type .FieldValueTableItem = bool|string|number|Entity|Vector|VMatrix|Angle|.FieldValueTable
type .FieldValueTableKey = bool|string|number|Entity
type .FieldValueTable = table(.FieldValueTableKey, .FieldValueTableItem)

--[[
    Simply, following types can be value of component field:
        .ObjectSet
        .Object
        bool, string, number, Entity        - this can also be table key and value
        Vector|VMatrix|Angle                - this can also be table value
        table                               - see previous two lines for possible keys and values
]]
type .FieldValue = .ObjectSet | .Object | .FieldValueTableItem
```

Object definition:
```
fn .RegisterObj(obj_ty: string, params: .ObjectParams)
fn .RegisterComp(obj_ty: string, comp_name: string, params: .ComponentDefParams)


type .ObjectParams = {
    --SaveCl: bool
    SaveSv: bool
    NetMode: array(string) | string={_value_}
}

type .ComponentDefParams = {
    --SaveCl: bool | nil -- If nil, inherit from owner
    SaveSv: bool | nil -- If nil, inherit from owner
    NetMode: array(string) | string={_value_} | nil -- If nil, inherit from owner
    Fields: table(name: string, {
        --SaveCl: bool | nil -- If nil, inherit from owner
        SaveSv: bool | nil -- If nil, inherit from owner
        NetMode: array(string) | string={_value_} | nil -- If nil, inherit from owner
        ForceNetMode: array(string) | string = {_value_} | nil -- Override networking mode
        Type: .FieldTypeVal
        AutoGetter: string|nil -- If not nil, name of auto-generated getter
        AutoSetter: string|nil -- If not nil, name of auto-generated getter
        -- If true, require value to be unique among all component fields in save set
        -- It means lookup by this field value is guaranteed to return zero or one object
        Unique: bool | nil=false 
        FastCheck: bool | nil=false -- If true and .Type == .FIELD_TYPE.TABLE, no recursive check will be done
    })
}

-- `recipents_fn` should modify it's second argument
fn .RegisterNetMode(netmode: string, obj_ty: string|nil, recipents_fn: fn(obj: .Object, recipents: CRecipentList))

fn .GetMetatable(obj_ty: string) -> table(any, any)|nil

fn .RegisterHook(obj_ty: string, comp_name: string, field_key: string,
    hook_name: string, hook: fn(obj: .Object(obj_ty), old: nil|.FieldValue, new: nil|.FieldValue))
```

Object instances:
```
fn .Manager(save_set: string, allow_db: bool) -> .Manager
readonly var .Managers: table(save_set: string, .Manager)
-- "Primary" manager that corresponds to active world state.
-- Actually, if it equals nil, you can not do much. Just assume it is not-nil
readonly var .Cur: .Manager|nil 

type .FindCriterion = "(" | ")" | "and" | "or" | "not" | {
    Name: .FieldKey,
    Value: .FieldValue
}

type .Manager = {
    -- (oid==nil)==self.AllowDatabaseIO
    fn :CreateObject(type: string, oid: .ObjectId|nil) -> .Object|nil

    fn :LoadObject(oid: .ObjectId) -> .Object|nil

    fn :FindLoadObjects(type: string, criteria: array(.FindCriterion)) -> array(.Object)
    fn :FindLoadObject(type: string, criteria: array(.FindCriterion)) -> .Object|nil

    readonly var .Instances: table(.ObjectId, .Object)
    readonly var .SaveSet: string
    readonly var .AllowDatabaseIO: bool

    fn :SaveObjects()

    fn :DeleteUnloadAll()
    fn :Shutdown() -- After this call, manager is no longer valid

    fn :__tostring() -> string

    fn :IsValid() -> bool
}

registered type .Object = {
    readonly var .Id: .ObjectId
    readonly var .SaveSet: string
    readonly var .Type: string
    readonly var .Manager: .Manager

    fn :Unload()
    fn :DeleteUnload()

    -- Object becomes invalid after :Unload() or :DeleteUnload() or .Manager:DeleteUnloadAll() or .Manager:Shutdown()
    fn :IsValid() -> bool 

    fn :Save(start_transaction: bool)

    meta var .Data: {
        -- On newly-created object indexing with registered component will return not-nil value
        fn :__index(comp_name: string) -> nil|{
            fn :__index(field_name: .FieldKey) -> nil|{
                fn .Get() -> .FieldValue|nil
                fn .GetForEdit() -> .FieldValue|nil
                fn .Set(value: .FieldValue|nil)
                fn .Edited()
            }
        }
    }

    fn :__tostring() -> String
}

registered type .ObjectSet = {
    -- [[
        for object in object_set:Iterate() do
            -- object is .Object
        end
    ]]
    fn :Iterate() -> !SEE COMMENT!

    fn :Add(item: .Object) -> added: bool
    fn :Remove(item: .Object) -> removed: bool

    fn :Count() -> uint
}

hook .ObjectCreated(obj: .Object)
hook .ObjectPreRemoved(obj: .Object)

hook .ComponentCreated(obj: .Object, comp_name: string, comp: .ComponentMeta)
hook .ComponentPreRemoved(obj: .Object, comp_name: string, object_removed: bool)

hook .FieldChanged(obj: .Object, comp: string, key: .FieldKey, oldvalue: .FieldTypes|nil, newvalue: .FieldTypes|nil)

```

## Data format

### In database

Objects
- Save set
- Object id
- Object type

Fields
- Save set
- Object id
- Component name
- Field set key (uint, may be non-sequencial, 0 - not a set member but header)
- Field key
- Value: object reference
- Value: normal (number|string)

### In memory

(If any parameter is nil, parent parameter value is used instead)
- Save/networking defenition
  - Save on client?
  - Save on server?
  - Networking mode

- Object defenition table (key is object type)
  - Object type
  - Save/networking
  
- Component defenition table (key is parent object type, second key is component name)
  - Parent object type
  - Component name
  - Save/networking
  - Field table (key is field name)
    - Field name
    - Save/networking
    - Is element of set?
    - Field type (bool|string|number|Vector|Angle|VMatrix|Entity|Object) (nil always allowed)
    - Unique in save set?
    - Auto-generated getter name, if any
    - Auto-generated setter name, if any

Networking mode functions here

- Manager table (key is save set)
  - Save set
  - Database I/O enabled?
  - Object table (key is object id)
    - Object Id
    - Object Type
    - Component table (key is component name)
      - Component name
      - Header-fields table (key is field name)
        - (K) Field name
        - Field value
      - Set-fields set (table, key is internal 'field set key')
        - (K) Field set key (nonzero_uint, may be non-sequencial)
        - Field table (key is field name)
          - (K) Field name
          - Field value
