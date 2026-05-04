-- ============================================
-- Ghost Hunter ESP - Streamlined v4.1 (Teleport to Van)
-- ============================================

local repo = "https://raw.githubusercontent.com/deividcomsono/Obsidian/main/"
local Library = loadstring(game:HttpGet(repo .. "Library.lua"))()
local ThemeManager = loadstring(game:HttpGet(repo .. "addons/ThemeManager.lua"))()
local SaveManager = loadstring(game:HttpGet(repo .. "addons/SaveManager.lua"))()

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")
local Lighting = game:GetService("Lighting")
local UserInputService = game:GetService("UserInputService")
local ContextActionService = game:GetService("ContextActionService")

local LocalPlayer = Players.LocalPlayer
local Options = Library.Options

-- ============================================
-- CONFIG
-- ============================================

local CONFIG = {
    GhostColor = Color3.fromRGB(255, 0, 0),
    PlayerColor = Color3.fromRGB(0, 255, 0),
    EvidenceColors = {
        EMF5 = Color3.fromRGB(255, 0, 0),
        Fingerprints = Color3.fromRGB(0, 255, 255),
        Orbs = Color3.fromRGB(255, 255, 0),
    },
    FlySpeed = 50,
    MaxDistance = 500,
}

-- ============================================
-- UTILS
-- ============================================

local function Notify(title, desc)
    Library:Notify({ Title = title, Description = desc, Time = 3 })
end

local function GetHRP(char)
    return char and char:FindFirstChild("HumanoidRootPart")
end

local function GetDistance(pos)
    local hrp = GetHRP(LocalPlayer.Character)
    return hrp and (hrp.Position - pos).Magnitude or math.huge
end

local function CreateHighlight(parent, color, fillTrans)
    local hl = Instance.new("Highlight")
    hl.FillColor = color
    hl.OutlineColor = Color3.fromRGB(255, 255, 255)
    hl.FillTransparency = fillTrans or 0.3
    hl.OutlineTransparency = 0
    hl.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
    hl.Adornee = parent
    hl.Parent = parent
    return hl
end

local function CreateBillboard(parent, color)
    local bb = Instance.new("BillboardGui")
    bb.Size = UDim2.new(0, 200, 0, 50)
    bb.StudsOffset = Vector3.new(0, 4, 0)
    bb.AlwaysOnTop = true
    bb.Adornee = parent
    bb.Parent = parent

    local tl = Instance.new("TextLabel")
    tl.Size = UDim2.new(1, 0, 1, 0)
    tl.BackgroundTransparency = 1
    tl.TextColor3 = color
    tl.TextStrokeTransparency = 0
    tl.TextStrokeColor3 = Color3.fromRGB(0, 0, 0)
    tl.Font = Enum.Font.GothamBold
    tl.TextSize = 14
    tl.Text = ""
    tl.Parent = bb
    return bb, tl
end

-- ============================================
-- GHOST ESP
-- ============================================

local GhostESP = {
    Enabled = false,
    Highlight = nil,
    Billboard = nil,
    TextLabel = nil,
    GhostModel = nil,
    ShowDistance = true,
}

local function FindGhostModel()
    local npcs = Workspace:FindFirstChild("NPCs")
    if not npcs then return nil end
    local global = npcs:FindFirstChild("GLOBAL")
    return global
end

local function GetGhostBasePart(model)
    if not model then return nil end
    if model:IsA("BasePart") then return model end
    return model:FindFirstChildWhichIsA("BasePart") or model:FindFirstChild("HumanoidRootPart") or model:FindFirstChild("Base")
end

local function UpdateGhostLabel()
    if not GhostESP.Billboard or not GhostESP.GhostModel then return end
    local base = GetGhostBasePart(GhostESP.GhostModel)
    if not base then return end
    local dist = GetDistance(base.Position)
    local text = "GHOST"
    if GhostESP.ShowDistance then
        text = text .. string.format("\n[%.1f studs]", dist)
    end
    GhostESP.TextLabel.Text = text
end

local function StartGhostESP()
    local model = FindGhostModel()
    if not model then
        Notify("Ghost ESP", "Ghost not found!")
        return
    end

    GhostESP.GhostModel = model
    local base = GetGhostBasePart(model)

    for _, part in pairs(model:GetDescendants()) do
        if part:IsA("BasePart") then
            part.Transparency = 0
        end
    end

    GhostESP.Highlight = CreateHighlight(model, CONFIG.GhostColor, 0)
    local bb, tl = CreateBillboard(base or model, CONFIG.GhostColor)
    GhostESP.Billboard = bb
    GhostESP.TextLabel = tl

    local conn = RunService.Heartbeat:Connect(function()
        if not model.Parent then
            StopGhostESP()
            return
        end
        for _, part in pairs(model:GetDescendants()) do
            if part:IsA("BasePart") and part.Transparency > 0 then
                part.Transparency = 0
            end
        end
    end)
    GhostESP.HeartbeatConn = conn

    task.spawn(function()
        while GhostESP.Enabled and model.Parent do
            UpdateGhostLabel()
            task.wait(0.5)
        end
    end)

    Notify("Ghost ESP", "Enabled!")
end

local function StopGhostESP()
    GhostESP.Enabled = false
    if GhostESP.HeartbeatConn then GhostESP.HeartbeatConn:Disconnect() end
    if GhostESP.Highlight then GhostESP.Highlight:Destroy() end
    if GhostESP.Billboard then GhostESP.Billboard:Destroy() end
    GhostESP.Highlight, GhostESP.Billboard, GhostESP.TextLabel, GhostESP.GhostModel = nil, nil, nil, nil
end

local function ToggleGhostESP(enabled)
    GhostESP.Enabled = enabled
    if enabled then StartGhostESP() else StopGhostESP() end
end

-- ============================================
-- EVIDENCE ESP
-- ============================================

local EvidenceESP = {
    Enabled = false,
    Items = {},
    FolderConns = {},
}

local function GetEvidenceFolder()
    local dynamic = Workspace:FindFirstChild("Dynamic")
    return dynamic and dynamic:FindFirstChild("Evidence")
end

local function ClearEvidenceESP()
    for _, data in pairs(EvidenceESP.Items) do
        if data.Highlight then data.Highlight:Destroy() end
        if data.Billboard then data.Billboard:Destroy() end
        if data.Conn then data.Conn:Disconnect() end
    end
    EvidenceESP.Items = {}
    for _, conn in pairs(EvidenceESP.FolderConns) do
        conn:Disconnect()
    end
    EvidenceESP.FolderConns = {}
end

local function AddEvidenceItem(item, name, color)
    if EvidenceESP.Items[item] then return end

    local target = item:IsA("BasePart") and item or item:FindFirstChildWhichIsA("BasePart")
    if not target then return end

    local hl = CreateHighlight(item, color, 0.3)
    local bb, tl = CreateBillboard(target, color)
    tl.Text = name

    local lastUpdate = 0
    local conn = RunService.Heartbeat:Connect(function()
        if tick() - lastUpdate < 0.5 then return end
        lastUpdate = tick()
        if not target.Parent then
            hl:Destroy()
            bb:Destroy()
            EvidenceESP.Items[item] = nil
            return
        end
        local dist = GetDistance(target.Position)
        tl.Text = string.format("%s\n[%.1f studs]", name, dist)
    end)

    EvidenceESP.Items[item] = {
        Highlight = hl,
        Billboard = bb,
        Conn = conn,
    }
end

local function ScanEvidence()
    ClearEvidenceESP()
    local evidence = GetEvidenceFolder()
    if not evidence then return end

    local function ScanFolder(folder, name, color)
        for _, child in pairs(folder:GetChildren()) do
            AddEvidenceItem(child, name, color)
        end
        local conn = folder.ChildAdded:Connect(function(child)
            if EvidenceESP.Enabled then
                AddEvidenceItem(child, name, color)
            end
        end)
        table.insert(EvidenceESP.FolderConns, conn)
    end

    for _, folder in pairs(evidence:GetChildren()) do
        if folder.Name:lower():find("emf") then
            ScanFolder(folder, "EMF 5", CONFIG.EvidenceColors.EMF5)
        end
    end

    local fp = evidence:FindFirstChild("Fingerprints")
    if fp then ScanFolder(fp, "FINGERPRINT", CONFIG.EvidenceColors.Fingerprints) end

    local orbs = evidence:FindFirstChild("Orbs")
    if orbs then ScanFolder(orbs, "ORB", CONFIG.EvidenceColors.Orbs) end
end

local function ToggleEvidenceESP(enabled)
    EvidenceESP.Enabled = enabled
    if enabled then
        ScanEvidence()
        Notify("Evidence ESP", "Enabled!")
    else
        ClearEvidenceESP()
        Notify("Evidence ESP", "Disabled!")
    end
end

-- ============================================
-- ITEMS ESP
-- ============================================

local ItemsESP = {
    Enabled = false,
    Items = {},
    Conns = {},
}

local function ClearItemsESP()
    for _, data in pairs(ItemsESP.Items) do
        if data.Highlight then data.Highlight:Destroy() end
        if data.Billboard then data.Billboard:Destroy() end
        if data.Conn then data.Conn:Disconnect() end
    end
    ItemsESP.Items = {}
    for _, conn in pairs(ItemsESP.Conns) do
        conn:Disconnect()
    end
    ItemsESP.Conns = {}
end

local function GetItemColor(name)
    local n = name:lower()
    if n:find("emf") then return Color3.fromRGB(255, 0, 0)
    elseif n:find("book") then return Color3.fromRGB(139, 69, 19)
    elseif n:find("crucifix") then return Color3.fromRGB(255, 215, 0)
    elseif n:find("goggle") then return Color3.fromRGB(0, 255, 255)
    elseif n:find("motion") then return Color3.fromRGB(255, 165, 0)
    elseif n:find("spirit") then return Color3.fromRGB(128, 0, 128)
    elseif n:find("thermo") then return Color3.fromRGB(0, 191, 255)
    else return Color3.fromRGB(255, 255, 255) end
end

local function AddItemESP(item, folder)
    if ItemsESP.Items[item] then return end

    local target = item:IsA("BasePart") and item or item:FindFirstChildWhichIsA("BasePart")
    if not target then return end

    local color = GetItemColor(item.Name)
    local hl = CreateHighlight(item, color, 0.3)
    local bb, tl = CreateBillboard(target, color)

    local lastUpdate = 0
    local conn = RunService.Heartbeat:Connect(function()
        if tick() - lastUpdate < 0.5 then return end
        lastUpdate = tick()
        if not target.Parent or not item.Parent then
            hl:Destroy(); bb:Destroy()
            ItemsESP.Items[item] = nil
            return
        end
        local dist = GetDistance(target.Position)
        tl.Text = string.format("%s\n[%.1f studs]", item.Name:upper(), dist)
    end)

    ItemsESP.Items[item] = {
        Highlight = hl,
        Billboard = bb,
        Conn = conn,
    }
end

local function WatchFolder(folder)
    if not folder then return end
    for _, item in pairs(folder:GetChildren()) do
        AddItemESP(item, folder)
    end
    local conn = folder.ChildAdded:Connect(function(child)
        if ItemsESP.Enabled then AddItemESP(child, folder) end
    end)
    table.insert(ItemsESP.Conns, conn)
end

local function ScanItems()
    ClearItemsESP()
    local van = Workspace:FindFirstChild("Van")
    if van then WatchFolder(van:FindFirstChild("Equipment")) end
    WatchFolder(Workspace:FindFirstChild("Equipment"))
end

local function ToggleItemsESP(enabled)
    ItemsESP.Enabled = enabled
    if enabled then
        ScanItems()
        Notify("Items ESP", "Enabled!")
    else
        ClearItemsESP()
        Notify("Items ESP", "Disabled!")
    end
end

-- ============================================
-- PLAYER ESP
-- ============================================

local PlayerESP = {
    Enabled = false,
    Players = {},
    MaxDistance = 500,
    ShowName = true,
    ShowHealth = true,
    ShowDistance = true,
}

local function ClearPlayerESP()
    for _, data in pairs(PlayerESP.Players) do
        if data.Highlight then data.Highlight:Destroy() end
        if data.Billboard then data.Billboard:Destroy() end
        if data.Conn then data.Conn:Disconnect() end
    end
    PlayerESP.Players = {}
end

local function RemovePlayerESP(player)
    local data = PlayerESP.Players[player]
    if not data then return end
    if data.Highlight then data.Highlight:Destroy() end
    if data.Billboard then data.Billboard:Destroy() end
    if data.Conn then data.Conn:Disconnect() end
    PlayerESP.Players[player] = nil
end

local function AddPlayerESP(player)
    if player == LocalPlayer then return end
    if PlayerESP.Players[player] then return end

    local function Setup(char)
        local hrp = char:WaitForChild("HumanoidRootPart", 3)
        local humanoid = char:WaitForChild("Humanoid", 3)
        if not hrp or not humanoid then return end

        RemovePlayerESP(player)

        local hl = CreateHighlight(char, CONFIG.PlayerColor, 0.5)
        local bb, tl = CreateBillboard(hrp, CONFIG.PlayerColor)

        local data = { Highlight = hl, Billboard = bb, Conn = nil }

        local lastUpdate = 0
        data.Conn = RunService.Heartbeat:Connect(function()
            if tick() - lastUpdate < 0.5 then return end
            lastUpdate = tick()
            if not hrp.Parent then
                RemovePlayerESP(player)
                return
            end

            local dist = GetDistance(hrp.Position)
            if dist > PlayerESP.MaxDistance then
                hl.Enabled = false
                bb.Enabled = false
                return
            end
            hl.Enabled = true
            bb.Enabled = true

            local parts = {}
            if PlayerESP.ShowName then table.insert(parts, player.Name) end
            if PlayerESP.ShowHealth then table.insert(parts, string.format("[%.0f HP]", humanoid.Health)) end
            if PlayerESP.ShowDistance then table.insert(parts, string.format("[%.1f studs]", dist)) end
            tl.Text = table.concat(parts, "\n")
        end)

        PlayerESP.Players[player] = data

        humanoid.Died:Once(function()
            RemovePlayerESP(player)
        end)
    end

    if player.Character then Setup(player.Character) end
    player.CharacterAdded:Connect(function(char)
        if PlayerESP.Enabled then task.delay(0.5, function() Setup(char) end) end
    end)
    player.CharacterRemoving:Connect(function()
        RemovePlayerESP(player)
    end)
end

local function TogglePlayerESP(enabled)
    PlayerESP.Enabled = enabled
    if enabled then
        for _, p in pairs(Players:GetPlayers()) do AddPlayerESP(p) end
        Notify("Player ESP", "Enabled!")
    else
        ClearPlayerESP()
        Notify("Player ESP", "Disabled!")
    end
end

-- ============================================
-- FULLBRIGHT
-- ============================================

local FullBright = {
    Enabled = false,
    Original = {},
    Conn = nil,
}

local function EnableFullBright()
    FullBright.Original = {
        Brightness = Lighting.Brightness,
        ClockTime = Lighting.ClockTime,
        FogEnd = Lighting.FogEnd,
        GlobalShadows = Lighting.GlobalShadows,
        OutdoorAmbient = Lighting.OutdoorAmbient,
    }

    Lighting.Brightness = 2
    Lighting.ClockTime = 14
    Lighting.FogEnd = 100000
    Lighting.GlobalShadows = false
    Lighting.OutdoorAmbient = Color3.fromRGB(128, 128, 128)

    FullBright.Conn = Lighting.Changed:Connect(function(prop)
        if not FullBright.Enabled then return end
        if prop == "Brightness" and Lighting.Brightness ~= 2 then Lighting.Brightness = 2
        elseif prop == "ClockTime" and Lighting.ClockTime ~= 14 then Lighting.ClockTime = 14
        elseif prop == "FogEnd" and Lighting.FogEnd ~= 100000 then Lighting.FogEnd = 100000
        elseif prop == "GlobalShadows" and Lighting.GlobalShadows ~= false then Lighting.GlobalShadows = false end
    end)
end

local function DisableFullBright()
    if FullBright.Conn then FullBright.Conn:Disconnect() end
    for prop, val in pairs(FullBright.Original) do
        Lighting[prop] = val
    end
end

local function ToggleFullBright(enabled)
    FullBright.Enabled = enabled
    if enabled then EnableFullBright() else DisableFullBright() end
    Notify("FullBright", enabled and "Enabled!" or "Disabled!")
end

-- ============================================
-- WALKSPEED - FIXED
-- ============================================

local WalkSpeed = {
    Enabled = false,
    Conn = nil,
    TargetSpeed = 16,
}

local function ToggleWalkSpeed(enabled, speed)
    WalkSpeed.Enabled = enabled
    if speed then WalkSpeed.TargetSpeed = speed end

    if enabled then
        WalkSpeed.Conn = RunService.Heartbeat:Connect(function()
            local char = LocalPlayer.Character
            if not char then return end
            local hrp = char:FindFirstChild("HumanoidRootPart")
            local humanoid = char:FindFirstChildOfClass("Humanoid")
            if not hrp or not humanoid then return end

            local moveDir = humanoid.MoveDirection
            if moveDir.Magnitude < 0.1 then return end

            local currentSpeed = humanoid.WalkSpeed
            local targetSpeed = WalkSpeed.TargetSpeed

            if targetSpeed > currentSpeed then
                local extraSpeed = targetSpeed - currentSpeed
                local velocity = moveDir * extraSpeed * 0.016
                hrp.CFrame = hrp.CFrame + Vector3.new(velocity.X, 0, velocity.Z)
            end
        end)
        Notify("WalkSpeed", "Enabled! Speed: " .. tostring(WalkSpeed.TargetSpeed))
    else
        if WalkSpeed.Conn then WalkSpeed.Conn:Disconnect() end
        WalkSpeed.Conn = nil
        Notify("WalkSpeed", "Disabled!")
    end
end

-- ============================================
-- QFLY - OLD TECHNIQUE (ContextActionService)
-- ============================================

local QFly = {
    Enabled = false,
    Connection = nil,
    BodyGyro = nil,
    BodyVelocity = nil,
    FlyKey = Enum.KeyCode.Q,
    ForwardBack = 0,
    LeftRight = 0,
    UpDown = 0,
    Speed = 50,
}

local function GetCamera()
    return Workspace.CurrentCamera
end

local function BindFlyControls()
    ContextActionService:BindAction("FlyForward", function(actionName, inputState, inputObj)
        if inputState == Enum.UserInputState.Begin then
            QFly.ForwardBack = -1
        elseif inputState == Enum.UserInputState.End then
            if not UserInputService:IsKeyDown(Enum.KeyCode.W) then
                QFly.ForwardBack = 0
            else
                QFly.ForwardBack = 1
            end
        end
        return Enum.ContextActionResult.Sink
    end, false, Enum.KeyCode.S, Enum.KeyCode.Down)

    ContextActionService:BindAction("FlyBack", function(actionName, inputState, inputObj)
        if inputState == Enum.UserInputState.Begin then
            QFly.ForwardBack = 1
        elseif inputState == Enum.UserInputState.End then
            if not UserInputService:IsKeyDown(Enum.KeyCode.S) then
                QFly.ForwardBack = 0
            else
                QFly.ForwardBack = -1
            end
        end
        return Enum.ContextActionResult.Sink
    end, false, Enum.KeyCode.W, Enum.KeyCode.Up)

    ContextActionService:BindAction("FlyLeft", function(actionName, inputState, inputObj)
        if inputState == Enum.UserInputState.Begin then
            QFly.LeftRight = -1
        elseif inputState == Enum.UserInputState.End then
            if not UserInputService:IsKeyDown(Enum.KeyCode.D) then
                QFly.LeftRight = 0
            else
                QFly.LeftRight = 1
            end
        end
        return Enum.ContextActionResult.Sink
    end, false, Enum.KeyCode.A, Enum.KeyCode.Left)

    ContextActionService:BindAction("FlyRight", function(actionName, inputState, inputObj)
        if inputState == Enum.UserInputState.Begin then
            QFly.LeftRight = 1
        elseif inputState == Enum.UserInputState.End then
            if not UserInputService:IsKeyDown(Enum.KeyCode.A) then
                QFly.LeftRight = 0
            else
                QFly.LeftRight = -1
            end
        end
        return Enum.ContextActionResult.Sink
    end, false, Enum.KeyCode.D, Enum.KeyCode.Right)

    ContextActionService:BindAction("FlyUp", function(actionName, inputState, inputObj)
        if inputState == Enum.UserInputState.Begin then
            QFly.UpDown = 1
        elseif inputState == Enum.UserInputState.End then
            if not UserInputService:IsKeyDown(Enum.KeyCode.LeftShift) and not UserInputService:IsKeyDown(Enum.KeyCode.RightShift) then
                QFly.UpDown = 0
            else
                QFly.UpDown = -1
            end
        end
        return Enum.ContextActionResult.Sink
    end, false, Enum.KeyCode.Space)

    ContextActionService:BindAction("FlyDown", function(actionName, inputState, inputObj)
        if inputState == Enum.UserInputState.Begin then
            QFly.UpDown = -1
        elseif inputState == Enum.UserInputState.End then
            if not UserInputService:IsKeyDown(Enum.KeyCode.Space) then
                QFly.UpDown = 0
            else
                QFly.UpDown = 1
            end
        end
        return Enum.ContextActionResult.Sink
    end, false, Enum.KeyCode.LeftShift, Enum.KeyCode.RightShift)
end

local function UnbindFlyControls()
    ContextActionService:UnbindAction("FlyForward")
    ContextActionService:UnbindAction("FlyBack")
    ContextActionService:UnbindAction("FlyLeft")
    ContextActionService:UnbindAction("FlyRight")
    ContextActionService:UnbindAction("FlyUp")
    ContextActionService:UnbindAction("FlyDown")

    QFly.ForwardBack = 0
    QFly.LeftRight = 0
    QFly.UpDown = 0
end

local function StartQFly()
    local char = LocalPlayer.Character
    if not char then return end
    local hrp = char:FindFirstChild("HumanoidRootPart")
    local humanoid = char:FindFirstChildOfClass("Humanoid")
    if not hrp or not humanoid then return end

    humanoid.PlatformStand = true
    humanoid.AutoRotate = false

    QFly.BodyGyro = Instance.new("BodyGyro")
    QFly.BodyGyro.Name = "QFly_Gyro"
    QFly.BodyGyro.P = 9e4
    QFly.BodyGyro.D = 500
    QFly.BodyGyro.MaxTorque = Vector3.new(9e9, 9e9, 9e9)
    QFly.BodyGyro.CFrame = hrp.CFrame
    QFly.BodyGyro.Parent = hrp

    QFly.BodyVelocity = Instance.new("BodyVelocity")
    QFly.BodyVelocity.Name = "QFly_Velocity"
    QFly.BodyVelocity.Velocity = Vector3.zero
    QFly.BodyVelocity.MaxForce = Vector3.new(9e9, 9e9, 9e9)
    QFly.BodyVelocity.P = 12500
    QFly.BodyVelocity.Parent = hrp

    BindFlyControls()

    QFly.Connection = RunService.RenderStepped:Connect(function()
        local hrp = LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("HumanoidRootPart")
        local humanoid = LocalPlayer.Character and LocalPlayer.Character:FindFirstChildOfClass("Humanoid")
        if not hrp or not humanoid then
            StopQFly()
            return
        end

        local camera = GetCamera()
        local flySpeed = QFly.Speed

        local camCF = camera.CFrame
        local camLook = camCF.LookVector
        local camRight = camCF.RightVector
        local camUp = Vector3.new(0, 1, 0)

        local fb = QFly.ForwardBack
        local lr = QFly.LeftRight
        local ud = QFly.UpDown

        local moveDir = humanoid.MoveDirection

        if moveDir.Magnitude > 0.1 then
            local flatLook = Vector3.new(camLook.X, 0, camLook.Z).Unit
            local flatRight = Vector3.new(camRight.X, 0, camRight.Z).Unit

            if flatLook.Magnitude > 0.1 and flatRight.Magnitude > 0.1 then
                fb = moveDir:Dot(flatLook)
                lr = moveDir:Dot(flatRight)
            end
        end

        local velocity = Vector3.zero

        if math.abs(fb) > 0.1 then
            velocity = velocity + (camLook * fb * flySpeed)
        end

        if math.abs(lr) > 0.1 then
            velocity = velocity + (camRight * lr * flySpeed)
        end

        if math.abs(ud) > 0.1 then
            velocity = velocity + (camUp * ud * flySpeed)
        end

        if velocity.Magnitude < 0.1 then
            velocity = Vector3.new(0, 0.1, 0)
        end

        QFly.BodyVelocity.Velocity = velocity
        QFly.BodyGyro.CFrame = CFrame.new(hrp.Position, hrp.Position + camLook)
    end)

    Notify("QFly", "Flight enabled! Press Q or button to toggle.")
end

local function StopQFly()
    if QFly.Connection then
        QFly.Connection:Disconnect()
        QFly.Connection = nil
    end
    if QFly.BodyGyro then
        QFly.BodyGyro:Destroy()
        QFly.BodyGyro = nil
    end
    if QFly.BodyVelocity then
        QFly.BodyVelocity:Destroy()
        QFly.BodyVelocity = nil
    end

    UnbindFlyControls()

    local char = LocalPlayer.Character
    if char then
        local humanoid = char:FindFirstChildOfClass("Humanoid")
        if humanoid then
            humanoid.PlatformStand = false
            humanoid.AutoRotate = true
        end
    end

    Notify("QFly", "Flight disabled!")
end

local function ToggleQFly()
    QFly.Enabled = not QFly.Enabled
    if QFly.Enabled then
        StartQFly()
    else
        StopQFly()
    end
end

UserInputService.InputBegan:Connect(function(input, gameProcessed)
    if not gameProcessed and input.KeyCode == QFly.FlyKey then
        ToggleQFly()
    end
end)

-- ============================================
-- NOCLIP
-- ============================================

local Noclip = {
    Enabled = false,
    Conn = nil,
}

local function ToggleNoclip(enabled)
    Noclip.Enabled = enabled
    if enabled then
        Noclip.Conn = RunService.Stepped:Connect(function()
            local char = LocalPlayer.Character
            if not char then return end
            for _, part in pairs(char:GetDescendants()) do
                if part:IsA("BasePart") then part.CanCollide = false end
            end
        end)
        Notify("Noclip", "Enabled!")
    else
        if Noclip.Conn then Noclip.Conn:Disconnect() end
        local char = LocalPlayer.Character
        if char then
            for _, part in pairs(char:GetDescendants()) do
                if part:IsA("BasePart") then part.CanCollide = true end
            end
        end
        Notify("Noclip", "Disabled!")
    end
end

-- ============================================
-- GHOST SENSOR
-- ============================================

local GhostTrigger = {
    SavedPos = nil,
    HoldConn = nil,
}

local function GetGhost()
    local npcs = Workspace:FindFirstChild("NPCs")
    local global = npcs and npcs:FindFirstChild("GLOBAL")
    if not global then return nil end
    return global, global:FindFirstChild("HumanoidRootPart"), global:FindFirstChildOfClass("Humanoid")
end

local function StopGhostHold()
    if GhostTrigger.HoldConn then GhostTrigger.HoldConn:Disconnect(); GhostTrigger.HoldConn = nil end
end

local function TeleportGhostToSensor()
    local ghost, hrp, hum = GetGhost()
    if not ghost then Notify("Ghost", "Not found!"); return end

    local sensor = nil
    local nearDist = math.huge
    local playerHRP = GetHRP(LocalPlayer.Character)
    if not playerHRP then return end

    local equip = Workspace:FindFirstChild("Equipment")
    if equip then
        for _, item in pairs(equip:GetChildren()) do
            if item.Name:lower():find("motion") then
                local part = item:IsA("BasePart") and item or item:FindFirstChildWhichIsA("BasePart")
                if part then
                    local d = (playerHRP.Position - part.Position).Magnitude
                    if d < nearDist then nearDist = d; sensor = part.Position end
                end
            end
        end
    end

    if not sensor then Notify("Ghost", "No motion sensor!"); return end

    StopGhostHold()
    if hum then hum.PlatformStand = true; hum.AutoRotate = false end

    local cf = CFrame.new(sensor)
    for _, part in pairs(ghost:GetDescendants()) do
        if part:IsA("BasePart") then part.CFrame = cf end
    end

    local start = tick()
    GhostTrigger.HoldConn = RunService.Heartbeat:Connect(function()
        if tick() - start >= 0.5 then
            StopGhostHold()
            if hum then hum.PlatformStand = false; hum.AutoRotate = true end
            return
        end
        for _, part in pairs(ghost:GetDescendants()) do
            if part:IsA("BasePart") then part.CFrame = cf end
        end
    end)

    Notify("Ghost", "Teleported to sensor!")
end

local function SaveGhostPos()
    local _, hrp = GetGhost()
    if not hrp then Notify("Ghost", "Not found!"); return end
    GhostTrigger.SavedPos = hrp.CFrame
    Notify("Ghost", "Position saved!")
end

local function ReturnGhostPos()
    if not GhostTrigger.SavedPos then Notify("Ghost", "No saved pos!"); return end
    local ghost, hrp, hum = GetGhost()
    if not ghost then Notify("Ghost", "Not found!"); return end

    StopGhostHold()
    if hum then hum.PlatformStand = true; hum.AutoRotate = false end

    local cf = GhostTrigger.SavedPos
    for _, part in pairs(ghost:GetDescendants()) do
        if part:IsA("BasePart") then part.CFrame = cf end
    end

    local start = tick()
    GhostTrigger.HoldConn = RunService.Heartbeat:Connect(function()
        if tick() - start >= 0.5 then
            StopGhostHold()
            if hum then hum.PlatformStand = false; hum.AutoRotate = true end
            GhostTrigger.SavedPos = nil
            return
        end
        for _, part in pairs(ghost:GetDescendants()) do
            if part:IsA("BasePart") then part.CFrame = cf end
        end
    end)

    Notify("Ghost", "Returned to saved pos!")
end

-- ============================================
-- GHOST ROOM FINDER (Integrated into Main Tab)
-- ============================================

local GhostRoomFinder = {
    Enabled = false,
    Rooms = {},
    IsTeleporting = false,
    CurrentRoomIndex = 0,
    GhostRoomCFrame = nil,
    TeleportConnection = nil,
    EMFConnection = nil,
    StatusLabel = nil,
    CurrentRoomLabel = nil,
    EMFStatusLabel = nil,
    GhostRoomBtn = nil,
}

local function GetRooms()
    local map = Workspace:FindFirstChild("Map")
    if not map then return {} end
    local roomsFolder = map:FindFirstChild("Rooms")
    if not roomsFolder then return {} end

    local roomTable = {}
    for _, room in pairs(roomsFolder:GetChildren()) do
        if room:IsA("Folder") or room:IsA("Model") then
            local hitbox = room:FindFirstChild("Hitbox")
            if hitbox and hitbox:IsA("BasePart") then
                table.insert(roomTable, {
                    Name = room.Name,
                    Hitbox = hitbox,
                    CFrame = hitbox.CFrame
                })
            end
        end
    end
    return roomTable
end

local function CheckEMF2()
    local playerModel = Workspace:FindFirstChild(LocalPlayer.Name)
    if not playerModel then return false end

    local equipmentModel = playerModel:FindFirstChild("EquipmentModel")
    if not equipmentModel then return false end

    local emfPart = equipmentModel:FindFirstChild("2")
    if not emfPart then return false end

    if emfPart:IsA("BasePart") or emfPart:IsA("MeshPart") then
        local color = emfPart.Color
        local material = emfPart.Material

        local isLemonColor = (math.abs(color.R - 131/255) < 0.05 and
                             math.abs(color.G - 156/255) < 0.05 and
                             math.abs(color.B - 49/255) < 0.05)

        local isLemonBrick = (emfPart.BrickColor.Name == "Lemon metalic" or
                             emfPart.BrickColor.Name == "Lemon metallic")

        local isNeon = (material == Enum.Material.Neon)

        return (isLemonColor or isLemonBrick) and isNeon
    end
    return false
end

local function UpdateRoomFinderUI()
    if not GhostRoomFinder.StatusLabel then return end
    GhostRoomFinder.StatusLabel:SetText("Rooms Found: " .. #GhostRoomFinder.Rooms)
end

local function StartEMFMonitor()
    GhostRoomFinder.EMFConnection = task.spawn(function()
        while GhostRoomFinder.Enabled do
            if CheckEMF2() then
                if GhostRoomFinder.EMFStatusLabel then
                    GhostRoomFinder.EMFStatusLabel:SetText("EMF: LEVEL 2 DETECTED!")
                    GhostRoomFinder.EMFStatusLabel.TextLabel.TextColor3 = Color3.fromRGB(255, 50, 50)
                end

                local hrp = GetHRP(LocalPlayer.Character)
                if hrp then
                    GhostRoomFinder.GhostRoomCFrame = hrp.CFrame
                end

                if GhostRoomFinder.GhostRoomBtn then
                    GhostRoomFinder.GhostRoomBtn:SetVisible(true)
                end

                if GhostRoomFinder.IsTeleporting then
                    GhostRoomFinder.IsTeleporting = false
                    if GhostRoomFinder.StatusLabel then
                        GhostRoomFinder.StatusLabel:SetText("Stopped - EMF 2 Found!")
                        GhostRoomFinder.StatusLabel.TextLabel.TextColor3 = Color3.fromRGB(255, 80, 80)
                    end
                    if GhostRoomFinder.CurrentRoomLabel then
                        GhostRoomFinder.CurrentRoomLabel:SetText("Current: Ghost Room Found!")
                    end
                end
                break
            else
                if GhostRoomFinder.EMFStatusLabel then
                    GhostRoomFinder.EMFStatusLabel:SetText("EMF: Scanning...")
                    GhostRoomFinder.EMFStatusLabel.TextLabel.TextColor3 = Color3.fromRGB(100, 255, 100)
                end
            end
            task.wait(0.1)
        end
    end)
end

local function TeleportAllRooms()
    if GhostRoomFinder.IsTeleporting then return end

    GhostRoomFinder.Rooms = GetRooms()
    if #GhostRoomFinder.Rooms == 0 then
        if GhostRoomFinder.StatusLabel then
            GhostRoomFinder.StatusLabel:SetText("No rooms found!")
        end
        return
    end

    GhostRoomFinder.GhostRoomCFrame = nil
    if GhostRoomFinder.GhostRoomBtn then
        GhostRoomFinder.GhostRoomBtn:SetVisible(false)
    end

    GhostRoomFinder.IsTeleporting = true
    GhostRoomFinder.CurrentRoomIndex = 1
    GhostRoomFinder.Enabled = true

    if GhostRoomFinder.StatusLabel then
        GhostRoomFinder.StatusLabel:SetText("Teleporting...")
        GhostRoomFinder.StatusLabel.TextLabel.TextColor3 = Color3.fromRGB(255, 80, 80)
    end

    StartEMFMonitor()

    GhostRoomFinder.TeleportConnection = task.spawn(function()
        while GhostRoomFinder.IsTeleporting and GhostRoomFinder.CurrentRoomIndex <= #GhostRoomFinder.Rooms do
            if CheckEMF2() then
                GhostRoomFinder.IsTeleporting = false
                if GhostRoomFinder.StatusLabel then
                    GhostRoomFinder.StatusLabel:SetText("Stopped - EMF 2 Found!")
                    GhostRoomFinder.StatusLabel.TextLabel.TextColor3 = Color3.fromRGB(255, 80, 80)
                end
                if GhostRoomFinder.CurrentRoomLabel then
                    GhostRoomFinder.CurrentRoomLabel:SetText("Current: Ghost Room Found!")
                end
                break
            end

            local room = GhostRoomFinder.Rooms[GhostRoomFinder.CurrentRoomIndex]
            local hrp = GetHRP(LocalPlayer.Character)

            if hrp and room then
                hrp.CFrame = room.CFrame + Vector3.new(0, 3, 0)
                if GhostRoomFinder.CurrentRoomLabel then
                    GhostRoomFinder.CurrentRoomLabel:SetText("Current: " .. room.Name)
                end
                task.wait(0.6)
            end

            GhostRoomFinder.CurrentRoomIndex = GhostRoomFinder.CurrentRoomIndex + 1
        end

        if GhostRoomFinder.IsTeleporting then
            GhostRoomFinder.IsTeleporting = false
            if GhostRoomFinder.StatusLabel then
                GhostRoomFinder.StatusLabel:SetText("Done! Rooms: " .. #GhostRoomFinder.Rooms)
                GhostRoomFinder.StatusLabel.TextLabel.TextColor3 = Color3.fromRGB(200, 200, 200)
            end
            if GhostRoomFinder.CurrentRoomLabel then
                GhostRoomFinder.CurrentRoomLabel:SetText("Current: Finished")
            end
        end
    end)
end

local function StopRoomTeleport()
    GhostRoomFinder.IsTeleporting = false
    if GhostRoomFinder.StatusLabel then
        GhostRoomFinder.StatusLabel:SetText("Stopped")
        GhostRoomFinder.StatusLabel.TextLabel.TextColor3 = Color3.fromRGB(200, 200, 200)
    end
end

local function TeleportToGhostRoom()
    if GhostRoomFinder.GhostRoomCFrame then
        local hrp = GetHRP(LocalPlayer.Character)
        if hrp then
            hrp.CFrame = GhostRoomFinder.GhostRoomCFrame
            if GhostRoomFinder.CurrentRoomLabel then
                GhostRoomFinder.CurrentRoomLabel:SetText("Current: Ghost Room")
            end
            if GhostRoomFinder.StatusLabel then
                GhostRoomFinder.StatusLabel:SetText("Teleported to Ghost Room!")
                GhostRoomFinder.StatusLabel.TextLabel.TextColor3 = Color3.fromRGB(100, 255, 100)
            end
        end
    end
end

-- ============================================
-- TELEPORT TO VAN
-- ============================================

local function TeleportToVan()
    local van = Workspace:FindFirstChild("Van")
    if not van then
        Notify("Van", "Van not found in workspace!")
        return
    end

    local spawn = van:FindFirstChild("Spawn")
    if not spawn then
        Notify("Van", "Spawn part not found in Van!")
        return
    end

    if not spawn:IsA("BasePart") then
        Notify("Van", "Spawn is not a BasePart!")
        return
    end

    local hrp = GetHRP(LocalPlayer.Character)
    if not hrp then
        Notify("Van", "Character not loaded!")
        return
    end

    hrp.CFrame = spawn.CFrame + Vector3.new(0, 3, 0)
    Notify("Van", "Teleported to Van Spawn!")
end

-- ============================================
-- QUICK KEYBINDS
-- ============================================

UserInputService.InputBegan:Connect(function(input, gpe)
    if gpe then return end
    if input.KeyCode == Enum.KeyCode.F1 then
        ToggleEvidenceESP(not EvidenceESP.Enabled)
    elseif input.KeyCode == Enum.KeyCode.F2 then
        ToggleItemsESP(not ItemsESP.Enabled)
    elseif input.KeyCode == Enum.KeyCode.F3 then
        ToggleFullBright(not FullBright.Enabled)
    elseif input.KeyCode == Enum.KeyCode.F4 then
        TogglePlayerESP(not PlayerESP.Enabled)
    elseif input.KeyCode == Enum.KeyCode.F5 then
        ToggleNoclip(not Noclip.Enabled)
    elseif input.KeyCode == Enum.KeyCode.F6 then
        local speed = WalkSpeed.TargetSpeed
        ToggleWalkSpeed(not WalkSpeed.Enabled, speed)
    end
end)

-- ============================================
-- UI SETUP
-- ============================================

Library.ForceCheckbox = false
local Window = Library:CreateWindow({
    Title = "Ghost Hunter ESP",
    Footer = "Streamlined v4.1",
    Icon = 95816097006870,
    NotifySide = "Right",
    ShowCustomCursor = true,
})

local Tabs = {
    ESP = Window:AddTab("ESP", "crosshair"),
    Player = Window:AddTab("Player", "user"),
    Main = Window:AddTab("Main", "ghost"),
    Visuals = Window:AddTab("Visuals", "eye"),
    Settings = Window:AddTab("Settings", "settings"),
}

-- ESP Tab
local GhostBox = Tabs.ESP:AddLeftGroupbox("Ghost ESP", "eye")
GhostBox:AddToggle("GhostESP", { Text = "Enable", Default = false, Callback = function(v) ToggleGhostESP(v) end })
GhostBox:AddToggle("GhostDist", { Text = "Show Distance", Default = true, Callback = function(v) GhostESP.ShowDistance = v end })

local EvBox = Tabs.ESP:AddLeftGroupbox("Evidence ESP", "search")
EvBox:AddToggle("EvESP", { Text = "Enable", Default = false, Callback = function(v) ToggleEvidenceESP(v) end })

local ItemBox = Tabs.ESP:AddRightGroupbox("Items ESP", "backpack")
ItemBox:AddToggle("ItemESP", { Text = "Enable", Default = false, Callback = function(v) ToggleItemsESP(v) end })

local PlBox = Tabs.ESP:AddRightGroupbox("Player ESP", "users")
PlBox:AddToggle("PlESP", { Text = "Enable", Default = false, Callback = function(v) TogglePlayerESP(v) end })
PlBox:AddToggle("PlName", { Text = "Show Name", Default = true, Callback = function(v) PlayerESP.ShowName = v end })
PlBox:AddToggle("PlHealth", { Text = "Show Health", Default = true, Callback = function(v) PlayerESP.ShowHealth = v end })
PlBox:AddToggle("PlDist", { Text = "Show Distance", Default = true, Callback = function(v) PlayerESP.ShowDistance = v end })
PlBox:AddSlider("PlMaxDist", { Text = "Max Distance", Default = 500, Min = 50, Max = 5000, Rounding = 0, Callback = function(v) PlayerESP.MaxDistance = v end })

-- Player Tab
local FlyBox = Tabs.Player:AddLeftGroupbox("QFly", "plane")
FlyBox:AddLabel("PC: Q = toggle")
FlyBox:AddButton("Toggle Fly", function() ToggleQFly() end)
FlyBox:AddSlider("FlySpeed", { Text = "Fly Speed", Default = 50, Min = 1, Max = 500, Rounding = 0, Callback = function(v) QFly.Speed = v end })

local MoveBox = Tabs.Player:AddLeftGroupbox("Movement", "zap")
MoveBox:AddToggle("WalkSpd", { Text = "WalkSpeed", Default = false, Callback = function(v)
    local speed = Options.WalkSpeedSlider and Options.WalkSpeedSlider.Value or 16
    ToggleWalkSpeed(v, speed)
end })
MoveBox:AddSlider("WalkSpeedSlider", { Text = "Speed", Default = 16, Min = 1, Max = 200, Rounding = 0, Callback = function(v)
    if WalkSpeed.Enabled then
        ToggleWalkSpeed(false)
        ToggleWalkSpeed(true, v)
    end
end })
MoveBox:AddToggle("Noclip", { Text = "Noclip", Default = false, Callback = function(v) ToggleNoclip(v) end })

-- ============================================
-- MAIN TAB (Ghost Room Finder + Ghost Sensor + Teleport to Van)
-- ============================================

local RoomFinderBox = Tabs.Main:AddLeftGroupbox("Ghost Room Finder", "home")

GhostRoomFinder.StatusLabel = RoomFinderBox:AddLabel("Rooms Found: 0")
GhostRoomFinder.StatusLabel.TextLabel.TextColor3 = Color3.fromRGB(200, 200, 200)

GhostRoomFinder.CurrentRoomLabel = RoomFinderBox:AddLabel("Current: None")
GhostRoomFinder.CurrentRoomLabel.TextLabel.TextColor3 = Color3.fromRGB(255, 200, 100)

GhostRoomFinder.EMFStatusLabel = RoomFinderBox:AddLabel("EMF: Scanning...")
GhostRoomFinder.EMFStatusLabel.TextLabel.TextColor3 = Color3.fromRGB(100, 255, 100)

RoomFinderBox:AddDivider()

RoomFinderBox:AddButton("Teleport All Rooms", function()
    GhostRoomFinder.Rooms = GetRooms()
    UpdateRoomFinderUI()
    TeleportAllRooms()
end)

RoomFinderBox:AddButton("Stop Teleport", StopRoomTeleport)

GhostRoomFinder.GhostRoomBtn = RoomFinderBox:AddButton("Teleport to Ghost Room", TeleportToGhostRoom)
GhostRoomFinder.GhostRoomBtn:SetVisible(false)

RoomFinderBox:AddDivider()

-- NEW: Teleport to Van button
RoomFinderBox:AddButton("Teleport to Van", TeleportToVan)

-- Auto-refresh room count on load
task.spawn(function()
    GhostRoomFinder.Rooms = GetRooms()
    UpdateRoomFinderUI()
end)

-- Ghost Sensor (moved to right side)
local TriggerBox = Tabs.Main:AddRightGroupbox("Ghost Sensor", "radio")
TriggerBox:AddLabel("Teleports the REAL ghost to your")
TriggerBox:AddLabel("placed motion sensor instantly", true)
TriggerBox:AddDivider()

TriggerBox:AddButton("Bring Ghost to Sensor", TeleportGhostToSensor)
TriggerBox:AddDivider()
TriggerBox:AddButton("Save Ghost Position", SaveGhostPos)
TriggerBox:AddButton("Return Ghost Position", ReturnGhostPos)

-- Visuals Tab
local VisBox = Tabs.Visuals:AddLeftGroupbox("Visuals", "sun")
VisBox:AddToggle("FullBright", { Text = "FullBright", Default = false, Callback = function(v) ToggleFullBright(v) end })

-- Settings
local SetBox = Tabs.Settings:AddLeftGroupbox("Menu", "wrench")
SetBox:AddButton("Unload", function()
    GhostRoomFinder.Enabled = false
    GhostRoomFinder.IsTeleporting = false
    ToggleGhostESP(false)
    ToggleEvidenceESP(false)
    ToggleItemsESP(false)
    TogglePlayerESP(false)
    ToggleFullBright(false)
    ToggleWalkSpeed(false)
    if QFly.Enabled then StopQFly() end
    ToggleNoclip(false)
    StopGhostHold()
    Library:Unload()
end)

-- ============================================
-- SAVE & THEME
-- ============================================

ThemeManager:SetLibrary(Library)
SaveManager:SetLibrary(Library)
SaveManager:IgnoreThemeSettings()
ThemeManager:SetFolder("GhostHunterESP")
SaveManager:SetFolder("GhostHunterESP/settings")
SaveManager:BuildConfigSection(Tabs.Settings)
ThemeManager:ApplyToTab(Tabs.Settings)
SaveManager:LoadAutoloadConfig()

Notify("Loaded", "Ghost Hunter ESP v4.1 - Teleport to Van added!")
