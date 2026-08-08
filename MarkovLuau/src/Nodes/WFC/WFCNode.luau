--!strict
--!native
--!optimize 2
local Grid = require(script.Parent.Parent.Parent.Grid)
local Node = require(script.Parent.Parent.Parent.Node)
local Random = require(script.Parent.Parent.Parent.Util.Random)
local Constants = require(script.Parent.Parent.Parent.Util.Constants)

local DX = Constants.WFC_DX
local DY = Constants.WFC_DY
local DZ = Constants.WFC_DZ
local OPPOSITE = Constants.WFC_OPPOSITE

local WFC = {}

export type Wave = {
	Length: number,
	Data: { [number]: { boolean } }, -- [cell 0-based][pattern 1-based]
	Compatible: { [number]: { { number } } }, -- [cell][pattern][direction 1-based]
	SumsOfOnes: { [number]: number },
	SumsOfWeights: { [number]: number }?,
	SumsOfWeightLogWeights: { [number]: number }?,
	Entropies: { [number]: number }?,
}

export type Propagator = { { { number } } } -- [direction 1-based][pattern 1-based] = compatible pattern list

export type WFCData = {
	-- Branch fields (Node.BranchGo/BranchReset read these directly)
	Nodes: { Node.Node },
	N: number, -- -1 = not yet collapsed
	-- WFC fields
	Wave: Wave,
	StartWave: Wave,
	Propagator: Propagator,
	P: number,
	DimN: number, -- upstream's own "N": pattern/tile extent (1 for TileModel, the overlap window size for Overlap)
	WaveMX: number,
	WaveMY: number,
	WaveMZ: number, -- captured once; see file header
	StackI: { number },
	StackT: { number }, -- preallocated parallel arrays (cellCount*P capacity), 1-based, StackSize is the live length
	StackSize: number,
	Weights: { number }, -- 1-indexed
	WeightLogWeights: { number }?,
	SumOfWeights: number,
	SumOfWeightLogWeights: number,
	StartingEntropy: number,
	NewGrid: Grid.Grid,
	Map: { [number]: { boolean } }, -- old-grid value (0-based, raw) -> per-pattern allowed set (1-indexed)
	Periodic: boolean,
	Shannon: boolean,
	Distribution: { number }, -- 1-indexed length P scratch buffer for Observe
	Tries: number,
	Name: string?,
	FirstGo: boolean,
	Rng: Random.Rng?, -- the node's own persistent RNG, seeded by GoodSeed once firstgo completes
	UpdateState: (node: Node.Node) -> (), -- injected in place of the abstract C# method
}

export type WFCSharedConfig = {
	Shannon: boolean?,
	Tries: number?,
	Periodic: boolean,
	Name: string?,
}

local function newWave(
	length: number,
	p: number,
	d: number,
	shannon: boolean
): Wave
	local data: { [number]: { boolean } } = table.create(length)
	local compatible: { [number]: { { number } } } = table.create(length)

	for i = 0, length - 1 do
		data[i] = table.create(p, true)
		local comp = table.create(p)

		for t = 1, p do
			comp[t] = table.create(d, -1)
		end

		compatible[i] = comp
	end

	local wave: Wave = { Length = length, Data = data, Compatible = compatible, SumsOfOnes = table.create(length, 0) }

	for i = 0, length - 1 do
		wave.SumsOfOnes[i] = 0
	end

	if shannon then
		local sumsOfWeights: { [number]: number } = table.create(length, 0)
		local sumsOfWeightLogWeights: { [number]: number } = table.create(length, 0)
		local entropies: { [number]: number } = table.create(length, 0)

		for i = 0, length - 1 do
			sumsOfWeights[i] = 0
			sumsOfWeightLogWeights[i] = 0
			entropies[i] = 0
		end

		wave.SumsOfWeights = sumsOfWeights
		wave.SumsOfWeightLogWeights = sumsOfWeightLogWeights
		wave.Entropies = entropies
	end

	return wave
end

local function waveInit(
	wave: Wave,
	propagator: Propagator,
	opposite: { number },
	sumOfWeights: number,
	sumOfWeightLogWeights: number,
	startingEntropy: number,
	shannon: boolean
)
	local p = #wave.Data[0]
	local d = #propagator

	for i = 0, wave.Length - 1 do
		local datai = wave.Data[i]
		local compi = wave.Compatible[i]

		for t = 1, p do
			datai[t] = true
			local compit = compi[t]

			for dir = 1, d do
				compit[dir] = #propagator[opposite[dir]][t]
			end
		end

		wave.SumsOfOnes[i] = p

		if shannon then
			local sumsOfWeights = wave.SumsOfWeights :: { [number]: number }
			local sumsOfWeightLogWeights = wave.SumsOfWeightLogWeights :: { [number]: number }
			local entropies = wave.Entropies :: { [number]: number }
			sumsOfWeights[i] = sumOfWeights
			sumsOfWeightLogWeights[i] = sumOfWeightLogWeights
			entropies[i] = startingEntropy
		end
	end
end

local function waveCopyFrom(
	wave: Wave,
	src: Wave,
	d: number,
	shannon: boolean
)

	for i = 0, wave.Length - 1 do
		local datai, srcDatai = wave.Data[i], src.Data[i]
		local compi, srcCompi = wave.Compatible[i], src.Compatible[i]

		for t = 1, #datai do
			datai[t] = srcDatai[t]
			local compit, srcCompit = compi[t], srcCompi[t]

			for dir = 1, d do
				compit[dir] = srcCompit[dir]
			end
		end

		wave.SumsOfOnes[i] = src.SumsOfOnes[i]

		if shannon then
			local sumsOfWeights = wave.SumsOfWeights :: { [number]: number }
			local sumsOfWeightLogWeights = wave.SumsOfWeightLogWeights :: { [number]: number }
			local entropies = wave.Entropies :: { [number]: number }
			local srcSumsOfWeights = src.SumsOfWeights :: { [number]: number }
			local srcSumsOfWeightLogWeights = src.SumsOfWeightLogWeights :: { [number]: number }
			local srcEntropies = src.Entropies :: { [number]: number }
			sumsOfWeights[i] = srcSumsOfWeights[i]
			sumsOfWeightLogWeights[i] = srcSumsOfWeightLogWeights[i]
			entropies[i] = srcEntropies[i]
		end
	end
end

WFC.DX, WFC.DY, WFC.DZ, WFC.Opposite = Constants.WFC_DX, Constants.WFC_DY, Constants.WFC_DZ, Constants.WFC_OPPOSITE

function WFC.NewData(
	config: WFCSharedConfig,
	p: number,
	propagator: Propagator,
	weights: { number },
	newgrid: Grid.Grid,
	map: { [number]: { boolean } },
	dimN: number,
	grid: Grid.Grid,
	updateState: (Node.Node) -> (),
	children: { Node.Node }
): WFCData
	local shannon = config.Shannon or false
	local d = #propagator
	local cellCount = grid.MX * grid.MY * grid.MZ

	local wave = newWave(cellCount, p, d, shannon)
	local startwave = newWave(cellCount, p, d, shannon)

	local sumOfWeights, sumOfWeightLogWeights, startingEntropy = 0, 0, 0
	local weightLogWeights: { number }? = nil

	if shannon then
		local wlw = table.create(p)

		for t = 1, p do
			wlw[t] = weights[t] * math.log(weights[t])
			sumOfWeights += weights[t]
			sumOfWeightLogWeights += wlw[t]
		end

		weightLogWeights = wlw
		startingEntropy = math.log(sumOfWeights) - sumOfWeightLogWeights / sumOfWeights
	end

	local stackCapacity = cellCount * p
	local data: WFCData = {
		Nodes = children,
		N = -1,
		Wave = wave,
		StartWave = startwave,
		Propagator = propagator,
		P = p,
		DimN = dimN,
		WaveMX = grid.MX,
		WaveMY = grid.MY,
		WaveMZ = grid.MZ,
		StackI = table.create(stackCapacity, 0),
		StackT = table.create(stackCapacity, 0),
		StackSize = 0,
		Weights = weights,
		WeightLogWeights = weightLogWeights,
		SumOfWeights = sumOfWeights,
		SumOfWeightLogWeights = sumOfWeightLogWeights,
		StartingEntropy = startingEntropy,
		NewGrid = newgrid,
		Map = map,
		Periodic = config.Periodic,
		Shannon = shannon,
		Distribution = table.create(p, 0),
		Tries = config.Tries or 1000,
		Name = config.Name,
		FirstGo = true,
		Rng = nil,
		UpdateState = updateState,
	}

	return data
end

local function ban(data: WFCData, i: number, t: number)
	local wave = data.Wave
	wave.Data[i][t] = false
	local comp = wave.Compatible[i][t]

	for dir = 1, #data.Propagator do
		comp[dir] = 0
	end

	data.StackSize += 1
	data.StackI[data.StackSize] = i
	data.StackT[data.StackSize] = t
	wave.SumsOfOnes[i] -= 1

	if data.Shannon then
		local sumsOfWeights = wave.SumsOfWeights :: { [number]: number }
		local sumsOfWeightLogWeights = wave.SumsOfWeightLogWeights :: { [number]: number }
		local entropies = wave.Entropies :: { [number]: number }
		local weightLogWeights = data.WeightLogWeights :: { number }
		local sum = sumsOfWeights[i]
		entropies[i] += sumsOfWeightLogWeights[i] / sum - math.log(sum)
		sumsOfWeights[i] -= data.Weights[t]
		sumsOfWeightLogWeights[i] -= weightLogWeights[t]
		sum = sumsOfWeights[i]
		entropies[i] -= sumsOfWeightLogWeights[i] / sum - math.log(sum)
	end
end

local function propagate(data: WFCData): boolean
	local mx, my, mz = data.WaveMX, data.WaveMY, data.WaveMZ
	local wave = data.Wave
	local propagator = data.Propagator
	local n = data.DimN
	local d = #propagator

	while data.StackSize > 0 do
		local i1 = data.StackI[data.StackSize]
		local p1 = data.StackT[data.StackSize]
		data.StackSize -= 1

		local x1 = i1 % mx
		local y1 = (i1 // mx) % my
		local z1 = i1 // (mx * my)

		for dir = 1, d do
			local dx, dy, dz = DX[dir], DY[dir], DZ[dir]
			local x2, y2, z2 = x1 + dx, y1 + dy, z1 + dz
			local outOfBounds = not data.Periodic and (x2 < 0 or y2 < 0 or z2 < 0 or x2 + n > mx or y2 + n > my or z2 + 1 > mz)

			if not outOfBounds then

				if x2 < 0 then
					x2 += mx
				elseif x2 >= mx then
					x2 -= mx
				end

				if y2 < 0 then
					y2 += my
				elseif y2 >= my then
					y2 -= my
				end

				if z2 < 0 then
					z2 += mz
				elseif z2 >= mz then
					z2 -= mz
				end

				local i2 = x2 + (y2 + z2 * my) * mx
				local compat = wave.Compatible[i2]

				for _, t2 in propagator[dir][p1] do
					local comp = compat[t2]
					comp[dir] -= 1

					if comp[dir] == 0 then
						ban(data, i2, t2)
					end
				end
			end
		end
	end

	return wave.SumsOfOnes[0] > 0
end

local function nextUnobservedNode(
	data: WFCData,
	rng: Random.Rng
): number
	local mx, my, mz = data.WaveMX, data.WaveMY, data.WaveMZ
	local n = data.DimN
	local wave = data.Wave
	local min, argmin = 1e4, -1

	for z = 0, mz - 1 do
		local zOffset = z * my

		for y = 0, my - 1 do
			local yOffset = (y + zOffset) * mx

			for x = 0, mx - 1 do
				if data.Periodic or (x + n <= mx and y + n <= my and z + 1 <= mz) then
					local i = x + yOffset
					local remainingValues = wave.SumsOfOnes[i]
					local entropy = if data.Shannon then (wave.Entropies :: { [number]: number })[i] else remainingValues
				
					if remainingValues > 1 and entropy <= min then
						local noise = 1e-6 * rng:NextNumber()

						if entropy + noise < min then
							min = entropy + noise
							argmin = i
						end
					end
				end
			end
		end
	end

	return argmin
end

local function observe(
	data: WFCData,
	node: number,
	rng: Random.Rng
)
	local w = data.Wave.Data[node]
	local distribution = data.Distribution

	for t = 1, data.P do
		distribution[t] = if w[t] then data.Weights[t] else 0.0
	end

	local r = Random.WeightedIndex(distribution, rng:NextNumber()) + 1

	for t = 1, data.P do

		if w[t] ~= (t == r) then
			ban(data, node, t)
		end
	end
end

local function goodSeed(
	data: WFCData,
	ip: Node.InterpreterState
): number?

	for _ = 1, data.Tries do
		local seed = ip.Random:NextSeed()
		local rng = Random.New(seed)
		data.StackSize = 0
		waveCopyFrom(data.Wave, data.StartWave, #data.Propagator, data.Shannon)
		while true do
			local node = nextUnobservedNode(data, rng)
			if node >= 0 then
				observe(data, node, rng)

				if not propagate(data) then
					break
				end
			else
				return seed
			end
		end
	end

	return nil
end

local wfcImpl: Node.NodeImpl = {
	Reset = function(node: Node.Node, dispatch: Node.Dispatch)
		Node.BranchReset(node, dispatch)
		local data = node.Data :: WFCData
		data.N = -1
		data.FirstGo = true
	end,
	Go = function(node: Node.Node, ip: Node.InterpreterState, dispatch: Node.Dispatch): boolean
		local data = node.Data :: WFCData

		if data.N >= 0 then
			return Node.BranchGo(node, ip, dispatch)
		end

		if data.FirstGo then
			local oldGrid = ip.Grid
			waveInit(data.Wave, data.Propagator, OPPOSITE, data.SumOfWeights, data.SumOfWeightLogWeights, data.StartingEntropy, data.Shannon)

			for i = 0, data.Wave.Length - 1 do
				local value = buffer.readu8(oldGrid.State, i)
				local startWave = data.Map[value]

				if startWave then
					for t = 1, data.P do
						if not startWave[t] then
							ban(data, i, t)
						end
					end
				end
			end

			if not propagate(data) then
				return false
			end

			waveCopyFrom(data.StartWave, data.Wave, #data.Propagator, data.Shannon)

			local seed = goodSeed(data, ip)

			if seed == nil then
				return false
			end

			data.Rng = Random.New(seed)
			data.StackSize = 0
			waveCopyFrom(data.Wave, data.StartWave, #data.Propagator, data.Shannon)
			data.FirstGo = false

			Grid.Clear(data.NewGrid)
			ip.Grid = data.NewGrid

			return true
		end

		local rng = data.Rng :: Random.Rng
		local unobserved = nextUnobservedNode(data, rng)

		if unobserved >= 0 then
			observe(data, unobserved, rng)
			propagate(data)
		else
			data.N += 1
		end

		if data.N >= 0 then
			data.UpdateState(node)
		end

		return true
	end,
}
WFC.Impl = wfcImpl

return WFC
