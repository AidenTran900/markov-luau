--!strict
--!native
--!optimize 2
local Grid = require(script.Parent.Parent.Grid)
local Node = require(script.Parent.Parent.Node)
local ScopeMod = require(script.Parent.Parent.Model.Scope)
local Contract = require(script.Parent.Parent.Model.Contract)
local Palette = require(script.Parent.Parent.Symbol.Palette)

--[=[
	@class ScopeNode
]=]
local ScopeNode = {}

export type ScopeOptions = {
	Private: { Palette.SymbolId }?,
	Ensures: { Contract.Check }?,
	Name: string?,
}

export type ScopeData = {
	Nodes: { Node.Node },
	N: number,
	LocalGrid: Grid.Grid,
	Private: { Palette.SymbolId }?,
	Ensures: { Contract.Check }?,
	Name: string?,
	Active: ScopeMod.Scope?,
}

--[=[
	Creates a new Scope node, grouping nodes under an independent coordinate and symbol scope.
	@param localGrid table -- The isolated grid instance for this scope.
	@param children table -- The child nodes executing within this scope.
	@param options table? -- Optional metadata, including contract assertions and private symbols.
	@return table -- The constructed Scope node.
]=]
function ScopeNode.New(localGrid: Grid.Grid, children: { Node.Node }, options: ScopeOptions?): Node.Node
	local opts = options or {}
	return {
		Kind = "Scope",
		Parent = nil,
		Data = {
			Nodes = children,
			N = 0,
			LocalGrid = localGrid,
			Private = opts.Private,
			Ensures = opts.Ensures,
			Name = opts.Name,
			Active = nil,
		} :: ScopeData,
	}
end

local function resetChildren(data: ScopeData, dispatch: Node.Dispatch)
	for _, child in data.Nodes do
		dispatch[child.Kind].Reset(child, dispatch)
	end
	data.N = 0
end

local impl: Node.NodeImpl = {
	Reset = function(node: Node.Node, dispatch: Node.Dispatch)
		local data = node.Data :: ScopeData
		resetChildren(data, dispatch)
		data.Active = nil
	end,
	Go = function(node: Node.Node, ip: Node.InterpreterState, dispatch: Node.Dispatch): boolean
		local data = node.Data :: ScopeData
		if data.Active == nil then
			data.Active = ScopeMod.Enter(ip, data.LocalGrid)
		end

		while data.N < #data.Nodes do
			local child = data.Nodes[data.N + 1]
			if Node.BranchKinds[child.Kind] then
				ip.Current = child
			end
			if dispatch[child.Kind].Go(child, ip, dispatch) then
				return true
			end
			data.N += 1
		end

		if data.Ensures then
			Contract.Assert(data.Ensures, { Grid = ip.Grid :: any, Private = data.Private }, data.Name or "scope")
		end
		
		ScopeMod.Exit(ip, data.Active :: ScopeMod.Scope)
		data.Active = nil

		ip.Current = node.Parent
		resetChildren(data, dispatch)
		return false
	end,
}
ScopeNode.Impl = impl

return ScopeNode
