--[[
================================================================================
    AuroraLib v4.0
    Premium Roblox UI Library
================================================================================
]]

local TweenService     = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")
local Players          = game:GetService("Players")
local CoreGui          = game:GetService("CoreGui")
local LocalPlayer      = Players.LocalPlayer

local Aurora        = {}
Aurora.__index      = Aurora
Aurora.Options      = {}
Aurora.ThemeObjs    = {}
Aurora.Scale        = 1.0
Aurora.LazyLoad     = true
Aurora.FadeIn       = true
Aurora.DelayPerTab  = 0.25
Aurora.DelayPerSection = 0.15
Aurora.DelayPerElement = 0.05
Aurora._globalElements = {}  -- Global element registry for search

-- ================================================================================
--  SCALING
-- ================================================================================
local SC = 1.0
local function s(n)  return math.max(1, math.floor(n * SC + 0.5)) end
local function ss(w,h) return UDim2.fromOffset(s(w), s(h)) end
local function sz(n) return UDim.new(0, s(n)) end
local function fs(n) return s(n) end

-- ================================================================================
--  ICON SYSTEM
-- ================================================================================
local _ICON_URLS = {
    solar     = "https://raw.githubusercontent.com/StyearX/Icons/refs/heads/main/solar/dist/Icons.lua",
    lucide    = "https://raw.githubusercontent.com/StyearX/Icons/refs/heads/main/lucide/dist/Icons.lua",
    gravity   = "https://raw.githubusercontent.com/StyearX/Icons/refs/heads/main/gravity/dist/Icons.lua",
    craft     = "https://raw.githubusercontent.com/StyearX/Icons/refs/heads/main/craft/dist/Icons.lua",
    geist     = "https://raw.githubusercontent.com/StyearX/Icons/refs/heads/main/geist/dist/Icons.lua",
    sfsymbols = "https://raw.githubusercontent.com/StyearX/Icons/refs/heads/main/sfsymbols/dist/Icons.lua",
}
local _ICON_CACHE  = {}
local _PACK_STATUS = {}

local function _loadPack(pack)
    if _PACK_STATUS[pack] then return end
    _PACK_STATUS[pack] = "loading"
    task.spawn(function()
        local url = _ICON_URLS[pack] or _ICON_URLS["solar"]
        local ok, res = pcall(function() return loadstring(game:HttpGet(url, true))() end)
        if ok and type(res) == "table" then
            _ICON_CACHE[pack] = res
            _PACK_STATUS[pack] = "ready"
        else
            _PACK_STATUS[pack] = "fail"
        end
    end)
end

function Aurora:GetIcon(iconStr)
    if not iconStr or iconStr == "" then return nil end
    local pack, name = iconStr:match("^(.-)%/(.+)$")
    if not pack then pack = "solar"; name = iconStr end
    if _PACK_STATUS[pack] ~= "ready" then _loadPack(pack); return nil end
    return _ICON_CACHE[pack] and _ICON_CACHE[pack][name]
end

local function applyIcon(imgLabel, iconStr, color)
    if not iconStr or iconStr == "" then return end
    local function tryApply()
        local asset = Aurora:GetIcon(iconStr)
        if asset and imgLabel and imgLabel.Parent then
            imgLabel.Image = tostring(asset)
            imgLabel.ImageColor3 = color or Color3.fromRGB(255,255,255)
            imgLabel.BackgroundTransparency = 1
        end
    end
    local pack = iconStr:match("^(.-)%/") or "solar"
    if _PACK_STATUS[pack] == "ready" then
        tryApply()
    else
        _loadPack(pack)
        task.spawn(function()
            local wait = 0.05
            local t0 = tick()
            while tick()-t0 < 8 do
                task.wait(wait)
                if _PACK_STATUS[pack] == "ready" then tryApply(); break end
                if _PACK_STATUS[pack] == "fail"  then break end
                wait = math.min(wait * 2, 0.8) -- exponential backoff
            end
        end)
    end
end

-- ================================================================================
--  UTILITIES
-- ================================================================================
local function triggerAutosave()
    if Aurora.SaveManager and Aurora.SaveManager.Autosave and Aurora.SaveManager.CurrentConfig then
        pcall(function() Aurora.SaveManager:Save(Aurora.SaveManager.CurrentConfig) end)
    end
end

local _tweenInfoCache = {}
local function _getTweenInfo(t, style, dir)
    local key = tostring(t).."_"..tostring(style).."_"..tostring(dir)
    if not _tweenInfoCache[key] then
        _tweenInfoCache[key] = TweenInfo.new(t, style, dir)
    end
    return _tweenInfoCache[key]
end
local function tw(obj, props, t, style, dir)
    t = t or 0.2; style = style or Enum.EasingStyle.Quad; dir = dir or Enum.EasingDirection.Out
    local tween = TweenService:Create(obj, _getTweenInfo(t, style, dir), props)
    tween:Play()
    return tween
end

local function make(class, props)
    local inst = Instance.new(class)
    if props then
        for k, v in pairs(props) do
            if k ~= "Parent" then pcall(function() inst[k] = v end) end
        end
        if props.Parent then inst.Parent = props.Parent end
    end
    return inst
end

-- Global element registry helper
local function _registerElement(title, frame, tabRef, subTabRef)
    if not title or title == "" or not frame or not tabRef then return end
    local entry = { title = title:lower(), displayTitle = title, frame = frame, tab = tabRef, subTab = subTabRef }
    table.insert(Aurora._globalElements, entry)
    frame.Destroying:Connect(function()
        for i, e in ipairs(Aurora._globalElements) do
            if e.frame == frame then table.remove(Aurora._globalElements, i); break end
        end
    end)
end

local function safeParent(gui)
    local ok = pcall(function()
        if syn and syn.protect_gui then syn.protect_gui(gui) end
        gui.Parent = CoreGui
    end)
    if not ok or not gui.Parent then
        pcall(function() gui.Parent = LocalPlayer:WaitForChild("PlayerGui") end)
    end
end

local function addVisibilityAPI(obj, frame)
    if not obj or not frame then return end
    obj.Frame = frame
    function obj:SetVisible(state)
        frame.Visible = state
    end
end

local function reg(obj, prop, key)
    table.insert(Aurora.ThemeObjs, { obj=obj, prop=prop, key=key })
    if Aurora.Theme then
        pcall(function()
            local val = Aurora.Theme[key]
            if key == "BackgroundImage" then
                if val and val ~= "" then
                    obj.Image = val
                    obj.Visible = true
                else
                    obj.Visible = false
                end
            elseif key == "BackgroundImageTransparency" then
                obj.ImageTransparency = val or 0
            else
                obj[prop] = val
            end
        end)
    end
end

local _tooltipGui, _tooltipFrame, _tooltipLbl, _tooltipStroke
local function _initTooltip()
    if _tooltipGui then return end
    _tooltipGui = make("ScreenGui", { Name="AuroraTooltip", ResetOnSpawn=false, DisplayOrder=100001 })
    safeParent(_tooltipGui)
    
    _tooltipFrame = make("Frame", {
        Size = UDim2.new(0, 0, 0, 0),
        AutomaticSize = Enum.AutomaticSize.XY,
        BackgroundColor3 = Aurora.Themes.Dark.Background,
        BackgroundTransparency = 0.1,
        Visible = false,
        Parent = _tooltipGui
    })
    make("UICorner", { CornerRadius = sz(9), Parent = _tooltipFrame })
    _tooltipStroke = make("UIStroke", { Color = Aurora.Themes.Dark.Border, Thickness = 1, Parent = _tooltipFrame })
    make("UIPadding", { PaddingTop = sz(4), PaddingBottom = sz(4), PaddingLeft = sz(8), PaddingRight = sz(8), Parent = _tooltipFrame })
    
    _tooltipLbl = make("TextLabel", {
        Size = UDim2.new(0, 0, 0, 0),
        AutomaticSize = Enum.AutomaticSize.XY,
        BackgroundTransparency = 1,
        TextColor3 = Aurora.Themes.Dark.Text,
        TextSize = fs(10),
        Font = Enum.Font.Gotham,
        TextXAlignment = Enum.TextXAlignment.Left,
        TextYAlignment = Enum.TextYAlignment.Center,
        TextWrapped = true,
        Parent = _tooltipFrame
    })
    make("UISizeConstraint", { MaxWidth = s(200), Parent = _tooltipLbl })

    reg(_tooltipFrame, "BackgroundColor3", "Background")
    reg(_tooltipStroke, "Color", "Border")
    reg(_tooltipLbl, "TextColor3", "Text")
end

local function addTooltip(frame, text)
    if not text or text == "" then return end
    _initTooltip()
    
    local mouseConnection
    frame.MouseEnter:Connect(function()
        _tooltipLbl.Text = text
        _tooltipFrame.Visible = true
        _tooltipFrame.BackgroundTransparency = 1
        _tooltipLbl.TextTransparency = 1
        _tooltipStroke.Transparency = 1
        
        tw(_tooltipFrame, { BackgroundTransparency = 0.1 }, 0.15)
        tw(_tooltipLbl, { TextTransparency = 0 }, 0.15)
        tw(_tooltipStroke, { Transparency = 0 }, 0.15)
        
        if mouseConnection then mouseConnection:Disconnect() end
        local mouse = LocalPlayer:GetMouse()
        mouseConnection = game:GetService("RunService").RenderStepped:Connect(function()
            local x, y = mouse.X, mouse.Y
            _tooltipFrame.Position = UDim2.new(0, x + 15, 0, y + 15)
        end)
    end)
    
    frame.MouseLeave:Connect(function()
        if mouseConnection then
            mouseConnection:Disconnect()
            mouseConnection = nil
        end
        _tooltipFrame.Visible = false
    end)
    
    frame.Destroying:Connect(function()
        if mouseConnection then mouseConnection:Disconnect() end
    end)
end

local function createAcrylic(frame)
    local camera = workspace.CurrentCamera
    if not camera then return nil end
    
    local dof = game:GetService("Lighting"):FindFirstChild("AuroraBlur")
    if not dof then
        dof = Instance.new("DepthOfFieldEffect")
        dof.Name = "AuroraBlur"
        dof.FarIntensity = 0
        dof.InFocusRadius = 0.1
        dof.NearIntensity = 1
        dof.Enabled = true
        dof.Parent = game:GetService("Lighting")
    end
    
    local part = Instance.new("Part")
    part.Name = "AuroraAcrylic"
    part.Color = Color3.fromRGB(0,0,0)
    part.Material = Enum.Material.Glass
    part.Size = Vector3.new(1, 1, 0)
    part.Anchored = true
    part.CanCollide = false
    part.Locked = true
    part.CastShadow = false
    part.Transparency = 0.98
    
    local mesh = Instance.new("SpecialMesh")
    mesh.MeshType = Enum.MeshType.Brick
    mesh.Offset = Vector3.new(0, 0, -0.000001)
    mesh.Parent = part
    
    part.Parent = camera
    
    local connections = {}
    local distance = 0.001
    
    local screenGui = frame:FindFirstAncestorOfClass("ScreenGui")
    
    local GuiService = game:GetService("GuiService")
    
    local function projectPoint(screenPos, dist)
        local ray = camera:ScreenPointToRay(screenPos.X, screenPos.Y)
        return ray.Origin + ray.Direction * dist
    end
    
    local function updatePosition()
        local cameraCF = camera.CFrame
        if not cameraCF then return end
        
        local visible = frame.Visible
        if visible and screenGui then
            visible = screenGui.Enabled
        end
        if frame.AbsoluteSize.X == 0 or frame.AbsoluteSize.Y == 0 then
            visible = false
        end
        
        part.Transparency = visible and 0.98 or 1
        if not visible then return end
        
        local absSize = frame.AbsoluteSize
        local absPos = frame.AbsolutePosition
        
        -- Dynamically resolve CornerRadius from a UICorner child
        local uiCorner = frame:FindFirstChildOfClass("UICorner")
        local radius = 16
        if uiCorner then
            if uiCorner.CornerRadius.Scale > 0 then
                radius = uiCorner.CornerRadius.Scale * math.min(absSize.X, absSize.Y)
            else
                radius = uiCorner.CornerRadius.Offset
            end
        end
        
        -- Use a safer inset coefficient (0.5) to ensure the 3D part's sharp corner is completely
        -- hidden within the rounded border of the UI.
        local inset = math.ceil(radius * 0.5)
        local topLeft = absPos + Vector2.new(inset, inset)
        local topRight = absPos + Vector2.new(absSize.X - inset, inset)
        local bottomRight = absPos + absSize - Vector2.new(inset, inset)
        
        local v = projectPoint(topLeft, distance)
        local w = projectPoint(topRight, distance)
        local x = projectPoint(bottomRight, distance)
        
        local width = (w - v).Magnitude
        local height = (w - x).Magnitude
        
        part.CFrame = CFrame.fromMatrix((v + x) / 2, cameraCF.XVector, cameraCF.YVector, cameraCF.ZVector)
        mesh.Scale = Vector3.new(width, height, 0.001)
    end
    
    table.insert(connections, camera:GetPropertyChangedSignal("CFrame"):Connect(updatePosition))
    table.insert(connections, camera:GetPropertyChangedSignal("ViewportSize"):Connect(updatePosition))
    table.insert(connections, camera:GetPropertyChangedSignal("FieldOfView"):Connect(updatePosition))
    table.insert(connections, frame:GetPropertyChangedSignal("AbsolutePosition"):Connect(updatePosition))
    table.insert(connections, frame:GetPropertyChangedSignal("AbsoluteSize"):Connect(updatePosition))
    table.insert(connections, frame:GetPropertyChangedSignal("Visible"):Connect(updatePosition))
    
    if screenGui then
        table.insert(connections, screenGui:GetPropertyChangedSignal("Enabled"):Connect(updatePosition))
    else
        task.spawn(function()
            while not screenGui do
                task.wait(0.1)
                screenGui = frame:FindFirstAncestorOfClass("ScreenGui")
            end
            table.insert(connections, screenGui:GetPropertyChangedSignal("Enabled"):Connect(updatePosition))
            updatePosition()
        end)
    end
    
    task.spawn(updatePosition)
    
    part.Destroying:Connect(function()
        for _, conn in ipairs(connections) do
            pcall(function() conn:Disconnect() end)
        end
    end)
    
    frame.Destroying:Connect(function()
        pcall(function() part:Destroy() end)
    end)
    
    return part
end

function Aurora:UpdateTheme()
    local dead = {}
    for i, e in ipairs(self.ThemeObjs) do
        local ok = pcall(function()
            if e.isCallback then
                e.callback()
            else
                -- Prune dead objects
                if not e.obj or (e.obj.ClassName ~= "" and not e.obj.Parent and not pcall(function() return e.obj.ClassName end)) then
                    table.insert(dead, i)
                    return
                end
                local val = self.Theme[e.key]
                if e.key == "BackgroundImage" then
                    if val and val ~= "" then
                        e.obj.Image = val
                        e.obj.Visible = true
                    else
                        e.obj.Visible = false
                    end
                elseif e.key == "BackgroundImageTransparency" then
                    e.obj.ImageTransparency = val or 0
                else
                    e.obj[e.prop] = val
                end
            end
        end)
        if not ok then table.insert(dead, i) end
    end
    -- Remove dead in reverse so indices stay valid
    for i = #dead, 1, -1 do
        table.remove(self.ThemeObjs, dead[i])
    end
end


local function hexToColor(hex)
    hex = hex:gsub("#", "")
    if #hex == 6 then
        local r = tonumber(hex:sub(1,2),16)
        local g = tonumber(hex:sub(3,4),16)
        local b = tonumber(hex:sub(5,6),16)
        if r and g and b then return Color3.fromRGB(r,g,b) end
    end
    return nil
end

local function colorToHex(color)
    return string.format("%02X%02X%02X",
        math.floor(color.R*255+.5),
        math.floor(color.G*255+.5),
        math.floor(color.B*255+.5))
end

-- ================================================================================
--  THEMES
-- ================================================================================
Aurora.Themes = {
    Dark = {
        Background   = Color3.fromRGB(10, 10, 13),
        Sidebar      = Color3.fromRGB(11, 11, 14),
        TopBar       = Color3.fromRGB(11, 11, 14),
        Element      = Color3.fromRGB(18, 18, 23),
        ElementHover = Color3.fromRGB(26, 26, 32),
        Accent       = Color3.fromRGB(220, 55, 55),
        AccentDim    = Color3.fromRGB(45, 15, 15),
        Text         = Color3.fromRGB(245, 245, 250),
        SubText      = Color3.fromRGB(140, 140, 158),
        Border       = Color3.fromRGB(35, 35, 44),
        Scrollbar    = Color3.fromRGB(55, 55, 68),
        ToggleOff    = Color3.fromRGB(32, 32, 42),
        ToggleOn     = Color3.fromRGB(220, 55, 55),
        SliderTrack  = Color3.fromRGB(28, 28, 36),
        SliderFill   = Color3.fromRGB(220, 55, 55),
        InputBG      = Color3.fromRGB(14, 14, 18),
        NotifBG      = Color3.fromRGB(14, 14, 18),
        TabActive    = Color3.fromRGB(245, 245, 250),
        TabInactive  = Color3.fromRGB(105, 105, 122),
        AlertInfo    = Color3.fromRGB(55, 135, 235),
        AlertWarn    = Color3.fromRGB(225, 155, 35),
        AlertError   = Color3.fromRGB(220, 55, 55),
        AlertSuccess = Color3.fromRGB(38, 195, 95),
        IconColor    = Color3.fromRGB(200, 200, 218),
    },
    Ocean = {
        Background   = Color3.fromRGB(10, 16, 26),
        Sidebar      = Color3.fromRGB(12, 19, 31),
        TopBar       = Color3.fromRGB(12, 19, 31),
        Element      = Color3.fromRGB(16, 26, 42),
        ElementHover = Color3.fromRGB(22, 36, 58),
        Accent       = Color3.fromRGB(0, 162, 255),
        AccentDim    = Color3.fromRGB(10, 40, 70),
        Text         = Color3.fromRGB(240, 245, 255),
        SubText      = Color3.fromRGB(130, 145, 175),
        Border       = Color3.fromRGB(30, 45, 70),
        Scrollbar    = Color3.fromRGB(40, 60, 90),
        ToggleOff    = Color3.fromRGB(24, 38, 60),
        ToggleOn     = Color3.fromRGB(0, 162, 255),
        SliderTrack  = Color3.fromRGB(20, 32, 50),
        SliderFill   = Color3.fromRGB(0, 162, 255),
        InputBG      = Color3.fromRGB(12, 20, 32),
        NotifBG      = Color3.fromRGB(12, 20, 32),
        TabActive    = Color3.fromRGB(240, 245, 255),
        TabInactive  = Color3.fromRGB(110, 125, 155),
        AlertInfo    = Color3.fromRGB(0, 162, 255),
        AlertWarn    = Color3.fromRGB(235, 160, 45),
        AlertError   = Color3.fromRGB(230, 60, 60),
        AlertSuccess = Color3.fromRGB(40, 200, 100),
        IconColor    = Color3.fromRGB(180, 195, 220),
    },
    RGB = {
        Background   = Color3.fromRGB(10, 10, 13),
        Sidebar      = Color3.fromRGB(11, 11, 14),
        TopBar       = Color3.fromRGB(11, 11, 14),
        Element      = Color3.fromRGB(18, 18, 23),
        ElementHover = Color3.fromRGB(26, 26, 32),
        Accent       = Color3.fromRGB(255, 0, 0),
        AccentDim    = Color3.fromRGB(45, 15, 15),
        Text         = Color3.fromRGB(245, 245, 250),
        SubText      = Color3.fromRGB(140, 140, 158),
        Border       = Color3.fromRGB(35, 35, 44),
        Scrollbar    = Color3.fromRGB(55, 55, 68),
        ToggleOff    = Color3.fromRGB(32, 32, 42),
        ToggleOn     = Color3.fromRGB(255, 0, 0),
        SliderTrack  = Color3.fromRGB(28, 28, 36),
        SliderFill   = Color3.fromRGB(255, 0, 0),
        InputBG      = Color3.fromRGB(14, 14, 18),
        NotifBG      = Color3.fromRGB(14, 14, 18),
        TabActive    = Color3.fromRGB(245, 245, 250),
        TabInactive  = Color3.fromRGB(105, 105, 122),
        AlertInfo    = Color3.fromRGB(55, 135, 235),
        AlertWarn    = Color3.fromRGB(225, 155, 35),
        AlertError   = Color3.fromRGB(220, 55, 55),
        AlertSuccess = Color3.fromRGB(38, 195, 95),
        IconColor    = Color3.fromRGB(200, 200, 218),
    },
    Amethyst = {
        Background   = Color3.fromRGB(10, 8, 14),
        Sidebar      = Color3.fromRGB(11, 9, 16),
        TopBar       = Color3.fromRGB(11, 9, 16),
        Element      = Color3.fromRGB(18, 14, 25),
        ElementHover = Color3.fromRGB(26, 20, 35),
        Accent       = Color3.fromRGB(160, 50, 240),
        AccentDim    = Color3.fromRGB(35, 15, 50),
        Text         = Color3.fromRGB(245, 240, 255),
        SubText      = Color3.fromRGB(150, 140, 170),
        Border       = Color3.fromRGB(38, 30, 50),
        Scrollbar    = Color3.fromRGB(60, 50, 80),
        ToggleOff    = Color3.fromRGB(34, 25, 45),
        ToggleOn     = Color3.fromRGB(160, 50, 240),
        SliderTrack  = Color3.fromRGB(30, 22, 40),
        SliderFill   = Color3.fromRGB(160, 50, 240),
        InputBG      = Color3.fromRGB(14, 10, 20),
        NotifBG      = Color3.fromRGB(14, 10, 20),
        TabActive    = Color3.fromRGB(245, 240, 255),
        TabInactive  = Color3.fromRGB(110, 100, 130),
        AlertInfo    = Color3.fromRGB(160, 50, 240),
        AlertWarn    = Color3.fromRGB(225, 155, 35),
        AlertError   = Color3.fromRGB(220, 55, 55),
        AlertSuccess = Color3.fromRGB(38, 195, 95),
        IconColor    = Color3.fromRGB(210, 195, 230),
    },
    Neon = {
        Background   = Color3.fromRGB(5, 12, 10),
        Sidebar      = Color3.fromRGB(6, 14, 12),
        TopBar       = Color3.fromRGB(6, 14, 12),
        Element      = Color3.fromRGB(10, 22, 18),
        ElementHover = Color3.fromRGB(14, 30, 24),
        Accent       = Color3.fromRGB(0, 255, 170),
        AccentDim    = Color3.fromRGB(10, 45, 35),
        Text         = Color3.fromRGB(240, 255, 250),
        SubText      = Color3.fromRGB(130, 160, 150),
        Border       = Color3.fromRGB(25, 50, 42),
        Scrollbar    = Color3.fromRGB(40, 80, 68),
        ToggleOff    = Color3.fromRGB(20, 40, 34),
        ToggleOn     = Color3.fromRGB(0, 255, 170),
        SliderTrack  = Color3.fromRGB(15, 30, 26),
        SliderFill   = Color3.fromRGB(0, 255, 170),
        InputBG      = Color3.fromRGB(8, 18, 14),
        NotifBG      = Color3.fromRGB(8, 18, 14),
        TabActive    = Color3.fromRGB(240, 255, 250),
        TabInactive  = Color3.fromRGB(110, 135, 125),
        AlertInfo    = Color3.fromRGB(0, 170, 255),
        AlertWarn    = Color3.fromRGB(225, 155, 35),
        AlertError   = Color3.fromRGB(220, 55, 55),
        AlertSuccess = Color3.fromRGB(0, 255, 170),
        IconColor    = Color3.fromRGB(190, 220, 210),
    },
    BloodRed = {
        Background   = Color3.fromRGB(12, 6, 6),
        Sidebar      = Color3.fromRGB(14, 7, 7),
        TopBar       = Color3.fromRGB(14, 7, 7),
        Element      = Color3.fromRGB(22, 10, 10),
        ElementHover = Color3.fromRGB(30, 14, 14),
        Accent       = Color3.fromRGB(255, 30, 30),
        AccentDim    = Color3.fromRGB(50, 10, 10),
        Text         = Color3.fromRGB(255, 240, 240),
        SubText      = Color3.fromRGB(170, 130, 130),
        Border       = Color3.fromRGB(45, 20, 20),
        Scrollbar    = Color3.fromRGB(75, 30, 30),
        ToggleOff    = Color3.fromRGB(35, 15, 15),
        ToggleOn     = Color3.fromRGB(255, 30, 30),
        SliderTrack  = Color3.fromRGB(28, 12, 12),
        SliderFill   = Color3.fromRGB(255, 30, 30),
        InputBG      = Color3.fromRGB(16, 8, 8),
        NotifBG      = Color3.fromRGB(16, 8, 8),
        TabActive    = Color3.fromRGB(255, 240, 240),
        TabInactive  = Color3.fromRGB(140, 105, 105),
        AlertInfo    = Color3.fromRGB(55, 135, 235),
        AlertWarn    = Color3.fromRGB(225, 155, 35),
        AlertError   = Color3.fromRGB(255, 30, 30),
        AlertSuccess = Color3.fromRGB(38, 195, 95),
        IconColor    = Color3.fromRGB(230, 190, 190),
        BackgroundImage = "rbxassetid://121343473918667",
        BackgroundImageTransparency = 0.15,
    },
    Midnight = {
        Background   = Color3.fromRGB(6, 6, 8),
        Sidebar      = Color3.fromRGB(8, 8, 10),
        TopBar       = Color3.fromRGB(8, 8, 10),
        Element      = Color3.fromRGB(14, 14, 18),
        ElementHover = Color3.fromRGB(20, 20, 26),
        Accent       = Color3.fromRGB(45, 110, 235),
        AccentDim    = Color3.fromRGB(15, 35, 75),
        Text         = Color3.fromRGB(245, 245, 250),
        SubText      = Color3.fromRGB(130, 130, 145),
        Border       = Color3.fromRGB(30, 30, 38),
        Scrollbar    = Color3.fromRGB(48, 48, 60),
        ToggleOff    = Color3.fromRGB(24, 24, 32),
        ToggleOn     = Color3.fromRGB(45, 110, 235),
        SliderTrack  = Color3.fromRGB(20, 20, 28),
        SliderFill   = Color3.fromRGB(45, 110, 235),
        InputBG      = Color3.fromRGB(10, 10, 14),
        NotifBG      = Color3.fromRGB(10, 10, 14),
        TabActive    = Color3.fromRGB(245, 245, 250),
        TabInactive  = Color3.fromRGB(100, 100, 115),
        AlertInfo    = Color3.fromRGB(45, 110, 235),
        AlertWarn    = Color3.fromRGB(225, 155, 35),
        AlertError   = Color3.fromRGB(220, 55, 55),
        AlertSuccess = Color3.fromRGB(38, 195, 95),
        IconColor    = Color3.fromRGB(190, 190, 205),
    },
    NeonCyber = {
        Background   = Color3.fromRGB(5, 10, 5),
        Sidebar      = Color3.fromRGB(3, 8, 3),
        TopBar       = Color3.fromRGB(3, 8, 3),
        Element      = Color3.fromRGB(10, 22, 10),
        ElementHover = Color3.fromRGB(15, 30, 15),
        Accent       = Color3.fromRGB(57, 255, 20),
        AccentDim    = Color3.fromRGB(10, 45, 15),
        Text         = Color3.fromRGB(200, 255, 190),
        SubText      = Color3.fromRGB(80, 200, 60),
        Border       = Color3.fromRGB(25, 60, 15),
        Scrollbar    = Color3.fromRGB(20, 50, 15),
        ToggleOff    = Color3.fromRGB(8, 18, 8),
        ToggleOn     = Color3.fromRGB(57, 255, 20),
        SliderTrack  = Color3.fromRGB(6, 14, 6),
        SliderFill   = Color3.fromRGB(57, 255, 20),
        InputBG      = Color3.fromRGB(8, 18, 8),
        NotifBG      = Color3.fromRGB(5, 12, 5),
        TabActive    = Color3.fromRGB(200, 255, 190),
        TabInactive  = Color3.fromRGB(80, 200, 60),
        AlertInfo    = Color3.fromRGB(57, 255, 20),
        AlertWarn    = Color3.fromRGB(225, 155, 35),
        AlertError   = Color3.fromRGB(220, 55, 55),
        AlertSuccess = Color3.fromRGB(57, 255, 20),
        IconColor    = Color3.fromRGB(150, 230, 140),
    },
    ArcticFrost = {
        Background   = Color3.fromRGB(210, 235, 250),
        Sidebar      = Color3.fromRGB(185, 215, 235),
        TopBar       = Color3.fromRGB(185, 215, 235),
        Element      = Color3.fromRGB(225, 242, 255),
        ElementHover = Color3.fromRGB(200, 228, 248),
        Accent       = Color3.fromRGB(100, 180, 240),
        AccentDim    = Color3.fromRGB(140, 185, 218),
        Text         = Color3.fromRGB(20, 40, 70),
        SubText      = Color3.fromRGB(65, 105, 148),
        Border       = Color3.fromRGB(170, 200, 225),
        Scrollbar    = Color3.fromRGB(150, 180, 200),
        ToggleOff    = Color3.fromRGB(190, 215, 230),
        ToggleOn     = Color3.fromRGB(100, 180, 240),
        SliderTrack  = Color3.fromRGB(180, 205, 220),
        SliderFill   = Color3.fromRGB(100, 180, 240),
        InputBG      = Color3.fromRGB(220, 240, 255),
        NotifBG      = Color3.fromRGB(210, 235, 250),
        TabActive    = Color3.fromRGB(20, 40, 70),
        TabInactive  = Color3.fromRGB(65, 105, 148),
        AlertInfo    = Color3.fromRGB(100, 180, 240),
        AlertWarn    = Color3.fromRGB(225, 155, 35),
        AlertError   = Color3.fromRGB(220, 55, 55),
        AlertSuccess = Color3.fromRGB(38, 195, 95),
        IconColor    = Color3.fromRGB(60, 120, 180),
    },
    CottonCandy = {
        Background   = Color3.fromRGB(255, 225, 245),
        Sidebar      = Color3.fromRGB(255, 200, 235),
        TopBar       = Color3.fromRGB(255, 200, 235),
        Element      = Color3.fromRGB(255, 235, 250),
        ElementHover = Color3.fromRGB(235, 210, 255),
        Accent       = Color3.fromRGB(255, 130, 190),
        AccentDim    = Color3.fromRGB(235, 170, 215),
        Text         = Color3.fromRGB(75, 25, 55),
        SubText      = Color3.fromRGB(145, 75, 115),
        Border       = Color3.fromRGB(230, 165, 210),
        Scrollbar    = Color3.fromRGB(220, 155, 200),
        ToggleOff    = Color3.fromRGB(240, 190, 225),
        ToggleOn     = Color3.fromRGB(255, 130, 190),
        SliderTrack  = Color3.fromRGB(230, 180, 215),
        SliderFill   = Color3.fromRGB(255, 130, 190),
        InputBG      = Color3.fromRGB(255, 238, 252),
        NotifBG      = Color3.fromRGB(255, 225, 245),
        TabActive    = Color3.fromRGB(75, 25, 55),
        TabInactive  = Color3.fromRGB(145, 75, 115),
        AlertInfo    = Color3.fromRGB(255, 130, 190),
        AlertWarn    = Color3.fromRGB(225, 155, 35),
        AlertError   = Color3.fromRGB(220, 55, 55),
        AlertSuccess = Color3.fromRGB(38, 195, 95),
        IconColor    = Color3.fromRGB(195, 100, 155),
    },
    Orange = {
        Background   = Color3.fromRGB(4, 4, 4),
        Sidebar      = Color3.fromRGB(10, 5, 0),
        TopBar       = Color3.fromRGB(10, 5, 0),
        Element      = Color3.fromRGB(22, 10, 2),
        ElementHover = Color3.fromRGB(30, 14, 2),
        Accent       = Color3.fromRGB(255, 140, 30),
        AccentDim    = Color3.fromRGB(80, 35, 5),
        Text         = Color3.fromRGB(255, 240, 220),
        SubText      = Color3.fromRGB(220, 175, 130),
        Border       = Color3.fromRGB(80, 35, 5),
        Scrollbar    = Color3.fromRGB(70, 30, 5),
        ToggleOff    = Color3.fromRGB(18, 8, 2),
        ToggleOn     = Color3.fromRGB(255, 140, 30),
        SliderTrack  = Color3.fromRGB(14, 6, 1),
        SliderFill   = Color3.fromRGB(255, 140, 30),
        InputBG      = Color3.fromRGB(18, 8, 2),
        NotifBG      = Color3.fromRGB(6, 3, 0),
        TabActive    = Color3.fromRGB(255, 240, 220),
        TabInactive  = Color3.fromRGB(220, 175, 130),
        AlertInfo    = Color3.fromRGB(255, 140, 30),
        AlertWarn    = Color3.fromRGB(225, 155, 35),
        AlertError   = Color3.fromRGB(220, 55, 55),
        AlertSuccess = Color3.fromRGB(38, 195, 95),
        IconColor    = Color3.fromRGB(210, 120, 30),
        BackgroundImage = "rbxassetid://122033436660262",
        BackgroundImageTransparency = 0.05,
    },
    Cyanic = {
        Background   = Color3.fromRGB(8, 18, 22),
        Sidebar      = Color3.fromRGB(8, 25, 32),
        TopBar       = Color3.fromRGB(8, 25, 32),
        Element      = Color3.fromRGB(14, 38, 46),
        ElementHover = Color3.fromRGB(20, 48, 58),
        Accent       = Color3.fromRGB(57, 197, 187),
        AccentDim    = Color3.fromRGB(35, 155, 150),
        Text         = Color3.fromRGB(210, 248, 246),
        SubText      = Color3.fromRGB(130, 210, 205),
        Border       = Color3.fromRGB(35, 155, 150),
        Scrollbar    = Color3.fromRGB(30, 120, 115),
        ToggleOff    = Color3.fromRGB(10, 28, 35),
        ToggleOn     = Color3.fromRGB(57, 197, 187),
        SliderTrack  = Color3.fromRGB(8, 22, 28),
        SliderFill   = Color3.fromRGB(57, 197, 187),
        InputBG      = Color3.fromRGB(10, 28, 35),
        NotifBG      = Color3.fromRGB(8, 22, 28),
        TabActive    = Color3.fromRGB(210, 248, 246),
        TabInactive  = Color3.fromRGB(130, 210, 205),
        AlertInfo    = Color3.fromRGB(57, 197, 187),
        AlertWarn    = Color3.fromRGB(225, 155, 35),
        AlertError   = Color3.fromRGB(220, 55, 55),
        AlertSuccess = Color3.fromRGB(38, 195, 95),
        IconColor    = Color3.fromRGB(45, 170, 160),
        BackgroundImage = "rbxassetid://95656189244173",
        BackgroundImageTransparency = 0.12,
    },
    AmberGlow = {
        Background   = Color3.fromRGB(18, 10, 4),
        Sidebar      = Color3.fromRGB(12, 6, 1),
        TopBar       = Color3.fromRGB(12, 6, 1),
        Element      = Color3.fromRGB(38, 20, 5),
        ElementHover = Color3.fromRGB(50, 25, 5),
        Accent       = Color3.fromRGB(255, 170, 40),
        AccentDim    = Color3.fromRGB(185, 120, 25),
        Text         = Color3.fromRGB(255, 245, 225),
        SubText      = Color3.fromRGB(230, 195, 145),
        Border       = Color3.fromRGB(185, 120, 25),
        Scrollbar    = Color3.fromRGB(140, 88, 18),
        ToggleOff    = Color3.fromRGB(28, 14, 3),
        ToggleOn     = Color3.fromRGB(255, 170, 40),
        SliderTrack  = Color3.fromRGB(20, 10, 2),
        SliderFill   = Color3.fromRGB(255, 170, 40),
        InputBG      = Color3.fromRGB(28, 14, 3),
        NotifBG      = Color3.fromRGB(18, 9, 2),
        TabActive    = Color3.fromRGB(255, 245, 225),
        TabInactive  = Color3.fromRGB(230, 195, 145),
        AlertInfo    = Color3.fromRGB(255, 170, 40),
        AlertWarn    = Color3.fromRGB(225, 155, 35),
        AlertError   = Color3.fromRGB(220, 55, 55),
        AlertSuccess = Color3.fromRGB(38, 195, 95),
        IconColor    = Color3.fromRGB(220, 140, 30),
        BackgroundImage = "rbxassetid://107795771598485",
        BackgroundImageTransparency = 0.12,
    },
    DeepViolet = {
        Background   = Color3.fromRGB(20, 20, 20),
        Sidebar      = Color3.fromRGB(40, 25, 65),
        TopBar       = Color3.fromRGB(40, 25, 65),
        Element      = Color3.fromRGB(60, 45, 80),
        ElementHover = Color3.fromRGB(85, 57, 139),
        Accent       = Color3.fromRGB(160, 120, 220),
        AccentDim    = Color3.fromRGB(110, 90, 130),
        Text         = Color3.fromRGB(240, 240, 240),
        SubText      = Color3.fromRGB(170, 170, 170),
        Border       = Color3.fromRGB(110, 90, 130),
        Scrollbar    = Color3.fromRGB(90, 70, 110),
        ToggleOff    = Color3.fromRGB(50, 35, 70),
        ToggleOn     = Color3.fromRGB(160, 120, 220),
        SliderTrack  = Color3.fromRGB(40, 28, 55),
        SliderFill   = Color3.fromRGB(160, 120, 220),
        InputBG      = Color3.fromRGB(70, 55, 85),
        NotifBG      = Color3.fromRGB(60, 45, 80),
        TabActive    = Color3.fromRGB(240, 240, 240),
        TabInactive  = Color3.fromRGB(170, 170, 170),
        AlertInfo    = Color3.fromRGB(160, 120, 220),
        AlertWarn    = Color3.fromRGB(225, 155, 35),
        AlertError   = Color3.fromRGB(220, 55, 55),
        AlertSuccess = Color3.fromRGB(38, 195, 95),
        IconColor    = Color3.fromRGB(130, 90, 180),
        BackgroundImage = "rbxassetid://136310484943077",
        BackgroundImageTransparency = 0.15,
    },
    Charcoal = {
        Background   = Color3.fromRGB(20, 20, 20),
        Sidebar      = Color3.fromRGB(15, 15, 15),
        TopBar       = Color3.fromRGB(15, 15, 15),
        Element      = Color3.fromRGB(35, 35, 35),
        ElementHover = Color3.fromRGB(45, 45, 45),
        Accent       = Color3.fromRGB(102, 102, 102),
        AccentDim    = Color3.fromRGB(60, 60, 60),
        Text         = Color3.fromRGB(240, 240, 240),
        SubText      = Color3.fromRGB(170, 170, 170),
        Border       = Color3.fromRGB(60, 60, 60),
        Scrollbar    = Color3.fromRGB(50, 50, 50),
        ToggleOff    = Color3.fromRGB(25, 25, 25),
        ToggleOn     = Color3.fromRGB(102, 102, 102),
        SliderTrack  = Color3.fromRGB(20, 20, 20),
        SliderFill   = Color3.fromRGB(102, 102, 102),
        InputBG      = Color3.fromRGB(25, 25, 25),
        NotifBG      = Color3.fromRGB(20, 20, 20),
        TabActive    = Color3.fromRGB(240, 240, 240),
        TabInactive  = Color3.fromRGB(170, 170, 170),
        AlertInfo    = Color3.fromRGB(102, 102, 102),
        AlertWarn    = Color3.fromRGB(225, 155, 35),
        AlertError   = Color3.fromRGB(220, 55, 55),
        AlertSuccess = Color3.fromRGB(38, 195, 95),
        IconColor    = Color3.fromRGB(130, 130, 130),
    },
    PearlWhite = {
        Background   = Color3.fromRGB(240, 240, 240),
        Sidebar      = Color3.fromRGB(220, 220, 220),
        TopBar       = Color3.fromRGB(220, 220, 220),
        Element      = Color3.fromRGB(230, 230, 230),
        ElementHover = Color3.fromRGB(210, 210, 210),
        Accent       = Color3.fromRGB(60, 160, 255),
        AccentDim    = Color3.fromRGB(200, 200, 200),
        Text         = Color3.fromRGB(20, 20, 20),
        SubText      = Color3.fromRGB(90, 90, 90),
        Border       = Color3.fromRGB(200, 200, 200),
        Scrollbar    = Color3.fromRGB(180, 180, 180),
        ToggleOff    = Color3.fromRGB(240, 240, 240),
        ToggleOn     = Color3.fromRGB(60, 160, 255),
        SliderTrack  = Color3.fromRGB(210, 210, 210),
        SliderFill   = Color3.fromRGB(60, 160, 255),
        InputBG      = Color3.fromRGB(240, 240, 240),
        NotifBG      = Color3.fromRGB(230, 230, 230),
        TabActive    = Color3.fromRGB(20, 20, 20),
        TabInactive  = Color3.fromRGB(90, 90, 90),
        AlertInfo    = Color3.fromRGB(60, 160, 255),
        AlertWarn    = Color3.fromRGB(225, 155, 35),
        AlertError   = Color3.fromRGB(220, 55, 55),
        AlertSuccess = Color3.fromRGB(38, 195, 95),
        IconColor    = Color3.fromRGB(80, 150, 210),
    },
    Galaxy = {
        Background   = Color3.fromRGB(12, 5, 25),
        Sidebar      = Color3.fromRGB(8, 3, 20),
        TopBar       = Color3.fromRGB(8, 3, 20),
        Element      = Color3.fromRGB(112, 40, 170),
        ElementHover = Color3.fromRGB(130, 50, 195),
        Accent       = Color3.fromRGB(160, 60, 220),
        AccentDim    = Color3.fromRGB(120, 40, 185),
        Text         = Color3.fromRGB(242, 232, 255),
        SubText      = Color3.fromRGB(200, 178, 228),
        Border       = Color3.fromRGB(120, 40, 185),
        Scrollbar    = Color3.fromRGB(95, 30, 140),
        ToggleOff    = Color3.fromRGB(48, 18, 85),
        ToggleOn     = Color3.fromRGB(160, 60, 220),
        SliderTrack  = Color3.fromRGB(35, 12, 60),
        SliderFill   = Color3.fromRGB(160, 60, 220),
        InputBG      = Color3.fromRGB(100, 35, 152),
        NotifBG      = Color3.fromRGB(8, 3, 20),
        TabActive    = Color3.fromRGB(242, 232, 255),
        TabInactive  = Color3.fromRGB(200, 178, 228),
        AlertInfo    = Color3.fromRGB(160, 60, 220),
        AlertWarn    = Color3.fromRGB(225, 155, 35),
        AlertError   = Color3.fromRGB(220, 55, 55),
        AlertSuccess = Color3.fromRGB(38, 195, 95),
        IconColor    = Color3.fromRGB(140, 80, 195),
    },
    AMOLED = {
        Background   = Color3.fromRGB(0, 0, 0),
        Sidebar      = Color3.fromRGB(10, 10, 10),
        TopBar       = Color3.fromRGB(10, 10, 10),
        Element      = Color3.fromRGB(15, 15, 15),
        ElementHover = Color3.fromRGB(22, 22, 22),
        Accent       = Color3.fromRGB(255, 255, 255),
        AccentDim    = Color3.fromRGB(50, 50, 50),
        Text         = Color3.fromRGB(255, 255, 255),
        SubText      = Color3.fromRGB(150, 150, 150),
        Border       = Color3.fromRGB(20, 20, 20),
        Scrollbar    = Color3.fromRGB(30, 30, 30),
        ToggleOff    = Color3.fromRGB(25, 25, 25),
        ToggleOn     = Color3.fromRGB(255, 255, 255),
        SliderTrack  = Color3.fromRGB(30, 30, 30),
        SliderFill   = Color3.fromRGB(255, 255, 255),
        InputBG      = Color3.fromRGB(12, 12, 12),
        NotifBG      = Color3.fromRGB(10, 10, 10),
        TabActive    = Color3.fromRGB(255, 255, 255),
        TabInactive  = Color3.fromRGB(150, 150, 150),
        AlertInfo    = Color3.fromRGB(255, 255, 255),
        AlertWarn    = Color3.fromRGB(225, 155, 35),
        AlertError   = Color3.fromRGB(220, 55, 55),
        AlertSuccess = Color3.fromRGB(38, 195, 95),
        IconColor    = Color3.fromRGB(200, 200, 200),
        BackgroundImage = "rbxassetid://134736124666311",
        BackgroundImageTransparency = 0.05,
    },
    AshGray = {
        Background   = Color3.fromRGB(45, 45, 45),
        Sidebar      = Color3.fromRGB(60, 60, 60),
        TopBar       = Color3.fromRGB(60, 60, 60),
        Element      = Color3.fromRGB(80, 80, 80),
        ElementHover = Color3.fromRGB(95, 95, 95),
        Accent       = Color3.fromRGB(150, 150, 150),
        AccentDim    = Color3.fromRGB(110, 110, 110),
        Text         = Color3.fromRGB(240, 240, 240),
        SubText      = Color3.fromRGB(170, 170, 170),
        Border       = Color3.fromRGB(90, 90, 90),
        Scrollbar    = Color3.fromRGB(110, 110, 110),
        ToggleOff    = Color3.fromRGB(55, 55, 55),
        ToggleOn     = Color3.fromRGB(150, 150, 150),
        SliderTrack  = Color3.fromRGB(65, 65, 65),
        SliderFill   = Color3.fromRGB(150, 150, 150),
        InputBG      = Color3.fromRGB(55, 55, 55),
        NotifBG      = Color3.fromRGB(45, 45, 45),
        TabActive    = Color3.fromRGB(240, 240, 240),
        TabInactive  = Color3.fromRGB(170, 170, 170),
        AlertInfo    = Color3.fromRGB(150, 150, 150),
        AlertWarn    = Color3.fromRGB(225, 155, 35),
        AlertError   = Color3.fromRGB(220, 55, 55),
        AlertSuccess = Color3.fromRGB(38, 195, 95),
        IconColor    = Color3.fromRGB(180, 180, 180),
    },
    NeonPurple = {
        Background   = Color3.fromRGB(5, 0, 15),
        Sidebar      = Color3.fromRGB(15, 0, 35),
        TopBar       = Color3.fromRGB(15, 0, 35),
        Element      = Color3.fromRGB(30, 0, 65),
        ElementHover = Color3.fromRGB(45, 0, 100),
        Accent       = Color3.fromRGB(180, 0, 255),
        AccentDim    = Color3.fromRGB(90, 0, 140),
        Text         = Color3.fromRGB(252, 245, 255),
        SubText      = Color3.fromRGB(210, 185, 255),
        Border       = Color3.fromRGB(140, 0, 255),
        Scrollbar    = Color3.fromRGB(100, 0, 180),
        ToggleOff    = Color3.fromRGB(20, 0, 45),
        ToggleOn     = Color3.fromRGB(180, 0, 255),
        SliderTrack  = Color3.fromRGB(25, 0, 55),
        SliderFill   = Color3.fromRGB(180, 0, 255),
        InputBG      = Color3.fromRGB(20, 0, 45),
        NotifBG      = Color3.fromRGB(10, 0, 30),
        TabActive    = Color3.fromRGB(252, 245, 255),
        TabInactive  = Color3.fromRGB(210, 185, 255),
        AlertInfo    = Color3.fromRGB(180, 0, 255),
        AlertWarn    = Color3.fromRGB(225, 155, 35),
        AlertError   = Color3.fromRGB(220, 55, 55),
        AlertSuccess = Color3.fromRGB(38, 195, 95),
        IconColor    = Color3.fromRGB(220, 190, 255),
    },
    RoyalBlue = {
        Background   = Color3.fromRGB(8, 20, 45),
        Sidebar      = Color3.fromRGB(10, 30, 65),
        TopBar       = Color3.fromRGB(10, 30, 65),
        Element      = Color3.fromRGB(15, 45, 95),
        ElementHover = Color3.fromRGB(20, 60, 125),
        Accent       = Color3.fromRGB(15, 82, 186),
        AccentDim    = Color3.fromRGB(10, 50, 115),
        Text         = Color3.fromRGB(220, 235, 255),
        SubText      = Color3.fromRGB(170, 190, 220),
        Border       = Color3.fromRGB(10, 65, 150),
        Scrollbar    = Color3.fromRGB(15, 75, 165),
        ToggleOff    = Color3.fromRGB(12, 35, 75),
        ToggleOn     = Color3.fromRGB(15, 82, 186),
        SliderTrack  = Color3.fromRGB(10, 28, 60),
        SliderFill   = Color3.fromRGB(15, 82, 186),
        InputBG      = Color3.fromRGB(12, 35, 75),
        NotifBG      = Color3.fromRGB(8, 20, 45),
        TabActive    = Color3.fromRGB(220, 235, 255),
        TabInactive  = Color3.fromRGB(170, 190, 220),
        AlertInfo    = Color3.fromRGB(15, 82, 186),
        AlertWarn    = Color3.fromRGB(225, 155, 35),
        AlertError   = Color3.fromRGB(220, 55, 55),
        AlertSuccess = Color3.fromRGB(38, 195, 95),
        IconColor    = Color3.fromRGB(180, 210, 255),
    },
    DeepOcean = {
        Background   = Color3.fromRGB(10, 25, 40),
        Sidebar      = Color3.fromRGB(15, 35, 60),
        TopBar       = Color3.fromRGB(15, 35, 60),
        Element      = Color3.fromRGB(20, 50, 85),
        ElementHover = Color3.fromRGB(30, 70, 115),
        Accent       = Color3.fromRGB(0, 150, 200),
        AccentDim    = Color3.fromRGB(0, 90, 135),
        Text         = Color3.fromRGB(240, 248, 255),
        SubText      = Color3.fromRGB(180, 210, 230),
        Border       = Color3.fromRGB(0, 100, 150),
        Scrollbar    = Color3.fromRGB(0, 120, 180),
        ToggleOff    = Color3.fromRGB(15, 40, 65),
        ToggleOn     = Color3.fromRGB(0, 150, 200),
        SliderTrack  = Color3.fromRGB(12, 30, 50),
        SliderFill   = Color3.fromRGB(0, 150, 200),
        InputBG      = Color3.fromRGB(15, 40, 65),
        NotifBG      = Color3.fromRGB(10, 25, 40),
        TabActive    = Color3.fromRGB(240, 248, 255),
        TabInactive  = Color3.fromRGB(180, 210, 230),
        AlertInfo    = Color3.fromRGB(0, 150, 200),
        AlertWarn    = Color3.fromRGB(225, 155, 35),
        AlertError   = Color3.fromRGB(220, 55, 55),
        AlertSuccess = Color3.fromRGB(38, 195, 95),
        IconColor    = Color3.fromRGB(160, 210, 240),
    },
    MidnightBlue = {
        Background   = Color3.fromRGB(8, 5, 20),
        Sidebar      = Color3.fromRGB(15, 10, 35),
        TopBar       = Color3.fromRGB(15, 10, 35),
        Element      = Color3.fromRGB(25, 18, 55),
        ElementHover = Color3.fromRGB(40, 30, 85),
        Accent       = Color3.fromRGB(100, 80, 200),
        AccentDim    = Color3.fromRGB(65, 50, 135),
        Text         = Color3.fromRGB(220, 220, 255),
        SubText      = Color3.fromRGB(170, 170, 210),
        Border       = Color3.fromRGB(60, 45, 140),
        Scrollbar    = Color3.fromRGB(75, 55, 160),
        ToggleOff    = Color3.fromRGB(18, 12, 40),
        ToggleOn     = Color3.fromRGB(100, 80, 200),
        SliderTrack  = Color3.fromRGB(14, 10, 30),
        SliderFill   = Color3.fromRGB(100, 80, 200),
        InputBG      = Color3.fromRGB(18, 12, 40),
        NotifBG      = Color3.fromRGB(8, 5, 20),
        TabActive    = Color3.fromRGB(220, 220, 255),
        TabInactive  = Color3.fromRGB(170, 170, 210),
        AlertInfo    = Color3.fromRGB(100, 80, 200),
        AlertWarn    = Color3.fromRGB(225, 155, 35),
        AlertError   = Color3.fromRGB(220, 55, 55),
        AlertSuccess = Color3.fromRGB(38, 195, 95),
        IconColor    = Color3.fromRGB(180, 170, 230),
    },
    CosmicViolet = {
        Background   = Color3.fromRGB(8, 6, 16),
        Sidebar      = Color3.fromRGB(12, 10, 22),
        TopBar       = Color3.fromRGB(12, 10, 22),
        Element      = Color3.fromRGB(22, 16, 45),
        ElementHover = Color3.fromRGB(34, 25, 65),
        Accent       = Color3.fromRGB(80, 60, 140),
        AccentDim    = Color3.fromRGB(55, 38, 115),
        Text         = Color3.fromRGB(230, 225, 245),
        SubText      = Color3.fromRGB(185, 175, 210),
        Border       = Color3.fromRGB(50, 35, 110),
        Scrollbar    = Color3.fromRGB(60, 42, 120),
        ToggleOff    = Color3.fromRGB(18, 12, 35),
        ToggleOn     = Color3.fromRGB(80, 60, 140),
        SliderTrack  = Color3.fromRGB(14, 10, 28),
        SliderFill   = Color3.fromRGB(80, 60, 140),
        InputBG      = Color3.fromRGB(18, 12, 35),
        NotifBG      = Color3.fromRGB(8, 6, 16),
        TabActive    = Color3.fromRGB(230, 225, 245),
        TabInactive  = Color3.fromRGB(185, 175, 210),
        AlertInfo    = Color3.fromRGB(80, 60, 140),
        AlertWarn    = Color3.fromRGB(225, 155, 35),
        AlertError   = Color3.fromRGB(220, 55, 55),
        AlertSuccess = Color3.fromRGB(38, 195, 95),
        IconColor    = Color3.fromRGB(170, 160, 200),
    },
    Sakura = {
        Background   = Color3.fromRGB(255, 238, 248),
        Sidebar      = Color3.fromRGB(252, 225, 242),
        TopBar       = Color3.fromRGB(252, 225, 242),
        Element      = Color3.fromRGB(255, 248, 253),
        ElementHover = Color3.fromRGB(248, 220, 240),
        Accent       = Color3.fromRGB(230, 100, 160),
        AccentDim    = Color3.fromRGB(245, 185, 215),
        Text         = Color3.fromRGB(80, 30, 60),
        SubText      = Color3.fromRGB(165, 100, 140),
        Border       = Color3.fromRGB(235, 180, 215),
        Scrollbar    = Color3.fromRGB(220, 160, 200),
        ToggleOff    = Color3.fromRGB(248, 218, 238),
        ToggleOn     = Color3.fromRGB(230, 100, 160),
        SliderTrack  = Color3.fromRGB(248, 215, 235),
        SliderFill   = Color3.fromRGB(230, 100, 160),
        InputBG      = Color3.fromRGB(255, 245, 252),
        NotifBG      = Color3.fromRGB(255, 238, 248),
        TabActive    = Color3.fromRGB(80, 30, 60),
        TabInactive  = Color3.fromRGB(165, 100, 140),
        AlertInfo    = Color3.fromRGB(130, 140, 220),
        AlertWarn    = Color3.fromRGB(200, 130, 50),
        AlertError   = Color3.fromRGB(210, 70, 70),
        AlertSuccess = Color3.fromRGB(60, 180, 100),
        IconColor    = Color3.fromRGB(195, 100, 155),
    }
}

-- ================================================================================
--  NOTIFICATIONS
-- ================================================================================
local _nGui, _nHolder
local _activeNotifs = {}
local function _initNotif()
    if _nGui then return end
    _nGui = make("ScreenGui", { Name="AuroraNotif", ResetOnSpawn=false, DisplayOrder=99999 })
    safeParent(_nGui)
    _nHolder = make("Frame", {
        Size=UDim2.new(0,s(310),1,0), Position=UDim2.new(1,-s(320),0,0),
        BackgroundTransparency=1, Parent=_nGui,
    })
    make("UIListLayout", {
        SortOrder=Enum.SortOrder.LayoutOrder,
        VerticalAlignment=Enum.VerticalAlignment.Bottom,
        Padding=sz(8), Parent=_nHolder,
    })
    make("UIPadding", { PaddingBottom=sz(22), Parent=_nHolder })
end

function Aurora:Notify(cfg)
    _initNotif()
    cfg = cfg or {}
    local thm = self.Theme or self.Themes.Dark
    local typ = cfg.Type or "Info"
    local dur = cfg.Duration or 4
    local accentMap = { Success=thm.AlertSuccess, Error=thm.AlertError, Warning=thm.AlertWarn, Info=thm.AlertInfo }
    local iconMap   = { Success="solar/check-circle-bold", Error="solar/close-circle-bold", Warning="solar/danger-bold", Info="solar/info-circle-bold" }
    local soundMap  = { Success=4590662762, Error=9069609268, Warning=6546366050, Info=4590662762 }
    local accent = accentMap[typ] or thm.Accent

    local function playSound(soundId)
        if cfg.PlaySound == false then return end
        task.spawn(function()
            local s = make("Sound", {
                SoundId = "rbxassetid://" .. tostring(soundId),
                Volume = cfg.Volume or 0.4,
                Parent = game:GetService("SoundService")
            })
            s:Play()
            task.wait(1.5)
            s:Destroy()
        end)
    end

    playSound(cfg.SoundId or soundMap[typ] or 4590662762)

    local acrylicEnabled = cfg.Acrylic
    if acrylicEnabled == nil then
        acrylicEnabled = self.Acrylic
    end
    if acrylicEnabled == nil then
        acrylicEnabled = true
    end

    local card = make("Frame", {
        Size=UDim2.new(1,0,0,s(4)), AutomaticSize=Enum.AutomaticSize.Y,
        BackgroundColor3=thm.NotifBG,
        BackgroundTransparency=(acrylicEnabled and 0.45 or 0),
        BorderSizePixel=0, ClipsDescendants=true,
        LayoutOrder=-tick(), Parent=_nHolder,
    })
    if acrylicEnabled then
        createAcrylic(card)
    end
    make("UICorner", { CornerRadius=sz(14), Parent=card })
    
    local cardStroke = make("UIStroke", { Thickness=1, Transparency=0.25, Parent=card })
    local gradient = make("UIGradient", {
        Color=ColorSequence.new({
            ColorSequenceKeypoint.new(0,  accent),
            ColorSequenceKeypoint.new(0.35, thm.Border),
            ColorSequenceKeypoint.new(1,  thm.Border),
        }),
        Rotation=45, Parent=cardStroke,
    })
    
    make("Frame", {
        Size=UDim2.new(1,0,0,s(1)), BackgroundColor3=Color3.fromRGB(255,255,255),
        BackgroundTransparency=0.85, BorderSizePixel=0, Parent=card,
    })

    local iconFrame = make("Frame", {
        Size=ss(28,28), AnchorPoint=Vector2.new(0,0), Position=UDim2.new(0,s(12),0,s(12)),
        BackgroundColor3=accent, BackgroundTransparency=0.85, BorderSizePixel=0, Parent=card,
    })
    make("UICorner", { CornerRadius=UDim.new(1,0), Parent=iconFrame })
    local iconStroke = make("UIStroke", { Color=accent, Thickness=1, Transparency=0.5, Parent=iconFrame })
    local notifIco = make("ImageLabel", {
        Size=ss(14,14), AnchorPoint=Vector2.new(0.5,0.5), Position=UDim2.fromScale(0.5,0.5),
        BackgroundTransparency=1, Parent=iconFrame,
    })
    applyIcon(notifIco, cfg.Icon or iconMap[typ] or "solar/info-circle-bold", accent)

    task.spawn(function()
        while card and card.Parent do
            pcall(function()
                local t1 = TweenService:Create(iconStroke, TweenInfo.new(0.9, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut), { Transparency = 0.9, Thickness = 2.5 })
                t1:Play()
                t1.Completed:Wait()
                local t2 = TweenService:Create(iconStroke, TweenInfo.new(0.9, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut), { Transparency = 0.4, Thickness = 1.0 })
                t2:Play()
                t2.Completed:Wait()
            end)
            task.wait(0.1)
        end
    end)

    local txtF = make("Frame", {
        Size=UDim2.new(1,-s(102),0,0), Position=UDim2.new(0,s(50),0,s(12)),
        BackgroundTransparency=1, AutomaticSize=Enum.AutomaticSize.Y, Parent=card,
    })
    make("UIListLayout", { SortOrder=Enum.SortOrder.LayoutOrder, Padding=sz(2), Parent=txtF })
    
    local titleLbl = make("TextLabel", {
        Size=UDim2.new(1,0,0,s(4)), AutomaticSize=Enum.AutomaticSize.Y,
        BackgroundTransparency=1, Text=cfg.Title or "Notification",
        TextColor3=thm.Text, TextSize=fs(16), Font=Enum.Font.GothamBold,
        TextXAlignment=Enum.TextXAlignment.Left, TextWrapped=true, RichText=true, Parent=txtF,
    })
    
    local contentLbl = make("TextLabel", {
        Size=UDim2.new(1,0,0,s(4)), AutomaticSize=Enum.AutomaticSize.Y,
        BackgroundTransparency=1, Text=cfg.Content or "",
        TextColor3=thm.SubText, TextSize=fs(16), Font=Enum.Font.Gotham,
        TextXAlignment=Enum.TextXAlignment.Left, TextWrapped=true, RichText=true, Parent=txtF,
        Visible = (cfg.Content ~= nil and cfg.Content ~= "")
    })

    local closed = false
    local closeNotif
    closeNotif = function()
        if closed then return end; closed = true
        for i, v in ipairs(_activeNotifs) do
            if v.Card == card then
                table.remove(_activeNotifs, i)
                break
            end
        end
        pcall(function()
            card.AutomaticSize = Enum.AutomaticSize.None
            local currentHeight = card.AbsoluteSize.Y
            card.Size = UDim2.new(1, 0, 0, currentHeight)
            
            for _, child in ipairs(card:GetDescendants()) do
                if child:IsA("TextLabel") or child:IsA("ImageLabel") or child:IsA("TextButton") or child:IsA("TextBox") then
                    tw(child, { ImageTransparency = 1, TextTransparency = 1, BackgroundTransparency = 1 }, 0.2)
                elseif child:IsA("UIStroke") then
                    tw(child, { Transparency = 1 }, 0.2)
                end
            end
            
            tw(card, { 
                Position = UDim2.new(1, s(40), 0, card.Position.Y.Offset), 
                BackgroundTransparency = 1,
                Size = UDim2.new(1, 0, 0, 0)
            }, 0.25)
        end)
        task.delay(0.26, function() pcall(function() card:Destroy() end) end)
    end

    local function addHoverScale(btn)
        local scale = make("UIScale", { Scale = 1, Parent = btn })
        btn.MouseEnter:Connect(function()
            tw(scale, { Scale = 1.06 }, 0.15, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
        end)
        btn.MouseLeave:Connect(function()
            tw(scale, { Scale = 1.0 }, 0.15, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
        end)
    end

    -- Setup input field
    local inputFrame = make("Frame", {
        Size = UDim2.new(1, 0, 0, s(24)),
        BackgroundColor3 = thm.InputBG,
        BackgroundTransparency = 0,
        BorderSizePixel = 0,
        LayoutOrder = 10,
        Parent = txtF,
        Visible = false
    })
    make("UICorner", { CornerRadius = sz(9), Parent = inputFrame })
    local inputStroke = make("UIStroke", { Color = thm.Border, Thickness = 1, Parent = inputFrame })
    
    local txtInput = make("TextBox", {
        Size = UDim2.new(1, -s(26), 1, 0),
        Position = UDim2.new(0, s(8), 0, 0),
        BackgroundTransparency = 1,
        PlaceholderText = cfg.InputPlaceholder or "Type here...",
        PlaceholderColor3 = thm.SubText,
        Text = "",
        TextColor3 = thm.Text,
        TextSize = fs(11),
        Font = Enum.Font.Gotham,
        TextXAlignment = Enum.TextXAlignment.Left,
        ClearTextOnFocus = false,
        Parent = inputFrame
    })
    
    local submitBtn = make("TextButton", {
        Size = ss(18, 18),
        AnchorPoint = Vector2.new(1, 0.5),
        Position = UDim2.new(1, -s(4), 0.5, 0),
        BackgroundTransparency = 1,
        Text = "",
        Parent = inputFrame
    })
    local submitIco = make("ImageLabel", {
        Size = ss(10, 10),
        AnchorPoint = Vector2.new(0.5, 0.5),
        Position = UDim2.fromScale(0.5, 0.5),
        BackgroundTransparency = 1,
        Parent = submitBtn
    })
    applyIcon(submitIco, "solar/alt-arrow-right-bold", thm.SubText)
    addHoverScale(submitBtn)

    local function submitVal()
        local val = txtInput.Text
        if cfg.InputCallback then
            pcall(cfg.InputCallback, val)
        end
        closeNotif()
    end
    txtInput.FocusLost:Connect(function(enterPressed)
        if enterPressed then submitVal() end
    end)
    submitBtn.MouseButton1Click:Connect(submitVal)

    txtInput.Focused:Connect(function()
        local currentThm = Aurora.Theme or Aurora.Themes.Dark
        tw(inputStroke, { Color = currentThm.Accent }, 0.15)
        tw(submitIco, { ImageColor3 = currentThm.Accent }, 0.15)
    end)
    txtInput.FocusLost:Connect(function()
        local currentThm = Aurora.Theme or Aurora.Themes.Dark
        tw(inputStroke, { Color = currentThm.Border }, 0.15)
        tw(submitIco, { ImageColor3 = currentThm.SubText }, 0.15)
    end)

    if cfg.Input then
        inputFrame.Visible = true
    end

    -- Setup custom buttons
    local btnSpacer = make("Frame", { Size=UDim2.new(1,0,0,s(6)), BackgroundTransparency=1, LayoutOrder = 11, Parent=txtF, Visible = false })
    local btnContainer = make("Frame", {
        Size = UDim2.new(1, 0, 0, s(22)),
        BackgroundTransparency = 1,
        LayoutOrder = 12,
        Parent = txtF,
        Visible = false
    })
    make("UIListLayout", {
        FillDirection = Enum.FillDirection.Horizontal,
        HorizontalAlignment = Enum.HorizontalAlignment.Left,
        VerticalAlignment = Enum.VerticalAlignment.Center,
        Padding = sz(6),
        Parent = btnContainer
    })

    local function buildButtons(btnList)
        for _, child in ipairs(btnContainer:GetChildren()) do
            if child:IsA("TextButton") then child:Destroy() end
        end
        if btnList and #btnList > 0 then
            btnSpacer.Visible = true
            btnContainer.Visible = true
            for idx, btnCfg in ipairs(btnList) do
                local button = make("TextButton", {
                    Size = UDim2.new(0, s(60), 1, 0),
                    BackgroundColor3 = thm.Element,
                    Text = btnCfg.Title or "Button",
                    TextColor3 = thm.Text,
                    TextSize = fs(9),
                    Font = Enum.Font.GothamBold,
                    Parent = btnContainer
                })
                make("UICorner", { CornerRadius = sz(9), Parent = button })
                local bStroke = make("UIStroke", { Color = thm.Border, Thickness = 1, Parent = button })
                addHoverScale(button)
                
                button.MouseEnter:Connect(function()
                    tw(button, { BackgroundColor3 = thm.ElementHover }, 0.1)
                    tw(bStroke, { Color = accent }, 0.1)
                end)
                button.MouseLeave:Connect(function()
                    tw(button, { BackgroundColor3 = thm.Element }, 0.1)
                    tw(bStroke, { Color = thm.Border }, 0.1)
                end)
                button.MouseButton1Click:Connect(function()
                    if btnCfg.Callback then pcall(btnCfg.Callback) end
                    closeNotif()
                end)
            end
        else
            btnSpacer.Visible = false
            btnContainer.Visible = false
        end
    end

    buildButtons(cfg.Buttons)

    make("Frame", { Size=UDim2.new(1,0,0,s(12)), ZIndex=0, BackgroundTransparency=1, LayoutOrder = 13, Parent=txtF })

    local function makeControlBtn(xOff)
        local b = make("TextButton", {
            Size=ss(16,16), Position=UDim2.new(1,-xOff,0,s(10)), AnchorPoint=Vector2.new(1,0),
            BackgroundColor3=thm.Element, BackgroundTransparency=1, Text="", ZIndex=5, Parent=card,
        })
        make("UICorner", { CornerRadius=UDim.new(1,0), Parent=b })
        addHoverScale(b)
        return b
    end
    local closeBtn = makeControlBtn(s(10))
    local copyBtn  = makeControlBtn(s(28))
    local cIco = make("ImageLabel", { Size=ss(8,8), AnchorPoint=Vector2.new(0.5,0.5), Position=UDim2.fromScale(0.5,0.5), BackgroundTransparency=1, Parent=closeBtn })
    local cpIco= make("ImageLabel", { Size=ss(8,8), AnchorPoint=Vector2.new(0.5,0.5), Position=UDim2.fromScale(0.5,0.5), BackgroundTransparency=1, Parent=copyBtn })
    applyIcon(cIco,  "solar/close-linear",  thm.SubText)
    applyIcon(cpIco, "solar/copy-linear",   thm.SubText)

    local pTrack = make("Frame", {
        Size=UDim2.new(1,0,0,s(3)), Position=UDim2.new(0,0,1,-s(3)),
        BackgroundColor3=thm.Border, BackgroundTransparency=0.75, BorderSizePixel=0, Parent=card,
    })
    local pFill = make("Frame", { Size=UDim2.new(1,0,1,0), BackgroundColor3=accent, BorderSizePixel=0, Parent=pTrack })
    -- Gradient on progress fill
    make("UIGradient", {
        Color=ColorSequence.new({
            ColorSequenceKeypoint.new(0, Color3.fromRGB(255,255,255)),
            ColorSequenceKeypoint.new(1, Color3.fromRGB(200,200,200)),
        }),
        Transparency=NumberSequence.new({
            NumberSequenceKeypoint.new(0, 0.2),
            NumberSequenceKeypoint.new(1, 0),
        }),
        Rotation=0, Parent=pFill,
    })
    make("UICorner", { CornerRadius=sz(4), Parent=pTrack })
    make("UICorner", { CornerRadius=sz(4), Parent=pFill })

    local notifObj = { Card = card, Close = closeNotif }
    table.insert(_activeNotifs, notifObj)
    if #_activeNotifs > 5 then
        local oldest = _activeNotifs[1]
        if oldest then oldest.Close() end
    end

    closeBtn.MouseButton1Click:Connect(closeNotif)
    copyBtn.MouseButton1Click:Connect(function()
        local t = tostring(titleLbl.Text or "")
        if contentLbl.Visible and contentLbl.Text ~= "" then t = t.."\n"..tostring(contentLbl.Text) end
        pcall(function() toclipboard(t) end)
    end)
    closeBtn.MouseEnter:Connect(function() tw(closeBtn,{BackgroundTransparency=0.4,BackgroundColor3=Color3.fromRGB(200,50,50)},0.1) end)
    closeBtn.MouseLeave:Connect(function() tw(closeBtn,{BackgroundTransparency=1},0.1) end)
    copyBtn.MouseEnter:Connect(function() tw(copyBtn,{BackgroundTransparency=0.4,BackgroundColor3=thm.ElementHover},0.1) end)
    copyBtn.MouseLeave:Connect(function() tw(copyBtn,{BackgroundTransparency=1},0.1) end)

    -- Drag to dismiss gesture
    local cardDragging = false
    local cardDragStartPos = nil
    
    card.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
            cardDragging = true
            cardDragStartPos = input.Position
        end
    end)
    
    local changedConn = UserInputService.InputChanged:Connect(function(input)
        if cardDragging and (input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch) then
            local delta = input.Position - cardDragStartPos
            if delta.X > 0 then
                card.Position = UDim2.new(0, delta.X, 0, card.Position.Y.Offset)
            end
        end
    end)
    
    local endedConn = UserInputService.InputEnded:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
            if cardDragging then
                cardDragging = false
                local offset = card.Position.X.Offset
                if offset > s(100) then
                    closeNotif()
                else
                    tw(card, { Position = UDim2.new(0,0,0,0) }, 0.15)
                end
            end
        end
    end)
    card.Destroying:Connect(function()
        pcall(function() changedConn:Disconnect() end)
        pcall(function() endedConn:Disconnect() end)
    end)

    card.Position = UDim2.new(1,s(320),0,0); card.BackgroundTransparency=1
    tw(card, { Position=UDim2.new(0,0,0,0), BackgroundTransparency=(acrylicEnabled and 0.45 or 0) }, 0.6, Enum.EasingStyle.Back, Enum.EasingDirection.Out)

    -- Timer & Progress Bar State
    local autoCloseThread
    local function startAutoClose(customDur)
        if autoCloseThread then
            pcall(task.cancel, autoCloseThread)
            autoCloseThread = nil
        end
        local d = customDur or dur
        if d and d > 0 then
            pFill.Size = UDim2.new(1, 0, 1, 0)
            tw(pFill, { Size = UDim2.new(0, 0, 1, 0) }, d, Enum.EasingStyle.Linear)
            autoCloseThread = task.delay(d, function()
                if not closed then closeNotif() end
            end)
        else
            pFill.Size = UDim2.new(0, 0, 1, 0)
        end
    end

    startAutoClose(dur)

    -- Dynamic update helpers
    local function updateText(lbl, newText)
        if not lbl then return end
        if lbl.Text == newText then return end
        tw(lbl, { TextTransparency = 1 }, 0.15)
        task.delay(0.15, function()
            lbl.Text = newText
            lbl.Visible = (newText ~= nil and newText ~= "")
            tw(lbl, { TextTransparency = 0 }, 0.15)
        end)
    end

    local function updateIcon(newIcon, newAccent)
        pcall(function()
            tw(iconStroke, { Color = newAccent }, 0.25)
            tw(iconFrame, { BackgroundColor3 = newAccent }, 0.25)
            tw(notifIco, { Size = ss(0, 0), Rotation = 180 }, 0.2, Enum.EasingStyle.Quad, Enum.EasingDirection.In)
            task.delay(0.2, function()
                notifIco.Rotation = -180
                applyIcon(notifIco, newIcon, newAccent)
                tw(notifIco, { Size = ss(14, 14), Rotation = 0 }, 0.2, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
            end)
        end)
    end

    local function updateGradient(newAccent)
        pcall(function()
            gradient.Color = ColorSequence.new({
                ColorSequenceKeypoint.new(0,  newAccent),
                ColorSequenceKeypoint.new(0.35, thm.Border),
                ColorSequenceKeypoint.new(1,  thm.Border),
            })
        end)
    end

    -- Controller Return API
    local controller = {}
    
    function controller:Update(newCfg)
        if closed then return end
        newCfg = newCfg or {}
        local currentThm = Aurora.Theme or Aurora.Themes.Dark
        
        if newCfg.Type or newCfg.Icon then
            local newTyp = newCfg.Type or typ
            local newAccent = accentMap[newTyp] or currentThm.Accent
            local newIcon = newCfg.Icon or iconMap[newTyp] or "solar/info-circle-bold"
            updateIcon(newIcon, newAccent)
            updateGradient(newAccent)
            
            if newCfg.Type and newCfg.Type ~= typ then
                local newSoundId = newCfg.SoundId or soundMap[newCfg.Type] or 4590662762
                playSound(newSoundId)
            end
            
            typ = newTyp
            accent = newAccent
        end
        
        if newCfg.Title then
            updateText(titleLbl, newCfg.Title)
        end
        if newCfg.Content then
            updateText(contentLbl, newCfg.Content)
        end
        
        if newCfg.Input ~= nil then
            inputFrame.Visible = newCfg.Input
            if newCfg.InputPlaceholder then
                txtInput.PlaceholderText = newCfg.InputPlaceholder
            end
            if newCfg.InputCallback then
                cfg.InputCallback = newCfg.InputCallback
            end
        end
        
        if newCfg.Buttons then
            buildButtons(newCfg.Buttons)
        end
        
        if newCfg.Duration ~= nil then
            dur = newCfg.Duration
            startAutoClose(dur)
        end
    end

    function controller:SetProgress(percent)
        if closed then return end
        if autoCloseThread then
            pcall(task.cancel, autoCloseThread)
            autoCloseThread = nil
        end
        pcall(function()
            pTrack.Visible = true
            pFill.Visible = true
            local p = math.clamp(percent, 0, 1)
            tw(pFill, { Size = UDim2.new(p, 0, 1, 0) }, 0.12, Enum.EasingStyle.Quad)
        end)
    end

    function controller:Close()
        closeNotif()
    end

    return controller
end

-- ================================================================================
--  SHARED ELEMENT FRAME
-- ================================================================================
local function registerHover(f, hoverTrigger)
    local stroke = f:FindFirstChildOfClass("UIStroke")
    local hovered = false
    hoverTrigger.MouseEnter:Connect(function()
        if hovered then return end
        hovered = true
        tw(f, { BackgroundColor3 = Aurora.Theme.ElementHover, BackgroundTransparency = 0.8 }, 0.12)
        if stroke then
            tw(stroke, { Color = Aurora.Theme.Accent, Transparency = 0.65 }, 0.12)
        end
    end)
    hoverTrigger.MouseLeave:Connect(function()
        if not hovered then return end
        hovered = false
        tw(f, { BackgroundColor3 = Aurora.Theme.Element, BackgroundTransparency = 1 }, 0.18)
        if stroke then
            tw(stroke, { Color = Color3.fromRGB(255,255,255), Transparency = 1 }, 0.18)
        end
    end)
end

local function elemFrame(parent)
    if Aurora.LazyLoad then
        task.wait(Aurora.DelayPerElement or 0.01)
    end

    local f = make(Aurora.FadeIn and "CanvasGroup" or "Frame", {
        Size=UDim2.new(1,0,0,s(4)), AutomaticSize=Enum.AutomaticSize.Y,
        BackgroundColor3=Aurora.Theme.Element, BackgroundTransparency=1, BorderSizePixel=0, Parent=parent,
    })
    make("UICorner", { CornerRadius=sz(12), Parent=f })
    make("UIPadding", { PaddingTop=sz(9), PaddingBottom=sz(9), PaddingLeft=sz(11), PaddingRight=sz(11), Parent=f })
    make("UIListLayout", { SortOrder=Enum.SortOrder.LayoutOrder, Padding=sz(6), Parent=f })
    reg(f, "BackgroundColor3", "Element")
    
    local stroke = make("UIStroke", {
        Color = Color3.fromRGB(255,255,255),
        Thickness = 1,
        Transparency = 1,
        Parent = f
    })

    if Aurora.FadeIn then
        f.GroupTransparency = 1
        task.defer(function()
            tw(f, { GroupTransparency = 0 }, 0.28, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
        end)
    end

    return f
end

-- ================================================================================
--  2D COLORPICKER PANEL
--  Layout: [SV Canvas] [Vertical Hue Bar] | [Hex/R/G/B/Alpha inputs]
--          [Old swatch][New swatch]
-- ================================================================================
local function createColorpickerPanel(parentFrame, cpObj, cpCfg, colDisp)
    local thm = Aurora.Theme
    local panel = make("Frame", {
        Size = UDim2.new(1, 0, 0, 0),
        ClipsDescendants = true,
        BackgroundTransparency = 1,
        LayoutOrder = 2,
        Parent = parentFrame,
    })

    local currentH, currentS, currentV = cpObj.Value:ToHSV()
    local currentA = 1
    local originalColor = cpObj.Value

    -- Main row holds canvas + hue bar + inputs side by side
    local mainRow = make("Frame", {
        Size     = UDim2.new(1, 0, 0, s(120)),
        Position = UDim2.new(0, 0, 0, s(4)),
        BackgroundTransparency = 1,
        Parent = panel,
    })

    -- SV Canvas (left ~50%)
    local canvasHolder = make("Frame", {
        Size = UDim2.new(0.50, -s(4), 1, 0),
        BackgroundColor3 = Color3.fromHSV(currentH, 1, 1),
        BorderSizePixel = 0,
        Parent = mainRow,
    })
    make("UICorner", { CornerRadius=sz(7), Parent=canvasHolder })

    local satGrad = make("Frame", { Size=UDim2.fromScale(1,1), BackgroundColor3=Color3.fromRGB(255,255,255), BorderSizePixel=0, Parent=canvasHolder })
    make("UICorner", { CornerRadius=sz(7), Parent=satGrad })
    make("UIGradient", {
        Color=ColorSequence.new(Color3.fromRGB(255,255,255), Color3.fromRGB(255,255,255)),
        Transparency=NumberSequence.new({ NumberSequenceKeypoint.new(0,0), NumberSequenceKeypoint.new(1,1) }),
        Rotation=0, Parent=satGrad,
    })

    local valGrad = make("Frame", { Size=UDim2.fromScale(1,1), BackgroundColor3=Color3.fromRGB(0,0,0), BorderSizePixel=0, Parent=canvasHolder })
    make("UICorner", { CornerRadius=sz(7), Parent=valGrad })
    make("UIGradient", {
        Color=ColorSequence.new(Color3.fromRGB(0,0,0), Color3.fromRGB(0,0,0)),
        Transparency=NumberSequence.new({ NumberSequenceKeypoint.new(0,1), NumberSequenceKeypoint.new(1,0) }),
        Rotation=90, Parent=valGrad,
    })

    local cursor = make("Frame", {
        Size=ss(11,11), AnchorPoint=Vector2.new(0.5,0.5),
        Position=UDim2.new(currentS, 0, 1-currentV, 0),
        BackgroundColor3=Color3.fromRGB(255,255,255), BorderSizePixel=0, ZIndex=3,
        Parent=canvasHolder,
    })
    make("UICorner", { CornerRadius=UDim.new(1,0), Parent=cursor })
    make("UIStroke", { Color=Color3.fromRGB(0,0,0), Thickness=1.5, Transparency=0.25, Parent=cursor })

    local canvasBtn = make("TextButton", {
        Size=UDim2.fromScale(1,1), BackgroundTransparency=1, Text="", ZIndex=4, Active=true, Parent=canvasHolder,
    })

    -- Vertical Hue Bar (narrow, next to canvas)
    local hueBar = make("TextButton", {
        Size     = UDim2.new(0, s(12), 1, 0),
        Position = UDim2.new(0.50, s(2), 0, 0),
        BackgroundColor3 = Color3.fromRGB(255,0,0),
        Text="", AutoButtonColor=false, Active=true,
        Parent = mainRow,
    })
    make("UICorner", { CornerRadius=sz(5), Parent=hueBar })
    make("UIGradient", {
        Color=ColorSequence.new({
            ColorSequenceKeypoint.new(0.00, Color3.fromRGB(255,  0,  0)),
            ColorSequenceKeypoint.new(0.17, Color3.fromRGB(255,255,  0)),
            ColorSequenceKeypoint.new(0.33, Color3.fromRGB(  0,255,  0)),
            ColorSequenceKeypoint.new(0.50, Color3.fromRGB(  0,255,255)),
            ColorSequenceKeypoint.new(0.67, Color3.fromRGB(  0,  0,255)),
            ColorSequenceKeypoint.new(0.83, Color3.fromRGB(255,  0,255)),
            ColorSequenceKeypoint.new(1.00, Color3.fromRGB(255,  0,  0)),
        }),
        Rotation=90,
        Parent=hueBar,
    })
    make("UIStroke", { Color=thm.Border, Thickness=1, Transparency=0.5, Parent=hueBar })

    -- Hue marker (flat horizontal bar, sticks out both sides like the image)
    local hueKnob = make("Frame", {
        Size = UDim2.new(1, s(6), 0, s(4)),
        AnchorPoint = Vector2.new(0.5, 0.5),
        Position = UDim2.new(0.5, 0, currentH, 0),
        BackgroundColor3 = Color3.fromRGB(255,255,255),
        BorderSizePixel=0, ZIndex=3,
        Parent=hueBar,
    })
    make("UICorner", { CornerRadius=sz(2), Parent=hueKnob })
    make("UIStroke", { Color=Color3.fromRGB(0,0,0), Thickness=1.5, Transparency=0.3, Parent=hueKnob })

    -- Input fields on the right (Hex, Red, Green, Blue, Alpha)
    local inputsFrame = make("Frame", {
        Size     = UDim2.new(0.50, -s(20), 1, 0),
        Position = UDim2.new(0.50, s(18), 0, 0),
        BackgroundTransparency = 1,
        Parent = mainRow,
    })
    make("UIListLayout", { SortOrder=Enum.SortOrder.LayoutOrder, Padding=sz(3), Parent=inputsFrame })

    local function makeInputRow(labelText, defaultText, lo)
        local row = make("Frame", {
            Size=UDim2.new(1,0,0,s(18)), BackgroundTransparency=1, LayoutOrder=lo, Parent=inputsFrame,
        })
        local box = make("TextBox", {
            Size=UDim2.new(0.60, -s(2), 1, 0),
            BackgroundColor3=thm.InputBG,
            Text=defaultText,
            TextColor3=thm.Text, TextSize=fs(10), Font=Enum.Font.GothamBold,
            TextXAlignment=Enum.TextXAlignment.Center,
            ClearTextOnFocus=false,
            Parent=row,
        })
        make("UICorner", { CornerRadius=sz(6), Parent=box })
        make("UIStroke", { Color=thm.Border, Thickness=1, Parent=box })
        make("TextLabel", {
            Size=UDim2.new(0.40, 0, 1, 0),
            Position=UDim2.new(0.60, s(4), 0, 0),
            BackgroundTransparency=1,
            Text=labelText,
            TextColor3=thm.SubText, TextSize=fs(10), Font=Enum.Font.Gotham,
            TextXAlignment=Enum.TextXAlignment.Left,
            Parent=row,
        })
        return box
    end

    local hexBox   = makeInputRow("Hex",   "#"..colorToHex(cpObj.Value),              1)
    local rBox     = makeInputRow("Red",   tostring(math.floor(cpObj.Value.R*255+.5)),2)
    local gBox     = makeInputRow("Green", tostring(math.floor(cpObj.Value.G*255+.5)),3)
    local bBox     = makeInputRow("Blue",  tostring(math.floor(cpObj.Value.B*255+.5)),4)
    local alphaBox = makeInputRow("Alpha", "100%",                                    5)

    -- Old / New color swatches below the canvas
    local swatchRow = make("Frame", {
        Size     = UDim2.new(0.50, -s(4), 0, s(14)),
        Position = UDim2.new(0, 0, 0, s(128)),
        BackgroundTransparency = 1,
        Parent = panel,
    })
    local oldSwatch = make("Frame", {
        Size=UDim2.new(0.5,-s(2),1,0), BackgroundColor3=originalColor, BorderSizePixel=0, Parent=swatchRow,
    })
    make("UICorner", { CornerRadius=sz(6), Parent=oldSwatch })
    make("UIStroke", { Color=thm.Border, Thickness=1, Parent=oldSwatch })

    local newSwatch = make("Frame", {
        Size=UDim2.new(0.5,-s(2),1,0), Position=UDim2.new(0.5,s(2),0,0),
        BackgroundColor3=cpObj.Value, BorderSizePixel=0, Parent=swatchRow,
    })
    make("UICorner", { CornerRadius=sz(6), Parent=newSwatch })
    make("UIStroke", { Color=thm.Border, Thickness=1, Parent=newSwatch })

    -- Update helpers
    local function refreshCanvas()
        canvasHolder.BackgroundColor3 = Color3.fromHSV(currentH, 1, 1)
        cursor.Position = UDim2.new(currentS, 0, 1-currentV, 0)
        hueKnob.Position = UDim2.new(0.5, 0, currentH, 0)
    end

    local function applyColor()
        local color = Color3.fromHSV(currentH, currentS, currentV)
        cpObj.Value = color
        if colDisp and colDisp.Parent then colDisp.BackgroundColor3 = color end
        newSwatch.BackgroundColor3 = color
        hexBox.Text   = "#"..colorToHex(color)
        rBox.Text     = tostring(math.floor(color.R*255+.5))
        gBox.Text     = tostring(math.floor(color.G*255+.5))
        bBox.Text     = tostring(math.floor(color.B*255+.5))
        alphaBox.Text = tostring(math.floor(currentA*100+.5)).."%"
        if cpCfg.Callback then pcall(cpCfg.Callback, color) end
        if cpCfg.OnTransparencyChanged then pcall(cpCfg.OnTransparencyChanged, 1-currentA) end
        triggerAutosave()
    end

    -- Canvas drag
    local canvasDrag = false
    canvasBtn.InputBegan:Connect(function(i)
        if i.UserInputType==Enum.UserInputType.MouseButton1 then
            canvasDrag=true
            local rx = math.clamp((i.Position.X-canvasHolder.AbsolutePosition.X)/canvasHolder.AbsoluteSize.X,0,1)
            local ry = math.clamp((i.Position.Y-canvasHolder.AbsolutePosition.Y)/canvasHolder.AbsoluteSize.Y,0,1)
            currentS=rx; currentV=1-ry; refreshCanvas(); applyColor()
        end
    end)
    UserInputService.InputChanged:Connect(function(i)
        if canvasDrag and i.UserInputType==Enum.UserInputType.MouseMovement then
            local rx = math.clamp((i.Position.X-canvasHolder.AbsolutePosition.X)/canvasHolder.AbsoluteSize.X,0,1)
            local ry = math.clamp((i.Position.Y-canvasHolder.AbsolutePosition.Y)/canvasHolder.AbsoluteSize.Y,0,1)
            currentS=rx; currentV=1-ry; refreshCanvas(); applyColor()
        end
    end)
    UserInputService.InputEnded:Connect(function(i)
        if i.UserInputType==Enum.UserInputType.MouseButton1 then canvasDrag=false end
    end)

    -- Hue bar drag (VERTICAL - Y axis)
    local hueDrag = false
    hueBar.InputBegan:Connect(function(i)
        if i.UserInputType==Enum.UserInputType.MouseButton1 then
            hueDrag=true
            currentH=math.clamp((i.Position.Y-hueBar.AbsolutePosition.Y)/hueBar.AbsoluteSize.Y,0,1)
            refreshCanvas(); applyColor()
        end
    end)
    UserInputService.InputChanged:Connect(function(i)
        if hueDrag and i.UserInputType==Enum.UserInputType.MouseMovement then
            currentH=math.clamp((i.Position.Y-hueBar.AbsolutePosition.Y)/hueBar.AbsoluteSize.Y,0,1)
            refreshCanvas(); applyColor()
        end
    end)
    UserInputService.InputEnded:Connect(function(i)
        if i.UserInputType==Enum.UserInputType.MouseButton1 then hueDrag=false end
    end)

    hexBox.FocusLost:Connect(function()
        local color = hexToColor(hexBox.Text)
        if color then
            currentH,currentS,currentV=color:ToHSV(); refreshCanvas(); applyColor()
        else hexBox.Text="#"..colorToHex(cpObj.Value) end
    end)

    local function applyRGB()
        local r=math.clamp(tonumber(rBox.Text) or 255,0,255)
        local g=math.clamp(tonumber(gBox.Text) or 0,  0,255)
        local b=math.clamp(tonumber(bBox.Text) or 0,  0,255)
        local color=Color3.fromRGB(r,g,b)
        currentH,currentS,currentV=color:ToHSV(); refreshCanvas(); applyColor()
    end
    rBox.FocusLost:Connect(applyRGB)
    gBox.FocusLost:Connect(applyRGB)
    bBox.FocusLost:Connect(applyRGB)

    alphaBox.FocusLost:Connect(function()
        local pct=tonumber((alphaBox.Text:gsub("%%","")))
        if pct then currentA=math.clamp(pct/100,0,1); applyColor() end
    end)

    oldSwatch.InputBegan:Connect(function(i)
        if i.UserInputType==Enum.UserInputType.MouseButton1 then
            currentH,currentS,currentV=originalColor:ToHSV(); refreshCanvas(); applyColor()
        end
    end)

    function cpObj:SetValue(c)
        currentH,currentS,currentV=c:ToHSV(); refreshCanvas(); applyColor()
    end

    function cpObj:SetValueRGB(c, transparency)
        self:SetValue(c)
        self.Transparency = transparency or 0
    end

    refreshCanvas(); applyColor()
    return panel
end

local _mobileKeybindCount = 0
-- ================================================================================
--  MOBILE KEYBIND FLOAT BUTTONS (Mobile-only pill buttons)
-- ================================================================================
local _isMobile = UserInputService.TouchEnabled and not UserInputService.KeyboardEnabled

local function _createMobileKeybind(title, onToggleCallback)
    -- On PC: no float buttons, keybinds handled via keyboard only
    if not (_isMobile or Aurora.MobileButtonOverride) then
        return nil, nil, nil
    end

    if not Aurora.MobileKeybindsGui then
        Aurora.MobileKeybindsGui = make("ScreenGui", {
            Name = "AuroraMobileKeybinds",
            ResetOnSpawn = false,
            DisplayOrder = 99995
        })
        safeParent(Aurora.MobileKeybindsGui)
    end

    _mobileKeybindCount = _mobileKeybindCount + 1
    local thm = Aurora.Theme or Aurora.Themes.Dark

    -- Pill button layout: right side of screen, stacked vertically with small gap
    local pillW, pillH = s(110), s(32)
    local yOffset = s(160) + (_mobileKeybindCount - 1) * (pillH + s(6))
    local defaultPos = UDim2.new(1, -(pillW + s(8)), 0, yOffset)

    -- Container for pill + dot indicator
    local mobileBtn = make("TextButton", {
        Name = "MobileKeybind_" .. title,
        Size = UDim2.fromOffset(pillW, pillH),
        Position = defaultPos,
        BackgroundColor3 = Color3.fromRGB(18, 18, 24),
        BackgroundTransparency = 0.18,
        Text = "",
        ZIndex = 200,
        Parent = Aurora.MobileKeybindsGui
    })
    make("UICorner", { CornerRadius = UDim.new(1, 0), Parent = mobileBtn })
    local mobileStroke = make("UIStroke", {
        Color = thm.Border,
        Thickness = 1,
        Parent = mobileBtn
    })
    -- Gloss overlay
    local pillGloss = make("Frame", {
        Size = UDim2.new(1, -s(4), 0, s(10)),
        Position = UDim2.new(0, s(2), 0, s(1)),
        BackgroundColor3 = Color3.fromRGB(255, 255, 255),
        BackgroundTransparency = 0.93,
        BorderSizePixel = 0,
        ZIndex = 201,
        Parent = mobileBtn,
    })
    make("UICorner", { CornerRadius = UDim.new(1, 0), Parent = pillGloss })

    -- Status dot (left side of pill)
    local dot = make("Frame", {
        Size = UDim2.fromOffset(s(7), s(7)),
        AnchorPoint = Vector2.new(0, 0.5),
        Position = UDim2.new(0, s(9), 0.5, 0),
        BackgroundColor3 = thm.Border,
        BorderSizePixel = 0,
        ZIndex = 202,
        Parent = mobileBtn,
    })
    make("UICorner", { CornerRadius = UDim.new(1, 0), Parent = dot })

    -- Truncated label (max 12 chars looks good at this size)
    local shortText = title or "Feature"
    if #shortText > 12 then shortText = shortText:sub(1, 11) .. "-" end

    local mobileLbl = make("TextLabel", {
        Size = UDim2.new(1, -s(22), 1, 0),
        Position = UDim2.new(0, s(22), 0, 0),
        BackgroundTransparency = 1,
        Text = shortText,
        TextColor3 = thm.SubText,
        TextSize = fs(11),
        Font = Enum.Font.GothamBold,
        TextXAlignment = Enum.TextXAlignment.Left,
        TextTruncate = Enum.TextTruncate.AtEnd,
        ZIndex = 202,
        Parent = mobileBtn
    })

    -- Press scale animation
    local mScale = make("UIScale", { Scale = 1.0, Parent = mobileBtn })
    mobileBtn.InputBegan:Connect(function(i)
        if i.UserInputType == Enum.UserInputType.Touch or i.UserInputType == Enum.UserInputType.MouseButton1 then
            tw(mScale, { Scale = 0.9 }, 0.08, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
        end
    end)
    mobileBtn.InputEnded:Connect(function(i)
        if i.UserInputType == Enum.UserInputType.Touch or i.UserInputType == Enum.UserInputType.MouseButton1 then
            tw(mScale, { Scale = 1.0 }, 0.14, Enum.EasingStyle.Back, Enum.EasingDirection.Out)
        end
    end)

    -- Drag system (touch or mouse)
    local kbDrag = false
    local kbDragStart = nil
    local kbStartPos = nil
    local kbDragDist = 0

    mobileBtn.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.Touch or input.UserInputType == Enum.UserInputType.MouseButton1 then
            kbDrag = true
            kbDragStart = input.Position
            kbStartPos = mobileBtn.Position
            kbDragDist = 0
        end
    end)

    UserInputService.InputChanged:Connect(function(input)
        if kbDrag and (input.UserInputType == Enum.UserInputType.Touch or input.UserInputType == Enum.UserInputType.MouseMovement) then
            local delta = input.Position - kbDragStart
            kbDragDist = delta.Magnitude
            mobileBtn.Position = UDim2.new(
                kbStartPos.X.Scale, kbStartPos.X.Offset + delta.X,
                kbStartPos.Y.Scale, kbStartPos.Y.Offset + delta.Y
            )
        end
    end)

    UserInputService.InputEnded:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.Touch or input.UserInputType == Enum.UserInputType.MouseButton1 then
            kbDrag = false
        end
    end)

    mobileBtn.MouseButton1Click:Connect(function()
        if kbDragDist < 8 then
            pcall(onToggleCallback)
        end
    end)

    -- Return dot as 4th value so callers can update it without touching Instance properties
    return mobileBtn, mobileStroke, mobileLbl, dot
end

-- ================================================================================
--  SECTION CLASS
-- ================================================================================
local Section = {}
Section.__index = Section

-- TOGGLE
function Section:AddToggle(id, cfg)
    cfg = cfg or {}
    local callbacks = {}
    local originalCallback = cfg.Callback
    cfg.Callback = function(val)
        if originalCallback then pcall(originalCallback, val) end
        for _, c in ipairs(callbacks) do
            pcall(c, val)
        end
    end
    local title = cfg.Title or "Toggle"
    local desc  = cfg.Description
    local def   = cfg.Default or false
    local cb    = cfg.Callback or function() end
    local thm   = Aurora.Theme

    local obj = { Type="Toggle", Value=def, id=id }
    local f = elemFrame(self.Container)
    addTooltip(f, cfg.Tooltip)

    local topF = make("Frame", { Size=UDim2.new(1,0,0,s(4)), AutomaticSize=Enum.AutomaticSize.Y, BackgroundTransparency=1, LayoutOrder=1, Parent=f })
    local txtF = make("Frame", { Size=UDim2.new(1,-s(130),0,0), AutomaticSize=Enum.AutomaticSize.Y, BackgroundTransparency=1, Parent=topF })
    make("UIListLayout", { SortOrder=Enum.SortOrder.LayoutOrder, Padding=sz(3), Parent=txtF })

    local tx = 0
    if cfg.Icon then
        local ico = make("ImageLabel",{Size=ss(16,16),BackgroundTransparency=1,Parent=txtF,LayoutOrder=-1})
        applyIcon(ico, cfg.Icon, thm.IconColor); tx=s(22)
    end

    make("TextLabel", {
        Size=UDim2.new(1,-tx,0,0), Position=UDim2.new(0,tx,0,0), AutomaticSize=Enum.AutomaticSize.Y,
        BackgroundTransparency=1, Text=title, TextColor3=thm.Text, TextSize=fs(16),
        Font=Enum.Font.GothamBold, TextXAlignment=Enum.TextXAlignment.Left, TextWrapped=true, Parent=txtF,
    })
    if desc then
        make("TextLabel", {
            Size=UDim2.new(1,-tx,0,0), Position=UDim2.new(0,tx,0,0), AutomaticSize=Enum.AutomaticSize.Y,
            BackgroundTransparency=1, Text=desc, TextColor3=thm.SubText, TextSize=fs(16),
            Font=Enum.Font.Gotham, TextXAlignment=Enum.TextXAlignment.Left, TextWrapped=true, Parent=txtF,
        })
    end

    local rightControls = make("Frame", {
        Size=UDim2.new(0,0,1,0), AutomaticSize=Enum.AutomaticSize.X,
        AnchorPoint=Vector2.new(1,0.5), Position=UDim2.new(1,0,0.5,0),
        BackgroundTransparency=1, ZIndex=5, Parent=topF,
    })
    make("UIListLayout", {
        FillDirection=Enum.FillDirection.Horizontal, HorizontalAlignment=Enum.HorizontalAlignment.Right,
        VerticalAlignment=Enum.VerticalAlignment.Center, SortOrder=Enum.SortOrder.LayoutOrder, Padding=sz(8),
        Parent=rightControls,
    })

    -- Modern pill-style toggle switch
    local pillW, pillH = s(38), s(20)
    local knobSize = s(16)
    local pill = make("TextButton", {
        Size=UDim2.fromOffset(pillW, pillH),
        BackgroundColor3=def and thm.ToggleOn or thm.ToggleOff,
        Text="", AutoButtonColor=false,
        LayoutOrder=10, ZIndex=6, Parent=rightControls,
    })
    make("UICorner", { CornerRadius=UDim.new(1,0), Parent=pill })
    local pillStroke = make("UIStroke", {
        Color=def and thm.ToggleOn or thm.Border,
        Thickness=1, Parent=pill
    })
    -- Inner highlight (top gloss)
    local pillGloss = make("Frame", {
        Size=UDim2.new(1,-s(2),0,s(8)),
        Position=UDim2.new(0,s(1),0,s(1)),
        BackgroundColor3=Color3.fromRGB(255,255,255),
        BackgroundTransparency=0.88, BorderSizePixel=0, ZIndex=7,
        Parent=pill,
    })
    make("UICorner", { CornerRadius=UDim.new(1,0), Parent=pillGloss })
    -- Knob
    local knob = make("Frame", {
        Size=UDim2.fromOffset(knobSize, knobSize),
        AnchorPoint=Vector2.new(0,0.5),
        Position=def and UDim2.new(1,-(knobSize+s(2)),0.5,0) or UDim2.new(0,s(2),0.5,0),
        BackgroundColor3=Color3.fromRGB(255,255,255),
        BorderSizePixel=0, ZIndex=8,
        Parent=pill,
    })
    make("UICorner", { CornerRadius=UDim.new(1,0), Parent=knob })
    make("UIStroke", { Color=Color3.fromRGB(0,0,0), Transparency=0.88, Thickness=1, Parent=knob })
    -- Knob shadow (subtle)
    local knobShadow = make("ImageLabel", {
        Size=UDim2.fromOffset(knobSize+s(4), knobSize+s(4)),
        AnchorPoint=Vector2.new(0.5,0.5),
        Position=UDim2.fromScale(0.5,0.5),
        BackgroundTransparency=1,
        Image="rbxassetid://6014261993",
        ImageColor3=Color3.fromRGB(0,0,0),
        ImageTransparency=0.85,
        ZIndex=7, Parent=knob,
    })

    local function set(v, silent)
        obj.Value=v
        local currentThm = Aurora.Theme
        tw(pill, { BackgroundColor3=v and currentThm.ToggleOn or currentThm.ToggleOff }, 0.18, Enum.EasingStyle.Quad)
        tw(pillStroke, { Color=v and currentThm.ToggleOn or currentThm.Border }, 0.18)
        tw(knob, {
            Position=v and UDim2.new(1,-(knobSize+s(2)),0.5,0) or UDim2.new(0,s(2),0.5,0)
        }, 0.2, Enum.EasingStyle.Back, Enum.EasingDirection.Out)
        if not silent then pcall(cb, v) end
        triggerAutosave()
        if Aurora.RefreshKeybindList then task.defer(Aurora.RefreshKeybindList) end
        if obj.Keybind and obj.Keybind.updateVisualState then
            pcall(obj.Keybind.updateVisualState)
        end
    end

    pill.MouseButton1Click:Connect(function() set(not obj.Value) end)
    -- Press animation
    pill.InputBegan:Connect(function(i)
        if i.UserInputType == Enum.UserInputType.MouseButton1 then
            tw(knob, { Size=UDim2.fromOffset(knobSize+s(3), knobSize-s(2)) }, 0.08)
        end
    end)
    pill.InputEnded:Connect(function(i)
        if i.UserInputType == Enum.UserInputType.MouseButton1 then
            tw(knob, { Size=UDim2.fromOffset(knobSize, knobSize) }, 0.12, Enum.EasingStyle.Back)
        end
    end)

    local btn = make("TextButton", {
        Size=UDim2.new(1,-s(170),1,0), BackgroundTransparency=1, Text="", ZIndex=1, Parent=topF,
    })
    btn.MouseButton1Click:Connect(function() set(not obj.Value) end)
    registerHover(f, btn)

    function obj:SetValue(v) set(v, true) end

    function obj:OnChanged(func)
        table.insert(callbacks, func)
        pcall(func, obj.Value)
        return {
            Disconnect = function()
                local idx = table.find(callbacks, func)
                if idx then table.remove(callbacks, idx) end
            end
        }
    end

    -- Inline Keybind
    function obj:AddKeybind(kbId, kbCfg)
        kbCfg = kbCfg or {}
        local defaultKey = kbCfg.Default or Enum.KeyCode.None
        local kbObj = { Type="Keybind", Value=defaultKey, id=kbId, ToggleParent=obj }
        local binding = false

        local kbBtn = make("TextButton", {
            Size=ss(55,20), BackgroundColor3=thm.InputBG,
            Text=defaultKey==Enum.KeyCode.None and "None" or defaultKey.Name,
            TextColor3=thm.SubText, TextSize=fs(16), Font=Enum.Font.GothamBold,
            LayoutOrder=5, ZIndex=10, Parent=rightControls,
        })
        make("UICorner", { CornerRadius=sz(8), Parent=kbBtn })
        local kbStroke = make("UIStroke", { Color=thm.Border, Thickness=1, Parent=kbBtn })

        local mobileBtn, mobileStroke, mobileLbl, mobileDot = _createMobileKeybind(kbCfg.Title or cfg.Title or title or "Toggle", function()
            set(not obj.Value)
        end)

        local function updateVisualState()
            if binding then return end
            local currentThm = Aurora.Theme or Aurora.Themes.Dark
            local active = obj.Value
            local activeColor = Color3.fromRGB(38, 195, 95)
            local activeBG    = Color3.fromRGB(15, 60, 30)
            if active then
                tw(kbBtn, { BackgroundColor3 = activeBG, TextColor3 = activeColor }, 0.12)
                tw(kbStroke, { Color = activeColor }, 0.12)
                if mobileBtn then
                    tw(mobileBtn, { BackgroundColor3 = activeBG }, 0.12)
                    tw(mobileStroke, { Color = activeColor }, 0.12)
                    mobileLbl.TextColor3 = activeColor
                    if mobileDot then
                        tw(mobileDot, { BackgroundColor3 = activeColor }, 0.12)
                    end
                end
            else
                tw(kbBtn, { BackgroundColor3 = currentThm.InputBG, TextColor3 = currentThm.SubText }, 0.12)
                tw(kbStroke, { Color = currentThm.Border }, 0.12)
                if mobileBtn then
                    tw(mobileBtn, { BackgroundColor3 = Color3.fromRGB(18, 18, 24) }, 0.12)
                    tw(mobileStroke, { Color = currentThm.Border }, 0.12)
                    mobileLbl.TextColor3 = currentThm.SubText
                    if mobileDot then
                        tw(mobileDot, { BackgroundColor3 = currentThm.Border }, 0.12)
                    end
                end
            end
        end

        local function updateKey(key)
            kbObj.Value=key
            if typeof(key) == "EnumItem" then
                if key.EnumType == Enum.KeyCode then
                    kbBtn.Text = key == Enum.KeyCode.None and "None" or key.Name
                elseif key.EnumType == Enum.UserInputType then
                    kbBtn.Text = key.Name:gsub("MouseButton", "MB")
                else
                    kbBtn.Text = "None"
                end
            else
                kbBtn.Text = "None"
            end
            triggerAutosave()
            if Aurora.RefreshKeybindList then task.defer(Aurora.RefreshKeybindList) end
        end

        kbBtn.MouseButton1Click:Connect(function()
            if binding then return end
            binding=true; kbBtn.Text="..."; kbBtn.TextColor3=thm.Accent
            task.spawn(function()
                task.wait()
                local conn
                conn=UserInputService.InputBegan:Connect(function(input)
                    if input.UserInputType==Enum.UserInputType.Keyboard then
                        conn:Disconnect(); binding=false
                        local k=input.KeyCode
                        updateKey(k==Enum.KeyCode.Escape and Enum.KeyCode.None or k)
                        kbBtn.TextColor3=thm.SubText
                        if kbCfg.Callback then pcall(kbCfg.Callback, kbObj.Value) end
                    elseif input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.MouseButton2 or input.UserInputType == Enum.UserInputType.MouseButton3 then
                        conn:Disconnect(); binding=false
                        updateKey(input.UserInputType)
                        kbBtn.TextColor3=thm.SubText
                        if kbCfg.Callback then pcall(kbCfg.Callback, kbObj.Value) end
                    end
                end)
            end)
        end)

        local inlineBegan = UserInputService.InputBegan:Connect(function(input,processed)
            if not processed and not binding then
                if input.KeyCode==kbObj.Value or input.UserInputType==kbObj.Value then
                    set(not obj.Value)
                end
            end
        end)
        if self._tab and self._tab._window and self._tab._window._connections then
            table.insert(self._tab._window._connections, inlineBegan)
        end
        kbBtn.Destroying:Connect(function()
            pcall(function() inlineBegan:Disconnect() end)
        end)

        local themeObj = {
            isCallback = true,
            callback = function()
                if not kbBtn or not kbBtn.Parent then return end
                pcall(updateVisualState)
            end
        }
        table.insert(Aurora.ThemeObjs, themeObj)

        f.Destroying:Connect(function()
            if mobileBtn then pcall(function() mobileBtn:Destroy() end) end
            for idx, item in ipairs(Aurora.ThemeObjs) do
                if item == themeObj then
                    table.remove(Aurora.ThemeObjs, idx)
                    break
                end
            end
        end)

        function kbObj:SetValue(key) updateKey(key) end
        kbObj.updateVisualState = updateVisualState
        obj.Keybind = kbObj
        updateVisualState()

        Aurora.Options[kbId]=kbObj
        return kbObj
    end

    -- Inline Colorpicker
    function obj:AddColorpicker(cpId, cpCfg)
        cpCfg = cpCfg or {}
        local cpObj = { Type="Colorpicker", Value=cpCfg.Default or Color3.fromRGB(255,255,255), id=cpId }

        local colDisp = make("Frame", {
            Size=ss(20,20), BackgroundColor3=cpObj.Value,
            LayoutOrder=1, ZIndex=10, Parent=rightControls,
        })
        make("UICorner", { CornerRadius=sz(7), Parent=colDisp })
        make("UIStroke", { Color=thm.Border, Thickness=1, Parent=colDisp })

        local cpBtn = make("TextButton", {
            Size=UDim2.fromScale(1,1), BackgroundTransparency=1, Text="", ZIndex=11, Parent=colDisp,
        })

        local cpPanel = createColorpickerPanel(f, cpObj, cpCfg, colDisp)
        local cpExpanded = false

        cpBtn.MouseButton1Click:Connect(function()
            cpExpanded=not cpExpanded
            tw(cpPanel, { Size=UDim2.new(1,0,0,cpExpanded and s(148) or 0) }, 0.22)
        end)

        Aurora.Options[cpId]=cpObj
        return cpObj
    end

    if cfg.Keybind then
        local kbCfg=type(cfg.Keybind)=="table" and cfg.Keybind or {}
        obj:AddKeybind(id.."_Bind", kbCfg)
    end
    if cfg.Colorpicker then
        local cpCfg=type(cfg.Colorpicker)=="table" and cfg.Colorpicker or {}
        obj:AddColorpicker(id.."_Color", cpCfg)
    end

    _registerElement(title, f, self._tab, self._subTab)
    addVisibilityAPI(obj, f)
    Aurora.Options[id]=obj
    return obj
end

-- SLIDER
function Section:AddSlider(id, cfg)
    cfg=cfg or {}
    local callbacks = {}
    local originalCallback = cfg.Callback
    cfg.Callback = function(val)
        if originalCallback then pcall(originalCallback, val) end
        for _, c in ipairs(callbacks) do
            pcall(c, val)
        end
    end
    local thm=Aurora.Theme
    local obj={Type="Slider",Value=cfg.Default or cfg.Min or 0,id=id}
    local min,max=cfg.Min or 0,cfg.Max or 100
    local dec=cfg.Decimals or 0

    local f=elemFrame(self.Container)
    addTooltip(f, cfg.Tooltip)
    local topF=make("Frame",{Size=UDim2.new(1,0,0,s(20)),BackgroundTransparency=1,LayoutOrder=1,Parent=f})

    local tx=0
    if cfg.Icon then
        local ico=make("ImageLabel",{Size=ss(16,16),BackgroundTransparency=1,Parent=topF})
        applyIcon(ico,cfg.Icon,thm.IconColor); tx=s(22)
    end

    make("TextLabel",{
        Size=UDim2.new(0.6,-tx,1,0),Position=UDim2.new(0,tx,0,0),
        BackgroundTransparency=1,Text=cfg.Title or "Slider",TextColor3=thm.Text,
        TextSize=fs(16),Font=Enum.Font.GothamBold,TextXAlignment=Enum.TextXAlignment.Left,Parent=topF,
    })

    local valBox=make("TextBox",{
        Size=ss(80,18),AnchorPoint=Vector2.new(1,0.5),Position=UDim2.new(1,0,0.5,0),
        BackgroundTransparency=1,Text=tostring(obj.Value)..(cfg.Suffix or ""),
        TextColor3=thm.SubText,TextSize=fs(16),Font=Enum.Font.GothamBold,
        TextXAlignment=Enum.TextXAlignment.Right,ClearTextOnFocus=false,Parent=topF,
    })

    local tr=make("Frame",{Size=UDim2.new(1,0,0,s(5)),LayoutOrder=2,BackgroundColor3=thm.SliderTrack,Parent=f})
    make("UICorner",{CornerRadius=UDim.new(1,0),Parent=tr})
    local fill=make("Frame",{Size=UDim2.new(0,0,1,0),BackgroundColor3=thm.SliderFill,Parent=tr})
    make("UICorner",{CornerRadius=UDim.new(1,0),Parent=fill})
    -- Gradient on fill for a glowing look
    make("UIGradient",{
        Color=ColorSequence.new({
            ColorSequenceKeypoint.new(0, Color3.fromRGB(255,255,255)),
            ColorSequenceKeypoint.new(1, Color3.fromRGB(200,200,200)),
        }),
        Transparency=NumberSequence.new({
            NumberSequenceKeypoint.new(0, 0.35),
            NumberSequenceKeypoint.new(1, 0),
        }),
        Rotation=0, Parent=fill,
    })
    reg(fill,"BackgroundColor3","SliderFill")
    -- Knob/thumb
    local knobSz = s(16)
    local sliderKnob = make("Frame",{
        Size=UDim2.fromOffset(knobSz,knobSz),
        AnchorPoint=Vector2.new(0.5,0.5), Position=UDim2.new(0,0,0.5,0),
        BackgroundColor3=Color3.fromRGB(255,255,255),
        BorderSizePixel=0, ZIndex=5, Parent=tr,
    })
    make("UICorner",{CornerRadius=UDim.new(1,0),Parent=sliderKnob})
    make("UIStroke",{Color=thm.SliderFill,Thickness=2,Parent=sliderKnob})
    local knobScale = make("UIScale",{Scale=1,Parent=sliderKnob})

    local function update(x)
        local r=math.clamp((x-tr.AbsolutePosition.X)/tr.AbsoluteSize.X,0,1)
        local raw=min+(max-min)*r
        local val=dec==0 and math.floor(raw+.5) or math.floor(raw*(10^dec)+.5)/(10^dec)
        obj.Value=val; fill.Size=UDim2.new(r,0,1,0)
        sliderKnob.Position=UDim2.new(r,0,0.5,0)
        valBox.Text=tostring(val)..(cfg.Suffix or "")
        if cfg.Callback then pcall(cfg.Callback,val) end
        triggerAutosave()
    end

    local drag=false
    tr.InputBegan:Connect(function(i)
        if i.UserInputType==Enum.UserInputType.MouseButton1 or i.UserInputType==Enum.UserInputType.Touch then
            drag=true; update(i.Position.X)
            tw(knobScale,{Scale=1.3},0.1,Enum.EasingStyle.Back)
        end
    end)
    local sliderChanged = UserInputService.InputChanged:Connect(function(i) if drag and (i.UserInputType==Enum.UserInputType.MouseMovement or i.UserInputType==Enum.UserInputType.Touch) then update(i.Position.X) end end)
    local sliderEnded = UserInputService.InputEnded:Connect(function(i)
        if i.UserInputType==Enum.UserInputType.MouseButton1 or i.UserInputType==Enum.UserInputType.Touch then
            drag=false
            tw(knobScale,{Scale=1},0.12,Enum.EasingStyle.Back)
        end
    end)
    if self._tab and self._tab._window and self._tab._window._connections then
        table.insert(self._tab._window._connections, sliderChanged)
        table.insert(self._tab._window._connections, sliderEnded)
    end
    f.Destroying:Connect(function()
        pcall(function() sliderChanged:Disconnect() end)
        pcall(function() sliderEnded:Disconnect() end)
    end)

    function obj:SetValue(v)
        v=math.clamp(v,min,max); obj.Value=v
        local r=(v-min)/(max-min)
        fill.Size=UDim2.new(r,0,1,0)
        sliderKnob.Position=UDim2.new(r,0,0.5,0)
        valBox.Text=tostring(v)..(cfg.Suffix or "")
        if cfg.Callback then pcall(cfg.Callback,v) end
        triggerAutosave()
    end

    valBox.FocusLost:Connect(function()
        local num=tonumber((valBox.Text:gsub(cfg.Suffix or "","")))
        if num then obj:SetValue(num) else valBox.Text=tostring(obj.Value)..(cfg.Suffix or "") end
    end)

    registerHover(f, f)

    function obj:OnChanged(func)
        table.insert(callbacks, func)
        pcall(func, obj.Value)
        return {
            Disconnect = function()
                local idx = table.find(callbacks, func)
                if idx then table.remove(callbacks, idx) end
            end
        }
    end

    _registerElement(cfg.Title or "Slider", f, self._tab, self._subTab)
    obj:SetValue(obj.Value)
    addVisibilityAPI(obj, f)
    Aurora.Options[id]=obj
    return obj
end

-- ALERT
function Section:AddAlert(cfg)
    cfg=cfg or{}
    local thm=Aurora.Theme
    local typ=cfg.Type or "Info"
    local amap={Info=thm.AlertInfo,Warning=thm.AlertWarn,Error=thm.AlertError,Success=thm.AlertSuccess}
    local imap={Info="solar/info-circle-bold",Warning="solar/danger-bold",Error="solar/close-circle-bold",Success="solar/check-circle-bold"}
    local col=amap[typ] or thm.Accent

    if Aurora.LazyLoad then
        task.wait(Aurora.DelayPerElement or 0.01)
    end

    local f=make(Aurora.FadeIn and "CanvasGroup" or "Frame",{Size=UDim2.new(1,0,0,0),AutomaticSize=Enum.AutomaticSize.Y,BackgroundTransparency=1,Parent=self.Container})
    
    local bgFrame=make("Frame",{Size=UDim2.new(1,0,1,0),BackgroundColor3=thm.Element,Parent=f})
    make("UICorner",{CornerRadius=sz(11),Parent=bgFrame})
    make("UIStroke",{Color=col,Thickness=1,Transparency=0.55,Parent=bgFrame})
    
    make("UIPadding",{PaddingTop=sz(6),PaddingBottom=sz(6),PaddingLeft=sz(10),PaddingRight=sz(10),Parent=f})
    
    local bar=make("Frame",{Size=UDim2.new(0,s(3),1,0),Position=UDim2.new(0,-s(10),0,0),BackgroundColor3=col,Parent=f})
    make("UICorner",{CornerRadius=sz(2),Parent=bar})
    
    local contentF = make("Frame", {Size=UDim2.new(1,0,0,0),AutomaticSize=Enum.AutomaticSize.Y,BackgroundTransparency=1,Parent=f})
    make("UIListLayout",{SortOrder=Enum.SortOrder.LayoutOrder,Padding=sz(4),Parent=contentF})
    
    local header=make("Frame",{Size=UDim2.new(1,0,0,s(18)),BackgroundTransparency=1,Parent=contentF})
    local ico=make("ImageLabel",{Size=ss(14,14),Position=UDim2.new(0,0,0.5,0),AnchorPoint=Vector2.new(0,0.5),BackgroundTransparency=1,Parent=header})
    applyIcon(ico,imap[typ],col)
    make("TextLabel",{
        Size=UDim2.new(1,-s(20),1,0),Position=UDim2.new(0,s(20),0,0),
        BackgroundTransparency=1,Text=cfg.Title or "Alert",TextColor3=thm.Text,
        TextSize=fs(16),Font=Enum.Font.GothamBold,TextXAlignment=Enum.TextXAlignment.Left,Parent=header,
    })
    if cfg.Content and cfg.Content ~= "" then
        make("TextLabel",{
            Size=UDim2.new(1,0,0,0),AutomaticSize=Enum.AutomaticSize.Y,
            BackgroundTransparency=1,Text=cfg.Content,TextColor3=thm.SubText,
            TextSize=fs(16),Font=Enum.Font.Gotham,TextXAlignment=Enum.TextXAlignment.Left,TextWrapped=true,Parent=contentF,
        })
    end

    if Aurora.FadeIn then
        f.GroupTransparency = 1
        task.defer(function()
            tw(f, { GroupTransparency = 0 }, 0.3, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
        end)
    end

    local obj = {Type = "Alert"}
    addVisibilityAPI(obj, f)
    return obj
end

-- STANDALONE COLORPICKER
function Section:AddColorpicker(id, cfg)
    cfg=cfg or{}
    local callbacks = {}
    local originalCallback = cfg.Callback
    cfg.Callback = function(val)
        if originalCallback then pcall(originalCallback, val) end
        for _, c in ipairs(callbacks) do
            pcall(c, val)
        end
    end
    local thm=Aurora.Theme
    local obj={Type="Colorpicker",Value=cfg.Default or Color3.fromRGB(255,255,255),id=id}

    local f=elemFrame(self.Container)
    addTooltip(f, cfg.Tooltip)
    local topF=make("Frame",{Size=UDim2.new(1,0,0,s(30)),BackgroundTransparency=1,LayoutOrder=1,Parent=f})

    local tx=0
    if cfg.Icon then
        local ico=make("ImageLabel",{Size=ss(16,16),AnchorPoint=Vector2.new(0,0.5),Position=UDim2.new(0,0,0.5,0),BackgroundTransparency=1,Parent=topF})
        applyIcon(ico,cfg.Icon,thm.IconColor); tx=s(22)
    end

    make("TextLabel",{
        Size=UDim2.new(0.6,-tx,1,0),Position=UDim2.new(0,tx,0,0),
        BackgroundTransparency=1,Text=cfg.Title or "Color",TextColor3=thm.Text,
        TextSize=fs(16),Font=Enum.Font.GothamBold,TextXAlignment=Enum.TextXAlignment.Left,Parent=topF,
    })

    local colDisp=make("Frame",{
        Size=ss(36,18),AnchorPoint=Vector2.new(1,0.5),Position=UDim2.new(1,0,0.5,0),
        BackgroundColor3=obj.Value,Parent=topF,
    })
    make("UICorner",{CornerRadius=sz(8),Parent=colDisp})
    make("UIStroke",{Color=thm.Border,Thickness=1,Parent=colDisp})

    local cpPanel=createColorpickerPanel(f,obj,cfg,colDisp)
    local btn=make("TextButton",{Size=UDim2.new(1,0,1,0),BackgroundTransparency=1,Text="",Parent=topF})
    local cpExpanded=false
    btn.MouseButton1Click:Connect(function()
        cpExpanded=not cpExpanded
        tw(cpPanel,{Size=UDim2.new(1,0,0,cpExpanded and s(148) or 0)},0.22)
    end)
    registerHover(f, btn)

    function obj:OnChanged(func)
        table.insert(callbacks, func)
        pcall(func, obj.Value)
        return {
            Disconnect = function()
                local idx = table.find(callbacks, func)
                if idx then table.remove(callbacks, idx) end
            end
        }
    end

    _registerElement(cfg.Title or "Color", f, self._tab, self._subTab)
    addVisibilityAPI(obj, f)
    Aurora.Options[id]=obj
    return obj
end

-- SEPARATOR
function Section:AddSeparator(text)
    if Aurora.LazyLoad then
        task.wait(Aurora.DelayPerElement or 0.01)
    end
    local f=make(Aurora.FadeIn and "CanvasGroup" or "Frame",{Size=UDim2.new(1,0,0,s(18)),BackgroundTransparency=1,Parent=self.Container})
    make("Frame",{Size=UDim2.new(1,0,0,1),AnchorPoint=Vector2.new(0.5,0.5),Position=UDim2.new(0.5,0,0.5,0),BackgroundColor3=Aurora.Theme.Border,BorderSizePixel=0,Parent=f})
    if text and text~="" then
        local tl=make("TextLabel",{
            Size=UDim2.new(0,0,1,0),AutomaticSize=Enum.AutomaticSize.X,AnchorPoint=Vector2.new(0.5,0.5),Position=UDim2.new(0.5,0,0.5,0),
            BackgroundColor3=Aurora.Theme.Background,Text=" "..text.." ",TextColor3=Aurora.Theme.SubText,TextSize=fs(10),Font=Enum.Font.GothamBold,Parent=f,
        })
        reg(tl,"BackgroundColor3","Background")
    end
    if Aurora.FadeIn then
        f.GroupTransparency = 1
        task.defer(function()
            tw(f, { GroupTransparency = 0 }, 0.3, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
        end)
    end
    local obj = {Type = "Separator"}
    addVisibilityAPI(obj, f)
    return obj
end

-- BUTTON
function Section:AddButton(cfg)
    cfg=cfg or{}
    local thm=Aurora.Theme
    local f=elemFrame(self.Container)
    addTooltip(f, cfg.Tooltip)
    local topF=make("Frame",{Size=UDim2.new(1,0,0,0),AutomaticSize=Enum.AutomaticSize.Y,BackgroundTransparency=1,LayoutOrder=1,Parent=f})
    local txtF=make("Frame",{Size=UDim2.new(1,-s(26),0,0),AutomaticSize=Enum.AutomaticSize.Y,BackgroundTransparency=1,Parent=topF})
    make("UIListLayout",{SortOrder=Enum.SortOrder.LayoutOrder,Padding=sz(2),Parent=txtF})

    local tx=0
    if cfg.Icon then
        local ico=make("ImageLabel",{Size=ss(16,16),BackgroundTransparency=1,Parent=txtF,LayoutOrder=-1})
        applyIcon(ico,cfg.Icon,thm.IconColor); tx=s(22)
    end

    local titleLbl = make("TextLabel",{
        Size=UDim2.new(1,-tx,0,0),Position=UDim2.new(0,tx,0,0),AutomaticSize=Enum.AutomaticSize.Y,
        BackgroundTransparency=1,Text=cfg.Title or "Button",TextColor3=thm.Text,
        TextSize=fs(16),Font=Enum.Font.GothamBold,TextXAlignment=Enum.TextXAlignment.Left,TextWrapped=true,Parent=txtF,
    })

    local descLbl
    if cfg.Description or cfg.Desc then
        descLbl = make("TextLabel",{
            Size=UDim2.new(1,-tx,0,0),Position=UDim2.new(0,tx,0,0),AutomaticSize=Enum.AutomaticSize.Y,
            BackgroundTransparency=1,Text=cfg.Description or cfg.Desc,TextColor3=thm.SubText,
            TextSize=fs(16),Font=Enum.Font.Gotham,TextXAlignment=Enum.TextXAlignment.Left,TextWrapped=true,Parent=txtF,
        })
    end

    local arr=make("ImageLabel",{Size=ss(14,14),AnchorPoint=Vector2.new(1,0.5),Position=UDim2.new(1,0,0.5,0),BackgroundTransparency=1,Parent=topF})
    applyIcon(arr,"solar/alt-arrow-right-bold",thm.Accent)

    local btn=make("TextButton",{Size=UDim2.new(1,0,1,0),BackgroundTransparency=1,Text="",Parent=topF})
    btn.MouseButton1Click:Connect(function()
        -- Ripple effect
        pcall(function()
            local ripple = make("Frame",{
                Size=UDim2.fromOffset(0,0),
                AnchorPoint=Vector2.new(0.5,0.5),
                Position=UDim2.fromScale(0.5,0.5),
                BackgroundColor3=Aurora.Theme.Accent,
                BackgroundTransparency=0.55,
                BorderSizePixel=0, ZIndex=10, Parent=f,
            })
            make("UICorner",{CornerRadius=UDim.new(1,0),Parent=ripple})
            tw(ripple,{Size=UDim2.fromOffset(s(200),s(200)),BackgroundTransparency=1},0.4,Enum.EasingStyle.Quad)
            task.delay(0.42,function() pcall(function() ripple:Destroy() end) end)
        end)
        tw(f,{BackgroundColor3=Aurora.Theme.Accent,BackgroundTransparency=0.6},0.06)
        task.delay(0.1,function() tw(f,{BackgroundColor3=Aurora.Theme.Element,BackgroundTransparency=1},0.2) end)
        if cfg.Callback then pcall(cfg.Callback) end
    end)
    registerHover(f, btn)

    local obj = {Type = "Button"}
    function obj:SetTitle(t) titleLbl.Text = t end
    function obj:SetDesc(d)
        if descLbl then
            descLbl.Text = d
        else
            descLbl = make("TextLabel",{
                Size=UDim2.new(1,-tx,0,0),Position=UDim2.new(0,tx,0,0),AutomaticSize=Enum.AutomaticSize.Y,
                BackgroundTransparency=1,Text=d,TextColor3=thm.SubText,
                TextSize=fs(16),Font=Enum.Font.Gotham,TextXAlignment=Enum.TextXAlignment.Left,TextWrapped=true,Parent=txtF,
            })
        end
    end
    function obj:SetDescription(d) self:SetDesc(d) end
    _registerElement(cfg.Title or "Button", f, self._tab, self._subTab)
    addVisibilityAPI(obj, f)
    return obj
end

-- PARAGRAPH
function Section:AddParagraph(cfg)
    cfg=cfg or{}
    local thm=Aurora.Theme
    local f=elemFrame(self.Container)
    local topF=make("Frame",{Size=UDim2.new(1,0,0,0),AutomaticSize=Enum.AutomaticSize.Y,BackgroundTransparency=1,LayoutOrder=1,Parent=f})
    local txtF=make("Frame",{Size=UDim2.new(1,0,0,0),AutomaticSize=Enum.AutomaticSize.Y,BackgroundTransparency=1,Parent=topF})
    make("UIListLayout",{SortOrder=Enum.SortOrder.LayoutOrder,Padding=sz(2),Parent=txtF})
    local tx=0
    if cfg.Icon then
        local ico=make("ImageLabel",{Size=ss(14,14),BackgroundTransparency=1,Parent=txtF,LayoutOrder=-1})
        applyIcon(ico,cfg.Icon,thm.IconColor); tx=s(20)
    end
    local titleLbl = make("TextLabel",{
        Size=UDim2.new(1,-tx,0,0),Position=UDim2.new(0,tx,0,0),AutomaticSize=Enum.AutomaticSize.Y,
        BackgroundTransparency=1,Text=cfg.Title or "",TextColor3=thm.Text,
        TextSize=fs(16),Font=Enum.Font.GothamBold,TextXAlignment=Enum.TextXAlignment.Left,TextWrapped=true,Parent=txtF,
    })
    local contentLbl = make("TextLabel",{
        Size=UDim2.new(1,-tx,0,0),Position=UDim2.new(0,tx,0,0),AutomaticSize=Enum.AutomaticSize.Y,
        BackgroundTransparency=1,Text=cfg.Content or "",TextColor3=thm.SubText,
        TextSize=fs(16),Font=Enum.Font.Gotham,TextXAlignment=Enum.TextXAlignment.Left,TextWrapped=true,Parent=txtF,
    })

    local obj = {Type = "Paragraph"}
    function obj:SetTitle(t) titleLbl.Text = t end
    function obj:SetContent(c) contentLbl.Text = c end
    addVisibilityAPI(obj, f)
    return obj
end

function Section:AddDropdown(id, cfg)
    cfg=cfg or{}
    local callbacks = {}
    local originalCallback = cfg.Callback
    cfg.Callback = function(val)
        if originalCallback then pcall(originalCallback, val) end
        for _, c in ipairs(callbacks) do
            pcall(c, val)
        end
    end
    local thm=Aurora.Theme
    local obj={Type="Dropdown",Value=cfg.Default or "",Multi=cfg.Multi or false,id=id}
    if obj.Multi and type(obj.Value)~="table" then obj.Value={} end

    local f=elemFrame(self.Container)
    addTooltip(f, cfg.Tooltip)
    local topF=make("Frame",{Size=UDim2.new(1,0,0,s(30)),BackgroundTransparency=1,LayoutOrder=1,Parent=f})
    local tx=0
    if cfg.Icon then
        local ico=make("ImageLabel",{Size=ss(16,16),AnchorPoint=Vector2.new(0,0.5),Position=UDim2.new(0,0,0.5,0),BackgroundTransparency=1,Parent=topF})
        applyIcon(ico,cfg.Icon,thm.IconColor); tx=s(22)
    end
    make("TextLabel",{
        Size=UDim2.new(0.5,-tx,1,0),Position=UDim2.new(0,tx,0,0),
        BackgroundTransparency=1,Text=cfg.Title or "Dropdown",TextColor3=thm.Text,
        TextSize=fs(16),Font=Enum.Font.GothamBold,TextXAlignment=Enum.TextXAlignment.Left,Parent=topF,
    })
    local valBox=make("Frame",{Size=UDim2.new(0.5,0,1,0),AnchorPoint=Vector2.new(1,0),Position=UDim2.new(1,0,0,0),BackgroundColor3=thm.InputBG,Parent=topF})
    make("UISizeConstraint",{MaxSize=Vector2.new(s(200),math.huge),Parent=valBox})
    make("UICorner",{CornerRadius=sz(10),Parent=valBox})
    make("UIStroke",{Color=thm.Border,Thickness=1,Parent=valBox})
    local valTxt=make("TextLabel",{
        Size=UDim2.new(1,-s(22),1,0),Position=UDim2.new(0,s(8),0,0),
        BackgroundTransparency=1,Text="",TextColor3=thm.SubText,TextSize=fs(16),
        Font=Enum.Font.Gotham,TextXAlignment=Enum.TextXAlignment.Left,TextTruncate=Enum.TextTruncate.AtEnd,Parent=valBox,
    })
    local arr=make("ImageLabel",{Size=ss(12,12),AnchorPoint=Vector2.new(1,0.5),Position=UDim2.new(1,-s(4),0.5,0),BackgroundTransparency=1,Parent=valBox})
    applyIcon(arr,"solar/alt-arrow-down-linear",thm.SubText)

    local function updateTxt()
        local currentThm = Aurora.Theme or Aurora.Themes.Dark
        local selectedText = ""
        local hasValue = false
        if obj.Multi then
            local selectedNames = {}
            for _, val in ipairs(cfg.Values or {}) do
                if obj.Value[val] then
                    table.insert(selectedNames, tostring(val))
                end
            end
            hasValue = #selectedNames > 0
            selectedText = hasValue and table.concat(selectedNames, ", ") or "None"
        else
            hasValue = (obj.Value ~= "" and obj.Value ~= nil)
            selectedText = tostring(hasValue and obj.Value or "None")
        end
        valTxt.Text = selectedText
        valTxt.TextColor3 = hasValue and currentThm.Text or currentThm.SubText
        valTxt.Font = hasValue and Enum.Font.GothamBold or Enum.Font.Gotham
    end

    local dropdownList=make("Frame",{Size=UDim2.new(1,0,0,0),ClipsDescendants=true,BackgroundTransparency=1,LayoutOrder=2,Parent=f})
    make("UIListLayout",{SortOrder=Enum.SortOrder.LayoutOrder,Padding=sz(3),Parent=dropdownList})
    local searchBox=make("TextBox",{
        Size=UDim2.new(1,0,0,s(24)),BackgroundColor3=thm.InputBG,
        PlaceholderText="Search...",PlaceholderColor3=thm.SubText,
        Text="",TextColor3=thm.Text,TextSize=fs(16),Font=Enum.Font.Gotham,LayoutOrder=1,Parent=dropdownList,
    })
    make("UICorner",{CornerRadius=sz(9),Parent=searchBox})
    make("UIStroke",{Color=thm.Border,Thickness=1,Parent=searchBox})
    make("UIPadding",{PaddingLeft=sz(8),Parent=searchBox})
    local optionScroll=make("ScrollingFrame",{
        Size=UDim2.new(1,0,0,s(112)),BackgroundTransparency=1,
        ScrollBarThickness=s(2),ScrollBarImageColor3=thm.Scrollbar,CanvasSize=UDim2.new(0,0,0,0),LayoutOrder=2,Parent=dropdownList,
    })
    local olay=make("UIListLayout",{SortOrder=Enum.SortOrder.LayoutOrder,Padding=sz(2),Parent=optionScroll})
    olay.Changed:Connect(function() optionScroll.CanvasSize=UDim2.new(0,0,0,olay.AbsoluteContentSize.Y+s(4)) end)
    local optionButtons={}

    local function populateOptions(vals)
        for _,val in ipairs(vals) do
            local optBtn=make("TextButton",{Size=UDim2.new(1,0,0,s(30)),BackgroundColor3=thm.InputBG,BackgroundTransparency=1,Text="",Parent=optionScroll})
            make("UICorner",{CornerRadius=sz(9),Parent=optBtn})
            local optLbl=make("TextLabel",{
                Size=UDim2.new(1,-s(28),1,0),Position=UDim2.new(0,s(8),0,0),
                BackgroundTransparency=1,Text=tostring(val),TextColor3=thm.SubText,TextSize=fs(16),
                Font=Enum.Font.Gotham,TextXAlignment=Enum.TextXAlignment.Left,Parent=optBtn,
            })
            local optCheck=make("ImageLabel",{Size=ss(12,12),AnchorPoint=Vector2.new(1,0.5),Position=UDim2.new(1,-s(8),0.5,0),BackgroundTransparency=1,Visible=false,Parent=optBtn})
            applyIcon(optCheck,"solar/check-linear",thm.Accent)
            
            local function updateSelectState()
                local isSel=obj.Multi and (not not obj.Value[val]) or (obj.Value==val)
                local currentThm = Aurora.Theme or Aurora.Themes.Dark
                optCheck.Visible=isSel
                optCheck.ImageColor3 = currentThm.Accent
                optLbl.TextColor3=isSel and currentThm.Accent or currentThm.SubText
                optLbl.Font=isSel and Enum.Font.GothamBold or Enum.Font.Gotham
                tw(optBtn, {
                    BackgroundColor3 = isSel and currentThm.Accent or currentThm.InputBG,
                    BackgroundTransparency = isSel and 0.82 or 1
                }, 0.12)
            end
            
            optBtn.MouseEnter:Connect(function()
                local isSel=obj.Multi and (not not obj.Value[val]) or (obj.Value==val)
                local currentThm = Aurora.Theme or Aurora.Themes.Dark
                if not isSel then
                    tw(optBtn,{BackgroundColor3=currentThm.ElementHover,BackgroundTransparency=0.55},0.1)
                    tw(optLbl,{TextColor3=currentThm.Text},0.1)
                else
                    tw(optBtn,{BackgroundTransparency=0.6},0.1)
                end
            end)
            optBtn.MouseLeave:Connect(function()
                local isSel=obj.Multi and (not not obj.Value[val]) or (obj.Value==val)
                local currentThm = Aurora.Theme or Aurora.Themes.Dark
                if not isSel then
                    tw(optBtn,{BackgroundTransparency=1},0.1)
                    tw(optLbl,{TextColor3=currentThm.SubText},0.1)
                else
                    tw(optBtn,{BackgroundTransparency=0.82},0.1)
                    tw(optLbl,{TextColor3=currentThm.Accent},0.1)
                end
            end)
            optBtn.MouseButton1Click:Connect(function()
                if obj.Multi then
                    obj.Value[val]=not obj.Value[val]; updateSelectState(); updateTxt()
                    if cfg.Callback then pcall(cfg.Callback,obj.Value) end
                else
                    obj.Value=val
                    for _,o in ipairs(optionButtons) do o.update() end
                    updateTxt(); pcall(function() obj.Toggle() end)
                    if cfg.Callback then pcall(cfg.Callback,val) end
                end
                triggerAutosave()
            end)
            table.insert(optionButtons,{btn=optBtn,update=updateSelectState,value=val})
            updateSelectState()
        end
    end

    populateOptions(cfg.Values or {}); updateTxt()
    searchBox:GetPropertyChangedSignal("Text"):Connect(function()
        local filter=searchBox.Text:lower()
        for _,opt in ipairs(optionButtons) do opt.btn.Visible=tostring(opt.value):lower():find(filter)~=nil end
    end)

    local btn=make("TextButton",{Size=UDim2.new(1,0,1,0),BackgroundTransparency=1,Text="",Parent=topF})
    local dropExpanded=false
    local function toggleDropdown()
        dropExpanded=not dropExpanded
        local elemCnt=math.min(6,#optionButtons)
        local targetH=dropExpanded and (s(24)+s(3)+elemCnt*s(32)+s(8)) or 0
        tw(dropdownList,{Size=UDim2.new(1,0,0,targetH)},0.2)
        tw(arr,{Rotation=dropExpanded and 180 or 0},0.2)
    end
    local origToggle = toggleDropdown
    obj.Open = origToggle
    obj.Toggle = function(...)
        if obj.Open then
            return obj.Open(...)
        else
            return origToggle(...)
        end
    end
    btn.MouseButton1Click:Connect(obj.Toggle)
    registerHover(f, btn)

    local themeObj = {
        isCallback = true,
        callback = function()
            if not f or not f.Parent then return end
            pcall(updateTxt)
            for _, o in ipairs(optionButtons) do
                pcall(o.update)
            end
        end
    }
    table.insert(Aurora.ThemeObjs, themeObj)
    f.Destroying:Connect(function()
        for idx, item in ipairs(Aurora.ThemeObjs) do
            if item == themeObj then
                table.remove(Aurora.ThemeObjs, idx)
                break
            end
        end
    end)

    function obj:Refresh(newValues)
        cfg.Values=newValues or{}
        for _,opt in ipairs(optionButtons) do opt.btn:Destroy() end
        table.clear(optionButtons); populateOptions(cfg.Values)
        if obj.Multi then
            local ns={}; for _,v in ipairs(cfg.Values) do ns[v]=true end
            for k in pairs(obj.Value) do if not ns[k] then obj.Value[k]=nil end end
        else
            local found=false
            for _,v in ipairs(cfg.Values) do if v==obj.Value then found=true; break end end
            if not found then obj.Value=cfg.Values[1] or "" end
        end
        updateTxt()
    end

    function obj:SetValue(val)
        if obj.Multi then obj.Value=type(val)=="table" and val or {}
        else obj.Value=val end
        for _,opt in ipairs(optionButtons) do opt.update() end
        updateTxt()
        if cfg.Callback then pcall(cfg.Callback, obj.Value) end
        triggerAutosave()
    end

    function obj:SetValues(newValues)
        self:Refresh(newValues)
    end

    function obj:OnChanged(func)
        table.insert(callbacks, func)
        pcall(func, obj.Value)
        return {
            Disconnect = function()
                local idx = table.find(callbacks, func)
                if idx then table.remove(callbacks, idx) end
            end
        }
    end

    _registerElement(cfg.Title or "Dropdown", f, self._tab, self._subTab)
    addVisibilityAPI(obj, f)
    Aurora.Options[id]=obj
    return obj
end


-- INPUT
function Section:AddInput(id, cfg)
    cfg=cfg or{}
    local callbacks = {}
    local originalCallback = cfg.Callback
    cfg.Callback = function(val)
        if originalCallback then pcall(originalCallback, val) end
        for _, c in ipairs(callbacks) do
            pcall(c, val)
        end
    end
    local thm=Aurora.Theme
    local obj={Type="Input",Value=cfg.Default or "",id=id}
    local f=elemFrame(self.Container)
    addTooltip(f, cfg.Tooltip)
    local topF=make("Frame",{Size=UDim2.new(1,0,0,s(30)),BackgroundTransparency=1,LayoutOrder=1,Parent=f})
    local tx=0
    if cfg.Icon then
        local ico=make("ImageLabel",{Size=ss(16,16),AnchorPoint=Vector2.new(0,0.5),Position=UDim2.new(0,0,0.5,0),BackgroundTransparency=1,Parent=topF})
        applyIcon(ico,cfg.Icon,thm.IconColor); tx=s(22)
    end
    make("TextLabel",{
        Size=UDim2.new(0.45,-tx,1,0),Position=UDim2.new(0,tx,0,0),
        BackgroundTransparency=1,Text=cfg.Title or "Input",TextColor3=thm.Text,
        TextSize=fs(16),Font=Enum.Font.GothamBold,TextXAlignment=Enum.TextXAlignment.Left,Parent=topF,
    })
    local inputValBox=make("TextBox",{
        Size=UDim2.new(0.55,0,0,s(22)),AnchorPoint=Vector2.new(1,0.5),Position=UDim2.new(1,0,0.5,0),
        BackgroundColor3=thm.InputBG,PlaceholderText=cfg.Placeholder or "Type here...",
        PlaceholderColor3=thm.SubText,Text=obj.Value,TextColor3=thm.Text,TextSize=fs(16),
        Font=Enum.Font.Gotham,TextXAlignment=Enum.TextXAlignment.Left,ClearTextOnFocus=false,Parent=topF,
    })
    make("UISizeConstraint",{MaxSize=Vector2.new(s(200),math.huge),Parent=inputValBox})
    make("UICorner",{CornerRadius=sz(10),Parent=inputValBox})
    make("UIStroke",{Color=thm.Border,Thickness=1,Parent=inputValBox})
    make("UIPadding",{PaddingLeft=sz(8),PaddingRight=sz(8),Parent=inputValBox})
    inputValBox.FocusLost:Connect(function() obj.Value=inputValBox.Text; if cfg.Callback then pcall(cfg.Callback,obj.Value) end; triggerAutosave() end)
    function obj:SetValue(v) obj.Value=v; inputValBox.Text=v; if cfg.Callback then pcall(cfg.Callback,v) end; triggerAutosave() end
    registerHover(f, f)

    function obj:OnChanged(func)
        table.insert(callbacks, func)
        pcall(func, obj.Value)
        return {
            Disconnect = function()
                local idx = table.find(callbacks, func)
                if idx then table.remove(callbacks, idx) end
            end
        }
    end

    _registerElement(cfg.Title or "Input", f, self._tab, self._subTab)
    addVisibilityAPI(obj, f)
    Aurora.Options[id]=obj
    return obj
end

-- KEYBIND
function Section:AddKeybind(id, cfg)
    cfg=cfg or{}
    local callbacks = {}
    local originalCallback = cfg.Callback
    cfg.Callback = function(val, state)
        if originalCallback then pcall(originalCallback, val, state) end
        for _, c in ipairs(callbacks) do
            pcall(c, val, state)
        end
    end
    local thm=Aurora.Theme
    local defaultKey=cfg.Default or Enum.KeyCode.None
    local active = false
    local obj={Type="Keybind",Value=defaultKey,id=id}
    obj.IsActive = function() return active end
    local binding=false

    local f=elemFrame(self.Container)
    addTooltip(f, cfg.Tooltip)
    local topF=make("Frame",{Size=UDim2.new(1,0,0,s(30)),BackgroundTransparency=1,LayoutOrder=1,Parent=f})
    local tx=0
    if cfg.Icon then
        local ico=make("ImageLabel",{Size=ss(16,16),AnchorPoint=Vector2.new(0,0.5),Position=UDim2.new(0,0.5,0.5,0),BackgroundTransparency=1,Parent=topF})
        applyIcon(ico,cfg.Icon,thm.IconColor); tx=s(22)
    end
    make("TextLabel",{
        Size=UDim2.new(0.6,-tx,1,0),Position=UDim2.new(0,tx,0,0),
        BackgroundTransparency=1,Text=cfg.Title or "Keybind",TextColor3=thm.Text,
        TextSize=fs(16),Font=Enum.Font.GothamBold,TextXAlignment=Enum.TextXAlignment.Left,Parent=topF,
    })
    local kbBtn=make("TextButton",{
        Size=ss(65,20),AnchorPoint=Vector2.new(1,0.5),Position=UDim2.new(1,0,0.5,0),
        BackgroundColor3=thm.InputBG,
        Text=defaultKey==Enum.KeyCode.None and "None" or defaultKey.Name,
        TextColor3=thm.SubText,TextSize=fs(16),Font=Enum.Font.GothamBold,ZIndex=10,Parent=topF,
    })
    make("UICorner",{CornerRadius=sz(8),Parent=kbBtn})
    local kbStroke=make("UIStroke",{Color=thm.Border,Thickness=1,Parent=kbBtn})

    local mobileBtn, mobileStroke, mobileLbl, mobileDot = _createMobileKeybind(cfg.Title or "Keybind", function()
        active = not active
        updateVisualState()
        if Aurora.RefreshKeybindList then task.defer(Aurora.RefreshKeybindList) end
        if cfg.Callback then pcall(cfg.Callback, obj.Value, active) end
    end)

    local function updateVisualState()
        if binding then return end
        local currentThm = Aurora.Theme or Aurora.Themes.Dark
        local activeColor = Color3.fromRGB(38, 195, 95)
        local activeBG    = Color3.fromRGB(15, 60, 30)
        if active then
            tw(kbBtn, { BackgroundColor3 = activeBG, TextColor3 = activeColor }, 0.12)
            tw(kbStroke, { Color = activeColor }, 0.12)
            if mobileBtn then
                tw(mobileBtn, { BackgroundColor3 = activeBG }, 0.12)
                tw(mobileStroke, { Color = activeColor }, 0.12)
                mobileLbl.TextColor3 = activeColor
                if mobileDot then
                    tw(mobileDot, { BackgroundColor3 = activeColor }, 0.12)
                end
            end
        else
            tw(kbBtn, { BackgroundColor3 = currentThm.InputBG, TextColor3 = currentThm.SubText }, 0.12)
            tw(kbStroke, { Color = currentThm.Border }, 0.12)
            if mobileBtn then
                tw(mobileBtn, { BackgroundColor3 = Color3.fromRGB(18, 18, 24) }, 0.12)
                tw(mobileStroke, { Color = currentThm.Border }, 0.12)
                mobileLbl.TextColor3 = currentThm.SubText
                if mobileDot then
                    tw(mobileDot, { BackgroundColor3 = currentThm.Border }, 0.12)
                end
            end
        end
    end

    local function updateKey(key)
        obj.Value=key
        if typeof(key) == "EnumItem" then
            if key.EnumType == Enum.KeyCode then
                kbBtn.Text = key == Enum.KeyCode.None and "None" or key.Name
            elseif key.EnumType == Enum.UserInputType then
                kbBtn.Text = key.Name:gsub("MouseButton", "MB")
            else
                kbBtn.Text = "None"
            end
        else
            kbBtn.Text = "None"
        end
        triggerAutosave()
        if Aurora.RefreshKeybindList then task.defer(Aurora.RefreshKeybindList) end
    end

    kbBtn.MouseButton1Click:Connect(function()
        if binding then return end
        binding=true; kbBtn.Text="..."; kbBtn.TextColor3=thm.Accent
        task.spawn(function()
            task.wait()
            local conn
            conn=UserInputService.InputBegan:Connect(function(input)
                if input.UserInputType==Enum.UserInputType.Keyboard then
                    conn:Disconnect(); binding=false
                    local k=input.KeyCode
                    updateKey(k==Enum.KeyCode.Escape and Enum.KeyCode.None or k)
                    kbBtn.TextColor3=thm.SubText
                    if cfg.Callback then pcall(cfg.Callback,obj.Value) end
                elseif input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.MouseButton2 or input.UserInputType == Enum.UserInputType.MouseButton3 then
                    conn:Disconnect(); binding=false
                    updateKey(input.UserInputType)
                    kbBtn.TextColor3=thm.SubText
                    if cfg.Callback then pcall(cfg.Callback,obj.Value) end
                end
            end)
        end)
    end)

    local keybindBegan = UserInputService.InputBegan:Connect(function(input,processed)
        if not processed and not binding then
            local isMatch = false
            if typeof(obj.Value) == "EnumItem" then
                if obj.Value.EnumType == Enum.KeyCode and obj.Value ~= Enum.KeyCode.None and input.KeyCode == obj.Value then
                    isMatch = true
                elseif obj.Value.EnumType == Enum.UserInputType and obj.Value ~= Enum.UserInputType.None and input.UserInputType == obj.Value then
                    isMatch = true
                end
            end
            if isMatch then
                active = true
                updateVisualState()
                if Aurora.RefreshKeybindList then task.defer(Aurora.RefreshKeybindList) end
                if cfg.Callback then pcall(cfg.Callback,obj.Value) end
            end
        end
    end)

    local keybindEnded = UserInputService.InputEnded:Connect(function(input,processed)
        if not binding then
            local isMatch = false
            if typeof(obj.Value) == "EnumItem" then
                if obj.Value.EnumType == Enum.KeyCode and obj.Value ~= Enum.KeyCode.None and input.KeyCode == obj.Value then
                    isMatch = true
                elseif obj.Value.EnumType == Enum.UserInputType and obj.Value ~= Enum.UserInputType.None and input.UserInputType == obj.Value then
                    isMatch = true
                end
            end
            if isMatch then
                active = false
                updateVisualState()
                if Aurora.RefreshKeybindList then task.defer(Aurora.RefreshKeybindList) end
            end
        end
    end)
    if self._tab and self._tab._window and self._tab._window._connections then
        table.insert(self._tab._window._connections, keybindBegan)
        table.insert(self._tab._window._connections, keybindEnded)
    end
    f.Destroying:Connect(function()
        pcall(function() keybindBegan:Disconnect() end)
        pcall(function() keybindEnded:Disconnect() end)
    end)

    local themeObj = {
        isCallback = true,
        callback = function()
            if not kbBtn or not kbBtn.Parent then return end
            pcall(updateVisualState)
        end
    }
    table.insert(Aurora.ThemeObjs, themeObj)
    
    f.Destroying:Connect(function()
        if mobileBtn then pcall(function() mobileBtn:Destroy() end) end
        for idx, item in ipairs(Aurora.ThemeObjs) do
            if item == themeObj then
                table.remove(Aurora.ThemeObjs, idx)
                break
            end
        end
    end)

    function obj:SetValue(key) updateKey(key) end
    registerHover(f, f)

    function obj:OnChanged(func)
        table.insert(callbacks, func)
        pcall(func, obj.Value)
        return {
            Disconnect = function()
                local idx = table.find(callbacks, func)
                if idx then table.remove(callbacks, idx) end
            end
        }
    end

    _registerElement(cfg.Title or "Keybind", f, self._tab, self._subTab)
    addVisibilityAPI(obj, f)
    Aurora.Options[id]=obj
    return obj
end

-- ================================================================================
--  COLUMN & TAB SYSTEM
-- ================================================================================
local Column={}
Column.__index=Column

function Column:AddSection(title, cfg)
    cfg = cfg or {}
    if Aurora.LazyLoad then
        task.wait(Aurora.DelayPerSection or 0.02)
    end
    local f=make("Frame",{Size=UDim2.new(1,0,0,0),AutomaticSize=Enum.AutomaticSize.Y,BackgroundTransparency=1,Parent=self.Frame})
    make("UIListLayout",{SortOrder=Enum.SortOrder.LayoutOrder,Padding=sz(7),Parent=f})

    local headerFrame=make(Aurora.FadeIn and "CanvasGroup" or "Frame",{Size=UDim2.new(1,0,0,s(22)),BackgroundTransparency=1,Parent=f})
    -- Accent dot
    local accentDot = make("Frame",{
        Size=UDim2.fromOffset(s(3),s(3)),
        AnchorPoint=Vector2.new(0,0.5), Position=UDim2.new(0,0,0.5,-s(3)),
        BackgroundColor3=Aurora.Theme.Accent,
        BorderSizePixel=0, Parent=headerFrame,
    })
    make("UICorner",{CornerRadius=UDim.new(1,0),Parent=accentDot})
    reg(accentDot,"BackgroundColor3","Accent")

    local titleLbl = make("TextLabel",{
        Size=UDim2.new(1,-s(8),1,-s(4)),
        Position=UDim2.new(0,s(8),0,0),
        BackgroundTransparency=1,
        Text=title,
        TextColor3=Aurora.Theme.Accent,
        TextSize=fs(10),Font=Enum.Font.GothamBold,
        TextXAlignment=Enum.TextXAlignment.Left,
        TextTransparency=0.05,
        Parent=headerFrame,
    })
    reg(titleLbl, "TextColor3", "Accent")

    local line=make("Frame",{
        Size=UDim2.new(1,0,0,s(1)),
        Position=UDim2.new(0,0,1,-s(1)),
        BackgroundColor3=Aurora.Theme.Accent,
        BorderSizePixel=0,
        Parent=headerFrame,
    })
    -- Gradient fade on the underline
    make("UIGradient",{
        Color=ColorSequence.new({
            ColorSequenceKeypoint.new(0, Color3.fromRGB(255,255,255)),
            ColorSequenceKeypoint.new(1, Color3.fromRGB(255,255,255)),
        }),
        Transparency=NumberSequence.new({
            NumberSequenceKeypoint.new(0, 0),
            NumberSequenceKeypoint.new(0.45, 0.1),
            NumberSequenceKeypoint.new(1, 1),
        }),
        Rotation=0, Parent=line,
    })
    reg(line, "BackgroundColor3", "Accent")

    local cont=make("Frame",{Size=UDim2.new(1,0,0,0),AutomaticSize=Enum.AutomaticSize.Y,BackgroundTransparency=1,Parent=f})
    make("UIListLayout",{SortOrder=Enum.SortOrder.LayoutOrder,Padding=sz(6),Parent=cont})
    
    local sectionObj = setmetatable({Container=cont, Frame=f, _tab = self._tab, _subTab = self._subTab}, Section)
    
    if cfg.Collapsible then
        local chevron = make("ImageLabel", {
            Size = ss(12, 12),
            AnchorPoint = Vector2.new(1, 0.5),
            Position = UDim2.new(1, -s(4), 0.5, 0),
            BackgroundTransparency = 1,
            Parent = headerFrame
        })
        applyIcon(chevron, "solar/alt-arrow-down-linear", Aurora.Theme.SubText)
        
        local btn = make("TextButton", {
            Size = UDim2.fromScale(1, 1),
            BackgroundTransparency = 1,
            Text = "",
            Parent = headerFrame
        })
        
        local expanded = cfg.DefaultExpanded ~= false
        cont.Visible = expanded
        chevron.Rotation = expanded and 0 or -90
        
        btn.MouseButton1Click:Connect(function()
            expanded = not expanded
            cont.Visible = expanded
            tw(chevron, { Rotation = expanded and 0 or -90 }, 0.18)
        end)
        
        function sectionObj:SetCollapsed(collapsed)
            expanded = not collapsed
            cont.Visible = expanded
            tw(chevron, { Rotation = expanded and 0 or -90 }, 0.18)
        end
    end

    if Aurora.FadeIn then
        headerFrame.GroupTransparency = 1
        task.defer(function()
            tw(headerFrame, { GroupTransparency = 0 }, 0.3, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
        end)
    end

    return sectionObj
end

local SubTab={}
SubTab.__index=SubTab
function SubTab:AddSection(title, cfg)
    local sec = Column.AddSection({Frame=self.ScrollContent, _tab=self._parentTab, _subTab=self}, title, cfg)
    return sec
end
function SubTab:AddColumns()
    local c=make("Frame",{Size=UDim2.new(1,0,0,0),AutomaticSize=Enum.AutomaticSize.Y,BackgroundTransparency=1,Parent=self.ScrollContent})
    local l=make("Frame",{Size=UDim2.new(0.5,-s(4),0,0),AutomaticSize=Enum.AutomaticSize.Y,BackgroundTransparency=1,Parent=c})
    make("UIListLayout",{SortOrder=Enum.SortOrder.LayoutOrder,Padding=sz(7),Parent=l})
    local r=make("Frame",{Size=UDim2.new(0.5,-s(4),0,0),Position=UDim2.new(0.5,s(4),0,0),AutomaticSize=Enum.AutomaticSize.Y,BackgroundTransparency=1,Parent=c})
    make("UIListLayout",{SortOrder=Enum.SortOrder.LayoutOrder,Padding=sz(7),Parent=r})
    return setmetatable({Frame=l, _tab=self._parentTab, _subTab=self},Column), setmetatable({Frame=r, _tab=self._parentTab, _subTab=self},Column)
end

local Tab={}
Tab.__index=Tab
function Tab:AddSection(title, cfg)
    local sec = Column.AddSection({Frame=self.ScrollContent, _tab=self}, title, cfg)
    return sec
end
function Tab:AddColumns()
    local c=make("Frame",{Size=UDim2.new(1,0,0,0),AutomaticSize=Enum.AutomaticSize.Y,BackgroundTransparency=1,Parent=self.ScrollContent})
    local l=make("Frame",{Size=UDim2.new(0.5,-s(4),0,0),AutomaticSize=Enum.AutomaticSize.Y,BackgroundTransparency=1,Parent=c})
    make("UIListLayout",{SortOrder=Enum.SortOrder.LayoutOrder,Padding=sz(7),Parent=l})
    local r=make("Frame",{Size=UDim2.new(0.5,-s(4),0,0),Position=UDim2.new(0.5,s(4),0,0),AutomaticSize=Enum.AutomaticSize.Y,BackgroundTransparency=1,Parent=c})
    make("UIListLayout",{SortOrder=Enum.SortOrder.LayoutOrder,Padding=sz(7),Parent=r})
    return setmetatable({Frame=l, _tab=self},Column), setmetatable({Frame=r, _tab=self},Column)
end

function Tab:AddSubTab(title)
    self.SubTabs=self.SubTabs or {}
    if not self.SubTabBar then
        self.DefaultScroll.Visible=false
        -- Apple-style pill bar background strip
        local bgBar = make("Frame",{
            Size=UDim2.new(1,0,0,s(44)),BackgroundColor3=Aurora.Theme.TopBar,BorderSizePixel=0,ZIndex=0,Parent=self.Page
        })
        make("UIGradient",{
            Color=ColorSequence.new({ColorSequenceKeypoint.new(0,Color3.fromRGB(18,18,24)),ColorSequenceKeypoint.new(1,Color3.fromRGB(12,12,16))}),
            Rotation=90, Parent=bgBar,
        })
        make("Frame",{Size=UDim2.new(1,0,0,1),Position=UDim2.new(0,0,1,-1),BackgroundColor3=Aurora.Theme.Border,BackgroundTransparency=0.5,BorderSizePixel=0,Parent=bgBar})
        -- Segmented pill track
        self.SubTabBar=make("ScrollingFrame",{
            Size=UDim2.new(1,-s(20),0,s(28)),Position=UDim2.new(0,s(10),0,s(8)),
            BackgroundColor3=Aurora.Theme.Element,BackgroundTransparency=0.5,BorderSizePixel=0,
            ScrollBarThickness=0,CanvasSize=UDim2.new(0,0,0,0),ScrollingDirection=Enum.ScrollingDirection.X,
            ZIndex=1,Parent=self.Page,
        })
        make("UICorner",{CornerRadius=sz(8),Parent=self.SubTabBar})
        make("UIStroke",{Color=Aurora.Theme.Border,Thickness=1,Transparency=0.45,Parent=self.SubTabBar})
        local slay=make("UIListLayout",{FillDirection=Enum.FillDirection.Horizontal,SortOrder=Enum.SortOrder.LayoutOrder,Padding=sz(2),Parent=self.SubTabBar})
        make("UIPadding",{PaddingLeft=sz(3),PaddingRight=sz(3),PaddingTop=sz(3),PaddingBottom=sz(3),Parent=self.SubTabBar})
        slay.Changed:Connect(function()
            self.SubTabBar.CanvasSize = UDim2.new(0, slay.AbsoluteContentSize.X + s(10), 0, 0)
        end)
        self.SubPageContainer=make("Frame",{Size=UDim2.new(1,0,1,-s(44)),Position=UDim2.new(0,0,0,s(44)),BackgroundTransparency=1,Parent=self.Page})
    end

    local subPage=make("ScrollingFrame",{
        Size=UDim2.fromScale(1,1),BackgroundTransparency=1,ScrollBarThickness=s(2),
        ScrollBarImageColor3=Aurora.Theme.Scrollbar,Visible=false,Parent=self.SubPageContainer,
    })
    local subContent=make("Frame",{Size=UDim2.new(1,0,0,0),AutomaticSize=Enum.AutomaticSize.Y,BackgroundTransparency=1,Parent=subPage})
    local subLay=make("UIListLayout",{SortOrder=Enum.SortOrder.LayoutOrder,Padding=sz(10),Parent=subContent})
    make("UIPadding",{PaddingTop=sz(14),PaddingBottom=sz(20),PaddingLeft=sz(14),PaddingRight=sz(14),Parent=subContent})
    subLay.Changed:Connect(function() subPage.CanvasSize=UDim2.new(0,0,0,subLay.AbsoluteContentSize.Y+s(30)) end)

    -- Apple pill button
    local subBtn=make("TextButton",{
        Size=UDim2.new(0,0,1,0),AutomaticSize=Enum.AutomaticSize.X,
        BackgroundColor3=Aurora.Theme.Accent,BackgroundTransparency=1,
        Text=title,TextColor3=Aurora.Theme.TabInactive,TextSize=fs(16),Font=Enum.Font.GothamBold,
        ZIndex=2,Parent=self.SubTabBar,
    })
    make("UICorner",{CornerRadius=sz(6),Parent=subBtn})
    make("UIPadding",{PaddingLeft=sz(10),PaddingRight=sz(10),Parent=subBtn})
    -- Dummy underline for API compatibility
    local underline=make("Frame",{Size=UDim2.new(0,0,0,0),BackgroundTransparency=1,Visible=false,Parent=subBtn})

    local function setActive(isActive)
        local currentThm = Aurora.Theme or Aurora.Themes.Dark
        if isActive then
            tw(subBtn, { BackgroundColor3 = currentThm.Accent, BackgroundTransparency = 0.82, TextColor3 = currentThm.Accent }, 0.18)
        else
            tw(subBtn, { BackgroundTransparency = 1, TextColor3 = currentThm.TabInactive }, 0.18)
        end
    end

    subBtn.MouseEnter:Connect(function()
        if not subPage.Visible then
            local currentThm = Aurora.Theme or Aurora.Themes.Dark
            tw(subBtn, { BackgroundColor3 = currentThm.ElementHover, BackgroundTransparency = 0.55, TextColor3 = currentThm.Text }, 0.12)
        end
    end)
    subBtn.MouseLeave:Connect(function()
        if not subPage.Visible then setActive(false) end
    end)

    local subTabObj=setmetatable({Button=subBtn,Page=subPage,ScrollContent=subContent,Underline=underline,_parentTab=self},SubTab)
    function subTabObj:Select()
        local currentThm = Aurora.Theme or Aurora.Themes.Dark
        for _,other in ipairs(self._parentTab.SubTabs) do
            other.Page.Visible=false
            tw(other.Button, { BackgroundTransparency = 1, TextColor3 = currentThm.TabInactive }, 0.18)
        end
        subPage.Visible=true
        setActive(true)
    end
    subBtn.MouseButton1Click:Connect(function() subTabObj:Select() end)
    if #self.SubTabs==0 then
        subPage.Visible=true
        setActive(true)
    end
    table.insert(self.SubTabs,subTabObj)
    return subTabObj
end

-- ================================================================================
--  WINDOW CREATION
-- ================================================================================
function Aurora:CreateWindow(cfg)
    cfg=cfg or{}
    SC=math.clamp(cfg.Scale or 1.0, 0.7, 2.0); self.Scale=SC
    self.Theme=self.Themes[cfg.Theme] or self.Themes.Dark
    self.Acrylic = cfg.Acrylic == true
    Aurora.MobileButtonOverride = (cfg.MobileButton == true)
    
    Aurora.LazyLoad = cfg.LazyLoad ~= false
    Aurora.FadeIn = cfg.FadeIn ~= false
    Aurora.DelayPerTab = cfg.DelayPerTab or 0.25
    Aurora.DelayPerSection = cfg.DelayPerSection or 0.15
    Aurora.DelayPerElement = cfg.DelayPerElement or 0.05
    local thm=self.Theme
    local winConnections = {}


    local gui=make("ScreenGui",{Name="AuroraLib",ResetOnSpawn=false,DisplayOrder=9998,ZIndexBehavior=Enum.ZIndexBehavior.Sibling})
    safeParent(gui)

    local main=make("Frame",{
        Size=cfg.Size or ss(720,530),
        AnchorPoint=Vector2.new(0.5,0.5), Position=UDim2.new(0.5,0,0.5,0),
        BackgroundColor3=thm.Background,
        BackgroundTransparency=self.Acrylic and 0.45 or 0,
        ClipsDescendants=true, Parent=gui,
    })
    local bgImg=make("ImageLabel",{
        Name="WindowBackground",
        Size=UDim2.fromScale(1,1),
        BackgroundTransparency=1,
        ScaleType=Enum.ScaleType.Crop,
        ZIndex=0,
        Parent=main,
    })
    make("UICorner",{CornerRadius=sz(20),Parent=bgImg})
    reg(bgImg, "Image", "BackgroundImage")
    reg(bgImg, "ImageTransparency", "BackgroundImageTransparency")
    if self.Acrylic then
        createAcrylic(main)
    end
    make("UICorner",{CornerRadius=sz(20),Parent=main})
    make("UIGradient",{
        Color=ColorSequence.new({
            ColorSequenceKeypoint.new(0.00,Color3.fromRGB(22,22,28)),
            ColorSequenceKeypoint.new(0.40,Color3.fromRGB(14,14,18)),
            ColorSequenceKeypoint.new(1.00,Color3.fromRGB(8,8,10)),
        }),
        Rotation=90, Parent=main,
    })
    local mainStroke=make("UIStroke",{Color=Color3.fromRGB(255,255,255),Thickness=1,Parent=main})
    make("UIGradient",{
        Color=ColorSequence.new({
            ColorSequenceKeypoint.new(0.00,Color3.fromRGB(100,100,120)),
            ColorSequenceKeypoint.new(0.35,Color3.fromRGB(55,55,70)),
            ColorSequenceKeypoint.new(0.70,Color3.fromRGB(28,28,36)),
            ColorSequenceKeypoint.new(1.00,Color3.fromRGB(12,12,16)),
        }),
        Rotation=135, Parent=mainStroke,
    })
    make("Frame",{
        Size=UDim2.new(1,0,0,s(1)),BackgroundColor3=Color3.fromRGB(255,255,255),
        BackgroundTransparency=0.72,BorderSizePixel=0,ZIndex=2,Parent=main,
    })

    -- Sidebar (Apple-style: cleaner, more rounded inner elements)
    local sidebarTrans = self.Acrylic and 0.6 or 0.08
    local sidebar=make("Frame",{Size=UDim2.new(0,s(192),1,0),BackgroundColor3=thm.Sidebar,BackgroundTransparency=sidebarTrans,Parent=main})
    make("UICorner",{CornerRadius=sz(20),Parent=sidebar})
    local sbPatch=make("Frame",{Name="CornerPatch",Size=UDim2.new(0,s(20),1,0),Position=UDim2.new(1,-s(20),0,0),BackgroundColor3=thm.Sidebar,BackgroundTransparency=sidebarTrans,BorderSizePixel=0,Parent=sidebar})
    make("Frame",{Size=UDim2.new(0,1,1,0),Position=UDim2.new(1,0,0,0),BackgroundColor3=Color3.fromRGB(255,255,255),BackgroundTransparency=0.88,BorderSizePixel=0,Parent=sidebar})
    local sbGrad=ColorSequence.new({ColorSequenceKeypoint.new(0,Color3.fromRGB(24,24,30)),ColorSequenceKeypoint.new(1,Color3.fromRGB(12,12,16))})
    make("UIGradient",{Color=sbGrad, Rotation=90, Parent=sidebar})
    make("UIGradient",{Color=sbGrad, Rotation=90, Parent=sbPatch})

    -- Logo / header area
    local logoFrame=make("Frame",{Size=UDim2.new(1,0,0,s(56)),BackgroundTransparency=1,Parent=sidebar})
    make("UIPadding",{PaddingLeft=sz(14),PaddingTop=sz(14),Parent=logoFrame})
    local logoIco=make("ImageLabel",{Size=ss(20,20),AnchorPoint=Vector2.new(0,0.5),Position=UDim2.new(0,0,0.5,-s(3)),BackgroundTransparency=1,Parent=logoFrame})
    applyIcon(logoIco,"solar/star-bold",thm.Accent)
    make("TextLabel",{
        Size=UDim2.new(1,-s(30),0,s(16)),Position=UDim2.new(0,s(26),0,s(10)),
        BackgroundTransparency=1,Text=cfg.Title or "Aurora",TextColor3=thm.Text,
        TextSize=fs(16),Font=Enum.Font.GothamBlack,TextXAlignment=Enum.TextXAlignment.Left,Parent=logoFrame,
    })
    if cfg.SubTitle then
        make("TextLabel",{
            Size=UDim2.new(1,-s(30),0,s(11)),Position=UDim2.new(0,s(26),0,s(28)),
            BackgroundTransparency=1,Text=cfg.SubTitle,TextColor3=thm.SubText,
            TextSize=fs(10),Font=Enum.Font.Gotham,TextXAlignment=Enum.TextXAlignment.Left,Parent=logoFrame,
        })
    end
    -- Separator line under logo
    make("Frame",{Size=UDim2.new(1,-s(24),0,s(1)),Position=UDim2.new(0,s(12),1,-1),BackgroundColor3=thm.Border,BackgroundTransparency=0.3,BorderSizePixel=0,Parent=logoFrame})

    -- User panel (rounded card, Apple-style)
    local userPanel=make("Frame",{Size=UDim2.new(1,-s(20),0,s(48)),Position=UDim2.new(0,s(10),0,s(60)),BackgroundColor3=thm.Element,BackgroundTransparency=0.35,Parent=sidebar})
    make("UICorner",{CornerRadius=sz(12),Parent=userPanel})
    make("UIStroke",{Color=thm.Border,Thickness=1,Transparency=0.4,Parent=userPanel})
    local avatarImg=make("ImageLabel",{Size=ss(30,30),Position=UDim2.new(0,s(9),0.5,0),AnchorPoint=Vector2.new(0,0.5),BackgroundColor3=thm.Element,BackgroundTransparency=0.4,Parent=userPanel})
    make("UICorner",{CornerRadius=UDim.new(1,0),Parent=avatarImg})
    make("UIStroke",{Color=thm.Accent,Thickness=1.5,Transparency=0.4,Parent=avatarImg})
    task.spawn(function()
        pcall(function()
            local content,isReady=Players:GetUserThumbnailAsync(LocalPlayer.UserId,Enum.ThumbnailType.HeadShot,Enum.ThumbnailSize.Size48x48)
            if isReady and avatarImg and avatarImg.Parent then avatarImg.Image=content end
        end)
    end)
    make("TextLabel",{Size=UDim2.new(1,-s(50),0,s(13)),Position=UDim2.new(0,s(46),0,s(7)),BackgroundTransparency=1,Text="Welcome back,",TextColor3=thm.SubText,TextSize=fs(10),Font=Enum.Font.Gotham,TextXAlignment=Enum.TextXAlignment.Left,Parent=userPanel})
    make("TextLabel",{Size=UDim2.new(1,-s(50),0,s(15)),Position=UDim2.new(0,s(46),0,s(22)),BackgroundTransparency=1,Text=LocalPlayer.DisplayName or LocalPlayer.Name,TextColor3=thm.Text,TextSize=fs(16),Font=Enum.Font.GothamBold,TextXAlignment=Enum.TextXAlignment.Left,TextTruncate=Enum.TextTruncate.AtEnd,Parent=userPanel})

    -- Search bar (more rounded, Apple-style)
    local searchFrame=make("Frame",{Size=UDim2.new(1,-s(20),0,s(30)),Position=UDim2.new(0,s(10),0,s(114)),BackgroundColor3=thm.InputBG,BackgroundTransparency=0.3,Parent=sidebar})
    make("UICorner",{CornerRadius=sz(10),Parent=searchFrame})
    make("UIStroke",{Color=thm.Border,Thickness=1,Transparency=0.5,Parent=searchFrame})
    local searchIco=make("ImageLabel",{Size=ss(13,13),Position=UDim2.new(0,s(9),0.5,0),AnchorPoint=Vector2.new(0,0.5),BackgroundTransparency=1,Parent=searchFrame})
    applyIcon(searchIco,"solar/magnifer-linear",thm.SubText)
    local searchBox=make("TextBox",{
        Size=UDim2.new(1,-s(30),1,0),Position=UDim2.new(0,s(26),0,0),
        BackgroundTransparency=1,PlaceholderText="Search tabs...",PlaceholderColor3=thm.SubText,
        Text="",TextColor3=thm.Text,TextSize=fs(16),Font=Enum.Font.Gotham,TextXAlignment=Enum.TextXAlignment.Left,ClearTextOnFocus=false,Parent=searchFrame,
    })

    local tabScroll=make("ScrollingFrame",{
        Size=UDim2.new(1,0,1,-s(194)),Position=UDim2.new(0,0,0,s(150)),
        BackgroundTransparency=1,ScrollBarThickness=s(2),ScrollBarImageColor3=thm.Scrollbar,Parent=sidebar,
    })
    local slay=make("UIListLayout",{SortOrder=Enum.SortOrder.LayoutOrder,Padding=sz(2),Parent=tabScroll})
    make("UIPadding",{PaddingTop=sz(6),PaddingBottom=sz(6),PaddingLeft=sz(8),PaddingRight=sz(8),Parent=tabScroll})
    slay.Changed:Connect(function() tabScroll.CanvasSize=UDim2.new(0,0,0,slay.AbsoluteContentSize.Y+s(12)) end)

    local content=make("Frame",{Size=UDim2.new(1,-s(192),1,0),Position=UDim2.new(0,s(192),0,0),BackgroundTransparency=1,Parent=main})
    local topTrans = self.Acrylic and 0.65 or 0.1
    local top=make("Frame",{Size=UDim2.new(1,0,0,s(50)),BackgroundColor3=thm.TopBar,BackgroundTransparency=topTrans,Parent=content})
    make("UICorner",{CornerRadius=sz(20),Parent=top})
    make("Frame",{Name="CornerPatch",Size=UDim2.new(1,0,0,s(20)),Position=UDim2.new(0,0,1,-s(20)),BackgroundColor3=thm.TopBar,BackgroundTransparency=topTrans,BorderSizePixel=0,Parent=top})
    make("Frame",{Name="CornerPatch",Size=UDim2.new(0,s(20),1,0),Position=UDim2.new(0,0,0,0),BackgroundColor3=thm.TopBar,BackgroundTransparency=topTrans,BorderSizePixel=0,Parent=top})
    make("Frame",{Size=UDim2.new(1,0,0,1),Position=UDim2.new(0,0,1,-1),BackgroundColor3=Color3.fromRGB(255,255,255),BackgroundTransparency=0.9,BorderSizePixel=0,Parent=top})
    local tabHold=make("Frame",{Size=UDim2.new(1,-s(12),1,-s(66)),Position=UDim2.new(0,0,0,s(50)),BackgroundTransparency=1,Parent=content})

    -- Window controls
    local function makeCtrlBtn(order, hoverBG)
        local btn=make("TextButton",{Size=ss(20,20),BackgroundTransparency=1,Text="",LayoutOrder=order,ZIndex=10000,Parent=nil})
        make("UICorner",{CornerRadius=sz(8),Parent=btn})
        btn.MouseEnter:Connect(function() tw(btn,{BackgroundColor3=hoverBG,BackgroundTransparency=0.15},0.1) end)
        btn.MouseLeave:Connect(function() tw(btn,{BackgroundTransparency=1},0.1) end)
        return btn
    end
    local controls=make("Frame",{Size=ss(80,20),Position=UDim2.new(1,-s(12),0,s(12)),AnchorPoint=Vector2.new(1,0),BackgroundTransparency=1,ZIndex=9999,Parent=main})
    make("UIListLayout",{FillDirection=Enum.FillDirection.Horizontal,HorizontalAlignment=Enum.HorizontalAlignment.Right,SortOrder=Enum.SortOrder.LayoutOrder,Padding=sz(5),Parent=controls})
    local minBtn=makeCtrlBtn(1,Color3.fromRGB(255,255,255)); minBtn.Parent=controls
    local maxBtn=makeCtrlBtn(2,Color3.fromRGB(255,255,255)); maxBtn.Parent=controls
    local closeBtn=makeCtrlBtn(3,Color3.fromRGB(220,55,55)); closeBtn.Parent=controls

    local minLine=make("Frame",{Size=UDim2.fromOffset(s(8),s(1)),AnchorPoint=Vector2.new(0.5,0.5),Position=UDim2.fromScale(0.5,0.5),BackgroundColor3=thm.SubText,BorderSizePixel=0,Parent=minBtn})
    local maxIco=make("Frame",{Size=UDim2.fromOffset(s(8),s(8)),AnchorPoint=Vector2.new(0.5,0.5),Position=UDim2.fromScale(0.5,0.5),BackgroundTransparency=1,Parent=maxBtn})
    local maxStk=make("UIStroke",{Color=thm.SubText,Thickness=1,Parent=maxIco})
    local clsIco=make("Frame",{Size=UDim2.fromOffset(s(8),s(8)),AnchorPoint=Vector2.new(0.5,0.5),Position=UDim2.fromScale(0.5,0.5),BackgroundTransparency=1,Parent=closeBtn})
    local cl1=make("Frame",{Size=UDim2.new(1,0,0,s(1)),AnchorPoint=Vector2.new(0.5,0.5),Position=UDim2.fromScale(0.5,0.5),BackgroundColor3=thm.SubText,BorderSizePixel=0,Rotation=45,Parent=clsIco})
    local cl2=make("Frame",{Size=UDim2.new(1,0,0,s(1)),AnchorPoint=Vector2.new(0.5,0.5),Position=UDim2.fromScale(0.5,0.5),BackgroundColor3=thm.SubText,BorderSizePixel=0,Rotation=-45,Parent=clsIco})

    -- Drag
    local drag,ds,sp=false,nil,nil
    top.InputBegan:Connect(function(i) if i.UserInputType==Enum.UserInputType.MouseButton1 then drag=true; ds=i.Position; sp=main.Position end end)
    local dragChanged = UserInputService.InputChanged:Connect(function(i)
        if drag and (i.UserInputType==Enum.UserInputType.MouseMovement or i.UserInputType==Enum.UserInputType.Touch) then
            local delta=i.Position-ds
            main.Position=UDim2.new(sp.X.Scale,sp.X.Offset+delta.X,sp.Y.Scale,sp.Y.Offset+delta.Y)
        end
    end)
    local dragEnded = UserInputService.InputEnded:Connect(function(i) if i.UserInputType==Enum.UserInputType.MouseButton1 then drag=false end end)
    table.insert(winConnections, dragChanged)
    table.insert(winConnections, dragEnded)

    -- Resize Overlay Container (prevents clipping of grab zones)
    local resizeOverlay = make("Frame", {
        Name = "ResizeOverlay",
        Size = main.Size,
        Position = main.Position,
        AnchorPoint = main.AnchorPoint,
        BackgroundTransparency = 1,
        ClipsDescendants = false,
        ZIndex = 10000,
        Parent = gui
    })
    main:GetPropertyChangedSignal("Size"):Connect(function()
        resizeOverlay.Size = main.Size
    end)
    main:GetPropertyChangedSignal("Position"):Connect(function()
        resizeOverlay.Position = main.Position
    end)

    -- Corner resize
    local minW,minH=s(400),s(300)
    local resizing=false
    local resizeCorner=make("TextButton",{
        Size=ss(16,16),AnchorPoint=Vector2.new(1,1),Position=UDim2.new(1,0,1,0),
        BackgroundColor3=Color3.fromRGB(255,255,255),BackgroundTransparency=0.9,
        Text="",ZIndex=10001,Parent=resizeOverlay,
    })
    make("UICorner",{CornerRadius=sz(4),Parent=resizeCorner})
    for di=1,3 do
        make("Frame",{
            Size=ss(2,2),AnchorPoint=Vector2.new(1,1),
            Position=UDim2.new(1,-s(2+(di-1)*4),1,-s(2+(di-1)*4)),
            BackgroundColor3=thm.SubText,BackgroundTransparency=0.4,BorderSizePixel=0,Parent=resizeCorner,
        })
    end
    local resizeStartPos,resizeStartSize
    resizeCorner.InputBegan:Connect(function(i)
        if i.UserInputType==Enum.UserInputType.MouseButton1 then
            resizing=true; resizeStartPos=i.Position
            resizeStartSize=Vector2.new(main.AbsoluteSize.X,main.AbsoluteSize.Y)
        end
    end)
    local resChanged = UserInputService.InputChanged:Connect(function(i)
        if resizing and i.UserInputType==Enum.UserInputType.MouseMovement then
            local delta=i.Position-resizeStartPos
            main.Size=UDim2.fromOffset(math.max(minW,resizeStartSize.X+delta.X),math.max(minH,resizeStartSize.Y+delta.Y))
        end
    end)
    local resEnded = UserInputService.InputEnded:Connect(function(i) if i.UserInputType==Enum.UserInputType.MouseButton1 then resizing=false end end)
    table.insert(winConnections, resChanged)
    table.insert(winConnections, resEnded)
    resizeCorner.MouseEnter:Connect(function() tw(resizeCorner,{BackgroundTransparency=0.6},0.1) end)
    resizeCorner.MouseLeave:Connect(function() tw(resizeCorner,{BackgroundTransparency=0.9},0.1) end)

    -- Edge/Corner Resizing
    local function createResizeEdge(name, size, pos, resizeType)
        local edge = make("TextButton", {
            Name = name,
            Size = size,
            Position = pos,
            BackgroundTransparency = 1,
            Text = "",
            ZIndex = 10000,
            Parent = resizeOverlay
        })
        
        -- Subtle highlight overlay
        local hl = make("Frame", {
            Size = UDim2.fromScale(1, 1),
            BackgroundColor3 = thm.Accent,
            BackgroundTransparency = 1,
            BorderSizePixel = 0,
            Parent = edge
        })
        
        edge.MouseEnter:Connect(function()
            tw(hl, { BackgroundTransparency = 0.65 }, 0.1)
        end)
        edge.MouseLeave:Connect(function()
            tw(hl, { BackgroundTransparency = 1 }, 0.1)
        end)
        
        local dragStartPos, dragStartSize, dragStartWindowPos
        local dragging = false
        
        edge.InputBegan:Connect(function(input)
            if input.UserInputType == Enum.UserInputType.MouseButton1 then
                dragging = true
                dragStartPos = input.Position
                dragStartSize = Vector2.new(main.AbsoluteSize.X, main.AbsoluteSize.Y)
                dragStartWindowPos = Vector2.new(main.Position.X.Offset, main.Position.Y.Offset)
            end
        end)
        
        local edgeDrag = UserInputService.InputChanged:Connect(function(input)
            if dragging and input.UserInputType == Enum.UserInputType.MouseMovement then
                local delta = input.Position - dragStartPos
                local newWidth = dragStartSize.X
                local newHeight = dragStartSize.Y
                
                if resizeType:find("Left") then
                    newWidth = math.max(minW, dragStartSize.X - delta.X)
                elseif resizeType:find("Right") then
                    newWidth = math.max(minW, dragStartSize.X + delta.X)
                end
                
                if resizeType:find("Top") then
                    newHeight = math.max(minH, dragStartSize.Y - delta.Y)
                elseif resizeType:find("Bottom") then
                    newHeight = math.max(minH, dragStartSize.Y + delta.Y)
                end
                
                local dW = newWidth - dragStartSize.X
                local dH = newHeight - dragStartSize.Y
                
                local newX = dragStartWindowPos.X
                local newY = dragStartWindowPos.Y
                
                if resizeType:find("Left") then
                    newX = dragStartWindowPos.X - dW / 2
                elseif resizeType:find("Right") then
                    newX = dragStartWindowPos.X + dW / 2
                end
                
                if resizeType:find("Top") then
                    newY = dragStartWindowPos.Y - dH / 2
                elseif resizeType:find("Bottom") then
                    newY = dragStartWindowPos.Y + dH / 2
                end
                
                main.Size = UDim2.fromOffset(newWidth, newHeight)
                main.Position = UDim2.new(main.Position.X.Scale, newX, main.Position.Y.Scale, newY)
            end
        end)
        
        local edgeEnd = UserInputService.InputEnded:Connect(function(input)
            if input.UserInputType == Enum.UserInputType.MouseButton1 then
                dragging = false
            end
        end)
        table.insert(winConnections, edgeDrag)
        table.insert(winConnections, edgeEnd)
    end

    -- Create 4 edges (6px thick overlaying the window boundaries)
    createResizeEdge("ResizeTop",    UDim2.new(1, -s(16), 0, s(6)),  UDim2.new(0, s(8), 0, -s(3)),  "Top")
    createResizeEdge("ResizeBottom", UDim2.new(1, -s(16), 0, s(6)),  UDim2.new(0, s(8), 1, -s(3)),  "Bottom")
    createResizeEdge("ResizeLeft",   UDim2.new(0, s(6), 1, -s(16)),  UDim2.new(0, -s(3), 0, s(8)),  "Left")
    createResizeEdge("ResizeRight",  UDim2.new(0, s(6), 1, -s(16)),  UDim2.new(1, -s(3), 0, s(8)),  "Right")

    -- Create 4 corners (12px by 12px grab zones)
    createResizeEdge("ResizeTopLeft",     ss(12, 12), UDim2.new(0, -s(6), 0, -s(6)), "TopLeft")
    createResizeEdge("ResizeTopRight",    ss(12, 12), UDim2.new(1, -s(6), 0, -s(6)), "TopRight")
    createResizeEdge("ResizeBottomLeft",  ss(12, 12), UDim2.new(0, -s(6), 1, -s(6)), "BottomLeft")
    createResizeEdge("ResizeBottomRight", ss(12, 12), UDim2.new(1, -s(6), 1, -s(6)), "BottomRight")

    -- Window control logic
    local minimized=false; local maximized=false
    local originalSize=main.Size
    local largeSize=UDim2.fromOffset(math.floor(originalSize.X.Offset*1.28),math.floor(originalSize.Y.Offset*1.22))

    local function toggleMinimize()
        minimized=not minimized
        if minimized then
            sidebar.Visible=false; content.Visible=false; originalSize=main.Size
            tw(main,{Size=UDim2.new(0,main.AbsoluteSize.X,0,s(50))},0.2)
            resizeOverlay.Visible = false
        else
            tw(main,{Size=originalSize},0.22)
            task.delay(0.22,function() if not minimized then sidebar.Visible=true; content.Visible=true end end)
            resizeOverlay.Visible = true
        end
    end

    local function toggleMaximize()
        if minimized then return end
        maximized=not maximized
        tw(main,{Size=maximized and largeSize or originalSize},0.2)
    end

    local function showClosePrompt()
        if main:FindFirstChild("CloseOverlay") then return end
        local overlay=make("TextButton",{Name="CloseOverlay",Size=UDim2.fromScale(1,1),BackgroundColor3=Color3.fromRGB(0,0,0),BackgroundTransparency=1,Text="",AutoButtonColor=false,ZIndex=9999,Parent=main})
        make("UICorner",{CornerRadius=sz(16),Parent=overlay})
        local prompt=make("Frame",{Size=ss(290,152),AnchorPoint=Vector2.new(0.5,0.5),Position=UDim2.fromScale(0.5,0.5),BackgroundColor3=thm.NotifBG,BackgroundTransparency=0.04,ZIndex=10000,Parent=overlay})
        make("UICorner",{CornerRadius=sz(16),Parent=prompt})
        local pStroke=make("UIStroke",{Thickness=1,Transparency=0.3,Parent=prompt})
        make("UIGradient",{Color=ColorSequence.new({ColorSequenceKeypoint.new(0,Color3.fromRGB(70,70,88)),ColorSequenceKeypoint.new(1,Color3.fromRGB(20,20,26))}),Rotation=45,Parent=pStroke})
        make("UIPadding",{PaddingTop=sz(16),PaddingBottom=sz(14),PaddingLeft=sz(18),PaddingRight=sz(18),Parent=prompt})
        make("UIListLayout",{SortOrder=Enum.SortOrder.LayoutOrder,Padding=sz(8),HorizontalAlignment=Enum.HorizontalAlignment.Center,Parent=prompt})
        local warnIco=make("ImageLabel",{Size=ss(26,26),BackgroundTransparency=1,LayoutOrder=0,Parent=prompt})
        applyIcon(warnIco,"solar/danger-bold",thm.AlertWarn)
        make("TextLabel",{Size=UDim2.new(1,0,0,s(16)),BackgroundTransparency=1,Text="Close Interface",TextColor3=thm.Text,TextSize=fs(16),Font=Enum.Font.GothamBold,TextXAlignment=Enum.TextXAlignment.Center,LayoutOrder=1,Parent=prompt})
        make("TextLabel",{Size=UDim2.new(1,0,0,s(28)),BackgroundTransparency=1,Text="Active features will keep running.",TextColor3=thm.SubText,TextSize=fs(16),Font=Enum.Font.Gotham,TextWrapped=true,TextXAlignment=Enum.TextXAlignment.Center,LayoutOrder=2,Parent=prompt})
        local btnRow=make("Frame",{Size=UDim2.new(1,0,0,s(26)),BackgroundTransparency=1,LayoutOrder=3,Parent=prompt})
        make("UIListLayout",{FillDirection=Enum.FillDirection.Horizontal,HorizontalAlignment=Enum.HorizontalAlignment.Center,SortOrder=Enum.SortOrder.LayoutOrder,Padding=sz(10),Parent=btnRow})
        local noBtn=make("TextButton",{Size=ss(88,24),BackgroundColor3=thm.Element,Text="Cancel",TextColor3=thm.SubText,TextSize=fs(16),Font=Enum.Font.GothamBold,LayoutOrder=1,Parent=btnRow})
        make("UICorner",{CornerRadius=sz(10),Parent=noBtn})
        make("UIStroke",{Color=thm.Border,Thickness=1,Parent=noBtn})
        local yesBtn=make("TextButton",{Size=ss(88,24),BackgroundColor3=thm.AlertError,Text="Close",TextColor3=Color3.fromRGB(255,255,255),TextSize=fs(16),Font=Enum.Font.GothamBold,LayoutOrder=2,Parent=btnRow})
        make("UICorner",{CornerRadius=sz(10),Parent=yesBtn})
        yesBtn.MouseEnter:Connect(function() tw(yesBtn,{BackgroundColor3=Color3.fromRGB(240,75,75)},0.1) end)
        yesBtn.MouseLeave:Connect(function() tw(yesBtn,{BackgroundColor3=thm.AlertError},0.1) end)
        noBtn.MouseEnter:Connect(function() tw(noBtn,{BackgroundColor3=thm.ElementHover},0.1) end)
        noBtn.MouseLeave:Connect(function() tw(noBtn,{BackgroundColor3=thm.Element},0.1) end)
        yesBtn.MouseButton1Click:Connect(function()
            tw(overlay,{BackgroundTransparency=1},0.15)
            tw(main,{Size=UDim2.new(0,main.AbsoluteSize.X,0,0),BackgroundTransparency=1},0.22)
            task.delay(0.25,function() gui:Destroy() end)
        end)
        local function cancelClose() tw(overlay,{BackgroundTransparency=1},0.15); task.delay(0.15,function() overlay:Destroy() end) end
        noBtn.MouseButton1Click:Connect(cancelClose)
        overlay.MouseButton1Click:Connect(cancelClose)
        tw(overlay,{BackgroundTransparency=0.5},0.2)
        prompt.Size=ss(0,0)
        tw(prompt,{Size=ss(290,152)},0.22,Enum.EasingStyle.Back)
    end

    minBtn.MouseButton1Click:Connect(toggleMinimize)
    maxBtn.MouseButton1Click:Connect(toggleMaximize)
    closeBtn.MouseButton1Click:Connect(showClosePrompt)

    local minimizeKey=cfg.MinimizeKey or Enum.KeyCode.LeftShift
    local visible=true

    local win={Tabs={},Categories={},GUI=gui,MainFrame=main, _connections=winConnections}

    local uiScale = main:FindFirstChildOfClass("UIScale") or make("UIScale", { Scale = 1, Parent = main })
    local toggling = false

    function win:SetVisible(state)
        if toggling then return end
        toggling = true
        if state then
            visible = true
            main.Visible = true
            resizeOverlay.Visible = not minimized
            uiScale.Scale = 0.8
            local t = tw(uiScale, { Scale = 1 }, 0.22, Enum.EasingStyle.Back, Enum.EasingDirection.Out)
            t.Completed:Connect(function()
                toggling = false
            end)
        else
            resizeOverlay.Visible = false
            local t = tw(uiScale, { Scale = 0.8 }, 0.18, Enum.EasingStyle.Quad, Enum.EasingDirection.In)
            t.Completed:Connect(function()
                main.Visible = false
                visible = false
                toggling = false
            end)
        end
    end

    function win:Toggle()
        self:SetVisible(not visible)
    end

    function win:SetMinimizeKey(key)
        if typeof(key) == "EnumItem" then
            minimizeKey = key
        elseif typeof(key) == "string" then
            pcall(function()
                minimizeKey = Enum.KeyCode[key]
            end)
        end
    end

    function win:SetAcrylicTransparency(transparency)
        if self.MainFrame then
            tw(self.MainFrame, { BackgroundTransparency = transparency }, 0.15)
            
            local sidebar = self.MainFrame:FindFirstChild("Sidebar")
            if sidebar then
                local st = math.clamp(transparency + 0.15, 0, 0.95)
                tw(sidebar, { BackgroundTransparency = st }, 0.15)
                for _, child in ipairs(sidebar:GetChildren()) do
                    if child.Name == "CornerPatch" then
                        tw(child, { BackgroundTransparency = st }, 0.15)
                    end
                end
            end
            
            local content = self.MainFrame:FindFirstChild("Content")
            if content then
                local top = content:FindFirstChild("Top")
                if top then
                    local tt = math.clamp(transparency + 0.20, 0, 0.95)
                    tw(top, { BackgroundTransparency = tt }, 0.15)
                    for _, child in ipairs(top:GetChildren()) do
                        if child.Name == "CornerPatch" then
                            tw(child, { BackgroundTransparency = tt }, 0.15)
                        end
                    end
                end
            end
        end
    end

    function win:SetBlurIntensity(intensity)
        local dof = game:GetService("Lighting"):FindFirstChild("AuroraBlur")
        if dof then
            tw(dof, { NearIntensity = intensity }, 0.15)
        end
    end

    -- Keyboard show/hide: PC only
    local minimizeConn
    if not _isMobile then
        minimizeConn = UserInputService.InputBegan:Connect(function(input, processed)
            if not processed and input.KeyCode == minimizeKey then
                win:Toggle()
            end
        end)
        table.insert(winConnections, minimizeConn)

        -- Keybind badge in sidebar (PC only) - shows the current minimize key
        local kbBadge = make("Frame", {
            Size = UDim2.new(1, -s(18), 0, s(28)),
            Position = UDim2.new(0, s(9), 1, -s(36)),
            BackgroundColor3 = thm.Element,
            BackgroundTransparency = 0.5,
            Parent = sidebar,
        })
        make("UICorner", { CornerRadius = sz(10), Parent = kbBadge })
        make("UIStroke", { Color = thm.Border, Thickness = 1, Transparency = 0.5, Parent = kbBadge })
        make("UIPadding", { PaddingLeft = sz(8), PaddingRight = sz(8), Parent = kbBadge })
        local kbIco = make("ImageLabel", {
            Size = ss(12, 12),
            AnchorPoint = Vector2.new(0, 0.5),
            Position = UDim2.new(0, 0, 0.5, 0),
            BackgroundTransparency = 1,
            Parent = kbBadge,
        })
        applyIcon(kbIco, "solar/keyboard-linear", thm.SubText)
        local keyName = minimizeKey == Enum.KeyCode.None and "None" or minimizeKey.Name
        make("TextLabel", {
            Size = UDim2.new(1, -s(18), 1, 0),
            Position = UDim2.new(0, s(18), 0, 0),
            BackgroundTransparency = 1,
            Text = keyName,
            TextColor3 = thm.SubText,
            TextSize = fs(10),
            Font = Enum.Font.GothamBold,
            TextXAlignment = Enum.TextXAlignment.Left,
            Parent = kbBadge,
        })
    end


    function win:Dialog(dcfg)
        dcfg = dcfg or {}
        if main:FindFirstChild("DialogOverlay") then return end
        
        local overlay = make("TextButton", {
            Name = "DialogOverlay",
            Size = UDim2.fromScale(1, 1),
            BackgroundColor3 = Color3.fromRGB(0,0,0),
            BackgroundTransparency = 1,
            Text = "",
            AutoButtonColor = false,
            ZIndex = 9999,
            Parent = main
        })
        make("UICorner", { CornerRadius = sz(16), Parent = overlay })
        
        local prompt = make("Frame", {
            Size = ss(320, 160),
            AnchorPoint = Vector2.new(0.5, 0.5),
            Position = UDim2.fromScale(0.5, 0.5),
            BackgroundColor3 = thm.NotifBG,
            BackgroundTransparency = 0.04,
            ZIndex = 10000,
            Parent = overlay
        })
        make("UICorner", { CornerRadius = sz(16), Parent = prompt })
        local pStroke = make("UIStroke", { Thickness = 1, Transparency = 0.3, Parent = prompt })
        make("UIGradient", {
            Color = ColorSequence.new({
                ColorSequenceKeypoint.new(0, Color3.fromRGB(70,70,88)),
                ColorSequenceKeypoint.new(1, Color3.fromRGB(20,20,26))
            }),
            Rotation = 45,
            Parent = pStroke
        })
        
        make("UIPadding", { PaddingTop = sz(16), PaddingBottom = sz(14), PaddingLeft = sz(18), PaddingRight = sz(18), Parent = prompt })
        make("UIListLayout", { SortOrder = Enum.SortOrder.LayoutOrder, Padding = sz(8), HorizontalAlignment = Enum.HorizontalAlignment.Center, Parent = prompt })
        
        make("TextLabel", {
            Size = UDim2.new(1, 0, 0, s(18)),
            BackgroundTransparency = 1,
            Text = dcfg.Title or "Dialog",
            TextColor3 = thm.Text,
            TextSize = fs(13),
            Font = Enum.Font.GothamBold,
            TextXAlignment = Enum.TextXAlignment.Center,
            LayoutOrder = 1,
            Parent = prompt
        })
        
        local contentLbl = make("TextLabel", {
            Size = UDim2.new(1, 0, 0, s(36)),
            BackgroundTransparency = 1,
            Text = dcfg.Content or "Are you sure?",
            TextColor3 = thm.SubText,
            TextSize = fs(11),
            Font = Enum.Font.Gotham,
            TextWrapped = true,
            TextXAlignment = Enum.TextXAlignment.Center,
            LayoutOrder = 2,
            Parent = prompt
        })
        
        local btnRow = make("Frame", {
            Size = UDim2.new(1, 0, 0, s(28)),
            BackgroundTransparency = 1,
            LayoutOrder = 3,
            Parent = prompt
        })
        make("UIListLayout", {
            FillDirection = Enum.FillDirection.Horizontal,
            HorizontalAlignment = Enum.HorizontalAlignment.Center,
            SortOrder = Enum.SortOrder.LayoutOrder,
            Padding = sz(10),
            Parent = btnRow
        })
        
        local function closeDialog()
            tw(overlay, { BackgroundTransparency = 1 }, 0.15)
            tw(prompt, { Size = ss(0,0) }, 0.15)
            task.delay(0.16, function() overlay:Destroy() end)
        end
        
        local buttons = dcfg.Buttons or {}
        if #buttons == 0 then
            buttons = { { Title = "OK", Callback = function() end } }
        end
        
        for idx, btnCfg in ipairs(buttons) do
            local btn = make("TextButton", {
                Size = ss(88, 24),
                BackgroundColor3 = idx == 1 and thm.Element or thm.Accent,
                Text = btnCfg.Title or "Button",
                TextColor3 = idx == 1 and thm.SubText or Color3.fromRGB(255,255,255),
                TextSize = fs(12),
                Font = Enum.Font.GothamBold,
                LayoutOrder = idx,
                Parent = btnRow
            })
            make("UICorner", { CornerRadius = sz(11), Parent = btn })
            if idx == 1 then
                make("UIStroke", { Color = thm.Border, Thickness = 1, Parent = btn })
            end
            
            btn.MouseEnter:Connect(function()
                tw(btn, { BackgroundColor3 = idx == 1 and thm.ElementHover or Color3.fromRGB(math.clamp(thm.Accent.R*255+20,0,255), math.clamp(thm.Accent.G*255+20,0,255), math.clamp(thm.Accent.B*255+20,0,255)) }, 0.1)
            end)
            btn.MouseLeave:Connect(function()
                tw(btn, { BackgroundColor3 = idx == 1 and thm.Element or thm.Accent }, 0.1)
            end)
            
            btn.MouseButton1Click:Connect(function()
                closeDialog()
                if btnCfg.Callback then pcall(btnCfg.Callback) end
            end)
        end
        
        task.spawn(function()
            task.wait()
            local textH = contentLbl.TextBounds.Y
            local minHeight = textH + s(100)
            prompt.Size = ss(320, minHeight)
        end)
        
        tw(overlay, { BackgroundTransparency = 0.5 }, 0.2)
        prompt.Size = ss(0, 0)
        tw(prompt, { Size = ss(320, 160) }, 0.22, Enum.EasingStyle.Back)
        
        return {
            Close = closeDialog
        }
    end

    local activeTab=nil

    searchBox:GetPropertyChangedSignal("Text"):Connect(function()
        local query = searchBox.Text:lower():match("^%s*(.-)%s*$") -- trim

        -- Search-results dropdown (created once, lives in sidebar)
        if not win._searchDropdown then
            local drop = make("ScrollingFrame", {
                Name = "SearchDrop",
                Size = UDim2.new(1, -s(18), 0, 0),
                Position = UDim2.new(0, s(9), 0, s(135)),
                BackgroundColor3 = thm.Element,
                BackgroundTransparency = 0.1,
                ScrollBarThickness = s(2),
                ScrollBarImageColor3 = thm.Scrollbar,
                ClipsDescendants = true,
                Visible = false,
                ZIndex = 50,
                Parent = sidebar,
            })
            make("UICorner", { CornerRadius = sz(11), Parent = drop })
            make("UIStroke", { Color = thm.Border, Thickness = 1, Transparency = 0.4, Parent = drop })
            local dropList = make("UIListLayout", {
                SortOrder = Enum.SortOrder.LayoutOrder,
                Padding = sz(2),
                Parent = drop,
            })
            make("UIPadding", { PaddingTop = sz(4), PaddingBottom = sz(4), PaddingLeft = sz(6), PaddingRight = sz(6), Parent = drop })
            dropList.Changed:Connect(function()
                local h = math.min(dropList.AbsoluteContentSize.Y + s(10), s(260))
                drop.Size = UDim2.new(1, -s(18), 0, h)
                drop.CanvasSize = UDim2.new(0, 0, 0, dropList.AbsoluteContentSize.Y + s(10))
            end)
            win._searchDropdown = drop
            win._searchDropList = dropList
        end

        local drop = win._searchDropdown
        local dropList = win._searchDropList

        -- Clear previous results
        for _, c in ipairs(drop:GetChildren()) do
            if c:IsA("TextButton") or c:IsA("TextLabel") or c:IsA("Frame") then c:Destroy() end
        end

        if query == "" then
            drop.Visible = false
            -- Restore tab visibility
            for _, tab in ipairs(win.Tabs) do tab.Button.Visible = true end
            for _, cat in ipairs(win.Categories) do
                cat.Header.Visible = true
                cat.Container.Visible = cat.Expanded
            end
            return
        end

        -- Search in global element registry
        local results = {}
        for _, entry in ipairs(Aurora._globalElements) do
            if entry.title:find(query, 1, true) then
                table.insert(results, entry)
            end
        end

        -- Also search tab names (keep existing tab filter)
        for _, tab in ipairs(win.Tabs) do
            tab.Button.Visible = tab.TextLabel.Text:lower():find(query, 1, true) ~= nil
        end
        for _, cat in ipairs(win.Categories) do
            local hasVis = false
            for _, tab in ipairs(cat.Tabs) do if tab.Button.Visible then hasVis = true; break end end
            cat.Header.Visible = hasVis
            cat.Container.Visible = hasVis
        end

        -- Populate dropdown
        local currentThm = Aurora.Theme or Aurora.Themes.Dark
        if #results == 0 then
            local noRes = make("TextLabel", {
                Size = UDim2.new(1, 0, 0, s(28)),
                BackgroundTransparency = 1,
                Text = "No results found",
                TextColor3 = currentThm.SubText,
                TextSize = fs(11),
                Font = Enum.Font.Gotham,
                TextXAlignment = Enum.TextXAlignment.Center,
                LayoutOrder = 1,
                Parent = drop,
            })
        else
            for idx, entry in ipairs(results) do
                local tabName = entry.tab and entry.tab.TextLabel and entry.tab.TextLabel.Text or "?"
                local row = make("TextButton", {
                    Size = UDim2.new(1, 0, 0, s(34)),
                    BackgroundColor3 = currentThm.Element,
                    BackgroundTransparency = 0.5,
                    Text = "",
                    AutoButtonColor = false,
                    LayoutOrder = idx,
                    ZIndex = 52,
                    Parent = drop,
                })
                make("UICorner", { CornerRadius = sz(9), Parent = row })
                -- Element name
                make("TextLabel", {
                    Size = UDim2.new(1, -s(8), 0, s(16)),
                    Position = UDim2.new(0, s(8), 0, s(2)),
                    BackgroundTransparency = 1,
                    Text = entry.displayTitle,
                    TextColor3 = currentThm.Text,
                    TextSize = fs(12),
                    Font = Enum.Font.GothamBold,
                    TextXAlignment = Enum.TextXAlignment.Left,
                    TextTruncate = Enum.TextTruncate.AtEnd,
                    ZIndex = 53,
                    Parent = row,
                })
                -- Tab badge
                make("TextLabel", {
                    Size = UDim2.new(1, -s(8), 0, s(13)),
                    Position = UDim2.new(0, s(8), 0, s(19)),
                    BackgroundTransparency = 1,
                    Text = tabName,
                    TextColor3 = currentThm.Accent,
                    TextSize = fs(10),
                    Font = Enum.Font.Gotham,
                    TextXAlignment = Enum.TextXAlignment.Left,
                    TextTruncate = Enum.TextTruncate.AtEnd,
                    ZIndex = 53,
                    Parent = row,
                })
                -- Hover
                row.MouseEnter:Connect(function() tw(row, { BackgroundTransparency = 0.2 }, 0.1) end)
                row.MouseLeave:Connect(function() tw(row, { BackgroundTransparency = 0.5 }, 0.1) end)
                -- Click: navigate to tab
                row.MouseButton1Click:Connect(function()
                    local tab = entry.tab
                    if tab then
                        pcall(function() tab:Select() end)
                        -- Select the subtab if it exists
                        if entry.subTab then
                            pcall(function() entry.subTab:Select() end)
                        end
                        -- Scroll to element
                        task.delay(0.05, function()
                            pcall(function()
                                local scrollFrame = entry.subTab and entry.subTab.Page or tab.DefaultScroll
                                local elemAbs = entry.frame.AbsolutePosition
                                local scrollAbs = scrollFrame.AbsolutePosition
                                local offset = elemAbs.Y - scrollAbs.Y + scrollFrame.CanvasPosition.Y
                                tw(scrollFrame, { CanvasPosition = Vector2.new(0, math.max(0, offset - s(20))) }, 0.3, Enum.EasingStyle.Quad)
                                -- Briefly highlight the element
                                tw(entry.frame, { BackgroundColor3 = currentThm.Accent, BackgroundTransparency = 0.75 }, 0.15)
                                task.delay(0.8, function()
                                    tw(entry.frame, { BackgroundTransparency = 1 }, 0.3)
                                end)
                            end)
                        end)
                        -- Clear search
                        searchBox.Text = ""
                    end
                end)
            end
        end
        drop.Visible = true
    end)

    local Category={}; Category.__index=Category
    function Category:AddTab(tcfg)
        local t=win:AddTab(tcfg, self.Container)
        table.insert(self.Tabs,t)
        return t
    end

    function win:AddCategory(title, icon)
        local category={Tabs={},Expanded=true}
        local header=make("TextButton",{Size=UDim2.new(1,0,0,s(24)),BackgroundTransparency=1,AutoButtonColor=false,Text="",Parent=tabScroll})
        make("UICorner",{CornerRadius=sz(9),Parent=header})
        
        local arrow=make("ImageLabel",{Size=ss(10,10),Position=UDim2.new(0,s(4),0.5,-s(5)),BackgroundTransparency=1,Parent=header})
        local label=make("TextLabel",{
            Size=UDim2.new(1,-s(20),1,0),Position=UDim2.new(0,s(18),0,0),
            BackgroundTransparency=1,Text=string.upper(title),
            TextSize=fs(10),Font=Enum.Font.GothamBold,TextXAlignment=Enum.TextXAlignment.Left,Parent=header,
        })

        local isHovering = false
        header.MouseEnter:Connect(function()
            isHovering = true
            local currentThm = Aurora.Theme or Aurora.Themes.Dark
            tw(header, { BackgroundColor3 = currentThm.ElementHover, BackgroundTransparency = 0.8 }, 0.15)
        end)
        header.MouseLeave:Connect(function()
            isHovering = false
            tw(header, { BackgroundTransparency = 1 }, 0.15)
        end)

        local tabContainer=make("Frame",{Size=UDim2.new(1,0,0,0),AutomaticSize=Enum.AutomaticSize.Y,BackgroundTransparency=1,Parent=tabScroll})
        make("UIListLayout",{SortOrder=Enum.SortOrder.LayoutOrder,Padding=sz(3),Parent=tabContainer})
        header.MouseButton1Click:Connect(function()
            category.Expanded=not category.Expanded
            tabContainer.Visible=category.Expanded
            tw(arrow, { Rotation = category.Expanded and 0 or -90 }, 0.18)
        end)

        local themeObj = {
            isCallback = true,
            callback = function()
                if not header or not header.Parent then return end
                local currentThm = Aurora.Theme or Aurora.Themes.Dark
                if isHovering then
                    header.BackgroundColor3 = currentThm.ElementHover
                end
                label.TextColor3 = currentThm.SubText
                applyIcon(arrow, "solar/alt-arrow-down-linear", currentThm.SubText)
            end
        }
        table.insert(Aurora.ThemeObjs, themeObj)

        header.Destroying:Connect(function()
            for idx, item in ipairs(Aurora.ThemeObjs) do
                if item == themeObj then
                    table.remove(Aurora.ThemeObjs, idx)
                    break
                end
            end
        end)

        pcall(themeObj.callback)

        category.Container=tabContainer; category.Header=header
        table.insert(win.Categories,category)
        return setmetatable(category,Category)
    end

    function win:AddTab(tcfg, parentContainer)
        if Aurora.LazyLoad then
            task.wait(Aurora.DelayPerTab or 0.05)
        end
        local tabParent=parentContainer or tabScroll
        local btn=make("TextButton",{Size=UDim2.new(1,0,0,s(34)),BackgroundTransparency=1,Text="",Parent=tabParent})
        make("UICorner",{CornerRadius=sz(10),Parent=btn})
        local lbl=make("TextLabel",{
            Size=UDim2.new(1,-s(38),1,0),Position=UDim2.new(0,s(34),0,0),
            BackgroundTransparency=1,Text=tcfg.Title,TextColor3=thm.TabInactive,
            TextSize=fs(16),Font=Enum.Font.GothamBold,TextXAlignment=Enum.TextXAlignment.Left,Parent=btn,
        })
        local ico=make("ImageLabel",{Size=ss(16,16),Position=UDim2.new(0,s(8),0.5,-s(8)),BackgroundTransparency=1,Parent=btn})
        applyIcon(ico,tcfg.Icon,thm.TabInactive)
        
        if Aurora.FadeIn then
            lbl.TextTransparency = 1
            ico.ImageTransparency = 1
            task.defer(function()
                tw(lbl, { TextTransparency = 0 }, 0.3)
                tw(ico, { ImageTransparency = 0 }, 0.3)
            end)
        end

        -- Left accent indicator (pill style)
        local indicator=make("Frame",{
            Size=UDim2.new(0,s(3),0,s(18)),Position=UDim2.new(0,s(3),0.5,-s(9)),
            BackgroundColor3=thm.Accent,BorderSizePixel=0,Visible=false,Parent=btn,
        })
        make("UICorner",{CornerRadius=sz(2),Parent=indicator})

        local p=make("Frame",{Size=UDim2.fromScale(1,1),BackgroundTransparency=1,Visible=false,Parent=tabHold})
        local defaultScroll=make("ScrollingFrame",{Size=UDim2.fromScale(1,1),BackgroundTransparency=1,ScrollBarThickness=s(2),ScrollBarImageColor3=thm.Scrollbar,Parent=p})
        local c=make("Frame",{Size=UDim2.new(1,0,0,0),AutomaticSize=Enum.AutomaticSize.Y,BackgroundTransparency=1,Parent=defaultScroll})
        local l=make("UIListLayout",{SortOrder=Enum.SortOrder.LayoutOrder,Padding=sz(10),Parent=c})
        make("UIPadding",{PaddingTop=sz(14),PaddingBottom=sz(20),PaddingLeft=sz(14),PaddingRight=sz(14),Parent=c})
        l.Changed:Connect(function() defaultScroll.CanvasSize=UDim2.new(0,0,0,l.AbsoluteContentSize.Y+s(30)) end)

        local t=setmetatable({Button=btn,Page=p,ScrollContent=c,DefaultScroll=defaultScroll,TextLabel=lbl,IconImg=ico,IconStr=tcfg.Icon,Indicator=indicator, _window=win},Tab)

        btn.MouseEnter:Connect(function()
            if activeTab ~= t then
                local currentThm = Aurora.Theme or Aurora.Themes.Dark
                tw(btn, { BackgroundColor3 = currentThm.ElementHover, BackgroundTransparency = 0.6 }, 0.15)
                tw(lbl, { TextColor3 = currentThm.Text }, 0.15)
                if ico then applyIcon(ico, tcfg.Icon, currentThm.Text) end
            end
        end)
        btn.MouseLeave:Connect(function()
            if activeTab ~= t then
                local currentThm = Aurora.Theme or Aurora.Themes.Dark
                tw(btn, { BackgroundTransparency = 1 }, 0.15)
                tw(lbl, { TextColor3 = currentThm.TabInactive }, 0.15)
                if ico then applyIcon(ico, tcfg.Icon, currentThm.TabInactive) end
            end
        end)

        function t:Select()
            local currentThm = Aurora.Theme or Aurora.Themes.Dark
            if activeTab then
                activeTab.Page.Visible=false
                tw(activeTab.Button,{BackgroundColor3=currentThm.Sidebar,BackgroundTransparency=1},0.18)
                activeTab.TextLabel.TextColor3=currentThm.TabInactive
                if activeTab.IconImg then applyIcon(activeTab.IconImg,activeTab.IconStr,currentThm.TabInactive) end
                activeTab.Indicator.Visible=false
            end
            activeTab=t; activeTab.Page.Visible=true
            activeTab.Page.Position = UDim2.new(0, 0, 0.025, 0)
            tw(activeTab.Page, { Position = UDim2.new(0, 0, 0, 0) }, 0.22, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
            -- Active tab: soft accent background, bolder accent text
            tw(btn,{BackgroundColor3=currentThm.Accent,BackgroundTransparency=0.85},0.18)
            lbl.TextColor3=currentThm.Accent
            if ico then applyIcon(ico,tcfg.Icon,currentThm.Accent) end
            indicator.Visible=true
        end

        btn.MouseButton1Click:Connect(function()
            t:Select()
        end)

        if #win.Tabs==0 then
            activeTab=t; t.Page.Visible=true
            btn.BackgroundTransparency=0.85; btn.BackgroundColor3=thm.Accent
            lbl.TextColor3=thm.Accent
            if ico then applyIcon(ico,tcfg.Icon,thm.Accent) end
            indicator.Visible=true
        end

        local themeObj = {
            isCallback = true,
            callback = function()
                if not btn or not btn.Parent then return end
                local currentThm = Aurora.Theme or Aurora.Themes.Dark
                if activeTab == t then
                    btn.BackgroundColor3 = currentThm.Accent
                    btn.BackgroundTransparency = 0.85
                    lbl.TextColor3 = currentThm.Accent
                    indicator.BackgroundColor3 = currentThm.Accent
                    if ico then applyIcon(ico, tcfg.Icon, currentThm.Accent) end
                else
                    btn.BackgroundTransparency = 1
                    lbl.TextColor3 = currentThm.TabInactive
                    if ico then applyIcon(ico, tcfg.Icon, currentThm.TabInactive) end
                end
            end
        }
        table.insert(Aurora.ThemeObjs, themeObj)
        btn.Destroying:Connect(function()
            for idx, item in ipairs(Aurora.ThemeObjs) do
                if item == themeObj then
                    table.remove(Aurora.ThemeObjs, idx)
                    break
                end
            end
        end)

        table.insert(win.Tabs,t)
        return t
    end

    -- ============================================================
    --  PLATFORM-SPECIFIC CONTROLS
    --  Mobile - FAB show/hide button + touch drag
    --  PC     - keyboard keybind only (registered above)
    -- ============================================================
    local mobileGui
    if _isMobile or cfg.MobileButton == true then
        mobileGui = make("ScreenGui", {
            Name = "AuroraMobileToggleGui",
            ResetOnSpawn = false,
            DisplayOrder = 99999
        })
        safeParent(mobileGui)

        local mbIcon = cfg.MobileButtonIcon or "solar/star-bold"
        local mbPos  = cfg.MobileButtonPosition or UDim2.new(0, s(16), 0, s(100))
        local fabSize = s(44) -- compact but touch-friendly

        local mobileBtn = make("TextButton", {
            Name = "AuroraMobileToggle",
            Size = UDim2.fromOffset(fabSize, fabSize),
            Position = mbPos,
            BackgroundColor3 = Color3.fromRGB(16, 16, 22),
            BackgroundTransparency = 0.12,
            Text = "",
            ZIndex = 100,
            Parent = mobileGui
        })
        make("UICorner", { CornerRadius = UDim.new(1, 0), Parent = mobileBtn })

        -- Accent ring
        local mStroke = make("UIStroke", {
            Color = thm.Accent,
            Thickness = 1.5,
            Transparency = 0.35,
            Parent = mobileBtn
        })
        -- Inner glow circle
        local innerGlow = make("Frame", {
            Size = UDim2.fromOffset(s(28), s(28)),
            AnchorPoint = Vector2.new(0.5, 0.5),
            Position = UDim2.fromScale(0.5, 0.5),
            BackgroundColor3 = thm.Accent,
            BackgroundTransparency = 0.75,
            Parent = mobileBtn
        })
        make("UICorner", { CornerRadius = UDim.new(1, 0), Parent = innerGlow })
        -- Icon
        local mIco = make("ImageLabel", {
            Size = UDim2.fromOffset(s(18), s(18)),
            AnchorPoint = Vector2.new(0.5, 0.5),
            Position = UDim2.fromScale(0.5, 0.5),
            BackgroundTransparency = 1,
            ZIndex = 101,
            Parent = mobileBtn
        })
        applyIcon(mIco, mbIcon, Color3.fromRGB(255, 255, 255))

        -- Press animation
        local mScale = make("UIScale", { Scale = 1.0, Parent = mobileBtn })
        mobileBtn.InputBegan:Connect(function(i)
            if i.UserInputType == Enum.UserInputType.Touch or i.UserInputType == Enum.UserInputType.MouseButton1 then
                tw(mScale, { Scale = 0.88 }, 0.1, Enum.EasingStyle.Back, Enum.EasingDirection.Out)
            end
        end)
        mobileBtn.InputEnded:Connect(function(i)
            if i.UserInputType == Enum.UserInputType.Touch or i.UserInputType == Enum.UserInputType.MouseButton1 then
                tw(mScale, { Scale = 1.0 }, 0.16, Enum.EasingStyle.Back, Enum.EasingDirection.Out)
            end
        end)

        -- Drag logic
        local mDrag = false
        local mDragStart, mStartPos
        local dragDistance = 0
        local lastInteractionTime = tick()

        local function wakeBtn()
            lastInteractionTime = tick()
            tw(mobileBtn, { BackgroundTransparency = 0.12 }, 0.15)
            tw(innerGlow,  { BackgroundTransparency = 0.75 }, 0.15)
            tw(mStroke,    { Transparency = 0.35 }, 0.15)
        end

        local function snapToEdge()
            local sw = mobileGui.AbsoluteSize.X
            if sw == 0 then sw = 800 end
            local cx = mobileBtn.AbsolutePosition.X + mobileBtn.AbsoluteSize.X / 2
            local targetX = cx < sw / 2 and s(16) or (sw - fabSize - s(16))
            tw(mobileBtn, { Position = UDim2.new(0, targetX, 0, mobileBtn.Position.Y.Offset) }, 0.3, Enum.EasingStyle.Back, Enum.EasingDirection.Out)
            task.delay(2.5, function()
                if not mDrag and tick() - lastInteractionTime >= 2.4 then
                    tw(mobileBtn, { BackgroundTransparency = 0.82 }, 0.35)
                    tw(innerGlow,  { BackgroundTransparency = 0.94 }, 0.35)
                    tw(mStroke,    { Transparency = 0.82 }, 0.35)
                end
            end)
        end

        -- Subtle pulse
        task.spawn(function()
            while mobileBtn and mobileBtn.Parent do
                pcall(function()
                    if not mDrag then
                        local base = mobileBtn.BackgroundTransparency > 0.5 and 0.78 or 0.3
                        local t1 = TweenService:Create(mStroke, TweenInfo.new(1.1, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut), { Transparency = base + 0.22, Thickness = 2.2 })
                        t1:Play(); t1.Completed:Wait()
                        local t2 = TweenService:Create(mStroke, TweenInfo.new(1.1, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut), { Transparency = base, Thickness = 1.5 })
                        t2:Play(); t2.Completed:Wait()
                    else
                        task.wait(0.2)
                    end
                end)
                task.wait(0.1)
            end
        end)

        mobileBtn.InputBegan:Connect(function(input)
            if input.UserInputType == Enum.UserInputType.Touch or input.UserInputType == Enum.UserInputType.MouseButton1 then
                mDrag = true; mDragStart = input.Position
                mStartPos = mobileBtn.Position; dragDistance = 0
                wakeBtn()
            end
        end)
        local mChanged = UserInputService.InputChanged:Connect(function(input)
            if mDrag and (input.UserInputType == Enum.UserInputType.Touch or input.UserInputType == Enum.UserInputType.MouseMovement) then
                local d = input.Position - mDragStart
                dragDistance = d.Magnitude
                mobileBtn.Position = UDim2.new(mStartPos.X.Scale, mStartPos.X.Offset + d.X, mStartPos.Y.Scale, mStartPos.Y.Offset + d.Y)
                lastInteractionTime = tick()
            end
        end)
        local mEnded = UserInputService.InputEnded:Connect(function(input)
            if input.UserInputType == Enum.UserInputType.Touch or input.UserInputType == Enum.UserInputType.MouseButton1 then
                if mDrag then mDrag = false; snapToEdge() end
            end
        end)
        table.insert(winConnections, mChanged)
        table.insert(winConnections, mEnded)
        mobileBtn.MouseButton1Click:Connect(function()
            if dragDistance < 8 then win:Toggle() end
        end)

        -- Touch drag for the main window itself (mobile)
        local winDrag = false
        local winDragStart, winStartPos
        top.InputBegan:Connect(function(input)
            if input.UserInputType == Enum.UserInputType.Touch then
                winDrag = true; winDragStart = input.Position; winStartPos = main.Position
            end
        end)
        local wChanged = UserInputService.InputChanged:Connect(function(input)
            if winDrag and input.UserInputType == Enum.UserInputType.Touch then
                local d = input.Position - winDragStart
                main.Position = UDim2.new(winStartPos.X.Scale, winStartPos.X.Offset + d.X, winStartPos.Y.Scale, winStartPos.Y.Offset + d.Y)
            end
        end)
        local wEnded = UserInputService.InputEnded:Connect(function(input)
            if input.UserInputType == Enum.UserInputType.Touch then winDrag = false end
        end)
        table.insert(winConnections, wChanged)
        table.insert(winConnections, wEnded)
    end

    gui.Destroying:Connect(function()
        if mobileGui then pcall(function() mobileGui:Destroy() end) end
        pcall(function()
            if Aurora.ActiveWatermarkObj then
                Aurora.ActiveWatermarkObj:Destroy()
            end
        end)
        pcall(function()
            if Aurora.ActiveKeybindListObj then
                Aurora.ActiveKeybindListObj:Destroy()
            end
        end)
        pcall(function()
            if Aurora.MobileKeybindsGui then
                Aurora.MobileKeybindsGui:Destroy()
                Aurora.MobileKeybindsGui = nil
            end
        end)
        pcall(function()
            if _tooltipGui then
                _tooltipGui:Destroy()
                _tooltipGui = nil
            end
        end)
        pcall(function()
            if _nGui then
                _nGui:Destroy()
                _nGui = nil
            end
        end)
        pcall(function()
            if winConnections then
                for _, conn in ipairs(winConnections) do
                    pcall(function() conn:Disconnect() end)
                end
                table.clear(winConnections)
            end
        end)
    end)

    function win:Destroy()
        pcall(function() gui:Destroy() end)
    end

    return win
end

-- ================================================================================
--  ADDITIONAL UTILITY FUNCTIONS (RGB & Themes)
-- ================================================================================
function Aurora:CreateTheme(name, tbl)
    tbl = tbl or {}
    local dark = self.Themes.Dark
    local newTheme = {}
    for k, v in pairs(dark) do
        newTheme[k] = tbl[k] or v
    end
    self.Themes[name] = newTheme
end

local rgbActive = false
function Aurora:SetTheme(name)
    rgbActive = false
    if name == "RGB" then
        self.Theme = self.Themes.RGB or self.Themes.Dark
        self:UpdateTheme()
        rgbActive = true
        task.spawn(function()
            local hue = 0
            while rgbActive and task.wait(0.03) do
                hue = (hue + 0.005) % 1
                local color = Color3.fromHSV(hue, 0.8, 1)
                self.Theme.Accent = color
                self.Theme.ToggleOn = color
                self.Theme.SliderFill = color
                self:UpdateTheme()
            end
        end)
    else
        self.Theme = self.Themes[name] or self.Themes.Dark
        self:UpdateTheme()
    end
end

function Aurora:Watermark(wcfg)
    wcfg = wcfg or {}
    if self.WatermarkGui then
        pcall(function() self.WatermarkGui:Destroy() end)
        self.WatermarkGui = nil
    end
    if wcfg.Enabled == false then return end

    local thm = self.Theme or self.Themes.Dark
    local gui = make("ScreenGui", { Name = "AuroraWatermark", ResetOnSpawn = false, DisplayOrder = 9999 })
    safeParent(gui)
    self.WatermarkGui = gui

    local frame = make("Frame", {
        Position = wcfg.Position or UDim2.new(0, s(20), 0, s(20)),
        Size = UDim2.new(0, 0, 0, s(26)),
        AutomaticSize = Enum.AutomaticSize.X,
        BackgroundColor3 = thm.Background,
        BackgroundTransparency = 0.35,
        Parent = gui
    })
    make("UICorner", { CornerRadius = sz(10), Parent = frame })
    local wStroke = make("UIStroke", { Color = thm.Border, Thickness = 1, Parent = frame })
    make("UIPadding", { PaddingLeft = sz(8), PaddingRight = sz(8), Parent = frame })
    
    local layout = make("UIListLayout", {
        FillDirection = Enum.FillDirection.Horizontal,
        VerticalAlignment = Enum.VerticalAlignment.Center,
        Padding = sz(6),
        Parent = frame
    })

    local dot = make("Frame", {
        Size = ss(8, 8),
        BackgroundColor3 = thm.Accent,
        Parent = frame
    })
    make("UICorner", { CornerRadius = UDim.new(1, 0), Parent = dot })
    local dotStroke = make("UIStroke", { Color = thm.Accent, Thickness = 1.5, Transparency = 0.5, Parent = dot })

    local lbl = make("TextLabel", {
        Size = UDim2.new(0, 0, 1, 0),
        AutomaticSize = Enum.AutomaticSize.X,
        BackgroundTransparency = 1,
        Text = "",
        TextColor3 = thm.Text,
        TextSize = fs(11),
        Font = Enum.Font.GothamBold,
        Parent = frame
    })

    local drag, ds, sp = false, nil, nil
    frame.InputBegan:Connect(function(i)
        if i.UserInputType == Enum.UserInputType.MouseButton1 or i.UserInputType == Enum.UserInputType.Touch then
            drag = true; ds = i.Position; sp = frame.Position
        end
    end)
    local changedConn = UserInputService.InputChanged:Connect(function(i)
        if drag and (i.UserInputType == Enum.UserInputType.MouseMovement or i.UserInputType == Enum.UserInputType.Touch) then
            local delta = i.Position - ds
            frame.Position = UDim2.new(sp.X.Scale, sp.X.Offset + delta.X, sp.Y.Scale, sp.Y.Offset + delta.Y)
        end
    end)
    local endedConn = UserInputService.InputEnded:Connect(function(i)
        if i.UserInputType == Enum.UserInputType.MouseButton1 or i.UserInputType == Enum.UserInputType.Touch then
            drag = false
        end
    end)
    gui.Destroying:Connect(function()
        pcall(function() changedConn:Disconnect() end)
        pcall(function() endedConn:Disconnect() end)
    end)

    task.spawn(function()
        while gui and gui.Parent do
            pcall(function()
                local t1 = TweenService:Create(dotStroke, TweenInfo.new(0.8, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut), { Transparency = 0.9, Thickness = 3 })
                t1:Play()
                t1.Completed:Wait()
                local t2 = TweenService:Create(dotStroke, TweenInfo.new(0.8, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut), { Transparency = 0.3, Thickness = 1.5 })
                t2:Play()
                t2.Completed:Wait()
            end)
            task.wait(0.1)
        end
    end)

    local runService = game:GetService("RunService")
    local stats = game:GetService("Stats")
    local fps = 60
    local ping = 0

    local conn
    conn = runService.RenderStepped:Connect(function(dt)
        if not gui or not gui.Parent then
            conn:Disconnect()
            return
        end
        fps = math.floor(1 / dt)
        pcall(function()
            ping = math.floor(stats.Network.ServerStatsItem["Data Ping"]:GetValue())
        end)
        lbl.Text = string.format("%s  |  %s  |  %dfps  |  %dms", wcfg.Title or "Aurora", LocalPlayer.Name, fps, ping)
    end)
    
    table.insert(self.ThemeObjs, { Obj = frame, Prop = "BackgroundColor3", Key = "Background" })
    table.insert(self.ThemeObjs, { Obj = wStroke, Prop = "Color", Key = "Border" })
    table.insert(self.ThemeObjs, { Obj = dot, Prop = "BackgroundColor3", Key = "Accent" })
    table.insert(self.ThemeObjs, { Obj = dotStroke, Prop = "Color", Key = "Accent" })
    table.insert(self.ThemeObjs, { Obj = lbl, Prop = "TextColor3", Key = "Text" })

    local obj = {}
    function obj:SetTitle(t)
        wcfg.Title = t
    end
    function obj:Destroy()
        if conn then conn:Disconnect() end
        pcall(function() gui:Destroy() end)
        if Aurora.ActiveWatermarkObj == obj then
            Aurora.ActiveWatermarkObj = nil
        end
    end
    Aurora.ActiveWatermarkObj = obj
    return obj

end

function Aurora:KeybindList(kcfg)
    kcfg = kcfg or {}
    if self.KeybindListGui then
        pcall(function() self.KeybindListGui:Destroy() end)
        self.KeybindListGui = nil
    end
    if kcfg.Enabled == false then 
        self.RefreshKeybindList = nil
        return 
    end

    local thm = self.Theme or self.Themes.Dark
    local gui = make("ScreenGui", { Name = "AuroraKeybindList", ResetOnSpawn = false, DisplayOrder = 9997 })
    safeParent(gui)
    self.KeybindListGui = gui

    local mainFrame = make("Frame", {
        Name = "MainFrame",
        Size = ss(180, 200),
        Position = kcfg.Position or UDim2.new(1, -s(200), 0.5, -s(100)),
        BackgroundColor3 = thm.Background,
        BackgroundTransparency = 0.35,
        ClipsDescendants = true,
        Parent = gui
    })
    make("UICorner", { CornerRadius = sz(11), Parent = mainFrame })
    local mStroke = make("UIStroke", { Color = thm.Border, Thickness = 1, Parent = mainFrame })
    
    local header = make("Frame", {
        Size = UDim2.new(1, 0, 0, s(28)),
        BackgroundColor3 = thm.Sidebar,
        BackgroundTransparency = 0.5,
        Parent = mainFrame
    })
    make("UICorner", { CornerRadius = sz(11), Parent = header })
    make("UIPadding", { PaddingLeft = sz(8), PaddingRight = sz(8), Parent = header })
    
    local title = make("TextLabel", {
        Size = UDim2.fromScale(1, 1),
        BackgroundTransparency = 1,
        Text = "Active Keybinds",
        TextColor3 = thm.Text,
        TextSize = fs(11),
        Font = Enum.Font.GothamBold,
        TextXAlignment = Enum.TextXAlignment.Left,
        Parent = header
    })
    
    local cont = make("Frame", {
        Size = UDim2.new(1, 0, 1, -s(28)),
        Position = UDim2.new(0, 0, 0, s(28)),
        BackgroundTransparency = 1,
        Parent = mainFrame
    })
    local layout = make("UIListLayout", {
        SortOrder = Enum.SortOrder.LayoutOrder,
        Padding = sz(4),
        Parent = cont
    })
    make("UIPadding", { PaddingTop = sz(6), PaddingBottom = sz(6), PaddingLeft = sz(8), PaddingRight = sz(8), Parent = cont })
    
    local drag, ds, sp = false, nil, nil
    header.InputBegan:Connect(function(i)
        if i.UserInputType == Enum.UserInputType.MouseButton1 or i.UserInputType == Enum.UserInputType.Touch then
            drag = true; ds = i.Position; sp = mainFrame.Position
        end
    end)
    local changedConn = UserInputService.InputChanged:Connect(function(i)
        if drag and (i.UserInputType == Enum.UserInputType.MouseMovement or i.UserInputType == Enum.UserInputType.Touch) then
            local delta = i.Position - ds
            mainFrame.Position = UDim2.new(sp.X.Scale, sp.X.Offset + delta.X, sp.Y.Scale, sp.Y.Offset + delta.Y)
        end
    end)
    local endedConn = UserInputService.InputEnded:Connect(function(i)
        if i.UserInputType == Enum.UserInputType.MouseButton1 or i.UserInputType == Enum.UserInputType.Touch then
            drag = false
        end
    end)
    gui.Destroying:Connect(function()
        pcall(function() changedConn:Disconnect() end)
        pcall(function() endedConn:Disconnect() end)
    end)

    local keybindLabels = {}
    local function refreshList()
        for _, lbl in pairs(keybindLabels) do
            lbl:Destroy()
        end
        table.clear(keybindLabels)
        
        local sorted = {}
        for id, opt in pairs(Aurora.Options) do
            if opt.Type == "Keybind" then
                table.insert(sorted, opt)
            end
        end
        
        for _, opt in ipairs(sorted) do
            local item = make("Frame", {
                Size = UDim2.new(1, 0, 0, s(20)),
                BackgroundTransparency = 1,
                Parent = cont
            })
            
            local isActive = false
            if opt.ToggleParent then
                isActive = (opt.ToggleParent.Value == true)
            elseif opt.IsActive then
                isActive = (opt.IsActive() == true)
            end

            local keyText = "None"
            if typeof(opt.Value) == "EnumItem" then
                if opt.Value.EnumType == Enum.KeyCode then
                    keyText = opt.Value == Enum.KeyCode.None and "None" or opt.Value.Name
                elseif opt.Value.EnumType == Enum.UserInputType then
                    keyText = opt.Value.Name:gsub("MouseButton", "MB")
                end
            end

            local nameLbl = make("TextLabel", {
                Size = UDim2.new(0.65, 0, 1, 0),
                BackgroundTransparency = 1,
                Text = opt.id:gsub("_Bind", ""),
                TextColor3 = isActive and thm.Text or thm.SubText,
                TextSize = fs(10),
                Font = Enum.Font.GothamBold,
                TextXAlignment = Enum.TextXAlignment.Left,
                Parent = item
            })
            local keyLbl = make("TextLabel", {
                Size = UDim2.new(0.35, 0, 1, 0),
                Position = UDim2.new(0.65, 0, 0, 0),
                BackgroundTransparency = 1,
                Text = keyText,
                TextColor3 = isActive and Color3.fromRGB(38, 195, 95) or thm.Accent,
                TextSize = fs(10),
                Font = Enum.Font.GothamBold,
                TextXAlignment = Enum.TextXAlignment.Right,
                Parent = item
            })
            
            table.insert(keybindLabels, item)
        end
        
        local count = #sorted
        local targetH = s(28) + s(12) + count * s(24)
        mainFrame.Size = ss(180, math.clamp(targetH, 60, 350))
    end

    self.RefreshKeybindList = refreshList

    task.spawn(function()
        task.wait(0.5)
        refreshList()
    end)
    
    local conn1 = UserInputService.InputBegan:Connect(function()
        task.defer(refreshList)
    end)
    local conn2 = UserInputService.InputEnded:Connect(function()
        task.defer(refreshList)
    end)

    table.insert(self.ThemeObjs, { Obj = mainFrame, Prop = "BackgroundColor3", Key = "Background" })
    table.insert(self.ThemeObjs, { Obj = mStroke, Prop = "Color", Key = "Border" })
    table.insert(self.ThemeObjs, { Obj = header, Prop = "BackgroundColor3", Key = "Sidebar" })
    table.insert(self.ThemeObjs, { Obj = title, Prop = "TextColor3", Key = "Text" })

    local obj = {}
    function obj:Refresh()
        refreshList()
    end
    function obj:Destroy()
        if conn1 then conn1:Disconnect() end
        if conn2 then conn2:Disconnect() end
        if Aurora.RefreshKeybindList == refreshList then
            Aurora.RefreshKeybindList = nil
        end
        pcall(function() gui:Destroy() end)
        if Aurora.ActiveKeybindListObj == obj then
            Aurora.ActiveKeybindListObj = nil
        end
    end
    Aurora.ActiveKeybindListObj = obj
    return obj

end

-- ================================================================================
--  NEW PREMIUM ELEMENTS (Divider, Image, Space, Audio, Code)
-- ================================================================================
function Section:AddDivider()
    return self:AddSeparator("")
end

function Section:AddLabel(id, text)
    local thm = Aurora.Theme
    local obj = { Type="Label", Value=text or "", id=id }

    local f = elemFrame(self.Container)
    local lbl = make("TextLabel", {
        Size = UDim2.new(1, 0, 0, 0),
        AutomaticSize = Enum.AutomaticSize.Y,
        BackgroundTransparency = 1,
        Text = text or "",
        TextColor3 = thm.Text,
        TextSize = fs(12),
        Font = Enum.Font.Gotham,
        TextXAlignment = Enum.TextXAlignment.Left,
        TextWrapped = true,
        Parent = f
    })

    function obj:SetText(t)
        self.Value = t
        lbl.Text = t
    end

    function obj:SetValue(t)
        self:SetText(t)
    end

    addVisibilityAPI(obj, f)
    Aurora.Options[id] = obj
    return obj
end

-- ================================================================================
function Section:AddChangelog(id, data)
    local thm = Aurora.Theme
    local obj = { Type="Changelog", Value=data, id=id }

    local f = elemFrame(self.Container)
    f.BackgroundTransparency = 0.8
    make("UIListLayout", { SortOrder = Enum.SortOrder.LayoutOrder, Padding = sz(12), Parent = f })
    
    local badgeColors = {
        Added    = Color3.fromRGB(46, 204, 113),
        Añadido  = Color3.fromRGB(46, 204, 113),
        Fixed    = Color3.fromRGB(231, 76, 60),
        BugFix   = Color3.fromRGB(231, 76, 60),
        Arreglo  = Color3.fromRGB(231, 76, 60),
        Improved = Color3.fromRGB(52, 152, 219),
        Mejora   = Color3.fromRGB(52, 152, 219),
        Removed  = Color3.fromRGB(230, 126, 34)
    }

    local numVersions = #data
    for i, ver in ipairs(data) do
        local verFrame = make("Frame", {
            Size = UDim2.new(1, 0, 0, 0),
            AutomaticSize = Enum.AutomaticSize.Y,
            BackgroundTransparency = 1,
            Parent = f
        })
        make("UIListLayout", { SortOrder = Enum.SortOrder.LayoutOrder, Padding = sz(8), Parent = verFrame })

        local header = make("Frame", {
            Size = UDim2.new(1, 0, 0, s(16)),
            BackgroundTransparency = 1,
            Parent = verFrame
        })
        
        make("TextLabel", {
            Size = UDim2.new(0.5, 0, 1, 0),
            Position = UDim2.new(0, 0, 0, 0),
            BackgroundTransparency = 1,
            Text = ver.Version or "v1.0",
            TextColor3 = thm.Text,
            TextSize = fs(14),
            Font = Enum.Font.GothamBold,
            TextXAlignment = Enum.TextXAlignment.Left,
            Parent = header
        })
        
        if ver.Date then
            make("TextLabel", {
                Size = UDim2.new(0.5, 0, 1, 0),
                Position = UDim2.new(0.5, 0, 0, 0),
                BackgroundTransparency = 1,
                Text = ver.Date,
                TextColor3 = thm.TextDark,
                TextSize = fs(11),
                Font = Enum.Font.Gotham,
                TextXAlignment = Enum.TextXAlignment.Right,
                Parent = header
            })
        end

        local changesFrame = make("Frame", {
            Size = UDim2.new(1, 0, 0, 0),
            AutomaticSize = Enum.AutomaticSize.Y,
            BackgroundTransparency = 1,
            Parent = verFrame
        })
        make("UIListLayout", { SortOrder = Enum.SortOrder.LayoutOrder, Padding = sz(6), Parent = changesFrame })

        if ver.Changes then
            for _, change in ipairs(ver.Changes) do
                local row = make("Frame", {
                    Size = UDim2.new(1, 0, 0, 0),
                    AutomaticSize = Enum.AutomaticSize.Y,
                    BackgroundTransparency = 1,
                    Parent = changesFrame
                })
                make("UIListLayout", {
                    SortOrder = Enum.SortOrder.LayoutOrder, 
                    FillDirection = Enum.FillDirection.Horizontal, 
                    Padding = sz(8), 
                    VerticalAlignment = Enum.VerticalAlignment.Center,
                    Parent = row 
                })

                local typeStr = change.Type or "Note"
                local badgeColor = badgeColors[typeStr] or Color3.fromRGB(149, 165, 166)

                local badge = make("Frame", {
                    AutomaticSize = Enum.AutomaticSize.XY,
                    BackgroundColor3 = badgeColor,
                    Parent = row
                })
                make("UICorner", { CornerRadius = sz(4), Parent = badge })
                make("UIPadding", {
                    PaddingTop = sz(2), PaddingBottom = sz(2),
                    PaddingLeft = sz(6), PaddingRight = sz(6),
                    Parent = badge
                })

                make("TextLabel", {
                    AutomaticSize = Enum.AutomaticSize.XY,
                    BackgroundTransparency = 1,
                    Text = typeStr:upper(),
                    TextColor3 = Color3.fromRGB(255, 255, 255),
                    TextSize = fs(10),
                    Font = Enum.Font.GothamBold,
                    Parent = badge
                })

                make("TextLabel", {
                    Size = UDim2.new(1, -s(60), 0, 0),
                    AutomaticSize = Enum.AutomaticSize.Y,
                    BackgroundTransparency = 1,
                    Text = change.Text or "",
                    TextColor3 = thm.TextDark,
                    TextSize = fs(12),
                    Font = Enum.Font.Gotham,
                    TextXAlignment = Enum.TextXAlignment.Left,
                    TextWrapped = true,
                    RichText = true,
                    Parent = row
                })
            end
        end

        if i < numVersions then
            make("Frame", {
                Size = UDim2.new(1, 0, 0, 1),
                BackgroundColor3 = thm.Border,
                BackgroundTransparency = 0.5,
                BorderSizePixel = 0,
                Parent = verFrame
            })
        end
    end

    addVisibilityAPI(obj, f)
    Aurora.Options[id] = obj
    return obj
end
function Section:AddLiveStat(id, cfg)
    local thm = Aurora.Theme
    cfg = cfg or {}
    local obj = { Type="LiveStat", Value=cfg.Default or "", id=id }

    local f = elemFrame(self.Container)
    local inner = make("Frame", {
        Size = UDim2.new(1, 0, 0, s(35)),
        BackgroundColor3 = thm.Element,
        BackgroundTransparency = 0.3,
        Parent = f
    })
    make("UICorner", { CornerRadius = UDim.new(0, s(6)), Parent = inner })
    make("UIStroke", { Color = thm.Border, Thickness = 1, Parent = inner })

    local icon = make("ImageLabel", {
        Size = UDim2.new(0, s(18), 0, s(18)),
        Position = UDim2.new(0, s(10), 0, s(8)),
        BackgroundTransparency = 1,
        ImageColor3 = cfg.IconColor or thm.ToggleOn,
        Image = Aurora:GetIcon(cfg.Icon or "solar/chart-bold") or "",
        Parent = inner
    })

    local titleLbl = make("TextLabel", {
        Size = UDim2.new(0.35, -40, 1, 0),
        Position = UDim2.new(0, s(36), 0, 0),
        BackgroundTransparency = 1,
        Text = cfg.Title or "Stat",
        TextColor3 = thm.SubText,
        TextSize = fs(13),
        TextScaled = true,
        Font = Enum.Font.GothamMedium,
        TextXAlignment = Enum.TextXAlignment.Left,
        Parent = inner
    })
    make("UITextSizeConstraint", { MaxTextSize = fs(13), MinTextSize = 8, Parent = titleLbl })

    local valLbl = make("TextLabel", {
        Size = UDim2.new(0.65, -10, 1, 0),
        Position = UDim2.new(0.35, 0, 0, 0),
        BackgroundTransparency = 1,
        Text = tostring(obj.Value),
        TextColor3 = cfg.Color or thm.Text,
        TextSize = fs(15),
        TextScaled = true,
        Font = Enum.Font.GothamBold,
        TextXAlignment = Enum.TextXAlignment.Right,
        Parent = inner
    })
    make("UITextSizeConstraint", { MaxTextSize = fs(15), MinTextSize = 8, Parent = valLbl })
    
    -- Subtle neon glow on the text
    local glow = make("UIStroke", {
        Color = cfg.Color or thm.ToggleOn,
        Thickness = 0.5,
        Transparency = 0.3,
        Parent = valLbl
    })

    function obj:SetText(t, color)
        self.Value = t
        valLbl.Text = tostring(t)
        if color then
            valLbl.TextColor3 = color
            glow.Color = color
            icon.ImageColor3 = color
        end
    end
    function obj:SetValue(t, color) self:SetText(t, color) end

    addVisibilityAPI(obj, f)
    Aurora.Options[id] = obj
    return obj
end

function Section:AddSpace(height)
    local f = make("Frame", {
        Size = UDim2.new(1, 0, 0, s(height or 10)),
        BackgroundTransparency = 1,
        Parent = self.Container
    })
    local obj = {Type = "Space"}
    addVisibilityAPI(obj, f)
    return obj
end

function Section:AddImage(id, cfg)
    cfg = cfg or {}
    local f = elemFrame(self.Container)
    local img = make("ImageLabel", {
        Size = cfg.Size or ss(200, 200),
        Image = cfg.Image or "",
        BackgroundTransparency = 1,
        Parent = f
    })
    local obj = { Type="Image", ImageLabel=img, id=id }
    function obj:SetImage(asset) img.Image = tostring(asset) end
    addVisibilityAPI(obj, f)
    Aurora.Options[id] = obj
    return obj
end

function Section:AddAudio(id, cfg)
    cfg = cfg or {}
    local thm = Aurora.Theme
    local sound = make("Sound", {
        SoundId = "rbxassetid://" .. tostring(cfg.SoundId or 0),
        Volume = cfg.Volume or 0.5,
        Looped = cfg.Looped or false,
        Parent = game:GetService("SoundService")
    })
    local f = elemFrame(self.Container)
    local topF = make("Frame", { Size=UDim2.new(1,0,0,s(4)), AutomaticSize=Enum.AutomaticSize.Y, BackgroundTransparency=1, Parent=f })
    local tx = 0
    if cfg.Icon then
        local ico = make("ImageLabel",{Size=ss(16,16),BackgroundTransparency=1,Parent=topF})
        applyIcon(ico, cfg.Icon, thm.IconColor); tx=s(22)
    end
    local titleLabel = make("TextLabel", {
        Size=UDim2.new(1,-tx-s(100),0,0), Position=UDim2.new(0,tx,0,0), AutomaticSize=Enum.AutomaticSize.Y,
        BackgroundTransparency=1, Text=cfg.Title or "Audio Player", TextColor3=thm.Text, TextSize=fs(16),
        Font=Enum.Font.GothamBold, TextXAlignment=Enum.TextXAlignment.Left, Parent=topF,
    })
    local rightControls = make("Frame", {
        Size=UDim2.new(0,s(90),1,0), AnchorPoint=Vector2.new(1,0.5), Position=UDim2.new(1,0,0.5,0),
        BackgroundTransparency=1, Parent=topF,
    })
    make("UIListLayout", { FillDirection=Enum.FillDirection.Horizontal, HorizontalAlignment=Enum.HorizontalAlignment.Right, VerticalAlignment=Enum.VerticalAlignment.Center, Padding=sz(5), Parent=rightControls })
    
    local playBtn = make("TextButton", { Size=ss(40,20), BackgroundColor3=thm.InputBG, Text="Play", TextColor3=thm.Text, Font=Enum.Font.GothamBold, TextSize=fs(10), Parent=rightControls })
    make("UICorner", { CornerRadius=sz(8), Parent=playBtn })
    make("UIStroke", { Color=thm.Border, Thickness=1, Parent=playBtn })
    
    local stopBtn = make("TextButton", { Size=ss(40,20), BackgroundColor3=thm.InputBG, Text="Stop", TextColor3=thm.Text, Font=Enum.Font.GothamBold, TextSize=fs(10), Parent=rightControls })
    make("UICorner", { CornerRadius=sz(8), Parent=stopBtn })
    make("UIStroke", { Color=thm.Border, Thickness=1, Parent=stopBtn })
    
    playBtn.MouseButton1Click:Connect(function() sound:Play() end)
    stopBtn.MouseButton1Click:Connect(function() sound:Stop() end)
    
    local obj = { Type="Audio", Sound=sound, id=id }
    function obj:Play() sound:Play() end
    function obj:Stop() sound:Stop() end
    function obj:SetVolume(v) sound.Volume = v end
    function obj:SetSoundId(sid) sound.SoundId = "rbxassetid://" .. tostring(sid) end
    
    addVisibilityAPI(obj, f)
    Aurora.Options[id] = obj
    return obj
end

function Section:AddCode(id, cfg)
    cfg = cfg or {}
    local thm = Aurora.Theme
    local f = elemFrame(self.Container)
    make("TextLabel", {
        Size=UDim2.new(1,0,0,s(14)), BackgroundTransparency=1, Text=cfg.Title or "Code Block", TextColor3=thm.SubText,
        TextSize=fs(10), Font=Enum.Font.GothamBold, TextXAlignment=Enum.TextXAlignment.Left, Parent=f,
    })
    local codeBG = make("Frame", {
        Size=UDim2.new(1,0,0,s(4)), AutomaticSize=Enum.AutomaticSize.Y, BackgroundColor3=thm.InputBG, Parent=f,
    })
    make("UICorner", { CornerRadius=sz(9), Parent=codeBG })
    make("UIStroke", { Color=thm.Border, Thickness=1, Parent=codeBG })
    make("UIPadding", { PaddingTop=sz(8), PaddingBottom=sz(8), PaddingLeft=sz(10), PaddingRight=sz(10), Parent=codeBG })
    
    local codeLbl = make("TextLabel", {
        Size=UDim2.new(1,0,0,s(4)), AutomaticSize=Enum.AutomaticSize.Y, BackgroundTransparency=1,
        Text=cfg.Code or "", TextColor3=thm.Accent, TextSize=fs(16), Font=Enum.Font.Code,
        TextXAlignment=Enum.TextXAlignment.Left, TextWrapped=true, Parent=codeBG,
    })
    
    local copyBtn = make("TextButton", {
        Size=ss(45,18), AnchorPoint=Vector2.new(1,0), Position=UDim2.new(1,0,0,0),
        BackgroundColor3=thm.Element, Text="Copy", TextColor3=thm.Text, Font=Enum.Font.GothamBold, TextSize=fs(10),
        Parent=f
    })
    make("UICorner", { CornerRadius=sz(8), Parent=copyBtn })
    copyBtn.MouseButton1Click:Connect(function()
        pcall(function() toclipboard(cfg.Code or "") end)
    end)
    
    local obj = { Type="Code", id=id }
    function obj:SetCode(txt) codeLbl.Text = txt; cfg.Code = txt end
    addVisibilityAPI(obj, f)
    Aurora.Options[id] = obj
    return obj
end

function Section:AddVideo(id, cfg)
    cfg = cfg or {}
    local thm = Aurora.Theme
    local videoId = cfg.Video or ""
    if type(videoId) == "number" or (type(videoId) == "string" and videoId:match("^%d+$")) then
        videoId = "rbxassetid://" .. tostring(videoId)
    end
    
    local f = elemFrame(self.Container)
    local height = cfg.Height or s(160)
    
    local videoContainer = make("Frame", {
        Size = UDim2.new(1, 0, 0, height),
        BackgroundColor3 = Color3.fromRGB(10, 10, 14),
        BorderSizePixel = 0,
        ClipsDescendants = true,
        Parent = f
    })
    make("UICorner", { CornerRadius = sz(10), Parent = videoContainer })
    local stroke = make("UIStroke", { Color = thm.Border, Thickness = 1, Parent = videoContainer })
    
    local videoFrame
    local isPlaying = cfg.AutoPlay ~= false
    local looped = cfg.Looped ~= false
    local volume = cfg.Volume or 0.5
    
    if videoId ~= "" then
        videoFrame = make("VideoFrame", {
            Size = UDim2.fromScale(1, 1),
            BackgroundTransparency = 1,
            Video = videoId,
            Looped = looped,
            Volume = volume,
            Parent = videoContainer
        })
        make("UICorner", { CornerRadius = sz(10), Parent = videoFrame })
        if isPlaying then
            task.spawn(function()
                pcall(function() videoFrame:Play() end)
            end)
        end
    end
    
    -- Controls Overlay (fades in on hover)
    local controls = make("Frame", {
        Size = UDim2.new(1, 0, 0, s(28)),
        Position = UDim2.new(0, 0, 1, -s(28)),
        BackgroundColor3 = Color3.fromRGB(0, 0, 0),
        BackgroundTransparency = 0.4,
        BorderSizePixel = 0,
        ZIndex = 5,
        Parent = videoContainer
    })
    
    local layout = make("UIListLayout", {
        FillDirection = Enum.FillDirection.Horizontal,
        VerticalAlignment = Enum.VerticalAlignment.Center,
        HorizontalAlignment = Enum.HorizontalAlignment.Left,
        SortOrder = Enum.SortOrder.LayoutOrder,
        Padding = sz(8),
        Parent = controls
    })
    make("UIPadding", { PaddingLeft = sz(8), PaddingRight = sz(8), Parent = controls })
    
    -- Play/Pause Button
    local playBtn = make("TextButton", {
        Size = ss(18, 18),
        BackgroundTransparency = 1,
        Text = "",
        ZIndex = 6,
        Parent = controls
    })
    local playIcon = make("ImageLabel", {
        Size = UDim2.fromScale(1, 1),
        BackgroundTransparency = 1,
        Parent = playBtn
    })
    applyIcon(playIcon, isPlaying and "solar/pause-bold" or "solar/play-bold", Color3.fromRGB(255, 255, 255))
    
    playBtn.MouseButton1Click:Connect(function()
        if not videoFrame then return end
        isPlaying = not isPlaying
        if isPlaying then
            videoFrame:Play()
            applyIcon(playIcon, "solar/pause-bold", Color3.fromRGB(255, 255, 255))
        else
            videoFrame:Pause()
            applyIcon(playIcon, "solar/play-bold", Color3.fromRGB(255, 255, 255))
        end
    end)
    
    -- Volume Slider / Mute Button
    local volBtn = make("TextButton", {
        Size = ss(18, 18),
        BackgroundTransparency = 1,
        Text = "",
        ZIndex = 6,
        Parent = controls
    })
    local volIcon = make("ImageLabel", {
        Size = UDim2.fromScale(1, 1),
        BackgroundTransparency = 1,
        Parent = volBtn
    })
    applyIcon(volIcon, volume > 0 and "solar/volume-loud-bold" or "solar/volume-cross-bold", Color3.fromRGB(255, 255, 255))
    
    volBtn.MouseButton1Click:Connect(function()
        if not videoFrame then return end
        if videoFrame.Volume > 0 then
            videoFrame.Volume = 0
            applyIcon(volIcon, "solar/volume-cross-bold", Color3.fromRGB(255, 255, 255))
        else
            videoFrame.Volume = volume
            applyIcon(volIcon, "solar/volume-loud-bold", Color3.fromRGB(255, 255, 255))
        end
    end)
    
    -- Title Label
    local titleLbl = make("TextLabel", {
        Size = UDim2.new(1, -s(80), 1, 0),
        BackgroundTransparency = 1,
        Text = cfg.Title or "Video Player",
        TextColor3 = Color3.fromRGB(255, 255, 255),
        TextSize = fs(10),
        Font = Enum.Font.GothamBold,
        TextXAlignment = Enum.TextXAlignment.Right,
        Parent = controls
    })
    
    local obj = { Type = "Video", VideoFrame = videoFrame, id = id }
    function obj:Play()
        if videoFrame then
            videoFrame:Play()
            isPlaying = true
            applyIcon(playIcon, "solar/pause-bold", Color3.fromRGB(255, 255, 255))
        end
    end
    function obj:Pause()
        if videoFrame then
            videoFrame:Pause()
            isPlaying = false
            applyIcon(playIcon, "solar/play-bold", Color3.fromRGB(255, 255, 255))
        end
    end
    function obj:SetVolume(v)
        volume = v
        if videoFrame then
            videoFrame.Volume = v
            applyIcon(volIcon, v > 0 and "solar/volume-loud-bold" or "solar/volume-cross-bold", Color3.fromRGB(255, 255, 255))
        end
    end
    
    addVisibilityAPI(obj, f)
    Aurora.Options[id] = obj
    return obj
end

-- ================================================================================
--  VIEWPORT 3D ELEMENT (Premium)
-- ================================================================================
function Section:AddViewport(id, cfg)
    cfg = cfg or {}
    local thm = Aurora.Theme or Aurora.Themes.Dark

    local height    = cfg.Height or 200
    local title     = cfg.Title or "3D Viewport"
    local camDist   = cfg.CameraDistance or 8
    local camAngleY = cfg.CameraAngleY or 25
    local spinSpeed = cfg.SpinSpeed or 0
    local autoSpin  = cfg.AutoSpin or false

    -- -- Outer wrapper frame ------------------------------------------
    local f = elemFrame(self.Container)

    -- Header row with accent dot
    local headerRow = make("Frame", {
        Size = UDim2.new(1, 0, 0, s(24)),
        BackgroundTransparency = 1,
        Parent = f,
    })

    -- Accent dot (like section headers)
    local accentDot = make("Frame", {
        Size = ss(4, 4),
        Position = UDim2.new(0, 0, 0.5, 0),
        AnchorPoint = Vector2.new(0, 0.5),
        BackgroundColor3 = thm.Accent,
        BorderSizePixel = 0,
        Parent = headerRow,
    })
    make("UICorner", { CornerRadius = UDim.new(1, 0), Parent = accentDot })
    reg(accentDot, "BackgroundColor3", "Accent")

    local titleLbl = make("TextLabel", {
        Size = UDim2.new(1, -s(90), 1, 0),
        Position = UDim2.new(0, s(10), 0, 0),
        BackgroundTransparency = 1,
        Text = title,
        TextColor3 = thm.Text,
        TextSize = fs(12),
        Font = Enum.Font.GothamBold,
        TextXAlignment = Enum.TextXAlignment.Left,
        Parent = headerRow,
    })
    reg(titleLbl, "TextColor3", "Text")

    -- Toolbar buttons (right side of header)
    local toolBar = make("Frame", {
        Size = UDim2.new(0, s(80), 1, 0),
        AnchorPoint = Vector2.new(1, 0),
        Position = UDim2.new(1, 0, 0, 0),
        BackgroundTransparency = 1,
        Parent = headerRow,
    })
    make("UIListLayout", {
        FillDirection = Enum.FillDirection.Horizontal,
        HorizontalAlignment = Enum.HorizontalAlignment.Right,
        VerticalAlignment = Enum.VerticalAlignment.Center,
        Padding = sz(3),
        Parent = toolBar,
    })

    local function mkToolBtn(icon, tooltip)
        local btn = make("TextButton", {
            Size = ss(24, 22),
            BackgroundColor3 = thm.Element,
            BackgroundTransparency = 0.3,
            Text = "",
            Parent = toolBar,
        })
        make("UICorner", { CornerRadius = sz(11), Parent = btn })
        local bStroke = make("UIStroke", { Color = thm.Border, Thickness = 1, Transparency = 0.4, Parent = btn })
        reg(bStroke, "Color", "Border")
        reg(btn, "BackgroundColor3", "Element")
        local ico = make("ImageLabel", {
            Size = ss(12, 12),
            AnchorPoint = Vector2.new(0.5, 0.5),
            Position = UDim2.fromScale(0.5, 0.5),
            BackgroundTransparency = 1,
            Parent = btn,
        })
        applyIcon(ico, icon, thm.SubText)
        if tooltip and tooltip ~= "" then addTooltip(btn, tooltip) end

        -- Hover scale animation
        local scale = make("UIScale", { Scale = 1, Parent = btn })
        btn.MouseEnter:Connect(function()
            tw(scale, { Scale = 1.08 }, 0.12, Enum.EasingStyle.Quad)
            tw(btn, { BackgroundTransparency = 0 }, 0.12)
            tw(bStroke, { Transparency = 0, Color = thm.Accent }, 0.12)
        end)
        btn.MouseLeave:Connect(function()
            tw(scale, { Scale = 1.0 }, 0.12, Enum.EasingStyle.Quad)
            tw(btn, { BackgroundTransparency = 0.3 }, 0.12)
            tw(bStroke, { Transparency = 0.4, Color = thm.Border }, 0.12)
        end)
        return btn, ico
    end

    local resetBtn,  resetIco  = mkToolBtn("solar/restart-bold",        "Reset Camera")
    local spinBtn,   spinIco   = mkToolBtn("solar/refresh-circle-bold", "Toggle Auto-Spin")
    local clearBtn,  clearIco  = mkToolBtn("solar/close-circle-bold",   "Clear Model")

    -- -- ViewportFrame container --------------------------------------
    local vpOuter = make("Frame", {
        Size = UDim2.new(1, 0, 0, s(height)),
        BackgroundColor3 = thm.InputBG,
        BorderSizePixel = 0,
        ClipsDescendants = true,
        Parent = f,
    })
    make("UICorner", { CornerRadius = sz(10), Parent = vpOuter })
    reg(vpOuter, "BackgroundColor3", "InputBG")

    -- Premium gradient accent border
    local vpStroke = make("UIStroke", { Thickness = s(1.5), Transparency = 0.3, Parent = vpOuter })
    local vpGrad = make("UIGradient", {
        Color = ColorSequence.new({
            ColorSequenceKeypoint.new(0, thm.Accent),
            ColorSequenceKeypoint.new(0.4, thm.Border),
            ColorSequenceKeypoint.new(1, thm.Border),
        }),
        Rotation = 135,
        Parent = vpStroke,
    })
    table.insert(Aurora.ThemeObjs, { isCallback = true, callback = function()
        local t = Aurora.Theme or Aurora.Themes.Dark
        vpGrad.Color = ColorSequence.new({
            ColorSequenceKeypoint.new(0, t.Accent),
            ColorSequenceKeypoint.new(0.4, t.Border),
            ColorSequenceKeypoint.new(1, t.Border),
        })
    end })

    -- Dark gradient overlay at the bottom (for footer readability)
    local bottomGrad = make("Frame", {
        Size = UDim2.new(1, 0, 0, s(40)),
        Position = UDim2.new(0, 0, 1, -s(40)),
        BackgroundColor3 = Color3.fromRGB(0, 0, 0),
        BackgroundTransparency = 0,
        BorderSizePixel = 0,
        ZIndex = 2,
        Parent = vpOuter,
    })
    make("UIGradient", {
        Transparency = NumberSequence.new({
            NumberSequenceKeypoint.new(0, 1),
            NumberSequenceKeypoint.new(0.5, 0.6),
            NumberSequenceKeypoint.new(1, 0.3),
        }),
        Rotation = 90,
        Parent = bottomGrad,
    })

    -- ViewportFrame
    local vp = make("ViewportFrame", {
        Size = UDim2.fromScale(1, 1),
        BackgroundTransparency = 1,
        LightColor = Color3.fromRGB(230, 235, 255),
        LightDirection = Vector3.new(-1, -1.5, -0.8),
        Ambient = Color3.fromRGB(95, 95, 110),
        Parent = vpOuter,
    })

    -- -- Placeholder (animated, shows when no model) ------------------
    local phFrame = make("Frame", {
        Size = UDim2.fromScale(1, 1),
        BackgroundTransparency = 1,
        ZIndex = 3,
        Parent = vpOuter,
    })

    local phIcon = make("ImageLabel", {
        Size = ss(32, 32),
        AnchorPoint = Vector2.new(0.5, 0.5),
        Position = UDim2.new(0.5, 0, 0.45, 0),
        BackgroundTransparency = 1,
        ImageTransparency = 0.5,
        Parent = phFrame,
    })
    applyIcon(phIcon, "solar/box-bold", thm.SubText)

    local phLbl = make("TextLabel", {
        Size = UDim2.new(0.8, 0, 0, s(30)),
        AnchorPoint = Vector2.new(0.5, 0),
        Position = UDim2.new(0.5, 0, 0.58, 0),
        BackgroundTransparency = 1,
        Text = "Drag a model here or use\n:SetPlayer() - :SetModel()",
        TextColor3 = thm.SubText,
        TextTransparency = 0.4,
        TextSize = fs(10),
        Font = Enum.Font.Gotham,
        TextWrapped = true,
        Parent = phFrame,
    })
    reg(phLbl, "TextColor3", "SubText")

    -- Pulse animation for the placeholder icon
    local phPulseConn
    task.spawn(function()
        task.wait(0.2)
        phPulseConn = game:GetService("RunService").Heartbeat:Connect(function()
            if not phFrame.Visible then return end
            local t = tick()
            local alpha = 0.4 + math.sin(t * 1.5) * 0.15
            pcall(function() phIcon.ImageTransparency = alpha end)
        end)
    end)

    -- Footer info bar (shows model name and part count)
    local footerLbl = make("TextLabel", {
        Size = UDim2.new(1, -s(16), 0, s(16)),
        Position = UDim2.new(0, s(8), 1, -s(22)),
        AnchorPoint = Vector2.new(0, 0),
        BackgroundTransparency = 1,
        Text = "",
        TextColor3 = Color3.fromRGB(200, 200, 215),
        TextTransparency = 0.15,
        TextSize = fs(9),
        Font = Enum.Font.GothamMedium,
        TextXAlignment = Enum.TextXAlignment.Left,
        ZIndex = 3,
        Parent = vpOuter,
    })

    -- -- Internal camera state ----------------------------------------
    local vpCamera = Instance.new("Camera")
    vpCamera.FieldOfView = 50
    vpCamera.Parent = vp
    vp.CurrentCamera = vpCamera

    local modelRoot     = nil
    local currentModel  = nil
    local modelOrigin   = Vector3.zero
    local camAngleX     = 0
    local camAngleYCur  = camAngleY
    local camDistCur    = camDist
    local spinning      = autoSpin
    local spinDeg       = spinSpeed ~= 0 and spinSpeed or 30
    local _allConns     = {}
    local charConn      = nil

    local function disconnectCharConn()
        if charConn then
            pcall(function() charConn:Disconnect() end)
            charConn = nil
        end
    end

    local worldModel = Instance.new("WorldModel")
    worldModel.Parent = vp

    -- Smooth camera update
    local function updateCamera()
        if not vpCamera or not vpCamera.Parent then return end
        local radX = math.rad(camAngleX)
        local radY = math.rad(camAngleYCur)
        local offset = Vector3.new(
            camDistCur * math.cos(radY) * math.sin(radX),
            camDistCur * math.sin(radY),
            camDistCur * math.cos(radY) * math.cos(radX)
        )
        vpCamera.CFrame = CFrame.lookAt(modelOrigin + offset, modelOrigin)
    end

    -- Update footer info text
    local function updateFooter(name, partCount)
        if name and name ~= "" then
            footerLbl.Text = name .. (partCount and ("  |  " .. partCount .. " parts") or "")
        else
            footerLbl.Text = ""
        end
    end

    -- Clear model with fade
    local function clearModel()
        disconnectCharConn()
        if currentModel then
            -- Fade out all parts
            for _, desc in ipairs(currentModel:GetDescendants()) do
                if desc:IsA("BasePart") then
                    pcall(function() tw(desc, { Transparency = 1 }, 0.2) end)
                end
            end
            task.delay(0.22, function()
                if currentModel then
                    pcall(function() currentModel:Destroy() end)
                    currentModel = nil
                end
            end)
        end
        modelRoot = nil
        modelOrigin = Vector3.zero
        phFrame.Visible = true
        tw(phIcon, { ImageTransparency = 0.4 }, 0.2)
        tw(phLbl, { TextTransparency = 0.4 }, 0.2)
        updateFooter("")
        updateCamera()
    end

    -- Load model into viewport with entrance animation
    local function loadModelIntoViewport(model)
        -- Clear existing immediately (no fade for swap)
        if currentModel then
            pcall(function() currentModel:Destroy() end)
            currentModel = nil
        end
        modelRoot = nil
        modelOrigin = Vector3.zero
        if not model or typeof(model) ~= "Instance" then
            phFrame.Visible = true
            updateFooter("")
            updateCamera()
            return
        end

        local clone
        local ok = pcall(function()
            local archivables = {}
            for _, desc in ipairs(model:GetDescendants()) do
                pcall(function()
                    archivables[desc] = desc.Archivable
                    desc.Archivable = true
                end)
            end
            local oldArch = model.Archivable
            model.Archivable = true
            
            clone = model:Clone()
            
            pcall(function() model.Archivable = oldArch end)
            for desc, val in pairs(archivables) do
                pcall(function() desc.Archivable = val end)
            end
        end)
        
        if not ok or not clone then
            warn("[AuroraLib Viewport] Failed to clone model: " .. tostring(model))
            return
        end

        clone.Parent = worldModel

        -- Model setup
        local modelName = clone.Name or "Model"
        local partCount = 0

        if clone:IsA("Model") then
            if not clone.PrimaryPart then
                local root = clone:FindFirstChild("HumanoidRootPart")
                    or clone:FindFirstChild("Torso")
                    or clone:FindFirstChild("Head")
                    or clone:FindFirstChildWhichIsA("BasePart")
                if root then clone.PrimaryPart = root end
            end
            -- PivotTo FIRST so bounding box is accurate inside the WorldModel
            pcall(function() clone:PivotTo(CFrame.new(Vector3.zero)) end)

            -- Ensure all parts are visible (some R15/R6 chars have parts hidden)
            for _, d in ipairs(clone:GetDescendants()) do
                if d:IsA("BasePart") then
                    partCount = partCount + 1
                    -- Force LocalTransparencyModifier off (common issue in ViewportFrame)
                    pcall(function() d.LocalTransparencyModifier = 0 end)
                end
            end
        elseif clone:IsA("BasePart") then
            clone.CFrame = CFrame.new(Vector3.zero)
            partCount = 1
            pcall(function() clone.LocalTransparencyModifier = 0 end)
        end

        currentModel = clone
        modelRoot = clone:IsA("Model") and clone or nil

        -- Calculate bounding box for camera fit (after PivotTo)
        local bbSize = Vector3.new(4, 6, 4)
        pcall(function()
            if clone:IsA("Model") then
                local _, sz2 = clone:GetBoundingBox()
                bbSize = sz2
            elseif clone:IsA("BasePart") then
                bbSize = clone.Size
            end
        end)

        -- Set model origin to center of bounding box
        pcall(function()
            if clone:IsA("Model") then
                local cf = clone:GetBoundingBox()
                modelOrigin = cf.Position
            else
                modelOrigin = clone.Position
            end
        end)

        local maxDim = math.max(bbSize.X, bbSize.Y, bbSize.Z)
        camDistCur = math.clamp(maxDim * 1.5, 3, 50)

        -- Hide placeholder
        phFrame.Visible = false

        updateFooter(modelName, partCount)
        updateCamera()
    end

    -- -- Orbital Drag Input -------------------------------------------
    local dragging    = false
    local dragStart   = nil
    local dragAngleX0 = 0
    local dragAngleY0 = 0

    vp.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1
        or input.UserInputType == Enum.UserInputType.Touch then
            dragging    = true
            dragStart   = input.Position
            dragAngleX0 = camAngleX
            dragAngleY0 = camAngleYCur
            -- Accent border glow while dragging
            tw(vpStroke, { Transparency = 0 }, 0.15)
        end
    end)

    local vpDragConn = UserInputService.InputChanged:Connect(function(input)
        if dragging and (input.UserInputType == Enum.UserInputType.MouseMovement
            or input.UserInputType == Enum.UserInputType.Touch) then
            if not dragStart then return end
            local delta = input.Position - dragStart
            camAngleX    = dragAngleX0 - delta.X * 0.5
            camAngleYCur = math.clamp(dragAngleY0 + delta.Y * 0.3, -80, 80)
            updateCamera()
        end
    end)
    table.insert(_allConns, vpDragConn)

    local vpEndConn = UserInputService.InputEnded:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1
        or input.UserInputType == Enum.UserInputType.Touch then
            dragging = false
            tw(vpStroke, { Transparency = 0.3 }, 0.2)
        end
    end)
    table.insert(_allConns, vpEndConn)

    -- Scroll-to-zoom with smooth tween
    vp.InputChanged:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseWheel then
            camDistCur = math.clamp(camDistCur - input.Position.Z * 0.8, 2, 60)
            updateCamera()
        end
    end)

    -- Hover glow effect on viewport border
    vpOuter.MouseEnter:Connect(function()
        if not dragging then
            tw(vpStroke, { Transparency = 0.1 }, 0.2)
        end
    end)
    vpOuter.MouseLeave:Connect(function()
        if not dragging then
            tw(vpStroke, { Transparency = 0.3 }, 0.2)
        end
    end)

    -- -- Auto-spin loop (resource-efficient: only runs when visible) --
    local spinConn
    local function startSpinLoop()
        if spinConn then return end
        spinConn = game:GetService("RunService").RenderStepped:Connect(function(dt)
            -- Skip if the viewport isn't visible (saves CPU)
            if not f.Visible or not vpOuter.Visible then return end
            if spinning and not dragging then
                camAngleX = camAngleX + spinDeg * dt
                updateCamera()
            end
        end)
        table.insert(_allConns, spinConn)
    end
    if autoSpin then spinning = true end
    startSpinLoop()

    -- -- Toolbar button callbacks -------------------------------------

    -- Spin toggle
    local function updateSpinVisual()
        local col = spinning and thm.Accent or thm.SubText
        applyIcon(spinIco, "solar/refresh-circle-bold", col)
    end
    updateSpinVisual()

    spinBtn.MouseButton1Click:Connect(function()
        spinning = not spinning
        updateSpinVisual()
        -- Micro ripple animation
        local sc = make("UIScale", { Scale = 1, Parent = spinBtn })
        tw(sc, { Scale = 0.88 }, 0.06)
        task.delay(0.06, function() tw(sc, { Scale = 1 }, 0.1, Enum.EasingStyle.Back) end)
        task.delay(0.18, function() pcall(function() sc:Destroy() end) end)
    end)

    -- Reset camera
    resetBtn.MouseButton1Click:Connect(function()
        camAngleX    = 0
        camAngleYCur = camAngleY
        camDistCur   = camDist
        updateCamera()
        -- Ripple animation
        local sc = make("UIScale", { Scale = 1, Parent = resetBtn })
        tw(sc, { Scale = 0.88 }, 0.06)
        task.delay(0.06, function() tw(sc, { Scale = 1 }, 0.12, Enum.EasingStyle.Back) end)
        task.delay(0.20, function() pcall(function() sc:Destroy() end) end)
    end)

    -- Clear button
    clearBtn.MouseButton1Click:Connect(function()
        clearModel()
        -- Ripple
        local sc = make("UIScale", { Scale = 1, Parent = clearBtn })
        tw(sc, { Scale = 0.88 }, 0.06)
        task.delay(0.06, function() tw(sc, { Scale = 1 }, 0.12, Enum.EasingStyle.Back) end)
        task.delay(0.20, function() pcall(function() sc:Destroy() end) end)
    end)

    -- -- Full cleanup on destroy --------------------------------------
    f.Destroying:Connect(function()
        for _, conn in ipairs(_allConns) do
            pcall(function() conn:Disconnect() end)
        end
        if phPulseConn then pcall(function() phPulseConn:Disconnect() end) end
        pcall(function() worldModel:Destroy() end)
        pcall(function() vpCamera:Destroy() end)
    end)

    updateCamera()

    -- -- Public API ---------------------------------------------------
    local obj = { Type = "Viewport", id = id }

    function obj:SetModel(model)
        disconnectCharConn()
        loadModelIntoViewport(model)
    end

    function obj:SetWorkspaceModel(nameOrInstance)
        disconnectCharConn()
        if typeof(nameOrInstance) == "Instance" then
            loadModelIntoViewport(nameOrInstance)
        else
            local found = workspace:FindFirstChild(nameOrInstance, true)
            if found then
                loadModelIntoViewport(found)
            else
                warn("[AuroraLib Viewport] Model not found in Workspace:", nameOrInstance)
            end
        end
    end

    function obj:SetPlayer(playerOrName)
        disconnectCharConn()
        local PlayersService = game:GetService("Players")
        local target
        if playerOrName == nil or playerOrName == "local" then
            target = PlayersService.LocalPlayer
        elseif typeof(playerOrName) == "Instance" and playerOrName:IsA("Player") then
            target = playerOrName
        elseif type(playerOrName) == "string" then
            target = PlayersService:FindFirstChild(playerOrName)
        end
        if target then
            charConn = target.CharacterAdded:Connect(function(char)
                loadModelIntoViewport(char)
            end)
            table.insert(_allConns, charConn)
            if target.Character then
                loadModelIntoViewport(target.Character)
            end
        else
            warn("[AuroraLib Viewport] Player not found for:", tostring(playerOrName))
        end
    end

    function obj:Spin(degsPerSec)
        spinDeg  = degsPerSec or 30
        spinning = spinDeg ~= 0
        updateSpinVisual()
    end

    function obj:Clear()
        clearModel()
    end

    function obj:SetTitle(t)
        titleLbl.Text = t
    end

    function obj:SetCamera(dist, angleY)
        if dist   then camDistCur   = dist   end
        if angleY then camAngleYCur = angleY end
        updateCamera()
    end

    addVisibilityAPI(obj, f)
    Aurora.Options[id] = obj
    return obj
end

-- ================================================================================
--  SAVEMANAGER API
-- ================================================================================
local httpService = game:GetService("HttpService")
local isfolder = isfolder or function() return false end
local makefolder = makefolder or function() end
local writefile = writefile or function() end
local readfile = readfile or function() return "" end
local isfile = isfile or function() return false end
local listfiles = listfiles or function() return {} end
local delfile = delfile or function() end

local SaveManager = {}
SaveManager.Folder = "AuroraSettings"
SaveManager.Ignore = {}
SaveManager.Parser = {
    Toggle    = { Save=function(idx,o) return{type="Toggle",idx=idx,value=o.Value} end, Load=function(idx,d) if SaveManager.Options[idx] then SaveManager.Options[idx]:SetValue(d.value) end end },
    Slider    = { Save=function(idx,o) return{type="Slider",idx=idx,value=o.Value} end, Load=function(idx,d) if SaveManager.Options[idx] then SaveManager.Options[idx]:SetValue(d.value) end end },
    Dropdown  = { Save=function(idx,o) return{type="Dropdown",idx=idx,value=o.Value} end, Load=function(idx,d) if SaveManager.Options[idx] then SaveManager.Options[idx]:SetValue(d.value) end end },
    Colorpicker={ Save=function(idx,o) return{type="Colorpicker",idx=idx,value=colorToHex(o.Value),transparency=o.Transparency or 0} end, Load=function(idx,d) if SaveManager.Options[idx] then SaveManager.Options[idx]:SetValueRGB(hexToColor(d.value),d.transparency) end end },
    Keybind   = { Save=function(idx,o) return{type="Keybind",idx=idx,key=o.Value.Name} end, Load=function(idx,d) if SaveManager.Options[idx] then SaveManager.Options[idx]:SetValue(Enum.KeyCode[d.key]) end end },
    Input     = { Save=function(idx,o) return{type="Input",idx=idx,text=o.Value} end, Load=function(idx,d) if SaveManager.Options[idx] and type(d.text)=="string" then SaveManager.Options[idx]:SetValue(d.text) end end },
}

function SaveManager:SetIgnoreIndexes(list) for _,k in next,list do self.Ignore[k]=true end end
function SaveManager:IgnoreIndexes(list) self:SetIgnoreIndexes(list) end
function SaveManager:SetFolder(folder) self.Folder=folder; self:BuildFolderTree() end
function SaveManager:BuildFolderTree()
    local gameFolder = self.Folder .. "/settings/" .. tostring(game.PlaceId)
    local paths = {self.Folder, self.Folder .. "/settings", gameFolder}
    for _, p2 in ipairs(paths) do if not isfolder(p2) then makefolder(p2) end end
end
function SaveManager:SetLibrary(lib) self.Library=lib; self.Options=lib.Options end
function SaveManager:IgnoreThemeSettings() self:SetIgnoreIndexes({"InterfaceTheme","AcrylicToggle","TransparentToggle","MenuKeybind","AnimationToggle"}) end

function SaveManager:Save(name)
    if not name then return false,"no config selected" end
    local data={objects={}}
    for idx,opt in next,SaveManager.Options do
        if self.Parser[opt.Type] and not self.Ignore[idx] then
            table.insert(data.objects, self.Parser[opt.Type].Save(idx,opt))
        end
    end
    local ok,enc=pcall(httpService.JSONEncode,httpService,data)
    if not ok then return false,"encode failed" end
    local path = self.Folder .. "/settings/" .. tostring(game.PlaceId) .. "/" .. name .. ".json"
    writefile(path,enc)
    self.CurrentConfig = name
    return true
end

function SaveManager:Load(name)
    if not name then return false,"no config selected" end
    local f = self.Folder .. "/settings/" .. tostring(game.PlaceId) .. "/" .. name .. ".json"
    if not isfile(f) then return false,"invalid file" end
    local ok,dec=pcall(httpService.JSONDecode,httpService,readfile(f))
    if not ok then return false,"decode error" end
    self.CurrentConfig = name
    for _,opt in next,dec.objects do
        if self.Parser[opt.type] then task.spawn(function() self.Parser[opt.type].Load(opt.idx,opt) end) end
    end
    return true
end

function SaveManager:RefreshConfigList()
    local path = self.Folder .. "/settings/" .. tostring(game.PlaceId)
    if not isfolder(path) then return {} end
    local list=listfiles(path); local out={}
    for _,file in ipairs(list) do
        if file:sub(-5)==".json" then
            local pos=file:find(".json",1,true); local start=pos
            local char=file:sub(pos,pos)
            while char~="/" and char~="\\" and char~="" do pos=pos-1; char=file:sub(pos,pos) end
            if char=="/" or char=="\\" then
                local name=file:sub(pos+1,start-1)
                if name~="options" then table.insert(out,name) end
            end
        end
    end
    return out
end

function SaveManager:LoadAutoloadConfig()
    local ap = self.Folder .. "/settings/" .. tostring(game.PlaceId) .. "/autoload.txt"
    if isfile(ap) then
        local name=readfile(ap)
        self.CurrentConfig = name
        local ok,err=self:Load(name)
        if not ok then return self.Library:Notify({Title="Interface",Content="Config loader",SubContent="Failed to load: "..err,Duration=7}) end
        self.Library:Notify({Title="Interface",Content="Config loader",SubContent=string.format("Auto loaded %q",name),Duration=7})
    end
end

-- ================================================================================
--  CLOUD CONFIG API
-- ================================================================================
function SaveManager:SaveCloud(name, author, description, gameName)
    if not name or name:gsub(" ","")=="" then return false,"invalid name" end
    local data={
        metadata = {
            name = name,
            author = (author and author ~= "") and author or "Anonymous",
            description = (description and description ~= "") and description or "No description",
            game = (gameName and gameName ~= "") and gameName or "Unknown Game",
            placeId = game.PlaceId
        },
        objects = {}
    }
    for idx,opt in next,SaveManager.Options do
        if self.Parser[opt.Type] and not self.Ignore[idx] then
            table.insert(data.objects, self.Parser[opt.Type].Save(idx,opt))
        end
    end
    local ok,enc=pcall(httpService.JSONEncode,httpService,data)
    if not ok then return false,"encode failed" end
    
    local folderClean = self.Folder:gsub("[^%a%d]", ""):lower()
    local bucket = folderClean ~= "" and ("aurora_" .. folderClean) or ("auroracfg" .. tostring(game.PlaceId))
    bucket = string.sub(bucket, 1, 32)
    local url = "https://kvdb.io/" .. bucket .. "/" .. name
    
    local req = request or http_request or (syn and syn.request) or (http and http.request)
    if not req then return false,"executor HTTP request function not supported" end
    
    local reqOk, res = pcall(function()
        return req({
            Url = url,
            Method = "POST",
            Headers = { ["Content-Type"] = "application/json" },
            Body = enc
        })
    end)
    if reqOk and res and (res.StatusCode == 200 or res.StatusCode == 201) then
        return true
    else
        local errDetail = (res and res.StatusCode) and ("status " .. tostring(res.StatusCode)) or "request failed"
        return false, errDetail
    end
end

-- Load from cloud
function SaveManager:LoadCloud(name)
    if not name or name == "" then return false,"no config selected" end
    local folderClean = self.Folder:gsub("[^%a%d]", ""):lower()
    local bucket = folderClean ~= "" and ("aurora_" .. folderClean) or ("auroracfg" .. tostring(game.PlaceId))
    bucket = string.sub(bucket, 1, 32)
    local url = "https://kvdb.io/" .. bucket .. "/" .. name
    
    local req = request or http_request or (syn and syn.request) or (http and http.request)
    local reqOk, res
    if req then
        reqOk, res = pcall(function()
            return req({ Url = url, Method = "GET" })
        end)
    else
        reqOk, res = pcall(function()
            return { StatusCode = 200, Body = game:HttpGet(url, true) }
        end)
    end
    
    if reqOk and res and res.StatusCode == 200 then
        local ok, dec = pcall(httpService.JSONDecode, httpService, res.Body)
        if not ok then return false, "decode error" end
        
        local objects = dec.objects or dec
        if not objects or type(objects) ~= "table" then return false, "invalid format" end
        
        for _, opt in next, objects do
            if self.Parser[opt.type] then
                task.spawn(function() self.Parser[opt.type].Load(opt.idx, opt) end)
            end
        end
        return true
    else
        return false, "config not found or HTTP error"
    end
end

-- Refresh cloud configs
function SaveManager:RefreshCloudConfigList()
    local folderClean = self.Folder:gsub("[^%a%d]", ""):lower()
    local bucket = folderClean ~= "" and ("aurora_" .. folderClean) or ("auroracfg" .. tostring(game.PlaceId))
    bucket = string.sub(bucket, 1, 32)
    local url = "https://kvdb.io/" .. bucket .. "/"
    
    local req = request or http_request or (syn and syn.request) or (http and http.request)
    local reqOk, res
    if req then
        reqOk, res = pcall(function()
            return req({ Url = url, Method = "GET" })
        end)
    else
        reqOk, res = pcall(function()
            return { StatusCode = 200, Body = game:HttpGet(url, true) }
        end)
    end
    
    local list = {}
    if reqOk and res and res.StatusCode == 200 then
        local body = res.Body
        for line in body:gmatch("[^\r\n]+") do
            local name = line:gsub("%s+", "")
            if name ~= "" then
                table.insert(list, name)
            end
        end
    end
    return list
end

function SaveManager:BuildConfigSection(sec)
    assert(self.Library, "Must set SaveManager.Library")
    
    local nameInput = sec:AddInput("SaveManager_ConfigName", {Title="Config name", Icon="solar/pen-new-round-bold"})
    local configDropdown = sec:AddDropdown("SaveManager_ConfigList", {Title="Local config list", Values=self:RefreshConfigList(), Icon="solar/list-bold"})
    
    sec:AddButton({Title="Create local config", Icon="solar/diskette-bold", Callback=function()
        local name = nameInput.Value
        if name:gsub(" ", "") == "" then
            return self.Library:Notify({Title="Interface", Content="Config loader", SubContent="Invalid name", Duration=7})
        end
        local ok, err = self:Save(name)
        if not ok then
            return self.Library:Notify({Title="Interface", Content="Config loader", SubContent="Failed: " .. err, Duration=7})
        end
        self.Library:Notify({Title="Interface", Content="Config loader", SubContent=string.format("Created local %q", name), Duration=7})
        configDropdown:Refresh(self:RefreshConfigList())
        configDropdown:SetValue(nil)
    end})
    
    sec:AddButton({Title="Load local config", Icon="solar/upload-minimalistic-bold", Callback=function()
        local name = configDropdown.Value
        local ok, err = self:Load(name)
        if not ok then
            return self.Library:Notify({Title="Interface", Content="Config loader", SubContent="Failed: " .. err, Duration=7})
        end
        self.Library:Notify({Title="Interface", Content="Config loader", SubContent=string.format("Loaded local %q", name), Duration=7})
    end})
    
    sec:AddButton({Title="Overwrite local config", Icon="solar/refresh-bold", Callback=function()
        local name = configDropdown.Value
        local ok, err = self:Save(name)
        if not ok then
            return self.Library:Notify({Title="Interface", Content="Config loader", SubContent="Failed: " .. err, Duration=7})
        end
        self.Library:Notify({Title="Interface", Content="Config loader", SubContent=string.format("Overwrote local %q", name), Duration=7})
    end})
    
    sec:AddButton({Title="Refresh local list", Icon="solar/restart-bold", Callback=function()
        configDropdown:Refresh(self:RefreshConfigList())
        configDropdown:SetValue(nil)
    end})
    
    local autoBtn, _autoPath = nil, self.Folder .. "/settings/" .. tostring(game.PlaceId) .. "/autoload.txt"
    autoBtn = sec:AddButton({Title="Set as autoload", Icon="solar/star-bold", Description="Current autoload: none", Callback=function()
        local name = configDropdown.Value
        if isfile(_autoPath) and readfile(_autoPath) == name then
            delfile(_autoPath)
            autoBtn:SetDesc("Current autoload: none")
            self.Library:Notify({Title="Interface", Content="Config loader", SubContent="Autoload disabled", Duration=7})
        else
            if not name or name == "" then
                return self.Library:Notify({Title="Interface", Content="Config loader", SubContent="No config selected", Duration=7})
            end
            writefile(_autoPath, name)
            autoBtn:SetDesc("Current autoload: " .. name)
            self.Library:Notify({Title="Interface", Content="Config loader", SubContent=string.format("Set %q to autoload", name), Duration=7})
        end
    end})
    
    if isfile(_autoPath) then
        autoBtn:SetDesc("Current autoload: " .. readfile(_autoPath))
    end

    sec:AddToggle("SaveManager_Autosave", {
        Title = "Auto-save on change",
        Default = false,
        Callback = function(v)
            self.Autosave = v
        end
    })

    sec:AddSeparator("Cloud configs")
    
    local cloudInfo = sec:AddParagraph({Title = "Cloud Config Info", Content = "Select a config to view details"})
    local cloudDropdown
    
    cloudDropdown = sec:AddDropdown("SaveManager_CloudConfigList", {
        Title = "Cloud config list",
        Values = self:RefreshCloudConfigList(),
        Icon = "solar/global-bold",
        Callback = function(val)
            if not val or val == "" then
                cloudInfo:SetTitle("Cloud Config Info")
                cloudInfo:SetContent("Select a config to view details")
                self.SelectedCloudData = nil
                return
            end
            task.spawn(function()
                cloudInfo:SetTitle("Fetching details...")
                cloudInfo:SetContent("Downloading configuration metadata from the cloud...")
                
                local folderClean = self.Folder:gsub("[^%a%d]", ""):lower()
                local bucket = folderClean ~= "" and ("aurora_" .. folderClean) or ("auroracfg" .. tostring(game.PlaceId))
                bucket = string.sub(bucket, 1, 32)
                local url = "https://kvdb.io/" .. bucket .. "/" .. val
                
                local req = request or http_request or (syn and syn.request) or (http and http.request)
                local reqOk, res
                if req then
                    reqOk, res = pcall(function()
                        return req({ Url = url, Method = "GET" })
                    end)
                else
                    reqOk, res = pcall(function()
                        return { StatusCode = 200, Body = game:HttpGet(url, true) }
                    end)
                end
                
                if reqOk and res and res.StatusCode == 200 then
                    local ok, dec = pcall(httpService.JSONDecode, httpService, res.Body)
                    if ok and type(dec) == "table" then
                        self.SelectedCloudData = dec
                        local meta = dec.metadata or {
                            name = val,
                            author = "Legacy",
                            description = "No description (Legacy format)",
                            game = "Unknown"
                        }
                        cloudInfo:SetTitle(meta.name or val)
                        cloudInfo:SetContent(string.format("Author: %s\nGame: %s\nDescription: %s", meta.author or "Anonymous", meta.game or "Unknown", meta.description or "No description"))
                    else
                        cloudInfo:SetTitle("Error")
                        cloudInfo:SetContent("Failed to parse config JSON.")
                        self.SelectedCloudData = nil
                    end
                else
                    cloudInfo:SetTitle("Error")
                    cloudInfo:SetContent("Failed to fetch config details.")
                    self.SelectedCloudData = nil
                end
            end)
        end
    })
    
    local defaultGameName = "Roblox Game"
    pcall(function()
        defaultGameName = game:GetService("MarketplaceService"):GetProductInfo(game.PlaceId).Name
    end)
    
    local cloudNameInput = sec:AddInput("SaveManager_CloudName", {Title="Upload Config Name", Icon="solar/pen-new-round-bold"})
    local cloudAuthorInput = sec:AddInput("SaveManager_CloudAuthor", {Title="Upload Creator/Author", Icon="solar/user-bold", Default=game.Players.LocalPlayer.Name})
    local cloudGameInput = sec:AddInput("SaveManager_CloudGame", {Title="Upload Game Name", Icon="solar/gamepad-bold", Default=defaultGameName})
    local cloudDescInput = sec:AddInput("SaveManager_CloudDesc", {Title="Upload Description", Icon="solar/document-text-bold"})
    
    sec:AddButton({Title="Upload to cloud", Icon="solar/upload-bold", Callback=function()
        local name = cloudNameInput.Value
        if name:gsub(" ", "") == "" then
            return self.Library:Notify({Title="Interface", Content="Config loader", SubContent="Enter an upload config name first", Duration=7})
        end
        local author = cloudAuthorInput.Value
        local gameName = cloudGameInput.Value
        local desc = cloudDescInput.Value
        
        local ok, err = self:SaveCloud(name, author, desc, gameName)
        if not ok then
            return self.Library:Notify({Title="Interface", Content="Config loader", SubContent="Failed to upload: " .. tostring(err), Duration=7})
        end
        self.Library:Notify({Title="Interface", Content="Config loader", SubContent=string.format("Uploaded %q to cloud", name), Duration=7})
        cloudDropdown:Refresh(self:RefreshCloudConfigList())
        cloudDropdown:SetValue(nil)
    end})
    
    sec:AddButton({Title="Load from cloud", Icon="solar/download-bold", Callback=function()
        local name = cloudDropdown.Value
        if not name or name == "" then
            return self.Library:Notify({Title="Interface", Content="Config loader", SubContent="Select a cloud config first", Duration=7})
        end
        
        local data = self.SelectedCloudData
        if data and data.objects then
            for _, opt in next, data.objects do
                if self.Parser[opt.type] then
                    task.spawn(function() self.Parser[opt.type].Load(opt.idx, opt) end)
                end
            end
            self.Library:Notify({Title="Interface", Content="Config loader", SubContent=string.format("Loaded cloud %q", name), Duration=7})
        else
            local ok, err = self:LoadCloud(name)
            if not ok then
                return self.Library:Notify({Title="Interface", Content="Config loader", SubContent="Failed to load: " .. tostring(err), Duration=7})
            end
            self.Library:Notify({Title="Interface", Content="Config loader", SubContent=string.format("Loaded cloud %q", name), Duration=7})
        end
    end})
    
    sec:AddButton({Title="Refresh cloud list", Icon="solar/restart-bold", Callback=function()
        cloudDropdown:Refresh(self:RefreshCloudConfigList())
        cloudDropdown:SetValue(nil)
    end})

    sec:AddSeparator("Clipboard configs")
    
    sec:AddButton({Title="Export to clipboard", Icon="solar/copy-linear", Callback=function()
        local data = { objects = {} }
        for idx, opt in next, SaveManager.Options do
            if self.Parser[opt.Type] and not self.Ignore[idx] then
                table.insert(data.objects, self.Parser[opt.Type].Save(idx, opt))
            end
        end
        local ok, enc = pcall(httpService.JSONEncode, httpService, data)
        if ok then
            pcall(function() toclipboard(enc) end)
            self.Library:Notify({Title="Interface", Content="Config loader", SubContent="Config JSON copied to clipboard", Duration=5})
        else
            self.Library:Notify({Title="Interface", Content="Config loader", SubContent="Failed to encode config", Duration=5})
        end
    end})
    
    sec:AddButton({Title="Import from clipboard", Icon="solar/import-bold", Callback=function()
        local success, clipboard = pcall(function()
            local getClipboard = getclipboard or get_clipboard or function() return "" end
            return getClipboard()
        end)
        if not success or not clipboard or clipboard == "" then
            return self.Library:Notify({Title="Interface", Content="Config loader", SubContent="Clipboard is empty or inaccessible", Duration=5})
        end
        local ok, dec = pcall(httpService.JSONDecode, httpService, clipboard)
        if not ok or not dec or not dec.objects then
            return self.Library:Notify({Title="Interface", Content="Config loader", SubContent="Invalid config in clipboard", Duration=5})
        end
        for _, opt in next, dec.objects do
            if self.Parser[opt.type] then
                task.spawn(function() self.Parser[opt.type].Load(opt.idx, opt) end)
            end
        end
        self.Library:Notify({Title="Interface", Content="Config loader", SubContent="Successfully imported from clipboard", Duration=5})
    end})
    
    SaveManager:SetIgnoreIndexes({
        "SaveManager_ConfigList",
        "SaveManager_ConfigName",
        "SaveManager_Autosave",
        "SaveManager_CloudConfigList",
        "SaveManager_CloudName",
        "SaveManager_CloudAuthor",
        "SaveManager_CloudGame",
        "SaveManager_CloudDesc"
    })
end

-- ================================================================================
--  KEY SYSTEM
-- ================================================================================
local KeySystem = {}
KeySystem.__index = KeySystem

function KeySystem.new(cfg)
    cfg = cfg or {}
    local self = setmetatable({}, KeySystem)
    self.Title = cfg.Title or "Key System"
    self.SubTitle = cfg.SubTitle or "Verification Required"
    self.Note = cfg.Note or "Please enter your access key below."
    self.Keys = cfg.Keys or {}
    self.KeyLink = cfg.KeyLink or ""
    self.SaveKey = cfg.SaveKey ~= false
    self.FileName = cfg.FileName or "AuroraKey.txt"
    self.OnSuccess = cfg.OnSuccess or function() end
    self.CustomValidate = cfg.CustomValidate -- optional function(key) -> bool
    
    local isfile = isfile or function() return false end
    local readfile = readfile or function() return "" end
    local writefile = writefile or function() end

    -- Check if key matches local list or custom validation function
    local function validateKey(key)
        if self.CustomValidate then
            local ok, res = pcall(self.CustomValidate, key)
            if ok and res then return true end
        end
        for _, k in ipairs(self.Keys) do
            if k == key then return true end
        end
        return false
    end
    
    -- Auto-validation
    if self.SaveKey and isfile(self.FileName) then
        local cachedKey = readfile(self.FileName)
        if validateKey(cachedKey) then
            task.spawn(self.OnSuccess)
            return self
        end
    end
    
    -- Create prompt UI
    local thm = Aurora.Theme or Aurora.Themes.Dark
    local keyGui = make("ScreenGui", { Name = "AuroraKeySystem", ResetOnSpawn = false, DisplayOrder = 100000 })
    safeParent(keyGui)
    
    local mainFrame = make("Frame", {
        Size = UDim2.fromOffset(s(380), s(280)),
        Position = UDim2.fromScale(0.5, 0.5),
        AnchorPoint = Vector2.new(0.5, 0.5),
        BackgroundColor3 = thm.Background,
        BackgroundTransparency = 0.05,
        Parent = keyGui
    })
    createAcrylic(mainFrame)
    make("UICorner", { CornerRadius = sz(16), Parent = mainFrame })
    local mainStroke = make("UIStroke", { Color = thm.Border, Thickness = 1, Parent = mainFrame })
    
    -- Dragging support for KeySystem main frame
    local dragInput, dragStart, startPos
    mainFrame.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
            dragStart = input.Position
            startPos = mainFrame.Position
            input.Changed:Connect(function()
                if input.UserInputState == Enum.UserInputState.End then
                    dragStart = nil
                end
            end)
        end
    end)
    mainFrame.InputChanged:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch then
            dragInput = input
        end
    end)
    local changedConn = UserInputService.InputChanged:Connect(function(input)
        if input == dragInput and dragStart then
            local delta = input.Position - dragStart
            mainFrame.Position = UDim2.new(startPos.X.Scale, startPos.X.Offset + delta.X, startPos.Y.Scale, startPos.Y.Offset + delta.Y)
        end
    end)
    keyGui.Destroying:Connect(function()
        pcall(function() changedConn:Disconnect() end)
    end)
    
    -- Topbar title/subtitle
    local titleLbl = make("TextLabel", {
        Size = UDim2.new(1, -s(24), 0, s(28)),
        Position = UDim2.new(0, s(12), 0, s(12)),
        BackgroundTransparency = 1,
        Text = self.Title,
        TextColor3 = thm.Text,
        TextSize = fs(18),
        Font = Enum.Font.GothamBold,
        TextXAlignment = Enum.TextXAlignment.Left,
        Parent = mainFrame
    })
    
    local subLbl = make("TextLabel", {
        Size = UDim2.new(1, -s(24), 0, s(18)),
        Position = UDim2.new(0, s(12), 0, s(38)),
        BackgroundTransparency = 1,
        Text = self.SubTitle,
        TextColor3 = thm.SubText,
        TextSize = fs(11),
        Font = Enum.Font.GothamMedium,
        TextXAlignment = Enum.TextXAlignment.Left,
        Parent = mainFrame
    })
    
    -- Divider line
    make("Frame", {
        Size = UDim2.new(1, -s(24), 0, 1),
        Position = UDim2.new(0, s(12), 0, s(64)),
        BackgroundColor3 = thm.Border,
        BorderSizePixel = 0,
        Parent = mainFrame
    })
    
    -- Note/Instructions
    local noteLbl = make("TextLabel", {
        Size = UDim2.new(1, -s(24), 0, s(40)),
        Position = UDim2.new(0, s(12), 0, s(75)),
        BackgroundTransparency = 1,
        Text = self.Note,
        TextColor3 = thm.SubText,
        TextSize = fs(11),
        Font = Enum.Font.Gotham,
        TextXAlignment = Enum.TextXAlignment.Left,
        TextWrapped = true,
        Parent = mainFrame
    })
    
    -- Input field background
    local inputBG = make("Frame", {
        Size = UDim2.new(1, -s(24), 0, s(36)),
        Position = UDim2.new(0, s(12), 0, s(125)),
        BackgroundColor3 = thm.InputBG,
        BorderSizePixel = 0,
        Parent = mainFrame
    })
    make("UICorner", { CornerRadius = sz(12), Parent = inputBG })
    local inputStroke = make("UIStroke", { Color = thm.Border, Thickness = 1, Parent = inputBG })
    
    local textBox = make("TextBox", {
        Size = UDim2.new(1, -s(16), 1, 0),
        Position = UDim2.new(0, s(8), 0, 0),
        BackgroundTransparency = 1,
        Text = "",
        PlaceholderText = "Enter key here...",
        PlaceholderColor3 = thm.SubText,
        TextColor3 = thm.Text,
        TextSize = fs(13),
        Font = Enum.Font.Gotham,
        TextXAlignment = Enum.TextXAlignment.Left,
        Parent = inputBG
    })
    
    -- Button Frame
    local btnFrame = make("Frame", {
        Size = UDim2.new(1, -s(24), 0, s(36)),
        Position = UDim2.new(0, s(12), 0, s(180)),
        BackgroundTransparency = 1,
        Parent = mainFrame
    })
    
    -- Verify Button
    local verifyBtn = make("TextButton", {
        Size = UDim2.new(0.5, -s(6), 1, 0),
        BackgroundColor3 = thm.Accent,
        Text = "Verify Key",
        TextColor3 = thm.Text,
        TextSize = fs(12),
        Font = Enum.Font.GothamBold,
        AutoButtonColor = false,
        Parent = btnFrame
    })
    make("UICorner", { CornerRadius = sz(12), Parent = verifyBtn })
    
    -- Get Key Button (or Copy Link)
    local getBtn = make("TextButton", {
        Size = UDim2.new(0.5, -s(6), 1, 0),
        Position = UDim2.new(0.5, s(6), 0, 0),
        BackgroundColor3 = thm.Element,
        Text = "Get Key",
        TextColor3 = thm.Text,
        TextSize = fs(12),
        Font = Enum.Font.GothamBold,
        AutoButtonColor = false,
        Parent = btnFrame
    })
    make("UICorner", { CornerRadius = sz(12), Parent = getBtn })
    local getStroke = make("UIStroke", { Color = thm.Border, Thickness = 1, Parent = getBtn })
    
    -- Status Label
    local statusLbl = make("TextLabel", {
        Size = UDim2.new(1, -s(24), 0, s(20)),
        Position = UDim2.new(0, s(12), 0, s(230)),
        BackgroundTransparency = 1,
        Text = "",
        TextColor3 = thm.AlertSuccess,
        TextSize = fs(11),
        Font = Enum.Font.GothamMedium,
        TextXAlignment = Enum.TextXAlignment.Center,
        Parent = mainFrame
    })
    
    -- Button Hover effects
    local function addBtnEffect(btn, bgNormal, bgHover)
        btn.MouseEnter:Connect(function()
            tw(btn, { BackgroundColor3 = bgHover }, 0.15)
        end)
        btn.MouseLeave:Connect(function()
            tw(btn, { BackgroundColor3 = bgNormal }, 0.15)
        end)
    end
    addBtnEffect(verifyBtn, thm.Accent, thm.AccentDim)
    addBtnEffect(getBtn, thm.Element, thm.ElementHover)
    
    -- Functionality
    verifyBtn.MouseButton1Click:Connect(function()
        local inputKey = textBox.Text:gsub("%s+", "")
        if inputKey == "" then
            statusLbl.TextColor3 = thm.AlertError
            statusLbl.Text = "Please enter a key!"
            return
        end
        statusLbl.TextColor3 = thm.SubText
        statusLbl.Text = "Verifying..."
        
        task.wait(0.5)
        
        if validateKey(inputKey) then
            statusLbl.TextColor3 = thm.AlertSuccess
            statusLbl.Text = "Key Verified! Loading script..."
            if self.SaveKey and writefile then
                pcall(writefile, self.FileName, inputKey)
            end
            task.wait(0.5)
            tw(mainFrame, { Size = UDim2.fromOffset(0, 0), BackgroundTransparency = 1 }, 0.3)
            task.wait(0.3)
            keyGui:Destroy()
            task.spawn(self.OnSuccess)
        else
            statusLbl.TextColor3 = thm.AlertError
            statusLbl.Text = "Invalid Key! Please try again."
        end
    end)
    
    getBtn.MouseButton1Click:Connect(function()
        if self.KeyLink ~= "" then
            pcall(function()
                local setClipboard = setclipboard or toclipboard or set_clipboard
                if setClipboard then
                    setClipboard(self.KeyLink)
                    statusLbl.TextColor3 = thm.AlertInfo
                    statusLbl.Text = "Key link copied to clipboard!"
                else
                    statusLbl.TextColor3 = thm.AlertError
                    statusLbl.Text = "Clipboard not supported!"
                end
            end)
        else
            statusLbl.TextColor3 = thm.AlertError
            statusLbl.Text = "No key link specified!"
        end
    end)
    
    return self
end

Aurora.KeySystem = KeySystem

-- ================================================================================
--  HUD OVERLAY
-- ================================================================================
local HUD = {}
HUD.__index = HUD

function Aurora:CreateHUD(cfg)
    cfg = cfg or {}
    local self = setmetatable({}, HUD)
    local thm = Aurora.Theme or Aurora.Themes.Dark
    
    local hudGui = make("ScreenGui", { Name = "AuroraHUD", ResetOnSpawn = false, DisplayOrder = 9998 })
    safeParent(hudGui)
    self.Gui = hudGui
    
    local frame = make("Frame", {
        Size = UDim2.fromOffset(s(cfg.Width or 220), 0),
        Position = cfg.Position or UDim2.new(0, s(20), 0, s(20)),
        BackgroundColor3 = thm.Background,
        BackgroundTransparency = 0.1,
        AutomaticSize = Enum.AutomaticSize.Y,
        Parent = hudGui
    })
    createAcrylic(frame)
    make("UICorner", { CornerRadius = sz(12), Parent = frame })
    local stroke = make("UIStroke", { Color = thm.Border, Thickness = 1, Parent = frame })
    self.Frame = frame
    
    -- Dragging
    local dragInput, dragStart, startPos
    frame.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
            dragStart = input.Position
            startPos = frame.Position
            input.Changed:Connect(function()
                if input.UserInputState == Enum.UserInputState.End then
                    dragStart = nil
                end
            end)
        end
    end)
    frame.InputChanged:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch then
            dragInput = input
        end
    end)
    local changedConn = UserInputService.InputChanged:Connect(function(input)
        if input == dragInput and dragStart then
            local delta = input.Position - dragStart
            frame.Position = UDim2.new(startPos.X.Scale, startPos.X.Offset + delta.X, startPos.Y.Scale, startPos.Y.Offset + delta.Y)
        end
    end)
    hudGui.Destroying:Connect(function()
        pcall(function() changedConn:Disconnect() end)
    end)
    
    -- Header
    local title = make("TextLabel", {
        Size = UDim2.new(1, -s(24), 0, s(30)),
        Position = UDim2.new(0, s(12), 0, 0),
        BackgroundTransparency = 1,
        Text = cfg.Title or "Aurora HUD",
        TextColor3 = thm.Text,
        TextSize = fs(13),
        Font = Enum.Font.GothamBold,
        TextXAlignment = Enum.TextXAlignment.Left,
        Parent = frame
    })
    
    local list = make("Frame", {
        Size = UDim2.new(1, -s(24), 0, 0),
        Position = UDim2.new(0, s(12), 0, s(32)),
        BackgroundTransparency = 1,
        AutomaticSize = Enum.AutomaticSize.Y,
        Parent = frame
    })
    make("UIListLayout", { SortOrder = Enum.SortOrder.LayoutOrder, Padding = sz(4), Parent = list })
    make("UIPadding", { PaddingBottom = sz(12), Parent = list })
    
    self.List = list
    self.Items = {}
    
    return self
end

function HUD:SetItem(id, value)
    local thm = Aurora.Theme or Aurora.Themes.Dark
    local item = self.Items[id]
    if not item then
        local container = make("Frame", {
            Size = UDim2.new(1, 0, 0, s(22)),
            BackgroundTransparency = 1,
            Parent = self.List
        })
        
        local label = make("TextLabel", {
            Size = UDim2.new(0.5, 0, 1, 0),
            BackgroundTransparency = 1,
            Text = tostring(id),
            TextColor3 = thm.SubText,
            TextSize = fs(11),
            Font = Enum.Font.GothamMedium,
            TextXAlignment = Enum.TextXAlignment.Left,
            Parent = container
        })
        
        local valLabel = make("TextLabel", {
            Size = UDim2.new(0.5, 0, 1, 0),
            Position = UDim2.new(0.5, 0, 0, 0),
            BackgroundTransparency = 1,
            Text = tostring(value),
            TextColor3 = thm.Text,
            TextSize = fs(11),
            Font = Enum.Font.GothamBold,
            TextXAlignment = Enum.TextXAlignment.Right,
            Parent = container
        })
        
        item = { container = container, label = label, valLabel = valLabel }
        self.Items[id] = item
    else
        item.valLabel.Text = tostring(value)
    end
end

function HUD:Toggle(bool)
    self.Frame.Visible = bool
end

-- ================================================================================
--  PROGRESS BAR ELEMENT
-- ================================================================================
function Section:AddProgressBar(id, cfg)
    cfg = cfg or {}
    local thm = Aurora.Theme or Aurora.Themes.Dark
    local f = elemFrame(self.Container)
    
    local titleLbl = make("TextLabel", {
        Size = UDim2.new(1, 0, 0, s(16)),
        BackgroundTransparency = 1,
        Text = cfg.Title or "Progress Bar",
        TextColor3 = thm.Text,
        TextSize = fs(11),
        Font = Enum.Font.GothamBold,
        TextXAlignment = Enum.TextXAlignment.Left,
        Parent = f
    })
    
    local track = make("Frame", {
        Size = UDim2.new(1, 0, 0, s(8)),
        BackgroundColor3 = thm.InputBG,
        BorderSizePixel = 0,
        Parent = f
    })
    make("UICorner", { CornerRadius = sz(6), Parent = track })
    local stroke = make("UIStroke", { Color = thm.Border, Thickness = 1, Parent = track })
    
    local fill = make("Frame", {
        Size = UDim2.new(0, 0, 1, 0),
        BackgroundColor3 = thm.Accent,
        BorderSizePixel = 0,
        Parent = track
    })
    make("UICorner", { CornerRadius = sz(6), Parent = fill })
    
    local valLbl = make("TextLabel", {
        Size = UDim2.new(1, 0, 0, s(12)),
        BackgroundTransparency = 1,
        Text = "0%",
        TextColor3 = thm.SubText,
        TextSize = fs(9),
        Font = Enum.Font.GothamMedium,
        TextXAlignment = Enum.TextXAlignment.Right,
        Parent = f
    })
    
    local obj = { Type = "ProgressBar", id = id, Value = 0 }
    
    function obj:SetProgress(percent)
        self.Value = math.clamp(percent, 0, 100)
        local formatted = string.format("%d%%", self.Value)
        valLbl.Text = formatted
        tw(fill, { Size = UDim2.fromScale(self.Value / 100, 1) }, 0.25)
    end
    
    function obj:SetValue(v)
        self:SetProgress(v)
    end
    
    function obj:SetTitle(newTitle)
        titleLbl.Text = newTitle
    end
    
    addVisibilityAPI(obj, f)
    Aurora.Options[id] = obj
    return obj
end

SaveManager:BuildFolderTree()
Aurora.SaveManager = SaveManager

return Aurora
