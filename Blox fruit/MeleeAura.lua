--[[
    ╔══════════════════════════════════════════════════════════════╗
    ║  Blox Fruits - Zamasu Melee Aura (Open Source)                     ║
    ║  Auto-hits all mobs in range when melee is equipped         ║
    ║  No GUI, no dependencies — plug and play                    ║
    ╚══════════════════════════════════════════════════════════════╝

    HOW IT WORKS:
        1. Equip any melee fighting style
        2. Script detects it and starts hitting all nearby mobs
        3. Unequip melee to stop

    CONFIGURATION:
        Change RADIUS, COOLDOWN, BURST below to tune.
]]

--// ═══════════════════════════════════════════════════════════════
--// SERVICES
--// ═══════════════════════════════════════════════════════════════
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local VirtualUser = game:GetService("VirtualUser")

local LocalPlayer = Players.LocalPlayer

--// ═══════════════════════════════════════════════════════════════
--// CONFIG
--// ═══════════════════════════════════════════════════════════════
local CONFIG = {
    RADIUS = 700,           -- How far to detect mobs (studs)
    COOLDOWN = 0.08,        -- Minimum time between attack bursts (seconds)
    BURST = 3,              -- Number of hits per burst
    BURST_DELAY = 0.06,     -- Delay between each hit in a burst (seconds)
    SECRET_KEY = "0243e692", -- Internal key
}

--// ═══════════════════════════════════════════════════════════════
--// MELEE NAMES (all fighting styles in Blox Fruits)
--// ═══════════════════════════════════════════════════════════════
local MELEE_NAMES = {
    -- Sea 1
    "Combat", "Dark Step", "Electric", "Water Kung Fu",
    -- Sea 2
    "Dragon Breath", "Superhuman", "Death Step", "Sharkman Karate",
    -- Sea 3
    "Electric Claw", "Dragon Talon", "Godhuman", "Sanguine Art",
    -- Other / Bonus
    "Black Leg", "Electro", "Fishman Karate", "Dragon Claw",
    "Iron Fist", "Beast Instinct",
}

--// ═══════════════════════════════════════════════════════════════
--// HELPERS
--// ═══════════════════════════════════════════════════════════════

--- Check if a tool name is a melee fighting style
local function IsMelee(toolName)
    for _, name in ipairs(MELEE_NAMES) do
        if name == toolName then return true end
    end
    return false
end

--- Get the currently equipped melee (in Character), or nil
local function GetEquippedMelee()
    local char = LocalPlayer.Character
    if not char then return nil end
    for _, child in pairs(char:GetChildren()) do
        if child:IsA("Tool") and IsMelee(child.Name) then
            return child.Name
        end
    end
    return nil
end

--- Find all alive mobs within RADIUS
local function GetNearbyMobs()
    local char = LocalPlayer.Character
    if not char or not char:FindFirstChild("HumanoidRootPart") then return {} end
    local pos = char.HumanoidRootPart.Position
    local mobs = {}

    for _, folder in pairs(workspace:GetChildren()) do
        if folder:IsA("Folder") or folder:IsA("Model") then
            for _, mob in pairs(folder:GetChildren()) do
                if mob:IsA("Model") and mob:FindFirstChild("Humanoid") and mob:FindFirstChild("Head") then
                    if mob.Humanoid.Health > 0 and not Players:GetPlayerFromCharacter(mob) then
                        local dist = (mob.Head.Position - pos).Magnitude
                        if dist <= CONFIG.RADIUS then
                            table.insert(mobs, mob)
                        end
                    end
                end
            end
        end
    end
    return mobs
end

--// ═══════════════════════════════════════════════════════════════
--// ATTACK FUNCTION
--// ═══════════════════════════════════════════════════════════════
local LastAttackTime = 0

local function AttackMobs(mobs)
    if #mobs == 0 then return end
    if tick() - LastAttackTime < CONFIG.COOLDOWN then return end

    pcall(function()
        -- Build hit data
        local hitData = {}
        for _, mob in ipairs(mobs) do
            if mob and mob.Parent and mob:FindFirstChild("Head") then
                table.insert(hitData, {mob, mob.Head})
            end
        end
        if #hitData == 0 then return end

        -- Fire burst
        local burstCount = math.max(1, CONFIG.BURST + math.random(-1, 1))
        for _ = 1, burstCount do
            ReplicatedStorage.Modules.Net["RE/RegisterAttack"]:FireServer(0.01)
            ReplicatedStorage.Modules.Net["RE/RegisterHit"]:FireServer(hitData[1][2], hitData, CONFIG.SECRET_KEY)

            -- Simulate mouse click (randomized position)
            local cx = 500 + math.random(-50, 50)
            local cy = 500 + math.random(-50, 50)
            VirtualUser:Button1Down(Vector2.new(cx, cy))
            task.wait(CONFIG.BURST_DELAY + (math.random() * 0.03))
            VirtualUser:Button1Up(Vector2.new(cx, cy))
        end
        LastAttackTime = tick()
    end)
end

--// ═══════════════════════════════════════════════════════════════
--// MAIN LOOP
--// ═══════════════════════════════════════════════════════════════
print("[MeleeAura] Loaded — equip any melee to start hitting")

RunService.Heartbeat:Connect(function()
    -- Only attack if a melee is equipped
    if not GetEquippedMelee() then return end

    local mobs = GetNearbyMobs()
    if #mobs > 0 then
        AttackMobs(mobs)
    end
end)
