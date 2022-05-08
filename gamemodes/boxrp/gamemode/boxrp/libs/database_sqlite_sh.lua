local sql_Query = sql.Query
local sql_LastError = sql.LastError
local sql_SQLStr = sql.SQLStr
local string_gsub = string.gsub
local string_StartWith = string.StartWith
local string_sub = string.sub

BoxRP.SQLite = {}

-- Returns table or errors
function BoxRP.SQLite.Query(expr, args)

    local query = string_gsub(expr, "{(%w%w-)}", function(key)
        if string_StartWith(key, "$") then
            return args[string_sub(key, 2)]
        end

        return sql_SQLStr(args[key])
    end)

    local result = sql_Query(query)

    if result == nil then
        error("SQL query error:", sql_LastError())
    end

    return result
end

-- Returns nil if there is >1 or zero results
-- Else returns value
function BoxRP.SQLite.QuerySingle(expr, raw_args)
    local result = BoxRP.SQLite.Query(expr, raw_args)

    local k1, v1 = next(result, nil)
    if v1 == nil then return nil end

    local _k2, v2 = next(result, k1)
    if v2 ~= nil then return nil end

    assert(k1 == 1, "Single query result key is not '1'")

    return v1
end

BoxRP.SQLite.Query([[
    PRAGMA foreign_keys = ON; -- Probably no addon will require this disabled
]])