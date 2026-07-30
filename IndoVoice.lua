-- ============================================================
--  Indo Voice DX8 — MERGED LOADER
--  Loads DX8 Library from GitHub, then inlines all modules:
--    IDV_mapdetector → IDV_pathfinding → IDV_esp →
--    IDV_autosell → IDV_mining → IDV_fishing → Indo_Voice
-- ============================================================

-- ════════════════════════════════════════════════════════════
--  STEP 1: Load DX8 Library from GitHub
-- ════════════════════════════════════════════════════════════
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

-- ════════════════════════════════════════════════════════════
--  STEP 2: Create Main Window
--  ⚙️  Sesuaikan Name/ToggleKey jika perlu
-- ════════════════════════════════════════════════════════════
local win = DX8:CreateWindow({
    Name      = "Indo Voice",
    Community = "https://discord.gg/",
    ToggleKey = Enum.KeyCode.RightControl,
})
_G.DX8_MainWindow = win
print("[IDV Merged] Window created OK")

-- ════════════════════════════════════════════════════════════
--  IDV_mapdetector
-- ════════════════════════════════════════════════════════════
print("[IDV] Loading IDV_mapdetector...")
local _IDV_mapdetector_ok, _IDV_mapdetector_err = pcall(function()
-- ============================================================
--  IDV_mapdetector.lua — Dynamic Map Detection for Indo Voice
--  Reads RS.Status.WorldStatus.Map (StringValue) — official game source
--  Exposes _G.IDV_Map with: Current, OnChange, IsMap, IsIsland, IsCity
-- ============================================================

local RS = game:GetService("ReplicatedStorage")

-- ── GLOBAL CONNECTION HELPER ──────────────────────────────────────────────────
local function RegConn(conn, scope)
    if shared.DX8_RegisterConnection then
        shared.DX8_RegisterConnection(conn, scope)
    end
    return conn
end

-- ── MAP REGISTRY ──────────────────────────────────────────────────────────────
-- Map metadata: add new maps here as they're discovered
-- "id"      = the exact string value from RS.Status.WorldStatus.Map
-- "display" = friendly name for UI / logging
-- "type"    = category ("island", "city", "dungeon", etc.)
local MAP_REGISTRY = {
    Map_01 = { id = "Map_01", display = "Island",        type = "island" },
    Map_02 = { id = "Map_02", display = "City",          type = "city"   },
    Map_03 = { id = "Map_03", display = "Desert Island", type = "island" },
    -- Add more maps here as discovered
}

-- ── CONTAINER PATHS (per map) ─────────────────────────────────────────────────
-- For modules that need to know WHERE data lives on each map.
-- "miningContainer" = path to ActiveMiningStones folder
-- "fishingZone"     = path to FishingZone model
local MAP_DATA = {
    -- All current maps appear to share the same RS.Main structure
    -- Override per-map entry if a future map changes the path
    default = {
        miningContainer = function()
            local wsMain = workspace:FindFirstChild("Main")
            if wsMain and wsMain:FindFirstChild("ActiveMiningStones") then
                return wsMain.ActiveMiningStones
            end
            local rsMain = RS:FindFirstChild("Main")
            return rsMain and rsMain:FindFirstChild("ActiveMiningStones")
        end,
        fishingZone = function()
            local wsMain = workspace:FindFirstChild("Main")
            if wsMain and wsMain:FindFirstChild("FishingZone") then
                return wsMain.FishingZone
            end
            local rsMain = RS:FindFirstChild("Main")
            return rsMain and rsMain:FindFirstChild("FishingZone")
        end,
        miningSpawnPoints = function()
            local wsMain = workspace:FindFirstChild("Main")
            if wsMain and wsMain:FindFirstChild("MiningSpawnPoints") then
                return wsMain.MiningSpawnPoints
            end
            local rsMain = RS:FindFirstChild("Main")
            return rsMain and rsMain:FindFirstChild("MiningSpawnPoints")
        end,
    },
    Map_01 = nil,  -- uses default
    Map_02 = nil,  -- uses default
    Map_03 = nil,  -- uses default
}

-- ── INTERNAL STATE ────────────────────────────────────────────────────────────
local _currentMapId   = "unknown"
local _currentMeta    = nil
local _changeHandlers = {}   -- list of { fn, tag }
local _mapValue       = nil  -- the StringValue instance

-- ── HELPERS ───────────────────────────────────────────────────────────────────
local function getMeta(id)
    return MAP_REGISTRY[id] or {
        id      = id,
        display = id,   -- fallback: raw id as display name
        type    = "unknown",
    }
end

local function getDataTable(id)
    return MAP_DATA[id] or MAP_DATA.default
end

local function fireChange(newId, oldId)
    for _, h in ipairs(_changeHandlers) do
        pcall(h.fn, newId, oldId, getMeta(newId))
    end
end

local function applyMap(id)
    if id == _currentMapId then return end
    local oldId = _currentMapId
    _currentMapId = id
    _currentMeta  = getMeta(id)
    print(string.format("[IDV_Map] Map changed: %s -> %s (%s)", oldId, id, _currentMeta.display))
    fireChange(id, oldId)
end

-- ── INIT ─────────────────────────────────────────────────────────────────────
local function init()
    local status = RS:WaitForChild("Status", 10)
    if not status then warn("[IDV_Map] RS.Status not found"); return end
    local worldStatus = status:WaitForChild("WorldStatus", 10)
    if not worldStatus then warn("[IDV_Map] WorldStatus not found"); return end
    _mapValue = worldStatus:WaitForChild("Map", 10)
    if not _mapValue then warn("[IDV_Map] Map StringValue not found"); return end

    applyMap(_mapValue.Value)

    RegConn(_mapValue.Changed:Connect(function(newVal)
        applyMap(newVal)
    end), "persistent")

    print("[IDV_Map] Ready. Map:", _currentMapId, "(" .. getMeta(_currentMapId).display .. ")")
end

task.spawn(init)

-- ── PUBLIC API ────────────────────────────────────────────────────────────────
local IDV_Map = {}

function IDV_Map.Current()
    return _currentMapId
end

function IDV_Map.Meta()
    return _currentMeta or getMeta(_currentMapId)
end

-- Register callback: fn(newId, oldId, meta) — returns disconnect fn
function IDV_Map.OnChange(fn, tag)
    local entry = { fn = fn, tag = tag or "unnamed" }
    table.insert(_changeHandlers, entry)
    return function()
        for i, h in ipairs(_changeHandlers) do
            if h == entry then table.remove(_changeHandlers, i); break end
        end
    end
end

-- Check by id OR type: IDV_Map.IsMap("Map_01") or IDV_Map.IsMap("island")
function IDV_Map.IsMap(query)
    if _currentMapId == query then return true end
    return getMeta(_currentMapId).type == query
end

function IDV_Map.IsIsland() return IDV_Map.IsMap("island") end
function IDV_Map.IsCity()   return IDV_Map.IsMap("city")   end

-- Get a map-specific instance (miningContainer, fishingZone, miningSpawnPoints)
function IDV_Map.GetData(key)
    local data = getDataTable(_currentMapId)
    if not data then return nil end
    local fn = data[key]
    if type(fn) == "function" then return fn() end
    return fn
end

function IDV_Map.GetMiningContainer()   return IDV_Map.GetData("miningContainer")   end
function IDV_Map.GetFishingZone()       return IDV_Map.GetData("fishingZone")        end
function IDV_Map.GetMiningSpawnPoints() return IDV_Map.GetData("miningSpawnPoints")  end

-- ── GLOBAL EXPORT ─────────────────────────────────────────────────────────────
_G.IDV_Map = IDV_Map

print("[IDV_Map] Module initialized")
return IDV_Map
end)
if not _IDV_mapdetector_ok then
    warn("[IDV] IDV_mapdetector ERROR: " .. tostring(_IDV_mapdetector_err))
else
    print("[IDV] IDV_mapdetector loaded OK")
end
-- ════════════════════════════════════════════════════════════
--  IDV_pathfinding
-- ════════════════════════════════════════════════════════════
print("[IDV] Loading IDV_pathfinding...")
local _IDV_pathfinding_ok, _IDV_pathfinding_err = pcall(function()
-- ============================================================
--  IDV_pathfinding.lua — Advanced Standalone Pathfinding Module
--  Version 2.0: Anti-Float Jump, Realistic Ground Pathing, Deadlock Recompute
-- ============================================================

local PathfindingService = game:GetService("PathfindingService")
local Players            = game:GetService("Players")
local RunService         = game:GetService("RunService")
local Workspace          = game:GetService("Workspace")

local LocalPlayer = Players.LocalPlayer

-- ── GLOBAL CONNECTION HELPER ──────────────────────────────────────────────────
local function RegConn(conn, scope)
    if shared.DX8_RegisterConnection then
        shared.DX8_RegisterConnection(conn, scope)
    end
    return conn
end

-- ── MODULE STATE ──────────────────────────────────────────────────────────────
local _walking      = false
local _walkThread   = nil
local _stuckConn    = nil
local _showPath     = false
local _trailFolder  = nil

-- ── HELPERS: TRAIL VISUALIZER ─────────────────────────────────────────────────
local function clearPathVisuals()
    if _trailFolder then
        pcall(function() _trailFolder:Destroy() end)
        _trailFolder = nil
    end
end

local function renderPathVisuals(waypoints)
    clearPathVisuals()
    if not _showPath or not waypoints or #waypoints < 2 then return end

    _trailFolder = Instance.new("Folder")
    _trailFolder.Name = "DX8_PathVisuals"
    _trailFolder.Parent = Workspace

    local total = #waypoints
    local startColor = Color3.fromRGB(0, 210, 255)  -- Electric Cyan
    local endColor   = Color3.fromRGB(80, 240, 120) -- Emerald Lime

    for i = 1, total do
        local wp = waypoints[i]
        local alpha = (i - 1) / math.max(1, total - 1)
        local currentColor = startColor:Lerp(endColor, alpha)
        local posWithOffset = wp.Position + Vector3.new(0, 0.3, 0)

        local dot = Instance.new("Part")
        dot.Name = "WP_" .. i
        dot.Anchored = true
        dot.CanCollide = false
        dot.CanQuery = false
        dot.Shape = Enum.PartType.Cylinder
        dot.Size = Vector3.new(0.2, 1.4, 1.4)
        dot.Material = Enum.Material.Neon
        dot.Color = currentColor
        dot.Transparency = 0.35
        dot.CFrame = CFrame.new(posWithOffset) * CFrame.Angles(0, 0, math.pi / 2)
        dot.Parent = _trailFolder

        if i == total then
            local sb = Instance.new("SelectionBox")
            sb.Color3 = Color3.fromRGB(255, 215, 0)
            sb.LineThickness = 0.05
            sb.Adornee = dot
            sb.Parent = dot
        end

        if i > 1 then
            local prevPos = waypoints[i - 1].Position + Vector3.new(0, 0.3, 0)
            local dist = (posWithOffset - prevPos).Magnitude
            if dist > 0.5 then
                local trail = Instance.new("Part")
                trail.Name = "Trail_" .. i
                trail.Anchored = true
                trail.CanCollide = false
                trail.CanQuery = false
                trail.Material = Enum.Material.Neon
                trail.Color = currentColor
                trail.Transparency = 0.65
                trail.Size = Vector3.new(0.35, 0.35, dist)
                trail.CFrame = CFrame.new(prevPos, posWithOffset) * CFrame.new(0, 0, -dist / 2)
                trail.Parent = _trailFolder
            end
        end
    end
end

-- ── ADVANCED WALK ENGINE ──────────────────────────────────────────────────────
local function stopWalk()
    _walking = false
    if _walkThread then task.cancel(_walkThread); _walkThread = nil end
    if _stuckConn  then pcall(function() _stuckConn:Disconnect() end); _stuckConn = nil end
    clearPathVisuals()

    local char = LocalPlayer.Character
    local hum  = char and char:FindFirstChildOfClass("Humanoid")
    local hrp  = char and char:FindFirstChild("HumanoidRootPart")
    if hum and hrp then
        pcall(function() hum:MoveTo(hrp.Position) end)
    end
end

local function walkTo(destination, options)
    options = options or {}
    stopWalk()

    local char = LocalPlayer.Character
    local hrp  = char and char:FindFirstChild("HumanoidRootPart")
    local hum  = char and char:FindFirstChildOfClass("Humanoid")
    if not (hrp and hum) then return false end

    _walking = true
    local speed = options.speed or 32
    pcall(function() hum.WalkSpeed = speed end)

    _walkThread = task.spawn(function()
        -- 1. Realistic Ground-Based Path Parameters (No Cliff Climbing)
        -- AgentMaxSlope = 35° forces pathfinding onto roads, trails, and reasonable ground
        -- AgentJumpHeight = 7.0 studs prevents superhuman wall jumps
        local path = PathfindingService:CreatePath({
            AgentRadius          = options.agentRadius or 3.2,
            AgentHeight          = options.agentHeight or 5.0,
            AgentCanJump         = true,
            AgentJumpHeight      = options.agentJumpHeight or 7.0,
            AgentMaxSlope        = options.agentMaxSlope or 35,
            WaypointSpacing      = 5,
        })

        -- 2. Compute Path with retries if initial status is not Success
        local ok = false
        local waypoints = {}
        for attempt = 1, 3 do
            if not _walking then break end
            ok = pcall(function() path:ComputeAsync(hrp.Position, destination) end)
            if ok and path.Status == Enum.PathStatus.Success then
                waypoints = path:GetWaypoints()
                if #waypoints >= 2 then break end
            end
            task.wait(0.2)
        end

        -- Direct fallback if pathfinding status != Success or waypoints < 2
        if not ok or path.Status ~= Enum.PathStatus.Success or #waypoints < 2 then
            hum:MoveTo(destination)
            local arrived = false
            local conn = hum.MoveToFinished:Connect(function() arrived = true end)
            local deadline = os.clock() + 20
            pcall(function()
                while not arrived and _walking and os.clock() < deadline do
                    task.wait(0.1)
                end
            end)
            if conn then conn:Disconnect() end
            stopWalk()
            return
        end

        -- Render path visual trail if enabled
        renderPathVisuals(waypoints)

        -- 3. Anti-Floating Jump State & Multi-Ray Obstacle Scanner
        local lastCheckPos      = hrp.Position
        local lastStuckTime     = os.clock()
        local jumpDebounce      = false
        local consecutiveJumps  = 0
        local lastGroundTime    = os.clock()

        local function triggerAutoJump()
            if jumpDebounce then return end

            -- ANTI-FLOAT RULE 1: NEVER jump if player is in air / freefall!
            -- This completely prevents floating up against invisible walls / ceilings!
            if hum.FloorMaterial == Enum.Material.Air then
                return
            end

            -- ANTI-FLOAT RULE 2: Max 2 consecutive jumps on obstacle, then must be grounded
            if consecutiveJumps >= 2 then
                if os.clock() - lastGroundTime < 0.8 then
                    return -- Wait for ground recovery before jumping again
                end
                consecutiveJumps = 0
            end

            jumpDebounce = true
            consecutiveJumps = consecutiveJumps + 1
            lastGroundTime = os.clock()

            pcall(function()
                hum:ChangeState(Enum.HumanoidStateType.Jumping)
                hum.Jump = true
            end)
            task.delay(0.5, function() jumpDebounce = false end)
        end

        _stuckConn = RegConn(RunService.Heartbeat:Connect(function()
            if not _walking then return end

            local curPos   = hrp.Position
            local moveDir  = hum.MoveDirection
            local lookVec  = (moveDir.Magnitude > 0.1) and moveDir.Unit or hrp.CFrame.LookVector
            local horizVel = Vector3.new(hrp.AssemblyLinearVelocity.X, 0, hrp.AssemblyLinearVelocity.Z).Magnitude

            -- Reset consecutive jumps when standing firmly on ground
            if hum.FloorMaterial ~= Enum.Material.Air and horizVel > 3 then
                consecutiveJumps = 0
                lastGroundTime = os.clock()
            end

            -- Layer 1: Active Velocity Stuck Check (trying to move but speed < 1.5 studs/s for >0.4s)
            if moveDir.Magnitude > 0.1 and horizVel < 1.5 then
                if os.clock() - lastStuckTime > 0.4 then
                    triggerAutoJump()
                    lastStuckTime = os.clock()
                end
            else
                lastStuckTime = os.clock()
            end

            -- Layer 2: Multi-Height & Multi-Angle Obstacle Raycasts
            local rayParams = RaycastParams.new()
            rayParams.FilterDescendantsInstances = {char}
            rayParams.FilterType = Enum.RaycastFilterType.Exclude

            local heights = { 0.4, 1.8 }
            local angles  = { 0, math.rad(25), math.rad(-25) }
            local rayDist = 4.0

            local obstacleAhead = false
            for _, h in ipairs(heights) do
                local origin = curPos + Vector3.new(0, h, 0)
                for _, ang in ipairs(angles) do
                    local dir = (CFrame.Angles(0, ang, 0) * lookVec).Unit
                    local rayRes = Workspace:Raycast(origin, dir * rayDist, rayParams)
                    if rayRes and rayRes.Normal.Y < 0.7 then
                        obstacleAhead = true
                        break
                    end
                end
                if obstacleAhead then break end
            end

            if obstacleAhead and hum.FloorMaterial ~= Enum.Material.Air then
                triggerAutoJump()
            end
        end))

        -- 4. Dynamic Path Blocked Listener
        local blockConn = path.Blocked:Connect(function(blockedIdx)
            if _walking then
                pcall(function()
                    path:ComputeAsync(hrp.Position, destination)
                    if path.Status == Enum.PathStatus.Success then
                        waypoints = path:GetWaypoints()
                        renderPathVisuals(waypoints)
                    end
                end)
            end
        end)

        -- 5. Waypoint Navigation with Deadlock Timeout & Recomputation
        local recomputeCount = 0
        local mainIndex = 2

        while mainIndex <= #waypoints and _walking do
            local wp = waypoints[mainIndex]
            hum:MoveTo(wp.Position)

            if wp.Action == Enum.PathWaypointAction.Jump and hum.FloorMaterial ~= Enum.Material.Air then
                triggerAutoJump()
            end

            local wpArrived = false
            local wpConn = hum.MoveToFinished:Connect(function()
                wpArrived = true
            end)

            local wpDeadline     = os.clock() + 4.0
            local stuckStartTime = os.clock()
            local lastStuckPos   = hrp.Position
            local waypointStuck  = false

            pcall(function()
                while not wpArrived and _walking and os.clock() < wpDeadline do
                    task.wait(0.08)

                    -- Deadlock Check: Moved < 1.5 studs in 1.8 seconds?
                    local movedDist = (hrp.Position - lastStuckPos).Magnitude
                    if movedDist > 1.5 then
                        lastStuckPos   = hrp.Position
                        stuckStartTime = os.clock()
                    elseif os.clock() - stuckStartTime > 1.8 then
                        waypointStuck = true
                        break
                    end
                end
            end)

            if wpConn then wpConn:Disconnect() end

            if waypointStuck then
                recomputeCount = recomputeCount + 1
                print(string.format("[IDV_Pathfinding] Stuck at waypoint %d -> Recomputing alternate path (attempt %d/3)", mainIndex, recomputeCount))

                if recomputeCount >= 3 then
                    print("[IDV_Pathfinding] 3 recomputations failed (invisible wall/boundary) -> Cancelling walk!")
                    stopWalk()
                    return
                end

                -- Recompute alternate path from current position
                local reok = pcall(function() path:ComputeAsync(hrp.Position, destination) end)
                if reok and path.Status == Enum.PathStatus.Success then
                    waypoints = path:GetWaypoints()
                    renderPathVisuals(waypoints)
                    mainIndex = 2 -- Restart waypoints from new route
                else
                    stopWalk()
                    return
                end
            else
                mainIndex = mainIndex + 1
            end
        end

        if blockConn then blockConn:Disconnect() end
        stopWalk()
    end)
    return true
end

-- ── PUBLIC API EXPORT ─────────────────────────────────────────────────────────
local IDV_Pathfinding = {
    WalkTo = walkTo,
    Stop = stopWalk,
    IsWalking = function() return _walking end,
    SetShowPath = function(val)
        _showPath = val
        if not val then clearPathVisuals() end
    end,
}

_G.IDV_Pathfinding = IDV_Pathfinding
print("[IDV_Pathfinding v2.0] Ground Pathing & Anti-Float System Ready")
return IDV_Pathfinding
end)
if not _IDV_pathfinding_ok then
    warn("[IDV] IDV_pathfinding ERROR: " .. tostring(_IDV_pathfinding_err))
else
    print("[IDV] IDV_pathfinding loaded OK")
end
-- ════════════════════════════════════════════════════════════
--  IDV_esp
-- ════════════════════════════════════════════════════════════
print("[IDV] Loading IDV_esp...")
local _IDV_esp_ok, _IDV_esp_err = pcall(function()
-- ============================================================
--  IDV_esp.lua — Ore & Fishing Hotspot ESP / Chams Module
--  Exposes _G.IDV_ESP: SetOreESP(bool), SetFishingESP(bool), Cleanup()
-- ============================================================

local Workspace         = game:GetService("Workspace")
local Players           = game:GetService("Players")
local RunService        = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local LocalPlayer = Players.LocalPlayer

-- ── GLOBAL CONNECTION HELPER ──────────────────────────────────────────────────
local function RegConn(conn, scope)
    if shared.DX8_RegisterConnection then
        shared.DX8_RegisterConnection(conn, scope)
    end
    return conn
end

-- ── MODULE STATE ──────────────────────────────────────────────────────────────
local _oreESPEnabled     = false
local _fishingESPEnabled = false

local _espFolder         = nil
local _espLoopConn       = nil

-- ── HELPERS: CLEANUP ──────────────────────────────────────────────────────────
local function clearESPVisuals()
    if _espFolder then
        pcall(function() _espFolder:Destroy() end)
        _espFolder = nil
    end
end

-- ── ESP CREATOR HELPERS ───────────────────────────────────────────────────────
local function createESPBox(adornee, text, color, isHotspot)
    if not adornee or not adornee.Parent then return end

    local container = _espFolder
    if not container then return end

    -- 1. Highlight / Chams
    local hl = Instance.new("Highlight")
    hl.Name = "HL_" .. adornee.Name
    hl.Adornee = adornee
    hl.FillColor = color
    hl.FillTransparency = isHotspot and 0.5 or 0.75
    hl.OutlineColor = isHotspot and Color3.fromRGB(255, 215, 0) or Color3.fromRGB(255, 255, 255)
    hl.OutlineTransparency = 0.2
    hl.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
    hl.Parent = container

    -- 2. BillboardGui Label
    local bb = Instance.new("BillboardGui")
    bb.Name = "BB_" .. adornee.Name
    bb.Adornee = adornee
    bb.Size = UDim2.new(0, 160, 0, 30)
    bb.StudsOffset = Vector3.new(0, isHotspot and 4.5 or 3.5, 0)
    bb.AlwaysOnTop = true
    bb.Parent = container

    local label = Instance.new("TextLabel")
    label.Size = UDim2.new(1, 0, 1, 0)
    label.BackgroundTransparency = 1
    label.Text = text
    label.TextColor3 = color
    label.Font = Enum.Font.GothamBold
    label.TextSize = isHotspot and 14 or 12
    label.TextStrokeColor3 = Color3.new(0, 0, 0)
    label.TextStrokeTransparency = 0.3
    label.Parent = bb
end

-- ── MAIN UPDATE LOOP ──────────────────────────────────────────────────────────
local function updateESP()
    clearESPVisuals()
    if not _oreESPEnabled and not _fishingESPEnabled then return end

    _espFolder = Instance.new("Folder")
    _espFolder.Name = "DX8_ESP_Folder"
    _espFolder.Parent = Workspace

    local char = LocalPlayer.Character
    local hrp  = char and char:FindFirstChild("HumanoidRootPart")
    local pPos = hrp and hrp.Position or Vector3.new(0, 0, 0)

    -- 1. ORE ESP
    if _oreESPEnabled then
        local miningContainer = _G.IDV_Map and _G.IDV_Map.GetMiningContainer and _G.IDV_Map.GetMiningContainer()
        if not miningContainer then
            local main = Workspace:FindFirstChild("Main")
            miningContainer = main and main:FindFirstChild("ActiveMiningStones")
        end

        if miningContainer then
            for _, stone in ipairs(miningContainer:GetChildren()) do
                local stonePos = nil
                if stone:IsA("Model") then
                    stonePos = stone:GetBoundingBox().Position
                elseif stone:IsA("BasePart") then
                    stonePos = stone.Position
                end

                if stonePos then
                    local dist = math.floor((pPos - stonePos).Magnitude)
                    local isHot = stone:GetAttribute("IsHotspot") == true or stone:FindFirstChild("Hotspot") ~= nil
                    local color = isHot and Color3.fromRGB(255, 215, 0) or Color3.fromRGB(150, 215, 255)
                    local title = isHot and string.format("⭐ HOTSPOT ORE (%dm)", dist) or string.format("⛏️ Ore (%dm)", dist)
                    createESPBox(stone, title, color, isHot)
                end
            end
        end
    end

    -- 2. FISHING HOTSPOT ESP
    if _fishingESPEnabled then
        local fishingZone = _G.IDV_Map and _G.IDV_Map.GetFishingZone and _G.IDV_Map.GetFishingZone()
        if not fishingZone then
            local main = Workspace:FindFirstChild("Main")
            fishingZone = main and main:FindFirstChild("FishingZone")
        end

        if fishingZone then
            for idx, part in ipairs(fishingZone:GetChildren()) do
                if part:IsA("BasePart") then
                    local dist = math.floor((pPos - part.Position).Magnitude)
                    local isActive = part:GetAttribute("IsActive") == true or part:FindFirstChild("DX8_Active") ~= nil
                    local color = isActive and Color3.fromRGB(80, 240, 120) or Color3.fromRGB(200, 200, 200)
                    local title = isActive and string.format("🎣 HOTSPOT SPOT #%d (%dm)", idx, dist) or string.format("○ Spot #%d (%dm)", idx, dist)
                    createESPBox(part, title, color, isActive)
                end
            end
        end
    end
end

-- ── START/STOP ESP LOOP ───────────────────────────────────────────────────────
local function refreshLoopState()
    if _oreESPEnabled or _fishingESPEnabled then
        if not _espLoopConn then
            local lastUpdate = 0
            _espLoopConn = RegConn(RunService.Heartbeat:Connect(function()
                if os.clock() - lastUpdate > 1.5 then -- Refresh every 1.5s
                    lastUpdate = os.clock()
                    pcall(updateESP)
                end
            end))
        end
    else
        if _espLoopConn then
            pcall(function() _espLoopConn:Disconnect() end)
            _espLoopConn = nil
        end
        clearESPVisuals()
    end
end

-- ── PUBLIC API ────────────────────────────────────────────────────────────────
local IDV_ESP = {
    SetOreESP = function(val)
        _oreESPEnabled = val
        refreshLoopState()
    end,
    SetFishingESP = function(val)
        _fishingESPEnabled = val
        refreshLoopState()
    end,
    Cleanup = function()
        _oreESPEnabled = false
        _fishingESPEnabled = false
        refreshLoopState()
    end,
}

_G.IDV_ESP = IDV_ESP
print("[IDV_ESP] Ore & Fishing ESP / Chams Module Loaded")
return IDV_ESP
end)
if not _IDV_esp_ok then
    warn("[IDV] IDV_esp ERROR: " .. tostring(_IDV_esp_err))
else
    print("[IDV] IDV_esp loaded OK")
end
-- ════════════════════════════════════════════════════════════
--  IDV_autosell
-- ════════════════════════════════════════════════════════════
print("[IDV] Loading IDV_autosell...")
local _IDV_autosell_ok, _IDV_autosell_err = pcall(function()
-- ============================================================
--  IDV_autosell.lua — Smart Auto-Sell Engine with Pathfinding
--  Pathfinds & walks to Shop NPC (OreShop or FishShop), sells items,
--  waits for sell validation, and resumes previous activity!
-- ============================================================

local Workspace         = game:GetService("Workspace")
local Players           = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local LocalPlayer = Players.LocalPlayer

-- ── HELPERS: SHOP NPC FINDER ──────────────────────────────────────────────────
local function getShopNPC(shopName)
    local world = Workspace:FindFirstChild("World")
    if not world then return nil end

    local mapVal = ReplicatedStorage:FindFirstChild("Status")
        and ReplicatedStorage.Status:FindFirstChild("WorldStatus")
        and ReplicatedStorage.Status.WorldStatus:FindFirstChild("Map")
    local mapName = mapVal and mapVal.Value or "Map_01"

    local currentMap = world:FindFirstChild(mapName)
    if not currentMap then return nil end

    local assetFolder = currentMap:FindFirstChild("Asset")
    local shopFolder  = assetFolder and assetFolder:FindFirstChild("ShopNPC")

    if shopFolder then
        return shopFolder:FindFirstChild(shopName)
    end
    return nil
end

local function getShopPosition(shopName)
    local npc = getShopNPC(shopName)
    if not npc then return nil end

    if npc:IsA("Model") then
        local primary = npc.PrimaryPart or npc:FindFirstChild("HumanoidRootPart") or npc:FindFirstChildWhichIsA("BasePart")
        if primary then return primary.Position end
        return npc:GetBoundingBox().Position
    elseif npc:IsA("BasePart") then
        return npc.Position
    end
    return nil
end

-- ── SELL FILTER CONSTANTS ─────────────────────────────────────────────────────
local ALL_ORE_TIERS = {
    "Ancient",
    "Mythic",
    "Legend",
    "Epic",
    "Rare",
    "Uncommon",
    "Common"
}

-- ── AUTO SELL ORES ────────────────────────────────────────────────────────────
-- keepList: table/set of tier names to SKIP (not sell). e.g. {"Ancient"=true} or {"Ancient","Mythic"}
-- onComplete: callback(success: bool, serverMsg: string)
local function sellOres(keepList, onComplete)
    -- Support old single-arg call: sellOres(callback)
    if type(keepList) == "function" then
        onComplete = keepList
        keepList   = {}
    end
    keepList = keepList or {}

    -- Normalize: accept both array {"Ancient","Mythic"} and set {Ancient=true}
    local keepSet = {}
    for k, v in pairs(keepList) do
        if type(k) == "number" then
            keepSet[v] = true        -- array form
        else
            keepSet[k] = v           -- set form {name=true}
        end
    end

    -- Build list of tiers to SELL (all tiers NOT in keepSet)
    local tiersToSell = {}
    for _, tier in ipairs(ALL_ORE_TIERS) do
        if not keepSet[tier] then
            table.insert(tiersToSell, tier)
        end
    end

    task.spawn(function()
        local grf           = ReplicatedStorage:FindFirstChild("GameRemoteFunctions")
        local sellAllRemote = grf and grf:FindFirstChild("SellAllOreFunction")

        local shopPos = getShopPosition("OreShop")
        if not shopPos then
            warn("[IDV_AutoSell] OreShop NPC position not found!")
            if onComplete then onComplete(false, "OreShop NPC position not found") end
            return
        end

        -- Pause mining walk while auto-selling
        if _G.Mining and _G.Mining.PauseForSell then
            pcall(_G.Mining.PauseForSell)
        end

        -- 1. Pathfind & walk to OreShop NPC
        print("[IDV_AutoSell] Starting Auto-Sell Ores — selling " .. #tiersToSell .. "/" .. #ALL_ORE_TIERS .. " tiers...")
        if _G.IDV_Pathfinding and _G.IDV_Pathfinding.WalkTo then
            print("[IDV_AutoSell] Pathfinding to OreShop NPC...")
            _G.IDV_Pathfinding.WalkTo(shopPos, { speed = 32 })

            local deadline = os.clock() + 35
            while os.clock() < deadline do
                task.wait(0.2)
                local char = LocalPlayer.Character
                local hrp  = char and char:FindFirstChild("HumanoidRootPart")
                if hrp and (hrp.Position - shopPos).Magnitude <= 12 then break end
                if not _G.IDV_Pathfinding.IsWalking() then break end
            end
            pcall(_G.IDV_Pathfinding.Stop)
        end

        -- 2. Invoke SellAllOreFunction with tier payload
        print("[IDV_AutoSell] Arrived at OreShop. Invoking SellAllOreFunction with " .. #tiersToSell .. " tiers...")
        local success   = false
        local serverMsg = nil

        if sellAllRemote then
            local resTable = nil
            local ok, err = pcall(function()
                resTable = table.pack(sellAllRemote:InvokeServer(tiersToSell))
            end)

            if ok and resTable then
                success   = resTable[1] == true
                serverMsg = type(resTable[2]) == "string" and resTable[2] or (resTable[2] ~= nil and tostring(resTable[2]) or nil)
                print("[IDV_AutoSell] SellAllOreFunction result -> success:", success, "msg:", tostring(serverMsg))
            else
                serverMsg = tostring(err or "Invoke failed")
                print("[IDV_AutoSell] SellAllOreFunction invoke error:", serverMsg)
            end
        else
            serverMsg = "SellAllOreFunction remote not found"
            warn("[IDV_AutoSell] " .. serverMsg)
        end

        -- Wait delay for sell animation / inventory refresh
        task.wait(1.5)

        -- Resume mining engine and auto-walk back to ores
        if _G.Mining and _G.Mining.ResumeAfterSell then
            pcall(_G.Mining.ResumeAfterSell)
        end

        if onComplete then onComplete(success, serverMsg) end
    end)
end

-- ── AUTO SELL FISH ────────────────────────────────────────────────────────────
local function sellFish(onComplete)
    task.spawn(function()
        print("[IDV_AutoSell] Starting Auto-Sell Fish pathfinding workflow...")

        local shopPos = getShopPosition("FishShop")
        if not shopPos then
            warn("[IDV_AutoSell] FishShop NPC position not found!")
            if onComplete then onComplete(false, "FishShop NPC position not found") end
            return
        end

        -- 1. Pathfind & walk to FishShop NPC
        if _G.IDV_Pathfinding and _G.IDV_Pathfinding.WalkTo then
            print("[IDV_AutoSell] Pathfinding to FishShop NPC...")
            _G.IDV_Pathfinding.WalkTo(shopPos, { speed = 32 })

            local deadline = os.clock() + 35
            while os.clock() < deadline do
                task.wait(0.2)
                local char = LocalPlayer.Character
                local hrp  = char and char:FindFirstChild("HumanoidRootPart")
                if hrp and (hrp.Position - shopPos).Magnitude <= 12 then break end
                if not _G.IDV_Pathfinding.IsWalking() then break end
            end
            pcall(_G.IDV_Pathfinding.Stop)
        end

        -- 2. Invoke Sell All Fish Remote
        print("[IDV_AutoSell] Arrived at FishShop. Invoking SellAllFishFunction...")
        local grf           = ReplicatedStorage:FindFirstChild("GameRemoteFunctions")
        local sellAllRemote = grf and grf:FindFirstChild("SellAllFishFunction")

        local success   = false
        local serverMsg = nil

        if sellAllRemote then
            local resTable = nil
            local ok, err = pcall(function()
                resTable = table.pack(sellAllRemote:InvokeServer())
            end)

            if ok and resTable then
                success   = resTable[1] == true
                serverMsg = type(resTable[2]) == "string" and resTable[2] or (resTable[2] ~= nil and tostring(resTable[2]) or nil)
                print("[IDV_AutoSell] SellAllFishFunction result -> success:", success, "msg:", tostring(serverMsg))
            else
                serverMsg = tostring(err or "Invoke failed")
            end
        else
            serverMsg = "SellAllFishFunction remote not found"
        end

        task.wait(1.5)

        if onComplete then
            onComplete(success, serverMsg)
        end
    end)
end

-- ── DEDICATED SHOP & AUTO SELL UI TAB ─────────────────────────────────────────
pcall(function()
    local DX8 = _G.DX8_Library
    local win = _G.DX8_MainWindow
    if not DX8 or not win then return end

    local shopTab    = win:CreateTab("Shop", "Shop & Auto Sell", 2)
    local oreShopSec = shopTab:AddSection("⛏️ Ore Shop & Auto Sell")
    local fishShopSec= shopTab:AddSection("🐟 Fish Shop & Auto Sell")

    -- 1. Ore Shop Section
    oreShopSec:AddButton({
        Title = "💰 Walk & Sell Ores",
        Description = "Pathfind dan berjalan otomatis ke OreShop NPC lalu menjual ore.",
        Callback = function()
            if _G.IDV_AutoSell and _G.IDV_AutoSell.SellOres then
                local keepList = (_G.Mining_CFG and _G.Mining_CFG.KEEP_ORES) or {}
                local keepCount = 0
                for _ in pairs(keepList) do keepCount = keepCount + 1 end
                local msg = keepCount > 0 and ("Menjual ore (tahan " .. keepCount .. " tier)...") or "Menjual semua ore..."
                DX8:Notify("Auto Sell", msg, 3)
                _G.IDV_AutoSell.SellOres(keepList, function(success, serverMsg)
                    if serverMsg and serverMsg ~= "" then
                        local title = success and "Auto Sell Success" or "Auto Sell"
                        DX8:Notify(title, serverMsg, 4)
                    end
                end)
            end
        end
    })

    local ALL_ORE_TIERS = { "Ancient", "Mythic", "Legend", "Epic", "Rare", "Uncommon", "Common" }
    oreShopSec:AddDropdown({
        Title       = "Keep Ore Tiers (Don't Sell)",
        List        = ALL_ORE_TIERS,
        Default     = {},
        Flag        = "ShopKeepOres",
        MultiSelect = true,
        Callback    = function(v)
            if _G.Mining_CFG then _G.Mining_CFG.KEEP_ORES = v end
            if type(v) == "table" and next(v) then
                DX8:Notify("Sell Filter", "Tahan tier: " .. table.concat(v, ", "), 3)
            else
                DX8:Notify("Sell Filter", "Jual semua tier (tidak ada yang ditahan)", 2)
            end
        end
    })

    -- 2. Fish Shop Section
    fishShopSec:AddButton({
        Title = "🚶 Walk & Sell All Fish",
        Description = "Pathfind dan berjalan otomatis ke FishShop NPC lalu menjual semua ikan.",
        Callback = function()
            DX8:Notify("Auto Sell", "Berjalan ke FishShop NPC...", 3)
            if _G.IDV_AutoSell and _G.IDV_AutoSell.SellFish then
                _G.IDV_AutoSell.SellFish(function(success, serverMsg)
                    if serverMsg and serverMsg ~= "" then
                        local title = success and "Auto Sell Fish Success" or "Auto Sell Fish"
                        DX8:Notify(title, serverMsg, 4)
                    end
                end)
            end
        end
    })
end)

-- ── PUBLIC API EXPORT ─────────────────────────────────────────────────────────
local IDV_AutoSell = {
    SellOres     = sellOres,
    SellFish     = sellFish,
    GetOreShop   = function() return getShopPosition("OreShop") end,
    GetFishShop  = function() return getShopPosition("FishShop") end,
}

_G.IDV_AutoSell = IDV_AutoSell
print("[IDV_AutoSell] Pathfinding Auto-Sell Engine Loaded with Dedicated Shop Tab")
return IDV_AutoSell

end)
if not _IDV_autosell_ok then
    warn("[IDV] IDV_autosell ERROR: " .. tostring(_IDV_autosell_err))
else
    print("[IDV] IDV_autosell loaded OK")
end
-- ════════════════════════════════════════════════════════════
--  IDV_mining
-- ════════════════════════════════════════════════════════════
print("[IDV] Loading IDV_mining...")
local _IDV_mining_ok, _IDV_mining_err = pcall(function()
local DX8 = _G.DX8_Library
local win = _G.DX8_MainWindow
-- ── SCRIPT CLEANUP ON RE-EXECUTION ───────────────────────────────────────────
if shared.DX8_Mining_Cleanup then
    pcall(shared.DX8_Mining_Cleanup)
end

local MiningConnections = {}
local function AddConn(conn)
    table.insert(MiningConnections, conn)
    return conn
end

-- ── DX8 BOOTSTRAP ─────────────────────────────────────────────────────────────

-- ── SERVICES ──────────────────────────────────────────────────────────────────
local Players            = game:GetService("Players")
local RunService         = game:GetService("RunService")
local UserInputService   = game:GetService("UserInputService")
local PathfindingService = game:GetService("PathfindingService")

local LocalPlayer = Players.LocalPlayer
local PlayerGui   = LocalPlayer:WaitForChild("PlayerGui")

-- ── CONFIG ────────────────────────────────────────────────────────────────────
local CFG = {
    -- Mining
    SEARCH_RADIUS    = 40,      -- studs: ore must be inside this to trigger
    LOOP_DELAY       = 0.8,     -- seconds between main loop ticks
    HIT_GAP          = 0.12,    -- seconds debounce between minigame hits
    SAFE_ZONE_PCT    = 0.05,    -- fraction of bar zone that counts as "in zone"
    WATCHDOG_TIME    = 3,       -- seconds before unlocking if mining UI never opens

    -- Walk
    AUTO_WALK        = true,
    WALK_RADIUS      = 2000,    -- studs: max range to look for distant ores (covers entire map)
    WALK_SPEED       = 32,      -- WalkSpeed while walking (Roblox default = 16)
    NAV_MODE         = "Smart", -- "Smart" (PathfindingService) or "Direct"
    DETECT_INTERVAL  = 0.15,    -- seconds: how fast we check for ore WHILE walking

    -- Ore filter
    HOTSPOT_MODE     = "Prioritize Hotspot", -- "Prioritize Hotspot", "Only Hotspot", "All Ores", "Only Normal"

    -- Sell filter: ore types to KEEP (not sell)
    KEEP_ORES        = {},  -- e.g. {"Mythril","Uranium","Void"}

    -- Auto Sell
    AUTO_SELL        = false,   -- auto sell loop enable
    SELL_INTERVAL    = 180,     -- seconds between auto sell checks

    -- Visual
    SHOW_RADIUS      = false,

    -- Misc
    DEBUG            = false,
}
_G.Mining_CFG = CFG

-- ── STATE ─────────────────────────────────────────────────────────────────────
local running      = false    -- auto-mine loop on/off
local busy         = false    -- currently in a mining minigame session
local walking      = false    -- walk thread running
local pausedForSell= false    -- paused temporarily during sell workflow
local status       = "Idle"
local totalMined   = 0
local totalFailed  = 0
local sessionToken = nil
local mainThread   = nil
local walkThread   = nil
local autoSellThread = nil

local function log(...) if CFG.DEBUG then print("[Mining]", ...) end end

-- Clear stale hook-guard attributes from any prior execution
do
    local function clearTool(parent)
        if not parent then return end
        for _, v in ipairs(parent:GetChildren()) do
            if v:IsA("Tool") and (v:FindFirstChild("Mine") or v:GetAttribute("IsPickaxe")) then
                pcall(function() v:SetAttribute("_DX8TokenHooked",  nil) end)
                pcall(function() v:SetAttribute("_DX8ResultHooked", nil) end)
            end
        end
    end
    clearTool(LocalPlayer and LocalPlayer.Character)
    clearTool(LocalPlayer and LocalPlayer:FindFirstChild("Backpack"))
end

-- ── HELPERS: ORE CONTAINERS ───────────────────────────────────────────────────
local function getContainer()
    if _G.IDV_Map and _G.IDV_Map.GetMiningContainer then
        local c = _G.IDV_Map.GetMiningContainer()
        if c then return c end
    end
    local main = workspace:FindFirstChild("Main")
    if main and main:FindFirstChild("ActiveMiningStones") then
        return main.ActiveMiningStones
    end
    local rsMain = game:GetService("ReplicatedStorage"):FindFirstChild("Main")
    return rsMain and rsMain:FindFirstChild("ActiveMiningStones")
end

local function getStonePos(stone)
    if stone:IsA("Model") then
        local cf = stone:GetBoundingBox()
        return cf.Position
    elseif stone:IsA("BasePart") then
        return stone.Position
    end
    return nil
end

local function isHotspot(stone)
    if not stone then return false end
    -- The game explicitly sets attribute "IsHotspot" = true on hotspot stones
    local attr = stone:GetAttribute("IsHotspot")
    if attr ~= nil then
        return attr == true
    end
    -- Fallback: name-based detection
    local name = stone.Name:lower()
    return name:find("hotspot") ~= nil or name:find("hot") ~= nil
end

local function isAllowed(stone)
    if not stone then return false end
    -- Basic check: must have a Position or be a Model
    if not (stone:IsA("BasePart") or stone:IsA("Model")) then return false end
    -- Hotspot mode filter
    local mode = CFG.HOTSPOT_MODE or "Prioritize Hotspot"
    if mode == "Only Hotspot" then
        return isHotspot(stone)
    elseif mode == "Only Normal" then
        return not isHotspot(stone)
    end
    -- "All Ores" and "Prioritize Hotspot" — accept everything
    return true
end

local function findOre(maxRadius)
    local char = LocalPlayer.Character
    local hrp  = char and char:FindFirstChild("HumanoidRootPart")
    if not hrp then return nil, nil, nil end
    local container = getContainer()
    if not container then return nil, nil, nil end

    local bestHotDist,  bestHotPos,  bestHotStone  = maxRadius, nil, nil
    local bestNormDist, bestNormPos, bestNormStone = maxRadius, nil, nil
    local bestAnyDist,  bestAnyPos,  bestAnyStone  = maxRadius, nil, nil

    for _, stone in ipairs(container:GetChildren()) do
        if isAllowed(stone) then
            local pos = getStonePos(stone)
            if pos then
                local d = (hrp.Position - pos).Magnitude
                if d < maxRadius then
                    if d < bestAnyDist then
                        bestAnyDist, bestAnyPos, bestAnyStone = d, pos, stone
                    end
                    if isHotspot(stone) then
                        if d < bestHotDist then
                            bestHotDist, bestHotPos, bestHotStone = d, pos, stone
                        end
                    else
                        if d < bestNormDist then
                            bestNormDist, bestNormPos, bestNormStone = d, pos, stone
                        end
                    end
                end
            end
        end
    end

    local mode = CFG.HOTSPOT_MODE or "Prioritize Hotspot"

    if mode == "Only Hotspot" then
        return bestHotStone, bestHotDist, bestHotPos
    elseif mode == "Only Normal" then
        return bestNormStone, bestNormDist, bestNormPos
    elseif mode == "All Ores" then
        return bestAnyStone, bestAnyDist, bestAnyPos
    else
        -- "Prioritize Hotspot" (Default):
        -- Prefer Hotspot if found within radius; fallback to closest Normal ore
        if bestHotStone then
            return bestHotStone, bestHotDist, bestHotPos
        end
        return bestNormStone, bestNormDist, bestNormPos
    end
end

-- ── HELPERS: PICKAXE ──────────────────────────────────────────────────────────
local function findPickaxe()
    local char = LocalPlayer.Character
    local bp   = LocalPlayer:FindFirstChild("Backpack")
    local function check(parent)
        if not parent then return nil end
        for _, v in ipairs(parent:GetChildren()) do
            if v:IsA("Tool") and (v:FindFirstChild("Mine") or v:GetAttribute("IsPickaxe")) then
                return v
            end
        end
    end
    return check(char) or check(bp)
end

local function equip(pickaxe)
    local char = LocalPlayer.Character
    if not char or pickaxe.Parent == char then return end
    local hum = char:FindFirstChildOfClass("Humanoid")
    if hum then hum:EquipTool(pickaxe) end
end

-- ── TARGET STATE (forward-declared — hookToken closure needs these) ───────────
local idvTargetMineGoal        = 0
local idvTargetMineProgressBar = nil
local idvTargetMineManager     = nil

-- Status stat cards (forward-declared; assigned in the UI section below)
local statTotal    = nil   -- total attempts (mined + failed)
local statMined    = nil   -- successful mines
local statFailed   = nil   -- failed mines
local statRate     = nil   -- success rate %
local statusBarLbl = nil   -- status text label inside the hand-built status bar

-- Color constants (used in hookToken and the UI section)
local _GREEN = Color3.fromRGB(80,  220, 120)
local _RED   = Color3.fromRGB(220, 90,  90)
local _BLUE  = Color3.fromRGB(100, 195, 255)

-- ── TOKEN ─────────────────────────────────────────────────────────────────────
local function hookToken(pickaxe)
    if not pickaxe then return end
    local ev = pickaxe:FindFirstChild("ToolReady")
    if ev then
        if not pickaxe:GetAttribute("_DX8TokenHooked") then
            pickaxe:SetAttribute("_DX8TokenHooked", true)
            ev.OnClientEvent:Connect(function(tok)
                sessionToken = tok
                log("token received:", tostring(tok))
            end)
        end
    end

    local mineResult = pickaxe:FindFirstChild("MineResult")
    if mineResult and not pickaxe:GetAttribute("_DX8ResultHooked") then
        pickaxe:SetAttribute("_DX8ResultHooked", true)
        mineResult.OnClientEvent:Connect(function(result)
            -- Server sends a table; CanMine=true means ore successfully mined
            local success = type(result) == "table" and result.CanMine == true
            if success then
                totalMined = totalMined + 1
                -- Target manager
                if idvTargetMineManager then idvTargetMineManager:Set(totalMined) end
                if idvTargetMineProgressBar then
                    if idvTargetMineGoal > 0 then
                        local pct = math.clamp((totalMined / idvTargetMineGoal) * 100, 0, 100)
                        idvTargetMineProgressBar:SetPercent(pct, string.format("%d/%d", totalMined, idvTargetMineGoal))
                    else
                        idvTargetMineProgressBar:SetStatus(tostring(totalMined) .. " mined")
                    end
                end
                -- Stat cards — drive from authoritative counters, flash green
                if statTotal  then statTotal:Set(totalMined + totalFailed) end
                if statMined  then statMined:Set(totalMined); statMined:Flash(_GREEN) end
                if CFG.DEBUG and type(result) == "table" then
                    log(string.format("Mined: %s [%s] $%d | total: %d",
                        result.OreName or "?", result.Rarity or "?",
                        result.Price or 0, totalMined))
                end
                log("MineResult: SUCCESS, total:", totalMined)
            else
                totalFailed = totalFailed + 1
                -- Stat cards — drive from authoritative counters, flash red
                if statTotal  then statTotal:Set(totalMined + totalFailed) end
                if statFailed then statFailed:Set(totalFailed); statFailed:Flash(_RED) end
                log("MineResult: FAILED, total:", totalFailed)
            end
        end)
    end
end

local function ensureToken()
    local p = findPickaxe()
    if not p then return end
    hookToken(p)
    if p.Parent ~= LocalPlayer.Character then
        equip(p)
    end
    if not sessionToken then
        task.spawn(function()
            local char = LocalPlayer.Character
            local hum  = char and char:FindFirstChildOfClass("Humanoid")
            if hum and p then
                hum:UnequipTools()
                task.wait(0.2)
                hum:EquipTool(p)
                hookToken(p)
            end
        end)
    end
end

-- Auto-hook whenever pickaxe enters character or backpack
AddConn(LocalPlayer.CharacterAdded:Connect(function(char)
    sessionToken = nil
    task.wait(1)
    ensureToken()
end))

task.spawn(function()
    -- Hook on backpack adds
    local bp = LocalPlayer:WaitForChild("Backpack", 5)
    if bp then
        AddConn(bp.ChildAdded:Connect(function(child)
            if child:IsA("Tool") and (child:FindFirstChild("Mine") or child:GetAttribute("IsPickaxe")) then
                task.wait(0.2)
                hookToken(child)
            end
        end))
    end
    -- Hook current pickaxe immediately
    task.wait(0.5)
    ensureToken()
end)

-- ── WALK ENGINE ───────────────────────────────────────────────────────────────
local _origSpeed   = nil
local _walkTarget  = nil
local _oreScanner  = nil

local function setSpeed(spd)
    local char = LocalPlayer.Character
    local hum  = char and char:FindFirstChildOfClass("Humanoid")
    if not hum then return end
    pcall(function() hum.WalkSpeed = spd end)
end
local _jumpConn = nil  -- jump detector connection, cleaned up by stopWalk

local function stopWalk()
    walking = false
    _walkTarget = nil
    if _G.IDV_Pathfinding and _G.IDV_Pathfinding.Stop then
        pcall(_G.IDV_Pathfinding.Stop)
    end
    if walkThread  then task.cancel(walkThread);  walkThread  = nil end
    if _oreScanner then pcall(function() _oreScanner:Disconnect() end); _oreScanner = nil end
    if _origSpeed  then setSpeed(_origSpeed);     _origSpeed  = nil end
    local char = LocalPlayer.Character
    local hum  = char and char:FindFirstChildOfClass("Humanoid")
    local hrp  = char and char:FindFirstChild("HumanoidRootPart")
    if hum and hrp then pcall(function() hum:MoveTo(hrp.Position) end) end
end

-- Test coordinate grabbed live (city map crevice, FloorMaterial=Air)
local _TEST_PIT_POS = Vector3.new(367.160, 84.118, 5906.909)

-- Flawless walk engine using IDV_pathfinding module:
-- 1. Delegates path creation, waypoint iteration, and wall collision stuck-jump to IDV_pathfinding.lua
-- 2. Parallel RunService ore scanner — interrupts walk instantly when ore enters SEARCH_RADIUS
local function startWalk(targetPos)
    stopWalk()

    local char = LocalPlayer.Character
    local hrp  = char and char:FindFirstChild("HumanoidRootPart")
    local hum  = char and char:FindFirstChildOfClass("Humanoid")
    if not (hrp and hum) then return end

    if _origSpeed == nil then _origSpeed = hum.WalkSpeed end
    setSpeed(CFG.WALK_SPEED)
    walking     = true
    _walkTarget = targetPos

    -- ── ORE SCANNER ──────────────────────────────────────────────────────────
    local _scanClock = os.clock()
    _oreScanner = RunService.Heartbeat:Connect(function()
        if not walking or busy or not running then
            if _oreScanner then _oreScanner:Disconnect(); _oreScanner = nil end
            return
        end
        if os.clock() - _scanClock < CFG.DETECT_INTERVAL then return end
        _scanClock = os.clock()
        local s, _, p = findOre(CFG.SEARCH_RADIUS)
        if s and p then
            stopWalk()
        end
    end)

    -- ── DELEGATE TO ADVANCED PATHFINDING MODULE ──────────────────────────────
    if _G.IDV_Pathfinding and _G.IDV_Pathfinding.WalkTo then
        _G.IDV_Pathfinding.WalkTo(targetPos, {
            speed           = CFG.WALK_SPEED,
            agentRadius     = 3.0,
            agentJumpHeight = 14.0,
        })
    end
end


-- ── RADIUS VISUAL ─────────────────────────────────────────────────────────────
local _rFill, _rBorder, _rAdorn = nil, nil, nil
local _ringThread = nil
local RING_COLOR = Color3.fromRGB(100, 195, 255)

local function killRing()
    for _, p in ipairs({_rFill, _rBorder, _rAdorn}) do
        if p then pcall(function() p:Destroy() end) end
    end
    _rFill, _rBorder, _rAdorn = nil, nil, nil

    -- Clean any leftover ring parts in workspace from previous script runs
    pcall(function()
        for _, child in ipairs(workspace:GetChildren()) do
            if child.Name == "DX8_RFill" or child.Name == "DX8_RBorder" or child.Name == "DX8_RAdorn" then
                child:Destroy()
            end
        end
    end)
end

-- Clean stray ring parts on script load
killRing()

local function makeDisk(name, r, trans)
    local p = Instance.new("Part")
    p.Name, p.Anchored, p.CanCollide, p.CanQuery = name, true, false, false
    p.CanTouch, p.CastShadow = false, false
    p.Transparency, p.Material = trans, Enum.Material.Neon
    p.Color, p.Shape = RING_COLOR, Enum.PartType.Cylinder
    p.Size   = Vector3.new(0.12, r * 2, r * 2)
    p.Parent = workspace
    return p
end

local function buildRing(r)
    killRing()
    _rFill   = makeDisk("DX8_RFill",   r,        0.97)
    _rBorder = makeDisk("DX8_RBorder", r + 0.8,  0.5)
    _rAdorn  = Instance.new("SelectionBox")
    _rAdorn.Name = "DX8_RAdorn"
    _rAdorn.Color3, _rAdorn.LineThickness  = RING_COLOR, 0.04
    _rAdorn.SurfaceTransparency, _rAdorn.Adornee = 1, _rBorder
    _rAdorn.Parent = workspace
end

local _lastRingR = 0
if _ringThread then task.cancel(_ringThread) end
_ringThread = task.spawn(function()
    local myExecId = shared.DX8_CurrentExecutionID
    while shared.DX8_CurrentExecutionID == myExecId do
        task.wait(0.03)
        if CFG.SHOW_RADIUS then
            local char = LocalPlayer.Character
            local hrp  = char and char:FindFirstChild("HumanoidRootPart")
            if hrp then
                local r = CFG.SEARCH_RADIUS
                if not _rBorder or not _rBorder.Parent or math.abs(r - _lastRingR) > 0.5 then
                    buildRing(r)
                    _lastRingR = r
                end
                local cf = CFrame.new(hrp.Position - Vector3.new(0, 3.1, 0))
                         * CFrame.Angles(0, 0, math.pi / 2)
                if _rFill   then _rFill.CFrame   = cf end
                if _rBorder then _rBorder.CFrame = cf end
            end
        elseif _rBorder then
            killRing()
        end
    end
    killRing()
end)

-- ── MINING UI HOOK ────────────────────────────────────────────────────────────
local function hookMiningUI(gui)
    local PreHolder  = gui:FindFirstChild("PreMiningHolder")
    local MineHolder = gui:FindFirstChild("MiningHolder")
    if not (PreHolder and MineHolder) then return end

    local DragBtn   = PreHolder:FindFirstChild("DragButton")
    local TargetFrm = PreHolder:FindFirstChild("TargetFrame")
    local DragDet   = DragBtn and DragBtn:FindFirstChild("UIDragDetector")
    local MineFrm   = MineHolder:FindFirstChild("MiningFrame")
    local BarCont   = MineFrm and MineFrm:FindFirstChild("BarContainer")
    local Bar       = BarCont and BarCont:FindFirstChild("Bar")
    local Point     = BarCont and BarCont:FindFirstChild("Point")
    local InfoLabel = MineFrm and MineFrm:FindFirstChild("InfoLabel")

    if not (DragBtn and TargetFrm and DragDet and Bar and Point) then
        warn("[Mining] missing UI elements in", gui.Name)
        return
    end

    -- Find registerHit via upvalue scan
    local registerHitFn = nil
    local function scanHit()
        if not getconnections or not getupvalues then return nil end
        local ok, conns = pcall(getconnections, UserInputService.InputBegan)
        if not ok then return nil end
        for _, c in ipairs(conns) do
            local fn = c.Function
            if type(fn) ~= "function" then continue end
            local ok2, ups = pcall(getupvalues, fn)
            if not ok2 then continue end
            local hasPoint = false
            for _, v in pairs(ups) do if v == Point then hasPoint = true; break end end
            if not hasPoint then continue end
            for _, v in pairs(ups) do
                if type(v) ~= "function" then continue end
                local ok3, inner = pcall(getupvalues, v)
                if not ok3 then continue end
                local hasGui, hasRemote = false, false
                for _, iv in pairs(inner) do
                    if typeof(iv) == "Instance" then
                        if iv:IsA("GuiObject") then hasGui = true end
                        if iv:IsA("RemoteFunction") or iv:IsA("RemoteEvent") then hasRemote = true end
                    end
                end
                if hasGui and hasRemote then return v end
            end
        end
        return nil
    end
    registerHitFn = scanHit()

    local VIM = game:GetService("VirtualInputManager")
    local hitDebounce = false
    local function doHit()
        if hitDebounce then return end
        hitDebounce = true
        task.delay(CFG.HIT_GAP, function() hitDebounce = false end)

        if registerHitFn then
            local ok, err = pcall(registerHitFn)
            if ok then return end
            registerHitFn = scanHit()
            if registerHitFn then pcall(registerHitFn); return end
        end

        local abs  = Point.AbsolutePosition
        local sz   = Point.AbsoluteSize
        local px   = math.floor(abs.X + sz.X * 0.5)
        local py   = math.floor(abs.Y + sz.Y * 0.5)
        pcall(function()
            VIM:SendMouseButtonEvent(px, py, 0, true,  game, 1)
            VIM:SendMouseButtonEvent(px, py, 0, false, game, 1)
        end)
    end

    -- Fire MinigameOpened if possible
    local px = findPickaxe()
    if px and sessionToken then
        local ev = px:FindFirstChild("MinigameOpened")
        if ev then task.spawn(function() pcall(function() ev:FireServer(sessionToken) end) end) end
    end

    log("hooked UI:", gui.Name)

    local preHandled = false
    local counted    = false
    local conn, roundConn

    conn = RunService.Heartbeat:Connect(function()
        if not running then
            conn:Disconnect()
            if roundConn then roundConn:Disconnect() end
            busy = false
            return
        end
        if not gui.Parent then
            conn:Disconnect()
            if roundConn then roundConn:Disconnect() end
            return
        end

        -- Phase 1: PreMining — drag button to target
        if PreHolder.Visible and DragDet.Enabled then
            status = "PreMining"
            if not preHandled then
                preHandled = true
                task.spawn(function()
                    DragBtn.Position = UDim2.new(
                        TargetFrm.Position.X.Scale, TargetFrm.Position.X.Offset,
                        TargetFrm.Position.Y.Scale, TargetFrm.Position.Y.Offset
                    )
                    RunService.Heartbeat:Wait()
                    pcall(firesignal, DragDet.DragStart)
                    task.wait(0.02)
                    pcall(firesignal, DragDet.DragContinue)
                    repeat task.wait()
                    until not gui.Parent or MineHolder.Visible or not PreHolder.Visible
                    preHandled = false
                end)
            end

        -- Phase 2: Minigame — hit the zone
        elseif MineHolder.Visible then
            status = "Mining ⛏️"

            -- Hit detection (result counted via MineResult RemoteEvent in hookToken)
            local marker = Point.Position.X.Scale
            local center = Bar.Position.X.Scale
            local half   = Bar.Size.X.Scale / 2
            local safe   = half * CFG.SAFE_ZONE_PCT
            if marker >= center - safe and marker <= center + safe then
                doHit()
            end
        end
    end)

    -- Refresh multipliers each round
    roundConn = gui:GetAttributeChangedSignal("CurrentRound"):Connect(function()
        local p2 = findPickaxe()
        if p2 and sessionToken then
            local rf = p2:FindFirstChild("RefreshMultipliers")
            if rf then pcall(function() rf:FireServer(sessionToken) end) end
        end
    end)

    -- On GUI close
    gui.Destroying:Connect(function()
        conn:Disconnect()
        if roundConn then roundConn:Disconnect() end
        task.wait(0.3)
        busy = false
        counted = false
        status = "Idle"
        log("session done")
    end)
end

-- Watcher: hook mining GUI as soon as it appears
AddConn(PlayerGui.ChildAdded:Connect(function(child)
    RunService.Heartbeat:Wait()
    if child:FindFirstChild("PreMiningHolder") then
        busy = true
        hookMiningUI(child)
    end
end))
for _, g in ipairs(PlayerGui:GetChildren()) do
    if g:FindFirstChild("PreMiningHolder") then
        busy = true
        hookMiningUI(g)
    end
end

-- ── TRIGGER ORE ───────────────────────────────────────────────────────────────
-- Walk character close to stone, then invoke Mine remote
local function triggerOre(stone, stonePos)
    local pickaxe = findPickaxe()
    if not pickaxe then log("no pickaxe"); busy = false; return end

    -- Equip only if not already in character hands
    local char = LocalPlayer.Character
    local wasInBackpack = pickaxe.Parent ~= char
    equip(pickaxe)
    -- Wait for server to register the tool as equipped
    if wasInBackpack then
        task.wait(0.5)
    end

    -- Re-grab after equip (in case reference changed)
    pickaxe = findPickaxe()
    if not pickaxe then log("pickaxe lost after equip"); busy = false; return end

    local mineRemote = pickaxe:FindFirstChild("Mine")
    if not mineRemote then log("Mine remote missing"); busy = false; return end
    if not sessionToken then
        log("no token — forcing unequip/equip refresh")
        ensureToken()
        local tw = os.clock() + 2.5
        while not sessionToken and os.clock() < tw do task.wait(0.15) end
        if not sessionToken then
            log("token timeout")
            busy = false
            return
        end
    end

    -- Walk close to the stone first (server needs proximity)
    char = LocalPlayer.Character
    local hrp = char and char:FindFirstChild("HumanoidRootPart")
    local hum = char and char:FindFirstChildOfClass("Humanoid")
    if hrp and hum and stonePos then
        local dist = (hrp.Position - stonePos).Magnitude
        if dist > 10 then
            hum:MoveTo(stonePos)
            local t = os.clock() + 6
            while os.clock() < t do
                task.wait(0.1)
                if not running then busy = false; return end
                if (hrp.Position - stonePos).Magnitude < 10 then break end
            end
        end
    end

    local token = sessionToken
    log("invoking Mine with token:", tostring(token))
    task.spawn(function()
        local ok, res = pcall(function() return mineRemote:InvokeServer(token) end)
        log("Mine invoke result:", ok, tostring(res))
        if not ok then
            busy = false
        end
    end)

    -- Watchdog: unlock busy if mining UI never opens in time
    task.delay(CFG.WATCHDOG_TIME, function()
        if not busy then return end
        local hasUI = false
        for _, g in ipairs(PlayerGui:GetChildren()) do
            if g:FindFirstChild("PreMiningHolder") then hasUI = true; break end
        end
        if not hasUI then
            log("watchdog unlock — no UI appeared")
            busy = false
        end
    end)
end

-- ── MAIN LOOP ─────────────────────────────────────────────────────────────────
local function mainLoop()
    while running do
        task.wait(CFG.LOOP_DELAY)
        if not running then break end
        if pausedForSell then
            status = "💰 Selling Ores..."
            continue
        end
        if busy then status = "Mining ⛏️"; continue end

        local char = LocalPlayer.Character
        if not char or not char:FindFirstChild("HumanoidRootPart") then
            status = "No Character"
            continue
        end

        local pickaxe = findPickaxe()
        if not pickaxe then
            status = "No Pickaxe"
            local p = findPickaxe()
            if p then equip(p); task.wait(0.5) end
            continue
        end

        -- Ensure token requested in background (non-blocking for walk)
        if not sessionToken then
            ensureToken()
        end

        -- 1. Look for ore inside SEARCH_RADIUS to trigger
        local stone, dist, pos = findOre(CFG.SEARCH_RADIUS)
        if stone and pos then
            if not sessionToken then
                status = "Equipping Pickaxe..."
                equip(pickaxe)
                task.wait(0.3)
                continue
            end
            stopWalk()
            status = string.format("Found Ore! (%.0f studs)", dist)
            busy   = true
            triggerOre(stone, pos)
            continue
        end

        -- 2. No close ore → auto walk to distant ore
        if CFG.AUTO_WALK then
            if not walking then
                local wstone, wdist, wpos = findOre(CFG.WALK_RADIUS)
                if wpos then
                    status = string.format("🚶 Walking (%.0f studs)", wdist)
                    startWalk(wpos)
                else
                    status = "🔍 No Ores Found"
                end
            else
                status = "🚶 Walking..."
            end
        else
            status = "No Ore Nearby"
            if walking then stopWalk() end
        end
    end
    status = "Idle"
    stopWalk()
end

local function pauseForSell()
    pausedForSell = true
    stopWalk()
end

local function resumeAfterSell()
    pausedForSell = false
    status = "Idle"
    if running and CFG.AUTO_WALK then
        task.wait(0.5)
        local wstone, wdist, wpos = findOre(CFG.WALK_RADIUS)
        if wpos then
            status = string.format("🚶 Returning to Ore (%.0f studs)", wdist)
            startWalk(wpos)
        end
    end
end

-- ── START / STOP ──────────────────────────────────────────────────────────────
local miningToggleRef = nil

local function startMining()
    if running then return end
    running = true
    ensureToken()
    if mainThread then task.cancel(mainThread) end
    mainThread = task.spawn(mainLoop)
    DX8:Notify("⛏️ Mining", "Auto Mining dimulai!", 2)
end

local function stopMining()
    running = false
    busy    = false
    stopWalk()
    if mainThread then task.cancel(mainThread); mainThread = nil end
    status = "Idle"
    DX8:Notify("⛏️ Mining", "Auto Mining dihentikan.", 2)
end

-- ── CLEANUP REGISTRATION ──────────────────────────────────────────────────────
local function CleanupScript()
    running = false
    busy    = false
    stopWalk()
    if mainThread  then task.cancel(mainThread);  mainThread  = nil end
    if walkThread  then task.cancel(walkThread);  walkThread  = nil end
    if _ringThread then task.cancel(_ringThread); _ringThread = nil end
    if _oreScanner then pcall(function() _oreScanner:Disconnect() end); _oreScanner = nil end
    if _jumpConn   then pcall(function() _jumpConn:Disconnect() end);   _jumpConn   = nil end
    killRing()
    for _, conn in ipairs(MiningConnections) do
        if conn then pcall(function() conn:Disconnect() end) end
    end
    MiningConnections = {}
    do
        local function clearTool(parent)
            if not parent then return end
            for _, v in ipairs(parent:GetChildren()) do
                if v:IsA("Tool") and (v:FindFirstChild("Mine") or v:GetAttribute("IsPickaxe")) then
                    pcall(function() v:SetAttribute("_DX8TokenHooked",  nil) end)
                    pcall(function() v:SetAttribute("_DX8ResultHooked", nil) end)
                end
            end
        end
        clearTool(LocalPlayer and LocalPlayer.Character)
        clearTool(LocalPlayer and LocalPlayer:FindFirstChild("Backpack"))
    end
    print("[Mining] Script cleaned up on unload/re-execute.")
end

shared.DX8_Mining_Cleanup = CleanupScript

local prevCleanup = shared.DX8_Cleanup
shared.DX8_Cleanup = function()
    CleanupScript()
    if prevCleanup then prevCleanup() end
end

-- ── UI ────────────────────────────────────────────────────────────────────────
local miningTab       = win:CreateTab("⛏️ Mining", "Automation", 1)
local controlSection  = miningTab:AddSection("Controls")
local targetSection   = miningTab:AddSection("Target")
local statusSection   = miningTab:AddSection("Status")
local settingsSection = miningTab:AddSection("Settings")

idvTargetMineProgressBar = targetSection:AddProgressBar({
    Title   = "Mining Target Progress",
    Default = 0,
    Status  = "Unlimited",
})

idvTargetMineManager = DX8:CreateTarget({
    Goal = 0,
    OnReach = function(current, goal)
        stopMining()
        if miningToggleRef then miningToggleRef:Set(false) end
        if idvTargetMineProgressBar then
            idvTargetMineProgressBar:SetStatus("🎉 GOAL REACHED!")
            idvTargetMineProgressBar:SetColor(Color3.fromRGB(80, 220, 120))
        end
        DX8:Notify("🎯 Target!", string.format("Target %d tambang tercapai!", goal), 5)
    end,
})

targetSection:AddSlider({
    Title    = "Target (0 = Unlimited)",
    Min = 0, Max = 500, Step = 5, Default = 0,
    Flag     = "IDV_TargetMine",
    Callback = function(val)
        idvTargetMineGoal = val
        idvTargetMineManager:SetGoal(val)
        if val <= 0 then
            idvTargetMineProgressBar:Reset()
            idvTargetMineProgressBar:SetStatus(tostring(totalMined) .. " mined")
            idvTargetMineProgressBar:SetColor(Color3.fromRGB(150, 211, 246))
        else
            local pct = math.clamp((totalMined / val) * 100, 0, 100)
            idvTargetMineProgressBar:SetPercent(pct, string.format("%d/%d", totalMined, val))
        end
    end,
})

targetSection:AddButton({
    Title    = "↺ Reset Counter",
    Callback = function()
        totalMined = 0
        idvTargetMineManager:Reset()
        idvTargetMineProgressBar:Reset()
        if idvTargetMineGoal > 0 then
            idvTargetMineProgressBar:SetStatus(string.format("0/%d", idvTargetMineGoal))
        else
            idvTargetMineProgressBar:SetStatus("0 mined")
        end
        DX8:Notify("Target", "Counter di-reset.", 2)
    end,
})

-- Controls
miningToggleRef = controlSection:AddToggle({
    Title    = "Auto Mining",
    Default  = false,
    Flag     = "AutoMining",
    Callback = function(state)
        if state then startMining() else stopMining() end
    end,
})

controlSection:AddButton({
    Title    = "🔧 Equip Pickaxe",
    Callback = function()
        local p = findPickaxe()
        if p then
            equip(p); task.wait(0.3); hookToken(p)
            DX8:Notify("Mining", "Pickaxe equipped & hooked!", 2)
        else
            DX8:Notify("Mining", "No pickaxe found!", 2)
        end
    end,
})

-- ── STATUS SECTION — 4 StatCard v2 cards in a 2×2 grid ───────────────────────
-- Create all 4 cards (they auto-parent to statusSection's contentFrame)
statTotal  = statusSection:AddStatCard({ Icon = "⛏️", Title = "Total",  Default = "0",  Color = _BLUE  })
statMined  = statusSection:AddStatCard({ Icon = "✓",   Title = "Mined",  Default = "0",  Color = _GREEN })
statFailed = statusSection:AddStatCard({ Icon = "✗",   Title = "Failed", Default = "0",  Color = _RED   })
statRate   = statusSection:AddStatCard({
    Icon   = "📊",
    Title  = "Rate",
    Default = "0%",
    Color  = _BLUE,
    Format = function(n) return string.format("%.1f%%", n) end,
})

-- Pull contentFrame reference from the first card's parent
local _cframe = statTotal:GetFrame().Parent

-- Build a 2×2 grid wrapper and reparent all 4 cards into it.
-- UIGridLayout overrides each card's own Size — Width/Height in AddStatCard
-- are irrelevant here; the cell dimensions below control the layout.
local _gridWrap = Instance.new("Frame")
_gridWrap.Name                 = "MiningStatGrid"
_gridWrap.Size                 = UDim2.new(1, -4, 0, 116)  -- 2 rows × 54px + 6px gap ≈ 114
_gridWrap.BackgroundTransparency = 1
_gridWrap.BorderSizePixel      = 0
_gridWrap.Parent               = _cframe

local _grid = Instance.new("UIGridLayout")
_grid.CellSize              = UDim2.new(0.5, -4, 0, 54)
_grid.CellPadding           = UDim2.new(0,   6,  0, 6)
_grid.FillDirection         = Enum.FillDirection.Horizontal
_grid.HorizontalAlignment   = Enum.HorizontalAlignment.Center
_grid.SortOrder             = Enum.SortOrder.LayoutOrder
_grid.Parent                = _gridWrap

local function _moveToGrid(comp, order)
    local f = comp:GetFrame()
    f.LayoutOrder = order
    f.Parent = _gridWrap
end
_moveToGrid(statTotal,  1)
_moveToGrid(statMined,  2)
_moveToGrid(statFailed, 3)
_moveToGrid(statRate,   4)

-- Status bar — hand-built since UIFactory / Tween aren't accessible here.
-- shared.DX8_Theme is the public ThemeManager surface exposed by DX8Lib.
local _TMGR = shared.DX8_Theme
local function _tc(t) return (_TMGR and _TMGR:Get(t)) or Color3.new(1, 1, 1) end

local _statusBar = Instance.new("Frame")
_statusBar.Name              = "MiningStatusBar"
_statusBar.Size              = UDim2.new(1, -4, 0, 22)
_statusBar.BackgroundColor3  = _tc("BgPanelDark")
_statusBar.BorderSizePixel   = 0
_statusBar.Parent            = _cframe
local _sc = Instance.new("UICorner"); _sc.CornerRadius = UDim.new(0, 5); _sc.Parent = _statusBar

statusBarLbl = Instance.new("TextLabel")
statusBarLbl.Size                 = UDim2.new(1, -10, 1, 0)
statusBarLbl.Position             = UDim2.new(0, 8, 0, 0)
statusBarLbl.BackgroundTransparency = 1
statusBarLbl.Text                 = "● Idle"
statusBarLbl.TextColor3           = _tc("TextDim")
statusBarLbl.Font                 = Enum.Font.GothamBold
statusBarLbl.TextSize             = 10
statusBarLbl.TextXAlignment       = Enum.TextXAlignment.Left
statusBarLbl.Parent               = _statusBar

-- Status polling — updates rate card + status bar text every 0.5s
task.spawn(function()
    local _IDLE_COLOR    = _tc("TextDim")
    local _RUNNING_COLOR = _tc("Accent")
    local _DOTS = { idle = "●", running = "◉" }
    while true do
        task.wait(0.5)
        local tot     = totalMined + totalFailed
        local rateNum = tot > 0 and (totalMined / tot * 100) or 0
        if statRate then statRate:Set(rateNum) end
        if statusBarLbl then
            local state   = running and "running" or "idle"
            local rateStr = string.format("%.1f%%", rateNum)
            statusBarLbl.Text       = (_DOTS[state] or "●") .. " " .. status .. "  |  " .. rateStr
            statusBarLbl.TextColor3 = (state == "running") and _RUNNING_COLOR or _IDLE_COLOR
        end
    end
end)

-- Settings
settingsSection:AddSlider({
    Title = "Search Radius (studs)", Min = 5, Max = 120, Step = 1,
    Default = CFG.SEARCH_RADIUS, Flag = "MineSearchR",
    Callback = function(v) CFG.SEARCH_RADIUS = v end,
})

settingsSection:AddSlider({
    Title = "Safe Zone %", Min = 1, Max = 100, Step = 1,
    Default = CFG.SAFE_ZONE_PCT * 100, Flag = "MineSafeZone",
    Callback = function(v) CFG.SAFE_ZONE_PCT = v / 100 end,
})

settingsSection:AddSlider({
    Title = "Loop Delay (s)", Min = 0.2, Max = 3, Step = 0.1,
    Default = CFG.LOOP_DELAY, Flag = "MineLoopDelay",
    Callback = function(v) CFG.LOOP_DELAY = v end,
})

settingsSection:AddToggle({
    Title = "Auto Walk", Default = CFG.AUTO_WALK, Flag = "MineAutoWalk",
    Callback = function(v)
        CFG.AUTO_WALK = v
        if not v then stopWalk() end
    end,
})

settingsSection:AddDropdown({
    Title = "Nav Mode", List = {"Smart", "Direct"}, Default = CFG.NAV_MODE, Flag = "MineNavMode",
    Callback = function(v) CFG.NAV_MODE = v end,
})

settingsSection:AddSlider({
    Title = "Walk Speed", Min = 16, Max = 100, Step = 2,
    Default = CFG.WALK_SPEED, Flag = "MineWalkSpeed",
    Callback = function(v) CFG.WALK_SPEED = v end,
})

settingsSection:AddSlider({
    Title = "Walk Radius (studs)", Min = 50, Max = 3000, Step = 50,
    Default = CFG.WALK_RADIUS, Flag = "MineWalkRadius",
    Callback = function(v) CFG.WALK_RADIUS = v end,
})

settingsSection:AddSlider({
    Title = "Ore Detect Interval (s)", Min = 0.05, Max = 1, Step = 0.05,
    Default = CFG.DETECT_INTERVAL, Flag = "MineDetectInterval",
    Callback = function(v) CFG.DETECT_INTERVAL = v end,
})

settingsSection:AddDropdown({
    Title   = "Hotspot Priority Mode",
    List    = {"Prioritize Hotspot", "Only Hotspot", "All Ores", "Only Normal"},
    Default = CFG.HOTSPOT_MODE,
    Flag    = "MineHotspotMode",
    Callback = function(v)
        CFG.HOTSPOT_MODE = v
        DX8:Notify("Mining", "Mode target batu: " .. v, 2)
    end,
})

-- Multi-select: ore tiers to KEEP (not sell when auto-sell triggers)
local ALL_ORE_TIERS = {
    "Ancient", "Mythic", "Legend", "Epic", "Rare", "Uncommon", "Common"
}
settingsSection:AddDropdown({
    Title       = "Keep Ore Tiers (Don't Sell)",
    List        = ALL_ORE_TIERS,
    Default     = {},
    Flag        = "MineKeepOres",
    MultiSelect = true,
    Callback    = function(v)
        -- v is a table of selected ore tiers to hold back
        CFG.KEEP_ORES = v
        if type(v) == "table" and next(v) then
            local names = table.concat(v, ", ")
            DX8:Notify("Sell Filter", "Tahan tier: " .. names, 3)
        else
            DX8:Notify("Sell Filter", "Jual semua tier (tidak ada yang ditahan)", 2)
        end
    end,
})

settingsSection:AddToggle({
    Title = "Show Radius Visual", Default = CFG.SHOW_RADIUS, Flag = "MineShowRadius",
    Callback = function(v)
        CFG.SHOW_RADIUS = v
        if not v then killRing() end
    end,
})

settingsSection:AddToggle({
    Title = "Show Path Trail", Default = false, Flag = "MineShowPathTrail",
    Callback = function(v)
        if _G.IDV_Pathfinding and _G.IDV_Pathfinding.SetShowPath then
            _G.IDV_Pathfinding.SetShowPath(v)
        end
    end,
})

settingsSection:AddToggle({
    Title = "Ore ESP / Chams", Default = false, Flag = "MineOreESP",
    Callback = function(v)
        if _G.IDV_ESP and _G.IDV_ESP.SetOreESP then
            _G.IDV_ESP.SetOreESP(v)
        end
    end,
})

controlSection:AddButton({
    Title = "💰 Walk & Sell Ores",
    Callback = function()
        if _G.IDV_AutoSell and _G.IDV_AutoSell.SellOres then
            local keepList = CFG.KEEP_ORES or {}
            local keepCount = 0
            for _ in pairs(keepList) do keepCount = keepCount + 1 end
            local msg = keepCount > 0
                and ("Menjual ore (tahan " .. keepCount .. " tipe)...")
                or  "Menjual semua ore..."
            DX8:Notify("Auto Sell", msg, 3)
            stopMining()
            _G.IDV_AutoSell.SellOres(keepList, function(success, serverMsg)
                if serverMsg and serverMsg ~= "" then
                    local title = success and "Auto Sell Success" or "Auto Sell"
                    DX8:Notify(title, serverMsg, 4)
                elseif success then
                    DX8:Notify("Auto Sell", "Sukses menjual ore di OreShop!", 3)
                else
                    DX8:Notify("Auto Sell", "Selesai di area OreShop.", 3)
                end
            end)
        end
    end,
})

-- ── AUTO SELL LOOP SYSTEM ─────────────────────────────────────────────────────
local function startAutoSellLoop()
    if autoSellThread then task.cancel(autoSellThread) end
    autoSellThread = task.spawn(function()
        while CFG.AUTO_SELL and running do
            task.wait(CFG.SELL_INTERVAL)
            if not CFG.AUTO_SELL or not running then break end
            if not busy and _G.IDV_AutoSell and _G.IDV_AutoSell.SellOres then
                DX8:Notify("Auto Sell Loop", "Memulai auto sell interval...", 3)
                _G.IDV_AutoSell.SellOres(CFG.KEEP_ORES or {}, function(success, serverMsg)
                    if serverMsg and serverMsg ~= "" then
                        local title = success and "Auto Sell Success" or "Auto Sell"
                        DX8:Notify(title, serverMsg, 4)
                    end
                end)
            end
        end
    end)
end

settingsSection:AddToggle({
    Title = "Auto Sell Loop", Default = CFG.AUTO_SELL, Flag = "MineAutoSellLoop",
    Callback = function(v)
        CFG.AUTO_SELL = v
        if v then
            DX8:Notify("Auto Sell Loop", "Auto sell interval diaktifkan (" .. CFG.SELL_INTERVAL .. "s)", 3)
            startAutoSellLoop()
        else
            if autoSellThread then task.cancel(autoSellThread); autoSellThread = nil end
            DX8:Notify("Auto Sell Loop", "Auto sell interval dimatikan.", 2)
        end
    end,
})

settingsSection:AddSlider({
    Title = "Sell Interval (s)", Min = 30, Max = 600, Step = 30,
    Default = CFG.SELL_INTERVAL, Flag = "MineSellInterval",
    Callback = function(v)
        CFG.SELL_INTERVAL = v
        if CFG.AUTO_SELL then startAutoSellLoop() end
    end,
})

settingsSection:AddToggle({
    Title = "Debug Logging", Default = CFG.DEBUG, Flag = "MineDebug",
    Callback = function(v) CFG.DEBUG = v end,
})

settingsSection:AddButton({
    Title = "🔄 Reset Stats",
    Callback = function()
        totalMined  = 0
        totalFailed = 0
        if statTotal  then statTotal:Set("0") end
        if statMined  then statMined:Set("0") end
        if statFailed then statFailed:Set("0") end
        if statRate   then statRate:Set(0) end
        DX8:Notify("Mining", "Stats di-reset!", 2)
    end,
})

-- ── GLOBAL API ────────────────────────────────────────────────────────────────
_G.Mining = {
    Start            = startMining,
    Stop             = stopMining,
    PauseForSell     = pauseForSell,
    ResumeAfterSell  = resumeAfterSell,
    ToggleRef        = miningToggleRef
}

log("IDV_mining v4 loaded — toggle ON to begin")
end)
if not _IDV_mining_ok then
    warn("[IDV] IDV_mining ERROR: " .. tostring(_IDV_mining_err))
else
    print("[IDV] IDV_mining loaded OK")
end
-- ════════════════════════════════════════════════════════════
--  IDV_fishing
-- ════════════════════════════════════════════════════════════
print("[IDV] Loading IDV_fishing...")
local _IDV_fishing_ok, _IDV_fishing_err = pcall(function()
local DX8 = _G.DX8_Library
local win = _G.DX8_MainWindow
-- ============================================================
--  DX8_Fishing.lua
--  Module Otomatisasi Pancing
--  [FINAL - Ready to Use]
-- ============================================================

-- ============================================================
-- DX8 injected by merged loader
-- SERVICES
-- ============================================================
local Players             = game:GetService("Players")
local ReplicatedStorage   = game:GetService("ReplicatedStorage")
local RunService          = game:GetService("RunService")
local VirtualInputManager = game:GetService("VirtualInputManager")
local LocalPlayer         = Players.LocalPlayer
local PlayerGui           = LocalPlayer:WaitForChild("PlayerGui")

-- ============================================================
-- CLEANUP PREVIOUS SCRIPT
-- ============================================================
if shared.DX8_Fishing_Cleanup then
    pcall(shared.DX8_Fishing_Cleanup)
end

pcall(function()
    local folders = {workspace, workspace:FindFirstChild("Temp")}
    for _, parent in ipairs(folders) do
        if parent then
            for _, child in ipairs(parent:GetChildren()) do
                if string.sub(child.Name, 1, 11) == "DX8_Hotspot" then
                    child:Destroy()
                end
            end
        end
    end
    local fz = (getFishingZone and getFishingZone())
        or (workspace:FindFirstChild("Main") and workspace.Main:FindFirstChild("FishingZone"))
    if fz then
        for _, part in ipairs(fz:GetChildren()) do
            for _, child in ipairs(part:GetChildren()) do
                if string.sub(child.Name, 1, 11) == "DX8_Hotspot" then
                    child:Destroy()
                end
            end
        end
    end
end)

-- ============================================================
-- SCRIPT ID
-- ============================================================
local fishingScriptID = os.clock()
shared.DX8_Fishing_CurrentID = fishingScriptID

-- ============================================================
-- FISHING STATE
-- ============================================================
local isBotRunning        = false
local isRodDetached       = true
local isCharacterMoving   = false
local isScriptLoaded      = true
local isMinigameActive    = false
local castWhileWalking    = false

local currentStage    = "Idle"
local totalFishCaught = 0
local timeoutCount    = 0

local timeoutPerStage = {
    ["Verify Cast"]    = 0,
    ["Waiting Pull"]   = 0,
    ["Post Pull Wait"] = 0,
    ["Catch"]          = 0,
}

local activeRod          = nil
local castToken          = nil
local rodConnections     = {}
local FishingConnections = {}
local isFishingLoopRunning = false

local isLegitFishingRunning   = false
local legitStatusPancing       = "Idle"
local legitWaktuCastTerakhir   = 0
local LEGIT_TIMEOUT_CAST       = 8.0
local legitBaitHasLanded       = false
local legitBaitLandedConn      = nil
local legitCancelConn          = nil

local Config = {
    CAST_HOLD_DURATION    = 1,
    POST_PULL_DELAY       = 1.0,
    PRE_END_DELAY         = 0.0,
    POST_END_DELAY        = 0.1,
    PRE_CAST_DELAY        = 0.1,
    VERIFY_CAST_TIMEOUT   = 10.0,
    WAITING_PULL_TIMEOUT  = 50.0,
    POST_PULL_TIMEOUT     = 5.0,
    -- Click speed (seconds between clicks during minigame).
    -- Controlled by the "Click Speed (CPS)" slider below.
    CLICK_INTERVAL        = 0.067,  -- default: ~15 CPS
}

local MINIGAME = {
    DECAY_RATE      = 0.132,
    GAIN_PASSIVE    = 0.055,
    CLICK_BOOST     = 0.068,
    WRONG_CLICK     = 0.33,
    STATE_MIN       = 1.8,
    STATE_MAX       = 3.6,
    START_FILL      = 0.45,
    WIN_THRESHOLD   = 0.99,
    LOSE_THRESHOLD  = 0.01,
    PRETAP_COUNT_MIN = 2,
    PRETAP_COUNT_MAX = 4,
}

local autoFishingToggleRef = nil
local legitFishingToggleRef = nil

-- Forward-declared stat cards (assigned in UI section)
local statFishCaught  = nil
local statFishRate    = nil
local statFishSession = nil

local function AddFishingConnection(conn)
    table.insert(FishingConnections, conn)
end

-- ============================================================
-- HOTSPOT MARKER SYSTEM
-- ============================================================
local _hotspotMarkers   = {}
local hotspotLockEnabled = false
local lastHotspotResult  = "—"
local hotspotStatusLabel = nil
local hotspotDisplayMode = "all_active"

local function clearHotspotMarkers()
    for _, marker in pairs(_hotspotMarkers) do
        pcall(function() marker:Destroy() end)
    end
    _hotspotMarkers = {}
    for _, child in ipairs(workspace:GetChildren()) do
        if string.sub(child.Name, 1, 11) == "DX8_Hotspot" then
            pcall(function() child:Destroy() end)
        end
    end
    local main = workspace:FindFirstChild("Main")
    local fz   = main and main:FindFirstChild("FishingZone")
    if fz then
        for _, part in ipairs(fz:GetChildren()) do
            for _, child in ipairs(part:GetChildren()) do
                if string.sub(child.Name, 1, 11) == "DX8_Hotspot" then
                    pcall(function() child:Destroy() end)
                end
            end
        end
    end
end

local function isHotspotActive(part)
    local att     = part:FindFirstChildOfClass("Attachment")
    local emitter = att and att:FindFirstChild("GroundFlasg")
    return emitter and emitter.Enabled == true
end

local function createPoolMarker(position, name, color, alpha, labelText, size)
    color = color or Color3.fromRGB(0, 220, 255)
    alpha = alpha or 0.92
    size  = size  or 60

    local pool = Instance.new("Part")
    pool.Name         = "DX8_Hotspot_" .. tostring(name)
    pool.Size         = Vector3.new(size, 0.05, size)
    pool.CFrame       = CFrame.new(position.X, 16.31, position.Z)
    pool.Anchored     = true
    pool.CanCollide   = false
    pool.Transparency = 1
    pool.CastShadow   = false
    pool.Parent       = workspace

    local decal = Instance.new("Decal")
    decal.Name        = "GlowDecal"
    decal.Texture     = "rbxassetid://15413222872"
    decal.Face        = Enum.NormalId.Top
    decal.Color3      = color
    decal.Transparency = alpha
    decal.Parent      = pool

    local surfGui = Instance.new("SurfaceGui")
    surfGui.Name        = "DX8_RingGui"
    surfGui.Face        = Enum.NormalId.Top
    surfGui.SizingMode  = Enum.SurfaceGuiSizingMode.PixelsPerStud
    surfGui.PixelsPerStud = 8
    surfGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
    surfGui.Parent      = pool

    local ringFrame = Instance.new("Frame")
    ringFrame.Name                  = "Ring"
    ringFrame.Size                  = UDim2.new(1, -2, 1, -2)
    ringFrame.Position              = UDim2.new(0, 1, 0, 1)
    ringFrame.BackgroundTransparency = 1
    ringFrame.BorderSizePixel       = 0
    ringFrame.Parent                = surfGui

    local corner = Instance.new("UICorner")
    corner.CornerRadius = UDim.new(0.5, 0)
    corner.Parent       = ringFrame

    local stroke = Instance.new("UIStroke")
    stroke.Thickness        = 2.5
    stroke.Color            = color
    stroke.Transparency     = 0.15
    stroke.ApplyStrokeMode  = Enum.ApplyStrokeMode.Border
    stroke.Parent           = ringFrame

    local bb = Instance.new("BillboardGui")
    bb.Size         = UDim2.new(0, 150, 0, 28)
    bb.StudsOffset  = Vector3.new(0, 5, 0)
    bb.AlwaysOnTop  = true
    bb.Parent       = pool

    local lbl = Instance.new("TextLabel")
    lbl.Size                    = UDim2.new(1, 0, 1, 0)
    lbl.BackgroundTransparency  = 1
    lbl.Text                    = labelText or ("🎣 " .. tostring(name))
    lbl.TextColor3              = color
    lbl.Font                    = Enum.Font.GothamBold
    lbl.TextSize                = 13
    lbl.TextStrokeColor3        = Color3.new(0, 0, 0)
    lbl.TextStrokeTransparency  = 0.4
    lbl.Parent                  = bb

    table.insert(_hotspotMarkers, pool)
    return pool
end

local function getFishingZone()
    if _G.IDV_Map and _G.IDV_Map.GetFishingZone then
        local fz = _G.IDV_Map.GetFishingZone()
        if fz then return fz end
    end
    local main = workspace:FindFirstChild("Main")
    if main and main:FindFirstChild("FishingZone") then
        return main.FishingZone
    end
    local rsMain = ReplicatedStorage:FindFirstChild("Main")
    return rsMain and rsMain:FindFirstChild("FishingZone")
end

local function getHotspots()
    local hotspots = {}
    local fz = getFishingZone()
    if not fz then return hotspots end
    for idx, part in ipairs(fz:GetChildren()) do
        if part:IsA("BasePart") then
            table.insert(hotspots, {
                position = part.Position,
                part     = part,
                index    = idx,
                isActive = isHotspotActive(part)
            })
        end
    end
    return hotspots
end

local function getClosestHotspot(fromPos)
    local hotspots = getHotspots()
    local closest, minDist = nil, math.huge
    for _, data in ipairs(hotspots) do
        if data.isActive then
            local d = (fromPos - data.position).Magnitude
            if d < minDist then minDist = d; closest = data end
        end
    end
    if not closest then
        for _, data in ipairs(hotspots) do
            local d = (fromPos - data.position).Magnitude
            if d < minDist then minDist = d; closest = data end
        end
    end
    return closest, minDist
end

local function showAllActiveMarkers()
    clearHotspotMarkers()
    local hotspots  = getHotspots()
    local char      = LocalPlayer.Character
    local root      = char and char:FindFirstChild("HumanoidRootPart")
    local playerPos = root and root.Position or Vector3.new(0, 0, 0)
    local closestActive = getClosestHotspot(playerPos)

    local count = 0
    for _, data in ipairs(hotspots) do
        if data.isActive then
            count = count + 1
            local dist      = (playerPos - data.position).Magnitude
            local isNearest = (closestActive and closestActive.index == data.index)
            local col       = isNearest and Color3.fromRGB(255, 200, 0) or Color3.fromRGB(0, 220, 255)
            local lbl       = isNearest
                and string.format("⭐ Active Hotspot %d (%.0f studs)", data.index, dist)
                or  string.format("🎣 Active Hotspot %d", data.index)
            createPoolMarker(data.position, "Zone_" .. data.index, col, 0.92, lbl, 60)
        end
    end
    return count
end

local function showNearestMarker()
    clearHotspotMarkers()
    local char = LocalPlayer.Character
    local root = char and char:FindFirstChild("HumanoidRootPart")
    if not root then return 0 end
    local closest, dist = getClosestHotspot(root.Position)
    if not closest then return 0 end
    local lbl = string.format("⭐ Nearest Hotspot (%.0f studs)", dist)
    createPoolMarker(closest.position, "Nearest", Color3.fromRGB(255, 200, 0), 0.92, lbl, 60)
    return 1
end

local function showAllExistMarkers()
    clearHotspotMarkers()
    local hotspots  = getHotspots()
    local char      = LocalPlayer.Character
    local root      = char and char:FindFirstChild("HumanoidRootPart")
    local playerPos = root and root.Position or Vector3.new(0, 0, 0)

    for _, data in ipairs(hotspots) do
        local col, alpha, size, lbl
        if data.isActive then
            col   = Color3.fromRGB(0, 220, 255)
            alpha = 0.92
            size  = 60
            lbl   = string.format("🎣 Active Zone %d", data.index)
        else
            col   = Color3.fromRGB(130, 130, 130)
            alpha = 0.96
            size  = 25
            lbl   = string.format("○ Zone %d (Inactive)", data.index)
        end
        createPoolMarker(data.position, "Exist_" .. data.index, col, alpha, lbl, size)
    end
    return #hotspots
end

local function updateHotspotMarkers()
    if hotspotDisplayMode == "nearest" then
        return showNearestMarker()
    elseif hotspotDisplayMode == "all_exist" then
        return showAllExistMarkers()
    else
        return showAllActiveMarkers()
    end
end

local _lastMarkerRedrawTime = 0
local _markerRedrawConn = RunService.Heartbeat:Connect(function()
    if not isScriptLoaded then return end
    if not hotspotLockEnabled then return end
    local now = tick()
    if (now - _lastMarkerRedrawTime) < 5 then return end
    _lastMarkerRedrawTime = now
    local alive    = 0
    local expected = #_hotspotMarkers
    for _, marker in ipairs(_hotspotMarkers) do
        if marker and marker.Parent then alive = alive + 1 end
    end
    if expected == 0 or alive < math.ceil(expected * 0.5) then
        pcall(updateHotspotMarkers)
    end
end)
table.insert(FishingConnections, _markerRedrawConn)

local function alignToNearestHotspot(castPower)
    local char = LocalPlayer.Character
    local root = char and char:FindFirstChild("HumanoidRootPart")
    if not root then return end
    local closest, dist = getClosestHotspot(root.Position)
    if not closest then return end
    local flatDir = Vector3.new(
        closest.position.X - root.Position.X, 0,
        closest.position.Z - root.Position.Z
    )
    if flatDir.Magnitude > 0.1 then
        root.CFrame = CFrame.new(root.Position, root.Position + flatDir)
    end
    lastHotspotResult = string.format("Locked Active — %.0f studs", dist)
    if hotspotStatusLabel then
        pcall(function() hotspotStatusLabel:SetTitle("Status: " .. lastHotspotResult) end)
    end
end

local function snapBaitToHotspot(baitPart, multiplierTable)
    if not baitPart or not baitPart.Parent then return end
    local closest = getClosestHotspot(baitPart.Position)
    if not closest then return end
    pcall(function()
        baitPart.CFrame = CFrame.new(closest.position + Vector3.new(0, 0.5, 0))
    end)
    lastHotspotResult = "Snapped ✔"
    if hotspotStatusLabel then
        pcall(function() hotspotStatusLabel:SetTitle("Status: " .. lastHotspotResult) end)
    end
end

-- ============================================================
-- FISHING CORE FUNCTIONS
-- ============================================================
local lastClickX, lastClickY = 0, 0

local function pressMouse()
    local camera       = workspace.CurrentCamera
    local viewportSize = camera and camera.ViewportSize or Vector2.new(800, 600)
    lastClickX = math.random(math.round(viewportSize.X * 0.45), math.round(viewportSize.X * 0.55))
    lastClickY = math.random(math.round(viewportSize.Y * 0.45), math.round(viewportSize.Y * 0.55))
    VirtualInputManager:SendMouseButtonEvent(lastClickX, lastClickY, 0, true, game, 0)
end

local function releaseMouse()
    VirtualInputManager:SendMouseButtonEvent(lastClickX, lastClickY, 0, false, game, 0)
end

local function getCurrentRod()
    local char = LocalPlayer.Character
    if not char then return nil end
    for _, v in ipairs(char:GetChildren()) do
        if v:IsA("Tool") and string.find(string.lower(v.Name), "rod") then return v end
    end
    return nil
end

local function getRodFromBackpack()
    local backpack = LocalPlayer:FindFirstChildOfClass("Backpack")
    if not backpack then return nil end
    for _, tool in ipairs(backpack:GetChildren()) do
        if tool:IsA("Tool") and string.find(string.lower(tool.Name), "rod") then return tool end
    end
    return nil
end

local function unhookRod()
    activeRod = nil; castToken = nil; isMinigameActive = false
    for k, conn in pairs(rodConnections) do
        if typeof(conn) == "RBXScriptConnection" then conn:Disconnect() end
    end
    table.clear(rodConnections)
end

local timeoutReset, handleCatch, simulateMinigame

timeoutReset = function(stageName)
    timeoutCount = timeoutCount + 1
    if timeoutPerStage[stageName] ~= nil then
        timeoutPerStage[stageName] = timeoutPerStage[stageName] + 1
    end
    releaseMouse(); unhookRod()
    currentStage = "Idle"
    task.spawn(function()
        local char    = LocalPlayer.Character
        local current = getCurrentRod()
        if current and LocalPlayer:FindFirstChildOfClass("Backpack") then
            unhookRod(); current.Parent = LocalPlayer.Backpack
        end
        task.wait(0.3)
        local rod = getRodFromBackpack()
        if rod and char then rod.Parent = char end
    end)
end

local function hookRod(tool)
    if activeRod == tool then return end
    unhookRod(); activeRod = tool

    local toolReady      = tool:WaitForChild("ToolReady", 5)
    local startMinigame  = tool:WaitForChild("StartMinigame", 5)
    local baitLanded     = tool:WaitForChild("BaitLanded", 5)
    local fishingCanceled = tool:WaitForChild("FishingCanceled", 5)
    local minigameOpened = tool:FindFirstChild("MinigameOpened")

    if toolReady and toolReady:IsA("RemoteEvent") then
        rodConnections.ToolReady = toolReady.OnClientEvent:Connect(function(token) castToken = token end)
    end

    if startMinigame and startMinigame:IsA("RemoteEvent") then
        rodConnections.StartMinigame = startMinigame.OnClientEvent:Connect(function()
            if currentStage == "Waiting Pull" or currentStage == "Verify Cast" then
                currentStage = "Catching"; isMinigameActive = true; task.spawn(handleCatch)
            end
        end)
    end

    if minigameOpened and minigameOpened:IsA("RemoteEvent") then
        rodConnections.MinigameOpened = minigameOpened.OnClientEvent:Connect(function()
            if currentStage == "Waiting Pull" or currentStage == "Verify Cast" then
                currentStage = "Catching"; isMinigameActive = true; task.spawn(handleCatch)
            end
        end)
    end

    if baitLanded and baitLanded:IsA("RemoteEvent") then
        rodConnections.BaitLanded = baitLanded.OnClientEvent:Connect(function(baitPart, multiplierTable)
            if hotspotLockEnabled then
                task.spawn(function()
                    task.wait(0.05)
                    snapBaitToHotspot(baitPart, multiplierTable)
                end)
            end
            if currentStage == "Verify Cast" then
                currentStage = "Waiting Pull"
                local checkTime = os.clock()
                rodConnections.BaitTime = checkTime
                task.spawn(function()
                    task.wait(Config.WAITING_PULL_TIMEOUT)
                    if currentStage == "Waiting Pull"
                        and rodConnections.BaitTime == checkTime
                        and isBotRunning
                    then
                        timeoutReset("Waiting Pull")
                    end
                end)
            end
        end)
    end

    if fishingCanceled and fishingCanceled:IsA("RemoteEvent") then
        rodConnections.FishingCanceled = fishingCanceled.OnClientEvent:Connect(function()
            isMinigameActive = false; currentStage = "Idle"
        end)
    end
end

local function automateDragPreFishing(preHolder)
    local dragBtn    = preHolder:WaitForChild("DragButton", 3)
    local targetFrame = preHolder:WaitForChild("TargetFrame", 3)
    if not dragBtn or not targetFrame then return false end
    local dragDetector = dragBtn:WaitForChild("UIDragDetector", 3)
    if not dragDetector then return false end

    local start = os.clock()
    while preHolder.Visible and (os.clock() - start) < 6 do
        pcall(function()
            dragBtn.Position = targetFrame.Position
            task.wait(0.04)
            if firesignal then
                firesignal(dragDetector.DragStart)
                task.wait(0.02)
                firesignal(dragDetector.DragContinue)
                task.wait(0.02)
                firesignal(dragDetector.DragEnd)
            end
        end)
        task.wait(0.2)
    end
    return true
end

local function clickUIButton()
    local success = false
    for _, gui in ipairs(PlayerGui:GetChildren()) do
        if gui:IsA("ScreenGui") then
            local fishingHolder = gui:FindFirstChild("FishingHolder")
            if fishingHolder and fishingHolder.Visible then
                for _, child in ipairs(fishingHolder:GetDescendants()) do
                    if child:IsA("TextButton") or child:IsA("ImageButton") then
                        if child.Visible and child.Active then
                            pcall(function()
                                child:Fire("MouseButton1Down")
                                task.wait(0.01)
                                child:Fire("MouseButton1Up")
                                child:Fire("Activated")
                            end)
                            success = true
                            break
                        end
                    end
                end
            end
            local preHolder = gui:FindFirstChild("PreFishingHolder")
            if preHolder and preHolder.Visible then
                local dragBtn = preHolder:FindFirstChild("DragButton")
                if dragBtn and dragBtn.Visible then
                    pcall(function()
                        dragBtn:Fire("MouseButton1Down")
                        task.wait(0.01)
                        dragBtn:Fire("MouseButton1Up")
                    end)
                    success = true
                end
            end
        end
    end
    return success
end

local function safeVirtualClick()
    local camera   = workspace.CurrentCamera
    if not camera then return end
    local viewport = camera.ViewportSize
    local centerX  = viewport.X / 2
    local centerY  = viewport.Y / 2
    local offsetX  = math.random(-50, 50)
    local offsetY  = math.random(-20, 20)
    VirtualInputManager:SendMouseButtonEvent(centerX + offsetX, centerY + offsetY, 0, true, game, 0)
    task.wait(0.005)
    VirtualInputManager:SendMouseButtonEvent(centerX + offsetX, centerY + offsetY, 0, false, game, 0)
end

local function smartClick()
    if clickUIButton() then return true end
    safeVirtualClick()
    return false
end

simulateMinigame = function()
    local preDragDone = false
    task.spawn(function()
        local deadline   = os.clock() + 3
        local fishingGui = nil
        while os.clock() < deadline do
            for _, gui in ipairs(PlayerGui:GetChildren()) do
                if gui:FindFirstChild("PreFishingHolder") then
                    fishingGui = gui; break
                end
            end
            if fishingGui then break end
            task.wait(0.05)
        end

        if not fishingGui then
            task.wait(1.5)
            preDragDone = true
            return
        end

        local preHolder = fishingGui:FindFirstChild("PreFishingHolder")
        if preHolder then
            automateDragPreFishing(preHolder)
        end
        preDragDone = true
    end)

    local waitDeadline = os.clock() + 6
    while not preDragDone and os.clock() < waitDeadline do
        task.wait(0.05)
    end
    if not isBotRunning or not isScriptLoaded then return false end

    local currentFill   = MINIGAME.START_FILL
    local isGreenPhase  = true
    local stateStart    = os.clock()
    local stateDuration = math.random() * (MINIGAME.STATE_MAX - MINIGAME.STATE_MIN) + MINIGAME.STATE_MIN
    local lastTick      = os.clock()
    local lastClickTime = 0  -- tracks when we last fired a click, independent of loop rate

    local function getActualBarFill()
        for _, gui in ipairs(PlayerGui:GetChildren()) do
            local fishHolder = gui:FindFirstChild("FishingHolder")
            if fishHolder and fishHolder.Visible then
                local frame = fishHolder:FindFirstChild("FishingFrame")
                if frame then
                    local barContainer = frame:FindFirstChild("BarContainer", true)
                    if barContainer then
                        local bar = barContainer:FindFirstChild("Bar", true)
                        if bar then return bar.Size.X.Scale end
                    end
                    local bar = frame:FindFirstChild("Bar", true)
                    if bar then return bar.Size.X.Scale end
                end
            end
        end
        return nil
    end

    -- Physics loop always ticks at ~60fps regardless of click speed.
    -- Click timing is decoupled: fires when (now - lastClickTime) >= CLICK_INTERVAL.
    while isBotRunning and isScriptLoaded do
        local now = os.clock()
        local dt  = now - lastTick
        lastTick  = now

        -- Sync to real bar fill if readable
        local realFill = getActualBarFill()
        if realFill then currentFill = realFill end

        -- Phase flip
        if (now - stateStart) > stateDuration then
            isGreenPhase  = not isGreenPhase
            stateStart    = now
            stateDuration = math.random() * (MINIGAME.STATE_MAX - MINIGAME.STATE_MIN) + MINIGAME.STATE_MIN
        end

        -- Fill physics (dt-accurate, unaffected by CPS)
        if isGreenPhase then
            currentFill = currentFill - MINIGAME.DECAY_RATE * dt
        else
            currentFill = currentFill + MINIGAME.GAIN_PASSIVE * dt
        end
        currentFill = math.clamp(currentFill, 0, 1)

        -- Click gate: only fires when enough time has passed per CLICK_INTERVAL
        if isGreenPhase and currentFill < 0.92 and (now - lastClickTime) >= Config.CLICK_INTERVAL then
            lastClickTime = now

            pcall(function()
                VirtualInputManager:SendMouseButtonEvent(
                    lastClickX + math.random(-5, 5),
                    lastClickY + math.random(-5, 5),
                    0, true, game, 1
                )
                VirtualInputManager:SendMouseButtonEvent(
                    lastClickX + math.random(-5, 5),
                    lastClickY + math.random(-5, 5),
                    0, false, game, 1
                )
            end)

            if firesignal then
                for _, gui in ipairs(PlayerGui:GetChildren()) do
                    local fh = gui:FindFirstChild("FishingHolder")
                    if fh and fh.Visible then
                        for _, child in ipairs(fh:GetDescendants()) do
                            if (child:IsA("TextButton") or child:IsA("ImageButton")) and child.Visible then
                                pcall(function() firesignal(child.MouseButton1Down) end)
                                break
                            end
                        end
                        break
                    end
                end
            end

            currentFill = math.clamp(currentFill + MINIGAME.CLICK_BOOST, 0, 1)
        end

        -- Fixed 60fps loop tick — physics stays accurate at any CPS setting
        task.wait(0.016)

        if currentFill >= MINIGAME.WIN_THRESHOLD  then return true  end
        if currentFill <= MINIGAME.LOSE_THRESHOLD then return false end
    end

    return false
end

handleCatch = function()
    local catchTool = activeRod
    if not catchTool then currentStage = "Idle"; return end

    local won = simulateMinigame()
    if not isBotRunning or not isScriptLoaded or activeRod ~= catchTool then
        currentStage = "Idle"; return
    end

    local catchRemote = catchTool:FindFirstChild("Catch")
    if catchRemote and catchRemote:IsA("RemoteEvent") then
        pcall(function() catchRemote:FireServer(won) end)
        if won then
            totalFishCaught = totalFishCaught + 1
            if statFishCaught then
                statFishCaught:Set(totalFishCaught)
                statFishCaught:Flash(Color3.fromRGB(80, 220, 120))
            end
            if idvTargetFishManager then idvTargetFishManager:Set(totalFishCaught) end
            if idvTargetFishProgressBar then
                if idvTargetFishGoal > 0 then
                    local pct = math.clamp((totalFishCaught / idvTargetFishGoal) * 100, 0, 100)
                    idvTargetFishProgressBar:SetPercent(pct, string.format("%d/%d", totalFishCaught, idvTargetFishGoal))
                else
                    idvTargetFishProgressBar:SetStatus(tostring(totalFishCaught) .. " caught")
                end
            end
        end
    else
        timeoutReset("Catch"); return
    end

    task.wait(Config.POST_END_DELAY + (math.random(-30, 30) / 1000))

    pcall(function()
        for _, gui in pairs(PlayerGui:GetChildren()) do
            if gui:IsA("ScreenGui") and gui:FindFirstChild("FishingHolder", true) then
                gui:Destroy(); break
            end
        end
    end)

    currentStage = "Idle"
end

local function checkRodAndState()
    if not isScriptLoaded then return end
    local tool = getCurrentRod()
    if tool then isRodDetached = false; hookRod(tool) else isRodDetached = true; unhookRod() end
    local char = LocalPlayer.Character
    local hum  = char and char:FindFirstChildOfClass("Humanoid")
    if hum then isCharacterMoving = (hum.MoveDirection.Magnitude > 0.1) end
end

local function startFishingEngine()
    if isFishingLoopRunning then return end
    isFishingLoopRunning = true
    while isBotRunning and isScriptLoaded and shared.DX8_Fishing_CurrentID == fishingScriptID do
        if isRodDetached or (isCharacterMoving and not castWhileWalking) then
            task.wait(0.2); continue
        end
        if currentStage == "Idle" then
            if activeRod and castToken then
                task.wait(math.random(1000, 2000) / 1000)
                if not isBotRunning or not isScriptLoaded or not activeRod or not castToken then continue end
                currentStage = "Casting"
                local holdDuration = Config.CAST_HOLD_DURATION + (math.random(-50, 50) / 1000)
                local power        = holdDuration * 2
                local castTool     = activeRod
                local token        = castToken
                castToken          = nil
                task.wait(holdDuration)
                if not isBotRunning or not isScriptLoaded or activeRod ~= castTool then
                    currentStage = "Idle"; continue
                end
                currentStage = "Verify Cast"
                if hotspotLockEnabled then
                    alignToNearestHotspot(power)
                    task.wait(0.05)
                end
                task.spawn(function() pcall(function() castTool.Cast:InvokeServer(power, token) end) end)
                task.spawn(function()
                    task.wait(Config.VERIFY_CAST_TIMEOUT)
                    if currentStage == "Verify Cast" and isBotRunning then
                        timeoutReset("Verify Cast")
                    end
                end)
            else
                if activeRod and not castToken then
                    task.wait(0.5)
                    pcall(function()
                        local current = getCurrentRod()
                        if current and LocalPlayer:FindFirstChildOfClass("Backpack") then
                            current.Parent = LocalPlayer.Backpack; task.wait(0.2)
                            if LocalPlayer.Character then current.Parent = LocalPlayer.Character end
                        end
                    end)
                    task.wait(0.8)
                else
                    task.wait(0.5)
                end
            end
        end
        task.wait(0.1)
    end
    isFishingLoopRunning = false
end

local function LegitCariBobberAktif(character)
    if not character then return nil end
    local bobber = character:FindFirstChild("Bobber")
    if bobber then return bobber end
    for _, obj in ipairs(workspace:GetChildren()) do
        local objName = string.lower(obj.Name)
        if (string.find(objName, string.lower(LocalPlayer.Name)) and string.find(objName, "bobber"))
            or obj.Name == "Bobber"
        then
            return obj
        end
    end
    return nil
end

local function LegitDapatkanFishingGui()
    for _, gui in ipairs(PlayerGui:GetChildren()) do
        if gui:FindFirstChild("FishingHolder") and gui:FindFirstChild("PreFishingHolder") then
            return gui
        end
    end
    return nil
end

local function startLegitFishingEngine()
    task.wait(2)
    while isLegitFishingRunning and isScriptLoaded and shared.DX8_Fishing_CurrentID == fishingScriptID do
        local loopSuccess, loopError = pcall(function()
            local char = LocalPlayer.Character
            local hum  = char and char:FindFirstChildOfClass("Humanoid")

            if not char or not hum or hum.Health <= 0 then
                legitStatusPancing = "Idle"
                if legitBaitLandedConn then pcall(function() legitBaitLandedConn:Disconnect() end); legitBaitLandedConn = nil end
                if legitCancelConn    then pcall(function() legitCancelConn:Disconnect()    end); legitCancelConn    = nil end
                task.wait(0.5)
                return
            end

            local tool = char:FindFirstChildOfClass("Tool")

            if not tool and hum then
                local backpack = LocalPlayer:FindFirstChildOfClass("Backpack")
                if backpack then
                    tool = backpack:FindFirstChildOfClass("Tool")
                    if tool and string.find(string.lower(tool.Name), "rod") then
                        hum:EquipTool(tool)
                        task.wait(0.5)
                    end
                end
            end

            if tool and string.find(string.lower(tool.Name), "rod") then
                local fishingGui = LegitDapatkanFishingGui()
                local bobber     = LegitCariBobberAktif(char)
                if bobber then legitBaitHasLanded = true end

                if tool:FindFirstChild("BaitLanded") and not legitBaitLandedConn then
                    legitBaitLandedConn = tool.BaitLanded.OnClientEvent:Connect(function()
                        legitBaitHasLanded = true
                    end)
                end

                if tool:FindFirstChild("FishingCanceled") and not legitCancelConn then
                    legitCancelConn = tool.FishingCanceled.OnClientEvent:Connect(function(reason)
                        legitStatusPancing = "Idle"
                        legitBaitHasLanded = false
                        DX8:Notify("Fishing Engine", "Sesi pancing batal: " .. tostring(reason), 2)
                        task.wait(1.0)
                    end)
                end

                if not bobber and not fishingGui then
                    if legitStatusPancing == "Fishing" then
                        legitStatusPancing = "Cooldown"
                        task.wait(1.5)
                        legitStatusPancing = "Idle"
                    end

                    if legitStatusPancing == "Idle" then
                        legitStatusPancing        = "Casting"
                        legitWaktuCastTerakhir    = tick()

                        VirtualInputManager:SendMouseButtonEvent(10, 10, 0, false, game, 1)
                        task.wait(0.05)
                        legitBaitHasLanded = false

                        if hotspotLockEnabled then
                            alignToNearestHotspot(Config.CAST_HOLD_DURATION * 2)
                            task.wait(0.05)
                        end

                        tool:Activate()
                        task.wait(0.05)

                        VirtualInputManager:SendMouseButtonEvent(10, 10, 0, true, game, 1)
                        task.wait(Config.CAST_HOLD_DURATION)
                        VirtualInputManager:SendMouseButtonEvent(10, 10, 0, false, game, 1)
                        legitStatusPancing = "Waiting"

                    elseif legitStatusPancing == "Waiting" and not legitBaitHasLanded then
                        if (tick() - legitWaktuCastTerakhir) > LEGIT_TIMEOUT_CAST then
                            legitStatusPancing = "Idle"
                        end
                    end
                else
                    legitStatusPancing = "Fishing"
                    local preFishing    = fishingGui and fishingGui:FindFirstChild("PreFishingHolder")
                    local fishingHolder = fishingGui and fishingGui:FindFirstChild("FishingHolder")

                    if preFishing and preFishing.Visible then
                        if not preFishing:FindFirstChild("_DX8PreHook") then
                            local hookTag      = Instance.new("BoolValue")
                            hookTag.Name       = "_DX8PreHook"
                            hookTag.Parent     = preFishing
                            task.spawn(function() automateDragPreFishing(preFishing) end)
                        end
                    elseif fishingHolder then
                        local fishingFrame = fishingHolder:FindFirstChild("FishingFrame")
                        local infoLabel    = fishingFrame and fishingFrame:FindFirstChild("InfoLabel")

                        if infoLabel then
                            if infoLabel.Text == "Click/tap to raise the bar!" then
                                pcall(function()
                                    VirtualInputManager:SendMouseButtonEvent(500, 500, 0, true, game, 1)
                                    task.wait(0.01)
                                    VirtualInputManager:SendMouseButtonEvent(500, 500, 0, false, game, 1)
                                end)
                                task.wait(Config.CLICK_INTERVAL)
                            elseif infoLabel.Text == "Stop click/tap" then
                                task.wait(0.05)
                            else
                                task.wait(0.05)
                            end
                        else
                            task.wait(0.05)
                        end
                    else
                        task.wait(0.05)
                    end
                end
            else
                legitStatusPancing = "Idle"
                if legitBaitLandedConn then legitBaitLandedConn:Disconnect(); legitBaitLandedConn = nil end
                if legitCancelConn    then legitCancelConn:Disconnect();    legitCancelConn    = nil end
            end
        end)

        if not loopSuccess then
            warn("[DX8 Engine Warning] State error: " .. tostring(loopError))
            task.wait(1.0)
        end

        task.wait(0.005)
    end
end

local function UnloadFishingEngine()
    isScriptLoaded        = false
    isBotRunning          = false
    isLegitFishingRunning = false

    if legitBaitLandedConn then pcall(function() legitBaitLandedConn:Disconnect() end) end
    if legitCancelConn      then pcall(function() legitCancelConn:Disconnect() end) end

    local function _unhook()
        activeRod = nil; castToken = nil; isMinigameActive = false
        for _, conn in pairs(rodConnections) do
            if typeof(conn) == "RBXScriptConnection" then pcall(function() conn:Disconnect() end) end
        end
        table.clear(rodConnections)
    end
    pcall(_unhook)
    pcall(function() VirtualInputManager:SendMouseButtonEvent(0, 0, 0, false, game, 0) end)

    for _, conn in pairs(FishingConnections) do
        if conn then pcall(function() conn:Disconnect() end) end
    end
    FishingConnections = {}
    pcall(function() clearHotspotMarkers() end)
    if fishingTab then pcall(function() fishingTab:Destroy() end) end
    print("[DX8] Fishing engine cleaned.")
end

shared.DX8_Fishing_Cleanup = UnloadFishingEngine

local originalCleanup = shared.DX8_Cleanup
shared.DX8_Cleanup = function()
    UnloadFishingEngine()
    if originalCleanup then originalCleanup() end
end

-- ============================================================
-- FISHING UI
-- ============================================================
local fishingTab    = win:CreateTab("🐟 Fishing", "Automation")
local ctrlSection   = fishingTab:AddSection("Automation")
local targetSection = fishingTab:AddSection("Target Catch System")
local hotspotSection = fishingTab:AddSection("Hotspot")
local sellSection   = fishingTab:AddSection("Sell All Fish")
local utilSection   = fishingTab:AddSection("Anti-AFK")

-- ── FISH STATS ───────────────────────────────────────────────
local statsSection = fishingTab:AddSection("📊 Stats")
statFishCaught  = statsSection:AddStatCard({ Icon = "🐟", Title = "Caught",  Default = "0",      Color = Color3.fromRGB(80, 220, 120)  })
statFishRate    = statsSection:AddStatCard({ Icon = "⚡", Title = "Rate",    Default = "0/min",  Color = Color3.fromRGB(255, 200, 50)  })
statFishSession = statsSection:AddStatCard({ Icon = "⏱️", Title = "Session", Default = "0s",     Color = Color3.fromRGB(150, 211, 246) })
local fishStatusLabel = statsSection:AddLabel({ Title = "Status: Idle" })

local _fish_cframe = statFishCaught:GetFrame().Parent

local _fish_gw = Instance.new("Frame")
_fish_gw.Name                   = "FishStatGrid"
_fish_gw.Size                   = UDim2.new(1, -4, 0, 60)
_fish_gw.BackgroundTransparency = 1
_fish_gw.BorderSizePixel        = 0
_fish_gw.Parent                 = _fish_cframe

local _fish_gl = Instance.new("UIGridLayout")
_fish_gl.CellSize            = UDim2.new(0.333, -4, 0, 54)
_fish_gl.CellPadding         = UDim2.new(0, 5, 0, 0)
_fish_gl.FillDirection       = Enum.FillDirection.Horizontal
_fish_gl.HorizontalAlignment = Enum.HorizontalAlignment.Center
_fish_gl.SortOrder           = Enum.SortOrder.LayoutOrder
_fish_gl.Parent              = _fish_gw

local function _fish_mv(comp, order)
    local f = comp:GetFrame(); f.LayoutOrder = order; f.Parent = _fish_gw
end
_fish_mv(statFishCaught, 1); _fish_mv(statFishRate, 2); _fish_mv(statFishSession, 3)

local _fishSessionStart = os.clock()

task.spawn(function()
    while true do
        task.wait(0.5)
        local elapsed   = os.clock() - _fishSessionStart
        local mins      = math.floor(elapsed / 60)
        local secs      = math.floor(elapsed % 60)
        local rate      = elapsed > 0 and string.format("%.1f/min", (totalFishCaught / elapsed) * 60) or "0/min"
        local sessionStr = mins > 0 and string.format("%dm %ds", mins, secs) or string.format("%ds", secs)

        statFishCaught:Set(tostring(totalFishCaught))
        statFishRate:Set(rate)
        statFishSession:Set(sessionStr)
        fishStatusLabel:Set("Status: " .. (currentStage or "Idle"))
    end
end)

-- ── TARGET CATCH SYSTEM ──────────────────────────────────────
local idvTargetFishGoal        = 0
local idvTargetFishProgressBar = nil
local idvTargetFishManager     = nil

idvTargetFishProgressBar = targetSection:AddProgressBar({
    Title   = "Fish Catch Target Progress",
    Default = 0,
    Status  = "Unlimited",
})

idvTargetFishManager = DX8:CreateTarget({
    Goal = 0,
    OnReach = function(current, goal)
        isBotRunning = false
        isLegitFishingRunning = false
        if autoFishingToggleRef  then autoFishingToggleRef:Set(false)  end
        if legitFishingToggleRef then legitFishingToggleRef:Set(false) end
        unhookRod()
        releaseMouse()
        if idvTargetFishProgressBar then
            idvTargetFishProgressBar:SetStatus("GOAL REACHED! 🎉")
            idvTargetFishProgressBar:SetColor(Color3.fromRGB(80, 220, 120))
        end
        DX8:Notify("🎯 Target Reached!", string.format("Target %d ikan di IDV Fishing telah tercapai! Auto Fishing dihentikan.", goal), 5)
    end
})

targetSection:AddSlider({
    Title       = "Target Catch (0 = Unlimited)",
    Min         = 0,
    Max         = 500,
    Step        = 5,
    Default     = 0,
    Flag        = "IDV_TargetFish",
    Description = "Set target jumlah ikan. Auto Fishing otomatis mati jika tercapai.",
    Callback    = function(val)
        idvTargetFishGoal = val
        idvTargetFishManager:SetGoal(val)
        if val <= 0 then
            idvTargetFishProgressBar:Reset()
            idvTargetFishProgressBar:SetStatus("Unlimited")
            idvTargetFishProgressBar:SetColor(Color3.fromRGB(150, 211, 246))
        else
            local pct = math.clamp((totalFishCaught / val) * 100, 0, 100)
            idvTargetFishProgressBar:SetPercent(pct, string.format("%d/%d", totalFishCaught, val))
        end
    end
})

targetSection:AddButton({
    Title       = "↺ Reset Target Counter",
    Description = "Reset hitungan progress target pancing ke 0.",
    Callback    = function()
        totalFishCaught = 0
        idvTargetFishManager:Reset()
        idvTargetFishProgressBar:Reset()
        if idvTargetFishGoal > 0 then
            idvTargetFishProgressBar:SetStatus(string.format("0/%d", idvTargetFishGoal))
        else
            idvTargetFishProgressBar:SetStatus("Unlimited")
        end
        DX8:Notify("Target System", "Hitungan progress target pancing di-reset ke 0.", 2)
    end
})

-- ── AUTOMATION TOGGLES + CLICK SPEED ─────────────────────────
autoFishingToggleRef = ctrlSection:AddToggle({
    Title       = "Blatant (W.I.P)",
    Default     = false,
    Flag        = "BlatantFish",
    Description = "Instant catch bypass minigame pancing.",
    Tooltip     = "Menggunakan silent remote invoke. Sangat cepat tapi berisiko tinggi.",
    Callback    = function(state)
        if state and isLegitFishingRunning then
            isLegitFishingRunning = false; legitStatusPancing = "Idle"
            if legitFishingToggleRef then legitFishingToggleRef:Set(false) end
        end
        isBotRunning = state
        if state then
            currentStage = "Idle"
            task.spawn(function()
                local char    = LocalPlayer.Character
                local current = getCurrentRod()
                if current and LocalPlayer:FindFirstChildOfClass("Backpack") then
                    current.Parent = LocalPlayer.Backpack
                end
                task.wait(0.3)
                local rod = getRodFromBackpack()
                if rod and char then rod.Parent = char end
                task.wait(0.5)
                startFishingEngine()
            end)
        else
            unhookRod(); releaseMouse()
        end
    end
})

legitFishingToggleRef = ctrlSection:AddToggle({
    Title       = "Legit Fishing",
    Default     = false,
    Flag        = "LegitFish",
    Description = "Pancing otomatis dengan input mouse virtual.",
    Tooltip     = "Memainkan minigame secara legit dengan melacak koordinat bar pancing (sangat aman).",
    Callback    = function(state)
        if state and isBotRunning then
            isBotRunning = false; unhookRod(); releaseMouse()
            if autoFishingToggleRef then autoFishingToggleRef:Set(false) end
        end
        isLegitFishingRunning = state
        if state then task.spawn(startLegitFishingEngine) else legitStatusPancing = "Idle" end
    end
})

-- Click Speed slider — sets how fast the minigame gets clicked
ctrlSection:AddSlider({
    Title       = "Click Speed (CPS)",
    Min         = 1,
    Max         = 10,
    Step        = 1,
    Default     = 5,
    Flag        = "FishClickCPS",
    Description = "Kecepatan klik saat minigame pancing (clicks per second). Lebih tinggi = lebih agresif.",
    Tooltip     = "Default 1 CPS. Naikkan jika bar sering turun, turunkan untuk terlihat lebih legit.",
    Callback    = function(v)
        Config.CLICK_INTERVAL = 1 / v
    end
})

-- ── HOTSPOT ──────────────────────────────────────────────────
hotspotStatusLabel = hotspotSection:AddLabel({ Title = "Status: Nonaktif" })

hotspotSection:AddDropdown({
    Title       = "Mode Tampilan",
    Description = "Pilih jenis marker yang ditampilkan di dunia game.",
    Tooltip     = "All Active: semua zona + highlight nearest | Nearest Only: 1 zona terdekat | All Exist: peta semua zona (abu-abu).",
    Flag        = "HotspotDisplayMode",
    Default     = "Show All Active Hotspot",
    Options     = {
        "Show All Active Hotspot",
        "Show Nearest Hotspot",
        "All Hotspot Exist",
    },
    Callback    = function(selected)
        if selected == "Show All Active Hotspot" then
            hotspotDisplayMode = "all_active"
        elseif selected == "Show Nearest Hotspot" then
            hotspotDisplayMode = "nearest"
        elseif selected == "All Hotspot Exist" then
            hotspotDisplayMode = "all_exist"
        end
        if hotspotLockEnabled then
            local count = updateHotspotMarkers()
            lastHotspotResult = string.format("Mode: %s (%d zona)", selected, count)
            if hotspotStatusLabel then
                pcall(function() hotspotStatusLabel:SetTitle("Status: " .. lastHotspotResult) end)
            end
        end
    end,
})

hotspotSection:AddToggle({
    Title       = "Hotspot Lock",
    Default     = false,
    Flag        = "HotspotLock",
    Description = "Cast otomatis diarahkan ke zona ikan terbaik.",
    Tooltip     = "Saat aktif: karakter menghadap hotspot sebelum cast, umpan di-snap ke zona saat mendarat.",
    Callback    = function(state)
        hotspotLockEnabled = state
        if state then
            local count = updateHotspotMarkers()
            if count > 0 then
                DX8:Notify("Hotspot Lock", string.format("%d zona ditemukan & ditandai!", count), 3)
                lastHotspotResult = string.format("%d zona aktif", count)
            else
                DX8:Notify("Hotspot Lock", "Tidak ada zona ditemukan. Coba Refresh.", 3)
                lastHotspotResult = "Tidak ada zona"
            end
        else
            clearHotspotMarkers()
            lastHotspotResult = "Nonaktif"
        end
        if hotspotStatusLabel then
            pcall(function() hotspotStatusLabel:SetTitle("Status: " .. lastHotspotResult) end)
        end
    end,
})

hotspotSection:AddButton({
    Title       = "Refresh Markers",
    Description = "Scan ulang FishingZone dan perbarui marker sesuai mode aktif.",
    Callback    = function()
        local count = updateHotspotMarkers()
        lastHotspotResult = string.format("%d zona (%s)", count, hotspotDisplayMode)
        if hotspotStatusLabel then
            pcall(function() hotspotStatusLabel:SetTitle("Status: " .. lastHotspotResult) end)
        end
        DX8:Notify("Hotspot", string.format("%d zona ditemukan, marker diperbarui!", count), 2)
    end,
})

hotspotSection:AddButton({
    Title       = "Clear Markers",
    Description = "Hapus semua marker visual dari workspace.",
    Callback    = function()
        clearHotspotMarkers()
        lastHotspotResult = "Marker dihapus"
        if hotspotStatusLabel then
            pcall(function() hotspotStatusLabel:SetTitle("Status: Marker dihapus") end)
        end
        DX8:Notify("Hotspot", "Semua marker dihapus.", 2)
    end,
})

hotspotSection:AddToggle({
    Title    = "Fishing Hotspot ESP / Chams",
    Default  = false,
    Flag     = "FishingHotspotESP",
    Callback = function(v)
        if _G.IDV_ESP and _G.IDV_ESP.SetFishingESP then
            _G.IDV_ESP.SetFishingESP(v)
        end
    end
})

-- ── SELL ALL FISH ─────────────────────────────────────────────
local autoSellFishLoop     = false
local autoSellFishInterval = 180
local autoSellFishThread   = nil

local function startAutoSellFishLoop()
    if autoSellFishThread then task.cancel(autoSellFishThread) end
    autoSellFishThread = task.spawn(function()
        while autoSellFishLoop and isScriptLoaded do
            task.wait(autoSellFishInterval)
            if not autoSellFishLoop or not isScriptLoaded then break end
            if _G.IDV_AutoSell and _G.IDV_AutoSell.SellFish then
                DX8:Notify("Auto Sell Fish", "Memulai auto sell ikan interval...", 3)
                _G.IDV_AutoSell.SellFish(function(success, serverMsg)
                    if serverMsg and serverMsg ~= "" then
                        local title = success and "Auto Sell Fish Success" or "Auto Sell Fish"
                        DX8:Notify(title, serverMsg, 4)
                    end
                end)
            end
        end
    end)
end

sellSection:AddButton({
    Title       = "🚶 Walk & Sell All Fish (FishShop NPC)",
    Description = "Pathfind dan berjalan ke FishShop NPC untuk menjual semua ikan secara aman.",
    Callback    = function()
        DX8:Notify("Auto Sell", "Berjalan ke FishShop NPC...", 3)
        if _G.IDV_AutoSell and _G.IDV_AutoSell.SellFish then
            _G.IDV_AutoSell.SellFish(function(success, serverMsg)
                if serverMsg and serverMsg ~= "" then
                    local title = success and "Auto Sell Fish Success" or "Auto Sell Fish"
                    DX8:Notify(title, serverMsg, 4)
                elseif success then
                    DX8:Notify("Auto Sell", "Sukses menjual semua ikan di FishShop!", 3)
                else
                    DX8:Notify("Auto Sell", "Selesai di area FishShop.", 3)
                end
            end)
        end
    end
})

sellSection:AddToggle({
    Title       = "Auto Sell Fish Loop",
    Default     = false,
    Flag        = "FishAutoSellLoop",
    Description = "Otomatis berjalan dan menjual ikan ke FishShop secara berkala.",
    Callback    = function(v)
        autoSellFishLoop = v
        if v then
            DX8:Notify("Auto Sell Fish", "Auto sell ikan interval diaktifkan (" .. autoSellFishInterval .. "s)", 3)
            startAutoSellFishLoop()
        else
            if autoSellFishThread then task.cancel(autoSellFishThread); autoSellFishThread = nil end
            DX8:Notify("Auto Sell Fish", "Auto sell ikan interval dimatikan.", 2)
        end
    end
})

sellSection:AddSlider({
    Title       = "Sell Fish Interval (s)",
    Min         = 30,
    Max         = 600,
    Step        = 30,
    Default     = 180,
    Flag        = "FishSellInterval",
    Description = "Interval jeda waktu (detik) untuk menjual ikan.",
    Callback    = function(v)
        autoSellFishInterval = v
        if autoSellFishLoop then startAutoSellFishLoop() end
    end
})

-- ── SELL TP DELAY ─────────────────────────────────────────────
sellSection:AddSlider({
    Title       = "TP Delay",
    Min         = 0,
    Max         = 50,
    Step        = 1,
    Default     = 20,
    Flag        = "FishingTpDelay",
    Description = "Waktu tunggu return teleport (satuan 0.1 detik).",
    Tooltip     = "20 = 2.0 detik jeda pengaman.",
    Callback    = function(val)
        tpReturnStreamWait = val / 10
    end
})

-- ── UTIL (ANTI-AFK / ROD SHOP) ────────────────────────────────
local rodShopToggle = nil

rodShopToggle = utilSection:AddToggle({
    Title       = "Open Rod Shop",
    Default     = false,
    Flag        = "OpenRodShop",
    Description = "Buka UI toko pancing dari mana saja.",
    Tooltip     = "Sinkronisasi status toggle secara langsung dengan status UI game yang asli.",
    Callback    = function(state)
        local RodShop           = PlayerGui:FindFirstChild("RodShop")
        local RodShopController = RodShop and RodShop:FindFirstChild("RodShopUIController")
        if RodShopController then
            if state then
                local ShowFunction = RodShopController:FindFirstChild("ShowFunction")
                if ShowFunction and (ShowFunction:IsA("BindableFunction") or ShowFunction:IsA("RemoteFunction")) then
                    pcall(function() ShowFunction:Invoke(false) end)
                end
            else
                local HideFunction = RodShopController:FindFirstChild("HideFunction")
                if HideFunction then pcall(function() HideFunction:Invoke() end) end
            end
        else
            if state then
                DX8:Notify("Rod Shop Error", "UI Rod Shop belum siap atau tidak ditemukan!", 3)
                if rodShopToggle then rodShopToggle:Set(false) end
            end
        end
    end
})

task.spawn(function()
    local RodShop = PlayerGui:WaitForChild("RodShop", 15)
    if RodShop and RodShop:IsA("ScreenGui") then
        local function syncVisuals(isVisible)
            if rodShopToggle and rodShopToggle:Get() ~= isVisible then
                pcall(function() rodShopToggle:Set(isVisible) end)
            end
        end
        local guiConn = RodShop:GetPropertyChangedSignal("Enabled"):Connect(function()
            syncVisuals(RodShop.Enabled)
        end)
        table.insert(FishingConnections, guiConn)
        syncVisuals(RodShop.Enabled)
    end
end)

-- ============================================================
-- SAVE MANAGER
-- ============================================================
pcall(function()
    local ThemeManager = (DX8 and DX8.Theme) or nil
    local SaveManager  = nil
    local okSave, resSave = pcall(function() return loadstring(readfile("DX8/DX8Library/SaveManager.lua"))() end)
    if okSave and resSave then SaveManager = resSave end

    if ThemeManager and ThemeManager.Init then pcall(function() ThemeManager:Init(DX8) end) end

    if not SaveManager then
        warn("[DX8] SaveManager failed to load!")
        return
    end

    SaveManager:Init()

    if _G.DX8_Toggles then
        for name, obj in pairs(_G.DX8_Toggles) do SaveManager:BindToggle(name, obj) end
    end
    if _G.DX8_Sliders then
        for name, obj in pairs(_G.DX8_Sliders) do SaveManager:BindSlider(name, obj) end
    end
    if autoFishingToggleRef  then SaveManager:BindToggle("AutoFish",  autoFishingToggleRef)  end
    if legitFishingToggleRef then SaveManager:BindToggle("LegitFish", legitFishingToggleRef) end

    local configTab  = win:CreateTab("Settings", "Settings")
    local configSec  = configTab:AddSection("Save Manager")

    local configNameBox = configSec:AddTextBox({ Title = "Config Name", Placeholder = "e.g. default", Callback = function() end })

    local existingConfigs = SaveManager:GetConfigs()
    local configDrop = configSec:AddDropdown({
        Title    = "Load Config",
        List     = #existingConfigs > 0 and existingConfigs or {"(none)"},
        Default  = existingConfigs[1] or "(none)",
        Callback = function() end
    })

    configSec:AddButton({
        Title    = "💾 Save Config",
        Callback = function()
            local name = configNameBox:Get()
            if not name or name == "" then
                DX8:Notify("Save Manager", "Isi nama config dulu!", 3)
                return
            end
            local ok, msg = SaveManager:Save(name)
            if ok then
                DX8:Notify("Save Manager", "Config '" .. name .. "' berhasil disimpan! ✅", 3)
                local fresh = SaveManager:GetConfigs()
                if configDrop.Refresh then configDrop:Refresh(#fresh > 0 and fresh or {"(none)"}) end
            else
                DX8:Notify("Save Manager", "Gagal simpan: " .. tostring(msg), 4)
            end
        end
    })

    configSec:AddButton({
        Title    = "📂 Load Config",
        Callback = function()
            local name = configDrop:Get()
            if not name or name == "" or name == "(none)" then
                DX8:Notify("Save Manager", "Pilih config dulu dari dropdown!", 3)
                return
            end
            local ok, msg = SaveManager:Load(name)
            if ok then
                DX8:Notify("Save Manager", "Config '" .. name .. "' berhasil di-load! ✅", 3)
            else
                DX8:Notify("Save Manager", "Gagal load: " .. tostring(msg), 4)
            end
        end
    })

    configSec:AddButton({
        Title    = "🗑️ Delete Config",
        Callback = function()
            local name = configDrop:Get()
            if not name or name == "" or name == "(none)" then
                DX8:Notify("Save Manager", "Pilih config yang mau dihapus!", 3)
                return
            end
            local path = SaveManager.Folder .. "/" .. name .. ".json"
            if isfile and isfile(path) then
                pcall(delfile, path)
                DX8:Notify("Save Manager", "Config '" .. name .. "' dihapus!", 3)
                local fresh = SaveManager:GetConfigs()
                if configDrop.Refresh then configDrop:Refresh(#fresh > 0 and fresh or {"(none)"}) end
            else
                DX8:Notify("Save Manager", "File tidak ditemukan!", 3)
            end
        end
    })

    task.delay(1.5, function()
        local ok, _ = SaveManager:Load("default")
        if ok then DX8:Notify("Save Manager", "Auto-loaded config 'default'!", 2) end
    end)

    shared.DX8_SaveManager = SaveManager
end)
end)
if not _IDV_fishing_ok then
    warn("[IDV] IDV_fishing ERROR: " .. tostring(_IDV_fishing_err))
else
    print("[IDV] IDV_fishing loaded OK")
end
-- ════════════════════════════════════════════════════════════
--  Indo_Voice
-- ════════════════════════════════════════════════════════════
print("[IDV] Loading Indo_Voice...")
local _Indo_Voice_ok, _Indo_Voice_err = pcall(function()
local DX8 = _G.DX8_Library
local win = _G.DX8_MainWindow
-- ============================================================
--  Games/Indo Voice.lua
--  DX8 Module — Indo Voice (Game Utama) - FIXED VERSION
--  Fitur spesifik Indo Voice:
--    - Love System (Auto Love All, Dynamic Love, Love Stats)
--  UniverseId: [Indo Voice universe id]
-- ============================================================

if shared.DX8_INDOVOICE_Cleanup then
    pcall(shared.DX8_INDOVOICE_Cleanup)
end



-- ============================================================
-- SERVICES
-- ============================================================
local Players           = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local LocalPlayer       = Players.LocalPlayer
local currentScriptID   = shared.DX8_CurrentExecutionID

-- ============================================================
-- LOVE REMOTE — cek ketersediaan
-- ============================================================
local loveFn = nil
do
    local ok, result = pcall(function()
        local remotes = ReplicatedStorage:WaitForChild("GameRemoteFunctions", 3)
        if remotes then loveFn = remotes:WaitForChild("GiveLoveFunction", 3) end
    end)
    if not ok or not loveFn then
        warn("[DX8 Indo Voice] GiveLoveFunction tidak tersedia di game ini.")
    end
end

-- ============================================================
-- STATE
-- ============================================================
local autoGiveLove       = false
local autoDynamicLove    = false
local processedPlayers   = {}
local dynamicFailedCount = {} -- FIX: Mencegah spam remote jika terjadi error berulang
local sentCount          = 0
local failedCount        = 0
local likedCount         = 0
local loveDelay          = 1
local loveSessionID      = 0
local loveToggle         = nil
local loveDelayBox       = nil

local Connections = {}
local function AddConnection(conn) table.insert(Connections, conn) end

-- FIX: Bersihkan cache data player jika mereka keluar server (rejoin handling)
AddConnection(Players.PlayerRemoving:Connect(function(player)
    processedPlayers[player.Name] = nil
    dynamicFailedCount[player.Name] = nil
end))

-- ============================================================
-- CLEANUP
-- ============================================================
local function Cleanup()
    autoGiveLove    = false
    autoDynamicLove = false
    loveSessionID   = loveSessionID + 1

    for _, conn in pairs(Connections) do
        if conn then pcall(function() conn:Disconnect() end) end
    end
    Connections = {}

    print("[DX8 Indo Voice] Module di-unload.")
end
shared.DX8_INDOVOICE_Cleanup = Cleanup

local prevCleanup = shared.DX8_Cleanup
shared.DX8_Cleanup = function()
    Cleanup()
    if prevCleanup then prevCleanup() end
end

-- ============================================================
-- HELPERS
-- ============================================================
local function getAllLoveTargets()
    local targets = {}
    for _, p in ipairs(Players:GetPlayers()) do
        if p ~= LocalPlayer then table.insert(targets, p) end
    end
    return targets
end

local function sendLove(targetPlayer)
    if not loveFn then return "failed", "fitur tidak tersedia di game ini" end
    if not targetPlayer or targetPlayer == LocalPlayer then return "failed", "self" end
    local ok, result, msg = pcall(function() return loveFn:InvokeServer(targetPlayer) end)
    if not ok then return "failed", tostring(result) end
    if result == false then
        if typeof(msg) == "string" then
            if string.find(msg, "once per day") or string.find(msg, "Try again tomorrow") then
                return "failed", "sudah di-love hari ini"
            else
                -- FIX: "Something went wrong" sekarang dianggap murni gagal agar bisa dicoba lagi
                return "failed", msg 
            end
        end
        return "failed", "unknown"
    end
    return "success", "love terkirim"
end

-- ============================================================
-- TAB
-- ============================================================
local ivTab    = win:CreateTab("Indo Voice", "Home")
local loveSec  = ivTab:AddSection("Love System")

-- ============================================================
-- LOVE STATS PANEL — StatCard v2 (3-across grid)
-- ============================================================
local _GREEN = Color3.fromRGB(80,  220, 120)
local _RED   = Color3.fromRGB(220, 90,  90)
local _BLUE  = Color3.fromRGB(100, 195, 255)

local statTotal  = loveSec:AddStatCard({ Icon = "👥", Title = "Total",  Default = "0", Color = _BLUE  })
local statSent   = loveSec:AddStatCard({ Icon = "♥",  Title = "Sent",   Default = "0", Color = _GREEN })
local statFailed = loveSec:AddStatCard({ Icon = "✗",  Title = "Failed", Default = "0", Color = _RED   })

-- Wire the 3 cards into a single-row 3-across grid
local _lv_cframe = statTotal:GetFrame().Parent

local _lv_gw = Instance.new("Frame")
_lv_gw.Name                   = "LoveStatGrid"
_lv_gw.Size                   = UDim2.new(1, -4, 0, 60)
_lv_gw.BackgroundTransparency = 1
_lv_gw.BorderSizePixel        = 0
_lv_gw.Parent                 = _lv_cframe

local _lv_gl = Instance.new("UIGridLayout")
_lv_gl.CellSize            = UDim2.new(0.333, -4, 0, 54)
_lv_gl.CellPadding         = UDim2.new(0, 5, 0, 0)
_lv_gl.FillDirection       = Enum.FillDirection.Horizontal
_lv_gl.HorizontalAlignment = Enum.HorizontalAlignment.Center
_lv_gl.SortOrder           = Enum.SortOrder.LayoutOrder
_lv_gl.Parent              = _lv_gw

local function _lv_mv(comp, order)
    local f = comp:GetFrame(); f.LayoutOrder = order; f.Parent = _lv_gw
end
_lv_mv(statTotal, 1); _lv_mv(statSent, 2); _lv_mv(statFailed, 3)

-- Status bar (hand-built; UIFactory is DX8Lib-internal)
local _lv_TMGR = shared.DX8_Theme
local function _lv_tc(t) return (_lv_TMGR and _lv_TMGR:Get(t)) or Color3.new(1, 1, 1) end

local _lv_sb = Instance.new("Frame")
_lv_sb.Name             = "LoveStatusBar"
_lv_sb.Size             = UDim2.new(1, -4, 0, 22)
_lv_sb.BackgroundColor3 = _lv_tc("BgPanelDark")
_lv_sb.BorderSizePixel  = 0
_lv_sb.Parent           = _lv_cframe
local _lv_sc = Instance.new("UICorner"); _lv_sc.CornerRadius = UDim.new(0, 5); _lv_sc.Parent = _lv_sb

local _lv_statusLbl = Instance.new("TextLabel")
_lv_statusLbl.Size                  = UDim2.new(1, -10, 1, 0)
_lv_statusLbl.Position              = UDim2.new(0, 8, 0, 0)
_lv_statusLbl.BackgroundTransparency = 1
_lv_statusLbl.Text                  = "● Idle"
_lv_statusLbl.TextColor3            = _lv_tc("TextDim")
_lv_statusLbl.Font                  = Enum.Font.GothamBold
_lv_statusLbl.TextSize              = 10
_lv_statusLbl.TextXAlignment        = Enum.TextXAlignment.Left
_lv_statusLbl.Parent                = _lv_sb

-- Compatibility shim — all existing loveStats:X() calls work unchanged
local _STATE_COLORS = {
    idle    = function() return _lv_tc("TextDim")  end,
    running = function() return _lv_tc("Accent")   end,
    done    = function() return _GREEN              end,
    error   = function() return _RED               end,
}
local _STATE_DOTS = { idle = "●", running = "◉", done = "✓", error = "✗" }

local loveStats = {
    SetTotal  = function(_, n)
        statTotal:Set(n)
    end,
    AddSent   = function(_)
        statSent:Add(1)
        statSent:Flash(_GREEN)
    end,
    AddFailed = function(_)
        statFailed:Add(1)
        statFailed:Flash(_RED)
    end,
    SetStatus = function(_, text, state)
        local colorFn = _STATE_COLORS[state]
        _lv_statusLbl.Text      = (_STATE_DOTS[state] or "●") .. " " .. tostring(text)
        _lv_statusLbl.TextColor3 = colorFn and colorFn() or _lv_tc("TextDim")
    end,
    Reset = function(_)
        statTotal:Reset(); statSent:Reset(); statFailed:Reset()
        _lv_statusLbl.Text      = "● Idle"
        _lv_statusLbl.TextColor3 = _lv_tc("TextDim")
    end,
}

-- ============================================================
-- LOVE DELAY
-- ============================================================
loveDelayBox = loveSec:AddTextBox({
    Title       = "Love Delay (detik)",
    Placeholder = tostring(loveDelay),
    Default     = tostring(DX8.GetFlag("LoveDelay") or loveDelay),
    Validate    = "Number",
    Flag        = "LoveDelay",
    Description = "Jeda antar kiriman love (contoh: 1.5).",
    Tooltip     = "Nilai minimum 0 detik.",
    Callback    = function(text)
        local num = tonumber(text)
        if num and num >= 0 then
            loveDelay = num
            DX8:Notify("Love Delay", "Delay diset ke " .. num .. " detik", 2)
        else
            DX8:Notify("Input Salah", "Masukkan angka valid", 2)
        end
    end
})

if DX8.GetFlag("LoveDelay") then
    loveDelay = tonumber(DX8.GetFlag("LoveDelay")) or 1
    loveDelayBox:Set(tostring(loveDelay))
end

-- ============================================================
-- AUTO LOVE ALL
-- ============================================================
loveToggle = loveSec:AddToggle({
    Title       = "Auto Love All",
    Default     = false,
    Flag        = "AutoLove",
    Description = "Kirim love ke semua player di server secara otomatis.",
    Tooltip     = "Proses player satu per satu sesuai delay yang diset.",
    Callback    = function(state)
        autoGiveLove  = state
        loveSessionID = loveSessionID + 1
        local currentSession = loveSessionID

        loveDelayBox:SetEnabled(not state)

        if state then
            processedPlayers = {}
            likedCount = 0; sentCount = 0; failedCount = 0
            loveStats:Reset()

            local allTargets = getAllLoveTargets()
            loveStats:SetTotal(#allTargets)
            loveStats:SetStatus("Memulai scan " .. #allTargets .. " player...", "running")
            DX8:Notify("Auto Love", "Memulai antrean " .. #allTargets .. " player...", 3)

            task.spawn(function()
                -- Phase 1: Scan siapa yang valid/sudah limit hari ini
                loveStats:SetStatus("Scanning...", "running")
                local unlovedTargets = {}

                for _, p in ipairs(getAllLoveTargets()) do
                    if not autoGiveLove or loveSessionID ~= currentSession then break end
                    
                    if not processedPlayers[p.Name] then
                        local ok, result, msg = pcall(function() return loveFn:InvokeServer(p) end)
                        if ok and result == false and typeof(msg) == "string" then
                            if string.find(msg, "once per day") or string.find(msg, "Try again tomorrow") then
                                processedPlayers[p.Name] = true; failedCount += 1; loveStats:AddFailed()
                            else
                                -- Gagal karena alasan lain masuk ke antrean tembak ulang
                                table.insert(unlovedTargets, p)
                            end
                        elseif ok and result ~= false then
                            processedPlayers[p.Name] = true; sentCount += 1; loveStats:AddSent()
                        else
                            table.insert(unlovedTargets, p)
                        end
                        loveStats:SetTotal(#getAllLoveTargets())
                        
                        -- FIX: Jeda scan dinaikkan ke 0.25 detik agar tidak memicu proteksi spam/rate-limit remote
                        task.wait(0.25)
                    end
                end

                -- FIX: Pengecekan akhir Phase 1 disesuaikan agar tidak langsung mematikan script jika scan awal gagal/terlewat
                if #unlovedTargets == 0 and sentCount == 0 and failedCount == 0 then
                    loveStats:SetStatus("Scan gagal/Player kosong, mencoba ulang...", "running")
                    unlovedTargets = getAllLoveTargets()
                end

                if #unlovedTargets == 0 and (sentCount > 0 or failedCount > 0) then
                    loveStats:SetStatus("Semua player sudah di-love hari ini!", "done")
                    DX8:Notify("Auto Love", "Semua player sudah di-love hari ini!", 4)
                    autoGiveLove = false
                    if loveToggle then loveToggle:Set(false) end
                    loveDelayBox:SetEnabled(true)
                    return
                end

                -- Phase 2: Kirim loop utama
                loveStats:SetStatus("Kirim ke " .. #unlovedTargets .. " player...", "running")

                while autoGiveLove and loveSessionID == currentSession and shared.DX8_CurrentExecutionID == currentScriptID do
                    local targets = getAllLoveTargets()
                    loveStats:SetTotal(#targets)

                    local targetPlayer = nil
                    for _, p in ipairs(targets) do
                        if not processedPlayers[p.Name] then targetPlayer = p; break end
                    end

                    if not targetPlayer then
                        loveStats:SetStatus("Selesai · " .. sentCount .. " sent · " .. failedCount .. " failed", "done")
                        DX8:Notify("Auto Love Selesai", "Semua player berhasil diproses!", 4)
                        autoGiveLove = false
                        if loveToggle then loveToggle:Set(false) end
                        loveDelayBox:SetEnabled(true)
                        break
                    end

                    loveStats:SetStatus("Proses: " .. targetPlayer.Name, "running")
                    local status, detail = sendLove(targetPlayer)
                    print(string.format("[LOVE] %s → %s (%s)", targetPlayer.Name, status, detail))

                    if loveSessionID ~= currentSession or shared.DX8_CurrentExecutionID ~= currentScriptID then break end

                    processedPlayers[targetPlayer.Name] = true

                    if status == "success" then
                        likedCount += 1; sentCount += 1
                        loveStats:AddSent()
                        if targetManager then targetManager:Set(sentCount) end
                        if targetLoveProgressBar then
                            if targetLoveGoal > 0 then
                                local pct = math.clamp((sentCount / targetLoveGoal) * 100, 0, 100)
                                targetLoveProgressBar:SetPercent(pct, string.format("%d/%d", sentCount, targetLoveGoal))
                            else
                                targetLoveProgressBar:SetStatus(tostring(sentCount) .. " sent")
                            end
                        end
                        DX8:Notify("♥ Love Terkirim", targetPlayer.Name .. " · " .. detail, 2)
                    else
                        failedCount += 1
                        loveStats:AddFailed()
                        DX8:Notify("✗ Gagal", targetPlayer.Name .. " · " .. detail, 2)
                    end

                    local waitTime = loveDelay
                    while waitTime > 0 and loveSessionID == currentSession and autoGiveLove
                        and shared.DX8_CurrentExecutionID == currentScriptID do
                        task.wait(0.1); waitTime -= 0.1
                    end
                end
            end)
        else
            loveStats:SetStatus("Idle · dihentikan", "idle")
            DX8:Notify("Auto Love", "Fitur dimatikan.", 2)
            loveDelayBox:SetEnabled(true)
        end
    end
})

-- ============================================================
-- AUTO LOVE DYNAMIC (FIXED SYNTAX)
-- ============================================================
loveSec:AddToggle({
    Title       = "Auto Love Dynamic",
    Default     = false,
    Flag        = "AutoLoveDynamic",
    Description = "Background scanner — kirim love ke player baru yang join.",
    Tooltip     = "Scan ulang tiap 10 detik.",
    Callback    = function(state)
        autoDynamicLove = state
        if state then
            loveStats:SetStatus("Dynamic · aktif", "running")
            DX8:Notify("Dynamic Love", "Background scanner aktif.", 3)
            task.spawn(function()
                while autoDynamicLove and shared.DX8_CurrentExecutionID == currentScriptID do
                    local targets = getAllLoveTargets()
                    loveStats:SetTotal(#targets)
                    for _, p in ipairs(targets) do
                        if not autoDynamicLove then break end
                        
                        if not processedPlayers[p.Name] then
                            -- Batasi percobaan jika terjadi error eksternal konstan agar tidak membanjiri antrean remote
                            dynamicFailedCount[p.Name] = dynamicFailedCount[p.Name] or 0
                            
                            if dynamicFailedCount[p.Name] < 3 then
                                local status, detail = sendLove(p)
                                if status == "success" then
                                    processedPlayers[p.Name] = true
                                    sentCount += 1; loveStats:AddSent()
                                    if targetManager then targetManager:Set(sentCount) end
                                    if targetLoveProgressBar then
                                        if targetLoveGoal > 0 then
                                            local pct = math.clamp((sentCount / targetLoveGoal) * 100, 0, 100)
                                            targetLoveProgressBar:SetPercent(pct, string.format("%d/%d", sentCount, targetLoveGoal))
                                        else
                                            targetLoveProgressBar:SetStatus(tostring(sentCount) .. " sent")
                                        end
                                    end
                                    DX8:Notify("♥ Dynamic", p.Name .. " · love terkirim!", 2)
                                elseif string.find(detail or "", "hari ini") then -- FIX: Kata 'omissions' sudah dihapus
                                    processedPlayers[p.Name] = true
                                    failedCount += 1; loveStats:AddFailed()
                                else
                                    -- Jika error lain (lag/rate-limit), naikkan counter gagal sementara
                                    dynamicFailedCount[p.Name] = dynamicFailedCount[p.Name] + 1
                                end
                                task.wait(loveDelay)
                            else
                                -- Jika sudah 3x gagal total, masukkan ke daftar terproses untuk dilewati sementara
                                processedPlayers[p.Name] = true
                                failedCount += 1; loveStats:AddFailed()
                            end
                        end
                    end
                    loveStats:SetStatus("Dynamic · standby...", "idle")
                    task.wait(10)
                end
                loveStats:SetStatus("Dynamic · dimatikan", "idle")
            end)
        else
            autoDynamicLove = false
            loveStats:SetStatus("Dynamic · dimatikan", "idle")
            DX8:Notify("Dynamic Love", "Dimatikan.", 2)
        end
    end
})

-- ============================================================
-- TARGET LOVE SYSTEM
-- ============================================================
local targetLoveGoal = 0
local targetLoveProgressBar = nil
local targetManager = nil

local targetSec = ivTab:AddSection("Target Love System")

targetLoveProgressBar = targetSec:AddProgressBar({
    Title   = "Target Love Progress",
    Default = 0,
    Status  = "Unlimited",
})

targetManager = DX8:CreateTarget({
    Goal = 0,
    OnReach = function(current, goal)
        autoGiveLove = false
        autoDynamicLove = false
        if loveToggle then loveToggle:Set(false) end
        if loveDelayBox then loveDelayBox:SetEnabled(true) end
        if targetLoveProgressBar then
            targetLoveProgressBar:SetStatus("GOAL REACHED! 🎉")
            targetLoveProgressBar:SetColor(Color3.fromRGB(80, 220, 120))
        end
        DX8:Notify("🎯 Target Reached!", string.format("Target %d love di Indo Voice telah tercapai! Auto Love dihentikan.", goal), 5)
    end
})

targetSec:AddSlider({
    Title       = "Target Love Count (0 = Unlimited)",
    Min         = 0,
    Max         = 200,
    Step        = 5,
    Default     = 0,
    Flag        = "IV_TargetLove",
    Description = "Set target jumlah love yang dikirim. Auto Love akan otomatis mati jika tercapai.",
    Callback    = function(val)
        targetLoveGoal = val
        targetManager:SetGoal(val)
        if val <= 0 then
            targetLoveProgressBar:Reset()
            targetLoveProgressBar:SetStatus(tostring(sentCount) .. " sent")
            targetLoveProgressBar:SetColor(Color3.fromRGB(150, 211, 246))
        else
            local pct = math.clamp((sentCount / val) * 100, 0, 100)
            targetLoveProgressBar:SetPercent(pct, string.format("%d/%d", sentCount, val))
        end
    end
})

targetSec:AddButton({
    Title       = "↺ Reset Target Counter",
    Description = "Reset hitungan progress target love ke 0.",
    Callback    = function()
        sentCount = 0
        targetManager:Reset()
        targetLoveProgressBar:Reset()
        if targetLoveGoal > 0 then
            targetLoveProgressBar:SetStatus(string.format("0/%d", targetLoveGoal))
        else
            targetLoveProgressBar:SetStatus("0 sent")
        end
        DX8:Notify("Target System", "Hitungan progress target love di-reset ke 0.", 2)
    end
})

-- ============================================================
DX8:Notify("Indo Voice", "Module Indo Voice loaded!", 3)
end)
if not _Indo_Voice_ok then
    warn("[IDV] Indo_Voice ERROR: " .. tostring(_Indo_Voice_err))
else
    print("[IDV] Indo_Voice loaded OK")
end
