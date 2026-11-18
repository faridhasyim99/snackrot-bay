-- Snackrot Bay: the client. Builds the whole HUD in code (cash, income,
-- rebirths, wave timer, base lock, rebirth and upgrade buttons, event
-- banner, toasts and the leaderboard) and talks to the server through one
-- RemoteEvent. The top-left corner is kept clear: Roblox's own menu sits
-- there, and screenshots must stay readable.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local BrainrotData = require(Shared:WaitForChild("BrainrotData"))
local Util = require(Shared:WaitForChild("Util"))

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")
local leaderstats = player:WaitForChild("leaderstats")
local cashValue = leaderstats:WaitForChild("Cash") :: IntValue
local incomeValue = leaderstats:WaitForChild("Income") :: IntValue
local rebirthValue = leaderstats:WaitForChild("Rebirths") :: IntValue

local remotes = ReplicatedStorage:WaitForChild("Remotes")
local gameAction = remotes:WaitForChild("GameAction") :: RemoteEvent
local gameNotify = remotes:WaitForChild("GameNotify") :: RemoteEvent

local speedLevel = 0
local incomeLevel = 0
local lockUntil = 0

local gui = Instance.new("ScreenGui")
gui.Name = "SnackrotHud"
gui.ResetOnSpawn = false
gui.IgnoreGuiInset = true
gui.Parent = playerGui

local function makeLabel(parent: Instance, name: string, text: string, size: UDim2, pos: UDim2, textSize: number, color: Color3): TextLabel
	local label = Instance.new("TextLabel")
	label.Name = name
	label.Size = size
	label.Position = pos
	label.BackgroundTransparency = 1
	label.Text = text
	label.TextColor3 = color
	label.TextSize = textSize
	label.TextStrokeTransparency = 0.3
	label.Font = Enum.Font.SourceSansBold
	label.Parent = parent
	return label
end

local function makeButton(parent: Instance, name: string, text: string, size: UDim2, pos: UDim2): TextButton
	local button = Instance.new("TextButton")
	button.Name = name
	button.Size = size
	button.Position = pos
	button.BackgroundColor3 = Color3.fromRGB(35, 55, 90)
	button.BorderColor3 = Color3.fromRGB(255, 215, 0)
	button.BorderSizePixel = 2
	button.Text = text
	button.TextColor3 = Color3.fromRGB(255, 255, 255)
	button.TextSize = 18
	button.Font = Enum.Font.SourceSansBold
	button.Parent = parent
	return button
end

-- Top bar, centred: cash, income, rebirths and the wave countdown.
local topBar = Instance.new("Frame")
topBar.Name = "TopBar"
topBar.AnchorPoint = Vector2.new(0.5, 0)
topBar.Position = UDim2.new(0.5, 0, 0, 12)
topBar.Size = UDim2.fromOffset(680, 56)
topBar.BackgroundColor3 = Color3.fromRGB(20, 30, 55)
topBar.BackgroundTransparency = 0.25
topBar.BorderSizePixel = 0
topBar.Parent = gui

local cashLabel = makeLabel(topBar, "Cash", "$250", UDim2.new(0.32, 0, 1, 0), UDim2.new(0.02, 0, 0, 0), 26, Color3.fromRGB(140, 255, 140))
local incomeLabel = makeLabel(topBar, "Income", "+$0/s", UDim2.new(0.24, 0, 1, 0), UDim2.new(0.34, 0, 0, 0), 22, Color3.fromRGB(255, 220, 120))
local rebirthLabel = makeLabel(topBar, "Rebirths", "Rebirth 0", UDim2.new(0.2, 0, 1, 0), UDim2.new(0.58, 0, 0, 0), 22, Color3.fromRGB(200, 160, 255))
local waveLabel = makeLabel(topBar, "Wave", "Wave 4:00", UDim2.new(0.22, 0, 1, 0), UDim2.new(0.78, 0, 0, 0), 20, Color3.fromRGB(120, 200, 255))

-- Right-hand action panel.
local panel = Instance.new("Frame")
panel.Name = "ActionPanel"
panel.AnchorPoint = Vector2.new(1, 0)
panel.Position = UDim2.new(1, -16, 0, 84)
panel.Size = UDim2.fromOffset(220, 250)
panel.BackgroundColor3 = Color3.fromRGB(20, 30, 55)
panel.BackgroundTransparency = 0.25
panel.BorderSizePixel = 0
panel.Parent = gui

makeLabel(panel, "PanelTitle", "SNACKROT BAY", UDim2.new(1, 0, 0, 30), UDim2.new(0, 0, 0, 0), 20, Color3.fromRGB(255, 215, 0))
local lockButton = makeButton(panel, "LockButton", "Lock Base (60s)", UDim2.new(1, -16, 0, 40), UDim2.new(0, 8, 0, 36))
local rebirthButton = makeButton(panel, "RebirthButton", "Rebirth ($100K)", UDim2.new(1, -16, 0, 40), UDim2.new(0, 8, 0, 84))
local speedButton = makeButton(panel, "SpeedButton", "Speed Lv 0 ($500)", UDim2.new(1, -16, 0, 40), UDim2.new(0, 8, 0, 132))
local incomeButton = makeButton(panel, "IncomeButton", "Income+ Lv 0 ($1K)", UDim2.new(1, -16, 0, 40), UDim2.new(0, 8, 0, 180))
makeLabel(panel, "PanelHint", "Steal from unlocked bases!", UDim2.new(1, 0, 0, 24), UDim2.new(0, 0, 0, 224), 15, Color3.fromRGB(255, 180, 180))

-- Leaderboard, left side below Roblox's menu row.
local board = Instance.new("Frame")
board.Name = "Leaderboard"
board.Position = UDim2.new(0, 16, 0, 84)
board.Size = UDim2.fromOffset(230, 170)
board.BackgroundColor3 = Color3.fromRGB(20, 30, 55)
board.BackgroundTransparency = 0.25
board.BorderSizePixel = 0
board.Parent = gui
makeLabel(board, "BoardTitle", "RICHEST SNACKROTTERS", UDim2.new(1, 0, 0, 28), UDim2.new(0, 0, 0, 0), 17, Color3.fromRGB(255, 215, 0))
local boardLines = {}
for i = 1, 5 do
	boardLines[i] = makeLabel(board, "Line" .. tostring(i), "", UDim2.new(1, -12, 0, 26), UDim2.new(0, 6, 0, 28 + (i - 1) * 27), 17, Color3.fromRGB(255, 255, 255))
end

-- Event banner, centre under the top bar.
local banner = Instance.new("TextLabel")
banner.Name = "Banner"
banner.AnchorPoint = Vector2.new(0.5, 0)
banner.Position = UDim2.new(0.5, 0, 0, 80)
banner.Size = UDim2.fromOffset(620, 52)
banner.BackgroundColor3 = Color3.fromRGB(200, 40, 40)
banner.BackgroundTransparency = 0.15
banner.BorderSizePixel = 0
banner.Text = ""
banner.TextColor3 = Color3.fromRGB(255, 255, 255)
banner.TextSize = 26
banner.Font = Enum.Font.SourceSansBold
banner.Visible = false
banner.Parent = gui

-- Toast, bottom centre. It wraps: a bought brainrot's quirk line can run
-- long, and clipping it would hide the joke.
local toast = Instance.new("TextLabel")
toast.Name = "Toast"
toast.AnchorPoint = Vector2.new(0.5, 1)
toast.Position = UDim2.new(0.5, 0, 1, -100)
toast.Size = UDim2.fromOffset(640, 64)
toast.BackgroundColor3 = Color3.fromRGB(20, 30, 55)
toast.BackgroundTransparency = 0.25
toast.BorderSizePixel = 0
toast.Text = ""
toast.TextColor3 = Color3.fromRGB(255, 255, 255)
toast.TextSize = 19
toast.TextWrapped = true
toast.Font = Enum.Font.SourceSans
toast.Visible = false
toast.Parent = gui

-- How to play, bottom left.
makeLabel(gui, "Help", "WASD to move  •  Buy snackrots on the conveyor  •  Steal from unlocked bases  •  Outrun the Snackwave!", UDim2.new(0, 700, 0, 34), UDim2.new(0, 16, 1, -44), 16, Color3.fromRGB(255, 255, 255))

local function refreshMoney()
	cashLabel.Text = Util.formatMoney(cashValue.Value)
	incomeLabel.Text = "+" .. Util.formatRate(incomeValue.Value)
	rebirthLabel.Text = "Rebirth " .. tostring(rebirthValue.Value)
	rebirthButton.Text = "Rebirth (" .. Util.formatMoney(BrainrotData.rebirthCost(rebirthValue.Value)) .. ")"
end

local function refreshUpgrades()
	speedButton.Text = if speedLevel >= 3
		then "Speed MAX"
		else "Speed Lv " .. tostring(speedLevel) .. " (" .. Util.formatMoney(500 * (2 ^ speedLevel)) .. ")"
	incomeButton.Text = if incomeLevel >= 5
		then "Income+ MAX"
		else "Income+ Lv " .. tostring(incomeLevel) .. " (" .. Util.formatMoney(1000 * (2 ^ incomeLevel)) .. ")"
end

local function refreshLock()
	if os.clock() < lockUntil then
		lockButton.Text = "Locked (" .. tostring(math.ceil(lockUntil - os.clock())) .. "s)"
	else
		lockButton.Text = "Lock Base (60s)"
	end
end

local function refreshBoard()
	local rows = {}
	for _, other in Players:GetPlayers() do
		local stats = other:FindFirstChild("leaderstats")
		local cash = stats and stats:FindFirstChild("Cash") :: IntValue
		if cash then
			table.insert(rows, { name = other.DisplayName, cash = cash.Value })
		end
	end
	table.sort(rows, function(a, b)
		return a.cash > b.cash
	end)
	for i = 1, 5 do
		if rows[i] then
			boardLines[i].Text = tostring(i) .. ". " .. rows[i].name .. "  " .. Util.formatMoney(rows[i].cash)
		else
			boardLines[i].Text = ""
		end
	end
end

cashValue:GetPropertyChangedSignal("Value"):Connect(refreshMoney)
incomeValue:GetPropertyChangedSignal("Value"):Connect(refreshMoney)
rebirthValue:GetPropertyChangedSignal("Value"):Connect(refreshMoney)

lockButton.MouseButton1Click:Connect(function()
	gameAction:FireServer("lock")
end)
rebirthButton.MouseButton1Click:Connect(function()
	gameAction:FireServer("rebirth")
end)
speedButton.MouseButton1Click:Connect(function()
	gameAction:FireServer("upgrade", "speed")
end)
incomeButton.MouseButton1Click:Connect(function()
	gameAction:FireServer("upgrade", "income")
end)

local bannerUntil = 0
local toastUntil = 0
gameNotify.OnClientEvent:Connect(function(kind: string, message: string)
	if kind == "toast" then
		toast.Text = message
		toast.Visible = true
		toastUntil = os.clock() + 4
	elseif kind == "banner" then
		banner.Text = message
		banner.Visible = true
		bannerUntil = os.clock() + 5
	elseif kind == "waveTimer" then
		local seconds = tonumber(message) or 0
		local mins = math.floor(seconds / 60)
		local secs = seconds % 60
		waveLabel.Text = "Wave " .. tostring(mins) .. ":" .. string.format("%02d", secs)
	elseif kind == "lockState" then
		lockUntil = os.clock() + (tonumber(message) or 0)
		refreshLock()
	elseif kind == "upgradeState" then
		local speed, income = string.match(message, "^(%d+),(%d+)$")
		speedLevel = tonumber(speed) or speedLevel
		incomeLevel = tonumber(income) or incomeLevel
		refreshUpgrades()
	elseif kind == "rebirthState" then
		refreshMoney()
	end
end)

-- Hide banners and toasts when their time is up; tick the lock button.
task.spawn(function()
	while true do
		task.wait(0.5)
		if banner.Visible and os.clock() > bannerUntil then
			banner.Visible = false
		end
		if toast.Visible and os.clock() > toastUntil then
			toast.Visible = false
		end
		refreshLock()
	end
end)

task.spawn(function()
	while true do
		task.wait(2)
		refreshBoard()
	end
end)

refreshMoney()
refreshUpgrades()
refreshBoard()
