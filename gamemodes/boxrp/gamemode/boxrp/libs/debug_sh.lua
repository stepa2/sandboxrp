local function ConcatToString(parts)
    for i, part in ipairs(parts) do
        parts[i] = tostring(part)
    end

    return table.concat(parts, "")
end

function BoxRP.Error(...)
    error(ConcatToString({...}), 2)
end

function BoxRP.ToString(val, pretty_print)
    pretty_print = pretty_print or false

    if val == nil then
        return "nil"
    elseif istable(val) then
        local meta = debug.getmetatable(val)
        if meta == nil or meta.__tostring == nil then
            return table.ToString(val, nil, pretty_print)
        end
    end

    return tostring(val)
end

local types = types or {}

function BoxRP.RegisterType(name, tbl)
    assert(isstring(name), "'name' is not a string")
    assert(istable(tbl), "'tbl' is not a table")

    local checker = tbl.IsInstance
    assert(isfunction(checker), "'tbl.IsInstance' is not a function")

    types[name] = checker
end

function BoxRP.CheckType(val, valname, allowed_types)
    for _, allowed_ty in ipairs(allowed_types) do
        if types[allowed_ty](val) then
            return val
        end
    end

    error(ConcatToString({
        "'",valname,"' is not a ",table.concat(allowed_types, "|"),",\n",
        "it is a [",type(val),"] ",BoxRP.ToString(val, true)
    }), 2)
end

BoxRP.RegisterType("nil", { IsInstance = function(v) return v == nil end})
BoxRP.RegisterType("number", { IsInstance = function(v) return isnumber(v) end})
BoxRP.RegisterType("string", { IsInstance = function(v) return isstring(v) end})
BoxRP.RegisterType("table", { IsInstance = function(v) return istable(v) end})
BoxRP.RegisterType("bool", { IsInstance = function(v) return isbool(v) end})
BoxRP.RegisterType("Entity", { IsInstance = function(v) return IsEntity(v) end})
BoxRP.RegisterType("Player", { IsInstance = function(v) return IsEntity(v) and v:IsPlayer() end})
BoxRP.RegisterType("Panel",  { IsInstance = function(v) return ispanel(v) end})
BoxRP.RegisterType("Vector", { IsInstance = function(v) return isvector(v) end})
BoxRP.RegisterType("Angle", { IsInstance = function(v) return isangle(v) end})
BoxRP.RegisterType("Matrix", { IsInstance = function(v) return ismatrix(v) end})