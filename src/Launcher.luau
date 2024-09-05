local Http = require("./Http")

local function buildUrl(placeID)
	return `https%3A%2F%2Fwww.roblox.com%2FGame%2FPlaceLauncher.ashx%3Frequest%3DRequestGame%26placeId%3D{placeID}%26isPlayTogetherGame%3Dfalse`
end

return function(placeId: number): string
	local nok, clientNonce = Http.AuthenticatedRequest {
		url = "https://auth.roblox.com/v1/client-assertion/",
		method = "GET"
	}

	if nok then
		local ok, authTokenRequest = Http.AuthenticatedRequest {
			url = "https://auth.roblox.com/v1/authentication-ticket/",
			method = "POST",
			body = clientNonce,
		
			headers = {
				Referer = "https://www.roblox.com"
			}
		}

		if ok then
			local token = authTokenRequest.httpMessage.headers["rbx-authentication-ticket"]
			local protocol = `roblox-player:1+launchmode:play+gameinfo:{token}+placelauncherurl:{buildUrl(placeId)}+robloxLocale:en_us+gameLocale:en_us`
		
			return protocol
		end
	end

	error("Experienced an error creating a launcher request.")
end