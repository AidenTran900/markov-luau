--!strict
--!native
--!optimize 2
local Grid = require(script.Parent.Parent.Grid)
local Rule = require(script.Parent.Parent.Rule)
local Node = require(script.Parent.Parent.Node)
local Symmetry = require(script.Parent.Parent.Util.Symmetry)
local Helper = require(script.Parent.Parent.Util.Helper)
local Field = require(script.Parent.Field)
local Observation = require(script.Parent.Parent.Inference.Observation)
local Search = require(script.Parent.Parent.Inference.Search)

local RuleNode = {}

export type Match = { R: number, X: number, Y: number, Z: number }

export type RuleNodeData = {
	Rules: { Rule.Rule },
	Counter: number,
	Steps: number,
	Matches: { Match },
	MatchCount: number,
	LastMatchedTurn: number,
	MatchMask: { buffer }?,
	Potentials: { { [number]: number } }?,
	Fields: { Field.Field? }?,
	Observations: { Observation.Observation? }?,
	Temperature: number,
	SearchEnabled: boolean,
	FutureComputed: boolean,
	Future: { [number]: number }?,

	ObservationsExternalName: string?,
	Trajectory: { buffer }?,
	Limit: number,
	DepthCoefficient: number,
	Last: { boolean },
}

export type RuleSpec = {
	InChars: { string },
	IMX: number,
	IMY: number,
	IMZ: number,
	OutChars: { string },
	OMX: number,
	OMY: number,
	OMZ: number,
	P: number?,
	Symmetry: string?,
}

export type FieldEntrySpec = { For: string, Spec: Field.FieldSpec }
export type ObservationEntrySpec = { Value: string, From: string?, To: string }

export type RuleNodeConfig = {
	Rules: { RuleSpec },
	Symmetry: string?,
	Steps: number?,
	Temperature: number?,
	Fields: { FieldEntrySpec }?,
	Observations: { ObservationEntrySpec }?,
	ObservationsName: string?,
	Search: boolean?,
	Limit: number?,
	DepthCoefficient: number?,
}

export type AddFn = (
	data: RuleNodeData, 
	grid: Grid.Grid, 
	ip: Node.InterpreterState, 
	r: number, 
	x: number, 
	y: number, 
	z: number, 
	maskr: buffer?
) -> ()

function RuleNode.New(
	config: RuleNodeConfig, 
	grid: Grid.Grid, 
	parentSymmetry: { boolean }, 
	needsMatchMask: boolean?
): RuleNodeData
	local d2 = grid.MZ == 1
	local symmetry = Symmetry.GetSymmetry(d2, config.Symmetry, parentSymmetry)

	assert(symmetry, `RuleNode.New: unknown symmetry "{config.Symmetry}"`)

	local rules: { Rule.Rule } = {}
	for _, spec in config.Rules do
		local rule = Rule.FromChars(
			spec.InChars,
			spec.IMX,
			spec.IMY,
			spec.IMZ,
			spec.OutChars,
			spec.OMX,
			spec.OMY,
			spec.OMZ,
			grid.Legend,
			grid.Legend,
			grid.C,
			spec.P or 1.0
		)
		rule.Original = true

		local ruleSymmetry = Symmetry.GetSymmetry(d2, spec.Symmetry, symmetry)
		assert(ruleSymmetry, `RuleNode.New: unknown symmetry "{spec.Symmetry}"`)

		for _, r in Rule.Symmetries(rule, ruleSymmetry, d2) do
			table.insert(rules, r)
		end
	end

	local cellCount = grid.MX * grid.MY * grid.MZ
	local data: RuleNodeData = {
		Rules = rules,
		Counter = 0,
		Steps = config.Steps or 0,
		Matches = {},
		MatchCount = 0,
		LastMatchedTurn = -1,
		Temperature = config.Temperature or 0,
		SearchEnabled = false,
		FutureComputed = false,
		Limit = -1,
		DepthCoefficient = 0.5,
		Last = table.create(#rules, false),
	}

	if config.Fields then
		local fields: { Field.Field? } = table.create(grid.C)

		for _, entry in config.Fields do
			local value = grid.Values[entry.For]
			assert(value, `RuleNode.New: unknown field value "{entry.For}"`)
			fields[value + 1] = Field.New(entry.Spec, grid)
		end

		data.Fields = fields
		local potentials: { { [number]: number } } = table.create(grid.C)

		for i = 1, grid.C do
			potentials[i] = Helper.Zeros0(cellCount)
		end

		data.Potentials = potentials
	end

	if needsMatchMask then
		local matchMask: { buffer } = table.create(#rules)

		for r = 1, #rules do
			matchMask[r] = buffer.create(cellCount)
		end

		data.MatchMask = matchMask
	end

	if config.Observations or config.ObservationsName then
		if config.Observations then
			local observations: { Observation.Observation? } = table.create(grid.C)
			for _, entry in config.Observations do
				local value = grid.Values[entry.Value]
				assert(value, `RuleNode.New: unknown observation value "{entry.Value}"`)

				local fromChar = entry.From or grid.Characters[value + 1]
				observations[value + 1] = Observation.New(fromChar, entry.To, grid)
			end
			data.Observations = observations
		end

		data.ObservationsExternalName = config.ObservationsName

		data.SearchEnabled = config.Search or false

		if data.SearchEnabled then
			data.Limit = config.Limit or -1
			data.DepthCoefficient = config.DepthCoefficient or 0.5
		else
			local potentials: { { [number]: number } } = table.create(grid.C)
			for i = 1, grid.C do
				potentials[i] = Helper.Zeros0(cellCount)
			end

			data.Potentials = potentials
		end

		data.Future = Helper.Zeros0(cellCount)
	end

	return data
end

function RuleNode.Reset(data: RuleNodeData)
	data.LastMatchedTurn = -1
	data.Counter = 0
	data.FutureComputed = false

	for i = 1, #data.Last do
		data.Last[i] = false
	end
end

function RuleNode.Add(data: RuleNodeData, grid: Grid.Grid, _ip: Node.InterpreterState, r: number, x: number, y: number, z: number, maskr: buffer?)
	if maskr then
		buffer.writeu8(maskr, x + (y + z * grid.MY) * grid.MX, 1)
	end

	local slot = data.MatchCount + 1
	local match: Match = { R = r, X = x, Y = y, Z = z }
	if slot <= #data.Matches then
		data.Matches[slot] = match
	else
		table.insert(data.Matches, match)
	end

	data.MatchCount += 1
end


function RuleNode.Go(data: RuleNodeData, grid: Grid.Grid, ip: Node.InterpreterState, addFn: AddFn, isAllNode: boolean): boolean
	for i = 1, #data.Last do
		data.Last[i] = false
	end

	if data.Steps > 0 and data.Counter >= data.Steps then
		return false
	end

	local mx, my, mz = grid.MX, grid.MY, grid.MZ

	if (data.Observations or data.ObservationsExternalName) and not data.FutureComputed then
		local future = data.Future :: { [number]: number }
		if data.ObservationsExternalName then
			local source = ip.Fields and ip.Fields[data.ObservationsExternalName]
			assert(source, `RuleNode.Go: external observation target "{data.ObservationsExternalName}" not found in ip.Fields`)
			
			for i = 0, mx * my * mz - 1 do
				future[i] = source[i]
			end

		elseif not Observation.ComputeFutureSetPresent(future, grid.State, data.Observations :: { Observation.Observation? }) then
			return false
		end

		data.FutureComputed = true

		if data.SearchEnabled then
			data.Trajectory = nil
			local tries = if data.Limit < 0 then 1 else 20

			for _ = 1, tries do
				if data.Trajectory then
					break
				end
				data.Trajectory =
					Search.Run(grid.State, future, data.Rules, mx, my, mz, grid.C, isAllNode, data.Limit, data.DepthCoefficient, ip.Random:NextSeed())
			end
		else
			Observation.ComputeBackwardPotentials(data.Potentials :: { { [number]: number } }, future, mx, my, mz, data.Rules)
		end
	end

	if data.LastMatchedTurn >= 0 then
		for n = ip.First[data.LastMatchedTurn + 1] + 1, #ip.Changes do
			local changedIndex = ip.Changes[n]
			local value = buffer.readu8(grid.State, changedIndex)
			local x = changedIndex % mx
			local y = (changedIndex // mx) % my
			local z = changedIndex // (mx * my)

			for r, rule in data.Rules do
				local maskr = (data.MatchMask :: { buffer })[r]

				for _, shift in rule.IShifts[value + 1] do
					local sx, sy, sz = x - shift.X, y - shift.Y, z - shift.Z

					if sx >= 0 and sy >= 0 and sz >= 0 and sx + rule.IMX <= mx and sy + rule.IMY <= my and sz + rule.IMZ <= mz then
						local si = sx + (sy + sz * my) * mx

						if buffer.readu8(maskr, si) == 0 and Grid.Matches(grid, rule, sx, sy, sz) then
							addFn(data, grid, ip, r, sx, sy, sz, maskr)
						end
					end
				end
			end
		end
	else
		data.MatchCount = 0
		for r, rule in data.Rules do
			local maskr = if data.MatchMask then data.MatchMask[r] else nil

			for z = rule.IMZ - 1, mz - 1, rule.IMZ do
			for y = rule.IMY - 1, my - 1, rule.IMY do
			for x = rule.IMX - 1, mx - 1, rule.IMX do
				local value = buffer.readu8(grid.State, x + (y + z * my) * mx)

				for _, shift in rule.IShifts[value + 1] do
					local sx, sy, sz = x - shift.X, y - shift.Y, z - shift.Z

					if sx >= 0 and sy >= 0 
						and sz >= 0 and sx + rule.IMX <= mx 
						and sy + rule.IMY <= my 
						and sz + rule.IMZ <= mz 
					then
						if Grid.Matches(grid, rule, sx, sy, sz) then
							addFn(data, grid, ip, r, sx, sy, sz, maskr)
						end
					end
				end

			end
			end
			end
		end
	end

	if data.Fields then
		local potentials = data.Potentials :: { { [number]: number } }
		local anySuccess, anyComputation = false, false

		for c = 1, #data.Fields do
			local field = data.Fields[c]

			if field and (data.Counter == 0 or field.Recompute) then
				local success = Field.Compute(field, potentials[c], grid, ip)

				if not success and field.Essential then
					return false
				end

				anySuccess = anySuccess or success
				anyComputation = true
			end
		end
		
		if anyComputation and not anySuccess then
			return false
		end
	end

	return true
end

return RuleNode
