--[[
  MOUNT ZIHAN v2 — SUMMIT SCRIPT
  BY ALFIAN
  Fase 1: Teleport ke titik awal (basecamp area)
  Fase 2: Teleport ke summit → jalan ke Primary → Claim Voucher
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

-- ══════════════════════════════
-- ANTI-LAG
-- ══════════════════════════════
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
               v:IsA("Smoke") or v:IsA("Sparkles") or v:IsA("Beam") then
                v.Enabled = false
            end
            if v:IsA("Decal") or v:IsA("Texture") then v.Transparency = 1 end
        end
    end)
end

-- ══════════════════════════════
-- KOORDINAT DARI LOG
-- ══════════════════════════════
-- TITIK 1: posisi awal / basecamp area
-- t=0.06 → (9150.5, 5054.2, -21364.1)
local TITIK1 = Vector3.new(9150.5, 5054.2, -21364.1)

-- TITIK 2: summit area setelah teleport
-- t=5.55 → (9814.0, 2988.5, -21591.3) teleport point
-- t=6.37 landed → (9814.0, 2952.5, -21591.3)
-- titik terakhir sebelum prompt t=9.29
-- → (9874.0, 2951.0, -21571.6)
local SUMMIT_TP   = Vector3.new(9814.0, 2952.5, -21591.3) -- landing spot
local SUMMIT_NEAR = Vector3.new(9874.0, 2951.0, -21571.6) -- dekat Primary

-- ══════════════════════════════
-- FIND PRIMARY + PROMPT
-- obj="Primary" dari log
-- ══════════════════════════════
local function findPrimary()
    -- exact "Primary" terdekat summit
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

    -- fallback: BasePart/Model "Primary" terdekat
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
    -- posisi 7 stud dari objek
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
    -- nudge
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

-- ══════════════════════════════
-- CORE SEQUENCE
-- ══════════════════════════════
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

local function runSequence()
    if running then return end
    running = true

    task.spawn(function()

        -- ambil HRP
        setStatus("CONNECTING", "wait")
        task.wait(0.15)
        local char = player.Character or player.CharacterAdded:Wait()
        local hrp  = char:WaitForChild("HumanoidRootPart", 5)
        if not hrp then
            setStatus("CHARACTER NOT FOUND", "err")
            running = false; return
        end
        local hum = char:FindFirstChildOfClass("Humanoid")
        if hum then hum.WalkSpeed = 0 end

        -- ══ FASE 1: TITIK PERTAMA (basecamp) ══
        setStatus("FASE 1 — TITIK AWAL", "wait")
        hrp.CFrame = CFrame.new(TITIK1 + Vector3.new(0, 5, 0))
        task.wait(0.4)
        if hum then hum.WalkSpeed = 16 end
        task.wait(0.3)

        -- ══ FASE 2: SUMMIT TP ══
        setStatus("FASE 2 — MENUJU SUMMIT", "wait")
        if hum then hum.WalkSpeed = 0 end
        task.wait(0.2)
        hrp.CFrame = CFrame.new(SUMMIT_TP + Vector3.new(0, 5, 0))
        task.wait(0.4)

        -- TP ke titik dekat Primary (posisi terakhir dari log)
        setStatus("MENDEKATI CLAIM POINT", "wait")
        hrp.CFrame = CFrame.new(SUMMIT_NEAR + Vector3.new(0, 5, 0))
        task.wait(0.3)

        -- scan Primary
        setStatus("LOCATING PRIMARY", "wait")
        local result = findPrimary()

        if result then
            setStatus("FIRING CLAIM PROMPT", "wait")
            if hum then hum.WalkSpeed = 16 end
            task.wait(0.12)
            firePrompt(result.prompt, result.pos, hrp)
            setStatus("ARRIVED — CLAIM MANUAL", "done")
            notif("Mount Zihan v2", "Sudah di summit. Claim voucher sekarang.")
        else
            -- tidak ditemukan → tetap tiba, user claim manual
            if hum then hum.WalkSpeed = 16 end
            setStatus("PRIMARY NOT FOUND — TAP MANUAL", "done")
            notif("Mount Zihan v2", "Sudah tiba. Tap Claim Voucher manual.")
        end

        running = false
    end)
end

-- ══════════════════════════════
-- GUI
-- ══════════════════════════════
local PNL = Color3.fromRGB(14,  14,  14)
local MID = Color3.fromRGB(22,  22,  22)
local BRD = Color3.fromRGB(34,  34,  34)
local BRD2= Color3.fromRGB(50,  50,  50)
local DIM = Color3.fromRGB(100, 100, 100)
local SIL = Color3.fromRGB(153, 153, 153)
local WHT = Color3.fromRGB(230, 230, 230)
local DEEP= Color3.fromRGB(8,   8,   8)
local GR  = Color3.fromRGB(150, 255, 170)
local RD  = Color3.fromRGB(255, 100, 100)
local YL  = Color3.fromRGB(230, 200, 100)

local function uic(p,r)
    local u=Instance.new("UICorner",p); u.CornerRadius=UDim.new(0,r or 6)
end
local function usk(p,c,t)
    local s=Instance.new("UIStroke",p); s.Color=c or BRD; s.Thickness=t or 1; return s
end
local function mkL(par,txt,col,sz,font,xa)
    local l=Instance.new("TextLabel",par)
    l.BackgroundTransparency=1; l.Text=txt or ""
    l.TextColor3=col or WHT; l.Font=font or Enum.Font.Gotham
    l.TextSize=sz or 10; l.ZIndex=14
    l.TextXAlignment=xa or Enum.TextXAlignment.Left
    return l
end

local sg=Instance.new("ScreenGui")
sg.Name="ZihanV2"; sg.ResetOnSpawn=false
sg.DisplayOrder=9999; sg.IgnoreGuiInset=true
sg.ZIndexBehavior=Enum.ZIndexBehavior.Sibling
sg.Parent=player.PlayerGui

-- FRAME
local F=Instance.new("Frame",sg)
F.Size=UDim2.new(0,230,0,320); F.Position=UDim2.new(0.5,-115,0.5,-160)
F.BackgroundColor3=PNL; F.BorderSizePixel=0
F.Active=true; F.Draggable=true; F.ZIndex=10
uic(F,8); usk(F,BRD,1)

-- top accent
local TL=Instance.new("Frame",F)
TL.Size=UDim2.new(1,-4,0,1); TL.Position=UDim2.new(0,2,0,0)
TL.BackgroundColor3=SIL; TL.BorderSizePixel=0; TL.ZIndex=15; uic(TL,1)

-- TOPBAR
local TB=Instance.new("Frame",F)
TB.Size=UDim2.new(1,0,0,44); TB.BackgroundColor3=DEEP
TB.BorderSizePixel=0; TB.ZIndex=11
local tbU=Instance.new("UICorner",TB); tbU.CornerRadius=UDim.new(0,8)
local tbF=Instance.new("Frame",TB)
tbF.Size=UDim2.new(1,0,0,8); tbF.Position=UDim2.new(0,0,1,-8)
tbF.BackgroundColor3=DEEP; tbF.BorderSizePixel=0; tbF.ZIndex=11
local tbB=Instance.new("Frame",TB)
tbB.Size=UDim2.new(1,0,0,1); tbB.Position=UDim2.new(0,0,1,-1)
tbB.BackgroundColor3=BRD; tbB.BorderSizePixel=0; tbB.ZIndex=12

local TIco=Instance.new("TextLabel",TB)
TIco.Size=UDim2.new(0,24,0,24); TIco.Position=UDim2.new(0,10,0.5,-12)
TIco.BackgroundColor3=MID; TIco.BorderSizePixel=0; TIco.ZIndex=13
TIco.Text="🗻"; TIco.TextColor3=WHT; TIco.Font=Enum.Font.Gotham; TIco.TextSize=13
TIco.TextXAlignment=Enum.TextXAlignment.Center; TIco.TextYAlignment=Enum.TextYAlignment.Center
uic(TIco,5); usk(TIco,BRD2,1)

local TTi=mkL(TB,"MOUNT ZIHAN v2",WHT,11,Enum.Font.GothamBold)
TTi.Size=UDim2.new(1,-80,0,16); TTi.Position=UDim2.new(0,40,0,7); TTi.ZIndex=13

local TBy=mkL(TB,"BY ALFIAN  ·  SUMMIT CLAIM",DIM,8,Enum.Font.Gotham)
TBy.Size=UDim2.new(1,-80,0,12); TBy.Position=UDim2.new(0,40,0,25); TBy.ZIndex=13

local XB=Instance.new("TextButton",TB)
XB.Size=UDim2.new(0,22,0,22); XB.Position=UDim2.new(1,-30,0.5,-11)
XB.BackgroundColor3=MID; XB.Text="✕"; XB.TextColor3=DIM
XB.Font=Enum.Font.GothamBold; XB.TextSize=9; XB.BorderSizePixel=0; XB.ZIndex=14
uic(XB,5); usk(XB,BRD2,1)
XB.MouseEnter:Connect(function() XB.TextColor3=WHT end)
XB.MouseLeave:Connect(function() XB.TextColor3=DIM end)
XB.MouseButton1Click:Connect(function()
    TweenSvc:Create(F,TweenInfo.new(0.18,Enum.EasingStyle.Quart),
        {Size=UDim2.new(0,230,0,0),BackgroundTransparency=1}):Play()
    task.delay(0.2,function() sg:Destroy() end)
end)

-- BODY
local Body=Instance.new("Frame",F)
Body.Size=UDim2.new(1,-24,1,-56); Body.Position=UDim2.new(0,12,0,50)
Body.BackgroundTransparency=1; Body.ZIndex=11
local BL=Instance.new("UIListLayout",Body)
BL.SortOrder=Enum.SortOrder.LayoutOrder; BL.Padding=UDim.new(0,7)

local function sep(order)
    local l=Instance.new("Frame",Body)
    l.LayoutOrder=order; l.Size=UDim2.new(1,0,0,1)
    l.BackgroundColor3=BRD; l.BorderSizePixel=0; l.ZIndex=12
end

-- FASE INDICATOR (2 langkah)
local FaseRow=Instance.new("Frame",Body)
FaseRow.LayoutOrder=1; FaseRow.Size=UDim2.new(1,0,0,52)
FaseRow.BackgroundTransparency=1; FaseRow.ZIndex=12
local FRL=Instance.new("UIListLayout",FaseRow)
FRL.FillDirection=Enum.FillDirection.Horizontal
FRL.Padding=UDim.new(0,6); FRL.SortOrder=Enum.SortOrder.LayoutOrder

local faseCards = {}
local FASES = {
    {num="1", label="TITIK\nAWAL",  icon="📍"},
    {num="2", label="SUMMIT\nCLAIM", icon="🏔"},
}
for i, fase in ipairs(FASES) do
    local card=Instance.new("Frame",FaseRow)
    card.LayoutOrder=i; card.Size=UDim2.new(0.5,-3,1,0)
    card.BackgroundColor3=MID; card.BorderSizePixel=0; card.ZIndex=13
    uic(card,7)
    local csk=usk(card, i==1 and BRD2 or BRD, 1)

    -- top line
    local ct=Instance.new("Frame",card)
    ct.Size=UDim2.new(1,-4,0,1); ct.Position=UDim2.new(0,2,0,0)
    ct.BackgroundColor3=i==1 and SIL or BRD; ct.BorderSizePixel=0; ct.ZIndex=15
    uic(ct,1)

    local ico=mkL(card,fase.icon,WHT,13,Enum.Font.Gotham,Enum.TextXAlignment.Center)
    ico.Size=UDim2.new(0,22,0,52); ico.Position=UDim2.new(0,6,0,0); ico.ZIndex=14

    local lbl=mkL(card,"FASE "..fase.num,i==1 and WHT or DIM,8,Enum.Font.GothamBold)
    lbl.Size=UDim2.new(1,-34,0,14); lbl.Position=UDim2.new(0,32,0,8); lbl.ZIndex=14

    local sub=mkL(card,fase.label,i==1 and SIL or DIM,8,Enum.Font.Gotham)
    sub.Size=UDim2.new(1,-34,0,28); sub.Position=UDim2.new(0,32,0,22)
    sub.TextWrapped=true; sub.ZIndex=14

    table.insert(faseCards, {card=card, csk=csk, ct=ct, lbl=lbl, sub=sub})
end

-- connector arrow
-- (visual only via UIListLayout gap)

sep(2)

-- KOORDINAT CARDS
local function mkCoordCard(order, label, pos)
    local card=Instance.new("Frame",Body)
    card.LayoutOrder=order; card.Size=UDim2.new(1,0,0,38)
    card.BackgroundColor3=MID; card.BorderSizePixel=0; card.ZIndex=12
    uic(card,6); usk(card,BRD,1)

    local kl=mkL(card,label,DIM,7,Enum.Font.GothamBold)
    kl.Size=UDim2.new(1,-10,0,12); kl.Position=UDim2.new(0,8,0,4); kl.ZIndex=13

    local vl=mkL(card,
        string.format("X %.0f   Y %.0f   Z %.0f", pos.X, pos.Y, pos.Z),
        SIL,9,Enum.Font.Code)
    vl.Size=UDim2.new(1,-10,0,16); vl.Position=UDim2.new(0,8,0,18); vl.ZIndex=13
    return card
end

mkCoordCard(3, "TITIK 1 — BASECAMP AREA", TITIK1)
mkCoordCard(4, "TITIK 2 — SUMMIT / CLAIM", SUMMIT_NEAR)

sep(5)

-- STATUS
local SC=Instance.new("Frame",Body)
SC.LayoutOrder=6; SC.Size=UDim2.new(1,0,0,28)
SC.BackgroundColor3=MID; SC.BorderSizePixel=0; SC.ZIndex=12
uic(SC,6); usk(SC,BRD,1)

local SDot=Instance.new("Frame",SC)
SDot.Size=UDim2.new(0,5,0,5); SDot.Position=UDim2.new(0,10,0.5,-2)
SDot.BackgroundColor3=GR; SDot.BorderSizePixel=0; SDot.ZIndex=13; uic(SDot,5)

local SKy=mkL(SC,"STATUS",DIM,8,Enum.Font.GothamBold)
SKy.Size=UDim2.new(0,44,1,0); SKy.Position=UDim2.new(0,22,0,0); SKy.ZIndex=13

local SVl=mkL(SC,"READY",GR,9,Enum.Font.GothamBold)
SVl.Size=UDim2.new(1,-70,1,0); SVl.Position=UDim2.new(0,68,0,0); SVl.ZIndex=13
SVl.TextTruncate=Enum.TextTruncate.AtEnd

statusCB=function(msg,col)
    SVl.Text=msg
    if col=="done" then SVl.TextColor3=GR; SDot.BackgroundColor3=GR
    elseif col=="err" then SVl.TextColor3=RD; SDot.BackgroundColor3=RD
    elseif col=="wait" then SVl.TextColor3=YL; SDot.BackgroundColor3=YL
    else SVl.TextColor3=WHT; SDot.BackgroundColor3=WHT end
end

-- ANTI-LAG
local AL=Instance.new("Frame",Body)
AL.LayoutOrder=7; AL.Size=UDim2.new(1,0,0,26)
AL.BackgroundColor3=MID; AL.BorderSizePixel=0; AL.ZIndex=12
uic(AL,6); usk(AL,BRD,1)
local ALK=mkL(AL,"ANTI-LAG / LOW GRAPHICS",DIM,8,Enum.Font.GothamBold)
ALK.Size=UDim2.new(0.65,0,1,0); ALK.Position=UDim2.new(0,10,0,0); ALK.ZIndex=13
local ALB=Instance.new("TextButton",AL)
ALB.Size=UDim2.new(0,36,0,17); ALB.Position=UDim2.new(1,-42,0.5,-8)
ALB.BackgroundColor3=MID; ALB.Text="OFF"; ALB.TextColor3=DIM
ALB.Font=Enum.Font.GothamBold; ALB.TextSize=8; ALB.BorderSizePixel=0; ALB.ZIndex=13
uic(ALB,5); local ALsk=usk(ALB,BRD2,1)
local alOn=false
ALB.MouseButton1Click:Connect(function()
    alOn=not alOn
    if alOn then applyAntiLag(); ALB.Text="ON"; ALB.TextColor3=WHT; ALsk.Color=SIL
    else ALB.Text="OFF"; ALB.TextColor3=DIM; ALsk.Color=BRD2 end
end)

sep(8)

-- START BUTTON
local StartBtn=Instance.new("TextButton",Body)
StartBtn.LayoutOrder=9; StartBtn.Size=UDim2.new(1,0,0,38)
StartBtn.BackgroundColor3=WHT; StartBtn.Text="▶  START SEQUENCE"
StartBtn.TextColor3=DEEP; StartBtn.Font=Enum.Font.GothamBold
StartBtn.TextSize=11; StartBtn.BorderSizePixel=0; StartBtn.ZIndex=12
uic(StartBtn,7); usk(StartBtn,BRD2,1)

-- fase highlight update
local function highlightFase(idx)
    for i, fc in ipairs(faseCards) do
        local active = (i == idx)
        fc.card.BackgroundColor3 = active and Color3.fromRGB(28,28,28) or MID
        fc.csk.Color = active and BRD2 or BRD
        fc.ct.BackgroundColor3 = active and WHT or BRD
        fc.lbl.TextColor3 = active and WHT or DIM
        fc.sub.TextColor3 = active and SIL or DIM
    end
end

-- pulse
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
    StartBtn.BackgroundColor3=MID; StartBtn.TextColor3=YL
    StartBtn.Text="⏳  RUNNING..."

    -- highlight fase 1 dulu
    highlightFase(1)

    -- override statusCB untuk update fase
    local origStat = statusCB
    statusCB = function(msg, col)
        origStat(msg, col)
        -- auto switch fase berdasarkan status
        if msg:match("SUMMIT") or msg:match("MENDEKATI") or
           msg:match("LOCATING") or msg:match("FIRING") then
            highlightFase(2)
        elseif msg:match("TITIK AWAL") then
            highlightFase(1)
        end
    end

    runSequence()

    task.spawn(function()
        while running do task.wait(0.1) end
        task.wait(0.5)
        StartBtn.BackgroundColor3=WHT; StartBtn.TextColor3=DEEP
        StartBtn.Text="▶  START SEQUENCE"; pulsing=true
        highlightFase(0)
        statusCB = origStat
    end)
end)

-- F9
UIS.InputBegan:Connect(function(inp,gpe)
    if gpe then return end
    if inp.KeyCode==Enum.KeyCode.F9 then F.Visible=not F.Visible end
end)

-- auto antilag
task.spawn(function()
    task.wait(0.5); applyAntiLag(); alOn=true
    ALB.Text="ON"; ALB.TextColor3=WHT; ALsk.Color=SIL
end)

print("Mount Zihan v2 | By Alfian | F9 toggle")
