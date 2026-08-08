--!strict
-- port of MarkovJuniorWeb's src/web/center.tsx
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local vide = require(ReplicatedStorage.Packages.vide)
local Store = require(script.Parent.Parent.Store)
local Hooks = require(script.Parent.Parent.Hooks)
local Theme = require(script.Parent.Parent.Theme)

local function Center(_props: {})
	return Theme.Frame {
		Name = "CenterPanel",
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, -20, 0, 0),
		Size = UDim2.new(1, -480, 0, 116),
		
		Theme.TextLabel {
			Name = "ModelNameLabel",
			Text = function()
				Hooks.useStoreVersion()
				local entry = Store.CurrentEntry
				return if entry then entry.Name else ""
			end,
			Size = UDim2.new(1, 0, 0, 24),
			Position = UDim2.new(0, 0, 0, 0),
		},
		Theme.TextLabel {
			Name = "InfoLabel",
			Text = function()
				Hooks.useStoreVersion()
				local entry = Store.CurrentEntry
				local sizeText = ""
				if entry then
					sizeText = if entry.MZ > 1 then `{entry.MX}x{entry.MY}x{entry.MZ}` else `{entry.MX}x{entry.MY}`
				end
				return if entry then `size: {sizeText}  seed: {Store.Seed}` else ""
			end,
			Size = UDim2.new(1, 0, 0, 20),
			Position = UDim2.new(0, 0, 0, 24),
		},
		Theme.Frame {
			Name = "SeedRow",
			Size = UDim2.new(1, 0, 0, 28),
			Position = UDim2.new(0, 0, 0, 48),
			BackgroundTransparency = 1,
			
			Theme.TextLabel {
				Name = "SeedTextLabel",
				Text = "Seed:",
				Size = UDim2.new(0, 50, 1, 0),
				Position = UDim2.new(0, 0, 0, 0),
			},
			Theme.TextBox {
				Name = "SeedBox",
				Text = function()
					Hooks.useStoreVersion()
					return tostring(Store.Seed)
				end,
				Size = UDim2.new(0, 150, 1, 0),
				Position = UDim2.new(0, 50, 0, 0),
				FocusLost = function(rbx: TextBox)
					local n = tonumber(rbx.Text)
					if n then
						Store.SetSeed(n)
					else
						rbx.Text = tostring(Store.Seed)
					end
				end,
			},
			Theme.TextButton {
				Name = "RandomizeButton",
				Text = "Randomize",
				Size = UDim2.new(0, 110, 1, 0),
				Position = UDim2.new(0, 210, 0, 0),
				Activated = function()
					Store.Randomize()
				end,
			},
		},
		Theme.Frame {
			Name = "ButtonsRow",
			Size = UDim2.new(1, 0, 0, 32),
			Position = UDim2.new(0, 0, 0, 82),
			BackgroundTransparency = 1,
			
			Theme.TextButton {
				Name = "GenerateButton",
				Text = "Generate",
				Size = UDim2.new(0, 90, 1, 0),
				Position = UDim2.new(0, 0, 0, 0),
				Activated = function()
					Store.Generate()
				end,
			},
			Theme.TextButton {
				Name = "PrevButton",
				Text = "Prev",
				Size = UDim2.new(0, 60, 1, 0),
				Position = UDim2.new(0, 100, 0, 0),
				Activated = function()
					Store.PrevSnapshot()
				end,
			},
			Theme.TextButton {
				Name = "NextButton",
				Text = "Next",
				Size = UDim2.new(0, 60, 1, 0),
				Position = UDim2.new(0, 170, 0, 0),
				Activated = function()
					Store.NextSnapshot()
				end,
			},
			Theme.TextLabel {
				Name = "SnapshotLabel",
				Text = function()
					Hooks.useStoreVersion()
					if #Store.Snapshots > 0 then
						local current = Store.Snapshots[Store.CurrentSnapshotIndex]
						if current then
							return `{Store.CurrentSnapshotIndex}/{#Store.Snapshots}: {current.Name}`
						else
							return `{Store.CurrentSnapshotIndex}/{#Store.Snapshots}: (invalid index)`
						end
					end
					return ""
				end,
				Size = UDim2.new(0, 200, 1, 0),
				Position = UDim2.new(0, 240, 0, 0),
				TextXAlignment = Enum.TextXAlignment.Left,
			},
		},
	}
end

return Center
