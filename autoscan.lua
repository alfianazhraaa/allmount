--[[
  MOUNT ZIHAN v2
  BY ALFIAN
]]

local Players  = game:GetService("Players")
local UIS      = game:GetService("UserInputService")
local TweenSvc = game:GetService("TweenService")
local player   = Players.LocalPlayer

pcall(function()
    for _, g in ipairs(player.PlayerGui:GetChildren()) do
        if g.Name == "ZihanV2" then g:Destroy() end
    end
end)

local function applyAntiLag()
    pcall(function() settings().Rendering.QualityLevel = Enum.QualityLevel.Level01 end)
    pcall(function() settings().Rendering.MeshPartDetailLevel = Enum.MeshPartDetailLevel.Level01 end)
    pcall(function() workspace.GlobalShadows = false end)
    pcall(function() settings().Rendering.MaxFrameRate = 15 end)
    pcall(function()
        local L = game:GetService("Lighting")
        L.GlobalShadows = false; L.Brightness = 1
        L.EnvironmentDiffuseScale = 0; L.EnvironmentSpecularScale = 0
        for _, v in ipairs(L:GetChildren()) do
            if v:IsA("BlurEffect") or v:IsA("SunRaysEffect") or
               v:IsA("ColorCorrectionEffect") or v:IsA("BloomEffect") or
               v:IsA("DepthOfFieldEffect") then v.Enabled = false end
        end
    end)
    pcall(function()
        for _, v in ipairs(workspace:GetDescendants()) do
            if v:IsA("ParticleEmitter") or v:IsA("Fire") or
               v:IsA("Smoke") or v:IsA("Sparkles") or v:IsA("Beam") then v.Enabled = false end
            if v:IsA("Decal") or v:IsA("Texture") then v.Transparency = 1 end
        end
    end)
end

-- ══════════════════════════════
-- KOORDINAT
-- ══════════════════════════════
-- Fase 1 — dari log baru t=0.05
local TITIK1      = Vector3.new(9233.1,  5054.2, -21332.8)
-- Fase 2 — summit dari log sebelumnya
local SUMMIT_LAND = Vector3.new(9814.0,  2952.5, -21591.3)
local SUMMIT_NEAR = Vector3.new(9874.0,  2951.0, -21571.6)

local running  = false
local statusCB = nil

local function setStatus(msg, col)
    if statusCB then statusCB(msg, col) end
end
local function notif(t, m)
    pcall(function()
        game:GetService("StarterGui"):SetCore("SendNotification",
            {Title=t, Text=m, Duration=3})
    end)
end

local function findPrimary()
    local best, bestDist = nil, math.huge
    for _, v in ipairs(workspace:GetDescendants()) do
        if v:IsA("ProximityPrompt") then
            local at = (v.ActionText or ""):lower()
            local pn = (v.Parent and v.Parent.Name or ""):lower()
            if at:match("claim") or at:match("voucher") or pn == "primary" then
                local par = v.Parent
                if par then
                    local pos
                    if par:IsA("BasePart") then pos = par.Position
                    elseif par:IsA("Model") then
                        local pp = par.PrimaryPart or par:FindFirstChildWhichIsA("BasePart")
                        pos = pp and pp.Position
                    end
                    if pos then
                        local d = (pos - SUMMIT_NEAR).Magnitude
                        if d < bestDist then bestDist=d; best={prompt=v, pos=pos} end
                    end
                end
            end
        end
    end
    if best then return best end
    for _, v in ipairs(workspace:GetDescendants()) do
        if v.Name == "Primary" and (v:IsA("BasePart") or v:IsA("Model")) then
            local pos
            if v:IsA("BasePart") then pos = v.Position
            elseif v:IsA("Model") then
                local pp = v.PrimaryPart or v:FindFirstChildWhichIsA("BasePart")
                pos = pp and pp.Position
            end
            if pos then
                local d = (pos - SUMMIT_NEAR).Magnitude
                if d < bestDist then
                    bestDist = d
                    local pr = v:FindFirstChildOfClass("ProximityPrompt")
                    best = {prompt=pr, pos=pos}
                end
            end
        end
    end
    return best
end

local function firePrompt(pr, objPos, hrp)
    if not pr then return false end
    if objPos then
        local dir = (hrp.Position - objPos)
        local safePos = objPos + (dir.Magnitude > 0.1 and dir.Unit*7 or Vector3.new(0,0,7))
        hrp.CFrame = CFrame.new(safePos + Vector3.new(0,3,0))
        task.wait(0.2)
    end
    for _ = 1, 3 do
        local ok = pcall(function() fireproximityprompt(pr) end)
        if ok then return true end
        task.wait(0.08)
    end
    if objPos then
        local d = (objPos - hrp.Position)
        if d.Magnitude > 0 then
            hrp.CFrame = CFrame.new(hrp.Position + d.Unit * 3)
        end
        task.wait(0.15)
        pcall(function() fireproximityprompt(pr) end)
    end
    return false
end

local function runSequence()
    if running then return end
    running = true
    task.spawn(function()
        setStatus("...", "wait")
        task.wait(0.15)

        local char = player.Character or player.CharacterAdded:Wait()
        local hrp  = char:WaitForChild("HumanoidRootPart", 5)
        if not hrp then
            setStatus("ERROR", "err"); running=false; return
        end
        local hum = char:FindFirstChildOfClass("Humanoid")
        if hum then hum.WalkSpeed = 0 end

        -- TP 1: Summit (fase 2 dulu)
        hrp.CFrame = CFrame.new(SUMMIT_NEAR + Vector3.new(0,5,0))
        task.wait(0.35)

        -- TP 2: Fase 1 — koordinat baru dari log
        hrp.CFrame = CFrame.new(TITIK1 + Vector3.new(0,5,0))
        task.wait(0.35)

        -- TP 3: Summit lagi + fire
        hrp.CFrame = CFrame.new(SUMMIT_LAND + Vector3.new(0,5,0))
        task.wait(0.25)
        hrp.CFrame = CFrame.new(SUMMIT_NEAR + Vector3.new(0,5,0))
        task.wait(0.25)

        if hum then hum.WalkSpeed = 16 end
        task.wait(0.1)

        local result = findPrimary()
        if result then
            firePrompt(result.prompt, result.pos, hrp)
        end

        setStatus("READY", "done")
        notif("Mount Zihan", "Claim voucher sekarang.")
        running = false
    end)
end

-- ══════════════════════════════
-- GUI
-- ══════════════════════════════
local PNL = Color3.fromRGB(14, 14, 14)
local MID = Color3.fromRGB(22, 22, 22)
local BRD = Color3.fromRGB(34, 34, 34)
local BRD2= Color3.fromRGB(50, 50, 50)
local DIM = Color3.fromRGB(100,100,100)
local SIL = Color3.fromRGB(153,153,153)
local WHT = Color3.fromRGB(230,230,230)
local DEEP= Color3.fromRGB(8,  8,  8)
local GR  = Color3.fromRGB(150,255,170)
local RD  = Color3.fromRGB(255,100,100)
local YL  = Color3.fromRGB(230,200,100)

local function uic(p,r)
    local u=Instance.new("UICorner",p); u.CornerRadius=UDim.new(0,r or 6)
end
local function usk(p,c,t)
    local s=Instance.new("UIStroke",p); s.Color=c or BRD; s.Thickness=t or 1; return s
end

local sg=Instance.new("ScreenGui")
sg.Name="ZihanV2"; sg.ResetOnSpawn=false
sg.DisplayOrder=9999; sg.IgnoreGuiInset=true
sg.ZIndexBehavior=Enum.ZIndexBehavior.Sibling
sg.Parent=player.PlayerGui

local F=Instance.new("Frame",sg)
F.Size=UDim2.new(0,200,0,140); F.Position=UDim2.new(0.5,-100,0.5,-70)
F.BackgroundColor3=PNL; F.BorderSizePixel=0
F.Active=true; F.Draggable=true; F.ZIndex=10
uic(F,8); usk(F,BRD,1)

local TL=Instance.new("Frame",F)
TL.Size=UDim2.new(1,-4,0,1); TL.Position=UDim2.new(0,2,0,0)
TL.BackgroundColor3=SIL; TL.BorderSizePixel=0; TL.ZIndex=15; uic(TL,1)

local TB=Instance.new("Frame",F)
TB.Size=UDim2.new(1,0,0,40); TB.BackgroundColor3=DEEP
TB.BorderSizePixel=0; TB.ZIndex=11
local tbU=Instance.new("UICorner",TB); tbU.CornerRadius=UDim.new(0,8)
local tbF=Instance.new("Frame",TB)
tbF.Size=UDim2.new(1,0,0,8); tbF.Position=UDim2.new(0,0,1,-8)
tbF.BackgroundColor3=DEEP; tbF.BorderSizePixel=0; tbF.ZIndex=11
local tbB=Instance.new("Frame",TB)
tbB.Size=UDim2.new(1,0,0,1); tbB.Position=UDim2.new(0,0,1,-1)
tbB.BackgroundColor3=BRD; tbB.BorderSizePixel=0; tbB.ZIndex=12

local TTi=Instance.new("TextLabel",TB)
TTi.Size=UDim2.new(1,-46,0,16); TTi.Position=UDim2.new(0,12,0,6)
TTi.BackgroundTransparency=1; TTi.Text="MOUNT ZIHAN v2"
TTi.TextColor3=WHT; TTi.Font=Enum.Font.GothamBold
TTi.TextSize=11; TTi.TextXAlignment=Enum.TextXAlignment.Left; TTi.ZIndex=13

local TBy=Instance.new("TextLabel",TB)
TBy.Size=UDim2.new(1,-46,0,12); TBy.Position=UDim2.new(0,12,0,23)
TBy.BackgroundTransparency=1; TBy.Text="BY ALFIAN"
TBy.TextColor3=DIM; TBy.Font=Enum.Font.GothamBold
TBy.TextSize=8; TBy.TextXAlignment=Enum.TextXAlignment.Left; TBy.ZIndex=13

local XB=Instance.new("TextButton",TB)
XB.Size=UDim2.new(0,22,0,22); XB.Position=UDim2.new(1,-28,0.5,-11)
XB.BackgroundColor3=MID; XB.Text="✕"; XB.TextColor3=DIM
XB.Font=Enum.Font.GothamBold; XB.TextSize=9; XB.BorderSizePixel=0; XB.ZIndex=14
uic(XB,5); usk(XB,BRD2,1)
XB.MouseEnter:Connect(function() XB.TextColor3=WHT end)
XB.MouseLeave:Connect(function() XB.TextColor3=DIM end)
XB.MouseButton1Click:Connect(function()
    TweenSvc:Create(F,TweenInfo.new(0.18,Enum.EasingStyle.Quart),
        {Size=UDim2.new(0,200,0,0),BackgroundTransparency=1}):Play()
    task.delay(0.2,function() sg:Destroy() end)
end)

local SR=Instance.new("Frame",F)
SR.Size=UDim2.new(1,-24,0,22); SR.Position=UDim2.new(0,12,0,48)
SR.BackgroundColor3=MID; SR.BorderSizePixel=0; SR.ZIndex=12
uic(SR,5); usk(SR,BRD,1)

local SDot=Instance.new("Frame",SR)
SDot.Size=UDim2.new(0,5,0,5); SDot.Position=UDim2.new(0,10,0.5,-2)
SDot.BackgroundColor3=GR; SDot.BorderSizePixel=0; SDot.ZIndex=13; uic(SDot,5)

local SVl=Instance.new("TextLabel",SR)
SVl.Size=UDim2.new(1,-24,1,0); SVl.Position=UDim2.new(0,22,0,0)
SVl.BackgroundTransparency=1; SVl.Text="READY"
SVl.TextColor3=GR; SVl.Font=Enum.Font.GothamBold
SVl.TextSize=9; SVl.TextXAlignment=Enum.TextXAlignment.Left
SVl.TextTruncate=Enum.TextTruncate.AtEnd; SVl.ZIndex=13

statusCB=function(msg,col)
    SVl.Text=msg
    if col=="done" then SVl.TextColor3=GR; SDot.BackgroundColor3=GR
    elseif col=="err" then SVl.TextColor3=RD; SDot.BackgroundColor3=RD
    elseif col=="wait" then SVl.TextColor3=YL; SDot.BackgroundColor3=YL
    else SVl.TextColor3=WHT; SDot.BackgroundColor3=WHT end
end

local StartBtn=Instance.new("TextButton",F)
StartBtn.Size=UDim2.new(1,-24,0,36); StartBtn.Position=UDim2.new(0,12,0,78)
StartBtn.BackgroundColor3=WHT; StartBtn.Text="[ START ]"
StartBtn.TextColor3=DEEP; StartBtn.Font=Enum.Font.GothamBold
StartBtn.TextSize=13; StartBtn.BorderSizePixel=0; StartBtn.ZIndex=12
uic(StartBtn,7); usk(StartBtn,BRD2,1)

local pulsing=true
task.spawn(function()
    while sg and sg.Parent do
        task.wait(0.05)
        if pulsing then
            TweenSvc:Create(StartBtn,TweenInfo.new(1.3,Enum.EasingStyle.Sine,Enum.EasingDirection.InOut),
                {BackgroundColor3=Color3.fromRGB(200,200,200)}):Play()
            task.wait(1.3)
            if pulsing then
                TweenSvc:Create(StartBtn,TweenInfo.new(1.3,Enum.EasingStyle.Sine,Enum.EasingDirection.InOut),
                    {BackgroundColor3=WHT}):Play()
                task.wait(1.3)
            end
        else task.wait(0.2) end
    end
end)

StartBtn.MouseButton1Click:Connect(function()
    if running then return end
    pulsing=false
    StartBtn.BackgroundColor3=MID; StartBtn.TextColor3=YL; StartBtn.Text="..."
    runSequence()
    task.spawn(function()
        while running do task.wait(0.1) end
        task.wait(0.4)
        StartBtn.BackgroundColor3=WHT; StartBtn.TextColor3=DEEP
        StartBtn.Text="[ START ]"; pulsing=true
    end)
end)

UIS.InputBegan:Connect(function(inp,gpe)
    if gpe then return end
    if inp.KeyCode==Enum.KeyCode.F9 then F.Visible=not F.Visible end
end)

task.spawn(function()
    task.wait(0.5); applyAntiLag()
end)

print("Mount Zihan v2 | By Alfian | F9 toggle")
