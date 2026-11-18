-- Snackrot Bay: small pure helpers shared by server and client.
-- No Roblox services are touched here, so every function is safe to call anywhere.

local Util = {}

-- Clamp a number into [lo, hi].
function Util.clamp(value: number, lo: number, hi: number): number
	if value < lo then
		return lo
	elseif value > hi then
		return hi
	end
	return value
end

-- Linear interpolation between a and b.
function Util.lerp(a: number, b: number, t: number): number
	return a + (b - a) * t
end

-- Short money text: 950 -> "$950", 1250 -> "$1.2K", 3_400_000 -> "$3.4M", 2_500_000_000 -> "$2.5B".
function Util.formatMoney(amount: number): string
	local n = math.floor(amount + 0.5)
	if n < 1000 then
		return "$" .. tostring(n)
	end
	local units = { "K", "M", "B", "T" }
	local value = n
	local unitIndex = 0
	while value >= 1000 and unitIndex < #units do
		value = value / 1000
		unitIndex += 1
	end
	local text
	if value >= 100 then
		text = tostring(math.floor(value + 0.5))
	elseif value >= 10 then
		text = string.format("%.1f", value)
	else
		text = string.format("%.2f", value)
	end
	-- Trim a trailing ".0" so $1.0K reads $1K.
	if string.sub(text, -2) == ".0" then
		text = string.sub(text, 1, -3)
	end
	return "$" .. text .. units[unitIndex]
end

-- "$/s" rate text: 12 -> "$12/s", 1500 -> "$1.5K/s".
function Util.formatRate(rate: number): string
	return Util.formatMoney(rate) .. "/s"
end

-- Pick one entry from a weighted list of {weight = n, ...} tables.
function Util.weightedPick<T>(rng: Random, entries: { T }): T
	local total = 0
	for _, entry in entries do
		total += (entry :: any).weight
	end
	local roll = rng:NextNumber() * total
	for _, entry in entries do
		roll -= (entry :: any).weight
		if roll <= 0 then
			return entry
		end
	end
	return entries[#entries]
end

return Util
