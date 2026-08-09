--!strict
--!native
--!optimize 2
local Grid = require(script.Parent.Parent.Grid)
local Alphabet = require(script.Parent.Parent.Symbol.Alphabet)
local Palette = require(script.Parent.Parent.Symbol.Palette)
local Node = require(script.Parent.Parent.Node)

--[=[
	@class Scope
	
	Defines scopes for resolving and binding symbols to components.
]=]
local Scope = {}

export type Scope = {
	Parent: Grid.Grid,
	Local: Grid.Grid,
	Mark: number, -- #ip.Changes at Enter time
}

local function slotFor(
	alphabet: Alphabet.Alphabet,
	sym: Palette.SymbolId
): number?

	for i, bind in alphabet.Slots do
		if bind == sym then
			return i - 1
		end
	end

	for i, bind in alphabet.Slots do
		if type(bind) == "table" and Palette.InGroup(alphabet.Palette, sym, (bind :: { Group: string }).Group) then
			return i - 1
		end
	end

	for i, bind in alphabet.Slots do
		if bind == "Any" then
			return i - 1
		end
	end

	return nil
end

--[=[
	Resolves a global Palette SymbolId to a concrete local alphabet slot.
	@param alphabet table -- The alphabet defining local slots.
	@param sym number -- The global SymbolId.
	@return number? -- The 0-based local slot index, or nil if not found.
]=]
function Scope.SlotFixedTo(
	alphabet: Alphabet.Alphabet,
	sym: Palette.SymbolId
): number?

	for i, bind in alphabet.Slots do
		if bind == sym then
			return i - 1
		end
	end

	return nil
end

local slotFixedTo = Scope.SlotFixedTo

--[=[
	Enters a new grid scope, resolving parent symbols into local slots for child node execution.
	@param ip table -- The interpreter state.
	@param local_ table -- The child grid to activate.
	@return table -- The constructed Scope object containing the parent/local grid context.
]=]
function Scope.Enter(
	ip: Node.InterpreterState,
	local_: Grid.Grid
): Scope
	local parent = ip.Grid
	local alphabet = local_.Alphabet
	assert(parent.Alphabet.Palette == alphabet.Palette, "Scope.Enter: local grid's alphabet must be built against the parent grid's own Palette")
	assert(
		parent.MX == local_.MX and parent.MY == local_.MY and parent.MZ == local_.MZ,
		"Scope.Enter: local grid must have the same dimensions as the parent (Scope doesn't rescale, unlike Map)"
	)

	local n = parent.MX * parent.MY * parent.MZ
	for i = 0, n - 1 do
		local parentValue = buffer.readu8(parent.State, i)
		local sym = Alphabet.SymbolAt(parent.Alphabet, parentValue)
		assert(
			sym,
			`Scope.Enter: parent cell {i} has value {parentValue}, which isn't bound to a single global symbol (Scope.Enter needs a concretely-valued parent grid)`
		)
		local localValue = slotFor(alphabet, sym :: Palette.SymbolId)
		assert(localValue, `Scope.Enter: parent symbol "{Palette.Name(alphabet.Palette, sym :: Palette.SymbolId)}" isn't claimed by any local slot`)
		buffer.writeu8(local_.State, i, localValue :: number)
	end

	local mark = #ip.Changes
	ip.Grid = local_

	return { Parent = parent, Local = local_, Mark = mark }
end

--[=[
	Exits a grid scope, copying any modifications made in the local grid back to the parent grid.
	@param ip table -- The interpreter state.
	@param scope table -- The Scope object to exit from.
]=]
function Scope.Exit(
	ip: Node.InterpreterState,
	scope: Scope
)
	assert(ip.Grid == scope.Local, "Scope.Exit: ip.Grid isn't this scope's own local grid (mismatched Enter/Exit pair?)")

	local alphabet = scope.Local.Alphabet

	for n = scope.Mark + 1, #ip.Changes do
		local i = ip.Changes[n]
		local localValue = buffer.readu8(scope.Local.State, i)
		local bind = alphabet.Slots[localValue + 1]
		assert(
			type(bind) == "number",
			`Scope.Exit: local value {localValue} came from a Group/"Any" slot, not a single symbol -- component outputs must bind to a concrete symbol`
		)
		local sym = bind :: Palette.SymbolId
		local parentValue = slotFixedTo(scope.Parent.Alphabet, sym)
		assert(parentValue, `Scope.Exit: parent grid has no slot for symbol "{Palette.Name(alphabet.Palette, sym)}"`)
		buffer.writeu8(scope.Parent.State, i, parentValue :: number)
	end

	ip.Grid = scope.Parent
end

return Scope
