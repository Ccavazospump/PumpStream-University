--[[
	Main (client entry point)
	-------------------------
	The HUD: cash display, carry counter, toast notifications, and a few
	welcome tips for new players. All gameplay runs on the server.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

local remotes = ReplicatedStorage:WaitForChild("Remotes")
local notifyRemote = remotes:WaitForChild("Notify")

-- ============================== HUD ==============================

local screenGui = Instance.new("ScreenGui")
screenGui.Name = "RetailHUD"
screenGui.ResetOnSpawn = false
screenGui.Parent = playerGui

local function styledFrame(size, position, anchor)
	local frame = Instance.new("Frame")
	frame.Size = size
	frame.Position = position
	frame.AnchorPoint = anchor or Vector2.new(0.5, 0)
	frame.BackgroundColor3 = Color3.fromRGB(25, 25, 30)
	frame.BackgroundTransparency = 0.25
	frame.BorderSizePixel = 0
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 10)
	corner.Parent = frame
	frame.Parent = screenGui
	return frame
end

local function styledLabel(parent, textSize)
	local label = Instance.new("TextLabel")
	label.Size = UDim2.fromScale(1, 1)
	label.BackgroundTransparency = 1
	label.TextColor3 = Color3.new(1, 1, 1)
	label.Font = Enum.Font.GothamBold
	label.TextSize = textSize
	label.Parent = parent
	return label
end

-- cash (bottom-left) — with a green gradient + outline so it pops
local cashFrame = styledFrame(UDim2.fromOffset(200, 48), UDim2.new(0, 14, 1, -14), Vector2.new(0, 1))
cashFrame.BackgroundTransparency = 0.1
do
	local gradient = Instance.new("UIGradient")
	gradient.Color = ColorSequence.new(Color3.fromRGB(38, 70, 48), Color3.fromRGB(22, 34, 28))
	gradient.Rotation = 90
	gradient.Parent = cashFrame
	local stroke = Instance.new("UIStroke")
	stroke.Color = Color3.fromRGB(120, 235, 150)
	stroke.Thickness = 1.6
	stroke.Transparency = 0.2
	stroke.Parent = cashFrame
end
local cashLabel = styledLabel(cashFrame, 24)
cashLabel.TextColor3 = Color3.fromRGB(150, 255, 170)

-- carry counter (above the cash, bottom-left)
local carryFrame = styledFrame(UDim2.fromOffset(200, 32), UDim2.new(0, 14, 1, -68), Vector2.new(0, 1))
local carryLabel = styledLabel(carryFrame, 16)

local function updateCash()
	local leaderstats = player:FindFirstChild("leaderstats")
	local cash = leaderstats and leaderstats:FindFirstChild("Cash")
	cashLabel.Text = "💵 $" .. (cash and cash.Value or 0)
end

local function updateCarry()
	local carrying = player:GetAttribute("Carrying") or 0
	local capacity = player:GetAttribute("CarryCapacity") or 1
	if carrying > 0 then
		carryLabel.Text = string.format("🧺 %d / %d   [X] put back", carrying, capacity)
	else
		carryLabel.Text = string.format("🧺 %d / %d", carrying, capacity)
	end
end

task.spawn(function()
	local leaderstats = player:WaitForChild("leaderstats")
	local cash = leaderstats:WaitForChild("Cash")
	updateCash()
	cash.Changed:Connect(updateCash)
end)

player:GetAttributeChangedSignal("Carrying"):Connect(updateCarry)
player:GetAttributeChangedSignal("CarryCapacity"):Connect(updateCarry)
updateCarry()

-- ============================ Toasts =============================

local toastContainer = Instance.new("Frame")
toastContainer.Size = UDim2.new(0, 380, 0.4, 0)
toastContainer.Position = UDim2.new(0.5, 0, 0.95, 0)
toastContainer.AnchorPoint = Vector2.new(0.5, 1)
toastContainer.BackgroundTransparency = 1
toastContainer.Parent = screenGui

local layout = Instance.new("UIListLayout")
layout.FillDirection = Enum.FillDirection.Vertical
layout.VerticalAlignment = Enum.VerticalAlignment.Bottom
layout.HorizontalAlignment = Enum.HorizontalAlignment.Center
layout.Padding = UDim.new(0, 6)
layout.Parent = toastContainer

local TOAST_COLORS = {
	info = Color3.fromRGB(235, 235, 235),
	success = Color3.fromRGB(140, 255, 160),
	error = Color3.fromRGB(255, 130, 120),
}

local function showToast(text, kind)
	local toast = Instance.new("TextLabel")
	toast.Size = UDim2.new(1, 0, 0, 36)
	toast.BackgroundColor3 = Color3.fromRGB(25, 25, 30)
	toast.BackgroundTransparency = 0.2
	toast.TextColor3 = TOAST_COLORS[kind] or TOAST_COLORS.info
	toast.Font = Enum.Font.GothamMedium
	toast.TextSize = 17
	toast.TextWrapped = true
	toast.Text = text
	toast.TextTransparency = 0
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 8)
	corner.Parent = toast
	toast.Parent = toastContainer

	task.delay(3.5, function()
		local tween = TweenService:Create(toast, TweenInfo.new(0.5), {
			TextTransparency = 1,
			BackgroundTransparency = 1,
		})
		tween:Play()
		tween.Completed:Wait()
		toast:Destroy()
	end)
end

notifyRemote.OnClientEvent:Connect(showToast)

-- ========================= Sound effects =========================
-- Built-in Roblox sounds (rbxasset = always available, no uploads).
-- Each entry: file, pitch, volume, and optional echo notes for layered
-- effects (the money "ka-ching" is two quick pings).

local SOUND_DEFS = {
	pickup = { file = "rbxasset://sounds/button.wav", pitch = 1.15, volume = 0.5 },
	putback = { file = "rbxasset://sounds/button.wav", pitch = 0.8, volume = 0.5 },
	money = { file = "rbxasset://sounds/electronicpingshort.wav", pitch = 1.2, volume = 0.6, echoPitch = 1.6, echoDelay = 0.09 },
	orderComplete = { file = "rbxasset://sounds/victory.wav", pitch = 1, volume = 0.3 },
	newOrder = { file = "rbxasset://sounds/electronicpingshort.wav", pitch = 0.9, volume = 0.7, echoPitch = 1.1, echoDelay = 0.18 },
	angry = { file = "rbxasset://sounds/uuhhh.wav", pitch = 1, volume = 0.5 },
	purchase = { file = "rbxasset://sounds/snap.wav", pitch = 1.1, volume = 0.6 },
}

local function playOnce(def, pitchOverride)
	local sound = Instance.new("Sound")
	sound.SoundId = def.file
	sound.Volume = def.volume or 0.5
	sound.PlaybackSpeed = pitchOverride or def.pitch or 1
	sound.Parent = screenGui
	sound.Ended:Once(function()
		sound:Destroy()
	end)
	sound:Play()
	task.delay(4, function()
		if sound.Parent then
			sound:Destroy()
		end
	end)
end

local function playSoundEffect(name)
	local def = SOUND_DEFS[name]
	if not def then
		return
	end
	playOnce(def)
	if def.echoPitch then
		task.delay(def.echoDelay or 0.1, function()
			playOnce(def, def.echoPitch)
		end)
	end
end

local soundRemote = remotes:WaitForChild("PlaySound")
soundRemote.OnClientEvent:Connect(playSoundEffect)

-- ===================== Put-back keybind (X) ======================

local putBackRemote = remotes:WaitForChild("PutBack")
UserInputService.InputBegan:Connect(function(input, gameProcessed)
	if gameProcessed then
		return
	end
	if input.KeyCode == Enum.KeyCode.X then
		putBackRemote:FireServer()
	end
end)

-- ========================= Welcome tips ==========================

local TIPS = {
	"🏪 Step on a glowing green pad to claim your store!",
	"🛒 Customers shop the aisles themselves — meet them at the register.",
	"💵 Stand at the register and use 'Checkout Customer' to ring them up.",
	"📱 Unlock Online Orders for curbside pickups — YOU shop those, for 1.5x pay!",
	"↩️ Wrong item? Press X to put it back, or use the Returns Bin.",
	"⭐ Buy the glowing upgrade pad to unlock the next thing — keep expanding!",
}

task.spawn(function()
	task.wait(3)
	for _, tip in ipairs(TIPS) do
		showToast(tip, "info")
		task.wait(4)
	end
end)
