--!strict
--!native
--!optimize 2
--[[
	C# System.Random has no portable Luau equivalent so this is its own seeded PCG32
]]

local Random = {}
Random.__index = Random

export type Rng = typeof(setmetatable(
	{} :: {
		StateHi: number,
		StateLo: number,
		IncHi: number,
		IncLo: number,
	},
	Random
))

local TWO_32 = 4294967296
local MASK32 = 0xFFFFFFFF

-- PCG_DEFAULT_MULTIPLIER_64 = 6364136223846793005 = 0x5851F42D4C957F2D
local MULT_HI = 0x5851F42D
local MULT_LO = 0x4C957F2D
-- PCG_DEFAULT_INCREMENT_64 = 1442695040888963407 = 0x14057B7EF767814F
local INC_HI = 0x14057B7E
local INC_LO = 0xF767814F

local function split16(x: number): (number, number)
	local lo = x % 65536
	return (x - lo) / 65536, lo
end

-- Exact (hi, lo) of a*b mod 2^64 for 32-bit unsigned a, b.
local function mul32to64(a: number, b: number): (number, number)
	local aHi, aLo = split16(a)
	local bHi, bLo = split16(b)
	local t0 = aLo * bLo
	local t1 = aHi * bLo + aLo * bHi
	local t2 = aHi * bHi
	local t1lo = t1 % 65536
	local t1hi = (t1 - t1lo) / 65536
	local lo = t0 + t1lo * 65536
	local carry = math.floor(lo / TWO_32)
	lo = lo % TWO_32
	local hi = (t2 + t1hi + carry) % TWO_32
	return hi, lo
end

-- (aHi,aLo) * (bHi,bLo) mod 2^64
local function mul64(aHi: number, aLo: number, bHi: number, bLo: number): (number, number)
	local loHi, loLo = mul32to64(aLo, bLo)
	local _, midA = mul32to64(aHi, bLo)
	local _, midB = mul32to64(aLo, bHi)
	local hi = (loHi + midA + midB) % TWO_32
	return hi, loLo
end

local function add64(aHi: number, aLo: number, bHi: number, bLo: number): (number, number)
	local lo = aLo + bLo
	local carry = if lo >= TWO_32 then 1 else 0
	lo %= TWO_32
	local hi = (aHi + bHi + carry) % TWO_32
	return hi, lo
end

local function rotr32(x: number, r: number): number
	r %= 32
	if r == 0 then
		return x
	end
	return bit32.bor(bit32.rshift(x, r), bit32.lshift(x, 32 - r))
end

-- Advances the LCG state and returns the next 0..2^32-1 output word
local function step(rng: Rng): number
	local oldHi, oldLo = rng.StateHi, rng.StateLo
	rng.StateHi, rng.StateLo = mul64(oldHi, oldLo, MULT_HI, MULT_LO)
	rng.StateHi, rng.StateLo = add64(rng.StateHi, rng.StateLo, rng.IncHi, rng.IncLo)

	-- xorshifted = (uint32)(((oldstate >> 18) ^ oldstate) >> 27)
	local shiftedHi = bit32.rshift(oldHi, 18)
	local shiftedLo = bit32.bor(bit32.rshift(oldLo, 18), bit32.lshift(oldHi, 14))
	local xoredHi = bit32.bxor(shiftedHi, oldHi)
	local xoredLo = bit32.bxor(shiftedLo, oldLo)
	local xorshifted = bit32.band(bit32.bor(bit32.rshift(xoredLo, 27), bit32.lshift(xoredHi, 5)), MASK32)

	-- rot = (uint32)(oldstate >> 59) -- top 5 bits of the 64-bit state.
	local rot = bit32.rshift(oldHi, 27)
	return rotr32(xorshifted, rot)
end

function Random.New(seed: number): Rng
	local rng = setmetatable({ StateHi = 0, StateLo = 0, IncHi = INC_HI, IncLo = INC_LO }, Random) :: Rng
	step(rng)
	rng.StateHi, rng.StateLo = add64(rng.StateHi, rng.StateLo, 0, seed % TWO_32)
	step(rng)
	return rng
end

function Random.NextU32(self: Rng): number
	return step(self)
end

-- 0..n-1. Small modulo bias against a uniform 32-bit source is accepted
-- (n is always small here: match counts, weight counts, etc.).
function Random.Next(self: Rng, n: number): number
	return step(self) % n
end

function Random.NextSeed(self: Rng): number
	return step(self) % 0x7FFFFFFF
end

function Random.NextNumber(self: Rng): number
	return step(self) / TWO_32
end

function Random.Pick<T>(self: Rng, list: { T }): T
	return list[self:Next(#list) + 1]
end

function Random.WeightedIndex(weights: { number }, r: number): number
	local sum = 0
	for _, w in weights do
		sum += w
	end
	local threshold = r * sum
	local partial = 0
	for i, w in weights do
		partial += w
		if partial >= threshold then
			return i - 1
		end
	end
	return 0
end

function Random.Weighted(self: Rng, weights: { number }): number
	return Random.WeightedIndex(weights, self:NextNumber())
end

function Random.Shuffle(self: Rng, n: number): { number }
	local array = table.create(n, 0)
	for i = 0, n - 1 do
		local j = self:Next(i + 1)
		array[i + 1] = array[j + 1]
		array[j + 1] = i
	end
	return array
end

return Random
