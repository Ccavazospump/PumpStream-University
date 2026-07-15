--[[
	StaffManager
	------------
	Hireable NPC employees:
	  • Cashier — stands at the register and rings up walk-in customers
	    waiting in line.
	  • Personal Shopper — works the curbside orders: walks the aisles
	    grabbing what online customers ordered and runs it out to them.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local GameConfig = require(ReplicatedStorage.Shared.GameConfig)
local Util = require(script.Parent.Util)
local CustomerManager = require(script.Parent.CustomerManager)

local StaffManager = {}

local UNIFORM = Color3.fromRGB(200, 30, 40) -- classic grocery-store red

local function customerIsValid(plot, list, customer, generation)
	return plot.generation == generation
		and customer.model
		and customer.model.Parent
		and table.find(list, customer) ~= nil
end

-- Find a curbside order line a shopper can work on that nobody claimed.
local function findShopperTask(plot)
	for _, customer in ipairs(plot.onlineCustomers) do
		if customer.state == "Waiting" then
			for _, line in ipairs(customer.order) do
				if line.got < line.need and not line.claimedBy then
					return customer, line
				end
			end
		end
	end
	return nil, nil
end

local function shopperLoop(plot, staff, generation)
	while plot.generation == generation and staff.model.Parent do
		local customer, line = findShopperTask(plot)
		if not customer then
			Util.pathWalkTo(staff.model, plot.points.shopperIdle)
			task.wait(1.2)
			continue
		end

		line.claimedBy = staff
		local shelfPosition = plot.shelfPositions[line.itemId]
		local grabbed = shelfPosition and Util.pathWalkTo(staff.model, shelfPosition)
		if grabbed then
			task.wait(1.2) -- grabbing the item off the shelf
		end

		if grabbed and customerIsValid(plot, plot.onlineCustomers, customer, generation) and customer.state == "Waiting" then
			local target = customer.root.Position + Vector3.new(2, 0, 0)
			if Util.pathWalkTo(staff.model, target) and customerIsValid(plot, plot.onlineCustomers, customer, generation) then
				CustomerManager.deliver(plot, customer, line.itemId, line.need - line.got)
			end
		end
		line.claimedBy = nil
		task.wait(0.5)
	end
end

local function cashierLoop(plot, staff, generation)
	Util.pathWalkTo(staff.model, plot.points.cashierIdle)
	while plot.generation == generation and staff.model.Parent do
		local anyWaiting = false
		for _, customer in ipairs(plot.customers) do
			if customer.state == "AtRegister" and not customer.paid then
				anyWaiting = true
				break
			end
		end
		if anyWaiting then
			task.wait(1.4) -- ringing them up
			if plot.generation == generation then
				CustomerManager.checkoutAtRegister(plot, nil)
			end
		else
			task.wait(0.8)
		end
	end
end

function StaffManager.hire(plot, role)
	local displayName = role == "Shopper" and "🛒 Personal Shopper" or "💵 Cashier"
	local model, humanoid, root = Util.createNPC(displayName, UNIFORM)
	humanoid.WalkSpeed = 14
	local idle = role == "Shopper" and plot.points.shopperIdle or plot.points.cashierIdle
	root.CFrame = CFrame.new(idle)
	model.Parent = workspace

	local staff = { model = model, role = role }
	table.insert(plot.staff, staff)

	local generation = plot.generation
	task.spawn(function()
		if role == "Shopper" then
			shopperLoop(plot, staff, generation)
		else
			cashierLoop(plot, staff, generation)
		end
	end)
	return staff
end

function StaffManager.dismissAll(plot)
	for _, staff in ipairs(plot.staff) do
		if staff.model then
			staff.model:Destroy()
		end
	end
	table.clear(plot.staff)
end

return StaffManager
