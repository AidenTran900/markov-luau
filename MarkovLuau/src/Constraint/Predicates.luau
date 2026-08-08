--!strict
--!native
--!optimize 2
local VoxelField = require(script.Parent.Parent.Field.VoxelField)
local Palette = require(script.Parent.Parent.Symbol.Palette)
local RegionTable = require(script.Parent.RegionTable)
local Constants = require(script.Parent.Parent.Util.Constants)

local Constraint = {}

export type Ctx = {
	Field: VoxelField.VoxelField,
	Palette: Palette.Palette,
	Regions: RegionTable.RegionTable?,
}

export type Check = (ctx: Ctx) -> (boolean, string?)

local function inGroup(ctx: Ctx, index: number, group: string): boolean
	local sym = VoxelField.GetMaterial(ctx.Field, index)
	return sym ~= 0 and Palette.InGroup(ctx.Palette, sym, group)
end

function Constraint.Connected(group: string): Check
	return function(ctx: Ctx): (boolean, string?)
		local field = ctx.Field
		local mx, my, mz = field.MX, field.MY, field.MZ
		local n = mx * my * mz

		local belongs = buffer.create(n)
		local memberCount = 0
		for i = 0, n - 1 do
			if inGroup(ctx, i, group) then
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
			for _, d in Constants.DIRS6 do
				local nx, ny, nz = x + d[1], y + d[2], z + d[3]
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

function Constraint.VolumeInRange(group: string, lo: number, hi: number): Check
	return function(ctx: Ctx): (boolean, string?)
		local field = ctx.Field
		local n = field.MX * field.MY * field.MZ
		local count = 0
		for i = 0, n - 1 do
			if inGroup(ctx, i, group) then
				count += 1
			end
		end
		if count < lo or count > hi then
			return false, `group "{group}" has {count} cells, expected between {lo} and {hi}`
		end
		return true
	end
end

local function bfsReach(ctx: Ctx, fromRegion: number, toRegion: number, group: string): (boolean, { number }?)
	local field = ctx.Field
	local mx, my, mz = field.MX, field.MY, field.MZ
	local n = mx * my * mz

	local visited = buffer.create(n)
	local parent: { [number]: number } = {}
	local queue: { number } = {}
	local target: number? = nil

	for i = 0, n - 1 do
		if VoxelField.GetRegion(field, i) == fromRegion then
			buffer.writeu8(visited, i, 1)
			table.insert(queue, i)
			if VoxelField.GetRegion(field, i) == toRegion then
				target = i
			end
		end
	end

	local head = 1
	while target == nil and head <= #queue do
		local i = queue[head]
		head += 1
		local x = i % mx
		local y = (i // mx) % my
		local z = i // (mx * my)
		for _, d in Constants.DIRS6 do
			local nx, ny, nz = x + d[1], y + d[2], z + d[3]
			if nx >= 0 and ny >= 0 and nz >= 0 and nx < mx and ny < my and nz < mz then
				local ni = nx + ny * mx + nz * mx * my
				if buffer.readu8(visited, ni) == 0 and inGroup(ctx, ni, group) then
					buffer.writeu8(visited, ni, 1)
					parent[ni] = i
					table.insert(queue, ni)
					if VoxelField.GetRegion(field, ni) == toRegion then
						target = ni
						break
					end
				end
			end
		end
	end

	if target == nil then
		return false, nil
	end

	local path = { target :: number }
	local cur = target :: number
	while parent[cur] do
		cur = parent[cur]
		table.insert(path, 1, cur)
	end
	return true, path
end

function Constraint.Reachable(fromRegion: number, toRegion: number, group: string): Check
	return function(ctx: Ctx): (boolean, string?)
		local ok = bfsReach(ctx, fromRegion, toRegion, group)
		if not ok then
			return false, `region {toRegion} is not reachable from region {fromRegion} through group "{group}"`
		end
		return true
	end
end

function Constraint.PathExists(fromRegion: number, toRegion: number, group: string): Check
	return function(ctx: Ctx): (boolean, string?)
		local ok = bfsReach(ctx, fromRegion, toRegion, group)
		if not ok then
			return false, `no path from region {fromRegion} to region {toRegion} through group "{group}"`
		end
		return true
	end
end

function Constraint.FindPath(ctx: Ctx, fromRegion: number, toRegion: number, group: string): { number }?
	local _, path = bfsReach(ctx, fromRegion, toRegion, group)
	return path
end

return Constraint
