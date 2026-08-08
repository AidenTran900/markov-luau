--!strict
--!native
--!optimize 2
local RegionTable = {}

export type Bounds = { MinX: number, MinY: number, MinZ: number, MaxX: number, MaxY: number, MaxZ: number }

export type RegionEntry = {
	Kind: string?,
	Bounds: Bounds?,
	Connections: { number }?, -- other region ids this one connects to
	Meta: { [string]: any }?,
}

export type RegionTable = { [number]: RegionEntry }

function RegionTable.New(): RegionTable

	return {}
end

function RegionTable.Add(
	regions: RegionTable,
	id: number,
	entry: RegionEntry
)
	regions[id] = entry
end

function RegionTable.Get(
	regions: RegionTable,
	id: number
): RegionEntry?

	return regions[id]
end

return RegionTable
