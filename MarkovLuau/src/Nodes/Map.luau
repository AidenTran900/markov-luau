--!strict
--!native
--!optimize 2
local Grid = require(script.Parent.Parent.Grid)
local Rule = require(script.Parent.Parent.Rule)
local Node = require(script.Parent.Parent.Node)
local Symmetry = require(script.Parent.Parent.Util.Symmetry)

local Map = {}

export type MapData = {
	Nodes: { Node.Node },
	N: number, -- -1 = not yet rescaled
	NewGrid: Grid.Grid,
	Rules: { Rule.Rule },
	NX: number,
	DX: number,
	NY: number,
	DY: number,
	NZ: number,
	DZ: number,
}

export type MapRuleSpec = {
	InChars: { string },
	IMX: number,
	IMY: number,
	IMZ: number,
	OutChars: { string },
	OMX: number,
	OMY: number,
	OMZ: number,
	P: number?,
}

export type MapConfig = {
	Rules: { MapRuleSpec },
	Symmetry: string?,
	ScaleNX: number,
	ScaleDX: number,
	ScaleNY: number,
	ScaleDY: number,
	ScaleNZ: number,
	ScaleDZ: number,
}

function Map.New(
	config: MapConfig,
	grid: Grid.Grid,
	newgrid: Grid.Grid,
	parentSymmetry: { boolean },
	children: { Node.Node }
): Node.Node

	local d2 = grid.MZ == 1
	local symmetry = Symmetry.GetSymmetry(d2, config.Symmetry, parentSymmetry)

	assert(symmetry, `Map.New: unknown symmetry "{config.Symmetry}"`)

	local rules: { Rule.Rule } = {}

	for _, spec in config.Rules do
		local rule = Rule.FromChars(
			spec.InChars, 
			spec.IMX, 
			spec.IMY, 
			spec.IMZ, 
			spec.OutChars, 
			spec.OMX, 
			spec.OMY, 
			spec.OMZ, 
			grid.Legend, 
			newgrid.Legend, 
			grid.C, 
			spec.P or 1.0
		)
		rule.Original = true

		for _, r in Rule.Symmetries(rule, symmetry, d2) do
			table.insert(rules, r)
		end
	end

	local data: MapData = {
		Nodes = children,
		N = -1,
		NewGrid = newgrid,
		Rules = rules,
		NX = config.ScaleNX,
		DX = config.ScaleDX,
		NY = config.ScaleNY,
		DY = config.ScaleDY,
		NZ = config.ScaleNZ,
		DZ = config.ScaleDZ,
	}

	return { Kind = "Map", Parent = nil, Data = data }
end

local function mapMatches(
	rule: Rule.Rule,
	x: number,
	y: number,
	z: number,
	state: buffer,
	mx: number,
	my: number,
	mz: number
): boolean
	local input = rule.Input
	local i = 1

	for dz = 0, rule.IMZ - 1 do
		for dy = 0, rule.IMY - 1 do
			for dx = 0, rule.IMX - 1 do
				local sx, sy, sz = x + dx, y + dy, z + dz

				if sx >= mx then
					sx -= mx
				end

				if sy >= my then
					sy -= my
				end

				if sz >= mz then
					sz -= mz
				end

				local v = buffer.readu8(state, sx + (sy + sz * my) * mx)

				if bit32.band(input[i], bit32.lshift(1, v)) == 0 then
					return false
				end

				i += 1
			end
		end
	end

	return true
end

local function mapApply(
	rule: Rule.Rule,
	x: number,
	y: number,
	z: number,
	state: buffer,
	mx: number,
	my: number,
	mz: number
)
	local outputBuffer = rule.Output
	local i = 0

	for dz = 0, rule.OMZ - 1 do
		for dy = 0, rule.OMY - 1 do
			for dx = 0, rule.OMX - 1 do
				local sx, sy, sz = x + dx, y + dy, z + dz

				if sx >= mx then
					sx -= mx
				end

				if sy >= my then
					sy -= my
				end

				if sz >= mz then
					sz -= mz
				end

				local output = buffer.readu8(outputBuffer, i)

				if output ~= 0xff then
					buffer.writeu8(state, sx + (sy + sz * my) * mx, output)
				end

				i += 1
			end
		end
	end
end

local mapImpl: Node.NodeImpl = {
	Reset = function(node: Node.Node, dispatch: Node.Dispatch)
		Node.BranchReset(node, dispatch)
		local data = node.Data :: MapData
		data.N = -1
	end,
	Go = function(node: Node.Node, ip: Node.InterpreterState, dispatch: Node.Dispatch): boolean
		local data = node.Data :: MapData

		if data.N >= 0 then
			return Node.BranchGo(node, ip, dispatch)
		end

		local grid = ip.Grid
		local newgrid = data.NewGrid
		Grid.Clear(newgrid)

		for _, rule in data.Rules do
			for z = 0, grid.MZ - 1 do
			for y = 0, grid.MY - 1 do
			for x = 0, grid.MX - 1 do
				if mapMatches(rule, x, y, z, grid.State, grid.MX, grid.MY, grid.MZ) then
					mapApply(
						rule,
						(x * data.NX) // data.DX,
						(y * data.NY) // data.DY,
						(z * data.NZ) // data.DZ,
						newgrid.State,
						newgrid.MX,
						newgrid.MY,
						newgrid.MZ
					)
				end
			end
			end
			end
		end

		ip.Grid = newgrid
		data.N += 1

		return true
	end,
}
Map.Impl = mapImpl

return Map
