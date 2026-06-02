-- Hoopz Core Matrix Console (2026 Adaptive Edition)

if not game:IsLoaded() then game.Loaded:Wait() end

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local LocalPlayer = Players.LocalPlayer

while not LocalPlayer or not LocalPlayer:FindFirstChild("PlayerGui") do
	task.wait(0.5)
	LocalPlayer = Players.LocalPlayer
end

local Camera = workspace.CurrentCamera
local PlayerGui = LocalPlayer:WaitForChild("PlayerGui")
local ShootingEvent = ReplicatedStorage:WaitForChild("shootingEvent")
local CursorButton = PlayerGui:WaitForChild("PowerUI", 5) and PlayerGui.PowerUI:FindFirstChild("CursorButton")

-- Automatically correct court parent hierarchies
if workspace:FindFirstChild("PracticeArea") then
	pcall(function() workspace.PracticeArea.Parent = workspace:FindFirstChild("Courts") or workspace end)
end

--// GLOBAL CONSOLE STATES
local uiVisible = true
local uiToggleKey = Enum.KeyCode.RightControl

local aimbotActive = false
local reachActive = false
local autoGuardActive = false
local customSpeed = 16

local hasBall = false
local jumping = false
local trackingTarget = false
local guardPlayer = nil

-- Safe character root utility to prevent R6/R15 red-lining crashes
local function getRoot(character)
	if not character then return nil end
	return character:FindFirstChild("HumanoidRootPart") or character:FindFirstChild("Torso")
end

--// MASTER GEOMETRY & TRAJECTORY MATRIX

local function getCourtGoal()
	local shortestDistance, closestGoal = 9e9, nil
	local root = getRoot(LocalPlayer.Character)
	if not root then return nil, nil end
	
	local courts = workspace:FindFirstChild("Courts") or workspace
	for _, obj in ipairs(courts:GetDescendants()) do
		if obj.Name == "Swish" and (obj:IsA("Sound") or obj.Parent:FindFirstChildOfClass("TouchTransmitter")) then
			local mag = (root.Position - obj.Parent.Position).Magnitude
			if shortestDistance > mag then
				shortestDistance = mag
				closestGoal = obj.Parent
			end
		end
	end
	return shortestDistance, closestGoal
end

local function calculateArcOffset(dist)
	dist = math.floor(dist)
	if dist == 12 or dist == 13 then return 15
	elseif dist == 14 or dist == 15 then return 20
	elseif dist == 16 or dist == 17 then return 15
	elseif dist == 18 or dist == 19 then return 25
	elseif dist == 20 or dist == 21 then return 20
	elseif dist == 22 or dist == 23 then return 25
	elseif dist == 24 or dist == 25 then return 20
	elseif dist == 26 then return 15
	elseif dist == 27 or dist == 28 then return 25
	elseif dist == 29 or dist == 30 then return 20
	elseif dist == 31 then return 15
	elseif dist == 32 or dist == 33 then return 30
	elseif dist == 34 or dist == 35 or dist == 36 then return 25
	elseif dist == 37 or dist == 38 then return 35
	elseif dist == 39 or dist == 40 then return 30
	elseif dist == 41 then return 25
	elseif dist == 42 or dist == 43 then return 40
	elseif dist == 44 then return 35
	elseif dist == 45 or dist == 46 then return 30
	elseif dist == 47 or dist == 48 then return 45
	elseif dist == 49 then return 40
	elseif dist == 50 then return 35
	elseif dist == 51 then return 50
	elseif dist == 52 then return 55
	elseif dist == 53 or dist == 54 then return 50
	elseif dist == 55 then return 45
	elseif dist == 56 then return 40
	elseif dist == 57 or dist == 58 then return 55
	elseif dist == 59 or dist == 60 or dist == 61 then return 50
	elseif dist == 62 or dist == 63 then return 65
	elseif dist == 64 then return 55
	elseif dist == 65 then return 60
	elseif dist == 66 or dist == 67 then return 50
	elseif dist == 68 or dist == 69 then return 75
	elseif dist == 70 or dist == 71 then return 70
	elseif dist == 72 then return 65
	elseif dist == 73 then return 60
	elseif dist == 74 then return 50
	elseif jumping and (dist == 9 or dist == 10 or dist == 11 or dist == 12) then return 20
	end
	return 25
end

local function getPowerSetting(dist)
	dist = math.floor(dist)
	if dist >= 13 and dist <= 16 then return 30
	elseif dist >= 17 and dist <= 21 then return 35
	elseif dist >= 22 and dist <= 26 then return 40
	elseif dist >= 27 and dist <= 31 then return 45
	elseif dist >= 32 and dist <= 36 then return 50
	elseif dist >= 37 and dist <= 41 then return 55
	elseif dist >= 42 and dist <= 46 then return 60
	elseif dist >= 47 and dist <= 50 then return 65
	elseif dist >= 51 and dist <= 56 then return 70
	elseif dist >= 57 and dist <= 61 then return 75
	elseif dist >= 62 and dist <= 67 then return 80
	elseif dist >= 68 and dist <= 74 then return 85
	elseif jumping and dist >= 9 and dist <= 12 then return 25
	end
	return nil
end

--// AUXILIARY UTILITY PATTERNS

local function getNearestCarrier()
	local targetDist = 9e9
	local chosenOne = nil
	local root = getRoot(LocalPlayer.Character)
	if not root then return nil end
	
	for _, p in ipairs(Players:GetPlayers()) do
		if p ~= LocalPlayer and p.Character and p.Character:FindFirstChild("Basketball") then
			local targetRoot = getRoot(p.Character)
			if targetRoot then
				local magnitude = (root.Position - targetRoot.Position).Magnitude
				if magnitude < 50 and targetDist > magnitude then
					targetDist = magnitude
					chosenOne = p
				end
			end
		end
	end
	return chosenOne
end

local function runShootCalculation()
	local distance, goal = getCourtGoal()
	local char = LocalPlayer.Character
	local hum = char and char:FindFirstChildOfClass("Humanoid")
	local root = getRoot(char)
	
	if distance and goal and char and hum and root and char:FindFirstChild("Basketball") then
		local targetArc = calculateArcOffset(distance)
		local originPos = root.Position
		local lookDirection = ((goal.Position + Vector3.new(0, targetArc, 0)) - root.Position + hum.MoveDirection).Unit
		
		-- Streamlined 2026 network structure fallback
		local currentPower = LocalPlayer:FindFirstChild("Power") and LocalPlayer.Power.Value or 40
		ShootingEvent:FireServer(char.Basketball, currentPower, {originPos.X, originPos.Y, originPos.Z, lookDirection.X, lookDirection.Y, lookDirection.Z})
	end
end

local function executeJumpShotHook()
	if aimbotActive and LocalPlayer.Character and hasBall and getRoot(LocalPlayer.Character) then
		jumping = true
		task.wait(0.325)
		runShootCalculation()
		task.wait(0.1)
		jumping = false
	end
end

--// CONSTRUCT CONTROL MATRIX UI

local ScreenGui = Instance.new("ScreenGui")
ScreenGui.Name = "NixusMasterGui"
ScreenGui.ResetOnSpawn = false
ScreenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
ScreenGui.Parent = PlayerGui

local MainFrame = Instance.new("Frame")
MainFrame.Name = "MainFrame"
MainFrame.Size = UDim2.new(0, 280, 0, 420)
MainFrame.Position = UDim2.new(0.05, 0, 0.2, 0)
MainFrame.BackgroundColor3 = Color3.fromRGB(25, 20, 30)
MainFrame.BorderSizePixel = 0
MainFrame.Active = true
MainFrame.Draggable = true
MainFrame.Parent = ScreenGui

local UICorner = Instance.new("UICorner")
UICorner.CornerRadius = UDim.new(0, 8)
UICorner.Parent = MainFrame

local Title = Instance.new("TextLabel")
Title.Size = UDim2.new(1, 0, 0, 40)
Title.BackgroundTransparency = 1
Title.Text = "Nixus Basketball Controller"
Title.TextColor3 = Color3.fromRGB(180, 100, 255)
Title.TextSize = 16
Title.Font = Enum.Font.SourceSansBold
Title.Parent = MainFrame

local Scroll = Instance.new("ScrollingFrame")
Scroll.Size = UDim2.new(0.92, 0, 0, 360)
Scroll.Position = UDim2.new(0.04, 0, 0, 45)
Scroll.BackgroundTransparency = 1
Scroll.CanvasSize = UDim2.new(0, 0, 0, 460)
Scroll.ScrollBarThickness = 4
Scroll.Parent = MainFrame

local UIListLayout = Instance.new("UIListLayout")
UIListLayout.SortOrder = Enum.SortOrder.LayoutOrder
UIListLayout.Padding = UDim.new(0, 12)
UIListLayout.Parent = Scroll

local function createButton(name, text, order)
	local btn = Instance.new("TextButton")
	btn.Name = name
	btn.Size = UDim2.new(1, 0, 0, 32)
	btn.BackgroundColor3 = Color3.fromRGB(45, 40, 55)
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
	lbl.TextColor3 = Color3.fromRGB(200, 190, 210)
	lbl.TextSize = 13
	lbl.Font = Enum.Font.SourceSans
	lbl.TextXAlignment = Enum.TextXAlignment.Left
	lbl.Parent = sliderFrame

	local bar = Instance.new("Frame")
	bar.Size = UDim2.new(1, 0, 0, 6)
	bar.Position = UDim2.new(0, 0, 0, 25)
	bar.BackgroundColor3 = Color3.fromRGB(60, 55, 70)
	bar.BorderSizePixel = 0
	bar.Parent = sliderFrame

	local knob = Instance.new("TextButton")
	knob.Size = UDim2.new(0, 14, 0, 14)
	knob.AnchorPoint = Vector2.new(0.5, 0.5)
	local initialPercent = (default - min) / (max - min)
	knob.Position = UDim2.new(initialPercent, 0, 0.5, 0)
	knob.BackgroundColor3 = Color3.fromRGB(160, 90, 255)
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
			local percent = math.clamp((mouseX - bar.AbsolutePosition.X) / bar.AbsoluteSize.X, 0, 1)
			knob.Position = UDim2.new(percent, 0, 0.5, 0)
			local value = math.floor(min + (percent * (max - min)))
			lbl.Text = labelText .. ": " .. value
			callback(value)
		end
	end)
end

-- Render runtime controls
local AimBtn = createButton("AimBtn", "Trajectory Aimbot: OFF", 1)
AimBtn.BackgroundColor3 = Color3.fromRGB(65, 35, 35)

local ReachBtn = createButton("ReachBtn", "Silent Pocket Reach: OFF", 2)
ReachBtn.BackgroundColor3 = Color3.fromRGB(65, 35, 35)

local GuardBtn = createButton("GuardBtn", "Auto Defend Guard: OFF", 3)
GuardBtn.BackgroundColor3 = Color3.fromRGB(65, 35, 35)

local StatusLabel = createButton("StatusLabel", "State: Neutral", 10)
StatusLabel.BackgroundColor3 = Color3.fromRGB(30, 25, 40)
StatusLabel.AutoButtonColor = false

createSlider("WSSlider", "Speed Modulation", 16, 45, customSpeed, 4, function(val) customSpeed = val end)

--// INTERACTION CONNECTIONS

AimBtn.MouseButton1Click:Connect(function()
	aimbotActive = not aimbotActive
	AimBtn.Text = aimbotActive and "Trajectory Aimbot: ON" or "Trajectory Aimbot: OFF"
	AimBtn.BackgroundColor3 = aimbotActive and Color3.fromRGB(35, 65, 35) or Color3.fromRGB(65, 35, 35)
end)

ReachBtn.MouseButton1Click:Connect(function()
	reachActive = not reachActive
	ReachBtn.Text = reachActive and "Silent Pocket Reach: ON" or "Silent Pocket Reach: OFF"
	ReachBtn.BackgroundColor3 = reachActive and Color3.fromRGB(35, 65, 35) or Color3.fromRGB(65, 35, 35)
end)

GuardBtn.MouseButton1Click:Connect(function()
	autoGuardActive = not autoGuardActive
	GuardBtn.Text = autoGuardActive and "Auto Defend Guard: ON" or "Auto Defend Guard: OFF"
	GuardBtn.BackgroundColor3 = autoGuardActive and Color3.fromRGB(35, 65, 35) or Color3.fromRGB(65, 35, 35)
	if autoGuardActive then
		game:GetService("StarterGui"):SetCore("SendNotification", {
			Title = "Guard System Enabled",
			Text = "Press [U] to tether directly to the active ball runner.",
			Duration = 4
		})
	else
		trackingTarget = false
	end
end)

--// EVENT CORE HANDLING

UserInputService.InputBegan:Connect(function(input, processed)
	if processed then return end
	if input.KeyCode == uiToggleKey then
		uiVisible = not uiVisible
		MainFrame.Visible = uiVisible
	elseif input.KeyCode == Enum.KeyCode.U and autoGuardActive then
		guardPlayer = getNearestCarrier()
		trackingTarget = not trackingTarget
	elseif input.KeyCode == Enum.KeyCode.X then
		local currentDistance, currentGoal = getCourtGoal()
		local head = LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("Head")
		if currentGoal and head and CursorButton then
			local oldCFrame = Camera.CFrame
			LocalPlayer.DevEnableMouseLock = false
			Camera.CFrame = CFrame.lookAt(head.Position, currentGoal.Position)
			pcall(function() firesignal(CursorButton.MouseButton1Click) end)
			Camera.CFrame = oldCFrame
			LocalPlayer.DevEnableMouseLock = true
		end
	end
end)

-- Manage Character Instance Transitions safely
local function bindCharacterSystems(char)
	if not char then return end
	local hum = char:WaitForChild("Humanoid", 10)
	if hum then
		_G.input = hum.Jumping:Connect(executeJumpShotHook)
	end
	_G.added = char.ChildAdded:Connect(function(child)
		if child.Name == "Basketball" then hasBall = true end
	end)
	_G.removed = char.ChildRemoved:Connect(function(child)
		if child.Name == "Basketball" then hasBall = false end
	end)
end

bindCharacterSystems(LocalPlayer.Character or LocalPlayer.CharacterAdded:Wait())
_G.charAdded = LocalPlayer.CharacterAdded:Connect(bindCharacterSystems)

--// RUNTIME ENGINE PIPELINE

RunService.Stepped:Connect(function()
	local char = LocalPlayer.Character
	local root = getRoot(char)
	local hum = char and char:FindFirstChildOfClass("Humanoid")
	if not root or not hum then return end
	
	local distance, goal = getCourtGoal()
	
	-- 1. Trajectory Matrix Power Manipulator Loop
	if aimbotActive and distance and goal then
		local dynamicPower = getPowerSetting(distance)
		if dynamicPower and hasBall then
			root.Size = Vector3.new(2.1, 2.1, 1.1)
			root.BrickColor = BrickColor.new("Lime green")
			root.Material = Enum.Material.Neon
			root.Transparency = 0
			if LocalPlayer:FindFirstChild("Power") then
				LocalPlayer.Power.Value = dynamicPower
			end
		else
			root.Transparency = 1
		end
	else
		root.Transparency = 1
	end
	
	-- 2. Dribble Speed Adjuster Logic
	if customSpeed ~= 16 and hum.WalkSpeed ~= 0 then
		hum.WalkSpeed = customSpeed
	end
	
	-- 3. Dynamic Console Status Monitoring
	if hasBall then
		StatusLabel.Text = "State: Possession (Aim Primed)"
		StatusLabel.TextColor3 = Color3.fromRGB(0, 255, 120)
	else
		StatusLabel.Text = distance and ("Hoop Distance: " .. math.floor(distance) .. " studs") or "State: Scanning..."
		StatusLabel.TextColor3 = Color3.fromRGB(200, 200, 200)
	end
	
	-- 4. AutoGuard Track Intercept Mechanics
	if autoGuardActive and trackingTarget and guardPlayer and guardPlayer.Character and guardPlayer.Character:FindFirstChild("Basketball") then
		local carrierRoot = getRoot(guardPlayer.Character)
		local ballTool = guardPlayer.Character:FindFirstChild("Basketball")
		local ballPart = ballTool and ballTool:FindFirstChildOfClass("Part")
		
		if carrierRoot and ballPart then
			local destination = ballPart.Position + carrierRoot.CFrame.LookVector + (guardPlayer.Character:FindFirstChildOfClass("Humanoid").MoveDirection * 2) + (root.Velocity.Unit * 3)
			hum:MoveTo(destination)
			
			if carrierRoot.Position.Y > 4 then
				hum.Jump = true
			end
		end
	end
	
	-- 5. Silent Pocket Intercept Reach Loop
	if reachActive then
		for _, player in ipairs(Players:GetPlayers()) do
			if player ~= LocalPlayer and player.Character then
				local targetChar = player.Character
				local targetRoot = getRoot(targetChar)
				local localRoot = getRoot(char)
				
				if localRoot and targetRoot and (localRoot.Position - targetRoot.Position).Magnitude < 8 then
					for _, item in ipairs(targetChar:GetChildren()) do
						if item:IsA("Tool") and item:FindFirstChildOfClass("Part") then
							firetouchinterest(localRoot, item:FindFirstChildOfClass("Part"), 0)
							task.wait()
							firetouchinterest(localRoot, item:FindFirstChildOfClass("Part"), 1)
						elseif item:IsA("BasePart") and string.find(item.Name:lower(), "ball") then
							firetouchinterest(localRoot, item, 0)
							task.wait()
							firetouchinterest(localRoot, item, 1)
						end
					end
				end
			end
		end
	end
end)
