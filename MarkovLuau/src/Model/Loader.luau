--!strict
--!native
--!optimize 2
local Grid = require(script.Parent.Parent.Grid)
local Rule = require(script.Parent.Parent.Rule)
local Node = require(script.Parent.Parent.Node)
local Helper = require(script.Parent.Parent.Util.Helper)
local Symmetry = require(script.Parent.Parent.Util.Symmetry)
local Sample = require(script.Parent.Parent.Sample)
local Xml = require(script.Parent.Xml)

local RuleNode = require(script.Parent.Parent.Nodes.RuleNode)
local One = require(script.Parent.Parent.Nodes.One)
local All = require(script.Parent.Parent.Nodes.All)
local Parallel = require(script.Parent.Parent.Nodes.Parallel)
local PathMod = require(script.Parent.Parent.Nodes.Path)
local MapMod = require(script.Parent.Parent.Nodes.Map)
local Convolution = require(script.Parent.Parent.Nodes.Convolution)
local ConvChain = require(script.Parent.Parent.Nodes.ConvChain)
local Overlap = require(script.Parent.Parent.Nodes.WFC.Overlap)
local TileModel = require(script.Parent.Parent.Nodes.WFC.TileModel)
local ScopeNode = require(script.Parent.Parent.Nodes.Scope)
local RetryNode = require(script.Parent.Parent.Nodes.Retry)
local BudgetNode = require(script.Parent.Parent.Nodes.Budget)
local SeedNode = require(script.Parent.Parent.Nodes.Seed)
local Alphabet = require(script.Parent.Parent.Symbol.Alphabet)
local Palette = require(script.Parent.Parent.Symbol.Palette)
local Contract = require(script.Parent.Contract)
local MarkerNode = require(script.Parent.Parent.Nodes.Marker)

local Loader = {}

export type ScopeRoleBinding = string | { Group: string } | "Any"
export type ScopeRoleSpec = { Char: string, Bind: ScopeRoleBinding, Role: string? }

export type Spec =
	{ Kind: "Sequence", Symmetry: string?, Children: { Spec }, Origin: string? }
	| { Kind: "Markov", Symmetry: string?, Children: { Spec }, Origin: string? }
	| { Kind: "One", Config: RuleNode.RuleNodeConfig, Origin: string? }
	| { Kind: "All", Config: RuleNode.RuleNodeConfig, Origin: string? }
	| { Kind: "Parallel", Config: RuleNode.RuleNodeConfig, Origin: string? }
	| { Kind: "Path", Config: PathMod.PathSpec, Origin: string? }
	| { Kind: "Convolution", Config: Convolution.ConvolutionConfig, Origin: string? }
	| { Kind: "ConvChain", Config: ConvChain.ConvChainConfig, Origin: string? }
	| {
		Kind: "Map",
		Config: MapMod.MapConfig,
		Values: string,
		Children: { Spec },
		Unions: { { Symbol: string, Values: string } },
		Origin: string?,
	}
	| {
		Kind: "Overlap",
		Config: Overlap.OverlapConfig,
		Values: string,
		Children: { Spec },
		Unions: { { Symbol: string, Values: string } },
		Origin: string?,
	}
	| {
		Kind: "TileModel",
		Config: TileModel.TileModelConfig,
		Values: string,
		Children: { Spec },
		Unions: { { Symbol: string, Values: string } },
		Origin: string?,
	}
	| {
		Kind: "Scope",
		Roles: { ScopeRoleSpec },
		Private: { string }?,
		Ensures: { Contract.Check }?,
		Name: string?,
		Children: { Spec },
		Origin: string?,
	}
	| {
		Kind: "Retry",
		Body: Spec,
		Attempts: number,
		Ensures: { Contract.Check }?,
		Name: string?,
		Origin: string?,
	}
	| {
		Kind: "Budget",
		Body: Spec,
		Steps: number?,
		Seconds: number?,
		Name: string?,
		Origin: string?,
	}
	| {
		Kind: "Seed",
		VoxelsName: string,
		Name: string?,
		Origin: string?,
	}
	| {
		Kind: "Marker",
		Name: string,
		Origin: string?,
	}

local function requireString(
	xelem: Xml.XElement,
	name: string
): string
	local v = xelem.Attrs[name]
	assert(v, `Loader: element "{xelem.Name}" at line {xelem.Line} is missing required attribute "{name}"`)

	return v
end

local function requireValues(xelem: Xml.XElement): string

	return (string.gsub(requireString(xelem, "values"), " ", ""))
end

local function getNumber(
	xelem: Xml.XElement,
	name: string,
	default: number
): number
	local v = xelem.Attrs[name]

	if v == nil then

		return default
	end

	local n = tonumber(v)
	assert(n, `Loader: attribute "{name}" at line {xelem.Line} is not a number`)

	return n
end

local function getBool(
	xelem: Xml.XElement,
	name: string,
	default: boolean
): boolean
	local v = xelem.Attrs[name]

	if v == nil then

		return default
	end

	return string.lower(v) == "true"
end

local function getChar(
	xelem: Xml.XElement,
	name: string
): string
	local v = requireString(xelem, name)
	assert(#v == 1, `Loader: attribute "{name}" at line {xelem.Line} must be a single character`)

	return v
end

local function resolveResourceChars(
	resolver: Sample.Resolver?,
	folder: string?,
	name: string): ({ string },
	number,
	number,
	number
)
	local resolve = Sample.Require(resolver, "ResolveImage", name)
	local img = resolve(name, folder)
	local ords, amount = Helper.Ords(img.Data)
	assert(img.Legend, `Loader: resource "{name}" has no legend`)
	local legend = img.Legend :: string
	assert(amount <= #legend, `Loader: the amount of colors {amount} in "{name}" is more than {#legend}`)
	local chars = table.create(#ords)

	for i, o in ords do
		chars[i] = string.sub(legend, o + 1, o + 1)
	end

	return chars, img.Width, img.Height, img.Depth
end

local function parseRuleSpec(
	xelem: Xml.XElement,
	resolver: Sample.Resolver?,
	folder: string?,
	requireMatchingDims: boolean
)
	local inStr = xelem.Attrs["in"]
	local outStr = xelem.Attrs["out"]
	local finStr = xelem.Attrs["fin"]
	local foutStr = xelem.Attrs["fout"]
	local fileStr = xelem.Attrs["file"]

	local inChars, imx, imy, imz
	local outChars, omx, omy, omz

	if fileStr == nil then
		assert(inStr or finStr, `Loader: no input in a rule at line {xelem.Line}`)
		assert(outStr or foutStr, `Loader: no output in a rule at line {xelem.Line}`)

		if inStr then
			inChars, imx, imy, imz = Rule.Parse(inStr)
		else
			inChars, imx, imy, imz = resolveResourceChars(resolver, folder, finStr :: string)
		end

		if outStr then
			outChars, omx, omy, omz = Rule.Parse(outStr)
		else
			outChars, omx, omy, omz = resolveResourceChars(resolver, folder, foutStr :: string)
		end

		if requireMatchingDims then
			assert(omx == imx and omy == imy and omz == imz, `Loader: non-matching pattern sizes at line {xelem.Line}`)
		end
	else
		assert(not (inStr or finStr or outStr or foutStr), `Loader: rule at line {xelem.Line} already contains a file attribute`)
		local chars, fx, fy, fz = resolveResourceChars(resolver, folder, fileStr)
		assert(fx % 2 == 0, `Loader: odd width {fx} in "{fileStr}"`)
		imx, imy, imz = fx // 2, fy, fz
		omx, omy, omz = fx // 2, fy, fz
		inChars = table.create(imx * imy * imz)
		outChars = table.create(omx * omy * omz)

		for z = 0, fz - 1 do

		for y = 0, fy - 1 do

		for x = 0, imx - 1 do
					local srcIdx = z * fx * fy + y * fx + x + 1
					local dstIdx = z * imx * imy + y * imx + x + 1
					inChars[dstIdx] = chars[srcIdx]
					outChars[dstIdx] = chars[srcIdx + imx]
		end
		end
		end
	end

	return {
		InChars = inChars,
		IMX = imx,
		IMY = imy,
		IMZ = imz,
		OutChars = outChars,
		OMX = omx,
		OMY = omy,
		OMZ = omz,
		P = getNumber(xelem, "p", 1.0),
		Symmetry = xelem.Attrs["symmetry"],
	}
end

local function childrenNamed(
	xelem: Xml.XElement,
	name: string
): { Xml.XElement }
	local out: { Xml.XElement } = {}

	for _, child in xelem.Children do

		if child.Name == name then
			table.insert(out, child)
		end
	end

	return out
end

local function parseFieldsAndObservations(
	xelem: Xml.XElement): ({ RuleNode.FieldEntrySpec }?,
	{ RuleNode.ObservationEntrySpec }?,
	boolean,
	number,
	number
)
	local fields: { RuleNode.FieldEntrySpec }? = nil

	for _, child in childrenNamed(xelem, "field") do
		fields = fields or {}
		table.insert(fields :: { RuleNode.FieldEntrySpec }, {
			For = getChar(child, "for"),
			Spec = {
				On = requireString(child, "on"),
				From = child.Attrs["from"],
				To = child.Attrs["to"],
				Recompute = getBool(child, "recompute", false),
				Essential = getBool(child, "essential", false),
			},
		})
	end

	local observations: { RuleNode.ObservationEntrySpec }? = nil
	local search, limit, depthCoefficient = false, -1, 0.5

	for _, child in childrenNamed(xelem, "observe") do
		observations = observations or {}
		table.insert(observations :: { RuleNode.ObservationEntrySpec }, {
			Value = getChar(child, "value"),
			From = child.Attrs["from"],
			To = requireString(child, "to"),
		})
	end

	if observations then
		search = getBool(xelem, "search", false)

		if search then
			limit = getNumber(xelem, "limit", -1)
			depthCoefficient = getNumber(xelem, "depthCoefficient", 0.5)
		end
	end

	return fields, observations, search, limit, depthCoefficient
end

local function parseRuleNodeConfig(
	xelem: Xml.XElement,
	resolver: Sample.Resolver?,
	folder: string?
): RuleNode.RuleNodeConfig
	local xrules = childrenNamed(xelem, "rule")
	local ruleElements = if #xrules > 0 then xrules else { xelem }
	local rules: { RuleNode.RuleSpec } = table.create(#ruleElements)

	for i, xrule in ruleElements do
		rules[i] = parseRuleSpec(xrule, resolver, folder, true)
	end

	local fields, observations, search, limit, depthCoefficient = parseFieldsAndObservations(xelem)

	return {
		Rules = rules,
		Symmetry = xelem.Attrs["symmetry"],
		Steps = getNumber(xelem, "steps", 0),
		Temperature = getNumber(xelem, "temperature", 0.0),
		Fields = fields,
		Observations = observations,
		Search = search,
		Limit = limit,
		DepthCoefficient = depthCoefficient,
	}
end

local function parsePathConfig(xelem: Xml.XElement): PathMod.PathSpec

	return {
		From = requireString(xelem, "from"),
		To = requireString(xelem, "to"),
		On = requireString(xelem, "on"),
		Color = xelem.Attrs["color"],
		Inertia = getBool(xelem, "inertia", false),
		Longest = getBool(xelem, "longest", false),
		Edges = getBool(xelem, "edges", false),
		Vertices = getBool(xelem, "vertices", false),
	}
end

local function parseConvolutionConfig(xelem: Xml.XElement): Convolution.ConvolutionConfig
	local xrules = childrenNamed(xelem, "rule")
	local ruleElements = if #xrules > 0 then xrules else { xelem }
	local rules: { Convolution.ConvRuleSpec } = table.create(#ruleElements)

	for i, xrule in ruleElements do
		rules[i] = {
			In = getChar(xrule, "in"),
			Out = getChar(xrule, "out"),
			P = getNumber(xrule, "p", 1.0),
			Values = xrule.Attrs["values"],
			Sum = xrule.Attrs["sum"],
		}
	end

	return {
		Rules = rules,
		Steps = getNumber(xelem, "steps", -1),
		Periodic = getBool(xelem, "periodic", false),
		Neighborhood = requireString(xelem, "neighborhood"),
	}
end

local function parseConvChainConfig(
	xelem: Xml.XElement,
	resolver: Sample.Resolver?
): ConvChain.ConvChainConfig
	local name = requireString(xelem, "sample")
	local resolveSample = Sample.Require(resolver, "ResolveSample", name)
	local img = resolveSample(name)
	local sample: { boolean } = table.create(#img.Data)

	for i, v in img.Data do
		sample[i] = v ~= 0
	end

	return {
		Sample = sample,
		SMX = img.Width,
		SMY = img.Height,
		N = getNumber(xelem, "n", 3),
		Steps = getNumber(xelem, "steps", -1),
		Temperature = getNumber(xelem, "temperature", 1.0),
		Black = getChar(xelem, "black"),
		White = getChar(xelem, "white"),
		On = getChar(xelem, "on"),
	}
end

local function readScale(s: string): (number, number)
	local slash = string.find(s, "/", 1, true)

	if slash then

		return tonumber(string.sub(s, 1, slash - 1)) :: number, tonumber(string.sub(s, slash + 1)) :: number
	end

	return tonumber(s) :: number, 1
end

local function parseMapConfig(
	xelem: Xml.XElement,
	resolver: Sample.Resolver?,
	folder: string?
): MapMod.MapConfig
	local scalestring = requireString(xelem, "scale")
	local parts: { string } = {}

	for token in string.gmatch(scalestring, "%S+") do
		table.insert(parts, token)
	end

	assert(#parts == 3, `Loader: scale attribute "{scalestring}" should have 3 components separated by space`)
	local nx, dx = readScale(parts[1])
	local ny, dy = readScale(parts[2])
	local nz, dz = readScale(parts[3])

	local xrules = childrenNamed(xelem, "rule")
	local rules: { MapMod.MapRuleSpec } = table.create(#xrules)

	for i, xrule in xrules do
		local spec = parseRuleSpec(xrule, resolver, folder, false)
		rules[i] = {
			InChars = spec.InChars,
			IMX = spec.IMX,
			IMY = spec.IMY,
			IMZ = spec.IMZ,
			OutChars = spec.OutChars,
			OMX = spec.OMX,
			OMY = spec.OMY,
			OMZ = spec.OMZ,
			P = spec.P,
		}
	end

	return {
		Rules = rules,
		Symmetry = xelem.Attrs["symmetry"],
		ScaleNX = nx,
		ScaleDX = dx,
		ScaleNY = ny,
		ScaleDY = dy,
		ScaleNZ = nz,
		ScaleDZ = dz,
	}
end

local function parseOverlapConfig(
	xelem: Xml.XElement,
	resolver: Sample.Resolver?): (Overlap.OverlapConfig,
	string
)
	local name = requireString(xelem, "sample")
	local resolveSample = Sample.Require(resolver, "ResolveSample", name)
	local img = resolveSample(name)

	local rules: { Overlap.OverlapRuleSpec } = {}

	for _, xrule in childrenNamed(xelem, "rule") do
		table.insert(rules, { In = getChar(xrule, "in"), Out = requireString(xrule, "out") })
	end

	local config: Overlap.OverlapConfig = {
		N = getNumber(xelem, "n", 3),
		Symmetry = xelem.Attrs["symmetry"],
		PeriodicInput = getBool(xelem, "periodicInput", true),
		Bitmap = img.Data,
		SMX = img.Width,
		SMY = img.Height,
		Rules = rules,
		Shannon = getBool(xelem, "shannon", false),
		Tries = getNumber(xelem, "tries", 1000),
		SampleName = name,
	}

	return config, requireValues(xelem)
end

local function parseTileModelConfig(
	xelem: Xml.XElement,
	resolver: Sample.Resolver?): (TileModel.TileModelConfig,
	string
)
	local name = requireString(xelem, "tileset")
	local tilesname = xelem.Attrs["tiles"] or name
	local resolveTileset = Sample.Require(resolver, "ResolveTileset", name)
	local tileset = resolveTileset(name, tilesname)

	local tiles: { TileModel.TileSpec } = {}

	for _, t in tileset.Tiles do
		table.insert(tiles, { Name = t.Name, Weight = t.Weight, Voxels = t.Voxels })
	end

	local neighbors: { TileModel.NeighborSpec } = {}

	for _, n in tileset.Neighbors do
		table.insert(neighbors, { Left = n.Left, Right = n.Right, Top = n.Top, Bottom = n.Bottom })
	end

	local rules: { { In: string, Out: string } } = {}

	for _, xrule in childrenNamed(xelem, "rule") do
		table.insert(rules, { In = getChar(xrule, "in"), Out = requireString(xrule, "out") })
	end

	local config: TileModel.TileModelConfig = {
		Periodic = getBool(xelem, "periodic", false),
		FullSymmetry = tileset.FullSymmetry,
		Overlap = getNumber(xelem, "overlap", 0),
		OverlapZ = getNumber(xelem, "overlapz", 0),
		S = tileset.S,
		SZ = tileset.SZ,
		Tiles = tiles,
		Neighbors = neighbors,
		Rules = rules,
		Shannon = getBool(xelem, "shannon", false),
		Tries = getNumber(xelem, "tries", 1000),
		TilesetName = name,
	}

	return config, requireValues(xelem)
end

local BRANCH_NODE_NAMES: { [string]: boolean } = { markov = true, sequence = true, union = true }
local NODE_NAMES: { [string]: boolean } =
	{ one = true, all = true, prl = true, markov = true, sequence = true, path = true, map = true, convolution = true, convchain = true, wfc = true }

local function collectUnions(xelem: Xml.XElement): { { Symbol: string, Values: string } }
	local unions: { { Symbol: string, Values: string } } = {}
	local queue: { Xml.XElement } = { xelem }
	local head = 1
	while head <= #queue do
		local e = queue[head]
		head += 1

		for _, child in e.Children do

			if child.Name == "union" then
				table.insert(unions, { Symbol = getChar(child, "symbol"), Values = requireString(child, "values") })
			elseif child.Name == "sequence" or child.Name == "markov" then
				table.insert(queue, child)
			end
		end
	end

	return unions
end

local function directChildSpecs(
	xelem: Xml.XElement,
	resolver: Sample.Resolver?,
	folder: string?
): { Spec }
	local children: { Spec } = {}

	for _, child in xelem.Children do

		if NODE_NAMES[child.Name] then
			table.insert(children, Loader.XmlToSpec(child, resolver, folder))
		end
	end

	return children
end

function Loader.XmlToSpec(
	xelem: Xml.XElement,
	resolver: Sample.Resolver?,
	folder: string?
): Spec
	local name = xelem.Name

	if name == "one" or name == "all" or name == "prl" then
		local kind = if name == "one" then "One" elseif name == "all" then "All" else "Parallel"

		return { Kind = kind :: any, Config = parseRuleNodeConfig(xelem, resolver, folder) }
	elseif name == "sequence" or name == "markov" then
		local kind = if name == "sequence" then "Sequence" else "Markov"

		return { Kind = kind :: any, Symmetry = xelem.Attrs["symmetry"], Children = directChildSpecs(xelem, resolver, folder) }
	elseif name == "path" then

		return { Kind = "Path", Config = parsePathConfig(xelem) }
	elseif name == "map" then
		local mapFolder = xelem.Attrs["folder"]
		local config = parseMapConfig(xelem, resolver, mapFolder)

		return {
			Kind = "Map",
			Config = config,
			Values = requireValues(xelem),
			Children = directChildSpecs(xelem, resolver, mapFolder),
			Unions = collectUnions(xelem),
		}
	elseif name == "convolution" then

		return { Kind = "Convolution", Config = parseConvolutionConfig(xelem) }
	elseif name == "convchain" then

		return { Kind = "ConvChain", Config = parseConvChainConfig(xelem, resolver) }
	elseif name == "wfc" then
		local children = directChildSpecs(xelem, resolver, xelem.Attrs["folder"])
		local unions = collectUnions(xelem)

		if xelem.Attrs["sample"] then
			local config, values = parseOverlapConfig(xelem, resolver)

			return { Kind = "Overlap", Config = config, Values = values, Children = children, Unions = unions }
		elseif xelem.Attrs["tileset"] then
			local config, values = parseTileModelConfig(xelem, resolver)

			return { Kind = "TileModel", Config = config, Values = values, Children = children, Unions = unions }
		end

		error(`Loader: <wfc> at line {xelem.Line} needs sample= or tileset=`, 0)
	end

	error(`Loader: unknown node type "{name}" at line {xelem.Line}`, 0)
end

-- ===== Spec -> Node.Node (shared by the XML and DSL front-ends) =====

local function assignParents(
	children: { Node.Node },
	parentNode: Node.Node
)
	for _, child in children do
		if Node.BranchKinds[child.Kind] then
			if child.Kind == "Map" or child.Kind == "Overlap" or child.Kind == "TileModel" then
				child.Parent = nil
			else
				child.Parent = parentNode
			end
		end
	end
end

local function buildChildren(
	specs: { Spec },
	grid: Grid.Grid,
	symmetry: { boolean }
): { Node.Node }
	local children: { Node.Node } = table.create(#specs)

	for i, childSpec in specs do
		children[i] = Loader.Build(childSpec, grid, symmetry)
	end

	return children
end

local function applyUnions(
	grid: Grid.Grid,
	unions: { { Symbol: string,
	Values: string } }?
)
	if not unions then
		return
	end

	for _, u in unions do
		local valid = true

		for i = 1, #u.Values do

			if not grid.Values[string.sub(u.Values, i, i)] then
				valid = false
				break
			end
		end

		if valid then
			Grid.AddUnion(grid, u.Symbol, u.Values)
		end
	end
end

function Loader.Build(
	spec: Spec,
	grid: Grid.Grid,
	parentSymmetry: { boolean }
): Node.Node
	local d2 = grid.MZ == 1

	if spec.Kind == "Sequence" or spec.Kind == "Markov" then
		local symmetry = Symmetry.GetSymmetry(d2, spec.Symmetry, parentSymmetry)
		assert(symmetry, `Loader.Build: unknown symmetry "{spec.Symmetry}"`)
		local children = buildChildren(spec.Children, grid, symmetry)
		local node: Node.Node = { Kind = spec.Kind, Parent = nil, Data = { Nodes = children, N = 0 } }
		assignParents(children, node)

		return node
	elseif spec.Kind == "One" then
		return One.New(spec.Config, grid, parentSymmetry)
		
	elseif spec.Kind == "All" then
		return All.New(spec.Config, grid, parentSymmetry)

	elseif spec.Kind == "Parallel" then
		return Parallel.New(spec.Config, grid, parentSymmetry)

	elseif spec.Kind == "Path" then
		return PathMod.New(spec.Config, grid)

	elseif spec.Kind == "Convolution" then
		return Convolution.New(spec.Config, grid)

	elseif spec.Kind == "ConvChain" then
		return ConvChain.New(spec.Config, grid, parentSymmetry)

	elseif spec.Kind == "Map" then
		local symmetry = Symmetry.GetSymmetry(d2, spec.Config.Symmetry, parentSymmetry)
		assert(symmetry, `Loader.Build: unknown symmetry "{spec.Config.Symmetry}"`)

		local newgrid = Grid.New(
			spec.Values,
			(grid.MX * spec.Config.ScaleNX) // spec.Config.ScaleDX,
			(grid.MY * spec.Config.ScaleNY) // spec.Config.ScaleDY,
			(grid.MZ * spec.Config.ScaleNZ) // spec.Config.ScaleDZ
		)

		applyUnions(newgrid, spec.Unions)

		local children = buildChildren(spec.Children, newgrid, symmetry)
		local node = MapMod.New(spec.Config, grid, newgrid, symmetry, children)
		assignParents(children, node)

		return node
	elseif spec.Kind == "Overlap" then
		local newgrid = Grid.New(spec.Values, grid.MX, grid.MY, grid.MZ)
		applyUnions(newgrid, spec.Unions)

		local children = buildChildren(spec.Children, newgrid, parentSymmetry)
		local node = Overlap.New(spec.Config, grid, newgrid, parentSymmetry, children)
		assignParents(children, node)

		return node
	elseif spec.Kind == "TileModel" then
		local overlapAmt = spec.Config.Overlap or 0
		local overlapZ = spec.Config.OverlapZ or 0
		local s, sz = spec.Config.S, spec.Config.SZ
		local newgrid = Grid.New(
			spec.Values,
			(s - overlapAmt) * grid.MX + overlapAmt,
			(s - overlapAmt) * grid.MY + overlapAmt,
			(sz - overlapZ) * grid.MZ + overlapZ
		)
		applyUnions(newgrid, spec.Unions)
		
		local children = buildChildren(spec.Children, newgrid, parentSymmetry)
		local node = TileModel.New(spec.Config, grid, newgrid, parentSymmetry, children)
		assignParents(children, node)

		return node
	elseif spec.Kind == "Scope" then
		local pal = grid.Alphabet.Palette
		local slots: { Alphabet.SlotSpec } = {}

		for _, role in spec.Roles do
			local bind: Alphabet.Binding

			if role.Bind == "Any" then
				bind = "Any"
			elseif type(role.Bind) == "table" then
				bind = { Group = (role.Bind :: { Group: string }).Group }
			else
				bind = Palette.Id(pal, role.Bind :: string)
			end

			table.insert(slots, { Char = role.Char, Bind = bind, Role = role.Role })
		end

		local private: { Palette.SymbolId }? = nil

		if spec.Private then
			private = {}

			for _, name in spec.Private do
				local id = Palette.Add(pal, name)
				table.insert(private :: { Palette.SymbolId }, id)
				table.insert(slots, { Char = "$" .. name, Bind = id })
			end
		end

		local alphabet = Alphabet.New(pal, slots)
		local newgrid = Grid.FromAlphabet(alphabet, grid.MX, grid.MY, grid.MZ)
		local children = buildChildren(spec.Children, newgrid, parentSymmetry)
		local node = ScopeNode.New(newgrid, children, { Private = private, Ensures = spec.Ensures, Name = spec.Name })
		assignParents(children, node)

		return node
	elseif spec.Kind == "Retry" then
		local body = Loader.Build(spec.Body, grid, parentSymmetry)
		local node = RetryNode.New(body, spec.Attempts, spec.Ensures, spec.Name)

		if Node.BranchKinds[body.Kind] then
			body.Parent = node
		end

		return node
	elseif spec.Kind == "Budget" then
		local body = Loader.Build(spec.Body, grid, parentSymmetry)
		local node = BudgetNode.New(body, spec.Steps, spec.Seconds, spec.Name)

		if Node.BranchKinds[body.Kind] then
			body.Parent = node
		end

		return node
	elseif spec.Kind == "Seed" then
		return SeedNode.New(spec.VoxelsName, spec.Name)

	elseif spec.Kind == "Marker" then
		return MarkerNode.New(spec.Name)

	end

	error(`Loader.Build: unknown spec kind "{(spec :: any).Kind}"`, 0)
end

-- Grid.cs:59
function Loader.FromXml(
	xmlString: string,
	mx: number,
	my: number,
	mz: number,
	resolver: Sample.Resolver?): (Node.Node,
	Grid.Grid,
	boolean
)
	local root = Xml.Parse(xmlString)
	local origin = getBool(root, "origin", false)
	local values = string.gsub(requireString(root, "values"), " ", "")
	local grid = Grid.New(values, mx, my, mz, root.Attrs["transparent"])
	grid.Folder = root.Attrs["folder"]
	applyUnions(grid, collectUnions(root))

	local d2 = grid.MZ == 1
	local symmetry = Symmetry.GetSymmetry(d2, root.Attrs["symmetry"], Helper.Array1D(if d2 then 8 else 48, true))
	assert(symmetry, `Loader.FromXml: unknown symmetry "{root.Attrs["symmetry"]}"`)

	local spec = Loader.XmlToSpec(root, resolver, grid.Folder)
	local topnode = Loader.Build(spec, grid, symmetry)

	return topnode, grid, origin
end

return Loader
