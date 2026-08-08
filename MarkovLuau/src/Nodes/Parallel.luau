--!strict
--!native
--!optimize 2
local Grid = require(script.Parent.Parent.Grid)
local Node = require(script.Parent.Parent.Node)
local RuleNode = require(script.Parent.RuleNode)

local Parallel = {}

export type ParallelData = {
	Base: RuleNode.RuleNodeData,
	NewState: buffer,
}

function Parallel.New(
	config: RuleNode.RuleNodeConfig,
	grid: Grid.Grid,
	parentSymmetry: { boolean }
): Node.Node
	local data = RuleNode.New(config, grid, parentSymmetry)
	local cellCount = grid.MX * grid.MY * grid.MZ
	local pdata: ParallelData = { Base = data, NewState = buffer.create(cellCount) }

	return { Kind = "Parallel", Parent = nil, Data = pdata }
end

local parallelImpl: Node.NodeImpl = {
	Reset = function(node: Node.Node, _dispatch: Node.Dispatch)
		RuleNode.Reset((node.Data :: ParallelData).Base)
	end,
	Go = function(node: Node.Node, ip: Node.InterpreterState, _dispatch: Node.Dispatch): boolean
		local pdata = node.Data :: ParallelData
		local data = pdata.Base
		local grid = ip.Grid

		local addFn: RuleNode.AddFn = function(d: RuleNode.RuleNodeData, g: Grid.Grid, interp: Node.InterpreterState, r: number, x: number, y: number, z: number, _maskr: buffer?)
			local rule = d.Rules[r]

			if interp.Random:NextNumber() > rule.P then
				return
			end

			d.Last[r] = true
			local out = rule.Output
			local state = g.State
			local mx, my = g.MX, g.MY
			local i = 0

			for dz = 0, rule.OMZ - 1 do
				local zOffset = (z + dz) * my

				for dy = 0, rule.OMY - 1 do
					local yOffset = (y + dy + zOffset) * mx

					for dx = 0, rule.OMX - 1 do
						local newvalue = buffer.readu8(out, i)

						if newvalue ~= 0xff then
							local idi = x + dx + yOffset

							if newvalue ~= buffer.readu8(state, idi) then
								buffer.writeu8(pdata.NewState, idi, newvalue)
								table.insert(interp.Changes, idi)
							end
						end

						i += 1
					end
				end
			end

			d.MatchCount += 1
		end

		if not RuleNode.Go(data, grid, ip, addFn, false) then
			return false
		end

		for n = ip.First[ip.Counter + 1] + 1, #ip.Changes do
			local i = ip.Changes[n]
			buffer.writeu8(grid.State, i, buffer.readu8(pdata.NewState, i))
		end

		data.Counter += 1

		return data.MatchCount > 0
	end,
}
Parallel.Impl = parallelImpl

return Parallel
