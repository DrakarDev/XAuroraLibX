local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")
local Players = game:GetService("Players")
local CoreGui = game:GetService("CoreGui")
local RunService = game:GetService("RunService")
local SoundService = game:GetService("SoundService")
local LocalPlayer = Players.LocalPlayer
local rgbActive = false
local Aurora = {}
Aurora.__index = Aurora
Aurora.Options = {}
Aurora.ThemeObjs = {}
Aurora._themeObjsByKey = {}
Aurora._activeThemePrivate = false
Aurora.Scale = 1.0
Aurora.LazyLoad = true
Aurora.FadeIn = true
Aurora.DelayPerTab = 0.08
Aurora.DelayPerSection = 0.04
Aurora.DelayPerElement = 0.012
Aurora._globalElements = {}
Aurora._globalElementsByTitle = {}
Aurora.IsPremium = false
Aurora._premiumCount = 0
Aurora._premiumButtons = {}
Aurora._premiumOverlays = {}
Aurora._premiumElements = {}
Aurora.SoundEnabled = true
Aurora.SmoothThemeTransition = true
Aurora.AutoTranslate = true
Aurora._userLocale = nil
Aurora._translations = {}
-- Sonidos centralizados (Creator Store, free-to-use). Cambia cualquiera aqui o con Aurora:SetSound(name,id).
Aurora.Sounds = {
    -- 0 = silencio (sin assets rotos). Pon IDs de sonido VALIDOS con Aurora:SetSound("Click", id).
    Click   = 0,
    Toggle  = 0,
    Open    = 0,
    Close   = 0,
    Hover   = 0,
    Success = 0,
    Error   = 0,
    Warning = 0,
    Info    = 0,
}
Aurora._soundPool = {}
Aurora._soundPoolSize = 4
function Aurora:PlaySound(name, volume)
    if not Aurora.SoundEnabled then return end
    local id = Aurora.Sounds and Aurora.Sounds[name]
    if not id or id == 0 then return end
    local pool = Aurora._soundPool[id]
    if not pool then
        pool = {}
        for i = 1, Aurora._soundPoolSize do
            local snd = Instance.new("Sound")
            snd.SoundId = "rbxassetid://" .. tostring(id)
            snd.Parent = SoundService
            pool[i] = snd
        end
        Aurora._soundPool[id] = pool
    end
    for _, snd in ipairs(pool) do
        if not snd.IsPlaying then
            snd.Volume = volume or 0.35
            snd:Play()
            return
        end
    end
    pool[1].Volume = volume or 0.35
    pool[1]:Play()
end
function Aurora:SetSound(name, id) if Aurora.Sounds then Aurora.Sounds[name] = id end end
-- Auto-ejecucion: escribe el script en la carpeta autoexec del executor para que
-- la GUI se cargue sola al reentrar al juego. Depende del soporte del executor.
function Aurora:SetupAutoExecute(source, name)
    name = name or "AuroraAutoLoad.lua"
    if type(source) ~= "string" then return false, "source debe ser un string (url o codigo)" end
    local content = source
    if source:match("^https?://") then
        content = 'loadstring(game:HttpGet("' .. source .. '"))()'
    end
    local ok = false
    pcall(function()
        if not writefile then return end
        for _, folder in ipairs({ "autoexec", "Autoexec", "auto_exec", "autoexecute" }) do
            local okk = pcall(function()
                if isfolder and makefolder and not isfolder(folder) then makefolder(folder) end
                writefile(folder .. "/" .. name, content)
            end)
            if okk then ok = true break end
        end
        if not ok then pcall(function() writefile(name, content); ok = true end) end
    end)
    return ok
end
function Aurora:RemoveAutoExecute(name)
    name = name or "AuroraAutoLoad.lua"
    pcall(function()
        for _, folder in ipairs({ "autoexec", "Autoexec", "auto_exec", "autoexecute" }) do
            pcall(function() if delfile and isfile and isfile(folder.."/"..name) then delfile(folder.."/"..name) end end)
        end
    end)
end
local function isMobileDevice()
    local ok, platform = pcall(function() return UserInputService:GetPlatform() end)
    if ok and (platform == Enum.Platform.Android or platform == Enum.Platform.IOS) then
        return true
    end
    return UserInputService.TouchEnabled
        and (not UserInputService.MouseEnabled or not UserInputService.KeyboardEnabled)
end
local _isMobile = isMobileDevice()
local SC = 1.0
local function s(n)
    return math.max(1, math.floor(n * SC + 0.5))
end
local function ss(w,h) return UDim2.fromOffset(s(w), s(h)) end
local function sz(n) return UDim.new(0, s(n)) end
local function fs(n) return s(n) * (_isMobile and 0.8464 or 1) end
local _ICON_URLS = {
    solar = "https://cdn.jsdelivr.net/gh/StyearX/Icons@main/solar/dist/Icons.lua",
    lucide = "https://cdn.jsdelivr.net/gh/StyearX/Icons@main/lucide/dist/Icons.lua",
    gravity = "https://cdn.jsdelivr.net/gh/StyearX/Icons@main/gravity/dist/Icons.lua",
    craft = "https://cdn.jsdelivr.net/gh/StyearX/Icons@main/craft/dist/Icons.lua",
    geist = "https://cdn.jsdelivr.net/gh/StyearX/Icons@main/geist/dist/Icons.lua",
    sfsymbols = "https://cdn.jsdelivr.net/gh/StyearX/Icons@main/sfsymbols/dist/Icons.lua",
}
local _ICON_CACHE = {}
local _PACK_STATUS = {}
local _ICON_WAITERS = {}
local function _loadPack(pack)
    if _PACK_STATUS[pack] then return end
    _PACK_STATUS[pack] = "loading"
    task.spawn(function()
        local url = _ICON_URLS[pack] or _ICON_URLS["solar"]
        for attempt = 1, 2 do
            local ok, res = pcall(function() return loadstring(game:HttpGet(url, true))() end)
            if ok and type(res) == "table" then
                _ICON_CACHE[pack] = res
                _PACK_STATUS[pack] = "ready"
                return
            end
            if attempt < 2 then task.wait(2) end
        end
        _PACK_STATUS[pack] = "fail"
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
        local waiters = _ICON_WAITERS[pack]
        if waiters then
            table.insert(waiters, tryApply)
            return
        end
        _ICON_WAITERS[pack] = { tryApply }
        task.spawn(function()
            local wait = 0.05
            local t0 = tick()
            while tick()-t0 < 8 and _PACK_STATUS[pack] ~= "ready" and _PACK_STATUS[pack] ~= "fail" do
                task.wait(wait)
                wait = math.min(wait * 2, 0.8)
            end
            local queued = _ICON_WAITERS[pack]
            _ICON_WAITERS[pack] = nil
            if _PACK_STATUS[pack] == "ready" and queued then
                for _, callback in ipairs(queued) do pcall(callback) end
            end
        end)
    end
end
local function triggerAutosave()
    if Aurora.SaveManager and Aurora.SaveManager.Autosave and Aurora.SaveManager.CurrentConfig then
        pcall(function() Aurora.SaveManager:Save(Aurora.SaveManager.CurrentConfig) end)
    end
    if Aurora._autoPersistHook then pcall(Aurora._autoPersistHook) end
end
local _tweenInfoCache = {}
local function _getTweenInfo(t, style, dir)
    local key = tostring(t).."_"..tostring(style).."_"..tostring(dir)
    if not _tweenInfoCache[key] then
        _tweenInfoCache[key] = TweenInfo.new(t, style, dir)
    end
    return _tweenInfoCache[key]
end

-- FPS-aware tween: reduce duration on low FPS to keep UI responsive
local _fpsSmooth = 60
local _fpsTrackConn
do
    local ok, conn = pcall(function()
        return RunService.RenderStepped:Connect(function(dt)
            local fps = 1 / math.max(dt, 0.001)
            _fpsSmooth = _fpsSmooth + (fps - _fpsSmooth) * 0.1
        end)
    end)
    if ok then _fpsTrackConn = conn end
end
Aurora._fpsAwareEnabled = true
local function _fpsScale(t)
    if not Aurora._fpsAwareEnabled then return t end
    if _fpsSmooth < 25 then return t * 0.3 end
    if _fpsSmooth < 40 then return t * 0.6 end
    return t
end

local function tw(obj, props, t, style, dir)
    t = t or 0.2; style = style or Enum.EasingStyle.Quad; dir = dir or Enum.EasingDirection.Out
    t = _fpsScale(t)
    local tween = TweenService:Create(obj, _getTweenInfo(t, style, dir), props)
    tween:Play()
    return tween
end

-- Connection cleanup manager
Aurora._connectionBuckets = {}
function Aurora:TrackConnection(bucket, conn)
    if not self._connectionBuckets[bucket] then
        self._connectionBuckets[bucket] = {}
    end
    table.insert(self._connectionBuckets[bucket], conn)
    return conn
end
function Aurora:CleanBucket(bucket)
    local conns = self._connectionBuckets[bucket]
    if not conns then return end
    for i = #conns, 1, -1 do
        pcall(function() conns[i]:Disconnect() end)
        conns[i] = nil
    end
    self._connectionBuckets[bucket] = nil
end
function Aurora:CleanAllConnections()
    for bucket in pairs(self._connectionBuckets) do
        self:CleanBucket(bucket)
    end
end

-- Notification object pool
local _notifPool = {}
local _notifPoolMax = 8
local function _poolPush(frame)
    if #_notifPool >= _notifPoolMax then
        pcall(function() frame:Destroy() end)
        return
    end
    frame.Visible = false
    frame.Parent = nil
    table.insert(_notifPool, frame)
end
local function _poolPop()
    if #_notifPool > 0 then
        local f = table.remove(_notifPool)
        for _, child in ipairs(f:GetChildren()) do
            if not child:IsA("UICorner") and not child:IsA("UIStroke") and not child:IsA("UIPadding") then
                pcall(function() child:Destroy() end)
            end
        end
        f.Visible = true
        return f
    end
    return nil
end

-- Batch theme update queue
local _themeUpdateQueued = false
local _themeUpdateKeys = {}
function Aurora:QueueThemeUpdate(key)
    _themeUpdateKeys[key] = true
    if not _themeUpdateQueued then
        _themeUpdateQueued = true
        task.defer(function()
            _themeUpdateQueued = false
            local keys = _themeUpdateKeys
            _themeUpdateKeys = {}
            self:UpdateTheme(keys)
        end)
    end
end

local _themeBindingIndex = setmetatable({}, { __mode = "k" })
local _autoThemeKeys = {
    BackgroundColor3 = { "Background", "Sidebar", "TopBar", "Element", "ElementHover", "InputBG", "NotifBG", "ToggleOff", "ToggleOn", "SliderTrack", "SliderFill", "Accent", "AccentDim", "Border", "AlertInfo", "AlertWarn", "AlertError", "AlertSuccess" },
    TextColor3 = { "Text", "SubText", "TabActive", "TabInactive", "Accent", "IconColor", "AlertInfo", "AlertWarn", "AlertError", "AlertSuccess" },
    PlaceholderColor3 = { "SubText" },
    ImageColor3 = { "IconColor", "Text", "SubText", "TabActive", "TabInactive", "Accent", "AlertInfo", "AlertWarn", "AlertError", "AlertSuccess" },
    Color = { "Border", "Accent", "Text", "SubText", "AlertInfo", "AlertWarn", "AlertError", "AlertSuccess" },
    ScrollBarImageColor3 = { "Scrollbar", "Border", "Accent" },
}
local function registerThemeBinding(obj, prop, key)
    if not obj or not prop or not key then return nil end
    local bindings = _themeBindingIndex[obj]
    if not bindings then
        bindings = {}
        _themeBindingIndex[obj] = bindings
    end
    local entry = bindings[prop]
    if entry then
        local oldKey = entry.key
        if oldKey ~= key then
            local oldBucket = Aurora._themeObjsByKey[oldKey]
            if oldBucket then
                for i, e in ipairs(oldBucket) do
                    if e == entry then table.remove(oldBucket, i); break end
                end
            end
            entry.key = key
            local bucket = Aurora._themeObjsByKey[key]
            if not bucket then
                bucket = {}
                Aurora._themeObjsByKey[key] = bucket
            end
            table.insert(bucket, entry)
        end
        return entry
    end
    entry = { obj = obj, prop = prop, key = key }
    bindings[prop] = entry
    table.insert(Aurora.ThemeObjs, entry)
    local bucket = Aurora._themeObjsByKey[key]
    if not bucket then
        bucket = {}
        Aurora._themeObjsByKey[key] = bucket
    end
    table.insert(bucket, entry)
    return entry
end
local function inferThemeKey(prop, value)
    local theme = Aurora.Theme
    if not theme or typeof(value) ~= "Color3" then return nil end
    for _, key in ipairs(_autoThemeKeys[prop] or {}) do
        if theme[key] == value then return key end
    end
    for key, themeValue in pairs(theme) do
        if typeof(themeValue) == "Color3" and themeValue == value then return key end
    end
    return nil
end
local function autoRegisterThemeProps(inst, props)
    if not Aurora.Theme or not props then return end
    for prop, value in pairs(props) do
        if _autoThemeKeys[prop] then
            local key = inferThemeKey(prop, value)
            if key then registerThemeBinding(inst, prop, key) end
        end
    end
end
local function make(class, props)
    local ok, inst = pcall(Instance.new, class)
    if not ok and class == "CanvasGroup" then
        Aurora.FadeIn = false
        ok, inst = pcall(Instance.new, "Frame")
    end
    if not ok then inst = Instance.new("Frame") end
    if props then
        for k, v in pairs(props) do
            if k ~= "Parent" then pcall(function() inst[k] = v end) end
        end
        autoRegisterThemeProps(inst, props)
        if props.Parent then inst.Parent = props.Parent end
    end
    return inst
end
local function _registerElement(title, frame, tabRef, subTabRef)
    if not title or title == "" or not frame or not tabRef then return end
    local lowerTitle = title:lower()
    local entry = { title = lowerTitle, displayTitle = title, frame = frame, tab = tabRef, subTab = subTabRef }
    table.insert(Aurora._globalElements, entry)
    local bucket = Aurora._globalElementsByTitle[lowerTitle]
    if not bucket then
        bucket = {}
        Aurora._globalElementsByTitle[lowerTitle] = bucket
    end
    table.insert(bucket, entry)
    frame.Destroying:Connect(function()
        for i, e in ipairs(Aurora._globalElements) do
            if e.frame == frame then table.remove(Aurora._globalElements, i); break end
        end
        local b = Aurora._globalElementsByTitle[lowerTitle]
        if b then
            for i, e in ipairs(b) do
                if e.frame == frame then table.remove(b, i); break end
            end
            if #b == 0 then Aurora._globalElementsByTitle[lowerTitle] = nil end
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
local function fitMobileCard(gui, card, width, height)
    if not isMobileDevice() then return end
    -- Keep viewport fitting separate from the card's entrance animation.
    local holder=make("Frame",{
        Name="MobileCardBounds",Size=UDim2.fromOffset(width,height),
        Position=card.Position,AnchorPoint=card.AnchorPoint,
        BackgroundTransparency=1,ZIndex=card.ZIndex,Parent=gui,
    })
    card.Parent=holder
    card.Position=UDim2.fromScale(0.5,0.5)
    local scale=make("UIScale",{Scale=1,Parent=holder})
    local function update()
        local size=gui.AbsoluteSize
        if size.X<=1 or size.Y<=1 then return end
        scale.Scale=math.min(0.8/SC,size.X*0.86/width,size.Y*0.78/height)
    end
    local connection=gui:GetPropertyChangedSignal("AbsoluteSize"):Connect(update)
    gui.Destroying:Once(function() connection:Disconnect() end)
    update()
    return holder
end
local function addVisibilityAPI(obj, frame)
    if not obj or not frame then return end
    obj.Frame = frame
    obj._connections = obj._connections or {}
    function obj:SetVisible(state)
        frame.Visible = state
    end
    function obj:Destroy()
        for _, conn in ipairs(self._connections) do
            pcall(function() conn:Disconnect() end)
        end
        self._connections = {}
        if self._premiumOverlay then
            pcall(function() self._premiumOverlay:Destroy() end)
        end
        if self._patchedOverlay then
            pcall(function() self._patchedOverlay:Destroy() end)
        end
        if self.id and Aurora.Options[self.id] == self then
            Aurora.Options[self.id] = nil
        end
        pcall(function() frame:Destroy() end)
    end
    function obj:AddConnection(conn)
        table.insert(self._connections, conn)
        return conn
    end
    function obj:SetPatched(state, customText)
        self._isPatched = state and true or false
        if frame then pcall(function() frame:SetAttribute("AuroraPatched", self._isPatched) end) end
        if state then
            if not self._patchedOverlay then
                local overlay = make("TextButton", {
                    Size = UDim2.fromScale(1, 1),
                    Position = UDim2.fromScale(0.5, 0.5),
                    AnchorPoint = Vector2.new(0.5, 0.5),
                    BackgroundColor3 = Color3.fromRGB(12, 12, 15),
                    BackgroundTransparency = 0.42,
                    Text = "",
                    AutoButtonColor = false,
                    Active = true,
                    ZIndex = 50,
                    Parent = frame
                })
                local corner = frame:FindFirstChildOfClass("UICorner")
                make("UICorner", { CornerRadius = corner and corner.CornerRadius or UDim.new(0, 8), Parent = overlay })
                local badge = make("Frame", {
                    AutomaticSize = Enum.AutomaticSize.X,
                    Size = UDim2.new(0, 0, 0, math.floor(20 * SC)),
                    Position = UDim2.fromScale(0.5, 0.5),
                    AnchorPoint = Vector2.new(0.5, 0.5),
                    BackgroundColor3 = Color3.fromRGB(26, 22, 15),
                    BackgroundTransparency = 0.05,
                    ZIndex = 51,
                    Parent = overlay
                })
                make("UICorner", { CornerRadius = UDim.new(1, 0), Parent = badge })
                make("UIStroke", { Color = Color3.fromRGB(238, 168, 82), Thickness = 1, Transparency = 0.35, Parent = badge })
                make("UIPadding", { PaddingLeft = UDim.new(0, math.floor(11 * SC)), PaddingRight = UDim.new(0, math.floor(11 * SC)), Parent = badge })
                local txt = make("TextLabel", {
                    AutomaticSize = Enum.AutomaticSize.X,
                    Size = UDim2.new(0, 0, 1, 0),
                    BackgroundTransparency = 1,
                    Text = customText or "PATCHED",
                    TextColor3 = Color3.fromRGB(238, 168, 82),
                    TextSize = math.floor(11 * SC),
                    Font = Enum.Font.GothamBold,
                    ZIndex = 52,
                    Parent = badge
                })
                self._patchedOverlay = overlay
            else
                self._patchedOverlay.Visible = true
                local txt = self._patchedOverlay:FindFirstChild("TextLabel", true)
                if txt then txt.Text = customText or "PATCHED" end
            end
        else
            if self._patchedOverlay then
                self._patchedOverlay.Visible = false
            end
        end
    end
    -- Premium features remain visible but are blocked until the user upgrades.
    function obj:SetPremium(isRequired, customText)
        if isRequired == false then return end
        if obj._premiumApplied then return end
        obj._premiumApplied = true
        obj.Premium = true
        table.insert(Aurora._premiumElements, obj)
        if Aurora.IsPremium or not frame then return end
        obj._premiumLocked = true
        if type(obj.SetValue) == "function" and not obj._premiumSetValueWrapped then
            obj._premiumSetValueWrapped = true
            local originalSetValue = obj.SetValue
            obj.SetValue = function(self, ...)
                if self._premiumLocked and not Aurora.IsPremium then
                    Aurora:OpenPremiumPrompt(customText or "Premium feature")
                    return self.Value
                end
                return originalSetValue(self, ...)
            end
        end
        Aurora._premiumCount = (Aurora._premiumCount or 0) + 1
        if Aurora._refreshPremiumButtons then pcall(Aurora._refreshPremiumButtons) end
        local currentThm = Aurora.Theme or Aurora.Themes.Dark
        local overlayParent = frame:FindFirstAncestorOfClass("ScreenGui")
        if not overlayParent then return end
        local _goldA = Color3.fromRGB(200, 155, 60)
        local _goldB = Color3.fromRGB(160, 120, 45)
        local overlay = make("TextButton", {
            Size=UDim2.fromOffset(0,0), Position=UDim2.fromOffset(0,0),
            BackgroundColor3=_goldA,
            BackgroundTransparency=1, Text="", AutoButtonColor=false, Active=true,
            ZIndex=100000, Parent=overlayParent,
        })
        local corner = frame:FindFirstChildOfClass("UICorner")
        make("UICorner", { CornerRadius=corner and corner.CornerRadius or sz(9), Parent=overlay })
        make("UIStroke", { Color=_goldA, Thickness=1, Transparency=0.5, Parent=overlay })
        local badge = make("Frame", {
            AutomaticSize=Enum.AutomaticSize.X, Size=UDim2.new(0,0,0,s(20)),
            Position=UDim2.new(1,-s(7),0,s(5)), AnchorPoint=Vector2.new(1,0),
            BackgroundColor3=Color3.fromRGB(35,28,15), BackgroundTransparency=0,
            ZIndex=100001, Parent=overlay,
        })
        make("UICorner", { CornerRadius=UDim.new(1,0), Parent=badge })
        make("UIStroke", { Color=_goldA, Thickness=1.2, Transparency=0.15, Parent=badge })
        make("UIGradient", { Color=ColorSequence.new({
            ColorSequenceKeypoint.new(0, Color3.fromRGB(50,40,18)),
            ColorSequenceKeypoint.new(1, Color3.fromRGB(30,24,12)),
        }), Rotation=90, Parent=badge })
        make("UIPadding", { PaddingLeft=sz(7), PaddingRight=sz(8), Parent=badge })
        make("UIListLayout", { FillDirection=Enum.FillDirection.Horizontal, HorizontalAlignment=Enum.HorizontalAlignment.Center, VerticalAlignment=Enum.VerticalAlignment.Center, Padding=sz(4), Parent=badge })
        local lock = make("ImageLabel", {
            Size=ss(12,12), AnchorPoint=Vector2.new(0,0.5), Position=UDim2.new(0,0,0.5,0),
            BackgroundTransparency=1, ZIndex=100002, Parent=badge,
        })
        applyIcon(lock, "solar/lock-keyhole-bold", Color3.fromRGB(220,175,70))
        make("TextLabel", {
            AutomaticSize=Enum.AutomaticSize.X, Size=UDim2.new(0,0,1,0),
            Position=UDim2.new(0,s(18),0,0), BackgroundTransparency=1,
            Text=customText or "PREMIUM", TextColor3=Color3.fromRGB(220,175,70),
            TextSize=fs(9), Font=Enum.Font.GothamBold, ZIndex=100002, Parent=badge,
        })
        local badgeScale=make("UIScale", {Scale=0.82, Parent=badge})
        tw(badgeScale, {Scale=1}, 0.28, Enum.EasingStyle.Back, Enum.EasingDirection.Out)
        -- shimmer animation on premium badge
        local shimmerFrame = make("Frame", {
            Name="PremiumShimmer", Size=UDim2.new(0.3,0,1,0), Position=UDim2.new(-0.3,0,0,0),
            BackgroundTransparency=1, ZIndex=100003, ClipsDescendants=false, Parent=badge,
        })
        make("UIGradient", {
            Color=ColorSequence.new(Color3.fromRGB(255,230,140)),
            Transparency=NumberSequence.new({
                NumberSequenceKeypoint.new(0,1), NumberSequenceKeypoint.new(0.45,0.5),
                NumberSequenceKeypoint.new(0.55,0.5), NumberSequenceKeypoint.new(1,1),
            }),
            Rotation=75, Parent=shimmerFrame,
        })
        local shimmerTween = TweenService:Create(shimmerFrame,
            TweenInfo.new(1.2, Enum.EasingStyle.Quad, Enum.EasingDirection.InOut, -1, false, 3.5),
            {Position = UDim2.new(1.3, 0, 0, 0)}
        )
        shimmerFrame.Position = UDim2.new(-0.3, 0, 0, 0)
        shimmerTween:Play()
        -- glow frame behind overlay (subtle)
        local premGlow = make("Frame", {
            Name="PremiumGlow", Size=UDim2.new(1,s(4),1,s(4)), AnchorPoint=Vector2.new(0.5,0.5),
            Position=UDim2.fromScale(0.5,0.5), BackgroundColor3=Color3.fromRGB(200,155,60),
            BackgroundTransparency=0.85, BorderSizePixel=0, ZIndex=99999, Parent=overlay,
        })
        local premGlowCorner = overlay:FindFirstChildOfClass("UICorner")
        make("UICorner", {CornerRadius=premGlowCorner and premGlowCorner.CornerRadius or sz(9), Parent=premGlow})
        overlay.MouseEnter:Connect(function() if _isMobile then return end
            tw(overlay,{BackgroundTransparency=0.88},0.14); tw(badgeScale,{Scale=1.08},0.14)
            tw(premGlow,{BackgroundTransparency=0.7},0.14)
        end)
        overlay.MouseLeave:Connect(function() if _isMobile then return end
            tw(overlay,{BackgroundTransparency=1},0.18); tw(badgeScale,{Scale=1},0.18)
            tw(premGlow,{BackgroundTransparency=0.85},0.18)
        end)
        overlay.MouseButton1Click:Connect(function()
            tw(badgeScale,{Scale=0.9},0.08)
            task.delay(0.09,function() if badgeScale and badgeScale.Parent then tw(badgeScale,{Scale=1},0.18,Enum.EasingStyle.Back,Enum.EasingDirection.Out) end end)
            Aurora:OpenPremiumPrompt(customText or "Premium feature")
        end)
        local function syncOverlay()
            if not overlay.Parent or not frame.Parent then return end
            local position, size = frame.AbsolutePosition, frame.AbsoluteSize
            local visible = frame.Visible
            local ancestor = frame.Parent
            while ancestor and ancestor ~= overlayParent do
                if ancestor:IsA("GuiObject") and not ancestor.Visible then
                    visible = false
                    break
                end
                if visible and ancestor:IsA("ScrollingFrame") then
                    local sp = ancestor.AbsolutePosition
                    local ss2 = ancestor.AbsoluteSize
                    local frameBottom = position.Y + size.Y
                    local frameRight = position.X + size.X
                    if position.Y + size.Y * 0.5 < sp.Y or position.Y + size.Y * 0.5 > sp.Y + ss2.Y
                        or position.X + size.X * 0.5 < sp.X or position.X + size.X * 0.5 > sp.X + ss2.X then
                        visible = false
                    end
                    if visible then
                        local clampX = math.max(position.X, sp.X)
                        local clampY = math.max(position.Y, sp.Y)
                        local clampR = math.min(frameRight, sp.X + ss2.X)
                        local clampB = math.min(frameBottom, sp.Y + ss2.Y)
                        if clampR > clampX and clampB > clampY then
                            position = Vector2.new(clampX, clampY)
                            size = Vector2.new(clampR - clampX, clampB - clampY)
                        else
                            visible = false
                        end
                    end
                end
                ancestor = ancestor.Parent
            end
            if not overlayParent.Enabled then visible = false end
            overlay.Position = UDim2.fromOffset(position.X, position.Y)
            overlay.Size = UDim2.fromOffset(size.X, size.Y)
            overlay.Visible = visible and size.X > 0 and size.Y > 0
        end
        local premiumEntry = {Gui=overlay, Sync=syncOverlay}
        table.insert(Aurora._premiumOverlays, premiumEntry)
        local overlayConnections = {
            frame:GetPropertyChangedSignal("AbsolutePosition"):Connect(syncOverlay),
            frame:GetPropertyChangedSignal("AbsoluteSize"):Connect(syncOverlay),
            frame:GetPropertyChangedSignal("Visible"):Connect(syncOverlay),
            overlayParent:GetPropertyChangedSignal("Enabled"):Connect(syncOverlay),
        }
        local ancestor = frame.Parent
        while ancestor and ancestor ~= overlayParent do
            if ancestor:IsA("GuiObject") then
                table.insert(overlayConnections, ancestor:GetPropertyChangedSignal("Visible"):Connect(syncOverlay))
            end
            ancestor = ancestor.Parent
        end
        frame.Destroying:Connect(function()
            for _, connection in ipairs(overlayConnections) do pcall(function() connection:Disconnect() end) end
            local index = table.find(Aurora._premiumOverlays, premiumEntry)
            if index then table.remove(Aurora._premiumOverlays, index) end
            pcall(function() overlay:Destroy() end)
        end)
        task.defer(syncOverlay)
        obj._premiumOverlay=overlay
    end
    -- Advertencia: borde ambar + icono con tooltip. :SetWarning(nil/false) la quita.
    function obj:SetWarning(text)
        if not frame then return end
        if text == nil or text == false then
            if obj._warnStroke then obj._warnStroke.Enabled = false end
            if obj._warnIco then obj._warnIco.Visible = false end
            return
        end
        local _AMBER = Color3.fromRGB(240, 185, 70)
        if not obj._warnStroke then
            obj._warnStroke = make("UIStroke", { Color = _AMBER, Thickness = 1.5, Transparency = 0.2, Parent = frame })
        else obj._warnStroke.Enabled = true end
        if not obj._warnIco then
            local _wi = math.floor(14 * (SC or 1))
            local ico = make("ImageLabel", {
                Size = UDim2.fromOffset(_wi, _wi), AnchorPoint = Vector2.new(1, 0),
                Position = UDim2.new(1, -math.floor(6 * (SC or 1)), 0, math.floor(4 * (SC or 1))),
                BackgroundTransparency = 1, ZIndex = 30, Parent = frame,
            })
            pcall(function() applyIcon(ico, "solar/danger-triangle-bold", _AMBER) end)
            obj._warnIco = ico
            if Aurora._addTooltip then pcall(Aurora._addTooltip, ico, tostring(text)) end
        else obj._warnIco.Visible = true end
        obj._warnText = tostring(text)
    end
end
local function applyPremiumConfig(obj, cfg)
    if obj and type(cfg) == "table" and cfg.Premium then
        obj:SetPremium(true, cfg.PremiumText or cfg.PremiumLabel)
    end
end
local function reg(obj, prop, key)
    registerThemeBinding(obj, prop, key)
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
local _tooltipActive = false
local _tooltipConn = nil
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
    local mouse = LocalPlayer:GetMouse()
    _tooltipConn = RunService.RenderStepped:Connect(function()
        if _tooltipActive and _tooltipFrame.Visible then
            _tooltipFrame.Position = UDim2.new(0, mouse.X + 15, 0, mouse.Y + 15)
        end
    end)
end
local function addTooltip(frame, text)
    if not text or text == "" then return end
    _initTooltip()
    frame.MouseEnter:Connect(function() if _isMobile then return end
        _tooltipLbl.Text = text
        _tooltipFrame.Visible = true
        _tooltipActive = true
        _tooltipFrame.BackgroundTransparency = 1
        _tooltipLbl.TextTransparency = 1
        _tooltipStroke.Transparency = 1
        tw(_tooltipFrame, { BackgroundTransparency = 0.1 }, 0.15)
        tw(_tooltipLbl, { TextTransparency = 0 }, 0.15)
        tw(_tooltipStroke, { Transparency = 0 }, 0.15)
    end)
    frame.MouseLeave:Connect(function() if _isMobile then return end
        _tooltipActive = false
        _tooltipFrame.Visible = false
    end)
end
Aurora._addTooltip = addTooltip
function Aurora:OpenPremiumPrompt(feature)
    if Aurora.IsPremium then return end
    if type(self.PremiumCallback) == "function" then
        return pcall(self.PremiumCallback, feature or "Premium feature")
    end
    local link = self.PremiumLink or ""
    if Aurora._premiumPromptActive then
        self:Notify({Title="Premium Required", Content=(feature or "This feature") .. " requires Premium.", Type="Warning", Duration=3})
        return
    end
    Aurora._premiumPromptActive = true
    local thm = Aurora.Theme or Aurora.Themes.Dark
    local _gold = Color3.fromRGB(220,175,70)
    local _goldDark = Color3.fromRGB(35,28,12)
    local screenGui = Instance.new("ScreenGui")
    screenGui.Name = "AuroraPremiumPrompt"
    screenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
    screenGui.DisplayOrder = 999
    pcall(function() screenGui.Parent = CoreGui end)
    if not screenGui.Parent then screenGui.Parent = LocalPlayer:FindFirstChildOfClass("PlayerGui") end
    local bg = make("TextButton", {
        Size=UDim2.fromScale(1,1), BackgroundColor3=Color3.new(0,0,0),
        BackgroundTransparency=1, Text="", AutoButtonColor=false, ZIndex=1, Parent=screenGui,
    })
    tw(bg, {BackgroundTransparency=0.45}, 0.3)
    local card = make("Frame", {
        Size=UDim2.fromOffset(s(280),s(200)), AnchorPoint=Vector2.new(0.5,0.5),
        Position=UDim2.fromScale(0.5,0.5), BackgroundColor3=_goldDark,
        ZIndex=2, Parent=screenGui,
    })
    make("UICorner", {CornerRadius=sz(14), Parent=card})
    make("UIStroke", {Color=_gold, Thickness=1.5, Transparency=0.2, Parent=card})
    make("UIGradient", {Color=ColorSequence.new({
        ColorSequenceKeypoint.new(0, Color3.fromRGB(45,36,16)),
        ColorSequenceKeypoint.new(1, Color3.fromRGB(25,20,10)),
    }), Rotation=90, Parent=card})
    local cardScale = make("UIScale", {Scale=0.7, Parent=card})
    tw(cardScale, {Scale=1}, 0.35, Enum.EasingStyle.Back, Enum.EasingDirection.Out)
    local crownIco = make("ImageLabel", {
        Size=ss(36,36), AnchorPoint=Vector2.new(0.5,0), Position=UDim2.new(0.5,0,0,s(18)),
        BackgroundTransparency=1, ZIndex=3, Parent=card,
    })
    applyIcon(crownIco, "solar/crown-bold", _gold)
    make("TextLabel", {
        Size=UDim2.new(1,-s(20),0,s(22)), Position=UDim2.new(0,s(10),0,s(60)),
        BackgroundTransparency=1, Text="Premium Required",
        TextColor3=_gold, TextSize=fs(16), Font=Enum.Font.GothamBold,
        ZIndex=3, Parent=card,
    })
    make("TextLabel", {
        Size=UDim2.new(1,-s(30),0,s(36)), Position=UDim2.new(0,s(15),0,s(86)),
        BackgroundTransparency=1, TextWrapped=true,
        Text=(feature or "This feature") .. " requires a Premium key.\nGet one from our Discord!",
        TextColor3=Color3.fromRGB(180,160,110), TextSize=fs(11), Font=Enum.Font.Gotham,
        ZIndex=3, Parent=card,
    })
    local closeBtn = make("TextButton", {
        Size=UDim2.new(0.45,0,0,s(32)), AnchorPoint=Vector2.new(0,0),
        Position=UDim2.new(0.03,s(8),1,-s(48)), BackgroundColor3=thm.Element or Color3.fromRGB(50,50,50),
        AutoButtonColor=false, Text="Close", TextColor3=Color3.fromRGB(180,170,140),
        TextSize=fs(11), Font=Enum.Font.GothamBold, ZIndex=3, Parent=card,
    })
    make("UICorner", {CornerRadius=sz(8), Parent=closeBtn})
    local copyBtn = make("TextButton", {
        Size=UDim2.new(0.45,0,0,s(32)), AnchorPoint=Vector2.new(1,0),
        Position=UDim2.new(0.97,-s(8),1,-s(48)), BackgroundColor3=Color3.fromRGB(180,140,50),
        AutoButtonColor=false, Text=(link ~= "" and "Copy Link" or "OK"), TextColor3=Color3.fromRGB(30,24,10),
        TextSize=fs(11), Font=Enum.Font.GothamBold, ZIndex=3, Parent=card,
    })
    make("UICorner", {CornerRadius=sz(8), Parent=copyBtn})
    make("UIGradient", {Color=ColorSequence.new({
        ColorSequenceKeypoint.new(0, Color3.fromRGB(220,180,80)),
        ColorSequenceKeypoint.new(1, Color3.fromRGB(170,130,45)),
    }), Rotation=90, Parent=copyBtn})
    local function closePrompt()
        Aurora._premiumPromptActive = false
        tw(cardScale, {Scale=0.7}, 0.2)
        tw(bg, {BackgroundTransparency=1}, 0.2)
        tw(card, {BackgroundTransparency=1}, 0.2)
        task.delay(0.25, function() pcall(function() screenGui:Destroy() end) end)
    end
    closeBtn.MouseButton1Click:Connect(closePrompt)
    bg.MouseButton1Click:Connect(closePrompt)
    copyBtn.MouseButton1Click:Connect(function()
        if link ~= "" then
            pcall(function() local sc = setclipboard or toclipboard or set_clipboard; if sc then sc(link) end end)
            pcall(function() copyBtn.Text = "Copied!" end)
            task.delay(1, closePrompt)
        else
            closePrompt()
        end
    end)
    task.delay(12, function() if screenGui and screenGui.Parent then closePrompt() end end)
end
function Aurora:UnlockPremium()
    if Aurora._premiumUnlocking then return end
    Aurora._premiumUnlocking = true
    Aurora.IsPremium = true
    Aurora._premiumPromptActive = false
    Aurora.KeySystem = Aurora.KeySystem or {}
    Aurora.KeySystem.Tier = "premium"
    pcall(function() getgenv().SyneroxTier = "premium" end)
    pcall(function()
        local pg = CoreGui:FindFirstChild("AuroraPremiumPrompt")
        if pg then pg:Destroy() end
    end)
    pcall(function()
        local pg2 = LocalPlayer:FindFirstChildOfClass("PlayerGui") and LocalPlayer.PlayerGui:FindFirstChild("AuroraPremiumPrompt")
        if pg2 then pg2:Destroy() end
    end)

    -- ══════════════════════════════════════════════
    -- PREMIUM CELEBRATION ANIMATION
    -- ══════════════════════════════════════════════
    pcall(function()
        local celebGui = make("ScreenGui", { Name="AuroraPremiumCelebration", ResetOnSpawn=false, DisplayOrder=100010 })
        safeParent(celebGui)

        local _GOLD = Color3.fromRGB(255, 200, 60)
        local _GOLD_DARK = Color3.fromRGB(180, 140, 40)
        local _GOLD_LIGHT = Color3.fromRGB(255, 230, 140)

        -- dim flash
        local flash = make("Frame", {
            Size=UDim2.fromScale(1,1), BackgroundColor3=_GOLD,
            BackgroundTransparency=1, BorderSizePixel=0, ZIndex=1, Parent=celebGui,
        })
        tw(flash, {BackgroundTransparency=0.75}, 0.15)
        task.delay(0.2, function() tw(flash, {BackgroundTransparency=1}, 0.8) end)

        -- particle burst (floating golden dots)
        local particleHolder = make("Frame", {
            Size=UDim2.fromScale(1,1), BackgroundTransparency=1, ZIndex=2, Parent=celebGui,
        })
        local rng = Random.new()
        for i = 1, 24 do
            local px = rng:NextNumber(0.1, 0.9)
            local py = rng:NextNumber(0.2, 0.8)
            local sz_p = rng:NextInteger(4, 10)
            local particle = make("Frame", {
                Size=UDim2.fromOffset(s(sz_p), s(sz_p)),
                Position=UDim2.fromScale(0.5, 0.5),
                AnchorPoint=Vector2.new(0.5, 0.5),
                BackgroundColor3 = i % 3 == 0 and _GOLD_LIGHT or (i % 3 == 1 and _GOLD or _GOLD_DARK),
                BackgroundTransparency=0, BorderSizePixel=0, ZIndex=3, Parent=particleHolder,
            })
            make("UICorner", {CornerRadius=UDim.new(1,0), Parent=particle})
            local dur = rng:NextNumber(0.6, 1.4)
            tw(particle, {
                Position=UDim2.fromScale(px, py),
                Size=UDim2.fromOffset(s(sz_p * 0.3), s(sz_p * 0.3)),
                BackgroundTransparency=1,
                Rotation=rng:NextNumber(-180, 180),
            }, dur, Enum.EasingStyle.Quint, Enum.EasingDirection.Out)
        end

        -- center card
        local card = make("Frame", {
            Size=UDim2.fromOffset(s(300), s(200)), AnchorPoint=Vector2.new(0.5,0.5),
            Position=UDim2.fromScale(0.5, 0.5), BackgroundColor3=Color3.fromRGB(20, 16, 8),
            BackgroundTransparency=0, BorderSizePixel=0, ZIndex=10, Parent=celebGui,
        })
        make("UICorner", {CornerRadius=sz(18), Parent=card})
        local cardStroke = make("UIStroke", {Color=_GOLD, Thickness=2, Transparency=0, Parent=card})
        make("UIGradient", {Color=ColorSequence.new({
            ColorSequenceKeypoint.new(0, Color3.fromRGB(35, 28, 12)),
            ColorSequenceKeypoint.new(0.5, Color3.fromRGB(50, 40, 18)),
            ColorSequenceKeypoint.new(1, Color3.fromRGB(30, 24, 10)),
        }), Rotation=135, Parent=card})
        local cardScale = make("UIScale", {Scale=0.5, Parent=card})
        fitMobileCard(celebGui,card,s(300),s(200))
        tw(cardScale, {Scale=1}, 0.5, Enum.EasingStyle.Back, Enum.EasingDirection.Out)

        -- glow ring behind crown
        local glow = make("Frame", {
            Size=UDim2.fromOffset(s(80), s(80)), AnchorPoint=Vector2.new(0.5,0.5),
            Position=UDim2.new(0.5,0,0,s(55)), BackgroundColor3=_GOLD,
            BackgroundTransparency=0.7, BorderSizePixel=0, ZIndex=11, Parent=card,
        })
        make("UICorner", {CornerRadius=UDim.new(1,0), Parent=glow})
        local glowScale = make("UIScale", {Scale=0.5, Parent=glow})
        tw(glowScale, {Scale=1.6}, 0.8, Enum.EasingStyle.Quint, Enum.EasingDirection.Out)
        tw(glow, {BackgroundTransparency=1}, 1.2, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)

        -- crown icon
        local crown = make("ImageLabel", {
            Size=UDim2.fromOffset(s(48), s(48)), AnchorPoint=Vector2.new(0.5,0.5),
            Position=UDim2.new(0.5,0,0,s(55)), BackgroundTransparency=1, ZIndex=12, Parent=card,
        })
        applyIcon(crown, "solar/crown-bold", _GOLD)
        local crownScale = make("UIScale", {Scale=0, Parent=crown})
        task.delay(0.15, function()
            tw(crownScale, {Scale=1}, 0.4, Enum.EasingStyle.Back, Enum.EasingDirection.Out)
        end)
        -- crown float animation
        task.spawn(function()
            local t = 0
            while crown and crown.Parent do
                t = t + 0.03
                crown.Position = UDim2.new(0.5, 0, 0, s(55) + math.sin(t * 2) * s(3))
                crown.Rotation = math.sin(t * 1.5) * 4
                task.wait(0.016)
            end
        end)

        -- title
        local titleLbl = make("TextLabel", {
            Size=UDim2.new(1, -s(30), 0, s(28)), AnchorPoint=Vector2.new(0.5,0),
            Position=UDim2.new(0.5, 0, 0, s(90)), BackgroundTransparency=1,
            Text="PREMIUM UNLOCKED", TextColor3=_GOLD,
            TextSize=fs(20), Font=Enum.Font.GothamBold, ZIndex=12, Parent=card,
        })
        titleLbl.TextTransparency = 1
        task.delay(0.3, function()
            tw(titleLbl, {TextTransparency=0}, 0.4)
        end)

        -- shimmer line across the title
        local shimmer = make("Frame", {
            Size=UDim2.new(0, s(60), 1, 0), Position=UDim2.new(-0.2, 0, 0, 0),
            BackgroundTransparency=1, ZIndex=13, Parent=titleLbl, ClipsDescendants=false,
        })
        make("UIGradient", {
            Color=ColorSequence.new({
                ColorSequenceKeypoint.new(0, Color3.fromRGB(255,255,255)),
                ColorSequenceKeypoint.new(0.5, Color3.fromRGB(255,255,255)),
                ColorSequenceKeypoint.new(1, Color3.fromRGB(255,255,255)),
            }),
            Transparency=NumberSequence.new({
                NumberSequenceKeypoint.new(0, 1),
                NumberSequenceKeypoint.new(0.4, 0.6),
                NumberSequenceKeypoint.new(0.5, 0.4),
                NumberSequenceKeypoint.new(0.6, 0.6),
                NumberSequenceKeypoint.new(1, 1),
            }),
            Rotation=75, Parent=shimmer,
        })
        task.delay(0.5, function()
            tw(shimmer, {Position=UDim2.new(1.2, 0, 0, 0)}, 0.8, Enum.EasingStyle.Quad, Enum.EasingDirection.InOut)
        end)

        -- subtitle
        local subLbl = make("TextLabel", {
            Size=UDim2.new(1, -s(40), 0, s(30)), AnchorPoint=Vector2.new(0.5,0),
            Position=UDim2.new(0.5, 0, 0, s(122)), BackgroundTransparency=1,
            Text="All premium features are now available!", TextColor3=Color3.fromRGB(200, 175, 120),
            TextSize=fs(12), Font=Enum.Font.Gotham, TextWrapped=true, ZIndex=12, Parent=card,
        })
        subLbl.TextTransparency = 1
        task.delay(0.5, function() tw(subLbl, {TextTransparency=0}, 0.4) end)

        -- bottom accent bar
        local bar = make("Frame", {
            Size=UDim2.new(0, 0, 0, s(3)), AnchorPoint=Vector2.new(0.5,1),
            Position=UDim2.new(0.5, 0, 1, -s(14)), BackgroundColor3=_GOLD,
            BackgroundTransparency=0, BorderSizePixel=0, ZIndex=12, Parent=card,
        })
        make("UICorner", {CornerRadius=UDim.new(1,0), Parent=bar})
        task.delay(0.4, function()
            tw(bar, {Size=UDim2.new(0.6, 0, 0, s(3))}, 0.6, Enum.EasingStyle.Quint, Enum.EasingDirection.Out)
        end)

        -- stroke pulse animation
        task.spawn(function()
            task.wait(0.5)
            for pulse = 1, 2 do
                if not cardStroke or not cardStroke.Parent then break end
                tw(cardStroke, {Color=_GOLD_LIGHT, Thickness=3}, 0.3)
                task.wait(0.35)
                tw(cardStroke, {Color=_GOLD, Thickness=2}, 0.3)
                task.wait(0.4)
            end
        end)

        -- auto close after 3.5s
        task.delay(3.5, function()
            if not celebGui or not celebGui.Parent then return end
            tw(cardScale, {Scale=0.8}, 0.3)
            tw(card, {BackgroundTransparency=1}, 0.3)
            tw(cardStroke, {Transparency=1}, 0.25)
            tw(titleLbl, {TextTransparency=1}, 0.2)
            tw(subLbl, {TextTransparency=1}, 0.2)
            tw(bar, {BackgroundTransparency=1}, 0.2)
            task.delay(0.35, function()
                pcall(function() celebGui:Destroy() end)
            end)
        end)
    end)

    -- ══════════════════════════════════════════════
    -- UNLOCK ALL PREMIUM OVERLAYS (with staggered gold-shimmer)
    -- ══════════════════════════════════════════════
    local delay_i = 0
    for _, entry in ipairs(Aurora._premiumOverlays or {}) do
        pcall(function()
            if entry.Gui and entry.Gui.Parent then
                local d = delay_i * 0.06
                delay_i = delay_i + 1
                task.delay(d, function()
                    if not entry.Gui or not entry.Gui.Parent then return end
                    -- gold flash before fade
                    tw(entry.Gui, {BackgroundColor3=Color3.fromRGB(255,200,60), BackgroundTransparency=0.6}, 0.12)
                    task.delay(0.15, function()
                        if not entry.Gui or not entry.Gui.Parent then return end
                        tw(entry.Gui, {BackgroundTransparency=1}, 0.35)
                        local badge = entry.Gui:FindFirstChildWhichIsA("Frame")
                        if badge then
                            local sc = badge:FindFirstChildOfClass("UIScale")
                            if sc then
                                tw(sc, {Scale=1.3}, 0.1)
                                task.delay(0.12, function()
                                    if sc and sc.Parent then tw(sc, {Scale=0}, 0.25) end
                                end)
                            end
                        end
                        task.delay(0.4, function() pcall(function() entry.Gui:Destroy() end) end)
                    end)
                end)
            end
        end)
    end
    Aurora._premiumOverlays = {}

    for _, elem in ipairs(Aurora._premiumElements or {}) do
        pcall(function()
            elem._premiumLocked = false
            if elem._premiumOverlay and elem._premiumOverlay.Parent then
                tw(elem._premiumOverlay, {BackgroundTransparency=1}, 0.3)
                task.delay(0.35, function() pcall(function() elem._premiumOverlay:Destroy() end) end)
                elem._premiumOverlay = nil
            end
        end)
    end

    if Aurora._refreshPremiumButtons then pcall(Aurora._refreshPremiumButtons) end

    -- refresh premium states on all dropdown options
    for _, opt in pairs(Aurora.Options or {}) do
        if opt and opt.Type == "Dropdown" and opt._hasPremiumValues and type(opt.RefreshPremiumState) == "function" then
            pcall(opt.RefreshPremiumState, opt)
        end
    end

    -- fire global callback for scripts
    if type(Aurora.OnPremiumUnlocked) == "function" then
        pcall(Aurora.OnPremiumUnlocked)
    end

    Aurora._premiumUnlocking = false
end

-- ══════════════════════════════════════════════
-- ENHANCED PREMIUM DETECTION
-- ══════════════════════════════════════════════
-- Check multiple sources: Aurora.IsPremium, getgenv().SyneroxTier, KeySystem.Tier
function Aurora:CheckPremium()
    if self.IsPremium then return true end
    local ok, tier = pcall(function() return getgenv().SyneroxTier end)
    if ok and tier == "premium" then
        if not self.IsPremium then
            self.IsPremium = true
            self.KeySystem = self.KeySystem or {}
            self.KeySystem.Tier = "premium"
        end
        return true
    end
    if self.KeySystem and self.KeySystem.Tier == "premium" then
        self.IsPremium = true
        return true
    end
    return false
end

-- Auto-detect premium from external sources (poll once)
function Aurora:DetectPremium()
    if self.IsPremium then return true end
    if self:CheckPremium() then
        self:UnlockPremium()
        return true
    end
    return false
end

-- Watch for premium unlock from external scripts (getgenv().SyneroxTier changes)
function Aurora:WatchPremium(interval)
    if self._premiumWatcher then return end
    interval = interval or 2
    self._premiumWatcher = true
    task.spawn(function()
        while self._premiumWatcher do
            if not self.IsPremium then
                if self:CheckPremium() then
                    self:UnlockPremium()
                    self._premiumWatcher = nil
                    return
                end
            else
                self._premiumWatcher = nil
                return
            end
            task.wait(interval)
        end
    end)
end
function Aurora:StopWatchPremium()
    self._premiumWatcher = nil
end
local activeAcrylics = {}
local function updateDofState()
    local dof = game:GetService("Lighting"):FindFirstChild("AuroraBlur")
    if not dof then return end
    local anyVisible = false
    for part, _ in pairs(activeAcrylics) do
        if part.Parent and part.Transparency < 1 then
            anyVisible = true
            break
        end
    end
    dof.Enabled = anyVisible
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
        dof.Enabled = false
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
    part.Transparency = 1
    local mesh = Instance.new("SpecialMesh")
    mesh.MeshType = Enum.MeshType.Brick
    mesh.Offset = Vector3.new(0, 0, -0.000001)
    mesh.Parent = part
    part.Parent = camera
    activeAcrylics[part] = true
    local connections = {}
    local distance = 0.001
    local screenGui = frame:FindFirstAncestorOfClass("ScreenGui")
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
        local oldTrans = part.Transparency
        local newTrans = visible and 0.98 or 1
        part.Transparency = newTrans
        if oldTrans ~= newTrans then
            updateDofState()
        end
        if not visible then return end
        local absSize = frame.AbsoluteSize
        local absPos = frame.AbsolutePosition
        local uiCorner = frame:FindFirstChildOfClass("UICorner")
        local radius = 16
        if uiCorner then
            if uiCorner.CornerRadius.Scale > 0 then
                radius = uiCorner.CornerRadius.Scale * math.min(absSize.X, absSize.Y)
            else
                radius = uiCorner.CornerRadius.Offset
            end
        end
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
    local function safeUpdate()
        local visible = frame.Visible
        if visible and screenGui then
            visible = screenGui.Enabled
        end
        if visible and frame.AbsoluteSize.X > 0 and frame.AbsoluteSize.Y > 0 then
            updatePosition()
        else
            if part.Transparency ~= 1 then
                part.Transparency = 1
                updateDofState()
            end
        end
    end
    table.insert(connections, camera:GetPropertyChangedSignal("CFrame"):Connect(safeUpdate))
    table.insert(connections, camera:GetPropertyChangedSignal("ViewportSize"):Connect(safeUpdate))
    table.insert(connections, camera:GetPropertyChangedSignal("FieldOfView"):Connect(safeUpdate))
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
        activeAcrylics[part] = nil
        updateDofState()
        for _, conn in ipairs(connections) do
            pcall(function() conn:Disconnect() end)
        end
    end)
    frame.Destroying:Connect(function()
        pcall(function() part:Destroy() end)
    end)
    return part
end
local function _applyThemeEntry(e, theme)
    if e.isCallback then
        if type(e.callback) == "function" then e.callback() end
        return true
    end
    local obj = e.obj
    local prop = e.prop
    local key = e.key
    if not obj or not obj.Parent then return false end
    local val = theme and theme[key]
    if val == nil then return true end
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
        if prop then obj[prop] = val end
    end
    return true
end
local function _cleanDeadEntry(entry, index)
    local obj = entry.obj
    local prop = entry.prop
    local key = entry.key
    local bindings = obj and _themeBindingIndex[obj]
    if bindings and prop and bindings[prop] == entry then
        bindings[prop] = nil
    end
    if key then
        local bucket = Aurora._themeObjsByKey[key]
        if bucket then
            for i, e in ipairs(bucket) do
                if e == entry then table.remove(bucket, i); break end
            end
        end
    end
end
function Aurora:UpdateTheme(changedKeys)
    if changedKeys then
        local dead = {}
        for changedKey in pairs(changedKeys) do
            local bucket = self._themeObjsByKey[changedKey]
            if bucket then
                for i = #bucket, 1, -1 do
                    local e = bucket[i]
                    local ok = pcall(_applyThemeEntry, e, self.Theme)
                    if not ok or (e.obj and not e.obj.Parent) then
                        table.insert(dead, e)
                    end
                end
            end
        end
        for _, entry in ipairs(dead) do
            _cleanDeadEntry(entry)
            for i, e in ipairs(self.ThemeObjs) do
                if e == entry then table.remove(self.ThemeObjs, i); break end
            end
        end
    else
        local dead = {}
        for i, e in ipairs(self.ThemeObjs) do
            local ok = pcall(_applyThemeEntry, e, self.Theme)
            if not ok or (not e.isCallback and e.obj and not e.obj.Parent) then
                table.insert(dead, i)
            end
        end
        for i = #dead, 1, -1 do
            local index = dead[i]
            local entry = self.ThemeObjs[index]
            _cleanDeadEntry(entry, index)
            table.remove(self.ThemeObjs, index)
        end
    end
    return true
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
Aurora.Themes = {
    Dark = {
        -- Neutral charcoal surfaces keep the accent reserved for actions and state.
        Background = Color3.fromRGB(13, 16, 20),
        Sidebar = Color3.fromRGB(16, 20, 25),
        TopBar = Color3.fromRGB(18, 23, 29),
        Element = Color3.fromRGB(25, 31, 38),
        ElementHover = Color3.fromRGB(35, 43, 52),
        Accent = Color3.fromRGB(124, 190, 238),
        AccentDim = Color3.fromRGB(27, 57, 82),
        Text = Color3.fromRGB(238, 243, 247),
        SubText = Color3.fromRGB(148, 162, 176),
        Border = Color3.fromRGB(48, 58, 70),
        Scrollbar = Color3.fromRGB(70, 86, 102),
        ToggleOff = Color3.fromRGB(36, 44, 53),
        ToggleOn = Color3.fromRGB(124, 190, 238),
        SliderTrack = Color3.fromRGB(31, 39, 48),
        SliderFill = Color3.fromRGB(124, 190, 238),
        InputBG = Color3.fromRGB(18, 23, 29),
        NotifBG = Color3.fromRGB(17, 22, 28),
        TabActive = Color3.fromRGB(240, 246, 250),
        TabInactive = Color3.fromRGB(128, 144, 160),
        AlertInfo = Color3.fromRGB(90, 170, 235),
        AlertWarn = Color3.fromRGB(237, 181, 76),
        AlertError = Color3.fromRGB(231, 97, 104),
        AlertSuccess = Color3.fromRGB(81, 205, 137),
        IconColor = Color3.fromRGB(193, 210, 222),
    },
    Ocean = {
        Background = Color3.fromRGB(10, 16, 26),
        Sidebar = Color3.fromRGB(12, 19, 31),
        TopBar = Color3.fromRGB(12, 19, 31),
        Element = Color3.fromRGB(16, 26, 42),
        ElementHover = Color3.fromRGB(22, 36, 58),
        Accent = Color3.fromRGB(0, 162, 255),
        AccentDim = Color3.fromRGB(10, 40, 70),
        Text = Color3.fromRGB(240, 245, 255),
        SubText = Color3.fromRGB(130, 145, 175),
        Border = Color3.fromRGB(30, 45, 70),
        Scrollbar = Color3.fromRGB(40, 60, 90),
        ToggleOff = Color3.fromRGB(24, 38, 60),
        ToggleOn = Color3.fromRGB(0, 162, 255),
        SliderTrack = Color3.fromRGB(20, 32, 50),
        SliderFill = Color3.fromRGB(0, 162, 255),
        InputBG = Color3.fromRGB(12, 20, 32),
        NotifBG = Color3.fromRGB(12, 20, 32),
        TabActive = Color3.fromRGB(240, 245, 255),
        TabInactive = Color3.fromRGB(110, 125, 155),
        AlertInfo = Color3.fromRGB(0, 162, 255),
        AlertWarn = Color3.fromRGB(235, 160, 45),
        AlertError = Color3.fromRGB(230, 60, 60),
        AlertSuccess = Color3.fromRGB(40, 200, 100),
        IconColor = Color3.fromRGB(180, 195, 220),
    },
    RGB = {
        Background = Color3.fromRGB(10, 10, 13),
        Sidebar = Color3.fromRGB(11, 11, 14),
        TopBar = Color3.fromRGB(11, 11, 14),
        Element = Color3.fromRGB(18, 18, 23),
        ElementHover = Color3.fromRGB(26, 26, 32),
        Accent = Color3.fromRGB(255, 0, 0),
        AccentDim = Color3.fromRGB(45, 15, 15),
        Text = Color3.fromRGB(245, 245, 250),
        SubText = Color3.fromRGB(140, 140, 158),
        Border = Color3.fromRGB(35, 35, 44),
        Scrollbar = Color3.fromRGB(55, 55, 68),
        ToggleOff = Color3.fromRGB(32, 32, 42),
        ToggleOn = Color3.fromRGB(255, 0, 0),
        SliderTrack = Color3.fromRGB(28, 28, 36),
        SliderFill = Color3.fromRGB(255, 0, 0),
        InputBG = Color3.fromRGB(14, 14, 18),
        NotifBG = Color3.fromRGB(14, 14, 18),
        TabActive = Color3.fromRGB(245, 245, 250),
        TabInactive = Color3.fromRGB(105, 105, 122),
        AlertInfo = Color3.fromRGB(55, 135, 235),
        AlertWarn = Color3.fromRGB(225, 155, 35),
        AlertError = Color3.fromRGB(220, 55, 55),
        AlertSuccess = Color3.fromRGB(38, 195, 95),
        IconColor = Color3.fromRGB(200, 200, 218),
    },
    Amethyst = {
        Background = Color3.fromRGB(10, 8, 14),
        Sidebar = Color3.fromRGB(11, 9, 16),
        TopBar = Color3.fromRGB(11, 9, 16),
        Element = Color3.fromRGB(18, 14, 25),
        ElementHover = Color3.fromRGB(26, 20, 35),
        Accent = Color3.fromRGB(160, 50, 240),
        AccentDim = Color3.fromRGB(35, 15, 50),
        Text = Color3.fromRGB(245, 240, 255),
        SubText = Color3.fromRGB(150, 140, 170),
        Border = Color3.fromRGB(38, 30, 50),
        Scrollbar = Color3.fromRGB(60, 50, 80),
        ToggleOff = Color3.fromRGB(34, 25, 45),
        ToggleOn = Color3.fromRGB(160, 50, 240),
        SliderTrack = Color3.fromRGB(30, 22, 40),
        SliderFill = Color3.fromRGB(160, 50, 240),
        InputBG = Color3.fromRGB(14, 10, 20),
        NotifBG = Color3.fromRGB(14, 10, 20),
        TabActive = Color3.fromRGB(245, 240, 255),
        TabInactive = Color3.fromRGB(110, 100, 130),
        AlertInfo = Color3.fromRGB(160, 50, 240),
        AlertWarn = Color3.fromRGB(225, 155, 35),
        AlertError = Color3.fromRGB(220, 55, 55),
        AlertSuccess = Color3.fromRGB(38, 195, 95),
        IconColor = Color3.fromRGB(210, 195, 230),
    },
    Neon = {
        Background = Color3.fromRGB(5, 12, 10),
        Sidebar = Color3.fromRGB(6, 14, 12),
        TopBar = Color3.fromRGB(6, 14, 12),
        Element = Color3.fromRGB(10, 22, 18),
        ElementHover = Color3.fromRGB(14, 30, 24),
        Accent = Color3.fromRGB(0, 255, 170),
        AccentDim = Color3.fromRGB(10, 45, 35),
        Text = Color3.fromRGB(240, 255, 250),
        SubText = Color3.fromRGB(130, 160, 150),
        Border = Color3.fromRGB(25, 50, 42),
        Scrollbar = Color3.fromRGB(40, 80, 68),
        ToggleOff = Color3.fromRGB(20, 40, 34),
        ToggleOn = Color3.fromRGB(0, 255, 170),
        SliderTrack = Color3.fromRGB(15, 30, 26),
        SliderFill = Color3.fromRGB(0, 255, 170),
        InputBG = Color3.fromRGB(8, 18, 14),
        NotifBG = Color3.fromRGB(8, 18, 14),
        TabActive = Color3.fromRGB(240, 255, 250),
        TabInactive = Color3.fromRGB(110, 135, 125),
        AlertInfo = Color3.fromRGB(0, 170, 255),
        AlertWarn = Color3.fromRGB(225, 155, 35),
        AlertError = Color3.fromRGB(220, 55, 55),
        AlertSuccess = Color3.fromRGB(0, 255, 170),
        IconColor = Color3.fromRGB(190, 220, 210),
    },
    BloodRed = {
        Background = Color3.fromRGB(12, 6, 6),
        Sidebar = Color3.fromRGB(14, 7, 7),
        TopBar = Color3.fromRGB(14, 7, 7),
        Element = Color3.fromRGB(22, 10, 10),
        ElementHover = Color3.fromRGB(30, 14, 14),
        Accent = Color3.fromRGB(255, 30, 30),
        AccentDim = Color3.fromRGB(50, 10, 10),
        Text = Color3.fromRGB(255, 240, 240),
        SubText = Color3.fromRGB(170, 130, 130),
        Border = Color3.fromRGB(45, 20, 20),
        Scrollbar = Color3.fromRGB(75, 30, 30),
        ToggleOff = Color3.fromRGB(35, 15, 15),
        ToggleOn = Color3.fromRGB(255, 30, 30),
        SliderTrack = Color3.fromRGB(28, 12, 12),
        SliderFill = Color3.fromRGB(255, 30, 30),
        InputBG = Color3.fromRGB(16, 8, 8),
        NotifBG = Color3.fromRGB(16, 8, 8),
        TabActive = Color3.fromRGB(255, 240, 240),
        TabInactive = Color3.fromRGB(140, 105, 105),
        AlertInfo = Color3.fromRGB(55, 135, 235),
        AlertWarn = Color3.fromRGB(225, 155, 35),
        AlertError = Color3.fromRGB(255, 30, 30),
        AlertSuccess = Color3.fromRGB(38, 195, 95),
        IconColor = Color3.fromRGB(230, 190, 190),
        BackgroundImage = "rbxassetid://121343473918667",
        BackgroundImageTransparency = 0.15,
    },
    Midnight = {
        Background = Color3.fromRGB(6, 6, 8),
        Sidebar = Color3.fromRGB(8, 8, 10),
        TopBar = Color3.fromRGB(8, 8, 10),
        Element = Color3.fromRGB(14, 14, 18),
        ElementHover = Color3.fromRGB(20, 20, 26),
        Accent = Color3.fromRGB(45, 110, 235),
        AccentDim = Color3.fromRGB(15, 35, 75),
        Text = Color3.fromRGB(245, 245, 250),
        SubText = Color3.fromRGB(130, 130, 145),
        Border = Color3.fromRGB(30, 30, 38),
        Scrollbar = Color3.fromRGB(48, 48, 60),
        ToggleOff = Color3.fromRGB(24, 24, 32),
        ToggleOn = Color3.fromRGB(45, 110, 235),
        SliderTrack = Color3.fromRGB(20, 20, 28),
        SliderFill = Color3.fromRGB(45, 110, 235),
        InputBG = Color3.fromRGB(10, 10, 14),
        NotifBG = Color3.fromRGB(10, 10, 14),
        TabActive = Color3.fromRGB(245, 245, 250),
        TabInactive = Color3.fromRGB(100, 100, 115),
        AlertInfo = Color3.fromRGB(45, 110, 235),
        AlertWarn = Color3.fromRGB(225, 155, 35),
        AlertError = Color3.fromRGB(220, 55, 55),
        AlertSuccess = Color3.fromRGB(38, 195, 95),
        IconColor = Color3.fromRGB(190, 190, 205),
    },
    NeonCyber = {
        Background = Color3.fromRGB(5, 10, 5),
        Sidebar = Color3.fromRGB(3, 8, 3),
        TopBar = Color3.fromRGB(3, 8, 3),
        Element = Color3.fromRGB(10, 22, 10),
        ElementHover = Color3.fromRGB(15, 30, 15),
        Accent = Color3.fromRGB(57, 255, 20),
        AccentDim = Color3.fromRGB(10, 45, 15),
        Text = Color3.fromRGB(200, 255, 190),
        SubText = Color3.fromRGB(80, 200, 60),
        Border = Color3.fromRGB(25, 60, 15),
        Scrollbar = Color3.fromRGB(20, 50, 15),
        ToggleOff = Color3.fromRGB(8, 18, 8),
        ToggleOn = Color3.fromRGB(57, 255, 20),
        SliderTrack = Color3.fromRGB(6, 14, 6),
        SliderFill = Color3.fromRGB(57, 255, 20),
        InputBG = Color3.fromRGB(8, 18, 8),
        NotifBG = Color3.fromRGB(5, 12, 5),
        TabActive = Color3.fromRGB(200, 255, 190),
        TabInactive = Color3.fromRGB(80, 200, 60),
        AlertInfo = Color3.fromRGB(57, 255, 20),
        AlertWarn = Color3.fromRGB(225, 155, 35),
        AlertError = Color3.fromRGB(220, 55, 55),
        AlertSuccess = Color3.fromRGB(57, 255, 20),
        IconColor = Color3.fromRGB(150, 230, 140),
    },
    ArcticFrost = {
        Background = Color3.fromRGB(210, 235, 250),
        Sidebar = Color3.fromRGB(185, 215, 235),
        TopBar = Color3.fromRGB(185, 215, 235),
        Element = Color3.fromRGB(225, 242, 255),
        ElementHover = Color3.fromRGB(200, 228, 248),
        Accent = Color3.fromRGB(100, 180, 240),
        AccentDim = Color3.fromRGB(140, 185, 218),
        Text = Color3.fromRGB(20, 40, 70),
        SubText = Color3.fromRGB(65, 105, 148),
        Border = Color3.fromRGB(170, 200, 225),
        Scrollbar = Color3.fromRGB(150, 180, 200),
        ToggleOff = Color3.fromRGB(190, 215, 230),
        ToggleOn = Color3.fromRGB(100, 180, 240),
        SliderTrack = Color3.fromRGB(180, 205, 220),
        SliderFill = Color3.fromRGB(100, 180, 240),
        InputBG = Color3.fromRGB(220, 240, 255),
        NotifBG = Color3.fromRGB(210, 235, 250),
        TabActive = Color3.fromRGB(20, 40, 70),
        TabInactive = Color3.fromRGB(65, 105, 148),
        AlertInfo = Color3.fromRGB(100, 180, 240),
        AlertWarn = Color3.fromRGB(225, 155, 35),
        AlertError = Color3.fromRGB(220, 55, 55),
        AlertSuccess = Color3.fromRGB(38, 195, 95),
        IconColor = Color3.fromRGB(60, 120, 180),
    },
    CottonCandy = {
        Background = Color3.fromRGB(255, 225, 245),
        Sidebar = Color3.fromRGB(255, 200, 235),
        TopBar = Color3.fromRGB(255, 200, 235),
        Element = Color3.fromRGB(255, 235, 250),
        ElementHover = Color3.fromRGB(235, 210, 255),
        Accent = Color3.fromRGB(255, 130, 190),
        AccentDim = Color3.fromRGB(235, 170, 215),
        Text = Color3.fromRGB(75, 25, 55),
        SubText = Color3.fromRGB(145, 75, 115),
        Border = Color3.fromRGB(230, 165, 210),
        Scrollbar = Color3.fromRGB(220, 155, 200),
        ToggleOff = Color3.fromRGB(240, 190, 225),
        ToggleOn = Color3.fromRGB(255, 130, 190),
        SliderTrack = Color3.fromRGB(230, 180, 215),
        SliderFill = Color3.fromRGB(255, 130, 190),
        InputBG = Color3.fromRGB(255, 238, 252),
        NotifBG = Color3.fromRGB(255, 225, 245),
        TabActive = Color3.fromRGB(75, 25, 55),
        TabInactive = Color3.fromRGB(145, 75, 115),
        AlertInfo = Color3.fromRGB(255, 130, 190),
        AlertWarn = Color3.fromRGB(225, 155, 35),
        AlertError = Color3.fromRGB(220, 55, 55),
        AlertSuccess = Color3.fromRGB(38, 195, 95),
        IconColor = Color3.fromRGB(195, 100, 155),
    },
    Orange = {
        Background = Color3.fromRGB(4, 4, 4),
        Sidebar = Color3.fromRGB(10, 5, 0),
        TopBar = Color3.fromRGB(10, 5, 0),
        Element = Color3.fromRGB(22, 10, 2),
        ElementHover = Color3.fromRGB(30, 14, 2),
        Accent = Color3.fromRGB(255, 140, 30),
        AccentDim = Color3.fromRGB(80, 35, 5),
        Text = Color3.fromRGB(255, 240, 220),
        SubText = Color3.fromRGB(220, 175, 130),
        Border = Color3.fromRGB(80, 35, 5),
        Scrollbar = Color3.fromRGB(70, 30, 5),
        ToggleOff = Color3.fromRGB(18, 8, 2),
        ToggleOn = Color3.fromRGB(255, 140, 30),
        SliderTrack = Color3.fromRGB(14, 6, 1),
        SliderFill = Color3.fromRGB(255, 140, 30),
        InputBG = Color3.fromRGB(18, 8, 2),
        NotifBG = Color3.fromRGB(6, 3, 0),
        TabActive = Color3.fromRGB(255, 240, 220),
        TabInactive = Color3.fromRGB(220, 175, 130),
        AlertInfo = Color3.fromRGB(255, 140, 30),
        AlertWarn = Color3.fromRGB(225, 155, 35),
        AlertError = Color3.fromRGB(220, 55, 55),
        AlertSuccess = Color3.fromRGB(38, 195, 95),
        IconColor = Color3.fromRGB(210, 120, 30),
        BackgroundImage = "rbxassetid://122033436660262",
        BackgroundImageTransparency = 0.05,
    },
    Cyanic = {
        Background = Color3.fromRGB(8, 18, 22),
        Sidebar = Color3.fromRGB(8, 25, 32),
        TopBar = Color3.fromRGB(8, 25, 32),
        Element = Color3.fromRGB(14, 38, 46),
        ElementHover = Color3.fromRGB(20, 48, 58),
        Accent = Color3.fromRGB(57, 197, 187),
        AccentDim = Color3.fromRGB(35, 155, 150),
        Text = Color3.fromRGB(210, 248, 246),
        SubText = Color3.fromRGB(130, 210, 205),
        Border = Color3.fromRGB(35, 155, 150),
        Scrollbar = Color3.fromRGB(30, 120, 115),
        ToggleOff = Color3.fromRGB(10, 28, 35),
        ToggleOn = Color3.fromRGB(57, 197, 187),
        SliderTrack = Color3.fromRGB(8, 22, 28),
        SliderFill = Color3.fromRGB(57, 197, 187),
        InputBG = Color3.fromRGB(10, 28, 35),
        NotifBG = Color3.fromRGB(8, 22, 28),
        TabActive = Color3.fromRGB(210, 248, 246),
        TabInactive = Color3.fromRGB(130, 210, 205),
        AlertInfo = Color3.fromRGB(57, 197, 187),
        AlertWarn = Color3.fromRGB(225, 155, 35),
        AlertError = Color3.fromRGB(220, 55, 55),
        AlertSuccess = Color3.fromRGB(38, 195, 95),
        IconColor = Color3.fromRGB(45, 170, 160),
        BackgroundImage = "rbxassetid://95656189244173",
        BackgroundImageTransparency = 0.12,
    },
    AmberGlow = {
        Background = Color3.fromRGB(18, 10, 4),
        Sidebar = Color3.fromRGB(12, 6, 1),
        TopBar = Color3.fromRGB(12, 6, 1),
        Element = Color3.fromRGB(38, 20, 5),
        ElementHover = Color3.fromRGB(50, 25, 5),
        Accent = Color3.fromRGB(255, 170, 40),
        AccentDim = Color3.fromRGB(185, 120, 25),
        Text = Color3.fromRGB(255, 245, 225),
        SubText = Color3.fromRGB(230, 195, 145),
        Border = Color3.fromRGB(185, 120, 25),
        Scrollbar = Color3.fromRGB(140, 88, 18),
        ToggleOff = Color3.fromRGB(28, 14, 3),
        ToggleOn = Color3.fromRGB(255, 170, 40),
        SliderTrack = Color3.fromRGB(20, 10, 2),
        SliderFill = Color3.fromRGB(255, 170, 40),
        InputBG = Color3.fromRGB(28, 14, 3),
        NotifBG = Color3.fromRGB(18, 9, 2),
        TabActive = Color3.fromRGB(255, 245, 225),
        TabInactive = Color3.fromRGB(230, 195, 145),
        AlertInfo = Color3.fromRGB(255, 170, 40),
        AlertWarn = Color3.fromRGB(225, 155, 35),
        AlertError = Color3.fromRGB(220, 55, 55),
        AlertSuccess = Color3.fromRGB(38, 195, 95),
        IconColor = Color3.fromRGB(220, 140, 30),
        BackgroundImage = "rbxassetid://107795771598485",
        BackgroundImageTransparency = 0.12,
    },
    DeepViolet = {
        Background = Color3.fromRGB(20, 20, 20),
        Sidebar = Color3.fromRGB(40, 25, 65),
        TopBar = Color3.fromRGB(40, 25, 65),
        Element = Color3.fromRGB(60, 45, 80),
        ElementHover = Color3.fromRGB(85, 57, 139),
        Accent = Color3.fromRGB(160, 120, 220),
        AccentDim = Color3.fromRGB(110, 90, 130),
        Text = Color3.fromRGB(240, 240, 240),
        SubText = Color3.fromRGB(170, 170, 170),
        Border = Color3.fromRGB(110, 90, 130),
        Scrollbar = Color3.fromRGB(90, 70, 110),
        ToggleOff = Color3.fromRGB(50, 35, 70),
        ToggleOn = Color3.fromRGB(160, 120, 220),
        SliderTrack = Color3.fromRGB(40, 28, 55),
        SliderFill = Color3.fromRGB(160, 120, 220),
        InputBG = Color3.fromRGB(70, 55, 85),
        NotifBG = Color3.fromRGB(60, 45, 80),
        TabActive = Color3.fromRGB(240, 240, 240),
        TabInactive = Color3.fromRGB(170, 170, 170),
        AlertInfo = Color3.fromRGB(160, 120, 220),
        AlertWarn = Color3.fromRGB(225, 155, 35),
        AlertError = Color3.fromRGB(220, 55, 55),
        AlertSuccess = Color3.fromRGB(38, 195, 95),
        IconColor = Color3.fromRGB(130, 90, 180),
        BackgroundImage = "rbxassetid://136310484943077",
        BackgroundImageTransparency = 0.15,
    },
    Charcoal = {
        Background = Color3.fromRGB(20, 20, 20),
        Sidebar = Color3.fromRGB(15, 15, 15),
        TopBar = Color3.fromRGB(15, 15, 15),
        Element = Color3.fromRGB(35, 35, 35),
        ElementHover = Color3.fromRGB(45, 45, 45),
        Accent = Color3.fromRGB(102, 102, 102),
        AccentDim = Color3.fromRGB(60, 60, 60),
        Text = Color3.fromRGB(240, 240, 240),
        SubText = Color3.fromRGB(170, 170, 170),
        Border = Color3.fromRGB(60, 60, 60),
        Scrollbar = Color3.fromRGB(50, 50, 50),
        ToggleOff = Color3.fromRGB(25, 25, 25),
        ToggleOn = Color3.fromRGB(102, 102, 102),
        SliderTrack = Color3.fromRGB(20, 20, 20),
        SliderFill = Color3.fromRGB(102, 102, 102),
        InputBG = Color3.fromRGB(25, 25, 25),
        NotifBG = Color3.fromRGB(20, 20, 20),
        TabActive = Color3.fromRGB(240, 240, 240),
        TabInactive = Color3.fromRGB(170, 170, 170),
        AlertInfo = Color3.fromRGB(102, 102, 102),
        AlertWarn = Color3.fromRGB(225, 155, 35),
        AlertError = Color3.fromRGB(220, 55, 55),
        AlertSuccess = Color3.fromRGB(38, 195, 95),
        IconColor = Color3.fromRGB(130, 130, 130),
    },
    PearlWhite = {
        Background = Color3.fromRGB(240, 240, 240),
        Sidebar = Color3.fromRGB(220, 220, 220),
        TopBar = Color3.fromRGB(220, 220, 220),
        Element = Color3.fromRGB(230, 230, 230),
        ElementHover = Color3.fromRGB(210, 210, 210),
        Accent = Color3.fromRGB(60, 160, 255),
        AccentDim = Color3.fromRGB(200, 200, 200),
        Text = Color3.fromRGB(20, 20, 20),
        SubText = Color3.fromRGB(90, 90, 90),
        Border = Color3.fromRGB(200, 200, 200),
        Scrollbar = Color3.fromRGB(180, 180, 180),
        ToggleOff = Color3.fromRGB(240, 240, 240),
        ToggleOn = Color3.fromRGB(60, 160, 255),
        SliderTrack = Color3.fromRGB(210, 210, 210),
        SliderFill = Color3.fromRGB(60, 160, 255),
        InputBG = Color3.fromRGB(240, 240, 240),
        NotifBG = Color3.fromRGB(230, 230, 230),
        TabActive = Color3.fromRGB(20, 20, 20),
        TabInactive = Color3.fromRGB(90, 90, 90),
        AlertInfo = Color3.fromRGB(60, 160, 255),
        AlertWarn = Color3.fromRGB(225, 155, 35),
        AlertError = Color3.fromRGB(220, 55, 55),
        AlertSuccess = Color3.fromRGB(38, 195, 95),
        IconColor = Color3.fromRGB(80, 150, 210),
    },
    Galaxy = {
        Background = Color3.fromRGB(12, 5, 25),
        Sidebar = Color3.fromRGB(8, 3, 20),
        TopBar = Color3.fromRGB(8, 3, 20),
        Element = Color3.fromRGB(112, 40, 170),
        ElementHover = Color3.fromRGB(130, 50, 195),
        Accent = Color3.fromRGB(160, 60, 220),
        AccentDim = Color3.fromRGB(120, 40, 185),
        Text = Color3.fromRGB(242, 232, 255),
        SubText = Color3.fromRGB(200, 178, 228),
        Border = Color3.fromRGB(120, 40, 185),
        Scrollbar = Color3.fromRGB(95, 30, 140),
        ToggleOff = Color3.fromRGB(48, 18, 85),
        ToggleOn = Color3.fromRGB(160, 60, 220),
        SliderTrack = Color3.fromRGB(35, 12, 60),
        SliderFill = Color3.fromRGB(160, 60, 220),
        InputBG = Color3.fromRGB(100, 35, 152),
        NotifBG = Color3.fromRGB(8, 3, 20),
        TabActive = Color3.fromRGB(242, 232, 255),
        TabInactive = Color3.fromRGB(200, 178, 228),
        AlertInfo = Color3.fromRGB(160, 60, 220),
        AlertWarn = Color3.fromRGB(225, 155, 35),
        AlertError = Color3.fromRGB(220, 55, 55),
        AlertSuccess = Color3.fromRGB(38, 195, 95),
        IconColor = Color3.fromRGB(140, 80, 195),
    },
    AMOLED = {
        Background = Color3.fromRGB(0, 0, 0),
        Sidebar = Color3.fromRGB(10, 10, 10),
        TopBar = Color3.fromRGB(10, 10, 10),
        Element = Color3.fromRGB(15, 15, 15),
        ElementHover = Color3.fromRGB(22, 22, 22),
        Accent = Color3.fromRGB(255, 255, 255),
        AccentDim = Color3.fromRGB(50, 50, 50),
        Text = Color3.fromRGB(255, 255, 255),
        SubText = Color3.fromRGB(150, 150, 150),
        Border = Color3.fromRGB(20, 20, 20),
        Scrollbar = Color3.fromRGB(30, 30, 30),
        ToggleOff = Color3.fromRGB(25, 25, 25),
        ToggleOn = Color3.fromRGB(255, 255, 255),
        SliderTrack = Color3.fromRGB(30, 30, 30),
        SliderFill = Color3.fromRGB(255, 255, 255),
        InputBG = Color3.fromRGB(12, 12, 12),
        NotifBG = Color3.fromRGB(10, 10, 10),
        TabActive = Color3.fromRGB(255, 255, 255),
        TabInactive = Color3.fromRGB(150, 150, 150),
        AlertInfo = Color3.fromRGB(255, 255, 255),
        AlertWarn = Color3.fromRGB(225, 155, 35),
        AlertError = Color3.fromRGB(220, 55, 55),
        AlertSuccess = Color3.fromRGB(38, 195, 95),
        IconColor = Color3.fromRGB(200, 200, 200),
        BackgroundImage = "rbxassetid://134736124666311",
        BackgroundImageTransparency = 0.05,
    },
    AshGray = {
        Background = Color3.fromRGB(45, 45, 45),
        Sidebar = Color3.fromRGB(60, 60, 60),
        TopBar = Color3.fromRGB(60, 60, 60),
        Element = Color3.fromRGB(80, 80, 80),
        ElementHover = Color3.fromRGB(95, 95, 95),
        Accent = Color3.fromRGB(150, 150, 150),
        AccentDim = Color3.fromRGB(110, 110, 110),
        Text = Color3.fromRGB(240, 240, 240),
        SubText = Color3.fromRGB(170, 170, 170),
        Border = Color3.fromRGB(90, 90, 90),
        Scrollbar = Color3.fromRGB(110, 110, 110),
        ToggleOff = Color3.fromRGB(55, 55, 55),
        ToggleOn = Color3.fromRGB(150, 150, 150),
        SliderTrack = Color3.fromRGB(65, 65, 65),
        SliderFill = Color3.fromRGB(150, 150, 150),
        InputBG = Color3.fromRGB(55, 55, 55),
        NotifBG = Color3.fromRGB(45, 45, 45),
        TabActive = Color3.fromRGB(240, 240, 240),
        TabInactive = Color3.fromRGB(170, 170, 170),
        AlertInfo = Color3.fromRGB(150, 150, 150),
        AlertWarn = Color3.fromRGB(225, 155, 35),
        AlertError = Color3.fromRGB(220, 55, 55),
        AlertSuccess = Color3.fromRGB(38, 195, 95),
        IconColor = Color3.fromRGB(180, 180, 180),
    },
    NeonPurple = {
        Background = Color3.fromRGB(5, 0, 15),
        Sidebar = Color3.fromRGB(15, 0, 35),
        TopBar = Color3.fromRGB(15, 0, 35),
        Element = Color3.fromRGB(30, 0, 65),
        ElementHover = Color3.fromRGB(45, 0, 100),
        Accent = Color3.fromRGB(180, 0, 255),
        AccentDim = Color3.fromRGB(90, 0, 140),
        Text = Color3.fromRGB(252, 245, 255),
        SubText = Color3.fromRGB(210, 185, 255),
        Border = Color3.fromRGB(140, 0, 255),
        Scrollbar = Color3.fromRGB(100, 0, 180),
        ToggleOff = Color3.fromRGB(20, 0, 45),
        ToggleOn = Color3.fromRGB(180, 0, 255),
        SliderTrack = Color3.fromRGB(25, 0, 55),
        SliderFill = Color3.fromRGB(180, 0, 255),
        InputBG = Color3.fromRGB(20, 0, 45),
        NotifBG = Color3.fromRGB(10, 0, 30),
        TabActive = Color3.fromRGB(252, 245, 255),
        TabInactive = Color3.fromRGB(210, 185, 255),
        AlertInfo = Color3.fromRGB(180, 0, 255),
        AlertWarn = Color3.fromRGB(225, 155, 35),
        AlertError = Color3.fromRGB(220, 55, 55),
        AlertSuccess = Color3.fromRGB(38, 195, 95),
        IconColor = Color3.fromRGB(220, 190, 255),
    },
    RoyalBlue = {
        Background = Color3.fromRGB(8, 20, 45),
        Sidebar = Color3.fromRGB(10, 30, 65),
        TopBar = Color3.fromRGB(10, 30, 65),
        Element = Color3.fromRGB(15, 45, 95),
        ElementHover = Color3.fromRGB(20, 60, 125),
        Accent = Color3.fromRGB(15, 82, 186),
        AccentDim = Color3.fromRGB(10, 50, 115),
        Text = Color3.fromRGB(220, 235, 255),
        SubText = Color3.fromRGB(170, 190, 220),
        Border = Color3.fromRGB(10, 65, 150),
        Scrollbar = Color3.fromRGB(15, 75, 165),
        ToggleOff = Color3.fromRGB(12, 35, 75),
        ToggleOn = Color3.fromRGB(15, 82, 186),
        SliderTrack = Color3.fromRGB(10, 28, 60),
        SliderFill = Color3.fromRGB(15, 82, 186),
        InputBG = Color3.fromRGB(12, 35, 75),
        NotifBG = Color3.fromRGB(8, 20, 45),
        TabActive = Color3.fromRGB(220, 235, 255),
        TabInactive = Color3.fromRGB(170, 190, 220),
        AlertInfo = Color3.fromRGB(15, 82, 186),
        AlertWarn = Color3.fromRGB(225, 155, 35),
        AlertError = Color3.fromRGB(220, 55, 55),
        AlertSuccess = Color3.fromRGB(38, 195, 95),
        IconColor = Color3.fromRGB(180, 210, 255),
    },
    DeepOcean = {
        Background = Color3.fromRGB(10, 25, 40),
        Sidebar = Color3.fromRGB(15, 35, 60),
        TopBar = Color3.fromRGB(15, 35, 60),
        Element = Color3.fromRGB(20, 50, 85),
        ElementHover = Color3.fromRGB(30, 70, 115),
        Accent = Color3.fromRGB(0, 150, 200),
        AccentDim = Color3.fromRGB(0, 90, 135),
        Text = Color3.fromRGB(240, 248, 255),
        SubText = Color3.fromRGB(180, 210, 230),
        Border = Color3.fromRGB(0, 100, 150),
        Scrollbar = Color3.fromRGB(0, 120, 180),
        ToggleOff = Color3.fromRGB(15, 40, 65),
        ToggleOn = Color3.fromRGB(0, 150, 200),
        SliderTrack = Color3.fromRGB(12, 30, 50),
        SliderFill = Color3.fromRGB(0, 150, 200),
        InputBG = Color3.fromRGB(15, 40, 65),
        NotifBG = Color3.fromRGB(10, 25, 40),
        TabActive = Color3.fromRGB(240, 248, 255),
        TabInactive = Color3.fromRGB(180, 210, 230),
        AlertInfo = Color3.fromRGB(0, 150, 200),
        AlertWarn = Color3.fromRGB(225, 155, 35),
        AlertError = Color3.fromRGB(220, 55, 55),
        AlertSuccess = Color3.fromRGB(38, 195, 95),
        IconColor = Color3.fromRGB(160, 210, 240),
    },
    MidnightBlue = {
        Background = Color3.fromRGB(8, 5, 20),
        Sidebar = Color3.fromRGB(15, 10, 35),
        TopBar = Color3.fromRGB(15, 10, 35),
        Element = Color3.fromRGB(25, 18, 55),
        ElementHover = Color3.fromRGB(40, 30, 85),
        Accent = Color3.fromRGB(100, 80, 200),
        AccentDim = Color3.fromRGB(65, 50, 135),
        Text = Color3.fromRGB(220, 220, 255),
        SubText = Color3.fromRGB(170, 170, 210),
        Border = Color3.fromRGB(60, 45, 140),
        Scrollbar = Color3.fromRGB(75, 55, 160),
        ToggleOff = Color3.fromRGB(18, 12, 40),
        ToggleOn = Color3.fromRGB(100, 80, 200),
        SliderTrack = Color3.fromRGB(14, 10, 30),
        SliderFill = Color3.fromRGB(100, 80, 200),
        InputBG = Color3.fromRGB(18, 12, 40),
        NotifBG = Color3.fromRGB(8, 5, 20),
        TabActive = Color3.fromRGB(220, 220, 255),
        TabInactive = Color3.fromRGB(170, 170, 210),
        AlertInfo = Color3.fromRGB(100, 80, 200),
        AlertWarn = Color3.fromRGB(225, 155, 35),
        AlertError = Color3.fromRGB(220, 55, 55),
        AlertSuccess = Color3.fromRGB(38, 195, 95),
        IconColor = Color3.fromRGB(180, 170, 230),
    },
    CosmicViolet = {
        Background = Color3.fromRGB(8, 6, 16),
        Sidebar = Color3.fromRGB(12, 10, 22),
        TopBar = Color3.fromRGB(12, 10, 22),
        Element = Color3.fromRGB(22, 16, 45),
        ElementHover = Color3.fromRGB(34, 25, 65),
        Accent = Color3.fromRGB(80, 60, 140),
        AccentDim = Color3.fromRGB(55, 38, 115),
        Text = Color3.fromRGB(230, 225, 245),
        SubText = Color3.fromRGB(185, 175, 210),
        Border = Color3.fromRGB(50, 35, 110),
        Scrollbar = Color3.fromRGB(60, 42, 120),
        ToggleOff = Color3.fromRGB(18, 12, 35),
        ToggleOn = Color3.fromRGB(80, 60, 140),
        SliderTrack = Color3.fromRGB(14, 10, 28),
        SliderFill = Color3.fromRGB(80, 60, 140),
        InputBG = Color3.fromRGB(18, 12, 35),
        NotifBG = Color3.fromRGB(8, 6, 16),
        TabActive = Color3.fromRGB(230, 225, 245),
        TabInactive = Color3.fromRGB(185, 175, 210),
        AlertInfo = Color3.fromRGB(80, 60, 140),
        AlertWarn = Color3.fromRGB(225, 155, 35),
        AlertError = Color3.fromRGB(220, 55, 55),
        AlertSuccess = Color3.fromRGB(38, 195, 95),
        IconColor = Color3.fromRGB(170, 160, 200),
    },
    Sakura = {
        Background = Color3.fromRGB(255, 238, 248),
        Sidebar = Color3.fromRGB(252, 225, 242),
        TopBar = Color3.fromRGB(252, 225, 242),
        Element = Color3.fromRGB(255, 248, 253),
        ElementHover = Color3.fromRGB(248, 220, 240),
        Accent = Color3.fromRGB(230, 100, 160),
        AccentDim = Color3.fromRGB(245, 185, 215),
        Text = Color3.fromRGB(80, 30, 60),
        SubText = Color3.fromRGB(165, 100, 140),
        Border = Color3.fromRGB(235, 180, 215),
        Scrollbar = Color3.fromRGB(220, 160, 200),
        ToggleOff = Color3.fromRGB(248, 218, 238),
        ToggleOn = Color3.fromRGB(230, 100, 160),
        SliderTrack = Color3.fromRGB(248, 215, 235),
        SliderFill = Color3.fromRGB(230, 100, 160),
        InputBG = Color3.fromRGB(255, 245, 252),
        NotifBG = Color3.fromRGB(255, 238, 248),
        TabActive = Color3.fromRGB(80, 30, 60),
        TabInactive = Color3.fromRGB(165, 100, 140),
        AlertInfo = Color3.fromRGB(130, 140, 220),
        AlertWarn = Color3.fromRGB(200, 130, 50),
        AlertError = Color3.fromRGB(210, 70, 70),
        AlertSuccess = Color3.fromRGB(60, 180, 100),
        IconColor = Color3.fromRGB(195, 100, 155),
    }
}

local function copyTheme(source)
    local result = {}
    for key, value in pairs(source or {}) do result[key] = value end
    return result
end
local function aliasTheme(name, sourceName)
    if Aurora.Themes[sourceName] then
        Aurora.Themes[name] = copyTheme(Aurora.Themes[sourceName])
    end
end
aliasTheme("Aurora", "Dark")
aliasTheme("AuroraHud", "Dark")
aliasTheme("AuroraTheme", "Dark")
aliasTheme("Darker", "Dark")
aliasTheme("Default", "Dark")
aliasTheme("Auto", "Dark")
aliasTheme("Purple", "Amethyst")
aliasTheme("Lavender", "Amethyst")
aliasTheme("Mint", "Cyanic")
aliasTheme("Forest", "Neon")
aliasTheme("Sunset", "AmberGlow")
aliasTheme("Light", "PearlWhite")
aliasTheme("Rose", "Sakura")
aliasTheme("Aqua", "Cyanic")
aliasTheme("Emerald", "Neon")
aliasTheme("Gold", "AmberGlow")
aliasTheme("Blood Red", "BloodRed")

local _nGui, _nHolder
local _activeNotifs = {}
local function _initNotif()
    if _nGui then return end
    _nGui = make("ScreenGui", { Name="AuroraNotif", ResetOnSpawn=false, DisplayOrder=99999 })
    safeParent(_nGui)
    local _notifW = _isMobile and s(240) or s(310)
    _nHolder = make("Frame", {
        Size=UDim2.new(0,_notifW,1,0), Position=UDim2.new(1,-_notifW-s(10),0,0),
        BackgroundTransparency=1, Parent=_nGui,
    })
    make("UIListLayout", {
        SortOrder=Enum.SortOrder.LayoutOrder,
        VerticalAlignment=Enum.VerticalAlignment.Bottom,
        Padding=sz(8), Parent=_nHolder,
    })
    make("UIPadding", { PaddingBottom=sz(22), Parent=_nHolder })
end
local _notifQueue = {}
local processNotifQueue
function Aurora:Notify(cfg)
    _initNotif()
    cfg = cfg or {}
    local thm = self.Theme or self.Themes.Dark
    local typ = tostring(cfg.Type or "Info")
    typ = typ:sub(1, 1):upper() .. typ:sub(2):lower()
    local dur = cfg.Duration
    if dur == nil then dur = 4 end
    dur = math.max(tonumber(dur) or 4, 0)
    local accentMap = { Success=thm.AlertSuccess, Error=thm.AlertError, Warning=thm.AlertWarn, Info=thm.AlertInfo }
    local iconMap = { Success="solar/check-circle-bold", Error="solar/close-circle-bold", Warning="solar/danger-bold", Info="solar/info-circle-bold" }
    local soundMap = { Success=Aurora.Sounds.Success, Error=Aurora.Sounds.Error, Warning=Aurora.Sounds.Warning, Info=Aurora.Sounds.Info }
    local accent = accentMap[typ] or thm.Accent
    local function playSound(soundId)
        if cfg.PlaySound == false or not Aurora.SoundEnabled then return end
        if not soundId or soundId == 0 or tostring(soundId) == "0" then return end
        task.spawn(function()
            local s = make("Sound", {
                SoundId = "rbxassetid://" .. tostring(soundId),
                Volume = cfg.Volume or 0.4,
                Parent = SoundService
            })
            s:Play()
            task.wait(1.5)
            s:Destroy()
        end)
    end
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
        LayoutOrder=-tick(),
    })
    if acrylicEnabled then
        createAcrylic(card)
    end
    make("UICorner", { CornerRadius=sz(18), Parent=card })
    -- Diseno limpio: sin barra lateral, sin hairline; icono circular con halo de acento
    local cardStroke = make("UIStroke", { Color=thm.Border, Thickness=1, Transparency=0.45, Parent=card })
    local gradient = make("UIGradient", {
        Color = ColorSequence.new({
            ColorSequenceKeypoint.new(0, accent),
            ColorSequenceKeypoint.new(0.32, thm.Border),
            ColorSequenceKeypoint.new(1, thm.Border),
        }),
        Parent = cardStroke,
    })
    local iconHalo = make("Frame", {
        Size=ss(38,38), AnchorPoint=Vector2.new(0,0), Position=UDim2.new(0,s(9),0,s(10)),
        BackgroundColor3=accent, BackgroundTransparency=0.9, BorderSizePixel=0, Parent=card,
    })
    make("UICorner", { CornerRadius=UDim.new(1,0), Parent=iconHalo })
    local iconFrame = make("Frame", {
        Size=ss(32,32), AnchorPoint=Vector2.new(0,0), Position=UDim2.new(0,s(12),0,s(13)),
        BackgroundColor3=accent, BackgroundTransparency=0.7, BorderSizePixel=0, Parent=card,
    })
    make("UICorner", { CornerRadius=UDim.new(1,0), Parent=iconFrame })
    local iconStroke = make("UIStroke", { Color=accent, Thickness=1.5, Transparency=0.3, Parent=iconFrame })
    local iconScale = make("UIScale", { Scale=1, Parent=iconFrame })
    local notifIco = make("ImageLabel", {
        Size=ss(16,16), AnchorPoint=Vector2.new(0.5,0.5), Position=UDim2.fromScale(0.5,0.5),
        BackgroundTransparency=1, Parent=iconFrame,
    })
    applyIcon(notifIco, cfg.Icon or iconMap[typ] or "solar/info-circle-bold", accent)
    -- (icono estatico y limpio; se quito el pulso constante que se veia busy)
    local txtF = make("Frame", {
        Size=UDim2.new(1,-s(102),0,0), Position=UDim2.new(0,s(50),0,s(12)),
        BackgroundTransparency=1, AutomaticSize=Enum.AutomaticSize.Y, Parent=card,
    })
    make("UIListLayout", { SortOrder=Enum.SortOrder.LayoutOrder, Padding=sz(2), Parent=txtF })
    local titleLbl = make("TextLabel", {
        Size=UDim2.new(1,0,0,s(4)), AutomaticSize=Enum.AutomaticSize.Y,
        BackgroundTransparency=1, Text=cfg.Title or "Notification",
        TextColor3=thm.Text, TextSize=fs(14), Font=Enum.Font.GothamBold,
        TextXAlignment=Enum.TextXAlignment.Left, TextWrapped=true, RichText=true, Parent=txtF,
    })
    local contentText = cfg.Content or cfg.SubContent or cfg.Message or cfg.Description or cfg.Text or ""
    local contentLbl = make("TextLabel", {
        Size=UDim2.new(1,0,0,s(4)), AutomaticSize=Enum.AutomaticSize.Y,
        BackgroundTransparency=1, Text=contentText,
        TextColor3=thm.SubText, TextSize=fs(11), Font=Enum.Font.Gotham,
        TextXAlignment=Enum.TextXAlignment.Left, TextWrapped=true, RichText=true, Parent=txtF,
        Visible = contentText ~= ""
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
            tw(iconScale, { Scale = 0.82 }, 0.2, Enum.EasingStyle.Quad, Enum.EasingDirection.In)
        end)
        task.delay(0.26, function()
            pcall(function() card:Destroy() end)
            processNotifQueue()
        end)
    end
    local function addHoverScale(btn)
        local scale = make("UIScale", { Scale = 1, Parent = btn })
        btn.MouseEnter:Connect(function() if _isMobile then return end
            tw(scale, { Scale = 1.02 }, 0.12, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
        end)
        btn.MouseLeave:Connect(function() if _isMobile then return end
            tw(scale, { Scale = 1.0 }, 0.12, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
        end)
    end
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
                local _isPrimary = (idx == 1)
                local _baseCol = _isPrimary and accent or thm.Element
                local button = make("TextButton", {
                    Size = UDim2.new(0, s(74), 1, 0),
                    BackgroundColor3 = _baseCol,
                    BackgroundTransparency = _isPrimary and 0 or 0.15,
                    AutoButtonColor = false,
                    Text = btnCfg.Title or "Button",
                    TextColor3 = _isPrimary and Color3.fromRGB(255,255,255) or thm.Text,
                    TextSize = fs(10),
                    Font = Enum.Font.GothamBold,
                    Parent = btnContainer
                })
                make("UICorner", { CornerRadius = sz(8), Parent = button })
                local bStroke = make("UIStroke", { Color = _isPrimary and accent or thm.Border, Thickness = 1, Transparency = _isPrimary and 1 or 0.3, Parent = button })
                addHoverScale(button)
                button.MouseEnter:Connect(function() if _isMobile then return end 
                    if _isPrimary then
                        tw(button, { BackgroundColor3 = accent:Lerp(Color3.new(1,1,1), 0.15) }, 0.1)
                    else
                        tw(button, { BackgroundColor3 = thm.ElementHover, BackgroundTransparency = 0 }, 0.1)
                        tw(bStroke, { Color = accent, Transparency = 0.1 }, 0.1)
                    end
                end)
                button.MouseLeave:Connect(function() if _isMobile then return end 
                    tw(button, { BackgroundColor3 = _baseCol, BackgroundTransparency = _isPrimary and 0 or 0.15 }, 0.1)
                    if not _isPrimary then tw(bStroke, { Color = thm.Border, Transparency = 0.3 }, 0.1) end
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
    local copyBtn = makeControlBtn(s(28))
    local cIco = make("ImageLabel", { Size=ss(8,8), AnchorPoint=Vector2.new(0.5,0.5), Position=UDim2.fromScale(0.5,0.5), BackgroundTransparency=1, Parent=closeBtn })
    local cpIco= make("ImageLabel", { Size=ss(8,8), AnchorPoint=Vector2.new(0.5,0.5), Position=UDim2.fromScale(0.5,0.5), BackgroundTransparency=1, Parent=copyBtn })
    applyIcon(cIco,  "solar/close-linear",  thm.SubText)
    applyIcon(cpIco, "solar/copy-linear",   thm.SubText)
    local pTrack = make("Frame", {
        AnchorPoint=Vector2.new(0.5,1), Size=UDim2.new(1,-s(24),0,s(2)), Position=UDim2.new(0.5,0,1,-s(6)),
        BackgroundColor3=thm.Border, BackgroundTransparency=0.8, BorderSizePixel=0, Parent=card,
    })
    local pFill = make("Frame", { Size=UDim2.new(1,0,1,0), BackgroundColor3=accent, BackgroundTransparency=0.1, BorderSizePixel=0, Parent=pTrack })
    make("UICorner", { CornerRadius=UDim.new(1,0), Parent=pTrack })
    make("UICorner", { CornerRadius=UDim.new(1,0), Parent=pFill })
    closeBtn.MouseButton1Click:Connect(closeNotif)
    copyBtn.MouseButton1Click:Connect(function()
        local t = tostring(titleLbl.Text or "")
        if contentLbl.Visible and contentLbl.Text ~= "" then t = t.."\n"..tostring(contentLbl.Text) end
        pcall(function() toclipboard(t) end)
    end)
    closeBtn.MouseEnter:Connect(function() if _isMobile then return end tw(closeBtn,{BackgroundTransparency=0.4,BackgroundColor3=Color3.fromRGB(200,50,50)},0.1) end)
    closeBtn.MouseLeave:Connect(function() if _isMobile then return end tw(closeBtn,{BackgroundTransparency=1},0.1) end)
    copyBtn.MouseEnter:Connect(function() if _isMobile then return end tw(copyBtn,{BackgroundTransparency=0.4,BackgroundColor3=thm.ElementHover},0.1) end)
    copyBtn.MouseLeave:Connect(function() if _isMobile then return end tw(copyBtn,{BackgroundTransparency=1},0.1) end)
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
    local autoCloseThread
    local pTween
    local function startAutoClose(customDur)
        if autoCloseThread then
            pcall(task.cancel, autoCloseThread)
            autoCloseThread = nil
        end
        local d = customDur
        if d == nil then d = dur end
        d = math.max(tonumber(d) or 0, 0)
        if d and d > 0 then
            pFill.Size = UDim2.new(1, 0, 1, 0)
            pTween = tw(pFill, { Size = UDim2.new(0, 0, 1, 0) }, d, Enum.EasingStyle.Linear)
            autoCloseThread = task.delay(d, function()
                if not closed then closeNotif() end
            end)
        else
            pFill.Size = UDim2.new(0, 0, 1, 0)
        end
    end
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
                ColorSequenceKeypoint.new(0.35, (Aurora.Theme or Aurora.Themes.Dark).Border),
                ColorSequenceKeypoint.new(1,  (Aurora.Theme or Aurora.Themes.Dark).Border),
            })
        end)
    end
    local controller = {}
    function controller:Update(newCfg)
        if closed then return end
        newCfg = newCfg or {}
        local currentThm = Aurora.Theme or Aurora.Themes.Dark
        if newCfg.Type or newCfg.Icon then
            local newTyp = tostring(newCfg.Type or typ)
            newTyp = newTyp:sub(1, 1):upper() .. newTyp:sub(2):lower()
            local newAccent = accentMap[newTyp] or currentThm.Accent
            local newIcon = newCfg.Icon or iconMap[newTyp] or "solar/info-circle-bold"
            updateIcon(newIcon, newAccent)
            updateGradient(newAccent)
            if newCfg.Type and newCfg.Type ~= typ then
                local newSoundId = newCfg.SoundId or soundMap[newTyp] or 0
                playSound(newSoundId)
            end
            typ = newTyp
            accent = newAccent
        end
        if newCfg.Title then
            updateText(titleLbl, newCfg.Title)
        end
        if newCfg.Content or newCfg.SubContent or newCfg.Message or newCfg.Description or newCfg.Text then
            updateText(contentLbl, newCfg.Content or newCfg.SubContent or newCfg.Message or newCfg.Description or newCfg.Text)
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
            dur = math.max(tonumber(newCfg.Duration) or 0, 0)
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
    card.MouseEnter:Connect(function()
        if _isMobile or closed then return end
        tw(iconScale, { Scale = 1.08 }, 0.18, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
        tw(cardStroke, { Transparency = 0.18 }, 0.18)
        if autoCloseThread then pcall(task.cancel, autoCloseThread); autoCloseThread = nil end
        if pTween then pcall(function() pTween:Cancel() end) end
    end)
    card.MouseLeave:Connect(function()
        if _isMobile or closed then return end
        tw(iconScale, { Scale = 1 }, 0.18, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
        tw(cardStroke, { Transparency = 0.45 }, 0.18)
        local total = dur
        if not total or total <= 0 then return end
        local ratio = math.clamp(pFill.Size.X.Scale, 0, 1)
        local remaining = total * ratio
        if remaining <= 0.05 then closeNotif(); return end
        pTween = tw(pFill, { Size = UDim2.new(0, 0, 1, 0) }, remaining, Enum.EasingStyle.Linear)
        if autoCloseThread then pcall(task.cancel, autoCloseThread) end
        autoCloseThread = task.delay(remaining, function() if not closed then closeNotif() end end)
    end)
    local notifObj = {
        Card = card,
        Show = function()
            playSound(cfg.SoundId or soundMap[typ] or 0)
            card.Parent = _nHolder
            card.Position = UDim2.new(1, s(320), 0, 0)
            card.BackgroundTransparency = 1
            iconScale.Scale = 0.72
            tw(iconScale, { Scale = 1 }, 0.42, Enum.EasingStyle.Back, Enum.EasingDirection.Out)
            tw(card, { Position=UDim2.new(0,0,0,0), BackgroundTransparency=(acrylicEnabled and 0.45 or 0) }, 0.6, Enum.EasingStyle.Back, Enum.EasingDirection.Out)
            startAutoClose(dur)
        end
    }
    table.insert(_notifQueue, notifObj)
    processNotifQueue()
    return controller
end
function processNotifQueue()
    if #_activeNotifs >= 3 then return end
    if #_notifQueue == 0 then return end
    local nextNotif = table.remove(_notifQueue, 1)
    table.insert(_activeNotifs, nextNotif)
    pcall(nextNotif.Show)
end
-- Ripple effect on click (material-design style)
local function createRipple(parent, input)
    if _isMobile then return end
    if not Aurora.RippleEnabled then return end
    local absPos = parent.AbsolutePosition
    local absSize = parent.AbsoluteSize
    local mx = (input and input.Position and input.Position.X or (absPos.X + absSize.X / 2)) - absPos.X
    local my = (input and input.Position and input.Position.Y or (absPos.Y + absSize.Y / 2)) - absPos.Y
    local maxDist = math.max(
        math.sqrt(mx^2 + my^2),
        math.sqrt((absSize.X - mx)^2 + my^2),
        math.sqrt(mx^2 + (absSize.Y - my)^2),
        math.sqrt((absSize.X - mx)^2 + (absSize.Y - my)^2)
    ) * 2
    local ripple = make("Frame", {
        Size = UDim2.fromOffset(0, 0),
        Position = UDim2.fromOffset(mx, my),
        AnchorPoint = Vector2.new(0.5, 0.5),
        BackgroundColor3 = (Aurora.Theme or Aurora.Themes.Dark).Accent,
        BackgroundTransparency = 0.75,
        BorderSizePixel = 0,
        ZIndex = 50,
        Parent = parent,
    })
    make("UICorner", { CornerRadius = UDim.new(1, 0), Parent = ripple })
    tw(ripple, { Size = UDim2.fromOffset(maxDist, maxDist), BackgroundTransparency = 1 }, 0.45, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
    task.delay(0.5, function()
        pcall(function() ripple:Destroy() end)
    end)
end
Aurora.RippleEnabled = true

-- Hover scale micro-interaction
local function addHoverScale(frame, scale)
    if _isMobile then return end
    scale = scale or 1.015
    local uiScale = frame:FindFirstChildOfClass("UIScale")
    if not uiScale then
        uiScale = make("UIScale", { Scale = 1, Parent = frame })
    end
    frame.MouseEnter:Connect(function()
        if _isMobile then return end
        tw(uiScale, { Scale = scale }, 0.12, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
    end)
    frame.MouseLeave:Connect(function()
        if _isMobile then return end
        tw(uiScale, { Scale = 1 }, 0.16, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
    end)
end

local function registerHover(f, hoverTrigger)
    local stroke = f:FindFirstChildOfClass("UIStroke")
    local normalTransparency = f.BackgroundTransparency
    local hovered = false
    hoverTrigger.MouseEnter:Connect(function() if _isMobile then return end
        if _isMobile or (UserInputService:GetLastInputType() == Enum.UserInputType.Touch) then return end
        if hovered then return end
        hovered = true
        local currentThm = Aurora.Theme or Aurora.Themes.Dark
        tw(f, { BackgroundColor3 = currentThm.ElementHover, BackgroundTransparency = 0.08 }, 0.12)
        if stroke then
            tw(stroke, { Color = currentThm.Accent, Transparency = 0.35 }, 0.12)
        end
    end)
    hoverTrigger.MouseLeave:Connect(function() if _isMobile then return end
        if not hovered then return end
        hovered = false
        local currentThm = Aurora.Theme or Aurora.Themes.Dark
        tw(f, { BackgroundColor3 = currentThm.Element, BackgroundTransparency = normalTransparency }, 0.18)
        if stroke then
            tw(stroke, { Color = currentThm.Border, Transparency = 0.55 }, 0.18)
        end
    end)
end
local _elemCounter = 0
local function elemFrame(parent)
    local f = make(Aurora.FadeIn and "CanvasGroup" or "Frame", {
        Size=UDim2.new(1,0,0,s(4)), AutomaticSize=Enum.AutomaticSize.Y,
        BackgroundColor3=Aurora.Theme.Element, BackgroundTransparency=0.2, BorderSizePixel=0, Parent=parent,
    })
    make("UICorner", { CornerRadius=sz(9), Parent=f })
    make("UIPadding", { PaddingTop=sz(9), PaddingBottom=sz(9), PaddingLeft=sz(11), PaddingRight=sz(11), Parent=f })
    make("UIListLayout", { SortOrder=Enum.SortOrder.LayoutOrder, Padding=sz(6), Parent=f })
    reg(f, "BackgroundColor3", "Element")
    local stroke = make("UIStroke", {
        Color = Aurora.Theme.Border,
        Thickness = 1,
        Transparency = 0.55,
        Parent = f
    })
    reg(stroke, "Color", "Border")
    if Aurora.FadeIn then
        f.GroupTransparency = 1
        if Aurora.LazyLoad then
            _elemCounter = _elemCounter + 1
            local delay = _elemCounter * (Aurora.DelayPerElement or 0.012)
            task.delay(delay, function()
                if f and f.Parent then
                    tw(f, { GroupTransparency = 0 }, 0.28, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
                end
            end)
        else
            tw(f, { GroupTransparency = 0 }, 0.28, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
        end
    end
    return f
end
local function createColorpickerPanel(parentFrame, cpObj, cpCfg, colDisp)
    local thm = Aurora.Theme
    local panel = make("Frame", {
        Size = UDim2.new(1, 0, 0, 0),
        ClipsDescendants = true,
        BackgroundTransparency = 1,
        LayoutOrder = 2,
        Parent = parentFrame,
    })
    local pickerConnections = {}
    local function trackPickerConnection(connection)
        table.insert(pickerConnections, connection)
        return connection
    end
    panel.Destroying:Connect(function()
        for _, connection in ipairs(pickerConnections) do
            pcall(function() connection:Disconnect() end)
        end
        table.clear(pickerConnections)
    end)
    local currentH, currentS, currentV = cpObj.Value:ToHSV()
    local currentA = 1
    local originalColor = cpObj.Value
    local mainRow = make("Frame", {
        Size = UDim2.new(1, 0, 0, s(120)),
        Position = UDim2.new(0, 0, 0, s(4)),
        BackgroundTransparency = 1,
        Parent = panel,
    })
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
    local hueBar = make("TextButton", {
        Size = UDim2.new(0, s(12), 1, 0),
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
    local inputsFrame = make("Frame", {
        Size = UDim2.new(0.50, -s(20), 1, 0),
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
    local hexBox = makeInputRow("Hex",   "#"..colorToHex(cpObj.Value),              1)
    local rBox = makeInputRow("Red",   tostring(math.floor(cpObj.Value.R*255+.5)),2)
    local gBox = makeInputRow("Green", tostring(math.floor(cpObj.Value.G*255+.5)),3)
    local bBox = makeInputRow("Blue",  tostring(math.floor(cpObj.Value.B*255+.5)),4)
    local alphaBox = makeInputRow("Alpha", "100%",                                    5)
    local swatchRow = make("Frame", {
        Size = UDim2.new(0.50, -s(4), 0, s(14)),
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
        hexBox.Text = "#"..colorToHex(color)
        rBox.Text = tostring(math.floor(color.R*255+.5))
        gBox.Text = tostring(math.floor(color.G*255+.5))
        bBox.Text = tostring(math.floor(color.B*255+.5))
        alphaBox.Text = tostring(math.floor(currentA*100+.5)).."%"
        if cpCfg.Callback then pcall(cpCfg.Callback, color) end
        if cpCfg.OnTransparencyChanged then pcall(cpCfg.OnTransparencyChanged, 1-currentA) end
        triggerAutosave()
    end
    local canvasDrag = false
    local hueDrag = false
    canvasBtn.InputBegan:Connect(function(i)
        if i.UserInputType==Enum.UserInputType.MouseButton1 then
            canvasDrag=true
            local rx = math.clamp((i.Position.X-canvasHolder.AbsolutePosition.X)/canvasHolder.AbsoluteSize.X,0,1)
            local ry = math.clamp((i.Position.Y-canvasHolder.AbsolutePosition.Y)/canvasHolder.AbsoluteSize.Y,0,1)
            currentS=rx; currentV=1-ry; refreshCanvas(); applyColor()
        end
    end)
    hueBar.InputBegan:Connect(function(i)
        if i.UserInputType==Enum.UserInputType.MouseButton1 then
            hueDrag=true
            currentH=math.clamp((i.Position.Y-hueBar.AbsolutePosition.Y)/hueBar.AbsoluteSize.Y,0,1)
            refreshCanvas(); applyColor()
        end
    end)
    trackPickerConnection(UserInputService.InputChanged:Connect(function(i)
        if i.UserInputType==Enum.UserInputType.MouseMovement then
            if canvasDrag then
                local rx = math.clamp((i.Position.X-canvasHolder.AbsolutePosition.X)/canvasHolder.AbsoluteSize.X,0,1)
                local ry = math.clamp((i.Position.Y-canvasHolder.AbsolutePosition.Y)/canvasHolder.AbsoluteSize.Y,0,1)
                currentS=rx; currentV=1-ry; refreshCanvas(); applyColor()
            end
            if hueDrag then
                currentH=math.clamp((i.Position.Y-hueBar.AbsolutePosition.Y)/hueBar.AbsoluteSize.Y,0,1)
                refreshCanvas(); applyColor()
            end
        end
    end))
    trackPickerConnection(UserInputService.InputEnded:Connect(function(i)
        if i.UserInputType==Enum.UserInputType.MouseButton1 then canvasDrag=false; hueDrag=false end
    end))
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
Aurora.MobileKeybindButtons = true
local function _createMobileKeybind(title, onToggleCallback)
    if not (_isMobile or Aurora.MobileButtonOverride) then
        return nil, nil, nil
    end
    if Aurora.MobileKeybindButtons == false then
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
    local btnSize = s(44)
    local yOffset = s(160) + (_mobileKeybindCount - 1) * (btnSize + s(8))
    local defaultPos = UDim2.new(1, -(btnSize + s(12)), 0, yOffset)
    local mobileBtn = make("TextButton", {
        Name = "MobileKeybind_" .. title,
        Size = UDim2.fromOffset(btnSize, btnSize),
        Position = defaultPos,
        BackgroundColor3 = thm.Background,
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
    local dot = make("Frame", {
        Size = UDim2.fromOffset(s(6), s(6)),
        AnchorPoint = Vector2.new(0.5, 1),
        Position = UDim2.new(0.5, 0, 1, -s(4)),
        BackgroundColor3 = thm.Border,
        BorderSizePixel = 0,
        ZIndex = 202,
        Parent = mobileBtn,
    })
    make("UICorner", { CornerRadius = UDim.new(1, 0), Parent = dot })
    local shortText = title or "Btn"
    if #shortText > 4 then shortText = shortText:sub(1, 4) end
    local mobileLbl = make("TextLabel", {
        Size = UDim2.new(1, -s(4), 1, -s(12)),
        Position = UDim2.new(0, s(2), 0, s(2)),
        BackgroundTransparency = 1,
        Text = shortText:upper(),
        TextColor3 = thm.SubText,
        TextSize = fs(11),
        Font = Enum.Font.GothamBold,
        TextXAlignment = Enum.TextXAlignment.Center,
        TextWrapped = true,
        ZIndex = 202,
        Parent = mobileBtn
    })
    local mScale = make("UIScale", { Scale = 1.0, Parent = mobileBtn })
    mobileBtn.InputBegan:Connect(function(i)
        if i.UserInputType == Enum.UserInputType.Touch or i.UserInputType == Enum.UserInputType.MouseButton1 then
            tw(mScale, { Scale = 0.9 }, 0.08, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
        end
    end)
    mobileBtn.InputEnded:Connect(function(i)
        if i.UserInputType == Enum.UserInputType.Touch or i.UserInputType == Enum.UserInputType.MouseButton1 then
            tw(mScale, { Scale = 1.0 }, 0.12, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
        end
    end)
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
    local kbChanged = UserInputService.InputChanged:Connect(function(input)
        if kbDrag and (input.UserInputType == Enum.UserInputType.Touch or input.UserInputType == Enum.UserInputType.MouseMovement) then
            local delta = input.Position - kbDragStart
            kbDragDist = delta.Magnitude
            mobileBtn.Position = UDim2.new(
                kbStartPos.X.Scale, kbStartPos.X.Offset + delta.X,
                kbStartPos.Y.Scale, kbStartPos.Y.Offset + delta.Y
            )
        end
    end)
    local kbEnded = UserInputService.InputEnded:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.Touch or input.UserInputType == Enum.UserInputType.MouseButton1 then
            kbDrag = false
        end
    end)
    mobileBtn.Destroying:Connect(function()
        pcall(function() kbChanged:Disconnect() end)
        pcall(function() kbEnded:Disconnect() end)
    end)
    mobileBtn.MouseButton1Click:Connect(function()
        if kbDragDist < 8 then
            pcall(onToggleCallback)
        end
    end)
    return mobileBtn, mobileStroke, mobileLbl, dot
end
local Section = {}
Section.__index = Section
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
    local desc = cfg.Description
    local def = cfg.Default or false
    local cb = cfg.Callback or function() end
    local thm = Aurora.Theme
    local obj = { Type="Toggle", Value=def, id=id }
    local f = elemFrame(self.Container)
    addTooltip(f, cfg.Tooltip)
    local topF = make("Frame", { Size=UDim2.new(1,0,0,s(4)), AutomaticSize=Enum.AutomaticSize.Y, BackgroundTransparency=1, LayoutOrder=1, Parent=f })
    local _rsv = self._compact and s(62) or s(130)
    local txtF = make("Frame", { Size=UDim2.new(1,-_rsv,0,0), AutomaticSize=Enum.AutomaticSize.Y, BackgroundTransparency=1, Parent=topF })
    make("UIListLayout", { SortOrder=Enum.SortOrder.LayoutOrder, Padding=sz(3), Parent=txtF })
    local tx = 0
    if cfg.Icon then
        local ico = make("ImageLabel",{Size=ss(16,16),BackgroundTransparency=1,Parent=txtF,LayoutOrder=-1})
        applyIcon(ico, cfg.Icon, thm.IconColor); tx=s(22)
    end
    make("TextLabel", {
        Size=UDim2.new(1,-tx,0,0), Position=UDim2.new(0,tx,0,0), AutomaticSize=Enum.AutomaticSize.Y,
        BackgroundTransparency=1, Text=title, TextColor3=thm.Text, TextSize=(self._compact and fs(13) or fs(14)),
        Font=Enum.Font.GothamBold, TextXAlignment=Enum.TextXAlignment.Left, TextWrapped=(not self._compact), TextTruncate=(self._compact and Enum.TextTruncate.AtEnd or Enum.TextTruncate.None), Parent=txtF,
    })
    if desc then
        make("TextLabel", {
            Size=UDim2.new(1,-tx,0,0), Position=UDim2.new(0,tx,0,0), AutomaticSize=Enum.AutomaticSize.Y,
            BackgroundTransparency=1, Text=desc, TextColor3=thm.SubText, TextSize=fs(11),
            Font=Enum.Font.Gotham, TextXAlignment=Enum.TextXAlignment.Left, TextWrapped=(not self._compact), TextTruncate=(self._compact and Enum.TextTruncate.AtEnd or Enum.TextTruncate.None), Parent=txtF,
        })
    end
    local rightControls = make("Frame", {
        Size=UDim2.new(0,0,1,0), AutomaticSize=Enum.AutomaticSize.X,
        AnchorPoint=Vector2.new(1,0.5), Position=UDim2.new(1,0,0.5,0),
        BackgroundTransparency=1, ZIndex=5, Parent=topF,
    })
    if _isMobile then
        topF.Size=UDim2.new(1,0,0,s(26))
        rightControls.Size=UDim2.new(0,0,0,s(24))
        rightControls.AnchorPoint=Vector2.new(1,0)
        rightControls.Position=UDim2.new(1,0,0,0)
        local function fitToggleTitle()
            local scale=1
            local ancestor=rightControls.Parent
            while ancestor and ancestor:IsA("GuiObject") do
                local uiScale=ancestor:FindFirstChildOfClass("UIScale")
                if uiScale then scale=scale*uiScale.Scale end
                ancestor=ancestor.Parent
            end
            txtF.Size=UDim2.new(1,-math.max(s(48),rightControls.AbsoluteSize.X/math.max(scale,0.01)+s(10)),0,0)
        end
        rightControls:GetPropertyChangedSignal("AbsoluteSize"):Connect(fitToggleTitle)
        fitToggleTitle()
    end
    make("UIListLayout", {
        FillDirection=Enum.FillDirection.Horizontal, HorizontalAlignment=Enum.HorizontalAlignment.Right,
        VerticalAlignment=Enum.VerticalAlignment.Center, SortOrder=Enum.SortOrder.LayoutOrder, Padding=sz(8),
        Parent=rightControls,
    })
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
    local pillGloss = make("Frame", {
        Size=UDim2.new(1,-s(2),0,s(8)),
        Position=UDim2.new(0,s(1),0,s(1)),
        BackgroundColor3=Color3.fromRGB(255,255,255),
        BackgroundTransparency=0.88, BorderSizePixel=0, ZIndex=7,
        Parent=pill,
    })
    make("UICorner", { CornerRadius=UDim.new(1,0), Parent=pillGloss })
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
    pill.MouseButton1Click:Connect(function() Aurora:PlaySound("Toggle") set(not obj.Value) end)
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
    local btn = pill
    if not _isMobile then
        -- Mobile uses the pill; a full-height sibling creates an autosize cycle.
        btn = make("TextButton", {
            Size=UDim2.new(1,-s(170),1,0), BackgroundTransparency=1, Text="", ZIndex=1, Parent=topF,
        })
        btn.MouseButton1Click:Connect(function() Aurora:PlaySound("Toggle") set(not obj.Value) end)
    end
    registerHover(f, btn)
    function obj:SetValue(v) set(v, false) end
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
    function obj:AddKeybind(kbId, kbCfg)
        kbCfg = kbCfg or {}
        local defaultKey = kbCfg.Default or Enum.KeyCode.None
        local kbObj = { Type="Keybind", Value=defaultKey, id=kbId, ToggleParent=obj }
        local binding = false
        local kbBtn = make("TextButton", {
            Size=UDim2.new(0, s(55), 0, s(20)), AutomaticSize=Enum.AutomaticSize.X,
            BackgroundColor3=thm.InputBG,
            Text=defaultKey==Enum.KeyCode.None and "None" or defaultKey.Name,
            TextColor3=thm.SubText, TextSize=fs(11), Font=Enum.Font.GothamBold,
            LayoutOrder=5, ZIndex=10, Parent=rightControls,
        })
        make("UICorner", { CornerRadius=sz(8), Parent=kbBtn })
        local kbStroke = make("UIStroke", { Color=thm.Border, Thickness=1, Parent=kbBtn })
        make("UIPadding", { PaddingLeft=sz(6), PaddingRight=sz(6), Parent=kbBtn })
        local mobileBtn, mobileStroke, mobileLbl, mobileDot = _createMobileKeybind(kbCfg.Title or cfg.Title or title or "Toggle", function()
            set(not obj.Value)
        end)
        local function updateVisualState()
            if binding then return end
            local currentThm = Aurora.Theme or Aurora.Themes.Dark
            local active = obj.Value
            local activeColor = currentThm.AlertSuccess
            local activeBG = currentThm.Background:Lerp(currentThm.AlertSuccess, 0.22)
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
                    tw(mobileBtn, { BackgroundColor3 = currentThm.Background }, 0.12)
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
            elseif type(key) == "table" and key.KeyCode then
                local text = ""
                if key.Ctrl then text = text .. "Ctrl+" end
                if key.Shift then text = text .. "Shift+" end
                if key.Alt then text = text .. "Alt+" end
                if typeof(key.KeyCode) == "EnumItem" then
                    if key.KeyCode.EnumType == Enum.KeyCode then
                        text = text .. (key.KeyCode == Enum.KeyCode.None and "None" or key.KeyCode.Name)
                    elseif key.KeyCode.EnumType == Enum.UserInputType then
                        text = text .. key.KeyCode.Name:gsub("MouseButton", "MB")
                    end
                else
                    text = text .. "None"
                end
                kbBtn.Text = text
            else
                kbBtn.Text = "None"
            end
            triggerAutosave()
            if Aurora.RefreshKeybindList then task.defer(Aurora.RefreshKeybindList) end
        end
        local function isModifierKey(keycode)
            return keycode == Enum.KeyCode.LeftControl or keycode == Enum.KeyCode.RightControl
                or keycode == Enum.KeyCode.LeftShift or keycode == Enum.KeyCode.RightShift
                or keycode == Enum.KeyCode.LeftAlt or keycode == Enum.KeyCode.RightAlt
        end
        local bindConn, bindEndConn
        kbBtn.MouseButton1Click:Connect(function()
            if binding then return end
            binding=true; kbBtn.Text="..."; kbBtn.TextColor3=thm.Accent
            task.spawn(function()
                task.wait()
                local function clean()
                    pcall(function() if bindConn then bindConn:Disconnect() end end)
                    pcall(function() if bindEndConn then bindEndConn:Disconnect() end end)
                    bindConn=nil; bindEndConn=nil
                    binding=false
                    kbBtn.TextColor3=thm.SubText
                end
                bindConn = UserInputService.InputBegan:Connect(function(input)
                    local key = input.KeyCode
                    local utype = input.UserInputType
                    if utype == Enum.UserInputType.Keyboard then
                        if isModifierKey(key) then
                            local ctrl = UserInputService:IsKeyDown(Enum.KeyCode.LeftControl) or UserInputService:IsKeyDown(Enum.KeyCode.RightControl)
                            local shift = UserInputService:IsKeyDown(Enum.KeyCode.LeftShift) or UserInputService:IsKeyDown(Enum.KeyCode.RightShift)
                            local alt = UserInputService:IsKeyDown(Enum.KeyCode.LeftAlt) or UserInputService:IsKeyDown(Enum.KeyCode.RightAlt)
                            kbBtn.Text = (ctrl and "Ctrl+" or "") .. (shift and "Shift+" or "") .. (alt and "Alt+" or "") .. "..."
                            return
                        end
                        clean()
                        if key == Enum.KeyCode.Escape then
                            updateKey(Enum.KeyCode.None)
                        else
                            local ctrl = UserInputService:IsKeyDown(Enum.KeyCode.LeftControl) or UserInputService:IsKeyDown(Enum.KeyCode.RightControl)
                            local shift = UserInputService:IsKeyDown(Enum.KeyCode.LeftShift) or UserInputService:IsKeyDown(Enum.KeyCode.RightShift)
                            local alt = UserInputService:IsKeyDown(Enum.KeyCode.LeftAlt) or UserInputService:IsKeyDown(Enum.KeyCode.RightAlt)
                            if ctrl or shift or alt then
                                updateKey({ KeyCode = key, Ctrl = ctrl, Shift = shift, Alt = alt })
                            else
                                updateKey(key)
                            end
                        end
                        if kbCfg.Callback then pcall(kbCfg.Callback, kbObj.Value) end
                    elseif utype == Enum.UserInputType.MouseButton1 or utype == Enum.UserInputType.MouseButton2 or utype == Enum.UserInputType.MouseButton3 then
                        clean()
                        local ctrl = UserInputService:IsKeyDown(Enum.KeyCode.LeftControl) or UserInputService:IsKeyDown(Enum.KeyCode.RightControl)
                        local shift = UserInputService:IsKeyDown(Enum.KeyCode.LeftShift) or UserInputService:IsKeyDown(Enum.KeyCode.RightShift)
                        local alt = UserInputService:IsKeyDown(Enum.KeyCode.LeftAlt) or UserInputService:IsKeyDown(Enum.KeyCode.RightAlt)
                        if ctrl or shift or alt then
                            updateKey({ KeyCode = utype, Ctrl = ctrl, Shift = shift, Alt = alt })
                        else
                            updateKey(utype)
                        end
                        if kbCfg.Callback then pcall(kbCfg.Callback, kbObj.Value) end
                    end
                end)
                bindEndConn = UserInputService.InputEnded:Connect(function(input)
                    if binding and input.UserInputType == Enum.UserInputType.Keyboard and isModifierKey(input.KeyCode) then
                        local ctrl = UserInputService:IsKeyDown(Enum.KeyCode.LeftControl) or UserInputService:IsKeyDown(Enum.KeyCode.RightControl)
                        local shift = UserInputService:IsKeyDown(Enum.KeyCode.LeftShift) or UserInputService:IsKeyDown(Enum.KeyCode.RightShift)
                        local alt = UserInputService:IsKeyDown(Enum.KeyCode.LeftAlt) or UserInputService:IsKeyDown(Enum.KeyCode.RightAlt)
                        kbBtn.Text = (ctrl and "Ctrl+" or "") .. (shift and "Shift+" or "") .. (alt and "Alt+" or "") .. "..."
                    end
                end)
            end)
        end)
        f.Destroying:Connect(function()
            pcall(function() if bindConn then bindConn:Disconnect() end end)
            pcall(function() if bindEndConn then bindEndConn:Disconnect() end end)
            bindConn=nil; bindEndConn=nil; binding=false
        end)
        local inlineBegan = UserInputService.InputBegan:Connect(function(input,processed)
            if not processed and not binding then
                local target = kbObj.Value
                if typeof(target) == "EnumItem" then
                    if input.KeyCode==target or input.UserInputType==target then
                        set(not obj.Value)
                    end
                elseif type(target) == "table" and target.KeyCode then
                    local mainMatch = (input.KeyCode == target.KeyCode or input.UserInputType == target.KeyCode)
                    if mainMatch then
                        local ctrl = UserInputService:IsKeyDown(Enum.KeyCode.LeftControl) or UserInputService:IsKeyDown(Enum.KeyCode.RightControl)
                        local shift = UserInputService:IsKeyDown(Enum.KeyCode.LeftShift) or UserInputService:IsKeyDown(Enum.KeyCode.RightShift)
                        local alt = UserInputService:IsKeyDown(Enum.KeyCode.LeftAlt) or UserInputService:IsKeyDown(Enum.KeyCode.RightAlt)
                        if (ctrl == not not target.Ctrl) and (shift == not not target.Shift) and (alt == not not target.Alt) then
                            set(not obj.Value)
                        end
                    end
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
    applyPremiumConfig(obj, cfg)
    Aurora.Options[id]=obj
    return obj
end
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
    local min,max=tonumber(cfg.Min) or 0,tonumber(cfg.Max) or 100
    if max < min then min,max=max,min end
    local dec=tonumber(cfg.Decimals or cfg.Rounding) or 0
    local defaultValue=tonumber(cfg.Default)
    local obj={Type="Slider",Value=math.clamp(defaultValue or min,min,max),id=id}
    local f=elemFrame(self.Container)
    addTooltip(f, cfg.Tooltip)
    local topF=make("Frame",{Size=UDim2.new(1,0,0,s(20)),BackgroundTransparency=1,LayoutOrder=1,Parent=f})
    local tx=0
    if cfg.Icon then
        local ico=make("ImageLabel",{Size=ss(16,16),BackgroundTransparency=1,Parent=topF})
        applyIcon(ico,cfg.Icon,thm.IconColor); tx=s(22)
    end
    local _sTitle = make("TextLabel",{
        Size=UDim2.new(1,-tx-s(86),1,0),Position=UDim2.new(0,tx,0,0),
        BackgroundTransparency=1,Text=cfg.Title or "Slider",TextColor3=thm.Text,
        TextScaled=true,Font=Enum.Font.GothamBold,TextXAlignment=Enum.TextXAlignment.Left,Parent=topF,
    })
    make("UITextSizeConstraint",{MaxTextSize=fs(16),MinTextSize=9,Parent=_sTitle})
    local valBox=make("TextBox",{
        Size=ss(80,18),AnchorPoint=Vector2.new(1,0.5),Position=UDim2.new(1,0,0.5,0),
        BackgroundTransparency=1,Text=tostring(obj.Value)..(cfg.Suffix or ""),
        TextColor3=thm.SubText,TextScaled=true,Font=Enum.Font.GothamBold,
        TextXAlignment=Enum.TextXAlignment.Right,ClearTextOnFocus=false,Parent=topF,
    })
    make("UITextSizeConstraint",{MaxTextSize=fs(16),MinTextSize=9,Parent=valBox})
    if _isMobile then
        topF.AutomaticSize=Enum.AutomaticSize.Y
        topF.Size=UDim2.new(1,0,0,0)
        make("UIListLayout",{Padding=sz(6),SortOrder=Enum.SortOrder.LayoutOrder,Parent=topF})
        _sTitle.TextScaled=false
        _sTitle.TextSize=fs(14)
        _sTitle.TextWrapped=true
        _sTitle.AutomaticSize=Enum.AutomaticSize.Y
        _sTitle.Size=UDim2.new(1,-tx,0,0)
        _sTitle.LayoutOrder=1
        valBox.TextScaled=false
        valBox.TextSize=fs(13)
        valBox.Size=UDim2.new(1,0,0,s(24))
        valBox.LayoutOrder=2
    end
    local tr=make("Frame",{Size=UDim2.new(1,0,0,s(5)),LayoutOrder=2,BackgroundColor3=thm.SliderTrack,Parent=f})
    make("UICorner",{CornerRadius=UDim.new(1,0),Parent=tr})
    local fill=make("Frame",{Size=UDim2.new(0,0,1,0),BackgroundColor3=thm.SliderFill,Parent=tr})
    make("UICorner",{CornerRadius=UDim.new(1,0),Parent=fill})
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
    local valTip = make("Frame", {
        AutomaticSize = Enum.AutomaticSize.X, Size = ss(0, 22),
        AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.new(0, 0, 0, -s(12)),
        BackgroundColor3 = thm.Element, BackgroundTransparency = 1,
        ZIndex = 20, Visible = false, Parent = tr,
    })
    make("UICorner", { CornerRadius = sz(6), Parent = valTip })
    make("UIPadding", { PaddingLeft = sz(8), PaddingRight = sz(8), Parent = valTip })
    local valTipStroke = make("UIStroke", { Color = thm.Border, Thickness = 1, Transparency = 1, Parent = valTip })
    local valTipTxt = make("TextLabel", {
        AutomaticSize = Enum.AutomaticSize.X, Size = UDim2.new(0, 0, 1, 0),
        BackgroundTransparency = 1, Text = "", TextColor3 = thm.Text, TextTransparency = 1,
        TextSize = fs(11), Font = Enum.Font.GothamBold, ZIndex = 21, Parent = valTip,
    })
    local function update(x)
        local r=math.clamp((x-tr.AbsolutePosition.X)/math.max(tr.AbsoluteSize.X,1),0,1)
        local raw=min+(max-min)*r
        local val
        if cfg.Step and cfg.Step > 0 then
            val = min + math.floor(((raw - min)/cfg.Step) + 0.5) * cfg.Step
        else
            val = dec==0 and math.floor(raw+.5) or math.floor(raw*(10^dec)+.5)/(10^dec)
        end
        val = math.clamp(val, min, max)
        obj.Value=val
        if drag then
            fill.Size=UDim2.new(r,0,1,0)
            sliderKnob.Position=UDim2.new(r,0,0.5,0)
        else
            tw(fill, {Size=UDim2.new(r,0,1,0)}, 0.14)
            tw(sliderKnob, {Position=UDim2.new(r,0,0.5,0)}, 0.14)
        end
        valTip.Position = UDim2.new(r, 0, 0, -s(12))
        valTipTxt.Text = tostring(val)..(cfg.Suffix or "")
        valBox.Text=tostring(val)..(cfg.Suffix or "")
        if cfg.Callback then pcall(cfg.Callback,val) end
        triggerAutosave()
    end
    local drag=false
    local hitbox = make("TextButton", {
        Size=UDim2.new(1,0,1,s(20)), Position=UDim2.fromScale(0.5, 0.5), AnchorPoint=Vector2.new(0.5, 0.5),
        BackgroundTransparency=1, Text="", ZIndex=10, Parent=tr
    })
    hitbox.InputBegan:Connect(function(i)
        if i.UserInputType==Enum.UserInputType.MouseButton1 or i.UserInputType==Enum.UserInputType.Touch then
            drag=true; update(i.Position.X)
            tw(knobScale,{Scale=1.3},0.1,Enum.EasingStyle.Back)
            valTip.Visible = true
            tw(valTip, { BackgroundTransparency = 0.05 }, 0.12)
            tw(valTipStroke, { Transparency = 0.4 }, 0.12)
            tw(valTipTxt, { TextTransparency = 0 }, 0.12)
        end
    end)
    local sliderChanged = UserInputService.InputChanged:Connect(function(i) if drag and (i.UserInputType==Enum.UserInputType.MouseMovement or i.UserInputType==Enum.UserInputType.Touch) then update(i.Position.X) end end)
    local sliderEnded = UserInputService.InputEnded:Connect(function(i)
        if i.UserInputType==Enum.UserInputType.MouseButton1 or i.UserInputType==Enum.UserInputType.Touch then
            drag=false
            tw(knobScale,{Scale=1},0.12,Enum.EasingStyle.Back)
            tw(valTip, { BackgroundTransparency = 1 }, 0.15)
            tw(valTipStroke, { Transparency = 1 }, 0.15)
            tw(valTipTxt, { TextTransparency = 1 }, 0.15)
            task.delay(0.16, function() if not drag then valTip.Visible = false end end)
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
        if cfg.Step and cfg.Step > 0 then v = min + math.floor(((v - min)/cfg.Step) + 0.5) * cfg.Step end
        v=math.clamp(v,min,max); obj.Value=v
        local r=(v-min)/math.max(max-min,1e-6)
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
    applyPremiumConfig(obj, cfg)
    Aurora.Options[id]=obj
    return obj
end
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
        TextSize=fs(14),Font=Enum.Font.GothamBold,TextXAlignment=Enum.TextXAlignment.Left,Parent=header,
    })
    if cfg.Content and cfg.Content ~= "" then
        make("TextLabel",{
            Size=UDim2.new(1,0,0,0),AutomaticSize=Enum.AutomaticSize.Y,
            BackgroundTransparency=1,Text=cfg.Content,TextColor3=thm.SubText,
            TextSize=fs(11),Font=Enum.Font.Gotham,TextXAlignment=Enum.TextXAlignment.Left,TextWrapped=true,Parent=contentF,
        })
    end
    if Aurora.FadeIn then
        f.GroupTransparency = 1
        tw(f, { GroupTransparency = 0 }, 0.3, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
    end
    local obj = {Type = "Alert"}
    addVisibilityAPI(obj, f)
    return obj
end
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
        TextSize=fs(14),Font=Enum.Font.GothamBold,TextXAlignment=Enum.TextXAlignment.Left,Parent=topF,
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
function Section:AddPremiumButton(cfg)
    cfg = cfg or {}
    Aurora.PremiumLink = cfg.Link or cfg.Url or Aurora.PremiumLink
    local btnObj = self:AddButton({
        Title = Aurora.IsPremium and (cfg.PremiumText or "Premium Active") or "Premium Features",
        Icon = Aurora.IsPremium and (cfg.PremiumIcon or "solar/crown-bold") or (cfg.Icon or "solar/crown-bold"),
        Description = Aurora.IsPremium and (cfg.PremiumDescription or "All premium features unlocked!") or cfg.Description,
        Callback = function()
            if Aurora.IsPremium then
                Aurora:Notify({ Title = "Premium Active", Content = "You already have Premium access!", Type = "Success", Duration = 3 })
                if cfg.Callback then pcall(cfg.Callback) end
                return
            end
            if cfg.Link and cfg.Link ~= "" then
                pcall(function() local sc = setclipboard or toclipboard or set_clipboard; if sc then sc(cfg.Link) end end)
                pcall(function() Aurora:Notify({ Title = "Premium", Content = "Link copied to clipboard!", Type = "Info", Duration = 4 }) end)
            end
            if cfg.Callback then pcall(cfg.Callback) end
        end,
    })
    Aurora._premiumButtons = Aurora._premiumButtons or {}
    table.insert(Aurora._premiumButtons, btnObj)
    Aurora._refreshPremiumButtons = function()
        for _, b in ipairs(Aurora._premiumButtons) do
            pcall(function()
                if Aurora.IsPremium then
                    b:SetTitle(cfg.PremiumText or "Premium Active")
                    if type(b.SetDesc) == "function" then
                        b:SetDesc(cfg.PremiumDescription or "All premium features unlocked!")
                    end
                else
                    b:SetTitle((cfg.Title or "Premium Features") .. " (" .. (Aurora._premiumCount or 0) .. ")")
                    if type(b.SetDesc) == "function" and cfg.Description then
                        b:SetDesc(cfg.Description)
                    end
                end
            end)
        end
    end
    pcall(Aurora._refreshPremiumButtons)
    return btnObj
end
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
        tw(f, { GroupTransparency = 0 }, 0.3, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
    end
    local obj = {Type = "Separator"}
    addVisibilityAPI(obj, f)
    return obj
end
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
        TextSize=(self._compact and fs(13) or fs(14)),Font=Enum.Font.GothamBold,TextXAlignment=Enum.TextXAlignment.Left,TextWrapped=(not self._compact),TextTruncate=(self._compact and Enum.TextTruncate.AtEnd or Enum.TextTruncate.None),Parent=txtF,
    })
    local descLbl
    if cfg.Description or cfg.Desc then
        descLbl = make("TextLabel",{
            Size=UDim2.new(1,-tx,0,0),Position=UDim2.new(0,tx,0,0),AutomaticSize=Enum.AutomaticSize.Y,
            BackgroundTransparency=1,Text=cfg.Description or cfg.Desc,TextColor3=thm.SubText,
            TextSize=fs(11),Font=Enum.Font.Gotham,TextXAlignment=Enum.TextXAlignment.Left,TextWrapped=(not self._compact),TextTruncate=(self._compact and Enum.TextTruncate.AtEnd or Enum.TextTruncate.None),Parent=txtF,
        })
    end
    local arr=make("ImageLabel",{Size=ss(14,14),AnchorPoint=Vector2.new(1,0.5),Position=UDim2.new(1,0,0.5,0),BackgroundTransparency=1,Parent=topF})
    applyIcon(arr,"solar/alt-arrow-right-bold",thm.Accent)
    local btn=make("TextButton",{Size=UDim2.new(1,0,1,0),BackgroundTransparency=1,Text="",Parent=topF})
    btn.MouseEnter:Connect(function() if _isMobile then return end
        tw(arr,{Position=UDim2.new(1,-s(3),0.5,0)},0.14,Enum.EasingStyle.Quad,Enum.EasingDirection.Out)
    end)
    btn.MouseLeave:Connect(function() if _isMobile then return end
        tw(arr,{Position=UDim2.new(1,0,0.5,0)},0.16,Enum.EasingStyle.Quad,Enum.EasingDirection.Out)
    end)
    btn.MouseButton1Click:Connect(function()
        Aurora:PlaySound("Click")
        tw(f,{BackgroundColor3=Aurora.Theme.Accent,BackgroundTransparency=0.72},0.08)
        task.delay(0.12,function() tw(f,{BackgroundColor3=Aurora.Theme.Element,BackgroundTransparency=0.2},0.22) end)
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
                TextSize=fs(11),Font=Enum.Font.Gotham,TextXAlignment=Enum.TextXAlignment.Left,TextWrapped=(not self._compact),TextTruncate=(self._compact and Enum.TextTruncate.AtEnd or Enum.TextTruncate.None),Parent=txtF,
            })
        end
    end
    function obj:SetDescription(d) self:SetDesc(d) end
    _registerElement(cfg.Title or "Button", f, self._tab, self._subTab)
    addVisibilityAPI(obj, f)
    applyPremiumConfig(obj, cfg)
    return obj
end
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
        TextSize=(self._compact and fs(13) or fs(14)),Font=Enum.Font.GothamBold,TextXAlignment=Enum.TextXAlignment.Left,TextWrapped=(not self._compact),TextTruncate=(self._compact and Enum.TextTruncate.AtEnd or Enum.TextTruncate.None),Parent=txtF,
    })
    local contentLbl = make("TextLabel",{
        Size=UDim2.new(1,-tx,0,0),Position=UDim2.new(0,tx,0,0),AutomaticSize=Enum.AutomaticSize.Y,
        BackgroundTransparency=1,Text=cfg.Content or "",TextColor3=thm.SubText,
        TextSize=fs(11),Font=Enum.Font.Gotham,TextXAlignment=Enum.TextXAlignment.Left,TextWrapped=(not self._compact),TextTruncate=(self._compact and Enum.TextTruncate.AtEnd or Enum.TextTruncate.None),Parent=txtF,
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
    local defaultValue = cfg.Default
    if type(defaultValue) == "number" and type(cfg.Values) == "table" then
        defaultValue = cfg.Values[defaultValue]
    end
    if defaultValue == nil and type(cfg.Values) == "table" then
        defaultValue = cfg.Values[1]
    end
    local obj={Type="Dropdown",Value=defaultValue ~= nil and defaultValue or "",Multi=cfg.Multi or false,id=id}
    if obj.Multi then
        local selected = {}
        if type(cfg.Default) == "table" then
            for key, value in pairs(cfg.Default) do
                if type(key) == "number" and value ~= nil then
                    selected[value] = true
                elseif type(key) == "string" and value then
                    selected[key] = true
                end
            end
        elseif type(cfg.Default) == "number" and type(cfg.Values) == "table" and cfg.Values[cfg.Default] ~= nil then
            selected[cfg.Values[cfg.Default]] = true
        elseif type(cfg.Default) == "string" and cfg.Default ~= "" then
            selected[cfg.Default] = true
        end
        obj.Value=selected
    end
    local f=elemFrame(self.Container)
    addTooltip(f, cfg.Tooltip)
    local topF=make("Frame",{Size=UDim2.new(1,0,0,s(30)),BackgroundTransparency=1,LayoutOrder=1,Parent=f})
    local tx=0
    if cfg.Icon then
        local ico=make("ImageLabel",{Size=ss(16,16),AnchorPoint=Vector2.new(0,0.5),Position=UDim2.new(0,0,0.5,0),BackgroundTransparency=1,Parent=topF})
        applyIcon(ico,cfg.Icon,thm.IconColor); tx=s(22)
    end
    local dropdownTitle=make("TextLabel",{
        Size=UDim2.new(0.5,-tx,1,0),Position=UDim2.new(0,tx,0,0),
        BackgroundTransparency=1,Text=cfg.Title or "Dropdown",TextColor3=thm.Text,
        TextSize=fs(14),Font=Enum.Font.GothamBold,TextXAlignment=Enum.TextXAlignment.Left,Parent=topF,
    })
    local valBox=make("Frame",{Size=UDim2.new(0.5,0,1,0),AnchorPoint=Vector2.new(1,0),Position=UDim2.new(1,0,0,0),BackgroundColor3=thm.InputBG,Parent=topF})
    if _isMobile then
        topF.Size=UDim2.new(1,0,0,0)
        topF.AutomaticSize=Enum.AutomaticSize.Y
        make("UIListLayout",{Padding=sz(6),SortOrder=Enum.SortOrder.LayoutOrder,Parent=topF})
        dropdownTitle.Size=UDim2.new(1,-tx,0,0)
        dropdownTitle.AutomaticSize=Enum.AutomaticSize.Y
        dropdownTitle.TextWrapped=true
        dropdownTitle.LayoutOrder=1
        valBox.Size=UDim2.new(1,0,0,s(32))
        valBox.AnchorPoint=Vector2.zero
        valBox.LayoutOrder=2
    end
    make("UISizeConstraint",{MaxSize=Vector2.new(s(200),math.huge),Parent=valBox})
    make("UICorner",{CornerRadius=sz(10),Parent=valBox})
    make("UIStroke",{Color=thm.Border,Thickness=1,Parent=valBox})
    local valTxt=make("TextLabel",{
        Size=UDim2.new(1,-s(22),1,0),Position=UDim2.new(0,s(8),0,0),
        BackgroundTransparency=1,Text="",TextColor3=thm.SubText,TextSize=fs(12),
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
            local selectedCount = #selectedNames
            hasValue = selectedCount > 0
            if selectedCount == 0 then
                selectedText = "None"
            elseif selectedCount == #(cfg.Values or {}) then
                selectedText = "All selected"
            elseif selectedCount <= 2 then
                selectedText = table.concat(selectedNames, ", ")
            else
                selectedText = tostring(selectedCount) .. " selected"
            end
        else
            hasValue = (obj.Value ~= "" and obj.Value ~= nil)
            selectedText = tostring(hasValue and obj.Value or "None")
        end
        valTxt.Text = selectedText
        valTxt.TextColor3 = hasValue and currentThm.Text or currentThm.SubText
        valTxt.Font = hasValue and Enum.Font.GothamBold or Enum.Font.Gotham
    end
    local dropdownList=make("Frame",{Size=UDim2.new(1,0,0,0),ClipsDescendants=true,BackgroundColor3=thm.Background,BackgroundTransparency=0.12,BorderSizePixel=0,LayoutOrder=2,Parent=f})
    make("UICorner",{CornerRadius=sz(11),Parent=dropdownList})
    make("UIStroke",{Color=thm.Border,Thickness=1,Transparency=0.35,Parent=dropdownList})
    make("UIPadding",{PaddingLeft=sz(5),PaddingRight=sz(5),Parent=dropdownList})
    reg(dropdownList,"BackgroundColor3","Background")
    make("UIListLayout",{SortOrder=Enum.SortOrder.LayoutOrder,Padding=sz(4),Parent=dropdownList})
    local bulkRow
    if obj.Multi then
        bulkRow=make("Frame",{Size=UDim2.new(1,0,0,s(26)),BackgroundTransparency=1,LayoutOrder=1,Parent=dropdownList})
        make("UIListLayout",{FillDirection=Enum.FillDirection.Horizontal,HorizontalAlignment=Enum.HorizontalAlignment.Center,VerticalAlignment=Enum.VerticalAlignment.Center,Padding=sz(6),Parent=bulkRow})
        local function makeBulkButton(text, accent)
            local button=make("TextButton",{
                Size=UDim2.new(0.5,-s(3),1,0),BackgroundColor3=accent and thm.Accent or thm.Element,
                BackgroundTransparency=accent and 0.16 or 0.35,AutoButtonColor=false,Text=text,
                TextColor3=accent and thm.Text or thm.SubText,TextSize=fs(10),Font=Enum.Font.GothamBold,Parent=bulkRow,
            })
            make("UICorner",{CornerRadius=sz(8),Parent=button})
            local stroke=make("UIStroke",{Color=accent and thm.Accent or thm.Border,Thickness=1,Transparency=0.35,Parent=button})
            button.MouseEnter:Connect(function() if _isMobile then return end
                local currentThm=Aurora.Theme or Aurora.Themes.Dark
                tw(button,{BackgroundColor3=accent and currentThm.AccentDim or currentThm.ElementHover,BackgroundTransparency=0.08},0.12)
                tw(stroke,{Color=currentThm.Accent,Transparency=0.1},0.12)
            end)
            button.MouseLeave:Connect(function() if _isMobile then return end
                local currentThm=Aurora.Theme or Aurora.Themes.Dark
                tw(button,{BackgroundColor3=accent and currentThm.Accent or currentThm.Element,BackgroundTransparency=accent and 0.16 or 0.35},0.12)
                tw(stroke,{Color=accent and currentThm.Accent or currentThm.Border,Transparency=0.35},0.12)
            end)
            return button
        end
        local selectAllBtn=makeBulkButton("Select All",true)
        local clearAllBtn=makeBulkButton("Clear All",false)
        selectAllBtn.MouseButton1Click:Connect(function() obj:SelectAll() end)
        clearAllBtn.MouseButton1Click:Connect(function() obj:ClearAll() end)
    end
    local searchBox=make("TextBox",{
        Size=UDim2.new(1,0,0,s(24)),BackgroundColor3=thm.InputBG,
        PlaceholderText="Search...",PlaceholderColor3=thm.SubText,
        Text="",TextColor3=thm.Text,TextSize=fs(11),Font=Enum.Font.Gotham,LayoutOrder=obj.Multi and 2 or 1,Parent=dropdownList,
    })
    make("UICorner",{CornerRadius=sz(10),Parent=searchBox})
    local _ddSearchStroke=make("UIStroke",{Color=thm.Border,Thickness=1,Transparency=0.35,Parent=searchBox})
    make("UIPadding",{PaddingLeft=sz(10),Parent=searchBox})
    pcall(function() searchBox.Focused:Connect(function()
        tw(_ddSearchStroke,{Color=Aurora.Theme.Accent,Transparency=0.05},0.16)
    end) end)
    searchBox.FocusLost:Connect(function()
        tw(_ddSearchStroke,{Color=Aurora.Theme.Border,Transparency=0.35},0.16)
    end)
    local optionScroll=make("ScrollingFrame",{
        Size=UDim2.new(1,0,0,s(112)),BackgroundTransparency=1,
        ScrollBarThickness=_isMobile and s(6) or s(4),ScrollBarImageColor3=thm.Scrollbar,ScrollBarImageTransparency=0.2,CanvasSize=UDim2.new(0,0,0,0),AutomaticCanvasSize=Enum.AutomaticSize.Y,LayoutOrder=obj.Multi and 3 or 2,Parent=dropdownList,
    })
    make("UIPadding",{PaddingTop=sz(3),PaddingBottom=sz(3),PaddingLeft=sz(2),PaddingRight=sz(4),Parent=optionScroll})
    local olay=make("UIListLayout",{SortOrder=Enum.SortOrder.LayoutOrder,Padding=sz(3),Parent=optionScroll})
    olay.Changed:Connect(function() optionScroll.CanvasSize=UDim2.new(0,0,0,olay.AbsoluteContentSize.Y+s(10)) end)
    local optionButtons={}
    -- PremiumValues: list/set of dropdown values that require premium
    local _premiumVals = {}
    if cfg.PremiumValues then
        if type(cfg.PremiumValues) == "table" then
            for _, pv in ipairs(cfg.PremiumValues) do _premiumVals[pv] = true end
            for pk, pv in pairs(cfg.PremiumValues) do
                if type(pk) == "string" then _premiumVals[pk] = pv end
            end
        end
    end
    local function _isValPremium(val)
        return _premiumVals[val] == true
    end
    local function populateOptions(vals)
        for _,val in ipairs(vals) do
            local isPremVal = _isValPremium(val)
            local optBtn=make("TextButton",{Size=UDim2.new(1,0,0,s(32)),BackgroundColor3=thm.InputBG,BackgroundTransparency=1,Text="",Parent=optionScroll})
            make("UICorner",{CornerRadius=sz(9),Parent=optBtn})
            local optScale=make("UIScale",{Scale=1,Parent=optBtn})
            local optBar=make("Frame",{Size=UDim2.new(0,s(3),0,s(14)),AnchorPoint=Vector2.new(0,0.5),Position=UDim2.new(0,s(4),0.5,0),BackgroundColor3=thm.Accent,BackgroundTransparency=1,BorderSizePixel=0,Parent=optBtn})
            make("UICorner",{CornerRadius=UDim.new(1,0),Parent=optBar})
            local optLbl=make("TextLabel",{
                Size=UDim2.new(1,-s(isPremVal and 52 or 34),1,0),Position=UDim2.new(0,s(12),0,0),
                BackgroundTransparency=1,Text=tostring(val),TextColor3=thm.SubText,TextSize=fs(15),
                Font=Enum.Font.Gotham,TextXAlignment=Enum.TextXAlignment.Left,Parent=optBtn,
            })
            -- Premium lock badge on premium values
            local premLock
            if isPremVal then
                premLock = make("Frame", {
                    Size=UDim2.fromOffset(s(18), s(14)), AnchorPoint=Vector2.new(1,0.5),
                    Position=UDim2.new(1, -s(24), 0.5, 0), BackgroundColor3=Color3.fromRGB(45,36,16),
                    BackgroundTransparency=0, BorderSizePixel=0, ZIndex=5, Parent=optBtn,
                })
                make("UICorner", {CornerRadius=UDim.new(1,0), Parent=premLock})
                make("UIStroke", {Color=Color3.fromRGB(200,155,60), Thickness=1, Transparency=0.3, Parent=premLock})
                local lockIco = make("ImageLabel", {
                    Size=UDim2.fromOffset(s(10), s(10)), AnchorPoint=Vector2.new(0.5,0.5),
                    Position=UDim2.fromScale(0.5, 0.5), BackgroundTransparency=1, ZIndex=6, Parent=premLock,
                })
                applyIcon(lockIco, "solar/lock-keyhole-bold", Color3.fromRGB(220,175,70))
            end
            local optCheck=make("ImageLabel",{Size=ss(12,12),AnchorPoint=Vector2.new(1,0.5),Position=UDim2.new(1,-s(8),0.5,0),BackgroundTransparency=1,Visible=false,Parent=optBtn})
            applyIcon(optCheck,"solar/check-linear",thm.Accent)
            local function updateSelectState()
                local isSel=obj.Multi and (not not obj.Value[val]) or (obj.Value==val)
                local currentThm = Aurora.Theme or Aurora.Themes.Dark
                local isLocked = isPremVal and not Aurora.IsPremium
                optCheck.Visible=isSel and not isLocked
                optCheck.ImageColor3 = currentThm.Accent
                tw(optBar,{BackgroundTransparency=isSel and 0 or 1, BackgroundColor3=isLocked and Color3.fromRGB(200,155,60) or currentThm.Accent},0.12)
                optLbl.TextColor3=isLocked and Color3.fromRGB(160,140,90) or (isSel and currentThm.Accent or currentThm.SubText)
                optLbl.Font=isSel and Enum.Font.GothamBold or Enum.Font.Gotham
                tw(optBtn, {
                    BackgroundColor3 = isSel and (isLocked and Color3.fromRGB(50,40,18) or currentThm.Accent) or currentThm.InputBG,
                    BackgroundTransparency = isSel and 0.82 or 1
                }, 0.12)
                if premLock then premLock.Visible = isLocked end
            end
            optBtn.MouseEnter:Connect(function() if _isMobile then return end
                local isSel=obj.Multi and (not not obj.Value[val]) or (obj.Value==val)
                local currentThm = Aurora.Theme or Aurora.Themes.Dark
                if not isSel then
                    tw(optBtn,{BackgroundColor3=currentThm.ElementHover,BackgroundTransparency=0.55},0.1)
                    tw(optLbl,{TextColor3=currentThm.Text},0.1)
                else
                    tw(optBtn,{BackgroundTransparency=0.6},0.1)
                end
            end)
            optBtn.MouseLeave:Connect(function() if _isMobile then return end
                local isSel=obj.Multi and (not not obj.Value[val]) or (obj.Value==val)
                local currentThm = Aurora.Theme or Aurora.Themes.Dark
                if not isSel then
                    tw(optBtn,{BackgroundTransparency=1},0.1)
                    tw(optLbl,{TextColor3=(isPremVal and not Aurora.IsPremium) and Color3.fromRGB(160,140,90) or currentThm.SubText},0.1)
                else
                    tw(optBtn,{BackgroundTransparency=0.82},0.1)
                    tw(optLbl,{TextColor3=(isPremVal and not Aurora.IsPremium) and Color3.fromRGB(200,155,60) or currentThm.Accent},0.1)
                end
            end)
            optBtn.MouseButton1Click:Connect(function()
                -- Premium gate check
                if isPremVal and not Aurora.IsPremium then
                    Aurora:PlaySound("Error")
                    tw(optBtn, {BackgroundColor3=Color3.fromRGB(80,60,20), BackgroundTransparency=0.4}, 0.08)
                    task.delay(0.12, function() tw(optBtn, {BackgroundTransparency=1}, 0.2) end)
                    if premLock then
                        local sc = premLock:FindFirstChildOfClass("UIScale") or make("UIScale", {Scale=1, Parent=premLock})
                        tw(sc, {Scale=1.4}, 0.08)
                        task.delay(0.1, function() if sc and sc.Parent then tw(sc, {Scale=1}, 0.2, Enum.EasingStyle.Back, Enum.EasingDirection.Out) end end)
                    end
                    Aurora:OpenPremiumPrompt(tostring(val))
                    return
                end
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
            table.insert(optionButtons,{btn=optBtn,update=updateSelectState,value=val,scale=optScale,isPremium=isPremVal})
            updateSelectState()
        end
        searchBox.Visible = #vals > (cfg.SearchThreshold or 6)
    end
    populateOptions(cfg.Values or {}); updateTxt()
    searchBox:GetPropertyChangedSignal("Text"):Connect(function()
        local filter=searchBox.Text:lower()
        for _,opt in ipairs(optionButtons) do opt.btn.Visible=tostring(opt.value):lower():find(filter,1,true)~=nil end
    end)
    -- Keep the hit target out of the mobile header's automatic-height list.
    local btn=make("TextButton",{Size=UDim2.new(1,0,1,0),BackgroundTransparency=1,Text="",Parent=_isMobile and valBox or topF})
    local dropExpanded=false
    local function _setAncestorScroll(enabled)
        if not _isMobile then return end
        local p = f.Parent
        while p and p ~= game do
            if p:IsA("ScrollingFrame") then pcall(function() p.ScrollingEnabled = enabled end) end
            p = p.Parent
        end
    end
    local function toggleDropdown()
        dropExpanded=not dropExpanded
        local visibleCount = 0
        for _,ob in ipairs(optionButtons) do if ob.btn.Visible then visibleCount = visibleCount + 1 end end
        local elemCnt=math.min(6,visibleCount)
        local _searchH = searchBox.Visible and (s(24)+s(4)) or 0
        local _bulkH = obj.Multi and (s(26)+s(4)) or 0
        local scrollH = elemCnt*s(35)+s(6)
        local targetH=dropExpanded and (_bulkH+_searchH+scrollH+s(8)) or 0
        optionScroll.Size = UDim2.new(1,0,0,scrollH)
        tw(dropdownList,{Size=UDim2.new(1,0,0,targetH)},0.2)
        tw(arr,{Rotation=dropExpanded and 180 or 0},0.2)
        _setAncestorScroll(not dropExpanded)
        if dropExpanded then
            task.spawn(function()
                for _, ob in ipairs(optionButtons) do
                    if not dropExpanded then break end
                    if ob.scale then
                        ob.scale.Scale = 0.92
                        tw(ob.scale, { Scale = 1 }, 0.18, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
                    end
                    task.wait(0.035)
                end
            end)
        end
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
        if obj.Multi then
            local selected = {}
            if type(val) == "table" then
                for key, value in pairs(val) do
                    if type(key) == "number" and value ~= nil then
                        selected[value] = true
                    elseif type(key) == "string" and value then
                        selected[key] = true
                    end
                end
            elseif type(val) == "string" and val ~= "" then
                selected[val] = true
            elseif type(val) == "number" and type(cfg.Values) == "table" and cfg.Values[val] ~= nil then
                selected[cfg.Values[val]] = true
            end
            obj.Value=selected
        else
            if type(val) == "number" and type(cfg.Values) == "table" then
                val = cfg.Values[val] or val
            end
            obj.Value=val
        end
        for _,opt in ipairs(optionButtons) do opt.update() end
        updateTxt()
        if cfg.Callback then pcall(cfg.Callback, obj.Value) end
        triggerAutosave()
    end
    function obj:SelectAll()
        if not obj.Multi then return self:SetValue(obj.Value) end
        local selected = {}
        for _, value in ipairs(cfg.Values or {}) do selected[value] = true end
        self:SetValue(selected)
    end
    function obj:ClearAll()
        if obj.Multi then self:SetValue({}) end
    end
    function obj:SetValues(newValues)
        self:Refresh(newValues)
    end
    function obj:SetPremiumValues(premVals)
        _premiumVals = {}
        if type(premVals) == "table" then
            for _, pv in ipairs(premVals) do _premiumVals[pv] = true end
            for pk, pv in pairs(premVals) do
                if type(pk) == "string" then _premiumVals[pk] = pv end
            end
        end
        for _, opt in ipairs(optionButtons) do
            opt.isPremium = _isValPremium(opt.value)
            opt.update()
        end
    end
    function obj:RefreshPremiumState()
        for _, opt in ipairs(optionButtons) do
            if opt.isPremium then opt.update() end
        end
    end
    obj._hasPremiumValues = next(_premiumVals) ~= nil
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
    applyPremiumConfig(obj, cfg)
    Aurora.Options[id]=obj
    return obj
end
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
    local inputTitle=make("TextLabel",{
        Size=UDim2.new(0.45,-tx,1,0),Position=UDim2.new(0,tx,0,0),
        BackgroundTransparency=1,Text=cfg.Title or "Input",TextColor3=thm.Text,
        TextSize=fs(14),Font=Enum.Font.GothamBold,TextXAlignment=Enum.TextXAlignment.Left,Parent=topF,
    })
    local inputValBox=make("TextBox",{
        Size=UDim2.new(0.55,0,0,s(22)),AnchorPoint=Vector2.new(1,0.5),Position=UDim2.new(1,0,0.5,0),
        BackgroundColor3=thm.InputBG,PlaceholderText=cfg.Placeholder or "Type here...",
        PlaceholderColor3=thm.SubText,Text=obj.Value,TextColor3=thm.Text,TextSize=fs(12),
        Font=Enum.Font.Gotham,TextXAlignment=Enum.TextXAlignment.Left,ClearTextOnFocus=false,Parent=topF,
    })
    if _isMobile then
        topF.Size=UDim2.new(1,0,0,0)
        topF.AutomaticSize=Enum.AutomaticSize.Y
        make("UIListLayout",{Padding=sz(6),SortOrder=Enum.SortOrder.LayoutOrder,Parent=topF})
        inputTitle.Size=UDim2.new(1,-tx,0,0)
        inputTitle.AutomaticSize=Enum.AutomaticSize.Y
        inputTitle.TextWrapped=true
        inputTitle.LayoutOrder=1
        inputValBox.Size=UDim2.new(1,0,0,s(32))
        inputValBox.AnchorPoint=Vector2.zero
        inputValBox.LayoutOrder=2
    end
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
    applyPremiumConfig(obj, cfg)
    Aurora.Options[id]=obj
    return obj
end
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
    local bindConn=nil
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
        TextSize=fs(14),Font=Enum.Font.GothamBold,TextXAlignment=Enum.TextXAlignment.Left,Parent=topF,
    })
    local kbBtn=make("TextButton",{
        Size=ss(65,20),AnchorPoint=Vector2.new(1,0.5),Position=UDim2.new(1,0,0.5,0),
        BackgroundColor3=thm.InputBG,
        Text=defaultKey==Enum.KeyCode.None and "None" or defaultKey.Name,
        TextColor3=thm.SubText,TextSize=fs(11),Font=Enum.Font.GothamBold,ZIndex=10,Parent=topF,
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
        local activeColor = currentThm.AlertSuccess
        local activeBG = currentThm.Background:Lerp(currentThm.AlertSuccess, 0.22)
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
                tw(mobileBtn, { BackgroundColor3 = currentThm.Background }, 0.12)
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
            bindConn=UserInputService.InputBegan:Connect(function(input)
                if input.UserInputType==Enum.UserInputType.Keyboard then
                    bindConn:Disconnect(); bindConn=nil; binding=false
                    local k=input.KeyCode
                    updateKey(k==Enum.KeyCode.Escape and Enum.KeyCode.None or k)
                    kbBtn.TextColor3=thm.SubText
                    if cfg.Callback then pcall(cfg.Callback,obj.Value) end
                elseif input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.MouseButton2 or input.UserInputType == Enum.UserInputType.MouseButton3 then
                    bindConn:Disconnect(); bindConn=nil; binding=false
                    updateKey(input.UserInputType)
                    kbBtn.TextColor3=thm.SubText
                    if cfg.Callback then pcall(cfg.Callback,obj.Value) end
                end
            end)
        end)
    end)
    f.Destroying:Connect(function()
        if bindConn then pcall(function() bindConn:Disconnect() end); bindConn=nil end
    end)
    kbBtn.MouseButton2Click:Connect(function()
        if binding then return end
        updateKey(Enum.KeyCode.None)
        active = false
        updateVisualState()
        if cfg.Callback then pcall(cfg.Callback, obj.Value, active) end
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
                if cfg.Mode == "Toggle" then active = not active else active = true end
                updateVisualState()
                if Aurora.RefreshKeybindList then task.defer(Aurora.RefreshKeybindList) end
                if cfg.Callback then pcall(cfg.Callback,obj.Value,active) end
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
            if isMatch and cfg.Mode ~= "Toggle" then
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
local Column={}
Column.__index=Column
local _sectionCounter = 0
function Column:AddSection(title, cfg)
    cfg = cfg or {}
    _sectionCounter = _sectionCounter + 1
    local f=make("Frame",{Size=UDim2.new(1,0,0,0),AutomaticSize=Enum.AutomaticSize.Y,BackgroundTransparency=1,Parent=self.Frame})
    make("UIListLayout",{SortOrder=Enum.SortOrder.LayoutOrder,Padding=sz(7),Parent=f})
    local headerFrame=make(Aurora.FadeIn and "CanvasGroup" or "Frame",{Size=UDim2.new(1,0,0,s(22)),BackgroundTransparency=1,Parent=f})
    local accentDot = make("Frame",{
        Size=UDim2.fromOffset(s(3),s(12)),
        AnchorPoint=Vector2.new(0,0.5), Position=UDim2.new(0,0,0.5,-s(1)),
        BackgroundColor3=Aurora.Theme.Accent,
        BorderSizePixel=0, Parent=headerFrame,
    })
    make("UICorner",{CornerRadius=UDim.new(1,0),Parent=accentDot})
    reg(accentDot,"BackgroundColor3","Accent")
    local titleLbl = make("TextLabel",{
        Size=UDim2.new(1,-s(11),1,-s(4)),
        Position=UDim2.new(0,s(11),0,0),
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
        if Aurora.LazyLoad then
            local secDelay = _sectionCounter * (Aurora.DelayPerSection or 0.04)
            task.delay(secDelay, function()
                if headerFrame and headerFrame.Parent then
                    tw(headerFrame, { GroupTransparency = 0 }, 0.3, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
                end
            end)
        else
            tw(headerFrame, { GroupTransparency = 0 }, 0.3, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
        end
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
    local forceVertical = _isMobile
    local initDir = forceVertical and Enum.FillDirection.Vertical or Enum.FillDirection.Horizontal
    local initSize = forceVertical and UDim2.new(1,0,0,0) or UDim2.new(0.5,-s(4),0,0)
    local c=make("Frame",{Size=UDim2.new(1,0,0,0),AutomaticSize=Enum.AutomaticSize.Y,BackgroundTransparency=1,Parent=self.ScrollContent})
    local layout = make("UIListLayout",{FillDirection=initDir,SortOrder=Enum.SortOrder.LayoutOrder,Padding=sz(8),Parent=c})
    local l=make("Frame",{Size=initSize,AutomaticSize=Enum.AutomaticSize.Y,BackgroundTransparency=1,Parent=c})
    make("UIListLayout",{SortOrder=Enum.SortOrder.LayoutOrder,Padding=sz(7),Parent=l})
    local r=make("Frame",{Size=initSize,AutomaticSize=Enum.AutomaticSize.Y,BackgroundTransparency=1,Parent=c})
    make("UIListLayout",{SortOrder=Enum.SortOrder.LayoutOrder,Padding=sz(7),Parent=r})
    if not forceVertical then
        local function upd()
            if c.AbsoluteSize.X < 400 then
                layout.FillDirection = Enum.FillDirection.Vertical
                l.Size = UDim2.new(1,0,0,0)
                r.Size = UDim2.new(1,0,0,0)
            else
                layout.FillDirection = Enum.FillDirection.Horizontal
                l.Size = UDim2.new(0.5,-s(4),0,0)
                r.Size = UDim2.new(0.5,-s(4),0,0)
            end
        end
        c:GetPropertyChangedSignal("AbsoluteSize"):Connect(upd)
        task.spawn(upd)
    end
    return setmetatable({Frame=l, _tab=self._parentTab, _subTab=self},Column), setmetatable({Frame=r, _tab=self._parentTab, _subTab=self},Column)
end
local Tab={}
Tab.__index=Tab
function Tab:AddSection(title, cfg)
    local sec = Column.AddSection({Frame=self.ScrollContent, _tab=self}, title, cfg)
    return sec
end
function Tab:AddColumns()
    local forceVertical = _isMobile
    local initDir = forceVertical and Enum.FillDirection.Vertical or Enum.FillDirection.Horizontal
    local initSize = forceVertical and UDim2.new(1,0,0,0) or UDim2.new(0.5,-s(4),0,0)
    local c=make("Frame",{Size=UDim2.new(1,0,0,0),AutomaticSize=Enum.AutomaticSize.Y,BackgroundTransparency=1,Parent=self.ScrollContent})
    local layout = make("UIListLayout",{FillDirection=initDir,SortOrder=Enum.SortOrder.LayoutOrder,Padding=sz(8),Parent=c})
    local l=make("Frame",{Size=initSize,AutomaticSize=Enum.AutomaticSize.Y,BackgroundTransparency=1,Parent=c})
    make("UIListLayout",{SortOrder=Enum.SortOrder.LayoutOrder,Padding=sz(7),Parent=l})
    local r=make("Frame",{Size=initSize,AutomaticSize=Enum.AutomaticSize.Y,BackgroundTransparency=1,Parent=c})
    make("UIListLayout",{SortOrder=Enum.SortOrder.LayoutOrder,Padding=sz(7),Parent=r})
    if not forceVertical then
        local function upd()
            if c.AbsoluteSize.X < 400 then
                layout.FillDirection = Enum.FillDirection.Vertical
                l.Size = UDim2.new(1,0,0,0)
                r.Size = UDim2.new(1,0,0,0)
            else
                layout.FillDirection = Enum.FillDirection.Horizontal
                l.Size = UDim2.new(0.5,-s(4),0,0)
                r.Size = UDim2.new(0.5,-s(4),0,0)
            end
        end
        c:GetPropertyChangedSignal("AbsoluteSize"):Connect(upd)
        task.spawn(upd)
    end
    return setmetatable({Frame=l, _tab=self},Column), setmetatable({Frame=r, _tab=self},Column)
end
function Tab:AddSubTab(title)
    self.SubTabs=self.SubTabs or {}
    if not self.SubTabBar then
        self.DefaultScroll.Visible=false
        local bgBar = make("Frame",{
            Size=UDim2.new(1,0,0,s(44)),BackgroundColor3=Aurora.Theme.TopBar,BorderSizePixel=0,ZIndex=0,Parent=self.Page
        })
        make("UIGradient",{
            Color=ColorSequence.new({ColorSequenceKeypoint.new(0,Color3.fromRGB(18,18,24)),ColorSequenceKeypoint.new(1,Color3.fromRGB(12,12,16))}),
            Rotation=90, Parent=bgBar,
        })
        make("Frame",{Size=UDim2.new(1,0,0,1),Position=UDim2.new(0,0,1,-1),BackgroundColor3=Aurora.Theme.Border,BackgroundTransparency=0.5,BorderSizePixel=0,Parent=bgBar})
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
        Size=UDim2.fromScale(1,1),BackgroundTransparency=1,ScrollBarThickness=_isMobile and s(6) or s(2),
        ScrollBarImageColor3=Aurora.Theme.Scrollbar,Visible=false,Parent=self.SubPageContainer,
    })
    local subContent=make("Frame",{Size=UDim2.new(1,0,0,0),AutomaticSize=Enum.AutomaticSize.Y,BackgroundTransparency=1,Parent=subPage})
    local subLay=make("UIListLayout",{SortOrder=Enum.SortOrder.LayoutOrder,Padding=sz(10),Parent=subContent})
    make("UIPadding",{PaddingTop=sz(14),PaddingBottom=sz(20),PaddingLeft=sz(14),PaddingRight=sz(14),Parent=subContent})
    subPage.CanvasSize=UDim2.fromOffset(0,0)
    subPage.AutomaticCanvasSize=Enum.AutomaticSize.Y
    subPage.ScrollingDirection=Enum.ScrollingDirection.Y
    local subBtn=make("TextButton",{
        Size=UDim2.new(0,0,1,0),AutomaticSize=Enum.AutomaticSize.X,
        BackgroundColor3=Aurora.Theme.Accent,BackgroundTransparency=1,
        Text=title,TextColor3=Aurora.Theme.TabInactive,TextSize=fs(12),Font=Enum.Font.GothamBold,
        ZIndex=2,Parent=self.SubTabBar,
    })
    make("UICorner",{CornerRadius=sz(6),Parent=subBtn})
    make("UIPadding",{PaddingLeft=sz(10),PaddingRight=sz(10),Parent=subBtn})
    local underline=make("Frame",{Size=UDim2.new(0,0,0,0),BackgroundTransparency=1,Visible=false,Parent=subBtn})
    local function setActive(isActive)
        local currentThm = Aurora.Theme or Aurora.Themes.Dark
        if isActive then
            tw(subBtn, { BackgroundColor3 = currentThm.Accent, BackgroundTransparency = 0.82, TextColor3 = currentThm.Accent }, 0.18)
        else
            tw(subBtn, { BackgroundTransparency = 1, TextColor3 = currentThm.TabInactive }, 0.18)
        end
    end
    subBtn.MouseEnter:Connect(function() if _isMobile then return end 
        if not subPage.Visible then
            local currentThm = Aurora.Theme or Aurora.Themes.Dark
            tw(subBtn, { BackgroundColor3 = currentThm.ElementHover, BackgroundTransparency = 0.55, TextColor3 = currentThm.Text }, 0.12)
        end
    end)
    subBtn.MouseLeave:Connect(function() if _isMobile then return end 
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
        subPage.Position = UDim2.new(0, 0, 0.03, 0)
        tw(subPage, { Position = UDim2.new(0, 0, 0, 0) }, 0.22, Enum.EasingStyle.Quint, Enum.EasingDirection.Out)
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
-- ============================================================
--  COMPACT WINDOW  (panel angosto de 1 columna, sin sidebar)
--  Reutiliza el sistema de Section: todos los elementos funcionan.
-- ============================================================
function Aurora:CreateCompactWindow(cfg)
    cfg = cfg or {}
    _isMobile = isMobileDevice()
    if type(cfg.MobileMode) == "boolean" then _isMobile = cfg.MobileMode end
    local defaultScale = _isMobile and 0.55 or 1.0
    SC = math.clamp(cfg.Scale or defaultScale, 0.4, 2.0)
    self.Scale = SC
    if cfg.Theme then Aurora:SetTheme(cfg.Theme) end
    if not Aurora.Theme then
        Aurora.Theme = copyTheme(Aurora.Themes.Dark)
        Aurora._activeThemePrivate = true
        Aurora.ThemeName = "Dark"
    end
    local thm = Aurora.Theme or Aurora.Themes.Dark
    local gui = make("ScreenGui", {
        Name = "AuroraCompact", ResetOnSpawn = false,
        ZIndexBehavior = Enum.ZIndexBehavior.Sibling, DisplayOrder = 90000,
    })
    safeParent(gui)
    local W = cfg.Width or 278
    local H = cfg.Height or 430
    local main = make("Frame", {
        AnchorPoint = Vector2.new(0.5, 0.5),
        Position = cfg.Position or UDim2.fromScale(0.5, 0.5),
        Size = UDim2.fromOffset(s(W), s(H)),
        BackgroundColor3 = thm.Background, BorderSizePixel = 0,
        ClipsDescendants = true, Parent = gui,
    })
    make("UICorner", { CornerRadius = sz(12), Parent = main })
    local mainStroke = make("UIStroke", { Color = thm.Border, Thickness = 1, Parent = main })
    -- Auto-scale for mobile/small viewports
    local compactScale = make("UIScale", { Name = "CompactUIScale", Scale = 1, Parent = main })
    local function recalibrateCompact()
        local cam = workspace.CurrentCamera
        local vp = cam and cam.ViewportSize or Vector2.new(1920, 1080)
        local isMob = _isMobile
        local baseW = W
        local baseH = H
        local maxRatioW, maxRatioH, scaleMax
        if isMob and math.min(vp.X, vp.Y) < 420 then
            maxRatioW, maxRatioH = 0.92, 0.88
            scaleMin, scaleMax = 0.55, 0.85
        elseif isMob then
            maxRatioW, maxRatioH = 0.88, 0.85
            scaleMin, scaleMax = 0.60, 0.92
        else
            maxRatioW, maxRatioH = 0.90, 0.88
            scaleMin, scaleMax = 0.70, 1.0
        end
        local targetScale = math.min((vp.X * maxRatioW) / s(baseW), (vp.Y * maxRatioH) / s(baseH))
        compactScale.Scale = math.clamp(targetScale, scaleMin, scaleMax)
    end
    recalibrateCompact()
    local cam = workspace.CurrentCamera
    if cam then
        cam:GetPropertyChangedSignal("ViewportSize"):Connect(recalibrateCompact)
    end
    -- Header
    local header = make("Frame", { Size = UDim2.new(1,0,0,s(42)), BackgroundTransparency = 1, ZIndex = 3, Parent = main })
    local logo = make("ImageLabel", {
        Size = ss(22,22), AnchorPoint = Vector2.new(0,0.5), Position = UDim2.new(0,s(12),0.5,0),
        BackgroundTransparency = 1, Parent = header,
    })
    applyIcon(logo, cfg.Icon or "solar/ghost-bold", thm.Accent)
    make("TextLabel", {
        AnchorPoint = Vector2.new(0,0.5), Position = UDim2.new(0,s(42),0.5,-s(5)), Size = UDim2.new(1,-s(104),0,s(16)),
        BackgroundTransparency = 1, Text = cfg.Title or "Hub", TextColor3 = thm.Text,
        TextSize = fs(15), Font = Enum.Font.GothamBold, TextXAlignment = Enum.TextXAlignment.Left, TextTruncate = Enum.TextTruncate.AtEnd, Parent = header,
    })
    make("TextLabel", {
        AnchorPoint = Vector2.new(0,0.5), Position = UDim2.new(0,s(42),0.5,s(8)), Size = UDim2.new(1,-s(104),0,s(12)),
        BackgroundTransparency = 1, Text = cfg.SubTitle or "", TextColor3 = thm.SubText,
        TextSize = fs(10), Font = Enum.Font.Gotham, TextXAlignment = Enum.TextXAlignment.Left, TextTruncate = Enum.TextTruncate.AtEnd, Parent = header,
    })
    -- FPS + Ping (por default; cfg.ShowStats=false los quita)
    local _statConn
    if cfg.ShowStats ~= false then
        local RunSvc = game:GetService("RunService")
        local StatsSvc = game:GetService("Stats")
        local statBox = make("Frame", {
            AnchorPoint = Vector2.new(1,0.5), Position = UDim2.new(1,-s(40),0.5,0),
            Size = ss(60,32), BackgroundTransparency = 1, ZIndex = 4, Parent = header,
        })
        local function _miniPill(yoff, iconId, col, iconCol)
            local pill = make("Frame", {
                Size = UDim2.new(1,0,0,s(15)), Position = UDim2.new(0,0,0,yoff),
                BackgroundColor3 = thm.Element, BackgroundTransparency = 0.4, BorderSizePixel = 0, ZIndex = 4, Parent = statBox,
            })
            make("UICorner", { CornerRadius = sz(6), Parent = pill })
            local ic = make("ImageLabel", { Size = ss(12,12), AnchorPoint = Vector2.new(0,0.5), Position = UDim2.new(0,s(6),0.5,0), BackgroundTransparency = 1, ZIndex = 5, Parent = pill })
            applyIcon(ic, iconId, iconCol or col)
            local lbl = make("TextLabel", {
                Size = UDim2.new(1,-s(23),1,0), Position = UDim2.new(0,s(22),0,0),
                BackgroundTransparency = 1, Text = "--", TextColor3 = col, TextSize = fs(9),
                Font = Enum.Font.GothamBold, TextXAlignment = Enum.TextXAlignment.Left, ZIndex = 5, Parent = pill,
            })
            return lbl
        end
        local _good, _mid, _bad = Color3.fromRGB(120,220,140), Color3.fromRGB(240,200,90), Color3.fromRGB(240,110,110)
        local fpsLbl  = _miniPill(0, "solar/bolt-bold", _good, _good)
        local pingLbl = _miniPill(s(18), "solar/pulse-bold", thm.SubText, thm.Accent)
        local _frames, _acc = 0, 0
        _statConn = RunSvc.RenderStepped:Connect(function(dt)
            _frames = _frames + 1
            _acc = _acc + dt
            if _acc >= 0.5 then
                local fps = math.floor(_frames/_acc + 0.5)
                fpsLbl.Text = tostring(fps)
                fpsLbl.TextColor3 = (fps >= 50 and _good) or (fps >= 30 and _mid) or _bad
                _frames, _acc = 0, 0
                local ok, ping = pcall(function() return math.floor(StatsSvc.Network.ServerStatsItem["Data Ping"]:GetValue() + 0.5) end)
                if ok and ping then
                    pingLbl.Text = ping .. "ms"
                    pingLbl.TextColor3 = (ping <= 90 and _good) or (ping <= 180 and _mid) or _bad
                end
            end
        end)
    end
    -- Close button
    local closeBtn = make("TextButton", {
        Size = ss(24,24), AnchorPoint = Vector2.new(1,0.5), Position = UDim2.new(1,-s(10),0.5,0),
        BackgroundTransparency = 1, Text = "", AutoButtonColor = false, ZIndex = 4, Parent = header,
    })
    local closeIco = make("ImageLabel", { Size = ss(19,19), AnchorPoint = Vector2.new(0.5,0.5), Position = UDim2.fromScale(0.5,0.5), BackgroundTransparency = 1, ZIndex = 5, Parent = closeBtn })
    applyIcon(closeIco, "solar/close-circle-bold", thm.SubText)
    -- Divider
    make("Frame", {
        Size = UDim2.new(1,-s(20),0,1), Position = UDim2.new(0,s(10),0,s(42)),
        BackgroundColor3 = thm.Border, BackgroundTransparency = 0.35, BorderSizePixel = 0, ZIndex = 3, Parent = main,
    })
    -- Content scroll
    local scroll = make("ScrollingFrame", {
        Position = UDim2.new(0,0,0,s(48)), Size = UDim2.new(1,0,1,-s(48)),
        BackgroundTransparency = 1, BorderSizePixel = 0, ScrollBarThickness = s(3),
        ScrollBarImageColor3 = thm.Accent, ScrollBarImageTransparency = 0.3,
        AutomaticCanvasSize = Enum.AutomaticSize.Y, CanvasSize = UDim2.new(0,0,0,0), Parent = main,
    })
    make("UIListLayout", { SortOrder = Enum.SortOrder.LayoutOrder, Padding = sz(10), Parent = scroll })
    make("UIPadding", { PaddingLeft = sz(10), PaddingRight = sz(10), PaddingTop = sz(4), PaddingBottom = sz(10), Parent = scroll })

    local win = { GUI = gui, MainFrame = main, ScreenGui = gui }
    local visible = true

    -- Drag por el header
    local dragging, dragStart, startPos = false, nil, nil
    header.InputBegan:Connect(function(i)
        if i.UserInputType == Enum.UserInputType.MouseButton1 or i.UserInputType == Enum.UserInputType.Touch then
            dragging = true; dragStart = i.Position; startPos = main.Position
        end
    end)
    header.InputEnded:Connect(function(i)
        if i.UserInputType == Enum.UserInputType.MouseButton1 or i.UserInputType == Enum.UserInputType.Touch then dragging = false end
    end)
    local _dragConn = UserInputService.InputChanged:Connect(function(i)
        if dragging and (i.UserInputType == Enum.UserInputType.MouseMovement or i.UserInputType == Enum.UserInputType.Touch) then
            local d = i.Position - dragStart
            main.Position = UDim2.new(startPos.X.Scale, startPos.X.Offset + d.X, startPos.Y.Scale, startPos.Y.Offset + d.Y)
        end
    end)

    -- AddSection: header CENTRADO con lineas a los lados (estilo compacto)
    function win:AddSection(title, scfg)
        scfg = scfg or {}
        local f = make("Frame", { Size = UDim2.new(1,0,0,0), AutomaticSize = Enum.AutomaticSize.Y, BackgroundTransparency = 1, Parent = scroll })
        make("UIListLayout", { SortOrder = Enum.SortOrder.LayoutOrder, Padding = sz(6), Parent = f })
        local headerFrame = make("Frame", { Size = UDim2.new(1,0,0,s(20)), BackgroundTransparency = 1, LayoutOrder = 0, Parent = f })
        make("UIPadding", { PaddingTop = sz(4), Parent = headerFrame })
        local _bar = make("Frame", {
            AnchorPoint = Vector2.new(0,0.5), Position = UDim2.new(0,0,0.5,s(2)), Size = ss(3,11),
            BackgroundColor3 = thm.Accent, BorderSizePixel = 0, Parent = headerFrame,
        })
        make("UICorner", { CornerRadius = UDim.new(1,0), Parent = _bar })
        reg(_bar, "BackgroundColor3", "Accent")
        local hlbl = make("TextLabel", {
            AnchorPoint = Vector2.new(0,0.5), Position = UDim2.new(0,s(10),0.5,s(2)), Size = UDim2.new(1,-s(10),1,0),
            BackgroundTransparency = 1, Text = tostring(title), TextColor3 = thm.Accent,
            TextSize = fs(11), Font = Enum.Font.GothamBold, TextXAlignment = Enum.TextXAlignment.Left,
            TextTruncate = Enum.TextTruncate.AtEnd, Parent = headerFrame,
        })
        reg(hlbl, "TextColor3", "Accent")
        local cont = make("Frame", { Size = UDim2.new(1,0,0,0), AutomaticSize = Enum.AutomaticSize.Y, BackgroundTransparency = 1, LayoutOrder = 1, Parent = f })
        make("UIListLayout", { SortOrder = Enum.SortOrder.LayoutOrder, Padding = sz(6), Parent = cont })
        return setmetatable({ Container = cont, Frame = f, _tab = nil, _subTab = nil, _compact = true }, Section)
    end

    function win:SetVisible(state)
        state = state and true or false
        if state == visible then return end
        visible = state
        gui.Enabled = state
    end
    function win:Toggle() self:SetVisible(not visible) end
    function win:Show() return self:SetVisible(true) end
    function win:Hide() return self:SetVisible(false) end
    function win:SetTheme(name) return Aurora:SetTheme(name) end
    function win:GetTheme() return Aurora.ThemeName or "Dark" end
    function win:Destroy()
        pcall(function() if win.SaveNow then win:SaveNow() end end)
        pcall(function() if _dragConn then _dragConn:Disconnect() end end)
        pcall(function() if _statConn then _statConn:Disconnect() end end)
        if Aurora._autoPersistHook then Aurora._autoPersistHook = nil end
        pcall(function() gui:Destroy() end)
    end

    closeBtn.MouseEnter:Connect(function() if _isMobile then return end tw(closeIco, { ImageColor3 = Color3.fromRGB(232,84,84) }, 0.12) end)
    closeBtn.MouseLeave:Connect(function() if _isMobile then return end tw(closeIco, { ImageColor3 = thm.SubText }, 0.12) end)
    closeBtn.MouseButton1Click:Connect(function()
        mainStroke.Enabled = false
        tw(main, { Size = UDim2.fromOffset(0,0), BackgroundTransparency = 1 }, 0.22, Enum.EasingStyle.Quad, Enum.EasingDirection.In)
        task.delay(0.24, function()
            if cfg.OnClose then pcall(cfg.OnClose) end
            win:Destroy()
        end)
    end)

    local minimizeKey = cfg.MinimizeKey
    if minimizeKey then
        UserInputService.InputBegan:Connect(function(input, processed)
            if processed then return end
            if input.KeyCode == minimizeKey then win:Toggle() end
        end)
    end

    -- ===== Auto-guardado automatico (independiente del SaveManager) =====
    -- Guarda solo en cada cambio y restaura al abrir. cfg.AutoSave=false lo desactiva.
    if cfg.AutoSave ~= false then
        local HttpService = game:GetService("HttpService")
        local folder = cfg.SaveFolder or "AuroraSettings"
        local safeName = tostring(cfg.SaveName or cfg.Title or "compact"):gsub("[^%w]", "_")
        local savePath = folder .. "/autosave_" .. safeName .. "_" .. tostring(game.PlaceId) .. ".json"
        local function _serialize()
            local data = {}
            for id, opt in pairs(Aurora.Options) do
                local v = opt.Value
                local t = typeof(v)
                if t == "boolean" or t == "number" or t == "string" then
                    data[id] = { t = t, v = v }
                elseif t == "Color3" then
                    data[id] = { t = "Color3", v = { math.floor(v.R*255+0.5), math.floor(v.G*255+0.5), math.floor(v.B*255+0.5) } }
                elseif t == "EnumItem" then
                    data[id] = { t = "Enum", e = tostring(v.EnumType), v = v.Name }
                elseif t == "table" then
                    data[id] = { t = "table", v = v }
                end
            end
            return data
        end
        function win:SaveNow()
            pcall(function()
                if makefolder and isfolder and not isfolder(folder) then makefolder(folder) end
                writefile(savePath, HttpService:JSONEncode(_serialize()))
            end)
        end
        function win:LoadNow()
            task.spawn(function()
                local data
                pcall(function()
                    if isfile and isfile(savePath) then data = HttpService:JSONDecode(readfile(savePath)) end
                end)
                if type(data) ~= "table" then return end
                -- Aplicar progresivamente: los elementos con LazyLoad se crean con delay,
                -- asi que reintentamos hasta que cada elemento exista (cada id una sola vez).
                local pending = {}
                for id in pairs(data) do pending[id] = true end
                local deadline = tick() + 10
                while next(pending) and tick() < deadline do
                    for id in pairs(pending) do
                        local opt = Aurora.Options[id]
                        if opt and opt.SetValue then
                            local entry = data[id]
                            local ok, val = pcall(function()
                                if entry.t == "Color3" then
                                    return Color3.fromRGB(entry.v[1], entry.v[2], entry.v[3])
                                elseif entry.t == "Enum" then
                                    local et = tostring(entry.e):gsub("^Enum%.", "")
                                    return Enum[et][entry.v]
                                else
                                    return entry.v
                                end
                            end)
                            if ok and val ~= nil then pcall(function() opt:SetValue(val) end) end
                            pending[id] = nil
                        end
                    end
                    task.wait(0.2)
                end
            end)
        end
        function win:ClearSave() pcall(function() if delfile and isfile and isfile(savePath) then delfile(savePath) end end) end
        local _saveTok = 0
        Aurora._autoPersistHook = function()
            _saveTok = _saveTok + 1
            local myTok = _saveTok
            task.delay(0.4, function() if myTok == _saveTok then win:SaveNow() end end)
        end
        task.delay(0.3, function() win:LoadNow() end)
    end

    return win
end

function Aurora:CreateWindow(cfg)
    cfg = cfg or {}
    _isMobile = isMobileDevice()
    if type(cfg.MobileMode) == "boolean" then _isMobile = cfg.MobileMode end
    pcall(function()
        local staleNames = {
            AuroraLib=true, AuroraMobileToggleGui=true, AuroraMobileKeybinds=true,
            AuroraWatermark=true, AuroraKeybindList=true, AuroraTooltip=true,
            AuroraNotif=true, AuroraThemeEditor=true, AuroraPerformanceOverlay=true,
            AuroraLoadingGui=true, AuroraExecWarn=true, AuroraKeySystem=true, AuroraHUD=true,
        }
        local function cleanGuiContainer(container)
            if not container then return end
            for _, child in ipairs(container:GetChildren()) do
                if staleNames[child.Name] then
                    pcall(function() child:Destroy() end)
                end
            end
        end
        cleanGuiContainer(CoreGui)
        local player = Players.LocalPlayer
        cleanGuiContainer(player and player:FindFirstChild("PlayerGui"))
        Aurora.MobileKeybindsGui = nil
        _mobileKeybindCount = 0
    end)

    cfg=cfg or{}
    local defaultScale = _isMobile and 0.85 or 1.0
    SC=math.clamp(cfg.Scale or defaultScale, 0.4, 2.0); self.Scale=SC
    if cfg.Theme == "RGB" then
        self:SetTheme("RGB")
    else
        local selectedTheme = type(cfg.Theme) == "table" and cfg.Theme or (self.Themes[cfg.Theme] or self.Themes.Dark)
        self.Theme = copyTheme(selectedTheme)
        self._activeThemePrivate = true
        self.ThemeName = self.Themes[cfg.Theme] and cfg.Theme or "Dark"
        if type(cfg.Theme) == "table" then self.ThemeName = "Custom" end
    end
    self.Acrylic = cfg.Acrylic == true
    Aurora.MobileButtonOverride = (cfg.MobileButton == true)
    Aurora.LazyLoad = cfg.LazyLoad ~= false
    Aurora.FadeIn = cfg.FadeIn ~= false and not _isMobile
    Aurora.DelayPerTab = cfg.DelayPerTab == nil and 0.08 or math.max(0, tonumber(cfg.DelayPerTab) or 0.08)
    Aurora.DelayPerSection = cfg.DelayPerSection == nil and 0.04 or math.max(0, tonumber(cfg.DelayPerSection) or 0.04)
    Aurora.DelayPerElement = cfg.DelayPerElement == nil and 0.012 or math.max(0, tonumber(cfg.DelayPerElement) or 0.012)
    if cfg.AutoExecute then
        pcall(function() Aurora:SetupAutoExecute(cfg.AutoExecute, cfg.AutoExecuteName) end)
    end
    local thm=self.Theme
    local winConnections = {}
    local gui=make("ScreenGui",{Name="AuroraLib",ResetOnSpawn=false,DisplayOrder=9998,ZIndexBehavior=Enum.ZIndexBehavior.Sibling})
    safeParent(gui)
    local windowSize = cfg.Size or ss(720,_isMobile and 480 or 530)
    local minimized=false; local maximized=false
    local originalSize=windowSize
    local expandedSize=windowSize
    local windowPosition = cfg.Position or UDim2.new(0.5,0,0.5,0)
    local shadow=make("Frame",{
        Name="WindowShadow",
        Size=UDim2.new(windowSize.X.Scale,windowSize.X.Offset+s(14),windowSize.Y.Scale,windowSize.Y.Offset+s(14)),
        AnchorPoint=Vector2.new(0.5,0.5), Position=windowPosition,
        BackgroundColor3=Color3.new(0,0,0), BackgroundTransparency=0.5,
        BorderSizePixel=0, ZIndex=0, Parent=gui,
    })
    make("UICorner",{CornerRadius=sz(18),Parent=shadow})
    local main=make("Frame",{
        Name="MainFrame",
        Size=windowSize,
        AnchorPoint=Vector2.new(0.5,0.5), Position=windowPosition,
        BackgroundColor3=thm.Background,
        BackgroundTransparency=self.Acrylic and 0.18 or 0,
        ClipsDescendants=true, Parent=gui,
    })
    local mainScale=make("UIScale",{Name="MainUIScale",Scale=1,Parent=main})
    local shadowScale=make("UIScale",{Name="ShadowUIScale",Scale=1,Parent=shadow})
    local function recalibrateScale()
        local cam = workspace.CurrentCamera
        local vp = cam and cam.ViewportSize or Vector2.new(1920, 1080)
        local isMobile = _isMobile
        local available = gui.AbsoluteSize
        if available.X > 0 and available.Y > 0 then vp = available end
        -- Android can report an empty viewport during client initialization.
        if vp.X <= 1 or vp.Y <= 1 then return end
        local baseW = math.max(1, vp.X * windowSize.X.Scale + windowSize.X.Offset)
        local baseH = math.max(1, vp.Y * windowSize.Y.Scale + windowSize.Y.Offset)
        local vpMin = math.min(vp.X, vp.Y)
        local isSmallPhone = isMobile and vpMin < 420
        local isMedPhone = isMobile and vpMin >= 420 and vpMin < 600
        local maxRatioW, maxRatioH, scaleMax
        if isSmallPhone then
            maxRatioW, maxRatioH = 0.82, 0.70
            scaleMax = 0.78
        elseif isMedPhone then
            maxRatioW, maxRatioH = 0.82, 0.70
            scaleMax = 0.82
        elseif isMobile then
            maxRatioW, maxRatioH = 0.80, 0.72
            scaleMax = 0.85
        else
            maxRatioW, maxRatioH = 0.90, 0.88
            scaleMax = 1.0
        end
        local targetScale = math.min((vp.X * maxRatioW) / baseW, (vp.Y * maxRatioH) / baseH)
        local finalScale = math.min(targetScale, scaleMax)
        if cfg.Scale and type(cfg.Scale) == "number" and not isMobile then
            finalScale = cfg.Scale
        end
        if isMobile then
            -- One scale only: resize the layout area instead of magnifying descendants.
            finalScale = 0.8 / SC
            local landscape=vp.X>vp.Y
            local widthLimit=vp.X*(landscape and 0.66 or 0.92)
            local heightLimit=vp.Y*(landscape and 0.80 or 0.66)
            local fittedSize=UDim2.fromOffset(
                math.floor(math.min(baseW, s(720), widthLimit/finalScale)),
                math.floor(math.min(baseH, s(510), heightLimit/finalScale))
            )
            originalSize=fittedSize
            expandedSize=fittedSize
            main.Size=minimized and UDim2.new(0,fittedSize.X.Offset,0,s(50)) or fittedSize
            shadow.Size=UDim2.new(0,main.Size.X.Offset+s(14),0,main.Size.Y.Offset+s(14))
        end
        mainScale.Scale = finalScale
        shadowScale.Scale = finalScale
    end
    recalibrateScale()
    table.insert(winConnections, gui:GetPropertyChangedSignal("AbsoluteSize"):Connect(recalibrateScale))
    local cam = workspace.CurrentCamera
    if cam then
        table.insert(winConnections, cam:GetPropertyChangedSignal("ViewportSize"):Connect(recalibrateScale))
    end
    table.insert(winConnections, workspace:GetPropertyChangedSignal("CurrentCamera"):Connect(function()
        local currentCamera = workspace.CurrentCamera
        if currentCamera then
            table.insert(winConnections, currentCamera:GetPropertyChangedSignal("ViewportSize"):Connect(recalibrateScale))
        end
        recalibrateScale()
    end))
    local bgImg=make("ImageLabel",{
        Name="WindowBackground",
        Size=UDim2.fromScale(1,1),
        BackgroundTransparency=1,
        ScaleType=Enum.ScaleType.Crop,
        ZIndex=0,
        Parent=main,
    })
    make("UICorner",{CornerRadius=sz(16),Parent=bgImg})
    reg(bgImg, "Image", "BackgroundImage")
    reg(bgImg, "ImageTransparency", "BackgroundImageTransparency")
    if self.Acrylic then
        createAcrylic(main)
    end
    make("UICorner",{CornerRadius=sz(16),Parent=main})
    local mainStroke=make("UIStroke",{Color=thm.Accent,Thickness=1.2,Transparency=0.35,Parent=main})
    reg(mainStroke,"Color","Accent")
    local topAccentLine=make("Frame",{
        Size=UDim2.new(1,0,0,s(2)),BackgroundColor3=thm.Accent,
        BackgroundTransparency=0.35,BorderSizePixel=0,ZIndex=2,Parent=main,
    })
    reg(topAccentLine,"BackgroundColor3","Accent")
    table.insert(winConnections, main:GetPropertyChangedSignal("Size"):Connect(function()
        shadow.Size=UDim2.new(main.Size.X.Scale,main.Size.X.Offset+s(14),main.Size.Y.Scale,main.Size.Y.Offset+s(14))
    end))
    table.insert(winConnections, main:GetPropertyChangedSignal("Position"):Connect(function()
        shadow.Position=main.Position
    end))
    local sidebarTrans = self.Acrylic and 0.6 or 0.08
    local _sidebarW = _isMobile and s(150) or s(192)
    local sidebar=make("Frame",{Name="Sidebar",Size=UDim2.new(0,_sidebarW,1,0),BackgroundColor3=thm.Sidebar,BackgroundTransparency=sidebarTrans,Parent=main})
    make("UICorner",{CornerRadius=sz(16),Parent=sidebar})
    local sbPatch=make("Frame",{Name="CornerPatch",Size=UDim2.new(0,s(16),1,0),Position=UDim2.new(1,-s(16),0,0),BackgroundColor3=thm.Sidebar,BackgroundTransparency=sidebarTrans,BorderSizePixel=0,Parent=sidebar})
    local _sbDiv=make("Frame",{Size=UDim2.new(0,1,1,0),Position=UDim2.new(1,0,0,0),BackgroundColor3=thm.Border,BackgroundTransparency=0.25,BorderSizePixel=0,Parent=sidebar})
    reg(_sbDiv,"BackgroundColor3","Border")
    make("UIGradient",{Rotation=90,Transparency=NumberSequence.new({NumberSequenceKeypoint.new(0,1),NumberSequenceKeypoint.new(0.18,0.5),NumberSequenceKeypoint.new(0.82,0.5),NumberSequenceKeypoint.new(1,1)}),Parent=_sbDiv})
    local logoFrame=make("Frame",{Size=UDim2.new(1,0,0,s(56)),BackgroundTransparency=1,Parent=sidebar})
    make("UIPadding",{PaddingLeft=sz(13),PaddingTop=sz(12),Parent=logoFrame})
    local logoBadge=make("Frame",{Size=ss(29,29),AnchorPoint=Vector2.new(0,0),Position=UDim2.new(0,0,0,s(1)),BackgroundColor3=thm.Accent,BackgroundTransparency=0.8,BorderSizePixel=0,Parent=logoFrame})
    make("UICorner",{CornerRadius=sz(9),Parent=logoBadge})
    make("UIStroke",{Color=thm.Accent,Thickness=1,Transparency=0.45,Parent=logoBadge})
    local logoGrad=make("UIGradient",{Color=ColorSequence.new(thm.Accent, Color3.fromRGB(math.floor(thm.Accent.R*255*0.6),math.floor(thm.Accent.G*255*0.6),math.floor(thm.Accent.B*255*0.6))),Rotation=90,Parent=logoBadge})
    local logoIco=make("ImageLabel",{Size=(cfg.Logo and cfg.Logo~="" and ss(26,26) or ss(17,17)),AnchorPoint=Vector2.new(0.5,0.5),Position=UDim2.fromScale(0.5,0.5),BackgroundTransparency=1,Parent=logoBadge})
    if cfg.Logo and cfg.Logo~="" then
        logoIco.Image=tostring(cfg.Logo)
        if cfg.LogoBadge==false then
            logoBadge.BackgroundTransparency=1
            for _,_ch in ipairs(logoBadge:GetChildren()) do if _ch:IsA("UIStroke") or _ch:IsA("UIGradient") then _ch.Enabled=false end end
            logoIco.Size=ss(29,29)
        end
    else
        applyIcon(logoIco,cfg.Icon or "solar/bolt-circle-bold",thm.Accent)
    end
    make("TextLabel",{
        Size=UDim2.new(1,-s(44),0,s(16)),Position=UDim2.new(0,s(37),0,s(1)),
        BackgroundTransparency=1,Text=cfg.Title or "Aurora",TextColor3=thm.Text,
        TextSize=fs(15),Font=Enum.Font.GothamBlack,TextXAlignment=Enum.TextXAlignment.Left,TextTruncate=Enum.TextTruncate.AtEnd,Parent=logoFrame,
    })
    if cfg.SubTitle then
        make("TextLabel",{
            Size=UDim2.new(1,-s(44),0,s(11)),Position=UDim2.new(0,s(37),0,s(18)),
            BackgroundTransparency=1,Text=cfg.SubTitle,TextColor3=thm.SubText,
            TextSize=fs(10),Font=Enum.Font.Gotham,TextXAlignment=Enum.TextXAlignment.Left,TextTruncate=Enum.TextTruncate.AtEnd,Parent=logoFrame,
        })
    end
    local _logoDiv=make("Frame",{Size=UDim2.new(1,-s(24),0,s(1)),Position=UDim2.new(0,s(12),1,-1),BackgroundColor3=thm.Border,BackgroundTransparency=0.45,BorderSizePixel=0,Parent=logoFrame})
    make("UIGradient",{Transparency=NumberSequence.new({NumberSequenceKeypoint.new(0,0.6),NumberSequenceKeypoint.new(0.5,0),NumberSequenceKeypoint.new(1,0.6)}),Parent=_logoDiv})
    local userPanel=make("TextButton",{Size=UDim2.new(1,-s(20),0,s(48)),Position=UDim2.new(0,s(10),0,s(60)),BackgroundColor3=thm.Element,BackgroundTransparency=0.35,Text="",AutoButtonColor=false,Parent=sidebar})
    make("UICorner",{CornerRadius=sz(12),Parent=userPanel})
    make("UIStroke",{Color=thm.Border,Thickness=1,Transparency=0.4,Parent=userPanel})
    local avatarImg=make("ImageLabel",{Size=ss(30,30),Position=UDim2.new(0,s(9),0.5,0),AnchorPoint=Vector2.new(0,0.5),BackgroundColor3=thm.Element,BackgroundTransparency=0.4,Parent=userPanel})
    make("UICorner",{CornerRadius=UDim.new(1,0),Parent=avatarImg})
    make("UIStroke",{Color=thm.Accent,Thickness=1.5,Transparency=0.4,Parent=avatarImg})
    
    local realAvatar = ""
    local realName = LocalPlayer.DisplayName or LocalPlayer.Name
    local profileHidden = false
    
    task.spawn(function()
        pcall(function()
            local content,isReady=Players:GetUserThumbnailAsync(LocalPlayer.UserId,Enum.ThumbnailType.HeadShot,Enum.ThumbnailSize.Size48x48)
            if isReady and avatarImg and avatarImg.Parent then 
                avatarImg.Image=content 
                realAvatar = content
            end
        end)
    end)
    local welcomeLbl = make("TextLabel",{Size=UDim2.new(1,-s(50),0,s(12)),Position=UDim2.new(0,s(46),0,s(4)),BackgroundTransparency=1,Text="Welcome back,",TextColor3=thm.SubText,TextSize=fs(9),Font=Enum.Font.Gotham,TextXAlignment=Enum.TextXAlignment.Left,Parent=userPanel})
    local userLbl = make("TextLabel",{Size=UDim2.new(1,-s(50),0,s(16)),Position=UDim2.new(0,s(46),0,s(14)),BackgroundTransparency=1,Text=realName,TextColor3=thm.Text,TextSize=fs(15),Font=Enum.Font.GothamBold,TextXAlignment=Enum.TextXAlignment.Left,TextTruncate=Enum.TextTruncate.AtEnd,Parent=userPanel})
    local _execName = "Unknown"
    pcall(function()
        if identifyexecutor then _execName = tostring((identifyexecutor()))
        elseif getexecutorname then _execName = tostring((getexecutorname()))
        elseif (syn and syn.request) then _execName = "Synapse X"
        elseif fluxus then _execName = "Fluxus"
        elseif KRNL_LOADED then _execName = "KRNL" end
    end)
    if _execName == nil or _execName == "" then _execName = "Unknown" end
    local _platform = _isMobile and "Mobile" or "PC"
    local execLbl = make("TextLabel",{Size=UDim2.new(1,-s(50),0,s(12)),Position=UDim2.new(0,s(46),0,s(32)),BackgroundTransparency=1,Text=_execName.." (".._platform..")",TextColor3=thm.Accent,TextSize=fs(9),Font=Enum.Font.GothamBold,TextXAlignment=Enum.TextXAlignment.Left,TextTruncate=Enum.TextTruncate.AtEnd,Parent=userPanel})

    userPanel.MouseButton1Click:Connect(function()
        profileHidden = not profileHidden
        if profileHidden then
            userLbl.Text = "********"
            welcomeLbl.Text = "Hidden Mode,"
            avatarImg.ImageTransparency = 0.9
            avatarImg.ImageColor3 = Color3.new(0, 0, 0)
        else
            userLbl.Text = realName
            welcomeLbl.Text = "Welcome back,"
            avatarImg.ImageTransparency = 0
            avatarImg.ImageColor3 = Color3.new(1, 1, 1)
        end
    end)
    local searchFrame=make("Frame",{Size=UDim2.new(1,-s(20),0,s(30)),Position=UDim2.new(0,s(10),0,s(114)),BackgroundColor3=thm.InputBG,BackgroundTransparency=0.3,Parent=sidebar})
    make("UICorner",{CornerRadius=sz(10),Parent=searchFrame})
    local searchStroke=make("UIStroke",{Color=thm.Border,Thickness=1,Transparency=0.5,Parent=searchFrame})
    local searchIco=make("ImageLabel",{Size=ss(13,13),Position=UDim2.new(0,s(9),0.5,0),AnchorPoint=Vector2.new(0,0.5),BackgroundTransparency=1,Parent=searchFrame})
    applyIcon(searchIco,"solar/magnifer-linear",thm.SubText)
    local searchBox=make("TextBox",{
        Size=UDim2.new(1,-s(48),1,0),Position=UDim2.new(0,s(26),0,0),
        BackgroundTransparency=1,PlaceholderText="Search tabs...",PlaceholderColor3=thm.SubText,
        Text="",TextColor3=thm.Text,TextSize=fs(12),Font=Enum.Font.Gotham,TextXAlignment=Enum.TextXAlignment.Left,ClearTextOnFocus=false,Parent=searchFrame,
    })
    pcall(function() searchBox.Focused:Connect(function()
        tw(searchStroke, { Color = Aurora.Theme.Accent, Transparency = 0.05 }, 0.18)
        tw(searchFrame, { BackgroundTransparency = 0.15 }, 0.18)
        tw(searchIco, { ImageColor3 = Aurora.Theme.Accent }, 0.18)
    end) end)
    searchBox.FocusLost:Connect(function()
        tw(searchStroke, { Color = Aurora.Theme.Border, Transparency = 0.5 }, 0.18)
        tw(searchFrame, { BackgroundTransparency = 0.3 }, 0.18)
        tw(searchIco, { ImageColor3 = Aurora.Theme.SubText }, 0.18)
    end)
    local searchClear = make("TextButton", {
        Size = ss(18,18), AnchorPoint = Vector2.new(1,0.5), Position = UDim2.new(1,-s(7),0.5,0),
        BackgroundColor3 = thm.Element, BackgroundTransparency = 0.4, Text = "",
        AutoButtonColor = false, Visible = false, ZIndex = 3, Parent = searchFrame,
    })
    make("UICorner", { CornerRadius = UDim.new(1,0), Parent = searchClear })
    local searchClearIco = make("ImageLabel", {
        Size = ss(10,10), AnchorPoint = Vector2.new(0.5,0.5), Position = UDim2.fromScale(0.5,0.5),
        BackgroundTransparency = 1, Parent = searchClear,
    })
    applyIcon(searchClearIco, "solar/close-circle-bold", thm.SubText)
    searchClear.MouseButton1Click:Connect(function()
        searchBox.Text = ""
        pcall(function() searchBox:CaptureFocus() end)
    end)
    searchClear.MouseEnter:Connect(function() if _isMobile then return end tw(searchClear, { BackgroundTransparency = 0.15 }, 0.1) end)
    searchClear.MouseLeave:Connect(function() if _isMobile then return end tw(searchClear, { BackgroundTransparency = 0.4 }, 0.1) end)
    searchBox:GetPropertyChangedSignal("Text"):Connect(function()
        searchClear.Visible = searchBox.Text ~= ""
    end)
    local tabScroll=make("ScrollingFrame",{
        Size=UDim2.new(1,0,1,-s(194)),Position=UDim2.new(0,0,0,s(150)),
        BackgroundTransparency=1,ScrollBarThickness=_isMobile and s(6) or s(2),ScrollBarImageColor3=thm.Scrollbar,ScrollBarImageTransparency=0.45,Parent=sidebar,
    })
    local slay=make("UIListLayout",{SortOrder=Enum.SortOrder.LayoutOrder,Padding=sz(2),Parent=tabScroll})
    make("UIPadding",{PaddingTop=sz(6),PaddingBottom=sz(6),PaddingLeft=sz(8),PaddingRight=sz(8),Parent=tabScroll})
    tabScroll.CanvasSize=UDim2.fromOffset(0,0)
    tabScroll.AutomaticCanvasSize=Enum.AutomaticSize.Y
    tabScroll.ScrollingDirection=Enum.ScrollingDirection.Y
    local content=make("Frame",{Name="Content",Size=UDim2.new(1,-_sidebarW,1,0),Position=UDim2.new(0,_sidebarW,0,0),BackgroundTransparency=1,Parent=main})
    local topTrans = self.Acrylic and 0.65 or 0.1
    local top=make("Frame",{Name="Top",Size=UDim2.new(1,0,0,s(50)),BackgroundColor3=thm.TopBar,BackgroundTransparency=topTrans,Parent=content})
    make("UICorner",{CornerRadius=sz(16),Parent=top})
    make("Frame",{Name="CornerPatch",Size=UDim2.new(1,0,0,s(16)),Position=UDim2.new(0,0,1,-s(16)),BackgroundColor3=thm.TopBar,BackgroundTransparency=topTrans,BorderSizePixel=0,Parent=top})
    make("Frame",{Name="CornerPatch",Size=UDim2.new(0,s(16),1,0),Position=UDim2.new(0,0,0,0),BackgroundColor3=thm.TopBar,BackgroundTransparency=topTrans,BorderSizePixel=0,Parent=top})
    -- Gradient overlay on TopBar
    local _topGrad = make("Frame",{Name="TopGradient",Size=UDim2.fromScale(1,1),BackgroundTransparency=1,BorderSizePixel=0,ZIndex=0,Parent=top})
    make("UIGradient",{
        Color=ColorSequence.new({
            ColorSequenceKeypoint.new(0, thm.Accent),
            ColorSequenceKeypoint.new(1, thm.TopBar),
        }),
        Transparency=NumberSequence.new({
            NumberSequenceKeypoint.new(0, 0.88),
            NumberSequenceKeypoint.new(0.6, 0.96),
            NumberSequenceKeypoint.new(1, 1),
        }),
        Rotation=0, Parent=_topGrad,
    })
    local _topDiv=make("Frame",{Size=UDim2.new(1,0,0,1),Position=UDim2.new(0,0,1,-1),BackgroundColor3=thm.Border,BackgroundTransparency=0.25,BorderSizePixel=0,Parent=top})
    reg(_topDiv,"BackgroundColor3","Border")
    make("UIGradient",{Transparency=NumberSequence.new({NumberSequenceKeypoint.new(0,1),NumberSequenceKeypoint.new(0.12,0.35),NumberSequenceKeypoint.new(0.88,0.35),NumberSequenceKeypoint.new(1,1)}),Parent=_topDiv})
    local tabHold=make("Frame",{Size=UDim2.new(1,-s(12),1,-s(66)),Position=UDim2.new(0,0,0,s(50)),BackgroundTransparency=1,Parent=content})
    local function makeCtrlBtn(order, hoverBG)
        local btn=make("TextButton",{Size=_isMobile and ss(44,44) or ss(20,20),BackgroundTransparency=1,Text="",LayoutOrder=order,ZIndex=10000,Parent=nil})
        make("UICorner",{CornerRadius=sz(8),Parent=btn})
        local btnScale = make("UIScale", { Scale = 1, Parent = btn })
        btn.MouseEnter:Connect(function() if _isMobile then return end tw(btn,{BackgroundColor3=hoverBG,BackgroundTransparency=0.15},0.1) end)
        btn.MouseLeave:Connect(function() if _isMobile then return end tw(btn,{BackgroundTransparency=1},0.1) end)
        btn.InputBegan:Connect(function(input)
            if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
                tw(btnScale, { Scale = 0.92 }, 0.06)
            end
        end)
        btn.InputEnded:Connect(function(input)
            if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
                tw(btnScale, { Scale = 1 }, 0.12, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
            end
        end)
        return btn
    end
    local controls=make("Frame",{Size=ss(80,20),Position=UDim2.new(1,-s(12),0,s(12)),AnchorPoint=Vector2.new(1,0),BackgroundTransparency=1,ZIndex=9999,Parent=main})
    if _isMobile then
        controls.Size = ss(142,44)
        controls.Position = UDim2.new(1,-s(6),0,s(3))
    end
    make("UIListLayout",{FillDirection=Enum.FillDirection.Horizontal,HorizontalAlignment=Enum.HorizontalAlignment.Right,SortOrder=Enum.SortOrder.LayoutOrder,Padding=sz(5),Parent=controls})
    local minBtn=makeCtrlBtn(1,thm.ElementHover); minBtn.Parent=controls
    local maxBtn=makeCtrlBtn(2,thm.ElementHover); maxBtn.Parent=controls
    local closeBtn=makeCtrlBtn(3,thm.AlertError); closeBtn.Parent=controls
    local minLine=make("Frame",{Size=UDim2.fromOffset(s(8),s(1)),AnchorPoint=Vector2.new(0.5,0.5),Position=UDim2.fromScale(0.5,0.5),BackgroundColor3=thm.SubText,BorderSizePixel=0,Parent=minBtn})
    local maxIco=make("Frame",{Size=UDim2.fromOffset(s(8),s(8)),AnchorPoint=Vector2.new(0.5,0.5),Position=UDim2.fromScale(0.5,0.5),BackgroundTransparency=1,Parent=maxBtn})
    local maxStk=make("UIStroke",{Color=thm.SubText,Thickness=1,Parent=maxIco})
    local clsIco=make("Frame",{Size=UDim2.fromOffset(s(8),s(8)),AnchorPoint=Vector2.new(0.5,0.5),Position=UDim2.fromScale(0.5,0.5),BackgroundTransparency=1,Parent=closeBtn})
    local cl1=make("Frame",{Size=UDim2.new(1,0,0,s(1)),AnchorPoint=Vector2.new(0.5,0.5),Position=UDim2.fromScale(0.5,0.5),BackgroundColor3=thm.SubText,BorderSizePixel=0,Rotation=45,Parent=clsIco})
    local cl2=make("Frame",{Size=UDim2.new(1,0,0,s(1)),AnchorPoint=Vector2.new(0.5,0.5),Position=UDim2.fromScale(0.5,0.5),BackgroundColor3=thm.SubText,BorderSizePixel=0,Rotation=-45,Parent=clsIco})
    local drag,ds,sp=false,nil,nil
    local targetPos = nil
    top.InputBegan:Connect(function(i)
        if i.UserInputType==Enum.UserInputType.MouseButton1 or i.UserInputType==Enum.UserInputType.Touch then
            drag=true; ds=i.Position; sp=main.Position
            targetPos = sp
        end
    end)
    local dragChanged = UserInputService.InputChanged:Connect(function(i)
        if drag and (i.UserInputType==Enum.UserInputType.MouseMovement or i.UserInputType==Enum.UserInputType.Touch) then
            local delta=i.Position-ds
            targetPos = UDim2.new(sp.X.Scale, sp.X.Offset + delta.X, sp.Y.Scale, sp.Y.Offset + delta.Y)
        end
    end)
    local rsConn = game:GetService("RunService").RenderStepped:Connect(function(dt)
        if drag and targetPos then
            main.Position = main.Position:Lerp(targetPos, math.clamp(dt * 15, 0, 1))
        end
    end)
    local dragEnded = UserInputService.InputEnded:Connect(function(i)
        if i.UserInputType==Enum.UserInputType.MouseButton1 or i.UserInputType==Enum.UserInputType.Touch then
            drag=false
        end
    end)
    table.insert(winConnections, dragChanged)
    table.insert(winConnections, dragEnded)
    table.insert(winConnections, rsConn)
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
    local resizeScale = make("UIScale", {Scale=mainScale.Scale, Parent=resizeOverlay})
    table.insert(winConnections, mainScale:GetPropertyChangedSignal("Scale"):Connect(function()
        shadowScale.Scale = mainScale.Scale
        resizeScale.Scale = mainScale.Scale
    end))
    main:GetPropertyChangedSignal("Size"):Connect(function()
        resizeOverlay.Size = main.Size
    end)
    main:GetPropertyChangedSignal("Position"):Connect(function()
        resizeOverlay.Position = main.Position
    end)
    local minW,minH=s(400),s(300)
    local resizing=false
    local resizeCorner=make("TextButton",{
        Size=ss(16,16),AnchorPoint=Vector2.new(1,1),Position=UDim2.new(1,0,1,0),
        BackgroundColor3=Color3.fromRGB(255,255,255),BackgroundTransparency=0.9,
        Text="",ZIndex=10001,Parent=resizeOverlay,
    })
    make("UICorner",{CornerRadius=sz(4),Parent=resizeCorner})
    for di=1,3 do
        local _rd=make("Frame",{
            Size=ss(2,2),AnchorPoint=Vector2.new(1,1),
            Position=UDim2.new(1,-s(2+(di-1)*4),1,-s(2+(di-1)*4)),
            BackgroundColor3=thm.SubText,BackgroundTransparency=0.4,BorderSizePixel=0,Parent=resizeCorner,
        })
        make("UICorner",{CornerRadius=UDim.new(1,0),Parent=_rd})
    end
    local resizeStartPos,resizeStartSize
    resizeCorner.InputBegan:Connect(function(i)
        if i.UserInputType==Enum.UserInputType.MouseButton1 or i.UserInputType==Enum.UserInputType.Touch then
            resizing=true; resizeStartPos=i.Position
            resizeStartSize=main.AbsoluteSize / mainScale.Scale
        end
    end)
    local resChanged = UserInputService.InputChanged:Connect(function(i)
        if resizing and (i.UserInputType==Enum.UserInputType.MouseMovement or i.UserInputType==Enum.UserInputType.Touch) then
            local delta=(i.Position-resizeStartPos) / mainScale.Scale
            main.Size=UDim2.fromOffset(math.max(minW,resizeStartSize.X+delta.X),math.max(minH,resizeStartSize.Y+delta.Y))
        end
    end)
    local resEnded = UserInputService.InputEnded:Connect(function(i) if i.UserInputType==Enum.UserInputType.MouseButton1 or i.UserInputType==Enum.UserInputType.Touch then resizing=false end end)
    table.insert(winConnections, resChanged)
    table.insert(winConnections, resEnded)
    resizeCorner.MouseEnter:Connect(function() if _isMobile then return end tw(resizeCorner,{BackgroundTransparency=0.6},0.1) end)
    resizeCorner.MouseLeave:Connect(function() if _isMobile then return end tw(resizeCorner,{BackgroundTransparency=0.9},0.1) end)
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
        local hl = make("Frame", {
            Size = UDim2.fromScale(1, 1),
            BackgroundColor3 = thm.Accent,
            BackgroundTransparency = 1,
            BorderSizePixel = 0,
            Parent = edge
        })
        edge.MouseEnter:Connect(function() if _isMobile then return end
            tw(hl, { BackgroundTransparency = 0.65 }, 0.1)
        end)
        edge.MouseLeave:Connect(function() if _isMobile then return end
            tw(hl, { BackgroundTransparency = 1 }, 0.1)
        end)
        local dragStartPos, dragStartSize, dragStartWindowPos
        local dragging = false
        edge.InputBegan:Connect(function(input)
            if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
                dragging = true
                dragStartPos = input.Position
                dragStartSize = main.AbsoluteSize / mainScale.Scale
                dragStartWindowPos = Vector2.new(main.Position.X.Offset, main.Position.Y.Offset)
            end
        end)
        local edgeDrag = UserInputService.InputChanged:Connect(function(input)
            if dragging and (input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch) then
                local delta = (input.Position - dragStartPos) / mainScale.Scale
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
                    newX = dragStartWindowPos.X - dW * mainScale.Scale / 2
                elseif resizeType:find("Right") then
                    newX = dragStartWindowPos.X + dW * mainScale.Scale / 2
                end
                if resizeType:find("Top") then
                    newY = dragStartWindowPos.Y - dH * mainScale.Scale / 2
                elseif resizeType:find("Bottom") then
                    newY = dragStartWindowPos.Y + dH * mainScale.Scale / 2
                end
                main.Size = UDim2.fromOffset(newWidth, newHeight)
                main.Position = UDim2.new(main.Position.X.Scale, newX, main.Position.Y.Scale, newY)
            end
        end)
        local edgeEnd = UserInputService.InputEnded:Connect(function(input)
            if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
                dragging = false
            end
        end)
        table.insert(winConnections, edgeDrag)
        table.insert(winConnections, edgeEnd)
    end
    createResizeEdge("ResizeTop",    UDim2.new(1, -s(16), 0, s(6)),  UDim2.new(0, s(8), 0, -s(3)),  "Top")
    createResizeEdge("ResizeBottom", UDim2.new(1, -s(16), 0, s(6)),  UDim2.new(0, s(8), 1, -s(3)),  "Bottom")
    createResizeEdge("ResizeLeft",   UDim2.new(0, s(6), 1, -s(16)),  UDim2.new(0, -s(3), 0, s(8)),  "Left")
    createResizeEdge("ResizeRight",  UDim2.new(0, s(6), 1, -s(16)),  UDim2.new(1, -s(3), 0, s(8)),  "Right")
    createResizeEdge("ResizeTopLeft",     ss(12, 12), UDim2.new(0, -s(6), 0, -s(6)), "TopLeft")
    createResizeEdge("ResizeTopRight",    ss(12, 12), UDim2.new(1, -s(6), 0, -s(6)), "TopRight")
    createResizeEdge("ResizeBottomLeft",  ss(12, 12), UDim2.new(0, -s(6), 1, -s(6)), "BottomLeft")
    createResizeEdge("ResizeBottomRight", ss(12, 12), UDim2.new(1, -s(6), 1, -s(6)), "BottomRight")
    originalSize=main.Size
    expandedSize=main.Size
    local minimizeAnimating=false
    local largeSize=UDim2.fromOffset(math.floor(originalSize.X.Offset*1.28),math.floor(originalSize.Y.Offset*1.22))
    local function toggleMinimize()
        if minimizeAnimating then return end
        minimizeAnimating=true
        minimized=not minimized
        local targetSize
        if minimized then
            expandedSize=main.Size
            sidebar.Visible=false
            tabHold.Visible=false
            content.Position=UDim2.new(0,0,0,0); content.Size=UDim2.new(1,0,1,0)
            targetSize=UDim2.new(expandedSize.X.Scale,expandedSize.X.Offset,0,s(50))
            resizeOverlay.Visible = false
        else
            content.Position=UDim2.new(0,_sidebarW,0,0); content.Size=UDim2.new(1,-_sidebarW,1,0)
            targetSize=expandedSize
        end
        -- Keep the top edge fixed while folding; dragging the bar still works.
        local targetHeight=(gui.AbsoluteSize.Y*targetSize.Y.Scale+targetSize.Y.Offset)*mainScale.Scale
        local targetPosition=main.Position+UDim2.fromOffset(0,(targetHeight-main.AbsoluteSize.Y)/2)
        local animation=tw(main,{Size=targetSize,Position=targetPosition},0.22)
        animation.Completed:Once(function()
            minimizeAnimating=false
            sidebar.Visible=not minimized
            tabHold.Visible=not minimized
            resizeOverlay.Visible=not minimized and gui.Enabled
        end)
    end
    local function toggleMaximize()
        if minimized or minimizeAnimating then return end
        maximized=not maximized
        tw(main,{Size=maximized and largeSize or originalSize},0.2)
    end
    local function showClosePrompt()
        if gui:FindFirstChild("CloseOverlay") then return end
        local hiddenPremiumOverlays = {}
        for _, entry in ipairs(Aurora._premiumOverlays or {}) do
            if entry.Gui and entry.Gui.Parent and entry.Gui.Visible then
                entry.Gui.Visible = false
                table.insert(hiddenPremiumOverlays, entry)
            end
        end
        local function restorePremiumOverlays()
            for _, entry in ipairs(hiddenPremiumOverlays) do
                if entry.Gui and entry.Gui.Parent and type(entry.Sync) == "function" then
                    pcall(entry.Sync)
                end
            end
        end
        local overlay=make("TextButton",{
            Name="CloseOverlay",Size=UDim2.fromScale(1,1),BackgroundColor3=Color3.new(0,0,0),
            BackgroundTransparency=1,Text="",AutoButtonColor=false,Active=true,ZIndex=10000,Parent=gui,
        })
        local prompt=make("Frame",{
            Size=ss(300,160),AnchorPoint=Vector2.new(0.5,0.5),Position=UDim2.fromScale(0.5,0.5),
            BackgroundColor3=thm.NotifBG,BackgroundTransparency=0.04,ZIndex=10001,Parent=overlay,
        })
        make("UICorner",{CornerRadius=sz(15),Parent=prompt})
        local pStroke=make("UIStroke",{Color=thm.Border,Thickness=1,Transparency=0.18,Parent=prompt})
        make("UIPadding",{PaddingTop=sz(15),PaddingBottom=sz(13),PaddingLeft=sz(18),PaddingRight=sz(18),Parent=prompt})
        make("UIListLayout",{SortOrder=Enum.SortOrder.LayoutOrder,Padding=sz(7),HorizontalAlignment=Enum.HorizontalAlignment.Center,Parent=prompt})
        local promptScale=make("UIScale",{Scale=0.86,Parent=prompt})
        local warnIco=make("ImageLabel",{Size=ss(24,24),BackgroundTransparency=1,LayoutOrder=0,Parent=prompt})
        applyIcon(warnIco,"solar/danger-bold",thm.AlertWarn)
        make("TextLabel",{Size=UDim2.new(1,0,0,s(18)),BackgroundTransparency=1,Text="Close Interface?",TextColor3=thm.Text,TextSize=fs(14),Font=Enum.Font.GothamBold,TextXAlignment=Enum.TextXAlignment.Center,LayoutOrder=1,Parent=prompt})
        make("TextLabel",{Size=UDim2.new(1,0,0,s(27)),BackgroundTransparency=1,Text="Your active features will keep running.",TextColor3=thm.SubText,TextSize=fs(11),Font=Enum.Font.Gotham,TextWrapped=true,TextXAlignment=Enum.TextXAlignment.Center,LayoutOrder=2,Parent=prompt})
        local btnRow=make("Frame",{Size=UDim2.new(1,0,0,s(28)),BackgroundTransparency=1,LayoutOrder=3,Parent=prompt})
        make("UIListLayout",{FillDirection=Enum.FillDirection.Horizontal,HorizontalAlignment=Enum.HorizontalAlignment.Center,SortOrder=Enum.SortOrder.LayoutOrder,Padding=sz(9),Parent=btnRow})
        local noBtn=make("TextButton",{Size=ss(92,26),BackgroundColor3=thm.Element,Text="Cancel",TextColor3=thm.SubText,TextSize=fs(11),Font=Enum.Font.GothamBold,AutoButtonColor=false,LayoutOrder=1,Parent=btnRow})
        local noStroke=make("UIStroke",{Color=thm.Border,Thickness=1,Parent=noBtn})
        make("UICorner",{CornerRadius=sz(9),Parent=noBtn})
        local yesBtn=make("TextButton",{Size=ss(92,26),BackgroundColor3=thm.AlertError,Text="Close",TextColor3=Color3.fromRGB(255,255,255),TextSize=fs(11),Font=Enum.Font.GothamBold,AutoButtonColor=false,LayoutOrder=2,Parent=btnRow})
        local yesStroke=make("UIStroke",{Color=thm.AlertError,Thickness=1,Transparency=0.2,Parent=yesBtn})
        make("UICorner",{CornerRadius=sz(9),Parent=yesBtn})
        local function buttonHover(button,stroke,normal,hover)
            button.MouseEnter:Connect(function() if _isMobile then return end tw(button,{BackgroundColor3=hover},0.12); tw(stroke,{Color=hover},0.12) end)
            button.MouseLeave:Connect(function() if _isMobile then return end tw(button,{BackgroundColor3=normal},0.16); tw(stroke,{Color=normal},0.16) end)
            button.InputBegan:Connect(function(input) if input.UserInputType==Enum.UserInputType.MouseButton1 or input.UserInputType==Enum.UserInputType.Touch then tw(button,{Size=ss(89,25)},0.06) end end)
            button.InputEnded:Connect(function(input) if input.UserInputType==Enum.UserInputType.MouseButton1 or input.UserInputType==Enum.UserInputType.Touch then tw(button,{Size=ss(92,26)},0.12,Enum.EasingStyle.Quad,Enum.EasingDirection.Out) end end)
        end
        buttonHover(noBtn,noStroke,thm.Element,thm.ElementHover)
        buttonHover(yesBtn,yesStroke,thm.AlertError,thm.AlertError:Lerp(Color3.new(1,1,1),0.14))
        local closing=false
        local function cancelClose()
            if closing then return end
            closing=true
            tw(overlay,{BackgroundTransparency=1},0.18)
            tw(promptScale,{Scale=0.86},0.18,Enum.EasingStyle.Quad,Enum.EasingDirection.In)
            task.delay(0.2,function()
                pcall(function() overlay:Destroy() end)
                restorePremiumOverlays()
            end)
        end
        noBtn.MouseButton1Click:Connect(cancelClose)
        overlay.MouseButton1Click:Connect(cancelClose)
        yesBtn.MouseButton1Click:Connect(function()
            if closing then return end
            closing=true
            tw(overlay,{BackgroundTransparency=1},0.2)
            tw(promptScale,{Scale=0.86},0.2,Enum.EasingStyle.Quad,Enum.EasingDirection.In)
            tw(main,{Position=main.Position+UDim2.fromOffset(0,s(8)),BackgroundTransparency=1},0.22,Enum.EasingStyle.Quart,Enum.EasingDirection.In)
            tw(mainStroke,{Transparency=1},0.18)
            tw(shadow,{BackgroundTransparency=1},0.18)
            task.delay(0.25,function() pcall(function() gui:Destroy() end) end)
        end)
        tw(overlay,{BackgroundTransparency=0.36},0.22,Enum.EasingStyle.Quad,Enum.EasingDirection.Out)
        tw(promptScale,{Scale=1},0.28,Enum.EasingStyle.Back,Enum.EasingDirection.Out)
    end
    minBtn.Activated:Connect(toggleMinimize)
    maxBtn.Activated:Connect(toggleMaximize)
    closeBtn.Activated:Connect(showClosePrompt)
    -- [Opt] Envoltorio CanvasGroup: el toggle se anima por GroupTransparency
    -- (composite en GPU, sin re-layout) y el ScreenGui queda siempre Enabled
    -- (sin reconstruccion del arbol). Elimina el pico de FPS al ocultar/mostrar.
    local canvas = make(_isMobile and "Frame" or "CanvasGroup", {
        Name = "AuroraCanvas",
        Size = UDim2.fromScale(1, 1),
        BackgroundTransparency = 1,
        BorderSizePixel = 0,
        GroupTransparency = 0,
        ZIndex = 1,
        Parent = main,
    })
    make("UICorner", { CornerRadius = sz(16), Parent = canvas })
    for _, _ch in ipairs(main:GetChildren()) do
        if _ch ~= canvas and _ch:IsA("GuiObject") then
            _ch.Parent = canvas
        end
    end
    local minimizeKey=cfg.MinimizeKey or Enum.KeyCode.LeftShift
    local visible=true
    local win={Tabs={},Categories={},GUI=gui,MainFrame=main, _connections=winConnections}
    if cfg.LoadingScreen ~= false and not _isMobile then shadow.BackgroundTransparency = 1 end
    local uiScale = main:FindFirstChildOfClass("UIScale") or make("UIScale", { Scale = 1, Parent = main })
    local toggling = false
    local _mainBgShown = main.BackgroundTransparency
    local _strokeShown = mainStroke.Transparency
    function win:SetVisible(state)
        state = state and true or false
        if toggling or state == visible then return end
        if _isMobile then
            visible = state
            gui.Enabled = state
            main.Visible = state
            canvas.Visible = state
            resizeOverlay.Visible = state and not minimized
            return
        end
        toggling = true
        if state then
            visible = true
            gui.Enabled = true
            main.Visible = true
            canvas.Visible = true
            resizeOverlay.Visible = not minimized
            local rest = main.Position
            main.Position = rest + UDim2.fromOffset(0, s(16))
            tw(main, { Position = rest }, 0.30, Enum.EasingStyle.Quint, Enum.EasingDirection.Out)
            tw(main, { BackgroundTransparency = _mainBgShown }, 0.22, Enum.EasingStyle.Quart, Enum.EasingDirection.Out)
            tw(mainStroke, { Transparency = _strokeShown }, 0.22, Enum.EasingStyle.Quart, Enum.EasingDirection.Out)
            tw(shadow, { BackgroundTransparency = 0.5 }, 0.22, Enum.EasingStyle.Quart, Enum.EasingDirection.Out)
            local t = tw(canvas, { GroupTransparency = 0 }, 0.22, Enum.EasingStyle.Quart, Enum.EasingDirection.Out)
            t.Completed:Connect(function() toggling = false end)
        else
            resizeOverlay.Visible = false
            -- Salida: hunde levemente + fade. Nada de gui.Enabled ni main.Visible: cero rebuild.
            local rest = main.Position
            tw(main, { Position = rest + UDim2.fromOffset(0, s(12)) }, 0.18, Enum.EasingStyle.Quart, Enum.EasingDirection.In)
            tw(main, { BackgroundTransparency = 1 }, 0.16, Enum.EasingStyle.Quart, Enum.EasingDirection.In)
            tw(mainStroke, { Transparency = 1 }, 0.16, Enum.EasingStyle.Quart, Enum.EasingDirection.In)
            tw(shadow, { BackgroundTransparency = 1 }, 0.16, Enum.EasingStyle.Quart, Enum.EasingDirection.In)
            local t = tw(canvas, { GroupTransparency = 1 }, 0.16, Enum.EasingStyle.Quart, Enum.EasingDirection.In)
            t.Completed:Connect(function()
                main.Position = rest
                visible = false
                toggling = false
                -- Deshabilitar el ScreenGui al ocultar: deja de capturar clicks
                -- (asi puedes mover la camara donde antes estaba la GUI).
                gui.Enabled = false
            end)
        end
    end
    function win:Toggle()
        self:SetVisible(not visible)
    end
    function win:SetTheme(name)
        return Aurora:SetTheme(name)
    end
    function win:GetTheme()
        return Aurora.ThemeName or "Dark"
    end
    function win:SetScale(value)
        local scale = math.clamp(tonumber(value) or 1, 0.5, 1.5)
        uiScale.Scale = scale
        shadowScale.Scale = scale
        return scale
    end
    function win:GetScale()
        return uiScale.Scale
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
            local sidebar = self.MainFrame:FindFirstChild("Sidebar", true)
            if sidebar then
                local st = math.clamp(transparency + 0.15, 0, 0.95)
                tw(sidebar, { BackgroundTransparency = st }, 0.15)
                for _, child in ipairs(sidebar:GetChildren()) do
                    if child.Name == "CornerPatch" then
                        tw(child, { BackgroundTransparency = st }, 0.15)
                    end
                end
            end
            local content = self.MainFrame:FindFirstChild("Content", true)
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
    local minimizeConn
    if not _isMobile then
        minimizeConn = UserInputService.InputBegan:Connect(function(input, processed)
            if not processed and input.KeyCode == minimizeKey then
                win:Toggle()
            end
        end)
        table.insert(winConnections, minimizeConn)
        -- Change Key button (only when KeySystem was used with SaveKey)
        if Aurora._keyConfig and Aurora._keyConfig.SaveKey then
            tabScroll.Size = UDim2.new(1, 0, 1, -s(216))
            local ckBtn = make("TextButton", {
                Size = UDim2.new(1, -s(18), 0, s(28)),
                Position = UDim2.new(0, s(9), 1, -s(72)),
                BackgroundColor3 = thm.Element,
                BackgroundTransparency = 0.5,
                Text = "",
                AutoButtonColor = false,
                Parent = sidebar,
            })
            make("UICorner", { CornerRadius = sz(10), Parent = ckBtn })
            local ckStroke = make("UIStroke", { Color = thm.Border, Thickness = 1, Transparency = 0.5, Parent = ckBtn })
            make("UIPadding", { PaddingLeft = sz(8), PaddingRight = sz(8), Parent = ckBtn })
            local ckIco = make("ImageLabel", {
                Size = ss(12, 12), AnchorPoint = Vector2.new(0, 0.5),
                Position = UDim2.new(0, 0, 0.5, 0), BackgroundTransparency = 1, Parent = ckBtn,
            })
            applyIcon(ckIco, "solar/key-minimalistic-bold", thm.SubText)
            make("TextLabel", {
                Size = UDim2.new(1, -s(18), 1, 0), Position = UDim2.new(0, s(18), 0, 0),
                BackgroundTransparency = 1, Text = "Change Key",
                TextColor3 = thm.SubText, TextSize = fs(10), Font = Enum.Font.GothamBold,
                TextXAlignment = Enum.TextXAlignment.Left, Parent = ckBtn,
            })
            ckBtn.MouseEnter:Connect(function() if _isMobile then return end
                tw(ckBtn, { BackgroundTransparency = 0.25, BackgroundColor3 = thm.ElementHover }, 0.12)
                tw(ckStroke, { Transparency = 0.2 }, 0.12)
            end)
            ckBtn.MouseLeave:Connect(function() if _isMobile then return end
                tw(ckBtn, { BackgroundTransparency = 0.5, BackgroundColor3 = thm.Element }, 0.12)
                tw(ckStroke, { Transparency = 0.5 }, 0.12)
            end)
            ckBtn.MouseButton1Click:Connect(function()
                local kc = Aurora._keyConfig
                if main:FindFirstChild("KeyChangeOverlay") then return end
                local overlay = make("TextButton", {
                    Name = "KeyChangeOverlay", Size = UDim2.fromScale(1, 1),
                    BackgroundColor3 = Color3.fromRGB(0,0,0), BackgroundTransparency = 1,
                    Text = "", AutoButtonColor = false, ZIndex = 9999, Parent = main,
                })
                make("UICorner", { CornerRadius = sz(16), Parent = overlay })
                tw(overlay, { BackgroundTransparency = 0.4 }, 0.2)
                local panel = make("Frame", {
                    Size = ss(340, 180), AnchorPoint = Vector2.new(0.5, 0.5),
                    Position = UDim2.fromScale(0.5, 0.5), BackgroundColor3 = thm.NotifBG,
                    BackgroundTransparency = 0.04, ZIndex = 10000, Parent = overlay,
                })
                make("UICorner", { CornerRadius = sz(16), Parent = panel })
                make("UIStroke", { Color = thm.Border, Thickness = 1, Transparency = 0.3, Parent = panel })
                panel.Size = ss(0, 0)
                tw(panel, { Size = ss(340, 180) }, 0.25, Enum.EasingStyle.Back)
                make("TextLabel", {
                    Size = UDim2.new(1, -s(32), 0, s(22)), Position = UDim2.new(0, s(16), 0, s(14)),
                    BackgroundTransparency = 1, Text = "Change Key",
                    TextColor3 = thm.Text, TextSize = fs(16), Font = Enum.Font.GothamBold,
                    TextXAlignment = Enum.TextXAlignment.Left, ZIndex = 10001, Parent = panel,
                })
                make("TextLabel", {
                    Size = UDim2.new(1, -s(32), 0, s(14)), Position = UDim2.new(0, s(16), 0, s(36)),
                    BackgroundTransparency = 1, Text = "Enter your new Free or Premium key below.",
                    TextColor3 = thm.SubText, TextSize = fs(10), Font = Enum.Font.Gotham,
                    TextXAlignment = Enum.TextXAlignment.Left, ZIndex = 10001, Parent = panel,
                })
                local inputFrame = make("Frame", {
                    Size = UDim2.new(1, -s(32), 0, s(34)), Position = UDim2.new(0, s(16), 0, s(58)),
                    BackgroundColor3 = thm.InputBG, BackgroundTransparency = 0.2, ZIndex = 10001, Parent = panel,
                })
                make("UICorner", { CornerRadius = sz(10), Parent = inputFrame })
                local inputStroke = make("UIStroke", { Color = thm.Border, Thickness = 1, Transparency = 0.4, Parent = inputFrame })
                local inputBox = make("TextBox", {
                    Size = UDim2.new(1, -s(16), 1, 0), Position = UDim2.new(0, s(8), 0, 0),
                    BackgroundTransparency = 1, PlaceholderText = "Paste new key...",
                    PlaceholderColor3 = thm.SubText, Text = "", TextColor3 = thm.Text,
                    TextSize = fs(12), Font = Enum.Font.GothamMedium, TextXAlignment = Enum.TextXAlignment.Left,
                    ClearTextOnFocus = true, ZIndex = 10002, Parent = inputFrame,
                })
                local statusLbl = make("TextLabel", {
                    Size = UDim2.new(1, -s(32), 0, s(14)), Position = UDim2.new(0, s(16), 0, s(98)),
                    BackgroundTransparency = 1, Text = "", TextColor3 = thm.SubText,
                    TextSize = fs(10), Font = Enum.Font.GothamMedium, TextXAlignment = Enum.TextXAlignment.Left,
                    ZIndex = 10001, Parent = panel,
                })
                local btnRow = make("Frame", {
                    Size = UDim2.new(1, -s(32), 0, s(32)), Position = UDim2.new(0, s(16), 1, -s(46)),
                    BackgroundTransparency = 1, ZIndex = 10001, Parent = panel,
                })
                local cancelBtn = make("TextButton", {
                    Size = UDim2.new(0.48, 0, 1, 0), BackgroundColor3 = thm.Element,
                    BackgroundTransparency = 0.3, Text = "Cancel", TextColor3 = thm.SubText,
                    TextSize = fs(11), Font = Enum.Font.GothamBold, AutoButtonColor = false,
                    ZIndex = 10002, Parent = btnRow,
                })
                make("UICorner", { CornerRadius = sz(8), Parent = cancelBtn })
                local confirmBtn = make("TextButton", {
                    Size = UDim2.new(0.48, 0, 1, 0), Position = UDim2.new(0.52, 0, 0, 0),
                    BackgroundColor3 = thm.Accent, BackgroundTransparency = 0.15,
                    Text = "Verify & Save", TextColor3 = Color3.new(1,1,1),
                    TextSize = fs(11), Font = Enum.Font.GothamBold, AutoButtonColor = false,
                    ZIndex = 10002, Parent = btnRow,
                })
                make("UICorner", { CornerRadius = sz(8), Parent = confirmBtn })
                local function closeDialog()
                    tw(panel, { Size = ss(0, 0), BackgroundTransparency = 1 }, 0.2)
                    tw(overlay, { BackgroundTransparency = 1 }, 0.2)
                    task.delay(0.25, function() pcall(function() overlay:Destroy() end) end)
                end
                cancelBtn.MouseButton1Click:Connect(closeDialog)
                overlay.MouseButton1Click:Connect(function()
                    if overlay.AbsoluteSize.X > 0 then closeDialog() end
                end)
                local verifying = false
                local function doVerify()
                    if verifying then return end
                    local newKey = inputBox.Text:gsub("%s+", "")
                    if newKey == "" then
                        statusLbl.Text = "Please enter a key!"
                        statusLbl.TextColor3 = thm.AlertError or Color3.fromRGB(255,80,80)
                        return
                    end
                    verifying = true
                    confirmBtn.Text = "Verifying..."
                    statusLbl.Text = "Checking key..."
                    statusLbl.TextColor3 = thm.SubText
                    task.spawn(function()
                        local valid, prem = kc._validateKey(newKey)
                        if valid then
                            if kc.SaveKey and kc._writefile then
                                pcall(kc._writefile, kc.FileName, newKey)
                            end
                            if prem then
                                Aurora:UnlockPremium()
                            else
                                Aurora.IsPremium = false
                                Aurora.KeySystem.Tier = "free"
                            end
                            statusLbl.Text = prem and "Premium key saved!" or "Free key saved!"
                            statusLbl.TextColor3 = thm.AlertSuccess or Color3.fromRGB(80,255,120)
                            tw(inputStroke, { Color = thm.AlertSuccess or Color3.fromRGB(80,255,120) }, 0.15)
                            confirmBtn.Text = "Done!"
                            task.wait(1)
                            closeDialog()
                        else
                            verifying = false
                            confirmBtn.Text = "Verify & Save"
                            statusLbl.Text = "Invalid key! Try again."
                            statusLbl.TextColor3 = thm.AlertError or Color3.fromRGB(255,80,80)
                            tw(inputStroke, { Color = thm.AlertError or Color3.fromRGB(255,80,80) }, 0.15)
                            task.delay(1.5, function()
                                pcall(function() tw(inputStroke, { Color = thm.Border }, 0.15) end)
                            end)
                        end
                    end)
                end
                confirmBtn.MouseButton1Click:Connect(doVerify)
                inputBox.FocusLost:Connect(function(enter) if enter then doVerify() end end)
            end)
        end
        -- Clickable keybind badge - click to rebind the hide/show hotkey
        local hasChangeKey = Aurora._keyConfig and Aurora._keyConfig.SaveKey
        local kbBadge = make("TextButton", {
            Size = UDim2.new(1, -s(18), 0, s(28)),
            Position = UDim2.new(0, s(9), 1, hasChangeKey and -s(38) or -s(36)),
            BackgroundColor3 = thm.Element,
            BackgroundTransparency = 0.5,
            Text = "",
            AutoButtonColor = false,
            Parent = sidebar,
        })
        make("UICorner", { CornerRadius = sz(10), Parent = kbBadge })
        local kbStroke = make("UIStroke", { Color = thm.Border, Thickness = 1, Transparency = 0.5, Parent = kbBadge })
        make("UIPadding", { PaddingLeft = sz(8), PaddingRight = sz(8), Parent = kbBadge })
        local kbIco = make("ImageLabel", {
            Size = ss(12, 12),
            AnchorPoint = Vector2.new(0, 0.5),
            Position = UDim2.new(0, 0, 0.5, 0),
            BackgroundTransparency = 1,
            Parent = kbBadge,
        })
        applyIcon(kbIco, "solar/eye-linear", thm.SubText)
        local kbTitle = make("TextLabel", {
            Size = UDim2.new(1, -s(76), 1, 0), Position = UDim2.new(0, s(18), 0, 0),
            BackgroundTransparency = 1, Text = "Hide / Show GUI",
            TextColor3 = thm.SubText, TextSize = fs(10), Font = Enum.Font.GothamBold,
            TextXAlignment = Enum.TextXAlignment.Left, TextTruncate = Enum.TextTruncate.AtEnd, Parent = kbBadge,
        })
        local keyNameLbl = make("TextLabel", {
            Size = UDim2.new(0, s(58), 1, 0), AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, 0, 0, 0),
            BackgroundTransparency = 1,
            Text = minimizeKey == Enum.KeyCode.None and "None" or minimizeKey.Name,
            TextColor3 = thm.Accent,
            TextSize = fs(10),
            Font = Enum.Font.GothamBold,
            TextXAlignment = Enum.TextXAlignment.Right,
            Parent = kbBadge,
        })
        -- Hover effect
        kbBadge.MouseEnter:Connect(function() if _isMobile then return end 
            tw(kbBadge, { BackgroundTransparency = 0.25, BackgroundColor3 = thm.ElementHover }, 0.12)
            tw(kbStroke, { Transparency = 0.2 }, 0.12)
        end)
        kbBadge.MouseLeave:Connect(function() if _isMobile then return end 
            tw(kbBadge, { BackgroundTransparency = 0.5, BackgroundColor3 = thm.Element }, 0.12)
            tw(kbStroke, { Transparency = 0.5 }, 0.12)
        end)
        -- Rebind on click
        local rebinding = false
        local rebindConn
        kbBadge.MouseButton1Click:Connect(function()
            if rebinding then return end
            rebinding = true
            kbTitle.Text = "Press a key... (Esc)"
            keyNameLbl.Text = ""
            keyNameLbl.TextColor3 = thm.Accent
            tw(kbBadge, { BackgroundColor3 = thm.Accent, BackgroundTransparency = 0.75 }, 0.15)
            tw(kbStroke, { Color = thm.Accent, Transparency = 0.1 }, 0.15)
            rebindConn = UserInputService.InputBegan:Connect(function(input, processed)
                if processed then return end
                if input.UserInputType ~= Enum.UserInputType.Keyboard then return end
                local newKey = input.KeyCode
                if newKey == Enum.KeyCode.Escape then
                    keyNameLbl.Text = minimizeKey == Enum.KeyCode.None and "None" or minimizeKey.Name
                else
                    minimizeKey = newKey
                    keyNameLbl.Text = newKey.Name
                end
                kbTitle.Text = "Hide / Show GUI"
                keyNameLbl.TextColor3 = thm.Accent
                tw(kbBadge, { BackgroundColor3 = thm.Element, BackgroundTransparency = 0.5 }, 0.15)
                tw(kbStroke, { Color = thm.Border, Transparency = 0.5 }, 0.15)
                rebindConn:Disconnect()
                rebindConn = nil
                rebinding = false
            end)
        end)
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
            btn.MouseEnter:Connect(function() if _isMobile then return end 
                tw(btn, { BackgroundColor3 = idx == 1 and thm.ElementHover or Color3.fromRGB(math.clamp(thm.Accent.R*255+20,0,255), math.clamp(thm.Accent.G*255+20,0,255), math.clamp(thm.Accent.B*255+20,0,255)) }, 0.1)
            end)
            btn.MouseLeave:Connect(function() if _isMobile then return end 
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
        local query = searchBox.Text:lower():match("^%s*(.-)%s*$")
        win._searchToken = (win._searchToken or 0) + 1
        local _stok = win._searchToken
        task.wait(0.06)
        if win._searchToken ~= _stok then return end
        if not win._searchDropdown then
            local drop = make("ScrollingFrame", {
                Name = "SearchDrop",
                Size = UDim2.new(1, -s(18), 0, 0),
                Position = UDim2.new(0, s(9), 0, s(135)),
                BackgroundColor3 = thm.Element,
                BackgroundTransparency = 0.1,
                ScrollBarThickness=_isMobile and s(6) or s(2),
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
        for _, c in ipairs(drop:GetChildren()) do
            if c:IsA("TextButton") or c:IsA("TextLabel") or c:IsA("Frame") then c:Destroy() end
        end
        if query == "" then
            drop.Visible = false
            for _, tab in ipairs(win.Tabs) do tab.Button.Visible = true end
            for _, cat in ipairs(win.Categories) do
                cat.Header.Visible = true
                cat.Container.Visible = cat.Expanded
            end
            return
        end
        local results = {}
        for _, entry in ipairs(Aurora._globalElements) do
            local _patched = (entry.tab and entry.tab._isPatched) or (entry.subTab and entry.subTab._isPatched) or (entry.frame and entry.frame:GetAttribute("AuroraPatched"))
            if entry.title:find(query, 1, true) and not _patched then
                table.insert(results, entry)
            end
        end
        for _, tab in ipairs(win.Tabs) do
            tab.Button.Visible = tab.TextLabel.Text:lower():find(query, 1, true) ~= nil
        end
        for _, cat in ipairs(win.Categories) do
            local hasVis = false
            for _, tab in ipairs(cat.Tabs) do if tab.Button.Visible then hasVis = true; break end end
            cat.Header.Visible = hasVis
            cat.Container.Visible = hasVis
        end
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
                local _iconHolder = make("Frame", {
                    Size = ss(26,26), AnchorPoint = Vector2.new(0,0.5), Position = UDim2.new(0, s(7), 0.5, 0),
                    BackgroundColor3 = currentThm.Accent, BackgroundTransparency = 0.82, BorderSizePixel = 0, ZIndex = 53, Parent = row,
                })
                make("UICorner", { CornerRadius = sz(8), Parent = _iconHolder })
                local _rico = make("ImageLabel", { Size = ss(15,15), AnchorPoint = Vector2.new(0.5,0.5), Position = UDim2.fromScale(0.5,0.5), BackgroundTransparency = 1, ZIndex = 54, Parent = _iconHolder })
                pcall(function() applyIcon(_rico, (entry.tab and entry.tab.IconStr) or "solar/widget-2-bold", currentThm.Accent) end)
                make("TextLabel", {
                    Size = UDim2.new(1, -s(44), 0, s(16)),
                    Position = UDim2.new(0, s(42), 0, s(3)),
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
                make("TextLabel", {
                    Size = UDim2.new(1, -s(44), 0, s(13)),
                    Position = UDim2.new(0, s(42), 0, s(19)),
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
                row.MouseEnter:Connect(function() if _isMobile then return end tw(row, { BackgroundTransparency = 0.2 }, 0.1) end)
                row.MouseLeave:Connect(function() if _isMobile then return end tw(row, { BackgroundTransparency = 0.5 }, 0.1) end)
                row.MouseButton1Click:Connect(function()
                    local tab = entry.tab
                    if tab then
                        pcall(function() tab:Select() end)
                        if entry.subTab then
                            pcall(function() entry.subTab:Select() end)
                        end
                        task.delay(0.05, function()
                            pcall(function()
                                local scrollFrame = entry.subTab and entry.subTab.Page or tab.DefaultScroll
                                local elemAbs = entry.frame.AbsolutePosition
                                local scrollAbs = scrollFrame.AbsolutePosition
                                local offset = elemAbs.Y - scrollAbs.Y + scrollFrame.CanvasPosition.Y
                                tw(scrollFrame, { CanvasPosition = Vector2.new(0, math.max(0, offset - s(20))) }, 0.3, Enum.EasingStyle.Quad)
                                tw(entry.frame, { BackgroundColor3 = currentThm.Accent, BackgroundTransparency = 0.75 }, 0.15)
                                task.delay(0.8, function()
                                     tw(entry.frame, { BackgroundTransparency = 0.2 }, 0.3)
                                end)
                            end)
                        end)
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
        local categoryIcon=make("ImageLabel",{
            Size=ss(12,12),Position=UDim2.new(0,s(4),0.5,-s(6)),
            BackgroundTransparency=1,Parent=header,
        })
        applyIcon(categoryIcon, icon or "solar/folder-2-bold", (Aurora.Theme or Aurora.Themes.Dark).Accent)
        local arrow=make("ImageLabel",{
            Size=ss(10,10),AnchorPoint=Vector2.new(1,0.5),
            Position=UDim2.new(1,-s(4),0.5,0),BackgroundTransparency=1,Parent=header,
        })
        applyIcon(arrow, "solar/alt-arrow-down-linear", (Aurora.Theme or Aurora.Themes.Dark).SubText)
        local label=make("TextLabel",{
            Size=UDim2.new(1,-s(32),1,0),Position=UDim2.new(0,s(22),0,0),
            BackgroundTransparency=1,Text=string.upper(title),
            TextColor3=(Aurora.Theme or Aurora.Themes.Dark).SubText,
            TextSize=fs(10),Font=Enum.Font.GothamBold,TextXAlignment=Enum.TextXAlignment.Left,Parent=header,
        })
        local isHovering = false
        header.MouseEnter:Connect(function() if _isMobile then return end 
            isHovering = true
            local currentThm = Aurora.Theme or Aurora.Themes.Dark
            tw(header, { BackgroundColor3 = currentThm.ElementHover, BackgroundTransparency = 0.8 }, 0.15)
        end)
        header.MouseLeave:Connect(function() if _isMobile then return end 
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
                applyIcon(categoryIcon, icon or "solar/folder-2-bold", currentThm.Accent)
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
        category.Container=tabContainer; category.Header=header; category.Icon=categoryIcon
        table.insert(win.Categories,category)
        return setmetatable(category,Category)
    end
    local _tabCounter = 0
    function win:AddTab(tcfg, parentContainer)
        _elemCounter = 0
        _sectionCounter = 0
        _tabCounter = _tabCounter + 1
        local tabParent=parentContainer or tabScroll
        local btn=make("TextButton",{Size=UDim2.new(1,0,0,s(34)),BackgroundTransparency=1,Text="",Parent=tabParent})
        make("UICorner",{CornerRadius=sz(10),Parent=btn})
        local btnStroke=make("UIStroke",{Color=thm.Accent,Thickness=1,Transparency=1,Parent=btn})
        local lbl=make("TextLabel",{
            Size=UDim2.new(1,-s(38),1,0),Position=UDim2.new(0,s(34),0,0),
            BackgroundTransparency=1,Text=tcfg.Title,TextColor3=thm.TabInactive,
            TextSize=fs(12),Font=Enum.Font.GothamBold,TextXAlignment=Enum.TextXAlignment.Left,Parent=btn,
        })
        local ico=make("ImageLabel",{Size=ss(16,16),Position=UDim2.new(0,s(8),0.5,-s(8)),BackgroundTransparency=1,Parent=btn})
        applyIcon(ico,tcfg.Icon,thm.TabInactive)
        if Aurora.FadeIn then
            lbl.TextTransparency = 1
            ico.ImageTransparency = 1
            if Aurora.LazyLoad then
                local tabDelay = _tabCounter * (Aurora.DelayPerTab or 0.08)
                task.delay(tabDelay, function()
                    if lbl and lbl.Parent then tw(lbl, { TextTransparency = 0 }, 0.3) end
                    if ico and ico.Parent then tw(ico, { ImageTransparency = 0 }, 0.3) end
                end)
            else
                tw(lbl, { TextTransparency = 0 }, 0.3)
                tw(ico, { ImageTransparency = 0 }, 0.3)
            end
        end
        local indicator=make("Frame",{
            Size=UDim2.new(0,s(3),0,s(18)),Position=UDim2.new(0,s(3),0.5,-s(9)),
            BackgroundColor3=thm.Accent,BorderSizePixel=0,Visible=false,Parent=btn,
        })
        make("UICorner",{CornerRadius=sz(2),Parent=indicator})
        local p=make("Frame",{Size=UDim2.fromScale(1,1),BackgroundTransparency=1,Visible=false,Parent=tabHold})
        local defaultScroll=make("ScrollingFrame",{Size=UDim2.fromScale(1,1),BackgroundTransparency=1,ScrollBarThickness=_isMobile and s(6) or s(2),ScrollBarImageColor3=thm.Scrollbar,ScrollBarImageTransparency=0.45,Parent=p})
        local c=make("Frame",{Size=UDim2.new(1,0,0,0),AutomaticSize=Enum.AutomaticSize.Y,BackgroundTransparency=1,Parent=defaultScroll})
        local l=make("UIListLayout",{SortOrder=Enum.SortOrder.LayoutOrder,Padding=sz(10),Parent=c})
        make("UIPadding",{PaddingTop=sz(14),PaddingBottom=sz(20),PaddingLeft=sz(14),PaddingRight=sz(14),Parent=c})
        defaultScroll.CanvasSize=UDim2.fromOffset(0,0)
        defaultScroll.AutomaticCanvasSize=Enum.AutomaticSize.Y
        defaultScroll.ScrollingDirection=Enum.ScrollingDirection.Y
        -- Tab badge
        local badgeLbl = make("TextLabel", {
            Size = ss(18, 16), AnchorPoint = Vector2.new(1, 0),
            Position = UDim2.new(1, -s(4), 0, s(2)),
            BackgroundColor3 = thm.Accent, BackgroundTransparency = 0,
            Text = "", TextColor3 = Color3.fromRGB(255, 255, 255),
            TextSize = fs(9), Font = Enum.Font.GothamBold,
            Visible = false, ZIndex = 15, Parent = btn,
        })
        make("UICorner", { CornerRadius = UDim.new(1, 0), Parent = badgeLbl })
        make("UIPadding", { PaddingLeft = sz(4), PaddingRight = sz(4), Parent = badgeLbl })
        local t=setmetatable({Button=btn,Page=p,ScrollContent=c,DefaultScroll=defaultScroll,TextLabel=lbl,IconImg=ico,IconStr=tcfg.Icon,Indicator=indicator,Stroke=btnStroke,BadgeLabel=badgeLbl, _window=win},Tab)
        function t:SetBadge(val)
            if val == nil or val == 0 or val == "" or val == false then
                badgeLbl.Visible = false
                badgeLbl.Text = ""
            else
                badgeLbl.Text = tostring(val)
                badgeLbl.Visible = true
                local badgeScale = badgeLbl:FindFirstChildOfClass("UIScale") or make("UIScale", { Scale = 1, Parent = badgeLbl })
                tw(badgeScale, { Scale = 1.3 }, 0.08)
                task.delay(0.1, function() tw(badgeScale, { Scale = 1 }, 0.16, Enum.EasingStyle.Back, Enum.EasingDirection.Out) end)
            end
        end
        addVisibilityAPI(t, btn)
        btn.MouseEnter:Connect(function() if _isMobile then return end 
            if activeTab ~= t then
                local currentThm = Aurora.Theme or Aurora.Themes.Dark
                tw(btn, { BackgroundColor3 = currentThm.ElementHover, BackgroundTransparency = 0.6 }, 0.15)
                tw(lbl, { TextColor3 = currentThm.Text }, 0.15)
                if ico then applyIcon(ico, tcfg.Icon, currentThm.Text) end
            end
        end)
        btn.MouseLeave:Connect(function() if _isMobile then return end 
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
                if activeTab.Stroke then tw(activeTab.Stroke,{Transparency=1},0.18) end
            end
            activeTab=t; activeTab.Page.Visible=true
            activeTab.Page.Position = UDim2.new(0, 0, 0.025, 0)
            tw(activeTab.Page, { Position = UDim2.new(0, 0, 0, 0) }, 0.22, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
            tw(btn,{BackgroundColor3=currentThm.Accent,BackgroundTransparency=0.82},0.18)
            tw(btnStroke,{Transparency=0.45,Color=currentThm.Accent},0.18)
            lbl.TextColor3=currentThm.Accent
            if ico then applyIcon(ico,tcfg.Icon,currentThm.Accent) end
            indicator.Visible=true
        end
        btn.MouseButton1Click:Connect(function()
            t:Select()
        end)
        if #win.Tabs==0 then
            activeTab=t; t.Page.Visible=true
            btn.BackgroundTransparency=0.82; btn.BackgroundColor3=thm.Accent
            btnStroke.Transparency=0.45; btnStroke.Color=thm.Accent
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
                    btn.BackgroundTransparency = 0.82
                    btnStroke.Color = currentThm.Accent
                    btnStroke.Transparency = 0.45
                    lbl.TextColor3 = currentThm.Accent
                    indicator.BackgroundColor3 = currentThm.Accent
                    if ico then applyIcon(ico, tcfg.Icon, currentThm.Accent) end
                else
                    btn.BackgroundTransparency = 1
                    btnStroke.Transparency = 1
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
    function win:SelectTab(target)
        local tab
        if type(target) == "number" then
            tab = self.Tabs[target]
        elseif type(target) == "string" then
            local needle = target:lower()
            for _, candidate in ipairs(self.Tabs) do
                if candidate.TextLabel and candidate.TextLabel.Text:lower() == needle then
                    tab = candidate
                    break
                end
            end
        elseif type(target) == "table" then
            tab = target
        end
        if tab and type(tab.Select) == "function" then
            tab:Select()
            return true
        end
        return false
    end
    function win:LoadDefault() return self:SelectTab(1) end
    function win:Show() return self:SetVisible(true) end
    function win:Hide() return self:SetVisible(false) end
    function win:Minimize(state)
        local desired = state == nil and true or state == true
        if desired ~= minimized then toggleMinimize() end
        return minimized
    end
    function win:Maximize(state)
        local desired = state == nil and true or state == true
        if desired ~= maximized then toggleMaximize() end
        return maximized
    end
    local mobileGui
    if _isMobile or cfg.MobileButton == true then
        mobileGui = make("ScreenGui", {
            Name = "AuroraMobileToggleGui",
            ResetOnSpawn = false,
            DisplayOrder = 99999
        })
        safeParent(mobileGui)
        local mbIcon = cfg.MobileButtonIcon or "solar/star-bold"
        local mbPos = cfg.MobileButtonPosition or UDim2.new(0, s(12), 0, s(80))
        local fabSize = s(52)
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
        local mStroke = make("UIStroke", {
            Color = thm.Accent,
            Thickness = 1.5,
            Transparency = 0.35,
            Parent = mobileBtn
        })
        local innerGlow = make("Frame", {
            Size = UDim2.fromOffset(s(28), s(28)),
            AnchorPoint = Vector2.new(0.5, 0.5),
            Position = UDim2.fromScale(0.5, 0.5),
            BackgroundColor3 = thm.Accent,
            BackgroundTransparency = 0.75,
            Parent = mobileBtn
        })
        make("UICorner", { CornerRadius = UDim.new(1, 0), Parent = innerGlow })
        local mIco = make("ImageLabel", {
            Size = UDim2.fromOffset(s(18), s(18)),
            AnchorPoint = Vector2.new(0.5, 0.5),
            Position = UDim2.fromScale(0.5, 0.5),
            BackgroundTransparency = 1,
            ZIndex = 101,
            Parent = mobileBtn
        })
        applyIcon(mIco, mbIcon, Color3.fromRGB(255, 255, 255))
        local mScale = make("UIScale", { Scale = 1.0, Parent = mobileBtn })
        mobileBtn.InputBegan:Connect(function(i)
            if i.UserInputType == Enum.UserInputType.Touch or i.UserInputType == Enum.UserInputType.MouseButton1 then
                tw(mScale, { Scale = 0.92 }, 0.06, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
            end
        end)
        mobileBtn.InputEnded:Connect(function(i)
            if i.UserInputType == Enum.UserInputType.Touch or i.UserInputType == Enum.UserInputType.MouseButton1 then
                tw(mScale, { Scale = 1.0 }, 0.12, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
            end
        end)
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
        local breathTween = TweenService:Create(mStroke,
            TweenInfo.new(1.8, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true),
            { Transparency = 0.6, Thickness = 2 }
        )
        breathTween:Play()
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
        rgbActive = false
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
            _nHolder = nil
            table.clear(_activeNotifs)
            table.clear(_notifQueue)
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
    -- ===== Loading / intro animation =====
    if cfg.LoadingScreen ~= false and not _isMobile then
        visible = false
        canvas.GroupTransparency = 1
        main.BackgroundTransparency = 1
        mainStroke.Transparency = 1
        resizeOverlay.Visible = false
        task.spawn(function()
            local accent = thm.Accent
            local loadGui = make("ScreenGui", {
                Name = "AuroraLoadingGui", ResetOnSpawn = false, IgnoreGuiInset = true,
                DisplayOrder = 100001, ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
            })
            safeParent(loadGui)
            local dim = make("Frame", {
                Size = UDim2.fromScale(1,1), BackgroundColor3 = Color3.fromRGB(8,8,11),
                BackgroundTransparency = 1, BorderSizePixel = 0, Parent = loadGui,
            })
            make("UIGradient", { Color = ColorSequence.new({
                ColorSequenceKeypoint.new(0, Color3.fromRGB(16,16,22)),
                ColorSequenceKeypoint.new(0.5, Color3.fromRGB(10,10,16)),
                ColorSequenceKeypoint.new(1, Color3.fromRGB(6,6,9)) }), Rotation = 135, Parent = dim })
            local card = make("Frame", {
                AnchorPoint = Vector2.new(0.5,0.5), Position = UDim2.fromScale(0.5,0.5),
                Size = ss(360,200), BackgroundTransparency = 1, Parent = dim,
            })
            local cardScale = make("UIScale", { Scale = 0.85, Parent = card })
            local centerY = s(36)
            local particleHolder = make("Frame", {
                AnchorPoint = Vector2.new(0.5,0.5), Position = UDim2.new(0.5,0,0,centerY),
                Size = ss(140,140), BackgroundTransparency = 1, ZIndex = 0, Parent = card,
            })
            local particles = {}
            local particleCount = 8
            for i = 1, particleCount do
                local p = make("Frame", {
                    AnchorPoint = Vector2.new(0.5,0.5), Position = UDim2.fromScale(0.5,0.5),
                    Size = ss(3,3), BackgroundColor3 = accent, BackgroundTransparency = 1, BorderSizePixel = 0, Parent = particleHolder,
                })
                make("UICorner", { CornerRadius = UDim.new(1,0), Parent = p })
                particles[i] = { frame = p, angle = (i / particleCount) * math.pi * 2, radius = s(32 + math.random()*16), speed = 0.6 + math.random()*0.8, size = s(2 + math.random()*2) }
            end
            local ring = make("Frame", {
                AnchorPoint = Vector2.new(0.5,0), Position = UDim2.new(0.5,0,0,centerY - s(29)),
                Size = ss(58,58), BackgroundTransparency = 1, Parent = card,
            })
            make("UICorner", { CornerRadius = UDim.new(1,0), Parent = ring })
            local ringStroke = make("UIStroke", { Thickness = s(2.5), Color = accent, Transparency = 1, Parent = ring })
            make("UIGradient", { Transparency = NumberSequence.new({
                NumberSequenceKeypoint.new(0,0), NumberSequenceKeypoint.new(0.35,0.2),
                NumberSequenceKeypoint.new(0.65,0.85), NumberSequenceKeypoint.new(1,1) }), Parent = ringStroke })
            local track = make("Frame", {
                AnchorPoint = Vector2.new(0.5,0.5), Position = UDim2.fromScale(0.5,0.5),
                Size = UDim2.fromScale(1,1), BackgroundTransparency = 1, Parent = ring,
            })
            make("UICorner", { CornerRadius = UDim.new(1,0), Parent = track })
            make("UIStroke", { Thickness = s(2.5), Color = thm.Element, Transparency = 1, Parent = track })
            local glow = make("Frame", {
                AnchorPoint = Vector2.new(0.5,0.5), Position = UDim2.new(0.5,0,0,centerY),
                Size = ss(50,50), BackgroundColor3 = accent, BackgroundTransparency = 1, BorderSizePixel = 0, ZIndex = 0, Parent = card,
            })
            make("UICorner", { CornerRadius = sz(16), Parent = glow })
            local ring2 = make("Frame", {
                AnchorPoint = Vector2.new(0.5,0.5), Position = UDim2.new(0.5,0,0,centerY),
                Size = ss(74,74), BackgroundTransparency = 1, ZIndex = 1, Parent = card,
            })
            make("UICorner", { CornerRadius = UDim.new(1,0), Parent = ring2 })
            local ring2Stroke = make("UIStroke", { Thickness = s(1.5), Color = accent, Transparency = 1, Parent = ring2 })
            make("UIGradient", { Transparency = NumberSequence.new({
                NumberSequenceKeypoint.new(0,1), NumberSequenceKeypoint.new(0.3,1),
                NumberSequenceKeypoint.new(0.55,0.45), NumberSequenceKeypoint.new(0.8,1), NumberSequenceKeypoint.new(1,1) }), Rotation = 140, Parent = ring2Stroke })
            local ring3 = make("Frame", {
                AnchorPoint = Vector2.new(0.5,0.5), Position = UDim2.new(0.5,0,0,centerY),
                Size = ss(90,90), BackgroundTransparency = 1, ZIndex = 0, Parent = card,
            })
            make("UICorner", { CornerRadius = UDim.new(1,0), Parent = ring3 })
            local ring3Stroke = make("UIStroke", { Thickness = s(1), Color = accent, Transparency = 1, Parent = ring3 })
            make("UIGradient", { Transparency = NumberSequence.new({
                NumberSequenceKeypoint.new(0,1), NumberSequenceKeypoint.new(0.4,0.7), NumberSequenceKeypoint.new(0.7,1), NumberSequenceKeypoint.new(1,1) }), Rotation = 60, Parent = ring3Stroke })
            local logoBadge = make("Frame", {
                AnchorPoint = Vector2.new(0.5,0.5), Position = UDim2.new(0.5,0,0,centerY),
                Size = ss(38,38), BackgroundColor3 = accent, BackgroundTransparency = 1, BorderSizePixel = 0, Parent = card,
            })
            make("UICorner", { CornerRadius = sz(12), Parent = logoBadge })
            local logoBadgeStroke = make("UIStroke", { Color = accent, Thickness = 1, Transparency = 1, Parent = logoBadge })
            local logo = make("ImageLabel", {
                AnchorPoint = Vector2.new(0.5,0.5), Position = UDim2.new(0.5,0,0,centerY),
                Size = ss(22,22), BackgroundTransparency = 1, ImageTransparency = 1, Parent = card,
            })
            applyIcon(logo, cfg.LoadingIcon or cfg.Icon or "solar/bolt-circle-bold", accent)
            local titleLbl = make("TextLabel", {
                AnchorPoint = Vector2.new(0.5,0), Position = UDim2.new(0.5,0,0,centerY + s(42)),
                Size = ss(320,28), BackgroundTransparency = 1, Text = cfg.Title or "Aurora",
                TextColor3 = Color3.fromRGB(255,255,255), TextTransparency = 1, TextSize = fs(22), Font = Enum.Font.GothamBlack, Parent = card,
            })
            local titleGrad = make("UIGradient", { Color = ColorSequence.new({
                ColorSequenceKeypoint.new(0, Color3.fromRGB(130,130,145)),
                ColorSequenceKeypoint.new(0.45, Color3.fromRGB(255,255,255)),
                ColorSequenceKeypoint.new(0.55, Color3.fromRGB(255,255,255)),
                ColorSequenceKeypoint.new(1, Color3.fromRGB(130,130,145)) }), Offset = Vector2.new(-1.5,0), Parent = titleLbl })
            local titleScale = make("UIScale", { Scale = 0.88, Parent = titleLbl })
            local subLbl = make("TextLabel", {
                AnchorPoint = Vector2.new(0.5,0), Position = UDim2.new(0.5,0,0,centerY + s(72)),
                Size = ss(320,15), BackgroundTransparency = 1, Text = cfg.LoadingText or cfg.SubTitle or "Free Script",
                TextColor3 = accent, TextTransparency = 1, TextSize = fs(11), Font = Enum.Font.Gotham, Parent = card,
            })
            local divider = make("Frame", {
                AnchorPoint = Vector2.new(0.5,0), Position = UDim2.new(0.5,0,0,centerY + s(92)),
                Size = ss(180,1), BackgroundColor3 = accent, BackgroundTransparency = 1, BorderSizePixel = 0, Parent = card,
            })
            local barBG = make("Frame", {
                AnchorPoint = Vector2.new(0.5,0), Position = UDim2.new(0.5,0,0,centerY + s(100)),
                Size = ss(240,4), BackgroundColor3 = thm.Element, BackgroundTransparency = 1, BorderSizePixel = 0, Parent = card,
            })
            make("UICorner", { CornerRadius = UDim.new(1,0), Parent = barBG })
            local barFill = make("Frame", {
                Size = UDim2.new(0,0,1,0), BackgroundColor3 = accent,
                BackgroundTransparency = 1, BorderSizePixel = 0, Parent = barBG,
            })
            make("UICorner", { CornerRadius = UDim.new(1,0), Parent = barFill })
            local barGrad = make("UIGradient", { Color = ColorSequence.new({
                ColorSequenceKeypoint.new(0, accent),
                ColorSequenceKeypoint.new(0.5, Color3.new(math.min(accent.R*1.4,1), math.min(accent.G*1.4,1), math.min(accent.B*1.4,1))),
                ColorSequenceKeypoint.new(1, accent) }), Parent = barFill })
            local shimmer = make("Frame", {
                AnchorPoint = Vector2.new(0.5,0.5), Position = UDim2.new(-0.1,0,0.5,0),
                Size = UDim2.new(0.2,0,1,s(4)), BackgroundColor3 = Color3.new(1,1,1),
                BackgroundTransparency = 0.75, BorderSizePixel = 0, Parent = barFill,
            })
            make("UICorner", { CornerRadius = UDim.new(1,0), Parent = shimmer })
            local barGlow = make("Frame", {
                AnchorPoint = Vector2.new(1,0.5), Position = UDim2.new(0,0,0.5,0),
                Size = ss(8,8), BackgroundColor3 = accent, BackgroundTransparency = 1, BorderSizePixel = 0, ZIndex = 2, Parent = barFill,
            })
            make("UICorner", { CornerRadius = UDim.new(1,0), Parent = barGlow })
            local pctLbl = make("TextLabel", {
                AnchorPoint = Vector2.new(0.5,0), Position = UDim2.new(0.5,0,0,centerY + s(112)),
                Size = ss(80,14), BackgroundTransparency = 1, Text = "0%",
                TextColor3 = thm.SubText, TextTransparency = 1, TextSize = fs(10), Font = Enum.Font.GothamBold, Parent = card,
            })
            -- Entrance
            tw(dim, { BackgroundTransparency = 0 }, 0.5)
            tw(cardScale, { Scale = 1 }, 0.6, Enum.EasingStyle.Back, Enum.EasingDirection.Out)
            task.wait(0.15)
            local trackStroke = track:FindFirstChildOfClass("UIStroke")
            if trackStroke then tw(trackStroke, { Transparency = 0.88 }, 0.4) end
            tw(ringStroke, { Transparency = 0 }, 0.4)
            tw(ring2Stroke, { Transparency = 0.3 }, 0.5)
            tw(ring3Stroke, { Transparency = 0.6 }, 0.6)
            tw(glow, { BackgroundTransparency = 0.88 }, 0.5)
            tw(logoBadge, { BackgroundTransparency = 0.82 }, 0.4)
            tw(logoBadgeStroke, { Transparency = 0.45 }, 0.4)
            tw(logo, { ImageTransparency = 0 }, 0.4)
            for i, pd in ipairs(particles) do
                task.delay(i * 0.04, function()
                    tw(pd.frame, { BackgroundTransparency = 0.3 + math.random()*0.3 }, 0.3)
                end)
            end
            task.wait(0.1)
            tw(titleLbl, { TextTransparency = 0 }, 0.4)
            tw(titleScale, { Scale = 1 }, 0.5, Enum.EasingStyle.Quint, Enum.EasingDirection.Out)
            task.wait(0.08)
            tw(subLbl, { TextTransparency = 0.15 }, 0.35)
            tw(divider, { BackgroundTransparency = 0.6 }, 0.35)
            tw(barBG, { BackgroundTransparency = 0.5 }, 0.35)
            tw(pctLbl, { TextTransparency = 0.2 }, 0.35)
            tw(barFill, { BackgroundTransparency = 0 }, 0.35)
            tw(barGlow, { BackgroundTransparency = 0.3 }, 0.35)
            -- Progress loop with step-based easing
            local running = true
            local dur = math.max(tonumber(cfg.LoadingDuration) or 2.5, 0.3)
            local t0 = tick()
            local lastPct = -1
            local steps = {0.12, 0.28, 0.45, 0.58, 0.72, 0.85, 0.94, 1.0}
            local loadRenderConn
            loadRenderConn = RunService.RenderStepped:Connect(function()
                if not running or not loadGui.Parent then
                    if loadRenderConn then loadRenderConn:Disconnect(); loadRenderConn = nil end
                    return
                end
                local elapsed = tick() - t0
                local pulse = (math.sin(elapsed * 2.8) + 1) * 0.5
                local fastPulse = (math.sin(elapsed * 5.6) + 1) * 0.5
                ring.Rotation = (elapsed * 165) % 360
                ring2.Rotation = (-elapsed * 95) % 360
                ring3.Rotation = (elapsed * 50) % 360
                glow.Size = ss(50 + pulse * 12, 50 + pulse * 12)
                glow.BackgroundTransparency = 0.88 - pulse * 0.15
                logo.Size = ss(22 + pulse * 3, 22 + pulse * 3)
                logo.Rotation = math.sin(elapsed * 1.2) * 3
                titleGrad.Offset = Vector2.new(-1.5 + ((elapsed * 0.7) % 3), 0)
                for _, pd in ipairs(particles) do
                    local a = pd.angle + elapsed * pd.speed
                    local r = pd.radius + math.sin(elapsed * 2 + pd.angle) * s(6)
                    local px = 0.5 + math.cos(a) * r / s(140)
                    local py = 0.5 + math.sin(a) * r / s(140)
                    pd.frame.Position = UDim2.fromScale(px, py)
                    pd.frame.Size = UDim2.fromOffset(pd.size + fastPulse * s(1.5), pd.size + fastPulse * s(1.5))
                    pd.frame.BackgroundTransparency = 0.25 + math.sin(elapsed * 3 + pd.angle * 2) * 0.25
                end
                shimmer.Position = UDim2.new((elapsed * 0.6) % 1.4 - 0.2, 0, 0.5, 0)
                local rawProg = math.clamp(elapsed / dur, 0, 1)
                local stepProg = 0
                for si, sv in ipairs(steps) do
                    local stepStart = (si - 1) / #steps
                    local stepEnd = si / #steps
                    if rawProg <= stepEnd then
                        local localT = (rawProg - stepStart) / (stepEnd - stepStart)
                        local easeT = localT < 0.5 and (2 * localT * localT) or (1 - 2 * (1 - localT) * (1 - localT))
                        local prevVal = si > 1 and steps[si-1] or 0
                        stepProg = prevVal + (sv - prevVal) * easeT
                        break
                    end
                    stepProg = sv
                end
                barFill.Size = UDim2.new(stepProg, 0, 1, 0)
                barGlow.Position = UDim2.new(1, 0, 0.5, 0)
                barGlow.BackgroundTransparency = 0.2 + fastPulse * 0.3
                barGrad.Offset = Vector2.new(math.sin(elapsed * 2) * 0.3, 0)
                local pct = math.floor(stepProg * 100 + 0.5)
                if pct ~= lastPct then
                    lastPct = pct
                    pctLbl.Text = string.format("%d%%", pct)
                end
                if elapsed >= dur then running = false end
            end)
            while running do task.wait(0.05) end
            if loadRenderConn then loadRenderConn:Disconnect(); loadRenderConn = nil end
            barFill.Size = UDim2.new(1,0,1,0)
            pctLbl.Text = "100%"
            -- Completion burst
            tw(ringStroke, { Thickness = s(4) }, 0.15)
            tw(glow, { Size = ss(80,80), BackgroundTransparency = 0.6 }, 0.2)
            tw(logoBadge, { Size = ss(42,42) }, 0.2, Enum.EasingStyle.Back, Enum.EasingDirection.Out)
            for _, pd in ipairs(particles) do
                local burstR = s(60 + math.random()*20)
                local a = pd.angle
                tw(pd.frame, { Position = UDim2.fromScale(0.5 + math.cos(a)*burstR/s(140), 0.5 + math.sin(a)*burstR/s(140)), BackgroundTransparency = 1, Size = UDim2.fromOffset(s(1),s(1)) }, 0.35)
            end
            tw(barGlow, { BackgroundTransparency = 0, Size = ss(12,12) }, 0.15)
            task.wait(0.25)
            -- Fade out
            running = false
            tw(dim, { BackgroundTransparency = 1 }, 0.5)
            tw(cardScale, { Scale = 1.08 }, 0.45, Enum.EasingStyle.Quad, Enum.EasingDirection.In)
            tw(ringStroke, { Transparency = 1 }, 0.3)
            if trackStroke then tw(trackStroke, { Transparency = 1 }, 0.3) end
            tw(logoBadge, { BackgroundTransparency = 1 }, 0.3)
            tw(ring2Stroke, { Transparency = 1 }, 0.3)
            tw(ring3Stroke, { Transparency = 1 }, 0.3)
            tw(glow, { BackgroundTransparency = 1 }, 0.3)
            tw(logoBadgeStroke, { Transparency = 1 }, 0.3)
            tw(logo, { ImageTransparency = 1 }, 0.3)
            tw(titleLbl, { TextTransparency = 1 }, 0.3)
            tw(subLbl, { TextTransparency = 1 }, 0.3)
            tw(divider, { BackgroundTransparency = 1 }, 0.3)
            tw(barBG, { BackgroundTransparency = 1 }, 0.3)
            tw(barFill, { BackgroundTransparency = 1 }, 0.3)
            tw(barGlow, { BackgroundTransparency = 1 }, 0.25)
            tw(pctLbl, { TextTransparency = 1 }, 0.3)
            task.wait(0.25)
            pcall(function() win:SetVisible(true) end)
            Aurora:PlaySound("Open")
            task.wait(0.5)
            pcall(function() loadGui:Destroy() end)
        end)
    end
    return win
end
function Aurora:CreateTheme(name, tbl)
    if type(name) ~= "string" or name == "" then return false end
    tbl = type(tbl) == "table" and tbl or {}
    local dark = self.Themes.Dark
    local newTheme = copyTheme(dark)
    for key, value in pairs(tbl) do
        newTheme[key] = value
    end
    self.Themes[name] = newTheme
    return true
end
function Aurora:SetTheme(name)
    rgbActive = false
    local theme
    local themeName = type(name) == "string" and name or "Custom"
    local animateRGB = name == "RGB"
    if type(name) == "table" then
        theme = name
    elseif animateRGB then
        theme = copyTheme(self.Themes.RGB or self.Themes.Dark)
    else
        theme = self.Themes[name]
    end
    local found = theme ~= nil
    local targetTheme = copyTheme(theme or self.Themes.Dark)
    if self._activeThemePrivate and type(self.Theme) == "table" then
        for key in pairs(self.Theme) do self.Theme[key] = nil end
        for key, value in pairs(targetTheme) do self.Theme[key] = value end
        theme = self.Theme
    else
        theme = targetTheme
        self._activeThemePrivate = true
    end
    self.Theme = theme
    self.ThemeName = found and themeName or "Dark"
    if Aurora.SmoothThemeTransition and not animateRGB then
        for _, e in ipairs(self.ThemeObjs) do
            if e.isCallback then
                pcall(e.callback)
            elseif e.obj and e.obj.Parent and e.key and theme[e.key] then
                local val = theme[e.key]
                if typeof(val) == "Color3" then
                    pcall(function() tw(e.obj, {[e.prop] = val}, 0.35) end)
                else
                    pcall(function() e.obj[e.prop] = val end)
                end
            end
        end
    else
        self:UpdateTheme()
    end
    if animateRGB and found then
        rgbActive = true
        task.spawn(function()
            local hue = 0
            while rgbActive and task.wait(0.03) do
                hue = (hue + 0.005) % 1
                local color = Color3.fromHSV(hue, 0.8, 1)
                self.Theme.Accent = color
                self.Theme.ToggleOn = color
                self.Theme.SliderFill = color
                self:UpdateTheme({ Accent = true, ToggleOn = true, SliderFill = true })
            end
        end)
    end
    return found
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
                TextColor3 = isActive and thm.AlertSuccess or thm.Accent,
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
function Section:AddChangelog(id, data)
    local thm = Aurora.Theme
    local obj = { Type="Changelog", Value=data, id=id }
    local f = elemFrame(self.Container)
    f.BackgroundTransparency = 1
    make("UIListLayout", { SortOrder = Enum.SortOrder.LayoutOrder, Padding = sz(16), Parent = f })
    local typeConfig = {
        ["Added"]       = { Color = thm.Accent, Icon = "solar/leaf-bold" },
        ["Añadido"]     = { Color = thm.Accent, Icon = "solar/leaf-bold" },
        ["Fixed"]       = { Color = thm.AlertError or Color3.fromRGB(235, 87, 87), Icon = "solar/bug-bold" },
        ["BugFix"]      = { Color = thm.AlertError or Color3.fromRGB(235, 87, 87), Icon = "solar/bug-bold" },
        ["Arreglo"]     = { Color = thm.AlertError or Color3.fromRGB(235, 87, 87), Icon = "solar/bug-bold" },
        ["Improved"]    = { Color = thm.AlertWarn or Color3.fromRGB(242, 201, 76), Icon = "solar/star-bold" },
        ["Improvement"] = { Color = thm.AlertWarn or Color3.fromRGB(242, 201, 76), Icon = "solar/star-bold" },
        ["Mejora"]      = { Color = thm.AlertWarn or Color3.fromRGB(242, 201, 76), Icon = "solar/star-bold" },
        ["Removed"]     = { Color = thm.AlertWarn or Color3.fromRGB(230, 126, 34), Icon = "solar/trash-bin-trash-bold" }
    }
    for i, ver in ipairs(data) do
        local verFrame = make("Frame", {
            Size = UDim2.new(1, 0, 0, 0),
            AutomaticSize = Enum.AutomaticSize.Y,
            BackgroundColor3 = thm.InputBG,
            Parent = f
        })
        make("UICorner", { CornerRadius = sz(8), Parent = verFrame })
        make("UIStroke", { Color = thm.Border, Transparency = 0.5, Thickness = 1, Parent = verFrame })
        local layout = make("UIListLayout", { SortOrder = Enum.SortOrder.LayoutOrder, Padding = sz(12), Parent = verFrame })
        make("UIPadding", { PaddingTop = sz(16), PaddingBottom = sz(16), PaddingLeft = sz(16), PaddingRight = sz(16), Parent = verFrame })
        local header = make("Frame", {
            Size = UDim2.new(1, 0, 0, s(50)),
            BackgroundTransparency = 1,
            Parent = verFrame
        })
        local leftHeader = make("Frame", {
            Size = UDim2.new(1, -s(100), 1, 0),
            BackgroundTransparency = 1,
            Parent = header
        })
        make("UIListLayout", { SortOrder = Enum.SortOrder.LayoutOrder, Padding = sz(2), Parent = leftHeader })
        local _clLbl = make("TextLabel", {
            Size = UDim2.new(1, 0, 0, s(12)),
            BackgroundTransparency = 1,
            Text = "CHANGELOG",
            TextColor3 = thm.Accent,
            TextSize = fs(11),
            Font = Enum.Font.GothamBold,
            TextXAlignment = Enum.TextXAlignment.Left,
            Parent = leftHeader
        })
        reg(_clLbl, "TextColor3", "Accent")
        make("TextLabel", {
            Size = UDim2.new(1, 0, 0, s(20)),
            BackgroundTransparency = 1,
            Text = "Update " .. (ver.Date or "Unknown"),
            TextColor3 = thm.Text,
            TextSize = fs(18),
            Font = Enum.Font.GothamBold,
            TextXAlignment = Enum.TextXAlignment.Left,
            Parent = leftHeader
        })
        make("TextLabel", {
            Size = UDim2.new(1, 0, 0, s(14)),
            BackgroundTransparency = 1,
            Text = ver.Version .. " Release",
            TextColor3 = thm.SubText,
            TextSize = fs(12),
            Font = Enum.Font.Gotham,
            TextXAlignment = Enum.TextXAlignment.Left,
            Parent = leftHeader
        })
        if ver.Changes then
            local rightBadge = make("Frame", {
                AnchorPoint = Vector2.new(1, 0),
                Position = UDim2.new(1, 0, 0, s(8)),
                AutomaticSize = Enum.AutomaticSize.XY,
                BackgroundColor3 = thm.Accent,
                BackgroundTransparency = 0.82,
                Parent = header
            })
            make("UICorner", { CornerRadius = sz(6), Parent = rightBadge })
            reg(rightBadge, "BackgroundColor3", "Accent")
            local _badgeStroke = make("UIStroke", { Color = thm.Accent, Transparency = 0.4, Thickness = 1, Parent = rightBadge })
            reg(_badgeStroke, "Color", "Accent")
            make("UIPadding", { PaddingTop = sz(6), PaddingBottom = sz(6), PaddingLeft = sz(12), PaddingRight = sz(12), Parent = rightBadge })
            make("TextLabel", {
                AutomaticSize = Enum.AutomaticSize.XY,
                BackgroundTransparency = 1,
                Text = tostring(#ver.Changes) .. " CHANGES",
                TextColor3 = thm.Accent,
                TextSize = fs(11),
                Font = Enum.Font.GothamBold,
                Parent = rightBadge
            })
        end
        local changesFrame = make("Frame", {
            Size = UDim2.new(1, 0, 0, 0),
            AutomaticSize = Enum.AutomaticSize.Y,
            BackgroundTransparency = 1,
            Parent = verFrame
        })
        make("UIListLayout", { SortOrder = Enum.SortOrder.LayoutOrder, Padding = sz(8), Parent = changesFrame })
        if ver.Changes then
            for _, change in ipairs(ver.Changes) do
                local row = make("Frame", {
                    Size = UDim2.new(1, 0, 0, 0),
                    AutomaticSize = Enum.AutomaticSize.Y,
                    BackgroundColor3 = thm.Element,
                    Parent = changesFrame
                })
                make("UICorner", { CornerRadius = sz(8), Parent = row })
                make("UIStroke", { Color = thm.Border, Transparency = 0.7, Thickness = 1, Parent = row })
                make("UIPadding", { PaddingTop = sz(12), PaddingBottom = sz(12), PaddingLeft = sz(12), PaddingRight = sz(12), Parent = row })
                make("UIListLayout", {
                    FillDirection = Enum.FillDirection.Horizontal,
                    SortOrder = Enum.SortOrder.LayoutOrder,
                    VerticalAlignment = Enum.VerticalAlignment.Top,
                    Padding = sz(12),
                    Parent = row
                })
                local typeStr = change.Type or "Note"
                local cfg = typeConfig[typeStr] or { Color = Color3.fromRGB(149, 165, 166), Icon = "solar/document-bold" }
                local iconBox = make("Frame", {
                    Size = UDim2.new(0, s(32), 0, s(32)),
                    BackgroundColor3 = cfg.Color,
                    BackgroundTransparency = 0.85,
                    LayoutOrder = 1,
                    Parent = row
                })
                make("UICorner", { CornerRadius = sz(8), Parent = iconBox })
                make("UIStroke", { Color = cfg.Color, Transparency = 0.4, Thickness = 1, Parent = iconBox })
                local img = make("ImageLabel", {
                    Size = ss(18, 18),
                    AnchorPoint = Vector2.new(0.5, 0.5),
                    Position = UDim2.fromScale(0.5, 0.5),
                    BackgroundTransparency = 1,
                    Parent = iconBox
                })
                applyIcon(img, cfg.Icon, cfg.Color)
                local textContainer = make("Frame", {
                    Size = UDim2.new(1, -s(44), 0, 0),
                    AutomaticSize = Enum.AutomaticSize.Y,
                    BackgroundTransparency = 1,
                    LayoutOrder = 2,
                    Parent = row
                })
                make("UIListLayout", { SortOrder = Enum.SortOrder.LayoutOrder, Padding = sz(2), Parent = textContainer })
                local titleStr = change.Title or typeStr
                local descStr = change.Text or ""
                make("TextLabel", {
                    Size = UDim2.new(1, 0, 0, 0),
                    AutomaticSize = Enum.AutomaticSize.Y,
                    BackgroundTransparency = 1,
                    Text = titleStr,
                    TextColor3 = thm.Text,
                    TextSize = fs(14),
                    Font = Enum.Font.GothamBold,
                    TextXAlignment = Enum.TextXAlignment.Left,
                    TextWrapped = true,
                    RichText = true,
                    Parent = textContainer
                })
                make("TextLabel", {
                    Size = UDim2.new(1, 0, 0, 0),
                    AutomaticSize = Enum.AutomaticSize.Y,
                    BackgroundTransparency = 1,
                    Text = descStr,
                    TextColor3 = thm.SubText,
                    TextSize = fs(12),
                    Font = Enum.Font.GothamMedium,
                    TextXAlignment = Enum.TextXAlignment.Left,
                    TextWrapped = true,
                    RichText = true,
                    LineHeight = 1.1,
                    Parent = textContainer
                })
            end
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
        BackgroundTransparency=1, Text=cfg.Title or "Audio Player", TextColor3=thm.Text, TextSize=fs(14),
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
        Text=cfg.Code or "", TextColor3=thm.Accent, TextSize=fs(12), Font=Enum.Font.Code,
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
    local controls = make("Frame", {
        Size = UDim2.new(1, -s(12), 0, s(28)),
        Position = UDim2.new(0, s(6), 1, -s(34)),
        BackgroundColor3 = Color3.fromRGB(0, 0, 0),
        BackgroundTransparency = 0.4,
        BorderSizePixel = 0,
        ZIndex = 5,
        Parent = videoContainer
    })
    make("UICorner", { CornerRadius = sz(9), Parent = controls })
    local layout = make("UIListLayout", {
        FillDirection = Enum.FillDirection.Horizontal,
        VerticalAlignment = Enum.VerticalAlignment.Center,
        HorizontalAlignment = Enum.HorizontalAlignment.Left,
        SortOrder = Enum.SortOrder.LayoutOrder,
        Padding = sz(8),
        Parent = controls
    })
    make("UIPadding", { PaddingLeft = sz(8), PaddingRight = sz(8), Parent = controls })
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
function Section:AddViewport(id, cfg)
    cfg = cfg or {}
    local thm = Aurora.Theme or Aurora.Themes.Dark
    local height = cfg.Height or 200
    local title = cfg.Title or "3D Viewport"
    local camDist = cfg.CameraDistance or 8
    local camAngleY = cfg.CameraAngleY or 25
    local spinSpeed = cfg.SpinSpeed or 0
    local autoSpin = cfg.AutoSpin or false
    local f = elemFrame(self.Container)
    local headerRow = make("Frame", {
        Size = UDim2.new(1, 0, 0, s(24)),
        BackgroundTransparency = 1,
        Parent = f,
    })
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
        local scale = make("UIScale", { Scale = 1, Parent = btn })
        btn.MouseEnter:Connect(function() if _isMobile then return end 
            tw(scale, { Scale = 1.08 }, 0.12, Enum.EasingStyle.Quad)
            tw(btn, { BackgroundTransparency = 0 }, 0.12)
            tw(bStroke, { Transparency = 0, Color = thm.Accent }, 0.12)
        end)
        btn.MouseLeave:Connect(function() if _isMobile then return end 
            tw(scale, { Scale = 1.0 }, 0.12, Enum.EasingStyle.Quad)
            tw(btn, { BackgroundTransparency = 0.3 }, 0.12)
            tw(bStroke, { Transparency = 0.4, Color = thm.Border }, 0.12)
        end)
        return btn, ico
    end
    local resetBtn,  resetIco  = mkToolBtn("solar/restart-bold",        "Reset Camera")
    local spinBtn,   spinIco   = mkToolBtn("solar/refresh-circle-bold", "Toggle Auto-Spin")
    local clearBtn,  clearIco  = mkToolBtn("solar/close-circle-bold",   "Clear Model")
    local vpOuter = make("Frame", {
        Size = UDim2.new(1, 0, 0, s(height)),
        BackgroundColor3 = thm.InputBG,
        BorderSizePixel = 0,
        ClipsDescendants = true,
        Parent = f,
    })
    make("UICorner", { CornerRadius = sz(10), Parent = vpOuter })
    reg(vpOuter, "BackgroundColor3", "InputBG")
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
    local vp = make("ViewportFrame", {
        Size = UDim2.fromScale(1, 1),
        BackgroundTransparency = 1,
        LightColor = Color3.fromRGB(230, 235, 255),
        LightDirection = Vector3.new(-1, -1.5, -0.8),
        Ambient = Color3.fromRGB(95, 95, 110),
        Parent = vpOuter,
    })
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
    local vpCamera = Instance.new("Camera")
    vpCamera.FieldOfView = 50
    vpCamera.Parent = vp
    vp.CurrentCamera = vpCamera
    local modelRoot = nil
    local currentModel = nil
    local modelOrigin = Vector3.zero
    local camAngleX = 0
    local camAngleYCur = camAngleY
    local camDistCur = camDist
    local spinning = autoSpin
    local spinDeg = spinSpeed ~= 0 and spinSpeed or 30
    local _allConns = {}
    local charConn = nil
    local function disconnectCharConn()
        if charConn then
            pcall(function() charConn:Disconnect() end)
            charConn = nil
        end
    end
    local worldModel = Instance.new("WorldModel")
    worldModel.Parent = vp
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
    local function updateFooter(name, partCount)
        if name and name ~= "" then
            footerLbl.Text = name .. (partCount and ("  |  " .. partCount .. " parts") or "")
        else
            footerLbl.Text = ""
        end
    end
    local function clearModel()
        disconnectCharConn()
        if currentModel then
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
    local function loadModelIntoViewport(model)
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
            pcall(function() clone:PivotTo(CFrame.new(Vector3.zero)) end)
            for _, d in ipairs(clone:GetDescendants()) do
                if d:IsA("BasePart") then
                    partCount = partCount + 1
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
        local bbSize = Vector3.new(4, 6, 4)
        pcall(function()
            if clone:IsA("Model") then
                local _, sz2 = clone:GetBoundingBox()
                bbSize = sz2
            elseif clone:IsA("BasePart") then
                bbSize = clone.Size
            end
        end)
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
        phFrame.Visible = false
        updateFooter(modelName, partCount)
        updateCamera()
    end
    local dragging = false
    local dragStart = nil
    local dragAngleX0 = 0
    local dragAngleY0 = 0
    vp.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1
        or input.UserInputType == Enum.UserInputType.Touch then
            dragging = true
            dragStart = input.Position
            dragAngleX0 = camAngleX
            dragAngleY0 = camAngleYCur
            tw(vpStroke, { Transparency = 0 }, 0.15)
        end
    end)
    local vpDragConn = UserInputService.InputChanged:Connect(function(input)
        if dragging and (input.UserInputType == Enum.UserInputType.MouseMovement
            or input.UserInputType == Enum.UserInputType.Touch) then
            if not dragStart then return end
            local delta = input.Position - dragStart
            camAngleX = dragAngleX0 - delta.X * 0.5
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
    vp.InputChanged:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseWheel then
            camDistCur = math.clamp(camDistCur - input.Position.Z * 0.8, 2, 60)
            updateCamera()
        end
    end)
    vpOuter.MouseEnter:Connect(function() if _isMobile then return end 
        if not dragging then
            tw(vpStroke, { Transparency = 0.1 }, 0.2)
        end
    end)
    vpOuter.MouseLeave:Connect(function() if _isMobile then return end 
        if not dragging then
            tw(vpStroke, { Transparency = 0.3 }, 0.2)
        end
    end)
    local spinConn
    local function startSpinLoop()
        if spinConn then return end
        spinConn = game:GetService("RunService").RenderStepped:Connect(function(dt)
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
    local function updateSpinVisual()
        local col = spinning and thm.Accent or thm.SubText
        applyIcon(spinIco, "solar/refresh-circle-bold", col)
    end
    updateSpinVisual()
    spinBtn.MouseButton1Click:Connect(function()
        spinning = not spinning
        updateSpinVisual()
        local sc = make("UIScale", { Scale = 1, Parent = spinBtn })
        tw(sc, { Scale = 0.88 }, 0.06)
        task.delay(0.06, function() tw(sc, { Scale = 1 }, 0.1, Enum.EasingStyle.Back) end)
        task.delay(0.18, function() pcall(function() sc:Destroy() end) end)
    end)
    resetBtn.MouseButton1Click:Connect(function()
        camAngleX = 0
        camAngleYCur = camAngleY
        camDistCur = camDist
        updateCamera()
        local sc = make("UIScale", { Scale = 1, Parent = resetBtn })
        tw(sc, { Scale = 0.88 }, 0.06)
        task.delay(0.06, function() tw(sc, { Scale = 1 }, 0.12, Enum.EasingStyle.Back) end)
        task.delay(0.20, function() pcall(function() sc:Destroy() end) end)
    end)
    clearBtn.MouseButton1Click:Connect(function()
        clearModel()
        local sc = make("UIScale", { Scale = 1, Parent = clearBtn })
        tw(sc, { Scale = 0.88 }, 0.06)
        task.delay(0.06, function() tw(sc, { Scale = 1 }, 0.12, Enum.EasingStyle.Back) end)
        task.delay(0.20, function() pcall(function() sc:Destroy() end) end)
    end)
    f.Destroying:Connect(function()
        for _, conn in ipairs(_allConns) do
            pcall(function() conn:Disconnect() end)
        end
        if phPulseConn then pcall(function() phPulseConn:Disconnect() end) end
        pcall(function() worldModel:Destroy() end)
        pcall(function() vpCamera:Destroy() end)
    end)
    updateCamera()
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
        spinDeg = degsPerSec or 30
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
    Toggle = { Save=function(idx,o) return{type="Toggle",idx=idx,value=o.Value} end, Load=function(idx,d) if SaveManager.Options[idx] then SaveManager.Options[idx]:SetValue(d.value) end end },
    Slider = { Save=function(idx,o) return{type="Slider",idx=idx,value=o.Value} end, Load=function(idx,d) if SaveManager.Options[idx] then SaveManager.Options[idx]:SetValue(d.value) end end },
    Dropdown = { Save=function(idx,o) return{type="Dropdown",idx=idx,value=o.Value} end, Load=function(idx,d) if SaveManager.Options[idx] then SaveManager.Options[idx]:SetValue(d.value) end end },
    Colorpicker={ Save=function(idx,o) return{type="Colorpicker",idx=idx,value=colorToHex(o.Value),transparency=o.Transparency or 0} end, Load=function(idx,d) if SaveManager.Options[idx] then SaveManager.Options[idx]:SetValueRGB(hexToColor(d.value),d.transparency) end end },
    Keybind = { Save=function(idx,o) return{type="Keybind",idx=idx,key=o.Value.Name} end, Load=function(idx,d) if SaveManager.Options[idx] then SaveManager.Options[idx]:SetValue(Enum.KeyCode[d.key]) end end },
    Input = { Save=function(idx,o) return{type="Input",idx=idx,text=o.Value} end, Load=function(idx,d) if SaveManager.Options[idx] and type(d.text)=="string" then SaveManager.Options[idx]:SetValue(d.text) end end },
}
function SaveManager:SetIgnoreIndexes(list) for _,k in next,list do self.Ignore[k]=true end end
function SaveManager:IgnoreIndexes(list) self:SetIgnoreIndexes(list) end
function SaveManager:SetFolder(folder) self.Folder=folder; self:BuildFolderTree() end
function SaveManager:BuildFolderTree()
    local gameFolder = self.Folder .. "/settings/" .. tostring(game.PlaceId)
    local paths = {self.Folder, self.Folder .. "/settings", gameFolder}
    for _, p2 in ipairs(paths) do
        pcall(function() if not isfolder(p2) then makefolder(p2) end end)
    end
    return gameFolder
end
function SaveManager:SetLibrary(lib) self.Library=lib; self.Options=lib.Options; pcall(function() self:BuildFolderTree() end) end
function SaveManager:IgnoreThemeSettings() self:SetIgnoreIndexes({"InterfaceTheme","AcrylicToggle","TransparentToggle","MenuKeybind","AnimationToggle"}) end
function SaveManager:Save(name)
    if not name or tostring(name):gsub("%s+","") == "" then return false,"no config selected" end
    self:BuildFolderTree()
    local data={objects={}}
    for idx,opt in next,SaveManager.Options do
        if self.Parser[opt.Type] and not self.Ignore[idx] then
            table.insert(data.objects, self.Parser[opt.Type].Save(idx,opt))
        end
    end
    local ok,enc=pcall(httpService.JSONEncode,httpService,data)
    if not ok then return false,"encode failed" end
    local path = self.Folder .. "/settings/" .. tostring(game.PlaceId) .. "/" .. name .. ".json"
    local wok = pcall(writefile, path, enc)
    if not wok then return false,"write failed (executor sin writefile?)" end
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
function SaveManager:GetConfigs() return self:RefreshConfigList() end
function SaveManager:GetPath() return self.Folder .. "/settings/" .. tostring(game.PlaceId) end
function SaveManager:Delete(name)
    if not name or name == "" then return false, "no config" end
    local f = self:GetPath() .. "/" .. name .. ".json"
    if not isfile(f) then return false, "not found" end
    local ok = pcall(delfile, f)
    if not ok then return false, "delete failed" end
    local ap = self:GetPath() .. "/autoload.txt"
    pcall(function() if isfile(ap) and readfile(ap) == name then delfile(ap); self.AutoloadConfig = nil end end)
    if self.CurrentConfig == name then self.CurrentConfig = nil end
    return true
end
function SaveManager:Rename(oldName, newName)
    if not oldName or not newName or newName:gsub("%s+","")=="" then return false, "invalid" end
    local srcF = self:GetPath() .. "/" .. oldName .. ".json"
    if not isfile(srcF) then return false, "not found" end
    local data = readfile(srcF)
    local ok = pcall(writefile, self:GetPath() .. "/" .. newName .. ".json", data)
    if not ok then return false, "write failed" end
    pcall(delfile, srcF)
    return true
end
function SaveManager:Serialize()
    local data = {objects={}}
    for idx,opt in next,SaveManager.Options do
        if self.Parser[opt.Type] and not self.Ignore[idx] then
            table.insert(data.objects, self.Parser[opt.Type].Save(idx,opt))
        end
    end
    return httpService:JSONEncode(data)
end
function SaveManager:ApplyString(str)
    if type(str) ~= "string" then return false, "invalid data" end
    local ok, dec = pcall(httpService.JSONDecode, httpService, str)
    if not ok or type(dec) ~= "table" or type(dec.objects) ~= "table" then return false, "invalid config data" end
    for _,opt in next,dec.objects do
        if self.Parser[opt.type] then task.spawn(function() self.Parser[opt.type].Load(opt.idx,opt) end) end
    end
    return true
end
function SaveManager:CopyToClipboard()
    local ok, enc = pcall(function() return self:Serialize() end)
    if not ok then return false, "encode failed" end
    local setClipboard = setclipboard or toclipboard or set_clipboard
    if not setClipboard then return false, "clipboard not supported" end
    local wok = pcall(setClipboard, enc)
    if not wok then return false, "clipboard write failed" end
    return true
end
function SaveManager:CopyConfigToClipboard(name)
    if not name or name == "" then return false, "no config" end
    local f = self:GetPath() .. "/" .. name .. ".json"
    if not isfile(f) then return false, "not found" end
    local setClipboard = setclipboard or toclipboard or set_clipboard
    if not setClipboard then return false, "clipboard not supported" end
    local wok = pcall(setClipboard, readfile(f))
    if not wok then return false, "clipboard write failed" end
    return true
end
function SaveManager:LoadFromClipboard()
    local getClipboard = getclipboard or get_clipboard or (Clipboard and Clipboard.get)
    if not getClipboard then return false, "clipboard read not supported" end
    local ok, str = pcall(getClipboard)
    if not ok or type(str) ~= "string" or str == "" then return false, "clipboard empty" end
    return self:ApplyString(str)
end
function SaveManager:SetAutoload(name)
    self:BuildFolderTree()
    local ap = self.Folder .. "/settings/" .. tostring(game.PlaceId) .. "/autoload.txt"
    pcall(writefile, ap, tostring(name))
    self.AutoloadConfig = name
    return true
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
    self:BuildFolderTree()
    local function notify(msg) self.Library:Notify({Title="Config loader", Content=msg, Type="Info", Duration=5}) end
    sec:AddSeparator("Local configs")
    local nameInput = sec:AddInput("SaveManager_ConfigName", {Title="Config name", Placeholder="my config", Icon="solar/pen-new-round-bold"})
    local configDropdown = sec:AddDropdown("SaveManager_ConfigList", {Title="Saved configs", Values=self:RefreshConfigList(), Icon="solar/list-bold"})
    local autoloadDropdown
    local _autoPath = self:GetPath() .. "/autoload.txt"
    local function _currentAutoload()
        if isfile(_autoPath) then local n = readfile(_autoPath); if n and n ~= "" then return n end end
        return "None"
    end
    local function refreshLists()
        local cfgs = self:RefreshConfigList()
        configDropdown:Refresh(cfgs)
        if autoloadDropdown then
            local t = {"None"}
            for _,c in ipairs(cfgs) do table.insert(t, c) end
            autoloadDropdown:Refresh(t)
            autoloadDropdown:SetValue(_currentAutoload())
        end
    end
    sec:AddButton({Title="Create config", Icon="solar/diskette-bold", Description="Save current settings as a new config", Callback=function()
        local name = nameInput.Value
        if not name or name:gsub("%s+","") == "" then return notify("Invalid name") end
        local ok, err = self:Save(name)
        if not ok then return notify("Failed: "..tostring(err)) end
        notify(string.format("Created %q", name))
        refreshLists(); configDropdown:SetValue(name)
    end})
    sec:AddButton({Title="Load config", Icon="solar/upload-minimalistic-bold", Description="Load the selected config", Callback=function()
        local name = configDropdown.Value
        if not name or name == "" then return notify("No config selected") end
        local ok, err = self:Load(name)
        if not ok then return notify("Failed: "..tostring(err)) end
        notify(string.format("Loaded %q", name))
    end})
    sec:AddButton({Title="Overwrite config", Icon="solar/refresh-bold", Description="Save current settings over the selected config", Callback=function()
        local name = configDropdown.Value
        if not name or name == "" then return notify("No config selected") end
        local ok, err = self:Save(name)
        if not ok then return notify("Failed: "..tostring(err)) end
        notify(string.format("Overwrote %q", name))
    end})
    sec:AddButton({Title="Rename config", Icon="solar/pen-2-bold", Description="Rename selected config to the 'Config name' value", Callback=function()
        local old = configDropdown.Value
        local new = nameInput.Value
        if not old or old == "" then return notify("No config selected") end
        if not new or new:gsub("%s+","") == "" then return notify("Enter a new name first") end
        local ok, err = self:Rename(old, new)
        if not ok then return notify("Failed: "..tostring(err)) end
        notify(string.format("Renamed to %q", new))
        refreshLists(); configDropdown:SetValue(new)
    end})
    sec:AddButton({Title="Delete config", Icon="solar/trash-bin-trash-bold", Description="Delete the selected config", Callback=function()
        local name = configDropdown.Value
        if not name or name == "" then return notify("No config selected") end
        self.Library:Notify({
            Title = "Delete config", Content = string.format("Delete %q permanently?", name), Type = "Warning", Duration = 0,
            Buttons = {
                { Title = "Delete", Callback = function()
                    local ok, err = self:Delete(name)
                    if not ok then return notify("Failed: "..tostring(err)) end
                    notify(string.format("Deleted %q", name))
                    refreshLists(); configDropdown:SetValue(nil)
                end },
                { Title = "Cancel", Callback = function() end },
            },
        })
    end})
    sec:AddButton({Title="Refresh list", Icon="solar/restart-bold", Description="Reload the config list from the folder", Callback=function()
        refreshLists(); notify("List refreshed")
    end})
    sec:AddSeparator("Auto")
    autoloadDropdown = sec:AddDropdown("SaveManager_Autoload", {
        Title = "Auto-load on execute",
        Description = "Config loaded automatically when the script runs",
        Values = (function() local t = {"None"} for _,c in ipairs(self:RefreshConfigList()) do table.insert(t, c) end return t end)(),
        Default = _currentAutoload(),
        Icon = "solar/star-bold",
        Callback = function(val)
            if not val or val == "None" then
                pcall(function() if isfile(_autoPath) then delfile(_autoPath) end end)
                self.AutoloadConfig = nil
                notify("Autoload disabled")
            else
                self:SetAutoload(val)
                notify(string.format("Autoload set to %q", val))
            end
        end,
    })
    sec:AddToggle("SaveManager_Autosave", {
        Title = "Auto-save on change",
        Description = "Save the current config automatically whenever you change a setting",
        Default = false,
        Callback = function(v)
            self.Autosave = v
            if v and not self.CurrentConfig then
                local sel = configDropdown.Value
                if sel and sel ~= "" then self.CurrentConfig = sel end
            end
        end
    })
    sec:AddSeparator("Share (clipboard)")
    sec:AddButton({Title="Copy current config", Icon="solar/copy-bold", Description="Copy your CURRENT active settings to the clipboard", Callback=function()
        local ok, err = self:CopyToClipboard()
        if not ok then return notify("Failed: "..tostring(err)) end
        notify("Current config copied to clipboard!")
    end})
    sec:AddButton({Title="Copy selected config", Icon="solar/clipboard-list-bold", Description="Copy the selected saved config to the clipboard", Callback=function()
        local name = configDropdown.Value
        if not name or name == "" then return notify("No config selected") end
        local ok, err = self:CopyConfigToClipboard(name)
        if not ok then return notify("Failed: "..tostring(err)) end
        notify(string.format("Copied %q to clipboard!", name))
    end})
    sec:AddButton({Title="Load from clipboard", Icon="solar/clipboard-check-bold", Description="Apply a config straight from your clipboard", Callback=function()
        local ok, err = self:LoadFromClipboard()
        if not ok then return notify("Failed: "..tostring(err).." (try pasting below)") end
        notify("Config loaded from clipboard!")
    end})
    local pasteInput = sec:AddInput("SaveManager_Paste", {Title="Or paste a config here", Placeholder="paste config text...", Icon="solar/import-bold"})
    sec:AddButton({Title="Import pasted config", Icon="solar/download-minimalistic-bold", Description="Apply the config text pasted above", Callback=function()
        local str = pasteInput.Value
        if not str or str:gsub("%s+","") == "" then return notify("Paste a config first") end
        local ok, err = self:ApplyString(str)
        if not ok then return notify("Failed: "..tostring(err)) end
        notify("Config imported!")
    end})
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
local KeySystem = {}
KeySystem.__index = KeySystem
function KeySystem.new(cfg)
    cfg = cfg or {}
    local self = setmetatable({}, KeySystem)
    self.Title = cfg.Title or "Key System"
    self.SubTitle = cfg.SubTitle or "Verification Required"
    self.Note = cfg.Note or "Please enter your access key below."
    self.Keys = cfg.Keys or {}
    self.PremiumKeys = cfg.PremiumKeys or {}
    self.KeyLink = cfg.KeyLink or ""
    self.SaveKey = cfg.SaveKey ~= false
    self.FileName = cfg.FileName or "AuroraKey.txt"
    self.OnSuccess = cfg.OnSuccess or function() end
    self.CustomValidate = cfg.CustomValidate
    self.ShowExit = cfg.ShowExit ~= false
    self.OnExit = cfg.OnExit
    Aurora._keyConfig = {
        SaveKey = self.SaveKey,
        FileName = self.FileName,
        CustomValidate = self.CustomValidate,
        Keys = self.Keys,
        PremiumKeys = self.PremiumKeys,
        KeyMethods = cfg.KeyMethods,
        PremiumButton = cfg.PremiumButton,
    }
    local isfile = isfile or function() return false end
    local readfile = readfile or function() return "" end
    local writefile = writefile or function() end
    local function validateKey(key)
        if self.CustomValidate then
            local ok, res, tier = pcall(self.CustomValidate, key)
            if ok and res then
                local prem = (tier == true) or (type(tier) == "string" and tier:lower():find("prem") ~= nil)
                return true, prem
            end
        end
        for _, k in ipairs(self.PremiumKeys) do
            if k == key then return true, true end
        end
        for _, k in ipairs(self.Keys) do
            if k == key then return true, false end
        end
        return false, false
    end
    Aurora._keyConfig._validateKey = validateKey
    Aurora._keyConfig._writefile = writefile
    local thm = Aurora.Theme or Aurora.Themes.Dark
    local keyGui = make("ScreenGui", { Name = "AuroraKeySystem", ResetOnSpawn = false, DisplayOrder = 100000 })
    safeParent(keyGui)
    local _methods = (type(cfg.KeyMethods)=="table" and cfg.KeyMethods) or {}
    local _links = (type(cfg.Links)=="table" and cfg.Links) or (type(cfg.Buttons)=="table" and cfg.Buttons) or {}
    local _hasMethods = #_methods > 0
    local _hasLinks = #_links > 0
    local selectedLink = self.KeyLink or ""
    local _prem = cfg.PremiumButton
    local _hasPremium = type(_prem) == "table" and (_prem.Link ~= nil or _prem.Url ~= nil)
    if _hasPremium then Aurora.PremiumLink = _prem.Link or _prem.Url end
    local _robux = cfg.RobuxButton
    local _hasRobux = type(_robux) == "table" and (_robux.Link ~= nil or _robux.Url ~= nil)
    local _socialY, _methodY, _premiumY, _robuxY
    local _y = s(222)
    if _hasPremium then _premiumY = _y; _y = _y + s(42) end
    if _hasRobux then _robuxY = _y; _y = _y + s(42) end
    local _statusY = _y
    _y = _y + s(20)
    if _hasLinks then _socialY = _y; _y = _y + s(42) end
    if _hasMethods then _methodY = _y; _y = _y + s(42) end
    local _frameH = math.max(s(256), _y + s(6))
    local mainFrame = make("Frame", {
        Size = UDim2.fromOffset(s(380), _frameH),
        Position = UDim2.fromScale(0.5, 0.5),
        AnchorPoint = Vector2.new(0.5, 0.5),
        BackgroundColor3 = thm.Background,
        BackgroundTransparency = 0.05,
        Active = true,
        Parent = keyGui
    })
    createAcrylic(mainFrame)
    make("UICorner", { CornerRadius = sz(16), Parent = mainFrame })
    local mainStroke = make("UIStroke", { Color = thm.Border, Thickness = 1, Parent = mainFrame })
    make("UIGradient", {
        Color = ColorSequence.new({
            ColorSequenceKeypoint.new(0, thm.Accent),
            ColorSequenceKeypoint.new(0.42, thm.Border),
            ColorSequenceKeypoint.new(1, thm.AccentDim),
        }),
        Rotation = 35,
        Parent = mainStroke,
    })
    local _entryScale = make("UIScale", { Scale = 0.8, Parent = mainFrame })
    local dragFrame=fitMobileCard(keyGui,mainFrame,s(380),_frameH) or mainFrame
    mainFrame.BackgroundTransparency = 1
    tw(_entryScale, { Scale = 1 }, 0.45, Enum.EasingStyle.Back, Enum.EasingDirection.Out)
    tw(mainFrame, { BackgroundTransparency = 0.05 }, 0.4)
    if self.ShowExit then
        local exitBtn = make("TextButton", {
            Size = ss(24,24), AnchorPoint = Vector2.new(1,0), Position = UDim2.new(1,-s(10),0,s(10)),
            BackgroundColor3 = thm.Element, BackgroundTransparency = 0.3, Text = "", AutoButtonColor = false, ZIndex = 5, Parent = mainFrame,
        })
        make("UICorner", { CornerRadius = UDim.new(1,0), Parent = exitBtn })
        local exitIco = make("ImageLabel", { Size = ss(12,12), AnchorPoint = Vector2.new(0.5,0.5), Position = UDim2.fromScale(0.5,0.5), BackgroundTransparency = 1, ZIndex = 6, Parent = exitBtn })
        applyIcon(exitIco, "solar/close-linear", thm.SubText)
        exitBtn.MouseEnter:Connect(function() if _isMobile then return end tw(exitBtn, { BackgroundColor3 = Color3.fromRGB(200,50,50), BackgroundTransparency = 0.1 }, 0.12) end)
        exitBtn.MouseLeave:Connect(function() if _isMobile then return end tw(exitBtn, { BackgroundColor3 = thm.Element, BackgroundTransparency = 0.3 }, 0.12) end)
        exitBtn.MouseButton1Click:Connect(function()
            tw(mainFrame, { Size = UDim2.fromOffset(0,0), BackgroundTransparency = 1 }, 0.25)
            task.delay(0.26, function()
                pcall(function() keyGui:Destroy() end)
                if self.OnExit then pcall(self.OnExit) end
            end)
        end)
    end
    local dragInput, dragStart, startPos
    mainFrame.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
            dragStart = input.Position
            startPos = dragFrame.Position
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
            dragFrame.Position = UDim2.new(startPos.X.Scale, startPos.X.Offset + delta.X, startPos.Y.Scale, startPos.Y.Offset + delta.Y)
        end
    end)
    keyGui.Destroying:Connect(function()
        pcall(function() changedConn:Disconnect() end)
    end)
    local logoCircle = make("Frame", {
        Size = ss(38,38), Position = UDim2.new(0, s(12), 0, s(13)),
        BackgroundColor3 = thm.Accent, BackgroundTransparency = 0.82, BorderSizePixel = 0, Parent = mainFrame,
    })
    make("UICorner", { CornerRadius = UDim.new(1,0), Parent = logoCircle })
    make("UIStroke", { Color = thm.Accent, Thickness = 1, Transparency = 0.4, Parent = logoCircle })
    local logoScale = make("UIScale", { Scale = 1, Parent = logoCircle })
    local logoIco = make("ImageLabel", { Size = ss(20,20), AnchorPoint = Vector2.new(0.5,0.5), Position = UDim2.fromScale(0.5,0.5), BackgroundTransparency = 1, Parent = logoCircle })
    applyIcon(logoIco, cfg.Icon or "solar/key-bold", thm.Accent)
    task.spawn(function()
        while logoCircle.Parent do
            tw(logoScale, { Scale = 1.06 }, 0.85, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut)
            task.wait(0.9)
            if not logoCircle.Parent then break end
            tw(logoScale, { Scale = 1 }, 0.85, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut)
            task.wait(1.8)
        end
    end)
    local titleLbl = make("TextLabel", {
        Size = UDim2.new(1, -s(96), 0, s(28)),
        Position = UDim2.new(0, s(56), 0, s(14)),
        BackgroundTransparency = 1,
        Text = self.Title,
        TextColor3 = thm.Text,
        TextSize = fs(18),
        Font = Enum.Font.GothamBold,
        TextXAlignment = Enum.TextXAlignment.Left,
        Parent = mainFrame
    })
    local subLbl = make("TextLabel", {
        Size = UDim2.new(1, -s(66), 0, s(18)),
        Position = UDim2.new(0, s(56), 0, s(38)),
        BackgroundTransparency = 1,
        Text = self.SubTitle,
        TextColor3 = thm.SubText,
        TextSize = fs(11),
        Font = Enum.Font.GothamMedium,
        TextXAlignment = Enum.TextXAlignment.Left,
        Parent = mainFrame
    })
    make("Frame", {
        Size = UDim2.new(1, -s(24), 0, 1),
        Position = UDim2.new(0, s(12), 0, s(64)),
        BackgroundColor3 = thm.Border,
        BorderSizePixel = 0,
        Parent = mainFrame
    })
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
    local inputBG = make("Frame", {
        Size = UDim2.new(1, -s(24), 0, s(36)),
        Position = UDim2.new(0, s(12), 0, s(125)),
        BackgroundColor3 = thm.InputBG,
        BorderSizePixel = 0,
        Parent = mainFrame
    })
    make("UICorner", { CornerRadius = sz(12), Parent = inputBG })
    local inputStroke = make("UIStroke", { Color = thm.Border, Thickness = 1, Parent = inputBG })
    local keyIco = make("ImageLabel", { Size = ss(14,14), AnchorPoint = Vector2.new(0,0.5), Position = UDim2.new(0, s(11), 0.5, 0), BackgroundTransparency = 1, Parent = inputBG })
    applyIcon(keyIco, "solar/key-minimalistic-bold", thm.SubText)
    local textBox = make("TextBox", {
        Size = UDim2.new(1, -s(42), 1, 0),
        Position = UDim2.new(0, s(34), 0, 0),
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
    textBox.Focused:Connect(function()
        tw(inputBG, { BackgroundColor3 = thm.Background }, 0.16)
        tw(inputStroke, { Color = thm.Accent, Transparency = 0.05, Thickness = 1.5 }, 0.16)
        tw(keyIco, { ImageColor3 = thm.Accent }, 0.16)
    end)
    textBox.FocusLost:Connect(function()
        tw(inputBG, { BackgroundColor3 = thm.InputBG }, 0.16)
        tw(inputStroke, { Color = thm.Border, Transparency = 0, Thickness = 1 }, 0.16)
        tw(keyIco, { ImageColor3 = thm.SubText }, 0.16)
    end)
    local btnFrame = make("Frame", {
        Size = UDim2.new(1, -s(24), 0, s(36)),
        Position = UDim2.new(0, s(12), 0, s(180)),
        BackgroundTransparency = 1,
        Parent = mainFrame
    })
    local verifyBtn = make("TextButton", {
        Size = UDim2.new(0.5, -s(6), 1, 0),
        BackgroundColor3 = thm.Accent,
        Text = "",
        AutoButtonColor = false,
        Parent = btnFrame
    })
    make("UICorner", { CornerRadius = sz(12), Parent = verifyBtn })
    local verifyStroke = make("UIStroke", { Color = thm.Accent, Thickness = 1, Transparency = 0.15, Parent = verifyBtn })
    make("UIGradient", { Color = ColorSequence.new({ ColorSequenceKeypoint.new(0, thm.Accent), ColorSequenceKeypoint.new(1, thm.AccentDim) }), Rotation = 90, Parent = verifyBtn })
    local getBtn = make("TextButton", {
        Size = UDim2.new(0.5, -s(6), 1, 0),
        Position = UDim2.new(0.5, s(6), 0, 0),
        BackgroundColor3 = thm.Element,
        Text = "",
        AutoButtonColor = false,
        Parent = btnFrame
    })
    make("UICorner", { CornerRadius = sz(12), Parent = getBtn })
    local getStroke = make("UIStroke", { Color = thm.Border, Thickness = 1, Parent = getBtn })
    make("UIGradient", { Color = ColorSequence.new({ ColorSequenceKeypoint.new(0, thm.ElementHover), ColorSequenceKeypoint.new(1, thm.Element) }), Rotation = 90, Parent = getBtn })
    local verifyIco = make("ImageLabel", { Size = ss(15,15), Position = UDim2.new(0, s(18), 0.5, 0), AnchorPoint = Vector2.new(0,0.5), BackgroundTransparency = 1, Parent = verifyBtn })
    local getIco = make("ImageLabel", { Size = ss(15,15), Position = UDim2.new(0, s(18), 0.5, 0), AnchorPoint = Vector2.new(0,0.5), BackgroundTransparency = 1, Parent = getBtn })
    applyIcon(verifyIco, "solar/shield-check-bold", Color3.fromRGB(255,255,255))
    applyIcon(getIco, "solar/link-bold", thm.Text)
    local verifyLbl = make("TextLabel", { Size = UDim2.new(1,-s(45),1,0), Position = UDim2.new(0,s(39),0,0), BackgroundTransparency = 1, Text = "Verify Key", TextColor3 = Color3.fromRGB(255,255,255), TextSize = fs(12), Font = Enum.Font.GothamBold, TextXAlignment = Enum.TextXAlignment.Left, Parent = verifyBtn })
    local getLbl = make("TextLabel", { Size = UDim2.new(1,-s(45),1,0), Position = UDim2.new(0,s(39),0,0), BackgroundTransparency = 1, Text = "Get Key", TextColor3 = thm.Text, TextSize = fs(12), Font = Enum.Font.GothamBold, TextXAlignment = Enum.TextXAlignment.Left, Parent = getBtn })
    local statusLbl = make("TextLabel", {
        Size = UDim2.new(1, -s(48), 0, s(20)),
        Position = UDim2.new(0, s(36), 0, _statusY),
        BackgroundTransparency = 1,
        Text = "",
        TextColor3 = thm.AlertSuccess,
        TextSize = fs(11),
        Font = Enum.Font.GothamMedium,
        TextXAlignment = Enum.TextXAlignment.Center,
        Parent = mainFrame
    })
    local statusDot = make("Frame", {
        Size = ss(6,6),
        Position = UDim2.new(0, s(15), 0, _statusY + s(7)),
        BackgroundColor3 = thm.SubText,
        BackgroundTransparency = 0.15,
        BorderSizePixel = 0,
        Parent = mainFrame,
    })
    make("UICorner", { CornerRadius = UDim.new(1,0), Parent = statusDot })
    local statusDotScale = make("UIScale", { Scale = 1, Parent = statusDot })
    local function setStatus(text, color)
        local nextColor = color or thm.SubText
        statusLbl.TextColor3 = nextColor
        statusLbl.TextTransparency = 1
        statusLbl.Text = tostring(text or "")
        tw(statusLbl, { TextTransparency = 0 }, 0.18, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
        tw(statusDot, { BackgroundColor3 = nextColor }, 0.18)
        statusDotScale.Scale = 0.72
        tw(statusDotScale, { Scale = 1 }, 0.32, Enum.EasingStyle.Back, Enum.EasingDirection.Out)
    end
    local function addBtnEffect(btn, bgNormal, bgHover, stroke)
        local btnScale = make("UIScale", { Scale = 1, Parent = btn })
        btn.MouseEnter:Connect(function() if _isMobile then return end 
            tw(btn, { BackgroundColor3 = bgHover }, 0.15)
            if stroke then tw(stroke, { Color = bgHover, Transparency = 0 }, 0.15) end
        end)
        btn.MouseLeave:Connect(function() if _isMobile then return end 
            tw(btn, { BackgroundColor3 = bgNormal }, 0.15)
            if stroke then tw(stroke, { Color = bgNormal, Transparency = 0.15 }, 0.15) end
        end)
        btn.InputBegan:Connect(function(input)
            if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
                tw(btnScale, { Scale = 0.96 }, 0.08, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
            end
        end)
        btn.InputEnded:Connect(function(input)
            if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
                tw(btnScale, { Scale = 1 }, 0.16, Enum.EasingStyle.Back, Enum.EasingDirection.Out)
            end
        end)
    end
    addBtnEffect(verifyBtn, thm.Accent, thm.AccentDim, verifyStroke)
    addBtnEffect(getBtn, thm.Element, thm.ElementHover, getStroke)
    local verifying = false
    local function doVerify()
        if verifying then return end
        local inputKey = textBox.Text:gsub("%s+", "")
        if inputKey == "" then
            setStatus("Please enter a key!", thm.AlertError)
            return
        end
        verifying = true
        verifyBtn.Active = false
        verifyLbl.Text = "Verifying..."
        tw(verifyIco, { Rotation = 360 }, 0.7, Enum.EasingStyle.Linear, Enum.EasingDirection.InOut)
        setStatus("Verifying...", thm.SubText)
        task.wait(0.5)
        local _valid, _prem = validateKey(inputKey)
        if _valid then
            if _prem then
                Aurora:UnlockPremium()
            else
                Aurora.IsPremium = false
                Aurora.KeySystem.Tier = "free"
            end
            setStatus(Aurora.IsPremium and "Premium Key Verified! Loading..." or "Key Verified! Loading script...", thm.AlertSuccess)
            verifyLbl.Text = "Verified"
            if self.SaveKey and writefile then
                pcall(writefile, self.FileName, inputKey)
            end
            task.wait(0.5)
            tw(mainFrame, { Size = UDim2.fromOffset(0, 0), BackgroundTransparency = 1 }, 0.3)
            task.wait(0.3)
            keyGui:Destroy()
            task.spawn(function() self.OnSuccess(Aurora.IsPremium) end)
        else
            verifying = false
            verifyBtn.Active = true
            verifyLbl.Text = "Try Again"
            setStatus("Invalid Key! Please try again.", thm.AlertError)
            local _bp = mainFrame.Position
            pcall(function() tw(inputStroke, { Color = thm.AlertError, Thickness = 1.5 }, 0.1) end)
            for _, _dx in ipairs({ -10, 9, -7, 5, -3, 0 }) do
                local _sh = tw(mainFrame, { Position = _bp + UDim2.fromOffset(_dx, 0) }, 0.045)
                _sh.Completed:Wait()
            end
            mainFrame.Position = _bp
            task.delay(1, function()
                if verifyLbl and verifyLbl.Parent then verifyLbl.Text = "Verify Key" end
            end)
            task.delay(0.9, function() pcall(function() tw(inputStroke, { Color = thm.Border, Thickness = 1 }, 0.2) end) end)
        end
    end
    verifyBtn.MouseButton1Click:Connect(doVerify)
    textBox.FocusLost:Connect(function(enter) if enter then doVerify() end end)
    -- Auto-verifica la key GUARDADA de forma ASINCRONA: muestra el GUI y, si la key
    -- guardada es valida, se cierra solo. Asi re-ejecutar NUNCA se cuelga aunque la API tarde.
    if self.SaveKey and isfile and isfile(self.FileName) then
        task.spawn(function()
            local cachedKey = readfile(self.FileName)
            task.wait(0.55)
            pcall(function() setStatus("Checking saved key...", thm.SubText) end)
            local _cValid, _cPrem = validateKey(cachedKey)
            if _cValid then
                if _cPrem then
                    Aurora:UnlockPremium()
                else
                    Aurora.IsPremium = false
                    Aurora.KeySystem.Tier = "free"
                end
                pcall(function()
                    textBox.Text = string.rep("*", math.min(16, math.max(4, #cachedKey)))
                    setStatus("Saved key verified! Loading...", thm.AlertSuccess)
                    tw(inputStroke, { Color = thm.AlertSuccess, Thickness = 1.5 }, 0.2)
                end)
                task.wait(0.5)
                pcall(function() tw(mainFrame, { Size = UDim2.fromOffset(0, 0), BackgroundTransparency = 1 }, 0.3) end)
                task.wait(0.3)
                pcall(function() keyGui:Destroy() end)
                task.spawn(function() self.OnSuccess(Aurora.IsPremium) end)
            end
        end)
    end
    getBtn.MouseButton1Click:Connect(function()
        if selectedLink ~= "" then
            pcall(function()
                local setClipboard = setclipboard or toclipboard or set_clipboard
                if setClipboard then
                    setClipboard(selectedLink)
                    setStatus("Key link copied to clipboard!", thm.AlertInfo)
                    getLbl.Text = "Copied"
                    task.delay(1, function()
                        if getLbl and getLbl.Parent then getLbl.Text = "Get Key" end
                    end)
                else
                    setStatus("Clipboard not supported!", thm.AlertError)
                end
            end)
        else
            setStatus("No key link specified!", thm.AlertError)
        end
    end)
    if _hasPremium then
        local pBtn = make("TextButton", {
            Size = UDim2.new(1,-s(24),0,s(34)), Position = UDim2.new(0,s(12),0,_premiumY),
            BackgroundColor3 = Color3.fromRGB(222,176,98), AutoButtonColor = false, Text = "", ZIndex = 3, Parent = mainFrame,
        })
        make("UICorner", { CornerRadius = sz(10), Parent = pBtn })
        local pStroke = make("UIStroke", { Color = Color3.fromRGB(150,108,44), Thickness = 1, Transparency = 0.35, Parent = pBtn })
        make("UIGradient", { Color = ColorSequence.new({
            ColorSequenceKeypoint.new(0, Color3.fromRGB(236,200,132)),
            ColorSequenceKeypoint.new(1, Color3.fromRGB(200,146,66)) }), Rotation = 90, Parent = pBtn })
        local pIco = make("ImageLabel", { Size = ss(16,16), AnchorPoint = Vector2.new(0,0.5), Position = UDim2.new(0,s(12),0.5,0), BackgroundTransparency = 1, ZIndex = 4, Parent = pBtn })
        applyIcon(pIco, _prem.Icon or "solar/crown-bold", Color3.fromRGB(60,40,10))
        make("TextLabel", { Size = UDim2.new(1,-s(40),1,0), Position = UDim2.new(0,s(36),0,0), BackgroundTransparency = 1, Text = _prem.Title or "Premium Keys", TextColor3 = Color3.fromRGB(50,34,8), TextSize = fs(12), Font = Enum.Font.GothamBold, TextXAlignment = Enum.TextXAlignment.Left, ZIndex = 4, Parent = pBtn })
        addBtnEffect(pBtn, Color3.fromRGB(222,176,98), Color3.fromRGB(236,196,126), pStroke)
        pBtn.MouseButton1Click:Connect(function()
            local link = _prem.Link or _prem.Url or ""
            if link ~= "" then
                pcall(function()
                    local setClipboard = setclipboard or toclipboard or set_clipboard
                    if setClipboard then setClipboard(link) end
                end)
                setStatus("Premium keys link copied!", thm.AlertInfo)
            end
        end)
    end
    if _hasRobux then
        local rBtn = make("TextButton", {
            Size = UDim2.new(1,-s(24),0,s(34)), Position = UDim2.new(0,s(12),0,_robuxY),
            BackgroundColor3 = Color3.fromRGB(0,180,80), AutoButtonColor = false, Text = "", ZIndex = 3, Parent = mainFrame,
        })
        make("UICorner", { CornerRadius = sz(10), Parent = rBtn })
        local rStroke = make("UIStroke", { Color = Color3.fromRGB(0,120,50), Thickness = 1, Transparency = 0.35, Parent = rBtn })
        make("UIGradient", { Color = ColorSequence.new({
            ColorSequenceKeypoint.new(0, Color3.fromRGB(30,200,100)),
            ColorSequenceKeypoint.new(1, Color3.fromRGB(0,150,60)) }), Rotation = 90, Parent = rBtn })
        local rIco = make("ImageLabel", { Size = ss(16,16), AnchorPoint = Vector2.new(0,0.5), Position = UDim2.new(0,s(12),0.5,0), BackgroundTransparency = 1, ZIndex = 4, Parent = rBtn })
        applyIcon(rIco, _robux.Icon or "solar/wallet-bold", Color3.fromRGB(255,255,255))
        make("TextLabel", { Size = UDim2.new(1,-s(40),1,0), Position = UDim2.new(0,s(36),0,0), BackgroundTransparency = 1, Text = _robux.Title or "Buy with Robux", TextColor3 = Color3.fromRGB(255,255,255), TextSize = fs(12), Font = Enum.Font.GothamBold, TextXAlignment = Enum.TextXAlignment.Left, ZIndex = 4, Parent = rBtn })
        addBtnEffect(rBtn, Color3.fromRGB(0,180,80), Color3.fromRGB(30,210,110), rStroke)
        rBtn.MouseButton1Click:Connect(function()
            local link = _robux.Link or _robux.Url or ""
            if link ~= "" then
                pcall(function()
                    local setClipboard = setclipboard or toclipboard or set_clipboard
                    if setClipboard then setClipboard(link) end
                end)
                setStatus("Robux purchase link copied!", thm.AlertInfo)
            end
        end)
    end
    if _hasLinks then
        local socialFrame = make("Frame", { Size = UDim2.new(1,-s(24),0,s(34)), Position = UDim2.new(0,s(12),0,_socialY), BackgroundTransparency = 1, Parent = mainFrame })
        make("UIListLayout", { FillDirection = Enum.FillDirection.Horizontal, HorizontalAlignment = Enum.HorizontalAlignment.Center, VerticalAlignment = Enum.VerticalAlignment.Center, Padding = sz(6), SortOrder = Enum.SortOrder.LayoutOrder, Parent = socialFrame })
        local n = #_links
        for i, lk in ipairs(_links) do
            local isDiscord = string.lower(tostring(lk.Type or lk.Title or "")):find("discord") ~= nil
            local col = lk.Color or (isDiscord and Color3.fromRGB(88,101,242)) or thm.Element
            local b = make("TextButton", { Size = UDim2.new(1/n, -s(6), 1, 0), BackgroundColor3 = col, AutoButtonColor = false, Text = "", LayoutOrder = i, Parent = socialFrame })
            make("UICorner", { CornerRadius = sz(10), Parent = b })
            make("UIStroke", { Color = col:Lerp(Color3.new(0,0,0), 0.35), Thickness = 1, Transparency = 0.5, Parent = b })
            local hasIcon = lk.Icon and lk.Icon ~= ""
            if hasIcon then
                local ic = make("ImageLabel", { Size = ss(14,14), AnchorPoint = Vector2.new(0,0.5), Position = UDim2.new(0,s(10),0.5,0), BackgroundTransparency = 1, Parent = b })
                applyIcon(ic, lk.Icon, Color3.fromRGB(255,255,255))
            end
            make("TextLabel", { Size = UDim2.new(1, hasIcon and -s(28) or 0, 1, 0), Position = UDim2.new(0, hasIcon and s(28) or 0, 0, 0), BackgroundTransparency = 1, Text = lk.Title or "Link", TextColor3 = Color3.fromRGB(255,255,255), TextSize = fs(11), Font = Enum.Font.GothamBold, TextXAlignment = hasIcon and Enum.TextXAlignment.Left or Enum.TextXAlignment.Center, Parent = b })
            local baseCol = col
            b.MouseEnter:Connect(function() if _isMobile then return end tw(b, { BackgroundColor3 = baseCol:Lerp(Color3.new(1,1,1), 0.15) }, 0.12) end)
            b.MouseLeave:Connect(function() if _isMobile then return end tw(b, { BackgroundColor3 = baseCol }, 0.12) end)
            b.MouseButton1Click:Connect(function()
                local link = lk.Link or lk.Url or ""
                if link ~= "" then
                    pcall(function()
                        local setClipboard = setclipboard or toclipboard or set_clipboard
                        if setClipboard then setClipboard(link) end
                    end)
                    setStatus((lk.Title or "Link").." link copied!", thm.AlertInfo)
                end
            end)
        end
    end
    if _hasMethods then
        selectedLink = _methods[1].Link or _methods[1].Url or selectedLink
        local mdOpen = false
        local mdField = make("TextButton", { Size = UDim2.new(1,-s(24),0,s(34)), Position = UDim2.new(0,s(12),0,_methodY), BackgroundColor3 = thm.InputBG, AutoButtonColor = false, Text = "", ZIndex = 3, Parent = mainFrame })
        make("UICorner", { CornerRadius = sz(10), Parent = mdField })
        local mdStroke = make("UIStroke", { Color = thm.Border, Thickness = 1, Parent = mdField })
        local mdScale = make("UIScale", { Scale = 1, Parent = mdField })
        local mdIco = make("ImageLabel", { Size = ss(14,14), AnchorPoint = Vector2.new(0,0.5), Position = UDim2.new(0,s(10),0.5,0), BackgroundTransparency = 1, ZIndex = 4, Parent = mdField })
        applyIcon(mdIco, "solar/key-linear", thm.Accent)
        local mdLbl = make("TextLabel", { Size = UDim2.new(1,-s(56),1,0), Position = UDim2.new(0,s(32),0,0), BackgroundTransparency = 1, Text = "Get key via: "..(_methods[1].Name or "Method 1"), TextColor3 = thm.Text, TextSize = fs(12), Font = Enum.Font.GothamBold, TextXAlignment = Enum.TextXAlignment.Left, ZIndex = 4, Parent = mdField })
        local mdArr = make("ImageLabel", { Size = ss(12,12), AnchorPoint = Vector2.new(1,0.5), Position = UDim2.new(1,-s(10),0.5,0), BackgroundTransparency = 1, ZIndex = 4, Parent = mdField })
        applyIcon(mdArr, "solar/alt-arrow-down-linear", thm.SubText)
        local mdList = make("Frame", { Size = UDim2.new(1,0,0,0), Position = UDim2.new(0,0,1,s(4)), BackgroundColor3 = thm.Background, ClipsDescendants = true, ZIndex = 40, Parent = mdField })
        make("UICorner", { CornerRadius = sz(10), Parent = mdList })
        make("UIStroke", { Color = thm.Border, Thickness = 1, Parent = mdList })
        make("UIListLayout", { SortOrder = Enum.SortOrder.LayoutOrder, Padding = sz(2), Parent = mdList })
        make("UIPadding", { PaddingTop = sz(4), PaddingBottom = sz(4), PaddingLeft = sz(4), PaddingRight = sz(4), Parent = mdList })
        mdField.MouseEnter:Connect(function() if _isMobile then return end tw(mdStroke, { Color = thm.Accent, Transparency = 0.2 }, 0.14) end)
        mdField.MouseLeave:Connect(function() if _isMobile then return end tw(mdStroke, { Color = thm.Border, Transparency = 0 }, 0.14) end)
        mdField.InputBegan:Connect(function(input)
            if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
                tw(mdScale, { Scale = 0.985 }, 0.08)
            end
        end)
        mdField.InputEnded:Connect(function(input)
            if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
                tw(mdScale, { Scale = 1 }, 0.16, Enum.EasingStyle.Back, Enum.EasingDirection.Out)
            end
        end)
        for i, m in ipairs(_methods) do
            local it = make("TextButton", { Size = UDim2.new(1,0,0,s(28)), BackgroundColor3 = thm.InputBG, BackgroundTransparency = 1, AutoButtonColor = false, Text = "", ZIndex = 41, LayoutOrder = i, Parent = mdList })
            make("UICorner", { CornerRadius = sz(8), Parent = it })
            make("TextLabel", { Size = UDim2.new(1,-s(16),1,0), Position = UDim2.new(0,s(10),0,0), BackgroundTransparency = 1, Text = m.Name or ("Method "..i), TextColor3 = thm.SubText, TextSize = fs(11), Font = Enum.Font.Gotham, TextXAlignment = Enum.TextXAlignment.Left, ZIndex = 42, Parent = it })
            it.MouseEnter:Connect(function() if _isMobile then return end tw(it, { BackgroundTransparency = 0.5 }, 0.1) end)
            it.MouseLeave:Connect(function() if _isMobile then return end tw(it, { BackgroundTransparency = 1 }, 0.1) end)
            it.MouseButton1Click:Connect(function()
                selectedLink = m.Link or m.Url or ""
                mdLbl.Text = "Get key via: "..(m.Name or ("Method "..i))
                mdOpen = false
                tw(mdList, { Size = UDim2.new(1,0,0,0) }, 0.18)
                tw(mdArr, { Rotation = 0 }, 0.18)
            end)
        end
        mdField.MouseButton1Click:Connect(function()
            mdOpen = not mdOpen
            local h = mdOpen and (#_methods*s(30)+s(8)) or 0
            tw(mdList, { Size = UDim2.new(1,0,0,h) }, 0.2)
            tw(mdArr, { Rotation = mdOpen and 180 or 0 }, 0.2)
        end)
    end
    self.Gui = keyGui
    self.Frame = mainFrame
    self.Input = textBox
    self.StatusLabel = statusLbl
    function self:SetStatus(text, color)
        setStatus(text, color)
    end
    function self:Focus()
        pcall(function() textBox:CaptureFocus() end)
    end
    function self:Verify()
        doVerify()
    end
    function self:Close()
        if not keyGui.Parent then return end
        tw(mainFrame, { Size = UDim2.fromOffset(0,0), BackgroundTransparency = 1 }, 0.25)
        task.delay(0.26, function()
            pcall(function() keyGui:Destroy() end)
            if self.OnExit then pcall(self.OnExit) end
        end)
    end
    function self:Destroy()
        pcall(function() keyGui:Destroy() end)
    end
    return self
end
function KeySystem.GetHWID()
    local id = "UNKNOWN"
    pcall(function()
        if gethwid then id = tostring(gethwid())
        else id = tostring(game:GetService("RbxAnalyticsService"):GetClientId()) end
    end)
    return id
end
Aurora.KeySystem = KeySystem
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
function Aurora:CreateThemeEditor()
    if _G.AuroraThemeCustomizerGui then
        _G.AuroraThemeCustomizerGui.Enabled = not _G.AuroraThemeCustomizerGui.Enabled
        return
    end
    local thm = self.Theme or self.Themes.Dark
    local keyGui = make("ScreenGui", { Name = "AuroraThemeEditor", ResetOnSpawn = false, DisplayOrder = 99996 })
    safeParent(keyGui)
    _G.AuroraThemeCustomizerGui = keyGui
    local mainFrame = make("Frame", {
        Size = UDim2.fromOffset(s(340), s(450)),
        Position = UDim2.new(0.5, -s(170), 0.5, -s(225)),
        BackgroundColor3 = thm.Background,
        BackgroundTransparency = 0.05,
        Parent = keyGui
    })
    createAcrylic(mainFrame)
    make("UICorner", { CornerRadius = sz(16), Parent = mainFrame })
    local mainStroke = make("UIStroke", { Color = thm.Border, Thickness = 1, Parent = mainFrame })
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
        _G.AuroraThemeCustomizerGui = nil
    end)
    local titleLbl = make("TextLabel", {
        Size = UDim2.new(1, -s(40), 0, s(32)),
        Position = UDim2.new(0, s(16), 0, s(8)),
        BackgroundTransparency = 1,
        Text = "Theme Customizer",
        TextColor3 = thm.Text,
        TextSize = fs(15),
        Font = Enum.Font.GothamBold,
        TextXAlignment = Enum.TextXAlignment.Left,
        Parent = mainFrame
    })
    local closeBtn = make("TextButton", {
        Size = ss(16, 16),
        Position = UDim2.new(1, -s(26), 0, s(16)),
        BackgroundTransparency = 1,
        Text = "",
        Parent = mainFrame
    })
    local closeIco = make("ImageLabel", {
        Size = ss(10, 10),
        AnchorPoint = Vector2.new(0.5, 0.5),
        Position = UDim2.fromScale(0.5, 0.5),
        BackgroundTransparency = 1,
        Parent = closeBtn
    })
    applyIcon(closeIco, "solar/close-linear", thm.SubText)
    closeBtn.MouseButton1Click:Connect(function() keyGui:Destroy() end)
    make("Frame", {
        Size = UDim2.new(1, -s(32), 0, 1),
        Position = UDim2.new(0, s(16), 0, s(44)),
        BackgroundColor3 = thm.Border,
        BorderSizePixel = 0,
        Parent = mainFrame
    })
    local scroll = make("ScrollingFrame", {
        Size = UDim2.new(1, -s(32), 1, -s(104)),
        Position = UDim2.new(0, s(16), 0, s(48)),
        BackgroundTransparency = 1,
        ScrollBarThickness = s(3),
        ScrollBarImageColor3 = thm.Scrollbar,
        CanvasSize = UDim2.new(0, 0, 0, 0),
        Parent = mainFrame
    })
    local listLayout = make("UIListLayout", { SortOrder = Enum.SortOrder.LayoutOrder, Padding = sz(8), Parent = scroll })
    listLayout.Changed:Connect(function()
        scroll.CanvasSize = UDim2.new(0, 0, 0, listLayout.AbsoluteContentSize.Y + s(10))
    end)
    local colorKeys = {
        { Key = "Accent", Title = "Accent Color" },
        { Key = "Background", Title = "Background Color" },
        { Key = "Sidebar", Title = "Sidebar Color" },
        { Key = "TopBar", Title = "Topbar Color" },
        { Key = "Element", Title = "Element Base" },
        { Key = "ElementHover", Title = "Element Hover" },
        { Key = "Text", Title = "Text Main" },
        { Key = "SubText", Title = "Text Secondary" },
        { Key = "Border", Title = "Border Color" },
        { Key = "ToggleOn", Title = "Toggle Switch On" },
        { Key = "SliderFill", Title = "Slider Active Fill" },
        { Key = "InputBG", Title = "Input Background" }
    }
    for _, item in ipairs(colorKeys) do
        local key = item.Key
        local row = make("Frame", {
            Size = UDim2.new(1, 0, 0, s(34)),
            AutomaticSize = Enum.AutomaticSize.Y,
            BackgroundColor3 = thm.Element,
            BackgroundTransparency = 0.5,
            Parent = scroll
        })
        make("UICorner", { CornerRadius = sz(8), Parent = row })
        make("UIPadding", { PaddingTop = sz(6), PaddingBottom = sz(6), PaddingLeft = sz(10), PaddingRight = sz(10), Parent = row })
        local headerRow = make("Frame", {
            Size = UDim2.new(1, 0, 0, s(22)),
            BackgroundTransparency = 1,
            Parent = row
        })
        make("TextLabel", {
            Size = UDim2.new(0.6, 0, 1, 0),
            BackgroundTransparency = 1,
            Text = item.Title,
            TextColor3 = thm.Text,
            TextSize = fs(12),
            Font = Enum.Font.GothamMedium,
            TextXAlignment = Enum.TextXAlignment.Left,
            Parent = headerRow
        })
        local colDisp = make("Frame", {
            Size = ss(30, 16),
            AnchorPoint = Vector2.new(1, 0.5),
            Position = UDim2.new(1, 0, 0.5, 0),
            BackgroundColor3 = self.Theme[key],
            Parent = headerRow
        })
        make("UICorner", { CornerRadius = sz(4), Parent = colDisp })
        local stroke = make("UIStroke", { Color = thm.Border, Thickness = 1, Parent = colDisp })
        local trigger = make("TextButton", {
            Size = UDim2.fromScale(1, 1),
            BackgroundTransparency = 1,
            Text = "",
            Parent = colDisp
        })
        local cpObj = { Value = self.Theme[key] }
        local cpCfg = {
            Callback = function(newColor)
                self.Theme[key] = newColor
                self:UpdateTheme()
            end
        }
        local cpPanel = createColorpickerPanel(row, cpObj, cpCfg, colDisp)
        local cpExpanded = false
        trigger.MouseButton1Click:Connect(function()
            cpExpanded = not cpExpanded
            tw(cpPanel, { Size = UDim2.new(1, 0, 0, cpExpanded and s(148) or 0) }, 0.22)
        end)
    end
    local exportBtn = make("TextButton", {
        Size = UDim2.new(1, -s(32), 0, s(36)),
        Position = UDim2.new(0, s(16), 1, -s(48)),
        BackgroundColor3 = thm.Accent,
        Text = "Copy Theme Table to Clipboard",
        TextColor3 = thm.Text,
        TextSize = fs(12),
        Font = Enum.Font.GothamBold,
        Parent = mainFrame
    })
    make("UICorner", { CornerRadius = sz(10), Parent = exportBtn })
    exportBtn.MouseButton1Click:Connect(function()
        local str = "{\n"
        for _, item in ipairs(colorKeys) do
            local key = item.Key
            local val = self.Theme[key]
            str = str .. string.format("    %-12s = Color3.fromRGB(%d, %d, %d),\n", key, math.round(val.R*255), math.round(val.G*255), math.round(val.B*255))
        end
        str = str .. "}"
        pcall(function() toclipboard(str) end)
        self:Notify({
            Title = "Theme Editor",
            Content = "Custom theme table copied to clipboard!",
            Duration = 3
        })
    end)
    exportBtn.MouseEnter:Connect(function() if _isMobile then return end tw(exportBtn, { BackgroundColor3 = thm.AccentDim or Color3.fromRGB(15, 60, 30) }, 0.15) end)
    exportBtn.MouseLeave:Connect(function() if _isMobile then return end tw(exportBtn, { BackgroundColor3 = thm.Accent }, 0.15) end)
end
function Aurora:CreatePerformanceOverlay()
    if _G.AuroraPerformanceOverlayGui then
        _G.AuroraPerformanceOverlayGui.Enabled = not _G.AuroraPerformanceOverlayGui.Enabled
        return
    end
    local thm = self.Theme or self.Themes.Dark
    local overlayGui = make("ScreenGui", { Name = "AuroraPerformanceOverlay", ResetOnSpawn = false, DisplayOrder = 99997 })
    safeParent(overlayGui)
    _G.AuroraPerformanceOverlayGui = overlayGui
    local frame = make("Frame", {
        Size = UDim2.fromOffset(s(160), s(70)),
        Position = UDim2.new(1, -s(180), 0, s(20)),
        BackgroundColor3 = Color3.fromRGB(10, 10, 15),
        BackgroundTransparency = 0.25,
        Parent = overlayGui
    })
    createAcrylic(frame)
    make("UICorner", { CornerRadius = sz(10), Parent = frame })
    local stroke = make("UIStroke", { Color = thm.Border, Thickness = 1, Parent = frame })
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
    local fpsLbl = make("TextLabel", {
        Size = UDim2.new(0.5, -s(8), 0, s(16)),
        Position = UDim2.new(0, s(8), 0, s(6)),
        BackgroundTransparency = 1,
        Text = "FPS: --",
        TextColor3 = thm.Text,
        TextSize = fs(10),
        Font = Enum.Font.GothamBold,
        TextXAlignment = Enum.TextXAlignment.Left,
        Parent = frame
    })
    local pingLbl = make("TextLabel", {
        Size = UDim2.new(0.5, -s(8), 0, s(16)),
        Position = UDim2.new(0.5, 0, 0, s(6)),
        BackgroundTransparency = 1,
        Text = "Ping: --ms",
        TextColor3 = thm.SubText,
        TextSize = fs(10),
        Font = Enum.Font.GothamBold,
        TextXAlignment = Enum.TextXAlignment.Right,
        Parent = frame
    })
    local graphFrame = make("Frame", {
        Size = UDim2.new(1, -s(16), 0, s(32)),
        Position = UDim2.new(0, s(8), 0, s(28)),
        BackgroundTransparency = 1,
        Parent = frame
    })
    local bars = {}
    local maxBarHeight = s(30)
    for i = 1, 25 do
        local bar = make("Frame", {
            Size = UDim2.new(0, s(3), 0, s(2)),
            Position = UDim2.new((i - 1)/25, 0, 1, 0),
            AnchorPoint = Vector2.new(0, 1),
            BackgroundColor3 = Color3.fromRGB(38, 195, 95),
            BorderSizePixel = 0,
            Parent = graphFrame
        })
        make("UICorner", { CornerRadius = sz(1), Parent = bar })
        bars[i] = bar
    end
    local dtBuffer = {}
    local history = {}
    for i = 1, 25 do history[i] = 60 end
    local renderConn = game:GetService("RunService").RenderStepped:Connect(function(dt)
        table.insert(dtBuffer, dt)
        if #dtBuffer > 60 then
            table.remove(dtBuffer, 1)
        end
    end)
    local stats = game:GetService("Stats")
    local updateLoop = task.spawn(function()
        while overlayGui and overlayGui.Parent do
            local sum = 0
            for _, v in ipairs(dtBuffer) do sum = sum + v end
            local currentFps = #dtBuffer > 0 and math.round(#dtBuffer / sum) or 60
            local currentPing = 0
            pcall(function()
                currentPing = math.round(stats.Network.ServerToClientPing * 1000)
            end)
            fpsLbl.Text = string.format("FPS: %d", currentFps)
            pingLbl.Text = string.format("Ping: %dms", currentPing)
            table.remove(history, 1)
            table.insert(history, currentFps)
            for i = 1, 25 do
                local val = history[i]
                local pct = math.clamp(val / 60, 0, 1)
                local barHeight = math.clamp(pct * maxBarHeight, s(2), maxBarHeight)
                local barColor = Color3.fromRGB(38, 195, 95)
                if val < 30 then
                    barColor = Color3.fromRGB(220, 55, 55)
                elseif val < 50 then
                    barColor = Color3.fromRGB(225, 155, 35)
                end
                bars[i].Size = UDim2.new(0, s(3), 0, barHeight)
                bars[i].BackgroundColor3 = barColor
            end
            task.wait(0.1)
        end
    end)
    overlayGui.Destroying:Connect(function()
        pcall(function() changedConn:Disconnect() end)
        pcall(function() renderConn:Disconnect() end)
        pcall(task.cancel, updateLoop)
        _G.AuroraPerformanceOverlayGui = nil
    end)
end
SaveManager:BuildFolderTree()
Aurora.SaveManager = SaveManager
-- ============================================================
--  Auto executor warning (viene por default en la libreria)
-- ============================================================
task.spawn(function()
    if _G.__AuroraExecWarned then return end
    local execName = ""
    pcall(function()
        if identifyexecutor then execName = tostring((identifyexecutor()))
        elseif getexecutorname then execName = tostring((getexecutorname())) end
    end)
    local low = string.lower(execName or "")
    local kind
    if low:find("solara") then kind = "solara"
    elseif low:find("xeno") then kind = "xeno" end
    if not kind then return end
    _G.__AuroraExecWarned = true
    task.wait(0.2)

    local isSolara = (kind == "solara")
    local ACCENT   = isSolara and Color3.fromRGB(235, 92, 92) or Color3.fromRGB(240, 185, 70)
    local titleTxt = isSolara and "Unsupported Executor" or "Performance Warning"
    local bodyTxt  = isSolara
        and "Solara is not officially supported. We can't guarantee features will work, and we're unable to help if something breaks."
        or "Some features may misbehave or lag on Xeno. For the best experience use a supported executor - or continue anyway."
    local iconId   = isSolara and "solar/shield-cross-bold" or "solar/danger-triangle-bold"

    local gui = make("ScreenGui", { Name = "AuroraExecWarn", ResetOnSpawn = false, IgnoreGuiInset = true, DisplayOrder = 200000 })
    safeParent(gui)
    local dim = make("Frame", { Size = UDim2.fromScale(1,1), BackgroundColor3 = Color3.fromRGB(0,0,0), BackgroundTransparency = 1, BorderSizePixel = 0, Parent = gui })

    local card = make("Frame", {
        AnchorPoint = Vector2.new(0.5,0.5), Position = UDim2.fromScale(0.5,0.5),
        Size = ss(370, 224), BackgroundColor3 = Color3.fromRGB(19,19,25), BackgroundTransparency = 1, BorderSizePixel = 0, Parent = gui,
    })
    make("UICorner", { CornerRadius = sz(16), Parent = card })
    local cardStroke = make("UIStroke", { Color = ACCENT, Thickness = 1, Transparency = 1, Parent = card })
    local cardScale = make("UIScale", { Scale = 0.82, Parent = card })
    local topLine = make("Frame", { Size = UDim2.new(1,-s(40),0,s(2)), Position = UDim2.new(0.5,0,0,s(0)), AnchorPoint = Vector2.new(0.5,0), BackgroundColor3 = ACCENT, BackgroundTransparency = 1, BorderSizePixel = 0, Parent = card })
    make("UICorner", { CornerRadius = UDim.new(1,0), Parent = topLine })
    make("UIGradient", { Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0,1), NumberSequenceKeypoint.new(0.5,0), NumberSequenceKeypoint.new(1,1) }), Parent = topLine })

    local iconBadge = make("Frame", { Size = ss(50,50), AnchorPoint = Vector2.new(0.5,0), Position = UDim2.new(0.5,0,0,s(22)), BackgroundColor3 = ACCENT, BackgroundTransparency = 1, BorderSizePixel = 0, Parent = card })
    make("UICorner", { CornerRadius = sz(15), Parent = iconBadge })
    local iconBadgeStroke = make("UIStroke", { Color = ACCENT, Thickness = 1, Transparency = 1, Parent = iconBadge })
    local ico = make("ImageLabel", { Size = ss(28,28), AnchorPoint = Vector2.new(0.5,0.5), Position = UDim2.fromScale(0.5,0.5), BackgroundTransparency = 1, ImageTransparency = 1, Parent = iconBadge })
    applyIcon(ico, iconId, ACCENT)

    local titleLbl = make("TextLabel", { Size = UDim2.new(1,-s(40),0,s(22)), Position = UDim2.new(0,s(20),0,s(82)), BackgroundTransparency = 1, Text = titleTxt, TextColor3 = Color3.fromRGB(255,255,255), TextTransparency = 1, TextSize = fs(19), Font = Enum.Font.GothamBold, TextXAlignment = Enum.TextXAlignment.Center, Parent = card })
    local pill = make("Frame", { AnchorPoint = Vector2.new(0.5,0), Position = UDim2.new(0.5,0,0,s(105)), Size = UDim2.new(0,0,0,s(18)), AutomaticSize = Enum.AutomaticSize.X, BackgroundColor3 = ACCENT, BackgroundTransparency = 1, BorderSizePixel = 0, Parent = card })
    make("UICorner", { CornerRadius = UDim.new(1,0), Parent = pill })
    local pillStroke = make("UIStroke", { Color = ACCENT, Thickness = 1, Transparency = 1, Parent = pill })
    make("UIPadding", { PaddingLeft = UDim.new(0,s(9)), PaddingRight = UDim.new(0,s(9)), Parent = pill })
    local subLbl = make("TextLabel", { AutomaticSize = Enum.AutomaticSize.X, Size = UDim2.new(0,0,1,0), BackgroundTransparency = 1, Text = string.upper(execName), TextColor3 = ACCENT, TextTransparency = 1, TextSize = fs(10), Font = Enum.Font.GothamBold, Parent = pill })
    local bodyLbl = make("TextLabel", { Size = UDim2.new(1,-s(48),0,s(40)), Position = UDim2.new(0,s(24),0,s(124)), BackgroundTransparency = 1, Text = bodyTxt, TextColor3 = Color3.fromRGB(178,178,190), TextTransparency = 1, TextSize = fs(12), Font = Enum.Font.Gotham, TextWrapped = true, TextXAlignment = Enum.TextXAlignment.Center, Parent = card })

    local function closeIt()
        tw(dim, { BackgroundTransparency = 1 }, 0.25)
        tw(cardScale, { Scale = 0.85 }, 0.25)
        tw(card, { BackgroundTransparency = 1 }, 0.25)
        tw(cardStroke, { Transparency = 1 }, 0.2)
        task.delay(0.28, function() pcall(function() gui:Destroy() end) end)
    end
    local function makeBtn(text, primary, xpos, w, onClick)
        local b = make("TextButton", {
            Size = UDim2.new(0, w, 0, s(36)), Position = UDim2.new(0, xpos, 0, s(174)),
            BackgroundColor3 = primary and ACCENT or Color3.fromRGB(38,38,46),
            BackgroundTransparency = primary and 0 or 0.15,
            Text = text, TextColor3 = primary and Color3.fromRGB(22,22,28) or Color3.fromRGB(220,220,228),
            TextSize = fs(13), Font = Enum.Font.GothamBold, AutoButtonColor = false, Parent = card,
        })
        make("UICorner", { CornerRadius = sz(10), Parent = b })
        local bs
        if not primary then bs = make("UIStroke", { Color = Color3.fromRGB(75,75,85), Thickness = 1, Transparency = 0.3, Parent = b }) end
        local base = primary and ACCENT or Color3.fromRGB(38,38,46)
        b.MouseEnter:Connect(function() if _isMobile then return end tw(b, { BackgroundColor3 = primary and base:Lerp(Color3.new(1,1,1),0.12) or Color3.fromRGB(52,52,62) }, 0.1) end)
        b.MouseLeave:Connect(function() if _isMobile then return end tw(b, { BackgroundColor3 = base }, 0.1) end)
        b.MouseButton1Click:Connect(onClick)
        return b
    end

    local pad, gap = s(20), s(8)
    local full = ss(370,224).X.Offset - pad*2
    if isSolara then
        makeBtn("Close", true, pad, full, closeIt)
    else
        local w = (full - gap) / 2
        makeBtn("Close", false, pad, w, closeIt)
        makeBtn("Continue", true, pad + w + gap, w, closeIt)
    end

    tw(dim, { BackgroundTransparency = 0.5 }, 0.3)
    tw(card, { BackgroundTransparency = 0 }, 0.3)
    tw(cardStroke, { Transparency = 0.45 }, 0.3)
    tw(cardScale, { Scale = 1 }, 0.45, Enum.EasingStyle.Back, Enum.EasingDirection.Out)
    tw(topLine, { BackgroundTransparency = 0 }, 0.4)
    tw(iconBadge, { BackgroundTransparency = 0.82 }, 0.4)
    tw(iconBadgeStroke, { Transparency = 0.4 }, 0.4)
    tw(ico, { ImageTransparency = 0 }, 0.4)
    tw(titleLbl, { TextTransparency = 0 }, 0.4)
    tw(pill, { BackgroundTransparency = 0.85 }, 0.4)
    tw(pillStroke, { Transparency = 0.4 }, 0.4)
    tw(subLbl, { TextTransparency = 0 }, 0.4)
    tw(bodyLbl, { TextTransparency = 0 }, 0.4)
end)
-- ═══════════════════════════════════════════════════════════
-- CONFIRMATION DIALOG
-- ═══════════════════════════════════════════════════════════
function Aurora:Confirm(cfg)
    cfg = cfg or {}
    local thm = self.Theme or self.Themes.Dark
    local gui = make("ScreenGui", { Name = "AuroraConfirm", ResetOnSpawn = false, DisplayOrder = 100001 })
    safeParent(gui)
    local dim = make("Frame", {
        Size = UDim2.fromScale(1, 1), BackgroundColor3 = Color3.new(0, 0, 0),
        BackgroundTransparency = 1, BorderSizePixel = 0, Parent = gui,
    })
    tw(dim, { BackgroundTransparency = 0.55 }, 0.25)
    local card = make("Frame", {
        Size = ss(340, 180), AnchorPoint = Vector2.new(0.5, 0.5),
        Position = UDim2.fromScale(0.5, 0.5), BackgroundColor3 = thm.Background,
        BorderSizePixel = 0, ClipsDescendants = true, Parent = gui,
    })
    make("UICorner", { CornerRadius = sz(16), Parent = card })
    make("UIStroke", { Color = thm.Border, Thickness = 1, Transparency = 0.3, Parent = card })
    if self.Acrylic then createAcrylic(card) end
    local cardScale = make("UIScale", { Scale = 0.85, Parent = card })
    tw(cardScale, { Scale = 1 }, 0.3, Enum.EasingStyle.Back, Enum.EasingDirection.Out)
    local iconLbl = make("ImageLabel", {
        Size = ss(28, 28), Position = UDim2.new(0, s(20), 0, s(18)),
        BackgroundTransparency = 1, Parent = card,
    })
    local iconMap = { Warning = "solar/danger-bold", Error = "solar/close-circle-bold", Info = "solar/info-circle-bold", Success = "solar/check-circle-bold" }
    local colorMap = { Warning = thm.AlertWarn, Error = thm.AlertError, Info = thm.AlertInfo, Success = thm.AlertSuccess }
    local typ = cfg.Type or "Warning"
    applyIcon(iconLbl, iconMap[typ] or cfg.Icon or iconMap.Warning, colorMap[typ] or thm.Accent)
    make("TextLabel", {
        Size = UDim2.new(1, -s(60), 0, s(24)), Position = UDim2.new(0, s(56), 0, s(18)),
        BackgroundTransparency = 1, Text = cfg.Title or "Confirm", TextColor3 = thm.Text,
        TextSize = fs(16), Font = Enum.Font.GothamBold, TextXAlignment = Enum.TextXAlignment.Left, Parent = card,
    })
    make("TextLabel", {
        Size = UDim2.new(1, -s(40), 0, s(50)), Position = UDim2.new(0, s(20), 0, s(52)),
        BackgroundTransparency = 1, Text = cfg.Content or "Are you sure?", TextColor3 = thm.SubText,
        TextSize = fs(12), Font = Enum.Font.Gotham, TextWrapped = true, TextXAlignment = Enum.TextXAlignment.Left,
        TextYAlignment = Enum.TextYAlignment.Top, Parent = card,
    })
    local result
    local function closeDialog(val)
        if result ~= nil then return end
        result = val
        tw(dim, { BackgroundTransparency = 1 }, 0.2)
        tw(cardScale, { Scale = 0.85 }, 0.2)
        tw(card, { BackgroundTransparency = 1 }, 0.2)
        task.delay(0.25, function() pcall(function() gui:Destroy() end) end)
        if cfg.Callback then pcall(cfg.Callback, val) end
    end
    local btnW = s(130)
    local gap = s(10)
    local startX = (s(340) - btnW * 2 - gap) / 2
    for i, btnCfg in ipairs({
        { Text = cfg.CancelText or "Cancel", Primary = false, Value = false },
        { Text = cfg.ConfirmText or "Confirm", Primary = true, Value = true },
    }) do
        local bx = startX + (i - 1) * (btnW + gap)
        local b = make("TextButton", {
            Size = UDim2.fromOffset(btnW, s(34)), Position = UDim2.new(0, bx, 1, -s(52)),
            BackgroundColor3 = btnCfg.Primary and thm.Accent or thm.Element,
            BackgroundTransparency = btnCfg.Primary and 0 or 0.15,
            Text = btnCfg.Text, TextColor3 = btnCfg.Primary and Color3.fromRGB(15, 15, 20) or thm.Text,
            TextSize = fs(13), Font = Enum.Font.GothamBold, AutoButtonColor = false, Parent = card,
        })
        make("UICorner", { CornerRadius = sz(10), Parent = b })
        if not btnCfg.Primary then make("UIStroke", { Color = thm.Border, Thickness = 1, Transparency = 0.3, Parent = b }) end
        local base = b.BackgroundColor3
        b.MouseEnter:Connect(function() if _isMobile then return end tw(b, { BackgroundColor3 = base:Lerp(Color3.new(1, 1, 1), 0.12) }, 0.1) end)
        b.MouseLeave:Connect(function() if _isMobile then return end tw(b, { BackgroundColor3 = base }, 0.1) end)
        b.MouseButton1Click:Connect(function() closeDialog(btnCfg.Value) end)
    end
    dim.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
            closeDialog(false)
        end
    end)
    return gui
end

-- ═══════════════════════════════════════════════════════════
-- LOADING OVERLAY
-- ═══════════════════════════════════════════════════════════
function Aurora:ShowLoading(cfg)
    cfg = cfg or {}
    local thm = self.Theme or self.Themes.Dark
    local gui = make("ScreenGui", { Name = "AuroraLoading", ResetOnSpawn = false, DisplayOrder = 100002 })
    safeParent(gui)
    local dim = make("Frame", {
        Size = UDim2.fromScale(1, 1), BackgroundColor3 = Color3.new(0, 0, 0),
        BackgroundTransparency = 1, BorderSizePixel = 0, Parent = gui,
    })
    tw(dim, { BackgroundTransparency = 0.6 }, 0.25)
    local card = make("Frame", {
        Size = ss(220, 120), AnchorPoint = Vector2.new(0.5, 0.5),
        Position = UDim2.fromScale(0.5, 0.5), BackgroundColor3 = thm.Background,
        BorderSizePixel = 0, Parent = gui,
    })
    make("UICorner", { CornerRadius = sz(16), Parent = card })
    make("UIStroke", { Color = thm.Border, Thickness = 1, Transparency = 0.3, Parent = card })
    if self.Acrylic then createAcrylic(card) end
    local cardScale = make("UIScale", { Scale = 0.85, Parent = card })
    tw(cardScale, { Scale = 1 }, 0.3, Enum.EasingStyle.Back, Enum.EasingDirection.Out)
    local spinner = make("Frame", {
        Size = ss(28, 28), AnchorPoint = Vector2.new(0.5, 0),
        Position = UDim2.new(0.5, 0, 0, s(22)),
        BackgroundTransparency = 1, Parent = card,
    })
    local spinnerArc = make("ImageLabel", {
        Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, Parent = spinner,
    })
    applyIcon(spinnerArc, "solar/refresh-bold", thm.Accent)
    local spinActive = true
    task.spawn(function()
        while spinActive and spinner and spinner.Parent do
            spinner.Rotation = spinner.Rotation + 6
            task.wait(0.016)
        end
    end)
    local msgLbl = make("TextLabel", {
        Size = UDim2.new(1, -s(20), 0, s(30)), AnchorPoint = Vector2.new(0.5, 0),
        Position = UDim2.new(0.5, 0, 0, s(60)),
        BackgroundTransparency = 1, Text = cfg.Text or "Loading...", TextColor3 = thm.SubText,
        TextSize = fs(13), Font = Enum.Font.GothamBold, TextWrapped = true, Parent = card,
    })
    local obj = {}
    function obj:SetText(t) if msgLbl and msgLbl.Parent then msgLbl.Text = t end end
    function obj:Close()
        spinActive = false
        tw(dim, { BackgroundTransparency = 1 }, 0.2)
        tw(cardScale, { Scale = 0.85 }, 0.2)
        tw(card, { BackgroundTransparency = 1 }, 0.2)
        task.delay(0.25, function() pcall(function() gui:Destroy() end) end)
    end
    if cfg.Duration and cfg.Duration > 0 then
        task.delay(cfg.Duration, function() obj:Close() end)
    end
    return obj
end

-- ═══════════════════════════════════════════════════════════
-- CONTEXT MENU (right-click menu)
-- ═══════════════════════════════════════════════════════════
function Aurora:ContextMenu(cfg)
    cfg = cfg or {}
    local thm = self.Theme or self.Themes.Dark
    local items = cfg.Items or {}
    local gui = make("ScreenGui", { Name = "AuroraCtxMenu", ResetOnSpawn = false, DisplayOrder = 100003 })
    safeParent(gui)
    local dismiss = make("TextButton", {
        Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, Text = "", Parent = gui,
    })
    local menu = make("Frame", {
        Size = UDim2.fromOffset(s(180), 0), AutomaticSize = Enum.AutomaticSize.Y,
        Position = UDim2.fromOffset(cfg.X or 0, cfg.Y or 0),
        BackgroundColor3 = thm.Background, BackgroundTransparency = 0.05,
        BorderSizePixel = 0, ClipsDescendants = true, ZIndex = 100, Parent = gui,
    })
    make("UICorner", { CornerRadius = sz(10), Parent = menu })
    make("UIStroke", { Color = thm.Border, Thickness = 1, Transparency = 0.3, Parent = menu })
    make("UIPadding", { PaddingTop = sz(4), PaddingBottom = sz(4), PaddingLeft = sz(4), PaddingRight = sz(4), Parent = menu })
    make("UIListLayout", { SortOrder = Enum.SortOrder.LayoutOrder, Padding = sz(2), Parent = menu })
    local menuScale = make("UIScale", { Scale = 0.9, Parent = menu })
    tw(menuScale, { Scale = 1 }, 0.15, Enum.EasingStyle.Back, Enum.EasingDirection.Out)
    local function closeMenu()
        tw(menuScale, { Scale = 0.9 }, 0.1)
        tw(menu, { BackgroundTransparency = 1 }, 0.1)
        task.delay(0.12, function() pcall(function() gui:Destroy() end) end)
    end
    dismiss.MouseButton1Click:Connect(closeMenu)
    for i, item in ipairs(items) do
        if item.Separator then
            local sep = make("Frame", { Size = UDim2.new(1, 0, 0, 1), BackgroundColor3 = thm.Border, BackgroundTransparency = 0.5, BorderSizePixel = 0, LayoutOrder = i, Parent = menu })
        else
            local opt = make("TextButton", {
                Size = UDim2.new(1, 0, 0, s(30)), BackgroundTransparency = 1,
                Text = "", AutoButtonColor = false, LayoutOrder = i, Parent = menu,
            })
            make("UICorner", { CornerRadius = sz(7), Parent = opt })
            local optIco
            if item.Icon then
                optIco = make("ImageLabel", { Size = ss(14, 14), Position = UDim2.new(0, s(6), 0.5, -s(7)), BackgroundTransparency = 1, Parent = opt })
                applyIcon(optIco, item.Icon, thm.SubText)
            end
            local tx = item.Icon and s(26) or s(8)
            make("TextLabel", {
                Size = UDim2.new(1, -tx - s(8), 1, 0), Position = UDim2.new(0, tx, 0, 0),
                BackgroundTransparency = 1, Text = item.Title or item.Text or "", TextColor3 = item.Danger and thm.AlertError or thm.Text,
                TextSize = fs(12), Font = Enum.Font.Gotham, TextXAlignment = Enum.TextXAlignment.Left, Parent = opt,
            })
            opt.MouseEnter:Connect(function() if _isMobile then return end tw(opt, { BackgroundColor3 = thm.ElementHover, BackgroundTransparency = 0.3 }, 0.08) end)
            opt.MouseLeave:Connect(function() if _isMobile then return end tw(opt, { BackgroundTransparency = 1 }, 0.08) end)
            opt.MouseButton1Click:Connect(function()
                closeMenu()
                if item.Callback then pcall(item.Callback) end
            end)
        end
    end
    return { Close = closeMenu, Gui = gui }
end

-- ═══════════════════════════════════════════════════════════
-- EXPORT / IMPORT CONFIG (clipboard string)
-- ═══════════════════════════════════════════════════════════
function Aurora:ExportConfig()
    local data = {}
    for id, opt in pairs(self.Options) do
        if opt and opt.Value ~= nil then
            local t = type(opt.Value)
            if t == "boolean" or t == "number" or t == "string" then
                data[id] = opt.Value
            elseif t == "table" then
                data[id] = opt.Value
            end
        end
    end
    local ok, encoded = pcall(function()
        return game:GetService("HttpService"):JSONEncode(data)
    end)
    if ok and encoded then
        pcall(function()
            if setclipboard then setclipboard(encoded) end
        end)
        self:Notify({ Title = "Config Exported", Content = "Copied to clipboard!", Type = "Success", Duration = 3 })
        return encoded
    end
    self:Notify({ Title = "Export Failed", Content = "Could not encode config", Type = "Error", Duration = 3 })
    return nil
end

function Aurora:ImportConfig(jsonStr)
    if not jsonStr or jsonStr == "" then
        pcall(function()
            if getclipboard then jsonStr = getclipboard() end
        end)
    end
    if not jsonStr or jsonStr == "" then
        self:Notify({ Title = "Import Failed", Content = "No data to import", Type = "Error", Duration = 3 })
        return false
    end
    local ok, data = pcall(function()
        return game:GetService("HttpService"):JSONDecode(jsonStr)
    end)
    if not ok or type(data) ~= "table" then
        self:Notify({ Title = "Import Failed", Content = "Invalid config data", Type = "Error", Duration = 3 })
        return false
    end
    local count = 0
    for id, val in pairs(data) do
        local opt = self.Options[id]
        if opt then
            pcall(function()
                if opt.Type == "Toggle" and type(val) == "boolean" then
                    opt:SetValue(val)
                    count = count + 1
                elseif opt.Type == "Slider" and type(val) == "number" then
                    opt:SetValue(val)
                    count = count + 1
                elseif opt.Type == "Dropdown" then
                    opt:SetValue(val)
                    count = count + 1
                elseif opt.Type == "Input" and type(val) == "string" then
                    opt:SetValue(val)
                    count = count + 1
                elseif opt.Type == "ColorPicker" then
                    opt:SetValue(val)
                    count = count + 1
                end
            end)
        end
    end
    self:Notify({ Title = "Config Imported", Content = count .. " settings loaded", Type = "Success", Duration = 3 })
    return true, count
end

-- ═══════════════════════════════════════════════════════════
-- PREMIUM BADGE PULSE ANIMATION
-- ═══════════════════════════════════════════════════════════
function Aurora:StartPremiumPulse()
    if self._premiumPulseActive then return end
    self._premiumPulseActive = true
    task.spawn(function()
        while self._premiumPulseActive do
            for _, el in ipairs(self._premiumElements or {}) do
                if el and el.overlay and el.overlay.Parent then
                    local glow = el.overlay:FindFirstChild("PremiumGlow")
                    if glow then
                        tw(glow, { BackgroundTransparency = 0.6 }, 0.8)
                        task.delay(0.85, function()
                            if glow and glow.Parent then
                                tw(glow, { BackgroundTransparency = 0.85 }, 0.8)
                            end
                        end)
                    end
                end
            end
            task.wait(1.8)
        end
    end)
end
function Aurora:StopPremiumPulse()
    self._premiumPulseActive = false
end

function Aurora:DestroyAll()
    self:StopPremiumPulse()
    self:CleanAllConnections()
    if _fpsTrackConn then pcall(function() _fpsTrackConn:Disconnect() end) end
    for _, f in ipairs(_notifPool) do pcall(function() f:Destroy() end) end
    table.clear(_notifPool)
    for id, opt in pairs(self.Options) do
        if type(opt) == "table" and type(opt.Destroy) == "function" then
            pcall(opt.Destroy, opt)
        end
    end
    table.clear(self.Options)
    table.clear(self.ThemeObjs)
    table.clear(self._themeObjsByKey)
    table.clear(self._globalElements)
    table.clear(self._globalElementsByTitle)
    for soundId, pool in pairs(self._soundPool) do
        for _, snd in ipairs(pool) do
            pcall(function() snd:Destroy() end)
        end
    end
    table.clear(self._soundPool)
    if _tooltipConn then
        pcall(function() _tooltipConn:Disconnect() end)
        _tooltipConn = nil
    end
    if _tooltipGui then
        pcall(function() _tooltipGui:Destroy() end)
        _tooltipGui = nil
        _tooltipFrame = nil
        _tooltipLbl = nil
        _tooltipStroke = nil
    end
    local dof = game:GetService("Lighting"):FindFirstChild("AuroraBlur")
    if dof then pcall(function() dof:Destroy() end) end
    for part in pairs(activeAcrylics) do
        pcall(function() part:Destroy() end)
    end
    table.clear(activeAcrylics)
end

-- ============================================================================
-- AUTO-TRANSLATION ENGINE
-- Detects user's Roblox locale and translates all UI text automatically.
-- Supports: es, pt-br, zh-cn, zh-tw, ja, ko, fr, de, ru, tr, vi, th, id
-- ============================================================================
do
    local LocalizationService = game:GetService("LocalizationService")

    local function detectLocale()
        if Aurora._userLocale then return Aurora._userLocale end
        local locale = "en"
        pcall(function()
            local raw = LocalizationService.RobloxLocaleId or LocalPlayer.LocaleId or "en-us"
            locale = string.lower(string.sub(raw, 1, 2))
        end)
        Aurora._userLocale = locale
        return locale
    end

    local _commonUI = {
        "Enable", "Disable", "Enabled", "Disabled", "Toggle", "Button", "Select", "Selected",
        "Default", "Settings", "Options", "Save", "Load", "Reset", "Close", "Open", "Cancel",
        "Confirm", "Delete", "Copy", "Refresh", "Search", "Show", "Hide", "Start", "Stop",
        "Pause", "Resume", "Apply", "Upgrade", "Purchase", "Buy", "Sell", "Equip", "Unequip",
        "Claim", "Redeem", "Teleport", "Premium", "Free", "Locked", "Unlocked",
    }
    local _commonGame = {
        "Auto", "Farm", "Fishing", "Fish", "Rod", "Bait", "Cast", "Catch",
        "Inventory", "Full", "Empty", "Boss", "Raid", "Fight", "Battle",
        "Quest", "Daily", "Reward", "Rewards", "Level", "Experience", "Cash", "Crystals",
        "Tickets", "Stars", "Coins", "Character", "Characters", "Gacha",
        "Trait", "Traits", "Orb", "Orbs", "Skill", "Skills",
        "Speed", "Power", "Damage", "Health", "Walk", "Jump", "Fly", "Sprint",
        "Noclip", "Godmode", "Fullbright",
        "Island", "Isle", "Zone", "Area", "Player", "Players", "Server",
        "Guild", "Boat", "Spawn", "Title", "Titles", "Skin", "Skins",
        "Craft", "Crafting", "Shop", "Exchange", "Tank", "Platform",
        "Weather", "Graphics", "Sound", "Music",
        "Notification", "Alert", "Warning",
        "Stats", "Status", "Info", "Summary",
        "Session", "Progress", "Complete", "Completed",
        "Active", "Inactive", "Ready", "Waiting", "Cooldown", "Duration", "Interval",
        "All", "None", "Once", "Loop", "Current", "Best", "Nearest",
        "Normal", "Hard", "Nightmare", "Owned", "Available", "Claimed",
        "Protection", "Protections", "Movement", "Visual", "Visuals", "ESP",
        "Reroll", "Lock", "Unlock", "Favorite", "Deposit",
        "Script", "Unload", "Clean", "Automation", "Engine", "Pipeline",
        "Rejoin", "Hop", "Remove", "Clear", "Add",
        "Weight", "Rarity", "Common", "Uncommon", "Rare", "Epic", "Legendary", "Mythic", "Mythical", "Secret",
        "Egg", "Eggs", "Pet", "Pets", "Hatch", "Hatching", "Rebirth", "Prestige", "Ascend",
        "Dungeon", "Tower", "Round", "Wave", "Floor", "Map", "World", "Potion", "Chest",
        "Click", "Clicks", "Tap", "Collect", "Harvest", "Mine", "Dig",
        "Merge", "Fuse", "Evolve", "Enchant", "Upgrade",
        "Attack", "Defense", "Armor", "Weapon", "Sword", "Shield",
        "Gold", "Gems", "Diamonds", "Energy", "Stamina", "Mana",
        "Team", "Party", "Ally", "Enemy", "Target", "Mob", "NPC",
        "Trade", "Market", "Auction", "Offer", "Price", "Cost", "Value",
        "Rank", "Score", "Leaderboard", "Trophy", "Badge", "Achievement",
    }
    local _commonPhrases = {
        "When Inventory Full", "Auto Fishing", "Auto Sell", "Auto Buy", "Auto Equip",
        "Auto Claim", "Auto Quest", "Auto Farm", "Auto Click", "Auto Collect",
        "Auto Hatch", "Auto Rebirth", "Auto Attack", "Auto Heal",
        "Get Free Key", "Buy Premium", "Buy with Robux",
        "requires a Premium key", "Not enough", "No Boss Tickets",
        "Inventory is full", "Sold all fish", "Equipped",
        "Arrived at", "Teleported to", "Fight started", "Quest complete",
        "On cooldown", "Data saved", "No active quests", "Already claimed",
        "Click Fight button", "Returned to NPC",
        "Fish Caught", "Caught", "Sold", "Stopped", "Started", "Accepted",
        "Working on", "Waiting", "Retrying",
        "remaining", "left", "free", "units", "studs", "seconds", "minutes", "stud/s", "power",
        "Walk Speed", "Jump Power", "Fly Speed",
        "Collect All", "Sell All", "Equip Best", "Hatch All",
        "Server Hop", "Rejoin Server", "Anti AFK",
        "No Clip", "Infinite Jump", "God Mode",
        "Hide / Show GUI", "Change Key", "Verify Key", "Get Key",
        "Key Verified", "Invalid Key", "Premium Key Verified",
        "Enter key here...", "Paste new key...",
        "Checking saved key...", "Verifying...", "Loading...",
        "Script Loaded", "Script Unloaded",
    }
    local dicts = {
        es = {
            ["Enable"] = "Activar", ["Disable"] = "Desactivar", ["Enabled"] = "Activado", ["Disabled"] = "Desactivado",
            ["Toggle"] = "Alternar", ["Button"] = "Botón", ["Select"] = "Seleccionar", ["Selected"] = "Seleccionado",
            ["Default"] = "Predeterminado", ["Settings"] = "Ajustes", ["Options"] = "Opciones",
            ["Save"] = "Guardar", ["Load"] = "Cargar", ["Reset"] = "Reiniciar", ["Close"] = "Cerrar",
            ["Open"] = "Abrir", ["Cancel"] = "Cancelar", ["Confirm"] = "Confirmar", ["Delete"] = "Eliminar",
            ["Copy"] = "Copiar", ["Refresh"] = "Actualizar", ["Search"] = "Buscar", ["Show"] = "Mostrar",
            ["Hide"] = "Ocultar", ["Start"] = "Iniciar", ["Stop"] = "Detener", ["Pause"] = "Pausar",
            ["Resume"] = "Reanudar", ["Apply"] = "Aplicar", ["Upgrade"] = "Mejorar", ["Purchase"] = "Comprar",
            ["Buy"] = "Comprar", ["Sell"] = "Vender", ["Equip"] = "Equipar", ["Unequip"] = "Desequipar",
            ["Claim"] = "Reclamar", ["Redeem"] = "Canjear", ["Teleport"] = "Teletransportar",
            ["Premium"] = "Premium", ["Free"] = "Gratis", ["Locked"] = "Bloqueado", ["Unlocked"] = "Desbloqueado",
            ["Auto"] = "Auto", ["Farm"] = "Farmeo", ["Fishing"] = "Pesca", ["Fish"] = "Pez",
            ["Rod"] = "Caña", ["Bait"] = "Carnada", ["Cast"] = "Lanzar", ["Catch"] = "Atrapar",
            ["Inventory"] = "Inventario", ["Full"] = "Lleno", ["Empty"] = "Vacío",
            ["Boss"] = "Jefe", ["Raid"] = "Raid", ["Fight"] = "Pelea", ["Battle"] = "Batalla",
            ["Quest"] = "Misión", ["Daily"] = "Diaria", ["Reward"] = "Recompensa", ["Rewards"] = "Recompensas",
            ["Level"] = "Nivel", ["Experience"] = "Experiencia", ["Cash"] = "Dinero", ["Crystals"] = "Cristales",
            ["Tickets"] = "Boletos", ["Stars"] = "Estrellas", ["Coins"] = "Monedas",
            ["Character"] = "Personaje", ["Characters"] = "Personajes", ["Gacha"] = "Gacha",
            ["Trait"] = "Rasgo", ["Traits"] = "Rasgos", ["Orb"] = "Orbe", ["Orbs"] = "Orbes",
            ["Skill"] = "Habilidad", ["Skills"] = "Habilidades",
            ["Speed"] = "Velocidad", ["Power"] = "Poder", ["Damage"] = "Daño", ["Health"] = "Vida",
            ["Walk"] = "Caminar", ["Jump"] = "Saltar", ["Fly"] = "Volar", ["Sprint"] = "Correr",
            ["Noclip"] = "Noclip", ["Godmode"] = "Modo Dios", ["Fullbright"] = "Brillo Completo",
            ["Island"] = "Isla", ["Isle"] = "Isla", ["Zone"] = "Zona", ["Area"] = "Área",
            ["Player"] = "Jugador", ["Players"] = "Jugadores", ["Server"] = "Servidor",
            ["Guild"] = "Gremio", ["Boat"] = "Bote", ["Spawn"] = "Aparición",
            ["Title"] = "Título", ["Titles"] = "Títulos", ["Skin"] = "Skin", ["Skins"] = "Skins",
            ["Craft"] = "Fabricar", ["Crafting"] = "Fabricación", ["Shop"] = "Tienda",
            ["Exchange"] = "Intercambio", ["Tank"] = "Tanque", ["Platform"] = "Plataforma",
            ["Weather"] = "Clima", ["Graphics"] = "Gráficos", ["Sound"] = "Sonido", ["Music"] = "Música",
            ["Notification"] = "Notificación", ["Alert"] = "Alerta", ["Warning"] = "Advertencia",
            ["Stats"] = "Estadísticas", ["Status"] = "Estado", ["Info"] = "Info", ["Summary"] = "Resumen",
            ["Session"] = "Sesión", ["Progress"] = "Progreso", ["Complete"] = "Completar", ["Completed"] = "Completado",
            ["Active"] = "Activo", ["Inactive"] = "Inactivo", ["Ready"] = "Listo", ["Waiting"] = "Esperando",
            ["Cooldown"] = "Enfriamiento", ["Duration"] = "Duración", ["Interval"] = "Intervalo",
            ["All"] = "Todo", ["None"] = "Ninguno", ["Once"] = "Una vez", ["Loop"] = "Bucle",
            ["Current"] = "Actual", ["Best"] = "Mejor", ["Nearest"] = "Más cercano",
            ["Normal"] = "Normal", ["Hard"] = "Difícil", ["Nightmare"] = "Pesadilla",
            ["Owned"] = "Obtenido", ["Available"] = "Disponible", ["Claimed"] = "Reclamado",
            ["Protection"] = "Protección", ["Protections"] = "Protecciones", ["Movement"] = "Movimiento",
            ["Visual"] = "Visual", ["Visuals"] = "Visuales", ["ESP"] = "ESP",
            ["Reroll"] = "Retirar", ["Lock"] = "Bloquear", ["Unlock"] = "Desbloquear",
            ["Favorite"] = "Favorito", ["Deposit"] = "Depositar",
            ["Script"] = "Script", ["Unload"] = "Descargar", ["Clean"] = "Limpiar",
            ["Automation"] = "Automatización", ["Engine"] = "Motor", ["Pipeline"] = "Pipeline",
            ["Rejoin"] = "Reconectar", ["Hop"] = "Saltar", ["Remove"] = "Quitar", ["Clear"] = "Limpiar", ["Add"] = "Añadir",
            ["Weight"] = "Peso", ["Rarity"] = "Rareza", ["Common"] = "Común", ["Uncommon"] = "Poco común",
            ["Rare"] = "Raro", ["Epic"] = "Épico", ["Legendary"] = "Legendario", ["Mythic"] = "Mítico",
            ["Mythical"] = "Mítico", ["Secret"] = "Secreto",
            ["Egg"] = "Huevo", ["Eggs"] = "Huevos", ["Pet"] = "Mascota", ["Pets"] = "Mascotas",
            ["Hatch"] = "Eclosionar", ["Hatching"] = "Eclosionando", ["Rebirth"] = "Renacer", ["Prestige"] = "Prestigio", ["Ascend"] = "Ascender",
            ["Dungeon"] = "Mazmorra", ["Tower"] = "Torre", ["Round"] = "Ronda", ["Wave"] = "Oleada", ["Floor"] = "Piso", ["Map"] = "Mapa", ["World"] = "Mundo",
            ["Potion"] = "Poción", ["Chest"] = "Cofre",
            ["Click"] = "Clic", ["Clicks"] = "Clics", ["Tap"] = "Toque", ["Collect"] = "Recolectar", ["Harvest"] = "Cosechar", ["Mine"] = "Minar", ["Dig"] = "Excavar",
            ["Merge"] = "Fusionar", ["Fuse"] = "Fusionar", ["Evolve"] = "Evolucionar", ["Enchant"] = "Encantar",
            ["Attack"] = "Ataque", ["Defense"] = "Defensa", ["Armor"] = "Armadura", ["Weapon"] = "Arma", ["Sword"] = "Espada", ["Shield"] = "Escudo",
            ["Gold"] = "Oro", ["Gems"] = "Gemas", ["Diamonds"] = "Diamantes", ["Energy"] = "Energía", ["Stamina"] = "Resistencia", ["Mana"] = "Maná",
            ["Team"] = "Equipo", ["Party"] = "Grupo", ["Ally"] = "Aliado", ["Enemy"] = "Enemigo", ["Target"] = "Objetivo", ["Mob"] = "Mob", ["NPC"] = "NPC",
            ["Trade"] = "Comerciar", ["Market"] = "Mercado", ["Auction"] = "Subasta", ["Offer"] = "Oferta", ["Price"] = "Precio", ["Cost"] = "Costo", ["Value"] = "Valor",
            ["Rank"] = "Rango", ["Score"] = "Puntuación", ["Leaderboard"] = "Tabla de líderes", ["Trophy"] = "Trofeo", ["Badge"] = "Insignia", ["Achievement"] = "Logro",
            ["When Inventory Full"] = "Cuando inventario lleno",
            ["Auto Fishing"] = "Pesca Automática", ["Auto Sell"] = "Venta Automática", ["Auto Buy"] = "Compra Automática",
            ["Auto Equip"] = "Equipar Automático", ["Auto Claim"] = "Reclamar Automático", ["Auto Quest"] = "Misión Automática",
            ["Auto Farm"] = "Farmeo Automático", ["Auto Click"] = "Clic Automático", ["Auto Collect"] = "Recolección Automática",
            ["Auto Hatch"] = "Eclosión Automática", ["Auto Rebirth"] = "Renacer Automático", ["Auto Attack"] = "Ataque Automático", ["Auto Heal"] = "Curación Automática",
            ["Get Free Key"] = "Obtener Clave Gratis", ["Buy Premium"] = "Comprar Premium", ["Buy with Robux"] = "Comprar con Robux",
            ["requires a Premium key"] = "requiere una clave Premium",
            ["Not enough"] = "No hay suficiente", ["No Boss Tickets"] = "No hay boletos de jefe",
            ["Inventory is full"] = "El inventario está lleno", ["Sold all fish"] = "Vendidos todos los peces",
            ["Equipped"] = "Equipado", ["Arrived at"] = "Llegaste a", ["Teleported to"] = "Teletransportado a",
            ["Fight started"] = "Pelea iniciada", ["Quest complete"] = "Misión completada",
            ["On cooldown"] = "En enfriamiento", ["Data saved"] = "Datos guardados",
            ["No active quests"] = "No hay misiones activas", ["Already claimed"] = "Ya reclamado",
            ["Click Fight button"] = "Clic en botón Pelear", ["Returned to NPC"] = "Regresando al NPC",
            ["Fish Caught"] = "Pez atrapado", ["Caught"] = "Atrapado", ["Sold"] = "Vendido",
            ["Stopped"] = "Detenido", ["Started"] = "Iniciado", ["Accepted"] = "Aceptado",
            ["Working on"] = "Trabajando en", ["Retrying"] = "Reintentando",
            ["remaining"] = "restante", ["left"] = "restante", ["free"] = "libre",
            ["units"] = "unidades", ["studs"] = "studs", ["seconds"] = "segundos", ["minutes"] = "minutos", ["stud/s"] = "stud/s", ["power"] = "poder",
            ["Walk Speed"] = "Velocidad al Caminar", ["Jump Power"] = "Fuerza de Salto", ["Fly Speed"] = "Velocidad de Vuelo",
            ["Collect All"] = "Recolectar Todo", ["Sell All"] = "Vender Todo", ["Equip Best"] = "Equipar Mejor", ["Hatch All"] = "Eclosionar Todo",
            ["Server Hop"] = "Cambiar Servidor", ["Rejoin Server"] = "Reconectar Servidor", ["Anti AFK"] = "Anti AFK",
            ["No Clip"] = "Sin Colisión", ["Infinite Jump"] = "Salto Infinito", ["God Mode"] = "Modo Dios",
            ["Hide / Show GUI"] = "Ocultar / Mostrar GUI", ["Change Key"] = "Cambiar Clave",
            ["Verify Key"] = "Verificar Clave", ["Get Key"] = "Obtener Clave",
            ["Key Verified"] = "Clave Verificada", ["Invalid Key"] = "Clave Inválida", ["Premium Key Verified"] = "Clave Premium Verificada",
            ["Enter key here..."] = "Ingresa tu clave...", ["Paste new key..."] = "Pega tu nueva clave...",
            ["Checking saved key..."] = "Verificando clave guardada...", ["Verifying..."] = "Verificando...", ["Loading..."] = "Cargando...",
            ["Script Loaded"] = "Script Cargado", ["Script Unloaded"] = "Script Descargado",
        },
        ["pt"] = {
            ["Enable"] = "Ativar", ["Disable"] = "Desativar", ["Enabled"] = "Ativado", ["Disabled"] = "Desativado",
            ["Toggle"] = "Alternar", ["Button"] = "Botão", ["Select"] = "Selecionar", ["Selected"] = "Selecionado",
            ["Default"] = "Padrão", ["Settings"] = "Configurações", ["Options"] = "Opções",
            ["Save"] = "Salvar", ["Load"] = "Carregar", ["Reset"] = "Reiniciar", ["Close"] = "Fechar",
            ["Open"] = "Abrir", ["Cancel"] = "Cancelar", ["Confirm"] = "Confirmar", ["Delete"] = "Excluir",
            ["Copy"] = "Copiar", ["Refresh"] = "Atualizar", ["Search"] = "Pesquisar", ["Show"] = "Mostrar",
            ["Hide"] = "Ocultar", ["Start"] = "Iniciar", ["Stop"] = "Parar", ["Pause"] = "Pausar",
            ["Resume"] = "Retomar", ["Apply"] = "Aplicar", ["Upgrade"] = "Melhorar", ["Purchase"] = "Comprar",
            ["Buy"] = "Comprar", ["Sell"] = "Vender", ["Equip"] = "Equipar", ["Unequip"] = "Desequipar",
            ["Claim"] = "Reivindicar", ["Redeem"] = "Resgatar", ["Teleport"] = "Teletransportar",
            ["Premium"] = "Premium", ["Free"] = "Grátis", ["Locked"] = "Bloqueado", ["Unlocked"] = "Desbloqueado",
            ["Auto"] = "Auto", ["Farm"] = "Farm", ["Fishing"] = "Pesca", ["Fish"] = "Peixe",
            ["Rod"] = "Vara", ["Bait"] = "Isca", ["Cast"] = "Lançar", ["Catch"] = "Pescar",
            ["Inventory"] = "Inventário", ["Full"] = "Cheio", ["Empty"] = "Vazio",
            ["Boss"] = "Chefe", ["Raid"] = "Raid", ["Fight"] = "Luta", ["Battle"] = "Batalha",
            ["Quest"] = "Missão", ["Daily"] = "Diária", ["Reward"] = "Recompensa", ["Rewards"] = "Recompensas",
            ["Level"] = "Nível", ["Experience"] = "Experiência", ["Cash"] = "Dinheiro", ["Crystals"] = "Cristais",
            ["Tickets"] = "Bilhetes", ["Stars"] = "Estrelas", ["Coins"] = "Moedas",
            ["Character"] = "Personagem", ["Characters"] = "Personagens", ["Gacha"] = "Gacha",
            ["Trait"] = "Característica", ["Traits"] = "Características", ["Orb"] = "Orbe", ["Orbs"] = "Orbes",
            ["Skill"] = "Habilidade", ["Skills"] = "Habilidades",
            ["Speed"] = "Velocidade", ["Power"] = "Poder", ["Damage"] = "Dano", ["Health"] = "Vida",
            ["Walk"] = "Andar", ["Jump"] = "Pular", ["Fly"] = "Voar", ["Sprint"] = "Correr",
            ["Noclip"] = "Noclip", ["Godmode"] = "Modo Deus", ["Fullbright"] = "Brilho Total",
            ["Island"] = "Ilha", ["Isle"] = "Ilha", ["Zone"] = "Zona", ["Area"] = "Área",
            ["Player"] = "Jogador", ["Players"] = "Jogadores", ["Server"] = "Servidor",
            ["Guild"] = "Guilda", ["Boat"] = "Barco", ["Spawn"] = "Nascimento",
            ["Title"] = "Título", ["Titles"] = "Títulos", ["Skin"] = "Skin", ["Skins"] = "Skins",
            ["Craft"] = "Fabricar", ["Crafting"] = "Fabricação", ["Shop"] = "Loja",
            ["Exchange"] = "Troca", ["Tank"] = "Tanque", ["Platform"] = "Plataforma",
            ["Weather"] = "Clima", ["Graphics"] = "Gráficos", ["Sound"] = "Som", ["Music"] = "Música",
            ["Notification"] = "Notificação", ["Alert"] = "Alerta", ["Warning"] = "Aviso",
            ["Stats"] = "Estatísticas", ["Status"] = "Status", ["Info"] = "Info", ["Summary"] = "Resumo",
            ["Session"] = "Sessão", ["Progress"] = "Progresso", ["Complete"] = "Completo", ["Completed"] = "Completado",
            ["Active"] = "Ativo", ["Inactive"] = "Inativo", ["Ready"] = "Pronto", ["Waiting"] = "Esperando",
            ["Cooldown"] = "Recarga", ["Duration"] = "Duração", ["Interval"] = "Intervalo",
            ["All"] = "Tudo", ["None"] = "Nenhum", ["Once"] = "Uma vez", ["Loop"] = "Loop",
            ["Current"] = "Atual", ["Best"] = "Melhor", ["Nearest"] = "Mais próximo",
            ["Normal"] = "Normal", ["Hard"] = "Difícil", ["Nightmare"] = "Pesadelo",
            ["Owned"] = "Possuído", ["Available"] = "Disponível", ["Claimed"] = "Resgatado",
            ["Protection"] = "Proteção", ["Movement"] = "Movimento", ["Visual"] = "Visual", ["Visuals"] = "Visuais",
            ["Lock"] = "Bloquear", ["Unlock"] = "Desbloquear", ["Favorite"] = "Favorito", ["Deposit"] = "Depositar",
            ["Rejoin"] = "Reconectar", ["Hop"] = "Pular", ["Remove"] = "Remover", ["Clear"] = "Limpar", ["Add"] = "Adicionar",
            ["Weight"] = "Peso", ["Rarity"] = "Raridade", ["Common"] = "Comum", ["Uncommon"] = "Incomum",
            ["Rare"] = "Raro", ["Epic"] = "Épico", ["Legendary"] = "Lendário", ["Mythic"] = "Mítico", ["Secret"] = "Secreto",
            ["Egg"] = "Ovo", ["Eggs"] = "Ovos", ["Pet"] = "Pet", ["Pets"] = "Pets",
            ["Hatch"] = "Chocar", ["Hatching"] = "Chocando", ["Rebirth"] = "Renascer", ["Prestige"] = "Prestígio", ["Ascend"] = "Ascender",
            ["Dungeon"] = "Masmorra", ["Tower"] = "Torre", ["Round"] = "Rodada", ["Wave"] = "Onda", ["Floor"] = "Andar", ["Map"] = "Mapa", ["World"] = "Mundo",
            ["Potion"] = "Poção", ["Chest"] = "Baú",
            ["Click"] = "Clique", ["Clicks"] = "Cliques", ["Collect"] = "Coletar", ["Harvest"] = "Colher", ["Mine"] = "Minerar",
            ["Merge"] = "Fundir", ["Fuse"] = "Fundir", ["Evolve"] = "Evoluir", ["Enchant"] = "Encantar",
            ["Attack"] = "Ataque", ["Defense"] = "Defesa", ["Armor"] = "Armadura", ["Weapon"] = "Arma", ["Sword"] = "Espada", ["Shield"] = "Escudo",
            ["Gold"] = "Ouro", ["Gems"] = "Gemas", ["Diamonds"] = "Diamantes", ["Energy"] = "Energia", ["Stamina"] = "Vigor", ["Mana"] = "Mana",
            ["Team"] = "Time", ["Party"] = "Grupo", ["Ally"] = "Aliado", ["Enemy"] = "Inimigo", ["Target"] = "Alvo", ["Mob"] = "Mob",
            ["Trade"] = "Trocar", ["Market"] = "Mercado", ["Auction"] = "Leilão", ["Offer"] = "Oferta", ["Price"] = "Preço", ["Cost"] = "Custo", ["Value"] = "Valor",
            ["Rank"] = "Ranking", ["Score"] = "Pontuação", ["Leaderboard"] = "Placar", ["Trophy"] = "Troféu", ["Badge"] = "Insígnia", ["Achievement"] = "Conquista",
            ["When Inventory Full"] = "Quando inventário cheio", ["Auto Fishing"] = "Pesca Automática", ["Auto Sell"] = "Venda Automática",
            ["Auto Buy"] = "Compra Automática", ["Auto Equip"] = "Equipar Automático", ["Auto Claim"] = "Reivindicar Automático",
            ["Auto Quest"] = "Missão Automática", ["Auto Farm"] = "Farm Automático", ["Auto Click"] = "Clique Automático",
            ["Auto Collect"] = "Coleta Automática", ["Auto Hatch"] = "Chocar Automático", ["Auto Rebirth"] = "Renascer Automático",
            ["Auto Attack"] = "Ataque Automático", ["Auto Heal"] = "Cura Automática",
            ["Get Free Key"] = "Obter Chave Grátis", ["Buy Premium"] = "Comprar Premium", ["Buy with Robux"] = "Comprar com Robux",
            ["requires a Premium key"] = "requer uma chave Premium",
            ["Not enough"] = "Não há suficiente", ["Inventory is full"] = "O inventário está cheio",
            ["Sold all fish"] = "Vendeu todos os peixes", ["Equipped"] = "Equipado",
            ["Arrived at"] = "Chegou em", ["Teleported to"] = "Teletransportado para",
            ["Fight started"] = "Luta iniciada", ["Quest complete"] = "Missão completa",
            ["On cooldown"] = "Em recarga", ["Data saved"] = "Dados salvos",
            ["Fish Caught"] = "Peixe pescado", ["Caught"] = "Pescado", ["Sold"] = "Vendido",
            ["Stopped"] = "Parado", ["Started"] = "Iniciado", ["Accepted"] = "Aceito",
            ["remaining"] = "restante", ["units"] = "unidades", ["seconds"] = "segundos", ["minutes"] = "minutos",
            ["Walk Speed"] = "Velocidade de Andar", ["Jump Power"] = "Força de Pulo", ["Fly Speed"] = "Velocidade de Voo",
            ["Collect All"] = "Coletar Tudo", ["Sell All"] = "Vender Tudo", ["Equip Best"] = "Equipar Melhor",
            ["Server Hop"] = "Trocar Servidor", ["Anti AFK"] = "Anti AFK",
            ["No Clip"] = "Sem Colisão", ["Infinite Jump"] = "Pulo Infinito", ["God Mode"] = "Modo Deus",
            ["Hide / Show GUI"] = "Ocultar / Mostrar GUI", ["Change Key"] = "Trocar Chave",
            ["Verify Key"] = "Verificar Chave", ["Get Key"] = "Obter Chave",
            ["Enter key here..."] = "Digite sua chave...", ["Verifying..."] = "Verificando...", ["Loading..."] = "Carregando...",
            ["Script Loaded"] = "Script Carregado",
        },
        ["zh"] = {
            ["Enable"] = "启用", ["Disable"] = "禁用", ["Enabled"] = "已启用", ["Disabled"] = "已禁用",
            ["Toggle"] = "切换", ["Button"] = "按钮", ["Select"] = "选择", ["Selected"] = "已选择",
            ["Default"] = "默认", ["Settings"] = "设置", ["Options"] = "选项",
            ["Save"] = "保存", ["Load"] = "加载", ["Reset"] = "重置", ["Close"] = "关闭",
            ["Open"] = "打开", ["Cancel"] = "取消", ["Confirm"] = "确认", ["Delete"] = "删除",
            ["Copy"] = "复制", ["Refresh"] = "刷新", ["Search"] = "搜索", ["Show"] = "显示", ["Hide"] = "隐藏",
            ["Start"] = "开始", ["Stop"] = "停止", ["Pause"] = "暂停", ["Resume"] = "继续", ["Apply"] = "应用",
            ["Upgrade"] = "升级", ["Purchase"] = "购买", ["Buy"] = "购买", ["Sell"] = "出售",
            ["Equip"] = "装备", ["Unequip"] = "卸下", ["Claim"] = "领取", ["Redeem"] = "兑换",
            ["Teleport"] = "传送", ["Premium"] = "高级版", ["Free"] = "免费", ["Locked"] = "已锁定", ["Unlocked"] = "已解锁",
            ["Auto"] = "自动", ["Farm"] = "刷", ["Fishing"] = "钓鱼", ["Fish"] = "鱼",
            ["Rod"] = "鱼竿", ["Bait"] = "鱼饵", ["Cast"] = "抛竿", ["Catch"] = "捕获",
            ["Inventory"] = "背包", ["Full"] = "已满", ["Empty"] = "空的",
            ["Boss"] = "首领", ["Raid"] = "突袭", ["Fight"] = "战斗", ["Battle"] = "战斗",
            ["Quest"] = "任务", ["Daily"] = "每日", ["Reward"] = "奖励", ["Rewards"] = "奖励",
            ["Level"] = "等级", ["Experience"] = "经验", ["Cash"] = "金币", ["Crystals"] = "水晶",
            ["Tickets"] = "票券", ["Stars"] = "星星", ["Coins"] = "金币",
            ["Character"] = "角色", ["Characters"] = "角色", ["Gacha"] = "抽卡",
            ["Skill"] = "技能", ["Skills"] = "技能", ["Speed"] = "速度", ["Power"] = "力量", ["Damage"] = "伤害", ["Health"] = "生命",
            ["Walk"] = "行走", ["Jump"] = "跳跃", ["Fly"] = "飞行", ["Sprint"] = "冲刺",
            ["Noclip"] = "穿墙", ["Godmode"] = "无敌", ["Fullbright"] = "全亮",
            ["Island"] = "岛屿", ["Zone"] = "区域", ["Area"] = "区域", ["Player"] = "玩家", ["Players"] = "玩家", ["Server"] = "服务器",
            ["Guild"] = "公会", ["Craft"] = "制作", ["Crafting"] = "制作", ["Shop"] = "商店",
            ["Stats"] = "统计", ["Status"] = "状态", ["Session"] = "会话", ["Progress"] = "进度",
            ["Complete"] = "完成", ["Completed"] = "已完成", ["Active"] = "活跃", ["Ready"] = "就绪",
            ["Cooldown"] = "冷却", ["Normal"] = "普通", ["Hard"] = "困难", ["Nightmare"] = "噩梦",
            ["Egg"] = "蛋", ["Eggs"] = "蛋", ["Pet"] = "宠物", ["Pets"] = "宠物",
            ["Hatch"] = "孵化", ["Hatching"] = "孵化中", ["Rebirth"] = "转生", ["Prestige"] = "声望", ["Ascend"] = "飞升",
            ["Dungeon"] = "地牢", ["Tower"] = "塔", ["Round"] = "回合", ["Wave"] = "波次", ["Floor"] = "层", ["Map"] = "地图", ["World"] = "世界",
            ["Potion"] = "药水", ["Chest"] = "宝箱",
            ["Click"] = "点击", ["Clicks"] = "点击", ["Collect"] = "收集", ["Harvest"] = "收获", ["Mine"] = "挖矿",
            ["Merge"] = "合并", ["Fuse"] = "融合", ["Evolve"] = "进化", ["Enchant"] = "附魔",
            ["Attack"] = "攻击", ["Defense"] = "防御", ["Armor"] = "护甲", ["Weapon"] = "武器", ["Sword"] = "剑", ["Shield"] = "盾",
            ["Gold"] = "金", ["Gems"] = "宝石", ["Diamonds"] = "钻石", ["Energy"] = "能量", ["Stamina"] = "体力", ["Mana"] = "法力",
            ["Team"] = "队伍", ["Party"] = "小队", ["Ally"] = "盟友", ["Enemy"] = "敌人", ["Target"] = "目标",
            ["Trade"] = "交易", ["Market"] = "市场", ["Auction"] = "拍卖", ["Price"] = "价格", ["Cost"] = "费用", ["Value"] = "价值",
            ["Rank"] = "排名", ["Score"] = "分数", ["Leaderboard"] = "排行榜", ["Trophy"] = "奖杯", ["Achievement"] = "成就",
            ["When Inventory Full"] = "背包满时", ["Auto Fishing"] = "自动钓鱼", ["Auto Sell"] = "自动出售",
            ["Auto Buy"] = "自动购买", ["Auto Farm"] = "自动刷", ["Auto Click"] = "自动点击",
            ["Auto Collect"] = "自动收集", ["Auto Hatch"] = "自动孵化", ["Auto Rebirth"] = "自动转生",
            ["Auto Attack"] = "自动攻击", ["Auto Heal"] = "自动治疗",
            ["Get Free Key"] = "获取免费密钥", ["Buy Premium"] = "购买高级版", ["Buy with Robux"] = "用Robux购买",
            ["Sold all fish"] = "已卖出所有鱼", ["Fight started"] = "战斗开始", ["Quest complete"] = "任务完成",
            ["Data saved"] = "数据已保存", ["Fish Caught"] = "捕获了鱼",
            ["remaining"] = "剩余", ["units"] = "个", ["seconds"] = "秒", ["minutes"] = "分钟",
            ["Walk Speed"] = "行走速度", ["Jump Power"] = "跳跃力", ["Fly Speed"] = "飞行速度",
            ["Collect All"] = "全部收集", ["Sell All"] = "全部出售", ["Server Hop"] = "换服",
            ["No Clip"] = "穿墙", ["Infinite Jump"] = "无限跳跃", ["God Mode"] = "无敌模式",
            ["Hide / Show GUI"] = "隐藏/显示界面", ["Change Key"] = "更换密钥",
            ["Verify Key"] = "验证密钥", ["Get Key"] = "获取密钥",
            ["Enter key here..."] = "在此输入密钥...", ["Verifying..."] = "验证中...", ["Loading..."] = "加载中...",
        },
        ["ja"] = {
            ["Enable"] = "有効", ["Disable"] = "無効", ["Enabled"] = "有効", ["Disabled"] = "無効",
            ["Toggle"] = "切替", ["Button"] = "ボタン", ["Select"] = "選択", ["Selected"] = "選択済",
            ["Default"] = "デフォルト", ["Settings"] = "設定", ["Options"] = "オプション",
            ["Save"] = "保存", ["Load"] = "読込", ["Reset"] = "リセット", ["Close"] = "閉じる",
            ["Open"] = "開く", ["Cancel"] = "キャンセル", ["Confirm"] = "確認", ["Delete"] = "削除",
            ["Copy"] = "コピー", ["Refresh"] = "更新", ["Search"] = "検索", ["Show"] = "表示", ["Hide"] = "非表示",
            ["Start"] = "開始", ["Stop"] = "停止", ["Pause"] = "一時停止", ["Resume"] = "再開", ["Apply"] = "適用",
            ["Upgrade"] = "アップグレード", ["Purchase"] = "購入", ["Buy"] = "購入", ["Sell"] = "売却",
            ["Equip"] = "装備", ["Unequip"] = "装備解除", ["Claim"] = "受取", ["Redeem"] = "引換",
            ["Teleport"] = "テレポート", ["Premium"] = "プレミアム", ["Free"] = "無料", ["Locked"] = "ロック", ["Unlocked"] = "解放済",
            ["Auto"] = "自動", ["Farm"] = "ファーム", ["Fishing"] = "釣り", ["Fish"] = "魚", ["Rod"] = "竿", ["Bait"] = "餌",
            ["Inventory"] = "インベントリ", ["Full"] = "満杯", ["Empty"] = "空",
            ["Boss"] = "ボス", ["Fight"] = "戦闘", ["Battle"] = "バトル",
            ["Quest"] = "クエスト", ["Daily"] = "デイリー", ["Reward"] = "報酬", ["Rewards"] = "報酬",
            ["Level"] = "レベル", ["Experience"] = "経験値", ["Character"] = "キャラクター",
            ["Skill"] = "スキル", ["Skills"] = "スキル", ["Speed"] = "速度", ["Power"] = "パワー", ["Damage"] = "ダメージ", ["Health"] = "体力",
            ["Walk"] = "歩行", ["Jump"] = "ジャンプ", ["Fly"] = "飛行", ["Sprint"] = "ダッシュ",
            ["Player"] = "プレイヤー", ["Server"] = "サーバー",
            ["Normal"] = "ノーマル", ["Hard"] = "ハード", ["Nightmare"] = "ナイトメア",
            ["Egg"] = "卵", ["Pet"] = "ペット", ["Pets"] = "ペット", ["Hatch"] = "孵化", ["Rebirth"] = "転生",
            ["Dungeon"] = "ダンジョン", ["Tower"] = "タワー", ["Round"] = "ラウンド", ["Wave"] = "ウェーブ", ["Floor"] = "フロア",
            ["Potion"] = "ポーション", ["Chest"] = "宝箱", ["Click"] = "クリック", ["Collect"] = "収集",
            ["Evolve"] = "進化", ["Enchant"] = "エンチャント",
            ["Attack"] = "攻撃", ["Defense"] = "防御", ["Weapon"] = "武器", ["Sword"] = "剣", ["Shield"] = "盾",
            ["Gold"] = "ゴールド", ["Gems"] = "ジェム", ["Diamonds"] = "ダイヤ", ["Energy"] = "エネルギー",
            ["Team"] = "チーム", ["Enemy"] = "敵", ["Target"] = "ターゲット",
            ["Trade"] = "取引", ["Market"] = "マーケット", ["Rank"] = "ランク", ["Score"] = "スコア", ["Achievement"] = "実績",
            ["Auto Farm"] = "自動ファーム", ["Auto Click"] = "自動クリック", ["Auto Collect"] = "自動収集",
            ["Get Free Key"] = "無料キーを取得", ["Buy Premium"] = "プレミアム購入", ["Buy with Robux"] = "Robuxで購入",
            ["remaining"] = "残り", ["units"] = "個", ["seconds"] = "秒", ["minutes"] = "分",
            ["Hide / Show GUI"] = "GUI表示切替", ["Change Key"] = "キー変更",
            ["Verify Key"] = "キー認証", ["Enter key here..."] = "キーを入力...", ["Verifying..."] = "認証中...", ["Loading..."] = "読込中...",
        },
        ["ko"] = {
            ["Enable"] = "활성화", ["Disable"] = "비활성화", ["Enabled"] = "활성", ["Disabled"] = "비활성",
            ["Toggle"] = "전환", ["Button"] = "버튼", ["Select"] = "선택", ["Selected"] = "선택됨",
            ["Default"] = "기본값", ["Settings"] = "설정", ["Options"] = "옵션",
            ["Save"] = "저장", ["Load"] = "불러오기", ["Reset"] = "초기화", ["Close"] = "닫기",
            ["Open"] = "열기", ["Cancel"] = "취소", ["Confirm"] = "확인", ["Delete"] = "삭제",
            ["Copy"] = "복사", ["Refresh"] = "새로고침", ["Search"] = "검색", ["Show"] = "표시", ["Hide"] = "숨기기",
            ["Start"] = "시작", ["Stop"] = "정지", ["Pause"] = "일시정지", ["Resume"] = "재개", ["Apply"] = "적용",
            ["Upgrade"] = "업그레이드", ["Purchase"] = "구매", ["Buy"] = "구매", ["Sell"] = "판매",
            ["Equip"] = "장착", ["Unequip"] = "해제", ["Claim"] = "수령", ["Redeem"] = "교환",
            ["Teleport"] = "텔레포트", ["Premium"] = "프리미엄", ["Free"] = "무료", ["Locked"] = "잠김", ["Unlocked"] = "해제됨",
            ["Auto"] = "자동", ["Farm"] = "파밍", ["Fishing"] = "낚시", ["Fish"] = "물고기", ["Rod"] = "낚싯대", ["Bait"] = "미끼",
            ["Inventory"] = "인벤토리", ["Full"] = "가득참", ["Empty"] = "비어있음",
            ["Boss"] = "보스", ["Fight"] = "전투", ["Battle"] = "배틀",
            ["Quest"] = "퀘스트", ["Daily"] = "일일", ["Reward"] = "보상", ["Rewards"] = "보상",
            ["Level"] = "레벨", ["Experience"] = "경험치", ["Character"] = "캐릭터",
            ["Skill"] = "스킬", ["Skills"] = "스킬", ["Speed"] = "속도", ["Power"] = "힘", ["Damage"] = "피해", ["Health"] = "체력",
            ["Walk"] = "걷기", ["Jump"] = "점프", ["Fly"] = "비행", ["Sprint"] = "달리기",
            ["Player"] = "플레이어", ["Server"] = "서버",
            ["Normal"] = "노멀", ["Hard"] = "하드", ["Nightmare"] = "나이트메어",
            ["Egg"] = "알", ["Pet"] = "펫", ["Pets"] = "펫", ["Hatch"] = "부화", ["Rebirth"] = "환생",
            ["Dungeon"] = "던전", ["Tower"] = "타워", ["Round"] = "라운드", ["Wave"] = "웨이브",
            ["Potion"] = "포션", ["Chest"] = "상자", ["Click"] = "클릭", ["Collect"] = "수집",
            ["Evolve"] = "진화", ["Attack"] = "공격", ["Defense"] = "방어", ["Weapon"] = "무기",
            ["Gold"] = "골드", ["Gems"] = "젬", ["Diamonds"] = "다이아", ["Energy"] = "에너지",
            ["Team"] = "팀", ["Enemy"] = "적", ["Target"] = "타겟",
            ["Trade"] = "거래", ["Market"] = "마켓", ["Rank"] = "랭크", ["Score"] = "점수", ["Achievement"] = "업적",
            ["Auto Farm"] = "자동 파밍", ["Auto Click"] = "자동 클릭", ["Auto Collect"] = "자동 수집",
            ["Get Free Key"] = "무료 키 받기", ["Buy Premium"] = "프리미엄 구매", ["Buy with Robux"] = "Robux로 구매",
            ["remaining"] = "남음", ["units"] = "개", ["seconds"] = "초", ["minutes"] = "분",
            ["Hide / Show GUI"] = "GUI 표시/숨기기", ["Change Key"] = "키 변경",
            ["Verify Key"] = "키 인증", ["Enter key here..."] = "키를 입력하세요...", ["Verifying..."] = "인증 중...", ["Loading..."] = "로딩 중...",
        },
        ["fr"] = {
            ["Enable"] = "Activer", ["Disable"] = "Désactiver", ["Enabled"] = "Activé", ["Disabled"] = "Désactivé",
            ["Toggle"] = "Basculer", ["Button"] = "Bouton", ["Select"] = "Sélectionner", ["Selected"] = "Sélectionné",
            ["Default"] = "Par défaut", ["Settings"] = "Paramètres", ["Options"] = "Options",
            ["Save"] = "Sauvegarder", ["Load"] = "Charger", ["Reset"] = "Réinitialiser", ["Close"] = "Fermer",
            ["Open"] = "Ouvrir", ["Cancel"] = "Annuler", ["Confirm"] = "Confirmer", ["Delete"] = "Supprimer",
            ["Copy"] = "Copier", ["Refresh"] = "Rafraîchir", ["Search"] = "Chercher", ["Show"] = "Afficher", ["Hide"] = "Masquer",
            ["Start"] = "Démarrer", ["Stop"] = "Arrêter", ["Pause"] = "Pause", ["Resume"] = "Reprendre", ["Apply"] = "Appliquer",
            ["Upgrade"] = "Améliorer", ["Purchase"] = "Acheter", ["Buy"] = "Acheter", ["Sell"] = "Vendre",
            ["Equip"] = "Équiper", ["Unequip"] = "Déséquiper", ["Claim"] = "Réclamer", ["Redeem"] = "Échanger",
            ["Teleport"] = "Téléporter", ["Premium"] = "Premium", ["Free"] = "Gratuit", ["Locked"] = "Verrouillé", ["Unlocked"] = "Déverrouillé",
            ["Auto"] = "Auto", ["Farm"] = "Farm", ["Fishing"] = "Pêche", ["Fish"] = "Poisson", ["Rod"] = "Canne", ["Bait"] = "Appât",
            ["Inventory"] = "Inventaire", ["Full"] = "Plein", ["Empty"] = "Vide",
            ["Boss"] = "Boss", ["Fight"] = "Combat", ["Battle"] = "Bataille",
            ["Quest"] = "Quête", ["Daily"] = "Quotidien", ["Reward"] = "Récompense", ["Rewards"] = "Récompenses",
            ["Level"] = "Niveau", ["Experience"] = "Expérience", ["Character"] = "Personnage",
            ["Skill"] = "Compétence", ["Skills"] = "Compétences", ["Speed"] = "Vitesse", ["Power"] = "Puissance", ["Damage"] = "Dégâts", ["Health"] = "Santé",
            ["Walk"] = "Marcher", ["Jump"] = "Sauter", ["Fly"] = "Voler", ["Sprint"] = "Sprinter",
            ["Player"] = "Joueur", ["Players"] = "Joueurs", ["Server"] = "Serveur",
            ["Normal"] = "Normal", ["Hard"] = "Difficile", ["Nightmare"] = "Cauchemar",
            ["Egg"] = "Oeuf", ["Eggs"] = "Oeufs", ["Pet"] = "Animal", ["Pets"] = "Animaux",
            ["Hatch"] = "Éclore", ["Rebirth"] = "Renaissance", ["Prestige"] = "Prestige",
            ["Dungeon"] = "Donjon", ["Tower"] = "Tour", ["Round"] = "Manche", ["Wave"] = "Vague", ["Floor"] = "Étage",
            ["Potion"] = "Potion", ["Chest"] = "Coffre", ["Click"] = "Clic", ["Collect"] = "Collecter",
            ["Evolve"] = "Évoluer", ["Enchant"] = "Enchanter",
            ["Attack"] = "Attaque", ["Defense"] = "Défense", ["Armor"] = "Armure", ["Weapon"] = "Arme", ["Sword"] = "Épée", ["Shield"] = "Bouclier",
            ["Gold"] = "Or", ["Gems"] = "Gemmes", ["Diamonds"] = "Diamants", ["Energy"] = "Énergie",
            ["Team"] = "Équipe", ["Enemy"] = "Ennemi", ["Target"] = "Cible",
            ["Trade"] = "Échanger", ["Market"] = "Marché", ["Rank"] = "Rang", ["Score"] = "Score", ["Achievement"] = "Succès",
            ["Auto Farm"] = "Farm Auto", ["Auto Click"] = "Clic Auto", ["Auto Collect"] = "Collecte Auto",
            ["Get Free Key"] = "Obtenir Clé Gratuite", ["Buy Premium"] = "Acheter Premium", ["Buy with Robux"] = "Acheter avec Robux",
            ["remaining"] = "restant", ["units"] = "unités", ["seconds"] = "secondes", ["minutes"] = "minutes",
            ["Hide / Show GUI"] = "Masquer / Afficher GUI", ["Change Key"] = "Changer Clé",
            ["Verify Key"] = "Vérifier Clé", ["Enter key here..."] = "Entrez la clé ici...", ["Verifying..."] = "Vérification...", ["Loading..."] = "Chargement...",
        },
        ["de"] = {
            ["Enable"] = "Aktivieren", ["Disable"] = "Deaktivieren", ["Enabled"] = "Aktiviert", ["Disabled"] = "Deaktiviert",
            ["Toggle"] = "Umschalten", ["Button"] = "Taste", ["Select"] = "Auswählen", ["Selected"] = "Ausgewählt",
            ["Default"] = "Standard", ["Settings"] = "Einstellungen", ["Options"] = "Optionen",
            ["Save"] = "Speichern", ["Load"] = "Laden", ["Reset"] = "Zurücksetzen", ["Close"] = "Schließen",
            ["Open"] = "Öffnen", ["Cancel"] = "Abbrechen", ["Confirm"] = "Bestätigen", ["Delete"] = "Löschen",
            ["Copy"] = "Kopieren", ["Refresh"] = "Aktualisieren", ["Search"] = "Suchen", ["Show"] = "Anzeigen", ["Hide"] = "Verstecken",
            ["Start"] = "Starten", ["Stop"] = "Stoppen", ["Pause"] = "Pause", ["Resume"] = "Fortsetzen", ["Apply"] = "Anwenden",
            ["Upgrade"] = "Verbessern", ["Purchase"] = "Kaufen", ["Buy"] = "Kaufen", ["Sell"] = "Verkaufen",
            ["Equip"] = "Ausrüsten", ["Unequip"] = "Ablegen", ["Claim"] = "Abholen", ["Redeem"] = "Einlösen",
            ["Teleport"] = "Teleportieren", ["Premium"] = "Premium", ["Free"] = "Kostenlos", ["Locked"] = "Gesperrt", ["Unlocked"] = "Freigeschaltet",
            ["Auto"] = "Auto", ["Farm"] = "Farmen", ["Fishing"] = "Angeln", ["Fish"] = "Fisch", ["Rod"] = "Rute", ["Bait"] = "Köder",
            ["Inventory"] = "Inventar", ["Full"] = "Voll", ["Empty"] = "Leer",
            ["Boss"] = "Boss", ["Fight"] = "Kampf", ["Battle"] = "Schlacht",
            ["Quest"] = "Quest", ["Daily"] = "Täglich", ["Reward"] = "Belohnung", ["Rewards"] = "Belohnungen",
            ["Level"] = "Stufe", ["Experience"] = "Erfahrung", ["Character"] = "Charakter",
            ["Skill"] = "Fähigkeit", ["Skills"] = "Fähigkeiten", ["Speed"] = "Geschwindigkeit", ["Power"] = "Kraft", ["Damage"] = "Schaden", ["Health"] = "Gesundheit",
            ["Walk"] = "Gehen", ["Jump"] = "Springen", ["Fly"] = "Fliegen", ["Sprint"] = "Sprinten",
            ["Player"] = "Spieler", ["Players"] = "Spieler", ["Server"] = "Server",
            ["Normal"] = "Normal", ["Hard"] = "Schwer", ["Nightmare"] = "Albtraum",
            ["Egg"] = "Ei", ["Eggs"] = "Eier", ["Pet"] = "Haustier", ["Pets"] = "Haustiere",
            ["Hatch"] = "Ausbrüten", ["Rebirth"] = "Wiedergeburt", ["Prestige"] = "Prestige",
            ["Dungeon"] = "Kerker", ["Tower"] = "Turm", ["Round"] = "Runde", ["Wave"] = "Welle", ["Floor"] = "Stockwerk",
            ["Potion"] = "Trank", ["Chest"] = "Truhe", ["Click"] = "Klick", ["Collect"] = "Sammeln",
            ["Evolve"] = "Entwickeln", ["Enchant"] = "Verzaubern",
            ["Attack"] = "Angriff", ["Defense"] = "Verteidigung", ["Armor"] = "Rüstung", ["Weapon"] = "Waffe", ["Sword"] = "Schwert", ["Shield"] = "Schild",
            ["Gold"] = "Gold", ["Gems"] = "Edelsteine", ["Diamonds"] = "Diamanten", ["Energy"] = "Energie",
            ["Team"] = "Team", ["Enemy"] = "Feind", ["Target"] = "Ziel",
            ["Trade"] = "Handeln", ["Market"] = "Markt", ["Rank"] = "Rang", ["Score"] = "Punktzahl", ["Achievement"] = "Erfolg",
            ["Auto Farm"] = "Auto Farmen", ["Auto Click"] = "Auto Klick",
            ["Get Free Key"] = "Kostenlosen Schlüssel holen", ["Buy Premium"] = "Premium kaufen", ["Buy with Robux"] = "Mit Robux kaufen",
            ["remaining"] = "übrig", ["units"] = "Einheiten", ["seconds"] = "Sekunden", ["minutes"] = "Minuten",
            ["Hide / Show GUI"] = "GUI Ein-/Ausblenden", ["Change Key"] = "Schlüssel ändern",
            ["Verify Key"] = "Schlüssel prüfen", ["Enter key here..."] = "Schlüssel eingeben...", ["Verifying..."] = "Wird geprüft...", ["Loading..."] = "Wird geladen...",
        },
        ["ru"] = {
            ["Enable"] = "Включить", ["Disable"] = "Отключить", ["Enabled"] = "Включено", ["Disabled"] = "Отключено",
            ["Toggle"] = "Переключить", ["Button"] = "Кнопка", ["Select"] = "Выбрать", ["Selected"] = "Выбрано",
            ["Default"] = "По умолчанию", ["Settings"] = "Настройки", ["Options"] = "Параметры",
            ["Save"] = "Сохранить", ["Load"] = "Загрузить", ["Reset"] = "Сбросить", ["Close"] = "Закрыть",
            ["Open"] = "Открыть", ["Cancel"] = "Отмена", ["Confirm"] = "Подтвердить", ["Delete"] = "Удалить",
            ["Copy"] = "Копировать", ["Refresh"] = "Обновить", ["Search"] = "Поиск", ["Show"] = "Показать", ["Hide"] = "Скрыть",
            ["Start"] = "Старт", ["Stop"] = "Стоп", ["Pause"] = "Пауза", ["Resume"] = "Продолжить", ["Apply"] = "Применить",
            ["Upgrade"] = "Улучшить", ["Purchase"] = "Купить", ["Buy"] = "Купить", ["Sell"] = "Продать",
            ["Equip"] = "Экипировать", ["Unequip"] = "Снять", ["Claim"] = "Забрать", ["Redeem"] = "Обменять",
            ["Teleport"] = "Телепорт", ["Premium"] = "Премиум", ["Free"] = "Бесплатно", ["Locked"] = "Заблокировано", ["Unlocked"] = "Разблокировано",
            ["Auto"] = "Авто", ["Farm"] = "Фарм", ["Fishing"] = "Рыбалка", ["Fish"] = "Рыба", ["Rod"] = "Удочка", ["Bait"] = "Наживка",
            ["Inventory"] = "Инвентарь", ["Full"] = "Полный", ["Empty"] = "Пустой",
            ["Boss"] = "Босс", ["Fight"] = "Бой", ["Battle"] = "Битва",
            ["Quest"] = "Задание", ["Daily"] = "Ежедневно", ["Reward"] = "Награда", ["Rewards"] = "Награды",
            ["Level"] = "Уровень", ["Experience"] = "Опыт", ["Character"] = "Персонаж",
            ["Skill"] = "Навык", ["Skills"] = "Навыки", ["Speed"] = "Скорость", ["Power"] = "Сила", ["Damage"] = "Урон", ["Health"] = "Здоровье",
            ["Walk"] = "Ходьба", ["Jump"] = "Прыжок", ["Fly"] = "Полёт", ["Sprint"] = "Бег",
            ["Player"] = "Игрок", ["Players"] = "Игроки", ["Server"] = "Сервер",
            ["Normal"] = "Обычный", ["Hard"] = "Сложный", ["Nightmare"] = "Кошмар",
            ["Egg"] = "Яйцо", ["Eggs"] = "Яйца", ["Pet"] = "Питомец", ["Pets"] = "Питомцы",
            ["Hatch"] = "Вылупить", ["Rebirth"] = "Перерождение", ["Prestige"] = "Престиж",
            ["Dungeon"] = "Подземелье", ["Tower"] = "Башня", ["Round"] = "Раунд", ["Wave"] = "Волна", ["Floor"] = "Этаж",
            ["Potion"] = "Зелье", ["Chest"] = "Сундук", ["Click"] = "Клик", ["Collect"] = "Собрать",
            ["Evolve"] = "Эволюция", ["Enchant"] = "Зачарить",
            ["Attack"] = "Атака", ["Defense"] = "Защита", ["Armor"] = "Броня", ["Weapon"] = "Оружие", ["Sword"] = "Меч", ["Shield"] = "Щит",
            ["Gold"] = "Золото", ["Gems"] = "Камни", ["Diamonds"] = "Алмазы", ["Energy"] = "Энергия",
            ["Team"] = "Команда", ["Enemy"] = "Враг", ["Target"] = "Цель",
            ["Trade"] = "Торговля", ["Market"] = "Рынок", ["Rank"] = "Ранг", ["Score"] = "Счёт", ["Achievement"] = "Достижение",
            ["Auto Farm"] = "Авто Фарм", ["Auto Click"] = "Авто Клик",
            ["Get Free Key"] = "Получить бесплатный ключ", ["Buy Premium"] = "Купить Премиум", ["Buy with Robux"] = "Купить за Robux",
            ["remaining"] = "осталось", ["units"] = "шт", ["seconds"] = "секунд", ["minutes"] = "минут",
            ["Hide / Show GUI"] = "Скрыть / Показать GUI", ["Change Key"] = "Сменить ключ",
            ["Verify Key"] = "Проверить ключ", ["Enter key here..."] = "Введите ключ...", ["Verifying..."] = "Проверка...", ["Loading..."] = "Загрузка...",
        },
        ["tr"] = {
            ["Enable"] = "Etkinleştir", ["Disable"] = "Devre Dışı", ["Enabled"] = "Etkin", ["Disabled"] = "Devre Dışı",
            ["Toggle"] = "Değiştir", ["Button"] = "Düğme", ["Select"] = "Seç", ["Selected"] = "Seçildi",
            ["Default"] = "Varsayılan", ["Settings"] = "Ayarlar", ["Options"] = "Seçenekler",
            ["Save"] = "Kaydet", ["Load"] = "Yükle", ["Reset"] = "Sıfırla", ["Close"] = "Kapat",
            ["Open"] = "Aç", ["Cancel"] = "İptal", ["Confirm"] = "Onayla", ["Delete"] = "Sil",
            ["Copy"] = "Kopyala", ["Refresh"] = "Yenile", ["Search"] = "Ara", ["Show"] = "Göster", ["Hide"] = "Gizle",
            ["Start"] = "Başlat", ["Stop"] = "Durdur", ["Pause"] = "Duraklat", ["Resume"] = "Devam", ["Apply"] = "Uygula",
            ["Upgrade"] = "Yükselt", ["Purchase"] = "Satın Al", ["Buy"] = "Satın Al", ["Sell"] = "Sat",
            ["Equip"] = "Kuşan", ["Claim"] = "Al", ["Redeem"] = "Kullan",
            ["Teleport"] = "Işınlan", ["Premium"] = "Premium", ["Free"] = "Ücretsiz", ["Locked"] = "Kilitli", ["Unlocked"] = "Açık",
            ["Auto"] = "Otomatik", ["Farm"] = "Farm", ["Fishing"] = "Balıkçılık", ["Fish"] = "Balık", ["Rod"] = "Olta", ["Bait"] = "Yem",
            ["Inventory"] = "Envanter", ["Full"] = "Dolu", ["Empty"] = "Boş",
            ["Boss"] = "Patron", ["Fight"] = "Savaş", ["Battle"] = "Muharebe",
            ["Quest"] = "Görev", ["Daily"] = "Günlük", ["Reward"] = "Ödül", ["Rewards"] = "Ödüller",
            ["Level"] = "Seviye", ["Experience"] = "Deneyim", ["Character"] = "Karakter",
            ["Skill"] = "Yetenek", ["Skills"] = "Yetenekler", ["Speed"] = "Hız", ["Power"] = "Güç", ["Damage"] = "Hasar", ["Health"] = "Sağlık",
            ["Walk"] = "Yürü", ["Jump"] = "Zıpla", ["Fly"] = "Uç", ["Sprint"] = "Koş",
            ["Player"] = "Oyuncu", ["Players"] = "Oyuncular", ["Server"] = "Sunucu",
            ["Normal"] = "Normal", ["Hard"] = "Zor", ["Nightmare"] = "Kabus",
            ["Egg"] = "Yumurta", ["Pet"] = "Evcil", ["Pets"] = "Evciller", ["Hatch"] = "Kuluçka", ["Rebirth"] = "Yeniden Doğuş",
            ["Dungeon"] = "Zindan", ["Tower"] = "Kule", ["Round"] = "Tur", ["Wave"] = "Dalga",
            ["Potion"] = "İksir", ["Chest"] = "Sandık", ["Click"] = "Tıkla", ["Collect"] = "Topla",
            ["Attack"] = "Saldırı", ["Defense"] = "Savunma", ["Weapon"] = "Silah", ["Sword"] = "Kılıç", ["Shield"] = "Kalkan",
            ["Gold"] = "Altın", ["Gems"] = "Taşlar", ["Energy"] = "Enerji",
            ["Team"] = "Takım", ["Enemy"] = "Düşman", ["Target"] = "Hedef",
            ["Trade"] = "Ticaret", ["Market"] = "Pazar", ["Rank"] = "Sıralama", ["Score"] = "Puan", ["Achievement"] = "Başarı",
            ["Auto Farm"] = "Otomatik Farm", ["Auto Click"] = "Otomatik Tıklama",
            ["Get Free Key"] = "Ücretsiz Anahtar Al", ["Buy Premium"] = "Premium Satın Al", ["Buy with Robux"] = "Robux ile Satın Al",
            ["remaining"] = "kalan", ["seconds"] = "saniye", ["minutes"] = "dakika",
            ["Hide / Show GUI"] = "GUI Göster / Gizle", ["Change Key"] = "Anahtar Değiştir",
            ["Verify Key"] = "Anahtar Doğrula", ["Enter key here..."] = "Anahtarı girin...", ["Verifying..."] = "Doğrulanıyor...", ["Loading..."] = "Yükleniyor...",
        },
        ["vi"] = {
            ["Enable"] = "Bật", ["Disable"] = "Tắt", ["Enabled"] = "Đã bật", ["Disabled"] = "Đã tắt",
            ["Toggle"] = "Chuyển đổi", ["Button"] = "Nút", ["Select"] = "Chọn", ["Selected"] = "Đã chọn",
            ["Default"] = "Mặc định", ["Settings"] = "Cài đặt", ["Options"] = "Tùy chọn",
            ["Save"] = "Lưu", ["Load"] = "Tải", ["Reset"] = "Đặt lại", ["Close"] = "Đóng",
            ["Open"] = "Mở", ["Cancel"] = "Hủy", ["Confirm"] = "Xác nhận", ["Delete"] = "Xóa",
            ["Copy"] = "Sao chép", ["Refresh"] = "Làm mới", ["Search"] = "Tìm kiếm", ["Show"] = "Hiện", ["Hide"] = "Ẩn",
            ["Start"] = "Bắt đầu", ["Stop"] = "Dừng", ["Pause"] = "Tạm dừng", ["Resume"] = "Tiếp tục", ["Apply"] = "Áp dụng",
            ["Upgrade"] = "Nâng cấp", ["Purchase"] = "Mua", ["Buy"] = "Mua", ["Sell"] = "Bán",
            ["Equip"] = "Trang bị", ["Claim"] = "Nhận", ["Redeem"] = "Đổi",
            ["Teleport"] = "Dịch chuyển", ["Premium"] = "Cao cấp", ["Free"] = "Miễn phí", ["Locked"] = "Đã khóa", ["Unlocked"] = "Đã mở",
            ["Auto"] = "Tự động", ["Farm"] = "Farm", ["Fishing"] = "Câu cá", ["Fish"] = "Cá", ["Rod"] = "Cần câu", ["Bait"] = "Mồi",
            ["Inventory"] = "Kho đồ", ["Full"] = "Đầy", ["Empty"] = "Trống",
            ["Boss"] = "Trùm", ["Fight"] = "Chiến đấu", ["Battle"] = "Trận chiến",
            ["Quest"] = "Nhiệm vụ", ["Daily"] = "Hàng ngày", ["Reward"] = "Phần thưởng", ["Rewards"] = "Phần thưởng",
            ["Level"] = "Cấp độ", ["Experience"] = "Kinh nghiệm", ["Character"] = "Nhân vật",
            ["Skill"] = "Kỹ năng", ["Skills"] = "Kỹ năng", ["Speed"] = "Tốc độ", ["Power"] = "Sức mạnh", ["Damage"] = "Sát thương", ["Health"] = "Máu",
            ["Walk"] = "Đi bộ", ["Jump"] = "Nhảy", ["Fly"] = "Bay", ["Sprint"] = "Chạy nhanh",
            ["Player"] = "Người chơi", ["Players"] = "Người chơi", ["Server"] = "Máy chủ",
            ["Normal"] = "Bình thường", ["Hard"] = "Khó", ["Nightmare"] = "Ác mộng",
            ["Egg"] = "Trứng", ["Pet"] = "Thú cưng", ["Pets"] = "Thú cưng", ["Hatch"] = "Ấp nở", ["Rebirth"] = "Tái sinh",
            ["Dungeon"] = "Hầm ngục", ["Tower"] = "Tháp", ["Round"] = "Vòng", ["Wave"] = "Đợt",
            ["Potion"] = "Thuốc", ["Chest"] = "Rương", ["Click"] = "Nhấp", ["Collect"] = "Thu thập",
            ["Attack"] = "Tấn công", ["Defense"] = "Phòng thủ", ["Weapon"] = "Vũ khí",
            ["Gold"] = "Vàng", ["Gems"] = "Đá quý", ["Energy"] = "Năng lượng",
            ["Team"] = "Đội", ["Enemy"] = "Kẻ thù", ["Target"] = "Mục tiêu",
            ["Trade"] = "Giao dịch", ["Market"] = "Chợ", ["Rank"] = "Hạng", ["Score"] = "Điểm", ["Achievement"] = "Thành tựu",
            ["Auto Farm"] = "Farm Tự động", ["Auto Click"] = "Nhấp Tự động",
            ["Get Free Key"] = "Lấy Key Miễn phí", ["Buy Premium"] = "Mua Cao cấp", ["Buy with Robux"] = "Mua bằng Robux",
            ["remaining"] = "còn lại", ["seconds"] = "giây", ["minutes"] = "phút",
            ["Hide / Show GUI"] = "Ẩn / Hiện GUI", ["Change Key"] = "Đổi Key",
            ["Verify Key"] = "Xác minh Key", ["Enter key here..."] = "Nhập key ở đây...", ["Verifying..."] = "Đang xác minh...", ["Loading..."] = "Đang tải...",
        },
        ["th"] = {
            ["Enable"] = "เปิด", ["Disable"] = "ปิด", ["Enabled"] = "เปิดอยู่", ["Disabled"] = "ปิดอยู่",
            ["Toggle"] = "สลับ", ["Button"] = "ปุ่ม", ["Select"] = "เลือก", ["Selected"] = "เลือกแล้ว",
            ["Default"] = "ค่าเริ่มต้น", ["Settings"] = "ตั้งค่า", ["Options"] = "ตัวเลือก",
            ["Save"] = "บันทึก", ["Load"] = "โหลด", ["Reset"] = "รีเซ็ต", ["Close"] = "ปิด",
            ["Open"] = "เปิด", ["Cancel"] = "ยกเลิก", ["Confirm"] = "ยืนยัน", ["Delete"] = "ลบ",
            ["Copy"] = "คัดลอก", ["Refresh"] = "รีเฟรช", ["Search"] = "ค้นหา", ["Show"] = "แสดง", ["Hide"] = "ซ่อน",
            ["Start"] = "เริ่ม", ["Stop"] = "หยุด", ["Pause"] = "หยุดชั่วคราว", ["Resume"] = "ทำต่อ", ["Apply"] = "ใช้งาน",
            ["Upgrade"] = "อัปเกรด", ["Buy"] = "ซื้อ", ["Sell"] = "ขาย",
            ["Equip"] = "สวมใส่", ["Claim"] = "รับ", ["Teleport"] = "เทเลพอร์ต",
            ["Premium"] = "พรีเมียม", ["Free"] = "ฟรี", ["Locked"] = "ล็อค", ["Unlocked"] = "ปลดล็อค",
            ["Auto"] = "อัตโนมัติ", ["Farm"] = "ฟาร์ม", ["Fishing"] = "ตกปลา", ["Fish"] = "ปลา",
            ["Inventory"] = "กระเป๋า", ["Full"] = "เต็ม", ["Empty"] = "ว่าง",
            ["Boss"] = "บอส", ["Fight"] = "สู้", ["Battle"] = "การต่อสู้",
            ["Quest"] = "เควส", ["Daily"] = "รายวัน", ["Reward"] = "รางวัล", ["Rewards"] = "รางวัล",
            ["Level"] = "เลเวล", ["Experience"] = "ค่าประสบการณ์", ["Character"] = "ตัวละคร",
            ["Skill"] = "ทักษะ", ["Speed"] = "ความเร็ว", ["Power"] = "พลัง", ["Damage"] = "ความเสียหาย", ["Health"] = "พลังชีวิต",
            ["Walk"] = "เดิน", ["Jump"] = "กระโดด", ["Fly"] = "บิน",
            ["Player"] = "ผู้เล่น", ["Players"] = "ผู้เล่น", ["Server"] = "เซิร์ฟเวอร์",
            ["Normal"] = "ปกติ", ["Hard"] = "ยาก", ["Nightmare"] = "ฝันร้าย",
            ["Egg"] = "ไข่", ["Pet"] = "สัตว์เลี้ยง", ["Pets"] = "สัตว์เลี้ยง", ["Hatch"] = "ฟักไข่", ["Rebirth"] = "เกิดใหม่",
            ["Dungeon"] = "ดันเจี้ยน", ["Tower"] = "หอคอย", ["Round"] = "รอบ", ["Wave"] = "เวฟ",
            ["Potion"] = "ยา", ["Chest"] = "กล่องสมบัติ", ["Click"] = "คลิก", ["Collect"] = "เก็บ",
            ["Attack"] = "โจมตี", ["Defense"] = "ป้องกัน", ["Weapon"] = "อาวุธ",
            ["Gold"] = "ทอง", ["Gems"] = "อัญมณี", ["Energy"] = "พลังงาน",
            ["Team"] = "ทีม", ["Enemy"] = "ศัตรู", ["Target"] = "เป้าหมาย",
            ["Trade"] = "ค้าขาย", ["Market"] = "ตลาด", ["Rank"] = "อันดับ", ["Score"] = "คะแนน",
            ["Auto Farm"] = "ฟาร์มอัตโนมัติ", ["Auto Click"] = "คลิกอัตโนมัติ",
            ["Get Free Key"] = "รับคีย์ฟรี", ["Buy Premium"] = "ซื้อพรีเมียม", ["Buy with Robux"] = "ซื้อด้วย Robux",
            ["remaining"] = "เหลือ", ["seconds"] = "วินาที", ["minutes"] = "นาที",
            ["Hide / Show GUI"] = "ซ่อน / แสดง GUI", ["Change Key"] = "เปลี่ยนคีย์",
            ["Verify Key"] = "ตรวจสอบคีย์", ["Enter key here..."] = "ใส่คีย์ที่นี่...", ["Verifying..."] = "กำลังตรวจสอบ...", ["Loading..."] = "กำลังโหลด...",
        },
        ["id"] = {
            ["Enable"] = "Aktifkan", ["Disable"] = "Nonaktifkan", ["Enabled"] = "Aktif", ["Disabled"] = "Nonaktif",
            ["Toggle"] = "Alihkan", ["Button"] = "Tombol", ["Select"] = "Pilih", ["Selected"] = "Dipilih",
            ["Default"] = "Bawaan", ["Settings"] = "Pengaturan", ["Options"] = "Opsi",
            ["Save"] = "Simpan", ["Load"] = "Muat", ["Reset"] = "Atur Ulang", ["Close"] = "Tutup",
            ["Open"] = "Buka", ["Cancel"] = "Batal", ["Confirm"] = "Konfirmasi", ["Delete"] = "Hapus",
            ["Copy"] = "Salin", ["Refresh"] = "Segarkan", ["Search"] = "Cari", ["Show"] = "Tampilkan", ["Hide"] = "Sembunyikan",
            ["Start"] = "Mulai", ["Stop"] = "Berhenti", ["Pause"] = "Jeda", ["Resume"] = "Lanjut", ["Apply"] = "Terapkan",
            ["Upgrade"] = "Tingkatkan", ["Purchase"] = "Beli", ["Buy"] = "Beli", ["Sell"] = "Jual",
            ["Equip"] = "Pakai", ["Claim"] = "Klaim", ["Redeem"] = "Tukar",
            ["Teleport"] = "Teleportasi", ["Premium"] = "Premium", ["Free"] = "Gratis", ["Locked"] = "Terkunci", ["Unlocked"] = "Terbuka",
            ["Auto"] = "Otomatis", ["Farm"] = "Farm", ["Fishing"] = "Memancing", ["Fish"] = "Ikan", ["Rod"] = "Joran", ["Bait"] = "Umpan",
            ["Inventory"] = "Inventaris", ["Full"] = "Penuh", ["Empty"] = "Kosong",
            ["Boss"] = "Bos", ["Fight"] = "Pertarungan", ["Battle"] = "Pertempuran",
            ["Quest"] = "Misi", ["Daily"] = "Harian", ["Reward"] = "Hadiah", ["Rewards"] = "Hadiah",
            ["Level"] = "Level", ["Experience"] = "Pengalaman", ["Character"] = "Karakter",
            ["Skill"] = "Keahlian", ["Skills"] = "Keahlian", ["Speed"] = "Kecepatan", ["Power"] = "Kekuatan", ["Damage"] = "Kerusakan", ["Health"] = "Kesehatan",
            ["Walk"] = "Jalan", ["Jump"] = "Lompat", ["Fly"] = "Terbang", ["Sprint"] = "Lari",
            ["Player"] = "Pemain", ["Players"] = "Pemain", ["Server"] = "Server",
            ["Normal"] = "Normal", ["Hard"] = "Sulit", ["Nightmare"] = "Mimpi Buruk",
            ["Egg"] = "Telur", ["Pet"] = "Hewan", ["Pets"] = "Hewan", ["Hatch"] = "Menetas", ["Rebirth"] = "Kelahiran Kembali",
            ["Dungeon"] = "Penjara Bawah Tanah", ["Tower"] = "Menara", ["Round"] = "Ronde", ["Wave"] = "Gelombang",
            ["Potion"] = "Ramuan", ["Chest"] = "Peti", ["Click"] = "Klik", ["Collect"] = "Kumpulkan",
            ["Attack"] = "Serangan", ["Defense"] = "Pertahanan", ["Weapon"] = "Senjata",
            ["Gold"] = "Emas", ["Gems"] = "Permata", ["Energy"] = "Energi",
            ["Team"] = "Tim", ["Enemy"] = "Musuh", ["Target"] = "Target",
            ["Trade"] = "Perdagangan", ["Market"] = "Pasar", ["Rank"] = "Peringkat", ["Score"] = "Skor", ["Achievement"] = "Pencapaian",
            ["Auto Farm"] = "Farm Otomatis", ["Auto Click"] = "Klik Otomatis",
            ["Get Free Key"] = "Dapatkan Kunci Gratis", ["Buy Premium"] = "Beli Premium", ["Buy with Robux"] = "Beli dengan Robux",
            ["remaining"] = "tersisa", ["seconds"] = "detik", ["minutes"] = "menit",
            ["Hide / Show GUI"] = "Sembunyikan / Tampilkan GUI", ["Change Key"] = "Ganti Kunci",
            ["Verify Key"] = "Verifikasi Kunci", ["Enter key here..."] = "Masukkan kunci...", ["Verifying..."] = "Memverifikasi...", ["Loading..."] = "Memuat...",
        },
        ["it"] = {
            ["Enable"] = "Attiva", ["Disable"] = "Disattiva", ["Enabled"] = "Attivato", ["Disabled"] = "Disattivato",
            ["Toggle"] = "Alterna", ["Button"] = "Pulsante", ["Select"] = "Seleziona", ["Selected"] = "Selezionato",
            ["Default"] = "Predefinito", ["Settings"] = "Impostazioni", ["Options"] = "Opzioni",
            ["Save"] = "Salva", ["Load"] = "Carica", ["Reset"] = "Reimposta", ["Close"] = "Chiudi",
            ["Open"] = "Apri", ["Cancel"] = "Annulla", ["Confirm"] = "Conferma", ["Delete"] = "Elimina",
            ["Copy"] = "Copia", ["Refresh"] = "Aggiorna", ["Search"] = "Cerca", ["Show"] = "Mostra", ["Hide"] = "Nascondi",
            ["Start"] = "Avvia", ["Stop"] = "Ferma", ["Pause"] = "Pausa", ["Resume"] = "Riprendi", ["Apply"] = "Applica",
            ["Upgrade"] = "Migliora", ["Purchase"] = "Acquista", ["Buy"] = "Compra", ["Sell"] = "Vendi",
            ["Equip"] = "Equipaggia", ["Claim"] = "Riscuoti", ["Redeem"] = "Riscatta",
            ["Teleport"] = "Teletrasporto", ["Premium"] = "Premium", ["Free"] = "Gratis", ["Locked"] = "Bloccato", ["Unlocked"] = "Sbloccato",
            ["Auto"] = "Auto", ["Farm"] = "Farm", ["Fishing"] = "Pesca", ["Fish"] = "Pesce", ["Rod"] = "Canna", ["Bait"] = "Esca",
            ["Inventory"] = "Inventario", ["Full"] = "Pieno", ["Empty"] = "Vuoto",
            ["Boss"] = "Boss", ["Fight"] = "Combatti", ["Battle"] = "Battaglia",
            ["Quest"] = "Missione", ["Daily"] = "Giornaliero", ["Reward"] = "Ricompensa", ["Rewards"] = "Ricompense",
            ["Level"] = "Livello", ["Experience"] = "Esperienza", ["Character"] = "Personaggio",
            ["Skill"] = "Abilità", ["Skills"] = "Abilità", ["Speed"] = "Velocità", ["Power"] = "Potenza", ["Damage"] = "Danno", ["Health"] = "Salute",
            ["Walk"] = "Camminare", ["Jump"] = "Saltare", ["Fly"] = "Volare", ["Sprint"] = "Scattare",
            ["Player"] = "Giocatore", ["Players"] = "Giocatori", ["Server"] = "Server",
            ["Normal"] = "Normale", ["Hard"] = "Difficile", ["Nightmare"] = "Incubo",
            ["Egg"] = "Uovo", ["Eggs"] = "Uova", ["Pet"] = "Animale", ["Pets"] = "Animali",
            ["Hatch"] = "Schiudere", ["Rebirth"] = "Rinascita", ["Prestige"] = "Prestigio",
            ["Dungeon"] = "Prigione", ["Tower"] = "Torre", ["Round"] = "Round", ["Wave"] = "Ondata",
            ["Potion"] = "Pozione", ["Chest"] = "Forziere", ["Click"] = "Clic", ["Collect"] = "Raccogli",
            ["Attack"] = "Attacco", ["Defense"] = "Difesa", ["Armor"] = "Armatura", ["Weapon"] = "Arma", ["Sword"] = "Spada", ["Shield"] = "Scudo",
            ["Gold"] = "Oro", ["Gems"] = "Gemme", ["Diamonds"] = "Diamanti", ["Energy"] = "Energia",
            ["Team"] = "Squadra", ["Enemy"] = "Nemico", ["Target"] = "Bersaglio",
            ["Trade"] = "Commercio", ["Market"] = "Mercato", ["Rank"] = "Rango", ["Score"] = "Punteggio", ["Achievement"] = "Obiettivo",
            ["Auto Farm"] = "Farm Automatico", ["Auto Click"] = "Clic Automatico",
            ["Get Free Key"] = "Ottieni Chiave Gratis", ["Buy Premium"] = "Compra Premium", ["Buy with Robux"] = "Compra con Robux",
            ["remaining"] = "rimanente", ["seconds"] = "secondi", ["minutes"] = "minuti",
            ["Hide / Show GUI"] = "Nascondi / Mostra GUI", ["Change Key"] = "Cambia Chiave",
            ["Verify Key"] = "Verifica Chiave", ["Enter key here..."] = "Inserisci chiave...", ["Verifying..."] = "Verifica...", ["Loading..."] = "Caricamento...",
        },
        ["pl"] = {
            ["Enable"] = "Włącz", ["Disable"] = "Wyłącz", ["Enabled"] = "Włączono", ["Disabled"] = "Wyłączono",
            ["Toggle"] = "Przełącz", ["Button"] = "Przycisk", ["Select"] = "Wybierz", ["Selected"] = "Wybrano",
            ["Default"] = "Domyślne", ["Settings"] = "Ustawienia", ["Options"] = "Opcje",
            ["Save"] = "Zapisz", ["Load"] = "Wczytaj", ["Reset"] = "Resetuj", ["Close"] = "Zamknij",
            ["Open"] = "Otwórz", ["Cancel"] = "Anuluj", ["Confirm"] = "Potwierdź", ["Delete"] = "Usuń",
            ["Copy"] = "Kopiuj", ["Refresh"] = "Odśwież", ["Search"] = "Szukaj", ["Show"] = "Pokaż", ["Hide"] = "Ukryj",
            ["Start"] = "Start", ["Stop"] = "Stop", ["Pause"] = "Pauza", ["Resume"] = "Wznów", ["Apply"] = "Zastosuj",
            ["Upgrade"] = "Ulepsz", ["Purchase"] = "Kup", ["Buy"] = "Kup", ["Sell"] = "Sprzedaj",
            ["Equip"] = "Załóż", ["Claim"] = "Odbierz", ["Redeem"] = "Wymień",
            ["Teleport"] = "Teleportuj", ["Premium"] = "Premium", ["Free"] = "Darmowe", ["Locked"] = "Zablokowane", ["Unlocked"] = "Odblokowane",
            ["Auto"] = "Auto", ["Farm"] = "Farmienie", ["Fishing"] = "Wędkarstwo", ["Fish"] = "Ryba", ["Rod"] = "Wędka", ["Bait"] = "Przynęta",
            ["Inventory"] = "Ekwipunek", ["Full"] = "Pełny", ["Empty"] = "Pusty",
            ["Boss"] = "Boss", ["Fight"] = "Walka", ["Battle"] = "Bitwa",
            ["Quest"] = "Zadanie", ["Daily"] = "Dzienne", ["Reward"] = "Nagroda", ["Rewards"] = "Nagrody",
            ["Level"] = "Poziom", ["Experience"] = "Doświadczenie", ["Character"] = "Postać",
            ["Skill"] = "Umiejętność", ["Skills"] = "Umiejętności", ["Speed"] = "Szybkość", ["Power"] = "Moc", ["Damage"] = "Obrażenia", ["Health"] = "Zdrowie",
            ["Walk"] = "Chodzić", ["Jump"] = "Skoczyć", ["Fly"] = "Latać", ["Sprint"] = "Biegać",
            ["Player"] = "Gracz", ["Players"] = "Gracze", ["Server"] = "Serwer",
            ["Normal"] = "Normalny", ["Hard"] = "Trudny", ["Nightmare"] = "Koszmar",
            ["Egg"] = "Jajko", ["Eggs"] = "Jajka", ["Pet"] = "Zwierzak", ["Pets"] = "Zwierzaki",
            ["Hatch"] = "Wykluć", ["Rebirth"] = "Odrodzenie", ["Prestige"] = "Prestiż",
            ["Dungeon"] = "Loch", ["Tower"] = "Wieża", ["Round"] = "Runda", ["Wave"] = "Fala",
            ["Potion"] = "Mikstura", ["Chest"] = "Skrzynia", ["Click"] = "Kliknij", ["Collect"] = "Zbierz",
            ["Attack"] = "Atak", ["Defense"] = "Obrona", ["Weapon"] = "Broń", ["Sword"] = "Miecz", ["Shield"] = "Tarcza",
            ["Gold"] = "Złoto", ["Gems"] = "Klejnoty", ["Energy"] = "Energia",
            ["Team"] = "Drużyna", ["Enemy"] = "Wróg", ["Target"] = "Cel",
            ["Trade"] = "Handel", ["Market"] = "Rynek", ["Rank"] = "Ranga", ["Score"] = "Wynik", ["Achievement"] = "Osiągnięcie",
            ["Auto Farm"] = "Auto Farmienie", ["Auto Click"] = "Auto Klik",
            ["Get Free Key"] = "Zdobądź Darmowy Klucz", ["Buy Premium"] = "Kup Premium", ["Buy with Robux"] = "Kup za Robux",
            ["remaining"] = "pozostało", ["seconds"] = "sekund", ["minutes"] = "minut",
            ["Hide / Show GUI"] = "Ukryj / Pokaż GUI", ["Change Key"] = "Zmień Klucz",
            ["Verify Key"] = "Zweryfikuj Klucz", ["Enter key here..."] = "Wpisz klucz...", ["Verifying..."] = "Weryfikacja...", ["Loading..."] = "Ładowanie...",
        },
        ["ar"] = {
            ["Enable"] = "تفعيل", ["Disable"] = "تعطيل", ["Enabled"] = "مفعّل", ["Disabled"] = "معطّل",
            ["Toggle"] = "تبديل", ["Button"] = "زر", ["Select"] = "اختيار", ["Selected"] = "تم الاختيار",
            ["Default"] = "افتراضي", ["Settings"] = "إعدادات", ["Options"] = "خيارات",
            ["Save"] = "حفظ", ["Load"] = "تحميل", ["Reset"] = "إعادة تعيين", ["Close"] = "إغلاق",
            ["Open"] = "فتح", ["Cancel"] = "إلغاء", ["Confirm"] = "تأكيد", ["Delete"] = "حذف",
            ["Copy"] = "نسخ", ["Refresh"] = "تحديث", ["Search"] = "بحث", ["Show"] = "إظهار", ["Hide"] = "إخفاء",
            ["Start"] = "بدء", ["Stop"] = "إيقاف", ["Pause"] = "إيقاف مؤقت", ["Resume"] = "استئناف", ["Apply"] = "تطبيق",
            ["Upgrade"] = "ترقية", ["Purchase"] = "شراء", ["Buy"] = "شراء", ["Sell"] = "بيع",
            ["Equip"] = "تجهيز", ["Claim"] = "مطالبة", ["Redeem"] = "استبدال",
            ["Teleport"] = "انتقال", ["Premium"] = "مميز", ["Free"] = "مجاني", ["Locked"] = "مقفل", ["Unlocked"] = "مفتوح",
            ["Auto"] = "تلقائي", ["Farm"] = "فارم", ["Fishing"] = "صيد السمك", ["Fish"] = "سمكة",
            ["Inventory"] = "المخزون", ["Full"] = "ممتلئ", ["Empty"] = "فارغ",
            ["Boss"] = "الزعيم", ["Fight"] = "قتال", ["Battle"] = "معركة",
            ["Quest"] = "مهمة", ["Daily"] = "يومي", ["Reward"] = "مكافأة", ["Rewards"] = "مكافآت",
            ["Level"] = "مستوى", ["Experience"] = "خبرة", ["Character"] = "شخصية",
            ["Skill"] = "مهارة", ["Skills"] = "مهارات", ["Speed"] = "سرعة", ["Power"] = "قوة", ["Damage"] = "ضرر", ["Health"] = "صحة",
            ["Walk"] = "مشي", ["Jump"] = "قفز", ["Fly"] = "طيران",
            ["Player"] = "لاعب", ["Players"] = "لاعبون", ["Server"] = "خادم",
            ["Normal"] = "عادي", ["Hard"] = "صعب", ["Nightmare"] = "كابوس",
            ["Egg"] = "بيضة", ["Pet"] = "حيوان أليف", ["Pets"] = "حيوانات أليفة", ["Hatch"] = "فقس",
            ["Dungeon"] = "زنزانة", ["Tower"] = "برج", ["Round"] = "جولة", ["Wave"] = "موجة",
            ["Potion"] = "جرعة", ["Chest"] = "صندوق", ["Click"] = "نقر", ["Collect"] = "جمع",
            ["Attack"] = "هجوم", ["Defense"] = "دفاع", ["Weapon"] = "سلاح",
            ["Gold"] = "ذهب", ["Gems"] = "أحجار كريمة", ["Energy"] = "طاقة",
            ["Team"] = "فريق", ["Enemy"] = "عدو", ["Target"] = "هدف",
            ["Trade"] = "تجارة", ["Market"] = "سوق", ["Rank"] = "رتبة", ["Score"] = "نقاط", ["Achievement"] = "إنجاز",
            ["Auto Farm"] = "فارم تلقائي", ["Auto Click"] = "نقر تلقائي",
            ["Get Free Key"] = "احصل على مفتاح مجاني", ["Buy Premium"] = "شراء مميز", ["Buy with Robux"] = "شراء بـ Robux",
            ["remaining"] = "متبقي", ["seconds"] = "ثوان", ["minutes"] = "دقائق",
            ["Hide / Show GUI"] = "إخفاء / إظهار الواجهة", ["Change Key"] = "تغيير المفتاح",
            ["Verify Key"] = "التحقق من المفتاح", ["Enter key here..."] = "أدخل المفتاح هنا...", ["Verifying..."] = "جاري التحقق...", ["Loading..."] = "جاري التحميل...",
        },
        ["hi"] = {
            ["Enable"] = "सक्रिय", ["Disable"] = "निष्क्रिय", ["Enabled"] = "सक्रिय", ["Disabled"] = "निष्क्रिय",
            ["Toggle"] = "टॉगल", ["Button"] = "बटन", ["Select"] = "चुनें", ["Selected"] = "चयनित",
            ["Default"] = "डिफ़ॉल्ट", ["Settings"] = "सेटिंग्स", ["Options"] = "विकल्प",
            ["Save"] = "सहेजें", ["Load"] = "लोड", ["Reset"] = "रीसेट", ["Close"] = "बंद करें",
            ["Open"] = "खोलें", ["Cancel"] = "रद्द", ["Confirm"] = "पुष्टि", ["Delete"] = "हटाएं",
            ["Copy"] = "कॉपी", ["Refresh"] = "रिफ्रेश", ["Search"] = "खोजें", ["Show"] = "दिखाएं", ["Hide"] = "छिपाएं",
            ["Start"] = "शुरू", ["Stop"] = "रोकें", ["Pause"] = "रुकें", ["Resume"] = "जारी रखें", ["Apply"] = "लागू करें",
            ["Upgrade"] = "अपग्रेड", ["Buy"] = "खरीदें", ["Sell"] = "बेचें",
            ["Equip"] = "पहनें", ["Claim"] = "प्राप्त करें", ["Teleport"] = "टेलीपोर्ट",
            ["Premium"] = "प्रीमियम", ["Free"] = "मुफ्त", ["Locked"] = "लॉक", ["Unlocked"] = "अनलॉक",
            ["Auto"] = "ऑटो", ["Farm"] = "फार्म", ["Fishing"] = "मछली पकड़ना", ["Fish"] = "मछली",
            ["Inventory"] = "इन्वेंटरी", ["Full"] = "भरा", ["Empty"] = "खाली",
            ["Boss"] = "बॉस", ["Fight"] = "लड़ाई", ["Battle"] = "युद्ध",
            ["Quest"] = "क्वेस्ट", ["Daily"] = "दैनिक", ["Reward"] = "इनाम", ["Rewards"] = "इनाम",
            ["Level"] = "लेवल", ["Experience"] = "अनुभव", ["Character"] = "पात्र",
            ["Skill"] = "कौशल", ["Speed"] = "गति", ["Power"] = "शक्ति", ["Damage"] = "नुकसान", ["Health"] = "स्वास्थ्य",
            ["Walk"] = "चलना", ["Jump"] = "कूदना", ["Fly"] = "उड़ना",
            ["Player"] = "खिलाड़ी", ["Players"] = "खिलाड़ी", ["Server"] = "सर्वर",
            ["Normal"] = "सामान्य", ["Hard"] = "कठिन", ["Nightmare"] = "बुरा सपना",
            ["Egg"] = "अंडा", ["Pet"] = "पालतू", ["Pets"] = "पालतू जानवर", ["Hatch"] = "हैच",
            ["Dungeon"] = "कालकोठरी", ["Tower"] = "टावर", ["Round"] = "राउंड", ["Wave"] = "लहर",
            ["Click"] = "क्लिक", ["Collect"] = "इकट्ठा करें",
            ["Attack"] = "हमला", ["Defense"] = "रक्षा", ["Weapon"] = "हथियार",
            ["Gold"] = "सोना", ["Gems"] = "रत्न", ["Energy"] = "ऊर्जा",
            ["Team"] = "टीम", ["Enemy"] = "दुश्मन", ["Target"] = "लक्ष्य",
            ["Trade"] = "व्यापार", ["Market"] = "बाज़ार", ["Rank"] = "रैंक", ["Score"] = "अंक",
            ["Auto Farm"] = "ऑटो फार्म", ["Auto Click"] = "ऑटो क्लिक",
            ["Get Free Key"] = "मुफ्त कुंजी प्राप्त करें", ["Buy Premium"] = "प्रीमियम खरीदें", ["Buy with Robux"] = "Robux से खरीदें",
            ["remaining"] = "शेष", ["seconds"] = "सेकंड", ["minutes"] = "मिनट",
            ["Hide / Show GUI"] = "GUI छिपाएं / दिखाएं", ["Change Key"] = "कुंजी बदलें",
            ["Verify Key"] = "कुंजी सत्यापित करें", ["Enter key here..."] = "यहां कुंजी दर्ज करें...", ["Verifying..."] = "सत्यापित हो रहा है...", ["Loading..."] = "लोड हो रहा है...",
        },
        ["ms"] = {
            ["Enable"] = "Aktifkan", ["Disable"] = "Nyahaktif", ["Enabled"] = "Aktif", ["Disabled"] = "Tidak Aktif",
            ["Toggle"] = "Togol", ["Select"] = "Pilih", ["Save"] = "Simpan", ["Close"] = "Tutup",
            ["Cancel"] = "Batal", ["Confirm"] = "Sahkan", ["Delete"] = "Padam",
            ["Start"] = "Mula", ["Stop"] = "Berhenti", ["Buy"] = "Beli", ["Sell"] = "Jual",
            ["Equip"] = "Pakai", ["Claim"] = "Tuntut", ["Teleport"] = "Teleportasi",
            ["Premium"] = "Premium", ["Free"] = "Percuma",
            ["Auto"] = "Auto", ["Farm"] = "Farm", ["Fishing"] = "Memancing", ["Fish"] = "Ikan",
            ["Inventory"] = "Inventori", ["Boss"] = "Bos", ["Fight"] = "Lawan", ["Quest"] = "Misi", ["Daily"] = "Harian",
            ["Reward"] = "Ganjaran", ["Level"] = "Tahap", ["Player"] = "Pemain", ["Server"] = "Pelayan",
            ["Normal"] = "Normal", ["Hard"] = "Sukar", ["Nightmare"] = "Mimpi Ngeri",
            ["Auto Farm"] = "Farm Auto", ["Get Free Key"] = "Dapatkan Kunci Percuma", ["Buy with Robux"] = "Beli dengan Robux",
            ["Hide / Show GUI"] = "Sembunyi / Tunjuk GUI", ["Change Key"] = "Tukar Kunci",
            ["Verify Key"] = "Sahkan Kunci", ["Enter key here..."] = "Masukkan kunci...", ["Verifying..."] = "Mengesahkan...", ["Loading..."] = "Memuatkan...",
        },
        ["tl"] = {
            ["Enable"] = "I-on", ["Disable"] = "I-off", ["Enabled"] = "Naka-on", ["Disabled"] = "Naka-off",
            ["Toggle"] = "I-toggle", ["Select"] = "Pumili", ["Save"] = "I-save", ["Close"] = "Isara",
            ["Cancel"] = "Kanselahin", ["Confirm"] = "Kumpirmahin", ["Delete"] = "Burahin",
            ["Start"] = "Simulan", ["Stop"] = "Itigil", ["Buy"] = "Bumili", ["Sell"] = "Ibenta",
            ["Equip"] = "I-equip", ["Claim"] = "Kunin", ["Teleport"] = "Teleport",
            ["Premium"] = "Premium", ["Free"] = "Libre",
            ["Auto"] = "Auto", ["Farm"] = "Farm", ["Fishing"] = "Pangingisda", ["Fish"] = "Isda",
            ["Inventory"] = "Imbentaryo", ["Boss"] = "Boss", ["Fight"] = "Laban", ["Quest"] = "Misyon", ["Daily"] = "Araw-araw",
            ["Reward"] = "Gantimpala", ["Level"] = "Level", ["Player"] = "Manlalaro", ["Server"] = "Server",
            ["Normal"] = "Normal", ["Hard"] = "Mahirap", ["Nightmare"] = "Bangungot",
            ["Auto Farm"] = "Auto Farm", ["Get Free Key"] = "Kumuha ng Libreng Key", ["Buy with Robux"] = "Bumili gamit Robux",
            ["Hide / Show GUI"] = "Itago / Ipakita GUI", ["Change Key"] = "Palitan Key",
            ["Verify Key"] = "I-verify Key", ["Enter key here..."] = "Ilagay key dito...", ["Verifying..."] = "Nag-ve-verify...", ["Loading..."] = "Naglo-load...",
        },
    }

    local _sortedKeys = {}
    local function _rebuildSorted(lang)
        local dict = dicts[lang]
        if not dict then return end
        local keys = {}
        for k in pairs(dict) do keys[#keys+1] = k end
        table.sort(keys, function(a, b) return #a > #b end)
        _sortedKeys[lang] = keys
    end
    for lang in pairs(dicts) do _rebuildSorted(lang) end

    local _cache = {}

    function Aurora:Translate(text)
        if not Aurora.AutoTranslate then return text end
        if type(text) ~= "string" or text == "" then return text end
        local lang = detectLocale()
        if lang == "en" then return text end
        local dict = dicts[lang]
        if not dict then return text end

        local cacheKey = lang .. "|" .. text
        if _cache[cacheKey] then return _cache[cacheKey] end

        local fullMatch = dict[text]
        if fullMatch then
            _cache[cacheKey] = fullMatch
            return fullMatch
        end

        local result = text
        local sorted = _sortedKeys[lang]
        if sorted then
            for _, key in ipairs(sorted) do
                if result:find(key, 1, true) then
                    local escaped = key:gsub("([%(%)%.%%%+%-%*%?%[%]%^%$])", "%%%1")
                    local pattern = "(%f[%w])" .. escaped .. "(%f[^%w])"
                    local replaced = result:gsub(pattern, "%1" .. dict[key] .. "%2")
                    if replaced == result then
                        result = result:gsub(escaped, dict[key])
                    else
                        result = replaced
                    end
                end
            end
        end

        _cache[cacheKey] = result
        return result
    end

    function Aurora:TranslateList(list)
        if not Aurora.AutoTranslate then return list end
        if type(list) ~= "table" then return list end
        local lang = detectLocale()
        if lang == "en" then return list end
        local out = {}
        for i, v in ipairs(list) do
            out[i] = Aurora:Translate(tostring(v))
        end
        return out
    end

    function Aurora:SetLocale(locale)
        Aurora._userLocale = string.lower(string.sub(locale, 1, 2))
        _cache = {}
    end

    function Aurora:AddTranslations(lang, entries)
        lang = string.lower(string.sub(lang, 1, 2))
        if not dicts[lang] then dicts[lang] = {} end
        for k, v in pairs(entries) do
            dicts[lang][k] = v
        end
        local keys = {}
        for k in pairs(dicts[lang]) do table.insert(keys, k) end
        table.sort(keys, function(a, b) return #a > #b end)
        _sortedKeys[lang] = keys
        _cache = {}
    end

    function Aurora:GetLocale()
        return detectLocale()
    end

    local _origAddToggle = Section.AddToggle
    function Section:AddToggle(id, cfg)
        if cfg and Aurora.AutoTranslate then
            cfg.Title = Aurora:Translate(cfg.Title or "Toggle")
            if cfg.Description then cfg.Description = Aurora:Translate(cfg.Description) end
            if cfg.Desc then cfg.Desc = Aurora:Translate(cfg.Desc) end
            if cfg.Tooltip then cfg.Tooltip = Aurora:Translate(cfg.Tooltip) end
        end
        return _origAddToggle(self, id, cfg)
    end

    local _origAddButton = Section.AddButton
    function Section:AddButton(cfg)
        if cfg and Aurora.AutoTranslate then
            cfg.Title = Aurora:Translate(cfg.Title or "Button")
            if cfg.Description then cfg.Description = Aurora:Translate(cfg.Description) end
            if cfg.Desc then cfg.Desc = Aurora:Translate(cfg.Desc) end
            if cfg.Tooltip then cfg.Tooltip = Aurora:Translate(cfg.Tooltip) end
        end
        return _origAddButton(self, cfg)
    end

    local _origAddSlider = Section.AddSlider
    function Section:AddSlider(id, cfg)
        if cfg and Aurora.AutoTranslate then
            cfg.Title = Aurora:Translate(cfg.Title or "Slider")
            if cfg.Description then cfg.Description = Aurora:Translate(cfg.Description) end
            if cfg.Suffix then cfg.Suffix = Aurora:Translate(cfg.Suffix) end
            if cfg.Tooltip then cfg.Tooltip = Aurora:Translate(cfg.Tooltip) end
        end
        return _origAddSlider(self, id, cfg)
    end

    local _origAddDropdown = Section.AddDropdown
    function Section:AddDropdown(id, cfg)
        if cfg and Aurora.AutoTranslate then
            cfg.Title = Aurora:Translate(cfg.Title or "Dropdown")
            if cfg.Description then cfg.Description = Aurora:Translate(cfg.Description) end
            if cfg.Tooltip then cfg.Tooltip = Aurora:Translate(cfg.Tooltip) end
        end
        return _origAddDropdown(self, id, cfg)
    end

    local _origAddInput = Section.AddInput
    function Section:AddInput(id, cfg)
        if cfg and Aurora.AutoTranslate then
            cfg.Title = Aurora:Translate(cfg.Title or "Input")
            if cfg.Description then cfg.Description = Aurora:Translate(cfg.Description) end
            if cfg.Placeholder then cfg.Placeholder = Aurora:Translate(cfg.Placeholder) end
            if cfg.Tooltip then cfg.Tooltip = Aurora:Translate(cfg.Tooltip) end
        end
        return _origAddInput(self, id, cfg)
    end

    local _origAddLabel = Section.AddLabel
    function Section:AddLabel(id, text)
        if text and Aurora.AutoTranslate then
            text = Aurora:Translate(text)
        end
        return _origAddLabel(self, id, text)
    end

    local _origAddLiveStat = Section.AddLiveStat
    function Section:AddLiveStat(id, cfg)
        if cfg and Aurora.AutoTranslate then
            cfg.Title = Aurora:Translate(cfg.Title or "Stat")
        end
        return _origAddLiveStat(self, id, cfg)
    end

    local _origColumnAddSection = Column.AddSection
    function Column:AddSection(title, cfg)
        if title and Aurora.AutoTranslate then
            title = Aurora:Translate(title)
        end
        return _origColumnAddSection(self, title, cfg)
    end

    local _origAddAlert = Section.AddAlert
    if _origAddAlert then
        function Section:AddAlert(cfg)
            if cfg and Aurora.AutoTranslate then
                if cfg.Title then cfg.Title = Aurora:Translate(cfg.Title) end
                if cfg.Content then cfg.Content = Aurora:Translate(cfg.Content) end
            end
            return _origAddAlert(self, cfg)
        end
    end

    local _origAddParagraph = Section.AddParagraph
    if _origAddParagraph then
        function Section:AddParagraph(cfg)
            if cfg and Aurora.AutoTranslate then
                if cfg.Title then cfg.Title = Aurora:Translate(cfg.Title) end
                if cfg.Content then cfg.Content = Aurora:Translate(cfg.Content) end
            end
            return _origAddParagraph(self, cfg)
        end
    end

    local _origAddSeparator = Section.AddSeparator
    if _origAddSeparator then
        function Section:AddSeparator(text)
            if text and Aurora.AutoTranslate then
                text = Aurora:Translate(text)
            end
            return _origAddSeparator(self, text)
        end
    end

    local _origNotify = Aurora.Notify
    function Aurora:Notify(cfg)
        if cfg and Aurora.AutoTranslate then
            if cfg.Title then cfg.Title = Aurora:Translate(cfg.Title) end
            if cfg.Content then cfg.Content = Aurora:Translate(cfg.Content) end
        end
        return _origNotify(self, cfg)
    end

    local _origConfirm = Aurora.Confirm
    if _origConfirm then
        function Aurora:Confirm(cfg)
            if cfg and Aurora.AutoTranslate then
                if cfg.Title then cfg.Title = Aurora:Translate(cfg.Title) end
                if cfg.Content then cfg.Content = Aurora:Translate(cfg.Content) end
                if cfg.ConfirmText then cfg.ConfirmText = Aurora:Translate(cfg.ConfirmText) end
                if cfg.CancelText then cfg.CancelText = Aurora:Translate(cfg.CancelText) end
            end
            return _origConfirm(self, cfg)
        end
    end

    local _origCreateCompactWindow = Aurora.CreateCompactWindow
    if _origCreateCompactWindow then
        function Aurora:CreateCompactWindow(cfg)
            local win = _origCreateCompactWindow(self, cfg)
            if win and win.AddSection and Aurora.AutoTranslate then
                local _origWinAddSection = win.AddSection
                function win:AddSection(title, scfg)
                    if title and Aurora.AutoTranslate then
                        title = Aurora:Translate(title)
                    end
                    return _origWinAddSection(self, title, scfg)
                end
            end
            return win
        end
    end

    local _origCreateWindow = Aurora.CreateWindow
    function Aurora:CreateWindow(cfg)
        local win = _origCreateWindow(self, cfg)
        if win and Aurora.AutoTranslate then
            if win.AddTab then
                local _origWinAddTab = win.AddTab
                function win:AddTab(tcfg, parentContainer)
                    if tcfg and tcfg.Title and Aurora.AutoTranslate then
                        tcfg.Title = Aurora:Translate(tcfg.Title)
                    end
                    return _origWinAddTab(self, tcfg, parentContainer)
                end
            end
            if win.AddCategory then
                local _origWinAddCategory = win.AddCategory
                function win:AddCategory(title, icon)
                    if title and Aurora.AutoTranslate then
                        title = Aurora:Translate(title)
                    end
                    return _origWinAddCategory(self, title, icon)
                end
            end
        end
        return win
    end
end

return Aurora
