--!strict
--!native
--!optimize 2
local Grid = require(script.Parent.Parent.Parent.Grid)
local Node = require(script.Parent.Parent.Parent.Node)
local Random = require(script.Parent.Parent.Parent.Util.Random)
local Helper = require(script.Parent.Parent.Parent.Util.Helper)
local Symmetry = require(script.Parent.Parent.Parent.Util.Symmetry)
local WFC = require(script.Parent.WFCNode)

local Overlap = {}

export type OverlapRuleSpec = { In: string, Out: string } -- Out: "A|B|C", resolved against newgrid's alphabet

export type OverlapConfig = {
	N: number?,
	Symmetry: string?,
	PeriodicInput: boolean?, -- default true
	Bitmap: { number }, -- raw sample pixel values (1-indexed, row-major, size SMX*SMY) -- pre-decoded by the host via Sample injection
	SMX: number,
	SMY: number,
	Rules: { OverlapRuleSpec },
	Shannon: boolean?,
	Tries: number?,
	SampleName: string?,
}

local function patternFromIndex(
	ind: number,
	w: number,
	c: number,
	cellCount: number
): { number }

	local residue, power = ind, w
	local result = table.create(cellCount)

	for i = 1, cellCount do
		power = power // c
		local count = 0
		while residue >= power do
			residue -= power
			count += 1
		end

		result[i] = count
	end

	return result
end

local function agrees(
	p1: { number },
	p2: { number },
	dx: number,
	dy: number,
	n: number
): boolean

	local xmin = if dx < 0 then 0 else dx
	local xmax = if dx < 0 then dx + n else n
	local ymin = if dy < 0 then 0 else dy
	local ymax = if dy < 0 then dy + n else n

	for y = ymin, ymax - 1 do

		for x = xmin, xmax - 1 do

			if p1[x + n * y + 1] ~= p2[(x - dx) + n * (y - dy) + 1] then

				return false
			end
		end
	end

	return true
end

local function updateState(
	node: Node.Node,
	patterns: { { number } },
	n: number,
	p: number
)
	local data = node.Data :: WFC.WFCData
	local newgrid = data.NewGrid
	local mx, my = newgrid.MX, newgrid.MY
	local cellCount = mx * my
	local votes: { [number]: { number } } = table.create(cellCount)

	for i = 0, cellCount - 1 do
		votes[i] = table.create(newgrid.C, 0)
	end

	for i = 0, data.Wave.Length - 1 do
		local w = data.Wave.Data[i]
		local x, y = i % mx, i // mx

		for pt = 1, p do
			if w[pt] then
				local pattern = patterns[pt]
				for dy = 0, n - 1 do
					local ydy = y + dy

					if ydy >= my then
						ydy -= my
					end

					for dx = 0, n - 1 do
						local xdx = x + dx

						if xdx >= mx then
							xdx -= mx
						end

						local value = pattern[dx + dy * n + 1]
						local cellVotes = votes[xdx + ydy * mx]
						cellVotes[value + 1] += 1
					end
				end
			end
		end
	end

	local rng = data.Rng :: Random.Rng

	for i = 0, cellCount - 1 do
		local v = votes[i]
		local max, argmax = -1.0, 0xff

		for c = 0, #v - 1 do
			local value = v[c + 1] + 0.1 * rng:NextNumber()

			if value > max then
				argmax = c
				max = value
			end
		end

		buffer.writeu8(newgrid.State, i, argmax)
	end
end

function Overlap.New(
	config: OverlapConfig,
	grid: Grid.Grid,
	newgrid: Grid.Grid,
	parentSymmetry: { boolean },
	children: { Node.Node }
): Node.Node

	assert(grid.MZ == 1, "Overlap.New: overlapping model currently works only for 2D")

	local n = config.N or 3
	local symmetry = Symmetry.GetSymmetry(true, config.Symmetry, parentSymmetry)

	assert(symmetry, `Overlap.New: unknown symmetry "{config.Symmetry}"`)

	local periodicInput = if config.PeriodicInput == nil then true else config.PeriodicInput
	local smx, smy = config.SMX, config.SMY
	local sampleOrds, c = Helper.Ords(config.Bitmap)

	assert(c <= newgrid.C, `Overlap.New: there were more than {newgrid.C} colors in the sample`)

	local w = Helper.Power(c, n * n)
	local cellCount = n * n

	local weights: { [number]: number } = {}
	local ordering: { number } = {}
	local ymax = if periodicInput then grid.MY else grid.MY - n + 1
	local xmax = if periodicInput then grid.MX else grid.MX - n + 1

	for y = 0, ymax - 1 do
	for x = 0, xmax - 1 do
		local pattern = Helper.Pattern(function(dx: number, dy: number)
			return sampleOrds[((x + dx) % smx) + ((y + dy) % smy) * smx + 1]
		end, n)
		local symmetries = Symmetry.SquareSymmetries(pattern, function(q)
			return Helper.Rotated(q, n)
		end, function(q)
			return Helper.Reflected(q, n)
		end, function(_, _)
			return false
		end, symmetry)

		for _, pat in symmetries do
			local ind = Helper.IndexC(pat, c)

			if weights[ind] then
				weights[ind] += 1
			else
				weights[ind] = 1
				table.insert(ordering, ind)
			end
		end
	end
	end

	local p = #ordering
	local patterns: { { number } } = table.create(p)
	local patternWeights: { number } = table.create(p)

	for i, ind in ordering do
		patterns[i] = patternFromIndex(ind, w, c, cellCount)
		patternWeights[i] = weights[ind]
	end

	local propagator: WFC.Propagator = table.create(4)

	for d = 1, 4 do
		local dirList = table.create(p)

		for t = 1, p do
			local list: { number } = {}
			for t2 = 1, p do
				if agrees(patterns[t], patterns[t2], WFC.DX[d], WFC.DY[d], n) then
					table.insert(list, t2)
				end
			end
			dirList[t] = list
		end

		propagator[d] = dirList
	end

	local map: { [number]: { boolean } } = {}
	for _, rule in config.Rules do
		local input = grid.Values[rule.In]

		assert(input, `Overlap.New: unknown in value "{rule.In}"`)

		local outputs: { [number]: boolean } = {}

		for token in string.gmatch(rule.Out, "[^|]+") do
			local ch = string.sub(token, 1, 1)
			local v = newgrid.Values[ch]
			assert(v, `Overlap.New: unknown out value "{ch}"`)
			outputs[v] = true
		end

		local position = table.create(p, false)
		for t = 1, p do
			position[t] = outputs[patterns[t][1]] == true
		end

		map[input] = position
	end

	if map[0] == nil then
		map[0] = table.create(p, true)
	end

	local data = WFC.NewData(
		{ Shannon = config.Shannon, Tries = config.Tries, Periodic = true, Name = config.SampleName },
		p,
		propagator,
		patternWeights,
		newgrid,
		map,
		n,
		grid,
		function(node)
			updateState(node, patterns, n, p)
		end,
		children
	)

	return { Kind = "Overlap", Parent = nil, Data = data }
end

Overlap.Impl = WFC.Impl

return Overlap
