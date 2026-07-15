--[[
	GameConfig
	----------
	Every tunable number in the game lives here: item prices, department
	unlocks, upgrade costs, customer behavior, store expansion sizes.
	Balance the game by editing this file only — no code changes needed.
]]

local GameConfig = {}

-- Money the very first time a player ever joins
GameConfig.StartingCash = 100

GameConfig.Plot = {
	Count = 6, -- how many player plots to generate
	Size = 150, -- studs (square)
	Spacing = 20, -- gap between plots
}

-- Store shell sizes. Buying an "expand" upgrade moves the walls out.
-- halfWidth = interior wall distance from center; backZ = back wall.
-- The storefront (z = 5) and door never move, so paths stay stable.
GameConfig.Expansions = {
	{ halfWidth = 35, backZ = -45 }, -- level 1: starter store
	{ halfWidth = 35, backZ = -75 }, -- level 2: deeper (Frozen, Meat & Deli)
	{ halfWidth = 55, backZ = -75 }, -- level 3: wider (Cosmetics, Household)
}

GameConfig.Customers = {
	BaseSpawnInterval = 12, -- seconds between customers (before upgrades)
	MinSpawnInterval = 5, -- upgrades can never push it below this
	BaseMaxCustomers = 2, -- customers in the store at once (before upgrades)
	Patience = 150, -- seconds a customer waits before storming out
	WalkSpeed = 13,
	MaxOrderLines = 5, -- most distinct items in one order
	QuantityTwoChance = 0.3, -- chance an order line asks for 2 of an item
	TipChance = 0.35, -- chance of a tip on checkout
	TipRange = { 2, 12 }, -- min/max tip
}

-- How many items a player can carry before any upgrades
GameConfig.BaseCarryCapacity = 1

--[[
	Every sellable item.
	price = what the customer pays per unit.
	shape = which procedural model ItemVisuals builds (see ItemVisuals.lua).
	color/accent = the model's two colors.
]]
local function item(name, price, shape, color, accent)
	return { name = name, price = price, shape = shape, color = color, accent = accent }
end

GameConfig.Items = {
	-- Produce
	Apple = item("Apple", 6, "sphere", Color3.fromRGB(196, 40, 28), Color3.fromRGB(92, 64, 40)),
	Banana = item("Banana", 5, "crescent", Color3.fromRGB(245, 205, 48), Color3.fromRGB(120, 96, 40)),
	Carrot = item("Carrot", 4, "carrot", Color3.fromRGB(226, 125, 40), Color3.fromRGB(80, 150, 60)),
	Tomato = item("Tomato", 7, "sphere", Color3.fromRGB(208, 60, 42), Color3.fromRGB(80, 150, 60)),
	Watermelon = item("Watermelon", 12, "sphere", Color3.fromRGB(64, 140, 70), Color3.fromRGB(40, 95, 48)),
	Grapes = item("Grapes", 9, "cluster", Color3.fromRGB(130, 70, 160), Color3.fromRGB(80, 150, 60)),
	-- Dry Goods
	Pasta = item("Pasta", 8, "box", Color3.fromRGB(46, 90, 160), Color3.fromRGB(240, 205, 90)),
	Cereal = item("Cereal", 11, "box", Color3.fromRGB(230, 130, 40), Color3.fromRGB(245, 240, 230)),
	Rice = item("Rice", 9, "bag", Color3.fromRGB(240, 238, 230), Color3.fromRGB(190, 60, 50)),
	CannedSoup = item("Canned Soup", 7, "can", Color3.fromRGB(190, 50, 45), Color3.fromRGB(200, 202, 208)),
	PeanutButter = item("Peanut Butter", 12, "jar", Color3.fromRGB(150, 100, 50), Color3.fromRGB(180, 40, 40)),
	Chips = item("Chips", 6, "bag", Color3.fromRGB(240, 200, 50), Color3.fromRGB(200, 50, 50)),
	-- Dairy
	Milk = item("Milk", 12, "carton", Color3.fromRGB(240, 240, 240), Color3.fromRGB(70, 110, 200)),
	Cheese = item("Cheese", 15, "wedge", Color3.fromRGB(250, 200, 80), Color3.fromRGB(235, 170, 50)),
	Eggs = item("Eggs", 10, "tray", Color3.fromRGB(210, 200, 180), Color3.fromRGB(240, 235, 220)),
	Yogurt = item("Yogurt", 13, "jar", Color3.fromRGB(235, 180, 200), Color3.fromRGB(245, 245, 245)),
	Butter = item("Butter", 11, "block", Color3.fromRGB(245, 215, 110), Color3.fromRGB(230, 190, 80)),
	Cream = item("Cream", 9, "carton", Color3.fromRGB(245, 242, 235), Color3.fromRGB(190, 60, 50)),
	-- Bakery
	Bread = item("Bread", 18, "loaf", Color3.fromRGB(196, 148, 86), Color3.fromRGB(150, 105, 60)),
	Donut = item("Donut", 14, "cake", Color3.fromRGB(230, 160, 190), Color3.fromRGB(160, 110, 70)),
	Croissant = item("Croissant", 16, "crescent", Color3.fromRGB(220, 170, 90), Color3.fromRGB(180, 130, 70)),
	Cake = item("Cake", 30, "cake", Color3.fromRGB(245, 240, 235), Color3.fromRGB(235, 130, 170)),
	Bagel = item("Bagel", 12, "cylinder", Color3.fromRGB(190, 140, 80), Color3.fromRGB(150, 105, 60)),
	Muffin = item("Muffin", 15, "muffin", Color3.fromRGB(150, 100, 60), Color3.fromRGB(220, 200, 170)),
	-- Frozen
	IceCream = item("Ice Cream", 22, "tub", Color3.fromRGB(120, 200, 220), Color3.fromRGB(140, 95, 60)),
	FrozenPizza = item("Frozen Pizza", 26, "box", Color3.fromRGB(200, 60, 50), Color3.fromRGB(245, 210, 90)),
	FrozenFries = item("Frozen Fries", 18, "bag", Color3.fromRGB(200, 50, 45), Color3.fromRGB(245, 205, 90)),
	IcePops = item("Ice Pops", 14, "box", Color3.fromRGB(90, 190, 230), Color3.fromRGB(245, 245, 245)),
	FrozenVeggies = item("Frozen Veggies", 16, "bag", Color3.fromRGB(80, 160, 80), Color3.fromRGB(240, 240, 235)),
	FishSticks = item("Fish Sticks", 24, "box", Color3.fromRGB(50, 90, 160), Color3.fromRGB(235, 150, 60)),
	-- Meat & Deli
	Chicken = item("Chicken", 28, "tray", Color3.fromRGB(240, 240, 238), Color3.fromRGB(240, 215, 170)),
	Steak = item("Steak", 40, "tray", Color3.fromRGB(240, 240, 238), Color3.fromRGB(180, 55, 55)),
	Bacon = item("Bacon", 24, "tray", Color3.fromRGB(240, 240, 238), Color3.fromRGB(160, 60, 60)),
	Sausage = item("Sausage", 20, "cylinder", Color3.fromRGB(160, 80, 60), Color3.fromRGB(130, 60, 45)),
	Ham = item("Ham", 22, "loaf", Color3.fromRGB(230, 140, 150), Color3.fromRGB(200, 110, 120)),
	Turkey = item("Turkey", 30, "tray", Color3.fromRGB(240, 240, 238), Color3.fromRGB(200, 160, 120)),
	-- Cosmetics
	Soap = item("Soap", 20, "block", Color3.fromRGB(170, 230, 180), Color3.fromRGB(240, 245, 240)),
	Shampoo = item("Shampoo", 25, "bottle", Color3.fromRGB(90, 180, 220), Color3.fromRGB(245, 245, 245)),
	Lipstick = item("Lipstick", 35, "tube", Color3.fromRGB(220, 60, 90), Color3.fromRGB(40, 40, 45)),
	Perfume = item("Perfume", 45, "bottle", Color3.fromRGB(200, 120, 220), Color3.fromRGB(230, 190, 90)),
	Lotion = item("Lotion", 28, "bottle", Color3.fromRGB(245, 235, 220), Color3.fromRGB(235, 170, 190)),
	Toothpaste = item("Toothpaste", 18, "tube", Color3.fromRGB(245, 245, 245), Color3.fromRGB(70, 130, 210)),
	-- Household
	Detergent = item("Detergent", 26, "bottle", Color3.fromRGB(235, 140, 50), Color3.fromRGB(245, 245, 245)),
	PaperTowels = item("Paper Towels", 20, "cylinder", Color3.fromRGB(245, 245, 245), Color3.fromRGB(90, 140, 210)),
	Sponges = item("Sponges", 12, "block", Color3.fromRGB(240, 210, 80), Color3.fromRGB(110, 190, 120)),
	Bleach = item("Bleach", 22, "bottle", Color3.fromRGB(245, 245, 245), Color3.fromRGB(200, 60, 50)),
	TrashBags = item("Trash Bags", 16, "box", Color3.fromRGB(45, 45, 50), Color3.fromRGB(240, 240, 240)),
	AirFreshener = item("Air Freshener", 24, "can", Color3.fromRGB(190, 160, 220), Color3.fromRGB(245, 245, 245)),
}

--[[
	Departments. Each is an aisle zone: two rows of three shelves facing
	each other. offset = zone center inside the plot; rotated zones run
	along the side wings added by Expansion II.
	Produce is free; the rest are unlocked through the upgrade chain.
]]
GameConfig.Sections = {
	{
		id = "Produce",
		name = "Produce",
		color = Color3.fromRGB(88, 168, 84),
		items = { "Apple", "Banana", "Carrot", "Tomato", "Watermelon", "Grapes" },
		offset = Vector3.new(-18, 0, -18),
	},
	{
		id = "DryGoods",
		name = "Dry Goods",
		color = Color3.fromRGB(214, 154, 90),
		items = { "Pasta", "Cereal", "Rice", "CannedSoup", "PeanutButter", "Chips" },
		offset = Vector3.new(18, 0, -18),
	},
	{
		id = "Dairy",
		name = "Dairy",
		color = Color3.fromRGB(120, 170, 240),
		items = { "Milk", "Cheese", "Eggs", "Yogurt", "Butter", "Cream" },
		offset = Vector3.new(-18, 0, -38),
	},
	{
		id = "Bakery",
		name = "Bakery",
		color = Color3.fromRGB(235, 180, 120),
		items = { "Bread", "Donut", "Croissant", "Cake", "Bagel", "Muffin" },
		offset = Vector3.new(18, 0, -38),
	},
	{
		id = "Frozen",
		name = "Frozen",
		color = Color3.fromRGB(110, 200, 230),
		items = { "IceCream", "FrozenPizza", "FrozenFries", "IcePops", "FrozenVeggies", "FishSticks" },
		offset = Vector3.new(-18, 0, -58),
	},
	{
		id = "MeatDeli",
		name = "Meat & Deli",
		color = Color3.fromRGB(220, 110, 110),
		items = { "Chicken", "Steak", "Bacon", "Sausage", "Ham", "Turkey" },
		offset = Vector3.new(18, 0, -58),
	},
	{
		id = "Cosmetics",
		name = "Cosmetics",
		color = Color3.fromRGB(190, 110, 210),
		items = { "Soap", "Shampoo", "Lipstick", "Perfume", "Lotion", "Toothpaste" },
		offset = Vector3.new(-44, 0, -30),
		rotated = true,
	},
	{
		id = "Household",
		name = "Household",
		color = Color3.fromRGB(120, 190, 150),
		items = { "Detergent", "PaperTowels", "Sponges", "Bleach", "TrashBags", "AirFreshener" },
		offset = Vector3.new(44, 0, -30),
		rotated = true,
	},
}

--[[
	Upgrades — tycoon style: each upgrade's buy-pad only appears once the
	one before it (`requires`) is owned, so you unlock one at a time.

	Three chains run in parallel:
	  • Store chain (departments + expansions) — pads sit on the floor of
	    the area they unlock (padAt = {x, z}).
	  • Register chain (slot = "economy") — one pad spot near the door.
	  • Staff chain (slot = "staff") — a second pad spot near the door.

	kind:
	  "section"       -> unlocks the department whose Sections id == this id
	  "expand"        -> grows the store shell to Expansions[value]
	  "carry"         -> raises the owner's carry capacity to `value`
	  "maxCustomers"  -> allows `value` more customers at once
	  "spawnRate"     -> customers arrive `value` seconds sooner
	  "payMultiplier" -> adds `value` to the checkout payout multiplier
	  "staff"         -> hires an NPC employee (`role`)
]]
GameConfig.Upgrades = {
	-- store chain
	{ id = "DryGoods", name = "Dry Goods Aisle", desc = "Pasta, cereal, canned goods", cost = 400, kind = "section", padAt = { 18, -18 } },
	{ id = "Dairy", name = "Dairy Aisle", desc = "Milk, cheese & more", cost = 1000, kind = "section", requires = "DryGoods", padAt = { -18, -38 } },
	{ id = "Bakery", name = "Bakery", desc = "Fresh bread & cake", cost = 1800, kind = "section", requires = "Dairy", padAt = { 18, -38 } },
	{ id = "Expansion1", name = "Store Expansion I", desc = "Push the back wall out!", cost = 2600, kind = "expand", value = 2, requires = "Bakery", padAt = { 0, -42 } },
	{ id = "Frozen", name = "Frozen Aisle", desc = "Ice cream & frozen meals", cost = 3400, kind = "section", requires = "Expansion1", padAt = { -18, -58 } },
	{ id = "MeatDeli", name = "Meat & Deli", desc = "The good stuff", cost = 4600, kind = "section", requires = "Frozen", padAt = { 18, -58 } },
	{ id = "Expansion2", name = "Store Expansion II", desc = "Widen the whole store!", cost = 6500, kind = "expand", value = 3, requires = "MeatDeli", padAt = { 0, -48 } },
	{ id = "Cosmetics", name = "Cosmetics Wing", desc = "High-value goods", cost = 7500, kind = "section", requires = "Expansion2", padAt = { -44, -30 } },
	{ id = "Household", name = "Household Wing", desc = "Cleaning & essentials", cost = 9500, kind = "section", requires = "Cosmetics", padAt = { 44, -30 } },
	-- register chain
	{ id = "Basket", name = "Shopping Basket", desc = "Carry 3 items", cost = 250, kind = "carry", value = 3, slot = "economy" },
	{ id = "Marketing1", name = "Marketing I", desc = "+2 customers", cost = 500, kind = "maxCustomers", value = 2, requires = "Basket", slot = "economy" },
	{ id = "Speedy1", name = "Fast Service I", desc = "Customers arrive sooner", cost = 800, kind = "spawnRate", value = 3, requires = "Marketing1", slot = "economy" },
	{ id = "TipJar", name = "Tip Jar", desc = "+25% checkout pay", cost = 1200, kind = "payMultiplier", value = 0.25, requires = "Speedy1", slot = "economy" },
	{ id = "Cart", name = "Shopping Cart", desc = "Carry 6 items", cost = 2200, kind = "carry", value = 6, requires = "TipJar", slot = "economy" },
	{ id = "Marketing2", name = "Marketing II", desc = "+2 customers", cost = 2800, kind = "maxCustomers", value = 2, requires = "Cart", slot = "economy" },
	{ id = "Speedy2", name = "Fast Service II", desc = "Customers arrive sooner", cost = 3600, kind = "spawnRate", value = 3, requires = "Marketing2", slot = "economy" },
	{ id = "ProBag", name = "Pro Shopper Bag", desc = "Carry 9 items", cost = 5200, kind = "carry", value = 9, requires = "Speedy2", slot = "economy" },
	{ id = "GoldTipJar", name = "Golden Tip Jar", desc = "+35% checkout pay", cost = 7000, kind = "payMultiplier", value = 0.35, requires = "ProBag", slot = "economy" },
	-- staff chain
	{ id = "Shopper", name = "Hire Personal Shopper", desc = "Fetches items for you", cost = 2800, kind = "staff", role = "Shopper", slot = "staff" },
	{ id = "Cashier", name = "Hire Cashier", desc = "Checks customers out", cost = 4000, kind = "staff", role = "Cashier", requires = "Shopper", slot = "staff" },
	{ id = "Shopper2", name = "2nd Personal Shopper", desc = "Double the fetching", cost = 6800, kind = "staff", role = "Shopper", requires = "Cashier", slot = "staff" },
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
