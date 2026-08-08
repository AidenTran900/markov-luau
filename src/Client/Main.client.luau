--!strict
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local vide = require(ReplicatedStorage.Packages.vide)

local UI = script.Parent:WaitForChild("UI")

local App = require(UI.App)
local Store = require(UI.Store)

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

local screenGui = Instance.new("ScreenGui")
screenGui.Name = "MarkovUI"
screenGui.ResetOnSpawn = false
screenGui.IgnoreGuiInset = true
screenGui.Parent = playerGui

vide.root(function()
	App().Parent = screenGui
end)

if Store.Models[1] then
	Store.LoadModel(Store.Models[1])
end
