DeriveGamemode("sandbox")

GM.Name = "Sandbox RP"
GM.Author = "stpM64"
GM.TeamBased = false


BoxRP = BoxRP or {}


STPLib.IncludeList("boxrp/", {
    "database_sqlite_sh.lua",
    "udata_def_sh.lua",
    "udata_util_sh.lua",
    "udata_sh.lua",
    "udata_db_sv.lua",
    "udata_net_sh.lua",
    "module_sh.lua",
})