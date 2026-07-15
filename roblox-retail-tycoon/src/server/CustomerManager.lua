--[[
	CustomerManager
	---------------
	Two kinds of customers, just like a real grocery store:

	WALK-INS (self-service):
	  walk in -> browse the aisles grabbing their own groceries (you can
	  see items stack up in their arms) -> queue at the register ->
	  YOU (or your Cashier) check them out at the register -> they pay.
	  States: "Arriving" -> "Shopping" -> "AtRegister" -> "Paid"/"Left"

	CURBSIDE (online orders, unlocked by the Online Orders upgrade):
	  an order pops up with an alert -> a customer parks at a curbside
	  spot outside with their order shown overhead -> you (or a Personal
	  Shopper) gather the items and hand them over -> premium pay.
	  States: "Arriving" -> "Waiting" -> "Paid"/"Left"
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local GameConfig = require(ReplicatedStorage.Shared.GameConfig)
local Util = require(script.Parent.Util)
local Economy = require(script.Parent.Economy)
local ItemVisuals = require(script.Parent.ItemVisuals)

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

local THANKS_PHRASES = {
	"Thank you! 😄",
	"Have a great day!",
	"See ya next time!",
	"Love this store! ⭐",
	"Quick and easy, thanks!",
}

local CHATTER_PHRASES = {
	"Hmm, which one...",
	"Ooh, that looks good!",
	"On sale? Nice.",
	"Almost done...",
	"My kids love these.",
}

-- ============================ helpers ================================

local function orderText(customer, title)
	local lines = { title or "🛒 Shopping list:" }
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

-- Random order using only items from unlocked departments.
local function generateOrder(plot, minLines, maxLines)
	local pool = {}
	for _, sectionId in ipairs(plot.unlockedSections) do
		local section = GameConfig.getSection(sectionId)
		if section then
			for _, itemId in ipairs(section.items) do
				table.insert(pool, itemId)
			end
		end
	end
	for i = #pool, 2, -1 do
		local j = math.random(i)
		pool[i], pool[j] = pool[j], pool[i]
	end

	local size = math.random(math.min(minLines, #pool), math.min(maxLines, #pool))
	local order = {}
	for i = 1, size do
		local need = (math.random() < GameConfig.Customers.QuantityTwoChance) and 2 or 1
		table.insert(order, { itemId = pool[i], need = need, got = 0 })
	end
	return order
end

-- A shopping cart welded in front of the customer (they "push" it).
-- All parts are non-colliding and massless so it never fights physics.
local function giveCart(customer)
	local root = customer.root
	if not root or not root.Parent then
		return
	end
	local cart = Instance.new("Model")
	cart.Name = "NPCCart"

	local function cartPart(size, offset, color, shape)
		local part = Instance.new("Part")
		if shape then
			part.Shape = shape
		end
		part.Size = size
		part.Color = color
		part.Material = Enum.Material.Metal
		part.CanCollide = false
		part.CanQuery = false
		part.Massless = true
		part.TopSurface = Enum.SurfaceType.Smooth
		part.BottomSurface = Enum.SurfaceType.Smooth
		part.CFrame = root.CFrame * offset
		local weld = Instance.new("WeldConstraint")
		weld.Part0 = root
		weld.Part1 = part
		weld.Parent = part
		part.Parent = cart
		return part
	end

	local frame = Color3.fromRGB(160, 164, 172)
	local CART_Z = -3.1 -- basket center, in front of the customer
	-- basket: floor + 4 low walls (open top so groceries show)
	cartPart(Vector3.new(2.4, 0.15, 3.0), CFrame.new(0, -1.5, CART_Z), frame)
	cartPart(Vector3.new(0.15, 1.1, 3.0), CFrame.new(-1.2, -0.95, CART_Z), frame)
	cartPart(Vector3.new(0.15, 1.1, 3.0), CFrame.new(1.2, -0.95, CART_Z), frame)
	cartPart(Vector3.new(2.4, 1.1, 0.15), CFrame.new(0, -0.95, CART_Z - 1.5), frame)
	cartPart(Vector3.new(2.4, 1.1, 0.15), CFrame.new(0, -0.95, CART_Z + 1.5), frame)
	-- handle bar near the customer
	cartPart(Vector3.new(2.4, 0.2, 0.2), CFrame.new(0, -0.35, CART_Z + 1.9), Color3.fromRGB(200, 60, 60))
	-- four little wheels
	for _, corner in ipairs({ { -1, -1 }, { 1, -1 }, { -1, 1 }, { 1, 1 } }) do
		cartPart(
			Vector3.new(0.35, 0.5, 0.5),
			CFrame.new(corner[1] * 1.0, -2.45, CART_Z + corner[2] * 1.3) * CFrame.Angles(0, 0, math.rad(90)),
			Color3.fromRGB(45, 45, 50),
			Enum.PartType.Cylinder
		)
	end

	cart.Parent = customer.model
	customer.cart = cart
end

-- Product model added to the customer's cart (or held overhead if they
-- have no cart, e.g. curbside pickups receiving their bags).
local function addCarryVisual(customer, itemId)
	local root = customer.root
	if not root or not root.Parent then
		return
	end
	local count = customer.carriedCount or 0
	customer.carriedCount = count + 1

	local model = ItemVisuals.buildModel(itemId, { anchored = false, scale = 0.6 })
	model.Name = "NPCItem"
	if customer.cart then
		-- 2 columns x 3 rows per layer inside the basket
		local col = (count % 2 == 0) and -0.55 or 0.55
		local row = (math.floor(count / 2) % 3 - 1) * 0.85
		local layer = math.floor(count / 6) * 0.75
		model:PivotTo(root.CFrame * CFrame.new(col, -1.05 + layer, -3.1 + row))
		local weld = Instance.new("WeldConstraint")
		weld.Part0 = root
		weld.Part1 = model.PrimaryPart
		weld.Parent = model.PrimaryPart
		model.Parent = customer.cart
	else
		model:PivotTo(root.CFrame * CFrame.new(0, 2.6 + customer.carriedCount * 1.0, 0))
		local weld = Instance.new("WeldConstraint")
		weld.Part0 = root
		weld.Part1 = model.PrimaryPart
		weld.Parent = model.PrimaryPart
		model.Parent = customer.model
	end
end

-- Pay the plot owner for a completed order.
local function payOwner(plot, customer, extraMultiplier, fee, reason)
	if not plot.owner then
		return 0
	end
	local total = 0
	for _, line in ipairs(customer.order) do
		total += GameConfig.Items[line.itemId].price * line.need
	end
	total = math.floor(total * plot.payMultiplier * (extraMultiplier or 1) + 0.5) + (fee or 0)

	local tip = 0
	if math.random() < GameConfig.Customers.TipChance then
		tip = math.random(GameConfig.Customers.TipRange[1], GameConfig.Customers.TipRange[2])
	end

	Economy.addCash(plot.owner, total + tip)
	Util.sound(plot.owner, "money")
	if tip > 0 then
		Util.notify(plot.owner, string.format("💵 +$%d %s (+$%d tip) — %s", total, reason, tip, customer.model.Name), "success")
	else
		Util.notify(plot.owner, string.format("💵 +$%d %s — %s", total, reason, customer.model.Name), "success")
	end
	return total + tip
end

local function removeFrom(list, customer)
	local index = table.find(list, customer)
	if index then
		table.remove(list, index)
	end
	if customer.model then
		customer.model:Destroy()
	end
end

local function leaveAngry(plot, customer, generation)
	customer.state = "Left"
	customer.billboard.Text = "😠 Too slow!"
	customer.billboard.TextColor3 = Color3.fromRGB(255, 120, 110)
	if customer.givePrompt then
		customer.givePrompt.Enabled = false
	end
	if plot.owner then
		Util.sound(plot.owner, "angry")
		Util.notify(plot.owner, "😠 " .. customer.model.Name .. " left without paying!", "error")
	end
end

local function makeCustomer(plot, name)
	local model, humanoid, root = Util.createNPC(name, SHIRT_COLORS[math.random(#SHIRT_COLORS)])
	humanoid.WalkSpeed = GameConfig.Customers.WalkSpeed * (0.85 + math.random() * 0.3)
	local customer = {
		model = model,
		humanoid = humanoid,
		root = root,
		state = "Arriving",
		carriedCount = 0,
	}
	customer.billboard = Util.billboard(root, "...", {
		size = UDim2.fromOffset(150, 100),
		offsetY = 4.5,
		maxDistance = 80,
	})
	return customer
end

-- ================ register checkout (conveyor + scanning) ================

-- Glide an anchored model from where it is to a target pivot.
local function slideModel(model, targetCF, duration)
	local start = model:GetPivot()
	local steps = math.max(4, math.floor(duration * 30))
	for step = 1, steps do
		if not model.Parent then
			return
		end
		model:PivotTo(start:Lerp(targetCF, step / steps))
		task.wait(duration / steps)
	end
end

local function setRegisterDisplay(plot, text)
	if plot.registerDisplay then
		plot.registerDisplay.Text = text
	end
end

-- Move the front customer's groceries out of their cart onto the belt.
local function loadBelt(plot, customer)
	plot.beltCustomer = customer

	-- the cart (with its groceries) gets "returned"
	if customer.cart then
		customer.cart:Destroy()
		customer.cart = nil
	end
	for _, child in ipairs(customer.model:GetChildren()) do
		if child.Name == "NPCItem" then
			child:Destroy()
		end
	end

	-- then they step up to the register to face you
	task.spawn(function()
		Util.walkTo(customer.model, plot.points.payPoint, 8)
	end)

	customer.beltItems = {}
	customer.subtotal = 0
	local count = 0
	for _, line in ipairs(customer.order) do
		for _ = 1, line.need do
			count += 1
			local model = ItemVisuals.buildModel(line.itemId, { anchored = true, scale = 0.8 })
			model.Name = "BeltItem"
			model:PivotTo(plot.getBeltSlot(count))
			model.Parent = plot.model
			table.insert(customer.beltItems, { itemId = line.itemId, model = model })
		end
	end
	customer.billboard.Text = "🛒 Unloading the belt..."
	if plot.registerPrompt then
		plot.registerPrompt.ActionText = "Scan Item"
	end
	setRegisterDisplay(plot, string.format("%d ITEMS\n$0", count))
end

local function clearBelt(plot)
	local customer = plot.beltCustomer
	if customer and customer.beltItems then
		for _, entry in ipairs(customer.beltItems) do
			if entry.model then
				entry.model:Destroy()
			end
		end
		customer.beltItems = nil
	end
	plot.beltCustomer = nil
	if plot.registerPrompt then
		plot.registerPrompt.ActionText = "Scan Item"
	end
	setRegisterDisplay(plot, "REGISTER\nREADY")
end

-- The cash drawer pops open, then slides shut again.
local function popDrawer(plot)
	local drawerInfo = plot.registerDrawer
	if not drawerInfo then
		return
	end
	task.spawn(function()
		local open = CFrame.new(0, 0, -1.3)
		for step = 1, 6 do
			local alpha = step / 6
			drawerInfo.drawer.CFrame = drawerInfo.drawerClosed:Lerp(drawerInfo.drawerClosed * open, alpha)
			drawerInfo.cash.CFrame = drawerInfo.cashClosed:Lerp(drawerInfo.cashClosed * open, alpha)
			task.wait(0.02)
		end
		task.wait(0.9)
		for step = 1, 6 do
			local alpha = 1 - step / 6
			drawerInfo.drawer.CFrame = drawerInfo.drawerClosed:Lerp(drawerInfo.drawerClosed * open, alpha)
			drawerInfo.cash.CFrame = drawerInfo.cashClosed:Lerp(drawerInfo.cashClosed * open, alpha)
			task.wait(0.02)
		end
	end)
end

-- Final beat of the checkout: take the money, drawer pops, thanks + hop.
local function takePayment(plot, customer)
	customer.paid = true
	customer.state = "Paid"
	popDrawer(plot)
	payOwner(plot, customer, 1, 0, "sale")
	setRegisterDisplay(plot, string.format("$%d\nPAID ✓", customer.subtotal))
	customer.billboard.Text = THANKS_PHRASES[math.random(#THANKS_PHRASES)]
	customer.billboard.TextColor3 = Color3.fromRGB(140, 255, 160)
	if customer.humanoid then
		customer.humanoid.Jump = true -- a happy hop
	end
	if plot.registerPrompt then
		plot.registerPrompt.ActionText = "Scan Item"
	end
	task.delay(1.2, function()
		if plot.beltCustomer == customer then
			clearBelt(plot)
		end
	end)
end

-- Scan ONE item off the belt. Tap after tap until the order is rung up —
-- called by the player's register prompt, or by a Cashier (byPlayer = nil).
function CustomerManager.scanAtRegister(plot, byPlayer)
	if byPlayer and plot.owner ~= byPlayer then
		Util.notify(byPlayer, "This isn't your register!", "error")
		return false
	end
	local customer = plot.beltCustomer
	if not customer or customer.paid then
		if byPlayer then
			Util.notify(byPlayer, "No groceries on the belt.", "info")
		end
		return false
	end

	-- everything scanned? this tap takes the payment instead
	if customer.readyToPay then
		takePayment(plot, customer)
		return true
	end

	if not customer.beltItems then
		return false
	end
	local entry = table.remove(customer.beltItems, 1)
	if not entry then
		return false
	end

	customer.subtotal += GameConfig.Items[entry.itemId].price
	Util.sound(plot.owner, "scan")

	-- slide the scanned item into the laser, then poof
	task.spawn(function()
		slideModel(entry.model, plot.getBeltSlot(0), 0.18)
		if entry.model then
			entry.model:Destroy()
		end
	end)
	-- everyone else shuffles one slot forward
	for index, remaining in ipairs(customer.beltItems) do
		task.spawn(slideModel, remaining.model, plot.getBeltSlot(index), 0.25)
	end

	local left = #customer.beltItems
	if left > 0 then
		setRegisterDisplay(plot, string.format("$%d\n%d left", customer.subtotal, left))
		return true
	end

	-- last item scanned: show the total, customer gets their wallet out
	customer.readyToPay = true
	setRegisterDisplay(plot, string.format("TOTAL\n$%d", customer.subtotal))
	customer.billboard.Text = "💳 That's everything!"
	if plot.registerPrompt then
		plot.registerPrompt.ActionText = string.format("Take Payment ($%d)", customer.subtotal)
	end
	return true
end

-- Watches the register line: when the belt is free, the next customer in
-- line unloads their groceries onto it.
local function startBeltWatcher(plot, generation)
	task.spawn(function()
		while plot.generation == generation and plot.owner do
			local current = plot.beltCustomer
			if current then
				local gone = not current.model or not current.model.Parent or current.state == "Left"
				if gone then
					clearBelt(plot)
				end
			else
				local next_
				for _, customer in ipairs(plot.customers) do
					if customer.state == "AtRegister" and not customer.paid then
						if not next_ or (customer.slot or 99) < (next_.slot or 99) then
							next_ = customer
						end
					end
				end
				if next_ then
					loadBelt(plot, next_)
				end
			end
			task.wait(0.3)
		end
	end)
end

-- ====================== curbside item delivery =======================

-- Hand items to a curbside customer. Returns how many they accepted.
function CustomerManager.deliver(plot, customer, itemId, count)
	if not customer.curbside or customer.state ~= "Waiting" or count <= 0 then
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
			-- order complete: they pay on the spot (premium + pickup fee)
			customer.state = "Paid"
			customer.paid = true
			if customer.givePrompt then
				customer.givePrompt.Enabled = false
			end
			if plot.owner then
				Util.sound(plot.owner, "orderComplete")
			end
			payOwner(plot, customer, GameConfig.OnlineOrders.PayMultiplier, GameConfig.OnlineOrders.PickupFee, "curbside pickup")
			customer.billboard.Text = "📦 " .. THANKS_PHRASES[math.random(#THANKS_PHRASES)]
			customer.billboard.TextColor3 = Color3.fromRGB(140, 255, 160)
			if customer.humanoid then
				customer.humanoid.Jump = true
			end
		else
			customer.billboard.Text = orderText(customer, "📱 Curbside order:")
		end
	end
	return accepted
end

-- =========================== walk-ins ================================

function CustomerManager.spawnCustomer(plot)
	local generation = plot.generation
	local customer = makeCustomer(plot, NAMES[math.random(#NAMES)])
	customer.curbside = false
	customer.order = generateOrder(plot, 1, math.min(GameConfig.Customers.MaxOrderLines, 1 + #plot.unlockedSections))

	customer.root.CFrame = CFrame.new(plot.points.customerSpawn)
	customer.model.Parent = workspace
	giveCart(customer) -- walk-ins push a shopping cart
	table.insert(plot.customers, customer)

	if plot.onCustomerSpawned then
		plot.onCustomerSpawned(customer)
	end

	task.spawn(function()
		local model = customer.model
		local arrived = Util.walkPath(model, { plot.points.doorOutside, plot.points.doorInside })
		if not arrived or plot.generation ~= generation then
			removeFrom(plot.customers, customer)
			return
		end

		-- browse the aisles, grabbing their own groceries
		customer.state = "Shopping"
		customer.billboard.Text = orderText(customer)
		for _, line in ipairs(customer.order) do
			if plot.generation ~= generation or not model.Parent then
				break
			end
			local shelfPosition = plot.shelfPositions[line.itemId]
			if shelfPosition then
				Util.pathWalkTo(model, shelfPosition)
				-- a little browsing chatter brings the store to life
				if math.random() < 0.3 then
					customer.billboard.Text = "💬 " .. CHATTER_PHRASES[math.random(#CHATTER_PHRASES)]
				end
				task.wait(GameConfig.Customers.ShopSeconds[1] + math.random() * (GameConfig.Customers.ShopSeconds[2] - GameConfig.Customers.ShopSeconds[1]))
				if plot.generation ~= generation or not model.Parent then
					break
				end
				for _ = 1, line.need do
					addCarryVisual(customer, line.itemId)
				end
				line.got = line.need
				customer.billboard.Text = orderText(customer)
			end
		end

		if plot.generation ~= generation or not model.Parent then
			removeFrom(plot.customers, customer)
			return
		end

		-- queue at the register
		local used = {}
		for _, other in ipairs(plot.customers) do
			if other.slot then
				used[other.slot] = true
			end
		end
		local slot = 1
		while used[slot] and slot < 8 do
			slot += 1
		end
		customer.slot = slot

		Util.pathWalkTo(model, plot.getQueueSlot(slot))
		customer.state = "AtRegister"
		customer.billboard.Text = "💰 Ready to check out!"
		customer.billboard.TextColor3 = Color3.fromRGB(255, 220, 120)

		local deadline = os.clock() + GameConfig.Customers.RegisterPatience
		while plot.generation == generation and model.Parent do
			if customer.paid then
				break
			end
			if os.clock() > deadline then
				leaveAngry(plot, customer, generation)
				break
			end
			task.wait(0.25)
		end

		-- walk out
		if plot.generation == generation and model.Parent then
			task.wait(0.8)
			customer.slot = nil
			Util.pathWalkTo(model, plot.points.doorInside)
			Util.walkPath(model, { plot.points.doorOutside, plot.points.customerSpawn })
		end
		removeFrom(plot.customers, customer)
	end)
end

-- Keep spawning walk-ins while the plot stays claimed.
function CustomerManager.startLoop(plot)
	local generation = plot.generation
	startBeltWatcher(plot, generation)
	task.spawn(function()
		task.wait(3)
		while plot.generation == generation and plot.owner do
			if #plot.customers < plot.maxCustomers then
				CustomerManager.spawnCustomer(plot)
			end
			task.wait(plot.spawnInterval * (0.75 + math.random() * 0.5))
		end
	end)
end

-- =========================== curbside ================================

function CustomerManager.spawnCurbside(plot)
	local generation = plot.generation

	-- find a free curbside spot
	local usedSpots = {}
	for _, other in ipairs(plot.onlineCustomers) do
		if other.spot then
			usedSpots[other.spot] = true
		end
	end
	local spot
	for i = 1, plot.curbsideSpots do
		if not usedSpots[i] then
			spot = i
			break
		end
	end
	if not spot then
		return
	end

	local customer = makeCustomer(plot, NAMES[math.random(#NAMES)])
	customer.curbside = true
	customer.spot = spot
	customer.order = generateOrder(plot, GameConfig.OnlineOrders.MinItems, GameConfig.OnlineOrders.MaxItems)

	local spotPosition = plot.getCurbsideSpot(spot)
	customer.root.CFrame = CFrame.new(spotPosition + Vector3.new(0, 0, 30))
	customer.model.Parent = workspace

	-- prompt for handing over the gathered items
	local givePrompt = Instance.new("ProximityPrompt")
	givePrompt.ActionText = "Hand Over Order"
	givePrompt.ObjectText = customer.model.Name
	givePrompt.HoldDuration = 0.3
	givePrompt.MaxActivationDistance = 8
	givePrompt.RequiresLineOfSight = false
	givePrompt.Enabled = false
	givePrompt.Parent = customer.root
	customer.givePrompt = givePrompt

	table.insert(plot.onlineCustomers, customer)

	if plot.onCustomerSpawned then
		plot.onCustomerSpawned(customer)
	end

	-- the "ding" + alert that an order came in
	if plot.owner then
		Util.sound(plot.owner, "newOrder")
		Util.notify(plot.owner, string.format("📱 Online order: %d items — %s is heading to Curbside %d!", #customer.order, customer.model.Name, spot), "success")
	end

	task.spawn(function()
		local model = customer.model
		local arrived = Util.walkTo(model, spotPosition, 15)
		if not arrived or plot.generation ~= generation then
			removeFrom(plot.onlineCustomers, customer)
			return
		end

		customer.state = "Waiting"
		customer.givePrompt.Enabled = true
		customer.billboard.Text = orderText(customer, "📱 Curbside order:")

		local deadline = os.clock() + GameConfig.OnlineOrders.Patience
		while plot.generation == generation and model.Parent do
			if customer.paid then
				break
			end
			if os.clock() > deadline then
				leaveAngry(plot, customer, generation)
				break
			end
			task.wait(0.25)
		end

		if plot.generation == generation and model.Parent then
			task.wait(1)
			Util.walkTo(model, spotPosition + Vector3.new(0, 0, 30), 15)
		end
		removeFrom(plot.onlineCustomers, customer)
	end)
end

-- Online orders keep coming in while the plot has curbside spots.
function CustomerManager.startOnlineLoop(plot)
	local generation = plot.generation
	task.spawn(function()
		task.wait(8)
		while plot.generation == generation and plot.owner and plot.curbsideSpots > 0 do
			if #plot.onlineCustomers < plot.curbsideSpots then
				CustomerManager.spawnCurbside(plot)
			end
			task.wait(GameConfig.OnlineOrders.BaseInterval * (0.7 + math.random() * 0.6))
		end
	end)
end

-- ============================ cleanup ================================

function CustomerManager.clearAll(plot)
	clearBelt(plot)
	for i = #plot.customers, 1, -1 do
		if plot.customers[i].model then
			plot.customers[i].model:Destroy()
		end
	end
	table.clear(plot.customers)
	for i = #plot.onlineCustomers, 1, -1 do
		if plot.onlineCustomers[i].model then
			plot.onlineCustomers[i].model:Destroy()
		end
	end
	table.clear(plot.onlineCustomers)
end

return CustomerManager
