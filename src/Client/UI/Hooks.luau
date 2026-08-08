--!strict
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local vide = require(ReplicatedStorage.Packages.vide)
local Store = require(script.Parent.Store)

local Hooks = {}

Hooks.version = vide.source(0)

Store.Subscribe(function()
	Hooks.version(Hooks.version() + 1)
end)

function Hooks.useStoreVersion(): number
	return Hooks.version()
end

return Hooks
