local stdio = require("@lune/stdio")

type ShellToolCommand = {
	Summary: string,
	Description: string,
	ExpandedHelp: {[string]: string},
	ArgValidate: ({string}) -> (boolean, {string}?)?,
	Run: ({string}) -> (boolean, string?),
	HelpInfo: string?
}

local function getFormatSpecifierForKeys(data: {[string]: any}): string
	local maxsize = 0
	for k in data do
		local len = string.len(k)
		if len > maxsize then maxsize = len end
	end

	return `%-{maxsize}s`
end

local function stringifyAndSort<T>(data: {[string]: T}): {{key: string, data: T}}
	local stringified = {}
	for key, msg in data do
		table.insert(stringified, {key = key, data = msg})
	end

	table.sort(stringified, function(a, b)
		return a.key < b.key
	end)

	return stringified
end

local function generateHelpInfoForCommand(command: ShellToolCommand)
	local buffer = {command.Description, `USAGE: {command.Summary}`}

	-- attach arg info
	local helpBuffer = {}
	local specifier = getFormatSpecifierForKeys(command.ExpandedHelp)

	if next(command.ExpandedHelp) then
		table.insert(buffer, "\nArguments:")

		for _, arg in stringifyAndSort(command.ExpandedHelp) do
			local argName, argDesc = arg.key, arg.data
			table.insert(helpBuffer, `{string.format(specifier, argName)}   {argDesc}`)
		end

		table.insert(buffer, `   {table.concat(helpBuffer, "\n   ")}`)
	end
	command.HelpInfo = table.concat(buffer, "\n")
end

local function generateHelpInfo(commands: {[string]: ShellToolCommand})
	-- left pads each name, puts a single tab mark, and shows help info
	local buffer = {}
	local formatSpecifier = getFormatSpecifierForKeys(commands)
	
	for _, commandKey in stringifyAndSort(commands) do
		local k, command = commandKey.key, commandKey.data
		generateHelpInfoForCommand(command)
		table.insert(buffer, `{string.format(formatSpecifier, k)}   {command.Description}`)
	end

	return table.concat(buffer, "\n   ")
end

local run = true
local HELP_INFO
local COMMAND_STACK: {[string]: ShellToolCommand} = {}

local HELP_COMMAND: ShellToolCommand = {
	Summary = "help [command]",
	Description = "shows command list and summary",
	ExpandedHelp = {
		COMMAND = "command to retrieve additional help from"
	},
	Run = function(args)
		local command = args[1]
		if command then
			local commandInfo = COMMAND_STACK[string.lower(args[1])]
			if not commandInfo then
				return false, `No command named {args[1]}`
			end

			print(commandInfo.HelpInfo)
			return true
		else
			print(`Available Commands:\n   {HELP_INFO}`)
			return true
		end
	end
}

local EXIT_COMMAND: ShellToolCommand = {
	Summary = "exit",
	Description = "exits the process",
	ExpandedHelp = {},
	Run = function(args)
		run = false
	end
}

local SHELL = {}

function SHELL.run(commands: {[string]: ShellToolCommand})
	commands.help = HELP_COMMAND
	commands.h = HELP_COMMAND
	commands.exit = EXIT_COMMAND

	HELP_INFO = generateHelpInfo(commands)
	COMMAND_STACK = commands

	while run do
		local command = string.match(stdio.prompt("text", ">"), "^%s*(.-)%s*$")
		if command == "" then continue end

		local args = string.split(command, " ")
		local exec = string.lower(table.remove(args, 1)::string)

		local commandRun = commands[exec]
		if commandRun then
			local tryFindHelp = string.lower(args[1] or "")
			if tryFindHelp == "-h" or tryFindHelp == "--help" then
				print(commandRun.HelpInfo)
				continue
			end

			if commandRun.ArgValidate then
				local argsOk, missingArgs = commandRun.ArgValidate(args)

				if not argsOk then
					local missingArgString = table.concat(missingArgs, ">\n   <")
					warn(`ERROR: Some arguments were not provided.\n   <{missingArgString}>\n\nUSAGE: {commandRun.Summary}`)
					continue
				end
			end

			local cmdOk, err = commandRun.Run(args)
			if not cmdOk and err then
				warn(err)
			end
		else
			warn(`Invalid command {exec}`)
		end
	end
end

local function NONE()
	return false, "Command buffer is using NONE. This is a bug, please report."
end

function SHELL.new(): ShellToolCommand
	return {
		Summary = "",
		Description = "",
		ExpandedHelp = {},
		Run = NONE
	}
end

return SHELL