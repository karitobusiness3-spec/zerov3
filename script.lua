-- Hoopz Ultimate Adaptive Auto-Green Console

-- Wait for game loading parameters to stabilize
if not game:IsLoaded() then
	game.Loaded:Wait()
end

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local LocalPlayer = Players.LocalPlayer

-- Fallback check to prevent execution crashes
while not LocalPlayer or not LocalPlayer:FindFirstChild("PlayerGui") do
	task.wait(0.5)
	LocalPlayer = Players.LocalPlayer
end

local Camera = workspace.CurrentCamera
local PlayerGui = LocalPlayer:WaitForChild("PlayerGui")

-- Safe check for the shooting button interface from your script
local ShootingButton = PlayerGui:WaitForChild("PowerUI", 5) and PlayerGui.PowerUI:FindFirstChild("CursorButton")

-- Automatically fix court grouping structure if it's separated
if workspace:FindFirstChild("PracticeArea") then
	pcall(function()
		workspace.PracticeArea.Parent = workspace:FindFirstChild("Courts") or workspace
	end)
end

--// Settings & States
local uiVisible = true
local uiToggleKey = Enum.KeyCode.RightControl

local autoShootActive = false
local shootKeybind = Enum.KeyCode.X -- Your default activation key
local magnetActive = false
local magnetRange = 30
local customSpeed = 16

local isBinding = false
local bindingTarget = "" 

--// DYNAMIC IDENTIFICATION FUNCTIONS

-- 1. Identifies the closest hoop/rim dynamically based on keyword matching
local function GetClosestGoal()
	local closestGoal = nil
	local shortestDistance = math.huge
	
	local character = LocalPlayer.Character
	local rootPart = character and (character:FindFirstChild("HumanoidRootPart") or character:FindFirstChild("Torso"))
	if not rootPart then return nil end
	
	-- Look inside Courts container first, fallback to workspace if missing
	local searchArea = workspace:FindFirstChild("Courts") or workspace
	
	for _, obj in ipairs(searchArea:GetDescendants()) do
		if obj:IsA("BasePart") then
			local nameLower = obj.Name:lower()
			
			-- Match by specific game targets ("Swish") or universal hoop terms
			if obj.Name == "Swish" or nameLower:find("rim") or nameLower:find("goalhoop") then
				local distance = (rootPart.Position - obj.Position).Magnitude
				if distance < shortestDistance then
					shortestDistance = distance
					closestGoal = obj
				end
			end
		end
	end
	
	return closestGoal
end

-- 2. Tracks the basketball object and finds which player is handling it
local function identifyBallAndCarrier()
	local activeBall = nil
	local closestCarrier = nil
	local shortestDistance = 15 -- Max distance to count as handling the ball
	
	for _, obj in ipairs(workspace:GetDescendants()) do
		if obj:IsA("BasePart") and (obj.Name:lower():find("ball") or obj.Name:lower():find("basketball")) then
			activeBall = obj
			break
		end
	end
	
	if activeBall then
		for _, p in ipairs(Players:GetPlayers()) do
			local char = p.Character
			local hrp = char and (char:FindFirstChild("HumanoidRootPart") or char:FindFirstChild("Torso"))
			if hrp then
				local dist = (hrp.Position - activeBall.Position).Magnitude
				if dist < shortestDistance then
					shortestDistance = dist
					closestCarrier = p
				end
			end
		end
	end
	
	return activeBall, closestCarrier
end

--// CREATE UI ELEMENTS

local ScreenGui = Instance.new("ScreenGui")
ScreenGui.Name = "HoopzUltimateControlGui"
ScreenGui.ResetOnSpawn = false
ScreenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
ScreenGui.Parent = PlayerGui

-- Main Frame
local MainFrame = Instance.new("Frame")
MainFrame.Name = "MainFrame"
MainFrame.Size = UDim2.new(0, 280, 0, 400)
MainFrame.Position = UDim2.new(0.05, 0, 0.15, 0)
MainFrame.BackgroundColor3 = Color3.fromRGB(20, 20, 25)
MainFrame.BorderSizePixel = 0
MainFrame.Active = true
MainFrame.Draggable = true
MainFrame.Parent = ScreenGui

local UICorner = Instance.new("UICorner")
UICorner.CornerRadius = UDim.new(0, 8)
UICorner.Parent = MainFrame

-- Title
local Title = Instance.new("TextLabel")
Title.Size = UDim2.new(1, 0, 0, 40)
Title.BackgroundTransparency = 1
Title.Text = "Hoopz Master Snap Console"
Title.TextColor3 = Color3.fromRGB(255, 90, 0)
Title.TextSize = 16
Title.Font = Enum.Font.SourceSansBold
Title.Parent = MainFrame

-- Scrolling Frame for Settings
local Scroll = Instance.new("ScrollingFrame")
Scroll.Size = UDim2.new(0.92, 0, 0, 340)
Scroll.Position = UDim2.new(0.04, 0, 0, 45)
Scroll.BackgroundTransparency = 1
Scroll.CanvasSize = UDim2.new(0, 0, 0, 450)
Scroll.ScrollBarThickness = 4
Scroll.Parent = MainFrame

local UIListLayout = Instance.new("UIListLayout")
UIListLayout.SortOrder = Enum.SortOrder.LayoutOrder
UIListLayout.Padding = UDim.new(0, 12)
UIListLayout.Parent = Scroll

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

-- Render GUI control elements
local ShootBtn = createButton("ShootBtn", "Auto-Snap Green: OFF", 1)
ShootBtn.BackgroundColor3 = Color3.fromRGB(60, 30, 30)

local BindBtn = createButton("BindBtn", "Shoot Keybind: X", 2)

local MagBtn = createButton("MagBtn", "Steal Magnet (Mag): OFF", 3)
MagBtn.BackgroundColor3 = Color3.fromRGB(60, 30, 30)

local StatusLabel = createButton("StatusLabel", "Status: Waiting for Ball...", 10)
StatusLabel.BackgroundColor3 = Color3.fromRGB(35, 35, 40)
StatusLabel.AutoButtonColor = false

-- Sliders configuration
createSlider("SpeedSlider", "Dribble Walkspeed", 16, 120, customSpeed, 4, function(val)
	customSpeed = val
end)

createSlider("MagRadiusSlider", "Intercept Distance (Mag)", 10, 120, magnetRange, 5, function(val)
	magnetRange = val
end)

--// INTERACTIVE CONTROLS CONNECTORS

ShootBtn.MouseButton1Click:Connect(function()
	autoShootActive = not autoShootActive
	ShootBtn.Text = autoShootActive and "Auto-Snap Green: ON" or "Auto-Snap Green: OFF"
	ShootBtn.BackgroundColor3 = autoShootActive and Color3.fromRGB(30, 60, 30) or Color3.fromRGB(60, 30, 30)
end)

MagBtn.MouseButton1Click:Connect(function()
	magnetActive = not magnetActive
	MagBtn.Text = magnetActive and "Steal Magnet (Mag): ON" or "Steal Magnet (Mag): OFF"
	MagBtn.BackgroundColor3 = magnetActive and Color3.fromRGB(30, 60, 30) or Color3.fromRGB(60, 30, 30)
end)

BindBtn.MouseButton1Click:Connect(function()
	isBinding = true
	BindBtn.Text = "Press any key..."
end)

--// HANDLE KEYBOARD TRIGGERS

UserInputService.InputBegan:Connect(function(input, gameProcessed)
	if gameProcessed then return end

	if input.KeyCode == uiToggleKey then
		uiVisible = not uiVisible
		MainFrame.Visible = uiVisible
	elseif isBinding then
		if input.UserInputType == Enum.UserInputType.Keyboard then
			shootKeybind = input.KeyCode
			BindBtn.Text = "Shoot Keybind: " .. input.KeyCode.Name
			isBinding = false
		end
	else
		-- Integrated Input Execution Loop from your script
		if input.KeyCode == shootKeybind and autoShootActive then
			local ball, carrier = identifyBallAndCarrier()
			
			if ball and carrier == LocalPlayer then
				local Goal = GetClosestGoal()
				local character = LocalPlayer.Character
				local head = character and character:FindFirstChild("Head")
				
				if Goal and head and ShootingButton then
					-- Execute your visual camera tracking cache snap
					local OldCFrame = Camera.CFrame
					LocalPlayer.DevEnableMouseLock = false
					
					Camera.CFrame = CFrame.lookAt(head.Position, Goal.Position)
					
					-- Firesignal interaction simulation layer
					pcall(function()
						firesignal(ShootingButton.MouseButton1Click)
					end)
					
					-- Seamlessly return original coordinate views back to player
					Camera.CFrame = OldCFrame
					LocalPlayer.DevEnableMouseLock = true
				end
			end
		end
	end
end)

--// BACKGROUND OPTIMIZATION LOOPS

RunService.RenderStepped:Connect(function()
	local character = LocalPlayer.Character
	local hrp = character and character:FindFirstChild("HumanoidRootPart")
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	if not hrp or not humanoid then return end

	-- Continuously apply custom dribble speed adjustments cleanly
	if humanoid.WalkSpeed ~= customSpeed then
		humanoid.WalkSpeed = customSpeed
	end

	-- Tracker Status updates
	local ball, carrier = identifyBallAndCarrier()
	if ball then
		if carrier == LocalPlayer then
			StatusLabel.Text = "Status: You have possession"
			StatusLabel.TextColor3 = Color3.fromRGB(0, 255, 150)
		elseif carrier then
			StatusLabel.Text = "Carrier: " .. carrier.Name
			StatusLabel.TextColor3 = Color3.fromRGB(255, 200, 0)
		else
			StatusLabel.Text = "Status: Ball Loose"
			StatusLabel.TextColor3 = Color3.fromRGB(200, 200, 200)
		end
	else
		StatusLabel.Text = "Status: Scanning for Ball..."
		StatusLabel.TextColor3 = Color3.fromRGB(150, 150, 150)
	end

	-- Steal Magnet Intercept Loop
	if magnetActive and ball then
		local dist = (hrp.Position - ball.Position).Magnitude
		if dist <= magnetRange and ball.AssemblyLinearVelocity.Magnitude > 1 then
			local interceptPoint = hrp.Position + (hrp.CFrame.LookVector * 1.5)
			ball.AssemblyLinearVelocity = (interceptPoint - ball.Position).Unit * 45
		end
	end
end)
