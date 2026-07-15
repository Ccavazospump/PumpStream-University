--[[
	GameConfig
	----------
	Every tunable number in the game lives here: item prices, section
	unlocks, upgrade costs, customer behavior, etc.
	Balance the game by editing this file only — no code changes needed.
]]

local GameConfig = {}

-- Money the very first time a player ever joins
GameConfig.StartingCash = 100

GameConfig.Plot = {
	Count = 6, -- how many player plots to generate
	Size = 120, -- studs (square)
	Spacing = 20, -- gap between plots
}

GameConfig.Customers = {
	BaseSpawnInterval = 14, -- seconds between customers (before upgrades)
	MinSpawnInterval = 5, -- upgrades can never push it below this
	BaseMaxCustomers = 2, -- customers in the store at once (before upgrades)
	Patience = 120, -- seconds a customer waits before storming out
	WalkSpeed = 11,
	QuantityTwoChance = 0.3, -- chance an order line asks for 2 of an item
	TipChance = 0.35, -- chance of a tip on checkout
	TipRange = { 2, 12 }, -- min/max tip
}

-- How many items a player can carry before any upgrades
GameConfig.BaseCarryCapacity = 1

-- Every sellable item in the game.
-- price = what the customer pays you per unit.
GameConfig.Items = {
	-- Produce
	Apple = { name = "Apple", price = 6, color = Color3.fromRGB(196, 40, 28) },
	Banana = { name = "Banana", price = 5, color = Color3.fromRGB(245, 205, 48) },
	Carrot = { name = "Carrot", price = 4, color = Color3.fromRGB(226, 125, 40) },
	Tomato = { name = "Tomato", price = 7, color = Color3.fromRGB(208, 60, 42) },
	-- Dairy
	Milk = { name = "Milk", price = 12, color = Color3.fromRGB(240, 240, 240) },
	Cheese = { name = "Cheese", price = 15, color = Color3.fromRGB(250, 200, 80) },
	Eggs = { name = "Eggs", price = 10, color = Color3.fromRGB(235, 225, 200) },
	Yogurt = { name = "Yogurt", price = 13, color = Color3.fromRGB(200, 220, 250) },
	-- Bakery
	Bread = { name = "Bread", price = 18, color = Color3.fromRGB(180, 130, 70) },
	Donut = { name = "Donut", price = 14, color = Color3.fromRGB(230, 160, 190) },
	Croissant = { name = "Croissant", price = 16, color = Color3.fromRGB(220, 170, 90) },
	Cake = { name = "Cake", price = 30, color = Color3.fromRGB(245, 190, 210) },
	-- Cosmetics
	Soap = { name = "Soap", price = 20, color = Color3.fromRGB(170, 230, 180) },
	Shampoo = { name = "Shampoo", price = 25, color = Color3.fromRGB(90, 180, 220) },
	Lipstick = { name = "Lipstick", price = 35, color = Color3.fromRGB(220, 60, 90) },
	Perfume = { name = "Perfume", price = 45, color = Color3.fromRGB(200, 120, 220) },
}

-- Store departments. "offset" is the section's position inside the plot
-- (plot center is 0,0,0 and the storefront faces +Z).
-- Produce is free and always unlocked; the rest are bought as upgrades
-- whose upgrade id must match the section id.
GameConfig.Sections = {
	{
		id = "Produce",
		name = "Produce",
		color = Color3.fromRGB(88, 168, 84),
		items = { "Apple", "Banana", "Carrot", "Tomato" },
		offset = Vector3.new(28, 0, -20),
	},
	{
		id = "Dairy",
		name = "Dairy",
		color = Color3.fromRGB(120, 170, 240),
		items = { "Milk", "Cheese", "Eggs", "Yogurt" },
		offset = Vector3.new(-28, 0, -20),
	},
	{
		id = "Bakery",
		name = "Bakery",
		color = Color3.fromRGB(214, 154, 90),
		items = { "Bread", "Donut", "Croissant", "Cake" },
		offset = Vector3.new(28, 0, -42),
	},
	{
		id = "Cosmetics",
		name = "Cosmetics",
		color = Color3.fromRGB(190, 110, 210),
		items = { "Soap", "Shampoo", "Lipstick", "Perfume" },
		offset = Vector3.new(-28, 0, -42),
	},
}

--[[
	Upgrades appear as buy-pads inside the store.
	kind:
	  "section"       -> unlocks the department whose Sections id == this id
	  "carry"         -> raises the owner's carry capacity to `value`
	  "maxCustomers"  -> allows `value` more customers in the store at once
	  "spawnRate"     -> customers arrive `value` seconds sooner
	  "payMultiplier" -> adds `value` to the checkout payout multiplier (1.0 base)
	  "staff"         -> hires an NPC employee (`role` = "Shopper" or "Cashier")
	requires: id of another upgrade that must be owned first (optional)
]]
GameConfig.Upgrades = {
	{ id = "Basket", name = "Shopping Basket", desc = "Carry 3 items", cost = 250, kind = "carry", value = 3 },
	{ id = "Marketing1", name = "Marketing I", desc = "+2 customers", cost = 400, kind = "maxCustomers", value = 2 },
	{ id = "Dairy", name = "Dairy Section", desc = "Milk, cheese & more", cost = 500, kind = "section" },
	{ id = "Speedy1", name = "Fast Service I", desc = "Customers arrive sooner", cost = 700, kind = "spawnRate", value = 3 },
	{ id = "TipJar", name = "Tip Jar", desc = "+25% checkout pay", cost = 900, kind = "payMultiplier", value = 0.25 },
	{ id = "Bakery", name = "Bakery Section", desc = "Fresh bread & cake", cost = 1500, kind = "section", requires = "Dairy" },
	{ id = "Marketing2", name = "Marketing II", desc = "+2 customers", cost = 1600, kind = "maxCustomers", value = 2, requires = "Marketing1" },
	{ id = "Cart", name = "Shopping Cart", desc = "Carry 6 items", cost = 1800, kind = "carry", value = 6, requires = "Basket" },
	{ id = "Speedy2", name = "Fast Service II", desc = "Customers arrive sooner", cost = 2200, kind = "spawnRate", value = 3, requires = "Speedy1" },
	{ id = "Shopper", name = "Hire Personal Shopper", desc = "Fetches items for you", cost = 2500, kind = "staff", role = "Shopper" },
	{ id = "Cashier", name = "Hire Cashier", desc = "Checks customers out", cost = 3500, kind = "staff", role = "Cashier" },
	{ id = "Cosmetics", name = "Cosmetics Section", desc = "High-value goods", cost = 4000, kind = "section", requires = "Bakery" },
}

function GameConfig.getSection(id)
	for _, section in ipairs(GameConfig.Sections) do
		if section.id == id then
			return section
		end
	end
	return nil
end

function GameConfig.getUpgrade(id)
	for _, upgrade in ipairs(GameConfig.Upgrades) do
		if upgrade.id == id then
			return upgrade
		end
	end
	return nil
end

return GameConfig
