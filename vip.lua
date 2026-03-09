--[[
  MOUNT ZIHAN SCRIPT
  BY ALFIAN
]]

local Players = game:GetService("Players")
local UIS = game:GetService("UserInputService")
local TweenService = game:GetService("TweenService")
local player = Players.LocalPlayer

pcall(function()
    for _, g in ipairs(player.PlayerGui:GetChildren()) do
        if g.Name == "MountZihan" then g:Destroy() end
    end
end)

-- ══════════════════════════════
-- ANTI-LAG
-- ══════════════════════════════
local function applyAntiLag()
    pcall(function() settings().Rendering.QualityLevel = Enum.QualityLevel.Level01 end)
    pcall(function() settings().Rendering.MeshPartDetailLevel = Enum.MeshPartDetailLevel.Level01 end)
    pcall(function() workspace.GlobalShadows = false end)
    pcall(function()
        settings().Rendering.FrameRateManager = 2
        settings().Rendering.MaxFrameRate = 15
    end)
    pcall(function()
        local L = game:GetService("Lighting")
        L.GlobalShadows = false
        L.Brightness = 1
        L.EnvironmentDiffuseScale = 0
        L.EnvironmentSpecularScale = 0
        for _, v in ipairs(L:GetChildren()) do
            if v:IsA("BlurEffect") or v:IsA("SunRaysEffect") or
               v:IsA("ColorCorrectionEffect") or v:IsA("BloomEffect") or
               v:IsA("DepthOfFieldEffect") then
                v.Enabled = false
            end
        end
    end)
    pcall(function()
        for _, v in ipairs(workspace:GetDescendants()) do
            if v:IsA("ParticleEmitter") or v:IsA("Fire") or
               v:IsA("Smoke") or v:IsA("Sparkles") or v:IsA("Beam") then
                v.Enabled = false
            end
            if v:IsA("Decal") or v:IsA("Texture") then
                v.Transparency = 1
            end
        end
    end)
end

-- ══════════════════════════════
-- 4 TITIK PETI DARI MOTION LOG
-- Diambil dari posisi swimming
-- tepat sebelum tiap PROMPT
-- offset +8 Z agar tidak overlap
-- ══════════════════════════════
local PETI = {
    {
        id    = 1,
        label = "PETI 1",
        -- t=2.58 pos sebelum prompt t=7.42
        pos   = Vector3.new(9800.3, 2945.9, -21525.8),
        near  = Vector3.new(9800.3, 2945.9, -21517.8),
    },
    {
        id    = 2,
        label = "PETI 2",
        -- t=16.68 pos sebelum prompt t=20.20
        pos   = Vector3.new(9876.8, 2953.1, -21564.6),
        near  = Vector3.new(9876.8, 2953.1, -21556.6),
    },
    {
        id    = 3,
        label = "PETI 3",
        -- t=26.33 pos sebelum prompt t=31.45
        pos   = Vector3.new(9938.1, 2952.4, -21551.0),
        near  = Vector3.new(9938.1, 2952.4, -21543.0),
    },
    {
        id    = 4,
        label = "PETI 4",
        -- t=36.92 pos sebelum prompt t=40.26
        -- sesi ke-2: t=0.05 pos=(9903.8, 2949.4, -21717.6) sebelum t=4.11
        pos   = Vector3.new(10057.2, 2954.7, -21546.0),
        near  = Vector3.new(10057.2, 2954.7, -21538.0),
    },
}

-- ══════════════════════════════
-- CORE
-- ══════════════════════════════
local running  = false
local statusCB = nil
local antilagOn = false

local function notif(t, m)
    pcall(function()
        game:GetService("StarterGui"):SetCore("SendNotification", {
            Title = t, Text = m, Duration = 3
        })
    end)
end

local function setStatus(msg, col)
    if statusCB then statusCB(msg, col) end
end

local function findPrimary(nearPos)
    -- exact name "Primary" dari log
    local best, bestDist = nil, math.huge
    for _, v in ipairs(workspace:GetDescendants()) do
        if v.Name == "Primary" and (v:IsA("BasePart") or v:IsA("Model")) then
            local pos
            if v:IsA("BasePart") then pos = v.Position
            elseif v:IsA("Model") then
                local p = v.PrimaryPart or v:FindFirstChildWhichIsA("BasePart")
                pos = p and p.Position
            end
            if pos then
                local d = (pos - nearPos).Magnitude
                if d < bestDist then
                    bestDist = d
                    best = v
                end
            end
        end
    end
    -- fallback scan voucher/claim
    if not best then
        for _, v in ipairs(workspace:GetDescendants()) do
            local n = v.Name:lower()
            if n:match("gopay") or n:match("voucher") or n:match("claim") or n:match("chest") then
                if v:IsA("BasePart") or v:IsA("Model") then
                    local pos
                    if v:IsA("BasePart") then pos = v.Position
                    elseif v:IsA("Model") then
                        local p = v.PrimaryPart or v:FindFirstChildWhichIsA("BasePart")
                        pos = p and p.Position
                    end
                    if pos then
                        local d = (pos - nearPos).Magnitude
                        if d < bestDist then
                            bestDist = d
                            best = v
                        end
                    end
                end
            end
        end
    end
    return best
end

local function getObjPos(obj)
    if not obj then return nil end
    if obj:IsA("BasePart") then return obj.Position end
    if obj:IsA("Model") then
        local p = obj.PrimaryPart or obj:FindFirstChildWhichIsA("BasePart")
        return p and p.Position
    end
end

local function fireAllPrompts(obj, nearPos)
    local candidates = {}
    if obj then
        for _, v in ipairs(obj:GetDescendants()) do
            if v:IsA("ProximityPrompt") then table.insert(candidates, v) end
        end
    end
    for _, v in ipairs(workspace:GetDescendants()) do
        if v:IsA("ProximityPrompt") then
            local n  = (v.ActionText or ""):lower()
            local pn = (v.Parent and v.Parent.Name or ""):lower()
            if n:match("claim") or n:match("voucher") or n:match("interact") or
               pn:match("primary") or pn:match("gopay") or pn:match("claim") then
                -- hanya yang dekat titik target
                local par = v.Parent
                if par then
                    local pos
                    if par:IsA("BasePart") then pos = par.Position
                    elseif par:IsA("Model") then
                        local p = par.PrimaryPart or par:FindFirstChildWhichIsA("BasePart")
                        pos = p and p.Position
                    end
                    if pos and (pos - nearPos).Magnitude < 80 then
                        table.insert(candidates, v)
                    end
                end
            end
        end
    end
    local seen, unique = {}, {}
    for _, p in ipairs(candidates) do
        if not seen[p] then seen[p]=true table.insert(unique, p) end
    end
    local fired = 0
    for _, prompt in ipairs(unique) do
        for _ = 1, 3 do
            local ok = pcall(function() fireproximityprompt(prompt) end)
            if ok then fired = fired + 1 break end
            task.wait(0.08)
        end
    end
    return fired
end

local function runPeti(petiData)
    if running then return end
    running = true

    task.spawn(function()
        setStatus("CONNECTING", "wait")
        task.wait(0.15)

        local char = player.Character or player.CharacterAdded:Wait()
        local hrp  = char:WaitForChild("HumanoidRootPart", 5)
        if not hrp then
            setStatus("CHARACTER NOT FOUND", "err")
            running = false
            return
        end

        local hum = char:FindFirstChildOfClass("Humanoid")
        if hum then hum.WalkSpeed = 0 end

        -- TP ke titik near (offset)
        setStatus("FAST TRAVEL  " .. petiData.label, "wait")
        hrp.CFrame = CFrame.new(petiData.near + Vector3.new(0, 5, 0))
        task.wait(0.25)

        -- Scan objek Primary terdekat
        setStatus("LOCATING " .. petiData.label, "wait")
        local obj = findPrimary(petiData.near)
        if obj then
            local pos = getObjPos(obj)
            if pos then
                local offset = (petiData.near - pos)
                if offset.Magnitude > 0.1 then
                    offset = offset.Unit * 8
                else
                    offset = Vector3.new(0, 0, 8)
                end
                hrp.CFrame = CFrame.new(pos + offset + Vector3.new(0, 3, 0))
                task.wait(0.2)
            end
        end

        if hum then hum.WalkSpeed = 16 end

        setStatus("FIRING PROMPT", "wait")
        task.wait(0.15)

        local fired = fireAllPrompts(obj, petiData.near)

        if fired == 0 and obj then
            local pos = getObjPos(obj)
            if pos then
                local dir = (pos - hrp.Position)
                if dir.Magnitude > 0 then
                    hrp.CFrame = CFrame.new(hrp.Position + dir.Unit * 2)
                end
                task.wait(0.15)
                fired = fireAllPrompts(obj, petiData.near)
            end
        end

        setStatus("ARRIVED  " .. petiData.label .. "  — CLAIM", "done")
        notif("Mount Zihan", petiData.label .. " — Claim voucher sekarang.")
        running = false
    end)
end

-- ══════════════════════════════
-- GUI
-- ══════════════════════════════
local C1c = Color3.fromRGB(8,   8,   8)
local C2c = Color3.fromRGB(14,  14,  14)
local C3c = Color3.fromRGB(22,  22,  22)
local C4c = Color3.fromRGB(35,  35,  35)
local C5c = Color3.fromRGB(55,  55,  55)
local W1c = Color3.fromRGB(220, 220, 220)
local W2c = Color3.fromRGB(140, 140, 140)
local W3c = Color3.fromRGB(55,  55,  55)
local GRc = Color3.fromRGB(150, 255, 170)
local RDc = Color3.fromRGB(255, 100, 100)
local YLc = Color3.fromRGB(230, 200, 100)

local function cr(p, r)
    local u = Instance.new("UICorner", p)
    u.CornerRadius = UDim.new(0, r or 6)
end
local function sk(p, c, t)
    local s = Instance.new("UIStroke", p)
    s.Color = c or C4c
    s.Thickness = t or 1
    return s
end

local sg = Instance.new("ScreenGui")
sg.Name           = "MountZihan"
sg.ResetOnSpawn   = false
sg.DisplayOrder   = 9999
sg.IgnoreGuiInset = true
sg.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
sg.Parent         = player.PlayerGui

-- MAIN FRAME
local F = Instance.new("Frame", sg)
F.Size             = UDim2.new(0, 240, 0, 430)
F.Position         = UDim2.new(0.5, -120, 0.5, -215)
F.BackgroundColor3 = C1c
F.BorderSizePixel  = 0
F.Active           = true
F.Draggable        = true
F.ZIndex           = 10
cr(F, 10) sk(F, C4c, 1)

local Accent = Instance.new("Frame", F)
Accent.Size             = UDim2.new(1, -2, 0, 1)
Accent.Position         = UDim2.new(0, 1, 0, 1)
Accent.BackgroundColor3 = W1c
Accent.BorderSizePixel  = 0
Accent.ZIndex           = 14
cr(Accent, 1)

-- TOPBAR
local TB = Instance.new("Frame", F)
TB.Size             = UDim2.new(1, 0, 0, 44)
TB.Position         = UDim2.new(0, 0, 0, 0)
TB.BackgroundColor3 = C2c
TB.BorderSizePixel  = 0
TB.ZIndex           = 11
cr(TB, 10)
local TBFix = Instance.new("Frame", TB)
TBFix.Size             = UDim2.new(1, 0, 0, 10)
TBFix.Position         = UDim2.new(0, 0, 1, -10)
TBFix.BackgroundColor3 = C2c
TBFix.BorderSizePixel  = 0
TBFix.ZIndex           = 11

local TTitle = Instance.new("TextLabel", TB)
TTitle.Size               = UDim2.new(1, -46, 0, 16)
TTitle.Position           = UDim2.new(0, 14, 0, 8)
TTitle.BackgroundTransparency = 1
TTitle.Text               = "MOUNT ZIHAN SCRIPT"
TTitle.TextColor3         = W1c
TTitle.Font               = Enum.Font.GothamBold
TTitle.TextSize           = 11
TTitle.TextXAlignment     = Enum.TextXAlignment.Left
TTitle.ZIndex             = 13

local TBy = Instance.new("TextLabel", TB)
TBy.Size               = UDim2.new(1, -46, 0, 12)
TBy.Position           = UDim2.new(0, 14, 0, 26)
TBy.BackgroundTransparency = 1
TBy.Text               = "BY ALFIAN"
TBy.TextColor3         = W3c
TBy.Font               = Enum.Font.GothamBold
TBy.TextSize           = 8
TBy.TextXAlignment     = Enum.TextXAlignment.Left
TBy.ZIndex             = 13

local XBtn = Instance.new("TextButton", TB)
XBtn.Size             = UDim2.new(0, 24, 0, 24)
XBtn.Position         = UDim2.new(1, -32, 0.5, -12)
XBtn.BackgroundColor3 = C3c
XBtn.Text             = "X"
XBtn.TextColor3       = W3c
XBtn.Font             = Enum.Font.GothamBold
XBtn.TextSize         = 10
XBtn.BorderSizePixel  = 0
XBtn.ZIndex           = 14
cr(XBtn, 6) sk(XBtn, C5c, 1)
XBtn.MouseEnter:Connect(function() XBtn.TextColor3 = W1c end)
XBtn.MouseLeave:Connect(function() XBtn.TextColor3 = W3c end)
XBtn.MouseButton1Click:Connect(function()
    TweenService:Create(F, TweenInfo.new(0.2, Enum.EasingStyle.Quart), {
        Size = UDim2.new(0, 240, 0, 0),
        BackgroundTransparency = 1
    }):Play()
    task.delay(0.25, function() sg:Destroy() end)
end)

local Sep = Instance.new("Frame", F)
Sep.Size             = UDim2.new(1, -28, 0, 1)
Sep.Position         = UDim2.new(0, 14, 0, 44)
Sep.BackgroundColor3 = C4c
Sep.BorderSizePixel  = 0
Sep.ZIndex           = 11

-- BODY
local Body = Instance.new("Frame", F)
Body.Size             = UDim2.new(1, -28, 1, -58)
Body.Position         = UDim2.new(0, 14, 0, 52)
Body.BackgroundTransparency = 1
Body.ZIndex           = 11

local BL = Instance.new("UIListLayout", Body)
BL.SortOrder = Enum.SortOrder.LayoutOrder
BL.Padding   = UDim.new(0, 6)

local function hl(order)
    local l = Instance.new("Frame", Body)
    l.LayoutOrder = order
    l.Size = UDim2.new(1, 0, 0, 1)
    l.BackgroundColor3 = C4c
    l.BorderSizePixel  = 0
    l.ZIndex = 12
end

local function seclbl(order, txt)
    local l = Instance.new("TextLabel", Body)
    l.LayoutOrder = order
    l.Size = UDim2.new(1, 0, 0, 12)
    l.BackgroundTransparency = 1
    l.Text = txt
    l.TextColor3 = W3c
    l.Font = Enum.Font.GothamBold
    l.TextSize = 8
    l.TextXAlignment = Enum.TextXAlignment.Left
    l.ZIndex = 12
end

-- CARA PAKAI
seclbl(1, "CARA PAKAI")
local steps = {
    "1.  Anti-Lag aktif otomatis saat load",
    "2.  Pilih PETI yang ingin diklaim",
    "3.  Tunggu status ARRIVED muncul",
    "4.  Klik Claim Voucher 1x saja",
    "5.  Ulangi untuk peti berbeda",
}
for i, step in ipairs(steps) do
    local row = Instance.new("Frame", Body)
    row.LayoutOrder = 1 + i
    row.Size = UDim2.new(1, 0, 0, 14)
    row.BackgroundTransparency = 1
    row.ZIndex = 12
    local t = Instance.new("TextLabel", row)
    t.Size = UDim2.new(1, 0, 1, 0)
    t.BackgroundTransparency = 1
    t.Text = step
    t.TextColor3 = W2c
    t.Font = Enum.Font.Gotham
    t.TextSize = 9
    t.TextXAlignment = Enum.TextXAlignment.Left
    t.ZIndex = 13
end

hl(8)

-- STATUS CARD
local StatCard = Instance.new("Frame", Body)
StatCard.LayoutOrder = 9
StatCard.Size = UDim2.new(1, 0, 0, 28)
StatCard.BackgroundColor3 = C2c
StatCard.BorderSizePixel  = 0
StatCard.ZIndex = 12
cr(StatCard, 6) sk(StatCard, C4c, 1)

local StatDot = Instance.new("Frame", StatCard)
StatDot.Size = UDim2.new(0, 5, 0, 5)
StatDot.Position = UDim2.new(0, 10, 0.5, -2)
StatDot.BackgroundColor3 = GRc
StatDot.BorderSizePixel  = 0
StatDot.ZIndex = 13
cr(StatDot, 5)

local StatVal = Instance.new("TextLabel", StatCard)
StatVal.Size = UDim2.new(1, -24, 1, 0)
StatVal.Position = UDim2.new(0, 22, 0, 0)
StatVal.BackgroundTransparency = 1
StatVal.Text = "READY — PILIH PETI"
StatVal.TextColor3 = GRc
StatVal.Font = Enum.Font.GothamBold
StatVal.TextSize = 9
StatVal.TextXAlignment = Enum.TextXAlignment.Left
StatVal.TextTruncate = Enum.TextTruncate.AtEnd
StatVal.ZIndex = 13

statusCB = function(msg, col)
    StatVal.Text = msg
    if col == "done" then
        StatVal.TextColor3 = GRc StatDot.BackgroundColor3 = GRc
    elseif col == "err" then
        StatVal.TextColor3 = RDc StatDot.BackgroundColor3 = RDc
    elseif col == "wait" then
        StatVal.TextColor3 = YLc StatDot.BackgroundColor3 = YLc
    else
        StatVal.TextColor3 = W1c StatDot.BackgroundColor3 = W1c
    end
end

hl(10)

-- PETI BUTTONS (2x2 grid)
seclbl(11, "PILIH PETI GOPAY")

local GridFrame = Instance.new("Frame", Body)
GridFrame.LayoutOrder = 12
GridFrame.Size = UDim2.new(1, 0, 0, 88)
GridFrame.BackgroundTransparency = 1
GridFrame.ZIndex = 12

local GridLayout = Instance.new("UIGridLayout", GridFrame)
GridLayout.CellSize    = UDim2.new(0.5, -3, 0, 40)
GridLayout.CellPadding = UDim2.new(0, 6, 0, 6)
GridLayout.SortOrder   = Enum.SortOrder.LayoutOrder

local petiButtons = {}

for _, peti in ipairs(PETI) do
    local btn = Instance.new("TextButton", GridFrame)
    btn.LayoutOrder = peti.id
    btn.BackgroundColor3 = C3c
    btn.Text = peti.label
    btn.TextColor3 = W2c
    btn.Font = Enum.Font.GothamBold
    btn.TextSize = 11
    btn.BorderSizePixel = 0
    btn.ZIndex = 13
    cr(btn, 7)
    local bsk = sk(btn, C5c, 1)

    -- coord sub-label
    local sub = Instance.new("TextLabel", btn)
    sub.Size = UDim2.new(1, 0, 0, 12)
    sub.Position = UDim2.new(0, 0, 1, -13)
    sub.BackgroundTransparency = 1
    sub.Text = string.format("%.0f  %.0f  %.0f", peti.pos.X, peti.pos.Y, peti.pos.Z)
    sub.TextColor3 = W3c
    sub.Font = Enum.Font.Code
    sub.TextSize = 7
    sub.TextXAlignment = Enum.TextXAlignment.Center
    sub.ZIndex = 14

    local activeBtn = nil

    btn.MouseButton1Click:Connect(function()
        if running then return end

        -- reset semua button
        for _, b in ipairs(petiButtons) do
            b.btn.TextColor3 = W2c
            b.sk.Color = C5c
            b.btn.BackgroundColor3 = C3c
        end

        -- highlight aktif
        btn.TextColor3 = W1c
        btn.BackgroundColor3 = C4c
        bsk.Color = W3c

        runPeti(peti)

        task.spawn(function()
            while running do task.wait(0.1) end
            task.wait(1)
            btn.TextColor3 = W2c
            btn.BackgroundColor3 = C3c
            bsk.Color = C5c
        end)
    end)

    btn.MouseEnter:Connect(function()
        if not running then
            btn.BackgroundColor3 = C4c
        end
    end)
    btn.MouseLeave:Connect(function()
        if not running then
            btn.BackgroundColor3 = C3c
        end
    end)

    table.insert(petiButtons, {btn = btn, sk = bsk})
end

hl(13)

-- ALL PETI BUTTON
local AllBtn = Instance.new("TextButton", Body)
AllBtn.LayoutOrder = 14
AllBtn.Size = UDim2.new(1, 0, 0, 32)
AllBtn.BackgroundColor3 = C3c
AllBtn.Text = "CLAIM SEMUA PETI"
AllBtn.TextColor3 = W2c
AllBtn.Font = Enum.Font.GothamBold
AllBtn.TextSize = 11
AllBtn.BorderSizePixel = 0
AllBtn.ZIndex = 12
cr(AllBtn, 7) sk(AllBtn, C5c, 1)

AllBtn.MouseEnter:Connect(function() AllBtn.BackgroundColor3 = C4c end)
AllBtn.MouseLeave:Connect(function() AllBtn.BackgroundColor3 = C3c end)

AllBtn.MouseButton1Click:Connect(function()
    if running then return end
    AllBtn.Text = "RUNNING ALL..."
    AllBtn.TextColor3 = YLc

    task.spawn(function()
        for _, peti in ipairs(PETI) do
            if running then task.wait(0.1) end
            runPeti(peti)
            -- tunggu selesai sebelum lanjut ke peti berikut
            while running do task.wait(0.1) end
            task.wait(1.5) -- jeda antar peti
        end
        AllBtn.Text = "CLAIM SEMUA PETI"
        AllBtn.TextColor3 = W2c
        notif("Mount Zihan", "Semua peti selesai dikunjungi.")
    end)
end)

-- ANTI-LAG CARD
local ALCard = Instance.new("Frame", Body)
ALCard.LayoutOrder = 15
ALCard.Size = UDim2.new(1, 0, 0, 28)
ALCard.BackgroundColor3 = C2c
ALCard.BorderSizePixel  = 0
ALCard.ZIndex = 12
cr(ALCard, 6) sk(ALCard, C4c, 1)

local ALLbl = Instance.new("TextLabel", ALCard)
ALLbl.Size = UDim2.new(0.65, 0, 1, 0)
ALLbl.Position = UDim2.new(0, 10, 0, 0)
ALLbl.BackgroundTransparency = 1
ALLbl.Text = "ANTI-LAG / LOW GRAPHICS"
ALLbl.TextColor3 = W3c
ALLbl.Font = Enum.Font.GothamBold
ALLbl.TextSize = 8
ALLbl.TextXAlignment = Enum.TextXAlignment.Left
ALLbl.ZIndex = 13

local ALBtn = Instance.new("TextButton", ALCard)
ALBtn.Size = UDim2.new(0, 40, 0, 18)
ALBtn.Position = UDim2.new(1, -46, 0.5, -9)
ALBtn.BackgroundColor3 = C3c
ALBtn.Text = "OFF"
ALBtn.TextColor3 = W3c
ALBtn.Font = Enum.Font.GothamBold
ALBtn.TextSize = 9
ALBtn.BorderSizePixel = 0
ALBtn.ZIndex = 13
cr(ALBtn, 5)
local ALStroke = sk(ALBtn, C5c, 1)

ALBtn.MouseButton1Click:Connect(function()
    antilagOn = not antilagOn
    if antilagOn then
        applyAntiLag()
        ALBtn.Text = "ON" ALBtn.TextColor3 = W1c ALStroke.Color = W2c
    else
        ALBtn.Text = "OFF" ALBtn.TextColor3 = W3c ALStroke.Color = C5c
    end
end)

-- F9
UIS.InputBegan:Connect(function(inp, gpe)
    if gpe then return end
    if inp.KeyCode == Enum.KeyCode.F9 then F.Visible = not F.Visible end
end)

-- auto antilag on load
task.spawn(function()
    task.wait(0.5)
    applyAntiLag()
    antilagOn = true
    ALBtn.Text = "ON"
    ALBtn.TextColor3 = W1c
    ALStroke.Color = W2c
end)

print("Mount Zihan Script | By Alfian | F9 toggle")
