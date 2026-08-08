--!strict
-- analogue of MarkovJuniorWeb's src/web/state.ts
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local NodeMod = require(ReplicatedStorage.MarkovJunior.Node)
local Interpreter = require(ReplicatedStorage.MarkovJunior.Interpreter)
local ConvolutionMod = require(ReplicatedStorage.MarkovJunior.Nodes.Convolution)
local WFCNodeMod = require(ReplicatedStorage.MarkovJunior.Nodes.WFC.WFCNode)

local State = {}

export type NodeInfo = {
	Node: NodeMod.Node,
	Depth: number,
}

local function isBranch(node: NodeMod.Node): boolean
	return NodeMod.BranchKinds[node.Kind] == true
end
State.IsBranch = isBranch

function State.Traverse(root: NodeMod.Node): { NodeInfo }
	local list: { NodeInfo } = {}

	local function visit(node: NodeMod.Node, depth: number)
		table.insert(list, { Node = node, Depth = depth })
		if isBranch(node) then
			local data = node.Data :: NodeMod.BranchData
			for _, child in data.Nodes do
				visit(child, depth + 1)
			end
		end
	end

	visit(root, 0)
	return list
end

function State.CurrentNode(ip: Interpreter.InterpreterState): NodeMod.Node?
	local br = ip.Current
	if br == nil then
		return nil
	end
	local data = br.Data :: NodeMod.BranchData
	if data.N < 0 or data.N >= #data.Nodes then
		return br
	end
	return data.Nodes[data.N + 1]
end

function State.CurrentIndex(nodes: { NodeInfo }, ip: Interpreter.InterpreterState): number
	local current = State.CurrentNode(ip)
	if current == nil then
		return -1
	end
	for i, info in nodes do
		if info.Node == current then
			return i
		end
	end
	return -1
end

function State.Name(node: NodeMod.Node): string
	local kind = node.Kind
	if kind == "One" then
		return "one"
	elseif kind == "All" then
		return "all"
	elseif kind == "Parallel" then
		return "prl"
	elseif kind == "Convolution" then
		local data = node.Data :: ConvolutionMod.ConvolutionData
		return `convolution-{string.lower(data.Neighborhood)}`
	elseif kind == "Overlap" then
		local data = node.Data :: WFCNodeMod.WFCData
		return `wfc-overlap: {string.lower(data.Name or "")}`
	elseif kind == "TileModel" then
		local data = node.Data :: WFCNodeMod.WFCData
		return `wfc-tile: {string.lower(data.Name or "")}`
	end
	return string.lower(kind)
end

return State
