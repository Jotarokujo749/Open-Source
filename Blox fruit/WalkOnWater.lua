--[[
    ╔══════════════════════════════════════════════════════════════╗
    ║  Blox Fruits - Zamasu Walk on Water (Open Source)                  ║
    ║  Walk on the ocean surface like solid ground                ║
    ║  No GUI, no dependencies — plug and play                    ║
    ╚══════════════════════════════════════════════════════════════╝

    HOW IT WORKS:
        An invisible part follows under your feet at water level.
        When you're over the ocean, it becomes solid so you walk on it.
        On islands, it disappears completely — zero interference.

   
]]

--// ═══════════════════════════════════════════════════════════════
--// SERVICES
--// ═══════════════════════════════════════════════════════════════
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

local LocalPlayer = Players.LocalPlayer

--// ═══════════════════════════════════════════════════════════════
--// CONFIG
--// ═══════════════════════════════════════════════════════════════
local WATER_Y = -4              -- Water surface Y level (tune this for your game)
local PART_SIZE = Vector3.new(22, 1.5, 22)  -- Platform size
local RESCUE_THRESHOLD = -2     -- How far below water before rescue teleport
local RESCUE_COOLDOWN = 0.8     -- Seconds between rescue teleports
local HEIGHT_CHECK = 20         -- If player Y > WATER_Y + this, assume on island
local STARTUP_DELAY = 3         -- Seconds to wait before activating (prevents glitches)

--// ═══════════════════════════════════════════════════════════════
--// STATE
--// ═══════════════════════════════════════════════════════════════
local WaterPart = nil
local WaterConn = nil
local LastRescue = 0
local Active = true

--// ═══════════════════════════════════════════════════════════════
--// RAYCAST SETUP
--// ═══════════════════════════════════════════════════════════════
local rayParams = RaycastParams.new()
rayParams.FilterType = Enum.RaycastFilterType.Exclude

--// ═══════════════════════════════════════════════════════════════
--// HELPERS
--// ═══════════════════════════════════════════════════════════════

--- Check if the player is over water (not over an island)
--- Key insight: raycast can hit the ocean FLOOR — we check if
--- the detected ground is ABOVE water level (= real island)
--- or BELOW it (= seabed, so we're over water)
local function IsOverWater(root)
    local char = LocalPlayer.Character
    if char then
        rayParams.FilterDescendantsInstances = {char, WaterPart or workspace}
    end
    local result = workspace:Raycast(root.Position, Vector3.new(0, -200, 0), rayParams)
    if result then
        -- Ground detected ABOVE water = island, not water
        if result.Position.Y > WATER_Y then
            return false
        end
    end
    -- No ground above water = open ocean
    return true
end

--- Hide the platform (move offscreen + disable collision)
local function HidePart()
    if WaterPart and WaterPart.Parent then
        WaterPart.CanCollide = false
        WaterPart.CFrame = CFrame.new(0, -500, 0)
    end
end

--- Show the platform under the player at water level
--- Predicts position slightly ahead using velocity for smooth movement
local function ShowPart(pos, vel)
    -- Lazy creation: part only exists when actually needed
    if not WaterPart or not WaterPart.Parent then
        local p = Instance.new("Part")
        p.Name = "WalkOnWater"
        p.Size = PART_SIZE
        p.Transparency = 1
        p.Anchored = true
        p.CanCollide = false
        p.Material = Enum.Material.SmoothPlastic
        p.CastShadow = false
        p.CFrame = CFrame.new(0, -500, 0)
        p.Parent = workspace
        WaterPart = p
    end
    -- Position slightly ahead of player for smooth walking
    WaterPart.CFrame = CFrame.new(
        pos.X + vel.X * 0.08,
        WATER_Y - 0.75,
        pos.Z + vel.Z * 0.08
    )
    WaterPart.CanCollide = true
end

--- Full cleanup — disconnect + destroy
local function Cleanup()
    if WaterConn then WaterConn:Disconnect(); WaterConn = nil end
    if WaterPart then pcall(function() WaterPart:Destroy() end); WaterPart = nil end
end

--// ═══════════════════════════════════════════════════════════════
--// MAIN LOOP
--// ═══════════════════════════════════════════════════════════════
local function Start()
    if WaterConn then return end

    WaterConn = RunService.Heartbeat:Connect(function()
        if not Active then Cleanup() return end

        local char = LocalPlayer.Character
        if not char then return end
        local root = char:FindFirstChild("HumanoidRootPart")
        local hum = char:FindFirstChildOfClass("Humanoid")
        if not root or not hum then return end

        local pos = root.Position
        local vel = root.AssemblyLinearVelocity

        -- Too high up = on an island, don't interfere
        if pos.Y > WATER_Y + HEIGHT_CHECK then
            HidePart()
            return
        end

        -- Standing on real ground (not our part) = on island
        local floor = hum.FloorMaterial
        if floor ~= Enum.Material.Air and floor ~= Enum.Material.SmoothPlastic then
            HidePart()
            return
        end

        -- Auto-calibrate water Y if swimming in a different zone
        if hum:GetState() == Enum.HumanoidStateType.Swimming then
            local detectedY = pos.Y + 1.5
            if math.abs(detectedY - WATER_Y) > 3 then
                WATER_Y = detectedY
                print("[WalkOnWater] Water Y updated: " .. tostring(math.floor(WATER_Y * 100) / 100))
            end
        end

        -- Over water — activate platform
        if IsOverWater(root) then
            ShowPart(pos, vel)

            -- Rescue if fallen below water
            if pos.Y < WATER_Y + RESCUE_THRESHOLD then
                local now = tick()
                if now - LastRescue > RESCUE_COOLDOWN then
                    LastRescue = now
                    root.CFrame = CFrame.new(pos.X, WATER_Y + 3.5, pos.Z)
                    root.AssemblyLinearVelocity = Vector3.new(vel.X, 0, vel.Z)
                end
            end
            return
        end

        -- Over island — hide everything
        HidePart()
    end)
end

--// ═══════════════════════════════════════════════════════════════
--// STARTUP (with delay to prevent injection glitches)
--// ═══════════════════════════════════════════════════════════════
print("[WalkOnWater] Loading — will activate in " .. STARTUP_DELAY .. "s...")

task.delay(STARTUP_DELAY, function()
    print("[WalkOnWater] Active — walk to the ocean!")
    Start()
end)

-- Reconnect after respawn
LocalPlayer.CharacterAdded:Connect(function()
    LastRescue = 0
    task.wait(2)
    if Active and not WaterConn then Start() end
end)

-- Safety: restart if connection dies
task.spawn(function()
    while Active do
        task.wait(30)
        if Active and not WaterConn then Start() end
    end
end)
