--!strict
--!native
--!optimize 2

-- Port of ArrayHelper.cs + Helper.cs.

local Helper = {}

-- Helper.cs part

function Helper.Ords(data: { number }, uniques: { number }?): ({ number }, number)
	local list = uniques or {}
	local result = table.create(#data)
	
	for i, d in data do
		local ord: number? = nil
		for u, value in list do
			if value == d then
				ord = u - 1
				break
			end
		end

		if ord == nil then
			ord = #list
			table.insert(list, d)
		end

		result[i] = ord
	end

	return result, #list
end

function Helper.Split(s: string, s1: string, s2: string): { { string } }
	local result = {}
	
	for part in string.gmatch(s .. s1, "(.-)" .. s1) do
		local row = {}

		for cell in string.gmatch(part .. s2, "(.-)" .. s2) do
			table.insert(row, cell)
		end

		table.insert(result, row)
	end
	return result
end

function Helper.Power(a: number, n: number): number
	local product = 1

	for _ = 1, n do
		product *= a
	end

	return product
end

function Helper.Index(array: { boolean }): number
	local result, power = 0, 1

	for i = 1, #array do
		if array[i] then
			result += power
		end

		power *= 2
	end

	return result
end

function Helper.IndexC(p: { number }, c: number): number
	local result, power = 0, 1

	for i = 0, #p - 1 do
		result += p[#p - i] * power
		power *= c
	end

	return result
end

function Helper.NonZeroPositions(w: number): { number }
	local result = {}
	local bit = 0

	while w > 0 do
		if w % 2 == 1 then
			table.insert(result, bit)
		end

		w = (w - w % 2) / 2
		bit += 1
	end

	return result
end

function Helper.MaxPositiveIndex(amounts: { number }): number
	local max, argmax = -1, -1

	for i, amount in amounts do
		if amount > 0 and amount > max then
			max = amount
			argmax = i - 1
		end
	end

	return argmax
end

function Helper.Pattern<T>(f: (number, number) -> T, n: number): { T }
	local result = table.create(n * n)

	for y = 0, n - 1 do
		for x = 0, n - 1 do
			result[x + y * n + 1] = f(x, y)
		end
	end

	return result
end

function Helper.Rotated<T>(p: { T }, n: number): { T }
	return Helper.Pattern(function(x, y)
		return p[(n - 1 - y + x * n) + 1]
	end, n)
end

function Helper.Reflected<T>(p: { T }, n: number): { T }
	return Helper.Pattern(function(x, y)
		return p[(n - 1 - x + y * n) + 1]
	end, n)
end

-- ArrayHelper.cs part

function Helper.Array1D<T>(length: number, value: T): { T }
	local result = table.create(length, value)

	for i = 1, length do
		result[i] = value
	end

	return result
end

function Helper.Zeros0(length: number): { [number]: number }
	local result = table.create(length)

	for i = 0, length - 1 do
		result[i] = 0
	end

	return result
end

function Helper.Fill0<T>(length: number, value: T): { [number]: T }
	local result = table.create(length)

	for i = 0, length - 1 do
		result[i] = value
	end

	return result
end

function Helper.Array1DFrom<T>(length: number, f: (number) -> T): { T }
	local result = table.create(length)

	for i = 1, length do
		result[i] = f(i - 1)
	end

	return result
end

function Helper.Array2D<T>(mx: number, my: number, value: T): { { T } }
	local result = table.create(mx)

	for x = 1, mx do
		result[x] = Helper.Array1D(my, value)
	end

	return result
end

function Helper.Array3D<T>(mx: number, my: number, mz: number, value: T): { { { T } } }
	local result = table.create(mx)

	for x = 1, mx do
		result[x] = Helper.Array2D(my, mz, value)
	end

	return result
end

function Helper.FlatArray3D<T>(mx: number, my: number, mz: number, f: (number, number, number) -> T): { T }
	local result = table.create(mx * my * mz)

	for z = 0, mz - 1 do
		for y = 0, my - 1 do
			for x = 0, mx - 1 do
				result[z * mx * my + y * mx + x + 1] = f(x, y, z)
			end
		end
	end

	return result
end

function Helper.Set2D<T>(a: { { T } }, value: T)
	for _, row in a do
		for i = 1, #row do
			row[i] = value
		end
	end
end

function Helper.Same(t1: { number }, t2: { number }): boolean
	if #t1 ~= #t2 then
		return false
	end

	for i = 1, #t1 do
		if t1[i] ~= t2[i] then
			return false
		end
	end
	
	return true
end

return Helper
