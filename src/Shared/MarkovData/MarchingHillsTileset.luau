--!strict

-- MarchingHills tileset, converted from resources/tilesets/MarchingHills.xml + MarchingHills/*.vox
return {
	FullSymmetry = false,
	S = 3,
	SZ = 3,
	Tiles = {
		{ Name = "Empty", Weight = 2.3, Voxels = {
		-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,
	} },
		{ Name = "Stone", Weight = 1.7, Voxels = {
		42,42,42,42,42,42,42,42,42,-1,-1,-1,-1,31,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,
	} },
		{ Name = "Wall", Weight = 1.3, Voxels = {
		42,42,-1,42,42,-1,42,42,-1,-1,-1,-1,-1,31,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,
	} },
		{ Name = "In", Weight = nil, Voxels = {
		42,42,42,42,42,42,42,42,-1,-1,-1,-1,-1,31,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,
	} },
		{ Name = "Out", Weight = nil, Voxels = {
		42,42,-1,42,42,-1,-1,-1,-1,-1,-1,-1,-1,31,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,
	} },
	},
	Neighbors = {
		{ Left = "Empty", Right = "Empty", Top = nil, Bottom = nil },
		{ Left = "Empty", Right = "z Out", Top = nil, Bottom = nil },
		{ Left = "Wall", Right = "Empty", Top = nil, Bottom = nil },
		{ Left = "z Wall", Right = "Out", Top = nil, Bottom = nil },
		{ Left = "In", Right = "Out", Top = nil, Bottom = nil },
		{ Left = "z Wall", Right = "z Wall", Top = nil, Bottom = nil },
		{ Left = "In", Right = "z Wall", Top = nil, Bottom = nil },
		{ Left = "zz Wall", Right = "In", Top = nil, Bottom = nil },
		{ Left = "Stone", Right = "Wall", Top = nil, Bottom = nil },
		{ Left = "z In", Right = "In", Top = nil, Bottom = nil },
		{ Left = "zz In", Right = "In", Top = nil, Bottom = nil },
		{ Left = "Stone", Right = "In", Top = nil, Bottom = nil },
		{ Left = "Stone", Right = "Stone", Top = nil, Bottom = nil },
		{ Left = nil, Right = nil, Top = "Empty", Bottom = "Empty" },
		{ Left = nil, Right = nil, Top = "Empty", Bottom = "Out" },
		{ Left = nil, Right = nil, Top = "Empty", Bottom = "Wall" },
		{ Left = nil, Right = nil, Top = "Empty", Bottom = "In" },
		{ Left = nil, Right = nil, Top = "Empty", Bottom = "Stone" },
		{ Left = nil, Right = nil, Top = "Out", Bottom = "Out" },
		{ Left = nil, Right = nil, Top = "Out", Bottom = "Wall" },
		{ Left = nil, Right = nil, Top = "z Out", Bottom = "In" },
		{ Left = nil, Right = nil, Top = "Out", Bottom = "Stone" },
		{ Left = nil, Right = nil, Top = "Wall", Bottom = "Wall" },
		{ Left = nil, Right = nil, Top = "Wall", Bottom = "In" },
		{ Left = nil, Right = nil, Top = "Wall", Bottom = "Stone" },
		{ Left = nil, Right = nil, Top = "In", Bottom = "In" },
		{ Left = nil, Right = nil, Top = "In", Bottom = "Stone" },
		{ Left = nil, Right = nil, Top = "Stone", Bottom = "Stone" },
		{ Left = "zz Wall", Right = "Wall", Top = nil, Bottom = nil },
		{ Left = "zz Wall", Right = "In", Top = nil, Bottom = nil },
		{ Left = "z In", Right = "In", Top = nil, Bottom = nil },
	},
}
