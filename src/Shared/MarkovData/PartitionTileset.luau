--!strict

-- Partition tileset, converted from resources/tilesets/Partition.xml + Partition/*.vox
return {
	FullSymmetry = false,
	S = 3,
	SZ = 3,
	Tiles = {
		{ Name = "Nothing", Weight = 2.0, Voxels = {
		-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,31,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,
	} },
		{ Name = "I", Weight = nil, Voxels = {
		-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,24,-1,-1,31,-1,-1,24,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,
	} },
		{ Name = "T", Weight = nil, Voxels = {
		-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,24,-1,-1,31,24,-1,24,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,
	} },
	},
	Neighbors = {
		{ Left = "Nothing", Right = "Nothing", Top = nil, Bottom = nil },
		{ Left = "Nothing", Right = "I", Top = nil, Bottom = nil },
		{ Left = "Nothing", Right = "T", Top = nil, Bottom = nil },
		{ Left = "z I", Right = "z I", Top = nil, Bottom = nil },
		{ Left = "z I", Right = "z T", Top = nil, Bottom = nil },
		{ Left = "T", Right = "z I", Top = nil, Bottom = nil },
		{ Left = "z T", Right = "zzz T", Top = nil, Bottom = nil },
		{ Left = nil, Right = nil, Top = "Nothing", Bottom = "Nothing" },
		{ Left = nil, Right = nil, Top = "Nothing", Bottom = "I" },
		{ Left = nil, Right = nil, Top = "Nothing", Bottom = "T" },
		{ Left = nil, Right = nil, Top = "I", Bottom = "Nothing" },
		{ Left = nil, Right = nil, Top = "I", Bottom = "I" },
		{ Left = nil, Right = nil, Top = "I", Bottom = "z I" },
		{ Left = nil, Right = nil, Top = "T", Bottom = "Nothing" },
		{ Left = nil, Right = nil, Top = "T", Bottom = "T" },
	},
}
