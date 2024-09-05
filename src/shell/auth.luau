local Http = require("../Http")
local ShellTool = require("../ShellTool")

local Command = ShellTool.new()

Command.Summary = "auth [COOKIE|logout]"
Command.Description = "attempts to authenticate the shell"
Command.ExpandedHelp = {
	logout = "deauthenticates the shell and deletes the COOKIE file"
}

function Command.Run(args)
	local useCookie = args[1]
	if useCookie and string.lower(useCookie) == "logout" then
		if not Http.CookieValidated() then return false, "Already logged out" end

		Http.FlushCookie()
		print("Cookie deleted. Logged out.")
		return true
	end

	if Http.CookieValidated() then
		local whoami = Http.whoami("name")
		return false, `Already logged in as {whoami}. Use \`auth logout\` first`
	end

	local ok, userid, dispName = Http.RenewCookieV2()

	if ok then
		print(`Authenticated as user id {userid} ({dispName})`)
		return true
	end

	return false, "Failed cookie verification. Please try again."
end

return Command