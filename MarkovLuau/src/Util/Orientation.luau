--!strict
--!native
--!optimize 2

--[[
	Precomputed symmetry group composition tables for Rule.OutputOrientation

	Composing element i then element j is regenerating 
	that recipe with element i's result as the new
	base and reading off position j
]]

local Orientation = {}

Orientation.SquareCount = 8
Orientation.CubeCount = 48

-- Fixed generator indices within the canonical ordering
Orientation.ReflectIndex = 2
Orientation.ZRotIndex = 3
Orientation.YRotIndex = 9

local function idx1(mx: number, my: number, x: number, y: number, z: number): number
	return z * mx * my + y * mx + x + 1
end

export type Probe = { Buf: buffer, MX: number, MY: number, MZ: number }

local function zRot(p: Probe): Probe
	local mx, my, mz = p.MX, p.MY, p.MZ
	local out = buffer.create(mx * my * mz)
	for z = 0, mz - 1 do
		for y = 0, mx - 1 do
			for x = 0, my - 1 do
				buffer.writeu8(out, idx1(my, mx, x, y, z) - 1, buffer.readu8(p.Buf, idx1(mx, my, mx - 1 - y, x, z) - 1))
			end
		end
	end
	return { Buf = out, MX = my, MY = mx, MZ = mz }
end

local function yRot(p: Probe): Probe
	local mx, my, mz = p.MX, p.MY, p.MZ
	local out = buffer.create(mx * my * mz)
	for z = 0, mx - 1 do
		for y = 0, my - 1 do
			for x = 0, mz - 1 do
				buffer.writeu8(out, idx1(mz, my, x, y, z) - 1, buffer.readu8(p.Buf, idx1(mx, my, mx - 1 - z, y, x) - 1))
			end
		end
	end
	return { Buf = out, MX = mz, MY = my, MZ = mx }
end

local function reflected(p: Probe): Probe
	local mx, my, mz = p.MX, p.MY, p.MZ
	local out = buffer.create(mx * my * mz)
	for z = 0, mz - 1 do
		for y = 0, my - 1 do
			for x = 0, mx - 1 do
				buffer.writeu8(out, idx1(mx, my, x, y, z) - 1, buffer.readu8(p.Buf, idx1(mx, my, mx - 1 - x, y, z) - 1))
			end
		end
	end
	return { Buf = out, MX = mx, MY = my, MZ = mz }
end

local function sameProbe(a: Probe, b: Probe): boolean
	if a.MX ~= b.MX or a.MY ~= b.MY or a.MZ ~= b.MZ then
		return false
	end

	for i = 0, a.MX * a.MY * a.MZ - 1 do
		if buffer.readu8(a.Buf, i) ~= buffer.readu8(b.Buf, i) then
			return false
		end
	end

	return true
end

-- A 3x3x1 (2D) or 3x3x3 (3D) probe whose byte at each cell is that cell's flat index
local function makeProbe(mz: number): Probe
	local mx, my = 3, 3
	local n = mx * my * mz
	local buf = buffer.create(n)

	for i = 0, n - 1 do
		buffer.writeu8(buf, i, i)
	end

	return { 
		Buf = buf, 
		MX = mx, 
		MY = my, 
		MZ = mz 
	}
end

function Orientation.SquareElements(base: Probe): { Probe }
	local s: { Probe } = table.create(8)

	s[1] = base
	s[2] = reflected(s[1])
	s[3] = zRot(s[1])
	s[4] = reflected(s[3])
	s[5] = zRot(s[3])
	s[6] = reflected(s[5])
	s[7] = zRot(s[5])
	s[8] = reflected(s[7])

	return s
end

function Orientation.CubeElements(base: Probe): { Probe }
	local s: { Probe } = table.create(48)

	s[1] = base
	s[2] = reflected(s[1])
	s[3] = zRot(s[1])
	s[4] = reflected(s[3])
	s[5] = zRot(s[3])
	s[6] = reflected(s[5])
	s[7] = zRot(s[5])
	s[8] = reflected(s[7])
	s[9] = yRot(s[1])
	s[10] = reflected(s[9])
	s[11] = yRot(s[3])
	s[12] = reflected(s[11])
	s[13] = yRot(s[5])
	s[14] = reflected(s[13])
	s[15] = yRot(s[7])
	s[16] = reflected(s[15])
	s[17] = yRot(s[9])
	s[18] = reflected(s[17])
	s[19] = yRot(s[11])
	s[20] = reflected(s[19])
	s[21] = yRot(s[13])
	s[22] = reflected(s[21])
	s[23] = yRot(s[15])
	s[24] = reflected(s[23])
	s[25] = yRot(s[17])
	s[26] = reflected(s[25])
	s[27] = yRot(s[19])
	s[28] = reflected(s[27])
	s[29] = yRot(s[21])
	s[30] = reflected(s[29])
	s[31] = yRot(s[23])
	s[32] = reflected(s[31])
	s[33] = zRot(s[9])
	s[34] = reflected(s[33])
	s[35] = zRot(s[11])
	s[36] = reflected(s[35])
	s[37] = zRot(s[13])
	s[38] = reflected(s[37])
	s[39] = zRot(s[15])
	s[40] = reflected(s[39])
	s[41] = zRot(s[25])
	s[42] = reflected(s[41])
	s[43] = zRot(s[27])
	s[44] = reflected(s[43])
	s[45] = zRot(s[29])
	s[46] = reflected(s[45])
	s[47] = zRot(s[31])
	s[48] = reflected(s[47])

	return s
end

local function buildTable(
	count: number, 
	mz: number, 
	elementsFn: (Probe) -> { Probe } 
): { { number } }
	local probe = makeProbe(mz)
	local canonical = elementsFn(probe)

	assert(#canonical == count, `Orientation: expected {count} elements, generated {#canonical}`)

	local compose: { { number } } = table.create(count)
	for i = 1, count do
		local regenerated = elementsFn(canonical[i])
		local row: { number } = table.create(count)

		for j = 1, count do
			local target = regenerated[j]
			local found: number? = nil

			for k = 1, count do
				if sameProbe(target, canonical[k]) then
					assert(found == nil, `Orientation: element {i} composed with {j} matches both {found} and {k}... group is not single-valued`)
					found = k
				end
			end

			assert(found ~= nil, `Orientation: element {i} composed with {j} matches no canonical element... group is not closed`)
			
			row[j] = found :: number
		end

		compose[i] = row
	end

	return compose
end

Orientation.ComposeSquare = buildTable(8, 1, Orientation.SquareElements)
Orientation.ComposeCube = buildTable(48, 3, Orientation.CubeElements)

function Orientation.Compose(d2: boolean, authored: number, generator: number): number
	local t = if d2 then Orientation.ComposeSquare else Orientation.ComposeCube
	return t[authored][generator]
end

return Orientation
