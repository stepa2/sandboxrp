# BoxRP.Command

```
fn .Register(cfg: {
    -- Should include command prefix (\ or ! or whatever)
    -- Use array for multiple aliases
    Name: string | array(string),

    -- User-displayed command description
    Desc: nil | string,

    Arguments: array(.CmdArgumentDef),

    -- Return true to allow executing command
    -- Return false to disallow execution
    -- Return string to disallow execution with custom error message
    Checker: nil|fn(ply: Player) -> bool|string,

    -- Return true or nil if command executed successfuly
    -- Return false or string if command failed (string for custom error message)
    SV Execute: fn(caller: Player, args: table(<.CmdArgumentDef.ValName>, <value>)) -> nil|bool|string
})

type .CmdArgumentDef = {
    Type: <.CmdArgumentType>
    ValName: string
}

fn .RegisterType(typename: string, cfg: {
    -- start_cp in Unicode codepoints 
    -- Parsing considered failed only if third return value is not nil
    -- Second return value (end_idx) is last codepoint index of parsed value
    --   (space may be excluded)
    -- You can return nil,$number,nil for successfully parsed nil
    TryParse: fn(fullcmd: string, start_cp: uint, args: array(any)) -> value: any|nil, end_idx: uint|nil error_msg: nil|string,

    DisplayName: string
})

-- If some chat text matches the `prefix_regex`, it is considered to be a command
fn .RegisterPrefix(prefix_regex: string)

fn .RegisterRelay(cfg: {
    PrefixRegex: string,
    GetCommands: 
})
```

`.CmdArgumentType` is always an array, first element is always string, name of the type (`typename` from `.RegisterType`)

## Predefined command types

- `bool` - true/1/yes for `true`, false/0/no for `false`
- `int` - interger `number`s
- `uint` - non-negative integer `number`s
- `pint` - positive `number`s
- `real` - `number`
- `ureal` - non-negative `number`s
- `preal` - positive `number`s
- `str` - `string`
  - If `Arguments = {{"str"},{"bool"}}`
    - `example yes` -> `{"example", true}`
    - `"example yes"` -> `{"example yes"}`
- `str_eol` - `string`, always captures everything up to the end of the command
- `entity` - `Entity`
  - Accepts entity id (integer)
  - Accepts creation id in format `CrID:00000000`
- `player` - `Player`
  - Accepts everything from `entity`, if found entity is a player
  - Accepts player name (partial too, if it is unique)
  - Accepts SteamID
  - Accepts user id in format `Usr:000`

- `option` - second array element is `.CmdArgumentType`.
  If type specified by second element can not be parsed, will not error, instead will return `nil`
