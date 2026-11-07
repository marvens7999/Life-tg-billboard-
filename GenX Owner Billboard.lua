--[[
    Gen-X OWNER Billboard  (v7 - Royal Purple Premium)
    Executor: Delta (Roblox, Luau)
    Animated premium name tag over the heads of the listed UserIds.
    Draws locally for every player running this script in the server.

    Layers (back to front):
      1. soft pulsing purple glow
      2. main text with flowing purple gradient fill
      3. LED chase light running around the text edge
      4. white shine sweeping through the letters
      5. travelling light on an underline + twinkling sparkles
]]

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local StarterGui = game:GetService("StarterGui")
local LocalPlayer = Players.LocalPlayer

-- ===== CONFIG =====
local OWNER_IDS = {
    [10909271675] = true,
    [10415460489] = true,
}
local TAG_TEXT = "👑 Gen-X OWNER 👑"
local HEIGHT_OFFSET = 3.3
local BOB_AMOUNT = 0.12
local FLOW_SPEED = 0.22      -- purple fill flow
local LED_SPEED = 220        -- degrees/sec of the edge chase light
local SHINE_SPEED = 0.7      -- white sweep
local MIN_WIDTH, MAX_WIDTH = 170, 300
local FORCE_LOCAL_TEST = false
local SHOW_NOTIFY = false    -- debug popups (errors always show)

local PURPLE_DARK  = Color3.fromRGB(122, 58, 238)
local PURPLE_MID   = Color3.fromRGB(172, 104, 255)
local PURPLE_LIGHT = Color3.fromRGB(238, 214, 255)
local WHITE        = Color3.fromRGB(255, 255, 255)
-- ==================

-- a new run always replaces the previous one (rejoining the same server or re-executing is safe)
local guardKey = "GenXBillboard_Cleanup"
local genv = (getgenv and getgenv()) or _G
if type(genv[guardKey]) == "function" then
    pcall(genv[guardKey])
end
genv[guardKey] = nil
local running = true
local conns = {}
local function keep(c) conns[#conns + 1] = c return c end

local function notify(text, force)
    print("[GenX] " .. text)
    if not (SHOW_NOTIFY or force) then return end
    pcall(function()
        StarterGui:SetCore("SendNotification", { Title = "Gen-X Billboard", Text = text, Duration = 6 })
    end)
end

local container = LocalPlayer:WaitForChild("PlayerGui")
local active = {}    -- [gui] = parts
local byPlayer = {}  -- [player] = gui

local function destroyLeftovers()
    for _, g in ipairs(container:GetChildren()) do
        if g.Name == "GenXOwnerBillboard" then pcall(function() g:Destroy() end) end
    end
end
destroyLeftovers()

genv[guardKey] = function()
    running = false
    for _, c in ipairs(conns) do pcall(function() c:Disconnect() end) end
    for gui in pairs(active) do pcall(function() gui:Destroy() end) end
    for _, gui in pairs(byPlayer) do pcall(function() gui:Destroy() end) end
    table.clear(active)
    table.clear(byPlayer)
    destroyLeftovers()
end

-- smooth dark -> mid -> light purple wave flowing across the text
local function purpleSequence(t)
    local n = 6
    local keys = {}
    for i = 0, n - 1 do
        local k = (math.sin((t + i / (n - 1)) * math.pi * 2) + 1) / 2
        local c
        if k < 0.5 then
            c = PURPLE_DARK:Lerp(PURPLE_MID, k * 2)
        else
            c = PURPLE_MID:Lerp(PURPLE_LIGHT, (k - 0.5) * 2)
        end
        keys[#keys + 1] = ColorSequenceKeypoint.new(i / (n - 1), c)
    end
    return ColorSequence.new(keys)
end

local function makeLabel(parent, z)
    local label = Instance.new("TextLabel")
    label.AnchorPoint = Vector2.new(0.5, 0)
    label.Position = UDim2.new(0.5, 0, 0, 0)
    label.Size = UDim2.new(1, 0, 0.8, 0)
    label.BackgroundTransparency = 1
    label.BorderSizePixel = 0
    label.Text = TAG_TEXT
    label.Font = Enum.Font.GothamBlack
    label.TextScaled = true
    label.TextColor3 = WHITE
    label.TextStrokeTransparency = 1
    label.ZIndex = z
    label.Parent = parent
    return label
end

-- custom-drawn sparkles (no emoji): 4-point star + diagonal arms + glowing core + halo
-- x/y = position on the tag, size in px, phase = offset in the cycle, speed = cycles/sec
local SPARKLES = {
    { x = 0.05, y = 0.12, size = 22, phase = 0.00, speed = 0.50, rot = 0  },
    { x = 0.22, y = 0.00, size = 12, phase = 0.35, speed = 0.62, rot = 15 },
    { x = 0.50, y = -0.04, size = 16, phase = 0.60, speed = 0.45, rot = 0  },
    { x = 0.78, y = 0.02, size = 12, phase = 0.15, speed = 0.58, rot = 30 },
    { x = 0.96, y = 0.14, size = 22, phase = 0.50, speed = 0.52, rot = 0  },
    { x = 0.36, y = 0.80, size = 11, phase = 0.80, speed = 0.66, rot = 20 },
    { x = 0.66, y = 0.82, size = 14, phase = 0.25, speed = 0.42, rot = 10 },
}

local function makeArm(parent, len, wid, rot, color)
    local arm = Instance.new("Frame")
    arm.AnchorPoint = Vector2.new(0.5, 0.5)
    arm.Position = UDim2.new(0.5, 0, 0.5, 0)
    arm.Size = UDim2.new(wid, 0, len, 0)
    arm.Rotation = rot
    arm.BackgroundColor3 = color
    arm.BackgroundTransparency = 1
    arm.BorderSizePixel = 0
    arm.ZIndex = 4
    arm.Parent = parent
    -- tapered ends so each arm looks like a light ray, not a bar
    local g = Instance.new("UIGradient")
    g.Rotation = 90
    g.Transparency = NumberSequence.new({
        NumberSequenceKeypoint.new(0.0, 1),
        NumberSequenceKeypoint.new(0.5, 0),
        NumberSequenceKeypoint.new(1.0, 1),
    })
    g.Parent = arm
    return arm
end

local function makeCircle(parent, scale, color)
    local c = Instance.new("Frame")
    c.AnchorPoint = Vector2.new(0.5, 0.5)
    c.Position = UDim2.new(0.5, 0, 0.5, 0)
    c.Size = UDim2.new(scale, 0, scale, 0)
    c.BackgroundColor3 = color
    c.BackgroundTransparency = 1
    c.BorderSizePixel = 0
    c.ZIndex = 4
    local corner = Instance.new("UICorner")
    corner.CornerRadius = UDim.new(1, 0)
    corner.Parent = c
    c.Parent = parent
    return c
end

local function makeSparkle(parent, cfg)
    local root = Instance.new("Frame")
    root.AnchorPoint = Vector2.new(0.5, 0.5)
    root.Position = UDim2.new(cfg.x, 0, cfg.y, 0)
    root.Size = UDim2.new(0, cfg.size, 0, cfg.size)
    root.Rotation = cfg.rot
    root.BackgroundTransparency = 1
    root.BorderSizePixel = 0
    root.ZIndex = 4
    root.Parent = parent

    local arms = {
        makeArm(root, 1.00, 0.13, 0,   WHITE),
        makeArm(root, 1.00, 0.13, 90,  WHITE),
        makeArm(root, 0.60, 0.09, 45,  PURPLE_LIGHT),
        makeArm(root, 0.60, 0.09, -45, PURPLE_LIGHT),
    }
    local core = makeCircle(root, 0.30, WHITE)

    return {
        root = root, arms = arms, core = core,
        x = cfg.x, y = cfg.y, size = cfg.size,
        phase = cfg.phase, speed = cfg.speed, rot = cfg.rot,
    }
end

-- glow in -> peak -> fade out, with a slow spin and a little upward drift
local function updateSparkle(sp, t)
    local cycle = (t * sp.speed + sp.phase) % 1
    local env = math.sin(cycle * math.pi) ^ 2      -- 0 -> 1 -> 0
    local scale = 0.15 + 0.85 * env

    sp.root.Size = UDim2.new(0, sp.size * scale, 0, sp.size * scale)
    sp.root.Rotation = sp.rot + cycle * 120
    sp.root.Position = UDim2.new(sp.x, 0, sp.y + 0.03 - cycle * 0.06, 0)

    local vis = 1 - env
    for _, arm in ipairs(sp.arms) do
        arm.BackgroundTransparency = vis
    end
    sp.core.BackgroundTransparency = vis
end

local function easeOutBack(x)
    local c1 = 1.70158
    local c3 = c1 + 1
    return 1 + c3 * (x - 1) ^ 3 + c1 * (x - 1) ^ 2
end

-- tiny glowing particles that rise off the tag and fade out
local EMBER_COUNT = 9
local EMBERS = {}
for n = 1, EMBER_COUNT do
    EMBERS[n] = {
        x = 0.08 + 0.84 * ((n * 0.618) % 1),
        phase = (n * 0.37) % 1,
        speed = 0.22 + 0.16 * ((n * 0.53) % 1),
        size = 3 + (n % 3),
        drift = (((n * 0.29) % 1) - 0.5) * 0.08,
    }
end

local function makeEmber(parent, cfg)
    local d = Instance.new("Frame")
    d.AnchorPoint = Vector2.new(0.5, 0.5)
    d.Position = UDim2.new(cfg.x, 0, 0.95, 0)
    d.Size = UDim2.new(0, cfg.size, 0, cfg.size)
    d.BackgroundColor3 = PURPLE_LIGHT
    d.BackgroundTransparency = 1
    d.BorderSizePixel = 0
    d.ZIndex = 4
    local corner = Instance.new("UICorner")
    corner.CornerRadius = UDim.new(1, 0)
    corner.Parent = d
    d.Parent = parent
    return { frame = d, x = cfg.x, phase = cfg.phase, speed = cfg.speed, drift = cfg.drift }
end

local function updateEmber(em, t)
    local cycle = (t * em.speed + em.phase) % 1
    local env = math.sin(cycle * math.pi) ^ 1.5
    local x = em.x + math.sin(t * 2 + em.phase * 6) * 0.015 + em.drift * cycle
    em.frame.Position = UDim2.new(x, 0, 0.95 - cycle * 1.15, 0)
    em.frame.BackgroundTransparency = 1 - env * 0.9
end

local function removeFor(plr)
    local old = byPlayer[plr]
    if old then
        active[old] = nil
        old:Destroy()
        byPlayer[plr] = nil
    end
end

local function buildBillboard(plr, head)
    removeFor(plr)

    local gui = Instance.new("BillboardGui")
    gui.Name = "GenXOwnerBillboard"
    gui.Adornee = head
    gui.Size = UDim2.new(0, 260, 0, 52)
    gui.StudsOffset = Vector3.new(0, HEIGHT_OFFSET, 0)
    gui.AlwaysOnTop = true
    gui.LightInfluence = 0
    gui.MaxDistance = math.huge
    gui.ResetOnSpawn = false
    gui.Active = false

    -- 0. drop shadow for depth and readability
    local shadow = makeLabel(gui, 1)
    shadow.Position = UDim2.new(0.5, 0, 0, 3)
    shadow.TextColor3 = Color3.fromRGB(16, 0, 40)
    shadow.TextTransparency = 0.7

    -- 1. soft glow
    local glow = makeLabel(gui, 1)
    glow.TextColor3 = PURPLE_MID
    glow.TextTransparency = 0.85
    local glowStroke = Instance.new("UIStroke")
    glowStroke.Thickness = 3
    glowStroke.Color = PURPLE_MID
    glowStroke.Transparency = 0.8
    glowStroke.Parent = glow

    -- 2. main text with flowing purple fill
    local main = makeLabel(gui, 2)
    local fill = Instance.new("UIGradient")
    fill.Color = purpleSequence(0)
    fill.Parent = main

    -- 3. LED chase light on the text edge (gradient on the stroke, rotating)
    local edge = Instance.new("UIStroke")
    edge.Thickness = 2.2
    edge.Color = WHITE
    edge.Transparency = 0
    edge.Parent = main
    local edgeGrad = Instance.new("UIGradient")
    edgeGrad.Color = ColorSequence.new({
        ColorSequenceKeypoint.new(0.00, PURPLE_DARK),
        ColorSequenceKeypoint.new(0.20, PURPLE_DARK),
        ColorSequenceKeypoint.new(0.25, WHITE),
        ColorSequenceKeypoint.new(0.30, PURPLE_DARK),
        ColorSequenceKeypoint.new(0.70, PURPLE_DARK),
        ColorSequenceKeypoint.new(0.75, WHITE),
        ColorSequenceKeypoint.new(0.80, PURPLE_DARK),
        ColorSequenceKeypoint.new(1.00, PURPLE_DARK),
    })
    edgeGrad.Parent = edge

    -- 3b. glossy top highlight on the letters
    local glossLabel = makeLabel(gui, 3)
    local glossGrad = Instance.new("UIGradient")
    glossGrad.Rotation = 90
    glossGrad.Transparency = NumberSequence.new({
        NumberSequenceKeypoint.new(0.00, 0.45),
        NumberSequenceKeypoint.new(0.45, 0.80),
        NumberSequenceKeypoint.new(0.50, 1.00),
        NumberSequenceKeypoint.new(1.00, 1.00),
    })
    glossGrad.Parent = glossLabel

    -- 4. white shine sweeping through the letters
    local shineLabel = makeLabel(gui, 3)
    local shine = Instance.new("UIGradient")
    shine.Color = ColorSequence.new(PURPLE_LIGHT)
    shine.Transparency = NumberSequence.new({
        NumberSequenceKeypoint.new(0.00, 1),
        NumberSequenceKeypoint.new(0.40, 1),
        NumberSequenceKeypoint.new(0.50, 0.05),
        NumberSequenceKeypoint.new(0.60, 1),
        NumberSequenceKeypoint.new(1.00, 1),
    })
    shine.Rotation = 20
    shine.Offset = Vector2.new(-1, 0)
    shine.Parent = shineLabel

    -- 5a. two curved LED bars (top + bottom) forming a transparent capsule around the whole name
    local function makeCapsule()
        local f = Instance.new("Frame")
        f.AnchorPoint = Vector2.new(0.5, 0.5)
        f.Position = UDim2.new(0.5, 0, 0.42, 0)
        f.Size = UDim2.new(1.12, 0, 0.9, 0)
        f.BackgroundTransparency = 1
        f.BorderSizePixel = 0
        f.ZIndex = 3
        local corner = Instance.new("UICorner")
        corner.CornerRadius = UDim.new(0.5, 0)
        corner.Parent = f
        f.Parent = gui
        return f
    end

    -- bars: bright along the top and bottom, fading out toward the middle of the curved sides
    local barFrame = makeCapsule()
    local barStroke = Instance.new("UIStroke")
    barStroke.Thickness = 2.2
    barStroke.Color = PURPLE_LIGHT
    barStroke.Parent = barFrame
    local barGrad = Instance.new("UIGradient")
    barGrad.Rotation = 90
    barGrad.Color = ColorSequence.new({
        ColorSequenceKeypoint.new(0.00, PURPLE_LIGHT),
        ColorSequenceKeypoint.new(0.20, PURPLE_MID),
        ColorSequenceKeypoint.new(0.50, PURPLE_DARK),
        ColorSequenceKeypoint.new(0.80, PURPLE_MID),
        ColorSequenceKeypoint.new(1.00, PURPLE_LIGHT),
    })
    barGrad.Transparency = NumberSequence.new({
        NumberSequenceKeypoint.new(0.00, 0.00),
        NumberSequenceKeypoint.new(0.18, 0.05),
        NumberSequenceKeypoint.new(0.50, 0.92),
        NumberSequenceKeypoint.new(0.82, 0.05),
        NumberSequenceKeypoint.new(1.00, 0.00),
    })
    barGrad.Parent = barStroke

    -- two light beads that run around the whole curved outline
    local chaseFrame = makeCapsule()
    local chaseStroke = Instance.new("UIStroke")
    chaseStroke.Thickness = 3
    chaseStroke.Color = WHITE
    chaseStroke.Parent = chaseFrame
    local chaseGrad = Instance.new("UIGradient")
    chaseGrad.Color = ColorSequence.new({
        ColorSequenceKeypoint.new(0.0, PURPLE_LIGHT),
        ColorSequenceKeypoint.new(0.5, WHITE),
        ColorSequenceKeypoint.new(1.0, PURPLE_LIGHT),
    })
    chaseGrad.Transparency = NumberSequence.new({
        NumberSequenceKeypoint.new(0.00, 1),
        NumberSequenceKeypoint.new(0.16, 1),
        NumberSequenceKeypoint.new(0.25, 0),
        NumberSequenceKeypoint.new(0.34, 1),
        NumberSequenceKeypoint.new(0.66, 1),
        NumberSequenceKeypoint.new(0.75, 0),
        NumberSequenceKeypoint.new(0.84, 1),
        NumberSequenceKeypoint.new(1.00, 1),
    })
    chaseGrad.Parent = chaseStroke

    -- 5a3. rising light particles
    local embers = {}
    for _, cfg in ipairs(EMBERS) do
        embers[#embers + 1] = makeEmber(gui, cfg)
    end

    -- 5b. custom sparkles
    local sparks = {}
    for _, cfg in ipairs(SPARKLES) do
        sparks[#sparks + 1] = makeSparkle(gui, cfg)
    end

    gui.Parent = LocalPlayer:FindFirstChildOfClass("PlayerGui") or container
    active[gui] = {
        head = head, fill = fill, edgeGrad = edgeGrad, shine = shine,
        glowStroke = glowStroke, sparks = sparks,
        barGrad = barGrad, barStroke = barStroke, chaseGrad = chaseGrad,
        embers = embers, spawn = os.clock(),
    }
    byPlayer[plr] = gui
    notify("billboard attached to " .. plr.Name)
end

local function shouldTag(plr)
    if OWNER_IDS[plr.UserId] then return true end
    if FORCE_LOCAL_TEST and plr == LocalPlayer then return true end
    return false
end

local function setupPlayer(plr)
    if not shouldTag(plr) then return end

    local function onCharacter(char)
        local head = char:WaitForChild("Head", 10)
        if not head then
            notify("No Head found on " .. plr.Name, true)
            return
        end
        local ok, err = pcall(buildBillboard, plr, head)
        if not ok then notify("Build error: " .. tostring(err), true) end
    end

    keep(plr.CharacterAdded:Connect(onCharacter))
    if plr.Character then task.spawn(onCharacter, plr.Character) end
end

for _, plr in ipairs(Players:GetPlayers()) do setupPlayer(plr) end
keep(Players.PlayerAdded:Connect(setupPlayer))
keep(Players.PlayerRemoving:Connect(removeFor))

keep(RunService.RenderStepped:Connect(function()
    local t = os.clock()
    local cam = workspace.CurrentCamera
    local flow = (t * FLOW_SPEED) % 1
    -- one sweep, then a pause (more premium than a constant loop)
    local sweepPhase = (t * SHINE_SPEED * 0.4) % 1
    local sweep = math.clamp(-1.3 + sweepPhase * 4.6, -1.3, 1.3)
    local glowPulse = 0.74 + (math.sin(t * 3) + 1) * 0.09
    local rot = (t * LED_SPEED) % 360

    for gui, p in pairs(active) do
        local head = p.head
        if gui.Parent == nil or not head or not head:IsDescendantOf(workspace) then
            active[gui] = nil
            gui:Destroy()
        else
            p.fill.Color = purpleSequence(flow)
            p.edgeGrad.Rotation = rot
            p.shine.Offset = Vector2.new(sweep, 0)
            p.glowStroke.Transparency = glowPulse
            p.chaseGrad.Rotation = (rot * 0.7 + 45) % 360
            p.barGrad.Offset = Vector2.new(0, math.sin(t * 1.4) * 0.06)
            p.barStroke.Transparency = 0.04 + (math.sin(t * 2) + 1) * 0.07

            -- entrance: pop in with a slight overshoot, settle, then gently breathe
            local e = easeOutBack(math.clamp((t - p.spawn) / 0.9, 0, 1))
            local bob = math.sin(t * 2) * BOB_AMOUNT
            gui.StudsOffset = Vector3.new(0, HEIGHT_OFFSET + bob - (1 - math.min(e, 1)) * 0.8, 0)

            -- keep the tag a readable size at any camera distance
            local w = 260
            if cam then
                local dist = (cam.CFrame.Position - head.Position).Magnitude
                w = math.clamp(4200 / math.max(dist, 1), MIN_WIDTH, MAX_WIDTH)
            end
            w = math.max(w * e * (1 + math.sin(t * 2) * 0.015), 1)
            gui.Size = UDim2.new(0, w, 0, math.max(w * 0.2, 1))

            for _, em in ipairs(p.embers) do
                updateEmber(em, t)
            end

            for _, sp in ipairs(p.sparks) do
                updateSparkle(sp, t)
            end
        end
    end
end))

-- watchdog: if the game swaps the Head (avatar copy, morphs, reloads), deletes the tag,
-- or the character streams in late, rebuild the tag on the current Head
task.spawn(function()
    while running do
        for _, plr in ipairs(Players:GetPlayers()) do
            if shouldTag(plr) then
                local char = plr.Character
                local head = char and char:FindFirstChild("Head")
                local gui = byPlayer[plr]
                if head and head:IsDescendantOf(workspace)
                    and (not gui or gui.Parent == nil or gui.Adornee ~= head) then
                    local ok, err = pcall(buildBillboard, plr, head)
                    if not ok then notify("Rebuild error: " .. tostring(err), true) end
                end
            end
        end
        task.wait(0.5)
    end
end)

notify("Loaded.")
