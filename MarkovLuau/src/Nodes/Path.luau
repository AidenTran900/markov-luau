--!strict
--!native
--!optimize 2
local Grid = require(script.Parent.Parent.Grid)
local Node = require(script.Parent.Parent.Node)
local Helper = require(script.Parent.Parent.Util.Helper)
local Queue = require(script.Parent.Parent.Util.Queue)
local Random = require(script.Parent.Parent.Util.Random)
local Constants = require(script.Parent.Parent.Util.Constants)

--[=[
	@class Path
]=]
local Path = {}

export type PathData = {
	Start: number, -- wave bitmask (from=)
	Finish: number, -- wave bitmask (to=)
	Substrate: number, -- wave bitmask (on=)
	Value: number, -- 0 based color painted along the path
	Inertia: boolean,
	Longest: boolean,
	Edges: boolean,
	Vertices: boolean,
}

export type PathSpec = {
	From: string,
	To: string,
	On: string,
	Color: string?,
	Inertia: boolean?,
	Longest: boolean?,
	Edges: boolean?,
	Vertices: boolean?,
}

--[=[
	Creates a new Path node.
	@param spec table -- The path generation spec.
	@param grid table -- The grid this path node is bound to.
	@return table -- The constructed Path node.
]=]
function Path.New(
	spec: PathSpec,
	grid: Grid.Grid
): Node.Node
	local colorChar = spec.Color or string.sub(spec.From, 1, 1)
	local value = grid.Values[colorChar]
	assert(value, `Path.New: unknown color "{colorChar}"`)
	local data: PathData = {
		Start = Grid.Wave(grid, spec.From),
		Finish = Grid.Wave(grid, spec.To),
		Substrate = Grid.Wave(grid, spec.On),
		Value = value,
		Inertia = spec.Inertia or false,
		Longest = spec.Longest or false,
		Edges = spec.Edges or false,
		Vertices = spec.Vertices or false,
	}

	return { Kind = "Path", Parent = nil, Data = data }
end



local function pickDirection(
	x: number,
	y: number,
	z: number,
	dx: number,
	dy: number,
	dz: number,
	generations: { [number]: number },
	rng: Random.Rng,
	mx: number,
	my: number,
	mz: number,
	edges: boolean,
	vertices: boolean,
	inertia: boolean
): (number, number, number)

	local g = generations[x + (y + z * my) * mx]

	local function addIfMatch(
		candidates: { { number } },
		ddx: number,
		ddy: number,
		ddz: number
	)
		if generations[x + ddx + (y + ddy + (z + ddz) * my) * mx] == g - 1 then
			table.insert(candidates, { ddx, ddy, ddz })
		end
	end

	if not vertices and not edges then

		if dx ~= 0 or dy ~= 0 or dz ~= 0 then
			local cx, cy, cz = x + dx, y + dy, z + dz
			if
				inertia
				and cx >= 0
				and cy >= 0
				and cz >= 0
				and cx < mx
				and cy < my
				and cz < mz
				and generations[cx + (cy + cz * my) * mx] == g - 1
			then
				return dx, dy, dz
			end
		end

		local candidates: { { number } } = {}

		if x > 0 then
			addIfMatch(candidates, -1, 0, 0)
		end

		if x < mx - 1 then
			addIfMatch(candidates, 1, 0, 0)
		end

		if y > 0 then
			addIfMatch(candidates, 0, -1, 0)
		end

		if y < my - 1 then
			addIfMatch(candidates, 0, 1, 0)
		end

		if z > 0 then
			addIfMatch(candidates, 0, 0, -1)
		end

		if z < mz - 1 then
			addIfMatch(candidates, 0, 0, 1)
		end

		assert(#candidates > 0, "Path: no direction candidates (generation field is inconsistent)")
		local pick = candidates[rng:Next(#candidates) + 1]

		return pick[1], pick[2], pick[3]
	end

	local candidates: { { number } } = {}
	local faces = if mz == 1 then 4 else 6

	for i = 1, faces do
		local dx2, dy2, dz2 = Constants.DIR_X[i], Constants.DIR_Y[i], Constants.DIR_Z[i]

		if x + dx2 >= 0 and x + dx2 < mx and y + dy2 >= 0 and y + dy2 < my and z + dz2 >= 0 and z + dz2 < mz then
			addIfMatch(candidates, dx2, dy2, dz2)
		end
	end

	if edges then
		local edgeCount = if mz == 1 then 4 else 12

		for i = 1, edgeCount do
			local dx2, dy2, dz2 = Constants.EDGE_X[i], Constants.EDGE_Y[i], Constants.EDGE_Z[i]

			if x + dx2 >= 0 and x + dx2 < mx and y + dy2 >= 0 and y + dy2 < my and z + dz2 >= 0 and z + dz2 < mz then
				addIfMatch(candidates, dx2, dy2, dz2)
			end
		end
	end

	if vertices and mz > 1 then

		for i = 1, 8 do
			local dx2, dy2, dz2 = Constants.VERT_X[i], Constants.VERT_Y[i], Constants.VERT_Z[i]

			if x + dx2 >= 0 and x + dx2 < mx and y + dy2 >= 0 and y + dy2 < my and z + dz2 >= 0 and z + dz2 < mz then
				addIfMatch(candidates, dx2, dy2, dz2)
			end
		end
	end

	if inertia and (dx ~= 0 or dy ~= 0 or dz ~= 0) then
		local maxScalar = -4.0
		local best = { -1, -1, -1 }

		for _, c in candidates do
			local noise = 0.1 * rng:NextNumber()
			local cos = (c[1] * dx + c[2] * dy + c[3] * dz) / math.sqrt((c[1] ^ 2 + c[2] ^ 2 + c[3] ^ 2) * (dx ^ 2 + dy ^ 2 + dz ^ 2))

			if cos + noise > maxScalar then
				maxScalar = cos + noise
				best = c
			end
		end

		return best[1], best[2], best[3]
	end

	assert(#candidates > 0, "Path: no direction candidates (generation field is inconsistent)")
	local pick = candidates[rng:Next(#candidates) + 1]

	return pick[1], pick[2], pick[3]
end

local pathImpl: Node.NodeImpl = {
	Reset = function(_node: Node.Node, _dispatch: Node.Dispatch) end,
	Go = function(node: Node.Node, ip: Node.InterpreterState, _dispatch: Node.Dispatch): boolean
		local data = node.Data :: PathData
		local grid = ip.Grid
		local mx, my, mz = grid.MX, grid.MY, grid.MZ
		local cellCount = mx * my * mz

		local generations = Helper.Fill0(cellCount, -1)
		local frontier = Queue.New()
		local startPositions: { { X: number, Y: number, Z: number } } = {}

		for i = 0, cellCount - 1 do
			local s = buffer.readu8(grid.State, i)
			local x = i % mx
			local y = (i // mx) % my
			local z = i // (mx * my)

			if bit32.band(data.Start, bit32.lshift(1, s)) ~= 0 then
				table.insert(startPositions, { X = x, Y = y, Z = z })
			end

			if bit32.band(data.Finish, bit32.lshift(1, s)) ~= 0 then
				generations[i] = 0
				Queue.Push(frontier, { T = 0, X = x, Y = y, Z = z })
			end
		end

		if #startPositions == 0 or Queue.IsEmpty(frontier) then

			return false
		end

		local function push(
			t: number,
			x: number,
			y: number,
			z: number
		)
			local i = Grid.Index(grid, x, y, z)
			local v = buffer.readu8(grid.State, i)
			local inSubstrate = bit32.band(data.Substrate, bit32.lshift(1, v)) ~= 0

			if generations[i] == -1 and (inSubstrate or bit32.band(data.Start, bit32.lshift(1, v)) ~= 0) then
				if inSubstrate then
					Queue.Push(frontier, { T = t, X = x, Y = y, Z = z })
				end

				generations[i] = t
			end
		end

		while not Queue.IsEmpty(frontier) do
			local item = Queue.Pop(frontier) :: { T: number, X: number, Y: number, Z: number }
			local faces = if mz == 1 then 4 else 6
			for i = 1, faces do
				push(item.T + 1, item.X + Constants.DIR_X[i], item.Y + Constants.DIR_Y[i], item.Z + Constants.DIR_Z[i])
			end

			if data.Edges then
				local edgeCount = if mz == 1 then 4 else 12
				for i = 1, edgeCount do
					push(item.T + 1, item.X + Constants.EDGE_X[i], item.Y + Constants.EDGE_Y[i], item.Z + Constants.EDGE_Z[i])
				end
			end

			if data.Vertices and mz > 1 then
				for i = 1, 8 do
					push(item.T + 1, item.X + Constants.VERT_X[i], item.Y + Constants.VERT_Y[i], item.Z + Constants.VERT_Z[i])
				end
			end
		end

		local anyReachable = false
		for _, p in startPositions do
			if generations[Grid.Index(grid, p.X, p.Y, p.Z)] > 0 then
				anyReachable = true
				break
			end
		end

		if not anyReachable then
			return false
		end

		local localRandom = Random.New(ip.Random:NextSeed())
		local min, max = mx * my * mz, -2.0
		local argmin, argmax = { X = -1, Y = -1, Z = -1 }, { X = -1, Y = -1, Z = -1 }

		for _, p in startPositions do
			local g = generations[Grid.Index(grid, p.X, p.Y, p.Z)]

			if g ~= -1 then
				local dg = g + 0.1 * localRandom:NextNumber()

				if dg < min then
					min = dg
					argmin = p
				end

				if dg > max then
					max = dg
					argmax = p
				end
			end
		end

		local pen = if data.Longest then argmax else argmin
		local penx, peny, penz = pen.X, pen.Y, pen.Z
		local dirx, diry, dirz = pickDirection(penx, peny, penz, 0, 0, 0, generations, localRandom, mx, my, mz, data.Edges, data.Vertices, data.Inertia)
		penx += dirx
		peny += diry
		penz += dirz

		while generations[Grid.Index(grid, penx, peny, penz)] ~= 0 do
			local i = Grid.Index(grid, penx, peny, penz)
			buffer.writeu8(grid.State, i, data.Value)
			table.insert(ip.Changes, i)
			dirx, diry, dirz = pickDirection(penx, peny, penz, dirx, diry, dirz, generations, localRandom, mx, my, mz, data.Edges, data.Vertices, data.Inertia)
			penx += dirx
			peny += diry
			penz += dirz
		end

		return true
	end,
}
Path.Impl = pathImpl

return Path
