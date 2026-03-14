--[[
  AUTO CLAIM VOUCHER — SCAN MAP
  BY ALFIAN
  Tidak pakai koordinat hardcode —
  scan seluruh workspace untuk
  ProximityPrompt "Claim Voucher"
]]

local Players  = game:GetService("Players")
local UIS      = game:GetService("UserInputService")
local TweenSvc = game:GetService("TweenService")
local player   = Players.LocalPlayer

pcall(function()
    for _, g in ipairs(player.PlayerGui:GetChildren()) do
        if g.Name == "ScanClaimAlfian" then g:Destroy() end
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
-- SCAN SELURUH MAP
-- Cari semua ProximityPrompt
-- yang mengandung "claim voucher"
-- ══════════════════════════════
local function scanAllClaimPrompts()
    local results = {}
    for _, v in ipairs(workspace:GetDescendants()) do
        if v:IsA("ProximityPrompt") then
            local at = (v.ActionText or ""):lower()
            local ot = (v.ObjectText or ""):lower()
            local pn = (v.Parent and v.Parent.Name or ""):lower()
            if at:match("claim") or at:match("voucher") or
               ot:match("claim") or ot:match("voucher") or
               pn:match("claim") or pn:match("voucher") then
                local par = v.Parent
                if par then
                    local pos
                    if par:IsA("BasePart") then
                        pos = par.Position
                    elseif par:IsA("Model") then
                        local pp = par.PrimaryPart or par:FindFirstChildWhichIsA("BasePart")
                        pos = pp and pp.Position
                    end
                    if pos then
                        table.insert(results, {
                            prompt  = v,
                            obj     = par,
                            pos     = pos,
                            label   = v.ActionText ~= "" and v.ActionText or pn,
                        })
                    end
                end
            end
        end
    end
    return results
end

local function getOffset(objPos)
    -- posisi 8 stud di depan objek (sumbu Z)
    return objPos + Vector3.new(0, 5, 8)
end

-- ══════════════════════════════
-- CORE
-- ══════════════════════════════
local running  = false
local statusCB = nil
local resultCB = nil  -- update hasil scan di UI

local function setStatus(msg, col)
    if statusCB then statusCB(msg, col) end
end
local function notif(t, m)
    pcall(function()
        game:GetService("StarterGui"):SetCore("SendNotification",
            {Title=t, Text=m, Duration=3})
    end)
end

local function teleportAndFire(promptData)
    local hrp = (player.Character or player.CharacterAdded:Wait())
                    :WaitForChild("HumanoidRootPart", 5)
    if not hrp then
        setStatus("CHARACTER NOT FOUND", "err"); running=false; return
    end
    local hum = hrp.Parent:FindFirstChildOfClass("Humanoid")
    if hum then hum.WalkSpeed = 0 end

    -- TP ke dekat objek
    setStatus("FAST TRAVEL", "wait")
    hrp.CFrame = CFrame.new(getOffset(promptData.pos))
    task.wait(0.25)

    -- posisi lebih presisi: 8 stud dari objek ke arah horizontal
    local dir = (hrp.Position - promptData.pos)
    local safePos
    if dir.Magnitude > 0.1 then
        safePos = promptData.pos + dir.Unit * 8 + Vector3.new(0,4,0)
    else
        safePos = promptData.pos + Vector3.new(0,4,8)
    end
    hrp.CFrame = CFrame.new(safePos)
    task.wait(0.2)

    if hum then hum.WalkSpeed = 16 end
    setStatus("FIRING CLAIM PROMPT", "wait")
    task.wait(0.12)

    -- fire dengan retry
    local fired = false
    for attempt = 1, 3 do
        local ok = pcall(function()
            fireproximityprompt(promptData.prompt)
        end)
        if ok then fired = true; break end
        task.wait(0.08)
    end

    -- nudge jika masih gagal
    if not fired then
        local d = (promptData.pos - hrp.Position)
        if d.Magnitude > 0 then
            hrp.CFrame = CFrame.new(hrp.Position + d.Unit * 3)
        end
        task.wait(0.15)
        pcall(function() fireproximityprompt(promptData.prompt) end)
    end

    setStatus("ARRIVED — CLAIM MANUAL", "done")
    notif("Claim Voucher", "Sudah tiba di " .. promptData.label)
    running = false
end

local function runScan(autoTeleport)
    if running then return end
    running = true

    task.spawn(function()
        setStatus("SCANNING MAP", "wait")
        task.wait(0.3)

        local results = scanAllClaimPrompts()

        if #results == 0 then
            setStatus("TIDAK DITEMUKAN", "err")
            notif("Scan", "Tidak ada Claim Voucher di map ini.")
            running = false
            return
        end

        -- update UI dengan hasil
        setStatus("DITEMUKAN " .. #results .. " TITIK", "done")
        if resultCB then resultCB(results) end

        if autoTeleport then
            -- langsung TP ke yang pertama
            task.wait(0.2)
            teleportAndFire(results[1])
        else
            running = false
        end
    end)
end

local function runTeleportTo(promptData)
    if running then return end
    running = true
    task.spawn(function()
        teleportAndFire(promptData)
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

local function uic(p, r)
    local u = Instance.new("UICorner", p); u.CornerRadius=UDim.new(0,r or 6)
end
local function usk(p, c, t)
    local s = Instance.new("UIStroke", p); s.Color=c or BRD; s.Thickness=t or 1; return s
end
local function mkLbl(parent, txt, col, sz, font, xa)
    local l = Instance.new("TextLabel", parent)
    l.BackgroundTransparency=1; l.Text=txt or ""
    l.TextColor3=col or WHT; l.Font=font or Enum.Font.Gotham
    l.TextSize=sz or 10; l.ZIndex=14
    l.TextXAlignment=xa or Enum.TextXAlignment.Left
    return l
end

local sg = Instance.new("ScreenGui")
sg.Name="ScanClaimAlfian"; sg.ResetOnSpawn=false
sg.DisplayOrder=9999; sg.IgnoreGuiInset=true
sg.ZIndexBehavior=Enum.ZIndexBehavior.Sibling
sg.Parent=player.PlayerGui

-- FRAME UTAMA
local F = Instance.new("Frame", sg)
F.Size=UDim2.new(0,240,0,320); F.Position=UDim2.new(0.5,-120,0.5,-160)
F.BackgroundColor3=PNL; F.BorderSizePixel=0
F.Active=true; F.Draggable=true; F.ZIndex=10
uic(F,8); usk(F,BRD,1)

-- top accent
local TL=Instance.new("Frame",F)
TL.Size=UDim2.new(1,-4,0,1); TL.Position=UDim2.new(0,2,0,0)
TL.BackgroundColor3=SIL; TL.BorderSizePixel=0; TL.ZIndex=15
uic(TL,1)

-- TOPBAR
local TB=Instance.new("Frame",F)
TB.Size=UDim2.new(1,0,0,44); TB.BackgroundColor3=DEEP
TB.BorderSizePixel=0; TB.ZIndex=11
local tbUIC=Instance.new("UICorner",TB); tbUIC.CornerRadius=UDim.new(0,8)
local tbFix=Instance.new("Frame",TB)
tbFix.Size=UDim2.new(1,0,0,8); tbFix.Position=UDim2.new(0,0,1,-8)
tbFix.BackgroundColor3=DEEP; tbFix.BorderSizePixel=0; tbFix.ZIndex=11
local tbBot=Instance.new("Frame",TB)
tbBot.Size=UDim2.new(1,0,0,1); tbBot.Position=UDim2.new(0,0,1,-1)
tbBot.BackgroundColor3=BRD; tbBot.BorderSizePixel=0; tbBot.ZIndex=12

local TIcon=Instance.new("TextLabel",TB)
TIcon.Size=UDim2.new(0,24,0,24); TIcon.Position=UDim2.new(0,10,0.5,-12)
TIcon.BackgroundColor3=MID; TIcon.BorderSizePixel=0; TIcon.ZIndex=13
TIcon.Text="🔍"; TIcon.TextColor3=WHT; TIcon.Font=Enum.Font.Gotham; TIcon.TextSize=12
TIcon.TextXAlignment=Enum.TextXAlignment.Center; TIcon.TextYAlignment=Enum.TextYAlignment.Center
uic(TIcon,5); usk(TIcon,BRD2,1)

local TTit=mkLbl(TB,"AUTO CLAIM VOUCHER",WHT,11,Enum.Font.GothamBold)
TTit.Size=UDim2.new(1,-80,0,16); TTit.Position=UDim2.new(0,40,0,7); TTit.ZIndex=13

local TBy=mkLbl(TB,"BY ALFIAN  ·  MAP SCANNER",DIM,8,Enum.Font.Gotham)
TBy.Size=UDim2.new(1,-80,0,12); TBy.Position=UDim2.new(0,40,0,25); TBy.ZIndex=13

local XBtn=Instance.new("TextButton",TB)
XBtn.Size=UDim2.new(0,22,0,22); XBtn.Position=UDim2.new(1,-30,0.5,-11)
XBtn.BackgroundColor3=MID; XBtn.Text="✕"; XBtn.TextColor3=DIM
XBtn.Font=Enum.Font.GothamBold; XBtn.TextSize=9; XBtn.BorderSizePixel=0; XBtn.ZIndex=14
uic(XBtn,5); usk(XBtn,BRD2,1)
XBtn.MouseEnter:Connect(function() XBtn.TextColor3=WHT end)
XBtn.MouseLeave:Connect(function() XBtn.TextColor3=DIM end)
XBtn.MouseButton1Click:Connect(function()
    TweenSvc:Create(F,TweenInfo.new(0.18,Enum.EasingStyle.Quart),
        {Size=UDim2.new(0,240,0,0),BackgroundTransparency=1}):Play()
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

-- STATUS CARD
local StatCard=Instance.new("Frame",Body)
StatCard.LayoutOrder=1; StatCard.Size=UDim2.new(1,0,0,28)
StatCard.BackgroundColor3=MID; StatCard.BorderSizePixel=0; StatCard.ZIndex=12
uic(StatCard,6); usk(StatCard,BRD,1)

local SDot=Instance.new("Frame",StatCard)
SDot.Size=UDim2.new(0,5,0,5); SDot.Position=UDim2.new(0,10,0.5,-2)
SDot.BackgroundColor3=GR; SDot.BorderSizePixel=0; SDot.ZIndex=13; uic(SDot,5)

local SKey=mkLbl(StatCard,"STATUS",DIM,8,Enum.Font.GothamBold)
SKey.Size=UDim2.new(0,44,1,0); SKey.Position=UDim2.new(0,22,0,0); SKey.ZIndex=13

local SVal=mkLbl(StatCard,"SIAP SCAN",GR,9,Enum.Font.GothamBold)
SVal.Size=UDim2.new(1,-70,1,0); SVal.Position=UDim2.new(0,68,0,0); SVal.ZIndex=13
SVal.TextTruncate=Enum.TextTruncate.AtEnd

statusCB=function(msg,col)
    SVal.Text=msg
    if col=="done" then SVal.TextColor3=GR; SDot.BackgroundColor3=GR
    elseif col=="err" then SVal.TextColor3=RD; SDot.BackgroundColor3=RD
    elseif col=="wait" then SVal.TextColor3=YL; SDot.BackgroundColor3=YL
    else SVal.TextColor3=WHT; SDot.BackgroundColor3=WHT end
end

sep(2)

-- HASIL SCAN — scrolling list
local ScanLabel=mkLbl(Body,"HASIL SCAN",DIM,7,Enum.Font.GothamBold)
ScanLabel.LayoutOrder=3; ScanLabel.Size=UDim2.new(1,0,0,12); ScanLabel.ZIndex=12

local ResultScroll=Instance.new("ScrollingFrame",Body)
ResultScroll.LayoutOrder=4; ResultScroll.Size=UDim2.new(1,0,0,100)
ResultScroll.BackgroundColor3=DEEP; ResultScroll.BorderSizePixel=0; ResultScroll.ZIndex=12
ResultScroll.ScrollBarThickness=2; ResultScroll.ScrollBarImageColor3=BRD2
ResultScroll.CanvasSize=UDim2.new(0,0,0,0); ResultScroll.AutomaticCanvasSize=Enum.AutomaticSize.Y
uic(ResultScroll,6); usk(ResultScroll,BRD,1)
local RSpad=Instance.new("UIPadding",ResultScroll)
RSpad.PaddingLeft=UDim.new(0,6); RSpad.PaddingRight=UDim.new(0,6)
RSpad.PaddingTop=UDim.new(0,5); RSpad.PaddingBottom=UDim.new(0,5)
local RSlay=Instance.new("UIListLayout",ResultScroll)
RSlay.SortOrder=Enum.SortOrder.LayoutOrder; RSlay.Padding=UDim.new(0,4)

-- placeholder
local PHlbl=mkLbl(ResultScroll,"Tekan SCAN untuk mencari titik Claim Voucher di map...",DIM,8,Enum.Font.Gotham)
PHlbl.Size=UDim2.new(1,0,0,50); PHlbl.TextWrapped=true; PHlbl.ZIndex=13
PHlbl.LayoutOrder=0

local scanResults = {}

resultCB=function(results)
    -- clear lama
    for _, c in ipairs(ResultScroll:GetChildren()) do
        if c:IsA("Frame") or c:IsA("TextLabel") then c:Destroy() end
    end
    scanResults = results

    for i, r in ipairs(results) do
        local row=Instance.new("Frame",ResultScroll)
        row.LayoutOrder=i; row.Size=UDim2.new(1,0,0,34)
        row.BackgroundColor3=MID; row.BorderSizePixel=0; row.ZIndex=13
        uic(row,5); usk(row,BRD,1)

        -- nomor
        local num=mkLbl(row,"#"..i,DIM,8,Enum.Font.GothamBold,Enum.TextXAlignment.Center)
        num.Size=UDim2.new(0,18,0,34); num.ZIndex=14

        -- label & koordinat
        local rName=mkLbl(row, r.label~="" and r.label or "Claim Voucher", WHT,9,Enum.Font.GothamBold)
        rName.Size=UDim2.new(1,-80,0,16); rName.Position=UDim2.new(0,22,0,4); rName.ZIndex=14

        local rCoord=mkLbl(row,
            string.format("%.0f  %.0f  %.0f",r.pos.X,r.pos.Y,r.pos.Z),
            DIM,7,Enum.Font.Code)
        rCoord.Size=UDim2.new(1,-80,0,12); rCoord.Position=UDim2.new(0,22,0,20); rCoord.ZIndex=14

        -- tombol TP
        local tpBtn=Instance.new("TextButton",row)
        tpBtn.Size=UDim2.new(0,40,0,22); tpBtn.Position=UDim2.new(1,-46,0.5,-11)
        tpBtn.BackgroundColor3=MID; tpBtn.Text="TP"
        tpBtn.TextColor3=SIL; tpBtn.Font=Enum.Font.GothamBold
        tpBtn.TextSize=9; tpBtn.BorderSizePixel=0; tpBtn.ZIndex=14
        uic(tpBtn,5); local tpsk=usk(tpBtn,BRD2,1)
        tpBtn.MouseEnter:Connect(function() tpBtn.TextColor3=WHT; tpsk.Color=SIL end)
        tpBtn.MouseLeave:Connect(function() tpBtn.TextColor3=SIL; tpsk.Color=BRD2 end)

        local capturedR = r
        tpBtn.MouseButton1Click:Connect(function()
            if running then return end
            tpBtn.Text="..."; tpBtn.TextColor3=YL
            runTeleportTo(capturedR)
            task.spawn(function()
                while running do task.wait(0.1) end
                tpBtn.Text="TP"; tpBtn.TextColor3=SIL
            end)
        end)
    end
end

sep(5)

-- ANTI-LAG ROW
local ALRow=Instance.new("Frame",Body)
ALRow.LayoutOrder=6; ALRow.Size=UDim2.new(1,0,0,26)
ALRow.BackgroundColor3=MID; ALRow.BorderSizePixel=0; ALRow.ZIndex=12
uic(ALRow,6); usk(ALRow,BRD,1)

local ALKey=mkLbl(ALRow,"ANTI-LAG / LOW GRAPHICS",DIM,8,Enum.Font.GothamBold)
ALKey.Size=UDim2.new(0.65,0,1,0); ALKey.Position=UDim2.new(0,10,0,0); ALKey.ZIndex=13

local ALBtn=Instance.new("TextButton",ALRow)
ALBtn.Size=UDim2.new(0,36,0,17); ALBtn.Position=UDim2.new(1,-42,0.5,-8)
ALBtn.BackgroundColor3=MID; ALBtn.Text="OFF"; ALBtn.TextColor3=DIM
ALBtn.Font=Enum.Font.GothamBold; ALBtn.TextSize=8; ALBtn.BorderSizePixel=0; ALBtn.ZIndex=13
uic(ALBtn,5); local ALsk=usk(ALBtn,BRD2,1)
local alOn=false
ALBtn.MouseButton1Click:Connect(function()
    alOn=not alOn
    if alOn then applyAntiLag(); ALBtn.Text="ON"; ALBtn.TextColor3=WHT; ALsk.Color=SIL
    else ALBtn.Text="OFF"; ALBtn.TextColor3=DIM; ALsk.Color=BRD2 end
end)

-- 2 BUTTON BAWAH: SCAN + START
local BtnRow=Instance.new("Frame",Body)
BtnRow.LayoutOrder=7; BtnRow.Size=UDim2.new(1,0,0,36)
BtnRow.BackgroundTransparency=1; BtnRow.ZIndex=12
local BRL=Instance.new("UIListLayout",BtnRow)
BRL.FillDirection=Enum.FillDirection.Horizontal; BRL.Padding=UDim.new(0,7)
BRL.SortOrder=Enum.SortOrder.LayoutOrder

-- SCAN BUTTON
local ScanBtn=Instance.new("TextButton",BtnRow)
ScanBtn.LayoutOrder=1; ScanBtn.Size=UDim2.new(0.42,0,1,0)
ScanBtn.BackgroundColor3=MID; ScanBtn.Text="🔍 SCAN"
ScanBtn.TextColor3=SIL; ScanBtn.Font=Enum.Font.GothamBold
ScanBtn.TextSize=10; ScanBtn.BorderSizePixel=0; ScanBtn.ZIndex=12
uic(ScanBtn,7); usk(ScanBtn,BRD2,1)
ScanBtn.MouseEnter:Connect(function() ScanBtn.TextColor3=WHT end)
ScanBtn.MouseLeave:Connect(function() ScanBtn.TextColor3=SIL end)
ScanBtn.MouseButton1Click:Connect(function()
    if running then return end
    ScanBtn.Text="..."; ScanBtn.TextColor3=YL
    runScan(false) -- scan saja, tidak auto TP
    task.spawn(function()
        while running do task.wait(0.1) end
        task.wait(0.3)
        ScanBtn.Text="🔍 SCAN"; ScanBtn.TextColor3=SIL
    end)
end)

-- START BUTTON (scan + auto TP ke pertama)
local StartBtn=Instance.new("TextButton",BtnRow)
StartBtn.LayoutOrder=2; StartBtn.Size=UDim2.new(0.58,-7,1,0)
StartBtn.BackgroundColor3=WHT; StartBtn.Text="▶ START"
StartBtn.TextColor3=DEEP; StartBtn.Font=Enum.Font.GothamBold
StartBtn.TextSize=11; StartBtn.BorderSizePixel=0; StartBtn.ZIndex=12
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
    StartBtn.BackgroundColor3=MID; StartBtn.TextColor3=YL; StartBtn.Text="SCANNING..."
    runScan(true) -- scan + auto TP
    task.spawn(function()
        while running do task.wait(0.1) end
        task.wait(0.4)
        StartBtn.BackgroundColor3=WHT; StartBtn.TextColor3=DEEP; StartBtn.Text="▶ START"
        pulsing=true
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
    ALBtn.Text="ON"; ALBtn.TextColor3=WHT; ALsk.Color=SIL
end)

print("Auto Claim Voucher — Map Scanner | By Alfian | F9 toggle")
```
