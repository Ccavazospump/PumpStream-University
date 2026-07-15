--[[
	Economy
	-------
	Player cash, shown on the leaderboard via leaderstats.
]]

local Economy = {}

function Economy.setup(player, startingCash)
	local leaderstats = Instance.new("Folder")
	leaderstats.Name = "leaderstats"

	local cash = Instance.new("IntValue")
	cash.Name = "Cash"
	cash.Value = startingCash
	cash.Parent = leaderstats

	leaderstats.Parent = player
end

function Economy.getCash(player)
	local leaderstats = player:FindFirstChild("leaderstats")
	local cash = leaderstats and leaderstats:FindFirstChild("Cash")
	return cash and cash.Value or 0
end

function Economy.addCash(player, amount)
	local leaderstats = player:FindFirstChild("leaderstats")
	local cash = leaderstats and leaderstats:FindFirstChild("Cash")
	if cash then
		cash.Value = math.max(0, cash.Value + amount)
	end
end

-- Returns true (and deducts) only if the player can afford it.
function Economy.trySpend(player, amount)
	if Economy.getCash(player) >= amount then
		Economy.addCash(player, -amount)
		return true
	end
	return false
end

return Economy
