-- Optimized, Lag-Free LocalScript for Hoopz

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local LocalPlayer = Players.LocalPlayer
local Camera = workspace.CurrentCamera

--// Settings & States
local uiVisible = true
local uiToggleKey = Enum.KeyCode.RightControl

local autoShootActive = false
local autoPowerActive = false
local camLockActive = false

local reachDistance = 15 
local magnetActive = false
local magnetRange = 30
local customSpeed = 16

-- Cache variables to prevent lag
local cachedRims = {}
local lastCacheTime = 0

-- Function to cache rims safely without causing frame drops
local function refreshRimCache()
	local now = os.clock()
	if now - lastCacheTime < 5 and #cachedRims > 0 then return end -- Only refresh every 5 seconds
	lastCacheTime = now
	
	table.clear(cachedRims)
	for _, obj in ipairs(workspace:GetDescendants()) do
		if obj:IsA("BasePart") and (obj.Name == "Rim" or obj.Name == "Ring" or obj.Name == "GoalRim") then
			table.insert(cachedRims, obj)
		end
	end
end

-- Fast ball locator (checks known spots first before scanning)
local function findHoopzBall()
	-- Check common loose ball names
	local ball = workspace:FindFirstChild("Basketball") or workspace:FindFirstChild("Ball")
	if ball and ball:IsA("BasePart") then return ball end
	
	-- Check players holding it
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
MainFrame.Size = UDim2.new(0, 280, 0, 480)
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
Title.Text = "Hoopz Lag-Free Console"
Title.TextColor3 = Color3.fromRGB(255, 90, 0) 
Title.TextSize = 16
Title.Font = Enum.Font.SourceSansBold
Title.Parent = MainFrame

-- Scrolling Frame for Settings
local Scroll = Instance.new("ScrollingFrame")
Scroll.Size = UDim2.new(1, -20, 1, -55)
Scroll.Position = UDim2.new(0, 10, 0, 45)
Scroll.BackgroundTransparency = 1
Scroll.CanvasSize = UDim2.new(0, 0, 0, 600)
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
			local value = math.floor(min + (percent * (max - min)))
			lbl.Text = labelText .. ": " .. value
			callback(value)
		end
	end)
end

-- Render Control Toggles
local ShootBtn = createButton("ShootBtn", "Auto-Green on Jump: OFF", 1)
ShootBtn.BackgroundColor3 = Color3.fromRGB(60, 30, 30)

local PowerBtn = createButton("PowerBtn", "Smart Dynamic Power: OFF", 2)
PowerBtn.BackgroundColor3 = Color3.fromRGB(60, 30, 30)

local CamBtn = createButton("CamBtn", "Perfect Spot Camlock: OFF", 3)
CamBtn.BackgroundColor3 = Color3.fromRGB(60, 30, 30)

local MagBtn = createButton("MagBtn", "Steal Magnet (Mag): OFF", 4)
MagBtn.BackgroundColor3 = Color3.fromRGB(60, 30, 30)

-- Configure Sliders
createSlider("SpeedSlider", "Player Speed Boost", 16, 120, customSpeed, 5, function(val)
	customSpeed = val
end)

createSlider("ReachSlider", "Reach Adjustment Range", 5, 60, reachDistance, 6, function(val)
	reachDistance = val
end)

createSlider("MagRadiusSlider", "Intercept Distance (Mag)", 10, 120, magnetRange, 7, function(val)
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
	ShootBtn.Text = autoShootActive and "Auto-Green on Jump: ON" or "Auto-Green on Jump: OFF"
	ShootBtn.BackgroundColor3 = autoShootActive and Color3.fromRGB(30, 60, 30) or Color3.fromRGB(60, 30, 30)
end)

PowerBtn.MouseButton1Click:Connect(function()
	autoPowerActive = not autoPowerActive
	PowerBtn.Text = autoPowerActive and "Smart Dynamic Power: ON" or "Smart Dynamic Power: OFF"
	PowerBtn.BackgroundColor3 = autoPowerActive and Color3.fromRGB(30, 60, 30) or Color3.fromRGB(60, 30, 30)
end)

CamBtn.MouseButton1Click:Connect(function()
	camLockActive = not camLockActive
	CamBtn.Text = camLockActive and "Perfect Spot Camlock: ON" or "Perfect Spot Camlock: OFF"
	CamBtn.BackgroundColor3 = camLockActive and Color3.fromRGB(30, 60, 30) or Color3.fromRGB(60, 30, 30)
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

--// Engine Physics Loop Runtime
RunService.RenderStepped:Connect(function()
	local character = LocalPlayer.Character
	local hrp = character and character:FindFirstChild("HumanoidRootPart")
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	if not hrp or not humanoid then return end

	-- Handle custom walkspeed safely
	if humanoid.WalkSpeed ~= customSpeed then
		humanoid.WalkSpeed = customSpeed
	end

	local ball = findHoopzBall()
	local rimPos = findClosestRim(hrp.Position)

	-- Calculate the absolute optimal swish entry point (slightly elevated center frame target)
	local perfectSpot = rimPos + Vector3.new(0, 0.8, 0)

	-- 1. Dynamic Camlock Engine
	if camLockActive and rimPos then
		Camera.CFrame = CFrame.lookAt(Camera.CFrame.Position, perfectSpot)
	end

	-- 2. Smart Target Physics Auto-Power Engine
	if autoShootActive and humanoid.Jump and ball then
		local distanceToBall = (hrp.Position - ball.Position).Magnitude
		if distanceToBall <= reachDistance then
			local direction = (perfectSpot - ball.Position)
			local horizontalDist = Vector3.new(direction.X, 0, direction.Z).Magnitude
			local verticalDist = direction.Y
			
			local gravity = workspace.Gravity
			
			-- DYNAMIC POWER: Automatically scales horizontal projection rate relative to distance from the hoop
			local horizontalVelocity = 52
			if autoPowerActive then
				-- Scaled mathematical equation for standard Hoopz physics weights
				horizontalVelocity = math.clamp(horizontalDist * 1.35, 38, 75)
			end
			
			local timeInAir = horizontalDist / horizontalVelocity
			
			if timeInAir > 0 then
				local verticalVelocity = (verticalDist / timeInAir) + (0.5 * gravity * timeInAir)
				local finalVelocityVector = Vector3.new(direction.X, 0, direction.Z).Unit * horizontalVelocity + Vector3.new(0, verticalVelocity, 0)
				
				ball.AssemblyLinearVelocity = finalVelocityVector
				ball.AssemblyAngularVelocity = Vector3.new(0, 0, 0)
			end
		end
	end

	-- 3. Loose Intercept Magnet (Mag)
	if magnetActive and ball then
		local dist = (hrp.Position - ball.Position).Magnitude
		if dist <= magnetRange and ball.AssemblyLinearVelocity.Magnitude > 1 then
			local interceptPoint = hrp.Position + (hrp.CFrame.LookVector * 1.5)
			ball.AssemblyLinearVelocity = (interceptPoint - ball.Position).Unit * 45
		end
	end
end)
