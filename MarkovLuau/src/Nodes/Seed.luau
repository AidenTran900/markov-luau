--!strict
--!native
--!optimize 2

local Node = require(script.Parent.Parent.Node)
local Palette = require(script.Parent.Parent.Symbol.Palette)
local Scope = require(script.Parent.Parent.Model.Scope)

local SeedNode = {}

export type SeedData = {
	VoxelsName: string,
	Name: string?,
	Done: boolean,
}

function SeedNode.New(voxelsName: string, name: string?): Node.Node
	return {
		Kind = "Seed",
		Parent = nil,
		Data = { VoxelsName = voxelsName, Name = name, Done = false } :: SeedData,
	}
end

local impl: Node.NodeImpl = {
	Reset = function(node: Node.Node, _dispatch: Node.Dispatch)
		(node.Data :: SeedData).Done = false
	end,
	Go = function(node: Node.Node, ip: Node.InterpreterState, _dispatch: Node.Dispatch): boolean
		local data = node.Data :: SeedData
		if data.Done then
			return false
		end
		data.Done = true

		local voxels = ip.Fields and ip.Fields[data.VoxelsName]

		assert(voxels, `Seed "{data.Name or "?"}": no ip.Fields["{data.VoxelsName}"] supplied`)

		local grid = ip.Grid
		for index, sym in voxels do
			local localValue = Scope.SlotFixedTo(grid.Alphabet, sym :: Palette.SymbolId)

			assert(localValue, `Seed "{data.Name or "?"}": grid has no local slot for symbol id {sym}`)
			
			buffer.writeu8(grid.State, index, localValue)
			table.insert(ip.Changes, index)
		end

		return false
	end,
}
SeedNode.Impl = impl

return SeedNode
