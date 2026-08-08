--!strict
-- port of MarkovJuniorWeb's src/web/left.tsx
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local vide = require(ReplicatedStorage.Packages.vide)

local Store = require(script.Parent.Parent.Store)
local Hooks = require(script.Parent.Parent.Hooks)
local Theme = require(script.Parent.Parent.Theme)

local function Left(_props: {})
	local search = vide.source("")

	return Theme.Frame {
		Name = "LeftPanel",
		AnchorPoint = Vector2.new(0, 0),
		Position = UDim2.new(0, 0, 0, 60),
		Size = UDim2.new(0, 220, 1, -60),
		
		Theme.TextLabel {
			Name = "Title",
			Text = "MarkovJunior",
			Size = UDim2.new(1, 0, 0, 32),
			Position = UDim2.new(0, 0, 0, 0),
		},
		Theme.TextBox {
			Name = "SearchBox",
			PlaceholderText = "Filter model by name",
			Text = search,
			Size = UDim2.new(1, 0, 0, 28),
			Position = UDim2.new(0, 0, 0, 32),
			vide.action(function(rbx: TextBox)
				local connection = rbx:GetPropertyChangedSignal("Text"):Connect(function()
					search(rbx.Text)
				end)
				vide.cleanup(connection)
			end),
		},
		Theme.ScrollingFrame {
			Name = "ModelList",
			Size = UDim2.new(1, 0, 1, -60),
			Position = UDim2.new(0, 0, 0, 60),
			CanvasSize = UDim2.new(0, 0, 0, 0),
			AutomaticCanvasSize = Enum.AutomaticSize.Y,
			
			vide.create("UIListLayout") {
				SortOrder = Enum.SortOrder.LayoutOrder,
			},
			
			function()
				Hooks.useStoreVersion()
				local currentName = Store.CurrentEntry and Store.CurrentEntry.Name

				local rows = {}
				local needle = string.lower(search())
				for i, entry in Store.Models do
					if needle == "" or string.find(string.lower(entry.Name), needle, 1, true) ~= nil then
						table.insert(rows, Theme.TextButton {
							Text = if entry.Name == currentName then `> {entry.Name}` else entry.Name,
							Size = UDim2.new(1, 0, 0, 30),
							LayoutOrder = i,
							Activated = function()
								Store.LoadModel(entry)
							end,
						})
					end
				end
				return rows
			end,
		},
	}
end

return Left
