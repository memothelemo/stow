--[[

    TYPES:

    RequestAsyncInfo = {
        Url: string,
        Method: "GET" | "POST" | "PUT" | "DELETE" | "PATCH",
        Headers: { [string]: string, },
        Body: any,
    }

    Response = {
        Success: bool,
        StatusCode: integer,
        StatusMessage: string,
        Headers: { [string]: any },
        Body: any,
    }

    METHODS:

    Http.RequestAsync(info: RequestAsyncInfo): Response
        -> Might throw an error

    Http.EncodeJSON(input: any): string
    Http.DecodeJSON(input: string): any
]]

local Http = {}
local Service = game:GetService("HttpService")

local Deque = require(script.Parent.Deque)
local t = require(script.Parent.t)

local running = coroutine.running
local yield = coroutine.yield

local RESET_INTERVAL_IN_SECONDS = 60
local MAX_REQUESTS_PER_MINUTE = 500
local SECONDS_PER_REQUEST = RESET_INTERVAL_IN_SECONDS / MAX_REQUESTS_PER_MINUTE

type RequestThread = {
	thread: thread,
	req_info: any,
}

---@diagnostic disable-next-line: undefined-type
local requestedThreads: Deque.Deque<RequestThread> = Deque.new()
local requestAsyncCheck = t.strictInterface {
	Url = t.string,
	-- https://developer.mozilla.org/en-US/docs/Web/HTTP/Methods
	Method = t.union(
		t.literal("GET"),
		t.literal("POST"),
		t.literal("PUT"),
		t.literal("DELETE"),
		t.literal("PATCH")
	),
	Headers = t.map(t.string, t.string),
	Body = t.union(t["nil"], t.any),
}

type RequestAsyncInfo = {
	Url: string,
	Method: "GET" | "POST" | "PUT" | "DELETE" | "PATCH",
	Headers: { [string]: string },
	Body: any,
}

function Http.RequestAsync(info: RequestAsyncInfo)
	assert(requestAsyncCheck(info))
	requestedThreads:pushRight({
		thread = running(),
		req_info = info,
	})
	local success, data = yield()
	if not success then
		error(string.format("HTTP REQUEST ERROR: %s", tostring(data)))
	end
	return data
end

Http.EncodeJSON = function(input)
	return Service:JSONEncode(input)
end

Http.DecodeJSON = function(input)
	return Service:JSONDecode(input)
end

task.spawn(function()
	local lastReset = os.clock() - workspace.DistributedGameTime
	local lastRequest = lastReset
	local allowance = MAX_REQUESTS_PER_MINUTE
	local overflowRequests = 0
	while true do
		-- reset if necessary
		local now = os.clock()
		local elapsed = now - lastReset
		if elapsed >= RESET_INTERVAL_IN_SECONDS then
			lastReset = now
			lastRequest = now
			overflowRequests = 0
			allowance = MAX_REQUESTS_PER_MINUTE
		end

		local requestElapsed = now - lastRequest
		if requestElapsed >= SECONDS_PER_REQUEST and allowance > 0 then
			lastRequest = os.clock()
			overflowRequests += 1
			allowance -= 1
		end

		if overflowRequests > 0 then
			while true do
				if overflowRequests == 0 then
					break
				end
				local request = requestedThreads:popLeft()
				if request == nil then
					break
				end
				overflowRequests -= 1
				task.spawn(function()
					local success, data = pcall(Service.RequestAsync, Service, request.req_info)
					coroutine.resume(request.thread, success, data)
				end)
			end
		end

		task.wait()
	end
end)

return Http
