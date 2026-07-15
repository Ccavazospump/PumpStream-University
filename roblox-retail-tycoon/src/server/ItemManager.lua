--[[
	ItemManager
	-----------
	The pick-up / carry / hand-over system. Carried items are shown as a
	stack of little product models above the player's head. Carry capacity
	starts at 1 and grows with Basket / Cart / Pro Bag upgrades.

	Grabbed the wrong thing? Two ways to fix it:
	  • press X to put back the last item you picked up
	  • use the Returns Bin by the checkout to put back everything
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local GameConfig = require(ReplicatedStorage.Shared.GameConfig)
local Util = require(script.Parent.Util)
local ItemVisuals = require(script.Parent.ItemVisuals)
local CustomerManager = require(script.Parent.CustomerManager)

local ItemManager = {}

local carried = {} -- [player] = { itemId, itemId, ... }

local function getCapacity(player)
	return player:GetAttribute("CarryCapacity") or GameConfig.BaseCarryCapacity
end

-- Rebuild the floating stack of product models above the player's head.
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

	for _, child in ipairs(character:GetChildren()) do
		if child.Name == "CarriedItem" then
			child:Destroy()
		end
	end

	for index, itemId in ipairs(list) do
		local model = ItemVisuals.buildModel(itemId, { anchored = false, scale = 0.75 })
		model.Name = "CarriedItem"
		model:PivotTo(root.CFrame * CFrame.new(0, 2.8 + index * 1.15, 0))
		local weld = Instance.new("WeldConstraint")
		weld.Part0 = root
		weld.Part1 = model.PrimaryPart
		weld.Parent = model.PrimaryPart
		model.Parent = character
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
		Util.notify(player, string.format("🧺 Hands full! (%d/%d) — press X to put one back.", #list, capacity), "error")
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
		Util.notify(player, customer.model.Name .. " doesn't need any of that — press X to put it back.", "error")
	end
end

-- X key: put back the most recently grabbed item.
function ItemManager.putBackLast(player)
	local list = carried[player]
	if not list or #list == 0 then
		return
	end
	local itemId = table.remove(list)
	refreshStack(player)
	Util.notify(player, "Put back " .. GameConfig.Items[itemId].name, "info")
end

-- Returns Bin: put back everything.
function ItemManager.putBackAll(player)
	local list = carried[player]
	if not list or #list == 0 then
		Util.notify(player, "You're not carrying anything.", "info")
		return
	end
	carried[player] = {}
	refreshStack(player)
	Util.notify(player, "↩️ Put everything back. Fresh start!", "success")
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
