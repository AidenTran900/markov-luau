--!strict
--!native
--!optimize 2

-- Port of Rule.cs

local Helper = require(script.Parent.Util.Helper)
local Symmetry = require(script.Parent.Util.Symmetry)
local Orientation = require(script.Parent.Util.Orientation)
local Legend = require(script.Parent.Symbol.Legend)

local Rule = {}

export type Shift = { X: number, Y: number, Z: number }

export type Rule = {
	Input: { number },
	Output: buffer,
	BInput: buffer,
	IMX: number,
	IMY: number,
	IMZ: number,
	OMX: number,
	OMY: number,
	OMZ: number,
	P: number,
	IShifts: { { Shift } },
	OShifts: { { Shift } }?,
	Original: boolean?,
	OutputOrientation: buffer?,
}

local function idx1(mx: number, my: number, x: number, y: number, z: number): number
	return z * mx * my + y * mx + x + 1
end

local function trailingZeroCount(w: number): number
	if w == 0 then
		return 32
	end
	local count = 0
	while bit32.band(w, 1) == 0 do
		w = bit32.rshift(w, 1)
		count += 1
	end
	return count
end

function Rule.New(
	input: { number },
	imx: number,
	imy: number,
	imz: number,
	output: buffer,
	omx: number,
	omy: number,
	omz: number,
	c: number,
	p: number
): Rule
	local ishiftLists: { { Shift } } = table.create(c)

	for color = 1, c do
		ishiftLists[color] = {}
	end

	for z = 0, imz - 1 do
	for y = 0, imy - 1 do
	for x = 0, imx - 1 do
		local w = input[idx1(imx, imy, x, y, z)]

		for color = 0, c - 1 do
			if bit32.band(bit32.rshift(w, color), 1) == 1 then
				table.insert(ishiftLists[color + 1], { X = x, Y = y, Z = z })
			end
		end
	end
	end
	end

	local oshiftLists: { { Shift } }? = nil
	if omx == imx and omy == imy and omz == imz then
		local lists: { { Shift } } = table.create(c)

		for color = 1, c do
			lists[color] = {}
		end

		for z = 0, omz - 1 do
		for y = 0, omy - 1 do
		for x = 0, omx - 1 do
			local o = buffer.readu8(output, idx1(omx, omy, x, y, z) - 1)

			if o ~= 0xff then
				table.insert(lists[o + 1], { X = x, Y = y, Z = z })
			else
				for color = 1, c do
					table.insert(lists[color], { X = x, Y = y, Z = z })
				end
			end
		end
		end
		end
		oshiftLists = lists
	end

	local wildcard = bit32.lshift(1, c) - 1
	local binput = buffer.create(#input)

	for i = 1, #input do
		local w = input[i]
		buffer.writeu8(binput, i - 1, if w == wildcard then 0xff else trailingZeroCount(w))
	end

	return {
		Input = input,
		Output = output,
		BInput = binput,
		IMX = imx,
		IMY = imy,
		IMZ = imz,
		OMX = omx,
		OMY = omy,
		OMZ = omz,
		P = p,
		IShifts = ishiftLists,
		OShifts = oshiftLists,
	}
end

function Rule.WithOrientation(rule: Rule, orientation: buffer): Rule
	assert(
		buffer.len(orientation) == rule.OMX * rule.OMY * rule.OMZ,
		`Rule.WithOrientation: orientation buffer has {buffer.len(orientation)} bytes, expected {rule.OMX * rule.OMY * rule.OMZ}`
	)
	rule.OutputOrientation = orientation
	return rule
end

function Rule.FromChars(
	inChars: { string },
	imx: number,
	imy: number,
	imz: number,
	outChars: { string },
	omx: number,
	omy: number,
	omz: number,
	inLegend: Legend.Legend,
	outLegend: Legend.Legend,
	c: number,
	p: number
): Rule
	local input = table.create(#inChars)

	for i, ch in inChars do
		local wave = inLegend.Waves[ch]
		assert(wave, `Rule.FromChars: input code "{ch}" is not found in codes`)
		input[i] = wave
	end

	local output = buffer.create(#outChars)

	for i, ch in outChars do
		if ch == "*" then
			buffer.writeu8(output, i - 1, 0xff)
		else
			local value = outLegend.Values[ch]
			assert(value, `Rule.FromChars: output code "{ch}" is not found in codes`)
			buffer.writeu8(output, i - 1, value)
		end
	end

	return Rule.New(input, imx, imy, imz, output, omx, omy, omz, c, p)
end

function Rule.Parse(s: string): ({ string }, number, number, number)
	local lines = Helper.Split(s, " ", "/")
	local mx = #lines[1][1]
	local my = #lines[1]
	local mz = #lines
	local result = table.create(mx * my * mz)

	for z = 0, mz - 1 do
		local linesz = lines[mz - z]

		assert(#linesz == my, "Rule.Parse: non-rectangular pattern")
		for y = 0, my - 1 do
			local row = linesz[y + 1]

			assert(#row == mx, "Rule.Parse: non-rectangular pattern")
			for x = 0, mx - 1 do
				result[idx1(mx, my, x, y, z)] = string.sub(row, x + 1, x + 1)
			end
		end
	end
	return result, mx, my, mz
end

function Rule.ZRotated(rule: Rule): Rule
	local imx, imy, imz = rule.IMX, rule.IMY, rule.IMZ
	local omx, omy, omz = rule.OMX, rule.OMY, rule.OMZ
	local newinput = table.create(#rule.Input)
	
	for z = 0, imz - 1 do
	for y = 0, imx - 1 do
	for x = 0, imy - 1 do
		newinput[idx1(imy, imx, x, y, z)] = rule.Input[idx1(imx, imy, imx - 1 - y, x, z)]
	end
	end
	end

	local newoutput = buffer.create(buffer.len(rule.Output))
	for z = 0, omz - 1 do
	for y = 0, omx - 1 do
	for x = 0, omy - 1 do
		buffer.writeu8(
			newoutput,
			idx1(omy, omx, x, y, z) - 1,
			buffer.readu8(rule.Output, idx1(omx, omy, omx - 1 - y, x, z) - 1)
		)
	end
	end
	end

	return Rule.New(newinput, imy, imx, imz, newoutput, omy, omx, omz, #rule.IShifts, rule.P)
end

function Rule.YRotated(rule: Rule): Rule
	local imx, imy, imz = rule.IMX, rule.IMY, rule.IMZ
	local omx, omy, omz = rule.OMX, rule.OMY, rule.OMZ
	local newinput = table.create(#rule.Input)

	for z = 0, imx - 1 do
	for y = 0, imy - 1 do
	for x = 0, imz - 1 do
		newinput[idx1(imz, imy, x, y, z)] = rule.Input[idx1(imx, imy, imx - 1 - z, y, x)]
	end
	end
	end

	local newoutput = buffer.create(buffer.len(rule.Output))
	for z = 0, omx - 1 do
	for y = 0, omy - 1 do
	for x = 0, omz - 1 do
		buffer.writeu8(
			newoutput,
			idx1(omz, omy, x, y, z) - 1,
			buffer.readu8(rule.Output, idx1(omx, omy, omx - 1 - z, y, x) - 1)
		)
	end
	end
	end

	return Rule.New(newinput, imz, imy, imx, newoutput, omz, omy, omx, #rule.IShifts, rule.P)
end

function Rule.Reflected(rule: Rule): Rule
	local imx, imy, imz = rule.IMX, rule.IMY, rule.IMZ
	local omx, omy, omz = rule.OMX, rule.OMY, rule.OMZ
	local newinput = table.create(#rule.Input)
	for z = 0, imz - 1 do
	for y = 0, imy - 1 do
	for x = 0, imx - 1 do
		newinput[idx1(imx, imy, x, y, z)] = rule.Input[idx1(imx, imy, imx - 1 - x, y, z)]
	end
	end
	end

	local newoutput = buffer.create(buffer.len(rule.Output))
	for z = 0, omz - 1 do
	for y = 0, omy - 1 do
	for x = 0, omx - 1 do
		buffer.writeu8(
			newoutput,
			idx1(omx, omy, x, y, z) - 1,
			buffer.readu8(rule.Output, idx1(omx, omy, omx - 1 - x, y, z) - 1)
		)
	end
	end
	end

	return Rule.New(newinput, imx, imy, imz, newoutput, omx, omy, omz, #rule.IShifts, rule.P)
end

function Rule.Same(a1: Rule, a2: Rule): boolean
	if a1.IMX ~= a2.IMX or a1.IMY ~= a2.IMY or a1.IMZ ~= a2.IMZ or a1.OMX ~= a2.OMX or a1.OMY ~= a2.OMY or a1.OMZ ~= a2.OMZ then
		return false
	end

	for i = 1, a1.IMX * a1.IMY * a1.IMZ do
		if a1.Input[i] ~= a2.Input[i] then
			return false
		end
	end

	for i = 0, a1.OMX * a1.OMY * a1.OMZ - 1 do
		if buffer.readu8(a1.Output, i) ~= buffer.readu8(a2.Output, i) then
			return false
		end
	end

	if (a1.OutputOrientation == nil) ~= (a2.OutputOrientation == nil) then
		return false
	end

	if a1.OutputOrientation then
		local o2 = a2.OutputOrientation :: buffer
		for i = 0, a1.OMX * a1.OMY * a1.OMZ - 1 do
			if buffer.readu8(a1.OutputOrientation, i) ~= buffer.readu8(o2, i) then
				return false
			end
		end
	end

	return true
end

local function stampOrientations(variants: { Rule }, authored: buffer, d2: boolean)
	local base = { Buf = authored, MX = variants[1].OMX, MY = variants[1].OMY, MZ = variants[1].OMZ }
	local permuted = if d2 then Orientation.SquareElements(base) else Orientation.CubeElements(base)

	for i, variant in variants do
		local p = permuted[i]
		local n = buffer.len(p.Buf)
		local stamped = buffer.create(n)

		for k = 0, n - 1 do
			local v = buffer.readu8(p.Buf, k)
			buffer.writeu8(stamped, k, if v == 0xff then 0xff else Orientation.Compose(d2, v, i))
		end

		variant.OutputOrientation = stamped
	end
end

function Rule.Symmetries(rule: Rule, symmetry: { boolean }, d2: boolean): { Rule }
	local elements = if d2
		then Symmetry.SquareElements(rule, Rule.ZRotated, Rule.Reflected)
		else Symmetry.CubeElements(rule, Rule.ZRotated, Rule.YRotated, Rule.Reflected)

	if rule.OutputOrientation then
		stampOrientations(elements, rule.OutputOrientation, d2)
	end

	local result: { Rule } = {}
	for i, variant in elements do
		if symmetry[i] then
			local dup = false

			for _, s in result do
				if Rule.Same(s, variant) then
					dup = true
					break
				end
			end

			if not dup then
				table.insert(result, variant)
			end
			
		end
	end
	return result
end

return Rule
