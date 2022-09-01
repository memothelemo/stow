# Stow
An experimental data store module for ROBLOX (with backup/database server)

## Disclaimer
This release of this module is under early stages. API (both server and the module)
will subject to change drastically in the future.

## License
I haven't decided what license should I use for this module. Serious and
production projects should not be used yet!

If you're using this for your non-important experimental projects,
go for it! :)

## Demonstration
```lua
local Stow = require(path.to.Stow)

local Store = Stow.GetStore(
    { name = "PlayerData", scope = "MyScope", },
    "data.server.com",
    "372h37h78r2h38723h78r23yh287",
    {
        Cash = 1,
    }
)

local function onPlayerAdded(player)
    local store = Store:LoadProfile(tostring(player.UserId))
    print(store)
end
```
