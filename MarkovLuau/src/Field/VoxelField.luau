--!strict
--!native
--!optimize 2
--[=[
	@class VoxelField
	
	Data structure representing multi-channel voxel arrays for generation output.
]=]
local VoxelField = {}

export type ChannelType = "u8" | "u16"

export type ChannelSpec = { Name: string, Type: ChannelType }

export type VoxelField = {
	MX: number,
	MY: number,
	MZ: number,
	Material: buffer, -- u16 per cell: global SymbolId (Symbol/Palette.luau), written by rules
	Orientation: buffer, -- u8 per cell: Util/Orientation.luau element index, 0xff = none. written by rules, symmetry transformed
	Region: buffer, -- u16 per cell: region id, 0 = unassigned. written by layout/external seeding
	Mask: buffer, -- u8 per cell: interpreter scratch (region guards, match masks)
	Lock: buffer, -- u8 per cell: interpreter scratch (LockMask)
	Channels: { [string]: buffer }, -- host-defined extra channels, u8 or u16
	ChannelTypes: { [string]: ChannelType },
}

--[=[
	Creates a new multi-channel VoxelField instance.
	@param mx number -- The X dimension.
	@param my number -- The Y dimension.
	@param mz number -- The Z dimension.
	@param extraChannels table? -- Optional array of ChannelSpecs to allocate custom data channels.
	@return table -- The constructed VoxelField.
]=]
function VoxelField.New(
	mx: number,
	my: number,
	mz: number,
	extraChannels: { ChannelSpec }?
): VoxelField
	local n = mx * my * mz
	local field: VoxelField = {
		MX = mx,
		MY = my,
		MZ = mz,
		Material = buffer.create(n * 2),
		Orientation = buffer.create(n),
		Region = buffer.create(n * 2),
		Mask = buffer.create(n),
		Lock = buffer.create(n),
		Channels = {},
		ChannelTypes = {},
	}
	buffer.fill(field.Orientation, 0, 0xff, n)

	if extraChannels then
		for _, spec in extraChannels do
			assert(field.Channels[spec.Name] == nil, `VoxelField.New: repeating channel "{spec.Name}"`)
			local bytesPerCell = if spec.Type == "u16" then 2 else 1
			field.Channels[spec.Name] = buffer.create(n * bytesPerCell)
			field.ChannelTypes[spec.Name] = spec.Type
		end
	end

	return field
end

--[=[
	Calculates the 1D buffer index for a given 3D coordinate.
	@param field table -- The VoxelField context.
	@param x number -- The X coordinate.
	@param y number -- The Y coordinate.
	@param z number -- The Z coordinate.
	@return number -- The 0-based 1D index.
]=]
function VoxelField.Index(
	field: VoxelField,
	x: number,
	y: number,
	z: number
): number
	return x + y * field.MX + z * field.MX * field.MY
end

--[=[
	Gets the global material SymbolId at a specific cell index.
	@param field table -- The VoxelField context.
	@param index number -- The 0-based 1D index.
	@return number -- The u16 SymbolId.
]=]
function VoxelField.GetMaterial(
	field: VoxelField,
	index: number
): number
	return buffer.readu16(field.Material, index * 2)
end

--[=[
	Sets the global material SymbolId at a specific cell index.
	@param field table -- The VoxelField context.
	@param index number -- The 0-based 1D index.
	@param value number -- The u16 SymbolId to assign.
]=]
function VoxelField.SetMaterial(
	field: VoxelField,
	index: number,
	value: number
)
	buffer.writeu16(field.Material, index * 2, value)
end

--[=[
	Gets the orientation element index at a specific cell index.
	@param field table -- The VoxelField context.
	@param index number -- The 0-based 1D index.
	@return number -- The u8 orientation index, or 0xff if unoriented.
]=]
function VoxelField.GetOrientation(
	field: VoxelField,
	index: number
): number
	return buffer.readu8(field.Orientation, index)
end

--[=[
	Sets the orientation element index at a specific cell index.
	@param field table -- The VoxelField context.
	@param index number -- The 0-based 1D index.
	@param value number -- The u8 orientation index to assign.
]=]
function VoxelField.SetOrientation(
	field: VoxelField,
	index: number,
	value: number
)
	buffer.writeu8(field.Orientation, index, value)
end

--[=[
	Gets the assigned region ID at a specific cell index.
	@param field table -- The VoxelField context.
	@param index number -- The 0-based 1D index.
	@return number -- The u16 region ID.
]=]
function VoxelField.GetRegion(
	field: VoxelField,
	index: number
): number

	return buffer.readu16(field.Region, index * 2)
end

--[=[
	Sets the assigned region ID at a specific cell index.
	@param field table -- The VoxelField context.
	@param index number -- The 0-based 1D index.
	@param value number -- The u16 region ID to assign.
]=]
function VoxelField.SetRegion(
	field: VoxelField,
	index: number,
	value: number
)
	buffer.writeu16(field.Region, index * 2, value)
end

--[=[
	Reads a value from a custom named channel at a specific cell index.
	@param field table -- The VoxelField context.
	@param name string -- The name of the custom channel.
	@param index number -- The 0-based 1D index.
	@return number -- The u8 or u16 value stored in the channel.
]=]
function VoxelField.GetChannel(
	field: VoxelField,
	name: string,
	index: number
): number
	local buf = field.Channels[name]
	assert(buf, `VoxelField.GetChannel: unknown channel "{name}"`)

	if field.ChannelTypes[name] == "u16" then
		return buffer.readu16(buf, index * 2)
	end

	return buffer.readu8(buf, index)
end

--[=[
	Writes a value to a custom named channel at a specific cell index.
	@param field table -- The VoxelField context.
	@param name string -- The name of the custom channel.
	@param index number -- The 0-based 1D index.
	@param value number -- The value to assign.
]=]
function VoxelField.SetChannel(
	field: VoxelField,
	name: string,
	index: number,
	value: number
)
	local buf = field.Channels[name]
	assert(buf, `VoxelField.SetChannel: unknown channel "{name}"`)

	if field.ChannelTypes[name] == "u16" then
		buffer.writeu16(buf, index * 2, value)
	else
		buffer.writeu8(buf, index, value)
	end
end

return VoxelField
