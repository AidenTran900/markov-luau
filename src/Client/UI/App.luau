--!strict
-- port of MarkovJuniorWeb's src/web/index.tsx
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local vide = require(ReplicatedStorage.Packages.vide)
local Store = require(script.Parent.Store)
local Left = require(script.Parent.Components.Left)
local Center = require(script.Parent.Components.Center)
local Right = require(script.Parent.Components.Right)

local function App(_props: {})
	local viewportRef = vide.source(nil :: ViewportFrame?)
	local cameraRef = vide.source(nil :: Camera?)
	local worldRef = vide.source(nil :: WorldModel?)
	
	local cameraAngles = Vector2.new(math.rad(-45), math.rad(45))
	local cameraDistance = -1
	local cameraTarget = Vector3.zero
	local draggingType = nil :: Enum.UserInputType?
	local lastMousePos = Vector2.zero
	local cameraInitialized = false
	
	vide.effect(function()
		local connBegan = UserInputService.InputBegan:Connect(function(input, gameProcessed)
			if gameProcessed then return end
			if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.MouseButton2 or input.UserInputType == Enum.UserInputType.MouseButton3 then
				draggingType = input.UserInputType
				lastMousePos = Vector2.new(input.Position.X, input.Position.Y)
			end
		end)
		
		local connEnded = UserInputService.InputEnded:Connect(function(input)
			if input.UserInputType == draggingType then
				draggingType = nil
			end
		end)
		
		local connChanged = UserInputService.InputChanged:Connect(function(input)
			if draggingType and input.UserInputType == Enum.UserInputType.MouseMovement then
				local currentPos = Vector2.new(input.Position.X, input.Position.Y)
				local delta = currentPos - lastMousePos
				lastMousePos = currentPos
				
				if draggingType == Enum.UserInputType.MouseButton3 then
					-- Pan
					local cam = cameraRef()
					if cam then
						local right = cam.CFrame.RightVector
						local up = cam.CFrame.UpVector
						local panSpeed = math.max(10, cameraDistance) * 0.002
						cameraTarget = cameraTarget - (right * delta.X * panSpeed) + (up * delta.Y * panSpeed)
					end
				else
					-- Rotate
					local angles = cameraAngles
					cameraAngles = Vector2.new(
						math.clamp(angles.X - delta.Y * 0.005, -math.rad(89), math.rad(89)),
						angles.Y - delta.X * 0.005
					)
				end
			elseif input.UserInputType == Enum.UserInputType.MouseWheel then
				local dist = cameraDistance
				if dist < 0 then dist = 50 end
				cameraDistance = math.clamp(dist - input.Position.Z * (dist * 0.1), 1, 1000)
			end
		end)
		
		vide.cleanup(function()
			connBegan:Disconnect()
			connEnded:Disconnect()
			connChanged:Disconnect()
		end)
	end)
	
	vide.effect(function()
		local vp = viewportRef()
		local cam = cameraRef()
		local world = worldRef()
		if vp and cam and world then
			Store.ViewportFrame = world
			
			if Store.Ip then
				task.spawn(function()
					Store.RebuildMesh()
				end)
			end
			
			local conn = RunService.RenderStepped:Connect(function()
				vp.CurrentCamera = cam
				
				local min = Vector3.new(math.huge, math.huge, math.huge)
				local max = Vector3.new(-math.huge, -math.huge, -math.huge)
				local found = false
				for _, child in vp:GetDescendants() do
					if child:IsA("BasePart") then
						found = true
						min = min:Min(child.Position - child.Size / 2)
						max = max:Max(child.Position + child.Size / 2)
					end
				end
				
				if found then
					local extents = max - min
					
					if not cameraInitialized then
						cameraInitialized = true
						cameraDistance = extents.Magnitude * 0.8 + 5
					end
					
					local angles = cameraAngles
					local dist = cameraDistance
					local target = cameraTarget
					
					local rotation = CFrame.Angles(0, angles.Y, 0) * CFrame.Angles(angles.X, 0, 0)
					local position = target + rotation * Vector3.new(0, 0, dist)
					
					cam.CFrame = CFrame.lookAt(position, target)
				end
			end)
			
			vide.cleanup(function()
				conn:Disconnect()
				if Store.ViewportFrame == world then
					Store.ViewportFrame = nil
				end
			end)
		end
	end)

	return vide.create("Frame") {
		BorderSizePixel = 0,
		BackgroundColor3 = Color3.fromRGB(15, 15, 15),
		Name = "MarkovJuniorApp",
		Size = UDim2.new(1, 0, 1, 0),
		BackgroundTransparency = 1,
		
		vide.create("ViewportFrame") {
			Name = "Viewport",
			BorderSizePixel = 0,
			BackgroundColor3 = Color3.fromRGB(15, 15, 15),
			Size = UDim2.new(1, 0, 1, 0),
			BackgroundTransparency = 0,
			Ambient = Color3.fromRGB(180, 180, 180),
			LightColor = Color3.fromRGB(255, 255, 255),
			LightDirection = Vector3.new(-1, -1, -1),
			ZIndex = 0,
			
			vide.action(function(v) viewportRef(v) end),
			
			vide.create("Camera") {
				Name = "Camera",
				CameraType = Enum.CameraType.Scriptable,
				vide.action(function(v) cameraRef(v) end),
			},
			vide.create("WorldModel") {
				Name = "World",
				vide.action(function(v) worldRef(v) end),
			}
		},
		Left({ Name = "Left" }),
		Center({ Name = "Center" }),
		Right({ Name = "Right" }),
	}
end

return App
