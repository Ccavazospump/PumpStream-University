--[[
	SaveManager
	-----------
	Persists each player's cash and owned upgrades with DataStoreService.
	NOTE: in Roblox Studio, enable
	  Game Settings -> Security -> "Enable Studio Access to API Services"
	or saving is silently skipped (the game still plays fine).
]]

local DataStoreService = game:GetService("DataStoreService")
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local GameConfig = require(ReplicatedStorage.Shared.GameConfig)
local Economy = require(script.Parent.Economy)

local SaveManager = {}

local STORE_NAME = "RetailTycoon_v1"
local store
local sessions = {} -- [player] = { cash = number, upgrades = {id, ...} }

local ok = pcall(function()
	store = DataStoreService:GetDataStore(STORE_NAME)
end)
if not ok then
	warn("[SaveManager] DataStores unavailable — progress will not save this session.")
end

-- Load (or create) the player's data and keep it in the session table.
function SaveManager.load(player)
	local data
	if store then
		local success, result = pcall(function()
			return store:GetAsync("player_" .. player.UserId)
		end)
		if success then
			data = result
		else
			warn("[SaveManager] Load failed for", player.Name, result)
		end
	end
	data = data or {}
	data.cash = data.cash or GameConfig.StartingCash
	data.upgrades = data.upgrades or {}
	sessions[player] = data
	return data
end

function SaveManager.getData(player)
	return sessions[player]
end

function SaveManager.save(player)
	local data = sessions[player]
	if not data or not store then
		return
	end
	data.cash = Economy.getCash(player)
	local success, err = pcall(function()
		store:SetAsync("player_" .. player.UserId, {
			cash = data.cash,
			upgrades = data.upgrades,
		})
	end)
	if not success then
		warn("[SaveManager] Save failed for", player.Name, err)
	end
end

function SaveManager.clearSession(player)
	sessions[player] = nil
end

-- Autosave everyone periodically, and flush on shutdown.
function SaveManager.startAutosave()
	task.spawn(function()
		while true do
			task.wait(120)
			for _, player in ipairs(Players:GetPlayers()) do
				SaveManager.save(player)
			end
		end
	end)

	game:BindToClose(function()
		if RunService:IsStudio() then
			task.wait(1) -- give Studio saves a moment
		end
		for _, player in ipairs(Players:GetPlayers()) do
			SaveManager.save(player)
		end
	end)
end

return SaveManager
