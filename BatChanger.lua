local Players = game:GetService("Players")
local CoreGui = game:GetService("CoreGui")
local PlayerGui = Players.LocalPlayer:WaitForChild("PlayerGui")
local UserInputService = game:GetService("UserInputService")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Lighting = game:GetService("Lighting")
local InsertService = game:GetService("InsertService")

local LocalPlayer = Players.LocalPlayer

local COLORS = {
    background = Color3.new(0.0470588, 0.0470588, 0.054902),
    header = Color3.new(0.0705882, 0.0705882, 0.0862745),
    row = Color3.new(0.0862745, 0.0862745, 0.101961),
    button = Color3.new(0.109804, 0.109804, 0.133333),
    darkButton = Color3.new(0.137255, 0.137255, 0.156863),
    mini = Color3.new(0.0588235, 0.0588235, 0.0705882),
    red = Color3.new(0.784314, 0, 0),
    red2 = Color3.new(1, 0.392157, 0.392157),
    gold = Color3.new(1, 0.72549, 0.196078),
    text = Color3.new(0.941176, 0.941176, 0.960784),
    dim = Color3.new(0.470588, 0.470588, 0.509804),
}

local State = {
    Skin = "KATANA",
    Minimized = false,
    SkinOrder = { "KATANA", "SCYTHE", "BAN HAMMER", "NONE" },
    Connections = {},
    LastBat = nil,
    LastAppliedSkin = nil,
    OriginalKatanaTemplate = nil,
    ExactTemplates = {},
    ExactTemplateSearched = {},
    -- The trace did not include MeshId/TextureId or asset-id arguments for
    -- Scythe/Ban Hammer. Paste exact model asset ids here if you have them.
    ExactAssetIds = {
        KATANA = "",
        SCYTHE = "",
        ["BAN HAMMER"] = "",
    },
    Original = {},
}

local function disconnectAll(list)
    for _, conn in ipairs(list) do
        if typeof(conn) == "RBXScriptConnection" then
            pcall(function() conn:Disconnect() end)
        end
    end
    table.clear(list)
end

local function make(className, props, parent)
    local inst = Instance.new(className)
    if props then
        for key, value in pairs(props) do
            inst[key] = value
        end
    end
    if parent then
        inst.Parent = parent
    end
    return inst
end

local function corner(parent, radius)
    return make("UICorner", {
        CornerRadius = UDim.new(0, radius or 8),
    }, parent)
end

local function stroke(parent, color, thickness, transparency)
    return make("UIStroke", {
        ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
        Color = color or COLORS.red,
        Thickness = thickness or 1,
        Transparency = transparency or 0.25,
    }, parent)
end

local function setPartSafe(part)
    if not part or not part:IsA("BasePart") then return end
    part.Anchored = false
    part.CanCollide = false
    part.CanTouch = false
    part.CanQuery = false
    part.Massless = true
end

local function weldToHandle(part, handle)
    if not part or not handle or not part:IsA("BasePart") or not handle:IsA("BasePart") then return end
    setPartSafe(part)
    local weld = Instance.new("WeldConstraint")
    weld.Name = "FlowerSkin_AssetWeld"
    weld.Part0 = handle
    weld.Part1 = part
    weld.Parent = part
end

local function findBat()
    local character = LocalPlayer.Character
    if character then
        local tool = character:FindFirstChild("Bat")
        if tool and tool:IsA("Tool") then
            return tool
        end
    end

    local backpack = LocalPlayer:FindFirstChildOfClass("Backpack")
    if backpack then
        local tool = backpack:FindFirstChild("Bat")
        if tool and tool:IsA("Tool") then
            return tool
        end
    end

    return nil
end

local function rememberOriginal(tool)
    if not tool then return end
    local handle = tool:FindFirstChild("Handle")
    local slash = tool:FindFirstChild("Slash")

    State.Original[tool] = State.Original[tool] or {}
    local original = State.Original[tool]

    if handle and handle:IsA("BasePart") and not original.Handle then
        original.Handle = {
            Transparency = handle.Transparency,
            LocalTransparencyModifier = handle.LocalTransparencyModifier,
            CastShadow = handle.CastShadow,
        }
    end

    if slash and slash:IsA("Sound") and not original.SlashSoundId then
        original.SlashSoundId = slash.SoundId
    end
end

local function captureKatanaTemplate()
    if State.OriginalKatanaTemplate then return end

    local function scan(container)
        if not container then return end
        local bat = container:FindFirstChild("Bat")
        if not bat then return end
        local folder = bat:FindFirstChild("FlowerSkin_KatanaRealistic")
        local asset = folder and folder:FindFirstChild("FlowerSkin_AssetKatana")
        if asset then
            State.OriginalKatanaTemplate = asset:Clone()
        end
    end

    scan(LocalPlayer:FindFirstChildOfClass("Backpack"))
    scan(LocalPlayer.Character)
end

local function hideOriginalHandle(tool, hidden)
    local handle = tool and tool:FindFirstChild("Handle")
    if not handle or not handle:IsA("BasePart") then return end

    rememberOriginal(tool)

    if hidden then
        handle.LocalTransparencyModifier = 1
        handle.Transparency = 1
        handle.CastShadow = false
    else
        local original = State.Original[tool] and State.Original[tool].Handle
        handle.LocalTransparencyModifier = original and original.LocalTransparencyModifier or 0
        handle.Transparency = original and original.Transparency or 0
        handle.CastShadow = original and original.CastShadow
        if handle.CastShadow == nil then
            handle.CastShadow = true
        end
    end
end

local function setSlashSound(tool, soundId)
    rememberOriginal(tool)
    local slash = tool and tool:FindFirstChild("Slash")
    if slash and slash:IsA("Sound") then
        slash.SoundId = soundId or ((State.Original[tool] and State.Original[tool].SlashSoundId) or slash.SoundId)
    end
end

local function removeSkin(tool)
    if not tool then return end

    local oldFolder = tool:FindFirstChild("FlowerSkin_KatanaRealistic")
    if oldFolder then
        oldFolder:Destroy()
    end

    local oldLoose = tool:FindFirstChild("FlowerSkin_AssetKatana")
    if oldLoose then
        oldLoose:Destroy()
    end

    hideOriginalHandle(tool, false)
    setSlashSound(tool, nil)
end

local function addRedVFX(parentPart)
    if not parentPart or not parentPart:IsA("BasePart") then return end

    local existing = parentPart:FindFirstChild("FlowerSkin_ExtraRedVFX")
    if existing then
        existing:Destroy()
    end

    local top = Instance.new("Attachment")
    top.Name = "FlowerSkin_ExtraRedVFX"
    top.Position = Vector3.new(0, parentPart.Size.Y * 0.5, 0)
    top.Parent = parentPart

    local bottom = Instance.new("Attachment")
    bottom.Name = "FlowerSkin_ExtraRedVFX_End"
    bottom.Position = Vector3.new(0, -parentPart.Size.Y * 0.5, 0)
    bottom.Parent = parentPart

    local trail = Instance.new("Trail")
    trail.Name = "FlowerSkin_ExtraRedVFX"
    trail.Attachment0 = top
    trail.Attachment1 = bottom
    trail.Color = ColorSequence.new({
        ColorSequenceKeypoint.new(0, COLORS.red2),
        ColorSequenceKeypoint.new(1, Color3.new(0.54902, 0, 0)),
    })
    trail.Transparency = NumberSequence.new({
        NumberSequenceKeypoint.new(0, 0.35),
        NumberSequenceKeypoint.new(1, 1),
    })
    trail.Lifetime = 0.18
    trail.LightEmission = 0.55
    trail.Parent = parentPart

    local emitter = Instance.new("ParticleEmitter")
    emitter.Name = "FlowerSkin_ExtraRedVFX"
    emitter.Color = ColorSequence.new({
        ColorSequenceKeypoint.new(0, Color3.new(0.784314, 0, 0)),
        ColorSequenceKeypoint.new(1, COLORS.red2),
    })
    emitter.LightEmission = 0.55
    emitter.Rate = 14
    emitter.Lifetime = NumberRange.new(0.25, 0.45)
    emitter.Speed = NumberRange.new(0.2, 0.7)
    emitter.SpreadAngle = Vector2.new(12, 12)
    emitter.Size = NumberSequence.new({
        NumberSequenceKeypoint.new(0, 0.08),
        NumberSequenceKeypoint.new(1, 0),
    })
    emitter.Texture = "rbxasset://textures/particles/sparkles_main.dds"
    emitter.Parent = parentPart
end

local function newPart(parent, name, size, offset, color, material)
    local part = Instance.new("Part")
    part.Name = name
    part.Size = size
    part.Color = color
    part.Material = material or Enum.Material.Neon
    part.TopSurface = Enum.SurfaceType.Smooth
    part.BottomSurface = Enum.SurfaceType.Smooth
    setPartSafe(part)
    part.Parent = parent
    return part, offset or CFrame.identity
end

-- =====================================================================
-- Exact mesh resolver
-- =====================================================================
local EXACT_TEMPLATE_NAMES = {
    KATANA = { "FlowerSkin_AssetKatana", "Katana", "FlowerSkin_KatanaRealistic" },
    SCYTHE = { "Scythe", "SCYTHE", "FlowerSkin_AssetScythe", "FlowerSkin_Scythe", "ScytheSkin" },
    ["BAN HAMMER"] = { "Ban Hammer", "BAN HAMMER", "BanHammer", "Hammer", "BanHammerTool", "FlowerSkin_BanHammer", "Tool" },
}

local function isScriptObject(inst)
    return inst:IsA("Script") or inst:IsA("LocalScript") or inst:IsA("ModuleScript")
end

local function stripScripts(root)
    if not root then return end
    if isScriptObject(root) then
        root:Destroy()
        return
    end
    for _, inst in ipairs(root:GetDescendants()) do
        if isScriptObject(inst) then
            inst:Destroy()
        end
    end
end

local function hasAnyBasePart(root)
    if not root then return false end
    if root:IsA("BasePart") then return true end
    return root:FindFirstChildWhichIsA("BasePart", true) ~= nil
end

local function isGeneratedProxy(root)
    local ok, value = pcall(function()
        return root:GetAttribute("ShadowBatSkinsGenerated")
    end)
    return ok and value == true
end

local function usableTemplate(root)
    if not root or isGeneratedProxy(root) then return nil end
    if root:IsA("Model") or root:IsA("Tool") or root:IsA("Folder") or root:IsA("BasePart") then
        if hasAnyBasePart(root) then
            return root
        end
    end
    return nil
end

local function findUsableNamed(root, names)
    if not root then return nil end

    for _, name in ipairs(names) do
        if root.Name == name then
            local direct = usableTemplate(root)
            if direct then return direct end
        end
    end

    for _, name in ipairs(names) do
        local found = root:FindFirstChild(name, true)
        local usable = usableTemplate(found)
        if usable then
            return usable
        end
    end

    return nil
end

local function assetTextFromId(assetId)
    local raw = tostring(assetId or ""):gsub("%s+", "")
    if raw == "" then return nil end
    if raw:match("^rbxassetid://") or raw:match("^rbxasset://") then
        return raw
    end
    if raw:match("^%d+$") then
        return "rbxassetid://" .. raw
    end
    return raw
end

local function loadExactTemplateFromAssetId(skinName)
    local assetText = assetTextFromId(State.ExactAssetIds[skinName])
    if not assetText then return nil end

    local loaded = {}
    pcall(function()
        loaded = game:GetObjects(assetText)
    end)

    if #loaded == 0 then
        local id = tostring(assetText):match("(%d+)")
        if id then
            pcall(function()
                table.insert(loaded, InsertService:LoadAsset(tonumber(id)))
            end)
        end
    end

    local names = EXACT_TEMPLATE_NAMES[skinName] or {}
    for _, root in ipairs(loaded) do
        local exact = findUsableNamed(root, names) or usableTemplate(root)
        if exact then
            local clone = exact:Clone()
            stripScripts(clone)
            return clone
        end
    end

    return nil
end

local function findExactTemplateInGame(skinName)
    local names = EXACT_TEMPLATE_NAMES[skinName]
    if not names then return nil end

    local containers = {
        LocalPlayer.Character,
        LocalPlayer:FindFirstChildOfClass("Backpack"),
        ReplicatedStorage,
        Lighting,
        workspace,
    }

    for _, container in ipairs(containers) do
        local source = findUsableNamed(container, names)
        if source then
            local clone = source:Clone()
            stripScripts(clone)
            return clone
        end
    end

    return nil
end

local function getExactTemplate(skinName)
    if skinName == "KATANA" and State.OriginalKatanaTemplate then
        return State.OriginalKatanaTemplate
    end

    if State.ExactTemplates[skinName] then
        return State.ExactTemplates[skinName]
    end

    if State.ExactTemplateSearched[skinName] then
        return nil
    end
    State.ExactTemplateSearched[skinName] = true

    local loaded = loadExactTemplateFromAssetId(skinName) or findExactTemplateInGame(skinName)
    if loaded then
        State.ExactTemplates[skinName] = loaded
    end
    return loaded
end

local function containerToModel(clone, folder)
    if clone:IsA("Model") then
        clone.Name = "FlowerSkin_AssetKatana"
        clone.Parent = folder
        return clone
    end

    if clone:IsA("BasePart") then
        local model = Instance.new("Model")
        model.Name = "FlowerSkin_AssetKatana"
        model.Parent = folder
        clone.Parent = model
        return model
    end

    if clone:IsA("Tool") or clone:IsA("Folder") then
        local nested = clone:FindFirstChild("FlowerSkin_AssetKatana")
            or clone:FindFirstChildWhichIsA("Model")
            or clone:FindFirstChildWhichIsA("BasePart")

        if nested and nested.Parent == clone then
            nested.Parent = nil
            clone:Destroy()
            return containerToModel(nested, folder)
        end

        local model = Instance.new("Model")
        model.Name = "FlowerSkin_AssetKatana"
        model.Parent = folder
        for _, child in ipairs(clone:GetChildren()) do
            if not isScriptObject(child) then
                child.Parent = model
            end
        end
        clone:Destroy()
        return model
    end

    return nil
end

local function applyExactMesh(tool, skinName)
    local handle = tool and tool:FindFirstChild("Handle")
    if not handle or not handle:IsA("BasePart") then return false end

    local template = getExactTemplate(skinName)
    if not template then
        return false
    end

    local folder = Instance.new("Folder")
    folder.Name = "FlowerSkin_KatanaRealistic"
    folder.Parent = tool

    local model = containerToModel(template:Clone(), folder)
    if not model or not hasAnyBasePart(model) then
        folder:Destroy()
        return false
    end

    stripScripts(model)
    pcall(function()
        model:SetAttribute("ShadowBatSkinsExactMesh", true)
    end)

    local firstPart = nil
    for _, inst in ipairs(model:GetDescendants()) do
        if inst:IsA("BasePart") then
            firstPart = firstPart or inst
            setPartSafe(inst)
        end
    end

    if not firstPart then
        folder:Destroy()
        return false
    end

    if model:IsA("Model") then
        model.PrimaryPart = model.PrimaryPart or firstPart
        pcall(function()
            -- Preserve the cloned mesh's internal offsets/scale, only move it onto the Bat handle.
            model:PivotTo(handle.CFrame)
        end)
    end

    for _, inst in ipairs(model:GetDescendants()) do
        if inst:IsA("BasePart") then
            weldToHandle(inst, handle)
        end
    end

    local vfxPart = model:FindFirstChild("SharpParts", true)
        or model:FindFirstChild("WeaponPart", true)
        or model:FindFirstChild("Handle", true)
        or firstPart
    if vfxPart and not vfxPart:FindFirstChild("FlowerSkin_ExtraRedVFX") then
        addRedVFX(vfxPart)
    end

    return true
end

local function buildProxyModel(tool, skinName)
    local handle = tool and tool:FindFirstChild("Handle")
    if not handle or not handle:IsA("BasePart") then return nil end

    local folder = Instance.new("Folder")
    folder.Name = "FlowerSkin_KatanaRealistic"
    folder.Parent = tool

    local model = Instance.new("Model")
    model.Name = "FlowerSkin_AssetKatana"
    model:SetAttribute("ShadowBatSkinsGenerated", true)
    model.Parent = folder

    local parts = {}
    local function add(name, size, offset, color, material)
        local part, cfOffset = newPart(model, name, size, offset, color, material)
        part.CFrame = handle.CFrame * cfOffset
        weldToHandle(part, handle)
        table.insert(parts, part)
        return part
    end

    if skinName == "SCYTHE" then
        add("Handle2", Vector3.new(0.18, 3.4, 0.18), CFrame.new(0, 0.2, 0), Color3.new(0.06, 0.06, 0.07), Enum.Material.Metal)
        local sharp = add("SharpParts", Vector3.new(2.4, 0.18, 0.42), CFrame.new(0.75, 1.55, 0) * CFrame.Angles(0, 0, math.rad(-25)), COLORS.red, Enum.Material.Neon)
        add("WeaponPart", Vector3.new(1.5, 0.16, 0.35), CFrame.new(1.15, 1.2, 0) * CFrame.Angles(0, 0, math.rad(32)), COLORS.red2, Enum.Material.Neon)
        add("NeonAccent", Vector3.new(0.35, 0.35, 0.35), CFrame.new(0, 1.25, 0), COLORS.gold, Enum.Material.Neon)
        addRedVFX(sharp)
    elseif skinName == "BAN HAMMER" then
        add("Handle2", Vector3.new(0.22, 3.2, 0.22), CFrame.new(0, 0.1, 0), Color3.new(0.08, 0.08, 0.09), Enum.Material.Metal)
        local head = add("WeaponPart", Vector3.new(1.8, 0.75, 0.75), CFrame.new(0, 1.55, 0), COLORS.red, Enum.Material.Neon)
        add("SharpParts", Vector3.new(2.15, 0.16, 0.9), CFrame.new(0, 1.55, 0), COLORS.gold, Enum.Material.Neon)
        add("NeonAccent", Vector3.new(0.35, 0.95, 0.95), CFrame.new(1.08, 1.55, 0), COLORS.red2, Enum.Material.Neon)
        addRedVFX(head)
    else -- KATANA fallback
        add("Handle2", Vector3.new(0.22, 1.0, 0.22), CFrame.new(0, -0.85, 0), Color3.new(0.04, 0.04, 0.045), Enum.Material.Metal)
        local sharp = add("SharpParts", Vector3.new(0.22, 3.35, 0.12), CFrame.new(0, 1.05, 0), COLORS.red2, Enum.Material.Neon)
        add("WeaponPart", Vector3.new(0.3, 2.7, 0.08), CFrame.new(0.08, 1.15, 0), COLORS.red, Enum.Material.Neon)
        add("NeonAccent", Vector3.new(0.75, 0.12, 0.42), CFrame.new(0, -0.28, 0), COLORS.gold, Enum.Material.Neon)
        addRedVFX(sharp)
    end

    model.PrimaryPart = parts[1]
    return model
end

local function applyTemplateKatana(tool)
    local handle = tool and tool:FindFirstChild("Handle")
    if not handle or not State.OriginalKatanaTemplate then
        return false
    end

    local folder = Instance.new("Folder")
    folder.Name = "FlowerSkin_KatanaRealistic"
    folder.Parent = tool

    local clone = State.OriginalKatanaTemplate:Clone()
    clone.Name = "FlowerSkin_AssetKatana"
    clone.Parent = folder

    for _, inst in ipairs(clone:GetDescendants()) do
        if inst:IsA("BasePart") then
            setPartSafe(inst)
            pcall(function()
                inst.CFrame = handle.CFrame
            end)
            weldToHandle(inst, handle)
        elseif inst:IsA("Script") or inst:IsA("LocalScript") then
            inst:Destroy()
        end
    end

    pcall(function()
        local _, size = clone:GetBoundingBox()
        local target = math.max(handle.Size.Y, 1)
        local current = math.max(size.Y, 1)
        clone:ScaleTo(math.clamp(target / current * 2.4, 0.35, 2.5))
        clone:PivotTo(handle.CFrame)
    end)

    local sharp = clone:FindFirstChild("SharpParts", true) or clone:FindFirstChildWhichIsA("BasePart", true)
    addRedVFX(sharp)
    return true
end

local SKIN_SOUND_IDS = {
    KATANA = "rbxassetid://111808555599832",
    SCYTHE = "rbxassetid://9113305311",
    ["BAN HAMMER"] = "rbxassetid://137964779511233",
}

local function applySkin(skinName)
    captureKatanaTemplate()

    local tool = findBat()
    if not tool then
        State.LastBat = nil
        State.LastAppliedSkin = nil
        return false, "Bat tool not found"
    end

    rememberOriginal(tool)
    removeSkin(tool)

    if skinName == "NONE" then
        State.LastBat = tool
        State.LastAppliedSkin = skinName
        return true
    end

    hideOriginalHandle(tool, true)
    setSlashSound(tool, SKIN_SOUND_IDS[skinName])

    -- Prefer the exact cloned mesh/template when it exists. The proxy model is
    -- only a fallback for traces where the mesh asset id was not captured.
    if not applyExactMesh(tool, skinName) then
        buildProxyModel(tool, skinName)
    end

    local handle = tool:FindFirstChild("Handle")
    if handle then
        local fire = handle:FindFirstChildOfClass("Fire") or handle:FindFirstChild("Fire")
        if fire and fire:IsA("Fire") then
            fire.Enabled = true
            fire.Color = COLORS.red
            fire.SecondaryColor = COLORS.red2
        end
    end

    State.LastBat = tool
    State.LastAppliedSkin = skinName
    return true
end

local function nextSkin()
    local index = table.find(State.SkinOrder, State.Skin) or 1
    State.Skin = State.SkinOrder[(index % #State.SkinOrder) + 1]
    applySkin(State.Skin)
    return State.Skin
end

-- =====================================================================
-- GUI reconstruction
-- =====================================================================

local function safeGuiParent(gui)
    local ok = pcall(function()
        gui.Parent = CoreGui
    end)
    if not ok or not gui.Parent then
        gui.Parent = PlayerGui
    end
end

local oldCore = CoreGui:FindFirstChild("ShadowBatSkins")
if oldCore then oldCore:Destroy() end
local oldPlayer = PlayerGui:FindFirstChild("ShadowBatSkins")
if oldPlayer then oldPlayer:Destroy() end
local oldBanner = PlayerGui:FindFirstChild("ShadowBatBanner")
if oldBanner then oldBanner:Destroy() end

local Gui = Instance.new("ScreenGui")
Gui.Name = "ShadowBatSkins"
Gui.ResetOnSpawn = false
Gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
safeGuiParent(Gui)

local Main = make("Frame", {
    Name = "Frame",
    Size = UDim2.new(0, 240, 0, 140),
    Position = UDim2.new(1, -248, 0, 8),
    BackgroundColor3 = COLORS.background,
    BackgroundTransparency = 0.05,
    BorderSizePixel = 0,
    ClipsDescendants = true,
    Active = true,
}, Gui)
corner(Main, 10)
local mainStroke = stroke(Main, COLORS.red, 1.5, 0.2)
local strokeGradient = make("UIGradient", {
    Color = ColorSequence.new({
        ColorSequenceKeypoint.new(0, COLORS.red),
        ColorSequenceKeypoint.new(0.35, COLORS.gold),
        ColorSequenceKeypoint.new(0.65, COLORS.red),
        ColorSequenceKeypoint.new(1, COLORS.gold),
    }),
    Rotation = 145,
}, mainStroke)
make("UIGradient", {
    Color = ColorSequence.new({
        ColorSequenceKeypoint.new(0, Color3.new(0.0705882, 0.0784314, 0.0862745)),
        ColorSequenceKeypoint.new(0.5, COLORS.background),
        ColorSequenceKeypoint.new(1, Color3.new(0.0313726, 0.0313726, 0.0392157)),
    }),
    Rotation = 145,
}, Main)

local Header = make("Frame", {
    Name = "Frame",
    Size = UDim2.new(1, 0, 0, 30),
    BackgroundColor3 = COLORS.header,
    BackgroundTransparency = 0.3,
    BorderSizePixel = 0,
    Active = true,
}, Main)

local Separator = make("Frame", {
    Name = "Divider",
    Size = UDim2.new(1, -16, 0, 1),
    Position = UDim2.new(0, 8, 0, 30),
    BackgroundColor3 = COLORS.red,
    BackgroundTransparency = 0.7,
    BorderSizePixel = 0,
}, Main)

local Title = make("TextLabel", {
    Name = "Title",
    Size = UDim2.new(1, -40, 1, 0),
    Position = UDim2.new(0, 12, 0, 0),
    BackgroundTransparency = 1,
    Text = "Shadow Bat Skins",
    Font = Enum.Font.GothamBlack,
    TextSize = 12,
    TextColor3 = COLORS.text,
    TextXAlignment = Enum.TextXAlignment.Left,
}, Header)

local MinimizeButton = make("TextButton", {
    Name = "TextButton",
    Size = UDim2.new(0, 22, 0, 22),
    Position = UDim2.new(1, -26, 0, 4),
    BackgroundColor3 = COLORS.darkButton,
    BackgroundTransparency = 0.5,
    Text = "-",
    TextColor3 = COLORS.dim,
    Font = Enum.Font.GothamBold,
    TextSize = 12,
    BorderSizePixel = 0,
    AutoButtonColor = false,
}, Header)
corner(MinimizeButton, 5)

local MiniClover = make("TextButton", {
    Name = "MiniClover",
    Size = UDim2.new(0, 40, 0, 40),
    Position = UDim2.new(1, -48, 0, 8),
    BackgroundColor3 = COLORS.mini,
    BackgroundTransparency = 0.1,
    Text = "S",
    TextColor3 = COLORS.red,
    Font = Enum.Font.GothamBlack,
    TextSize = 18,
    Visible = false,
    ZIndex = 200,
    BorderSizePixel = 0,
    AutoButtonColor = false,
}, Gui)
corner(MiniClover, 10)
stroke(MiniClover, COLORS.red, 1, 0.4)

local Section = make("Frame", {
    Name = "BatSkinsSection",
    Size = UDim2.new(1, -20, 0, 40),
    Position = UDim2.new(0, 10, 0, 38),
    BackgroundColor3 = COLORS.row,
    BorderSizePixel = 0,
}, Main)
corner(Section, 7)

local SectionLabel = make("TextLabel", {
    Name = "TextLabel",
    Size = UDim2.new(1, -60, 1, 0),
    Position = UDim2.new(0, 10, 0, 0),
    BackgroundTransparency = 1,
    Text = "Bat Skins",
    Font = Enum.Font.GothamBold,
    TextSize = 12,
    TextColor3 = COLORS.text,
    TextXAlignment = Enum.TextXAlignment.Left,
}, Section)

local Badge = make("Frame", {
    Name = "Badge",
    Size = UDim2.new(0, 80, 0, 22),
    Position = UDim2.new(1, -86, 0.5, -11),
    BackgroundColor3 = COLORS.button,
    BackgroundTransparency = 0.1,
    BorderSizePixel = 0,
}, Section)
corner(Badge, 11)
stroke(Badge, COLORS.red, 1, 0.65)

make("TextLabel", {
    Name = "TextLabel",
    Size = UDim2.new(1, 0, 1, 0),
    BackgroundTransparency = 1,
    Text = "/49UZyd92bH",
    Font = Enum.Font.GothamBold,
    TextSize = 10,
    TextColor3 = COLORS.dim,
    TextXAlignment = Enum.TextXAlignment.Center,
}, Badge)

local BadgeButton = make("TextButton", {
    Name = "TextButton",
    Size = UDim2.new(1, 0, 1, 0),
    BackgroundTransparency = 1,
    Text = "",
    ZIndex = 5,
}, Badge)

local SkinRow = make("Frame", {
    Name = "SkinRow",
    Size = UDim2.new(1, -20, 0, 40),
    Position = UDim2.new(0, 10, 0, 84),
    BackgroundColor3 = COLORS.row,
    BorderSizePixel = 0,
}, Main)
corner(SkinRow, 7)

local SkinLabel = make("TextLabel", {
    Name = "TextLabel",
    Size = UDim2.new(0, 45, 1, 0),
    Position = UDim2.new(0, 10, 0, 0),
    BackgroundTransparency = 1,
    Text = "Skin",
    Font = Enum.Font.GothamBold,
    TextSize = 12,
    TextColor3 = COLORS.text,
    TextXAlignment = Enum.TextXAlignment.Left,
}, SkinRow)

local SkinButton = make("TextButton", {
    Name = "TextButton",
    Size = UDim2.new(1, -70, 0, 28),
    Position = UDim2.new(0, 60, 0.5, -14),
    BackgroundColor3 = COLORS.button,
    Text = State.Skin,
    TextColor3 = COLORS.gold,
    TextSize = 10,
    Font = Enum.Font.GothamBlack,
    BorderSizePixel = 0,
    AutoButtonColor = false,
}, SkinRow)
corner(SkinButton, 7)
stroke(SkinButton, COLORS.red, 1, 0.5)

-- Small screen-space banner seen in the trace. Uses the traced image asset id if available.
local BannerGui = Instance.new("ScreenGui")
BannerGui.Name = "ShadowBatBanner"
BannerGui.ResetOnSpawn = false
BannerGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
BannerGui.Parent = PlayerGui

local Banner = make("ImageLabel", {
    Name = "ShadowBanner",
    Size = UDim2.new(0, 150, 0, 100),
    BackgroundTransparency = 1,
    Image = "rbxasset://58e6484d3029c34fd16300196472a4ee/cursed_banner.png",
    Visible = false,
}, BannerGui)

local BannerFallback = make("TextLabel", {
    Name = "FallbackText",
    Size = UDim2.new(1, 0, 0, 24),
    Position = UDim2.new(0, 0, 0.5, -12),
    BackgroundTransparency = 1,
    Text = "SHADOW",
    Font = Enum.Font.GothamBlack,
    TextSize = 16,
    TextColor3 = COLORS.red,
    TextStrokeTransparency = 0.35,
}, Banner)

local function refreshSkinButton()
    SkinButton.Text = State.Skin
    if State.Skin == "NONE" then
        SkinButton.TextColor3 = COLORS.dim
    elseif State.Skin == "BAN HAMMER" then
        SkinButton.TextColor3 = COLORS.red2
    elseif State.Skin == "SCYTHE" then
        SkinButton.TextColor3 = COLORS.red
    else
        SkinButton.TextColor3 = COLORS.gold
    end
end

local function setMinimized(value)
    State.Minimized = value and true or false
    Main.Visible = not State.Minimized
    MiniClover.Visible = State.Minimized
end

local function tweenButton(button, hover)
    local color = hover and Color3.new(0.2, 0.2, 0.235294) or COLORS.darkButton
    TweenService:Create(button, TweenInfo.new(0.12, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
        BackgroundColor3 = color,
        TextColor3 = hover and COLORS.text or COLORS.dim,
    }):Play()
end

MinimizeButton.MouseEnter:Connect(function() tweenButton(MinimizeButton, true) end)
MinimizeButton.MouseLeave:Connect(function() tweenButton(MinimizeButton, false) end)
MiniClover.MouseEnter:Connect(function()
    TweenService:Create(MiniClover, TweenInfo.new(0.12, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
        BackgroundColor3 = COLORS.darkButton,
    }):Play()
end)
MiniClover.MouseLeave:Connect(function()
    TweenService:Create(MiniClover, TweenInfo.new(0.12, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
        BackgroundColor3 = COLORS.mini,
    }):Play()
end)

MinimizeButton.MouseButton1Click:Connect(function()
    setMinimized(true)
end)
MiniClover.MouseButton1Click:Connect(function()
    setMinimized(false)
end)

BadgeButton.MouseButton1Click:Connect(function()
    if type(setclipboard) == "function" then
        pcall(setclipboard, "/49UZyd92bH")
    end
end)

SkinButton.MouseButton1Click:Connect(function()
    nextSkin()
    refreshSkinButton()
end)

local function makeDraggable(frame, handle)
    local dragging = false
    local dragStart = nil
    local startPos = nil
    local dragInput = nil

    handle.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
            dragging = true
            dragStart = input.Position
            startPos = frame.Position
            input.Changed:Connect(function()
                if input.UserInputState == Enum.UserInputState.End then
                    dragging = false
                end
            end)
        end
    end)

    handle.InputChanged:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch then
            dragInput = input
        end
    end)

    UserInputService.InputChanged:Connect(function(input)
        if input == dragInput and dragging then
            local delta = input.Position - dragStart
            frame.Position = UDim2.new(
                startPos.X.Scale,
                startPos.X.Offset + delta.X,
                startPos.Y.Scale,
                startPos.Y.Offset + delta.Y
            )
        end
    end)
end

makeDraggable(Main, Header)
makeDraggable(MiniClover, MiniClover)

UserInputService.InputBegan:Connect(function(input, gameProcessed)
    if gameProcessed then return end
    if input.KeyCode == Enum.KeyCode.RightControl then
        setMinimized(not State.Minimized)
    elseif input.KeyCode == Enum.KeyCode.K then
        nextSkin()
        refreshSkinButton()
    end
end)

RunService.RenderStepped:Connect(function(dt)
    strokeGradient.Rotation = (strokeGradient.Rotation + (dt * 60)) % 360

    local character = LocalPlayer.Character
    local root = character and character:FindFirstChild("HumanoidRootPart")
    local camera = workspace.CurrentCamera
    if root and camera and State.Skin ~= "NONE" then
        local screenPos, onScreen = camera:WorldToViewportPoint(root.Position + Vector3.new(0, 3, 0))
        Banner.Visible = onScreen
        if onScreen then
            Banner.Position = UDim2.new(0, screenPos.X - 75, 0, screenPos.Y - 50)
        end
    else
        Banner.Visible = false
    end
end)

LocalPlayer.CharacterAdded:Connect(function()
    task.wait(1)
    applySkin(State.Skin)
end)

-- Keep the cosmetic skin on the current Bat as it moves between Backpack/Character.
task.spawn(function()
    while Gui.Parent do
        local bat = findBat()
        if bat ~= State.LastBat or State.LastAppliedSkin ~= State.Skin then
            pcall(function()
                applySkin(State.Skin)
            end)
        end
        task.wait(0.5)
    end
end)

_G.CursedBatSkins = {
    Gui = Gui,
    BannerGui = BannerGui,
    State = State,
    SetExactAssetId = function(skinName, assetId)
        skinName = tostring(skinName or ""):upper()
        if skinName == "BANHAMMER" then skinName = "BAN HAMMER" end
        if not table.find(State.SkinOrder, skinName) or skinName == "NONE" then
            return false, "unknown skin"
        end
        State.ExactAssetIds[skinName] = tostring(assetId or "")
        State.ExactTemplateSearched[skinName] = nil
        State.ExactTemplates[skinName] = nil
        return true
    end,
    SetExactTemplate = function(skinName, instance)
        skinName = tostring(skinName or ""):upper()
        if skinName == "BANHAMMER" then skinName = "BAN HAMMER" end
        if not table.find(State.SkinOrder, skinName) or skinName == "NONE" then
            return false, "unknown skin"
        end
        local usable = usableTemplate(instance)
        if not usable then
            return false, "template needs a Model/Tool/Folder/BasePart with BaseParts"
        end
        State.ExactTemplates[skinName] = usable:Clone()
        State.ExactTemplateSearched[skinName] = true
        stripScripts(State.ExactTemplates[skinName])
        return true
    end,
    GetExactMeshStatus = function()
        return {
            AssetIds = State.ExactAssetIds,
            Cached = {
                KATANA = State.OriginalKatanaTemplate ~= nil or State.ExactTemplates.KATANA ~= nil,
                SCYTHE = State.ExactTemplates.SCYTHE ~= nil,
                ["BAN HAMMER"] = State.ExactTemplates["BAN HAMMER"] ~= nil,
            },
        }
    end,
    ApplySkin = function(skinName)
        skinName = tostring(skinName or State.Skin):upper()
        if skinName == "BANHAMMER" then skinName = "BAN HAMMER" end
        if not table.find(State.SkinOrder, skinName) then
            return false, "unknown skin"
        end
        State.Skin = skinName
        refreshSkinButton()
        return applySkin(State.Skin)
    end,
    NextSkin = function()
        local skin = nextSkin()
        refreshSkinButton()
        return skin
    end,
    ClearSkin = function()
        State.Skin = "NONE"
        refreshSkinButton()
        return applySkin("NONE")
    end,
    GetSkin = function()
        return State.Skin
    end,
    SetMinimized = setMinimized,
    Destroy = function()
        disconnectAll(State.Connections)
        if Gui then Gui:Destroy() end
        if BannerGui then BannerGui:Destroy() end
    end,
}

refreshSkinButton()
task.defer(function()
    applySkin(State.Skin)
end)
