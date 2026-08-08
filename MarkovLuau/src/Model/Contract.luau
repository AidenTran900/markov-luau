--!strict
--!native
--!optimize 2
local Grid = require(script.Parent.Parent.Grid)
local Alphabet = require(script.Parent.Parent.Symbol.Alphabet)
local Palette = require(script.Parent.Parent.Symbol.Palette)

local Contract = {}

export type CheckContext = {
	Grid: Grid.Grid,
	Private: { Palette.SymbolId }?,
}

export type Check = (ctx: CheckContext) -> (boolean, string?)
export type Direction = { DX: number, DY: number, DZ: number }

local function requireGrounded(
	alphabet: Alphabet.Alphabet,
	value: number
): Palette.SymbolId?
	return Alphabet.SymbolAt(alphabet, value)
end

function Contract.NoPrivateSymbols(
	ctx: CheckContext): (boolean,
	string?
)
	local private = ctx.Private
	if not private or #private == 0 then
		return true
	end

	local grid = ctx.Grid
	local n = grid.MX * grid.MY * grid.MZ

	for i = 0, n - 1 do
		local sym = requireGrounded(grid.Alphabet, buffer.readu8(grid.State, i))
		if sym then
			for _, p in private do
				if sym == p then
					return false, `cell {i} still holds private symbol "{Palette.Name(grid.Alphabet.Palette, sym)}"`
				end
			end
		end
	end

	return true
end

function Contract.OnlySymbols(group: string): Check
	return function(ctx: CheckContext): (boolean, string?)
		local grid = ctx.Grid
		local n = grid.MX * grid.MY * grid.MZ

		for i = 0, n - 1 do
			local v = buffer.readu8(grid.State, i)
			local bind = grid.Alphabet.Slots[v + 1]

			if type(bind) == "number" then
				if not Palette.InGroup(grid.Alphabet.Palette, bind, group) then
					return false, `cell {i} holds symbol "{Palette.Name(grid.Alphabet.Palette, bind)}", not in group "{group}"`
				end
			elseif type(bind) == "table" then
				if (bind :: { Group: string }).Group ~= group then
					return false, `cell {i}'s local slot is bound to group "{(bind :: { Group: string }).Group}", not "{group}"`
				end
			else
				return false, `cell {i}'s local slot is an unconstrained "Any" binding, can't guarantee group "{group}" membership`
			end
		end

		return true
	end
end

function Contract.CountInRange(
	sym: Palette.SymbolId,
	lo: number,
	hi: number
): Check
	return function(ctx: CheckContext): (boolean, string?)
		local grid = ctx.Grid
		local n = grid.MX * grid.MY * grid.MZ
		local count = 0

		for i = 0, n - 1 do
			if requireGrounded(grid.Alphabet, buffer.readu8(grid.State, i)) == sym then
				count += 1
			end
		end

		if count < lo or count > hi then
			return false, `found {count} cells of "{Palette.Name(grid.Alphabet.Palette, sym)}", expected between {lo} and {hi}`
		end

		return true
	end
end

function Contract.Supported(
	sym: Palette.SymbolId,
	emptySym: Palette.SymbolId,
	down: Direction?
): Check
	local d = down or { DX = 0, DY = -1, DZ = 0 }

	return function(ctx: CheckContext): (boolean, string?)
		local grid = ctx.Grid
		local mx, my, mz = grid.MX, grid.MY, grid.MZ

		for z = 0, mz - 1 do
		for y = 0, my - 1 do
		for x = 0, mx - 1 do
			local i = Grid.Index(grid, x, y, z)

			if requireGrounded(grid.Alphabet, buffer.readu8(grid.State, i)) == sym then
				local bx, by, bz = x + d.DX, y + d.DY, z + d.DZ

				if bx >= 0 and by >= 0 and bz >= 0 and bx < mx and by < my and bz < mz then
					local belowSym = requireGrounded(grid.Alphabet, buffer.readu8(grid.State, Grid.Index(grid, bx, by, bz)))

					if belowSym == emptySym then
						return false, `cell ({x}, {y}, {z}) holding "{Palette.Name(grid.Alphabet.Palette, sym)}" is unsupported`
					end
				end
			end
		end
		end
		end

		return true
	end
end

function Contract.Connected(group: string): Check
	return function(ctx: CheckContext): (boolean, string?)
		local grid = ctx.Grid
		local mx, my, mz = grid.MX, grid.MY, grid.MZ
		local n = mx * my * mz

		local belongs = buffer.create(n)
		local memberCount = 0

		for i = 0, n - 1 do
			local sym = requireGrounded(grid.Alphabet, buffer.readu8(grid.State, i))

			if sym and Palette.InGroup(grid.Alphabet.Palette, sym, group) then
				buffer.writeu8(belongs, i, 1)
				memberCount += 1
			end
		end

		if memberCount == 0 then
			return true
		end

		local visited = buffer.create(n)
		local stack: { number } = {}

		for i = 0, n - 1 do
			if buffer.readu8(belongs, i) == 1 then
				table.insert(stack, i)
				buffer.writeu8(visited, i, 1)
				break
			end
		end

		local visitedCount = 0
		while #stack > 0 do
			local i = table.remove(stack) :: number
			visitedCount += 1
			local x = i % mx
			local y = (i // mx) % my
			local z = i // (mx * my)
			local deltas = { { -1, 0, 0 }, { 1, 0, 0 }, { 0, -1, 0 }, { 0, 1, 0 }, { 0, 0, -1 }, { 0, 0, 1 } }

			for _, delta in deltas do
				local nx, ny, nz = x + delta[1], y + delta[2], z + delta[3]

				if nx >= 0 and ny >= 0 and nz >= 0 and nx < mx and ny < my and nz < mz then
					local ni = nx + ny * mx + nz * mx * my

					if buffer.readu8(belongs, ni) == 1 and buffer.readu8(visited, ni) == 0 then
						buffer.writeu8(visited, ni, 1)
						table.insert(stack, ni)
					end
				end
			end
		end

		if visitedCount ~= memberCount then
			return false, `group "{group}" has {memberCount} cells but only {visitedCount} are reachable from each other -- not connected`
		end

		return true
	end
end

function Contract.CheckAll(
	checks: { Check },
	ctx: CheckContext): (boolean,
	string?
)
	for _, check in checks do
		local ok, detail = check(ctx)

		if not ok then
			return false, detail
		end
	end

	return true
end

function Contract.Assert(
	checks: { Check },
	ctx: CheckContext,
	seam: string
)
	local ok, detail = Contract.CheckAll(checks, ctx)
	assert(ok, `Contract violated at {seam}: {detail}`)
end

return Contract
