local SqlQuery = BoxRP.SQLite.SqlQuery
local SqlQuerySingle = BoxRP.SQLite.QuerySingle
local sql_SQLStr = sql.SQLStr
local table_insert = table.insert
local table_concat = table.concat
local string_format = string.format

SqlQuery([[
    PRAGMA foreign_keys = ON; -- Probably no addon will require this disabled

    CREATE TABLE IF NOT EXISTS boxrp_characters (
        id INTEGER          PRIMARY KEY AUTOINCREMENT NOT NULL,
        ply_steamid TEXT    NOT NULL
    ) STRICT;

    CREATE TABLE IF NOT EXISTS boxrp_characters_data (
        char_id INTEGER     NOT NULL,
        key TEXT            NOT NULL,
        value TEXT          NOT NULL,

        UNIQUE (char_id, key),
        FOREIGN KEY (char_id) REFERENCES boxrp_characters(id) ON DELETE CASCADE
    ) STRICT;
]])

local DB = {}

function DB.CreateCharacter(ply)
    assert(not ply:IsBot(), "'ply' is bot, bots can not have characters")

    return SqlQuerySingle([[
        INSERT INTO boxrp_characters (ply_steamid)
            VALUES ({steamid})
            RETURNING boxrp_characters.id AS char_id
    ]], { steamid = ply:SteamID()}).char_id
end

function DB.RemoveCharacterById(char_id)
    SqlQuery([[
        DELETE FROM boxrp_characters
            WHERE boxrp_characters.id == {char_id}
    ]], { char_id = char_id })
end

-- Returns array of { char_id: int } 
function DB.RemoveCharactersBySteamId(steamid)
    return SqlQuery([[
        DELETE FROM boxrp_characters
            WHERE boxrp_characters.ply_steamid == {steamid}
            RETURNING boxrp_characters.id AS char_id
    ]])
end


function DB.TransferCharacter(char_id, new_steamid)
    SqlQuery([[
        UPDATE boxrp_characters
            SET ply_steamid = {new_steamid}
            WHERE boxrp_characters.id == {char_id}
    ]], { char_id = char_id, new_steamid = new_steamid })
end

function DB.GetCharacterSteamId(char_id)
    local result = SqlQuerySingle([[
        SELECT ply_steamid FROM boxrp_characters
            WHERE boxrp_characters.char_id == {char_id}
    ]], { char_id = char_id })

    return result ~= nil and result.ply_steamid or nil
end


function DB.SetData(char_id, key, value)
    assert(value == nil or isstring(value), "'value' is neither nil nor string")

    if value == nil then
        SqlQuery([[
            DELETE FROM boxrp_characters_data as cdata
                WHERE cdata.char_id == {char_id} AND cdata.key == {key}
        ]], { char_id = char_id, key = key })
    else
        SqlQuery([[
            INSERT OR REPLACE INTO boxrp_characters_data
                (char_id, key, value)
                VALUES ({char_id}, {key}, {value})
        ]], { char_id = char_id, key = key, value = value })
    end
end

function DB.UpdateDataMany(char_id, kvs)
    local values = {}

    char_id = sql_SQLStr(char_id)

    for k, v in pairs(kvs) do
        table_insert(values, string_format("(%s, %s, %s)",
            char_id, sql_SQLStr(k), sql_SQLStr(v)))
    end

    SqlQuery([[
        INSERT OR REPLACE INTO boxrp_characters_data
            (char_id, key, value)
            VALUES {$values}
    ]], { values = table_concat(values, ", ") })
end

function DB.DeleteDataMany(char_id, keys)
    for i, key in ipairs(keys) do
        keys[i] = sql_SQLStr(key)
    end

    SqlQuery([[
        DELETE FROM boxrp_characters_data as cdata
            WHERE cdata.char_id == {char_id} AND cdata.key IN {$keys}
    ]], { char_id = char_id, keys = table_concat(keys, ", ") })
end

function DB.GetData(char_id, key)
    local result = SqlQuerySingle([[
        SELECT value FROM boxrp_characters_data AS cdata
            WHERE cdata.char_id == {char_id} AND cdata.key == {key} 
    ]], { char_id = char_id, key = key })

    return result ~= nil and result.value or nil
end

function DB.GetAllData(char_id)
    local result = SqlQuery([[
        SELECT key, value FROM boxrp_characters_data AS cdata
            WHERE cdata.char_id == {char_id}
    ]], { char_id = char_id })

    return result
end

BoxRP.Char._DB = DB