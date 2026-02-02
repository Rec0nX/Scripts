--[[
    Dream Rivals Script
    Game: RIVALS
    Place ID: 17625359962
    Features: 45+ game-specific features
]]

-- Services
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")
local Lighting = game:GetService("Lighting")
local TweenService = game:GetService("TweenService")

local Player = Players.LocalPlayer
local Character = Player.Character or Player.CharacterAdded:Wait()
local Humanoid = Character:WaitForChild("Humanoid")
local HumanoidRootPart = Character:WaitForChild("HumanoidRootPart")

-- Check if already injected
local playerGui = Player:WaitForChild("PlayerGui")
if playerGui:FindFirstChild("DreamRivalsGUI") then
    warn("[Dream Rivals] Script already injected!")
    return
end

-- Remotes
local Remotes = {
    Data = ReplicatedStorage:WaitForChild("Remotes"):WaitForChild("Data"),
    Misc = ReplicatedStorage:WaitForChild("Remotes"):WaitForChild("Misc"),
    Duels = ReplicatedStorage:WaitForChild("Remotes"):WaitForChild("Duels"),
    Moderator = ReplicatedStorage:WaitForChild("Remotes"):WaitForChild("Moderator"),
    Matchmaking = ReplicatedStorage:WaitForChild("Remotes"):WaitForChild("Matchmaking"),
    Fighter = ReplicatedStorage:WaitForChild("Remotes"):WaitForChild("Replication"):WaitForChild("Fighter"),
    PrivateServer = ReplicatedStorage:WaitForChild("Remotes"):WaitForChild("PrivateServer")
}

-- Configuration
local Config = {
    -- Movement
    WalkSpeed = 16,
    JumpPower = 20,
    NoClip = false,
    Fly = false,
    FlySpeed = 50,
    InfiniteJump = false,
    
    -- ESP
    PlayerESP = false,
    WeaponESP = false,
    BoxESP = false,
    DistanceESP = false,
    TracerESP = false,
    Chams = false,
    ChamsColor = Color3.fromRGB(255, 100, 255),
    
    -- Visuals
    FullBright = false,
    RemoveFog = false,
    
    -- Combat
    NoRecoil = false,
    AutoRespawn = false,
    Aimbot = false,
    AimbotKey = Enum.KeyCode.E,
    AimbotFOV = 200,
    AimbotMaxDistance = 500,
    AimbotSmoothing = 1,
    ShowFOV = false,
    HitboxExpander = false,
    HitboxSize = 10,
    
    -- Auto Features
    AutoClaimRewards = false,
    AutoJoinQueue = false,
    AutoRematch = false,
    AutoVote = false,
    AntiAFK = false,
    
    -- Matchmaking
    AutoAcceptPartyInvite = false,
    AutoPlayAgain = false,
    
    -- Shop
    AutoRefreshShop = false,
    
    -- Misc
    SpamPing = false,
    AutoCollectSnowballs = false,
    SpamEmote = false,
    SelectedEmote = 1
}

local ToggleReferences = {}
local KeybindButtonRef = nil -- Reference to update keybind button after config load
local ESPObjects = {}
local Loops = {}
local FlyConnection = nil
local NoClipConnection = nil
local AimbotConnection = nil
local FOVCircle = nil
local CurrentTarget = nil
local ESPDrawings = {}
local ChamsFolder = nil
local AimbotActive = false
local AimbotKeyHeld = false -- Manual tracking of key state
local ScriptEnabled = true -- Flag to control script state

-- Config Save/Load System
local ConfigFileName = "DreamRivalsConfig.json"

local function saveConfig()
    pcall(function()
        local configData = {}
        for key, value in pairs(Config) do
            if typeof(value) == "Color3" then
                configData[key] = {value.R, value.G, value.B}
            elseif typeof(value) == "EnumItem" then
                -- Save both KeyCode and UserInputType enums
                if value.EnumType == Enum.KeyCode then
                    configData[key] = "KeyCode." .. tostring(value.Name)
                elseif value.EnumType == Enum.UserInputType then
                    configData[key] = "UserInputType." .. tostring(value.Name)
                else
                    configData[key] = tostring(value)
                end
            elseif typeof(value) ~= "function" and typeof(value) ~= "userdata" then
                configData[key] = value
            end
        end
        
        if writefile then
            writefile(ConfigFileName, game:GetService("HttpService"):JSONEncode(configData))
            print("[Dream Rivals] Config saved successfully")
        end
    end)
end

local function loadConfig()
    local success = pcall(function()
        if isfile and readfile and isfile(ConfigFileName) then
            local data = game:GetService("HttpService"):JSONDecode(readfile(ConfigFileName))
            
            for key, value in pairs(data) do
                if key == "ChamsColor" and typeof(value) == "table" then
                    Config[key] = Color3.new(value[1], value[2], value[3])
                elseif key == "AimbotKey" and typeof(value) == "string" then
                    -- Handle KeyCode
                    if value:match("KeyCode%.(.+)") then
                        local keyName = value:match("KeyCode%.(.+)")
                        if keyName and Enum.KeyCode[keyName] then
                            Config[key] = Enum.KeyCode[keyName]
                        end
                    -- Handle UserInputType (mouse buttons)
                    elseif value:match("UserInputType%.(.+)") then
                        local inputName = value:match("UserInputType%.(.+)")
                        if inputName and Enum.UserInputType[inputName] then
                            Config[key] = Enum.UserInputType[inputName]
                        end
                    end
                else
                    Config[key] = value
                end
            end
            
            print("[Dream Rivals] Config loaded successfully")
            return true
        end
    end)
    
    return success
end

local function autoSaveConfig()
    task.spawn(function()
        while task.wait(60) do -- Auto-save every 60 seconds
            saveConfig()
        end
    end)
end

-- Utility Functions
local function getAimbotKeyDisplayName()
    if typeof(Config.AimbotKey) == "EnumItem" then
        if Config.AimbotKey.EnumType == Enum.UserInputType then
            if Config.AimbotKey == Enum.UserInputType.MouseButton1 then
                return "Left Click"
            elseif Config.AimbotKey == Enum.UserInputType.MouseButton2 then
                return "Right Click"
            elseif Config.AimbotKey == Enum.UserInputType.MouseButton3 then
                return "Middle Click"
            end
        else
            return Config.AimbotKey.Name
        end
    end
    return "E"
end

local function notify(message)
    game:GetService("StarterGui"):SetCore("SendNotification", {
        Title = "Dream Rivals",
        Text = message,
        Duration = 3
    })
end


local function safeFireRemote(remote, ...)
    local args = {...}
    pcall(function()
        if remote and typeof(remote) == "Instance" then
            if remote:IsA("RemoteEvent") then
                remote:FireServer(unpack(args))
            elseif remote:IsA("RemoteFunction") then
                remote:InvokeServer(unpack(args))
            end
        end
    end)
end

-- ESP Functions
local function createESP(object, text, color)
    if not object or ESPObjects[object] then return end
    
    local billboardGui = Instance.new("BillboardGui")
    billboardGui.Name = "ESP"
    billboardGui.Adornee = object
    billboardGui.Size = UDim2.new(0, 100, 0, 50)
    billboardGui.StudsOffset = Vector3.new(0, 2, 0)
    billboardGui.AlwaysOnTop = true
    billboardGui.Parent = object
    
    local textLabel = Instance.new("TextLabel")
    textLabel.Size = UDim2.new(1, 0, 1, 0)
    textLabel.BackgroundTransparency = 1
    textLabel.Text = text
    textLabel.TextColor3 = color
    textLabel.TextStrokeTransparency = 0.5
    textLabel.Font = Enum.Font.SourceSansBold
    textLabel.TextSize = 14
    textLabel.Parent = billboardGui
    
    ESPObjects[object] = billboardGui
end

local function removeESP(object)
    if ESPObjects[object] then
        ESPObjects[object]:Destroy()
        ESPObjects[object] = nil
    end
end

local function clearAllESP()
    for _, esp in pairs(ESPObjects) do
        if esp then esp:Destroy() end
    end
    ESPObjects = {}
    
    for _, drawing in pairs(ESPDrawings) do
        if drawing then
            for _, obj in pairs(drawing) do
                if obj and obj.Remove then
                    obj:Remove()
                end
            end
        end
    end
    ESPDrawings = {}
end

local function createDrawingESP(player)
    if ESPDrawings[player] then return end
    
    local drawings = {}
    
    -- Box ESP
    drawings.Box = Drawing.new("Square")
    drawings.Box.Thickness = 2
    drawings.Box.Filled = false
    drawings.Box.Color = Color3.fromRGB(255, 100, 255)
    drawings.Box.Visible = false
    
    drawings.BoxOutline = Drawing.new("Square")
    drawings.BoxOutline.Thickness = 4
    drawings.BoxOutline.Filled = false
    drawings.BoxOutline.Color = Color3.fromRGB(0, 0, 0)
    drawings.BoxOutline.Visible = false
    
    -- Name Text
    drawings.Name = Drawing.new("Text")
    drawings.Name.Size = 14
    drawings.Name.Center = true
    drawings.Name.Outline = true
    drawings.Name.Color = Color3.fromRGB(255, 100, 255)
    drawings.Name.Visible = false
    
    -- Distance Text
    drawings.Distance = Drawing.new("Text")
    drawings.Distance.Size = 14
    drawings.Distance.Center = true
    drawings.Distance.Outline = true
    drawings.Distance.Color = Color3.fromRGB(255, 255, 255)
    drawings.Distance.Visible = false
    
    -- Tracer
    drawings.Tracer = Drawing.new("Line")
    drawings.Tracer.Thickness = 2
    drawings.Tracer.Color = Color3.fromRGB(255, 100, 255)
    drawings.Tracer.Visible = false
    
    ESPDrawings[player] = drawings
end

local function updateDrawingESP()
    if not (Config.PlayerESP or Config.BoxESP or Config.DistanceESP or Config.TracerESP) then
        return
    end
    
    local camera = Workspace.CurrentCamera
    if not camera or not HumanoidRootPart then return end
    
    local screenSize = camera.ViewportSize
    
    for player, drawings in pairs(ESPDrawings) do
        if not player or not player.Parent or not player.Character then
            if drawings.Box then drawings.Box.Visible = false end
            if drawings.BoxOutline then drawings.BoxOutline.Visible = false end
            if drawings.Name then drawings.Name.Visible = false end
            if drawings.Distance then drawings.Distance.Visible = false end
            if drawings.Tracer then drawings.Tracer.Visible = false end
            continue
        end
        
        local character = player.Character
        local hrp = character:FindFirstChild("HumanoidRootPart")
        local head = character:FindFirstChild("Head")
        
        if not hrp or not head then
            if drawings.Box then drawings.Box.Visible = false end
            if drawings.BoxOutline then drawings.BoxOutline.Visible = false end
            if drawings.Name then drawings.Name.Visible = false end
            if drawings.Distance then drawings.Distance.Visible = false end
            if drawings.Tracer then drawings.Tracer.Visible = false end
            continue
        end
        
        local hrpPos, onScreen = camera:WorldToViewportPoint(hrp.Position)
        
        if not onScreen or hrpPos.Z <= 0 then
            if drawings.Box then drawings.Box.Visible = false end
            if drawings.BoxOutline then drawings.BoxOutline.Visible = false end
            if drawings.Name then drawings.Name.Visible = false end
            if drawings.Distance then drawings.Distance.Visible = false end
            if drawings.Tracer then drawings.Tracer.Visible = false end
            continue
        end
        
        local headPos = camera:WorldToViewportPoint(head.Position + Vector3.new(0, 0.5, 0))
        local legPos = camera:WorldToViewportPoint(hrp.Position - Vector3.new(0, 3, 0))
        local height = math.abs(headPos.Y - legPos.Y)
        local width = height / 2
        
        -- Box
        if Config.BoxESP then
            drawings.Box.Size = Vector2.new(width, height)
            drawings.Box.Position = Vector2.new(hrpPos.X - width / 2, headPos.Y)
            drawings.Box.Visible = true
            drawings.BoxOutline.Size = Vector2.new(width, height)
            drawings.BoxOutline.Position = Vector2.new(hrpPos.X - width / 2, headPos.Y)
            drawings.BoxOutline.Visible = true
        else
            drawings.Box.Visible = false
            drawings.BoxOutline.Visible = false
        end
        
        -- Name
        if Config.PlayerESP then
            drawings.Name.Text = player.Name
            drawings.Name.Position = Vector2.new(hrpPos.X, headPos.Y - 20)
            drawings.Name.Visible = true
        else
            drawings.Name.Visible = false
        end
        
        -- Distance
        if Config.DistanceESP then
            local distance = math.floor((hrp.Position - HumanoidRootPart.Position).Magnitude)
            drawings.Distance.Text = distance .. "m"
            drawings.Distance.Position = Vector2.new(hrpPos.X, legPos.Y + 5)
            drawings.Distance.Visible = true
        else
            drawings.Distance.Visible = false
        end
        
        -- Tracer
        if Config.TracerESP then
            drawings.Tracer.From = Vector2.new(screenSize.X / 2, screenSize.Y)
            drawings.Tracer.To = Vector2.new(hrpPos.X, hrpPos.Y)
            drawings.Tracer.Visible = true
        else
            drawings.Tracer.Visible = false
        end
    end
end

local function createChams(character)
    if not character or not Config.Chams then return end
    
    -- Use Highlight on the character model directly (more reliable)
    local existingHighlight = character:FindFirstChild("DreamChams")
    if existingHighlight then return end -- Already has chams
    
    local highlight = Instance.new("Highlight")
    highlight.Name = "DreamChams"
    highlight.FillColor = Config.ChamsColor
    highlight.OutlineColor = Color3.fromRGB(255, 255, 255)
    highlight.FillTransparency = 0.5
    highlight.OutlineTransparency = 0
    highlight.Adornee = character
    highlight.Parent = character
end

local function removeChams(character)
    if not character then return end
    
    local cham = character:FindFirstChild("DreamChams")
    if cham then
        cham:Destroy()
    end
end

local function updateChams()
    for _, player in pairs(Players:GetPlayers()) do
        if player ~= Player then
            pcall(function()
                local character = player.Character
                if character then
                    if Config.Chams then
                        -- Check if chams already exist
                        if not character:FindFirstChild("DreamChams") then
                            createChams(character)
                        end
                    else
                        removeChams(character)
                    end
                end
            end)
        end
    end
end


local function updatePlayerESP()
    if Config.PlayerESP or Config.BoxESP or Config.DistanceESP or Config.TracerESP then
        -- Create ESP for ALL players immediately
        for _, player in pairs(Players:GetPlayers()) do
            if player ~= Player then
                if not ESPDrawings[player] then
                    createDrawingESP(player)
                end
                
                -- Also check if they have a character
                if player.Character and not ESPDrawings[player] then
                    createDrawingESP(player)
                end
            end
        end
        updateDrawingESP()
    end
end

local function updateWeaponESP()
    if Config.WeaponESP then
        for _, obj in pairs(Workspace:GetDescendants()) do
            if obj:IsA("Tool") or (obj:IsA("Model") and obj:FindFirstChild("Handle")) then
                local handle = obj:FindFirstChild("Handle")
                if handle then
                    createESP(handle, obj.Name, Color3.fromRGB(100, 255, 100))
                end
            end
        end
    end
end

-- Movement Functions
local function setWalkSpeed(speed)
    if Humanoid then
        Humanoid.WalkSpeed = speed
    end
end

local function setJumpPower(power)
    if Humanoid then
        Humanoid.JumpPower = power
    end
end

local function toggleNoClip(enabled)
    if NoClipConnection then
        NoClipConnection:Disconnect()
        NoClipConnection = nil
    end
    
    if enabled then
        NoClipConnection = RunService.Stepped:Connect(function()
            if Character then
                for _, part in pairs(Character:GetDescendants()) do
                    if part:IsA("BasePart") then
                        part.CanCollide = false
                    end
                end
            end
        end)
    end
end


local function toggleFly(enabled)
    -- Clean up existing fly objects
    if FlyConnection then
        FlyConnection:Disconnect()
        FlyConnection = nil
    end
    
    -- Remove any existing fly objects from character
    if HumanoidRootPart then
        local oldBV = HumanoidRootPart:FindFirstChild("FlyVelocity")
        local oldBG = HumanoidRootPart:FindFirstChild("FlyGyro")
        if oldBV then oldBV:Destroy() end
        if oldBG then oldBG:Destroy() end
    end
    
    if enabled and HumanoidRootPart then
        -- Disable humanoid physics
        if Humanoid then
            Humanoid.PlatformStand = true
        end
        
        local bodyVelocity = Instance.new("BodyVelocity")
        bodyVelocity.Name = "FlyVelocity"
        bodyVelocity.Velocity = Vector3.new(0, 0, 0)
        bodyVelocity.MaxForce = Vector3.new(math.huge, math.huge, math.huge)
        bodyVelocity.Parent = HumanoidRootPart
        
        local bodyGyro = Instance.new("BodyGyro")
        bodyGyro.Name = "FlyGyro"
        bodyGyro.MaxTorque = Vector3.new(math.huge, math.huge, math.huge)
        bodyGyro.P = 1e6
        bodyGyro.D = 100
        bodyGyro.Parent = HumanoidRootPart
        
        FlyConnection = RunService.RenderStepped:Connect(function()
            if not Config.Fly or not HumanoidRootPart or not HumanoidRootPart.Parent then
                -- Clean up
                if bodyVelocity and bodyVelocity.Parent then bodyVelocity:Destroy() end
                if bodyGyro and bodyGyro.Parent then bodyGyro:Destroy() end
                if Humanoid then Humanoid.PlatformStand = false end
                if FlyConnection then
                    FlyConnection:Disconnect()
                    FlyConnection = nil
                end
                return
            end
            
            local camera = Workspace.CurrentCamera
            local moveDirection = Vector3.new(0, 0, 0)
            
            if UserInputService:IsKeyDown(Enum.KeyCode.W) then
                moveDirection = moveDirection + camera.CFrame.LookVector
            end
            if UserInputService:IsKeyDown(Enum.KeyCode.S) then
                moveDirection = moveDirection - camera.CFrame.LookVector
            end
            if UserInputService:IsKeyDown(Enum.KeyCode.A) then
                moveDirection = moveDirection - camera.CFrame.RightVector
            end
            if UserInputService:IsKeyDown(Enum.KeyCode.D) then
                moveDirection = moveDirection + camera.CFrame.RightVector
            end
            if UserInputService:IsKeyDown(Enum.KeyCode.Space) then
                moveDirection = moveDirection + Vector3.new(0, 1, 0)
            end
            if UserInputService:IsKeyDown(Enum.KeyCode.LeftShift) then
                moveDirection = moveDirection - Vector3.new(0, 1, 0)
            end
            
            -- Only apply velocity if moving, otherwise hover in place
            if moveDirection.Magnitude > 0 then
                bodyVelocity.Velocity = moveDirection.Unit * Config.FlySpeed
            else
                bodyVelocity.Velocity = Vector3.new(0, 0, 0)
            end
            
            bodyGyro.CFrame = camera.CFrame
        end)
        
        notify("Fly ON - WASD to move, Space/Shift for up/down")
    else
        -- Disable fly
        if Humanoid then
            Humanoid.PlatformStand = false
        end
        notify("Fly OFF")
    end
end


-- Visual Functions
local function toggleFullBright(enabled)
    if enabled then
        Lighting.Brightness = 2
        Lighting.ClockTime = 14
        Lighting.GlobalShadows = false
        Lighting.OutdoorAmbient = Color3.fromRGB(128, 128, 128)
    else
        Lighting.Brightness = 1
        Lighting.GlobalShadows = true
        Lighting.OutdoorAmbient = Color3.fromRGB(70, 70, 70)
    end
end

local function toggleRemoveFog(enabled)
    if enabled then
        Lighting.FogEnd = 100000
    else
        Lighting.FogEnd = 1000
    end
end

-- Auto Features
local function autoClaimRewards()
    task.spawn(function()
        while Config.AutoClaimRewards do
            pcall(function()
                safeFireRemote(Remotes.Data:FindFirstChild("ClaimGroupReward"))
                safeFireRemote(Remotes.Data:FindFirstChild("ClaimLikeReward"))
                safeFireRemote(Remotes.Data:FindFirstChild("ClaimNotificationsReward"))
                safeFireRemote(Remotes.Data:FindFirstChild("ClaimFavoriteReward"))
            end)
            task.wait(5)
        end
    end)
end

local function autoJoinQueue()
    task.spawn(function()
        while Config.AutoJoinQueue do
            pcall(function()
                local queueJoin = Remotes.Misc:FindFirstChild("QueueJoin")
                if queueJoin then
                    queueJoin:InvokeServer()
                end
            end)
            task.wait(2)
        end
    end)
end


local function autoRematch()
    task.spawn(function()
        while Config.AutoRematch do
            pcall(function()
                safeFireRemote(Remotes.Duels:FindFirstChild("Rematch"))
            end)
            task.wait(1)
        end
    end)
end

local function autoVote()
    task.spawn(function()
        while Config.AutoVote do
            pcall(function()
                safeFireRemote(Remotes.Duels:FindFirstChild("Vote"), 1)
            end)
            task.wait(1)
        end
    end)
end

local function antiAFK()
    task.spawn(function()
        while Config.AntiAFK do
            pcall(function()
                local VirtualUser = game:GetService("VirtualUser")
                VirtualUser:CaptureController()
                VirtualUser:ClickButton2(Vector2.new())
            end)
            task.wait(60)
        end
    end)
end

local function spamPing()
    task.spawn(function()
        while Config.SpamPing do
            pcall(function()
                safeFireRemote(Remotes.Misc:FindFirstChild("Ping"))
                safeFireRemote(Remotes.Fighter:FindFirstChild("Ping"))
            end)
            task.wait(0.1)
        end
    end)
end

local function autoCollectSnowballs()
    task.spawn(function()
        while Config.AutoCollectSnowballs do
            pcall(function()
                safeFireRemote(Remotes.Misc:FindFirstChild("GrabSnowball"))
            end)
            task.wait(0.5)
        end
    end)
end


local function spamEmote()
    task.spawn(function()
        while Config.SpamEmote do
            pcall(function()
                safeFireRemote(Remotes.Fighter:FindFirstChild("UseEmote"), Config.SelectedEmote)
            end)
            task.wait(0.5)
        end
    end)
end

local function autoRefreshShop()
    task.spawn(function()
        while Config.AutoRefreshShop do
            pcall(function()
                safeFireRemote(Remotes.Data:FindFirstChild("RefreshDailyShop"))
            end)
            task.wait(10)
        end
    end)
end

-- Combat Functions
local function autoRespawn()
    task.spawn(function()
        while Config.AutoRespawn do
            pcall(function()
                safeFireRemote(Remotes.Duels:FindFirstChild("RespawnNow"))
            end)
            task.wait(0.5)
        end
    end)
end

local function getClosestPlayer()
    local closestPlayer = nil
    local shortestDistance = Config.AimbotFOV
    
    if not HumanoidRootPart then return nil end
    
    local camera = Workspace.CurrentCamera
    if not camera then return nil end
    
    local mousePos = UserInputService:GetMouseLocation()
    local myPosition = HumanoidRootPart.Position
    
    for _, player in pairs(Players:GetPlayers()) do
        if player ~= Player and player.Character then
            local humanoid = player.Character:FindFirstChild("Humanoid")
            local head = player.Character:FindFirstChild("Head")
            local targetHRP = player.Character:FindFirstChild("HumanoidRootPart")
            
            if humanoid and head and targetHRP and humanoid.Health > 0 then
                local distance3D = (targetHRP.Position - myPosition).Magnitude
                if distance3D <= Config.AimbotMaxDistance then
                    local screenPos, onScreen = camera:WorldToViewportPoint(head.Position)
                    
                    if onScreen and screenPos.Z > 0 then
                        local distance2D = (Vector2.new(screenPos.X, screenPos.Y) - mousePos).Magnitude
                        
                        if distance2D < shortestDistance then
                            shortestDistance = distance2D
                            closestPlayer = player
                        end
                    end
                end
            end
        end
    end
    
    return closestPlayer
end

local function createFOVCircle()
    if FOVCircle then
        FOVCircle:Remove()
    end
    
    FOVCircle = Drawing.new("Circle")
    FOVCircle.Thickness = 2
    FOVCircle.NumSides = 50
    FOVCircle.Radius = Config.AimbotFOV
    FOVCircle.Color = Color3.fromRGB(255, 100, 255)
    FOVCircle.Visible = Config.ShowFOV
    FOVCircle.Filled = false
    FOVCircle.Transparency = 1
    
    return FOVCircle
end

local function updateFOVCircle()
    if FOVCircle then
        local mousePos = UserInputService:GetMouseLocation()
        FOVCircle.Position = mousePos
        FOVCircle.Radius = Config.AimbotFOV
        FOVCircle.Visible = Config.ShowFOV
    end
end

local function toggleAimbot(enabled)
    if AimbotConnection then
        AimbotConnection:Disconnect()
        AimbotConnection = nil
    end
    
    if not FOVCircle then
        createFOVCircle()
    end
    
    if enabled then
        print("[Dream Rivals] Aimbot ENABLED - Key: " .. tostring(Config.AimbotKey))
        notify("Aimbot ON - Hold your key")
        
        local lockedTarget = nil -- Sticky target
        
        AimbotConnection = RunService.RenderStepped:Connect(function()
            if not Config.Aimbot then return end
            if not ScriptEnabled then return end
            
            updateFOVCircle()
            
            -- Reset when not holding key
            if not AimbotKeyHeld then
                lockedTarget = nil
                if FOVCircle then
                    FOVCircle.Color = Color3.fromRGB(255, 100, 255)
                end
                return
            end
            
            -- Refresh character references
            if not Character or not Character.Parent then
                Character = Player.Character
                if Character then
                    HumanoidRootPart = Character:FindFirstChild("HumanoidRootPart")
                end
            end
            if not HumanoidRootPart then return end
            
            -- Check if locked target is still valid
            if lockedTarget then
                if not lockedTarget.Parent or not lockedTarget.Character then
                    lockedTarget = nil
                else
                    local humanoid = lockedTarget.Character:FindFirstChild("Humanoid")
                    if not humanoid or humanoid.Health <= 0 then
                        lockedTarget = nil
                    end
                end
            end
            
            -- Find new target if needed
            if not lockedTarget then
                lockedTarget = getClosestPlayer()
            end
            
            if not lockedTarget or not lockedTarget.Character then return end
            
            local head = lockedTarget.Character:FindFirstChild("Head")
            if not head then return end
            
            local camera = Workspace.CurrentCamera
            if not camera then return end
            
            local targetPos = head.Position
            
            -- Get target screen position BEFORE moving camera
            local screenPos, onScreen = camera:WorldToViewportPoint(targetPos)
            
            if onScreen and screenPos.Z > 0 then
                -- Move mouse to target's screen position
                if mousemoveabs then
                    mousemoveabs(screenPos.X, screenPos.Y)
                elseif setmouse then
                    setmouse(screenPos.X, screenPos.Y)
                end
            end
            
            if FOVCircle then
                FOVCircle.Color = Color3.fromRGB(0, 255, 0)
            end
        end)
        
        print("[Dream Rivals] Aimbot loop started")
    else
        print("[Dream Rivals] Aimbot DISABLED")
        AimbotKeyHeld = false
        notify("Aimbot OFF")
    end
end

local function toggleHitboxExpander(enabled)
    if enabled then
        task.spawn(function()
            while Config.HitboxExpander and task.wait(2) do
                pcall(function()
                    for _, player in pairs(Players:GetPlayers()) do
                        if player ~= Player and player.Character then
                            local hrp = player.Character:FindFirstChild("HumanoidRootPart")
                            if hrp then
                                hrp.Size = Vector3.new(Config.HitboxSize, Config.HitboxSize, Config.HitboxSize)
                                hrp.Transparency = 1
                                hrp.CanCollide = false
                                hrp.Massless = true
                            end
                        end
                    end
                end)
            end
        end)
    else
        -- Reset hitboxes
        task.spawn(function()
            for _, player in pairs(Players:GetPlayers()) do
                if player ~= Player and player.Character then
                    pcall(function()
                        local hrp = player.Character:FindFirstChild("HumanoidRootPart")
                        if hrp then
                            hrp.Size = Vector3.new(2, 2, 1)
                            hrp.Transparency = 1
                            hrp.CanCollide = false
                        end
                    end)
                end
            end
        end)
    end
end

-- Matchmaking Functions
local function autoAcceptPartyInvite()
    task.spawn(function()
        while Config.AutoAcceptPartyInvite do
            pcall(function()
                safeFireRemote(Remotes.Matchmaking:FindFirstChild("AcceptPartyInvite"))
            end)
            task.wait(1)
        end
    end)
end

local function autoPlayAgain()
    task.spawn(function()
        while Config.AutoPlayAgain do
            pcall(function()
                safeFireRemote(Remotes.Matchmaking:FindFirstChild("PlayAgain"))
            end)
            task.wait(2)
        end
    end)
end


-- GUI Creation Functions
local function createMainFrame()
    local screenGui = Instance.new("ScreenGui")
    screenGui.Name = "DreamRivalsGUI"
    screenGui.ResetOnSpawn = false
    screenGui.IgnoreGuiInset = false
    screenGui.DisplayOrder = 100
    screenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
    
    -- Always use PlayerGui for better persistence
    screenGui.Parent = Player:WaitForChild("PlayerGui")
    
    local mainFrame = Instance.new("Frame")
    mainFrame.Name = "MainFrame"
    mainFrame.Size = UDim2.new(0, 600, 0, 450)
    mainFrame.Position = UDim2.new(0.5, -300, 0.5, -225)
    mainFrame.BackgroundColor3 = Color3.fromRGB(15, 15, 20)
    mainFrame.BorderSizePixel = 0
    mainFrame.Active = true
    mainFrame.Draggable = true
    mainFrame.Parent = screenGui
    
    local corner = Instance.new("UICorner")
    corner.CornerRadius = UDim.new(0, 8)
    corner.Parent = mainFrame
    
    -- Title Bar
    local titleBar = Instance.new("Frame")
    titleBar.Name = "TitleBar"
    titleBar.Size = UDim2.new(1, 0, 0, 40)
    titleBar.BackgroundColor3 = Color3.fromRGB(30, 32, 38)
    titleBar.BorderSizePixel = 0
    titleBar.Parent = mainFrame
    
    local titleCorner = Instance.new("UICorner")
    titleCorner.CornerRadius = UDim.new(0, 8)
    titleCorner.Parent = titleBar
    
    local titleLabel = Instance.new("TextLabel")
    titleLabel.Size = UDim2.new(1, -100, 1, 0)
    titleLabel.Position = UDim2.new(0, 10, 0, 0)
    titleLabel.BackgroundTransparency = 1
    titleLabel.Text = "Dream Rivals Script [INSERT]"
    titleLabel.TextColor3 = Color3.fromRGB(255, 100, 255)
    titleLabel.Font = Enum.Font.SourceSansBold
    titleLabel.TextSize = 18
    titleLabel.TextXAlignment = Enum.TextXAlignment.Left
    titleLabel.Parent = titleBar
    
    -- Un-inject Button
    local uninjectBtn = Instance.new("TextButton")
    uninjectBtn.Name = "UninjectButton"
    uninjectBtn.Size = UDim2.new(0, 30, 0, 30)
    uninjectBtn.Position = UDim2.new(1, -70, 0.5, -15)
    uninjectBtn.BackgroundColor3 = Color3.fromRGB(200, 100, 50)
    uninjectBtn.Text = "U"
    uninjectBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
    uninjectBtn.Font = Enum.Font.SourceSansBold
    uninjectBtn.TextSize = 16
    uninjectBtn.Parent = titleBar
    
    local uninjectCorner = Instance.new("UICorner")
    uninjectCorner.CornerRadius = UDim.new(0, 6)
    uninjectCorner.Parent = uninjectBtn
    
    uninjectBtn.MouseButton1Click:Connect(function()
        -- Visual feedback - use clear text
        uninjectBtn.Text = "..."
        uninjectBtn.BackgroundColor3 = Color3.fromRGB(255, 50, 50)
        
        -- Execute uninject immediately
        task.spawn(function()
            uninject()
        end)
    end)
    
    -- Close Button
    local closeBtn = Instance.new("TextButton")
    closeBtn.Name = "CloseButton"
    closeBtn.Size = UDim2.new(0, 30, 0, 30)
    closeBtn.Position = UDim2.new(1, -35, 0.5, -15)
    closeBtn.BackgroundColor3 = Color3.fromRGB(200, 50, 50)
    closeBtn.Text = "X"
    closeBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
    closeBtn.Font = Enum.Font.SourceSansBold
    closeBtn.TextSize = 16
    closeBtn.Parent = titleBar
    
    local closeCorner = Instance.new("UICorner")
    closeCorner.CornerRadius = UDim.new(0, 6)
    closeCorner.Parent = closeBtn
    
    closeBtn.MouseButton1Click:Connect(function()
        mainFrame.Visible = false
    end)
    
    -- Tab Container
    local tabContainer = Instance.new("Frame")
    tabContainer.Name = "TabContainer"
    tabContainer.Size = UDim2.new(0, 120, 1, -50)
    tabContainer.Position = UDim2.new(0, 5, 0, 45)
    tabContainer.BackgroundColor3 = Color3.fromRGB(20, 22, 28)
    tabContainer.BorderSizePixel = 0
    tabContainer.Parent = mainFrame
    
    local tabCorner = Instance.new("UICorner")
    tabCorner.CornerRadius = UDim.new(0, 6)
    tabCorner.Parent = tabContainer
    
    local tabLayout = Instance.new("UIListLayout")
    tabLayout.Padding = UDim.new(0, 5)
    tabLayout.Parent = tabContainer
    
    -- Content Container
    local contentContainer = Instance.new("Frame")
    contentContainer.Name = "ContentContainer"
    contentContainer.Size = UDim2.new(1, -135, 1, -50)
    contentContainer.Position = UDim2.new(0, 130, 0, 45)
    contentContainer.BackgroundColor3 = Color3.fromRGB(20, 22, 28)
    contentContainer.BorderSizePixel = 0
    contentContainer.Parent = mainFrame
    
    local contentCorner = Instance.new("UICorner")
    contentCorner.CornerRadius = UDim.new(0, 6)
    contentCorner.Parent = contentContainer
    
    return screenGui, mainFrame, tabContainer, contentContainer
end


local function createTab(parent, text, callback)
    local button = Instance.new("TextButton")
    button.Size = UDim2.new(1, -10, 0, 35)
    button.BackgroundColor3 = Color3.fromRGB(35, 37, 45)
    button.Text = text
    button.TextColor3 = Color3.fromRGB(200, 200, 200)
    button.Font = Enum.Font.SourceSans
    button.TextSize = 14
    button.Parent = parent
    
    local corner = Instance.new("UICorner")
    corner.CornerRadius = UDim.new(0, 6)
    corner.Parent = button
    
    button.MouseButton1Click:Connect(callback)
    
    return button
end

local function createScrollFrame(parent)
    local scrollFrame = Instance.new("ScrollingFrame")
    scrollFrame.Size = UDim2.new(1, -10, 1, -10)
    scrollFrame.Position = UDim2.new(0, 5, 0, 5)
    scrollFrame.BackgroundTransparency = 1
    scrollFrame.BorderSizePixel = 0
    scrollFrame.ScrollBarThickness = 6
    scrollFrame.ScrollBarImageColor3 = Color3.fromRGB(255, 100, 255)
    scrollFrame.Parent = parent
    
    local layout = Instance.new("UIListLayout")
    layout.Padding = UDim.new(0, 5)
    layout.Parent = scrollFrame
    
    layout:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(function()
        scrollFrame.CanvasSize = UDim2.new(0, 0, 0, layout.AbsoluteContentSize.Y + 10)
    end)
    
    return scrollFrame
end

local function createSection(parent, text)
    local section = Instance.new("Frame")
    section.Size = UDim2.new(1, -10, 0, 30)
    section.BackgroundColor3 = Color3.fromRGB(35, 37, 45)
    section.BorderSizePixel = 0
    section.Parent = parent
    
    local corner = Instance.new("UICorner")
    corner.CornerRadius = UDim.new(0, 6)
    corner.Parent = section
    
    local label = Instance.new("TextLabel")
    label.Size = UDim2.new(1, -10, 1, 0)
    label.Position = UDim2.new(0, 10, 0, 0)
    label.BackgroundTransparency = 1
    label.Text = text
    label.TextColor3 = Color3.fromRGB(220, 220, 100)
    label.Font = Enum.Font.SourceSansBold
    label.TextSize = 14
    label.TextXAlignment = Enum.TextXAlignment.Left
    label.Parent = section
    
    return section
end


local function createToggle(parent, text, configKey, callback)
    local toggle = Instance.new("Frame")
    toggle.Size = UDim2.new(1, -10, 0, 38)
    toggle.BackgroundColor3 = Color3.fromRGB(35, 37, 45)
    toggle.BorderSizePixel = 0
    toggle.Parent = parent
    
    local corner = Instance.new("UICorner")
    corner.CornerRadius = UDim.new(0, 6)
    corner.Parent = toggle
    
    local label = Instance.new("TextLabel")
    label.Size = UDim2.new(1, -60, 1, 0)
    label.Position = UDim2.new(0, 10, 0, 0)
    label.BackgroundTransparency = 1
    label.Text = text
    label.TextColor3 = Color3.fromRGB(200, 200, 200)
    label.Font = Enum.Font.SourceSans
    label.TextSize = 13
    label.TextXAlignment = Enum.TextXAlignment.Left
    label.Parent = toggle
    
    local button = Instance.new("TextButton")
    button.Size = UDim2.new(0, 45, 0, 28)
    button.Position = UDim2.new(1, -50, 0.5, -14)
    button.BackgroundColor3 = Config[configKey] and Color3.fromRGB(50, 180, 100) or Color3.fromRGB(180, 50, 50)
    button.Text = Config[configKey] and "ON" or "OFF"
    button.TextColor3 = Color3.fromRGB(255, 255, 255)
    button.Font = Enum.Font.SourceSansBold
    button.TextSize = 12
    button.Parent = toggle
    
    local btnCorner = Instance.new("UICorner")
    btnCorner.CornerRadius = UDim.new(0, 6)
    btnCorner.Parent = button
    
    ToggleReferences[configKey] = {button = button, callback = callback}
    
    button.MouseButton1Click:Connect(function()
        Config[configKey] = not Config[configKey]
        button.BackgroundColor3 = Config[configKey] and Color3.fromRGB(50, 180, 100) or Color3.fromRGB(180, 50, 50)
        button.Text = Config[configKey] and "ON" or "OFF"
        
        if callback then
            callback(Config[configKey])
        end
        
        -- Don't auto-save on every toggle to prevent spam
    end)
    
    return toggle
end


local function createSlider(parent, text, configKey, min, max, callback)
    local slider = Instance.new("Frame")
    slider.Size = UDim2.new(1, -10, 0, 55)
    slider.BackgroundColor3 = Color3.fromRGB(35, 37, 45)
    slider.BorderSizePixel = 0
    slider.Parent = parent
    
    local corner = Instance.new("UICorner")
    corner.CornerRadius = UDim.new(0, 6)
    corner.Parent = slider
    
    local label = Instance.new("TextLabel")
    label.Size = UDim2.new(1, -20, 0, 20)
    label.Position = UDim2.new(0, 10, 0, 5)
    label.BackgroundTransparency = 1
    label.Text = text .. ": " .. Config[configKey]
    label.TextColor3 = Color3.fromRGB(200, 200, 200)
    label.Font = Enum.Font.SourceSans
    label.TextSize = 13
    label.TextXAlignment = Enum.TextXAlignment.Left
    label.Parent = slider
    
    local sliderBar = Instance.new("Frame")
    sliderBar.Size = UDim2.new(1, -20, 0, 20)
    sliderBar.Position = UDim2.new(0, 10, 0, 30)
    sliderBar.BackgroundColor3 = Color3.fromRGB(20, 22, 28)
    sliderBar.BorderSizePixel = 0
    sliderBar.Parent = slider
    
    local barCorner = Instance.new("UICorner")
    barCorner.CornerRadius = UDim.new(0, 6)
    barCorner.Parent = sliderBar
    
    local fill = Instance.new("Frame")
    fill.Size = UDim2.new((Config[configKey] - min) / (max - min), 0, 1, 0)
    fill.BackgroundColor3 = Color3.fromRGB(255, 100, 255)
    fill.BorderSizePixel = 0
    fill.Parent = sliderBar
    
    local fillCorner = Instance.new("UICorner")
    fillCorner.CornerRadius = UDim.new(0, 6)
    fillCorner.Parent = fill
    
    local dragging = false
    
    sliderBar.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 then
            dragging = true
        end
    end)
    
    sliderBar.InputEnded:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 then
            dragging = false
        end
    end)
    
    UserInputService.InputChanged:Connect(function(input)
        if dragging and input.UserInputType == Enum.UserInputType.MouseMovement then
            local pos = (input.Position.X - sliderBar.AbsolutePosition.X) / sliderBar.AbsoluteSize.X
            pos = math.clamp(pos, 0, 1)
            local value = math.floor(min + (max - min) * pos)
            
            Config[configKey] = value
            fill.Size = UDim2.new(pos, 0, 1, 0)
            label.Text = text .. ": " .. value
            
            if callback then
                callback(value)
            end
        end
    end)
    
    return slider
end

local function createButton(parent, text, callback)
    local button = Instance.new("TextButton")
    button.Size = UDim2.new(1, -10, 0, 38)
    button.BackgroundColor3 = Color3.fromRGB(35, 37, 45)
    button.Text = text
    button.TextColor3 = Color3.fromRGB(200, 200, 200)
    button.Font = Enum.Font.SourceSans
    button.TextSize = 13
    button.Parent = parent
    
    local corner = Instance.new("UICorner")
    corner.CornerRadius = UDim.new(0, 6)
    corner.Parent = button
    
    button.MouseButton1Click:Connect(function()
        button.BackgroundColor3 = Color3.fromRGB(255, 100, 255)
        task.wait(0.1)
        button.BackgroundColor3 = Color3.fromRGB(35, 37, 45)
        
        if callback then
            callback()
        end
    end)
    
    return button
end

local function createTextBox(parent, placeholder, callback)
    local textBox = Instance.new("TextBox")
    textBox.Size = UDim2.new(1, -10, 0, 38)
    textBox.BackgroundColor3 = Color3.fromRGB(35, 37, 45)
    textBox.PlaceholderText = placeholder
    textBox.Text = ""
    textBox.TextColor3 = Color3.fromRGB(200, 200, 200)
    textBox.PlaceholderColor3 = Color3.fromRGB(100, 100, 100)
    textBox.Font = Enum.Font.SourceSans
    textBox.TextSize = 13
    textBox.Parent = parent
    
    local corner = Instance.new("UICorner")
    corner.CornerRadius = UDim.new(0, 6)
    corner.Parent = textBox
    
    if callback then
        textBox.FocusLost:Connect(function(enterPressed)
            if enterPressed then
                callback(textBox.Text)
            end
        end)
    end
    
    return textBox
end


-- Tab Content Functions
local function createMovementTab(parent)
    local scroll = createScrollFrame(parent)
    
    createSection(scroll, "Movement Settings")
    createSlider(scroll, "Walk Speed", "WalkSpeed", 16, 200, setWalkSpeed)
    createSlider(scroll, "Jump Power", "JumpPower", 20, 300, setJumpPower)
    createToggle(scroll, "NoClip", "NoClip", toggleNoClip)
    createToggle(scroll, "Fly", "Fly", toggleFly)
    createSlider(scroll, "Fly Speed", "FlySpeed", 10, 200, nil)
    createToggle(scroll, "Infinite Jump", "InfiniteJump", nil)
    
    return scroll
end

local function createESPTab(parent)
    local scroll = createScrollFrame(parent)
    
    createSection(scroll, "ESP Settings")
    createToggle(scroll, "Player Name ESP", "PlayerESP", function(enabled)
        if not enabled and not Config.BoxESP and not Config.DistanceESP and not Config.TracerESP then
            clearAllESP()
        end
    end)
    createToggle(scroll, "Box ESP", "BoxESP", function(enabled)
        if not enabled and not Config.PlayerESP and not Config.DistanceESP and not Config.TracerESP then
            clearAllESP()
        end
    end)
    createToggle(scroll, "Distance ESP", "DistanceESP", function(enabled)
        if not enabled and not Config.PlayerESP and not Config.BoxESP and not Config.TracerESP then
            clearAllESP()
        end
    end)
    createToggle(scroll, "Tracer ESP", "TracerESP", function(enabled)
        if not enabled and not Config.PlayerESP and not Config.BoxESP and not Config.DistanceESP then
            clearAllESP()
        end
    end)
    createToggle(scroll, "Chams (Highlight)", "Chams", function(enabled)
        updateChams()
    end)
    createToggle(scroll, "Weapon ESP", "WeaponESP", function(enabled)
        if enabled then
            updateWeaponESP()
        else
            clearAllESP()
        end
    end)
    
    return scroll
end

local function createVisualsTab(parent)
    local scroll = createScrollFrame(parent)
    
    createSection(scroll, "Visual Settings")
    createToggle(scroll, "Full Bright", "FullBright", toggleFullBright)
    createToggle(scroll, "Remove Fog", "RemoveFog", toggleRemoveFog)
    
    return scroll
end


local function createAutoTab(parent)
    local scroll = createScrollFrame(parent)
    
    createSection(scroll, "Auto Features")
    createToggle(scroll, "Auto Claim Rewards", "AutoClaimRewards", function(enabled)
        if enabled then autoClaimRewards() end
    end)
    createToggle(scroll, "Auto Join Queue", "AutoJoinQueue", function(enabled)
        if enabled then autoJoinQueue() end
    end)
    createToggle(scroll, "Auto Rematch", "AutoRematch", function(enabled)
        if enabled then autoRematch() end
    end)
    createToggle(scroll, "Auto Vote", "AutoVote", function(enabled)
        if enabled then autoVote() end
    end)
    createToggle(scroll, "Auto Respawn", "AutoRespawn", function(enabled)
        if enabled then autoRespawn() end
    end)
    createToggle(scroll, "Anti AFK", "AntiAFK", function(enabled)
        if enabled then antiAFK() end
    end)
    createToggle(scroll, "Auto Collect Snowballs", "AutoCollectSnowballs", function(enabled)
        if enabled then autoCollectSnowballs() end
    end)
    createToggle(scroll, "Auto Refresh Shop", "AutoRefreshShop", function(enabled)
        if enabled then autoRefreshShop() end
    end)
    
    createSection(scroll, "Manual Actions")
    createButton(scroll, "Claim Group Reward", function()
        safeFireRemote(Remotes.Data:FindFirstChild("ClaimGroupReward"))
        notify("Claimed Group Reward")
    end)
    createButton(scroll, "Claim Like Reward", function()
        safeFireRemote(Remotes.Data:FindFirstChild("ClaimLikeReward"))
        notify("Claimed Like Reward")
    end)
    createButton(scroll, "Claim Notifications Reward", function()
        safeFireRemote(Remotes.Data:FindFirstChild("ClaimNotificationsReward"))
        notify("Claimed Notifications Reward")
    end)
    createButton(scroll, "Claim Favorite Reward", function()
        safeFireRemote(Remotes.Data:FindFirstChild("ClaimFavoriteReward"))
        notify("Claimed Favorite Reward")
    end)
    createButton(scroll, "Claim Welcome Back Gift", function()
        safeFireRemote(Remotes.Data:FindFirstChild("ClaimWelcomeBackGift"))
        notify("Claimed Welcome Back Gift")
    end)
    createButton(scroll, "Claim Event Gift", function()
        safeFireRemote(Remotes.Misc:FindFirstChild("ClaimEventGift"))
        notify("Claimed Event Gift")
    end)
    
    return scroll
end


local function createCombatTab(parent)
    local scroll = createScrollFrame(parent)
    
    createSection(scroll, "Aimbot Features")
    createToggle(scroll, "Aimbot (Hold Key)", "Aimbot", function(enabled)
        toggleAimbot(enabled)
    end)
    
    -- Keybind selector
    local keybindFrame = Instance.new("Frame")
    keybindFrame.Size = UDim2.new(1, -10, 0, 38)
    keybindFrame.BackgroundColor3 = Color3.fromRGB(35, 37, 45)
    keybindFrame.BorderSizePixel = 0
    keybindFrame.Parent = scroll
    
    local keyCorner = Instance.new("UICorner")
    keyCorner.CornerRadius = UDim.new(0, 6)
    keyCorner.Parent = keybindFrame
    
    local keybindLabel = Instance.new("TextLabel")
    keybindLabel.Size = UDim2.new(1, -120, 1, 0)
    keybindLabel.Position = UDim2.new(0, 10, 0, 0)
    keybindLabel.BackgroundTransparency = 1
    keybindLabel.Text = "Aimbot Key:"
    keybindLabel.TextColor3 = Color3.fromRGB(200, 200, 200)
    keybindLabel.Font = Enum.Font.SourceSans
    keybindLabel.TextSize = 13
    keybindLabel.TextXAlignment = Enum.TextXAlignment.Left
    keybindLabel.Parent = keybindFrame
    
    local keybindButton = Instance.new("TextButton")
    keybindButton.Size = UDim2.new(0, 100, 0, 28)
    keybindButton.Position = UDim2.new(1, -105, 0.5, -14)
    keybindButton.BackgroundColor3 = Color3.fromRGB(50, 50, 60)
    
    -- Display key name properly using helper function
    keybindButton.Text = getAimbotKeyDisplayName()
    keybindButton.TextColor3 = Color3.fromRGB(255, 255, 255)
    keybindButton.Font = Enum.Font.SourceSansBold
    keybindButton.TextSize = 12
    keybindButton.Parent = keybindFrame
    
    -- Store reference for updating after config load
    KeybindButtonRef = keybindButton
    
    local keyBtnCorner = Instance.new("UICorner")
    keyBtnCorner.CornerRadius = UDim.new(0, 6)
    keyBtnCorner.Parent = keybindButton
    
    local waitingForKey = false
    keybindButton.MouseButton1Click:Connect(function()
        if not waitingForKey then
            waitingForKey = true
            keybindButton.Text = "Press Key..."
            keybindButton.BackgroundColor3 = Color3.fromRGB(255, 100, 255)
            
            local connection
            connection = UserInputService.InputBegan:Connect(function(input, gameProcessed)
                if input.UserInputType == Enum.UserInputType.Keyboard then
                    Config.AimbotKey = input.KeyCode
                    keybindButton.Text = input.KeyCode.Name
                    keybindButton.BackgroundColor3 = Color3.fromRGB(50, 50, 60)
                    waitingForKey = false
                    connection:Disconnect()
                    saveConfig()
                    notify("Aimbot key set to: " .. input.KeyCode.Name)
                elseif input.UserInputType == Enum.UserInputType.MouseButton1 then
                    Config.AimbotKey = Enum.UserInputType.MouseButton1
                    keybindButton.Text = "Left Click"
                    keybindButton.BackgroundColor3 = Color3.fromRGB(50, 50, 60)
                    waitingForKey = false
                    connection:Disconnect()
                    saveConfig()
                    notify("Aimbot key set to: Left Click")
                elseif input.UserInputType == Enum.UserInputType.MouseButton2 then
                    Config.AimbotKey = Enum.UserInputType.MouseButton2
                    keybindButton.Text = "Right Click"
                    keybindButton.BackgroundColor3 = Color3.fromRGB(50, 50, 60)
                    waitingForKey = false
                    connection:Disconnect()
                    saveConfig()
                    notify("Aimbot key set to: Right Click")
                elseif input.UserInputType == Enum.UserInputType.MouseButton3 then
                    Config.AimbotKey = Enum.UserInputType.MouseButton3
                    keybindButton.Text = "Middle Click"
                    keybindButton.BackgroundColor3 = Color3.fromRGB(50, 50, 60)
                    waitingForKey = false
                    connection:Disconnect()
                    saveConfig()
                    notify("Aimbot key set to: Middle Click")
                end
            end)
        end
    end)
    
    createSlider(scroll, "Aimbot FOV", "AimbotFOV", 50, 500, function(value)
        if FOVCircle then
            FOVCircle.Radius = value
        end
    end)
    createSlider(scroll, "Max Distance (studs)", "AimbotMaxDistance", 100, 1000, nil)
    createSlider(scroll, "Smoothing (0.1-1.0)", "AimbotSmoothing", 0.1, 1, nil)
    
    -- Info label
    local infoLabel = Instance.new("TextLabel")
    infoLabel.Size = UDim2.new(1, -10, 0, 30)
    infoLabel.BackgroundColor3 = Color3.fromRGB(35, 37, 45)
    infoLabel.Text = "0.1=Smooth | 0.5=Balanced | 1.0=Instant"
    infoLabel.TextColor3 = Color3.fromRGB(150, 150, 150)
    infoLabel.Font = Enum.Font.SourceSans
    infoLabel.TextSize = 11
    infoLabel.Parent = scroll
    
    local infoCorner = Instance.new("UICorner")
    infoCorner.CornerRadius = UDim.new(0, 6)
    infoCorner.Parent = infoLabel
    
    createToggle(scroll, "Show FOV Circle", "ShowFOV", function(enabled)
        if FOVCircle then
            FOVCircle.Visible = enabled
        end
    end)
    
    -- Aimbot V2 (External)
    createButton(scroll, "Load Aimbot V2 (WeAreDevs)", function()
        notify("Loading Aimbot V2...")
        local success, err = pcall(function()
            loadstring(game:HttpGet("https://obj.wearedevs.net/2/scripts/Aimbot.lua"))()
        end)
        if success then
            notify("Aimbot V2 Loaded! Check settings.")
        else
            notify("Failed to load Aimbot V2")
            warn("[Dream Rivals] Aimbot V2 Error: " .. tostring(err))
        end
    end)
    
    createSection(scroll, "Hitbox Features")
    createToggle(scroll, "Hitbox Expander", "HitboxExpander", toggleHitboxExpander)
    createSlider(scroll, "Hitbox Size", "HitboxSize", 5, 30, nil)
    
    createSection(scroll, "Combat Actions")
    createButton(scroll, "Reset Character", function()
        safeFireRemote(Remotes.Fighter:FindFirstChild("ResetCharacter"))
        notify("Character Reset")
    end)
    createButton(scroll, "Cancel Quick Attack", function()
        safeFireRemote(Remotes.Fighter:FindFirstChild("CancelQuickAttack"))
        notify("Quick Attack Cancelled")
    end)
    createButton(scroll, "Request Replication", function()
        safeFireRemote(Remotes.Fighter:FindFirstChild("RequestReplication"))
        notify("Replication Requested")
    end)
    
    return scroll
end

local function createMatchmakingTab(parent)
    local scroll = createScrollFrame(parent)
    
    createSection(scroll, "Matchmaking Features")
    createToggle(scroll, "Auto Accept Party Invite", "AutoAcceptPartyInvite", function(enabled)
        if enabled then autoAcceptPartyInvite() end
    end)
    createToggle(scroll, "Auto Play Again", "AutoPlayAgain", function(enabled)
        if enabled then autoPlayAgain() end
    end)
    
    createSection(scroll, "Matchmaking Actions")
    createButton(scroll, "Join Queue", function()
        local queueJoin = Remotes.Matchmaking:FindFirstChild("JoinQueue")
        if queueJoin then
            queueJoin:InvokeServer()
            notify("Joined Queue")
        end
    end)
    createButton(scroll, "Leave Queue", function()
        safeFireRemote(Remotes.Matchmaking:FindFirstChild("LeaveQueue"))
        notify("Left Queue")
    end)
    createButton(scroll, "Leave Party", function()
        safeFireRemote(Remotes.Matchmaking:FindFirstChild("LeaveParty"))
        notify("Left Party")
    end)
    createButton(scroll, "Back to Hub", function()
        safeFireRemote(Remotes.Matchmaking:FindFirstChild("BackToHub"))
        notify("Returning to Hub")
    end)
    
    return scroll
end


local function createDuelsTab(parent)
    local scroll = createScrollFrame(parent)
    
    createSection(scroll, "Duel Features")
    createButton(scroll, "Leave Duel", function()
        safeFireRemote(Remotes.Duels:FindFirstChild("LeaveDuel"))
        notify("Left Duel")
    end)
    createButton(scroll, "Rematch", function()
        safeFireRemote(Remotes.Duels:FindFirstChild("Rematch"))
        notify("Rematch Requested")
    end)
    createButton(scroll, "Respawn Now", function()
        safeFireRemote(Remotes.Duels:FindFirstChild("RespawnNow"))
        notify("Respawning")
    end)
    createButton(scroll, "Switch Team", function()
        local switchTeam = Remotes.Duels:FindFirstChild("SwitchTeam")
        if switchTeam then
            switchTeam:InvokeServer()
            notify("Team Switched")
        end
    end)
    createButton(scroll, "Vote Map 1", function()
        safeFireRemote(Remotes.Duels:FindFirstChild("Vote"), 1)
        notify("Voted for Map 1")
    end)
    createButton(scroll, "Vote Map 2", function()
        safeFireRemote(Remotes.Duels:FindFirstChild("Vote"), 2)
        notify("Voted for Map 2")
    end)
    createButton(scroll, "Vote Map 3", function()
        safeFireRemote(Remotes.Duels:FindFirstChild("Vote"), 3)
        notify("Voted for Map 3")
    end)
    
    return scroll
end

local function createShopTab(parent)
    local scroll = createScrollFrame(parent)
    
    createSection(scroll, "Shop Features")
    createButton(scroll, "Refresh Daily Shop", function()
        safeFireRemote(Remotes.Data:FindFirstChild("RefreshDailyShop"))
        notify("Shop Refreshed")
    end)
    createButton(scroll, "Request Daily Shop", function()
        local requestShop = Remotes.Data:FindFirstChild("RequestDailyShop")
        if requestShop then
            requestShop:InvokeServer()
            notify("Shop Data Requested")
        end
    end)
    createButton(scroll, "View Daily Shop", function()
        safeFireRemote(Remotes.Misc:FindFirstChild("ViewedDailyShop"))
        notify("Viewed Daily Shop")
    end)
    
    createSection(scroll, "Cosmetics")
    createButton(scroll, "Favorite Cosmetic", function()
        safeFireRemote(Remotes.Data:FindFirstChild("FavoriteCosmetic"), 1)
        notify("Cosmetic Favorited")
    end)
    createButton(scroll, "Equip Cosmetic", function()
        safeFireRemote(Remotes.Data:FindFirstChild("EquipCosmetic"), 1)
        notify("Cosmetic Equipped")
    end)
    
    return scroll
end


local function createTeleportTab(parent)
    local scroll = createScrollFrame(parent)
    
    createSection(scroll, "Player Teleports")
    
    local function refreshPlayers()
        for _, child in pairs(scroll:GetChildren()) do
            if child:IsA("TextButton") and child.Name == "PlayerTP" then
                child:Destroy()
            end
        end
        
        for _, player in pairs(Players:GetPlayers()) do
            if player ~= Player then
                createButton(scroll, "TP to " .. player.Name, function()
                    if player.Character and player.Character:FindFirstChild("HumanoidRootPart") then
                        HumanoidRootPart.CFrame = player.Character.HumanoidRootPart.CFrame
                        notify("Teleported to " .. player.Name)
                    end
                end).Name = "PlayerTP"
            end
        end
    end
    
    createButton(scroll, "Refresh Players", refreshPlayers)
    refreshPlayers()
    
    createSection(scroll, "Location Teleports")
    createButton(scroll, "Teleport to Lobby", function()
        local lobby = Workspace:FindFirstChild("Lobby")
        if lobby then
            HumanoidRootPart.CFrame = lobby:GetModelCFrame()
            notify("Teleported to Lobby")
        end
    end)
    
    return scroll
end

local function createMiscTab(parent)
    local scroll = createScrollFrame(parent)
    
    createSection(scroll, "Config Management")
    createButton(scroll, "Save Config", function()
        saveConfig()
        notify("Config Saved!")
    end)
    createButton(scroll, "Load Config", function()
        if loadConfig() then
            notify("Config Loaded!")
        else
            notify("No config file found")
        end
    end)
    createButton(scroll, "Reset Config", function()
        -- Reset to defaults
        Config.WalkSpeed = 16
        Config.JumpPower = 20
        Config.FlySpeed = 50
        Config.AimbotFOV = 200
        Config.HitboxSize = 10
        Config.SelectedEmote = 1
        Config.AimbotKey = Enum.KeyCode.E
        
        -- Turn off all features
        for key, value in pairs(Config) do
            if typeof(value) == "boolean" then
                Config[key] = false
            end
        end
        
        saveConfig()
        notify("Config Reset! Reload script to apply.")
    end)
    
    createSection(scroll, "Misc Features")
    createToggle(scroll, "Spam Ping", "SpamPing", function(enabled)
        if enabled then spamPing() end
    end)
    createToggle(scroll, "Spam Emote", "SpamEmote", function(enabled)
        if enabled then spamEmote() end
    end)
    createSlider(scroll, "Emote Slot", "SelectedEmote", 1, 8, nil)
    
    createSection(scroll, "Code Redemption")
    local codeBox = createTextBox(scroll, "Enter Code", function(code)
        local redeemCode = Remotes.Data:FindFirstChild("RedeemCode")
        if redeemCode then
            local success = redeemCode:InvokeServer(code)
            if success then
                notify("Code Redeemed: " .. code)
            else
                notify("Code Failed: " .. code)
            end
        end
    end)
    
    createSection(scroll, "Misc Actions")
    createButton(scroll, "Request Player Data", function()
        local requestData = Remotes.Data:FindFirstChild("RequestPlayerData")
        if requestData then
            requestData:InvokeServer()
            notify("Player Data Requested")
        end
    end)
    createButton(scroll, "Request Constants", function()
        local requestConstants = Remotes.Misc:FindFirstChild("RequestConstants")
        if requestConstants then
            requestConstants:InvokeServer()
            notify("Constants Requested")
        end
    end)
    createButton(scroll, "View Patch Notes", function()
        safeFireRemote(Remotes.Misc:FindFirstChild("ViewedPatchNotes"))
        notify("Viewed Patch Notes")
    end)
    createButton(scroll, "Default Settings", function()
        safeFireRemote(Remotes.Data:FindFirstChild("DefaultSettings"))
        notify("Settings Reset to Default")
    end)
    createButton(scroll, "Verify Codes", function()
        safeFireRemote(Remotes.Data:FindFirstChild("VerifyCodes"))
        notify("Codes Verified")
    end)
    createButton(scroll, "Request Leaderboards", function()
        safeFireRemote(Remotes.Misc:FindFirstChild("RequestLeaderboards"))
        notify("Leaderboards Requested")
    end)
    createButton(scroll, "Shooting Range Enter", function()
        safeFireRemote(Remotes.Misc:FindFirstChild("ShootingRangeEnter"))
        notify("Entered Shooting Range")
    end)
    createButton(scroll, "Shooting Range Leave", function()
        safeFireRemote(Remotes.Misc:FindFirstChild("ShootingRangeLeave"))
        notify("Left Shooting Range")
    end)
    createButton(scroll, "Grab Snowball", function()
        safeFireRemote(Remotes.Misc:FindFirstChild("GrabSnowball"))
        notify("Grabbed Snowball")
    end)
    createButton(scroll, "Use Emote Slot 1", function()
        safeFireRemote(Remotes.Fighter:FindFirstChild("UseEmote"), 1)
        notify("Used Emote 1")
    end)
    createButton(scroll, "Cancel Emote", function()
        safeFireRemote(Remotes.Fighter:FindFirstChild("CancelEmoteFromClient"))
        notify("Emote Cancelled")
    end)
    
    createSection(scroll, "Player Stats")
    local statsLabel = Instance.new("TextLabel")
    statsLabel.Size = UDim2.new(1, -10, 0, 80)
    statsLabel.BackgroundColor3 = Color3.fromRGB(35, 37, 45)
    statsLabel.Text = "Level: " .. (Player.leaderstats and Player.leaderstats.Level.Value or "N/A") .. "\nWin Streak: " .. (Player.leaderstats and Player.leaderstats["Win Streak"].Value or "N/A")
    statsLabel.TextColor3 = Color3.fromRGB(200, 200, 200)
    statsLabel.Font = Enum.Font.SourceSans
    statsLabel.TextSize = 13
    statsLabel.Parent = scroll
    
    local statsCorner = Instance.new("UICorner")
    statsCorner.CornerRadius = UDim.new(0, 6)
    statsCorner.Parent = statsLabel
    
    return scroll
end


-- Un-inject Function
local function uninject()
    print("[Dream Rivals] ========== UNINJECT STARTED ==========")
    
    -- IMMEDIATELY set flag to disable script
    ScriptEnabled = false
    print("[Dream Rivals] Script disabled flag set")
    
    -- Disable all config features
    for key, value in pairs(Config) do
        if typeof(value) == "boolean" then
            Config[key] = false
        end
    end
    AimbotActive = false
    print("[Dream Rivals] All config features disabled")
    
    -- Stop all connections
    pcall(function()
        if NoClipConnection then
            NoClipConnection:Disconnect()
            NoClipConnection = nil
            print("[Dream Rivals] NoClip disconnected")
        end
    end)
    
    pcall(function()
        if FlyConnection then
            FlyConnection:Disconnect()
            FlyConnection = nil
            print("[Dream Rivals] Fly disconnected")
        end
    end)
    
    pcall(function()
        if AimbotConnection then
            AimbotConnection:Disconnect()
            AimbotConnection = nil
            print("[Dream Rivals] Aimbot disconnected")
        end
    end)
    
    -- Remove FOV Circle
    pcall(function()
        if FOVCircle then
            FOVCircle:Remove()
            FOVCircle = nil
            print("[Dream Rivals] FOV Circle removed")
        end
    end)
    
    -- Clear ESP
    pcall(function()
        clearAllESP()
        print("[Dream Rivals] ESP cleared")
    end)
    
    -- Remove all chams
    pcall(function()
        for _, player in pairs(Players:GetPlayers()) do
            if player.Character then
                removeChams(player.Character)
            end
        end
        print("[Dream Rivals] Chams removed")
    end)
    
    -- Reset hitboxes
    pcall(function()
        for _, player in pairs(Players:GetPlayers()) do
            if player ~= Player and player.Character then
                local hrp = player.Character:FindFirstChild("HumanoidRootPart")
                if hrp then
                    hrp.Size = Vector3.new(2, 2, 1)
                    hrp.Transparency = 1
                end
            end
        end
        print("[Dream Rivals] Hitboxes reset")
    end)
    
    -- Reset character stats
    pcall(function()
        if Humanoid then
            Humanoid.WalkSpeed = 16
            Humanoid.JumpPower = 20
            print("[Dream Rivals] Character stats reset")
        end
    end)
    
    -- Reset lighting
    pcall(function()
        Lighting.Brightness = 1
        Lighting.GlobalShadows = true
        Lighting.OutdoorAmbient = Color3.fromRGB(70, 70, 70)
        Lighting.FogEnd = 1000
        print("[Dream Rivals] Lighting reset")
    end)
    
    -- Destroy GUI
    pcall(function()
        local gui = playerGui:FindFirstChild("DreamRivalsGUI")
        if gui then
            gui:Destroy()
            print("[Dream Rivals] GUI destroyed")
        end
    end)
    
    print("[Dream Rivals] ========== UNINJECT COMPLETE ==========")
    
    -- Final notification
    game:GetService("StarterGui"):SetCore("SendNotification", {
        Title = "Dream Rivals",
        Text = "Script Un-injected Successfully!",
        Duration = 5
    })
end

-- Main GUI Setup
local function setupGUI()
    local screenGui, mainFrame, tabContainer, contentContainer = createMainFrame()
    
    local tabs = {}
    local currentTab = nil
    
    local function switchTab(tabName)
        for name, content in pairs(tabs) do
            content.Visible = (name == tabName)
        end
        currentTab = tabName
    end
    
    -- Create tabs
    local tabNames = {"Movement", "ESP", "Visuals", "Auto", "Combat", "Matchmaking", "Duels", "Shop", "Teleport", "Misc"}
    local tabFunctions = {
        Movement = createMovementTab,
        ESP = createESPTab,
        Visuals = createVisualsTab,
        Auto = createAutoTab,
        Combat = createCombatTab,
        Matchmaking = createMatchmakingTab,
        Duels = createDuelsTab,
        Shop = createShopTab,
        Teleport = createTeleportTab,
        Misc = createMiscTab
    }
    
    for _, tabName in ipairs(tabNames) do
        local tabContent = Instance.new("Frame")
        tabContent.Name = tabName
        tabContent.Size = UDim2.new(1, 0, 1, 0)
        tabContent.BackgroundTransparency = 1
        tabContent.Visible = false
        tabContent.Parent = contentContainer
        
        if tabFunctions[tabName] then
            tabFunctions[tabName](tabContent)
        end
        
        tabs[tabName] = tabContent
        
        createTab(tabContainer, tabName, function()
            switchTab(tabName)
        end)
    end
    
    switchTab("Movement")
    
    -- Menu toggle
    UserInputService.InputBegan:Connect(function(input, gameProcessed)
        if not gameProcessed and input.KeyCode == Enum.KeyCode.Insert then
            mainFrame.Visible = not mainFrame.Visible
        end
    end)
    
    return screenGui
end

-- Main Loops
local function startMainLoops()
    -- AIMBOT KEY TRACKING - Manual state tracking (more reliable than IsKeyDown)
    UserInputService.InputBegan:Connect(function(input, gameProcessed)
        -- Don't ignore gameProcessed for aimbot - we want it to work even when typing
        if not Config.Aimbot then return end
        
        local isAimbotKey = false
        
        if typeof(Config.AimbotKey) == "EnumItem" then
            if Config.AimbotKey.EnumType == Enum.KeyCode then
                isAimbotKey = (input.KeyCode == Config.AimbotKey)
            elseif Config.AimbotKey.EnumType == Enum.UserInputType then
                isAimbotKey = (input.UserInputType == Config.AimbotKey)
            end
        end
        
        if isAimbotKey then
            AimbotKeyHeld = true
        end
    end)
    
    UserInputService.InputEnded:Connect(function(input, gameProcessed)
        if not Config.Aimbot then return end
        
        local isAimbotKey = false
        
        if typeof(Config.AimbotKey) == "EnumItem" then
            if Config.AimbotKey.EnumType == Enum.KeyCode then
                isAimbotKey = (input.KeyCode == Config.AimbotKey)
            elseif Config.AimbotKey.EnumType == Enum.UserInputType then
                isAimbotKey = (input.UserInputType == Config.AimbotKey)
            end
        end
        
        if isAimbotKey then
            AimbotKeyHeld = false
        end
    end)
    
    -- Stat maintenance loop - only update when needed
    local lastWalkSpeed, lastJumpPower = Config.WalkSpeed, Config.JumpPower
    task.spawn(function()
        while task.wait(0.1) do
            if not ScriptEnabled then break end
            if Humanoid and Humanoid.Parent then
                if Config.WalkSpeed ~= lastWalkSpeed or Humanoid.WalkSpeed ~= Config.WalkSpeed then
                    Humanoid.WalkSpeed = Config.WalkSpeed
                    lastWalkSpeed = Config.WalkSpeed
                end
                if Config.JumpPower ~= lastJumpPower or Humanoid.JumpPower ~= Config.JumpPower then
                    Humanoid.JumpPower = Config.JumpPower
                    lastJumpPower = Config.JumpPower
                end
            end
        end
    end)
    
    -- Aimbot hotkey handler (global) - REMOVED, now using InputBegan/InputEnded tracking
    
    -- ESP update loop (MUCH less frequent to prevent lag)
    task.spawn(function()
        while task.wait(1) do -- Check every 1 second for chams
            if not ScriptEnabled then break end
            pcall(function()
                if Config.PlayerESP or Config.BoxESP or Config.DistanceESP or Config.TracerESP then
                    -- Only create ESP, don't update every frame
                    for _, player in pairs(Players:GetPlayers()) do
                        if player ~= Player and not ESPDrawings[player] then
                            createDrawingESP(player)
                        end
                    end
                end
                if Config.Chams then
                    -- Force update chams for ALL players
                    for _, player in pairs(Players:GetPlayers()) do
                        if player ~= Player and player.Character then
                            if not player.Character:FindFirstChild("DreamChams") then
                                createChams(player.Character)
                            end
                        end
                    end
                end
            end)
        end
    end)
    
    -- ESP rendering loop - smooth updates using RenderStepped
    RunService.RenderStepped:Connect(function()
        if not ScriptEnabled then return end
        if Config.PlayerESP or Config.BoxESP or Config.DistanceESP or Config.TracerESP then
            updateDrawingESP()
        end
    end)
    
    -- Weapon ESP update (less frequent)
    task.spawn(function()
        while task.wait(3) do
            pcall(function()
                if Config.WeaponESP then
                    updateWeaponESP()
                end
            end)
        end
    end)
    
    -- Force ESP creation on player join
    Players.PlayerAdded:Connect(function(player)
        task.wait(1)
        if Config.PlayerESP or Config.BoxESP or Config.DistanceESP or Config.TracerESP then
            if not ESPDrawings[player] then
                createDrawingESP(player)
            end
        end
        
        player.CharacterAdded:Connect(function(character)
            task.wait(1)
            if Config.Chams then
                createChams(character)
            end
            if Config.PlayerESP or Config.BoxESP or Config.DistanceESP or Config.TracerESP then
                if not ESPDrawings[player] then
                    createDrawingESP(player)
                end
            end
        end)
    end)
    
    -- Infinite Jump
    UserInputService.JumpRequest:Connect(function()
        if Config.InfiniteJump and Humanoid then
            Humanoid:ChangeState(Enum.HumanoidStateType.Jumping)
        end
    end)
    
    Players.PlayerRemoving:Connect(function(player)
        if ESPDrawings[player] then
            for _, drawing in pairs(ESPDrawings[player]) do
                pcall(function()
                    if drawing and drawing.Remove then
                        drawing:Remove()
                    end
                end)
            end
            ESPDrawings[player] = nil
        end
    end)
end


-- Character Setup
local function setupCharacter(char)
    Character = char
    Humanoid = char:WaitForChild("Humanoid")
    HumanoidRootPart = char:WaitForChild("HumanoidRootPart")
    
    -- Apply current settings
    task.wait(0.5) -- Wait for character to fully load
    
    if Humanoid then
        Humanoid.WalkSpeed = Config.WalkSpeed
        Humanoid.JumpPower = Config.JumpPower
    end
    
    -- Reapply features that need character
    if Config.NoClip then
        toggleNoClip(true)
    end
    if Config.Fly then
        toggleFly(true)
    end
    
    -- Force ESP update when entering new game
    task.wait(1)
    if Config.PlayerESP or Config.BoxESP or Config.DistanceESP or Config.TracerESP then
        -- Clear old ESP
        for player, drawings in pairs(ESPDrawings) do
            for _, drawing in pairs(drawings) do
                pcall(function()
                    if drawing and drawing.Remove then
                        drawing:Remove()
                    end
                end)
            end
        end
        ESPDrawings = {}
        
        -- Create new ESP for all players
        for _, player in pairs(Players:GetPlayers()) do
            if player ~= Player then
                createDrawingESP(player)
            end
        end
    end
    
    notify("Character Loaded - Settings Applied")
end

Player.CharacterAdded:Connect(function(char)
    setupCharacter(char)
end)

if Character then
    task.spawn(function()
        setupCharacter(Character)
    end)
end

-- GUI Persistence Check - Aggressive monitoring
task.spawn(function()
    while task.wait(0.5) do
        -- Only run if script is enabled
        if not ScriptEnabled then
            break
        end
        
        pcall(function()
            local gui = playerGui:FindFirstChild("DreamRivalsGUI")
            
            -- If GUI is missing, recreate it immediately
            if not gui then
                warn("[Dream Rivals] GUI was removed! Recreating...")
                setupGUI()
                
                -- Reapply all settings
                task.wait(0.5)
                for configKey, data in pairs(ToggleReferences) do
                    if Config[configKey] == true and data.callback then
                        pcall(function()
                            data.callback(true)
                        end)
                    end
                end
                
                notify("GUI Restored!")
            else
                -- Ensure properties are correct
                gui.ResetOnSpawn = false
                gui.DisplayOrder = 100
            end
        end)
    end
end)

-- Teleport persistence - Save and monitor
task.spawn(function()
    while task.wait(1) do
        -- Only run if script is enabled
        if not ScriptEnabled then
            break
        end
        
        pcall(function()
            -- Continuously save config during gameplay
            if tick() % 60 < 1 then -- Every 60 seconds
                saveConfig()
            end
            
            -- Check GUI exists
            local gui = playerGui:FindFirstChild("DreamRivalsGUI")
            if not gui then
                setupGUI()
                task.wait(0.5)
                -- Reapply features
                for configKey, data in pairs(ToggleReferences) do
                    if Config[configKey] == true and data.callback then
                        pcall(function()
                            data.callback(true)
                        end)
                    end
                end
            end
        end)
    end
end)

-- Initialize
print("=================================")
print("Dream Rivals Script Loaded")
print("=================================")
print("Features:")
print("- Movement: Walk Speed, Jump Power, NoClip, Fly, Infinite Jump")
print("- ESP: Name, Box, Distance, Tracers, Chams, Weapon ESP")
print("- Visuals: Full Bright, Remove Fog")
print("- Auto: Claim Rewards, Join Queue, Rematch, Vote, Anti-AFK")
print("- Combat: Aimbot, Hitbox Expander")
print("- Matchmaking: Auto Accept Party, Auto Play Again, Queue Controls")
print("- Duels: Leave, Rematch, Respawn, Switch Team, Vote Maps")
print("- Shop: Refresh Shop, Equip Cosmetics")
print("- Teleport: Player TP, Location TP")
print("- Misc: Spam Ping, Emotes, Code Redemption")
print("- Config: Auto-save, Load, Reset")
print("=================================")
print("Press INSERT to toggle menu")
print("=================================")

-- Load saved config
local configLoaded = loadConfig()
if configLoaded then
    print("[Dream Rivals] Config loaded from file")
else
    print("[Dream Rivals] Using default config")
end

setupGUI()
startMainLoops()
autoSaveConfig()

-- Update keybind button with loaded config value
if KeybindButtonRef then
    KeybindButtonRef.Text = getAimbotKeyDisplayName()
    print("[Dream Rivals] Keybind button updated to: " .. getAimbotKeyDisplayName())
end

-- Apply loaded settings and trigger callbacks
task.wait(0.5)
for configKey, data in pairs(ToggleReferences) do
    if Config[configKey] ~= nil and typeof(Config[configKey]) == "boolean" then
        local button = data.button
        local callback = data.callback
        
        button.BackgroundColor3 = Config[configKey] and Color3.fromRGB(50, 180, 100) or Color3.fromRGB(180, 50, 50)
        button.Text = Config[configKey] and "ON" or "OFF"
        
        -- Trigger callback if feature is enabled
        if Config[configKey] and callback then
            pcall(function()
                callback(true)
            end)
        end
    end
end

-- Apply movement settings
if Humanoid then
    Humanoid.WalkSpeed = Config.WalkSpeed
    Humanoid.JumpPower = Config.JumpPower
end

notify("Dream Rivals Script Loaded!")
if configLoaded then
    notify("Previous config restored!")
end

print("[Dream Rivals] GUI persistence enabled - checking every 0.5s")
