--!strict
--!native
--!optimize 2

local Palette = require(script.Parent.Palette)

--[=[
	@class Alphabet
	
	Maps pattern characters to palette symbols or component bindings.
]=]
local Alphabet = {}

export type Binding = Palette.SymbolId | { Group: string } | "Any"

export type Alphabet = {
	Palette: Palette.Palette,
	Size: number, -- <= 31
	Slots: { Binding }, -- Slots[i] is local value (i-1) binding
	Chars: { string }, -- Chars[i] is local value (i-1) pattern character
	ByChar: { [string]: number }, -- pattern character -> local value (0 based)
	ByRole: { [string]: number }, -- role name -> local value (0 based)
}

export type SlotSpec = { Char: string, Bind: Binding, Role: string? }

--[=[
	Creates a new Alphabet mapped to a specific Palette.
	@param palette table -- The parent palette to draw symbols from.
	@param slots table -- The array of slot specifications mapping pattern characters to bindings.
	@return table -- The constructed Alphabet.
]=]
function Alphabet.New(palette: Palette.Palette, slots: { SlotSpec }): Alphabet
	local size = #slots
	assert(size <= 31, `Alphabet.New: alphabet has {size} symbols, the wave bitmask format caps at 31`)

	local bindings: { Binding } = table.create(size)
	local chars: { string } = table.create(size)
	local byChar: { [string]: number } = {}
	local byRole: { [string]: number } = {}

	for i, slot in slots do
		assert(byChar[slot.Char] == nil, `Alphabet.New: repeating pattern character "{slot.Char}"`)

		bindings[i] = slot.Bind
		chars[i] = slot.Char
		byChar[slot.Char] = i - 1

		if slot.Role then
			assert(byRole[slot.Role] == nil, `Alphabet.New: repeating role "{slot.Role}"`)

			byRole[slot.Role] = i - 1
		end
	end

	return {
		Palette = palette,
		Size = size,
		Slots = bindings,
		Chars = chars,
		ByChar = byChar,
		ByRole = byRole,
	}
end

--[=[
	Creates an identity Alphabet directly from a string of unique characters.
	@param values string -- The string of unique characters.
	@return table -- The generated Alphabet and its implicit underlying Palette.
]=]
function Alphabet.Identity(values: string): Alphabet
	local palette = Palette.New()
	local slots: { SlotSpec } = table.create(#values)

	for i = 1, #values do
		local ch = string.sub(values, i, i)
		local id = Palette.Add(palette, ch)
		slots[i] = { Char = ch, Bind = id }
	end

	return Alphabet.New(palette, slots)
end

--[=[
	Resolves a local alphabet value back to its global Palette SymbolId, if it represents a single specific symbol.
	@param alphabet table -- The alphabet.
	@param localValue number -- The zero-based local slot index.
	@return number? -- The global SymbolId, or nil if the slot is bound to a group or "Any".
]=]
function Alphabet.SymbolAt(alphabet: Alphabet, localValue: number): Palette.SymbolId?
	local bind = alphabet.Slots[localValue + 1]

	if type(bind) == "number" then
		return bind
	end
	
	return nil
end

return Alphabet
