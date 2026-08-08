-- Builds a MarkovJunior.Sample.Resolver backed by the vox/tileset data
-- tools/convert_resources.py baked out of MarkovJunior/resources/** at
-- authoring time (Roblox experiences can't read arbitrary files off disk at
-- runtime, so those .vox/.xml files are decoded once, offline, into the
-- plain Luau tables under MarkovData/).
local MarchingHillsTileset = require(script.Parent.MarkovData.MarchingHillsTileset)
local PathsTileset = require(script.Parent.MarkovData.PathsTileset)
local PartitionTileset = require(script.Parent.MarkovData.PartitionTileset)
local PartitionedEdgesTileset = require(script.Parent.MarkovData.PartitionedEdgesTileset)

local IMAGE_FOLDERS = {
}

local TILESETS = {
	MarchingHills = MarchingHillsTileset,
	Paths = PathsTileset,
	Partition = PartitionTileset,
	PartitionedEdges = PartitionedEdgesTileset,
}

local Resolver = {}

function Resolver.New()
	return {
		ResolveImage = function(name: string, folder: string?)
			local images = folder and IMAGE_FOLDERS[folder]
			assert(images, `Resolver.ResolveImage: no baked resources for folder "{tostring(folder)}"`)
			local entry = images[name]
			assert(entry, `Resolver.ResolveImage: unknown resource "{name}" in folder "{tostring(folder)}"`)
			return entry
		end,
		ResolveTileset = function(name: string, _tilesFolder: string)
			local tileset = TILESETS[name]
			assert(tileset, `Resolver.ResolveTileset: unknown tileset "{name}"`)
			return tileset
		end,
	}
end

return Resolver
