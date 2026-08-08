--!strict
--!native
--!optimize 2
local Node = require(script.Parent.Parent.Node)

local Marker = {}

function Marker.New(name: string): Node.Node
	return { Kind = "Marker", Parent = nil, Data = { Name = name } }
end

local impl: Node.NodeImpl = {
	Reset = function(node: Node.Node, dispatch: Node.Dispatch)
		-- Nothing to reset
	end,
	Go = function(node: Node.Node, ip: Node.InterpreterState, dispatch: Node.Dispatch): boolean
		local data = node.Data :: { Name: string }
		if ip.OnMarker then
			ip.OnMarker(data.Name)
		end

		-- Return false so the branch continues to the next child in the same step
		return false
	end,
}
Marker.Impl = impl

return Marker
