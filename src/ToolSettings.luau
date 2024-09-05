-- Migration from SharedIO
-- Implementing this better

--[[
	Windows path:
	%APPDATA%/.avatarstore/SETTINGS

	MacOS path:
	~/Library/Application Support/.avatarstore/SETTINGS

	Linux path:
	~/.local/share/.avatarstore/SETTINGS
]]--

local process = require("@lune/process")
local serde = require("@lune/serde")
local fs = require("@lune/fs")
local os = process.os

local AppData = if os == "windows" then process.env.APPDATA
else if os == "macos" then "~/Library/Application Support"
else if os == "linux" then "~/.local/share"
else error("Cant use settings on this OS")

if not fs.isDir(`{AppData}/metatablecatGames`) then
	fs.writeDir(`{AppData}/metatablecatGames`)
end

if not fs.isDir(`{AppData}/metatablecatGames/GameLauncher`) then
	fs.writeDir(`{AppData}/metatablecatGames/GameLauncher`)
end


type SettingsFileBin = {
	path: string,
	version: number,
	flags: {
		compress: boolean -- bit 0
	},
	keys: {
		[string]: string
	}
}

local function serializeLEB128(n: number): string
	local result = {}
		
	repeat
		local byte = bit32.band(n, 0x7F)
		n = bit32.rshift(n, 7)
		
		if n ~= 0 then
				byte = bit32.bor(byte, 0x80)
		end
		
		table.insert(result, string.char(byte))
	until n == 0
	
	return table.concat(result, "")
end

local function serializeString(str: string): string
	local len = #str
	return `{serializeLEB128(len)}{str}`
end

local function deserializeLEB128(b, offset)
	local result = 0
	local shift = 0
	local byte

	repeat
		byte = buffer.readu8(b, offset)  -- Read a byte from the buffer at the given offset
		result = result + bit32.band(byte, 0x7F) * 2^shift
		shift = shift + 7
		offset = offset + 1
	until bit32.band(byte, 0x80) == 0

	return result, offset
end

local function deserializeString(b, offset)
	local length, newOffset = deserializeLEB128(b, offset)
	local str = buffer.readstring(b, newOffset, length)
	newOffset = newOffset + length
	return str, newOffset
end

local function save(settingsFile: SettingsFileBin)
	local binStream = `SBIN{string.char(settingsFile.version)}`

	-- pack flag, right now compress represents 0 but if we add more, rewrite this impl
	binStream ..= if settingsFile.flags.compress then "\1" else "\0"
	
	-- pack keys
	-- we need to know the number of keys before encoding, so we need to scan over the list twice
	local sizekeys = 0
	for _ in settingsFile.keys do sizekeys += 1 end

	binStream ..= serializeLEB128(sizekeys)

	for key, value in settingsFile.keys do
		binStream ..= serializeString(key)

		if settingsFile.flags.compress then
			-- write uncompressed data size before serializing
			binStream ..= serializeString(serde.compress("zlib", value))
		else
			binStream ..= serializeString(value)
		end
	end

	fs.writeFile(settingsFile.path, binStream)
end

local function open(path): SettingsFileBin
	local file
	
	if fs.isFile(path) then
		local stream = buffer.fromstring(fs.readFile(path))
		local HEADER = buffer.readu32(stream, 0)

		if HEADER ~= 1313423955 then
			error("Invalid SBIN data")
		end

		local version = buffer.readu8(stream, 4)
		local compress = buffer.readu8(stream, 5)

		if version ~= 0 then
			error("Invalid SBIN version")
		end

		local doCompress = compress == 1

		file = {
			path = path,
			version = version,
			flags = {compress = doCompress},
			keys = {}
		}

		local sizekeys, offset = deserializeLEB128(stream, 6)
		local str
		-- begin scanning keys
		if sizekeys > 0 then
			for i = 1, sizekeys do
				str, offset = deserializeString(stream, offset)
				local key = str

				str, offset = deserializeString(stream, offset)
				file.keys[key] = if doCompress then serde.decompress("zlib", str) else str
			end
		end
	else
		file = {
			path = path,
			version = 0,
			flags = {compress = true},
			keys = {
			}
		}

		save(file)
	end

	return file
end

local Settings = {}
Settings.PATH = `{AppData}/metatablecatGames/GameLauncher`
local stream = open(`{Settings.PATH}/SETTINGS`)

type tostringable = number | string | boolean
	| typeof(setmetatable({}::{[any]: any}, {} :: {
		__tostring: ({[any]: any}) -> string
	}))

function Settings.SetKey(key: string, value: tostringable?)
	stream.keys[key] = tostring(value)
	save(stream)
end

function Settings.GetKey(key: string)
	return stream.keys[key]
end

return Settings