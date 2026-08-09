--!strict
--!native
--!optimize 2

-- Port of Node.cs Node/Branch/SequenceNode/MarkovNode + shared InterpreterState from Interpreter.cs

local Grid = require(script.Parent.Grid)
local Random = require(script.Parent.Util.Random)

--[=[
	@class Node
	
	Defines the fundamental Node structure that makes up a MarkovJunior model execution tree.
]=]
local Node = {}

export type Node = {
	Kind: string,
	Parent: Node?,
	Data: any,
}

export type TraceEvent = {
	Step: number,
	Kind: string, -- (One/All/Parallel/...)
	RuleId: number?, -- index
	X: number,
	Y: number,
	Z: number,
}
export type TraceSink = (TraceEvent) -> ()

export type InterpreterState = {
	Root: Node,
	Current: Node?,
	Grid: Grid.Grid,
	Random: Random.Rng,
	Changes: { number },
	First: { number },
	Counter: number,
	Origin: boolean,
	Fields: { [string]: { [number]: number } }?,
	-- nil by default, feeds a replay viewer
	Trace: TraceSink?,
	OnMarker: ((string) -> ())?,
}

export type NodeImpl = {
	Reset: (node: Node, dispatch: Dispatch) -> (),
	Go: (node: Node, ip: InterpreterState, dispatch: Dispatch) -> boolean,
}
export type Dispatch = { [string]: NodeImpl }

export type BranchData = {
	Nodes: { Node },
	N: number,
}

local BRANCH_KINDS: { [string]: boolean } = {
	Sequence = true,
	Markov = true,
	Map = true,
	Overlap = true,
	TileModel = true,
	Scope = true,
	Retry = true,
	Budget = true,
}
Node.BranchKinds = BRANCH_KINDS

--[=[
	Advances the execution of a branch node (Sequence or Markov) by invoking its children.
	@param branch table -- The branch node to execute.
	@param ip table -- The interpreter state.
	@param dispatch table -- The table containing implementation routines for each node kind.
	@return boolean -- True if a child is currently executing, false if the branch is finished.
]=]
function Node.BranchGo(branch: Node, ip: InterpreterState, dispatch: Dispatch): boolean
	local data = branch.Data :: BranchData

	while data.N < #data.Nodes do
		local child = data.Nodes[data.N + 1]

		if BRANCH_KINDS[child.Kind] then
			ip.Current = child
			data.N += 1

			if dispatch[child.Kind].Go(child, ip, dispatch) then
				return true
			end
		else
			if dispatch[child.Kind].Go(child, ip, dispatch) then
				return true
			end

			data.N += 1
		end
	end

	ip.Current = branch.Parent
	Node.BranchReset(branch, dispatch)
	return false
end

--[=[
	Resets the state of a branch node and all of its descendants recursively.
	@param branch table -- The branch node to reset.
	@param dispatch table -- The table containing implementation routines for each node kind.
]=]
function Node.BranchReset(branch: Node, dispatch: Dispatch)
	local data = branch.Data :: BranchData

	for _, child in data.Nodes do
		dispatch[child.Kind].Reset(child, dispatch)
	end

	data.N = 0
end

local sequenceImpl: NodeImpl = {
	Reset = function(node: Node, dispatch: Dispatch)
		Node.BranchReset(node, dispatch)
	end,
	Go = function(node: Node, ip: InterpreterState, dispatch: Dispatch): boolean
		return Node.BranchGo(node, ip, dispatch)
	end,
}
Node.Sequence = sequenceImpl

local markovImpl: NodeImpl = {
	Reset = function(node: Node, dispatch: Dispatch)
		Node.BranchReset(node, dispatch)
	end,
	Go = function(node: Node, ip: InterpreterState, dispatch: Dispatch): boolean
		(node.Data :: BranchData).N = 0
		return Node.BranchGo(node, ip, dispatch)
	end,
}
Node.Markov = markovImpl

return Node
