--!strict
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local MarkovJunior = require(ReplicatedStorage.MarkovJunior)
local VoxelMesher = require(ReplicatedStorage.VoxelMesher)
local BasePalette = require(ReplicatedStorage.MarkovData.Palette)
local ModelRegistry = require(ReplicatedStorage.MarkovData.ModelRegistry)

local Interpreter = require(ReplicatedStorage.MarkovJunior.Interpreter)
local Loader = require(ReplicatedStorage.MarkovJunior.Model.Loader)
local Author = require(ReplicatedStorage.MarkovJunior.Model.Author)
local Dispatch = MarkovJunior.Dispatch

local State = require(script.Parent.State)

export type InterpreterState = Interpreter.InterpreterState

local Store = {}

Store.Models = ModelRegistry
Store.Palette = table.clone(BasePalette) :: { [string]: Color3 }

Store.CurrentEntry = nil :: ModelRegistry.ModelEntry?
Store.Ip = nil :: InterpreterState?
Store.Seed = os.time()
Store.Paused = false
Store.Running = false
Store.Dirty = true
Store.SelectedSymbol = nil :: string?

Store.Nodes = {} :: { [number]: State.NodeInfo }
Store.CurrentNodeIndex = -1
Store.Wildcard = 0
Store.Snapshots = {} :: { { Name: string, StateBuffer: buffer, Grid: any } }
Store.CurrentSnapshotIndex = 0

Store.ViewportFrame = nil :: ViewportFrame?

local displayParts: { MeshPart } = {}
local displayChunks: { any } = {}

local listeners: { [number]: () -> () } = {}
local nextListenerId = 0

function Store.Subscribe(fn: () -> ()): () -> ()
	nextListenerId += 1
	local id = nextListenerId
	listeners[id] = fn
	return function()
		listeners[id] = nil
	end
end

function Store.Notify()
	for _, fn in listeners do
		fn()
	end
end

local function colorToHex(c: Color3): string
	return string.format("%02X%02X%02X", math.floor(c.R * 255 + 0.5), math.floor(c.G * 255 + 0.5), math.floor(c.B * 255 + 0.5))
end
Store.ColorToHex = colorToHex

function Store.ParseHex(s: string): Color3?
	s = s:gsub("^#", "")
	if #s ~= 6 then
		return nil
	end
	local r = tonumber(s:sub(1, 2), 16)
	local g = tonumber(s:sub(3, 4), 16)
	local b = tonumber(s:sub(5, 6), 16)
	if not (r and g and b) then
		return nil
	end
	return Color3.fromRGB(r, g, b)
end

local function clearDisplay()
	for _, part in displayParts do
		part:Destroy()
	end
	for _, chunk in displayChunks do
		chunk:Destroy()
	end
	table.clear(displayParts)
	table.clear(displayChunks)
end

local function rebuildMesh()
	local ip, entry = Store.Ip, Store.CurrentEntry
	if not ip or not entry then
		return
	end
	clearDisplay()
	local target = Store.ViewportFrame or workspace
	local center = Vector3.new(ip.Grid.MX / 2, ip.Grid.MZ / 2, -ip.Grid.MY / 2)
	local parts, _, chunks = VoxelMesher.BuildAndDisplay(ip.Grid, Store.Palette, target, entry.Name, -center)
	displayParts = parts
	displayChunks = chunks or {}
end
Store.RebuildMesh = rebuildMesh

function Store.GetPaletteColor(symbol: string): Color3
	return Store.Palette[symbol] or Color3.new(1, 0, 1)
end

function Store.SelectSymbol(symbol: string)
	Store.SelectedSymbol = symbol
	Store.Notify()
end

function Store.ApplyPaletteEdit(hex: string)
	local symbol = Store.SelectedSymbol
	if not symbol then
		return
	end
	local color = Store.ParseHex(hex)
	if not color then
		return
	end
	Store.Palette[symbol] = color
	rebuildMesh()
	Store.Notify()
end

local function refreshCurrentNode()
	local ip = Store.Ip
	if not ip then
		Store.CurrentNodeIndex = -1
		return
	end
	Store.CurrentNodeIndex = State.CurrentIndex(Store.Nodes, ip)
end

local function rebuildIp()
	local entry = Store.CurrentEntry
	assert(entry, "rebuildIp: no model selected")
	local resolver = entry.Resolver and entry.Resolver() or nil

	local model, grid, origin
	if entry.Model then
		local built = entry.Model(resolver)
		model, grid, origin = Author.New(built.Spec, built.Values, entry.MX, entry.MY, entry.MZ, { Symmetry = built.Symmetry })
	else
		assert(entry.Xml, `rebuildIp: model "{entry.Name}" has neither Xml nor Model`)
		model, grid, origin = Loader.FromXml(entry.Xml, entry.MX, entry.MY, entry.MZ, resolver)
	end
	local ip = Interpreter.NewState(Dispatch, model, grid, Store.Seed, origin)
	
	table.clear(Store.Snapshots)
	Store.CurrentSnapshotIndex = 0
	ip.OnMarker = function(name)
		local currentGrid = ip.Grid
		local copy = buffer.create(buffer.len(currentGrid.State))
		buffer.copy(copy, 0, currentGrid.State, 0, buffer.len(currentGrid.State))
		table.insert(Store.Snapshots, {
			Name = name,
			StateBuffer = copy,
			Grid = currentGrid
		})
	end

	Store.Ip = ip
	Store.Dirty = false
	Store.Nodes = State.Traverse(ip.Root)
	if grid.C >= 31 then
		Store.Wildcard = 0x7FFFFFFF
	else
		Store.Wildcard = bit32.lshift(1, grid.C) - 1
	end
	refreshCurrentNode()
	rebuildMesh()
end

function Store.LoadModel(entry: ModelRegistry.ModelEntry)
	Store.CurrentEntry = entry
	Store.Seed = os.time()
	Store.Paused = false
	Store.Running = false
	Store.SelectedSymbol = nil
	Store.SelectedSymbol = nil

	rebuildIp()
	Store.Notify()
end

function Store.ApplySnapshot(index: number)
	if index < 1 or index > #Store.Snapshots then return end
	Store.CurrentSnapshotIndex = index
	local snap = Store.Snapshots[index]
	
	local ip = Store.Ip :: InterpreterState
	ip.Grid = snap.Grid
	buffer.copy(ip.Grid.State, 0, snap.StateBuffer, 0, buffer.len(snap.StateBuffer))
	
	rebuildMesh()
	Store.Notify()
end

function Store.NextSnapshot()
	Store.ApplySnapshot(Store.CurrentSnapshotIndex + 1)
end

function Store.PrevSnapshot()
	Store.ApplySnapshot(Store.CurrentSnapshotIndex - 1)
end

function Store.Generate()
	if not Store.CurrentEntry then
		return
	end

	rebuildIp()
	local ip = Store.Ip :: InterpreterState
	while ip.Current ~= nil do
		Interpreter.Step(ip, Dispatch)
	end
	
	local copy = buffer.create(buffer.len(ip.Grid.State))
	buffer.copy(copy, 0, ip.Grid.State, 0, buffer.len(ip.Grid.State))
	table.insert(Store.Snapshots, {
		Name = "Final",
		StateBuffer = copy,
		Grid = ip.Grid
	})
	
	Store.CurrentSnapshotIndex = #Store.Snapshots
	Store.ApplySnapshot(Store.CurrentSnapshotIndex)
end

function Store.Randomize()
	Store.Seed = math.random(0, 2147483647)
	Store.Dirty = true
	Store.Notify()
end

function Store.SetSeed(n: number)
	Store.Seed = math.floor(n)
	Store.Dirty = true
	Store.Notify()
end

return Store
