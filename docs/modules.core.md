# modules/core/_base.lua
Defines:
- "everyone" networking mode - sending data to all human players
- "none" networking mode - sending data to noone
- "core_char" object type - roleplaying character
  - Sent to everyone
  - Saved on client and server
- "core_player" object type - serverside player info
  - Sent to noone
  - Saved on server only
- "core_charmemory" object type - memory of one character about another 
  - Saved on client and server
  - Sent to owner of memory-owner character
- "core_charmemory" object type - memory of character(s) about another character 
  - Saved on client and server
  - Sent to player(s) that use memory-owner character(s)

# modules/core/player_steamid.lua
**TODO**: Family sharing detection/handling
```
SV readonly var Player.BoxRP_PlayerData: .Object("core_playerdata")

fn .Object("core_playerdata"):Core_GetSteamId() -> string
```

# modules/core/char_owner.lua
Defines:
- "ownerply" networking mode for "core_char" - send to :Core_GetOwnerEnt() if it is a player

```
fn .Object("core_char"):Core_GetOwnerData() -> nil|.Object("core_playerdata")
fn .Object("core_char"):Core_GetOwnerEnt() -> nil|Entity

SV fn .Object("core_char"):Core_SetOwnerData(data: nil|.Object("core_playerdata"), update_ent: bool|nil=false)
SV fn .Object("core_char"):Core_SetOwnerEnt(ent: nil|Entity, update_data: bool|nil=false)

readonly var Entity.BoxRP_Character: nil|.Object("core_char")
```