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

--[=[
	@class MarkovJunior
	
	The main API for the MarkovLuau engine. This module provides functions to run
	procedural generation models and access core engine components.
]=]
local MarkovJunior = {}

-- Core engine
--[=[
	@prop Grid table -- The module for managing 3D grid states and WFC matching.
	@within MarkovJunior
]=]
MarkovJunior.Grid = Grid
--[=[
	@prop Rule table -- The module for defining and transforming Markov rules.
	@within MarkovJunior
]=]
MarkovJunior.Rule = Rule
--[=[
	@prop Node table -- The module defining the base node structure for model execution.
	@within MarkovJunior
]=]
MarkovJunior.Node = Node
--[=[
	@prop Interpreter table -- The module for interpreting and running generated models.
	@within MarkovJunior
]=]
MarkovJunior.Interpreter = Interpreter
--[=[
	@prop Sample table -- The module for resolving external samples and images.
	@within MarkovJunior
]=]
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

--[=[
	Runs a MarkovJunior model from an XML string.
	
	@param xmlString string -- The XML string that contains the model definition.
	@param mx number -- The X dimension of the output grid.
	@param my number -- The Y dimension of the output grid.
	@param mz number -- The Z dimension of the output grid.
	@param seed number -- The random seed for generation.
	@param steps number? -- The maximum number of steps to run.
	@param resolver table? -- The resource resolver for loading external patterns.
	@return table -- Returns the generated grid.
]=]
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

--[=[
	Runs a MarkovJunior model from a Lua specification table.
	
	@param spec table -- The specification table defining the model rules.
	@param values string -- The string of characters representing grid values.
	@param mx number -- The X dimension of the output grid.
	@param my number -- The Y dimension of the output grid.
	@param mz number -- The Z dimension of the output grid.
	@param seed number -- The random seed for generation.
	@param steps number? -- The maximum number of steps to run.
	@param options table? -- Additional options for model creation.
	@return table -- Returns the generated grid.
]=]
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

--[=[
	Creates a Sequence node that runs its child nodes in order.
	@prop Sequence function
	@within MarkovJunior
]=]
MarkovJunior.Sequence = Author.Sequence

--[=[
	Creates a Markov node that applies its child nodes until no more matches are found.
	@prop Markov function
	@within MarkovJunior
]=]
MarkovJunior.Markov = Author.Markov

--[=[
	Creates a One node that applies a rule once and stops.
	@prop One function
	@within MarkovJunior
]=]
MarkovJunior.One = Author.One

--[=[
	Creates an All node that applies a rule to all possible non-overlapping matches simultaneously.
	@prop All function
	@within MarkovJunior
]=]
MarkovJunior.All = Author.All

--[=[
	Creates a Parallel node that continuously applies rules in parallel without overlap checks.
	@prop Parallel function
	@within MarkovJunior
]=]
MarkovJunior.Parallel = Author.Parallel

--[=[
	Creates a Path node that generates a path between points in the grid.
	@prop Path function
	@within MarkovJunior
]=]
MarkovJunior.Path = Author.Path

--[=[
	Creates a Convolution node that applies cellular automata rules using neighborhood kernels.
	@prop Convolution function
	@within MarkovJunior
]=]
MarkovJunior.Convolution = Author.Convolution

--[=[
	Creates a ConvChain node for generating continuous textures based on an input sample.
	@prop ConvChain function
	@within MarkovJunior
]=]
MarkovJunior.ConvChain = Author.ConvChain

--[=[
	Creates a Map node that transfers and scales grid contents between domains.
	@prop Map function
	@within MarkovJunior
]=]
MarkovJunior.Map = Author.Map

--[=[
	Creates an Overlap Wave Function Collapse node for generating structures from examples.
	@prop Overlap function
	@within MarkovJunior
]=]
MarkovJunior.Overlap = Author.Overlap

--[=[
	Creates a TileModel Wave Function Collapse node for generating structures using predefined tiles.
	@prop TileModel function
	@within MarkovJunior
]=]
MarkovJunior.TileModel = Author.TileModel

--[=[
	Creates a Rewrite rule from a pattern string.
	@prop Rewrite function
	@within MarkovJunior
]=]
MarkovJunior.Rewrite = Author.Rewrite

--[=[
	Creates a Retry node that attempts its body up to a specified number of times if it fails contracts.
	@prop Retry function
	@within MarkovJunior
]=]
MarkovJunior.Retry = Author.Retry

--[=[
	Creates a Budget node that restricts the execution of its body by steps or time.
	@prop Budget function
	@within MarkovJunior
]=]
MarkovJunior.Budget = Author.Budget

--[=[
	Creates a Seed node that initializes the grid from external voxel data.
	@prop Seed function
	@within MarkovJunior
]=]
MarkovJunior.Seed = Author.Seed

--[=[
	Creates a Marker node that yields execution and fires an event for step-by-step visualization.
	@prop Marker function
	@within MarkovJunior
]=]
MarkovJunior.Marker = Author.Marker


return MarkovJunior
