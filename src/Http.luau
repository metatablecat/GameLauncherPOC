local net = require("@lune/net")
local serde = require("@lune/serde")
local settings = require("./ToolSettings")
local QuickLogin = require("./QuickLoginAuth")

local QLP = QuickLogin()

local COOKIE = settings.GetKey(".RBXCOOKIE")
local validated = false
local userid, username

local AUTH_FAILED = "Failed cookie verification, please renew using the auth command"

local Http = {}

--[[
function Http.RenewCookieDeprecated(renewQuick: string?): (boolean, number?)
	local ok
	repeat
		local attempt = if renewQuick then renewQuick else stdio.prompt("text", "Enter cookie or type exit to give up:")
		if string.lower(attempt) ~= "exit" then
			COOKIE = attempt
			ok = Http.TryLogIn()

			if attempt == renewQuick then attempt = "exit" end
		end
	until ok or string.lower(attempt) == "exit"

	if userid then
		settings.SetKey(".RBXCOOKIE", COOKIE)
		return true, userid, username
	end

	return false
end
]]--

function Http.RenewCookieV2()
	local ok, sectoken = QLP:Await()
	if ok then
		COOKIE = sectoken
		ok = Http.TryLogIn()
	end

	if userid then
		settings.SetKey(".RBXCOOKIE", COOKIE)
		return true, userid, username
	end

	return false
end

function Http.FlushCookie()
	if COOKIE then
		validated = false
		userid, username = nil, nil

		local ok = Http.AuthenticatedRequest {
			method = "POST",
			url = "https://auth.roblox.com/v2/logout"
		}

		COOKIE = nil
		
		if not ok then
			warn("Failed to logout, you'll need to remove this session in Roblox settings > Security.\nIt usually appears as 'Roblox Unknown App'")
		end

		settings.SetKey(".RBXCOOKIE")
	end
end

function Http.CookieValidated(): (boolean, string?)
	if not validated then
		return false, AUTH_FAILED
	end

	return true
end

function Http.TryLogIn(): (boolean, number?, string?)
	if not COOKIE then
		warn(AUTH_FAILED)

		validated = false
		return false
	end

	-- try to fetch the authenticated user, this is usually enough to figure out if the cookie is valid
	local ok, userData = Http.AuthenticatedRequest {
		url = "https://users.roblox.com/v1/users/authenticated",
		method = "GET"
	}

	if not ok then
		warn(AUTH_FAILED)

		validated = false
		return false
	end

	userData = userData.body

	validated = true
	userid, username = userData.id, userData.displayName
	return true, userData.id, userData.displayName
end

function Http.whoami(reqType: "userid"|"name"): number|string
	return reqType == "userid" and userid or username
end

function Http.AuthenticatedRequest(request)
	-- we need to attach "Cookie: .ROBLOSECURITY=COOKIE", nothing should be
	-- writing to Cookie so its safe to put it there ourselves

	if not COOKIE then return false, "Cookie is not present" end

	local headers = request.headers
	if not headers then
		headers = {}
		request.headers = headers
	end

	headers.Accept = "application/json"
	headers["Content-Type"] = "application/json"
	headers.Cookie = `.ROBLOSECURITY={COOKIE}`
	
	local res = net.request(request)

	if not res.ok then
		-- is it a CSRF challenge?
		local xcsrf = res.headers["x-csrf-token"]
		if xcsrf then
			-- we send request again!
			request.headers["x-csrf-token"] = xcsrf
			res = net.request(request)
		end
	end

	-- main response handle
	if not res.ok then
		return false, {
			httpMessage = res,
			body = res.body
		}
	end

	return true, {
		httpMessage = res,
		body = serde.decode("json", res.body)
	}
end

return Http