local DB = BoxRP.Char._DB

local ActiveChars = ActiveChars or {}

local function GetCheckChar(id)
    local char = ActiveChars[id]
    if char == nil then error("Character #",id," unloaded or not exists") end
    return char
end

local function LoadChar(id)
    if ActiveChars[id] ~= nil then
        error("Character #",id," is already loaded")
    end

    local steamid = DB.GetCharacterSteamId(id)

    if steamid == nil then
        return nil
    end

    local tbl = {
        Id = id,
        OwnerSteamId = steamid,
        Data = {},
        DataUnsaved = {},
    }

    ActiveChars[id] = tbl

    return tbl
end

local function TransferChar(id, new_steamid)
    local char = GetCheckChar(id)

    DB.TransferCharacter(id, new_steamid)
    char.OwnerSteamId = new_steamid

    -- TODO: get Player entity
end


local function LoadCharData(id, key)
    local ch = GetCheckChar(id)

    local val_str = DB.GetData(id, key)
    if val_str == nil then return nil end

    local val = util.JSONToTable(val_str)
    if val == nil then return nil end

    ch.Data[key] = val
    ch.DataUnsaved[key] = false

    return val
end

local function SaveAllCharData(id)
    local ch = GetCheckChar(id)

    local update = {}
    local delete = {}

    local saved = {}

    for key, is_unsaved in pairs(ch.DataUnsaved) do
        if is_unsaved == false then continue end

        table.insert(saved, key)

        local data = ch.Data[key]

        if data == nil then
            table.insert(delete, key)
        else
            update[key] = util.TableToJSON(data)
        end
    end

    DB.UpdateDataMany(id, update)
    DB.DeleteDataMany(id, delete)

    for _, key in ipairs(saved) do
        ch.DataUnsaved[key] = false
    end
end

local function UnloadChar(id, no_save)
    if ActiveChars[id] == nil then error("Character #",id," not exists or already unloaded") end

    if no_save ~= true then
        SaveCharData(id)
    end

    ActiveChars[id] = nil
end

