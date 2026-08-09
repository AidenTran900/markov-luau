--!strict
--!native
--!optimize 2
--[=[
	@class Sample
	
	Defines types and utilities for resolving external resources like images and tilesets.
]=]
local Sample = {}

export type ImageResource = {
	Width: number,
	Height: number,
	Depth: number,
	Data: { number },
	Legend: string?,
}

export type TileResource = {
	Name: string,
	Weight: number?,
	Voxels: { number },
}

export type NeighborResource = {
	Left: string?,
	Right: string?,
	Top: string?,
	Bottom: string?,
}

export type TilesetResource = {
	FullSymmetry: boolean,
	S: number,
	SZ: number,
	Tiles: { TileResource },
	Neighbors: { NeighborResource },
}

export type Resolver = {
	ResolveImage: ((name: string, folder: string?) -> ImageResource)?,
	ResolveSample: ((name: string) -> ImageResource)?,
	ResolveTileset: ((name: string, tilesFolder: string) -> TilesetResource)?,
}

--[=[
	A helper method to safely extract a required callback from the Resolver dictionary.
	@param resolver table? -- The resolver table provided at execution time.
	@param field string -- The name of the specific resolve callback required.
	@param name string -- The identifier of the resource being requested (for error logging).
	@return function -- The callback function.
]=]
function Sample.Require(resolver: Resolver?, field: string, name: string): any
	local fn = resolver and (resolver :: any)[field]
	assert(fn, `Sample: model needs "{name}" ({field}) but no resolver.{field} was given`)
	return fn
end

return Sample
