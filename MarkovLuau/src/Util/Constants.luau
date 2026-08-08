local Constants = {}

Constants.DIR_X = { -1, 1, 0, 0, 0, 0 }
Constants.DIR_Y = { 0, 0, -1, 1, 0, 0 }
Constants.DIR_Z = { 0, 0, 0, 0, -1, 1 }

Constants.EDGE_X = { -1, -1, 1, 1, -1, -1, 1, 1, 0, 0, 0, 0 }
Constants.EDGE_Y = { -1, 1, -1, 1, 0, 0, 0, 0, -1, -1, 1, 1 }
Constants.EDGE_Z = { 0, 0, 0, 0, -1, 1, -1, 1, -1, 1, -1, 1 }

Constants.VERT_X = { -1, -1, -1, -1, 1, 1, 1, 1 }
Constants.VERT_Y = { -1, -1, 1, 1, -1, -1, 1, 1 }
Constants.VERT_Z = { -1, 1, -1, 1, -1, 1, -1, 1 }

Constants.WFC_DX = { 1, 0, -1, 0, 0, 0 }
Constants.WFC_DY = { 0, 1, 0, -1, 0, 0 }
Constants.WFC_DZ = { 0, 0, 0, 0, 1, -1 }
Constants.WFC_OPPOSITE = { 3, 4, 1, 2, 6, 5 }

Constants.DIRS6 = {
	{ -1, 0, 0 },
	{ 1, 0, 0 },
	{ 0, -1, 0 },
	{ 0, 1, 0 },
	{ 0, 0, -1 },
	{ 0, 0, 1 },
}

local DIRS26 = {}
for dz = -1, 1 do
	for dy = -1, 1 do
		for dx = -1, 1 do
			if dx ~= 0 or dy ~= 0 or dz ~= 0 then
				table.insert(DIRS26, { dx, dy, dz })
			end
		end
	end
end
Constants.DIRS26 = DIRS26

return Constants
