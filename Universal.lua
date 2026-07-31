-- ============================================================
--  DX8-Main.lua  — Universal Features (v2)
--  Fitur-fitur yang berlaku di SEMUA game
--  Fitur game-spesifik ada di Games/<NamaGame>.lua
-- ============================================================

local _DX8_LIB_URL = "https://raw.githubusercontent.com/d8nte/DX8/main/Library.lua"
local _dx8ok, _dx8lib = pcall(function()
    return loadstring(game:HttpGet(_DX8_LIB_URL, true))()
end)
if not _dx8ok or not _dx8lib then
    error("[IDV Merged] Gagal load DX8 Library dari GitHub: " .. tostring(_dx8lib))
end

local DX8 = _dx8lib
_G.DX8_Library = DX8
print("[IDV Merged] DX8 Library loaded from GitHub OK")

local win = DX8:CreateWindow({
    Name      = "Indo Voice",
    Community = "https://discord.gg/",
    ToggleKey = Enum.KeyCode.RightControl,
})
_G.DX8_MainWindow = win
print("[IDV Merged] Window created OK")

-- ============================================================
-- #14 Window State + Flag persistence
-- ============================================================
pcall(function() win:LoadState() end)
pcall(function() DX8.Config:LoadFlags("main") end)

-- ============================================================
-- SERVICES
-- ============================================================
local Players          = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")
local RunService       = game:GetService("RunService")
local Lighting         = game:GetService("Lighting")
local TeleportService  = game:GetService("TeleportService")
local LocalPlayer      = Players.LocalPlayer
local currentScriptID  = shared.DX8_CurrentExecutionID

-- ============================================================
-- FEATURE STATE
-- ============================================================
local autoSprintLoop   = false
local infJumpConn      = nil
local noclipConn       = nil
local flyActive        = false
local flyBV            = nil
local flyBG            = nil
local flyConn          = nil
local espActive        = false
local espConnections   = {}
local espObjects       = {}   -- [player] = { highlight, billboard, hpLabel, distLabel, tracer }
local espUpdateConn    = nil
local tracersActive    = false
local fullbrightActive = false
local originalLighting = {}
local afkConn          = nil
local texturesRemoved  = false
local removedObjects   = {}
local shadowsDisabled  = false
local originalShadows  = true
local Connections      = {}

local function AddConnection(conn)
    table.insert(Connections, conn)
end

-- ============================================================
-- HELPERS
-- ============================================================
local function getLocalCharacter()
    return LocalPlayer.Character
end

local function getLocalHumanoid()
    local char = getLocalCharacter()
    return char and char:FindFirstChildOfClass("Humanoid")
end

local function getHRP(player)
    local char = player and player.Character
    return char and char:FindFirstChild("HumanoidRootPart")
end

-- ============================================================
-- CLEANUP HELPERS
-- ============================================================
local function cleanESP()
    for _, objs in pairs(espObjects) do
        pcall(function() if objs.highlight then objs.highlight:Destroy() end end)
        pcall(function() if objs.billboard then objs.billboard:Destroy() end end)
        pcall(function() if objs.tracer    then objs.tracer:Remove()    end end)
    end
    espObjects = {}

    for _, conn in pairs(espConnections) do
        pcall(function() conn:Disconnect() end)
    end
    espConnections = {}

    if espUpdateConn then
        pcall(function() espUpdateConn:Disconnect() end)
        espUpdateConn = nil
    end
end

local function cleanFly()
    flyActive = false
    if flyConn then pcall(function() flyConn:Disconnect() end);  flyConn = nil end
    if flyBV   then pcall(function() flyBV:Destroy() end);       flyBV   = nil end
    if flyBG   then pcall(function() flyBG:Destroy() end);       flyBG   = nil end
    local hum = getLocalHumanoid()
    if hum then pcall(function() hum.PlatformStand = false end) end
end

local function cleanNoclip()
    if noclipConn then pcall(function() noclipConn:Disconnect() end); noclipConn = nil end
    local char = getLocalCharacter()
    if char then
        for _, part in ipairs(char:GetDescendants()) do
            if part:IsA("BasePart") then
                pcall(function() part.CanCollide = true end)
            end
        end
    end
end

local function cleanFullbright()
    if fullbrightActive then
        for k, v in pairs(originalLighting) do
            pcall(function() Lighting[k] = v end)
        end
        fullbrightActive = false
        originalLighting = {}
    end
end

-- ============================================================
-- GLOBAL CLEANUP
-- ============================================================
local function UnloadFeatures()
    autoSprintLoop = false

    if infJumpConn then pcall(function() infJumpConn:Disconnect() end); infJumpConn = nil end
    if afkConn     then pcall(function() afkConn:Disconnect()     end); afkConn     = nil end

    cleanNoclip()
    cleanFly()
    cleanESP()
    cleanFullbright()

    -- restore gravity
    pcall(function() workspace.Gravity = 196.2 end)

    -- restore FOV
    pcall(function()
        if workspace.CurrentCamera then
            workspace.CurrentCamera.FieldOfView = 70
        end
    end)

    -- restore textures
    for _, entry in ipairs(removedObjects) do
        pcall(function()
            if entry.obj and entry.obj.Parent then
                entry.obj.Transparency = entry.trans
            end
        end)
    end
    removedObjects  = {}
    texturesRemoved = false

    -- restore shadows
    if shadowsDisabled then
        Lighting.GlobalShadows = originalShadows
        shadowsDisabled = false
    end

    -- unlock FPS
    pcall(function() if setfpscap then setfpscap(0) end end)

    for _, conn in pairs(Connections) do
        if conn then pcall(function() conn:Disconnect() end) end
    end
    Connections = {}

    pcall(function() DX8.Config:SaveFlags("main") end)
    print("[DX8 Features] Semua fitur berhasil dibersihkan.")
end
shared.DX8_Features_Cleanup = UnloadFeatures

local originalCleanup = shared.DX8_Cleanup
shared.DX8_Cleanup = function()
    UnloadFeatures()
    if originalCleanup then originalCleanup() end
end

-- ============================================================
-- EVENTS
-- ============================================================
DX8.on("ThemeChanged", function(name)
    DX8:Notify("Tema Berganti", "Tema aktif: " .. tostring(name), 2)
end)

DX8.on("ConfigLoaded", function(name)
    if name ~= "flags" then
        DX8:Notify("Config Dimuat", "'" .. tostring(name) .. "' berhasil dimuat.", 2)
    end
end)

DX8.on("ConfigSaved", function(name)
    if name == "main" then
        DX8:Notify("Config Tersimpan", "Semua flag disimpan ke 'main'.", 2)
    end
end)

-- ============================================================
-- TABS
-- ============================================================
local mainTab     = win:CreateTab("Main Features", "Home")
local visualsTab  = win:CreateTab("Visuals",       "Eye")
local serverTab   = win:CreateTab("Server",        "Network")
local perfTab     = win:CreateTab("Performance",   "Settings")
local settingsTab = win:CreateTab("Settings",      "Settings")
local unloadTab   = win:CreateTab("Unload",        "Events")

-- ============================================================
-- ╔══════════════════════════════════════╗
-- ║         TAB: MAIN FEATURES           ║
-- ╚══════════════════════════════════════╝
-- ============================================================

-- ─── SECTION: MOVEMENT & CHARACTER ───────────────────────────
local movementSection = mainTab:AddSection("Movement & Character")

-- WALKSPEED
movementSection:AddSlider({
    Title       = "Walk Speed",
    Min         = 1,
    Max         = 500,
    Step        = 1,
    Default     = DX8.GetFlag("WalkSpeed") or 16,
    Flag        = "WalkSpeed",
    Description = "Atur kecepatan berjalan karakter (default: 16).",
    Tooltip     = "Klik angka untuk input manual.",
    Callback    = function(value)
        local hum = getLocalHumanoid()
        if hum then hum.WalkSpeed = value end
    end
})

-- AUTO SPRINT
local sprintToggle = movementSection:AddToggle({
    Title       = "Auto Sprint",
    Default     = DX8.GetFlag("AutoSprint") or false,
    Flag        = "AutoSprint",
    Description = "Jaga WalkSpeed tetap di 25 secara otomatis.",
    Tooltip     = "Aktif = lock WalkSpeed 25, Mati = kembali ke slider.",
    Callback    = function(state)
        autoSprintLoop = state
        if state then
            task.spawn(function()
                while autoSprintLoop and shared.DX8_CurrentExecutionID == currentScriptID do
                    local hum = getLocalHumanoid()
                    if hum and hum.WalkSpeed < 25 then hum.WalkSpeed = 25 end
                    task.wait(0.5)
                end
            end)
        else
            local hum = getLocalHumanoid()
            if hum then hum.WalkSpeed = DX8.GetFlag("WalkSpeed") or 16 end
        end
    end
})

-- INFINITE JUMP
movementSection:AddToggle({
    Title       = "Infinite Jump",
    Default     = DX8.GetFlag("InfiniteJump") or false,
    Flag        = "InfiniteJump",
    Description = "Lompat tanpa batas, bahkan di udara.",
    Tooltip     = "Konek ke JumpRequest setiap kali diaktifkan.",
    Callback    = function(state)
        if infJumpConn then infJumpConn:Disconnect(); infJumpConn = nil end
        if state then
            infJumpConn = UserInputService.JumpRequest:Connect(function()
                local hum = getLocalHumanoid()
                if hum then hum:ChangeState(Enum.HumanoidStateType.Jumping) end
            end)
            DX8:Notify("Infinite Jump", "Aktif!", 2)
        else
            DX8:Notify("Infinite Jump", "Dimatikan.", 2)
        end
    end
})

-- JUMP POWER
movementSection:AddSlider({
    Title       = "Jump Power",
    Min         = 50,
    Max         = 1000,
    Step        = 10,
    Default     = DX8.GetFlag("JumpPower") or 50,
    Flag        = "JumpPower",
    Description = "Atur kekuatan lompatan (50–1000).",
    Tooltip     = "Klik angka untuk input manual.",
    Callback    = function(value)
        local hum = getLocalHumanoid()
        if hum then
            hum.UseJumpPower = true
            hum.JumpPower    = value
        end
    end
})

-- HIP HEIGHT
movementSection:AddSlider({
    Title       = "Hip Height",
    Min         = 0,
    Max         = 20,
    Step        = 0.5,
    Default     = DX8.GetFlag("HipHeight") or 0,
    Flag        = "HipHeight",
    Description = "Ubah tinggi melayang karakter dari tanah (default: 0).",
    Callback    = function(value)
        local hum = getLocalHumanoid()
        if hum then hum.HipHeight = value end
    end
})

-- GRAVITY MODIFIER
movementSection:AddSlider({
    Title       = "Gravity",
    Min         = 0,
    Max         = 400,
    Step        = 5,
    Default     = DX8.GetFlag("Gravity") or 196,
    Flag        = "Gravity",
    Description = "Atur gravitasi workspace (default: 196.2). 0 = weightless.",
    Tooltip     = "Nilai rendah = serasa di bulan.",
    Callback    = function(value)
        pcall(function() workspace.Gravity = value end)
    end
})

-- NOCLIP
movementSection:AddToggle({
    Title       = "Noclip",
    Default     = DX8.GetFlag("Noclip") or false,
    Flag        = "Noclip",
    Description = "Tembus tembok & objek — CanCollide = false per frame.",
    Callback    = function(state)
        cleanNoclip()
        if state then
            noclipConn = RunService.Stepped:Connect(function()
                local char = getLocalCharacter()
                if not char then return end
                for _, part in ipairs(char:GetDescendants()) do
                    if part:IsA("BasePart") then
                        part.CanCollide = false
                    end
                end
            end)
            DX8:Notify("Noclip", "Aktif — tembus tembok!", 2)
        else
            DX8:Notify("Noclip", "Dimatikan.", 2)
        end
    end
})

-- FLY SPEED (slider first so the fly toggle can read its flag)
movementSection:AddSlider({
    Title       = "Fly Speed",
    Min         = 10,
    Max         = 500,
    Step        = 10,
    Default     = DX8.GetFlag("FlySpeed") or 50,
    Flag        = "FlySpeed",
    Description = "Kecepatan terbang saat Fly aktif (10–500).",
    Callback    = function(_)
        -- live-read in fly loop via DX8.GetFlag("FlySpeed")
    end
})

-- FLY TOGGLE
movementSection:AddToggle({
    Title       = "Fly",
    Default     = DX8.GetFlag("Fly") or false,
    Flag        = "Fly",
    Description = "Terbang bebas: WASD bergerak, Space naik, LCtrl/LShift turun.",
    Tooltip     = "BodyVelocity + BodyGyro. Auto-clean saat karakter respawn.",
    Callback    = function(state)
        cleanFly()
        if not state then
            DX8:Notify("Fly", "Dimatikan.", 2)
            return
        end

        local char = getLocalCharacter()
        local hrp  = char and char:FindFirstChild("HumanoidRootPart")
        local hum  = char and char:FindFirstChildOfClass("Humanoid")
        if not hrp or not hum then
            DX8:Notify("Fly Error", "Karakter tidak ditemukan.", 3)
            return
        end

        flyActive = true
        pcall(function() hum.PlatformStand = true end)

        flyBV           = Instance.new("BodyVelocity")
        flyBV.Velocity  = Vector3.new(0, 0, 0)
        flyBV.MaxForce  = Vector3.new(1e9, 1e9, 1e9)
        flyBV.Parent    = hrp

        flyBG           = Instance.new("BodyGyro")
        flyBG.MaxTorque = Vector3.new(1e9, 1e9, 1e9)
        flyBG.D         = 100
        flyBG.CFrame    = hrp.CFrame
        flyBG.Parent    = hrp

        flyConn = RunService.RenderStepped:Connect(function()
            if not flyActive or not flyBV or not flyBV.Parent then
                cleanFly()
                return
            end

            local camera = workspace.CurrentCamera
            if not camera then return end

            local speed = DX8.GetFlag("FlySpeed") or 50
            local dir   = Vector3.new(0, 0, 0)

            if UserInputService:IsKeyDown(Enum.KeyCode.W) then
                dir = dir + camera.CFrame.LookVector
            end
            if UserInputService:IsKeyDown(Enum.KeyCode.S) then
                dir = dir - camera.CFrame.LookVector
            end
            if UserInputService:IsKeyDown(Enum.KeyCode.A) then
                dir = dir - camera.CFrame.RightVector
            end
            if UserInputService:IsKeyDown(Enum.KeyCode.D) then
                dir = dir + camera.CFrame.RightVector
            end
            if UserInputService:IsKeyDown(Enum.KeyCode.Space) then
                dir = dir + Vector3.new(0, 1, 0)
            end
            if UserInputService:IsKeyDown(Enum.KeyCode.LeftControl)
            or UserInputService:IsKeyDown(Enum.KeyCode.LeftShift) then
                dir = dir - Vector3.new(0, 1, 0)
            end

            if dir.Magnitude > 0 then dir = dir.Unit end

            flyBV.Velocity = dir * speed
            flyBG.CFrame   = camera.CFrame * CFrame.Angles(0, math.pi, 0)
        end)

        -- cleanup if player respawns mid-fly
        AddConnection(LocalPlayer.CharacterAdded:Connect(function()
            if flyActive then cleanFly() end
        end))

        DX8:Notify("Fly", "Aktif! WASD + Space / LCtrl untuk navigasi.", 3)
    end
})

-- ─── SECTION: TELEPORT ───────────────────────────────────────
local tpSection = mainTab:AddSection("Teleport Player")

local function getOnlinePlayers()
    local names = {}
    for _, p in ipairs(Players:GetPlayers()) do
        if p ~= LocalPlayer then table.insert(names, p.Name) end
    end
    if #names == 0 then table.insert(names, "Tidak ada player lain") end
    return names
end

local initialList        = getOnlinePlayers()
local selectedPlayerName = initialList[1] or "Tidak ada player lain"
local playerDropdown

playerDropdown = tpSection:AddDropdown({
    Title       = "Pilih Player",
    List        = initialList,
    Default     = initialList[1],
    Description = "Pilih player target untuk aksi Teleport.",
    Tooltip     = "Klik Refresh untuk update daftar player terbaru.",
    Buttons     = {
        {
            Text     = "Teleport",
            Callback = function(targetName)
                selectedPlayerName = targetName
                if selectedPlayerName == "Tidak ada player lain" or selectedPlayerName == "" then
                    DX8:Notify("Teleport Gagal", "Pilih nama player aktif dulu!", 3)
                    return
                end
                local target    = Players:FindFirstChild(selectedPlayerName)
                local localChar = getLocalCharacter()
                if target and target.Character
                    and target.Character:FindFirstChild("HumanoidRootPart")
                    and localChar
                    and localChar:FindFirstChild("HumanoidRootPart") then
                    localChar.HumanoidRootPart.CFrame =
                        target.Character.HumanoidRootPart.CFrame * CFrame.new(0, 3, 0)
                    DX8:Notify("Teleport", "Berhasil ke " .. selectedPlayerName, 3)
                else
                    DX8:Notify("Teleport Gagal", "Karakter tidak ditemukan/aktif!", 3)
                end
            end
        },
        {
            Text     = "Refresh",
            Callback = function()
                local updated = getOnlinePlayers()
                playerDropdown:Refresh(updated)
                selectedPlayerName = updated[1] or "Tidak ada player lain"
                DX8:Notify("Refresh", "Daftar player diperbarui.", 2)
            end
        }
    }
})

-- ============================================================
-- ╔══════════════════════════════════════╗
-- ║            TAB: VISUALS              ║
-- ╚══════════════════════════════════════╝
-- ============================================================

-- ─── SECTION: PLAYER ESP ─────────────────────────────────────
local espSection = visualsTab:AddSection("Player ESP")

-- internal: build all ESP objects for one player
local function buildESPFor(player)
    if not espActive or player == LocalPlayer then return end

    local char = player.Character
    local hrp  = char and char:FindFirstChild("HumanoidRootPart")
    if not char or not hrp then return end

    -- tear down stale objects first
    if espObjects[player] then
        local old = espObjects[player]
        pcall(function() if old.highlight then old.highlight:Destroy() end end)
        pcall(function() if old.billboard then old.billboard:Destroy() end end)
        pcall(function() if old.tracer    then old.tracer:Remove()    end end)
        espObjects[player] = nil
    end

    local objs = {}

    -- HIGHLIGHT / CHAMS — Roblox-native, works through walls via DepthMode
    local hl                    = Instance.new("Highlight")
    hl.FillColor                = Color3.fromRGB(220, 50, 50)
    hl.OutlineColor             = Color3.fromRGB(255, 255, 255)
    hl.FillTransparency         = 0.55
    hl.OutlineTransparency      = 0
    hl.Adornee                  = char
    hl.DepthMode                = Enum.HighlightDepthMode.AlwaysOnTop
    hl.Parent                   = char
    objs.highlight              = hl

    -- BILLBOARD — names, health bar, distance (toggled via flag)
    if DX8.GetFlag("ESPNames") ~= false then
        local bb        = Instance.new("BillboardGui")
        bb.AlwaysOnTop  = true
        bb.Size         = UDim2.new(0, 160, 0, 56)
        bb.StudsOffset  = Vector3.new(0, 3.5, 0)
        bb.Adornee      = hrp
        bb.Parent       = char

        local nameLabel                   = Instance.new("TextLabel")
        nameLabel.BackgroundTransparency  = 1
        nameLabel.Size                    = UDim2.new(1, 0, 0.42, 0)
        nameLabel.Position                = UDim2.new(0, 0, 0, 0)
        nameLabel.TextColor3              = Color3.fromRGB(255, 255, 255)
        nameLabel.TextStrokeTransparency  = 0.4
        nameLabel.Font                    = Enum.Font.GothamBold
        nameLabel.TextSize                = 13
        nameLabel.Text                    = player.Name
        nameLabel.Parent                  = bb

        local hpLabel                     = Instance.new("TextLabel")
        hpLabel.BackgroundTransparency    = 1
        hpLabel.Size                      = UDim2.new(1, 0, 0.33, 0)
        hpLabel.Position                  = UDim2.new(0, 0, 0.42, 0)
        hpLabel.TextColor3                = Color3.fromRGB(80, 255, 80)
        hpLabel.TextStrokeTransparency    = 0.4
        hpLabel.Font                      = Enum.Font.Gotham
        hpLabel.TextSize                  = 11
        hpLabel.Text                      = "HP: --"
        hpLabel.Parent                    = bb
        objs.hpLabel                      = hpLabel

        local distLabel                   = Instance.new("TextLabel")
        distLabel.BackgroundTransparency  = 1
        distLabel.Size                    = UDim2.new(1, 0, 0.28, 0)
        distLabel.Position                = UDim2.new(0, 0, 0.74, 0)
        distLabel.TextColor3              = Color3.fromRGB(180, 200, 255)
        distLabel.TextStrokeTransparency  = 0.4
        distLabel.Font                    = Enum.Font.Gotham
        distLabel.TextSize                = 10
        distLabel.Text                    = "0 studs"
        distLabel.Parent                  = bb
        objs.distLabel                    = distLabel

        objs.billboard = bb
    end

    -- TRACER — Drawing API line from bottom-center of screen to player
    if tracersActive then
        local ok, tracer = pcall(function()
            local line       = Drawing.new("Line")
            line.Color       = Color3.fromRGB(220, 50, 50)
            line.Thickness   = 1
            line.Transparency = 1
            line.Visible     = true
            return line
        end)
        if ok then objs.tracer = tracer end
    end

    espObjects[player] = objs
end

local function destroyESPFor(player)
    local objs = espObjects[player]
    if not objs then return end
    pcall(function() if objs.highlight then objs.highlight:Destroy() end end)
    pcall(function() if objs.billboard then objs.billboard:Destroy() end end)
    pcall(function() if objs.tracer    then objs.tracer:Remove()    end end)
    espObjects[player] = nil
end

local function startESP()
    espActive = true

    for _, p in ipairs(Players:GetPlayers()) do
        if p ~= LocalPlayer then
            buildESPFor(p)
            local conn = p.CharacterAdded:Connect(function()
                task.wait(0.1)
                buildESPFor(p)
            end)
            table.insert(espConnections, conn)
        end
    end

    local joinConn = Players.PlayerAdded:Connect(function(p)
        local conn = p.CharacterAdded:Connect(function()
            task.wait(0.1)
            buildESPFor(p)
        end)
        table.insert(espConnections, conn)
        if p.Character then buildESPFor(p) end
    end)
    table.insert(espConnections, joinConn)

    local leaveConn = Players.PlayerRemoving:Connect(function(p)
        destroyESPFor(p)
    end)
    table.insert(espConnections, leaveConn)

    -- per-frame update: health gradient, distance, tracer lines
    espUpdateConn = RunService.RenderStepped:Connect(function()
        local localHRP = getHRP(LocalPlayer)
        local cam      = workspace.CurrentCamera

        for player, objs in pairs(espObjects) do
            local char = player.Character
            local hrp  = char and char:FindFirstChild("HumanoidRootPart")
            local hum  = char and char:FindFirstChildOfClass("Humanoid")

            if not char or not hrp then
                destroyESPFor(player)
                continue
            end

            -- health label + green→red gradient
            if objs.hpLabel and hum then
                local hp    = math.floor(hum.Health)
                local maxHp = math.max(math.floor(hum.MaxHealth), 1)
                objs.hpLabel.Text = string.format("HP: %d / %d", hp, maxHp)
                local ratio = hp / maxHp
                objs.hpLabel.TextColor3 = Color3.fromRGB(
                    math.floor((1 - ratio) * 255),
                    math.floor(ratio       * 230),
                    50
                )
            end

            -- distance label
            if objs.distLabel and localHRP then
                local dist = math.floor((hrp.Position - localHRP.Position).Magnitude)
                objs.distLabel.Text = dist .. " studs"
            end

            -- tracer line
            if objs.tracer and cam then
                local screenPos, onScreen = cam:WorldToViewportPoint(hrp.Position)
                if onScreen then
                    objs.tracer.Visible = true
                    objs.tracer.From    = Vector2.new(cam.ViewportSize.X / 2, cam.ViewportSize.Y)
                    objs.tracer.To      = Vector2.new(screenPos.X, screenPos.Y)
                else
                    objs.tracer.Visible = false
                end
            end
        end
    end)
end

local function stopESP()
    espActive = false
    cleanESP()
end

espSection:AddToggle({
    Title       = "Player ESP (Highlight / Chams)",
    Default     = DX8.GetFlag("ESP") or false,
    Flag        = "ESP",
    Description = "Sorot semua player lain menembus dinding via Highlight.",
    Callback    = function(state)
        if state then startESP() else stopESP() end
        DX8:Notify("ESP", state and "Aktif!" or "Dimatikan.", 2)
    end
})

espSection:AddToggle({
    Title       = "Show Names, Health & Distance",
    Default     = DX8.GetFlag("ESPNames") ~= false,
    Flag        = "ESPNames",
    Description = "Billboard di atas kepala: nama, HP bar, dan jarak dalam stud.",
    Callback    = function(_)
        -- rebuild to add/remove billboards
        if espActive then stopESP(); startESP() end
    end
})

espSection:AddToggle({
    Title       = "Tracers",
    Default     = DX8.GetFlag("Tracers") or false,
    Flag        = "Tracers",
    Description = "Garis dari bawah layar ke tiap player (butuh Drawing API).",
    Callback    = function(state)
        tracersActive = state
        if espActive then stopESP(); startESP() end
    end
})

-- ─── SECTION: CAMERA & RENDERING ─────────────────────────────
local camSection = visualsTab:AddSection("Camera & Rendering")

-- FULLBRIGHT
camSection:AddToggle({
    Title       = "Fullbright / Night Vision",
    Default     = DX8.GetFlag("Fullbright") or false,
    Flag        = "Fullbright",
    Description = "Paksa pencahayaan terang total — tidak ada malam, tidak ada kabut.",
    Callback    = function(state)
        if state then
            originalLighting = {
                Brightness    = Lighting.Brightness,
                ClockTime     = Lighting.ClockTime,
                FogEnd        = Lighting.FogEnd,
                FogColor      = Lighting.FogColor,
                GlobalShadows = Lighting.GlobalShadows,
                Ambient       = Lighting.Ambient,
                OutdoorAmbient = Lighting.OutdoorAmbient,
            }
            Lighting.Brightness     = 10
            Lighting.ClockTime      = 14
            Lighting.FogEnd         = 100000
            Lighting.GlobalShadows  = false
            Lighting.Ambient        = Color3.fromRGB(178, 178, 178)
            Lighting.OutdoorAmbient = Color3.fromRGB(178, 178, 178)
            fullbrightActive        = true
            DX8:Notify("Fullbright", "Aktif — map terang total!", 2)
        else
            cleanFullbright()
            DX8:Notify("Fullbright", "Dimatikan — pencahayaan normal.", 2)
        end
    end
})

-- FOV CHANGER
camSection:AddSlider({
    Title       = "FOV (Field of View)",
    Min         = 30,
    Max         = 120,
    Step        = 1,
    Default     = DX8.GetFlag("FOV") or 70,
    Flag        = "FOV",
    Description = "Sudut pandang kamera (default: 70). Tinggi = lebih lebar.",
    Callback    = function(value)
        pcall(function()
            if workspace.CurrentCamera then
                workspace.CurrentCamera.FieldOfView = value
            end
        end)
    end
})

-- re-apply FOV if camera instance changes
AddConnection(workspace:GetPropertyChangedSignal("CurrentCamera"):Connect(function()
    local fov = DX8.GetFlag("FOV")
    if fov then
        pcall(function()
            if workspace.CurrentCamera then
                workspace.CurrentCamera.FieldOfView = fov
            end
        end)
    end
end))

-- FORCE SHIFTLOCK
camSection:AddToggle({
    Title       = "Force Shiftlock",
    Default     = DX8.GetFlag("ShiftLock") or false,
    Flag        = "ShiftLock",
    Description = "Aktifkan Shift Lock paksa meskipun game tidak mengizinkannya.",
    Callback    = function(state)
        pcall(function() LocalPlayer.DevEnableMouseLock = state end)
        DX8:Notify("Shiftlock", state and "Diaktifkan paksa." or "Dimatikan.", 2)
    end
})

-- ============================================================
-- ╔══════════════════════════════════════╗
-- ║            TAB: SERVER               ║
-- ╚══════════════════════════════════════╝
-- ============================================================

local serverUtilSection = serverTab:AddSection("Server Utilities")

-- ANTI-AFK
serverUtilSection:AddToggle({
    Title       = "Anti-AFK",
    Default     = DX8.GetFlag("AntiAFK") or false,
    Flag        = "AntiAFK",
    Description = "Cegah kick AFK Roblox setelah 20 menit tidak bergerak.",
    Callback    = function(state)
        if afkConn then pcall(function() afkConn:Disconnect() end); afkConn = nil end
        if state then
            local VirtualUser = game:GetService("VirtualUser")
            afkConn = LocalPlayer.Idled:Connect(function()
                VirtualUser:Button2Down(Vector2.new(0, 0), workspace.CurrentCamera.CFrame)
                task.wait(0.5)
                VirtualUser:Button2Up(Vector2.new(0, 0), workspace.CurrentCamera.CFrame)
            end)
            DX8:Notify("Anti-AFK", "Aktif — tidak akan di-kick.", 2)
        else
            DX8:Notify("Anti-AFK", "Dimatikan.", 2)
        end
    end
})

-- REJOIN
serverUtilSection:AddButton({
    Title       = "Rejoin Server",
    Description = "Masuk kembali ke server yang sama secara instan.",
    Callback    = function()
        DX8:Notify("Rejoin", "Rejoining server saat ini...", 2)
        task.delay(1, function()
            pcall(function()
                TeleportService:TeleportToPlaceInstance(
                    game.PlaceId,
                    game.JobId,
                    LocalPlayer
                )
            end)
        end)
    end
})

-- SERVER HOP
serverUtilSection:AddButton({
    Title       = "Server Hop",
    Description = "Pindah ke server lain yang aktif & tidak penuh.",
    Callback    = function()
        DX8:Notify("Server Hop", "Mencari server lain...", 2)
        task.spawn(function()
            local ok = pcall(function()
                local HttpService = game:GetService("HttpService")
                local placeId     = game.PlaceId
                local currentJob  = game.JobId

                local url = string.format(
                    "https://games.roblox.com/v1/games/%d/servers/Public?sortOrder=Asc&limit=100",
                    placeId
                )
                local raw     = HttpService:GetAsync(url)
                local data    = HttpService:JSONDecode(raw)

                for _, server in ipairs(data.data or {}) do
                    if server.id ~= currentJob and server.playing < server.maxPlayers then
                        TeleportService:TeleportToPlaceInstance(placeId, server.id, LocalPlayer)
                        return
                    end
                end

                -- fallback: new server
                TeleportService:Teleport(placeId, LocalPlayer)
            end)

            if not ok then
                -- executor might block HTTP; still hop via new-server teleport
                pcall(function() TeleportService:Teleport(game.PlaceId, LocalPlayer) end)
            end
        end)
    end
})

-- ─── SECTION: GAME INFO & CLIPBOARD ──────────────────────────
local idSection = serverTab:AddSection("Game Info & Clipboard")

idSection:AddButton({
    Title       = "Copy Place ID",
    Description = "Salin Place ID game aktif ke clipboard.",
    Callback    = function()
        local id = tostring(game.PlaceId)
        pcall(function()
            if setclipboard then
                setclipboard(id)
            else
                game:GetService("GuiService"):SetClipboard(id)
            end
        end)
        DX8:Notify("Place ID Disalin", id, 3)
    end
})

idSection:AddButton({
    Title       = "Copy Job ID",
    Description = "Salin Job ID (server ID) aktif ke clipboard.",
    Callback    = function()
        local id = tostring(game.JobId)
        pcall(function()
            if setclipboard then
                setclipboard(id)
            else
                game:GetService("GuiService"):SetClipboard(id)
            end
        end)
        DX8:Notify("Job ID Disalin", id:sub(1, 24) .. "...", 3)
    end
})

idSection:AddLabel({ Title = "Place: " .. tostring(game.PlaceId) })
idSection:AddLabel({ Title = "Job:   " .. tostring(game.JobId):sub(1, 20) .. "…" })

-- ============================================================
-- ╔══════════════════════════════════════╗
-- ║          TAB: PERFORMANCE            ║
-- ╚══════════════════════════════════════╝
-- ============================================================

local fpsSection = perfTab:AddSection("FPS & Graphics")

-- REMOVE TEXTURES
fpsSection:AddToggle({
    Title       = "Remove Textures",
    Default     = DX8.GetFlag("RemoveTextures") or false,
    Flag        = "RemoveTextures",
    Description = "Sembunyikan semua Decal & Texture di workspace untuk boost FPS.",
    Callback    = function(state)
        if state then
            texturesRemoved = true
            removedObjects  = {}
            for _, obj in ipairs(workspace:GetDescendants()) do
                if obj:IsA("Decal") or obj:IsA("Texture") then
                    table.insert(removedObjects, { obj = obj, trans = obj.Transparency })
                    pcall(function() obj.Transparency = 1 end)
                end
            end
            DX8:Notify("Textures", "Semua tekstur disembunyikan.", 2)
        else
            texturesRemoved = false
            for _, entry in ipairs(removedObjects) do
                pcall(function()
                    if entry.obj and entry.obj.Parent then
                        entry.obj.Transparency = entry.trans
                    end
                end)
            end
            removedObjects = {}
            DX8:Notify("Textures", "Tekstur dikembalikan.", 2)
        end
    end
})

-- DISABLE SHADOWS
fpsSection:AddToggle({
    Title       = "Disable Shadows",
    Default     = DX8.GetFlag("DisableShadows") or false,
    Flag        = "DisableShadows",
    Description = "Matikan GlobalShadows — boost FPS signifikan di map kompleks.",
    Callback    = function(state)
        if state then
            originalShadows        = Lighting.GlobalShadows
            Lighting.GlobalShadows = false
            shadowsDisabled        = true
            DX8:Notify("Shadows", "Bayangan dimatikan.", 2)
        else
            Lighting.GlobalShadows = originalShadows
            shadowsDisabled        = false
            DX8:Notify("Shadows", "Bayangan dikembalikan.", 2)
        end
    end
})

-- FPS CAP
fpsSection:AddSlider({
    Title       = "FPS Cap",
    Min         = 15,
    Max         = 240,
    Step        = 15,
    Default     = DX8.GetFlag("FPSCap") or 60,
    Flag        = "FPSCap",
    Description = "Batasi FPS (15–240). 240 = tidak dibatasi (setfpscap 0).",
    Callback    = function(value)
        pcall(function()
            if setfpscap then
                setfpscap(value >= 240 and 0 or value)
            end
        end)
        DX8:Notify(
            "FPS Cap",
            value >= 240 and "FPS tidak dibatasi." or ("Dibatasi ke " .. value .. " FPS"),
            2
        )
    end
})

-- RESET GRAPHICS
fpsSection:AddButton({
    Title       = "Reset Graphics",
    Description = "Kembalikan semua pengaturan grafis ke default sekaligus.",
    Callback    = function()
        -- textures
        for _, entry in ipairs(removedObjects) do
            pcall(function()
                if entry.obj and entry.obj.Parent then
                    entry.obj.Transparency = entry.trans
                end
            end)
        end
        removedObjects  = {}
        texturesRemoved = false

        -- shadows
        Lighting.GlobalShadows = true
        shadowsDisabled        = false

        -- FPS
        pcall(function() if setfpscap then setfpscap(0) end end)

        -- FOV
        pcall(function()
            if workspace.CurrentCamera then
                workspace.CurrentCamera.FieldOfView = 70
            end
        end)

        -- gravity
        pcall(function() workspace.Gravity = 196.2 end)

        -- fullbright
        cleanFullbright()

        DX8:Notify("Reset Graphics", "Semua pengaturan grafis dikembalikan.", 3)
    end
})

-- ============================================================
-- ╔══════════════════════════════════════╗
-- ║            TAB: SETTINGS             ║
-- ╚══════════════════════════════════════╝
-- ============================================================

local configSection = settingsTab:AddSection("Config Manager")

configSection:AddButton({
    Title       = "Simpan Config",
    Description = "Simpan semua nilai flag saat ini ke disk.",
    Callback    = function()
        local ok = DX8.Config:SaveFlags("main")
        DX8:Notify(
            ok and "Config Tersimpan" or "Gagal Simpan",
            ok and "Tersimpan ke profil 'main'." or "Error saat menyimpan.",
            3
        )
    end
})

configSection:AddButton({
    Title       = "Muat Config",
    Description = "Muat flag dari disk.",
    Callback    = function()
        DX8.Config:LoadFlags("main")
        if DX8.GetFlag("AutoSprint") ~= nil then
            sprintToggle:Set(DX8.GetFlag("AutoSprint") == true)
        end
        DX8:Notify("Config Dimuat", "Flag berhasil dimuat dari 'main'.", 3)
    end
})

configSection:AddButton({
    Title       = "Hapus Config",
    Confirm     = true,
    Description = "Hapus profil config 'main' dari disk.",
    Callback    = function()
        DX8.Config:Delete("main")
        DX8:Notify("Config Dihapus", "Profil 'main' dihapus.", 3)
    end
})

local themeSection = settingsTab:AddSection("Tema UI")

themeSection:AddDropdown({
    Title       = "Pilih Tema",
    List        = {"Default", "Dark", "Neon", "Midnight"},
    Default     = "Default",
    Flag        = "ActiveTheme",
    Description = "Ganti tema warna seluruh UI secara langsung.",
    Callback    = function(themeName)
        pcall(function() DX8.Theme:SetTheme(themeName) end)
    end
})

themeSection:AddSlider({
    Title       = "Skala UI (Mobile/PC)",
    Min         = 70,
    Max         = 130,
    Step        = 5,
    Default     = DX8.GetFlag("UIScaleValue") or 100,
    Flag        = "UIScaleValue",
    Description = "Atur ukuran tampilan UI secara bebas (70%–130%).",
    Callback    = function(val)
        pcall(function()
            if win and win.SetScale then win:SetScale(val / 100) end
        end)
    end
})

local debugSection = settingsTab:AddSection("Developer")

debugSection:AddButton({
    Title       = "Load Test Feature",
    Description = "Muat modul pengujian UI untuk mencoba semua komponen & dialog.",
    Callback    = function()
        local testPath   = "DX8/Games/Test Feature/Test Feature.lua"
        local ok, content = pcall(readfile, testPath)
        if ok and content and content ~= "" then
            local fn, err = loadstring(content)
            if fn then
                fn()
            else
                DX8:Notify("Error", "Gagal kompilasi: " .. tostring(err), 4)
            end
        else
            DX8:Notify("Error", "File tidak ditemukan: " .. testPath, 4)
        end
    end
})

debugSection:AddToggle({
    Title       = "Debug Mode",
    Default     = DX8.Debug or true,
    Flag        = "DebugMode",
    Description = "Aktifkan logging DX8 ke Output.",
    Callback    = function(state)
        DX8.Debug = state
        DX8:Notify("Debug Mode", state and "Logging aktif." or "Logging dimatikan.", 2)
    end
})

debugSection:AddLabel({ Title = "DX8 Library  v" .. (DX8.Version or "?") })

-- ============================================================
-- ╔══════════════════════════════════════╗
-- ║             TAB: UNLOAD              ║
-- ╚══════════════════════════════════════╝
-- ============================================================

local unloadSec = unloadTab:AddSection("Unload Script")

unloadSec:AddButton({
    Title       = "Unload",
    Description = "Unload Script?",
    Callback    = function()
        DX8:ShowCustomConfirm(
            "Do you want to Unload Script?",
            function()
                if shared.DX8_Cleanup then pcall(shared.DX8_Cleanup) end

                local containers = {
                    game:GetService("CoreGui"),
                    LocalPlayer and LocalPlayer:FindFirstChild("PlayerGui")
                }
                if gethui then pcall(function() table.insert(containers, gethui()) end) end

                for _, c in ipairs(containers) do
                    if c then
                        for _, gui in ipairs(c:GetChildren()) do
                            if gui:IsA("ScreenGui") and (
                                gui.Name:find("DX8") or
                                gui.Name:find("Hub") or
                                gui.Name:find(HUB_NAME)
                            ) then
                                pcall(function() gui:Destroy() end)
                            end
                        end
                    end
                end

                print(string.format("[%s] Unloaded!", HUB_NAME))
            end,
            {
                YesText = "Yoi, Bro!",
                NoText  = "No no!"
            }
        )
    end
})

-- ============================================================
print("[DX8-Main] Universal features v2 loaded — Movement / ESP / Server / Performance ready.")
DX8:Notify("DX8 Ready!", "Menu berhasil dimuat. RightShift untuk toggle.", 4)
