--!strict
--!native
--!optimize 2
local VoxelField = require(script.Parent.Parent.Field.VoxelField)
local Export = require(script.Parent.Export)
local Constants = require(script.Parent.Parent.Util.Constants)

--[=[
	@class Neighborhood
	
	Calculates voxel neighborhood adjacency masks for procedural meshing.
]=]
local Neighborhood = {}



local function mask(
	input: Export.MeshInput,
	index: number,
	group: string,
	dirs: { { number } }
): number
	local bit = input.GroupIndex[group]

	assert(bit, `Neighborhood: unknown group "{group}"`)
	
	local groupBit = bit32.lshift(1, bit)

	local field = input.Field
	local mx, my, mz = field.MX, field.MY, field.MZ
	local x = index % mx
	local y = (index // mx) % my
	local z = index // (mx * my)

	local result = 0

	for i, d in dirs do
		local nx, ny, nz = x + d[1], y + d[2], z + d[3]

		if nx >= 0 and ny >= 0 and nz >= 0 and nx < mx and ny < my and nz < mz then
			local sym = VoxelField.GetMaterial(field, VoxelField.Index(field, nx, ny, nz))
			local bits = input.SymbolGroupBits[sym]

			if bits and bit32.band(bits, groupBit) ~= 0 then
				result = bit32.bor(result, bit32.lshift(1, i - 1))
			end
		end
	end

	return result
end

-- 6 bit mask (-x,+x,-y,+y,-z,+z)
function Neighborhood.Mask6(
	input: Export.MeshInput,
	index: number,
	group: string
): number

	return mask(input, index, group, Constants.DIRS6)
end

-- 3x3x3 block
function Neighborhood.Mask26(
	input: Export.MeshInput,
	index: number,
	group: string
): number

	return mask(input, index, group, Constants.DIRS26)
end

return Neighborhood
