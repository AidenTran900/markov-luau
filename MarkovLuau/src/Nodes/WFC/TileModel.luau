--!strict
--!native
--!optimize 2
local Grid = require(script.Parent.Parent.Parent.Grid)
local Node = require(script.Parent.Parent.Parent.Node)
local Random = require(script.Parent.Parent.Parent.Util.Random)
local Helper = require(script.Parent.Parent.Parent.Util.Helper)
local Symmetry = require(script.Parent.Parent.Parent.Util.Symmetry)
local WFC = require(script.Parent.WFCNode)

--[=[
	@class TileModel
]=]
local TileModel = {}

export type TileSpec = {
	Name: string,
	Weight: number?,
	Voxels: { number }, -- raw (pre-Ords) voxel palette values, 1-indexed flat S*S*SZ, x fastest then y then z
}

export type NeighborSpec = {
	Left: string?,
	Right: string?,
	Top: string?,
	Bottom: string?,
}

export type TileModelConfig = {
	Periodic: boolean?,
	FullSymmetry: boolean?,
	Overlap: number?,
	OverlapZ: number?,
	S: number,
	SZ: number,
	Tiles: { TileSpec },
	Neighbors: { NeighborSpec },
	Rules: { { In: string, Out: string } }, -- Out: "tile1|tile2|..."
	Shannon: boolean?,
	Tries: number?,
	TilesetName: string?,
}

local function newTile(
	s: number,
	sz: number,
	f: (number,
	number,
	number) -> number
): { number }
	local result = table.create(s * s * sz)

	for z = 0, sz - 1 do
	for y = 0, s - 1 do
	for x = 0, s - 1 do
		result[z * s * s + y * s + x + 1] = f(x, y, z)
	end
	end
	end

	return result
end

local function zRotate(
	p: { number },
	s: number,
	sz: number
): { number }
	return newTile(s, sz, function(x, y, z)
		return p[y + (s - 1 - x) * s + z * s * s + 1]
	end)
end

local function yRotate(
	p: { number },
	s: number,
	sz: number
): { number }
	return newTile(s, sz, function(x, y, z)
		return p[z + y * s + (s - 1 - x) * s * s + 1]
	end)
end

local function xRotate(
	p: { number },
	s: number,
	sz: number
): { number }
	return newTile(s, sz, function(x, y, z)
		return p[x + z * s + (s - 1 - y) * s * s + 1]
	end)
end

local function xReflect(
	p: { number },
	s: number,
	sz: number
): { number }
	return newTile(s, sz, function(x, y, z)
		return p[(s - 1 - x) + y * s + z * s * s + 1]
	end)
end

local function yReflect(
	p: { number },
	s: number,
	sz: number
): { number }
	return newTile(s, sz, function(x, y, z)
		return p[x + (s - 1 - y) * s + z * s * s + 1]
	end)
end

local function zReflect(
	p: { number },
	s: number,
	sz: number
): { number }
	return newTile(s, sz, function(x, y, z)
		return p[x + y * s + (s - 1 - z) * s * s + 1]
	end)
end

local function last(attribute: string): string
	local lastToken = attribute

	for token in string.gmatch(attribute, "%S+") do
		lastToken = token
	end

	return lastToken
end

local function resolveTile(
	attribute: string,
	namedTileData: { [string]: { { number } } },
	s: number,
	sz: number
): { number }
	local parts: { string } = {}

	for token in string.gmatch(attribute, "%S+") do
		table.insert(parts, token)
	end

	local action = if #parts == 2 then parts[1] else ""
	local name = parts[#parts]
	local startTile = namedTileData[name][1]

	for i = #action, 1, -1 do
		local sym = string.sub(action, i, i)

		if sym == "x" then
			startTile = xRotate(startTile, s, sz)
		elseif sym == "y" then
			startTile = yRotate(startTile, s, sz)
		elseif sym == "z" then
			startTile = zRotate(startTile, s, sz)
		else
			error(`TileModel.New: unknown symmetry "{sym}"`, 0)
		end
	end

	return startTile
end

local function tileIndex(
	tiledata: { { number } },
	p: { number }
): number
	for i, t in tiledata do
		if Helper.Same(t, p) then
			return i
		end
	end

	error("TileModel.New: tile pattern not found in tiledata (internal consistency error)", 0)
end

local function tileUpdateState(
	node: Node.Node,
	tiledata: { { number } },
	s: number,
	sz: number,
	overlapAmt: number,
	overlapZ: number,
	p: number
)
	local data = node.Data :: WFC.WFCData
	local newgrid = data.NewGrid
	local mx, my, mz = data.WaveMX, data.WaveMY, data.WaveMZ
	local rng = data.Rng :: Random.Rng
	local cellVoxels = s * s * sz

	for z = 0, mz - 1 do
	for y = 0, my - 1 do
	for x = 0, mx - 1 do
		local w = data.Wave.Data[x + y * mx + z * mx * my]
		local votes: { [number]: { number } } = table.create(cellVoxels)

		for i = 0, cellVoxels - 1 do
			votes[i] = table.create(newgrid.C, 0)
		end

		for t = 1, p do
			if w[t] then
				local tile = tiledata[t]

				for dz = 0, sz - 1 do
				for dy = 0, s - 1 do
				for dx = 0, s - 1 do
					local di = dx + (dy + dz * s) * s
					votes[di][tile[di + 1] + 1] += 1
				end
				end
				end
			end
		end

		for dz = 0, sz - 1 do
		for dy = 0, s - 1 do
		for dx = 0, s - 1 do
			local di = dx + (dy + dz * s) * s
			local v = votes[di]
			local max, argmax = -1.0, 0xff

			for c = 0, #v - 1 do
				local vote = v[c + 1] + 0.1 * rng:NextNumber()

				if vote > max then
					argmax = c
					max = vote
				end
			end

			local sx = x * (s - overlapAmt) + dx
			local sy = y * (s - overlapAmt) + dy
			local sz2 = z * (sz - overlapZ) + dz

			buffer.writeu8(newgrid.State, Grid.Index(newgrid, sx, sy, sz2), argmax)
		end
		end
		end
	end
	end
	end
end

--[=[
	Creates a new TileModel WFC node, generating structures based on discrete tile adjacencies and neighbors.
	@param config table -- The tile model configuration.
	@param grid table -- The parent grid.
	@param newgrid table -- The new child grid where generation happens.
	@param _parentSymmetry table -- Ignored; tile model uses explicit internal symmetries.
	@param children table -- The child nodes.
	@return table -- The constructed TileModel node.
]=]
function TileModel.New(
	config: TileModelConfig,
	grid: Grid.Grid,
	newgrid: Grid.Grid,
	_parentSymmetry: { boolean },
	children: { Node.Node }
): Node.Node
	local fullSymmetry = config.FullSymmetry or false
	local overlapAmt = config.Overlap or 0
	local overlapZ = config.OverlapZ or 0
	local s, sz = config.S, config.SZ

	assert(not fullSymmetry or s == sz, `TileModel.New: tiles should be cubes for the full symmetry option: {s} ~= {sz}`)

	local uniques: { number } = {}
	local namedTileData: { [string]: { { number } } } = {}
	local tempWeights: { number } = {}
	local tiledata: { { number } } = {}
	local positions: { [string]: { boolean } } = {}
	local tilenames: { [string]: boolean } = {}
	local ind = 0

	for _, tile in config.Tiles do
		tilenames[tile.Name] = true
		local flatTile, tileC = Helper.Ords(tile.Voxels, uniques)

		assert(tileC <= newgrid.C, `TileModel.New: there were more than {newgrid.C} colors in vox files`)

		local localdata: { { number } }

		if fullSymmetry then
			localdata = Symmetry.CubeSymmetries(flatTile, function(p)
				return zRotate(p, s, sz)
			end, function(p)
				return yRotate(p, s, sz)
			end, function(p)
				return xReflect(p, s, sz)
			end, Helper.Same)
		else
			localdata = Symmetry.SquareSymmetries(flatTile, function(p)
				return zRotate(p, s, sz)
			end, function(p)
				return xReflect(p, s, sz)
			end, Helper.Same)
		end

		local position = table.create(128, false)
		namedTileData[tile.Name] = localdata

		for _, p in localdata do
			table.insert(tiledata, p)
			table.insert(tempWeights, tile.Weight or 1.0)
			position[ind + 1] = true
			ind += 1
		end

		positions[tile.Name] = position
	end

	local p = #tiledata

	local map: { [number]: { boolean } } = {}

	for _, rule in config.Rules do
		local input = grid.Values[rule.In]
		assert(input, `TileModel.New: unknown in value "{rule.In}"`)
		local position = table.create(p, false)

		for token in string.gmatch(rule.Out, "[^|]+") do
			local array = positions[token]
			assert(array, `TileModel.New: unknown tilename "{token}"`)

			for t = 1, p do
				if array[t] then
					position[t] = true
				end
			end
		end

		map[input] = position
	end

	if map[0] == nil then
		map[0] = table.create(p, true)
	end

	local function checkTileName(attribute: string?)
		if attribute == nil then
			return
		end

		local name = last(attribute)
		assert(tilenames[name], `TileModel.New: unknown tile "{name}"`)
	end

	local tempPropagator: { { { boolean } } } = table.create(6)

	for d = 1, 6 do
		local layer = table.create(p)

		for i = 1, p do
			layer[i] = table.create(p, false)
		end

		tempPropagator[d] = layer
	end

	for _, nb in config.Neighbors do
		if fullSymmetry then
			checkTileName(nb.Left)
			checkTileName(nb.Right)

			assert(nb.Left and nb.Right, "TileModel.New: fullSymmetry neighbor requires left/right")
			
			local ltile = resolveTile(nb.Left :: string, namedTileData, s, sz)
			local rtile = resolveTile(nb.Right :: string, namedTileData, s, sz)

			local lsym = Symmetry.SquareSymmetries(ltile, function(q)
				return xRotate(q, s, sz)
			end, function(q)
				return yReflect(q, s, sz)
			end, function(_, _)
				return false
			end)
			local rsym = Symmetry.SquareSymmetries(rtile, function(q)
				return xRotate(q, s, sz)
			end, function(q)
				return yReflect(q, s, sz)
			end, function(_, _)
				return false
			end)

			for i = 1, #lsym do
				tempPropagator[1][tileIndex(tiledata, lsym[i])][tileIndex(tiledata, rsym[i])] = true
				tempPropagator[1][tileIndex(tiledata, xReflect(rsym[i], s, sz))][tileIndex(tiledata, xReflect(lsym[i], s, sz))] = true
			end

			local dtile = zRotate(ltile, s, sz)
			local utile = zRotate(rtile, s, sz)

			local dsym = Symmetry.SquareSymmetries(dtile, function(q)
				return yRotate(q, s, sz)
			end, function(q)
				return zReflect(q, s, sz)
			end, function(_, _)
				return false
			end)

			local usym = Symmetry.SquareSymmetries(utile, function(q)
				return yRotate(q, s, sz)
			end, function(q)
				return zReflect(q, s, sz)
			end, function(_, _)
				return false
			end)

			for i = 1, #dsym do
				tempPropagator[2][tileIndex(tiledata, dsym[i])][tileIndex(tiledata, usym[i])] = true
				tempPropagator[2][tileIndex(tiledata, yReflect(usym[i], s, sz))][tileIndex(tiledata, yReflect(dsym[i], s, sz))] = true
			end

			local btile = yRotate(ltile, s, sz)
			local ttile = yRotate(rtile, s, sz)

			local bsym = Symmetry.SquareSymmetries(btile, function(q)
				return zRotate(q, s, sz)
			end, function(q)
				return xReflect(q, s, sz)
			end, function(_, _)
				return false
			end)

			local tsym = Symmetry.SquareSymmetries(ttile, function(q)
				return zRotate(q, s, sz)
			end, function(q)
				return xReflect(q, s, sz)
			end, function(_, _)
				return false
			end)

			for i = 1, #bsym do
				tempPropagator[5][tileIndex(tiledata, bsym[i])][tileIndex(tiledata, tsym[i])] = true
				tempPropagator[5][tileIndex(tiledata, zReflect(tsym[i], s, sz))][tileIndex(tiledata, zReflect(bsym[i], s, sz))] = true
			end
		elseif nb.Left ~= nil then
			checkTileName(nb.Left)
			checkTileName(nb.Right)

			local ltile = resolveTile(nb.Left :: string, namedTileData, s, sz)
			local rtile = resolveTile(nb.Right :: string, namedTileData, s, sz)

			tempPropagator[1][tileIndex(tiledata, ltile)][tileIndex(tiledata, rtile)] = true
			tempPropagator[1][tileIndex(tiledata, yReflect(ltile, s, sz))][tileIndex(tiledata, yReflect(rtile, s, sz))] = true
			tempPropagator[1][tileIndex(tiledata, xReflect(rtile, s, sz))][tileIndex(tiledata, xReflect(ltile, s, sz))] = true
			tempPropagator[1][tileIndex(tiledata, yReflect(xReflect(rtile, s, sz), s, sz))][tileIndex(tiledata, yReflect(xReflect(ltile, s, sz), s, sz))] = true

			local dtile = zRotate(ltile, s, sz)
			local utile = zRotate(rtile, s, sz)

			tempPropagator[2][tileIndex(tiledata, dtile)][tileIndex(tiledata, utile)] = true
			tempPropagator[2][tileIndex(tiledata, xReflect(dtile, s, sz))][tileIndex(tiledata, xReflect(utile, s, sz))] = true
			tempPropagator[2][tileIndex(tiledata, yReflect(utile, s, sz))][tileIndex(tiledata, yReflect(dtile, s, sz))] = true
			tempPropagator[2][tileIndex(tiledata, xReflect(yReflect(utile, s, sz), s, sz))][tileIndex(tiledata, xReflect(yReflect(dtile, s, sz), s, sz))] = true
		else
			checkTileName(nb.Top)
			checkTileName(nb.Bottom)

			assert(nb.Top and nb.Bottom, "TileModel.New: neighbor requires top/bottom when left/right absent")
			
			local ttile = resolveTile(nb.Top :: string, namedTileData, s, sz)
			local btile = resolveTile(nb.Bottom :: string, namedTileData, s, sz)
			local tsym = Symmetry.SquareSymmetries(ttile, function(q)
				return zRotate(q, s, sz)
			end, function(q)
				return xReflect(q, s, sz)
			end, function(_, _)
				return false
			end)

			local bsym = Symmetry.SquareSymmetries(btile, function(q)
				return zRotate(q, s, sz)
			end, function(q)
				return xReflect(q, s, sz)
			end, function(_, _)
				return false
			end)

			for i = 1, #tsym do
				tempPropagator[5][tileIndex(tiledata, bsym[i])][tileIndex(tiledata, tsym[i])] = true
			end
		end
	end

	for p2 = 1, p do
	for p1 = 1, p do
		tempPropagator[3][p2][p1] = tempPropagator[1][p1][p2]
		tempPropagator[4][p2][p1] = tempPropagator[2][p1][p2]
		tempPropagator[6][p2][p1] = tempPropagator[5][p1][p2]
	end
	end

	local propagator: WFC.Propagator = table.create(6)

	for d = 1, 6 do
		local dirList = table.create(p)

		for p1 = 1, p do
			local list: { number } = {}
			local tp = tempPropagator[d][p1]
			for p2 = 1, p do
				if tp[p2] then
					table.insert(list, p2)
				end
			end

			dirList[p1] = list
		end

		propagator[d] = dirList
	end

	local data = WFC.NewData(
		{ Shannon = config.Shannon, Tries = config.Tries, Periodic = config.Periodic or false, Name = config.TilesetName },
		p,
		propagator,
		tempWeights,
		newgrid,
		map,
		1,
		grid,
		function(node)
			tileUpdateState(node, tiledata, s, sz, overlapAmt, overlapZ, p)
		end,
		children
	)

	return { Kind = "TileModel", Parent = nil, Data = data }
end

TileModel.Impl = WFC.Impl

return TileModel
