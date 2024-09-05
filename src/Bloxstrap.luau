-- Resolves bloxstrap
-- Currently a required dependency until Lune fixes protocol launches

local process = require("@lune/process")
local stdio = require("@lune/stdio")
local fs = require("@lune/fs")
local task = require("@lune/task")

local BLOXSTRAP_PATH = `{process.env.LOCALAPPDATA}\\Bloxstrap\\Bloxstrap.exe`

while not fs.isFile(BLOXSTRAP_PATH) do
	print("Bloxstrap is not installed. Please install Bloxstrap to use GameLauncher")
	print("https://github.com/pizzaboxer/bloxstrap/releases/latest")

	stdio.prompt("text", "Press ENTER when Bloxstrap is installed")
end

return function(protocol)
	print("You can safely close this shell once Bloxstrap starts")
	process.spawn(BLOXSTRAP_PATH, {protocol})
	task.wait(1)
	process.exit(0)
end