--[[
  AUTO CLAIM VOUCHER — UNIVERSAL MAP SCANNER
  BY ALFIAN
  Bekerja di map apapun yang ada Claim Voucher
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
-- UNIVERSAL SCANNER
-- Pola dari semua log yang ada:
--   map 1: obj="Part"
--   map 2: obj="RedemptionPointBasepart"
--   + scan ProximityPrompt langsung
--   + scan BillboardGui/SurfaceGui text
--   + scan nama objek umum voucher
-- ══════════════════════════════

-- nama objek yang diketahui dari log
local KNOWN_OBJ_NAMES = {
    "RedemptionPointBasepart",
    "RedemptionPoint",
    "Gopay",
    "GopayPoint",
    "VoucherPoint",
    "ClaimPoint",
    "Primary",
    "Part",
}

-- keyword untuk match nama / text
local CLAIM_KEYWORDS = {
    "claim voucher",
    "claim",
    "voucher",
    "redeem",
    "redemption",
    "gopay",
    "klaim",
}

local function containsKeyword(str)
    if not str or str == "" then return false end
    local s = str:lower()
    for _, kw in ipairs(CLAIM_KEYWORDS) do
        if s:match(kw) then return true end
    end
    return false
end

local function isKnownObjName(name)
    local nl = name:lower()
    for _, n in ipairs(KNOWN_OBJ_NAMES) do
        if nl == n:lower() then return true end
    end
    -- partial match untuk nama seperti "RedemptionPointBasepart_v2"
    if nl:match("redemption") or nl:match("gopay") or
       nl:match("voucher") or nl:match("claim") then
        return true
    end
    return false
end

local function getPartPos(obj)
    if obj:IsA("BasePart") then return obj.Position end
    if obj:IsA("Model") then
        local pp = obj.PrimaryPart or obj:FindFirstChildWhichIsA("BasePart")
        return pp and pp.Position
    end
    return nil
end

local function scanAllClaimPrompts()
    local results = {}
    local seen    = {} -- deduplicate by prompt instance

    -- ── PASS 1: ProximityPrompt langsung ──
    -- Ini paling akurat, ActionText dari game
    for _, v in ipairs(workspace:GetDescendants()) do
        if v:IsA("ProximityPrompt") and not seen[v] then
            local at = v.ActionText or ""
            local ot = v.ObjectText or ""
            local pn = v.Parent and v.Parent.Name or ""

            if containsKeyword(at) or containsKeyword(ot) or isKnownObjName(pn) then
                local par = v.Parent
                if par then
                    local pos = getPartPos(par)
                    if pos then
                        seen[v] = true
                        table.insert(results, {
                            prompt = v,
                            obj    = par,
                            pos    = pos,
                            label  = at ~= "" and at or (ot ~= "" and ot or pn),
                            src    = "ProximityPrompt",
                        })
                    end
                end
            end
        end
    end

    -- ── PASS 2: Objek dengan nama dikenal → cari prompt di dalamnya ──
    for _, v in ipairs(workspace:GetDescendants()) do
        if (v:IsA("BasePart") or v:IsA("Model")) and isKnownObjName(v.Name) then
            local pos = getPartPos(v)
            if pos then
                -- cari ProximityPrompt di dalam/di parent
                local function findPromptIn(obj)
                    for _, c in ipairs(obj:GetDescendants()) do
                        if c:IsA("ProximityPrompt") and not seen[c] then
                            return c
                        end
                    end
                    return nil
                end
                local pr = findPromptIn(v)
                -- juga cek parent model
                if not pr and v.Parent and v.Parent:IsA("Model") then
                    pr = findPromptIn(v.Parent)
                end
                if pr and not seen[pr] then
                    seen[pr] = true
                    table.insert(results, {
                        prompt = pr,
                        obj    = v,
                        pos    = pos,
                        label  = pr.ActionText ~= "" and pr.ActionText or v.Name,
                        src    = "ObjName:" .. v.Name,
                    })
                elseif not pr then
                    -- objek dikenal tapi tidak ada prompt → tetap masukkan
                    -- user bisa TP manual lalu claim sendiri
                    local fakeKey = tostring(v:GetDebugId())
                    if not seen[fakeKey] then
                        seen[fakeKey] = true
                        table.insert(results, {
                            prompt = nil,
                            obj    = v,
                            pos    = pos,
                            label  = v.Name,
                            src    = "ObjOnly:" .. v.Name,
                        })
                    end
                end
            end
        end
    end

    -- ── PASS 3: BillboardGui / SurfaceGui dengan text keyword ──
    for _, v in ipairs(workspace:GetDescendants()) do
        if v:IsA("BillboardGui") or v:IsA("SurfaceGui") then
            local par = v.Parent
            if par and (par:IsA("BasePart") or par:IsA("Model")) then
                for _, c in ipairs(v:GetDescendants()) do
                    if (c:IsA("TextLabel") or c:IsA("TextButton")) and
                       containsKeyword(c.Text) then
                        local pos = getPartPos(par)
                        if pos then
                            -- cari prompt terdekat
                            local pr = nil
                            for _, d in ipairs(par:GetDescendants()) do
                                if d:IsA("ProximityPrompt") and not seen[d] then
                                    pr = d; break
                                end
                            end
                            local key = tostring(par:GetDebugId())
                            if not seen[key] then
                                seen[key]  = true
                                if pr then seen[pr] = true end
                                table.insert(results, {
                                    prompt = pr,
                                    obj    = par,
                                    pos    = pos,
                                    label  = c.Text,
                                    src    = "Billboard",
                                })
                            end
                        end
                        break
                    end
                end
            end
        end
    end

    return results
end

-- ══════════════════════════════
-- CORE TELEPORT + FIRE
-- ══════════════════════════════
local running  = false
local statusCB = nil
local resultCB = nil

local function setStatus(msg, col)
    if statusCB then statusCB(msg, col) end
end
local function notif(t, m)
    pcall(function()
        game:GetService("StarterGui"):SetCore("SendNotification",
            {Title=t, Text=m, Duration=3})
    end)
end

local function teleportAndFire(data)
    local char = player.Character or player.CharacterAdded:Wait()
    local hrp  = char:WaitForChild("HumanoidRootPart", 5)
    if not hrp then
        setStatus("CHARACTER NOT FOUND", "err"); running=false; return
    end
    local hum = char:FindFirstChildOfClass("Humanoid")
    if hum then hum.WalkSpeed = 0 end

    -- TP offset 8 stud
    setStatus("FAST TRAVEL", "wait")
    local safePos = data.pos + Vector3.new(0, 5, 8)
    hrp.CFrame = CFrame.new(safePos)
    task.wait(0.25)

    -- refined offset ke arah dari objek
    local dir = (hrp.Position - data.pos)
    if dir.Magnitude > 0.1 then
        safePos = data.pos + dir.Unit * 8 + Vector3.new(0, 4, 0)
    end
    hrp.CFrame = CFrame.new(safePos)
    task.wait(0.2)

    if hum then hum.WalkSpeed = 16 end

    if data.prompt then
        setStatus("FIRING PROMPT", "wait")
        task.wait(0.12)
        local fired = false
        for _ = 1, 3 do
            local ok = pcall(function() fireproximityprompt(data.prompt) end)
            if ok then fired=true; break end
            task.wait(0.08)
        end
        -- nudge jika gagal
        if not fired then
            local d = (data.pos - hrp.Position)
            if d.Magnitude > 0 then
                hrp.CFrame = CFrame.new(hrp.Position + d.Unit * 3)
            end
            task.wait(0.15)
            pcall(function() fireproximityprompt(data.prompt) end)
        end
        setStatus("ARRIVED — CLAIM MANUAL", "done")
    else
        -- tidak ada prompt → TP saja, user tap sendiri
        setStatus("TIBA — TAP CLAIM MANUAL", "done")
    end

    notif("Claim Voucher", "Tiba di: " .. data.label)
    running = false
end

local function runScan(autoTP)
    if running then return end
    running = true
    task.spawn(function()
        setStatus("SCANNING MAP...", "wait")
        task.wait(0.3)
        local results = scanAllClaimPrompts()
        if #results == 0 then
            setStatus("TIDAK DITEMUKAN", "err")
            notif("Scanner", "Tidak ada Claim Voucher di map ini.")
            running = false; return
        end
        setStatus("DITEMUKAN " .. #results .. " TITIK", "done")
        if resultCB then resultCB(results) end
        if autoTP then
            task.wait(0.2)
            teleportAndFire(results[1])
        else
            running = false
        end
    end)
end

local function runTP(data)
    if running then return end
    running = true
    task.spawn(function() teleportAndFire(data) end)
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
sg.Name="ScanClaimAlfian"; sg.ResetOnSpawn=false
sg.DisplayOrder=9999; sg.IgnoreGuiInset=true
sg.ZIndexBehavior=Enum.ZIndexBehavior.Sibling
sg.Parent=player.PlayerGui

local F=Instance.new("Frame",sg)
F.Size=UDim2.new(0,248,0,330); F.Position=UDim2.new(0.5,-124,0.5,-165)
F.BackgroundColor3=PNL; F.BorderSizePixel=0
F.Active=true; F.Draggable=true; F.ZIndex=10
uic(F,8); usk(F,BRD,1)

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
TIco.Text="🔍"; TIco.TextColor3=WHT; TIco.Font=Enum.Font.Gotham; TIco.TextSize=12
TIco.TextXAlignment=Enum.TextXAlignment.Center; TIco.TextYAlignment=Enum.TextYAlignment.Center
uic(TIco,5); usk(TIco,BRD2,1)

local TTi=mkL(TB,"UNIVERSAL CLAIM SCANNER",WHT,10,Enum.Font.GothamBold)
TTi.Size=UDim2.new(1,-80,0,16); TTi.Position=UDim2.new(0,40,0,7); TTi.ZIndex=13

local TBy=mkL(TB,"BY ALFIAN  ·  WORKS ON ANY MAP",DIM,7,Enum.Font.Gotham)
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
        {Size=UDim2.new(0,248,0,0),BackgroundTransparency=1}):Play()
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

-- STATUS
local SC=Instance.new("Frame",Body)
SC.LayoutOrder=1; SC.Size=UDim2.new(1,0,0,28)
SC.BackgroundColor3=MID; SC.BorderSizePixel=0; SC.ZIndex=12
uic(SC,6); usk(SC,BRD,1)

local SDot=Instance.new("Frame",SC)
SDot.Size=UDim2.new(0,5,0,5); SDot.Position=UDim2.new(0,10,0.5,-2)
SDot.BackgroundColor3=GR; SDot.BorderSizePixel=0; SDot.ZIndex=13; uic(SDot,5)

local SKy=mkL(SC,"STATUS",DIM,8,Enum.Font.GothamBold)
SKy.Size=UDim2.new(0,44,1,0); SKy.Position=UDim2.new(0,22,0,0); SKy.ZIndex=13

local SVl=mkL(SC,"SIAP SCAN",GR,9,Enum.Font.GothamBold)
SVl.Size=UDim2.new(1,-70,1,0); SVl.Position=UDim2.new(0,68,0,0); SVl.ZIndex=13
SVl.TextTruncate=Enum.TextTruncate.AtEnd

statusCB=function(msg,col)
    SVl.Text=msg
    if col=="done" then SVl.TextColor3=GR; SDot.BackgroundColor3=GR
    elseif col=="err" then SVl.TextColor3=RD; SDot.BackgroundColor3=RD
    elseif col=="wait" then SVl.TextColor3=YL; SDot.BackgroundColor3=YL
    else SVl.TextColor3=WHT; SDot.BackgroundColor3=WHT end
end

sep(2)

-- INFO: scan pattern
local InfoCard=Instance.new("Frame",Body)
InfoCard.LayoutOrder=3; InfoCard.Size=UDim2.new(1,0,0,38)
InfoCard.BackgroundColor3=MID; InfoCard.BorderSizePixel=0; InfoCard.ZIndex=12
uic(InfoCard,6); usk(InfoCard,BRD,1)
local IK=mkL(InfoCard,"SCAN PATTERN",DIM,7,Enum.Font.GothamBold)
IK.Size=UDim2.new(1,-10,0,12); IK.Position=UDim2.new(0,8,0,4); IK.ZIndex=13
local IV=mkL(InfoCard,"ProximityPrompt · Nama Objek · BillboardGui",SIL,8,Enum.Font.Gotham)
IV.Size=UDim2.new(1,-10,0,12); IV.Position=UDim2.new(0,8,0,18); IV.ZIndex=13
local IV2=mkL(InfoCard,"claim · voucher · redemption · gopay · klaim",DIM,7,Enum.Font.Code)
IV2.Size=UDim2.new(1,-10,0,12); IV2.Position=UDim2.new(0,8,0,28); IV2.ZIndex=13

sep(4)

-- HASIL SCAN
local SLb=mkL(Body,"HASIL SCAN",DIM,7,Enum.Font.GothamBold)
SLb.LayoutOrder=5; SLb.Size=UDim2.new(1,0,0,12); SLb.ZIndex=12

local RS=Instance.new("ScrollingFrame",Body)
RS.LayoutOrder=6; RS.Size=UDim2.new(1,0,0,96)
RS.BackgroundColor3=DEEP; RS.BorderSizePixel=0; RS.ZIndex=12
RS.ScrollBarThickness=2; RS.ScrollBarImageColor3=BRD2
RS.CanvasSize=UDim2.new(0,0,0,0); RS.AutomaticCanvasSize=Enum.AutomaticSize.Y
uic(RS,6); usk(RS,BRD,1)
local RSp=Instance.new("UIPadding",RS)
RSp.PaddingLeft=UDim.new(0,6); RSp.PaddingRight=UDim.new(0,6)
RSp.PaddingTop=UDim.new(0,5); RSp.PaddingBottom=UDim.new(0,5)
local RSl=Instance.new("UIListLayout",RS)
RSl.SortOrder=Enum.SortOrder.LayoutOrder; RSl.Padding=UDim.new(0,4)

local PH=mkL(RS,"Tekan SCAN atau START untuk mencari Claim Voucher...",DIM,8,Enum.Font.Gotham)
PH.Size=UDim2.new(1,0,0,50); PH.TextWrapped=true; PH.ZIndex=13; PH.LayoutOrder=0

resultCB=function(results)
    for _, c in ipairs(RS:GetChildren()) do
        if c:IsA("Frame") or c:IsA("TextLabel") then c:Destroy() end
    end
    for i, r in ipairs(results) do
        local row=Instance.new("Frame",RS)
        row.LayoutOrder=i; row.Size=UDim2.new(1,0,0,36)
        row.BackgroundColor3=MID; row.BorderSizePixel=0; row.ZIndex=13
        uic(row,5); usk(row,BRD,1)

        -- badge sumber
        local srcBadge=Instance.new("TextLabel",row)
        srcBadge.Size=UDim2.new(0,16,0,36)
        srcBadge.BackgroundColor3=r.prompt and Color3.fromRGB(30,30,30) or Color3.fromRGB(25,25,25)
        srcBadge.BorderSizePixel=0; srcBadge.ZIndex=14
        srcBadge.Text=""; srcBadge.Font=Enum.Font.Gotham; srcBadge.TextSize=7
        uic(srcBadge,5)
        local dot2=Instance.new("Frame",srcBadge)
        dot2.Size=UDim2.new(0,4,0,4); dot2.Position=UDim2.new(0.5,-2,0.5,-2)
        dot2.BackgroundColor3=r.prompt and GR or YL; dot2.BorderSizePixel=0; dot2.ZIndex=15
        uic(dot2,5)

        local numL=mkL(row,"#"..i,DIM,8,Enum.Font.GothamBold,Enum.TextXAlignment.Center)
        numL.Size=UDim2.new(0,18,0,36); numL.Position=UDim2.new(0,18,0,0); numL.ZIndex=14

        local maxLabel = #r.label > 20 and r.label:sub(1,18).."…" or r.label
        local rN=mkL(row,maxLabel,WHT,9,Enum.Font.GothamBold)
        rN.Size=UDim2.new(1,-88,0,16); rN.Position=UDim2.new(0,38,0,4); rN.ZIndex=14

        local rC=mkL(row,
            string.format("%.0f  %.0f  %.0f",r.pos.X,r.pos.Y,r.pos.Z),
            DIM,7,Enum.Font.Code)
        rC.Size=UDim2.new(1,-88,0,12); rC.Position=UDim2.new(0,38,0,21); rC.ZIndex=14

        -- prompt badge
        local pBadge=mkL(row, r.prompt and "PROMPT✓" or "OBJ ONLY", r.prompt and GR or YL, 6, Enum.Font.GothamBold)
        pBadge.Size=UDim2.new(0,50,0,10); pBadge.Position=UDim2.new(0,38,0,25); pBadge.ZIndex=15

        local tpB=Instance.new("TextButton",row)
        tpB.Size=UDim2.new(0,38,0,22); tpB.Position=UDim2.new(1,-44,0.5,-11)
        tpB.BackgroundColor3=MID; tpB.Text="TP"
        tpB.TextColor3=SIL; tpB.Font=Enum.Font.GothamBold
        tpB.TextSize=9; tpB.BorderSizePixel=0; tpB.ZIndex=14
        uic(tpB,5); local tsk=usk(tpB,BRD2,1)
        tpB.MouseEnter:Connect(function() tpB.TextColor3=WHT; tsk.Color=SIL end)
        tpB.MouseLeave:Connect(function() tpB.TextColor3=SIL; tsk.Color=BRD2 end)

        local cap=r
        tpB.MouseButton1Click:Connect(function()
            if running then return end
            tpB.Text="..."; tpB.TextColor3=YL
            runTP(cap)
            task.spawn(function()
                while running do task.wait(0.1) end
                tpB.Text="TP"; tpB.TextColor3=SIL
            end)
        end)
    end
end

sep(7)

-- ANTI-LAG
local AL=Instance.new("Frame",Body)
AL.LayoutOrder=8; AL.Size=UDim2.new(1,0,0,26)
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

-- BUTTONS
local BR=Instance.new("Frame",Body)
BR.LayoutOrder=9; BR.Size=UDim2.new(1,0,0,36)
BR.BackgroundTransparency=1; BR.ZIndex=12
local BRL=Instance.new("UIListLayout",BR)
BRL.FillDirection=Enum.FillDirection.Horizontal
BRL.Padding=UDim.new(0,7); BRL.SortOrder=Enum.SortOrder.LayoutOrder

local ScanBtn=Instance.new("TextButton",BR)
ScanBtn.LayoutOrder=1; ScanBtn.Size=UDim2.new(0.4,0,1,0)
ScanBtn.BackgroundColor3=MID; ScanBtn.Text="🔍 SCAN"
ScanBtn.TextColor3=SIL; ScanBtn.Font=Enum.Font.GothamBold
ScanBtn.TextSize=10; ScanBtn.BorderSizePixel=0; ScanBtn.ZIndex=12
uic(ScanBtn,7); usk(ScanBtn,BRD2,1)
ScanBtn.MouseEnter:Connect(function() ScanBtn.TextColor3=WHT end)
ScanBtn.MouseLeave:Connect(function() ScanBtn.TextColor3=SIL end)
ScanBtn.MouseButton1Click:Connect(function()
    if running then return end
    ScanBtn.Text="..."; ScanBtn.TextColor3=YL
    runScan(false)
    task.spawn(function()
        while running do task.wait(0.1) end
        task.wait(0.2)
        ScanBtn.Text="🔍 SCAN"; ScanBtn.TextColor3=SIL
    end)
end)

local StartBtn=Instance.new("TextButton",BR)
StartBtn.LayoutOrder=2; StartBtn.Size=UDim2.new(0.6,-7,1,0)
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
    runScan(true)
    task.spawn(function()
        while running do task.wait(0.1) end
        task.wait(0.4)
        StartBtn.BackgroundColor3=WHT; StartBtn.TextColor3=DEEP; StartBtn.Text="▶ START"
        pulsing=true
    end)
end)

UIS.InputBegan:Connect(function(inp,gpe)
    if gpe then return end
    if inp.KeyCode==Enum.KeyCode.F9 then F.Visible=not F.Visible end
end)

task.spawn(function()
    task.wait(0.5); applyAntiLag(); alOn=true
    ALB.Text="ON"; ALB.TextColor3=WHT; ALsk.Color=SIL
end)

print("Universal Claim Scanner | By Alfian | F9 toggle")
