--!strict
--!native
--!optimize 2
local Rule = require(script.Parent.Rule)
local Alphabet = require(script.Parent.Symbol.Alphabet)
local Legend = require(script.Parent.Symbol.Legend)

--[=[
	@class Grid
	
	Represents the 3D grid state and logic for wave function collapse and rule matching.
]=]
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

--[=[
	Calculates the 1D buffer index for a given 3D grid coordinate.
	@param grid table -- The grid to index into.
	@param x number -- The X coordinate.
	@param y number -- The Y coordinate.
	@param z number -- The Z coordinate.
	@return number -- The computed 1D index.
]=]
function Grid.Index(grid: Grid, x: number, y: number, z: number): number
	return x + (y + z * grid.MY) * grid.MX
end

--[=[
	Builds a new Grid over an already constructed Alphabet.
	@param alphabet table -- The alphabet containing symbols and character mappings.
	@param mx number -- The X dimension size.
	@param my number -- The Y dimension size.
	@param mz number -- The Z dimension size.
	@return table -- The constructed Grid object.
]=]
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

--[=[
	Instantiates a new Grid from a string of base values representing its Alphabet.
	@param values string -- The set of unique characters defining the grid's initial symbols.
	@param mx number -- The X dimension size.
	@param my number -- The Y dimension size.
	@param mz number -- The Z dimension size.
	@param transparentValues string? -- Optional characters considered transparent or invisible.
	@return table -- The newly initialized Grid object.
]=]
function Grid.New(values: string, mx: number, my: number, mz: number, transparentValues: string?): Grid
	local grid = Grid.FromAlphabet(Alphabet.Identity(values), mx, my, mz)

	if transparentValues then
		grid.Transparent = Grid.Wave(grid, transparentValues)
	end

	return grid
end

--[=[
	Binds a new symbol character to represent a union of multiple other characters.
	@param grid table -- The grid to update.
	@param symbol string -- The character representing the union group.
	@param values string -- The characters making up the union.
]=]
function Grid.AddUnion(grid: Grid, symbol: string, values: string)
	Legend.AddUnion(grid.Legend, symbol, values)
end

--[=[
	Clears the grid state by setting all cell values to zero.
	@param grid table -- The grid to clear.
]=]
function Grid.Clear(grid: Grid)
	buffer.fill(grid.State, 0, 0, buffer.len(grid.State))
end

--[=[
	Combines the bitmasks of a string of values into a single compound wave integer.
	@param grid table -- The grid defining the symbols.
	@param values string -- The characters to combine into a single wave.
	@return number -- The aggregated wave bitmask.
]=]
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

--[=[
	Evaluates whether a Markov rule matches the grid state at a specific coordinate.
	@param grid table -- The grid to check against.
	@param rule table -- The rule definition to match.
	@param x number -- The starting X coordinate for the match.
	@param y number -- The starting Y coordinate for the match.
	@param z number -- The starting Z coordinate for the match.
	@return boolean -- True if the rule perfectly aligns with the grid subset; false otherwise.
]=]
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
