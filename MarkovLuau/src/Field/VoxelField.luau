--!strict
--!native
--!optimize 2
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

function VoxelField.Index(
	field: VoxelField,
	x: number,
	y: number,
	z: number
): number
	return x + y * field.MX + z * field.MX * field.MY
end

function VoxelField.GetMaterial(
	field: VoxelField,
	index: number
): number
	return buffer.readu16(field.Material, index * 2)
end

function VoxelField.SetMaterial(
	field: VoxelField,
	index: number,
	value: number
)
	buffer.writeu16(field.Material, index * 2, value)
end

function VoxelField.GetOrientation(
	field: VoxelField,
	index: number
): number
	return buffer.readu8(field.Orientation, index)
end

function VoxelField.SetOrientation(
	field: VoxelField,
	index: number,
	value: number
)
	buffer.writeu8(field.Orientation, index, value)
end

function VoxelField.GetRegion(
	field: VoxelField,
	index: number
): number

	return buffer.readu16(field.Region, index * 2)
end

function VoxelField.SetRegion(
	field: VoxelField,
	index: number,
	value: number
)
	buffer.writeu16(field.Region, index * 2, value)
end

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
