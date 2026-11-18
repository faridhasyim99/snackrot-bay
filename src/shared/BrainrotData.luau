-- Snackrot Bay: the brainrot catalogue. Every character, rarity and mutation
-- in the game is defined here, and only here, so the server, the factory and
-- the client all agree on names, rates and prices.

local Util = require(script.Parent.Util)

local BrainrotData = {}

-- Rarity ladder, cheapest first. `weight` is the conveyor spawn weight,
-- `rateLo`/`rateHi` bound the money-a-second of the tier (species set the
-- exact rate), `costMult` turns a rate into a buy price.
BrainrotData.RARITIES = {
	{ id = "Common", label = "Common", weight = 40, color = Color3.fromRGB(120, 200, 90), rateLo = 5, rateHi = 15 },
	{ id = "Rare", label = "Rare", weight = 25, color = Color3.fromRGB(70, 140, 255), rateLo = 20, rateHi = 50 },
	{ id = "Epic", label = "Epic", weight = 15, color = Color3.fromRGB(175, 90, 255), rateLo = 60, rateHi = 150 },
	{ id = "Legendary", label = "Legendary", weight = 10, color = Color3.fromRGB(255, 190, 40), rateLo = 200, rateHi = 500 },
	{ id = "Mythic", label = "Mythic", weight = 6, color = Color3.fromRGB(255, 70, 130), rateLo = 600, rateHi = 1500 },
	{ id = "Secret", label = "Secret", weight = 1, color = Color3.fromRGB(40, 20, 60), rateLo = 3000, rateHi = 8000 },
}

-- A mutation multiplies the rate (and the price) and repaints the model.
BrainrotData.MUTATIONS = {
	{ id = "None", label = "", weight = 80, mult = 1, color = nil },
	{ id = "Golden", label = "Golden", weight = 8, mult = 2, color = Color3.fromRGB(255, 215, 0) },
	{ id = "Lava", label = "Lava", weight = 5, mult = 8, color = Color3.fromRGB(255, 90, 20) },
	{ id = "Diamond", label = "Diamond", weight = 4, mult = 5, color = Color3.fromRGB(170, 230, 255) },
	{ id = "Rainbow", label = "Rainbow", weight = 2, mult = 10, color = nil },
	{ id = "Cosmic", label = "Cosmic", weight = 1, mult = 25, color = Color3.fromRGB(150, 60, 255) },
}

-- The cast. All names, jokes and looks are original to Snackrot Bay.
-- `rate` is the base $/s, `price` is derived from it (rate * 25).
-- `body`/`belly` are the model's colours, `accessory` picks the hat builder,
-- `scale` sizes the model, `quirk` is the one-liner shown when it is bought.
BrainrotData.SPECIES = {
	{ id = "waddlesworth", name = "Sir Waddlesworth", rarity = "Common", rate = 8, body = Color3.fromRGB(45, 110, 60), belly = Color3.fromRGB(190, 235, 170), accessory = "TopHat", scale = 1.0, quirk = "A pickle penguin. He waddles, therefore he earns." },
	{ id = "baguette", name = "Baron von Baguette", rarity = "Common", rate = 12, body = Color3.fromRGB(205, 155, 85), belly = Color3.fromRGB(240, 210, 150), accessory = "Mustache", scale = 1.0, quirk = "Crusty on the outside, rich on the inside." },
	{ id = "crumb", name = "Captain Crumb", rarity = "Common", rate = 6, body = Color3.fromRGB(150, 95, 50), belly = Color3.fromRGB(210, 160, 110), accessory = "None", scale = 0.9, quirk = "A cookie crab. He pinches pennies. Literally." },
	{ id = "nacho", name = "DJ Nacho Narwhal", rarity = "Rare", rate = 30, body = Color3.fromRGB(255, 165, 40), belly = Color3.fromRGB(255, 225, 140), accessory = "Headphones", scale = 1.1, quirk = "Drops beats and drops cash. Mostly cash." },
	{ id = "latte", name = "Madame Llama Latte", rarity = "Rare", rate = 45, body = Color3.fromRGB(235, 220, 190), belly = Color3.fromRGB(255, 250, 235), accessory = "None", scale = 1.15, quirk = "Foamy, fabulous, and financially fluent." },
	{ id = "borks", name = "Sir Borks-a-Lot", rarity = "Rare", rate = 25, body = Color3.fromRGB(190, 130, 55), belly = Color3.fromRGB(240, 200, 130), accessory = "Cape", scale = 1.0, quirk = "A croissant dog. He borks. You profit." },
	{ id = "wobble", name = "Professor Wobble", rarity = "Epic", rate = 90, body = Color3.fromRGB(255, 120, 180), belly = Color3.fromRGB(255, 200, 225), accessory = "Sunglasses", scale = 1.05, quirk = "A jelly scientist. His research pays dividends." },
	{ id = "burrito", name = "The Forbidden Burrito", rarity = "Epic", rate = 130, body = Color3.fromRGB(200, 170, 90), belly = Color3.fromRGB(120, 190, 90), accessory = "Crown", scale = 1.1, quirk = "Do not eat him. Do collect him." },
	{ id = "spaghetti", name = "Count Spaghetti", rarity = "Epic", rate = 110, body = Color3.fromRGB(250, 210, 90), belly = Color3.fromRGB(255, 240, 180), accessory = "ChefHat", scale = 1.1, quirk = "He counts noodles. He counts money. Same thing." },
	{ id = "blobert", name = "Queen Blobert", rarity = "Legendary", rate = 350, body = Color3.fromRGB(255, 110, 190), belly = Color3.fromRGB(255, 190, 220), accessory = "Crown", scale = 1.3, quirk = "Royalty made of jelly. The crown is also jelly." },
	{ id = "gnocchi", name = "Grandpa Gnocchi", rarity = "Legendary", rate = 280, body = Color3.fromRGB(230, 215, 160), belly = Color3.fromRGB(250, 240, 210), accessory = "TopHat", scale = 1.2, quirk = "Old, wise, and worth every cent." },
	{ id = "churro", name = "El Churro Supremo", rarity = "Mythic", rate = 900, body = Color3.fromRGB(165, 105, 45), belly = Color3.fromRGB(230, 180, 110), accessory = "Crown", scale = 1.4, quirk = "Supreme in name, supreme in income." },
	{ id = "meatball", name = "The Infinite Meatball", rarity = "Mythic", rate = 1200, body = Color3.fromRGB(130, 55, 35), belly = Color3.fromRGB(200, 110, 80), accessory = "None", scale = 1.5, quirk = "It never ends. Neither does the money." },
	{ id = "bananaconda", name = "Bananaconda Prime", rarity = "Secret", rate = 5000, body = Color3.fromRGB(250, 225, 60), belly = Color3.fromRGB(255, 245, 160), accessory = "Crown", scale = 1.6, quirk = "A banana snake. Slippery, potassium-rich, priceless." },
}

BrainrotData.PRICE_MULT = 25
BrainrotData.START_CASH = 250
BrainrotData.BASE_SLOTS = 8
BrainrotData.REBIRTH_BASE_COST = 100000
BrainrotData.REBIRTH_MULT_PER = 0.25

function BrainrotData.getRarity(rarityId: string)
	for _, rarity in BrainrotData.RARITIES do
		if rarity.id == rarityId then
			return rarity
		end
	end
	return BrainrotData.RARITIES[1]
end

function BrainrotData.getMutation(mutationId: string)
	for _, mutation in BrainrotData.MUTATIONS do
		if mutation.id == mutationId then
			return mutation
		end
	end
	return BrainrotData.MUTATIONS[1]
end

function BrainrotData.getSpecies(speciesId: string)
	for _, species in BrainrotData.SPECIES do
		if species.id == speciesId then
			return species
		end
	end
	return BrainrotData.SPECIES[1]
end

function BrainrotData.speciesOfRarity(rarityId: string)
	local pool = {}
	for _, species in BrainrotData.SPECIES do
		if species.rarity == rarityId then
			table.insert(pool, species)
		end
	end
	return pool
end

-- Roll a full brainrot: rarity by weight, a species of that rarity, a
-- mutation by weight. `rng` is the caller's Random so rolls stay testable.
function BrainrotData.rollBrainrot(rng: Random)
	local rarity = Util.weightedPick(rng, BrainrotData.RARITIES)
	local pool = BrainrotData.speciesOfRarity(rarity.id)
	local species = pool[rng:NextInteger(1, #pool)]
	local mutation = Util.weightedPick(rng, BrainrotData.MUTATIONS)
	local rate = species.rate * mutation.mult
	return {
		speciesId = species.id,
		name = species.name,
		rarity = rarity.id,
		mutation = mutation.id,
		rate = rate,
		price = rate * BrainrotData.PRICE_MULT,
		quirk = species.quirk,
	}
end

-- Cost of the next rebirth for a player who has rebirthed `count` times.
function BrainrotData.rebirthCost(count: number): number
	return BrainrotData.REBIRTH_BASE_COST * (2 ^ count)
end

-- Income multiplier from rebirths: +25% per rebirth.
function BrainrotData.rebirthMult(count: number): number
	return 1 + BrainrotData.REBIRTH_MULT_PER * count
end

-- Display name with mutation: "Golden Queen Blobert", "Queen Blobert".
function BrainrotData.displayName(record): string
	local mutation = BrainrotData.getMutation(record.mutation)
	if mutation.id == "None" then
		return record.name
	end
	return mutation.label .. " " .. record.name
end

return BrainrotData
