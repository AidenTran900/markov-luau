--!strict
local AssetService = game:GetService("AssetService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local MarkovJunior = require(ReplicatedStorage.MarkovJunior)
local Grid = MarkovJunior.Grid

local VoxelMesher = {}

export type Palette = { [string]: Color3 }

export type BuildOptions = {
	CellSize: number?, -- studs per voxel, default 1
	SkipValue: number?, -- 0-based grid value treated as empty/background, default 0
	DefaultColor: Color3?, -- used for any symbol missing from the palette
}

local FACES = {
	{ D = Vector3.new(1, 0, 0), Corners = { { 1, 0, 0 }, { 1, 1, 0 }, { 1, 1, 1 }, { 1, 0, 1 } } }, -- +X
	{ D = Vector3.new(-1, 0, 0), Corners = { { 0, 0, 0 }, { 0, 0, 1 }, { 0, 1, 1 }, { 0, 1, 0 } } }, -- -X
	{ D = Vector3.new(0, 1, 0), Corners = { { 0, 1, 0 }, { 0, 1, 1 }, { 1, 1, 1 }, { 1, 1, 0 } } }, -- +Y
	{ D = Vector3.new(0, -1, 0), Corners = { { 0, 0, 0 }, { 1, 0, 0 }, { 1, 0, 1 }, { 0, 0, 1 } } }, -- -Y
	{ D = Vector3.new(0, 0, 1), Corners = { { 0, 0, 1 }, { 1, 0, 1 }, { 1, 1, 1 }, { 0, 1, 1 } } }, -- +Z
	{ D = Vector3.new(0, 0, -1), Corners = { { 0, 0, 0 }, { 0, 1, 0 }, { 1, 1, 0 }, { 1, 0, 0 } } }, -- -Z
}

local MAX_QUADS_PER_CHUNK = 9000

function VoxelMesher.Build(grid: Grid.Grid, palette: Palette, options: BuildOptions?): ({ EditableMesh }, number)
	local opts = options or {}
	local cellSize = opts.CellSize or 1
	local skipValue = opts.SkipValue or 0
	local defaultColor = opts.DefaultColor or Color3.new(1, 0, 1)

	local chunks: { EditableMesh } = {}
	local mesh: EditableMesh
	local colorIds: { [string]: number }
	local chunkQuads = 0

	local function startChunk()
		mesh = AssetService:CreateEditableMesh()
		table.insert(chunks, mesh)
		colorIds = {}
		chunkQuads = 0
	end
	startChunk()
	local function colorId(color: Color3): number
		local key = tostring(color)
		local id = colorIds[key]
		if id == nil then
			id = mesh:AddColor(color, 1)
			colorIds[key] = id
		end
		return id :: number
	end

	local mx, my, mz = grid.MX, grid.MY, grid.MZ
	local function cellValue(x: number, y: number, z: number): number?
		if x < 0 or y < 0 or z < 0 or x >= mx or y >= my or z >= mz then
			return nil
		end
		return buffer.readu8(grid.State, Grid.Index(grid, x, y, z))
	end

	local totalQuads = 0
	local solidCells = 0
	for z = 0, mz - 1 do
		for y = 0, my - 1 do
			for x = 0, mx - 1 do
				local value = cellValue(x, y, z) :: number
				if value ~= skipValue then
					solidCells += 1
					if solidCells % 4000 == 0 then
						task.wait()
					end
					local symbol = grid.Characters[value + 1]
					local cid = colorId(palette[symbol] or defaultColor)

					for _, face in FACES do
						local nv = cellValue(x + face.D.X, y + face.D.Y, z + face.D.Z)
						if nv == nil or nv == skipValue then
							if chunkQuads >= MAX_QUADS_PER_CHUNK then
								mesh:RemoveUnused()
								startChunk()
								cid = colorId(palette[symbol] or defaultColor)
							end
							local ids = table.create(4)
							for i, corner in face.Corners do
								-- MarkovJunior's grid is Z-up but Roblox is Y-up
								ids[i] = mesh:AddVertex(Vector3.new(
									(x + corner[1]) * cellSize,
									(z + corner[3]) * cellSize,
									-(y + corner[2]) * cellSize
								))
							end
							local t1 = mesh:AddTriangle(ids[1], ids[2], ids[3])
							local t2 = mesh:AddTriangle(ids[1], ids[3], ids[4])
							mesh:SetFaceColors(t1, { cid, cid, cid })
							mesh:SetFaceColors(t2, { cid, cid, cid })
							chunkQuads += 1
							totalQuads += 1
						end
					end
				end
			end
		end
	end

	if chunkQuads == 0 then
		local emptyMesh = table.remove(chunks)
		if emptyMesh then
			emptyMesh:Destroy()
		end
	else
		mesh:RemoveUnused()
	end
	return chunks, totalQuads
end

function VoxelMesher.CreateMeshPart(mesh: EditableMesh, parent: Instance?): MeshPart
	local content = Content.fromObject(mesh)
	local meshPart = AssetService:CreateMeshPartAsync(content, { CollisionFidelity = Enum.CollisionFidelity.Box })
	meshPart.Anchored = true
	meshPart.Material = Enum.Material.SmoothPlastic
	meshPart.Parent = parent
	return meshPart
end

function VoxelMesher.BuildAndDisplay(
	grid: Grid.Grid,
	palette: Palette,
	parent: Instance,
	name: string,
	position: Vector3,
	options: BuildOptions?
): ({ MeshPart }, number)
	local chunks, quads = VoxelMesher.Build(grid, palette, options)
	local parts = table.create(#chunks)
	for i, chunkMesh in chunks do
		local part = VoxelMesher.CreateMeshPart(chunkMesh, parent)
		part.Name = if #chunks > 1 then `{name}_{i}` else name
		part.Position = part.Position + position
		parts[i] = part
	end
	return parts, quads, chunks
end

return VoxelMesher
