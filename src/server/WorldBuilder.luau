-- Snackrot Bay: builds the 3D world at runtime. Eight beach-hut bases ring
-- a central tide conveyor; palms, rocks, a lighthouse and the bay sign dress
-- the island. Every position is computed from a few constants, so the layout
-- stays consistent and easy to tune.

local WorldBuilder = {}

local PLOT_COUNT = 8
local PLOT_RADIUS = 78
local PLOT_WIDTH = 20
local PLOT_DEPTH = 16
local SLOT_ROWS = { -4, 4 }
local SLOT_COLS = { -7.5, -2.5, 2.5, 7.5 }
local CONVEYOR_POINTS = 10
local CONVEYOR_HALF = 45

local function newPart(name: string, className: string, parent: Instance, props: { [string]: any }): Part
	local part = Instance.new(className)
	part.Name = name
	for key, value in props do
		(part :: any)[key] = value
	end
	part.Parent = parent
	return part
end

local function newModel(name: string, parent: Instance): Model
	local model = Instance.new("Model")
	model.Name = name
	model.Parent = parent
	return model
end

-- A SurfaceGui text board that faces `lookAt` from `position`.
local function signBoard(name: string, parent: Instance, position: Vector3, lookAt: Vector3, size: Vector2, text: string, textSize: number, bg: Color3): SurfaceGui
	local board = newPart(name, "Part", parent, {
		Anchored = true,
		CanCollide = false,
		Size = Vector3.new(size.X, size.Y, 0.4),
		CFrame = CFrame.lookAt(position, lookAt),
		Color = Color3.fromRGB(120, 75, 40),
		Material = Enum.Material.Wood,
	})
	local gui = Instance.new("SurfaceGui")
	gui.Name = "SignGui"
	gui.Face = Enum.NormalId.Front
	gui.Parent = board
	local label = Instance.new("TextLabel")
	label.Name = "SignText"
	label.Size = UDim2.fromScale(1, 1)
	label.BackgroundColor3 = bg
	label.BorderSizePixel = 0
	label.Text = text
	label.TextColor3 = Color3.fromRGB(255, 255, 255)
	label.TextScaled = true
	label.Font = Enum.Font.SourceSansBold
	label.Parent = gui
	return gui
end

function WorldBuilder.build(): { plots: { any }, conveyorPoints: { Vector3 } }
	local world = Instance.new("Folder")
	world.Name = "World"
	world.Parent = workspace

	-- The sea peeks out around the sand island.
	newPart("Sea", "Part", world, {
		Anchored = true,
		CanCollide = false,
		Size = Vector3.new(760, 1, 760),
		Position = Vector3.new(0, -1.5, 0),
		Color = Color3.fromRGB(35, 140, 210),
		Material = Enum.Material.SmoothPlastic,
		Transparency = 0.15,
	})

	-- The tide conveyor: a belt across the middle where snackrots wash up.
	local belt = newPart("ConveyorBelt", "Part", world, {
		Anchored = true,
		Size = Vector3.new(100, 1, 8),
		Position = Vector3.new(0, 1, 0),
		Color = Color3.fromRGB(60, 60, 70),
		Material = Enum.Material.Metal,
	})
	_ = belt
	newPart("ConveyorRailA", "Part", world, {
		Anchored = true,
		Size = Vector3.new(100, 1.5, 1),
		Position = Vector3.new(0, 1.8, -4.5),
		Color = Color3.fromRGB(255, 190, 40),
		Material = Enum.Material.SmoothPlastic,
	})
	newPart("ConveyorRailB", "Part", world, {
		Anchored = true,
		Size = Vector3.new(100, 1.5, 1),
		Position = Vector3.new(0, 1.8, 4.5),
		Color = Color3.fromRGB(255, 190, 40),
		Material = Enum.Material.SmoothPlastic,
	})

	local conveyorPoints = {}
	for i = 1, CONVEYOR_POINTS do
		local x = -CONVEYOR_HALF + (i - 1) * (2 * CONVEYOR_HALF / (CONVEYOR_POINTS - 1))
		table.insert(conveyorPoints, Vector3.new(x, 1.5, 0))
		newPart("SpawnPad" .. tostring(i), "Part", world, {
			Anchored = true,
			Size = Vector3.new(7, 0.3, 7),
			Position = Vector3.new(x, 1.6, 0),
			Color = Color3.fromRGB(90, 90, 100),
			Material = Enum.Material.SmoothPlastic,
		})
	end

	-- Eight base plots in a ring. Local +Z faces the map centre.
	local plots = {}
	for i = 1, PLOT_COUNT do
		local angle = math.rad((i - 1) * (360 / PLOT_COUNT) + 22.5)
		local center = Vector3.new(math.sin(angle) * PLOT_RADIUS, 0, math.cos(angle) * PLOT_RADIUS)
		local facing = CFrame.lookAt(center, Vector3.new(0, 0, 0))
		local plot = newModel("Plot" .. tostring(i), world)

		newPart("Pad", "Part", plot, {
			Anchored = true,
			Size = Vector3.new(PLOT_WIDTH, 1, PLOT_DEPTH),
			CFrame = facing * CFrame.new(0, 0.5, 0),
			Color = Color3.fromRGB(235, 205, 140),
			Material = Enum.Material.Sand,
		})
		-- Back wall, side walls and a roof on four posts.
		newPart("BackWall", "Part", plot, {
			Anchored = true,
			Size = Vector3.new(PLOT_WIDTH, 8, 1),
			CFrame = facing * CFrame.new(0, 4.5, -PLOT_DEPTH / 2),
			Color = Color3.fromRGB(255, 150, 90),
			Material = Enum.Material.WoodPlanks,
		})
		for _, sideX in { -PLOT_WIDTH / 2, PLOT_WIDTH / 2 } do
			newPart("SideWall", "Part", plot, {
				Anchored = true,
				Size = Vector3.new(1, 8, PLOT_DEPTH),
				CFrame = facing * CFrame.new(sideX, 4.5, 0),
				Color = Color3.fromRGB(255, 150, 90),
				Material = Enum.Material.WoodPlanks,
			})
		end
		for _, px in { -9, 9 } do
			for _, pz in { -7, 7 } do
				newPart("Post", "Part", plot, {
					Anchored = true,
					Size = Vector3.new(1, 9, 1),
					CFrame = facing * CFrame.new(px, 5.5, pz),
					Color = Color3.fromRGB(120, 75, 40),
					Material = Enum.Material.Wood,
				})
			end
		end
		newPart("Roof", "Part", plot, {
			Anchored = true,
			Size = Vector3.new(PLOT_WIDTH + 2, 0.6, PLOT_DEPTH + 2),
			CFrame = facing * CFrame.new(0, 10.2, 0),
			Color = Color3.fromRGB(255, 90, 90),
			Material = Enum.Material.SmoothPlastic,
		})

		-- Owner sign on the back wall, facing the plot.
		local signPos = facing.Position + facing.LookVector * -7.2 + Vector3.new(0, 6, 0)
		local signGui = signBoard("OwnerSign", plot, signPos, center + facing.LookVector * 10, Vector2.new(14, 3), "EMPTY PLOT", 28, Color3.fromRGB(40, 90, 140))
		local signLabel = signGui:FindFirstChild("SignText") :: TextLabel

		-- Eight slot pads, two rows of four.
		local slots = {}
		for _, rz in SLOT_ROWS do
			for _, cx in SLOT_COLS do
				local slotPos = facing * CFrame.new(cx, 1.2, rz)
				newPart("SlotPad", "Part", plot, {
					Anchored = true,
					Size = Vector3.new(3, 0.4, 3),
					CFrame = slotPos,
					Color = Color3.fromRGB(255, 220, 120),
					Material = Enum.Material.Neon,
				})
				table.insert(slots, (slotPos * CFrame.new(0, 0.2, 0)).Position)
			end
		end

		-- Green spawn pad at the front of the plot.
		newPart("SpawnPad", "Part", plot, {
			Anchored = true,
			Size = Vector3.new(4, 0.4, 4),
			CFrame = facing * CFrame.new(0, 1.2, PLOT_DEPTH / 2 + 2),
			Color = Color3.fromRGB(90, 220, 110),
			Material = Enum.Material.Neon,
		})

		table.insert(plots, {
			index = i,
			center = center,
			cframe = facing,
			slots = slots,
			signLabel = signLabel,
			spawnPoint = (facing * CFrame.new(0, 3, PLOT_DEPTH / 2 + 2)).Position,
			homeRadius = 14,
		})
	end

	-- Palms, rocks and clouds, placed with a fixed seed so the island
	-- looks the same every server.
	local rng = Random.new(20261118)
	local function scatter(count: number, minR: number, maxR: number, make: (pos: Vector3, r: Random) -> ())
		for _ = 1, count do
			local angle = rng:NextNumber() * math.pi * 2
			local radius = rng:NextNumber(minR, maxR)
			local pos = Vector3.new(math.sin(angle) * radius, 0, math.cos(angle) * radius)
			-- Keep the conveyor lane and the plot ring clear.
			if math.abs(pos.Z) > 10 or math.abs(pos.X) > 55 then
				local nearPlot = false
				for _, plot in plots do
					if (Vector2.new(pos.X - plot.center.X, pos.Z - plot.center.Z)).Magnitude < 15 then
						nearPlot = true
						break
					end
				end
				if not nearPlot then
					make(pos, rng)
				end
			end
		end
	end

	scatter(12, 30, 120, function(pos: Vector3, r: Random)
		local palm = newModel("Palm", world)
		local lean = r:NextNumber(-0.15, 0.15)
		newPart("Trunk", "Part", palm, {
			Anchored = true,
			Shape = Enum.PartType.Cylinder,
			Size = Vector3.new(9, 1.6, 1.6),
			CFrame = CFrame.new(pos + Vector3.new(0, 4.5, 0)) * CFrame.Angles(0, 0, math.rad(90) + lean),
			Color = Color3.fromRGB(140, 95, 50),
			Material = Enum.Material.Wood,
		})
		for k = 1, 3 do
			local leafAngle = math.rad(k * 120)
			newPart("Leaf", "Part", palm, {
				Anchored = true,
				Shape = Enum.PartType.Ball,
				Size = Vector3.new(4, 2, 4),
				CFrame = CFrame.new(pos + Vector3.new(math.sin(leafAngle) * 2.5, 9.5, math.cos(leafAngle) * 2.5)),
				Color = Color3.fromRGB(60, 180, 80),
				Material = Enum.Material.SmoothPlastic,
			})
		end
	end)

	scatter(14, 25, 130, function(pos: Vector3, r: Random)
		local s = r:NextNumber(2, 5)
		newPart("Rock", "Part", world, {
			Anchored = true,
			Shape = Enum.PartType.Ball,
			Size = Vector3.new(s, s * 0.7, s),
			CFrame = CFrame.new(pos + Vector3.new(0, s * 0.3, 0)),
			Color = Color3.fromRGB(130, 130, 135),
			Material = Enum.Material.Slate,
		})
	end)

	-- The lighthouse on the south-west shore.
	local light = newModel("Lighthouse", world)
	local towerBase = Vector3.new(-110, 0, 105)
	for k = 1, 5 do
		newPart("TowerRing" .. tostring(k), "Part", light, {
			Anchored = true,
			Shape = Enum.PartType.Cylinder,
			Size = Vector3.new(6, 8 - k, 8 - k),
			CFrame = CFrame.new(towerBase + Vector3.new(0, k * 6 - 3, 0)) * CFrame.Angles(0, 0, math.rad(90)),
			Color = if k % 2 == 1 then Color3.fromRGB(240, 240, 240) else Color3.fromRGB(230, 60, 60),
			Material = Enum.Material.SmoothPlastic,
		})
	end
	local lamp = newPart("Lamp", "Part", light, {
		Anchored = true,
		Shape = Enum.PartType.Ball,
		Size = Vector3.new(5, 5, 5),
		CFrame = CFrame.new(towerBase + Vector3.new(0, 32, 0)),
		Color = Color3.fromRGB(255, 240, 150),
		Material = Enum.Material.Neon,
	})
	local pointLight = Instance.new("PointLight")
	pointLight.Brightness = 2
	pointLight.Range = 60
	pointLight.Parent = lamp

	-- The bay's welcome sign, facing the centre.
	signBoard("WelcomeSign", world, Vector3.new(0, 5, 58), Vector3.new(0, 5, 0), Vector2.new(30, 6), "SNACKROT BAY", 40, Color3.fromRGB(30, 120, 180))

	-- Drifting clouds.
	for k = 1, 6 do
		local cx = rng:NextNumber(-140, 140)
		local cz = rng:NextNumber(-140, 140)
		local cy = rng:NextNumber(55, 85)
		newPart("Cloud" .. tostring(k), "Part", world, {
			Anchored = true,
			Shape = Enum.PartType.Ball,
			Size = Vector3.new(rng:NextNumber(18, 30), 7, rng:NextNumber(12, 18)),
			CFrame = CFrame.new(cx, cy, cz),
			Color = Color3.fromRGB(255, 255, 255),
			Material = Enum.Material.SmoothPlastic,
			Transparency = 0.1,
		})
	end

	return { plots = plots, conveyorPoints = conveyorPoints }
end

return WorldBuilder
