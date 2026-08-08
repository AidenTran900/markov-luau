--!strict
--!native
--!optimize 2

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

function Palette.New(): Palette
	return { Entries = {}, ByName = {}, GroupMembers = {} }
end

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

function Palette.Id(palette: Palette, name: string): SymbolId
	local id = palette.ByName[name]
	assert(id, `Palette.Id: unknown symbol "{name}"`)
	return id
end

function Palette.TryId(palette: Palette, name: string): SymbolId?
	return palette.ByName[name]
end

function Palette.Entry(palette: Palette, id: SymbolId): PaletteEntry
	local entry = palette.Entries[id]
	assert(entry, `Palette.Entry: unknown symbol id {id}`)
	return entry
end

function Palette.Name(palette: Palette, id: SymbolId): string
	return Palette.Entry(palette, id).Name
end

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

function Palette.Members(palette: Palette, group: string): { SymbolId }
	return palette.GroupMembers[group] or {}
end

return Palette
