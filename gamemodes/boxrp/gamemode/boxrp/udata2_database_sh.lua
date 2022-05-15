local check_ty = BoxRP.CheckType
local SQL = BoxRP.SQLite.Query
local SQLSingle = BoxRP.SQLite.QuerySingle
local SQLEscape = sql.SQLStr

local function SQLEscapeNullable(val)
    if val == nil then
        return "NULL"
    else
        return SQLEscape(val)
    end
end

---------------------

BoxRP.UData2._Database = BoxRP.UData2._Database or {}

---------------------

--[[
    save_set    Name of save set (think of save file name)
    obj_id      UData object id 
    obj_type    UData object type
    comp_name   UData object component name (table-object key name)

]]

local SQL_OBJECT_ID_CHECK = [[CHECK(obj_id > 0 AND obj_id < 1 << 31)]]

SQL([[
    CREATE TABLE IF NOT EXISTS boxrp_udata_obj (
        save_set    TEXT NOT NULL,
        obj_id      INT NOT NULL {$obj_id_check},

        obj_type    TEXT NOT NULL,

        PRIMARY KEY (save_set, obj_id)
    ) STRICT;

    CREATE INDEX IF NOT EXISTS boxrp_udata_obj__saveset
        ON boxrp_udata_obj (save_set);

    CREATE INDEX IF NOT EXISTS boxrp_udata_obj__saveset_objtype
        ON boxrp_udata_obj (save_set, obj_type);

    CREATE TABLE IF NOT EXISTS boxrp_udata_field (
        save_set    TEXT NOT NULL,
        obj_id      INT NOT NULL {$obj_id_check},
        comp_name   TEXT NOT NULL,
        field_name  ANY NOT NULL,
        
        value_any   ANY,
        value_xref  INT {$obj_id_check}

        PRIMARY KEY (save_set, obj_id, comp_name, field_name),
        FOREIGN KEY (save_set, obj_id)
            REFERENCES boxrp_udata_obj
            ON DELETE CASCADE
            ON UPDATE CASCADE,
        FOREIGN KEY (save_set, value_xref)
            REFERENCES boxrp_udata_obj (save_set, obj_id)
            ON DELETE CASCADE
            ON UPDATE CASCADE,
        CHECK( (value_any NOT NULL) + (value_xref NOT NULL) == 1) -- One and only one of the values should be not-null
    ) STRICT;

    CREATE INDEX IF NOT EXISTS boxrp_udata_field__saveset_objid
        ON boxrp_udata_field (save_set, obj_id);

    CREATE INDEX IF NOT EXISTS boxrp_udata_field__saveset_objid_compname
        ON boxrp_udata_field (save_set, obj_id, comp_name);

    CREATE TEMP TABLE IF NOT EXISTS boxrp_udata_supported_comps (
        obj_type    TEXT NOT NULL,
        comp_name   TEXT NOT NULL

        PRIMARY KEY (obj_type, comp_name)
    ) STRICT
]], { obj_id_check = SQL_OBJECT_ID_CHECK })


-------- Database - util

function BoxRP.UData2._Database.RegisterSupportedComponent(obj_type, comp_name)

    SQL([[
        INSERT OR IGNORE 
            INTO boxrp_udata_supported_comps (obj_type, comp_name)
            VALUES ({obj_type}, {comp_name})
    ]], {obj_type = obj_type, comp_name = comp_name})
end

-------- Database - object

function BoxRP.UData2._Database.CreateSaveObject(save_set, obj_type)
    local q_result = SQLSingle([[
        INSERT INTO boxrp_udata_obj (save_set, obj_id, obj_type)
            SELECT {save_set}, max(obj.obj_id) + 1, {obj_type}
                FROM boxrp_udata_obj AS obj
                WHERE obj.save_set == {save_set}
            RETURNING boxrp_udata_obj.obj_id
    ]], {save_set = save_set, obj_type = obj_type})

    return q_result.obj_id
end

function BoxRP.UData2._Database.LoadObject(save_set, obj_id)
    local q_result = SQLSingle([[
        SELECT obj.obj_type
            FROM boxrp_udata_obj AS obj
            WHERE obj.save_set == {save_set} AND obj.obj_id == {obj_id}
    ]], { save_set = save_set, obj_id = obj_id })

    if q_result == nil then
        return nil
    else
        return q_result.obj_type
    end
end

function BoxRP.UData2._Database.DeleteObject(save_set, obj_id)
    SQL([[
        DELETE FROM boxrp_udata_obj as obj
            WHERE obj.save_set == {save_set} AND obj.obj_id == {obj_id}
    ]], {save_set = save_set, obj_id = obj_id})
end

function BoxRP.UData._Database.DeleteAllObjects(save_set)
    SQL([[
        DELETE FROM boxrp_udata_obj as obj
            WHERE obj.save_set == {save_set}
    ]], {save_set = save_set})
end

function BoxRP.UData2._Database.LoadObjectsRecursive(save_set, obj_ids, supported_only)
    local q_obj_ids = {}
    for i, obj_id in ipairs(obj_ids) do
        q_obj_ids[i] = "("..SQLEscape(obj_id)..")"
    end
    q_obj_ids = table.concat(q_obj_ids, ", ")

    local q_objrefs

    if supported_only then
        q_objrefs = [[
            obj_refs (save_set, self_id, ref_id) AS (
                SELECT 
                    boxrp_udata_obj.save_set, 
                    boxrp_udata_obj.obj_id, 
                    boxrp_udata_field.value_xref
                    FROM 
                        boxrp_udata_obj 
                        NATURAL JOIN boxrp_udata_field
                        NATURAL JOIN boxrp_udata_supported_comps
                    WHERE boxrp_udata_field.value_xref NOT NULL
            )
        ]]
    else
        q_objrefs = [[
            obj_refs (save_set, self_id, ref_id) AS (
                SELECT 
                    boxrp_udata_obj.save_set, 
                    boxrp_udata_obj.obj_id, 
                    boxrp_udata_field.value_xref
                    FROM 
                        boxrp_udata_obj
                        NATURAL JOIN boxrp_udata_field
                    WHERE boxrp_udata_field.value_xref NOT NULL
            )
        ]]
    end

    return SQL([[
        WITH RECURSIVE
            {$q_objrefs},
            obj_refs_rec (obj_id) AS (
                VALUES ({q_obj_ids}) 
                UNION ALL SELECT obj_refs.ref_id
                    FROM obj_refs
                    WHERE obj_refs.save_set == {save_set}
                        AND obj_refs.self_id == obj_refs_rec.obj_id

            )
        SELECT DISTINCT obj_refs_rec.obj_id, boxrp_udata_obj.obj_type 
            FROM obj_refs_rec
                NATURAL JOIN boxrp_udata_obj
    ]], { save_set = save_set, q_obj_ids = q_obj_ids, q_objrefs = q_objrefs })
end

-------- Database - components/fields

--[[
    fn DB_LoadComponents(save_set: string, obj_id: .ObjectId, supported_only: bool) 
        -> array({
            comp_name: string,
            field_name: string|number,
            value: string|number,
            is_xref: bool
        })
]]
function BoxRP.UData2._Database.LoadComponents(save_set, obj_id, supported_only)
    local q_support_join = supported_only and "NATURAL JOIN boxrp_udata_supported_comps" or ""

    local q_result = SQL([[
        SELECT
            field.comp_name, 
            field.field_name,
            ifnull(field.value_any, field.value_xref) AS value
            (field.value_xref NOT NULL) as is_xref
            FROM 
                boxrp_udata_obj AS obj
                NATURAL JOIN boxrp_udata_field as field
                {$q_support_join}
            WHERE
                obj.save_set == {save_set}
                AND obj.obj_id == {obj_id}
    ]], { save_set = save_set, obj_id = obj_id, q_support_join = q_support_join })

    return q_result
end

--[[
    ! Wrap this function with transaction to achieve peformance
    If components = { blah = {} }, component 'blah' will be removed

    fn DB_SaveComponents(save_set: string, obj_id: .ObjectId, components: table(comp_name: string, array({
        field_name: string|number,
        value_any: string|number|nil,
        value_xref: number|nil
    })))
]]

function BoxRP.UData2._Database.SaveComponents(save_set, obj_id, components)
    for comp_name, fields in pairs(components) do
        local q_compdata = {}
        for i, field in ipairs(fields) do
            q_compdata[i] =
                "("..SQLEscape(fields.field_name)..", "..SQLEscapeNullable(fields.value_any)
                    ..", "..SQLEscapeNullable(fields.value_xref).." )"

        end
        q_compdata = table.concat(q_compdata, ", ")

        SQL([[
            DELETE FROM boxrp_udata_field AS field
                WHERE field.save_set == {save_set} AND field.obj_id == {obj_id};

            INSERT INTO boxrp_udata_field
                (save_set, obj_id, comp_name, field_name, value_any, value_xref)
                SELECT 
                    {save_set}, {obj_id}, {comp_name}, *
                    FROM (VALUES ({$q_compdata}))
        ]], { save_set = save_set, obj_id = obj_id, q_compdata = q_compdata, comp_name = comp_name })
    end
end

--[[
    type FindConstraint = "AND" | "OR" | "NOT" | "(" | ")" {
        Name: string,
        Value: number|.ObjectId|string,
        IsXRef: bool
    }

    !! SECURITY WARNING: if .FindConstraint is a string, SQL injection is possible. Check string arguments if they come from user code

    fn DB_FindObjectByComponent(save_set: string, obj_type: string, comp_name: string, constraints: array(FindConstraint)) -> array(.ObjectId)
]]
function BoxRP.UData2._Database.FindObjectByComponent(save_set, obj_type, comp_name, constraints)
    local q_constraints = {}

    for i, constraint in ipairs(constraints) do
        if isstring(constraint) then
            q_constraints[i] = constraint
        else
            local q_constraint = "( field.field_name == "..SQLEscape(constraint.Name).." AND "

            if constraint.IsXRef then
                q_constraint = q_constraint.."field.value_xref"
            else
                q_constraint = q_constraint.."field.value_any"
            end
            q_constraints[i] = q_constraint.." == "..SQLEscape(constraint.Value).." )"
        end
    end

    local q_constraints_concat = table.concat(q_constraints, " ")

    local q_result = SQL([[
        SELECT DISTINCT obj.obj_id
            FROM
                boxrp_udata_obj AS obj
                NATURAL JOIN boxrp_udata_comp AS comp
                NATURAL JOIN boxrp_udata_field AS field
            WHERE 
                obj.save_set == {save_set}
                AND obj.obj_type == {obj_type}
                AND comp.comp_name == {comp_name}
                AND ({$q_constraints_concat})
    ]], {
        save_set = save_set,
        obj_type = obj_type,
        comp_name = comp_name,
        q_constraints_concat = q_constraints_concat
    })

    local result = {}
    for i, q_item in ipairs(q_result) do
        result[i] = q_item.obj_id
    end

    return result
end

