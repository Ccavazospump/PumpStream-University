--[[
	ItemManager
	-----------
	The pick-up / carry / hand-over system. Carried items are shown as a
	stack of colored cubes floating above the player's head. Carry
	capacity starts at 1 and grows with the Basket and Cart upgrades.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local GameConfig = require(ReplicatedStorage.Shared.GameConfig)
local Util = require(script.Parent.Util)
local CustomerManager = require(script.Parent.CustomerManager)

local ItemManager = {}

local carried = {} -- [player] = { itemId, itemId, ... }

local function getCapacity(player)
	return player:GetAttribute("CarryCapacity") or GameConfig.BaseCarryCapacity
end

-- Rebuild the floating stack of item cubes above the player's head.
local function refreshStack(player)
	local list = carried[player] or {}
	local character = player.Character
	if not character then
		return
	end
	local root = character:FindFirstChild("HumanoidRootPart")
	if not root then
		return
	end

	-- clear old visuals
	for _, child in ipairs(character:GetChildren()) do
		if child.Name == "CarriedItem" then
			child:Destroy()
		end
	end

	for index, itemId in ipairs(list) do
		local item = GameConfig.Items[itemId]
		local cube = Instance.new("Part")
		cube.Name = "CarriedItem"
		cube.Size = Vector3.new(1.2, 1.2, 1.2)
		cube.Color = item.color
		cube.CanCollide = false
		cube.Massless = true
		cube.TopSurface = Enum.SurfaceType.Smooth
		cube.BottomSurface = Enum.SurfaceType.Smooth
		cube.CFrame = root.CFrame * CFrame.new(0, 3 + index * 1.35, 0)
		local weld = Instance.new("WeldConstraint")
		weld.Part0 = root
		weld.Part1 = cube
		weld.Parent = cube
		cube.Parent = character
	end

	player:SetAttribute("Carrying", #list)
end

-- Shelf prompt handler: grab one item off the shelf.
function ItemManager.pickup(player, plot, itemId)
	if plot.owner ~= player then
		Util.notify(player, "This isn't your store!", "error")
		return
	end
	local list = carried[player]
	if not list then
		list = {}
		carried[player] = list
	end
	local capacity = getCapacity(player)
	if #list >= capacity then
		Util.notify(player, string.format("🧺 Hands full! (%d/%d) — buy a Basket or Cart upgrade.", #list, capacity), "error")
		return
	end
	table.insert(list, itemId)
	refreshStack(player)
	Util.notify(player, "Picked up " .. GameConfig.Items[itemId].name, "info")
end

-- Customer prompt handler: hand over everything they need from what we carry.
function ItemManager.giveTo(player, plot, customer)
	if plot.owner ~= player then
		return
	end
	local list = carried[player]
	if not list or #list == 0 then
		Util.notify(player, "You're not carrying anything — grab items from the shelves!", "error")
		return
	end

	local delivered = 0
	for i = #list, 1, -1 do
		local accepted = CustomerManager.deliver(plot, customer, list[i], 1)
		if accepted > 0 then
			table.remove(list, i)
			delivered += 1
		end
	end

	if delivered > 0 then
		refreshStack(player)
	else
		Util.notify(player, customer.model.Name .. " doesn't need any of that.", "error")
	end
end

-- Drop everything (death, leaving, releasing plot).
function ItemManager.clear(player)
	carried[player] = nil
	local character = player.Character
	if character then
		for _, child in ipairs(character:GetChildren()) do
			if child.Name == "CarriedItem" then
				child:Destroy()
			end
		end
	end
	player:SetAttribute("Carrying", 0)
end

return ItemManager
