--!strict
--!native
--!optimize 2
local Export = require(script.Parent.Export)
local Palette = require(script.Parent.Parent.Symbol.Palette)

local MeshPass = {}

export type MeshPassFn = (input: Export.MeshInput, dirty: { number }?) -> ...any

local registry: { [string]: MeshPassFn } = {}

function MeshPass.Register(class: string, pass: MeshPassFn)
	registry[class] = pass
end

function MeshPass.Get(class: string): MeshPassFn?
	return registry[class]
end

function MeshPass.For(
	input: Export.MeshInput,
	symbolId: Palette.SymbolId
): MeshPassFn?

	local entry = input.Palette.Entries[symbolId]

	if not entry or not entry.Meta then
		return nil
	end

	local class = entry.Meta.MeshClass

	if type(class) ~= "string" then
		return nil
	end

	return registry[class]
end

return MeshPass
