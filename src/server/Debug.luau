-- Snackrot Bay: reviewer helpers. TOUR.json calls these so make.fun's
-- reviewers can bring the game to a screenshot's screen themselves.
-- Each function takes one argument (an integer or a short string) and runs
-- on the Server. Nothing here is part of the normal game loop.

local Debug = {}

-- The game server registers itself here at boot.
Debug._server = nil

function Debug.register(server)
	Debug._server = server
end

-- Fill the caller's base with one brainrot of each rarity.
-- arg: a user id ("123456"), or a player name / display name.
function Debug.fillBase(arg: string): string
	if not Debug._server then
		return "server not ready"
	end
	local players = game:GetService("Players")
	local player = nil
	local userId = tonumber(arg)
	if userId then
		player = players:GetPlayerByUserId(userId)
	else
		for _, candidate in players:GetPlayers() do
			if candidate.Name == arg or candidate.DisplayName == arg then
				player = candidate
				break
			end
		end
	end
	if not player then
		return "no such player: " .. arg
	end
	Debug._server:debugFillBase(player)
	return "base filled"
end

-- Start the Snackwave immediately (arg is ignored).
function Debug.startWave(_arg: string): string
	if not Debug._server then
		return "server not ready"
	end
	Debug._server:debugStartWave()
	return "wave started"
end

-- Spawn a brainrot of the named rarity on the conveyor (arg: rarity id).
function Debug.spawnRarity(arg: string): string
	if not Debug._server then
		return "server not ready"
	end
	return Debug._server:debugSpawnRarity(arg)
end

return Debug
