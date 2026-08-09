--!strict
--!native
--!optimize 2
local Grid = require(script.Parent.Parent.Grid)
local Node = require(script.Parent.Parent.Node)

--[=[
	@class Convolution
]=]
local Convolution = {}

local KERNELS_2D: { [string]: { number } } = {
	VonNeumann = { 0, 1, 0, 1, 0, 1, 0, 1, 0 },
	Moore = { 1, 1, 1, 1, 0, 1, 1, 1, 1 },
}
local KERNELS_3D: { [string]: { number } } = {
	VonNeumann = { 0, 0, 0, 0, 1, 0, 0, 0, 0, 0, 1, 0, 1, 0, 1, 0, 1, 0, 0, 0, 0, 0, 1, 0, 0, 0, 0 },
	NoCorners = { 0, 1, 0, 1, 1, 1, 0, 1, 0, 1, 1, 1, 1, 0, 1, 1, 1, 1, 0, 1, 0, 1, 1, 1, 0, 1, 0 },
}

export type ConvRule = {
	Input: number, -- 0 based color
	Output: number,
	Values: { number }?, -- 0 based colors sampled from the 3x3(x3) sum for sum= filtering
	Sums: { boolean }?, -- 1 indexed 1..28 (sum values 0..27)
	P: number,
}

export type ConvolutionData = {
	Rules: { ConvRule },
	Kernel: { number }, -- 9 (2D) or 27 (3D) entries 1indexed
	Periodic: boolean,
	Counter: number,
	Steps: number, -- <= 0 = unlimited
	SumField: { [number]: { number } }, -- 0 based per cell, each a 1 indexed length-C array
}

export type ConvRuleSpec = { In: string, Out: string, P: number?, Values: string?, Sum: string? }
export type ConvolutionConfig = {
	Rules: { ConvRuleSpec },
	Steps: number?,
	Periodic: boolean?,
	Neighborhood: string,
}

-- "4..8" -> {4,5,6,7,8}; "3" -> {3}.
local function parseInterval(s: string): { number }
	local dotPos = string.find(s, "%.%.")

	if dotPos then
		local min = tonumber(string.sub(s, 1, dotPos - 1)) :: number
		local max = tonumber(string.sub(s, dotPos + 2)) :: number
		local result = table.create(max - min + 1)

		for i = 0, max - min do
			result[i + 1] = min + i
		end

		return result
	end

	return { tonumber(s) :: number }
end

local function buildConvRule(
	spec: ConvRuleSpec,
	grid: Grid.Grid
): ConvRule
	local input = grid.Values[spec.In]
	assert(input, `Convolution: unknown in value "{spec.In}"`)

	local output = grid.Values[spec.Out]
	assert(output, `Convolution: unknown out value "{spec.Out}"`)

	assert((spec.Values == nil) == (spec.Sum == nil), "Convolution: values= and sum= must be given together")

	local values: { number }? = nil
	local sums: { boolean }? = nil

	if spec.Values then
		local valuesStr = spec.Values :: string
		local v: { number } = {}

		for i = 1, #valuesStr do
			local ch = string.sub(valuesStr, i, i)
			local color = grid.Values[ch]
			assert(color, `Convolution: unknown value "{ch}" in values=`)
			table.insert(v, color)
		end

		values = v
		local s = table.create(28, false)

		for interval in string.gmatch(spec.Sum :: string, "[^,]+") do
			for _, n in parseInterval(interval) do
				s[n + 1] = true
			end
		end

		sums = s
	end

	return { Input = input, Output = output, Values = values, Sums = sums, P = spec.P or 1.0 }
end

--[=[
	Creates a new Convolution node, applying cellular automaton neighbor-sum rules.
	@param config table -- The convolution configuration.
	@param grid table -- The parent grid.
	@return table -- The constructed Convolution node.
]=]
function Convolution.New(
	config: ConvolutionConfig,
	grid: Grid.Grid
): Node.Node
	local rules: { ConvRule } = table.create(#config.Rules)

	for _, spec in config.Rules do
		table.insert(rules, buildConvRule(spec, grid))
	end

	local kernel = if grid.MZ == 1 then KERNELS_2D[config.Neighborhood] else KERNELS_3D[config.Neighborhood]
	assert(kernel, `Convolution.New: unknown neighborhood "{config.Neighborhood}"`)

	local cellCount = grid.MX * grid.MY * grid.MZ
	local sumfield: { [number]: { number } } = table.create(cellCount)

	for i = 0, cellCount - 1 do
		sumfield[i] = table.create(grid.C, 0)
	end

	local data: ConvolutionData = {
		Rules = rules,
		Kernel = kernel,
		Periodic = config.Periodic or false,
		Counter = 0,
		Steps = config.Steps or -1,
		SumField = sumfield,
	}

	return { Kind = "Convolution", Parent = nil, Data = data }
end

local convolutionImpl: Node.NodeImpl = {
	Reset = function(node: Node.Node, _dispatch: Node.Dispatch)
		(node.Data :: ConvolutionData).Counter = 0
	end,
	Go = function(node: Node.Node, ip: Node.InterpreterState, _dispatch: Node.Dispatch): boolean
		local data = node.Data :: ConvolutionData

		if data.Steps > 0 and data.Counter >= data.Steps then
			return false
		end

		local grid = ip.Grid
		local mx, my, mz = grid.MX, grid.MY, grid.MZ
		local cellCount = mx * my * mz
		local sumfield = data.SumField
		local kernel = data.Kernel
		local periodic = data.Periodic

		for i = 0, cellCount - 1 do
			local sums = sumfield[i]

			for c = 1, #sums do
				sums[c] = 0
			end
		end

		if mz == 1 then
			for y = 0, my - 1 do
			for x = 0, mx - 1 do
				local sums = sumfield[x + y * mx]
				
				for dy = -1, 1 do
				for dx = -1, 1 do
					local sx, sy = x + dx, y + dy
					local inBounds = true

					if periodic then
						if sx < 0 then
							sx += mx
						elseif sx >= mx then
							sx -= mx
						end

						if sy < 0 then
							sy += my
						elseif sy >= my then
							sy -= my
						end
					elseif sx < 0 or sy < 0 or sx >= mx or sy >= my then
						inBounds = false
					end

					if inBounds then
						local v = buffer.readu8(grid.State, sx + sy * mx)
						sums[v + 1] += kernel[dx + 1 + (dy + 1) * 3 + 1]
					end
				end
				end
			end
			end
		else
			for z = 0, mz - 1 do
			for y = 0, my - 1 do
			for x = 0, mx - 1 do
				local sums = sumfield[x + (y + z * my) * mx]

				for dz = -1, 1 do
				for dy = -1, 1 do
				for dx = -1, 1 do
					local sx, sy, sz = x + dx, y + dy, z + dz
					local inBounds = true

					if periodic then

						if sx < 0 then
							sx += mx
						elseif sx >= mx then
							sx -= mx
						end

						if sy < 0 then
							sy += my
						elseif sy >= my then
							sy -= my
						end

						if sz < 0 then
							sz += mz
						elseif sz >= mz then
							sz -= mz
						end
					elseif sx < 0 or sy < 0 or sz < 0 or sx >= mx or sy >= my or sz >= mz then
						inBounds = false
					end

					if inBounds then
						local v = buffer.readu8(grid.State, sx + (sy + sz * my) * mx)
						sums[v + 1] += kernel[dx + 1 + (dy + 1) * 3 + (dz + 1) * 9 + 1]
					end
				end
				end
				end
			end
			end
			end
		end

		local change = false
		for i = 0, cellCount - 1 do
			local sums = sumfield[i]
			local input = buffer.readu8(grid.State, i)

			for _, rule in data.Rules do
				if input == rule.Input and rule.Output ~= input and (rule.P == 1.0 or ip.Random:NextNumber() < rule.P) then
					local success = true

					if rule.Sums then
						local sum = 0

						for _, v in rule.Values :: { number } do
							sum += sums[v + 1]
						end

						success = (rule.Sums :: { boolean })[sum + 1] == true
					end

					if success then
						buffer.writeu8(grid.State, i, rule.Output)
						change = true

						break
					end
				end
			end
		end

		data.Counter += 1
		return change
	end,
}
Convolution.Impl = convolutionImpl

return Convolution
