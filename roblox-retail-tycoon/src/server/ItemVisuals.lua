--[[
	ItemVisuals
	-----------
	Builds small multi-part models for every item so products look like
	products instead of solid cubes. Each item's `shape`, `color`, and
	`accent` come from GameConfig.Items.

	buildModel(itemId, options) -> Model (PrimaryPart set)
	  options.anchored : true for shelf displays, false for carried items
	  options.scale    : overall size multiplier (default 1)

	Models are built around the origin and positioned by the caller with
	model:PivotTo(cframe). Unanchored parts are welded to the primary.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local GameConfig = require(ReplicatedStorage.Shared.GameConfig)

local ItemVisuals = {}

-- one part of a model; offset/size get multiplied by the scale later
local function p(shape, size, offset, color, material, angles)
	return {
		shape = shape, -- "Block" | "Ball" | "Cylinder" | "Wedge"
		size = size,
		offset = offset,
		color = color,
		material = material,
		angles = angles, -- optional Vector3 of degrees
	}
end

-- Returns a list of part specs for an item. c = main color, a = accent.
local function specsFor(item)
	local c, a = item.color, item.accent
	local shape = item.shape

	if shape == "sphere" then
		return {
			p("Ball", Vector3.new(1.5, 1.5, 1.5), Vector3.new(0, 0, 0), c),
			p("Cylinder", Vector3.new(0.5, 0.18, 0.18), Vector3.new(0, 0.85, 0), a, nil, Vector3.new(0, 0, 90)),
		}
	elseif shape == "cluster" then
		return {
			p("Ball", Vector3.new(0.9, 0.9, 0.9), Vector3.new(0, 0, 0), c),
			p("Ball", Vector3.new(0.8, 0.8, 0.8), Vector3.new(0.45, -0.2, 0.2), c),
			p("Ball", Vector3.new(0.8, 0.8, 0.8), Vector3.new(-0.45, -0.2, -0.1), c),
			p("Ball", Vector3.new(0.7, 0.7, 0.7), Vector3.new(0, -0.45, 0.35), c),
			p("Cylinder", Vector3.new(0.5, 0.15, 0.15), Vector3.new(0, 0.55, 0), a, nil, Vector3.new(0, 0, 90)),
		}
	elseif shape == "crescent" then -- banana / croissant: three angled segments
		return {
			p("Block", Vector3.new(0.45, 0.45, 0.9), Vector3.new(-0.5, 0, 0.1), c, nil, Vector3.new(0, 35, 0)),
			p("Block", Vector3.new(0.45, 0.45, 1.0), Vector3.new(0, 0.12, -0.15), c),
			p("Block", Vector3.new(0.45, 0.45, 0.9), Vector3.new(0.5, 0, 0.1), c, nil, Vector3.new(0, -35, 0)),
		}
	elseif shape == "carrot" then
		return {
			p("Cylinder", Vector3.new(1.4, 0.55, 0.55), Vector3.new(0, -0.1, 0), c, nil, Vector3.new(0, 0, 90)),
			p("Cylinder", Vector3.new(0.5, 0.25, 0.25), Vector3.new(0, 0.85, 0), a, nil, Vector3.new(0, 0, 90)),
		}
	elseif shape == "box" then
		return {
			p("Block", Vector3.new(1.1, 1.5, 0.5), Vector3.new(0, 0, 0), c),
			p("Block", Vector3.new(1.12, 0.5, 0.52), Vector3.new(0, 0.15, 0), a),
		}
	elseif shape == "bag" then
		return {
			p("Block", Vector3.new(1.1, 1.3, 0.6), Vector3.new(0, 0, 0), c, Enum.Material.Fabric),
			p("Block", Vector3.new(1.2, 0.18, 0.25), Vector3.new(0, 0.75, 0), a),
		}
	elseif shape == "carton" then
		return {
			p("Block", Vector3.new(0.8, 1.3, 0.8), Vector3.new(0, 0, 0), c),
			p("Wedge", Vector3.new(0.8, 0.4, 0.4), Vector3.new(0, 0.85, -0.2), a),
			p("Wedge", Vector3.new(0.8, 0.4, 0.4), Vector3.new(0, 0.85, 0.2), a, nil, Vector3.new(0, 180, 0)),
		}
	elseif shape == "bottle" then
		return {
			p("Cylinder", Vector3.new(1.2, 0.75, 0.75), Vector3.new(0, 0, 0), c, nil, Vector3.new(0, 0, 90)),
			p("Cylinder", Vector3.new(0.35, 0.4, 0.4), Vector3.new(0, 0.78, 0), a, nil, Vector3.new(0, 0, 90)),
		}
	elseif shape == "can" then
		return {
			p("Cylinder", Vector3.new(1.1, 0.8, 0.8), Vector3.new(0, 0, 0), c, nil, Vector3.new(0, 0, 90)),
			p("Cylinder", Vector3.new(0.12, 0.82, 0.82), Vector3.new(0, 0.61, 0), a, Enum.Material.Metal, Vector3.new(0, 0, 90)),
		}
	elseif shape == "jar" then
		return {
			p("Cylinder", Vector3.new(0.9, 0.85, 0.85), Vector3.new(0, 0, 0), c, nil, Vector3.new(0, 0, 90)),
			p("Cylinder", Vector3.new(0.25, 0.9, 0.9), Vector3.new(0, 0.58, 0), a, nil, Vector3.new(0, 0, 90)),
		}
	elseif shape == "loaf" then
		return {
			p("Block", Vector3.new(1.5, 0.7, 0.8), Vector3.new(0, -0.15, 0), c),
			p("Cylinder", Vector3.new(1.5, 0.75, 0.75), Vector3.new(0, 0.2, 0), a, nil, Vector3.new(0, 0, 90)),
		}
	elseif shape == "tube" then
		return {
			p("Cylinder", Vector3.new(1.2, 0.4, 0.4), Vector3.new(0, 0, 0), c, nil, Vector3.new(90, 0, 0)),
			p("Cylinder", Vector3.new(0.25, 0.42, 0.42), Vector3.new(0, 0, 0.7), a, nil, Vector3.new(90, 0, 0)),
		}
	elseif shape == "wedge" then
		return {
			p("Wedge", Vector3.new(0.9, 0.9, 1.4), Vector3.new(0, 0, 0), c),
			p("Block", Vector3.new(0.92, 0.2, 1.42), Vector3.new(0, -0.36, 0), a),
		}
	elseif shape == "block" then
		return {
			p("Block", Vector3.new(1.2, 0.7, 0.9), Vector3.new(0, 0, 0), c),
			p("Block", Vector3.new(1.22, 0.25, 0.92), Vector3.new(0, 0.1, 0), a),
		}
	elseif shape == "tray" then -- meat on a white foam tray
		return {
			p("Block", Vector3.new(1.5, 0.25, 1.1), Vector3.new(0, -0.3, 0), c),
			p("Block", Vector3.new(1.2, 0.45, 0.85), Vector3.new(0, 0.05, 0), a),
		}
	elseif shape == "tub" then
		return {
			p("Cylinder", Vector3.new(0.9, 1.1, 1.1), Vector3.new(0, 0, 0), c, nil, Vector3.new(0, 0, 90)),
			p("Cylinder", Vector3.new(0.2, 1.15, 1.15), Vector3.new(0, 0.55, 0), a, nil, Vector3.new(0, 0, 90)),
		}
	elseif shape == "cylinder" then
		return {
			p("Cylinder", Vector3.new(0.9, 1.0, 1.0), Vector3.new(0, 0, 0), c, nil, Vector3.new(0, 0, 90)),
		}
	elseif shape == "cake" then -- also used for donuts
		return {
			p("Cylinder", Vector3.new(0.6, 1.3, 1.3), Vector3.new(0, 0, 0), c, nil, Vector3.new(0, 0, 90)),
			p("Cylinder", Vector3.new(0.18, 1.32, 1.32), Vector3.new(0, 0.39, 0), a, nil, Vector3.new(0, 0, 90)),
		}
	elseif shape == "muffin" then
		return {
			p("Cylinder", Vector3.new(0.6, 0.8, 0.8), Vector3.new(0, -0.25, 0), a, nil, Vector3.new(0, 0, 90)),
			p("Ball", Vector3.new(1.05, 0.85, 1.05), Vector3.new(0, 0.3, 0), c),
		}
	end

	-- unknown shape: plain cube fallback
	return { p("Block", Vector3.new(1.2, 1.2, 1.2), Vector3.new(0, 0, 0), c) }
end

function ItemVisuals.buildModel(itemId, options)
	options = options or {}
	local scale = options.scale or 1
	local anchored = options.anchored == true

	local item = GameConfig.Items[itemId]
	local model = Instance.new("Model")
	model.Name = itemId

	local primary
	for index, spec in ipairs(specsFor(item)) do
		local part
		if spec.shape == "Wedge" then
			part = Instance.new("WedgePart")
		else
			part = Instance.new("Part")
			if spec.shape == "Ball" then
				part.Shape = Enum.PartType.Ball
			elseif spec.shape == "Cylinder" then
				part.Shape = Enum.PartType.Cylinder
			end
		end
		part.Size = spec.size * scale
		part.Color = spec.color
		part.Material = spec.material or Enum.Material.SmoothPlastic
		part.TopSurface = Enum.SurfaceType.Smooth
		part.BottomSurface = Enum.SurfaceType.Smooth
		part.CanCollide = false
		part.CanQuery = false
		part.Massless = true
		part.Anchored = anchored

		local angles = spec.angles or Vector3.zero
		part.CFrame = CFrame.new(spec.offset * scale)
			* CFrame.Angles(math.rad(angles.X), math.rad(angles.Y), math.rad(angles.Z))
		part.Parent = model

		if index == 1 then
			primary = part
		elseif not anchored then
			local weld = Instance.new("WeldConstraint")
			weld.Part0 = primary
			weld.Part1 = part
			weld.Parent = part
		end
	end

	model.PrimaryPart = primary
	return model
end

return ItemVisuals
