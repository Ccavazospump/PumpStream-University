--[[
	PlotBuilder
	-----------
	Builds all the physical parts of a plot: floor, an EXPANDABLE store
	shell (3 sizes — see GameConfig.Expansions), checkout counter, claim
	pad, aisle-style departments, spread-out upgrade pads, and a returns
	bin. Pure construction — game logic lives in PlotManager.

	Every plot is built relative to an origin CFrame. The storefront
	faces +Z; the front wall and door NEVER move when the store expands,
	so customer paths stay stable.

	Layout (plot-local coords):
	  door           (0, 5)      counter      x -28..-4 at z = -8
	  returns bin    (-31.5, -1) register     (-8, -8)
	  upgrade spots  economy (12, -2) / staff (18, -2), near the door
	  departments    aisle zones on a grid; see GameConfig.Sections
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local GameConfig = require(ReplicatedStorage.Shared.GameConfig)
local Util = require(script.Parent.Util)
local ItemVisuals = require(script.Parent.ItemVisuals)

local PlotBuilder = {}

local GROUND = 0.5 -- top surface of the plot floor
local WALL_HEIGHT = 14

-- Optional pretty-model hooks: drop a Model named "ShelfUnit" or
-- "Register" into ReplicatedStorage/Assets (set its PrimaryPart, pivot at
-- bottom-center) and it will be used instead of the built-in blocky look.
local function getTemplate(name)
	local assets = ReplicatedStorage:FindFirstChild("Assets")
	local template = assets and assets:FindFirstChild(name)
	if template and template:IsA("Model") then
		return template
	end
	return nil
end

local COLORS = {
	Pavement = Color3.fromRGB(170, 172, 178),
	StoreFloor = Color3.fromRGB(224, 226, 232),
	FloorAccent = Color3.fromRGB(78, 182, 164),
	Wall = Color3.fromRGB(206, 86, 78),
	WallTrim = Color3.fromRGB(250, 250, 248),
	AwningStripe = Color3.fromRGB(250, 250, 248),
	Counter = Color3.fromRGB(146, 102, 70),
	CounterTop = Color3.fromRGB(238, 228, 210),
	Shelf = Color3.fromRGB(96, 100, 112),
	Light = Color3.fromRGB(255, 250, 235),
	ClaimPad = Color3.fromRGB(88, 226, 128),
	PadAvailable = Color3.fromRGB(255, 200, 60),
	ReturnsBin = Color3.fromRGB(78, 182, 164),
}

-- fixed pad spots for the chains that live near the door
local CHAIN_SLOTS = {
	economy = { 12, -2 },
	staff = { 19, -2 },
	services = { 26, -2 },
}

-- ========================= Expandable shell ==========================

-- (Re)build walls, floors, trim, lights, sign, awning for an expansion
-- level. Called on plot creation (level 1) and on each expansion.
function PlotBuilder.buildShell(plot, level)
	local origin = plot.origin
	local bounds = GameConfig.Expansions[level]
	local hw, backZ = bounds.halfWidth, bounds.backZ
	local model = plot.shellFolder

	model:ClearAllChildren()
	plot.expansionLevel = level

	local interiorDepth = 5 - backZ
	local centerZ = (5 + backZ) / 2
	local wallY = GROUND + WALL_HEIGHT / 2
	local WALL_MAT = Enum.Material.SmoothPlastic

	-- floors
	Util.part({
		Name = "FloorAccent",
		Size = Vector3.new(hw * 2 + 4, 0.2, interiorDepth + 4),
		CFrame = origin * CFrame.new(0, GROUND + 0.02, centerZ),
		Color = COLORS.FloorAccent,
		Parent = model,
	})
	Util.part({
		Name = "StoreFloor",
		Size = Vector3.new(hw * 2, 0.2, interiorDepth),
		CFrame = origin * CFrame.new(0, GROUND + 0.05, centerZ),
		Color = COLORS.StoreFloor,
		Reflectance = 0.04,
		Parent = model,
	})

	-- front wall segments leave a 14-stud door gap at x = 0
	local frontSegment = (hw - 7) / 2 + 7 -- center x of each segment
	local frontLength = hw - 7
	Util.part({ Name = "FrontWallL", Size = Vector3.new(frontLength, WALL_HEIGHT, 1), CFrame = origin * CFrame.new(-frontSegment, wallY, 5), Color = COLORS.Wall, Material = WALL_MAT, Parent = model })
	Util.part({ Name = "FrontWallR", Size = Vector3.new(frontLength, WALL_HEIGHT, 1), CFrame = origin * CFrame.new(frontSegment, wallY, 5), Color = COLORS.Wall, Material = WALL_MAT, Parent = model })
	Util.part({ Name = "DoorHeader", Size = Vector3.new(14, 4, 1), CFrame = origin * CFrame.new(0, GROUND + WALL_HEIGHT - 2, 5), Color = COLORS.Wall, Material = WALL_MAT, Parent = model })
	Util.part({ Name = "SideWallL", Size = Vector3.new(1, WALL_HEIGHT, interiorDepth), CFrame = origin * CFrame.new(-hw, wallY, centerZ), Color = COLORS.Wall, Material = WALL_MAT, Parent = model })
	Util.part({ Name = "SideWallR", Size = Vector3.new(1, WALL_HEIGHT, interiorDepth), CFrame = origin * CFrame.new(hw, wallY, centerZ), Color = COLORS.Wall, Material = WALL_MAT, Parent = model })
	Util.part({ Name = "BackWall", Size = Vector3.new(hw * 2, WALL_HEIGHT, 1), CFrame = origin * CFrame.new(0, wallY, backZ), Color = COLORS.Wall, Material = WALL_MAT, Parent = model })

	-- white roof trim + interior baseboards for a finished look
	local topY = GROUND + WALL_HEIGHT
	Util.part({ Name = "Trim", Size = Vector3.new(hw * 2 + 2, 1, 1.4), CFrame = origin * CFrame.new(0, topY, 5), Color = COLORS.WallTrim, Parent = model })
	Util.part({ Name = "Trim", Size = Vector3.new(hw * 2 + 2, 1, 1.4), CFrame = origin * CFrame.new(0, topY, backZ), Color = COLORS.WallTrim, Parent = model })
	Util.part({ Name = "Trim", Size = Vector3.new(1.4, 1, interiorDepth + 2), CFrame = origin * CFrame.new(-hw, topY, centerZ), Color = COLORS.WallTrim, Parent = model })
	Util.part({ Name = "Trim", Size = Vector3.new(1.4, 1, interiorDepth + 2), CFrame = origin * CFrame.new(hw, topY, centerZ), Color = COLORS.WallTrim, Parent = model })
	Util.part({ Name = "Baseboard", Size = Vector3.new(hw * 2, 1, 0.4), CFrame = origin * CFrame.new(0, GROUND + 0.6, backZ + 0.6), Color = COLORS.WallTrim, Parent = model })
	Util.part({ Name = "Baseboard", Size = Vector3.new(0.4, 1, interiorDepth), CFrame = origin * CFrame.new(-hw + 0.6, GROUND + 0.6, centerZ), Color = COLORS.WallTrim, Parent = model })
	Util.part({ Name = "Baseboard", Size = Vector3.new(0.4, 1, interiorDepth), CFrame = origin * CFrame.new(hw - 0.6, GROUND + 0.6, centerZ), Color = COLORS.WallTrim, Parent = model })

	-- ceiling light strips in a grid that scales with the store
	for _, x in ipairs({ -(hw - 16), 0, hw - 16 }) do
		local z = -8
		while z > backZ + 6 do
			local fixture = Util.part({
				Name = "LightFixture",
				Size = Vector3.new(8, 0.4, 3),
				CFrame = origin * CFrame.new(x, topY - 1.5, z),
				Color = COLORS.Light,
				Material = Enum.Material.Neon,
				Parent = model,
			})
			local light = Instance.new("PointLight")
			light.Brightness = 0.45
			light.Range = 16
			light.Color = COLORS.Light
			light.Parent = fixture
			z -= 18
		end
	end

	-- striped entrance awning
	for i = 0, 6 do
		Util.part({
			Name = "Awning",
			Size = Vector3.new(2, 0.4, 5),
			CFrame = origin * CFrame.new(-6 + i * 2, GROUND + WALL_HEIGHT - 4.5, 8)
				* CFrame.Angles(math.rad(-28), 0, 0),
			Color = (i % 2 == 0) and COLORS.Wall or COLORS.AwningStripe,
			Material = Enum.Material.Fabric,
			Parent = model,
		})
	end

	-- welcome mat
	Util.part({
		Name = "WelcomeMat",
		Size = Vector3.new(12, 0.12, 5),
		CFrame = origin * CFrame.new(0, GROUND + 0.16, 8),
		Color = COLORS.FloorAccent,
		Material = Enum.Material.Fabric,
		Parent = model,
	})

	-- storefront sign (label recreated each rebuild; PlotManager re-titles it)
	local storeSign = Util.part({
		Name = "StoreSign",
		Size = Vector3.new(30, 4.5, 1),
		CFrame = origin * CFrame.new(0, GROUND + WALL_HEIGHT + 2.5, 5),
		Color = COLORS.WallTrim,
		Parent = model,
	})
	plot.ownerSignLabel = Util.surfaceSign(storeSign, Enum.NormalId.Back, plot.signText or ("FOR SALE — Store #" .. plot.index), Color3.fromRGB(206, 86, 78))
end

-- ========================== Departments ===============================

-- Builds one department as a real aisle: two rows of three shelf units
-- facing each other. Returns the shelves so PlotManager can wire prompts.
function PlotBuilder.buildSection(plot, section)
	local base = plot.origin * CFrame.new(section.offset.X, 0, section.offset.Z)
	if section.rotated then
		base = base * CFrame.Angles(0, math.rad(90), 0)
	end

	local folder = Instance.new("Folder")
	folder.Name = section.id

	-- department floor mat (14 deep so there's a walkable corridor between zones)
	Util.part({
		Name = "Mat",
		Size = Vector3.new(28, 0.2, 14),
		CFrame = base * CFrame.new(0, GROUND + 0.11, 0),
		Color = section.color,
		Transparency = 0.25,
		Parent = folder,
	})

	-- hanging department sign over the aisle
	local sign = Util.part({
		Name = "Sign",
		Size = Vector3.new(14, 2.5, 0.6),
		CFrame = base * CFrame.new(0, GROUND + 11, 0),
		Color = section.color,
		Parent = folder,
	})
	Util.surfaceSign(sign, Enum.NormalId.Back, section.name)
	Util.surfaceSign(sign, Enum.NormalId.Front, section.name)

	local shelves = {}
	for index, itemId in ipairs(section.items) do
		local item = GameConfig.Items[itemId]
		-- two rows of three: row A (index 1-3) at z -4.5, row B at +4.5
		local row = (index <= 3) and -1 or 1
		local col = ((index - 1) % 3) - 1 -- -1, 0, 1
		local x = col * 8.5
		local z = row * 4.5
		local shelfCF = base * CFrame.new(x, 0, z)

		-- your pretty model if provided, otherwise the built-in blocky unit
		local stand
		local shelfTemplate = getTemplate("ShelfUnit")
		if shelfTemplate then
			local unit = shelfTemplate:Clone()
			unit.Name = itemId .. "Shelf"
			unit:PivotTo(shelfCF * CFrame.new(0, GROUND, 0) * CFrame.Angles(0, row == 1 and math.rad(180) or 0, 0))
			unit.Parent = folder
			stand = unit.PrimaryPart or unit:FindFirstChildWhichIsA("BasePart")
		else
			stand = Util.part({
				Name = itemId .. "Shelf",
				Size = Vector3.new(6, 3, 2.6),
				CFrame = shelfCF * CFrame.new(0, GROUND + 1.5, 0),
				Color = COLORS.Shelf,
				Parent = folder,
			})

			-- department-colored header board on the back of the unit
			Util.part({
				Name = "ShelfHeader",
				Size = Vector3.new(6, 1.6, 0.4),
				CFrame = shelfCF * CFrame.new(0, GROUND + 3.8, 1.1 * row),
				Color = section.color,
				Parent = folder,
			})
		end

		-- two product models sitting on top (real shapes, not cubes)
		for _, side in ipairs({ -1.4, 1.4 }) do
			local display = ItemVisuals.buildModel(itemId, { anchored = true, scale = 0.9 })
			display:PivotTo(shelfCF * CFrame.new(side, GROUND + 3.8, -0.4 * row) * CFrame.Angles(0, math.rad(math.random(-30, 30)), 0))
			display.Parent = folder
		end

		-- compact price tag, short range so only nearby shelves show
		Util.billboard(stand, string.format("%s  $%d", item.name, item.price), {
			size = UDim2.fromOffset(96, 24),
			offsetY = 2.6,
			maxDistance = 24,
			backgroundTransparency = 0.25,
		})

		local prompt = Instance.new("ProximityPrompt")
		prompt.ActionText = "Take " .. item.name
		prompt.ObjectText = section.name
		prompt.HoldDuration = 0.35
		prompt.MaxActivationDistance = 8
		prompt.RequiresLineOfSight = false
		prompt.Parent = stand

		-- where staff NPCs stand: in the aisle, in front of this unit
		plot.shelfPositions[itemId] = (shelfCF * CFrame.new(0, GROUND + 2, -2.6 * row)).Position

		table.insert(shelves, { itemId = itemId, prompt = prompt })
	end

	folder.Parent = plot.sectionsFolder
	return shelves
end

-- ========================== Upgrade pads ==============================

local function padPosition(upgrade)
	if upgrade.padAt then
		return upgrade.padAt[1], upgrade.padAt[2]
	end
	local slot = CHAIN_SLOTS[upgrade.slot or "economy"]
	return slot[1], slot[2]
end

local function buildUpgradePads(plot)
	local origin = plot.origin
	for _, upgrade in ipairs(GameConfig.Upgrades) do
		local x, z = padPosition(upgrade)
		local pad = Util.part({
			Name = "Pad_" .. upgrade.id,
			Shape = Enum.PartType.Cylinder,
			Size = Vector3.new(0.4, 5, 5),
			CFrame = origin * CFrame.new(x, GROUND + 0.2, z) * CFrame.Angles(0, 0, math.rad(90)),
			Color = COLORS.PadAvailable,
			Material = Enum.Material.Neon,
			Transparency = 1,
			Parent = plot.model,
		})

		local label = Util.billboard(pad, upgrade.name, {
			size = UDim2.fromOffset(160, 72),
			offsetY = 3.4,
			maxDistance = 60,
		})
		label:FindFirstAncestorOfClass("BillboardGui").Enabled = false

		local prompt = Instance.new("ProximityPrompt")
		prompt.ActionText = "Buy"
		prompt.ObjectText = upgrade.name
		prompt.HoldDuration = 0.5
		prompt.MaxActivationDistance = 8
		prompt.RequiresLineOfSight = false
		prompt.Enabled = false
		prompt.Parent = pad

		plot.padByUpgrade[upgrade.id] = { pad = pad, prompt = prompt, label = label }
	end
end

-- Tycoon-style sequential visibility: a pad is shown ONLY when it's the
-- next thing in its chain (prereq owned, not yet owned). ownedSet nil =
-- unclaimed plot = everything hidden.
function PlotBuilder.refreshUpgradePads(plot, ownedSet)
	for _, upgrade in ipairs(GameConfig.Upgrades) do
		local entry = plot.padByUpgrade[upgrade.id]
		if entry then
			local available = ownedSet ~= nil
				and not ownedSet[upgrade.id]
				and (upgrade.requires == nil or ownedSet[upgrade.requires])
			entry.pad.Transparency = available and 0.15 or 1
			entry.prompt.Enabled = available
			entry.label:FindFirstAncestorOfClass("BillboardGui").Enabled = available
			if available then
				entry.label.Text = string.format("⭐ %s\n%s\n$%d", upgrade.name, upgrade.desc or "", upgrade.cost)
			end
		end
	end
end

-- ============================ Full plot ===============================

function PlotBuilder.build(origin, index)
	local model = Instance.new("Model")
	model.Name = "Plot" .. index

	local plot = {
		index = index,
		origin = origin,
		model = model,
		owner = nil,
		generation = 0, -- bumped on claim/release so old NPC loops stop
		expansionLevel = 1,
		padByUpgrade = {},
		shelfPositions = {}, -- itemId -> world Vector3 in the aisle
		customers = {}, -- walk-in shoppers
		onlineCustomers = {}, -- curbside pickups
		curbsideSpots = 0,
		staff = {},
		signText = nil,
	}

	local size = GameConfig.Plot.Size

	-- plot ground (parking lot / street)
	Util.part({
		Name = "Floor",
		Size = Vector3.new(size, 1, size),
		CFrame = origin * CFrame.new(0, 0, 0),
		Color = COLORS.Pavement,
		Material = Enum.Material.Concrete,
		Parent = model,
	})

	-- folders: shell rebuilds on expansion, sections build on unlock
	local shellFolder = Instance.new("Folder")
	shellFolder.Name = "Shell"
	shellFolder.Parent = model
	plot.shellFolder = shellFolder

	local sectionsFolder = Instance.new("Folder")
	sectionsFolder.Name = "Sections"
	sectionsFolder.Parent = model
	plot.sectionsFolder = sectionsFolder

	local curbsideFolder = Instance.new("Folder")
	curbsideFolder.Name = "Curbside"
	curbsideFolder.Parent = model
	plot.curbsideFolder = curbsideFolder

	PlotBuilder.buildShell(plot, 1)

	-- checkout counter (front-left) + register
	Util.part({
		Name = "Counter",
		Size = Vector3.new(24, 3, 3),
		CFrame = origin * CFrame.new(-16, GROUND + 1.5, -8),
		Color = COLORS.Counter,
		Material = Enum.Material.WoodPlanks,
		Parent = model,
	})
	Util.part({
		Name = "CounterTop",
		Size = Vector3.new(24.6, 0.4, 3.6),
		CFrame = origin * CFrame.new(-16, GROUND + 3.2, -8),
		Color = COLORS.CounterTop,
		Reflectance = 0.05,
		Parent = model,
	})
	-- conveyor belt running along the counter top toward the register
	Util.part({
		Name = "BeltStrip",
		Size = Vector3.new(16, 0.25, 2.3),
		CFrame = origin * CFrame.new(-19, GROUND + 3.55, -8),
		Color = Color3.fromRGB(52, 54, 60),
		Material = Enum.Material.Fabric,
		Parent = model,
	})
	Util.part({ Name = "BeltRail", Size = Vector3.new(16, 0.35, 0.25), CFrame = origin * CFrame.new(-19, GROUND + 3.65, -9.25), Color = Color3.fromRGB(180, 182, 188), Material = Enum.Material.Metal, Parent = model })
	Util.part({ Name = "BeltRail", Size = Vector3.new(16, 0.35, 0.25), CFrame = origin * CFrame.new(-19, GROUND + 3.65, -6.75), Color = Color3.fromRGB(180, 182, 188), Material = Enum.Material.Metal, Parent = model })

	-- red laser scanner at the register end of the belt
	Util.part({
		Name = "ScannerBeam",
		Size = Vector3.new(0.15, 0.3, 2.3),
		CFrame = origin * CFrame.new(-10.5, GROUND + 3.75, -8),
		Color = Color3.fromRGB(255, 60, 50),
		Material = Enum.Material.Neon,
		Parent = model,
	})

	-- a register that looks like a register: base + angled screen + keypad
	-- (or YOUR model, if ReplicatedStorage/Assets/Register exists)
	local registerBase
	local registerTemplate = getTemplate("Register")
	if registerTemplate then
		local custom = registerTemplate:Clone()
		custom.Name = "Register"
		custom:PivotTo(origin * CFrame.new(-8, GROUND, -8))
		custom.Parent = model
		registerBase = custom.PrimaryPart or custom:FindFirstChildWhichIsA("BasePart")
		plot.registerDisplay = Util.billboard(registerBase, "REGISTER READY", {
			size = UDim2.fromOffset(120, 44),
			offsetY = 4,
			maxDistance = 35,
			textColor = Color3.fromRGB(120, 255, 170),
		})
		plot.registerDrawer = nil -- custom models handle their own look
	else
		registerBase = Util.part({
			Name = "Register",
			Size = Vector3.new(2.4, 1, 2.4),
			CFrame = origin * CFrame.new(-8, GROUND + 3.9, -8),
			Color = Color3.fromRGB(60, 62, 70),
			Parent = model,
		})
		local screen = Util.part({
			Name = "RegisterScreen",
			Size = Vector3.new(2.2, 1.8, 0.2),
			CFrame = origin * CFrame.new(-8, GROUND + 5.4, -8.4) * CFrame.Angles(math.rad(-12), 0, 0),
			Color = Color3.fromRGB(22, 24, 30),
			Parent = model,
		})
		plot.registerDisplay = Util.surfaceSign(screen, Enum.NormalId.Front, "REGISTER\nREADY", Color3.fromRGB(120, 255, 170))
		Util.part({
			Name = "Keypad",
			Size = Vector3.new(1.6, 0.25, 1.2),
			CFrame = origin * CFrame.new(-8, GROUND + 4.5, -7.2) * CFrame.Angles(math.rad(8), 0, 0),
			Color = Color3.fromRGB(200, 202, 208),
			Parent = model,
		})

		-- cash drawer that pops open when you take payment
		local drawer = Util.part({
			Name = "CashDrawer",
			Size = Vector3.new(2.0, 0.6, 1.6),
			CFrame = origin * CFrame.new(-8, GROUND + 3.5, -8),
			Color = Color3.fromRGB(90, 92, 100),
			Material = Enum.Material.Metal,
			Parent = model,
		})
		local cash = Util.part({
			Name = "DrawerCash",
			Size = Vector3.new(1.6, 0.15, 1.2),
			CFrame = origin * CFrame.new(-8, GROUND + 3.85, -8),
			Color = Color3.fromRGB(110, 190, 110),
			Parent = model,
		})
		plot.registerDrawer = {
			drawer = drawer,
			cash = cash,
			drawerClosed = drawer.CFrame,
			cashClosed = cash.CFrame,
		}
	end

	-- scanning happens HERE: quick E taps, one per item
	local registerPrompt = Instance.new("ProximityPrompt")
	registerPrompt.ActionText = "Scan Item"
	registerPrompt.ObjectText = "Register"
	registerPrompt.HoldDuration = 0
	registerPrompt.MaxActivationDistance = 9
	registerPrompt.RequiresLineOfSight = false
	registerPrompt.Parent = registerBase
	plot.registerPrompt = registerPrompt

	-- belt slot positions: slot 1 is next in line (nearest the scanner),
	-- higher slots stretch toward the customer end; slot 0 is the scanner
	-- itself. Items slide slot-to-slot toward the laser.
	plot.getBeltSlot = function(slotIndex)
		if slotIndex <= 0 then
			return origin * CFrame.new(-10.5, GROUND + 4.35, -8)
		end
		local clamped = math.min(slotIndex, 7)
		local x = -25.5 + (7 - clamped) * 1.9
		local zJitter = (slotIndex - clamped) * 0.4
		return origin * CFrame.new(x, GROUND + 4.35, -8 + zJitter)
	end

	-- returns bin: put back wrongly-grabbed items
	local returnsBin = Util.part({
		Name = "ReturnsBin",
		Size = Vector3.new(3, 3.4, 3),
		CFrame = origin * CFrame.new(-31.5, GROUND + 1.7, -1),
		Color = COLORS.ReturnsBin,
		Parent = model,
	})
	Util.billboard(returnsBin, "↩️ RETURNS\nPut items back", {
		size = UDim2.fromOffset(110, 40),
		offsetY = 2.6,
		maxDistance = 30,
	})
	local returnsPrompt = Instance.new("ProximityPrompt")
	returnsPrompt.ActionText = "Put Back All Items"
	returnsPrompt.ObjectText = "Returns Bin"
	returnsPrompt.HoldDuration = 0.3
	returnsPrompt.MaxActivationDistance = 8
	returnsPrompt.RequiresLineOfSight = false
	returnsPrompt.Parent = returnsBin
	plot.returnsPrompt = returnsPrompt

	-- claim pad out front
	local claimPad = Util.part({
		Name = "ClaimPad",
		Shape = Enum.PartType.Cylinder,
		Size = Vector3.new(0.4, 9, 9),
		CFrame = origin * CFrame.new(0, GROUND + 0.2, 20) * CFrame.Angles(0, 0, math.rad(90)),
		Color = COLORS.ClaimPad,
		Material = Enum.Material.Neon,
		Parent = model,
	})
	plot.claimPad = claimPad
	plot.claimLabel = Util.billboard(claimPad, "🏪 Claim Store #" .. index .. "!", {
		size = UDim2.fromOffset(200, 50),
		offsetY = 4,
		maxDistance = 150,
	})

	buildUpgradePads(plot)

	-- key walking positions (world space)
	local function point(x, z)
		return (origin * CFrame.new(x, GROUND + 3, z)).Position
	end
	plot.points = {
		customerSpawn = point(0, 55),
		doorOutside = point(0, 12),
		doorInside = point(0, 0),
		shopperIdle = point(2, -12), -- right end of the counter, inside
		cashierIdle = point(-16, -12), -- behind the counter
		payPoint = point(-8, -4), -- customer side of the register
	}
	-- queue slots along the front of the counter
	plot.getQueueSlot = function(slotIndex)
		local x = -26 + ((slotIndex - 1) % 8) * 4
		return point(x, -3.5)
	end
	-- open floor at either end of the counter; NPCs detour through these
	plot.getCounterGap = function(side)
		return point(side >= 0 and 2 or -31.5, -8)
	end
	-- curbside parking spots outside, to the right of the entrance
	plot.getCurbsideSpot = function(spotIndex)
		return point(16 + (spotIndex - 1) * 10, 18)
	end

	model.Parent = workspace
	return plot
end

-- Paint a curbside pickup spot outside (called when the upgrade unlocks it).
function PlotBuilder.buildCurbsideSpot(plot, spotIndex)
	local origin = plot.origin
	local x = 16 + (spotIndex - 1) * 10

	local spot = Util.part({
		Name = "CurbsideSpot" .. spotIndex,
		Size = Vector3.new(8, 0.15, 11),
		CFrame = origin * CFrame.new(x, GROUND + 0.14, 18),
		Color = Color3.fromRGB(70, 72, 78),
		Parent = plot.curbsideFolder,
	})
	-- white border stripes
	for _, edge in ipairs({ { 0, -5.4, 8.4, 0.5 }, { 0, 5.4, 8.4, 0.5 }, { -4, 0, 0.5, 10.6 }, { 4, 0, 0.5, 10.6 } }) do
		Util.part({
			Name = "Stripe",
			Size = Vector3.new(edge[3], 0.16, edge[4]),
			CFrame = origin * CFrame.new(x + edge[1], GROUND + 0.16, 18 + edge[2]),
			Color = Color3.fromRGB(245, 245, 245),
			Parent = plot.curbsideFolder,
		})
	end
	Util.billboard(spot, "📱 CURBSIDE " .. spotIndex, {
		size = UDim2.fromOffset(130, 32),
		offsetY = 5,
		maxDistance = 80,
	})
end

function PlotBuilder.clearCurbside(plot)
	plot.curbsideFolder:ClearAllChildren()
end

-- Show/hide the claim pad (hidden while the plot is owned).
function PlotBuilder.setClaimPadVisible(plot, visible)
	plot.claimPad.Transparency = visible and 0 or 1
	plot.claimPad.CanTouch = visible
	plot.claimPad.CanCollide = visible
	local gui = plot.claimLabel and plot.claimLabel:FindFirstAncestorOfClass("BillboardGui")
	if gui then
		gui.Enabled = visible
	end
end

function PlotBuilder.setOwnerSign(plot, text)
	plot.signText = text
	if plot.ownerSignLabel then
		plot.ownerSignLabel.Text = text
	end
end

-- Remove all built departments (called when a plot is released).
function PlotBuilder.clearSections(plot)
	plot.sectionsFolder:ClearAllChildren()
	plot.shelfPositions = {}
end

return PlotBuilder
