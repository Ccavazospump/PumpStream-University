--[[
	CustomerManager
	---------------
	Spawns NPC customers for a claimed plot, walks them to the counter,
	generates their order, and handles delivery + checkout.

	Customer states: "Arriving" -> "Waiting" -> "ReadyToPay" -> "Paid"/"Left"
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local GameConfig = require(ReplicatedStorage.Shared.GameConfig)
local Util = require(script.Parent.Util)
local Economy = require(script.Parent.Economy)

local CustomerManager = {}

local NAMES = {
	"Alex", "Sam", "Riley", "Jordan", "Casey", "Morgan", "Taylor",
	"Avery", "Quinn", "Dana", "Reese", "Skyler", "Jamie", "Cameron",
}

local SHIRT_COLORS = {
	Color3.fromRGB(90, 140, 220), Color3.fromRGB(220, 150, 60),
	Color3.fromRGB(120, 190, 120), Color3.fromRGB(200, 110, 170),
	Color3.fromRGB(150, 150, 160), Color3.fromRGB(230, 210, 90),
}

local function orderText(customer)
	local lines = { "🛒 Order:" }
	for _, line in ipairs(customer.order) do
		local item = GameConfig.Items[line.itemId]
		if line.got >= line.need then
			table.insert(lines, string.format("%s ✅", item.name))
		else
			table.insert(lines, string.format("%s  %d/%d", item.name, line.got, line.need))
		end
	end
	return table.concat(lines, "\n")
end

local function isOrderComplete(customer)
	for _, line in ipairs(customer.order) do
		if line.got < line.need then
			return false
		end
	end
	return true
end

-- Build a random order using only items from unlocked departments.
local function generateOrder(plot)
	local pool = {}
	for _, sectionId in ipairs(plot.unlockedSections) do
		local section = GameConfig.getSection(sectionId)
		if section then
			for _, itemId in ipairs(section.items) do
				table.insert(pool, itemId)
			end
		end
	end

	-- shuffle the pool
	for i = #pool, 2, -1 do
		local j = math.random(i)
		pool[i], pool[j] = pool[j], pool[i]
	end

	-- more departments unlocked -> bigger possible orders
	local orderSize = math.random(1, math.min(GameConfig.Customers.MaxOrderLines, 1 + #plot.unlockedSections, #pool))
	local order = {}
	for i = 1, orderSize do
		local need = (math.random() < GameConfig.Customers.QuantityTwoChance) and 2 or 1
		table.insert(order, { itemId = pool[i], need = need, got = 0 })
	end
	return order
end

-- Try to hand `count` of an item to a customer. Returns how many they took.
function CustomerManager.deliver(plot, customer, itemId, count)
	if customer.state ~= "Waiting" or count <= 0 then
		return 0
	end
	local accepted = 0
	for _, line in ipairs(customer.order) do
		if line.itemId == itemId then
			local take = math.min(count, line.need - line.got)
			line.got += take
			accepted += take
			break
		end
	end
	if accepted > 0 then
		if isOrderComplete(customer) then
			customer.state = "ReadyToPay"
			customer.givePrompt.Enabled = false
			customer.checkoutPrompt.Enabled = true
			customer.billboard.Text = "💰 Ready to check out!"
			customer.billboard.TextColor3 = Color3.fromRGB(140, 255, 160)
		else
			customer.billboard.Text = orderText(customer)
		end
	end
	return accepted
end

-- Ring them up: pays the plot owner and sends the customer home happy.
function CustomerManager.checkout(plot, customer)
	if customer.state ~= "ReadyToPay" or not plot.owner then
		return false
	end
	customer.state = "Paid"
	customer.checkoutPrompt.Enabled = false

	local total = 0
	for _, line in ipairs(customer.order) do
		total += GameConfig.Items[line.itemId].price * line.need
	end
	total = math.floor(total * plot.payMultiplier + 0.5)

	local tip = 0
	if math.random() < GameConfig.Customers.TipChance then
		tip = math.random(GameConfig.Customers.TipRange[1], GameConfig.Customers.TipRange[2])
	end

	Economy.addCash(plot.owner, total + tip)
	if tip > 0 then
		Util.notify(plot.owner, string.format("💵 +$%d sale (+$%d tip) from %s!", total, tip, customer.model.Name), "success")
	else
		Util.notify(plot.owner, string.format("💵 +$%d sale from %s!", total, customer.model.Name), "success")
	end

	customer.billboard.Text = "😄 Thanks!"
	return true
end

local function removeCustomer(plot, customer)
	local index = table.find(plot.customers, customer)
	if index then
		table.remove(plot.customers, index)
	end
	if customer.model then
		customer.model:Destroy()
	end
end

function CustomerManager.spawnCustomer(plot)
	local generation = plot.generation
	local name = NAMES[math.random(#NAMES)]
	local shirt = SHIRT_COLORS[math.random(#SHIRT_COLORS)]

	local model, humanoid, root = Util.createNPC(name, shirt)
	humanoid.WalkSpeed = GameConfig.Customers.WalkSpeed
	root.CFrame = CFrame.new(plot.points.customerSpawn)
	model.Parent = workspace

	local customer = {
		model = model,
		humanoid = humanoid,
		root = root,
		order = generateOrder(plot),
		state = "Arriving",
		paidOut = false,
	}

	-- billboard that shows the order
	customer.billboard = Util.billboard(root, "...", {
		size = UDim2.fromOffset(150, 90),
		offsetY = 4.5,
		maxDistance = 70,
	})

	-- prompt the owner uses to hand over carried items
	local givePrompt = Instance.new("ProximityPrompt")
	givePrompt.ActionText = "Hand Over Items"
	givePrompt.ObjectText = name
	givePrompt.HoldDuration = 0.3
	givePrompt.MaxActivationDistance = 8
	givePrompt.RequiresLineOfSight = false
	givePrompt.Enabled = false
	givePrompt.Parent = root
	customer.givePrompt = givePrompt

	-- prompt to ring them up once the order is complete
	local checkoutPrompt = Instance.new("ProximityPrompt")
	checkoutPrompt.ActionText = "Checkout"
	checkoutPrompt.ObjectText = name
	checkoutPrompt.HoldDuration = 0.3
	checkoutPrompt.MaxActivationDistance = 8
	checkoutPrompt.KeyboardKeyCode = Enum.KeyCode.F
	checkoutPrompt.RequiresLineOfSight = false
	checkoutPrompt.Enabled = false
	checkoutPrompt.Parent = root
	customer.checkoutPrompt = checkoutPrompt

	-- take the lowest queue slot no other customer is standing in
	local usedSlots = {}
	for _, other in ipairs(plot.customers) do
		if other.slot then
			usedSlots[other.slot] = true
		end
	end
	local slotIndex = 1
	while usedSlots[slotIndex] do
		slotIndex += 1
	end
	customer.slot = slotIndex

	table.insert(plot.customers, customer)

	-- let PlotManager wire the prompts to the item/checkout systems
	if plot.onCustomerSpawned then
		plot.onCustomerSpawned(customer)
	end

	-- lifecycle coroutine
	task.spawn(function()
		local arrived = Util.walkPath(model, {
			plot.points.doorOutside,
			plot.points.doorInside,
			plot.getQueueSlot(slotIndex),
		})
		if not arrived or plot.generation ~= generation then
			removeCustomer(plot, customer)
			return
		end

		customer.state = "Waiting"
		customer.givePrompt.Enabled = true
		customer.billboard.Text = orderText(customer)

		local deadline = os.clock() + GameConfig.Customers.Patience
		while plot.generation == generation and customer.model.Parent do
			if customer.state == "Paid" then
				break
			end
			if os.clock() > deadline then
				-- ran out of patience
				customer.state = "Left"
				customer.givePrompt.Enabled = false
				customer.checkoutPrompt.Enabled = false
				customer.billboard.Text = "😠 Too slow!"
				customer.billboard.TextColor3 = Color3.fromRGB(255, 120, 110)
				if plot.owner then
					Util.notify(plot.owner, "😠 " .. name .. " left without buying anything!", "error")
				end
				break
			end
			task.wait(0.25)
		end

		-- walk out and despawn
		if plot.generation == generation and customer.model.Parent then
			task.wait(0.8)
			Util.walkPath(model, {
				plot.points.doorInside,
				plot.points.doorOutside,
				plot.points.customerSpawn,
			})
		end
		removeCustomer(plot, customer)
	end)

	return customer
end

-- Keep spawning customers while the plot stays claimed.
function CustomerManager.startLoop(plot)
	local generation = plot.generation
	task.spawn(function()
		task.wait(3) -- brief pause after claiming before the first customer
		while plot.generation == generation and plot.owner do
			if #plot.customers < plot.maxCustomers then
				CustomerManager.spawnCustomer(plot)
			end
			-- a little randomness so arrivals don't feel robotic
			task.wait(plot.spawnInterval * (0.75 + math.random() * 0.5))
		end
	end)
end

-- Despawn everyone (plot released / owner left).
function CustomerManager.clearAll(plot)
	for i = #plot.customers, 1, -1 do
		local customer = plot.customers[i]
		if customer.model then
			customer.model:Destroy()
		end
	end
	table.clear(plot.customers)
end

return CustomerManager
