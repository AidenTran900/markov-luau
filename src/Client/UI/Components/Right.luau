--!strict
-- port of MarkovJuniorWeb's src/web/right.tsx
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local vide = require(ReplicatedStorage.Packages.vide)

local Store = require(script.Parent.Parent.Store)
local Hooks = require(script.Parent.Parent.Hooks)
local State = require(script.Parent.Parent.State)
local Theme = require(script.Parent.Parent.Theme)

local NodeMod = require(ReplicatedStorage.MarkovJunior.Node)
local GridMod = require(ReplicatedStorage.MarkovJunior.Grid)
local RuleMod = require(ReplicatedStorage.MarkovJunior.Rule)
local Helper = require(ReplicatedStorage.MarkovJunior.Util.Helper)
local RuleNodeMod = require(ReplicatedStorage.MarkovJunior.Nodes.RuleNode)
local ParallelMod = require(ReplicatedStorage.MarkovJunior.Nodes.Parallel)
local MapMod = require(ReplicatedStorage.MarkovJunior.Nodes.Map)
local ConvolutionMod = require(ReplicatedStorage.MarkovJunior.Nodes.Convolution)
local ConvChainMod = require(ReplicatedStorage.MarkovJunior.Nodes.ConvChain)
local PathMod = require(ReplicatedStorage.MarkovJunior.Nodes.Path)
local FieldMod = require(ReplicatedStorage.MarkovJunior.Nodes.Field)
local ObservationMod = require(ReplicatedStorage.MarkovJunior.Inference.Observation)

local CELL = 14

-- color helpers
local function colorForIndex(grid: GridMod.Grid, colorIndex: number): Color3
	local symbol = grid.Characters[colorIndex + 1]
	if not symbol then
		return Color3.new(1, 0, 1)
	end
	return Store.GetPaletteColor(symbol)
end

local function bitPosition(v: number): number
	for i = 0, 30 do
		if bit32.band(v, bit32.lshift(1, i)) ~= 0 then
			return i
		end
	end
	return -1
end

-- Cell

type CellProps = {
	Grid: GridMod.Grid,
	Value: number,
	LayoutOrder: number?,
	Transparency: number?,
	ZIndex: number?,
	Position: UDim2?,
}

local function Cell(props: CellProps)
	local transparent = props.Value == 0xff
	return Theme.Frame {
		Size = UDim2.new(0, CELL, 0, CELL),
		Position = props.Position,
		BackgroundColor3 = if transparent then Color3.new(1, 1, 1) else colorForIndex(props.Grid, props.Value),
		BackgroundTransparency = if transparent then 1 else (props.Transparency or 0),
		BorderSizePixel = 0,
		ZIndex = if transparent then (props.ZIndex or 20) - 5 else (props.ZIndex or 20),
		LayoutOrder = props.LayoutOrder or 0,
		
		vide.create("UIStroke") {
			Color = Color3.fromRGB(238, 238, 238),
			Thickness = 1,
			Transparency = 1 - ((if transparent then 0.5 else 1) * (1 - (props.Transparency or 0))),
			ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
		}
	}
end

-- UnionCell

type UnionCellProps = {
	Grid: GridMod.Grid,
	Value: number,
	LayoutOrder: number?,
	Transparency: number?,
	ZIndex: number?,
	Position: UDim2?,
}

local function UnionCell(props: UnionCellProps)
	local c = props.Grid.C
	local wildcard = if c >= 31 then 0x7FFFFFFF else bit32.lshift(1, c) - 1
	local value = props.Value
	
	value = bit32.band(value, wildcard)
	
	local transparent = value == wildcard
	local isPot = value ~= 0 and bit32.band(value, value - 1) == 0

	local bg = Color3.new(1, 1, 1)
	local kids: { any } = {}

	if transparent then
	elseif isPot then
		bg = colorForIndex(props.Grid, bitPosition(value))
	else
		local colors: { Color3 } = {}
		for i = 0, 30 do
			if #colors >= 10 then
				break
			end
			if bit32.band(value, bit32.lshift(1, i)) ~= 0 then
				table.insert(colors, colorForIndex(props.Grid, i))
			end
		end
		if #colors > 0 then
			bg = colors[1]
		end
		if #colors > 1 then
			local n = #colors
			local keypoints: { ColorSequenceKeypoint } = {}
			for idx, col in colors do
				local t0 = (idx - 1) / n
				local t1 = idx / n - 0.001
				table.insert(keypoints, ColorSequenceKeypoint.new(math.clamp(t0, 0, 1), col))
				table.insert(keypoints, ColorSequenceKeypoint.new(math.clamp(t1, t0, 1), col))
			end
			keypoints[1] = ColorSequenceKeypoint.new(0, colors[1])
			keypoints[#keypoints] = ColorSequenceKeypoint.new(1, colors[n])
			table.insert(kids, vide.create("UIGradient") { Color = ColorSequence.new(keypoints) })
		end
	end

	table.insert(kids, vide.create("Frame") {
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,
		vide.create("UIStroke") {
			Color = Color3.fromRGB(238, 238, 238),
			Thickness = 1,
			Transparency = 1 - ((if transparent then 0.5 else 1) * (1 - (props.Transparency or 0))),
			ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
		}
	})

	return Theme.Frame {
		Size = UDim2.new(0, CELL, 0, CELL),
		Position = props.Position,
		BackgroundColor3 = bg,
		BackgroundTransparency = if transparent then 1 else (props.Transparency or 0),
		BorderSizePixel = 0,
		ZIndex = if transparent then (props.ZIndex or 20) - 5 else (props.ZIndex or 20),
		LayoutOrder = props.LayoutOrder or 0,
		unpack(kids)
	}
end

-- Grid builder

local function buildGrid(mx: number, my: number, mz: number, cellAt: (x: number, y: number, z: number, transparency: number, layoutOrder: number, zIndex: number, position: UDim2) -> any)
	local cells: { any } = {}
	for z = 0, mz - 1 do
		local opacity = if z == 0 then 1 else (mz - z) / mz / 2 + 0.25
		local transparency = 1 - opacity
		for y = 0, my - 1 do
			for x = 0, mx - 1 do
				local baseZIndex = (mz - z) * 2 + 10
				local position = UDim2.new(0, x * CELL + z * 5, 0, y * CELL + z * 5)
				table.insert(cells, cellAt(x, y, z, transparency, y * mx + x, baseZIndex, position))
			end
		end
	end

	return Theme.Frame {
		Size = UDim2.new(0, mx * CELL + math.max(0, mz - 1) * 5, 0, my * CELL + math.max(0, mz - 1) * 5),
		BackgroundTransparency = 1,
		unpack(cells)
	}
end

-- RuleViz: input -> output grids

type RuleVizProps = {
	Grid: GridMod.Grid,
	Rule: RuleMod.Rule,
	Active: boolean,
	LayoutOrder: number,
	Extra: { any }?,
}

local function RuleViz(props: RuleVizProps)
	local rule = props.Rule
	local grid = props.Grid

	local inputGrid = buildGrid(rule.IMX, rule.IMY, rule.IMZ, function(x, y, z, transparency, order, zIndex, position)
		local i = x + y * rule.IMX + z * rule.IMX * rule.IMY + 1
		return UnionCell({
			Grid = grid,
			Value = rule.Input[i],
			Transparency = transparency,
			LayoutOrder = order,
			ZIndex = zIndex,
			Position = position,
		})
	end)

	local outputGrid = buildGrid(rule.OMX, rule.OMY, rule.OMZ, function(x, y, z, transparency, order, zIndex, position)
		local i = x + y * rule.OMX + z * rule.OMX * rule.OMY
		return Cell({
			Grid = grid,
			Value = buffer.readu8(rule.Output, i),
			Transparency = transparency,
			LayoutOrder = order,
			ZIndex = zIndex,
			Position = position,
		})
	end)

	local children: { any } = {
		vide.create("UIListLayout") {
			FillDirection = Enum.FillDirection.Horizontal,
			SortOrder = Enum.SortOrder.LayoutOrder,
			VerticalAlignment = Enum.VerticalAlignment.Center,
		},
		Theme.Frame { Size = UDim2.new(0, rule.IMX * CELL + math.max(0, rule.IMZ - 1) * 5, 0, rule.IMY * CELL + math.max(0, rule.IMZ - 1) * 5), BackgroundTransparency = 1, LayoutOrder = 1, inputGrid },
		Theme.TextLabel { Text = if props.Active then "=>" else "->", Size = UDim2.new(0, 24, 1, 0), LayoutOrder = 2, BackgroundTransparency = 1, },
		Theme.Frame { Size = UDim2.new(0, rule.OMX * CELL + math.max(0, rule.OMZ - 1) * 5, 0, rule.OMY * CELL + math.max(0, rule.OMZ - 1) * 5), BackgroundTransparency = 1, LayoutOrder = 3, outputGrid },
	}

	if props.Extra then
		table.insert(children, Theme.Frame {
			Size = UDim2.new(0, 140, 1, 0),
			BackgroundTransparency = 1,
			LayoutOrder = 4,
			unpack(props.Extra)
		})
	end

	return Theme.Frame {
		Size = UDim2.new(1, 0, 0, math.max(rule.IMY * CELL + math.max(0, rule.IMZ - 1) * 5, rule.OMY * CELL + math.max(0, rule.OMZ - 1) * 5, 16) + 4),
		BackgroundTransparency = 1,
		LayoutOrder = props.LayoutOrder,
		unpack(children)
	}
end

-- FieldViz / ObserveViz

local function positionsRow(grid: GridMod.Grid, values: { number }, label: string, layoutOrder: number)
	local cells: { any } = {
		vide.create("UIListLayout") { FillDirection = Enum.FillDirection.Horizontal, SortOrder = Enum.SortOrder.LayoutOrder },
	}
	for i, v in values do
		table.insert(cells, Cell({ Grid = grid, Value = v, LayoutOrder = i }))
	end
	return Theme.Frame {
		Size = UDim2.new(1, 0, 0, CELL + 2),
		BackgroundTransparency = 1,
		LayoutOrder = layoutOrder,
		vide.create("UIListLayout") { FillDirection = Enum.FillDirection.Horizontal, SortOrder = Enum.SortOrder.LayoutOrder },
		Theme.TextLabel { Text = label, Size = UDim2.new(0, 60, 1, 0), LayoutOrder = 0 },
		Theme.Frame { Size = UDim2.new(1, -60, 1, 0), Position = UDim2.new(0, 60, 0, 0), BackgroundTransparency = 1, unpack(cells) },
	}
end

local function FieldViz(props: { Grid: GridMod.Grid, C: number, Field: FieldMod.Field, LayoutOrder: number })
	local grid, field = props.Grid, props.Field
	return Theme.Frame {
		Size = UDim2.new(1, 0, 0, 90),
		BackgroundTransparency = 1,
		LayoutOrder = props.LayoutOrder,
		vide.create("UIListLayout") { SortOrder = Enum.SortOrder.LayoutOrder },
		positionsRow(grid, { props.C }, "field", 0),
		positionsRow(grid, Helper.NonZeroPositions(field.Zero), if field.Inversed then "from" else "to", 1),
		positionsRow(grid, Helper.NonZeroPositions(field.Substrate), "on", 2),
		Theme.TextLabel { Text = `Recompute: {tostring(field.Recompute)}`, Size = UDim2.new(1, 0, 0, 16), LayoutOrder = 3 },
		Theme.TextLabel { Text = `Essential: {tostring(field.Essential)}`, Size = UDim2.new(1, 0, 0, 16), LayoutOrder = 4 },
	}
end

local function ObserveViz(props: { Grid: GridMod.Grid, C: number, Obs: ObservationMod.Observation, LayoutOrder: number })
	local grid, obs = props.Grid, props.Obs
	return Theme.Frame {
		Size = UDim2.new(1, 0, 0, 66),
		BackgroundTransparency = 1,
		LayoutOrder = props.LayoutOrder,
		vide.create("UIListLayout") { SortOrder = Enum.SortOrder.LayoutOrder },
		positionsRow(grid, { props.C }, "observe", 0),
		positionsRow(grid, { obs.From }, "from", 1),
		positionsRow(grid, Helper.NonZeroPositions(obs.To), "to", 2),
	}
end

-- PathViz

local function PathViz(props: { Grid: GridMod.Grid, Data: PathMod.PathData })
	local grid, data = props.Grid, props.Data
	return Theme.Frame {
		Size = UDim2.new(1, 0, 0, 4 * (CELL + 4)),
		BackgroundTransparency = 1,
		vide.create("UIListLayout") { SortOrder = Enum.SortOrder.LayoutOrder },
		positionsRow(grid, Helper.NonZeroPositions(data.Start), "from", 0),
		positionsRow(grid, Helper.NonZeroPositions(data.Finish), "to", 1),
		positionsRow(grid, Helper.NonZeroPositions(data.Substrate), "on", 2),
		positionsRow(grid, { data.Value }, "colored", 3),
	}
end

-- ConvoRuleViz / Convolution node

local function sumsLabel(sums: { boolean }?): string
	if not sums then
		return ""
	end
	local parts: { string } = {}
	for i = 1, #sums do
		if sums[i] then
			table.insert(parts, tostring(i - 1))
		end
	end
	return table.concat(parts, ",")
end

local function ConvoRuleViz(props: { Grid: GridMod.Grid, Rule: ConvolutionMod.ConvRule, LayoutOrder: number })
	local grid, rule = props.Grid, props.Rule
	local children: { any } = {
		vide.create("UIListLayout") { FillDirection = Enum.FillDirection.Horizontal, SortOrder = Enum.SortOrder.LayoutOrder, VerticalAlignment = Enum.VerticalAlignment.Center },
		Theme.Frame { Size = UDim2.new(0, CELL, 0, CELL), BackgroundTransparency = 1, LayoutOrder = 0, Cell({ Grid = grid, Value = rule.Input }) },
		Theme.TextLabel { Text = "->", Size = UDim2.new(0, 20, 0, CELL), LayoutOrder = 1 },
		Theme.Frame { Size = UDim2.new(0, CELL, 0, CELL), BackgroundTransparency = 1, LayoutOrder = 2, Cell({ Grid = grid, Value = rule.Output }) },
	}
	if rule.Values then
		local valueCells: { any } = { vide.create("UIListLayout") { FillDirection = Enum.FillDirection.Horizontal, SortOrder = Enum.SortOrder.LayoutOrder } }
		for i, v in rule.Values :: { number } do
			table.insert(valueCells, Cell({ Grid = grid, Value = v, LayoutOrder = i }))
		end
		table.insert(children, Theme.Frame { Size = UDim2.new(0, 120, 0, CELL), BackgroundTransparency = 1, LayoutOrder = 3, unpack(valueCells) })
	end
	if rule.Sums then
		table.insert(children, Theme.TextLabel { Text = `sums: {sumsLabel(rule.Sums)}`, Size = UDim2.new(0, 160, 0, CELL), LayoutOrder = 4 })
	end
	if rule.P < 1 then
		table.insert(children, Theme.TextLabel { Text = `p = {rule.P}`, Size = UDim2.new(0, 80, 0, CELL), LayoutOrder = 5 })
	end
	return Theme.Frame {
		Size = UDim2.new(1, 0, 0, CELL + 4),
		BackgroundTransparency = 1,
		LayoutOrder = props.LayoutOrder,
		unpack(children)
	}
end

-- Node dispatch

local function getRuleNodeData(node: NodeMod.Node): RuleNodeMod.RuleNodeData
	if node.Kind == "Parallel" then
		return (node.Data :: ParallelMod.ParallelData).Base
	end
	return node.Data :: RuleNodeMod.RuleNodeData
end

local function RuleNodeBody(props: { Grid: GridMod.Grid, Node: NodeMod.Node })
	local node = props.Node
	local isMap = node.Kind == "Map"
	local data: RuleNodeMod.RuleNodeData? = nil
	local rules: { RuleMod.Rule }

	if isMap then
		local mapData = node.Data :: MapMod.MapData
		rules = mapData.Rules
	else
		local ruleData = getRuleNodeData(node)
		data = ruleData
		rules = ruleData.Rules
	end

	local ruleRows: { any } = {
		vide.create("UIListLayout") { SortOrder = Enum.SortOrder.LayoutOrder },
	}
	local order = 0
	for i, rule in rules do
		if rule.Original then
			order += 1
			local extra: { any }? = nil
			if rule.P < 1 then
				extra = { Theme.TextLabel { Text = `p = {string.format("%.4f", rule.P)}`, Size = UDim2.new(1, 0, 0, 14) } }
			end
			local active = data ~= nil and data.Last[i] == true
			table.insert(ruleRows, RuleViz({
				Grid = props.Grid,
				Rule = rule,
				Active = active,
				LayoutOrder = order,
				Extra = extra,
			}))
		end
	end

	local sections: { any } = {
		vide.create("UIListLayout") { SortOrder = Enum.SortOrder.LayoutOrder },
		Theme.Frame { Size = UDim2.new(0, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.XY, BackgroundTransparency = 1, LayoutOrder = 0, unpack(ruleRows) },
	}

	if not isMap and data then
		local infoParts = {}
		if data.Steps > 0 then
			table.insert(infoParts, `{data.Counter}/{data.Steps}`)
		end
		if data.Temperature > 0 then
			table.insert(infoParts, `temperature: {data.Temperature}`)
		end
		if data.SearchEnabled then
			table.insert(infoParts, "search enabled")
		end
		if #infoParts > 0 then
			table.insert(sections, Theme.TextLabel { Text = table.concat(infoParts, "  "), Size = UDim2.new(1, 0, 0, 16), LayoutOrder = 1 })
		end

		if data.Fields then
			local fieldRows: { any } = { vide.create("UIListLayout") { SortOrder = Enum.SortOrder.LayoutOrder } }
			for c, field in data.Fields :: { FieldMod.Field? } do
				if field then
					table.insert(fieldRows, FieldViz({ Grid = props.Grid, C = c - 1, Field = field, LayoutOrder = c }))
				end
			end
			table.insert(sections, Theme.Frame { Size = UDim2.new(1, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y, BackgroundTransparency = 1, LayoutOrder = 2, unpack(fieldRows) })
		end

		if data.Observations then
			local obsRows: { any } = { vide.create("UIListLayout") { SortOrder = Enum.SortOrder.LayoutOrder } }
			for c, obs in data.Observations :: { ObservationMod.Observation? } do
				if obs then
					table.insert(obsRows, ObserveViz({ Grid = props.Grid, C = c - 1, Obs = obs, LayoutOrder = c }))
				end
			end
			table.insert(sections, Theme.Frame { Size = UDim2.new(1, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y, BackgroundTransparency = 1, LayoutOrder = 3, unpack(obsRows) })
		end
	end

	return Theme.Frame {
		Size = UDim2.new(0, 0, 0, 0),
		AutomaticSize = Enum.AutomaticSize.XY,
		BackgroundTransparency = 1,
		unpack(sections)
	}
end

local function ConvolutionBody(props: { Grid: GridMod.Grid, Node: NodeMod.Node })
	local data = props.Node.Data :: ConvolutionMod.ConvolutionData
	local rows: { any } = { vide.create("UIListLayout") { SortOrder = Enum.SortOrder.LayoutOrder } }
	if data.Steps > 0 then
		table.insert(rows, Theme.TextLabel { Text = `{data.Counter}/{data.Steps}`, Size = UDim2.new(1, 0, 0, 16), LayoutOrder = 0 })
	end
	for i, rule in data.Rules do
		table.insert(rows, ConvoRuleViz({ Grid = props.Grid, Rule = rule, LayoutOrder = i }))
	end
	return Theme.Frame { Size = UDim2.new(0, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.XY, BackgroundTransparency = 1, unpack(rows) }
end

local function ConvChainBody(props: { Node: NodeMod.Node })
	local data = props.Node.Data :: ConvChainMod.ConvChainData
	local text = `c0/c1: {data.C0}/{data.C1}`
	if data.Steps > 0 then
		text ..= `  {data.Counter}/{data.Steps}`
	end
	return Theme.TextLabel { Text = text, Size = UDim2.new(1, 0, 0, 16) }
end

local function PathBody(props: { Grid: GridMod.Grid, Node: NodeMod.Node })
	return PathViz({ Grid = props.Grid, Data = props.Node.Data :: PathMod.PathData })
end

local function NodeBody(props: { Grid: GridMod.Grid, Node: NodeMod.Node })
	local kind = props.Node.Kind
	if kind == "One" or kind == "All" or kind == "Parallel" or kind == "Map" then
		return RuleNodeBody({ Grid = props.Grid, Node = props.Node })
	elseif kind == "Convolution" then
		return ConvolutionBody({ Grid = props.Grid, Node = props.Node })
	elseif kind == "ConvChain" then
		return ConvChainBody({ Node = props.Node })
	elseif kind == "Path" then
		return PathBody({ Grid = props.Grid, Node = props.Node })
	end
	return nil
end

-- Palette

local function Palette()
	local hexBoxRef = vide.source(nil :: TextBox?)

	return Theme.Frame {
		Name = "Palette",
		Size = UDim2.new(1, 0, 0, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		BackgroundTransparency = 1,
		
		vide.create("UIListLayout") { SortOrder = Enum.SortOrder.LayoutOrder },
		Theme.TextLabel { Text = "Palette", Size = UDim2.new(1, 0, 0, 20), LayoutOrder = 0 },
		Theme.Frame {
			Size = UDim2.new(1, 0, 0, 0),
			AutomaticSize = Enum.AutomaticSize.Y,
			BackgroundTransparency = 1,
			LayoutOrder = 1,
			vide.create("UIGridLayout") { CellSize = UDim2.new(0, 40, 0, 46), SortOrder = Enum.SortOrder.LayoutOrder },
			
			function()
				Hooks.useStoreVersion()
				local ip = Store.Ip
				local rows = {}
				if ip then
					for i, symbol in ip.Grid.Characters do
						local color = Store.GetPaletteColor(symbol)
						table.insert(rows, Theme.Frame {
							Size = UDim2.new(0, 40, 0, 46),
							LayoutOrder = i,
							BackgroundTransparency = 1,
							
							Theme.TextButton {
								Text = symbol,
								Size = UDim2.new(0, 36, 0, 36),
								BackgroundColor3 = color,
								Activated = function()
									Store.SelectSymbol(symbol)
								end,
							},
							Theme.TextLabel {
								Text = symbol,
								Size = UDim2.new(1, 0, 0, 10),
								Position = UDim2.new(0, 0, 0, 36),
							},
						})
					end
				end
				return rows
			end
		},
		Theme.Frame {
			Size = UDim2.new(1, 0, 0, 32),
			BackgroundTransparency = 1,
			LayoutOrder = 2,
			
			vide.create("UIListLayout") { FillDirection = Enum.FillDirection.Horizontal, SortOrder = Enum.SortOrder.LayoutOrder },
			Theme.TextLabel { 
				Text = function() Hooks.useStoreVersion() return Store.SelectedSymbol or "" end, 
				Size = UDim2.new(0, 30, 1, 0), LayoutOrder = 0 
			},
			Theme.TextBox {
				PlaceholderText = "RRGGBB",
				Text = function()
					Hooks.useStoreVersion()
					return if Store.SelectedSymbol then Store.ColorToHex(Store.GetPaletteColor(Store.SelectedSymbol)) else ""
				end,
				Size = UDim2.new(0, 110, 1, 0),
				LayoutOrder = 1,
				vide.action(function(v) hexBoxRef(v) end),
				FocusLost = function(rbx: TextBox, enterPressed: boolean)
					if enterPressed then
						Store.ApplyPaletteEdit(rbx.Text)
					end
				end,
			},
			Theme.TextButton {
				Text = "Apply",
				Size = UDim2.new(0, 70, 1, 0),
				LayoutOrder = 2,
				Activated = function()
					local box = hexBoxRef()
					if box then
						Store.ApplyPaletteEdit(box.Text)
					end
				end,
			},
		}
	}
end

-- StateTree

local function StateTree()
	return Theme.ScrollingFrame {
		Size = UDim2.new(1, 0, 1, 0),
		CanvasSize = UDim2.new(0, 0, 0, 0),
		AutomaticCanvasSize = Enum.AutomaticSize.Y,
		BackgroundTransparency = 1,
		
		vide.create("UIListLayout") { SortOrder = Enum.SortOrder.LayoutOrder },
		
		function()
			Hooks.useStoreVersion()
			local ip = Store.Ip
			if not ip then return {} end

			local grid = ip.Grid
			local rows = {}

			for i, info in Store.Nodes do
				local node = info.Node

				if node.Kind == "Marker" then
					table.insert(rows, Theme.Frame {
						Size = UDim2.new(1, 0, 0, 32),
						BackgroundTransparency = 1,
						LayoutOrder = i,
						
						vide.create("UIPadding") {
							PaddingLeft = UDim.new(0, info.Depth * 24),
							PaddingRight = UDim.new(0, 24),
						},
						Theme.Frame {
							Size = UDim2.new(1, 0, 0, 1),
							Position = UDim2.new(0, 0, 0.5, 0),
							BackgroundColor3 = Color3.fromRGB(80, 80, 80),
							ZIndex = 1,
						},
						Theme.TextLabel {
							Text = (node.Data :: any).Name or "Marker",
							TextColor3 = Color3.fromRGB(150, 150, 150),
							BackgroundColor3 = Theme.Colors.Panel,
							BackgroundTransparency = 0,
							Size = UDim2.new(0, 0, 1, 0),
							Position = UDim2.new(0, 24, 0, 0),
							AutomaticSize = Enum.AutomaticSize.X,
							ZIndex = 2,
							vide.create("UIPadding") {
								PaddingLeft = UDim.new(0, 8),
								PaddingRight = UDim.new(0, 8),
							}
						}
					})
					continue
				end

				local body = NodeBody({ Grid = grid, Node = node })
				local rowChildren: { any } = {
					vide.create("UIListLayout") { 
						SortOrder = Enum.SortOrder.LayoutOrder,
						FillDirection = Enum.FillDirection.Horizontal,
						Padding = UDim.new(0, 8)
					},
					vide.create("UIPadding") {
						PaddingLeft = UDim.new(0, info.Depth * 24)
					},
					Theme.TextLabel {
						Text = if i == Store.CurrentNodeIndex then `> {State.Name(node)}` else State.Name(node),
						Size = UDim2.new(0, 0, 0, 18),
						AutomaticSize = Enum.AutomaticSize.X,
						LayoutOrder = 0,
					},
				}
				if body then
					table.insert(rowChildren, Theme.Frame { Size = UDim2.new(0, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.XY, BackgroundTransparency = 1, LayoutOrder = 1, body })
				end

				table.insert(rows, Theme.Frame {
					Size = UDim2.new(1, 0, 0, 0),
					AutomaticSize = Enum.AutomaticSize.Y,
					BackgroundTransparency = 1,
					LayoutOrder = i,
					unpack(rowChildren)
				})
			end

			return rows
		end
	}
end

-- Panel

local function Right(_props: {})
	local paletteHeight = vide.source(150)

	return Theme.Frame {
		Name = "RightPanel",
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, 0, 0, 0),
		Size = UDim2.new(0, 260, 1, 0),
		
		Theme.Frame {
			Name = "PaletteSection",
			Size = UDim2.new(1, 0, 0, 0),
			AutomaticSize = Enum.AutomaticSize.Y,
			BackgroundTransparency = 1,
			vide.action(function(rbx: Frame)
				local connection = rbx:GetPropertyChangedSignal("AbsoluteSize"):Connect(function()
					paletteHeight(rbx.AbsoluteSize.Y)
				end)
				vide.cleanup(connection)
			end),
			Palette(),
		},
		Theme.Frame {
			Name = "Content",
			Size = function() return UDim2.new(1, 0, 1, -paletteHeight() - 10) end,
			Position = function() return UDim2.new(0, 0, 0, paletteHeight() + 10) end,
			BackgroundTransparency = 1,
			StateTree(),
		},
	}
end

return Right
