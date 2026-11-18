-- Snackrot Bay: the game server. Owns the whole loop: plots, the tide
-- conveyor, buying, stealing, base locks, rebirths, upgrades and the
-- Snackwave. All player state lives in State; all world geometry comes
-- from WorldBuilder; all characters come from BrainrotFactory.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local BrainrotData = require(Shared:WaitForChild("BrainrotData"))
local Util = require(Shared:WaitForChild("Util"))
local State = require(script.Parent:WaitForChild("State"))
local WorldBuilder = require(script.Parent:WaitForChild("WorldBuilder"))
local BrainrotFactory = require(script.Parent:WaitForChild("BrainrotFactory"))
local Debug = require(script.Parent:WaitForChild("Debug"))

local Server = {}

local CONVEYOR_SPAWN_SECONDS = 5
local INCOME_SECONDS = 1
local WAVE_EVERY_SECONDS = 240
local WAVE_WARN_SECONDS = 15
local WAVE_SWEEP_SECONDS = 14

local rng = Random.new()
local world = WorldBuilder.build()
local plots = world.plots
local conveyorPoints = world.conveyorPoints

local brainrotFolder = Instance.new("Folder")
brainrotFolder.Name = "Brainrots"
brainrotFolder.Parent = Workspace

local remotes = Instance.new("Folder")
remotes.Name = "Remotes"
remotes.Parent = ReplicatedStorage

local gameAction = Instance.new("RemoteEvent")
gameAction.Name = "GameAction"
gameAction.Parent = remotes

local gameNotify = Instance.new("RemoteEvent")
gameNotify.Name = "GameNotify"
gameNotify.Parent = remotes

-- {[plotIndex] = Player} and {[conveyorPointIndex] = record}
local plotOwners = {}
local conveyorSlots = {}
-- {[model] = record} for every live brainrot, conveyor or slotted.
local liveRecords = {}
-- Conveyor models bobbing: {[model] = base CFrame}
local bobbing = {}
-- Rainbow models cycling hue: {model}
local rainbows = {}

local brainrotCounter = 0
local waveInProgress = false
local nextWaveAt = os.clock() + WAVE_EVERY_SECONDS

local function notify(player: Player, kind: string, message: string)
	gameNotify:FireClient(player, kind, message)
end

local function notifyAll(kind: string, message: string)
	gameNotify:FireAllClients(kind, message)
end

local function nextBrainrotId(): string
	brainrotCounter += 1
	return "snackrot-" .. tostring(brainrotCounter)
end

-- Tween an anchored model to a target CFrame without blocking the caller.
local function flyModelTo(model: Model, target: CFrame, duration: number)
	task.spawn(function()
		local value = Instance.new("CFrameValue")
		value.Value = model:GetPivot()
		local conn = value.Changed:Connect(function()
			model:PivotTo(value.Value)
		end)
		local tween = TweenService:Create(value, TweenInfo.new(duration, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), { Value = target })
		tween:Play()
		tween.Completed:Wait()
		conn:Disconnect()
		value:Destroy()
		model:PivotTo(target)
	end)
end

-- Slot a brainrot record into a player's base: fly the model to the slot,
-- record it in State, and flip its prompt from Buy to Steal.
local function slotBrainrot(data: State.PlayerData, record, slot: number)
	local plot = plots[data.plotIndex]
	local slotPos = plot.slots[slot]
	local model = record.model
	record.slot = slot
	data.slots[slot] = record
	liveRecords[model] = record
	bobbing[model] = nil
	local target = CFrame.lookAt(slotPos, plot.center)
	local prompt = (model.PrimaryPart :: Part):FindFirstChild("BrainrotPrompt") :: ProximityPrompt
	if prompt then
		prompt.Enabled = false
		prompt.ActionText = "Steal"
		prompt.ObjectText = data.player.DisplayName .. "'s " .. BrainrotData.displayName(record)
		prompt.HoldDuration = 3
	end
	flyModelTo(model, target, 1.2)
	task.delay(1.3, function()
		if prompt and prompt.Parent then
			prompt.Enabled = true
			local label = (model.PrimaryPart :: Part):FindFirstChild("BrainrotLabel") :: BillboardGui
			if label then
				local price = label:FindFirstChild("Price") :: TextLabel
				if price then
					price.Text = "Owned by " .. data.player.DisplayName
				end
			end
		end
	end)
end

-- The buy/steal prompt on any brainrot. One handler covers both: the
-- record's home (conveyor point vs. a player's slot) decides the branch.
local function onBrainrotPrompt(player: Player, prompt: ProximityPrompt)
	local model = prompt.Parent and prompt.Parent.Parent :: Model
	if not model or not liveRecords[model] then
		return
	end
	local record = liveRecords[model]
	local data = State.get(player)
	if not data then
		return
	end

	if record.slot == 0 then
		-- On the conveyor: buy it.
		if not State.canAfford(data, record.price) then
			notify(player, "toast", "Not enough cash for " .. BrainrotData.displayName(record) .. " (" .. Util.formatMoney(record.price) .. ").")
			return
		end
		local slot = State.freeSlot(data)
		if not slot then
			notify(player, "toast", "Your base is full! Rebirth or wait for a slot.")
			return
		end
		if not State.spend(data, record.price) then
			return
		end
		conveyorSlots[record.conveyorPoint] = nil
		record.conveyorPoint = nil
		slotBrainrot(data, record, slot)
		notify(player, "toast", "Bought " .. BrainrotData.displayName(record) .. " for " .. Util.formatMoney(record.price) .. "! " .. record.quirk)
	elseif record.ownerId ~= player.UserId then
		-- On someone else's base: steal it, unless their base is locked.
		local owner = Players:GetPlayerByUserId(record.ownerId)
		local ownerData = owner and State.get(owner)
		if ownerData and State.isLocked(ownerData) then
			notify(player, "toast", owner.DisplayName .. "'s base is LOCKED. Wait it out!")
			return
		end
		local slot = State.freeSlot(data)
		if not slot then
			notify(player, "toast", "Your base is full! No room for stolen goods.")
			return
		end
		if ownerData then
			ownerData.slots[record.slot] = nil
		end
		record.ownerId = player.UserId
		slotBrainrot(data, record, slot)
		notify(player, "toast", "STOLE " .. BrainrotData.displayName(record) .. " from " .. (owner and owner.DisplayName or "someone") .. "!")
		if owner then
			notify(owner, "toast", player.DisplayName .. " stole your " .. BrainrotData.displayName(record) .. "! Lock your base!")
		end
	else
		notify(player, "toast", "That one is already yours.")
	end
end

-- Spawn one rolled brainrot on a free conveyor point.
local function spawnConveyorBrainrot(forcedRarity: string?): string?
	for i, point in conveyorPoints do
		if conveyorSlots[i] == nil then
			local rolled
			if forcedRarity then
				local pool = BrainrotData.speciesOfRarity(forcedRarity)
				if #pool == 0 then
					return nil
				end
				local species = pool[rng:NextInteger(1, #pool)]
				local mutation = Util.weightedPick(rng, BrainrotData.MUTATIONS)
				rolled = {
					speciesId = species.id,
					name = species.name,
					rarity = forcedRarity,
					mutation = mutation.id,
					rate = species.rate * mutation.mult,
					price = species.rate * mutation.mult * BrainrotData.PRICE_MULT,
					quirk = species.quirk,
				}
			else
				rolled = BrainrotData.rollBrainrot(rng)
			end
			rolled.id = nextBrainrotId()
			rolled.slot = 0
			rolled.conveyorPoint = i
			rolled.ownerId = 0
			local model = BrainrotFactory.build(rolled, point, point + Vector3.new(0, 0, 10))
			model.Parent = brainrotFolder
			rolled.model = model
			conveyorSlots[i] = rolled
			liveRecords[model] = rolled
			bobbing[model] = model:GetPivot()
			if rolled.mutation == "Rainbow" then
				table.insert(rainbows, model)
			end
			local prompt = (model.PrimaryPart :: Part):FindFirstChild("BrainrotPrompt") :: ProximityPrompt
			prompt.Triggered:Connect(function(triggeringPlayer: Player)
				onBrainrotPrompt(triggeringPlayer, prompt)
			end)
			return BrainrotData.displayName(rolled)
		end
	end
	return nil
end

-- The Snackwave: a wall of water sweeps the map. Anyone caught outside
-- their own base gets flung home; the conveyor's stock washes away.
local function startWave()
	if waveInProgress then
		return
	end
	waveInProgress = true
	notifyAll("banner", "SNACKWAVE INCOMING! Get to your base!")
	task.wait(WAVE_WARN_SECONDS)
	notifyAll("banner", "THE SNACKWAVE IS HERE!")

	-- Wash the conveyor clean.
	local washed = {}
	for _, record in conveyorSlots do
		table.insert(washed, record)
	end
	table.clear(conveyorSlots)
	for _, record in washed do
		if record.model then
			liveRecords[record.model] = nil
			bobbing[record.model] = nil
			record.model:Destroy()
		end
	end

	local wall = Instance.new("Part")
	wall.Name = "SnackwaveWall"
	wall.Anchored = true
	wall.CanCollide = false
	wall.Size = Vector3.new(360, 50, 6)
	wall.CFrame = CFrame.new(0, 22, -180)
	wall.Color = Color3.fromRGB(40, 160, 230)
	wall.Material = Enum.Material.Neon
	wall.Transparency = 0.3
	wall.Parent = Workspace
	local sweep = TweenService:Create(wall, TweenInfo.new(WAVE_SWEEP_SECONDS, Enum.EasingStyle.Linear), { CFrame = CFrame.new(0, 22, 180) })
	sweep:Play()

	local startTime = os.clock()
	while os.clock() - startTime < WAVE_SWEEP_SECONDS do
		task.wait(0.5)
		local wallZ = wall.Position.Z
		for _, data in State.all() do
			local character = data.player.Character
			local root = character and character:FindFirstChild("HumanoidRootPart") :: BasePart
			if root then
				local plot = plots[data.plotIndex]
				local home = plot and (Vector2.new(root.Position.X - plot.center.X, root.Position.Z - plot.center.Z)).Magnitude < plot.homeRadius
				if not home and math.abs(root.Position.Z - wallZ) < 12 then
					local away = (plot.center - root.Position)
					local dir = Vector3.new(away.X, 0, away.Z)
					if dir.Magnitude > 0.1 then
						dir = dir.Unit
					else
						dir = Vector3.new(0, 0, 1)
					end
					root.AssemblyLinearVelocity = dir * 70 + Vector3.new(0, 35, 0)
					notify(data.player, "toast", "Swept away by the Snackwave! Dash home!")
				end
			end
		end
	end
	wall:Destroy()
	notifyAll("banner", "The Snackwave passed. The tide brings fresh snackrots!")
	waveInProgress = false
	nextWaveAt = os.clock() + WAVE_EVERY_SECONDS
end

-- Client actions: lock, rebirth, upgrades. One remote, one switch.
gameAction.OnServerEvent:Connect(function(player: Player, action: string, arg: string)
	local data = State.get(player)
	if not data then
		return
	end
	if action == "lock" then
		local ok, message = State.tryLock(data)
		notify(player, "toast", message)
		if ok then
			notify(player, "lockState", tostring(State.lockRemaining(data)))
		end
	elseif action == "rebirth" then
		local ok, message = State.tryRebirth(data)
		notify(player, "toast", message)
		if ok then
			notify(player, "rebirthState", tostring(data.rebirths))
			local leaderstats = player:FindFirstChild("leaderstats") :: Folder
			if leaderstats then
				(leaderstats:FindFirstChild("Rebirths") :: IntValue).Value = data.rebirths
			end
			local character = player.Character
			local humanoid = character and character:FindFirstChildOfClass("Humanoid")
			if humanoid then
				humanoid.WalkSpeed = State.walkSpeed(data)
			end
		end
	elseif action == "upgrade" then
		local ok, message = State.tryUpgrade(data, arg)
		notify(player, "toast", message)
		if ok then
			notify(player, "upgradeState", tostring(data.speedLevel) .. "," .. tostring(data.incomeLevel))
		end
		if ok and arg == "speed" then
			local character = player.Character
			local humanoid = character and character:FindFirstChildOfClass("Humanoid")
			if humanoid then
				humanoid.WalkSpeed = State.walkSpeed(data)
			end
		end
	end
end)

local function assignPlot(player: Player): number?
	for i, _ in plots do
		if plotOwners[i] == nil then
			plotOwners[i] = player
			return i
		end
	end
	return nil
end

local function onPlayerAdded(player: Player)
	local data = State.newPlayer(player)
	local leaderstats = Instance.new("Folder")
	leaderstats.Name = "leaderstats"
	leaderstats.Parent = player
	local cashValue = Instance.new("IntValue")
	cashValue.Name = "Cash"
	cashValue.Value = BrainrotData.START_CASH
	cashValue.Parent = leaderstats
	local incomeValue = Instance.new("IntValue")
	incomeValue.Name = "Income"
	incomeValue.Value = 0
	incomeValue.Parent = leaderstats
	local rebirthValue = Instance.new("IntValue")
	rebirthValue.Name = "Rebirths"
	rebirthValue.Value = 0
	rebirthValue.Parent = leaderstats

	local plotIndex = assignPlot(player)
	data.plotIndex = plotIndex
	if plotIndex then
		plots[plotIndex].signLabel.Text = player.DisplayName .. "'s BASE"
	end

	notify(player, "toast", "Welcome to Snackrot Bay! Buy snackrots off the conveyor, fill your base, and watch the cash roll in. Beware the Snackwave!")
end

local function onCharacterAdded(player: Player, character: Model)
	local data = State.get(player)
	if not data or not data.plotIndex then
		return
	end
	local root = character:WaitForChild("HumanoidRootPart", 10) :: BasePart
	local humanoid = character:WaitForChild("Humanoid", 10) :: Humanoid
	if root then
		root.CFrame = CFrame.new(plots[data.plotIndex].spawnPoint)
	end
	if humanoid then
		humanoid.WalkSpeed = State.walkSpeed(data)
	end
end

local function onPlayerRemoving(player: Player)
	local data = State.get(player)
	if data then
		for _, record in data.slots do
			if record.model then
				liveRecords[record.model] = nil
				record.model:Destroy()
			end
		end
		if data.plotIndex then
			plotOwners[data.plotIndex] = nil
			plots[data.plotIndex].signLabel.Text = "EMPTY PLOT"
		end
	end
	State.remove(player)
end

Players.PlayerAdded:Connect(onPlayerAdded)
Players.PlayerRemoving:Connect(onPlayerRemoving)
for _, player in Players:GetPlayers() do
	task.spawn(onPlayerAdded, player)
	player.CharacterAdded:Connect(function(character: Model)
		onCharacterAdded(player, character)
	end)
end
Players.PlayerAdded:Connect(function(player: Player)
	player.CharacterAdded:Connect(function(character: Model)
		onCharacterAdded(player, character)
	end)
end)

-- Income ticks, once a second, for every player at once.
task.spawn(function()
	while true do
		task.wait(INCOME_SECONDS)
		for _, data in State.all() do
			local income = State.incomePerSecond(data)
			data.cash += income
			local leaderstats = data.player:FindFirstChild("leaderstats") :: Folder
			if leaderstats then
				(leaderstats:FindFirstChild("Cash") :: IntValue).Value = math.floor(data.cash);
				(leaderstats:FindFirstChild("Income") :: IntValue).Value = math.floor(income)
			end
		end
	end
end)

-- The conveyor restocks itself every few seconds.
task.spawn(function()
	while true do
		task.wait(CONVEYOR_SPAWN_SECONDS)
		spawnConveyorBrainrot(nil)
	end
end)

-- The wave clock: warn, sweep, repeat. A countdown goes to clients.
task.spawn(function()
	while true do
		task.wait(5)
		if not waveInProgress then
			local remaining = math.max(0, math.floor(nextWaveAt - os.clock()))
			notifyAll("waveTimer", tostring(remaining))
			if remaining <= 0 then
				task.spawn(startWave)
			end
		end
	end
end)

-- Life: bobbing conveyor snackrots and cycling rainbow paint.
RunService.Heartbeat:Connect(function()
	local t = os.clock()
	for model, base in bobbing do
		if model.Parent then
			model:PivotTo(base * CFrame.new(0, math.sin(t * 2 + model:GetAttribute("Rate") :: number) * 0.3, 0))
		else
			bobbing[model] = nil
		end
	end
	local hue = (t % 5) / 5
	for i = #rainbows, 1, -1 do
		local model = rainbows[i]
		if model.Parent then
			local paint = Color3.fromHSV(hue, 0.85, 1)
			for _, part in model:GetDescendants() do
				if part:IsA("BasePart") and (part.Name == "Body" or part.Name == "Head" or part.Name == "Belly") then
					part.Color = paint
				end
			end
		else
			table.remove(rainbows, i)
		end
	end
end)

-- Reviewer helpers (TOUR.json).
function Server.debugFillBase(player: Player)
	local data = State.get(player)
	if not data or not data.plotIndex then
		return
	end
	for _, rarity in BrainrotData.RARITIES do
		local slot = State.freeSlot(data)
		if not slot then
			break
		end
		local pool = BrainrotData.speciesOfRarity(rarity.id)
		local species = pool[1]
		local record = {
			id = nextBrainrotId(),
			speciesId = species.id,
			name = species.name,
			rarity = rarity.id,
			mutation = "None",
			rate = species.rate,
			price = species.rate * BrainrotData.PRICE_MULT,
			quirk = species.quirk,
			slot = 0,
			conveyorPoint = nil,
			ownerId = player.UserId,
		}
		local plot = plots[data.plotIndex]
		local model = BrainrotFactory.build(record, plot.slots[slot], plot.center)
		model.Parent = brainrotFolder
		record.model = model
		local prompt = (model.PrimaryPart :: Part):FindFirstChild("BrainrotPrompt") :: ProximityPrompt
		prompt.Triggered:Connect(function(triggeringPlayer: Player)
			onBrainrotPrompt(triggeringPlayer, prompt)
		end)
		slotBrainrot(data, record, slot)
	end
end

function Server.debugStartWave()
	task.spawn(startWave)
end

function Server.debugSpawnRarity(rarityId: string): string
	local name = spawnConveyorBrainrot(rarityId)
	if name then
		return "spawned " .. name
	end
	return "conveyor is full"
end

Debug.register(Server)

print("Snackrot Bay server ready: " .. tostring(#plots) .. " plots, " .. tostring(#conveyorPoints) .. " conveyor points.")
