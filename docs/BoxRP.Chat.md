# BoxRP.Chat

```
fn .RegisterMode(modename: string, config: .ChatModeConfig)

type .ChatModeConfig = {
    Parse = nil | .ChatParseFn | .ChatParseCommand,
}

-- Function should return message contents 
type .ChatParseFn = fn(full_msg: string) -> msg_text: string|nil

```