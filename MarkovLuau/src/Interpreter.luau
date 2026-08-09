--!strict
--!native
--!optimize 2
local Grid = require(script.Parent.Grid)
local Node = require(script.Parent.Node)
local Random = require(script.Parent.Util.Random)

--[=[
	@class Interpreter
	
	Manages the state and execution of a MarkovJunior procedural generation model.
]=]
local Interpreter = {}

export type InterpreterState = Node.InterpreterState

local function wrapRoot(model: Node.Node): Node.Node
	if Node.BranchKinds[model.Kind] then
		return model
	end
	return { Kind = "Markov", Parent = nil, Data = { Nodes = { model }, N = 0 } }
end

--[=[
	Creates a new interpreter state to begin executing a model.
	@param dispatch table -- The table mapping Node types to their implementation logic.
	@param model table -- The root node of the Markov model to execute.
	@param grid table -- The 3D grid state to run the model upon.
	@param seed number -- The random seed for deterministic generation.
	@param origin boolean -- Whether to initialize the center cell with a default starting symbol (value 1).
	@return table -- The fully initialized interpreter state.
]=]
function Interpreter.NewState(
	dispatch: Node.Dispatch,
	model: Node.Node,
	grid: Grid.Grid,
	seed: number,
	origin: boolean
): InterpreterState
	local root = wrapRoot(model)
	local ip: InterpreterState = {
		Root = root,
		Current = root,
		Grid = grid,
		Random = Random.New(seed),
		Changes = {},
		First = { 0 },
		Counter = 0,
		Origin = origin,
	}

	Grid.Clear(grid)
	if origin then
		buffer.writeu8(grid.State, Grid.Index(grid, grid.MX // 2, grid.MY // 2, grid.MZ // 2), 1)
	end

	dispatch[root.Kind].Reset(root, dispatch)

	return ip
end

local function collectGrids(node: Node.Node, into: { Grid.Grid })
	local data = node.Data :: any
	local own = data.LocalGrid or data.NewGrid

	if own then
		table.insert(into, own :: Grid.Grid)
	end

	if data.Nodes then
		for _, child in data.Nodes :: { Node.Node } do
			collectGrids(child, into)
		end
	end
end

export type Snapshot = {
	Grids: { { Grid: Grid.Grid, State: buffer } },
	RandomStateHi: number,
	RandomStateLo: number,
	RandomIncHi: number,
	RandomIncLo: number,
	Counter: number,
}

--[=[
	Captures a point-in-time snapshot of the grid, random state, and node execution counter.
	Used primarily by the Time Travel and Retry systems to rollback generation to a previous point.
	@param ip table -- The current interpreter state.
	@param subtree table -- The subtree of nodes whose local grid scopes should also be snapshotted.
	@return table -- A snapshot structure holding copies of grid states and RNG seeds.
]=]
function Interpreter.Snapshot(ip: InterpreterState, subtree: Node.Node): Snapshot
	local grids: { Grid.Grid } = { ip.Grid }
	collectGrids(subtree, grids)

	local seen: { [Grid.Grid]: boolean } = {}
	local entries: { { Grid: Grid.Grid, State: buffer } } = {}

	for _, grid in grids do
		if not seen[grid] then
			seen[grid] = true
			local copy = buffer.create(buffer.len(grid.State))
			buffer.copy(copy, 0, grid.State, 0, buffer.len(grid.State))
			table.insert(entries, { Grid = grid, State = copy })
		end
	end

	return {
		Grids = entries,
		RandomStateHi = ip.Random.StateHi,
		RandomStateLo = ip.Random.StateLo,
		RandomIncHi = ip.Random.IncHi,
		RandomIncLo = ip.Random.IncLo,
		Counter = ip.Counter,
	}
end


--[=[
	Restores the interpreter to a previously captured state snapshot, rolling back all grids and RNG logic.
	@param ip table -- The current interpreter state to overwrite.
	@param dispatch table -- The node implementation dispatch table to invoke reset logic.
	@param subtree table -- The subtree of nodes to reset alongside the main interpreter state.
	@param snap table -- The snapshot data to restore from.
]=]
function Interpreter.Restore(ip: InterpreterState, dispatch: Node.Dispatch, subtree: Node.Node, snap: Snapshot)
	for _, entry in snap.Grids do
		buffer.copy(entry.Grid.State, 0, entry.State, 0, buffer.len(entry.State))
	end

	ip.Random.StateHi = snap.RandomStateHi
	ip.Random.StateLo = snap.RandomStateLo
	ip.Random.IncHi = snap.RandomIncHi
	ip.Random.IncLo = snap.RandomIncLo
	ip.Counter = snap.Counter

	dispatch[subtree.Kind].Reset(subtree, dispatch)
end

--[=[
	Advances the execution of the model by a single step.
	@param ip table -- The interpreter state holding the current execution pointer.
	@param dispatch table -- The table of node implementations.
	@return boolean -- True if the model is still executing, false if execution has finished.
]=]
function Interpreter.Step(ip: InterpreterState, dispatch: Node.Dispatch): boolean
	local current = ip.Current
	if current == nil then
		return false
	end

	dispatch[current.Kind].Go(current, ip, dispatch)
	ip.Counter += 1
	table.insert(ip.First, #ip.Changes)

	return ip.Current ~= nil
end

--[=[
	Executes a MarkovJunior model fully, driving the interpreter loop until completion or max steps.
	@param dispatch table -- The table mapping Node types to their implementation logic.
	@param model table -- The root node of the Markov model to execute.
	@param grid table -- The 3D grid state to run the model upon.
	@param seed number -- The random seed for deterministic generation.
	@param steps number? -- The maximum number of generation steps. If nil or 0, runs indefinitely.
	@param origin boolean -- Whether to automatically initialize the center cell.
	@param onFrame function? -- An optional callback invoked after every single execution step, useful for visualizers.
	@return table -- The final generated grid state.
]=]
function Interpreter.Run(
	dispatch: Node.Dispatch,
	model: Node.Node,
	grid: Grid.Grid,
	seed: number,
	steps: number?,
	origin: boolean,
	onFrame: ((InterpreterState) -> ())?
): Grid.Grid
	local ip = Interpreter.NewState(dispatch, model, grid, seed, origin)
	local maxSteps = steps or 0

	while ip.Current ~= nil and (maxSteps <= 0 or ip.Counter < maxSteps) do
		if onFrame then
			onFrame(ip)
		end
		Interpreter.Step(ip, dispatch)
	end

	if onFrame then
		onFrame(ip)
	end
	
	return ip.Grid
end

return Interpreter
