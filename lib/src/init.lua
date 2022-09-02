local Stow = {}

local DEBUG_MODE = true
local SERVER_ID = game.JobId

if SERVER_ID:len() == 0 or SERVER_ID == nil then
    SERVER_ID = game:GetService("HttpService"):GenerateGUID(false)
end

local Http = require(script.Http)
local TableUtil = require(script.TableUtil)

local StowStore = {
    --[[
        _storeName: string,
        _storeScope?: string,

        _databaseEnabled: bool,
        _databaseUrl: string,
        _databaseToken: string,

        _template: table,

        _headers(): Dictionary,
        _registerClientSession(): (),
    ]]
}
StowStore.__index = StowStore

local function log(template, ...)
    if DEBUG_MODE then
        warn("[Stow Debug]", string.format(template, ...))
    end
end

--[[
    Forms a default HTTP headers for the Stow database API
]]
function StowStore:_headers(...)
    return TableUtil.Assign({
        Authorization = self._databaseToken,
        Server = SERVER_ID,
    }, ...)
end

--[[
    Registers a new session to the Stow database API
]]
function StowStore:_registerClientSession()
    assert(self._databaseEnabled, "Database backup is disabled!")

    log("[%s] registering client session from database API (url = %s)", self._storeName, self._databaseUrl)
    local data = Http.RequestAsync({
        Url = string.format("%s/register", self._databaseUrl),
        Method = "POST",
        Headers = self:_headers(),
    })

    game:BindToClose(function()
        task.spawn(function()
            log("[%s] shutting down", self._storeName)
            local success, response = pcall(Http.RequestAsync, {
                Url = string.format("%s/logout", self._databaseUrl),
                Method = "POST",
                Headers = self:_headers(),
            })
            print(response)
            local alternative = success and not response.Success
            if not success or not response.Success then
                log("[%s] failed to logout the API", self._storeName)
                if alternative then
                    log("[%s] error: (%d) %s", self._storeName, response.StatusCode, response.StatusMessage)
                else
                    log("[%s] error: %s", self._storeName, tostring(response))
                end
            else
                log("[%s] successfully logged out", self._storeName)
            end
        end)

        -- waiting for a second to log out the session
        -- otherwise, let the server do the cleanup every 10 minutes
        task.wait(1)
    end)
end

function Stow.GetStore(index, url, token, template)
    local name
    local scope
    if type(index) == "string" then
        name = index
    elseif type(index) == "table" then
        local initialName = index.name
        if type(initialName) == "string" then
            name = initialName
        else
            error("[Stow::GetStore] expected 'name' in #1 argument")
        end
        local initialScope = index.scope
        if type(initialScope) == "string" then
            scope = initialScope
        elseif initialScope ~= nil then
            warn("[Stow::GetStore] invalid 'scope' specified, defaulting to nil")
        end
    else
        error("[Stow::GetStore] invalid #1 argument (expected string or table)")
    end

    local urlType = type(url)
    if urlType ~= "string" and urlType ~= "nil" then
        error("[Stow::GetStore] unexpected 'nil' in #2 argument (database url link)")
    end

    local tokenType = type(token)
    if tokenType == "string" and url == nil then
        error("[Stow::GetStore] expected 'nil' in #3 argument (token) while #2 argument (link) is nil!")
    elseif tokenType ~= "string" and url ~= nil then
        error("[Stow::GetStore] expected 'token' in #3 argument (string)")
    end

    if not token:match("^Bearer ") then
        token = "Bearer " .. token
    end
    print(token)

    if template == nil then
        error("[Stow::GetStore] unexpected 'nil' in #4 argument (data template)")
    end

    local databaseEnabled = url ~= nil
    local store = {
        _storeName = name,
        _storeScope = scope,

        _databaseEnabled = databaseEnabled,
        _databaseUrl = url,
        _databaseToken = token,

        _template = template,
    }
    setmetatable(store, StowStore)

    if databaseEnabled then
        task.spawn(store._registerClientSession, store)
    end

    return store
end

return Stow
