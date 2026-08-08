--!strict
--!native
--!optimize 2
local Rule = require(script.Parent.Rule)
local Alphabet = require(script.Parent.Symbol.Alphabet)
local Legend = require(script.Parent.Symbol.Legend)

local Grid = {}

export type Grid = {
	Alphabet: Alphabet.Alphabet,
	Legend: Legend.Legend,
	State: buffer,
	Mask: buffer,
	LockMask: buffer?,
	MX: number,
	MY: number,
	MZ: number,
	C: number,
	Characters: { string },
	Values: { [string]: number },
	Waves: { [string]: number },
	Transparent: number?,
	Folder: string?,
}

function Grid.Index(grid: Grid, x: number, y: number, z: number): number
	return x + (y + z * grid.MY) * grid.MX
end

-- Builds a grid over an already constructed Alphabet
function Grid.FromAlphabet(
	alphabet: Alphabet.Alphabet, 
	mx: number, 
	my: number, 
	mz: number
): Grid
	local legend = Legend.New(alphabet)
	local cellCount = mx * my * mz

	return {
		Alphabet = alphabet,
		Legend = legend,
		State = buffer.create(cellCount),
		Mask = buffer.create(cellCount),
		MX = mx,
		MY = my,
		MZ = mz,
		C = alphabet.Size,
		Characters = alphabet.Chars,
		Values = legend.Values,
		Waves = legend.Waves,
	}
end

function Grid.New(values: string, mx: number, my: number, mz: number, transparentValues: string?): Grid
	local grid = Grid.FromAlphabet(Alphabet.Identity(values), mx, my, mz)

	if transparentValues then
		grid.Transparent = Grid.Wave(grid, transparentValues)
	end

	return grid
end

function Grid.AddUnion(grid: Grid, symbol: string, values: string)
	Legend.AddUnion(grid.Legend, symbol, values)
end

function Grid.Clear(grid: Grid)
	buffer.fill(grid.State, 0, 0, buffer.len(grid.State))
end

function Grid.Wave(grid: Grid, values: string): number
	local sum = 0
	for i = 1, #values do
		local symbol = string.sub(values, i, i)
		local w = grid.Waves[symbol]
		assert(w, `Grid.Wave: unknown symbol "{symbol}"`)
		sum = bit32.bor(sum, w)
	end
	return sum
end

function Grid.Matches(grid: Grid, rule: Rule.Rule, x: number, y: number, z: number): boolean
	local mx, my = grid.MX, grid.MY
	local state = grid.State
	local i = 1

	for dz = 0, rule.IMZ - 1 do
		local zOffset = (z + dz) * mx * my

		for dy = 0, rule.IMY - 1 do
			local offset = x + (y + dy) * mx + zOffset

			for dx = 0, rule.IMX - 1 do
				local cellState = buffer.readu8(state, offset + dx)

				if bit32.band(rule.Input[i], bit32.lshift(1, cellState)) == 0 then
					return false
				end

				i += 1
			end
		end
	end

	if grid.LockMask then
		local lockMask = grid.LockMask
		local outOutput = rule.Output
		local oi = 0

		for oz = 0, rule.OMZ - 1 do
			local zOffset = (z + oz) * mx * my

			for oy = 0, rule.OMY - 1 do
				local offset = x + (y + oy) * mx + zOffset

				for ox = 0, rule.OMX - 1 do
					local outValue = buffer.readu8(outOutput, oi)

					if outValue ~= 0xff and buffer.readu8(lockMask, offset + ox) ~= 0 then
						return false
					end
					
					oi += 1
				end
			end
		end
	end

	return true
end

return Grid
