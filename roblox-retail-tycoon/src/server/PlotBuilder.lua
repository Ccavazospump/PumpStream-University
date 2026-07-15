--[[
	PlotBuilder
	-----------
	Builds all the physical parts of a plot: floor, store walls, counter,
	claim pad, department shelves and upgrade pads. Pure construction —
	game logic (claiming, buying, customers) lives in PlotManager.

	Every plot is built relative to an origin CFrame. The storefront
	faces +Z: customers spawn at the street (+Z edge) and walk in.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local GameConfig = require(ReplicatedStorage.Shared.GameConfig)
local Util = require(script.Parent.Util)

local PlotBuilder = {}

local GROUND = 0.5 -- top surface of the plot floor
local WALL_HEIGHT = 14

local COLORS = {
	Pavement = Color3.fromRGB(163, 162, 165),
	StoreFloor = Color3.fromRGB(230, 228, 220),
	Wall = Color3.fromRGB(216, 90, 74), -- warm grocery-store red
	WallTrim = Color3.fromRGB(245, 241, 227),
	Counter = Color3.fromRGB(120, 84, 58),
	Shelf = Color3.fromRGB(70, 70, 76),
	ClaimPad = Color3.fromRGB(80, 220, 120),
	PadAvailable = Color3.fromRGB(255, 200, 60),
	PadOwned = Color3.fromRGB(80, 200, 110),
	PadLocked = Color3.fromRGB(110, 110, 115),
}

-- Builds one department (floor mat, sign, one stocked shelf per item).
-- Returns the shelves so the caller can hook up their pickup prompts.
function PlotBuilder.buildSection(plot, section)
	local origin = plot.origin
	local offset = section.offset

	local folder = Instance.new("Folder")
	folder.Name = section.id

	-- colored floor mat
	Util.part({
		Name = "Mat",
		Size = Vector3.new(28, 0.2, 14),
		CFrame = origin * CFrame.new(offset.X, GROUND + 0.11, offset.Z),
		Color = section.color,
		Parent = folder,
	})

	-- hanging department sign
	local sign = Util.part({
		Name = "Sign",
		Size = Vector3.new(12, 2.5, 0.6),
		CFrame = origin * CFrame.new(offset.X, GROUND + 11, offset.Z - 3),
		Color = section.color,
		Parent = folder,
	})
	Util.surfaceSign(sign, Enum.NormalId.Back, section.name)
	Util.surfaceSign(sign, Enum.NormalId.Front, section.name)

	local shelves = {}
	for index, itemId in ipairs(section.items) do
		local item = GameConfig.Items[itemId]
		local x = offset.X + (index - (#section.items + 1) / 2) * 7
		local shelfZ = offset.Z - 3

		local stand = Util.part({
			Name = itemId .. "Shelf",
			Size = Vector3.new(4, 4.5, 2),
			CFrame = origin * CFrame.new(x, GROUND + 2.25, shelfZ),
			Color = COLORS.Shelf,
			Material = Enum.Material.Metal,
			Parent = folder,
		})

		-- the "product" sitting on top of the shelf
		Util.part({
			Name = "Display",
			Size = Vector3.new(1.6, 1.6, 1.6),
			CFrame = origin * CFrame.new(x, GROUND + 5.3, shelfZ),
			Color = item.color,
			Parent = folder,
		})

		Util.billboard(stand, string.format("%s\n$%d", item.name, item.price), {
			size = UDim2.fromOffset(110, 44),
			offsetY = 5.2,
			maxDistance = 45,
		})

		local prompt = Instance.new("ProximityPrompt")
		prompt.ActionText = "Take " .. item.name
		prompt.ObjectText = section.name
		prompt.HoldDuration = 0.35
		prompt.MaxActivationDistance = 9
		prompt.RequiresLineOfSight = false
		prompt.Parent = stand

		-- where staff NPCs stand to grab this item
		plot.shelfPositions[itemId] = (origin * CFrame.new(x, GROUND + 2, shelfZ + 4)).Position

		table.insert(shelves, { itemId = itemId, prompt = prompt })
	end

	folder.Parent = plot.sectionsFolder
	return shelves
end

-- One buy-pad per upgrade, arranged in rows in the front-right of the store.
local function buildUpgradePads(plot)
	local origin = plot.origin

	local boardSign = Util.part({
		Name = "UpgradeBoard",
		Size = Vector3.new(14, 2.5, 0.6),
		CFrame = origin * CFrame.new(28, GROUND + 11, 2),
		Color = Color3.fromRGB(50, 50, 60),
		Parent = plot.model,
	})
	Util.surfaceSign(boardSign, Enum.NormalId.Front, "UPGRADES")

	for index, upgrade in ipairs(GameConfig.Upgrades) do
		local row = math.floor((index - 1) / 6)
		local col = (index - 1) % 6
		local x = 14 + col * 5.5
		local z = -2 - row * 7

		local pad = Util.part({
			Name = "Pad_" .. upgrade.id,
			Shape = Enum.PartType.Cylinder,
			Size = Vector3.new(0.4, 4.4, 4.4),
			CFrame = origin * CFrame.new(x, GROUND + 0.2, z) * CFrame.Angles(0, 0, math.rad(90)),
			Color = COLORS.PadLocked,
			Parent = plot.model,
		})

		local label = Util.billboard(pad, upgrade.name, {
			size = UDim2.fromOffset(150, 66),
			offsetY = 3.2,
			maxDistance = 40,
		})

		local prompt = Instance.new("ProximityPrompt")
		prompt.ActionText = "Buy"
		prompt.ObjectText = upgrade.name
		prompt.HoldDuration = 0.5
		prompt.MaxActivationDistance = 7
		prompt.RequiresLineOfSight = false
		prompt.Enabled = false
		prompt.Parent = pad

		plot.padByUpgrade[upgrade.id] = { pad = pad, prompt = prompt, label = label }
	end
end

-- Refresh every pad's color/label/prompt for the current ownership state.
-- ownedSet is a { [upgradeId] = true } map; pass nil for an unclaimed plot.
function PlotBuilder.refreshUpgradePads(plot, ownedSet)
	for _, upgrade in ipairs(GameConfig.Upgrades) do
		local entry = plot.padByUpgrade[upgrade.id]
		if entry then
			if not ownedSet then
				entry.pad.Color = COLORS.PadLocked
				entry.label.Text = upgrade.name
				entry.prompt.Enabled = false
			elseif ownedSet[upgrade.id] then
				entry.pad.Color = COLORS.PadOwned
				entry.label.Text = upgrade.name .. "\nOWNED ✓"
				entry.prompt.Enabled = false
			elseif upgrade.requires and not ownedSet[upgrade.requires] then
				local required = GameConfig.getUpgrade(upgrade.requires)
				entry.pad.Color = COLORS.PadLocked
				entry.label.Text = string.format("%s\n🔒 Needs: %s", upgrade.name, required and required.name or upgrade.requires)
				entry.prompt.Enabled = false
			else
				entry.pad.Color = COLORS.PadAvailable
				entry.label.Text = string.format("%s\n%s\n$%d", upgrade.name, upgrade.desc or "", upgrade.cost)
				entry.prompt.Enabled = true
			end
		end
	end
end

-- Build the full plot shell and return the plot state table.
function PlotBuilder.build(origin, index)
	local model = Instance.new("Model")
	model.Name = "Plot" .. index

	local plot = {
		index = index,
		origin = origin,
		model = model,
		owner = nil,
		generation = 0, -- bumped on claim/release so old NPC loops stop
		padByUpgrade = {},
		shelfPositions = {}, -- itemId -> world Vector3 in front of the shelf
		customers = {},
		staff = {},
	}

	local size = GameConfig.Plot.Size

	-- plot floor (parking lot / pavement)
	Util.part({
		Name = "Floor",
		Size = Vector3.new(size, 1, size),
		CFrame = origin * CFrame.new(0, 0, 0),
		Color = COLORS.Pavement,
		Material = Enum.Material.Concrete,
		Parent = model,
	})

	-- store interior floor
	Util.part({
		Name = "StoreFloor",
		Size = Vector3.new(90, 0.2, 60),
		CFrame = origin * CFrame.new(0, GROUND + 0.05, -25),
		Color = COLORS.StoreFloor,
		Parent = model,
	})

	-- walls: front (with door gap), two sides, back
	local wallY = GROUND + WALL_HEIGHT / 2
	Util.part({ Name = "FrontWallL", Size = Vector3.new(38, WALL_HEIGHT, 1), CFrame = origin * CFrame.new(-26, wallY, 5), Color = COLORS.Wall, Material = Enum.Material.Brick, Parent = model })
	Util.part({ Name = "FrontWallR", Size = Vector3.new(38, WALL_HEIGHT, 1), CFrame = origin * CFrame.new(26, wallY, 5), Color = COLORS.Wall, Material = Enum.Material.Brick, Parent = model })
	Util.part({ Name = "DoorHeader", Size = Vector3.new(14, 4, 1), CFrame = origin * CFrame.new(0, GROUND + WALL_HEIGHT - 2, 5), Color = COLORS.Wall, Material = Enum.Material.Brick, Parent = model })
	Util.part({ Name = "SideWallL", Size = Vector3.new(1, WALL_HEIGHT, 60), CFrame = origin * CFrame.new(-45, wallY, -25), Color = COLORS.Wall, Material = Enum.Material.Brick, Parent = model })
	Util.part({ Name = "SideWallR", Size = Vector3.new(1, WALL_HEIGHT, 60), CFrame = origin * CFrame.new(45, wallY, -25), Color = COLORS.Wall, Material = Enum.Material.Brick, Parent = model })
	Util.part({ Name = "BackWall", Size = Vector3.new(90, WALL_HEIGHT, 1), CFrame = origin * CFrame.new(0, wallY, -55), Color = COLORS.Wall, Material = Enum.Material.Brick, Parent = model })

	-- storefront sign above the door
	local storeSign = Util.part({
		Name = "StoreSign",
		Size = Vector3.new(30, 4.5, 1),
		CFrame = origin * CFrame.new(0, GROUND + WALL_HEIGHT + 2.5, 5),
		Color = COLORS.WallTrim,
		Parent = model,
	})
	plot.ownerSignLabel = Util.surfaceSign(storeSign, Enum.NormalId.Back, "FOR SALE — Store #" .. index, Color3.fromRGB(216, 90, 74))

	-- checkout counter + register
	Util.part({
		Name = "Counter",
		Size = Vector3.new(24, 3, 3),
		CFrame = origin * CFrame.new(0, GROUND + 1.5, -8),
		Color = COLORS.Counter,
		Material = Enum.Material.WoodPlanks,
		Parent = model,
	})
	local register = Util.part({
		Name = "Register",
		Size = Vector3.new(2, 2, 2),
		CFrame = origin * CFrame.new(8, GROUND + 4, -8),
		Color = Color3.fromRGB(40, 40, 45),
		Parent = model,
	})
	Util.billboard(register, "CHECKOUT", {
		size = UDim2.fromOffset(120, 30),
		offsetY = 2.2,
		maxDistance = 50,
	})

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

	-- folder that holds unlocked department builds
	local sectionsFolder = Instance.new("Folder")
	sectionsFolder.Name = "Sections"
	sectionsFolder.Parent = model
	plot.sectionsFolder = sectionsFolder

	buildUpgradePads(plot)

	-- key walking positions (world space)
	local function point(x, z)
		return (origin * CFrame.new(x, GROUND + 3, z)).Position
	end
	plot.points = {
		customerSpawn = point(0, 54),
		doorOutside = point(0, 12),
		doorInside = point(0, 0),
		shopperIdle = point(-18, -14), -- behind the counter, near the shelves
		cashierIdle = point(0, -12), -- behind the counter
	}
	-- queue slots along the front of the counter
	plot.getQueueSlot = function(slotIndex)
		local x = -10 + ((slotIndex - 1) % 6) * 4
		return point(x, -3.5)
	end
	-- open floor at either end of the counter; NPCs route through these
	-- so straight-line MoveTo doesn't walk them into the counter
	plot.getCounterGap = function(side)
		return point(side >= 0 and 17 or -17, -8)
	end

	model.Parent = workspace
	return plot
end

-- Show/hide the claim pad (hidden while the plot is owned).
function PlotBuilder.setClaimPadVisible(plot, visible)
	plot.claimPad.Transparency = visible and 0 or 1
	plot.claimPad.CanTouch = visible
	plot.claimPad.CanCollide = visible -- customers walk right through where it was
	local gui = plot.claimLabel and plot.claimLabel:FindFirstAncestorOfClass("BillboardGui")
	if gui then
		gui.Enabled = visible
	end
end

function PlotBuilder.setOwnerSign(plot, text)
	plot.ownerSignLabel.Text = text
end

-- Remove all built departments (called when a plot is released).
function PlotBuilder.clearSections(plot)
	plot.sectionsFolder:ClearAllChildren()
	plot.shelfPositions = {}
end

return PlotBuilder
