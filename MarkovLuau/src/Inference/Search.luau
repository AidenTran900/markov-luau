--!strict
--!native
--!optimize 2
local Helper = require(script.Parent.Parent.Util.Helper)
local Heap = require(script.Parent.Parent.Util.Heap)
local Random = require(script.Parent.Parent.Util.Random)
local Rule = require(script.Parent.Parent.Rule)
local Observation = require(script.Parent.Observation)

local Search = {}

export type Board = {
	State: buffer,
	ParentIndex: number, -- 0 = none (root)
	Depth: number,
	BackwardEstimate: number,
	ForwardEstimate: number,
}

local function rank(
	board: Board,
	rng: Random.Rng,
	depthCoefficient: number
): number
	local result = if depthCoefficient < 0
		then 1000 - board.Depth
		else board.ForwardEstimate + board.BackwardEstimate + 2.0 * depthCoefficient * board.Depth

	return result + 0.0001 * rng:NextNumber()
end

function Search.Trajectory(
	index: number,
	database: { Board }
): { Board }
	local result: { Board } = {}
	local board = database[index]
	while board.ParentIndex > 0 do
		table.insert(result, board)
		board = database[board.ParentIndex]
	end

	local n = #result

	for i = 1, n // 2 do
		result[i], result[n - i + 1] = result[n - i + 1], result[i]
	end

	return result
end


local function isInside(
	px: number,
	py: number,
	rule: Rule.Rule,
	x: number,
	y: number
): boolean
	return x <= px and px < x + rule.IMX and y <= py and py < y + rule.IMY
end

local function overlaps(
	rule0: Rule.Rule,
	x0: number,
	y0: number,
	rule1: Rule.Rule,
	x1: number,
	y1: number
): boolean
	for dy = 0, rule0.IMY - 1 do
	for dx = 0, rule0.IMX - 1 do
		if isInside(x0 + dx, y0 + dy, rule1, x1, y1) then
			return true
		end
	end
	end

	return false
end

local function ruleMatches2D(
	rule: Rule.Rule,
	x: number,
	y: number,
	state: buffer,
	mx: number,
	my: number
): boolean
	if x + rule.IMX > mx or y + rule.IMY > my then
		return false
	end

	local dx, dy = 0, 0
	for di = 1, #rule.Input do
		local v = buffer.readu8(state, x + dx + (y + dy) * mx)
		if bit32.band(rule.Input[di], bit32.lshift(1, v)) == 0 then
			return false
		end

		dx += 1
		if dx == rule.IMX then
			dx = 0
			dy += 1
		end
	end

	return true
end

local function applied2D(
	rule: Rule.Rule,
	x: number,
	y: number,
	state: buffer,
	mx: number
): buffer
	local result = buffer.create(buffer.len(state))
	buffer.copy(result, 0, state, 0, buffer.len(state))

	for dy = 0, rule.OMY - 1 do
		for dx = 0, rule.OMX - 1 do
			local newValue = buffer.readu8(rule.Output, dx + dy * rule.OMX)
			if newValue ~= 0xff then
				buffer.writeu8(result, x + dx + (y + dy) * mx, newValue)
			end
		end
	end

	return result
end

local function oneChildStates(
	state: buffer,
	mx: number,
	my: number,
	rules: { Rule.Rule }
): { buffer }
	local result = {}

	for _, rule in rules do
		for y = 0, my - 1 do
		for x = 0, mx - 1 do
			if ruleMatches2D(rule, x, y, state, mx, my) then
				table.insert(result, applied2D(rule, x, y, state, mx))
			end
		end
		end
	end

	return result
end


type Tile = { Rule: Rule.Rule, I: number } -- I: flat 0-based (x + y*mx) anchor
local function applyTileUnchecked(
	rule: Rule.Rule,
	x: number,
	y: number,
	state: buffer,
	mx: number
)
	for dy = 0, rule.OMY - 1 do
	for dx = 0, rule.OMX - 1 do
		buffer.writeu8(state, x + dx + (y + dy) * mx, buffer.readu8(rule.Output, dx + dy * rule.OMX))
	end
	end
end

local function applySolution(
	state: buffer,
	solution: { Tile },
	mx: number
): buffer
	local result = buffer.create(buffer.len(state))
	buffer.copy(result, 0, state, 0, buffer.len(state))

	for _, tile in solution do
		applyTileUnchecked(tile.Rule, tile.I % mx, tile.I // mx, result, mx)
	end

	return result
end

local function hide(
	l: number,
	unhide: boolean,
	tiles: { Tile },
	amounts: { [number]: number },
	mask: { boolean },
	mx: number
)
	mask[l] = unhide
	local tile = tiles[l]
	local x, y = tile.I % mx, tile.I // mx
	local incr = if unhide then 1 else -1

	for dy = 0, tile.Rule.IMY - 1 do
	for dx = 0, tile.Rule.IMX - 1 do
		local idx = x + dx + (y + dy) * mx
		amounts[idx] += incr
	end
	end
end

local function maxPositiveIndex0(
	amounts: { [number]: number },
	cellCount: number
): number
	local max, argmax = -1, -1

	for i = 0, cellCount - 1 do
		local amount = amounts[i]

		if amount > 0 and amount > max then
			max = amount
			argmax = i
		end
	end

	return argmax
end

local function enumerate(
	children: { buffer },
	solution: { Tile },
	tiles: { Tile },
	amounts: { [number]: number },
	mask: { boolean },
	state: buffer,
	mx: number,
	cellCount: number
)
	local idx = maxPositiveIndex0(amounts, cellCount)
	if idx < 0 then
		table.insert(children, applySolution(state, solution, mx))
		return
	end

	local px, py = idx % mx, idx // mx
	local cover: { number } = {}
	for l = 1, #tiles do
		local tile = tiles[l]

		if mask[l] and isInside(px, py, tile.Rule, tile.I % mx, tile.I // mx) then
			table.insert(cover, l)
		end
	end

	for _, l in cover do
		local tile = tiles[l]
		table.insert(solution, tile)

		local intersecting: { number } = {}
		for l2 = 1, #tiles do
			if mask[l2] then
				local tile2 = tiles[l2]

				if overlaps(tile.Rule, tile.I % mx, tile.I // mx, tile2.Rule, tile2.I % mx, tile2.I // mx) then
					table.insert(intersecting, l2)
				end
			end
		end

		for _, l2 in intersecting do
			hide(l2, false, tiles, amounts, mask, mx)
		end

		enumerate(children, solution, tiles, amounts, mask, state, mx, cellCount)

		for _, l2 in intersecting do
			hide(l2, true, tiles, amounts, mask, mx)
		end

		solution[#solution] = nil
	end
end

local function allChildStates(
	state: buffer,
	mx: number,
	my: number,
	rules: { Rule.Rule }
): { buffer }
	local cellCount = mx * my
	local tiles: { Tile } = {}
	local amounts = Helper.Zeros0(cellCount)

	for i = 0, cellCount - 1 do
		local x, y = i % mx, i // mx

		for _, rule in rules do
			if ruleMatches2D(rule, x, y, state, mx, my) then
				table.insert(tiles, { Rule = rule, I = i })

				for dy = 0, rule.IMY - 1 do
				for dx = 0, rule.IMX - 1 do
					local cell = x + dx + (y + dy) * mx
					amounts[cell] += 1
				end
				end
			end
		end
	end

	local mask = table.create(#tiles, true)
	local solution: { Tile } = {}
	local result: { buffer } = {}
	enumerate(result, solution, tiles, amounts, mask, state, mx, cellCount)

	return result
end

function Search.Run(
	present: buffer,
	future: { [number]: number },
	rules: { Rule.Rule },
	mx: number,
	my: number,
	mz: number,
	c: number,
	allMode: boolean,
	limit: number,
	depthCoefficient: number,
	seed: number
): { buffer }?
	assert(mz == 1, "Search.Run: search only works in 2D")
	local cellCount = mx * my * mz

	local bpotentials: { { [number]: number } } = table.create(c)
	local fpotentials: { { [number]: number } } = table.create(c)

	for i = 1, c do
		bpotentials[i] = Helper.Fill0(cellCount, -1)
		fpotentials[i] = Helper.Fill0(cellCount, -1)
	end

	Observation.ComputeBackwardPotentials(bpotentials, future, mx, my, mz, rules)
	local rootBackwardEstimate = Observation.BackwardPointwise(bpotentials, present)
	Observation.ComputeForwardPotentials(fpotentials, present, mx, my, mz, rules)
	local rootForwardEstimate = Observation.ForwardPointwise(fpotentials, future, cellCount)

	if rootBackwardEstimate < 0 or rootForwardEstimate < 0 then
		return nil
	end

	if rootBackwardEstimate == 0 then
		return {}
	end

	local rootState = buffer.create(cellCount)
	buffer.copy(rootState, 0, present, 0, cellCount)
	local rootBoard: Board = {
		State = rootState,
		ParentIndex = 0,
		Depth = 0,
		BackwardEstimate = rootBackwardEstimate,
		ForwardEstimate = rootForwardEstimate,
	}
	local database: { Board } = { rootBoard }
	local visited: { [string]: number } = { [buffer.tostring(present)] = 1 }
	local frontier = Heap.New(function(a: { Priority: number }, b: { Priority: number })
		return a.Priority < b.Priority
	end)
	
	local rng = Random.New(seed)
	Heap.Push(frontier, { Index = 1, Priority = rank(rootBoard, rng, depthCoefficient) })

	local record = rootBackwardEstimate + rootForwardEstimate
	while Heap.Count(frontier) > 0 and (limit < 0 or #database < limit) do
		local entry = Heap.Pop(frontier) :: { Index: number, Priority: number }
		local boardIndex = entry.Index
		local board = database[boardIndex]

		local children = if allMode then allChildStates(board.State, mx, my, rules) else oneChildStates(board.State, mx, my, rules)

		for _, childState in children do
			local key = buffer.tostring(childState)
			local existingIndex = visited[key]

			if existingIndex then
				local oldBoard = database[existingIndex]

				if board.Depth + 1 < oldBoard.Depth then
					oldBoard.Depth = board.Depth + 1
					oldBoard.ParentIndex = boardIndex

					if oldBoard.BackwardEstimate >= 0 and oldBoard.ForwardEstimate >= 0 then
						Heap.Push(frontier, { Index = existingIndex, Priority = rank(oldBoard, rng, depthCoefficient) })
					end
				end
			else
				local childBackwardEstimate = Observation.BackwardPointwise(bpotentials, childState)
				Observation.ComputeForwardPotentials(fpotentials, childState, mx, my, mz, rules)
				local childForwardEstimate = Observation.ForwardPointwise(fpotentials, future, cellCount)

				if childBackwardEstimate >= 0 and childForwardEstimate >= 0 then
					local childBoard: Board = {
						State = childState,
						ParentIndex = boardIndex,
						Depth = board.Depth + 1,
						BackwardEstimate = childBackwardEstimate,
						ForwardEstimate = childForwardEstimate,
					}
					table.insert(database, childBoard)
					local childIndex = #database
					visited[key] = childIndex

					if childForwardEstimate == 0 then
						local traj = Search.Trajectory(childIndex, database)
						local states: { buffer } = table.create(#traj)

						for i, b in traj do
							states[i] = b.State
						end

						return states
					end

					if limit < 0 and childBackwardEstimate + childForwardEstimate <= record then
						record = childBackwardEstimate + childForwardEstimate
					end

					Heap.Push(frontier, { Index = childIndex, Priority = rank(childBoard, rng, depthCoefficient) })
				end
			end
		end
	end

	return nil
end

return Search
