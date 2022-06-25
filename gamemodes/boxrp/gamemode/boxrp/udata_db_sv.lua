local SQL = BoxRP.SQLite.Query
local SQLSingle = BoxRP.SQLite.QuerySingle
local SQLEscape = sql.SQLStr

BoxRP.UData = BoxRP.UData or {}

SQL [[
    BEGIN;
        CREATE TABLE IF NOT EXISTS boxrp_objects (
            obj_id              INTEGER PRIMARY KEY,
            obj_type        TEXT NOT NULL
        );

        CREATE TABLE IF NOT EXISTS boxrp_objvalues (
            obj_id          INT NOT NULL,
            key             TEXT NOT NULL,
            value_plain     ANY,
            value_objref    INT,

            PRIMARY KEY (obj_id, key),
            -- One and only one value should be not-null
            CHECK (value_plain NOT NULL + value_objref NOT NULL == 1),

            FOREIGN KEY (obj_id) REFERENCES boxrp_objects(obj_id)
                ON UPDATE CASCADE
                ON DELETE CASCADE,
            FOREIGN KEY (value_objref) REFERENCES boxrp_objects(obj_id)
                ON UPDATE CASCADE
                ON DELETE CASCADE
        );

        CREATE TEMPORARY TABLE IF NOT EXISTS boxrp_objreg (
            obj_type    TEXT NOT NULL,
            key         TEXT NOT NULL, -- dictionary-type object if empty string
            -- 0 - plain value
            -- 1 - object reference
            -- 2 - lazy object reference
            mode        INT NOT NULL,
            
            PRIMARY KEY (obj_type, key)
        );
    COMMIT
]]

local function FieldModeFromDef(def)
    if istable(def.Type) then
        if def.Type[1] == "object" then
            return 1
        else -- "object_lazy"
            return 2
        end
    else
        return 0
    end
end

function BoxRP.UData.DB_RegisterField(objty, key, def)
    SQL([[
        BEGIN;
            DELETE FROM boxrp_objreg AS objreg
                WHERE objreg.obj_type == {objty} AND objreg.key == "";
            INSERT OR REPLACE INTO boxrp_objreg
                (obj_type, key, mode)
                VALUES ({objty}, {key}, {mode});   
        COMMIT
    ]], {objty = objty, key = key, mode = FieldModeFromDef(def)})
end

function BoxRP.UData.DB_RegisterFieldEvery(objty, def)
    SQL([[
        BEGIN;
            DELETE FROM boxrp_objreg AS objreg
                WHERE objreg.obj_type != {objty};
            INSERT INTO boxrp_objreg
                (obj_type, key, mode)
                VALUES ({objty}, "", {mode});
        COMMIT
    ]], {objty = objty, mode = FieldModeFromDef(def)})
end

function BoxRP.UData.DB_RemoveAll()
    SQL [[
        BEGIN;
            DELETE FROM boxrp_objects;
            DELETE FROM boxrp_objvalues;
        COMMIT
    ]]
end

function BoxRP.UData.DB_CreateSaveObj(objty)
    local q_ret = SQLSingle([[
        INSERT INTO boxrp_objects AS object 
            (obj_type)
            VALUES ({objty});

        SELECT last_insert_rowid() AS obj_id
    ]], {objty = objty})
    assert(q_ret ~= nil)

    return q_ret.obj_id
end

function BoxRP.UData.DB_RemoveObjs(ids)
    local q_ids = {}
    for i, id in ipairs(ids) do q_ids[i] = SQLEscape(id) end
    q_ids = table.concat(q_ids, ",")

    SQL([[
        DELETE FROM boxrp_objects AS object
            WHERE object.obj_id IN ({$q_ids}) 
    ]], {q_ids = q_ids})
end

function BoxRP.UData.DB_LoadObjRecursive(ids)
    local q_ids = {}
    for i, id in ipairs(ids) do q_ids[i] = "("..SQLEscape(id)..")" end
    q_ids = table.concat(q_ids, ",")

    local q_ret = SQL([[
        WITH RECURSIVE 
            obj_refs (obj_id, ref_id) AS (
                SELECT boxrp_objects.obj_id, boxrp_objvalues.value_objref
                FROM 
                    boxrp_objects 
                    NATURAL JOIN boxrp_objvalues
                    JOIN boxrp_objreg 
                        ON boxrp_objects.obj_type == boxrp_objreg.obj_type 
                            AND (boxrp_objreg.key == "" OR boxrp_objreg.key == boxrp_objvalues.key)
                            AND boxrp_objreg.mode != 2
                WHERE
                    boxrp_objvalues.value_objref NOT NULL
            ),
            obj_refs_rec (obj_id) AS (
                VALUES {$q_ids}
                UNION obj_refs_rec
                UNION SELECT obj_refs.ref_id
                    FROM obj_refs_rec NATURAL JOIN obj_refs
            )
        SELECT
            object.obj_id AS id,
            object.obj_type AS type
        FROM
            obj_refs_rec NATURAL JOIN boxrp_objects AS object
    ]], {q_ids = q_ids})

    return q_ret
end

function BoxRP.UData.DB_LoadFields(ids)
    local q_ids = {}
    for i, id in ipairs(ids) do q_ids[i] = "("..SQLEscape(id)..")" end
    q_ids = table.concat(q_ids, ",")

    local q_ret = SQL([[
        WITH
            ids (obj_id) AS ( VALUES {$q_ids} )
        SELECT
            object.obj_id AS id,
            value.key AS key,
            ifnull(value.value_plain, value.value_objref) AS value
        FROM
            boxrp_objects AS object
            NATURAL JOIN ids
            NATURAL JOIN boxrp_objvalues AS value
            JOIN boxrp_objreg
                ON object.obj_type == boxrp_objreg.obj_type
                    AND (boxrp_objreg.key == "" OR boxrp_objreg.key == value.key)
    ]], {q_ids = q_ids})

    return q_ret
end

function BoxRP.UData.DB_SaveFields(fields)
    local q_fields_val = {}
    local q_fields_noval = {}

    for i, field in ipairs(fields) do
        if field.value == nil then
            table.insert(q_fields_noval, "("..SQLEscape(field.id)..","..SQLEscape(field.key)..")")
        else
            local value
            if field.is_objref then
                value = "NULL,"..SQLEscape(value)
            else
                value = SQLEscape(value)..",NULL"
            end

            table.insert(q_fields_val, "("..SQLEscape(field.id)..","..SQLEscape(field.key)..","..value..")")
        end
    end

    q_fields_val = table.concat(q_fields_val, ", ")
    q_fields_noval = table.concat(q_fields_noval, ", ")

    SQL([[
        DELETE FROM boxrp_objvalues AS value
            WHERE (value.obj_id, value.key) IN ({$q_fields_noval});
        
        INSERT OR REPLACE INTO boxrp_objvalues
            (obj_id, key, value_plain, value_objref)
            VALUES {$q_fields_val}
    ]], {q_fields_noval = q_fields_noval, q_fields_val = q_fields_val})
end

function BoxRP.UData.DB_FindByField(objty, key, value, is_objref)
    if field_value == nil then
        return SQL([[
            SELECT object.obj_id AS id
                FROM boxrp_objects AS object
                WHERE NOT EXISTS (
                    SELECT *
                        FROM boxrp_objvalues AS value
                        WHERE value.obj_id == object.obj_id
                            AND value.key == {key}
                )
        ]], {key = key})
    else
        return SQL([[
            SELECT object.obj_id AS id
                FROM boxrp_objects AS object 
                    NATURAL JOIN boxrp_objvalues AS value
                WHERE object.obj_type == {objty}
                    AND value.key == {field_key}
                    AND value.{$value_field} == {value}
        ]], {
            objty = objty, key = key, value = value,
            value_field = is_objref and "value_objref" or "value_plain"
        })
    end
end

function BoxRP.UData.Create(objtype)
    local id = BoxRP.UData.DB_CreateSaveObj(objtype)
    return BoxRP.UData._Create(objtype, id)
end

local function _LoadMany(params)
    local ids = {}

    for i, param in ipairs(params) do
        if BoxRP.UData.Objects[param.id] ~= nil then
            continue
        end

        BoxRP.UData._Create(params.type, params.id)
        table.insert(ids, params.id)
    end

    local fields = BoxRP.UData.DB_LoadFields(ids)
    for _, field in ipairs(fields) do
        BoxRP.UData.Objects[field.id]:Raw_Set(
            field.key, BoxRP.UData.Util_SqlToMem(field.value),
            true -- unchecked
        )
    end
end

function BoxRP.UData.Load(id)
    BoxRP.UData.LoadMany({id})
    return BoxRP.UData.Objects[id]
end

function BoxRP.UData.LoadMany(ids)
    if #ids == 0 then return end

    _LoadMany(BoxRP.UData.DB_LoadObjRecursive(ids))
end

function BoxRP.UData.Object:Save()
    if self._unsaved == nil then return end

    local fields = {}
    self:_Save_GetData(fields)

    if table.IsEmpty(fields) then return end

    BoxRP.UData.DB_SaveFields(fields)
end

function BoxRP.UData.Object:_Save_GetData(out_fields)
    for field, _ in pairs(self._unsaved) do
        local value_mem = self._data[field]
        local field_def = BoxRP.UData.GetFieldDef(self.Type, field)
        -- If you have nil error on next line, probably this field is not defined
        -- Check for :Raw_Save with unchecked=true
        if field_def.SaveSv == false then continue end

        local value_type = field_def.Type
        local value_sql, is_objref = BoxRP.UData.Util_MemToSql(value_mem, value_type)

        table.insert(out_fields, {
            id = self.Id,
            key = field,
            value = value_sql,
            is_objref = is_objref
        })
    end

    self._unsaved = {}
end

hook.Add("BoxRP.UData.ObjectLoaded", "BoxRP.UData.LoadSaveInit", function(obj)
    if obj._def.Obj.SaveSv then
        obj._unsaved = {}
    end
end)

hook.Add("BoxRP.UData.ObjectPreUnloaded", "BoxRP.UData.UnloadSave", function(obj)
    obj:Save()
end)

hook.Add("BoxRP.UData.FieldChanged", "BoxRP.UData.MarkUnsaved", function(obj, fieldkey, _, _)
    if obj._unsaved == nil then return end
    obj._unsaved[fieldkey] = true
end)

function BoxRP.UData.SaveAll()
    local fields = {}

    for _, obj in pairs(BoxRP.UData.Objects) do
        if obj._unsaved ~= nil then
            obj:_Save_GetData(fields)
        end
    end

    if table.IsEmpty(fields) then return end
    BoxRP.UData.DB_SaveFields(fields)
end

timer.Create("BoxRP.UData.AutoSave", 90, 0,
    BoxRP.UData.SaveAll
)

function BoxRP.UData.Object:DeleteUnload()
    BoxRP.UData.DB_RemoveObjs({self.Id})
    self._unsaved = {}
    self:Unload()
end