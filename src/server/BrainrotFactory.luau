-- Snackrot Bay: builds a brainrot character model from parts. Every species
-- is the same blocky body plan (body, belly, head, eyes, feet) with its own
-- colours, scale and accessory, plus a floating label with its name, rarity
-- and money-a-second, and a ProximityPrompt the server wires up.

local BrainrotData = require(game:GetService("ReplicatedStorage"):WaitForChild("Shared"):WaitForChild("BrainrotData"))
local Util = require(game:GetService("ReplicatedStorage"):WaitForChild("Shared"):WaitForChild("Util"))

local BrainrotFactory = {}

local function part(name: string, parent: Instance, props: { [string]: any }): Part
	local p = Instance.new("Part")
	p.Name = name
	for key, value in props do
		(p :: any)[key] = value
	end
	p.Parent = parent
	return p
end

-- One accessory, built from parts on top of the head.
local function addAccessory(model: Model, kind: string, headTopY: number, scale: number, bodyColor: Color3)
	if kind == "TopHat" then
		part("HatBrim", model, {
			Anchored = true, Size = Vector3.new(2.2 * scale, 0.25 * scale, 2.2 * scale),
			CFrame = model.PrimaryPart.CFrame * CFrame.new(0, headTopY + 0.1 * scale, 0),
			Color = Color3.fromRGB(30, 30, 35), Material = Enum.Material.SmoothPlastic,
		})
		part("HatTop", model, {
			Anchored = true, Size = Vector3.new(1.4 * scale, 1.2 * scale, 1.4 * scale),
			CFrame = model.PrimaryPart.CFrame * CFrame.new(0, headTopY + 0.7 * scale, 0),
			Color = Color3.fromRGB(30, 30, 35), Material = Enum.Material.SmoothPlastic,
		})
	elseif kind == "ChefHat" then
		part("ChefHat", model, {
			Anchored = true, Shape = Enum.PartType.Ball, Size = Vector3.new(2 * scale, 1.4 * scale, 2 * scale),
			CFrame = model.PrimaryPart.CFrame * CFrame.new(0, headTopY + 0.5 * scale, 0),
			Color = Color3.fromRGB(250, 250, 250), Material = Enum.Material.SmoothPlastic,
		})
	elseif kind == "Crown" then
		part("Crown", model, {
			Anchored = true, Size = Vector3.new(1.8 * scale, 0.6 * scale, 1.8 * scale),
			CFrame = model.PrimaryPart.CFrame * CFrame.new(0, headTopY + 0.3 * scale, 0),
			Color = Color3.fromRGB(255, 215, 0), Material = Enum.Material.Neon,
		})
		for _, dx in { -0.6, 0, 0.6 } do
			part("CrownSpike", model, {
				Anchored = true, Size = Vector3.new(0.35 * scale, 0.7 * scale, 0.35 * scale),
				CFrame = model.PrimaryPart.CFrame * CFrame.new(dx * scale, headTopY + 0.8 * scale, 0),
				Color = Color3.fromRGB(255, 215, 0), Material = Enum.Material.Neon,
			})
		end
	elseif kind == "Headphones" then
		for _, dx in { -1.1, 1.1 } do
			part("EarCup", model, {
				Anchored = true, Size = Vector3.new(0.5 * scale, 1 * scale, 1 * scale),
				CFrame = model.PrimaryPart.CFrame * CFrame.new(dx * scale, headTopY - 0.4 * scale, 0),
				Color = Color3.fromRGB(40, 40, 50), Material = Enum.Material.SmoothPlastic,
			})
		end
		part("Headband", model, {
			Anchored = true, Size = Vector3.new(2.6 * scale, 0.35 * scale, 0.5 * scale),
			CFrame = model.PrimaryPart.CFrame * CFrame.new(0, headTopY + 0.1 * scale, 0),
			Color = Color3.fromRGB(40, 40, 50), Material = Enum.Material.SmoothPlastic,
		})
	elseif kind == "Cape" then
		part("Cape", model, {
			Anchored = true, Size = Vector3.new(2.4 * scale, 2.6 * scale, 0.25 * scale),
			CFrame = model.PrimaryPart.CFrame * CFrame.new(0, 0.6 * scale, -1.35 * scale),
			Color = Color3.fromRGB(200, 30, 60), Material = Enum.Material.SmoothPlastic,
		})
	elseif kind == "Mustache" then
		part("Mustache", model, {
			Anchored = true, Size = Vector3.new(1.6 * scale, 0.35 * scale, 0.4 * scale),
			CFrame = model.PrimaryPart.CFrame * CFrame.new(0, 1.15 * scale, 1.05 * scale),
			Color = Color3.fromRGB(25, 20, 15), Material = Enum.Material.SmoothPlastic,
		})
	elseif kind == "Sunglasses" then
		for _, dx in { -0.55, 0.55 } do
			part("Lens", model, {
				Anchored = true, Size = Vector3.new(0.8 * scale, 0.6 * scale, 0.2 * scale),
				CFrame = model.PrimaryPart.CFrame * CFrame.new(dx * scale, 1.55 * scale, 1.05 * scale),
				Color = Color3.fromRGB(15, 15, 20), Material = Enum.Material.Neon,
			})
		end
	end
	_ = bodyColor
end

-- Build the model for a rolled brainrot at `position`, facing `lookAt`.
-- The model is anchored and ready for the server to place or tween.
function BrainrotFactory.build(record, position: Vector3, lookAt: Vector3): Model
	local species = BrainrotData.getSpecies(record.speciesId)
	local rarity = BrainrotData.getRarity(record.rarity)
	local mutation = BrainrotData.getMutation(record.mutation)
	local scale = species.scale

	local model = Instance.new("Model")
	model.Name = BrainrotData.displayName(record)

	local bodyColor = species.body
	local bellyColor = species.belly
	if mutation.id == "Golden" or mutation.id == "Diamond" or mutation.id == "Lava" or mutation.id == "Cosmic" then
		bodyColor = mutation.color
		bellyColor = mutation.color
	end

	local base = CFrame.lookAt(position, Vector3.new(lookAt.X, position.Y, lookAt.Z))
	local body = part("Body", model, {
		Anchored = true,
		Size = Vector3.new(2.4 * scale, 2 * scale, 2 * scale),
		CFrame = base * CFrame.new(0, 1.2 * scale, 0),
		Color = bodyColor,
		Material = Enum.Material.SmoothPlastic,
	})
	model.PrimaryPart = body

	part("Belly", model, {
		Anchored = true,
		Size = Vector3.new(1.6 * scale, 1.2 * scale, 0.3 * scale),
		CFrame = base * CFrame.new(0, 1 * scale, 1.05 * scale),
		Color = bellyColor,
		Material = Enum.Material.SmoothPlastic,
	})
	part("Head", model, {
		Anchored = true,
		Size = Vector3.new(2 * scale, 1.6 * scale, 1.8 * scale),
		CFrame = base * CFrame.new(0, 2.9 * scale, 0),
		Color = bodyColor,
		Material = Enum.Material.SmoothPlastic,
	})
	for _, dx in { -0.5, 0.5 } do
		part("EyeWhite", model, {
			Anchored = true, Shape = Enum.PartType.Ball, Size = Vector3.new(0.55 * scale, 0.7 * scale, 0.3 * scale),
			CFrame = base * CFrame.new(dx * scale, 3.05 * scale, 0.95 * scale),
			Color = Color3.fromRGB(255, 255, 255), Material = Enum.Material.SmoothPlastic,
		})
		part("Pupil", model, {
			Anchored = true, Shape = Enum.PartType.Ball, Size = Vector3.new(0.28 * scale, 0.4 * scale, 0.15 * scale),
			CFrame = base * CFrame.new(dx * scale, 3.05 * scale, 1.1 * scale),
			Color = Color3.fromRGB(20, 20, 25), Material = Enum.Material.SmoothPlastic,
		})
	end
	part("Mouth", model, {
		Anchored = true, Size = Vector3.new(0.9 * scale, 0.3 * scale, 0.2 * scale),
		CFrame = base * CFrame.new(0, 2.5 * scale, 0.95 * scale),
		Color = Color3.fromRGB(120, 30, 40), Material = Enum.Material.SmoothPlastic,
	})
	for _, dx in { -0.7, 0.7 } do
		part("Foot", model, {
			Anchored = true, Size = Vector3.new(0.9 * scale, 0.4 * scale, 1.2 * scale),
			CFrame = base * CFrame.new(dx * scale, 0.2 * scale, 0.2 * scale),
			Color = Color3.fromRGB(40, 35, 30), Material = Enum.Material.SmoothPlastic,
		})
	end

	addAccessory(model, species.accessory, 3.7 * scale, scale, bodyColor)

	-- Rainbow and Cosmic repaint themselves every frame (GameServer's loop).
	if mutation.id == "Rainbow" then
		body:SetAttribute("RainbowCycle", true)
	end
	if mutation.id == "Cosmic" then
		local sparkles = Instance.new("ParticleEmitter")
		sparkles.Name = "CosmicSparkles"
		sparkles.Texture = "rbxassetid://241650934"
		sparkles.Color = ColorSequence.new(Color3.fromRGB(190, 120, 255))
		sparkles.Size = NumberSequence.new(0.5)
		sparkles.Rate = 12
		sparkles.Parent = body
	end
	if record.rarity == "Secret" then
		local glow = Instance.new("PointLight")
		glow.Name = "SecretGlow"
		glow.Color = Color3.fromRGB(170, 80, 255)
		glow.Brightness = 1.5
		glow.Range = 12
		glow.Parent = body
	end

	-- Floating label: name, rarity and money-a-second, readable at a glance.
	local billboard = Instance.new("BillboardGui")
	billboard.Name = "BrainrotLabel"
	billboard.Size = UDim2.fromOffset(180, 64)
	billboard.StudsOffset = Vector3.new(0, 5.2 * scale, 0)
	billboard.AlwaysOnTop = true
	billboard.Parent = body

	local nameLabel = Instance.new("TextLabel")
	nameLabel.Name = "Name"
	nameLabel.Size = UDim2.new(1, 0, 0.45, 0)
	nameLabel.BackgroundTransparency = 1
	nameLabel.Text = BrainrotData.displayName(record)
	nameLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
	nameLabel.TextStrokeTransparency = 0.2
	nameLabel.TextScaled = true
	nameLabel.Font = Enum.Font.SourceSansBold
	nameLabel.Parent = billboard

	local rarityLabel = Instance.new("TextLabel")
	rarityLabel.Name = "Rarity"
	rarityLabel.Position = UDim2.new(0, 0, 0.45, 0)
	rarityLabel.Size = UDim2.new(1, 0, 0.28, 0)
	rarityLabel.BackgroundTransparency = 1
	rarityLabel.Text = rarity.label .. "  •  " .. Util.formatRate(record.rate)
	rarityLabel.TextColor3 = rarity.color
	rarityLabel.TextStrokeTransparency = 0.2
	rarityLabel.TextScaled = true
	rarityLabel.Font = Enum.Font.SourceSansBold
	rarityLabel.Parent = billboard

	local priceLabel = Instance.new("TextLabel")
	priceLabel.Name = "Price"
	priceLabel.Position = UDim2.new(0, 0, 0.73, 0)
	priceLabel.Size = UDim2.new(1, 0, 0.27, 0)
	priceLabel.BackgroundTransparency = 1
	priceLabel.Text = Util.formatMoney(record.price)
	priceLabel.TextColor3 = Color3.fromRGB(140, 255, 140)
	priceLabel.TextStrokeTransparency = 0.2
	priceLabel.TextScaled = true
	priceLabel.Font = Enum.Font.SourceSansBold
	priceLabel.Parent = billboard

	-- The buy prompt; the server connects it and flips it to steal later.
	local prompt = Instance.new("ProximityPrompt")
	prompt.Name = "BrainrotPrompt"
	prompt.ActionText = "Buy"
	prompt.ObjectText = BrainrotData.displayName(record)
	prompt.HoldDuration = 0.5
	prompt.MaxActivationDistance = 14
	prompt.RequiresLineOfSight = false
	prompt.Parent = body

	model:SetAttribute("BrainrotId", record.id)
	model:SetAttribute("Rate", record.rate)
	model:SetAttribute("Price", record.price)
	return model
end

return BrainrotFactory
