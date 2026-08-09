--!strict
--!native
--!optimize 2
local Grid = require(script.Parent.Parent.Grid)
local Node = require(script.Parent.Parent.Node)
local Sample = require(script.Parent.Parent.Sample)
local Rule = require(script.Parent.Parent.Rule)
local Symmetry = require(script.Parent.Parent.Util.Symmetry)
local Helper = require(script.Parent.Parent.Util.Helper)
local Loader = require(script.Parent.Loader)
local Pattern = require(script.Parent.Pattern)
local Contract = require(script.Parent.Contract)

local RuleNode = require(script.Parent.Parent.Nodes.RuleNode)
local PathMod = require(script.Parent.Parent.Nodes.Path)
local MapMod = require(script.Parent.Parent.Nodes.Map)
local Convolution = require(script.Parent.Parent.Nodes.Convolution)
local ConvChain = require(script.Parent.Parent.Nodes.ConvChain)
local Overlap = require(script.Parent.Parent.Nodes.WFC.Overlap)
local TileModel = require(script.Parent.Parent.Nodes.WFC.TileModel)

--[=[
	@class Author
	
	Programmatic DSL for authoring MarkovJunior models entirely in code.
]=]
local Author = {}

export type Spec = Loader.Spec

local function origin(): string
	local source, line = debug.info(2, "sl")

	return `{source}:{line}`
end

--[=[
	Creates a Sequence node that executes its children in linear order.
	@param children table -- A list of specification child nodes to run.
	@param symmetry string? -- An optional symmetry transformation modifier.
	@return table -- A Sequence node specification.
]=]
function Author.Sequence(
	children: { Spec },
	symmetry: string?
): Spec

	return { Kind = "Sequence", Symmetry = symmetry, Children = children, Origin = origin() }
end

--[=[
	Creates a Markov node that applies its child nodes until no matches are found.
	@param children table -- A list of specification child nodes to loop through.
	@param symmetry string? -- An optional symmetry transformation modifier.
	@return table -- A Markov node specification.
]=]
function Author.Markov(
	children: { Spec },
	symmetry: string?
): Spec

	return { Kind = "Markov", Symmetry = symmetry, Children = children, Origin = origin() }
end

--[=[
	Creates a One node that applies a rule once and terminates.
	@param config table -- The configuration containing rule parameters.
	@return table -- A One node specification.
]=]
function Author.One(config: RuleNode.RuleNodeConfig): Spec
	return { Kind = "One", Config = config, Origin = origin() }
end

--[=[
	Creates an All node that applies a rule to all possible non-overlapping matches simultaneously.
	@param config table -- The configuration containing rule parameters.
	@return table -- An All node specification.
]=]
function Author.All(config: RuleNode.RuleNodeConfig): Spec
	return { Kind = "All", Config = config, Origin = origin() }
end

--[=[
	Creates a Parallel node that applies rules continuously in parallel.
	@param config table -- The configuration containing rule parameters.
	@return table -- A Parallel node specification.
]=]
function Author.Parallel(config: RuleNode.RuleNodeConfig): Spec
	return { Kind = "Parallel", Config = config, Origin = origin() }
end

function Author.Path(config: PathMod.PathSpec): Spec
	return { Kind = "Path", Config = config, Origin = origin() }
end

function Author.Convolution(config: Convolution.ConvolutionConfig): Spec
	return { Kind = "Convolution", Config = config, Origin = origin() }
end

function Author.ConvChain(config: ConvChain.ConvChainConfig): Spec
	return { Kind = "ConvChain", Config = config, Origin = origin() }
end

function Author.Marker(name: string): Spec
	return { Kind = "Marker", Name = name, Origin = origin() }
end

export type UnionSpec = { Symbol: string, Values: string }

function Author.Map(
	config: MapMod.MapConfig,
	values: string,
	children: { Spec },
	unions: { UnionSpec }?
): Spec

	return { Kind = "Map", Config = config, Values = values, Children = children, Unions = unions or {}, Origin = origin() }
end

function Author.Overlap(
	config: Overlap.OverlapConfig,
	values: string,
	children: { Spec },
	unions: { UnionSpec }?
): Spec
	return { Kind = "Overlap", Config = config, Values = values, Children = children, Unions = unions or {}, Origin = origin() }
end

function Author.TileModel(
	config: TileModel.TileModelConfig,
	values: string,
	children: { Spec },
	unions: { UnionSpec }?
): Spec
	return { Kind = "TileModel", Config = config, Values = values, Children = children, Unions = unions or {}, Origin = origin() }
end

export type TileModelOptions = {
	Rules: { { In: string, Out: string } },
	TilesFolder: string?,
	Periodic: boolean?,
	Overlap: number?,
	OverlapZ: number?,
	Shannon: boolean?,
	Tries: number?,
}

function Author.ResolveTileModel(
	resolver: Sample.Resolver?,
	name: string,
	opts: TileModelOptions
): TileModel.TileModelConfig
	local resolveTileset = Sample.Require(resolver, "ResolveTileset", name)
	local tileset = resolveTileset(name, opts.TilesFolder or name)
	local tiles: { TileModel.TileSpec } = table.create(#tileset.Tiles)

	for _, t in tileset.Tiles do
		table.insert(tiles, { Name = t.Name, Weight = t.Weight, Voxels = t.Voxels })
	end

	local neighbors: { TileModel.NeighborSpec } = table.create(#tileset.Neighbors)
	for _, n in tileset.Neighbors do
		table.insert(neighbors, { Left = n.Left, Right = n.Right, Top = n.Top, Bottom = n.Bottom })
	end

	return {
		Periodic = opts.Periodic or false,
		FullSymmetry = tileset.FullSymmetry,
		Overlap = opts.Overlap or 0,
		OverlapZ = opts.OverlapZ or 0,
		S = tileset.S,
		SZ = tileset.SZ,
		Tiles = tiles,
		Neighbors = neighbors,
		Rules = opts.Rules,
		Shannon = opts.Shannon or false,
		Tries = opts.Tries or 1000,
		TilesetName = name,
	}
end


function Author.ImageChars(
	resolver: Sample.Resolver?,
	name: string,
	folder: string?): ({ string },
	number,
	number,
	number
)
	local resolve = Sample.Require(resolver, "ResolveImage", name)
	local img = resolve(name, folder)
	local ords, amount = Helper.Ords(img.Data)
	assert(img.Legend, `Author.ImageChars: resource "{name}" has no legend`)
	local legend = img.Legend :: string
	assert(amount <= #legend, `Author.ImageChars: the amount of colors {amount} in "{name}" is more than {#legend}`)
	local chars = table.create(#ords)

	for i, o in ords do
		chars[i] = string.sub(legend, o + 1, o + 1)
	end

	return chars, img.Width, img.Height, img.Depth
end

local function resolveMapRuleSides(resolver: Sample.Resolver?, folder: string?, opts: {
	In: string?,
	Out: string?,
	Fin: string?,
	Fout: string?,
	File: string?,
})
	if opts.File then
		local chars, fx, fy, fz = Author.ImageChars(resolver, opts.File, folder)
		assert(fx % 2 == 0, `Author.MapRule: odd width {fx} in "{opts.File}"`)
		local imx, imy, imz = fx // 2, fy, fz
		local inChars, outChars = table.create(imx * imy * imz), table.create(imx * imy * imz)

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

		return inChars, imx, imy, imz, outChars, imx, imy, imz
	end

	local inChars, imx, imy, imz
	local outChars, omx, omy, omz

	if opts.In then
		inChars, imx, imy, imz = Rule.Parse(opts.In)
	else
		inChars, imx, imy, imz = Author.ImageChars(resolver, opts.Fin :: string, folder)
	end

	if opts.Out then
		outChars, omx, omy, omz = Rule.Parse(opts.Out)
	else
		outChars, omx, omy, omz = Author.ImageChars(resolver, opts.Fout :: string, folder)
	end

	return inChars, imx, imy, imz, outChars, omx, omy, omz
end

export type MapRuleOptions = { In: string?, Out: string?, Fin: string?, Fout: string?, File: string?, P: number? }

function Author.MapRule(
	resolver: Sample.Resolver?,
	folder: string?,
	opts: MapRuleOptions
): MapMod.MapRuleSpec
	local inChars, imx, imy, imz, outChars, omx, omy, omz = resolveMapRuleSides(resolver, folder, opts)

	return { InChars = inChars, IMX = imx, IMY = imy, IMZ = imz, OutChars = outChars, OMX = omx, OMY = omy, OMZ = omz, P = opts.P }
end

export type RetryConfig = {
	Body: Spec,
	Attempts: number,
	Ensures: { Contract.Check }?,
	Name: string?,
}

--[=[
	Creates a Retry node that attempts its body up to a specified number of times if it fails contracts.
	@param config table -- The retry node configuration and constraint assertions.
	@return table -- A Retry node specification.
]=]
function Author.Retry(config: RetryConfig): Spec

	return {
		Kind = "Retry",
		Body = config.Body,
		Attempts = config.Attempts,
		Ensures = config.Ensures,
		Name = config.Name,
		Origin = origin(),
	}
end

export type BudgetConfig = {
	Body: Spec,
	Steps: number?,
	Seconds: number?,
	Name: string?,
}

function Author.Budget(config: BudgetConfig): Spec

	return {
		Kind = "Budget",
		Body = config.Body,
		Steps = config.Steps,
		Seconds = config.Seconds,
		Name = config.Name,
		Origin = origin(),
	}
end

--[=[
	Creates a Seed node that initializes the grid from external voxel data.
	@param voxelsName string -- The name of the voxel file to load.
	@param name string? -- An optional internal name for the node.
	@return table -- A Seed node specification.
]=]
function Author.Seed(
	voxelsName: string,
	name: string?
): Spec

	return {
		Kind = "Seed",
		VoxelsName = voxelsName,
		Name = name,
		Origin = origin(),
	}
end

export type RewriteOptions = { P: number?, Symmetry: string? }

function Author.Rewrite(
	raw: string,
	options: RewriteOptions?
): RuleNode.RuleSpec
	local parsed = Pattern.Parse(raw)
	local opts = options or {}

	return {
		InChars = parsed.InTokens,
		IMX = parsed.IMX,
		IMY = parsed.IMY,
		IMZ = parsed.IMZ,
		OutChars = parsed.OutTokens,
		OMX = parsed.OMX,
		OMY = parsed.OMY,
		OMZ = parsed.OMZ,
		P = opts.P,
		Symmetry = opts.Symmetry,
	}
end

function Author.Rule(
	inRaw: string,
	outRaw: string,
	options: RewriteOptions?
): RuleNode.RuleSpec
	local inChars, imx, imy, imz = Rule.Parse(inRaw)
	local outChars, omx, omy, omz = Rule.Parse(outRaw)
	local opts = options or {}

	return {
		InChars = inChars,
		IMX = imx,
		IMY = imy,
		IMZ = imz,
		OutChars = outChars,
		OMX = omx,
		OMY = omy,
		OMZ = omz,
		P = opts.P,
		Symmetry = opts.Symmetry,
	}
end

export type NewOptions = {
	Origin: boolean?,
	Transparent: string?,
	Folder: string?,
	Symmetry: string?,
	Unions: { { Symbol: string, Values: string } }?,
	Resolver: Sample.Resolver?,
}

function Author.New(
	spec: Spec,
	values: string,
	mx: number,
	my: number,
	mz: number,
	options: NewOptions?): (Node.Node,
	Grid.Grid,
	boolean
)
	local opts = options or {}
	local grid = Grid.New(values, mx, my, mz, opts.Transparent)
	grid.Folder = opts.Folder

	if opts.Unions then
		for _, u in opts.Unions :: { { Symbol: string, Values: string } } do
			Grid.AddUnion(grid, u.Symbol, u.Values)
		end
	end

	local d2 = grid.MZ == 1
	local symmetry = Symmetry.GetSymmetry(d2, opts.Symmetry, Helper.Array1D(if d2 then 8 else 48, true))
	assert(symmetry, `Author.New: unknown symmetry "{opts.Symmetry}"`)

	local topnode = Loader.Build(spec, grid, symmetry)
	return topnode, grid, opts.Origin or false
end

Author.Build = Loader.Build

return Author
