--!strict
--!native
--!optimize 2
local Grid = require(script.Grid)
local Rule = require(script.Rule)
local Node = require(script.Node)
local Interpreter = require(script.Interpreter)
local Sample = require(script.Sample)

local Xml = require(script.Model.Xml)
local Loader = require(script.Model.Loader)
local Dsl = require(script.Model.Dsl)
local Author = require(script.Model.Author)
local Pattern = require(script.Model.Pattern)

local One = require(script.Nodes.One)
local All = require(script.Nodes.All)
local Parallel = require(script.Nodes.Parallel)
local PathMod = require(script.Nodes.Path)
local MapMod = require(script.Nodes.Map)
local Convolution = require(script.Nodes.Convolution)
local ConvChain = require(script.Nodes.ConvChain)
local Overlap = require(script.Nodes.WFC.Overlap)
local TileModel = require(script.Nodes.WFC.TileModel)
local ScopeNode = require(script.Nodes.Scope)
local RetryNode = require(script.Nodes.Retry)
local BudgetNode = require(script.Nodes.Budget)
local SeedNode = require(script.Nodes.Seed)
local MarkerNode = require(script.Nodes.Marker)

local Symbol_Palette = require(script.Symbol.Palette)
local Symbol_Alphabet = require(script.Symbol.Alphabet)
local Symbol_Legend = require(script.Symbol.Legend)
local Contract = require(script.Model.Contract)
local Scope = require(script.Model.Scope)
local Component = require(script.Model.Component)
local Stage = require(script.Model.Stage)

local VoxelField = require(script.Field.VoxelField)
local Export = require(script.Output.Export)
local Neighborhood = require(script.Output.Neighborhood)
local MeshPass = require(script.Output.MeshPass)

local RegionTable = require(script.Constraint.RegionTable)
local ConstraintPredicates = require(script.Constraint.Predicates)

local MarkovJunior = {}

-- Core engine
MarkovJunior.Grid = Grid
MarkovJunior.Rule = Rule
MarkovJunior.Node = Node
MarkovJunior.Interpreter = Interpreter
MarkovJunior.Sample = Sample

-- Model construction
MarkovJunior.Xml = Xml
MarkovJunior.Loader = Loader
MarkovJunior.Dsl = Dsl
MarkovJunior.Author = Author
MarkovJunior.Pattern = Pattern
MarkovJunior.Scope = Scope
MarkovJunior.Contract = Contract
MarkovJunior.Component = Component
MarkovJunior.Stage = Stage

-- Channels / output
MarkovJunior.VoxelField = VoxelField
MarkovJunior.Export = Export
MarkovJunior.Neighborhood = Neighborhood
MarkovJunior.MeshPass = MeshPass

-- Constraints
MarkovJunior.RegionTable = RegionTable
MarkovJunior.Constraint = ConstraintPredicates

-- Symbols
MarkovJunior.Palette = Symbol_Palette
MarkovJunior.Alphabet = Symbol_Alphabet
MarkovJunior.Legend = Symbol_Legend

local DISPATCH: Node.Dispatch = {
	Sequence = Node.Sequence,
	Markov = Node.Markov,
	One = One.Impl,
	All = All.Impl,
	Parallel = Parallel.Impl,
	Path = PathMod.Impl,
	Map = MapMod.Impl,
	Convolution = Convolution.Impl,
	ConvChain = ConvChain.Impl,
	Overlap = Overlap.Impl,
	TileModel = TileModel.Impl,
	Scope = ScopeNode.Impl,
	Retry = RetryNode.Impl,
	Budget = BudgetNode.Impl,
	Seed = SeedNode.Impl,
	Marker = MarkerNode.Impl,
}

MarkovJunior.Dispatch = DISPATCH

function MarkovJunior.RunXml(
	xmlString: string, 
	mx: number, 
	my: number, 
	mz: number, 
	seed: number, 
	steps: number?, 
	resolver: Sample.Resolver?
): Grid.Grid
	local model, grid, origin = Loader.FromXml(xmlString, mx, my, mz, resolver)
	return Interpreter.Run(DISPATCH, model, grid, seed, steps, origin)
end

function MarkovJunior.RunSpec(
	spec: Author.Spec, 
	values: string, 
	mx: number, 
	my: number, 
	mz: number, 
	seed: number, 
	steps: number?, 
	options: Author.NewOptions?
): Grid.Grid
	local model, grid, origin = Author.New(spec, values, mx, my, mz, options)
	return Interpreter.Run(DISPATCH, model, grid, seed, steps, origin)
end

MarkovJunior.Sequence = Author.Sequence
MarkovJunior.Markov = Author.Markov
MarkovJunior.One = Author.One
MarkovJunior.All = Author.All
MarkovJunior.Parallel = Author.Parallel
MarkovJunior.Path = Author.Path
MarkovJunior.Convolution = Author.Convolution
MarkovJunior.ConvChain = Author.ConvChain
MarkovJunior.Map = Author.Map
MarkovJunior.Overlap = Author.Overlap
MarkovJunior.TileModel = Author.TileModel
MarkovJunior.Rewrite = Author.Rewrite
MarkovJunior.Retry = Author.Retry
MarkovJunior.Budget = Author.Budget
MarkovJunior.Seed = Author.Seed
MarkovJunior.Marker = Author.Marker

return MarkovJunior
