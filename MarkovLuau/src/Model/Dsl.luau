--!strict
--!native
--!optimize 2
local Grid = require(script.Parent.Parent.Grid)
local Node = require(script.Parent.Parent.Node)
local Sample = require(script.Parent.Parent.Sample)
local Symmetry = require(script.Parent.Parent.Util.Symmetry)
local Helper = require(script.Parent.Parent.Util.Helper)
local Loader = require(script.Parent.Loader)

local RuleNode = require(script.Parent.Parent.Nodes.RuleNode)
local PathMod = require(script.Parent.Parent.Nodes.Path)
local MapMod = require(script.Parent.Parent.Nodes.Map)
local Convolution = require(script.Parent.Parent.Nodes.Convolution)
local ConvChain = require(script.Parent.Parent.Nodes.ConvChain)
local Overlap = require(script.Parent.Parent.Nodes.WFC.Overlap)
local TileModel = require(script.Parent.Parent.Nodes.WFC.TileModel)

local Dsl = {}

export type Spec = Loader.Spec

function Dsl.Sequence(
	symmetry: string?,
	children: { Spec }
): Spec
	return { Kind = "Sequence", Symmetry = symmetry, Children = children }
end

function Dsl.Markov(
	symmetry: string?,
	children: { Spec }
): Spec

	return { Kind = "Markov", Symmetry = symmetry, Children = children }
end

function Dsl.One(config: RuleNode.RuleNodeConfig): Spec
	return { Kind = "One", Config = config }
end

function Dsl.All(config: RuleNode.RuleNodeConfig): Spec
	return { Kind = "All", Config = config }
end

function Dsl.Parallel(config: RuleNode.RuleNodeConfig): Spec
	return { Kind = "Parallel", Config = config }
end

function Dsl.Path(config: PathMod.PathSpec): Spec
	return { Kind = "Path", Config = config }
end

function Dsl.Convolution(config: Convolution.ConvolutionConfig): Spec
	return { Kind = "Convolution", Config = config }
end

function Dsl.ConvChain(config: ConvChain.ConvChainConfig): Spec
	return { Kind = "ConvChain", Config = config }
end

function Dsl.Map(
	config: MapMod.MapConfig,
	values: string,
	children: { Spec }
): Spec
	return { Kind = "Map", Config = config, Values = values, Children = children }
end

function Dsl.Overlap(
	config: Overlap.OverlapConfig,
	values: string,
	children: { Spec }
): Spec
	return { Kind = "Overlap", Config = config, Values = values, Children = children }
end

function Dsl.TileModel(
	config: TileModel.TileModelConfig,
	values: string,
	children: { Spec }
): Spec
	return { Kind = "TileModel", Config = config, Values = values, Children = children }
end

export type NewOptions = {
	Origin: boolean?,
	Transparent: string?,
	Folder: string?,
	Symmetry: string?,
	Unions: { { Symbol: string, Values: string } }?,
	Resolver: Sample.Resolver?,
}

function Dsl.New(
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
	assert(symmetry, `Dsl.New: unknown symmetry "{opts.Symmetry}"`)

	local topnode = Loader.Build(spec, grid, symmetry)
	return topnode, grid, opts.Origin or false
end

Dsl.Build = Loader.Build

return Dsl
