--!strict
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local vide = require(ReplicatedStorage.Packages.vide)

local Theme = {}

Theme.Colors = {
	Background = Color3.fromRGB(15, 15, 15),
	Panel = Color3.fromRGB(20, 20, 20),
	Element = Color3.fromRGB(30, 30, 30),
	Input = Color3.fromRGB(35, 35, 35),
	Button = Color3.fromRGB(40, 40, 40),
	Text = Color3.fromRGB(240, 240, 240),
	TextPlaceholder = Color3.fromRGB(180, 180, 180),
	Border = Color3.fromRGB(0, 0, 0),
}

function Theme.Frame(props: { [any]: any })
	if props.BorderSizePixel == nil then props.BorderSizePixel = 0 end
	if props.BackgroundTransparency == nil and props.BackgroundColor3 == nil then
		props.BackgroundColor3 = Theme.Colors.Panel
	end
	return vide.create("Frame")(props)
end

function Theme.TextLabel(props: { [any]: any })
	if props.BorderSizePixel == nil then props.BorderSizePixel = 0 end
	if props.BackgroundTransparency == nil and props.BackgroundColor3 == nil then
		props.BackgroundColor3 = Theme.Colors.Element
	end
	if props.TextColor3 == nil then props.TextColor3 = Theme.Colors.Text end
	if props.TextSize == nil then props.TextSize = 16 end
	return vide.create("TextLabel")(props)
end

function Theme.TextBox(props: { [any]: any })
	if props.BorderSizePixel == nil then props.BorderSizePixel = 0 end
	if props.BackgroundTransparency == nil and props.BackgroundColor3 == nil then
		props.BackgroundColor3 = Theme.Colors.Input
	end
	if props.TextColor3 == nil then props.TextColor3 = Theme.Colors.Text end
	if props.PlaceholderColor3 == nil then props.PlaceholderColor3 = Theme.Colors.TextPlaceholder end
	if props.TextSize == nil then props.TextSize = 16 end
	return vide.create("TextBox")(props)
end

function Theme.TextButton(props: { [any]: any })
	if props.BorderSizePixel == nil then props.BorderSizePixel = 0 end
	if props.BackgroundTransparency == nil and props.BackgroundColor3 == nil then
		props.BackgroundColor3 = Theme.Colors.Button
	end
	if props.TextColor3 == nil then props.TextColor3 = Theme.Colors.Text end
	if props.AutoButtonColor == nil then props.AutoButtonColor = true end
	if props.TextSize == nil then props.TextSize = 16 end
	return vide.create("TextButton")(props)
end

function Theme.ScrollingFrame(props: { [any]: any })
	if props.BorderSizePixel == nil then props.BorderSizePixel = 0 end
	if props.BackgroundTransparency == nil and props.BackgroundColor3 == nil then
		props.BackgroundColor3 = Theme.Colors.Panel
	end
	if props.ScrollBarImageColor3 == nil then props.ScrollBarImageColor3 = Theme.Colors.TextPlaceholder end
	return vide.create("ScrollingFrame")(props)
end

return Theme
