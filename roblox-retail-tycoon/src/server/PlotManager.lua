--[[
	PlotManager
	-----------
	The orchestrator. Creates all plots at server start, handles claiming
	and releasing, wires shelf/customer prompts into the item system, and
	processes upgrade purchases.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local GameConfig = require(ReplicatedStorage.Shared.GameConfig)
local Util = require(script.Parent.Util)
local Economy = require(script.Parent.Economy)
local SaveManager = require(script.Parent.SaveManager)
local PlotBuilder = require(script.Parent.PlotBuilder)
local CustomerManager = require(script.Parent.CustomerManager)
local ItemManager = require(script.Parent.ItemManager)
local StaffManager = require(script.Parent.StaffManager)

local PlotManager = {}

local plots = {}

local function ownedSet(plot)
	local set = {}
	for _, id in ipairs(plot.upgradeIds or {}) do
		set[id] = true
	end
	return set
end

-- Build a department and hook up its shelf pickup prompts.
local function buildAndWireSection(plot, sectionId)
	local section = GameConfig.getSection(sectionId)
	if not section then
		return
	end
	table.insert(plot.unlockedSections, sectionId)
	local shelves = PlotBuilder.buildSection(plot, section)
	for _, shelf in ipairs(shelves) do
		shelf.prompt.Triggered:Connect(function(player)
			if plot.owner == player then
				ItemManager.pickup(player, plot, shelf.itemId)
			end
		end)
	end
end

-- Apply one upgrade's effect to the plot/owner. `silent` skips the toast
-- (used when re-applying saved upgrades on claim).
local function applyUpgrade(plot, upgrade, silent)
	if upgrade.kind == "section" then
		buildAndWireSection(plot, upgrade.id)
	elseif upgrade.kind == "carry" then
		local current = plot.owner:GetAttribute("CarryCapacity") or GameConfig.BaseCarryCapacity
		plot.owner:SetAttribute("CarryCapacity", math.max(current, upgrade.value))
	elseif upgrade.kind == "maxCustomers" then
		plot.maxCustomers += upgrade.value
	elseif upgrade.kind == "spawnRate" then
		plot.spawnInterval = math.max(GameConfig.Customers.MinSpawnInterval, plot.spawnInterval - upgrade.value)
	elseif upgrade.kind == "payMultiplier" then
		plot.payMultiplier += upgrade.value
	elseif upgrade.kind == "staff" then
		StaffManager.hire(plot, upgrade.role)
	end
	if not silent then
		Util.notify(plot.owner, "⭐ Purchased: " .. upgrade.name .. "!", "success")
	end
end

local function tryPurchase(plot, player, upgrade)
	if plot.owner ~= player then
		Util.notify(player, "This isn't your store!", "error")
		return
	end
	local owned = ownedSet(plot)
	if owned[upgrade.id] then
		return
	end
	if upgrade.requires and not owned[upgrade.requires] then
		local required = GameConfig.getUpgrade(upgrade.requires)
		Util.notify(player, "🔒 You need " .. (required and required.name or upgrade.requires) .. " first.", "error")
		return
	end
	if not Economy.trySpend(player, upgrade.cost) then
		Util.notify(player, string.format("Not enough cash! %s costs $%d.", upgrade.name, upgrade.cost), "error")
		return
	end

	table.insert(plot.upgradeIds, upgrade.id)
	applyUpgrade(plot, upgrade, false)
	PlotBuilder.refreshUpgradePads(plot, ownedSet(plot))
end

function PlotManager.claim(plot, player)
	if plot.owner or player:GetAttribute("PlotIndex") then
		return
	end
	local data = SaveManager.getData(player)
	if not data then
		return -- still loading
	end

	plot.owner = player
	plot.generation += 1
	player:SetAttribute("PlotIndex", plot.index)

	-- fresh per-claim state
	plot.unlockedSections = {}
	plot.upgradeIds = data.upgrades -- persisted list, shared with SaveManager
	plot.maxCustomers = GameConfig.Customers.BaseMaxCustomers
	plot.spawnInterval = GameConfig.Customers.BaseSpawnInterval
	plot.payMultiplier = 1

	PlotBuilder.setClaimPadVisible(plot, false)
	PlotBuilder.setOwnerSign(plot, "🛒 " .. player.Name .. "'s Market")

	-- Produce is always free; then re-apply everything they own
	buildAndWireSection(plot, "Produce")
	for _, upgradeId in ipairs(plot.upgradeIds) do
		local upgrade = GameConfig.getUpgrade(upgradeId)
		if upgrade then
			applyUpgrade(plot, upgrade, true)
		end
	end
	PlotBuilder.refreshUpgradePads(plot, ownedSet(plot))

	-- wire each new customer's prompts to the gameplay systems
	plot.onCustomerSpawned = function(customer)
		customer.givePrompt.Triggered:Connect(function(promptPlayer)
			if plot.owner == promptPlayer then
				ItemManager.giveTo(promptPlayer, plot, customer)
			end
		end)
		customer.checkoutPrompt.Triggered:Connect(function(promptPlayer)
			if plot.owner == promptPlayer then
				CustomerManager.checkout(plot, customer)
			end
		end)
	end

	CustomerManager.startLoop(plot)
	Util.notify(player, "🏪 Welcome to your store! Customers are on the way — listen for their orders at the counter.", "success")
end

function PlotManager.release(player)
	for _, plot in ipairs(plots) do
		if plot.owner == player then
			plot.generation += 1
			plot.owner = nil
			plot.onCustomerSpawned = nil
			CustomerManager.clearAll(plot)
			StaffManager.dismissAll(plot)
			PlotBuilder.clearSections(plot)
			PlotBuilder.refreshUpgradePads(plot, nil)
			PlotBuilder.setOwnerSign(plot, "FOR SALE — Store #" .. plot.index)
			PlotBuilder.setClaimPadVisible(plot, true)
			break
		end
	end
	player:SetAttribute("PlotIndex", nil)
end

function PlotManager.init()
	local count = GameConfig.Plot.Count
	local pitch = GameConfig.Plot.Size + GameConfig.Plot.Spacing

	for index = 1, count do
		local x = (index - (count + 1) / 2) * pitch
		local origin = CFrame.new(x, 0, 0)
		local plot = PlotBuilder.build(origin, index)
		plots[index] = plot

		-- claim by stepping on the glowing pad
		local debounce = false
		plot.claimPad.Touched:Connect(function(hit)
			if debounce or plot.owner then
				return
			end
			local character = hit.Parent
			local player = character and Players:GetPlayerFromCharacter(character)
			if not player then
				return
			end
			debounce = true
			PlotManager.claim(plot, player)
			task.wait(1)
			debounce = false
		end)

		-- upgrade pad prompts (wired once; ownership checked on trigger)
		for _, upgrade in ipairs(GameConfig.Upgrades) do
			local entry = plot.padByUpgrade[upgrade.id]
			if entry then
				entry.prompt.Triggered:Connect(function(player)
					tryPurchase(plot, player, upgrade)
				end)
			end
		end
	end
end

return PlotManager
