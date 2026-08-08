--!strict
--!native
--!optimize 2
local VoxelField = require(script.Parent.Parent.Field.VoxelField)
local Palette = require(script.Parent.Parent.Symbol.Palette)
local Node = require(script.Parent.Parent.Node)

local Export = {}

export type MeshInput = {
	Field: VoxelField.VoxelField,
	Palette: Palette.Palette,
	GroupIndex: { [string]: number }, -- group name -> bit position (0 based, <32 groups)
	SymbolGroupBits: { [Palette.SymbolId]: number }, -- symbol -> bitset of which groups it belongs to
}

function Export.Build(field: VoxelField.VoxelField, palette: Palette.Palette): MeshInput
	local groupIndex: { [string]: number } = {}
	local nextBit = 0

	for _, entry in palette.Entries do
		for _, g in entry.Groups do
			if groupIndex[g] == nil then
				assert(nextBit < 32, `Export.Build: more than 32 distinct groups ("{g}" is #{nextBit + 1}), can't fit in one bitset word`)
				
				groupIndex[g] = nextBit
				nextBit += 1
			end
		end
	end

	local symbolGroupBits: { [Palette.SymbolId]: number } = {}
	for id = 1, #palette.Entries do
		local entry = palette.Entries[id]
		local bits = 0

		for _, g in entry.Groups do
			bits = bit32.bor(bits, bit32.lshift(1, groupIndex[g]))
		end

		symbolGroupBits[id] = bits
	end

	return {
		Field = field,
		Palette = palette,
		GroupIndex = groupIndex,
		SymbolGroupBits = symbolGroupBits,
	}
end

function Export.ChangesSince(ip: Node.InterpreterState, mark: number): { number }
	local dirty: { number } = {}

	for i = mark + 1, #ip.Changes do
		table.insert(dirty, ip.Changes[i])
	end

	return dirty
end

return Export
