--!strict
--!native
--!optimize 2
local Grid = require(script.Parent.Parent.Grid)
local Node = require(script.Parent.Parent.Node)
local Field = require(script.Parent.Field)
local RuleNode = require(script.Parent.RuleNode)

local All = {}

function All.New(
	config: RuleNode.RuleNodeConfig,
	grid: Grid.Grid,
	parentSymmetry: { boolean }
): Node.Node
	local data = RuleNode.New(config, grid, parentSymmetry, true)

	return { Kind = "All", Parent = nil, Data = data }
end

local function fit(
	data: RuleNode.RuleNodeData,
	grid: Grid.Grid,
	ip: Node.InterpreterState,
	r: number,
	x: number,
	y: number,
	z: number
)
	local rule = data.Rules[r]
	local out = rule.Output
	local mask = grid.Mask
	local mx, my = grid.MX, grid.MY
	local i = 0

	for dz = 0, rule.OMZ - 1 do
		local zOffset = (z + dz) * my

		for dy = 0, rule.OMY - 1 do
			local yOffset = (y + dy + zOffset) * mx

			for dx = 0, rule.OMX - 1 do
				local value = buffer.readu8(out, i)

				if value ~= 0xff and buffer.readu8(mask, x + dx + yOffset) ~= 0 then
					return
				end

				i += 1
			end
		end
	end

	data.Last[r] = true

	if ip.Trace then
		ip.Trace({ Step = ip.Counter, Kind = "All", RuleId = r, X = x, Y = y, Z = z })
	end
	
	local state = grid.State
	i = 0

	for dz = 0, rule.OMZ - 1 do
		local zOffset = (z + dz) * my

		for dy = 0, rule.OMY - 1 do
			local yOffset = (y + dy + zOffset) * mx

			for dx = 0, rule.OMX - 1 do
				local newvalue = buffer.readu8(out, i)

				if newvalue ~= 0xff then
					local idi = x + dx + yOffset
					buffer.writeu8(mask, idi, 1)
					buffer.writeu8(state, idi, newvalue)
					table.insert(ip.Changes, idi)
				end

				i += 1
			end
		end
	end
end

local allImpl: Node.NodeImpl = {
	Reset = function(node: Node.Node, _dispatch: Node.Dispatch)
		RuleNode.Reset(node.Data :: RuleNode.RuleNodeData)
	end,
	Go = function(node: Node.Node, ip: Node.InterpreterState, _dispatch: Node.Dispatch): boolean
		local data = node.Data :: RuleNode.RuleNodeData
		local grid = ip.Grid

		if not RuleNode.Go(data, grid, ip, RuleNode.Add, true) then
			return false
		end

		data.LastMatchedTurn = ip.Counter

		if data.Trajectory then
			local traj = data.Trajectory :: { buffer }
			if data.Counter >= #traj then
				return false
			end

			local frame = traj[data.Counter + 1]
			buffer.copy(grid.State, 0, frame, 0, buffer.len(frame))
			data.Counter += 1

			return true
		end

		if data.MatchCount == 0 then
			return false
		end

		local matchMask = data.MatchMask :: { buffer }

		if data.Potentials then
			local ordered: { { M: number, Key: number } } = {}
			local firstHeuristic, firstHeuristicComputed = 0.0, false

			for m = 1, data.MatchCount do
				local match = data.Matches[m]
				local heuristic = Field.DeltaPointwise(
					grid.State, 
					data.Rules[match.R], 
					match.X, 
					match.Y, 
					match.Z, 
					data.Fields, 
					data.Potentials :: { { [number]: number } }, 
					grid.MX, 
					grid.MY
				)

				if heuristic ~= nil then
					local h = heuristic :: number

					if not firstHeuristicComputed then
						firstHeuristic = h
						firstHeuristicComputed = true
					end

					local u = ip.Random:NextNumber()
					local key = if data.Temperature > 0 then u ^ math.exp((h - firstHeuristic) / data.Temperature) else -h + 0.001 * u
					table.insert(ordered, { M = m, Key = key })
				end
			end

			table.sort(ordered, function(a, b)
				if a.Key ~= b.Key then
					return a.Key > b.Key
				end
				return a.M < b.M
			end)

			for _, entry in ordered do
				local match = data.Matches[entry.M]
				buffer.writeu8(matchMask[match.R], Grid.Index(grid, match.X, match.Y, match.Z), 0)
				fit(data, grid, ip, match.R, match.X, match.Y, match.Z)
			end
		else
			local shuffle = ip.Random:Shuffle(data.MatchCount)

			for k = 1, #shuffle do
				local match = data.Matches[shuffle[k] + 1]
				buffer.writeu8(matchMask[match.R], Grid.Index(grid, match.X, match.Y, match.Z), 0)
				fit(data, grid, ip, match.R, match.X, match.Y, match.Z)
			end
		end

		for n = ip.First[data.LastMatchedTurn + 1] + 1, #ip.Changes do
			buffer.writeu8(grid.Mask, ip.Changes[n], 0)
		end

		data.Counter += 1
		data.MatchCount = 0

		return true
	end,
}
All.Impl = allImpl

return All
