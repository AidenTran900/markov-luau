--!strict
--!native
--!optimize 2
local Grid = require(script.Parent.Grid)
local Node = require(script.Parent.Node)
local Random = require(script.Parent.Util.Random)

local Interpreter = {}

export type InterpreterState = Node.InterpreterState

local function wrapRoot(model: Node.Node): Node.Node
	if Node.BranchKinds[model.Kind] then
		return model
	end
	return { Kind = "Markov", Parent = nil, Data = { Nodes = { model }, N = 0 } }
end

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
