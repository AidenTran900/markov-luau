--!strict
--!native
--!optimize 2
local Grid = require(script.Parent.Parent.Grid)
local Rule = require(script.Parent.Parent.Rule)
local Queue = require(script.Parent.Parent.Util.Queue)

local Observation = {}

export type Observation = { From: number, To: number } -- From: 0-based grid value, To: wave bitmask

function Observation.New(
	fromChar: string,
	to: string,
	grid: Grid.Grid
): Observation
	local from = grid.Values[fromChar]
	assert(from, `Observation.New: unknown from value "{fromChar}"`)

	return { From = from, To = Grid.Wave(grid, to) }
end

function Observation.ComputeFutureSetPresent(
	future: { [number]: number },
	state: buffer,
	observations: { Observation? }
): boolean
	local c = #observations
	local seen = table.create(c, false)

	for k = 1, c do
		if observations[k] == nil then
			seen[k] = true
		end
	end

	for i = 0, buffer.len(state) - 1 do
		local value = buffer.readu8(state, i)
		local obs = observations[value + 1]
		seen[value + 1] = true

		if obs then
			future[i] = obs.To
			buffer.writeu8(state, i, obs.From)
		else
			future[i] = bit32.lshift(1, value)
		end
	end

	for k = 1, c do
		if not seen[k] then
			return false
		end
	end

	return true
end

local function forwardMatches(
	rule: Rule.Rule,
	x: number,
	y: number,
	z: number,
	potentials: { { [number]: number } },
	t: number,
	mx: number,
	my: number,
	backwards: boolean
): boolean
	local a = if backwards then rule.Output else rule.BInput
	local di = 0

	for dz = 0, rule.IMZ - 1 do
		local zOffset = (z + dz) * my
		for dy = 0, rule.IMY - 1 do
			local yOffset = (y + dy + zOffset) * mx
			for dx = 0, rule.IMX - 1 do
				local value = buffer.readu8(a, di)

				if value ~= 0xff then
					local current = potentials[value + 1][x + dx + yOffset]

					if current > t or current == -1 then
						return false
					end
				end

				di += 1
			end
		end
	end

	return true
end

local function applyForward(
	rule: Rule.Rule,
	x: number,
	y: number,
	z: number,
	potentials: { { [number]: number } },
	t: number,
	mx: number,
	my: number,
	queue: Queue.Queue<{ ColorIdx: number, X: number, Y: number, Z: number }>,
	backwards: boolean
)
	local a = if backwards then rule.BInput else rule.Output
	local di = 0

	for dz = 0, rule.IMZ - 1 do
		local zdz = z + dz
		local zOffset = zdz * my

		for dy = 0, rule.IMY - 1 do
			local ydy = y + dy
			local yOffset = (ydy + zOffset) * mx

			for dx = 0, rule.IMX - 1 do
				local xdx = x + dx
				local idi = xdx + yOffset
				local o = buffer.readu8(a, di)

				if o ~= 0xff and potentials[o + 1][idi] == -1 then
					potentials[o + 1][idi] = t + 1
					Queue.Push(queue, { ColorIdx = o + 1, X = xdx, Y = ydy, Z = zdz })
				end

				di += 1
			end
		end
	end
end

local function computePotentials(
	potentials: { { [number]: number } },
	mx: number,
	my: number,
	mz: number,
	rules: { Rule.Rule },
	backwards: boolean
)
	local queue = Queue.New()
	local c = #potentials
	local cellCount = mx * my * mz

	for colorIdx = 1, c do
		local potential = potentials[colorIdx]

		for i = 0, cellCount - 1 do
			if potential[i] == 0 then
				Queue.Push(queue, { ColorIdx = colorIdx, X = i % mx, Y = (i // mx) % my, Z = i // (mx * my) })
			end
		end
	end

	local matchMask: { buffer } = table.create(#rules)

	for r = 1, #rules do
		matchMask[r] = buffer.create(cellCount)
	end

	while not Queue.IsEmpty(queue) do
		local item = Queue.Pop(queue) :: { ColorIdx: number, X: number, Y: number, Z: number }
		local colorIdx, x, y, z = item.ColorIdx, item.X, item.Y, item.Z
		local i = x + y * mx + z * mx * my
		local t = potentials[colorIdx][i]

		for r, rule in rules do
			local maskr = matchMask[r]
			local shifts = if backwards then (rule.OShifts :: { { Rule.Shift } })[colorIdx] else rule.IShifts[colorIdx]

			for _, shift in shifts do
				local sx, sy, sz = x - shift.X, y - shift.Y, z - shift.Z

				if sx >= 0 and sy >= 0 and sz >= 0 and sx + rule.IMX <= mx and sy + rule.IMY <= my and sz + rule.IMZ <= mz then
					local si = sx + (sy + sz * my) * mx

					if buffer.readu8(maskr, si) == 0 and forwardMatches(rule, sx, sy, sz, potentials, t, mx, my, backwards) then
						buffer.writeu8(maskr, si, 1)
						applyForward(rule, sx, sy, sz, potentials, t, mx, my, queue, backwards)
					end
				end
			end
		end
	end
end

function Observation.ComputeForwardPotentials(
	potentials: { { [number]: number } },
	state: buffer,
	mx: number,
	my: number,
	mz: number,
	rules: { Rule.Rule }
)
	local cellCount = mx * my * mz

	for colorIdx = 1, #potentials do
		local potential = potentials[colorIdx]

		for i = 0, cellCount - 1 do
			potential[i] = -1
		end
	end

	for i = 0, buffer.len(state) - 1 do
		potentials[buffer.readu8(state, i) + 1][i] = 0
	end

	computePotentials(potentials, mx, my, mz, rules, false)
end

function Observation.ComputeBackwardPotentials(
	potentials: { { [number]: number } },
	future: { [number]: number },
	mx: number,
	my: number,
	mz: number,
	rules: { Rule.Rule }
)
	local cellCount = mx * my * mz

	for colorIdx = 1, #potentials do
		local potential = potentials[colorIdx]

		for i = 0, cellCount - 1 do
			potential[i] = if bit32.band(future[i], bit32.lshift(1, colorIdx - 1)) ~= 0 then 0 else -1
		end
	end

	computePotentials(potentials, mx, my, mz, rules, true)
end

function Observation.IsGoalReached(
	present: buffer,
	future: { [number]: number }
): boolean

	for i = 0, buffer.len(present) - 1 do
		if bit32.band(bit32.lshift(1, buffer.readu8(present, i)), future[i]) == 0 then
			return false
		end
	end

	return true
end

function Observation.ForwardPointwise(
	potentials: { { [number]: number } },
	future: { [number]: number },
	cellCount: number
): number
	local sum = 0
	local c = #potentials

	for i = 0, cellCount - 1 do
		local f = future[i]
		local min, argmin = 1000, -1

		for colorValue = 0, c - 1 do

			if bit32.band(bit32.rshift(f, colorValue), 1) == 1 then
				local potential = potentials[colorValue + 1][i]

				if potential >= 0 and potential < min then
					min = potential
					argmin = colorValue
				end
			end
		end

		if argmin < 0 then
			return -1
		end

		sum += min
	end

	return sum
end

function Observation.BackwardPointwise(
	potentials: { { [number]: number } },
	present: buffer
): number
	local sum = 0

	for i = 0, buffer.len(present) - 1 do
		local potential = potentials[buffer.readu8(present, i) + 1][i]

		if potential < 0 then
			return -1
		end

		sum += potential
	end

	return sum
end

return Observation
