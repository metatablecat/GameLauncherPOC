local net = require("@lune/net")
local serde = require("@lune/serde")
local task = require("@lune/task")

local CREATE_TOKEN = "https://apis.roblox.com/auth-token-service/v1/login/create"
local PING_TOKEN = "https://apis.roblox.com/auth-token-service/v1/login/status"
local CANCEL_TOKEN = "https://apis.roblox.com/auth-token-service/v1/login/cancel"
local AUTH_PATTERN = "^%.ROBLOSECURITY=(.-)$"

local function jHttpRequest(req)
	if not req.headers then
		req.headers = {}
	end

	req.headers.Accept = "application/json"
	req.headers["Content-Type"] = "application/json"

	req.body = serde.encode("json", req.body)
	local res = net.request(req)

	if not res.ok then
		-- if its xcsrf, we need to handle again
		if res.headers then
			req.headers["x-csrf-token"] = res.headers["x-csrf-token"]
			res = net.request(req)
		end
	end

	if not res.ok then
		return false, {
			httpMessage = res,
			body = res.body,
			sentMessage = req.body
		}
	end

	return true, {
		httpMessage = res,
		body = serde.decode("json", res.body),
		sentMessage = req.body
	}
end

type QuickLoginProtocol = {
	State: {
		ActiveTokenID: string?,
		RootThread: thread,
		Thread: thread,
		PrivateKey: string?
	}?,

	Cancel: (QuickLoginProtocol) -> (),
	Await: (QuickLoginProtocol) -> (boolean, string?)
}

local function createdStatus(qlp: QuickLoginProtocol): (boolean, any, string?)
	local state = qlp.State

	local isok, res = jHttpRequest {
		url = PING_TOKEN,
		method = "POST",
		body = {
			code = state.ActiveTokenID,
			privateKey = state.PrivateKey
		}
	}

	if isok then
		-- expected result (do nothing because the code is still valid)
		return true, res, res.body.status
	else
		-- is code 400 and body "CodeInvalid"?
		if res.body == '"CodeInvalid"' and res.statusCode == 400 then
			return true, res, "NotCreated"
		else
			return false, res
		end
	end
end

local function makeNewToken(qlp: QuickLoginProtocol): (boolean, any, string?)
	local state = qlp.State

	local ok, res = jHttpRequest {
		url = CREATE_TOKEN,
		method = "POST",
	}

	if ok then
		local body = res.body
		state.PrivateKey = body.privateKey
		state.ActiveTokenID = body.code
		print(`Use quick login on Roblox and enter code {body.code} to log in.`)

		return true, res, body.status
	end

	return false, res
end

local function loginHandler(qlp: QuickLoginProtocol)
	local state = qlp.State
	local ok, res, statusBranch = makeNewToken(qlp)
	local SECTOKEN, lastStatusBranch
	
	repeat
		-- last path handler
		task.wait(5)
		ok, res, statusBranch = createdStatus(qlp)

		if res.body == '"CodeInvalid"' or statusBranch == "NotCreated" or statusBranch == "Cancelled" then
			-- likely expired token from a 400
			-- generate new token and continue
			print("Previous code has expired. Generating new code...")
			ok, res, statusBranch = makeNewToken(qlp)
		
		elseif statusBranch == "UserLinked" then
			if lastStatusBranch ~= "UserLinked" then
				print(`Receiving login attempt from {res.body.accountName}. If this is not you. Cancel the request with Ctrl-C NOW. This will abort the login.`)
			end

		elseif statusBranch == "Validated" then
			print("Performing login attempt...")
		end

		lastStatusBranch = statusBranch
	until not ok or statusBranch == "Validated"

	if not ok then
		return false, res
	end

	ok, res = jHttpRequest {
		url = "https://auth.roblox.com/v2/login",
		method = "POST",
		body = {
			ctype = "AuthToken",
			cvalue = state.ActiveTokenID,
			password = state.PrivateKey
		}
	}
	if not ok then return false, res end
	-- extract auth cookie, request is a table so we need to scan it until the roblo matches

	for _, cookie in res.httpMessage.headers["set-cookie"] do
		local token = string.match(cookie, AUTH_PATTERN)
		if token then
			SECTOKEN = token
			break
		end
	end

	if not SECTOKEN then
		return false, "Unknown internal error, please report"
	end
	
	return true, SECTOKEN
end

local function loginResponseHandler(qlp: QuickLoginProtocol)
	local state = qlp.State
	local ok, msg = loginHandler(qlp)

	if not ok then
		warn("HTTP Error")
		print(msg)
	end

	task.defer(state.RootThread, ok, if ok then msg else nil)
end

return function(): QuickLoginProtocol
	local QLP = {}
	
	function QLP:Await()
		if self.State then
			error("This QLP is already running.")
		end

		local co = coroutine.running()
		local thread = task.defer(loginResponseHandler, self)

		self.State = {
			Thread = thread,
			RootThread = co
		}

		local ok, res = coroutine.yield(thread)

		if not ok then
			-- cancel the token because HTTP Error
			jHttpRequest {
				url = CANCEL_TOKEN,
				body = {
					code = self.State.ActiveTokenID
				},
				method = "POST"
			}
		end

		self.State = nil
		return ok, res
	end

	function QLP:Cancel()
		local state = self.State
		if state then
			task.cancel(state.Thread)
			task.defer(state.RootThread, false)
		end
	end

	return QLP
end