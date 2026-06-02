-- Complete Lag-Free Input-Based Master Script for Hoopz

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local VirtualInputManager = game:GetService("VirtualInputManager")
local LocalPlayer = Players.LocalPlayer
local Camera = workspace.CurrentCamera

--// Settings & States
local uiVisible = true
local uiToggleKey = Enum.KeyCode.RightControl

local autoShootActive = false
local powerDelay = 0.35 -- Adjust this (in seconds) to find your perfect green release point
local magnetActive = false
local magnetRange = 30
local customSpeed = 16

-- Cache variables to prevent lag
local cachedRims = {}
local lastCacheTime = 0

-- Function to cache rims safely without causing frame drops
local function refreshRimCache()
	local now = os.clock()
	if now - lastCacheTime < 5 and #cachedRims > 0 then return end
	lastCacheTime = now
	
	table.clear(cachedRims)
	for _, obj in ipairs(workspace:GetDescendants()) do
		if obj:IsA("BasePart") and (obj.Name == "Rim" or obj.Name == "Ring" or obj.Name == "GoalRim") then
			table.insert(cachedRims, obj)
		end
	end
end

-- Fast ball locator
local function findHoopzBall()
	local ball = workspace:FindFirstChild("Basketball") or workspace:FindFirstChild("Ball")
	if ball and ball:IsA("BasePart") then return ball end
	
	for _, player in ipairs(Players:GetPlayers()) do
		local char = player.Character
		if char then
			local b = char:FindFirstChild("Basketball") or char:FindFirstChild("Ball")
			if b and b:IsA("BasePart") then return b end
		end
	end
	return nil
end

-- Lag-free closest rim finder using the cache
local function findClosestRim(myPos)
	refreshRimCache()
	local closestRimPosition = Vector3.new(0, 16.5, 0)
	local shortestDistance = math.huge
	
	for i = 1, #cachedRims do
		local obj = cachedRims[i]
		if obj and obj.Parent then
			local dist = (myPos - obj.Position).Magnitude
			if dist < shortestDistance then
				shortestDistance = dist
				closestRimPosition = obj.Position
			end
		end
	end
	return closestRimPosition
end

-- Configuration Menu Assets
local ScreenGui = Instance.new("ScreenGui")
ScreenGui.Name = "HoopzSupremeGui"
ScreenGui.ResetOnSpawn = false
ScreenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
ScreenGui.Parent = LocalPlayer:WaitForChild("PlayerGui")

-- Main Frame
local MainFrame = Instance.new("Frame")
MainFrame.Name = "MainFrame"
MainFrame.Size = UDim2.new(0, 280, 0, 420)
MainFrame.Position = UDim2.new(0.05, 0, 0.15, 0)
MainFrame.BackgroundColor3 = Color3.fromRGB(20, 20, 25) 
MainFrame.BorderSizePixel = 0
MainFrame.Active = true
MainFrame.Draggable = true
MainFrame.ClipsDescendants = true
MainFrame.Parent = ScreenGui

local UICorner = Instance.new("UICorner")
UICorner.CornerRadius = UDim.new(0, 8)
UICorner.Parent = MainFrame

-- Title
local Title = Instance.new("TextLabel")
Title.Size = UDim2.new(1, 0, 0, 40)
Title.BackgroundTransparency = 1
Title.Text = "Hoopz Elite Console"
Title.TextColor3 = Color3.fromRGB(255, 90, 0) 
Title.TextSize = 16
Title.Font = Enum.Font.SourceSansBold
Title.Parent = MainFrame

-- Scrolling Frame for Settings
local Scroll = Instance.new("ScrollingFrame")
Scroll.Size = UDim2.new(1, -20, 1, -55)
Scroll.Position = UDim2.new(0, 10, 0, 45)
Scroll.BackgroundTransparency = 1
Scroll.CanvasSize = UDim2.new(0, 0, 0, 550)
Scroll.ScrollBarThickness = 4
Scroll.Parent = MainFrame

local UIListLayout = Instance.new("UIListLayout")
UIListLayout.SortOrder = Enum.SortOrder.LayoutOrder
UIListLayout.Padding = UDim.new(0, 12)
UIListLayout.Parent = Scroll

-- Expandable Dragger Handle
local DragHandle = Instance.new("TextButton")
DragHandle.Name = "DragHandle"
DragHandle.Size = UDim2.new(0, 15, 0, 15)
DragHandle.Position = UDim2.new(1, -15, 1, -15)
DragHandle.BackgroundColor3 = Color3.fromRGB(50, 50, 55)
DragHandle.Text = "///"
DragHandle.TextColor3 = Color3.fromRGB(150, 150, 150)
DragHandle.TextSize = 10
DragHandle.Font = Enum.Font.SourceSans
DragHandle.ZIndex = 5
DragHandle.Parent = MainFrame

local HandleCorner = Instance.new("UICorner")
HandleCorner.CornerRadius = UDim.new(0, 4)
HandleCorner.Parent = DragHandle

-- Component Helpers
local function createButton(name, text, order)
	local btn = Instance.new("TextButton")
	btn.Name = name
	btn.Size = UDim2.new(1, 0, 0, 32)
	btn.BackgroundColor3 = Color3.fromRGB(45, 45, 50)
	btn.TextColor3 = Color3.fromRGB(230, 230, 230)
	btn.TextSize = 14
	btn.Font = Enum.Font.SourceSans
	btn.Text = text
	btn.LayoutOrder = order
	btn.AutoButtonColor = true
	btn.Parent = Scroll
	
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 6)
	corner.Parent = btn
	return btn
end

local function createSlider(name, labelText, min, max, default, order, callback)
	local sliderFrame = Instance.new("Frame")
	sliderFrame.Name = name .. "Frame"
	sliderFrame.Size = UDim2.new(1, 0, 0, 45)
	sliderFrame.BackgroundTransparency = 1
	sliderFrame.LayoutOrder = order
	sliderFrame.Parent = Scroll

	local lbl = Instance.new("TextLabel")
	lbl.Size = UDim2.new(1, 0, 0, 20)
	lbl.BackgroundTransparency = 1
	lbl.Text = labelText .. ": " .. default
	lbl.TextColor3 = Color3.fromRGB(200, 200, 200)
	lbl.TextSize = 13
	lbl.Font = Enum.Font.SourceSans
	lbl.TextXAlignment = Enum.TextXAlignment.Left
	lbl.Parent = sliderFrame

	local bar = Instance.new("Frame")
	bar.Size = UDim2.new(1, 0, 0, 6)
	bar.Position = UDim2.new(0, 0, 0, 25)
	bar.BackgroundColor3 = Color3.fromRGB(60, 60, 65)
	bar.BorderSizePixel = 0
	bar.Parent = sliderFrame
	
	local barCorner = Instance.new("UICorner")
	barCorner.CornerRadius = UDim.new(1, 0)
	barCorner.Parent = bar

	local knob = Instance.new("TextButton")
	knob.Size = UDim2.new(0, 14, 0, 14)
	knob.AnchorPoint = Vector2.new(0.5, 0.5)
	local initialPercent = (default - min) / (max - min)
	knob.Position = UDim2.new(initialPercent, 0, 0.5, 0)
	knob.BackgroundColor3 = Color3.fromRGB(255, 110, 0)
	knob.Text = ""
	knob.Parent = bar

	local knobCorner = Instance.new("UICorner")
	knobCorner.CornerRadius = UDim.new(1, 0)
	knobCorner.Parent = knob

	local dragging = false
	knob.MouseButton1Down:Connect(function() dragging = true end)
	UserInputService.InputEnded:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseButton1 then dragging = false end
	end)

	UserInputService.InputChanged:Connect(function(input)
		if dragging and input.UserInputType == Enum.UserInputType.MouseMovement then
			local mouseX = input.Position.X
			local barAbsolutePos = bar.AbsolutePosition.X
			local barAbsoluteSize = bar.AbsoluteSize.X
			local percent = math.clamp((mouseX - barAbsolutePos) / barAbsoluteSize, 0, 1)
			
			knob.Position = UDim2.new(percent, 0, 0.5, 0)
			local value = min + (percent * (max - min))
			-- Handle decimal visualization specifically for power delays
			if min < 1 then
				value = math.floor(value * 100) / 100
			else
				value = math.floor(value)
			end
			lbl.Text = labelText .. ": " .. value
			callback(value)
		end
	end)
end

-- Render Control Toggles
local ShootBtn = createButton("ShootBtn", "Auto-Click Release on Jump: OFF", 1)
ShootBtn.BackgroundColor3 = Color3.fromRGB(60, 30, 30)

local MagBtn = createButton("MagBtn", "Steal Magnet (Mag): OFF", 2)
MagBtn.BackgroundColor3 = Color3.fromRGB(60, 30, 30)

-- Configure Sliders
createSlider("PowerSlider", "Shot Release Delay (Power)", 0.1, 1.0, powerDelay, 3, function(val)
	powerDelay = val
end)

createSlider("SpeedSlider", "Player Speed Boost", 16, 120, customSpeed, 4, function(val)
	customSpeed = val
end)

createSlider("MagRadiusSlider", "Intercept Distance (Mag)", 10, 120, magnetRange, 5, function(val)
	magnetRange = val
end)

--// UI Resizer Integration
local resizing = false
local startSize, startMousePos

DragHandle.MouseButton1Down:Connect(function()
	resizing = true
	startSize = MainFrame.Size
	startMousePos = UserInputService:GetMouseLocation()
	MainFrame.Draggable = false 
end)

UserInputService.InputEnded:Connect(function(input)
	if input.UserInputType == Enum.UserInputType.MouseButton1 then
		resizing = false
		MainFrame.Draggable = true
	end
end)

UserInputService.InputChanged:Connect(function(input)
	if resizing and input.UserInputType == Enum.UserInputType.MouseMovement then
		local currentMousePos = UserInputService:GetMouseLocation()
		local deltaX = currentMousePos.X - startMousePos.X
		local deltaY = currentMousePos.Y - startMousePos.Y
		
		local newWidth = math.max(220, startSize.X.Offset + deltaX)
		local newHeight = math.max(200, startSize.Y.Offset + deltaY)
		
		MainFrame.Size = UDim2.new(0, newWidth, 0, newHeight)
		DragHandle.Position = UDim2.new(1, -15, 1, -15)
	end
end)

--// Activation Input Listeners
ShootBtn.MouseButton1Click:Connect(function()
	autoShootActive = not autoShootActive
	ShootBtn.Text = autoShootActive and "Auto-Click Release on Jump: ON" or "Auto-Click Release on Jump: OFF"
	ShootBtn.BackgroundColor3 = autoShootActive and Color3.fromRGB(30, 60, 30) or Color3.fromRGB(60, 30, 30)
end)

MagBtn.MouseButton1Click:Connect(function()
	magnetActive = not magnetActive
	MagBtn.Text = magnetActive and "Steal Magnet (Mag): ON" or "Steal Magnet (Mag): OFF"
	MagBtn.BackgroundColor3 = magnetActive and Color3.fromRGB(30, 60, 30) or Color3.fromRGB(60, 30, 30)
end)

UserInputService.InputBegan:Connect(function(input, gameProcessed)
	if gameProcessed then return end
	if input.KeyCode == uiToggleKey then
		uiVisible = not uiVisible
		MainFrame.Visible = uiVisible
	end
end)

-- Initialize Cache immediately on run
refreshRimCache()

--// Input Timing Loop For Automated Jumps
task.spawn(function()
	while true do
		task.wait(0.05)
		local character = LocalPlayer.Character
		local humanoid = character and character:FindFirstChildOfClass("Humanoid")
		
		if humanoid and autoShootActive then
			local jumpConnection
			jumpConnection = humanoid.Jumping:Connect(function(isActive)
				if isActive and autoShootActive then
					local ball = findHoopzBall()
					if ball then
						-- Auto-Click Native Down Press
						VirtualInputManager:SendMouseButtonEvent(0, 0, 0, true, game, 0)
						
						-- Hold until the exact optimized timeline selection match
						task.wait(powerDelay)
						
						-- Auto-Click Native Release
						VirtualInputManager:SendMouseButtonEvent(0, 0, 0, false, game, 0)
					end
				end
				jumpConnection:Disconnect()
			end)
		end
	end
end)

--// Continuous Background Adjustments Loop (Lag-Free)
RunService.RenderStepped:Connect(function()
	local character = LocalPlayer.Character
	local hrp = character and character:FindFirstChild("HumanoidRootPart")
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	if not hrp or not humanoid then return end

	-- Handle custom walkspeed safely
	if humanoid.WalkSpeed ~= customSpeed then
		humanoid.WalkSpeed = customSpeed
	end

	-- Loose Intercept Magnet (Mag) Execution
	if magnetActive then
		local ball = findHoopzBall()
		if ball then
			local dist = (hrp.Position - ball.Position).Magnitude
			if dist <= magnetRange and ball.AssemblyLinearVelocity.Magnitude > 1 then
				local interceptPoint = hrp.Position + (hrp.CFrame.LookVector * 1.5)
				ball.AssemblyLinearVelocity = (interceptPoint - ball.Position).Unit * 45
			end
		end
	end
end)
