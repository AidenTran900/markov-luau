--!strict
--!native
--!optimize 2
local Grid = require(script.Parent.Parent.Grid)
local Rule = require(script.Parent.Parent.Rule)
local Queue = require(script.Parent.Parent.Util.Queue)
local Node = require(script.Parent.Parent.Node)
local Constants = require(script.Parent.Parent.Util.Constants)

--[=[
	@class Field
]=]
local Field = {}

export type FieldSpec = {
	On: string,
	From: string?,
	To: string?,
	Recompute: boolean?,
	Essential: boolean?,
	Source: ("Computed" | "External")?,
	Name: string?,
}

export type Field = {
	Recompute: boolean,
	Inversed: boolean,
	Essential: boolean,
	Zero: number,
	Substrate: number,
	Source: ("Computed" | "External")?,
	Name: string?,
}

--[=[
	Creates a new Field instance representing a scalar potential field used for heuristic search.
	@param spec table -- The field configuration specification.
	@param grid table -- The parent grid.
	@return table -- The constructed Field data structure.
]=]
function Field.New(spec: FieldSpec, grid: Grid.Grid): Field
	if spec.Source == "External" then
		assert(spec.Name, `Field.New: Source="External" needs a Name naming the ip.Fields key`)

		return {
			Recompute = spec.Recompute or false,
			Essential = spec.Essential or false,
			Inversed = false,
			Zero = 0,
			Substrate = 0,
			Source = "External",
			Name = spec.Name,
		}
	end

	local inversed = spec.From ~= nil
	local zeroSymbols = spec.From or spec.To
	assert(zeroSymbols, "Field.New: neither from= nor to= given")

	return {
		Recompute = spec.Recompute or false,
		Essential = spec.Essential or false,
		Inversed = inversed,
		Zero = Grid.Wave(grid, zeroSymbols),
		Substrate = Grid.Wave(grid, spec.On),
	}
end



local function computeExternal(
	field: Field,
	potential: { [number]: number },
	grid: Grid.Grid,
	ip: Node.InterpreterState
): boolean
	local source = ip.Fields and ip.Fields[field.Name :: string]

	assert(source, `Field.Compute: external field "{field.Name}" not found in ip.Fields`)
	
	local cellCount = grid.MX * grid.MY * grid.MZ
	local any = false

	for i = 0, cellCount - 1 do
		local v = source[i]
		potential[i] = v

		if v ~= nil and v >= 0 then
			any = true
		end
	end

	return any
end

--[=[
	Computes the potential field by calculating distances from the zero-set, propagating through the substrate.
	@param field table -- The field configuration.
	@param potential table -- The output array where distance values will be written.
	@param grid table -- The parent grid.
	@param ip table -- The interpreter state.
	@return boolean -- True if the field was successfully computed and has valid potentials.
]=]
function Field.Compute(
	field: Field,
	potential: { [number]: number },
	grid: Grid.Grid,
	ip: Node.InterpreterState
): boolean

	if field.Source == "External" then
		return computeExternal(field, potential, grid, ip)
	end

	local mx, my, mz = grid.MX, grid.MY, grid.MZ
	local front = Queue.New()
	local ix, iy, iz = 0, 0, 0
	local cellCount = mx * my * mz

	for i = 0, cellCount - 1 do
		potential[i] = -1
		local value = buffer.readu8(grid.State, i)

		if bit32.band(field.Zero, bit32.lshift(1, value)) ~= 0 then
			potential[i] = 0
			Queue.Push(front, { T = 0, X = ix, Y = iy, Z = iz })
		end

		ix += 1

		if ix == mx then
			ix = 0
			iy += 1

			if iy == my then
				iy = 0
				iz += 1
			end
		end
	end

	if Queue.IsEmpty(front) then

		return false
	end

	while not Queue.IsEmpty(front) do
		local item = Queue.Pop(front) :: { T: number, X: number, Y: number, Z: number }

		for d = 1, 6 do
			local nx, ny, nz = item.X + Constants.DIR_X[d], item.Y + Constants.DIR_Y[d], item.Z + Constants.DIR_Z[d]

			if nx >= 0 and nx < mx and ny >= 0 and ny < my and nz >= 0 and nz < mz then
				local i = nx + (ny + nz * my) * mx
				local v = buffer.readu8(grid.State, i)

				if potential[i] == -1 and bit32.band(field.Substrate, bit32.lshift(1, v)) ~= 0 then
					Queue.Push(front, { T = item.T + 1, X = nx, Y = ny, Z = nz })
					potential[i] = item.T + 1
				end
			end
		end
	end

	return true
end

--[=[
	Calculates the net change in potential if a specific rule were applied at the given coordinates.
	Used by Markov search algorithms to evaluate rule candidates.
	@param state buffer -- The grid's voxel state buffer.
	@param rule table -- The rule being evaluated.
	@param x number -- X coordinate of the match.
	@param y number -- Y coordinate of the match.
	@param z number -- Z coordinate of the match.
	@param fields table? -- The array of active fields mapping to symbols.
	@param potentials table -- The array of computed potential values.
	@param mx number -- Grid X dimension.
	@param my number -- Grid Y dimension.
	@return number? -- The numeric potential delta, or nil if a required potential is missing/invalid.
]=]
function Field.DeltaPointwise(
	state: buffer,
	rule: Rule.Rule,
	x: number,
	y: number,
	z: number,
	fields: { Field? }?,
	potentials: { { [number]: number } },
	mx: number,
	my: number
): number?
	local sum = 0
	local out = rule.Output
	local input = rule.Input
	local i = 0

	for dz = 0, rule.IMZ - 1 do
		local zOffset = (z + dz) * my

		for dy = 0, rule.IMY - 1 do
			local yOffset = (y + dy + zOffset) * mx

			for dx = 0, rule.IMX - 1 do
				local newValue = buffer.readu8(out, i)

				if newValue ~= 0xff and bit32.band(input[i + 1], bit32.lshift(1, newValue)) == 0 then
					local idx = x + dx + yOffset
					local newPotential = potentials[newValue + 1][idx]

					if newPotential == -1 then

						return nil
					end

					local oldValue = buffer.readu8(state, idx)
					local oldPotential = potentials[oldValue + 1][idx]
					sum += newPotential - oldPotential

					if fields then
						local oldField = fields[oldValue + 1]

						if oldField and oldField.Inversed then
							sum += 2 * oldPotential
						end

						local newField = fields[newValue + 1]

						if newField and newField.Inversed then
							sum -= 2 * newPotential
						end
					end
				end

				i += 1
			end
		end
	end

	return sum
end

return Field
