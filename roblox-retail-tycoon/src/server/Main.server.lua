--[[
	Main (server entry point)
	-------------------------
	Boots the whole game: creates remotes, the ground + spawn, all plots,
	and hooks up player join/leave.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

-- Remotes must exist before any module tries to use them
local remotes = Instance.new("Folder")
remotes.Name = "Remotes"
local notify = Instance.new("RemoteEvent")
notify.Name = "Notify"
notify.Parent = remotes
remotes.Parent = ReplicatedStorage

local GameConfig = require(ReplicatedStorage.Shared.GameConfig)
local Economy = require(script.Parent.Economy)
local SaveManager = require(script.Parent.SaveManager)
local ItemManager = require(script.Parent.ItemManager)
local PlotManager = require(script.Parent.PlotManager)
local Ambiance = require(script.Parent.Ambiance)

-- ground plane + spawn (skipped if the place already has a Baseplate)
if not workspace:FindFirstChild("Baseplate") then
	local ground = Instance.new("Part")
	ground.Name = "Ground"
	ground.Size = Vector3.new(1400, 1, 1400)
	ground.CFrame = CFrame.new(0, -0.51, 0)
	ground.Anchored = true
	ground.Color = Color3.fromRGB(106, 158, 88)
	ground.Material = Enum.Material.Grass
	ground.Parent = workspace
end

if not workspace:FindFirstChildOfClass("SpawnLocation") then
	local spawnLocation = Instance.new("SpawnLocation")
	spawnLocation.Size = Vector3.new(14, 1, 14)
	spawnLocation.CFrame = CFrame.new(0, 1, 110) -- on the "street" in front of the plots
	spawnLocation.Anchored = true
	spawnLocation.Color = Color3.fromRGB(240, 240, 240)
	spawnLocation.Duration = 0
	spawnLocation.Parent = workspace
end

Ambiance.setup()
PlotManager.init()
SaveManager.startAutosave()

Players.PlayerAdded:Connect(function(player)
	local data = SaveManager.load(player)
	Economy.setup(player, data.cash)
	player:SetAttribute("CarryCapacity", GameConfig.BaseCarryCapacity)
	player:SetAttribute("Carrying", 0)

	-- dropped items don't survive death
	player.CharacterAdded:Connect(function(character)
		local humanoid = character:WaitForChild("Humanoid", 5)
		if humanoid then
			humanoid.Died:Connect(function()
				ItemManager.clear(player)
			end)
		end
	end)
end)

Players.PlayerRemoving:Connect(function(player)
	PlotManager.release(player)
	ItemManager.clear(player)
	SaveManager.save(player)
	SaveManager.clearSession(player)
end)

print("[RetailTycoon] Server started — " .. GameConfig.Plot.Count .. " plots ready.")
