-- Snackrot Bay: player state. One table per player, owned by the server,
-- and every system (income, buying, stealing, locks, rebirths, upgrades)
-- reads and writes through this module alone.

local BrainrotData = require(game:GetService("ReplicatedStorage"):WaitForChild("Shared"):WaitForChild("BrainrotData"))

local State = {}

State.LOCK_SECONDS = 60
State.LOCK_COOLDOWN_SECONDS = 180
State.MAX_SPEED_LEVEL = 3
State.MAX_INCOME_LEVEL = 5
State.UPGRADE_BASE_COST = 500

-- {[userId] = PlayerData}
local players = {}

export type BrainrotRecord = {
	id: string,
	speciesId: string,
	name: string,
	rarity: string,
	mutation: string,
	rate: number,
	price: number,
	quirk: string,
	slot: number,
	model: Model?,
}

export type PlayerData = {
	player: Player,
	cash: number,
	rebirths: number,
	speedLevel: number,
	incomeLevel: number,
	plotIndex: number?,
	lockUntil: number,
	lockCooldownUntil: number,
	slots: { [number]: BrainrotRecord },
}

function State.newPlayer(player: Player): PlayerData
	local data: PlayerData = {
		player = player,
		cash = BrainrotData.START_CASH,
		rebirths = 0,
		speedLevel = 0,
		incomeLevel = 0,
		plotIndex = nil,
		lockUntil = 0,
		lockCooldownUntil = 0,
		slots = {},
	}
	players[player.UserId] = data
	return data
end

function State.get(player: Player): PlayerData?
	return players[player.UserId]
end

function State.remove(player: Player)
	players[player.UserId] = nil
end

function State.all(): { PlayerData }
	local list = {}
	for _, data in players do
		table.insert(list, data)
	end
	return list
end

-- Income multiplier from upgrades (+10% a level) and rebirths (+25% each).
function State.incomeMult(data: PlayerData): number
	return (1 + 0.10 * data.incomeLevel) * BrainrotData.rebirthMult(data.rebirths)
end

-- $/s the player's slotted brainrots earn, before multipliers.
function State.baseIncome(data: PlayerData): number
	local total = 0
	for _, record in data.slots do
		total += record.rate
	end
	return total
end

function State.incomePerSecond(data: PlayerData): number
	return State.baseIncome(data) * State.incomeMult(data)
end

function State.brainrotCount(data: PlayerData): number
	local count = 0
	for _ in data.slots do
		count += 1
	end
	return count
end

-- First empty slot number (1..BASE_SLOTS), or nil when the base is full.
function State.freeSlot(data: PlayerData): number?
	for i = 1, BrainrotData.BASE_SLOTS do
		if data.slots[i] == nil then
			return i
		end
	end
	return nil
end

function State.canAfford(data: PlayerData, price: number): boolean
	return data.cash >= price
end

function State.spend(data: PlayerData, price: number): boolean
	if data.cash < price then
		return false
	end
	data.cash -= price
	return true
end

-- The base lock: stealing is refused while now < lockUntil.
function State.isLocked(data: PlayerData): boolean
	return os.clock() < data.lockUntil
end

function State.lockRemaining(data: PlayerData): number
	return math.max(0, data.lockUntil - os.clock())
end

function State.lockCooldownRemaining(data: PlayerData): number
	return math.max(0, data.lockCooldownUntil - os.clock())
end

function State.tryLock(data: PlayerData): (boolean, string)
	if State.isLocked(data) then
		return false, "Your base is already locked."
	end
	local cooldown = State.lockCooldownRemaining(data)
	if cooldown > 0 then
		return false, "Lock recharging: " .. tostring(math.ceil(cooldown)) .. "s left."
	end
	local now = os.clock()
	data.lockUntil = now + State.LOCK_SECONDS
	data.lockCooldownUntil = now + State.LOCK_COOLDOWN_SECONDS
	return true, "Base locked for " .. tostring(State.LOCK_SECONDS) .. "s!"
end

function State.upgradeCost(kind: string, level: number): number
	return State.UPGRADE_BASE_COST * (2 ^ level) * (if kind == "income" then 2 else 1)
end

function State.tryUpgrade(data: PlayerData, kind: string): (boolean, string)
	if kind == "speed" then
		if data.speedLevel >= State.MAX_SPEED_LEVEL then
			return false, "Walk speed is maxed out."
		end
		local cost = State.upgradeCost(kind, data.speedLevel)
		if not State.spend(data, cost) then
			return false, "Not enough cash for walk speed."
		end
		data.speedLevel += 1
		return true, "Walk speed up! Level " .. tostring(data.speedLevel) .. "."
	elseif kind == "income" then
		if data.incomeLevel >= State.MAX_INCOME_LEVEL then
			return false, "Income boost is maxed out."
		end
		local cost = State.upgradeCost(kind, data.incomeLevel)
		if not State.spend(data, cost) then
			return false, "Not enough cash for the income boost."
		end
		data.incomeLevel += 1
		return true, "Income boost up! Level " .. tostring(data.incomeLevel) .. "."
	end
	return false, "Unknown upgrade."
end

-- Walk speed from upgrades: 16 base, +4 a level.
function State.walkSpeed(data: PlayerData): number
	return 16 + 4 * data.speedLevel
end

function State.tryRebirth(data: PlayerData): (boolean, string)
	local cost = BrainrotData.rebirthCost(data.rebirths)
	if data.cash < cost then
		return false, "Rebirth needs " .. tostring(cost) .. " cash."
	end
	data.cash = 0
	data.rebirths += 1
	for _, record in data.slots do
		if record.model then
			record.model:Destroy()
		end
	end
	table.clear(data.slots)
	return true, "Rebirth " .. tostring(data.rebirths) .. "! Income x" .. string.format("%.2f", BrainrotData.rebirthMult(data.rebirths)) .. " forever."
end

return State
