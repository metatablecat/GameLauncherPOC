local Http = require("./Http") -- initialisation buffers
local ShellTool = require("./ShellTool")
local process = require("@lune/process")
local Launcher = require("./Launcher")
local Bloxstrap = require("./Bloxstrap")
local ToolVersion = "0.1.0"

print(`GameLauncher - metatablecat (v{ToolVersion})`)
local ok, _, displayName = Http.TryLogIn()

if ok then
	print(`Login Completed! Hello {displayName}!`)
end

if process.args[1] == "--placeId" and process.args[2] then
	local placeid = tonumber(process.args[2])
	if placeid then
		Bloxstrap(Launcher(placeid))
	end
else
	ShellTool.run {
		auth = require("./shell/auth"),
	}
end