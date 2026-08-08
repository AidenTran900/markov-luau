--!strict
--!native
--!optimize 2

-- Port of SymmetryHelper.cs

local Helper = require(script.Parent.Helper)

local Symmetry = {}

local squareSubgroups: { [string]: { boolean } } = {
	["()"] = { true, false, false, false, false, false, false, false },
	["(x)"] = { true, true, false, false, false, false, false, false },
	["(y)"] = { true, false, false, false, false, true, false, false },
	["(x)(y)"] = { true, true, false, false, true, true, false, false },
	["(xy+)"] = { true, false, true, false, true, false, true, false },
	["(xy)"] = { true, true, true, true, true, true, true, true },
}
Symmetry.SquareSubgroups = squareSubgroups

function Symmetry.SquareElements<T>(thing: T, rotation: (T) -> T, reflection: (T) -> T): { T }
	local things: { T } = table.create(8)
	things[1] = thing
	things[2] = reflection(things[1])
	things[3] = rotation(things[1])
	things[4] = reflection(things[3])
	things[5] = rotation(things[3])
	things[6] = reflection(things[5])
	things[7] = rotation(things[5])
	things[8] = reflection(things[7])
	return things
end

function Symmetry.SquareSymmetries<T>(
	thing: T,
	rotation: (T) -> T,
	reflection: (T) -> T,
	same: (T, T) -> boolean,
	subgroup: { boolean }?
): { T }
	local things = Symmetry.SquareElements(thing, rotation, reflection)

	local result: { T } = {}
	for i = 1, 8 do
		if subgroup == nil or subgroup[i] then
			local dup = false
			for _, s in result do
				if same(s, things[i]) then
					dup = true
					break
				end
			end
			if not dup then
				table.insert(result, things[i])
			end
		end
	end
	return result
end

local cubeSubgroups: { [string]: { boolean } } = {
	["()"] = Helper.Array1DFrom(48, function(l)
		return l == 0
	end),
	["(x)"] = Helper.Array1DFrom(48, function(l)
		return l == 0 or l == 1
	end),
	["(z)"] = Helper.Array1DFrom(48, function(l)
		return l == 0 or l == 17
	end),
	["(xy)"] = Helper.Array1DFrom(48, function(l)
		return l < 8
	end),
	["(xyz+)"] = Helper.Array1DFrom(48, function(l)
		return l % 2 == 0
	end),
	["(xyz)"] = Helper.Array1D(48, true),
}
Symmetry.CubeSubgroups = cubeSubgroups

function Symmetry.CubeElements<T>(thing: T, a: (T) -> T, b: (T) -> T, r: (T) -> T): { T }
	local s: { T } = table.create(48)
	s[1] = thing
	s[2] = r(s[1])
	s[3] = a(s[1])
	s[4] = r(s[3])
	s[5] = a(s[3])
	s[6] = r(s[5])
	s[7] = a(s[5])
	s[8] = r(s[7])
	s[9] = b(s[1])
	s[10] = r(s[9])
	s[11] = b(s[3])
	s[12] = r(s[11])
	s[13] = b(s[5])
	s[14] = r(s[13])
	s[15] = b(s[7])
	s[16] = r(s[15])
	s[17] = b(s[9])
	s[18] = r(s[17])
	s[19] = b(s[11])
	s[20] = r(s[19])
	s[21] = b(s[13])
	s[22] = r(s[21])
	s[23] = b(s[15])
	s[24] = r(s[23])
	s[25] = b(s[17])
	s[26] = r(s[25])
	s[27] = b(s[19])
	s[28] = r(s[27])
	s[29] = b(s[21])
	s[30] = r(s[29])
	s[31] = b(s[23])
	s[32] = r(s[31])
	s[33] = a(s[9])
	s[34] = r(s[33])
	s[35] = a(s[11])
	s[36] = r(s[35])
	s[37] = a(s[13])
	s[38] = r(s[37])
	s[39] = a(s[15])
	s[40] = r(s[39])
	s[41] = a(s[25])
	s[42] = r(s[41])
	s[43] = a(s[27])
	s[44] = r(s[43])
	s[45] = a(s[29])
	s[46] = r(s[45])
	s[47] = a(s[31])
	s[48] = r(s[47])
	return s
end

function Symmetry.CubeSymmetries<T>(
	thing: T,
	a: (T) -> T,
	b: (T) -> T,
	r: (T) -> T,
	same: (T, T) -> boolean,
	subgroup: { boolean }?
): { T }
	local s = Symmetry.CubeElements(thing, a, b, r)

	local result: { T } = {}
	for i = 1, 48 do
		if subgroup == nil or subgroup[i] then
			local dup = false
			for _, t in result do
				if same(t, s[i]) then
					dup = true
					break
				end
			end
			if not dup then
				table.insert(result, s[i])
			end
		end
	end
	return result
end

function Symmetry.GetSymmetry(d2: boolean, s: string?, dflt: { boolean }?): { boolean }?
	if s == nil then
		return dflt
	end
	local table_ = if d2 then Symmetry.SquareSubgroups else Symmetry.CubeSubgroups
	return table_[s :: string]
end

return Symmetry
