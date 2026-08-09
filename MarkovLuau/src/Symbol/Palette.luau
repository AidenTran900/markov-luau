--!strict
--!native
--!optimize 2

--[=[
	@class Palette
	
	Defines global symbol palettes, tags, and grouping structures.
]=]
local Palette = {}

export type SymbolId = number

export type PaletteEntry = {
	Name: string,
	Tags: { string },
	Groups: { string },
	Meta: { [string]: any }?,
}

export type Palette = {
	Entries: { PaletteEntry },
	ByName: { [string]: SymbolId },
	GroupMembers: { [string]: { SymbolId } },
}

export type EntrySpec = {
	Tags: { string }?,
	Groups: { string }?,
	Meta: { [string]: any }?,
}

--[=[
	Creates a new empty Palette.
	@return table -- The new Palette instance.
]=]
function Palette.New(): Palette
	return { Entries = {}, ByName = {}, GroupMembers = {} }
end

--[=[
	Registers a new symbol in the palette, or returns its existing ID if already registered.
	@param palette table -- The palette to modify.
	@param name string -- The name of the symbol.
	@param spec table? -- Optional metadata, tags, and group memberships.
	@return number -- The global SymbolId.
]=]
function Palette.Add(palette: Palette, name: string, spec: EntrySpec?): SymbolId
	local existing = palette.ByName[name]
	if existing then
		return existing
	end

	local s = spec or {}
	local entry: PaletteEntry = {
		Name = name,
		Tags = s.Tags or {},
		Groups = s.Groups or {},
		Meta = s.Meta,
	}
	local id = #palette.Entries + 1
	
	palette.Entries[id] = entry
	palette.ByName[name] = id

	for _, group in entry.Groups do
		local members = palette.GroupMembers[group]

		if not members then
			members = {}
			palette.GroupMembers[group] = members
		end

		table.insert(members, id)
	end
	return id
end

--[=[
	Retrieves the SymbolId for a given symbol name. Throws an error if not found.
	@param palette table -- The palette to query.
	@param name string -- The symbol name.
	@return number -- The SymbolId.
]=]
function Palette.Id(palette: Palette, name: string): SymbolId
	local id = palette.ByName[name]
	assert(id, `Palette.Id: unknown symbol "{name}"`)
	return id
end

--[=[
	Attempts to retrieve the SymbolId for a given symbol name. Returns nil if not found.
	@param palette table -- The palette to query.
	@param name string -- The symbol name.
	@return number? -- The SymbolId, or nil.
]=]
function Palette.TryId(palette: Palette, name: string): SymbolId?
	return palette.ByName[name]
end

--[=[
	Retrieves the full entry specification for a specific SymbolId.
	@param palette table -- The palette to query.
	@param id number -- The global SymbolId.
	@return table -- The PaletteEntry containing tags, groups, and metadata.
]=]
function Palette.Entry(palette: Palette, id: SymbolId): PaletteEntry
	local entry = palette.Entries[id]
	assert(entry, `Palette.Entry: unknown symbol id {id}`)
	return entry
end

--[=[
	Retrieves the string name of a specific SymbolId.
	@param palette table -- The palette to query.
	@param id number -- The global SymbolId.
	@return string -- The name of the symbol.
]=]
function Palette.Name(palette: Palette, id: SymbolId): string
	return Palette.Entry(palette, id).Name
end

--[=[
	Checks whether a symbol belongs to a specific group.
	@param palette table -- The palette to query.
	@param id number -- The global SymbolId.
	@param group string -- The name of the group.
	@return boolean -- True if the symbol is a member of the group.
]=]
function Palette.InGroup(palette: Palette, id: SymbolId, group: string): boolean
	local entry = palette.Entries[id]

	if not entry then
		return false
	end

	for _, g in entry.Groups do
		if g == group then
			return true
		end
	end
	
	return false
end

--[=[
	Retrieves all SymbolIds that belong to a specific group.
	@param palette table -- The palette to query.
	@param group string -- The name of the group.
	@return table -- An array of SymbolIds.
]=]
function Palette.Members(palette: Palette, group: string): { SymbolId }
	return palette.GroupMembers[group] or {}
end

return Palette
