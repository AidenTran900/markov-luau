--!strict
--!native
--!optimize 2
local Grid = require(script.Parent.Parent.Grid)
local Node = require(script.Parent.Parent.Node)
local Helper = require(script.Parent.Parent.Util.Helper)
local Symmetry = require(script.Parent.Parent.Util.Symmetry)

local ConvChain = {}

export type ConvChainData = {
	N: number,
	Temperature: number,
	Weights: { number }, -- 1 indexed (bitmask+1), size 2^(N*N)
	C0: number,
	C1: number, -- 0 based colors
	Substrate: buffer, -- one byte(0/1) per cell
	SubstrateColor: number,
	Counter: number,
	Steps: number, -- <= 0 = unlimited
}

export type ConvChainConfig = {
	Sample: { boolean }, -- flat row-major, 1 indexed, size SMX*SMY
	SMX: number,
	SMY: number,
	N: number?,
	Steps: number?,
	Temperature: number?,
	Black: string,
	White: string,
	On: string,
}

function ConvChain.New(
	config: ConvChainConfig,
	grid: Grid.Grid,
	symmetry: { boolean }
): Node.Node

	assert(grid.MZ == 1, "ConvChain.New: convchain currently works only for 2D")

	local n = config.N or 3
	local smx, smy = config.SMX, config.SMY
	local sample = config.Sample

	local weightCount = 2 ^ (n * n)
	local weights = table.create(weightCount, 0)

	for y = 0, smy - 1 do
		for x = 0, smx - 1 do
			local pattern = Helper.Pattern(function(dx: number, dy: number)
				return sample[((x + dx) % smx) + ((y + dy) % smy) * smx + 1]
			end, n)
			local symmetries = Symmetry.SquareSymmetries(pattern, function(q)
				return Helper.Rotated(q, n)
			end, function(q)
				return Helper.Reflected(q, n)
			end, function(_, _)
				return false
			end, symmetry)

			for _, q in symmetries do
				local idx = Helper.Index(q) + 1
				weights[idx] += 1
			end
		end
	end

	for k = 1, weightCount do

		if weights[k] <= 0 then
			weights[k] = 0.1
		end
	end

	local c0 = grid.Values[config.Black]
	assert(c0, `ConvChain.New: unknown black value "{config.Black}"`)

	local c1 = grid.Values[config.White]
	assert(c1, `ConvChain.New: unknown white value "{config.White}"`)

	local substrateColor = grid.Values[config.On]
	assert(substrateColor, `ConvChain.New: unknown on value "{config.On}"`)

	local cellCount = grid.MX * grid.MY * grid.MZ
	local data: ConvChainData = {
		N = n,
		Temperature = config.Temperature or 1.0,
		Weights = weights,
		C0 = c0,
		C1 = c1,
		Substrate = buffer.create(cellCount),
		SubstrateColor = substrateColor,
		Counter = 0,
		Steps = config.Steps or -1,
	}

	return { Kind = "ConvChain", Parent = nil, Data = data }
end

local function toggle(
	state: buffer,
	i: number,
	c0: number,
	c1: number
)
	buffer.writeu8(state, i, if buffer.readu8(state, i) == c0 then c1 else c0)
end

local convChainImpl: Node.NodeImpl = {
	Reset = function(node: Node.Node, _dispatch: Node.Dispatch)
		local data = node.Data :: ConvChainData
		buffer.fill(data.Substrate, 0, 0, buffer.len(data.Substrate))

		data.Counter = 0
	end,
	Go = function(node: Node.Node, ip: Node.InterpreterState, _dispatch: Node.Dispatch): boolean
		local data = node.Data :: ConvChainData

		if data.Steps > 0 and data.Counter >= data.Steps then
			return false
		end

		local grid = ip.Grid
		local mx, my = grid.MX, grid.MY
		local state = grid.State
		local n = data.N
		local weights = data.Weights
		local c0, c1 = data.C0, data.C1

		if data.Counter == 0 then
			local anySubstrate = false

			for i = 0, buffer.len(data.Substrate) - 1 do

				if buffer.readu8(state, i) == data.SubstrateColor then
					buffer.writeu8(state, i, if ip.Random:Next(2) == 0 then c0 else c1)
					buffer.writeu8(data.Substrate, i, 1)
					anySubstrate = true
				end
			end

			data.Counter += 1

			return anySubstrate
		end

		local cellCount = buffer.len(state)

		for _ = 1, cellCount do
			local r = ip.Random:Next(cellCount)

			if buffer.readu8(data.Substrate, r) ~= 0 then
				local x, y = r % mx, r // mx
				local q = 1.0

				for sy = y - n + 1, y + n - 1 do

					for sx = x - n + 1, x + n - 1 do
						local ind, difference = 0, 0

						for dy = 0, n - 1 do
							local py = sy + dy

							if py < 0 then
								py += my
							elseif py >= my then
								py -= my
							end

							local yOffset = py * mx

							for dx = 0, n - 1 do
								local px = sx + dx

								if px < 0 then
									px += mx
								elseif px >= mx then
									px -= mx
								end

								local value = buffer.readu8(state, px + yOffset) == c1
								local power = bit32.lshift(1, dy * n + dx)

								if value then
									ind += power
								end

								if px == x and py == y then
									difference = if value then power else -power
								end
							end
						end

						q *= weights[(ind - difference) + 1] / weights[ind + 1]
					end
				end

				if q >= 1 then
					toggle(state, r, c0, c1)
				else
					if data.Temperature ~= 1 then
						q ^= 1.0 / data.Temperature
					end

					if q > ip.Random:NextNumber() then
						toggle(state, r, c0, c1)
					end
				end
			end
		end

		data.Counter += 1

		return true
	end,
}
ConvChain.Impl = convChainImpl

return ConvChain
