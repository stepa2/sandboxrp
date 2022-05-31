
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
