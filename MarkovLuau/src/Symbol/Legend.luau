--!strict
--!native
--!optimize 2

--[[
	Compiles pattern characters (rule in=/out=/Luau Pattern literal) 
	down to the wave bitmasks and single val bytes
]]

local Alphabet = require(script.Parent.Alphabet)
local Palette = require(script.Parent.Palette)

--[=[
	@class Legend
	
	Compiles pattern characters into wave bitmasks for the constraint solver.
]=]
local Legend = {}

export type GroupBinding = { Group: string }
export type NotBinding = { Not: string }
export type ExtraBinding = Palette.SymbolId | string | GroupBinding | NotBinding | "Any"

export type Legend = {
	Alphabet: Alphabet.Alphabet,
	Waves: { [string]: number },
	Values: { [string]: number },
}

local function fullWave(size: number): number
	return bit32.lshift(1, size) - 1
end

local function groupWave(alphabet: Alphabet.Alphabet, group: string): number
	local sum = 0
	for i, bind in alphabet.Slots do
		if type(bind) == "number" and Palette.InGroup(alphabet.Palette, bind, group) then
			sum = bit32.bor(sum, bit32.lshift(1, i - 1))
		end
	end
	return sum
end

--[=[
	Binds a pattern character to an extra logical binding (like a Group, Not expression, or "Any").
	@param legend table -- The legend to update.
	@param char string -- The pattern character.
	@param bind any -- The extra binding definition.
]=]
function Legend.Bind(legend: Legend, char: string, bind: ExtraBinding)
	local alphabet = legend.Alphabet

	if bind == "Any" then
		legend.Waves[char] = fullWave(alphabet.Size)

	elseif type(bind) == "number" then
		local sum = 0
		local single: number? = nil
		local count = 0

		for i, slotBind in alphabet.Slots do
			if slotBind == bind then
				sum = bit32.bor(sum, bit32.lshift(1, i - 1))
				single = i - 1
				count += 1
			end
		end

		assert(count > 0, `Legend.Bind: symbol id {bind} has no local slot in this alphabet`)

		legend.Waves[char] = sum
		if count == 1 then
			legend.Values[char] = single :: number
		end

	elseif type(bind) == "string" then
		local w = legend.Waves[bind]
		assert(w, `Legend.Bind: unknown symbol "{bind}"`)

		legend.Waves[char] = w
		if legend.Values[bind] then
			legend.Values[char] = legend.Values[bind]
		end

	elseif type(bind) == "table" then
		if (bind :: GroupBinding).Group then
			legend.Waves[char] = groupWave(alphabet, (bind :: GroupBinding).Group)

		elseif (bind :: NotBinding).Not then
			local of = (bind :: NotBinding).Not
			local w = legend.Waves[of]

			assert(w, `Legend.Bind: unknown symbol "{of}" in Not(...)`)

			legend.Waves[char] = bit32.bxor(fullWave(alphabet.Size), w)

		else
			error(`Legend.Bind: unrecognized binding table for "{char}"`, 0)
		end
	else
		error(`Legend.Bind: unrecognized binding for "{char}"`, 0)
	end
end

--[=[
	Creates a new Legend for a specific Alphabet, optionally evaluating extra bindings.
	@param alphabet table -- The base alphabet.
	@param extra table? -- Optional extra bindings.
	@return table -- The constructed Legend.
]=]
function Legend.New(alphabet: Alphabet.Alphabet, extra: { [string]: ExtraBinding }?): Legend
	local waves: { [string]: number } = {}
	local values: { [string]: number } = {}

	for i, ch in alphabet.Chars do
		local localValue = i - 1

		waves[ch] = bit32.lshift(1, localValue)

		if type(alphabet.Slots[i]) == "number" then
			values[ch] = localValue
		end
	end

	waves["*"] = fullWave(alphabet.Size)

	local legend: Legend = { Alphabet = alphabet, Waves = waves, Values = values }
	
	if extra then
		for ch, bind in extra do
			Legend.Bind(legend, ch, bind)
		end
	end

	return legend
end

--[=[
	Adds a new pattern symbol that represents the logical OR (union) of a string of other pattern symbols.
	@param legend table -- The legend to update.
	@param symbol string -- The new union pattern character.
	@param values string -- The characters to combine into the union.
]=]
function Legend.AddUnion(legend: Legend, symbol: string, values: string)
	assert(legend.Waves[symbol] == nil, `Legend.AddUnion: repeating union type "{symbol}"`)

	local sum = 0
	for i = 1, #values do
		local ch = string.sub(values, i, i)
		local w = legend.Waves[ch]

		assert(w, `Legend.AddUnion: unknown symbol "{ch}"`)

		sum = bit32.bor(sum, w)
	end
	
	legend.Waves[symbol] = sum
end

return Legend
