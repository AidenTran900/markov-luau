--!strict
--!native
--!optimize 2
local Grid = require(script.Parent.Parent.Grid)
local Rule = require(script.Parent.Parent.Rule)
local Node = require(script.Parent.Parent.Node)
local Field = require(script.Parent.Field)
local Observation = require(script.Parent.Parent.Inference.Observation)
local RuleNode = require(script.Parent.RuleNode)

local One = {}

function One.New(
	config: RuleNode.RuleNodeConfig,
	grid: Grid.Grid,
	parentSymmetry: { boolean }
): Node.Node
	local data = RuleNode.New(config, grid, parentSymmetry, true)
	return { Kind = "One", Parent = nil, Data = data }
end

local function apply(
	grid: Grid.Grid,
	ip: Node.InterpreterState,
	rule: Rule.Rule,
	x: number,
	y: number,
	z: number
)
	local out = rule.Output
	local state = grid.State
	local mx, my = grid.MX, grid.MY
	local i = 0

	for dz = 0, rule.OMZ - 1 do
		local zOffset = (z + dz) * my

		for dy = 0, rule.OMY - 1 do
			local yOffset = (y + dy + zOffset) * mx

			for dx = 0, rule.OMX - 1 do
				local newValue = buffer.readu8(out, i)

				if newValue ~= 0xff then
					local si = x + dx + yOffset
					local oldValue = buffer.readu8(state, si)

					if newValue ~= oldValue then
						buffer.writeu8(state, si, newValue)
						table.insert(ip.Changes, si)
					end
				end

				i += 1
			end
		end
	end
end

local function randomMatch(
	data: RuleNode.RuleNodeData,
	grid: Grid.Grid,
	ip: Node.InterpreterState): (number,
	number,
	number,
	number
)
	local rules = data.Rules
	local matchMask = data.MatchMask :: { buffer }

	if data.Potentials then
		if (data.Observations or data.ObservationsExternalName) and Observation.IsGoalReached(grid.State, data.Future :: { [number]: number }) then
			data.FutureComputed = false

			return 0, -1, -1, -1
		end

		local max, argmax = -1000.0, 0
		local firstHeuristic, firstHeuristicComputed = 0.0, false
		local k = 1
		while k <= data.MatchCount do
			local m = data.Matches[k]
			local i = Grid.Index(grid, m.X, m.Y, m.Z)

			if not Grid.Matches(grid, rules[m.R], m.X, m.Y, m.Z) then
				buffer.writeu8(matchMask[m.R], i, 0)
				data.Matches[k] = data.Matches[data.MatchCount]
				data.MatchCount -= 1
			else
				local heuristic = Field.DeltaPointwise(grid.State, rules[m.R], m.X, m.Y, m.Z, data.Fields, data.Potentials :: { { [number]: number } }, grid.MX, grid.MY)

				if heuristic ~= nil then
					local h = heuristic :: number

					if not firstHeuristicComputed then
						firstHeuristic = h
						firstHeuristicComputed = true
					end

					local u = ip.Random:NextNumber()
					local key = if data.Temperature > 0 then 
						u ^ math.exp((h - firstHeuristic) / data.Temperature) 
					else 
						-h + 0.001 * u

					if key > max then
						max = key
						argmax = k
					end
				end

				k += 1
			end
		end

		if argmax >= 1 then
			local m = data.Matches[argmax]

			return m.R, m.X, m.Y, m.Z
		end

		return 0, -1, -1, -1
	end

	while data.MatchCount > 0 do
		local matchIndex = ip.Random:Next(data.MatchCount) + 1
		local m = data.Matches[matchIndex]
		local i = Grid.Index(grid, m.X, m.Y, m.Z)

		buffer.writeu8(matchMask[m.R], i, 0)
		data.Matches[matchIndex] = data.Matches[data.MatchCount]
		data.MatchCount -= 1

		if Grid.Matches(grid, rules[m.R], m.X, m.Y, m.Z) then
			return m.R, m.X, m.Y, m.Z
		end
	end

	return 0, -1, -1, -1
end

local oneImpl: Node.NodeImpl = {
	Reset = function(node: Node.Node, _dispatch: Node.Dispatch)
		local data = node.Data :: RuleNode.RuleNodeData
		RuleNode.Reset(data)

		if data.MatchCount ~= 0 then
			for _, m in data.MatchMask :: { buffer } do
				buffer.fill(m, 0, 0, buffer.len(m))
			end

			data.MatchCount = 0
		end

	end,
	Go = function(node: Node.Node, ip: Node.InterpreterState, _dispatch: Node.Dispatch): boolean
		local data = node.Data :: RuleNode.RuleNodeData
		if not RuleNode.Go(data, ip.Grid, ip, RuleNode.Add, false) then
			return false
		end

		data.LastMatchedTurn = ip.Counter

		if data.Trajectory then
			local traj = data.Trajectory :: { buffer }

			if data.Counter >= #traj then
				return false
			end

			local frame = traj[data.Counter + 1]
			buffer.copy(ip.Grid.State, 0, frame, 0, buffer.len(frame))
			data.Counter += 1

			return true
		end

		local r, x, y, z = randomMatch(data, ip.Grid, ip)
		if r == 0 then
			return false
		end

		data.Last[r] = true
		apply(ip.Grid, ip, data.Rules[r], x, y, z)

		if ip.Trace then
			ip.Trace({ Step = ip.Counter, Kind = "One", RuleId = r, X = x, Y = y, Z = z })
		end

		data.Counter += 1

		return true
	end,
}
One.Impl = oneImpl

return One
