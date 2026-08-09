--!strict
local GrowthXml = require(script.Parent.GrowthXml)
local ApartemazementsModel = require(script.Parent.ApartemazementsModel)
local Resolver = require(script.Parent.Parent.Resolver)
local Sample = require(script.Parent.Parent.MarkovJunior.Sample)
local Author = require(script.Parent.Parent.MarkovJunior.Model.Author)

local SimpleGrowthModel = require(script.Parent.SimpleGrowthModel)
local PathfindingModel = require(script.Parent.PathfindingModel)
local BasicWfcModel = require(script.Parent.BasicWfcModel)

export type AuthoredModel = (resolver: Sample.Resolver?) -> {
	Values: string,
	Symmetry: string?,
	Spec: Author.Spec,
}

export type ModelEntry = {
	Name: string,
	Xml: string?,
	Model: AuthoredModel?,
	MX: number,
	MY: number,
	MZ: number,
	Steps: number?,
	Resolver: (() -> any)?,
}

local Models: { ModelEntry } = {
	{
		Name = "Growth",
		Xml = GrowthXml,
		MX = 25,
		MY = 25,
		MZ = 25,
		Steps = 4000,
		Resolver = nil,
	},
	{
		Name = "Apartemazements",
		Model = ApartemazementsModel,
		MX = 8,
		MY = 8,
		MZ = 8,
		Steps = nil,
		Resolver = Resolver.New,
	},
	{
		Name = "SimpleGrowth",
		Model = SimpleGrowthModel,
		MX = 20,
		MY = 20,
		MZ = 1,
		Resolver = nil,
	},
	{
		Name = "Pathfinding",
		Model = PathfindingModel,
		MX = 20,
		MY = 20,
		MZ = 1,
		Resolver = nil,
	},
	{
		Name = "BasicWfc",
		Model = BasicWfcModel,
		MX = 8,
		MY = 8,
		MZ = 8,
		Resolver = Resolver.New,
	},
}

return Models
