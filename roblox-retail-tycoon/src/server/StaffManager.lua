--[[
	StaffManager
	------------
	Hireable NPC employees:
	  • Personal Shopper — walks to shelves, grabs what customers ordered,
	    and delivers it to them (your job at HEB, automated!)
	  • Cashier — stands behind the counter and rings up customers whose
	    orders are complete.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local GameConfig = require(ReplicatedStorage.Shared.GameConfig)
local Util = require(script.Parent.Util)
local CustomerManager = require(script.Parent.CustomerManager)

local StaffManager = {}

local UNIFORM = Color3.fromRGB(200, 30, 40) -- classic grocery-store red

local function customerIsValid(plot, customer, generation)
	return plot.generation == generation
		and customer.model
		and customer.model.Parent
		and table.find(plot.customers, customer) ~= nil
end

-- Find an order line a shopper can work on that no other shopper claimed.
local function findShopperTask(plot)
	for _, customer in ipairs(plot.customers) do
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

-- Walk to a position, detouring around the end of the counter whenever the
-- path would cross it (MoveTo walks in straight lines and would get stuck).
local function routeTo(plot, staff, targetPosition)
	local root = staff.model:FindFirstChild("HumanoidRootPart")
	if not root then
		return false
	end
	local COUNTER_Z = -8
	local localFrom = plot.origin:PointToObjectSpace(root.Position)
	local localTo = plot.origin:PointToObjectSpace(targetPosition)
	local crossesCounter = (localFrom.Z - COUNTER_Z) * (localTo.Z - COUNTER_Z) < 0
	if crossesCounter then
		local side = (localFrom.X + localTo.X) >= 0 and 1 or -1
		if not Util.walkTo(staff.model, plot.getCounterGap(side)) then
			return false
		end
	end
	return Util.walkTo(staff.model, targetPosition)
end

local function shopperLoop(plot, staff, generation)
	while plot.generation == generation and staff.model.Parent do
		local customer, line = findShopperTask(plot)
		if not customer then
			routeTo(plot, staff, plot.points.shopperIdle)
			task.wait(1)
			continue
		end

		line.claimedBy = staff
		local shelfPosition = plot.shelfPositions[line.itemId]
		local grabbed = shelfPosition and routeTo(plot, staff, shelfPosition)
		if grabbed then
			task.wait(1.2) -- grabbing the item off the shelf
		end

		if grabbed and customerIsValid(plot, customer, generation) and customer.state == "Waiting" then
			local target = customer.root.Position + Vector3.new(2, 0, 0)
			if routeTo(plot, staff, target) and customerIsValid(plot, customer, generation) then
				CustomerManager.deliver(plot, customer, line.itemId, line.need - line.got)
			end
		end
		line.claimedBy = nil
		task.wait(0.5)
	end
end

local function cashierLoop(plot, staff, generation)
	Util.walkTo(staff.model, plot.points.cashierIdle, 8)
	while plot.generation == generation and staff.model.Parent do
		local target
		for _, customer in ipairs(plot.customers) do
			if customer.state == "ReadyToPay" and not customer.cashierClaimed then
				target = customer
				break
			end
		end
		if target then
			target.cashierClaimed = true
			task.wait(1.5) -- ringing them up
			if customerIsValid(plot, target, generation) then
				CustomerManager.checkout(plot, target)
			end
		else
			task.wait(0.8)
		end
	end
end

function StaffManager.hire(plot, role)
	local displayName = role == "Shopper" and "🛒 Personal Shopper" or "💵 Cashier"
	local model, humanoid, root = Util.createNPC(displayName, UNIFORM)
	humanoid.WalkSpeed = 13
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
