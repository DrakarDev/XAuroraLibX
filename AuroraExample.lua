--[[
================================================================================
    AuroraLib v4.5 — Complete Booga Booga Example
    Ready to execute in any Roblox executor!
    
    Demonstrates:
    - Grab-and-drag Edge Resizing
    - SaveManager (Configuration Saving, Loading, Autoloading)
    - Game-specific isolated configurations
    - Online cloud sharing via keyless kvdb.io buckets
    - Clipboard backup export/import tools
    - Horizontal Scrollable SubTabs (with sliding underline animation)
    - Dynamic RGB/Chroma Theme and preset options
    - Progressive lazy rendering by default
================================================================================
]]

-- NOTE FOR LOCAL TESTING:
-- Attempts to load the local updated library file from the workspace folder first.
-- Falls back to GitHub if the local file is not present.
local Aurora
local ok, res = pcall(function()
    return loadstring(readfile("AuroraLibraryReal.lua"))()
end)
if ok and type(res) == "table" then
    Aurora = res
else
    Aurora = loadstring(game:HttpGet("https://raw.githubusercontent.com/DrakarDev/XAuroraLibX/refs/heads/main/AuroraLibrary.lua"))()
end

-- 1. KEY SYSTEM VERIFICATION (NEW FEATURE)
-- Block script load until the user enters a valid license key
local keyVerified = false
Aurora.KeySystem.new({
    Title = "Aurora Verification",
    SubTitle = "License Verification Required",
    Note = "Get your free license key from our Discord server. Keys update every 24 hours!",
    Keys = {"AuroraKey2026", "DevKey"},       -- Local valid keys list
    KeyLink = "https://discord.gg/auroralib", -- Get key copy link
    SaveKey = true,                           -- Save verified key to cache
    FileName = "AuroraLicense_Cache.txt",     -- Cached key file name
    OnSuccess = function()
        keyVerified = true
    end
})

-- Wait for validation success
repeat task.wait(0.2) until keyVerified

-- 2. CUSTOM THEME REGISTRATION
-- Register a custom neon amethyst theme programmatically
Aurora:CreateTheme("CyberGlow", {
    Background   = Color3.fromRGB(15, 10, 25),
    Sidebar      = Color3.fromRGB(18, 12, 30),
    TopBar       = Color3.fromRGB(18, 12, 30),
    Element      = Color3.fromRGB(28, 20, 45),
    ElementHover = Color3.fromRGB(38, 28, 60),
    Accent       = Color3.fromRGB(0, 255, 200),
    AccentDim    = Color3.fromRGB(10, 50, 45),
    Text         = Color3.fromRGB(240, 255, 250),
    SubText      = Color3.fromRGB(150, 165, 180),
    Border       = Color3.fromRGB(50, 35, 75),
    Scrollbar    = Color3.fromRGB(70, 50, 100),
    ToggleOff    = Color3.fromRGB(35, 25, 55),
    ToggleOn     = Color3.fromRGB(0, 255, 200),
    SliderTrack  = Color3.fromRGB(30, 20, 45),
    SliderFill   = Color3.fromRGB(0, 255, 200),
    InputBG      = Color3.fromRGB(20, 15, 35),
    NotifBG      = Color3.fromRGB(20, 15, 35),
    TabActive    = Color3.fromRGB(240, 255, 250),
    TabInactive  = Color3.fromRGB(130, 115, 150),
    AlertInfo    = Color3.fromRGB(0, 162, 255),
    AlertWarn    = Color3.fromRGB(235, 160, 45),
    AlertError   = Color3.fromRGB(230, 60, 60),
    AlertSuccess = Color3.fromRGB(0, 255, 200),
    IconColor    = Color3.fromRGB(200, 240, 230),
})

-- 2. WINDOW INITIALIZATION
local Window = Aurora:CreateWindow({
    Title       = "Aurora Premium",
    SubTitle    = "Booga Booga Reborn Edition",
    Theme       = "Dark",
    Size        = UDim2.fromOffset(800, 560),
    MinimizeKey = Enum.KeyCode.LeftShift, -- PC only: keyboard shortcut to show/hide
    Acrylic     = true,                  -- Enables the premium glass/acrylic blur background
    -- Mobile: FAB button and pill float buttons are created automatically on touch devices
    LazyLoad    = true,                  -- Enables progressive rendering (default)
    DelayPerElement = 0.01,
    DelayPerSection = 0.03,
    DelayPerTab     = 0.08,
    FadeIn      = true,
})

-- 3. HUD OVERLAYS INITIALIZATION
local WatermarkObj = Aurora:Watermark({ Enabled = true, Title = "Aurora Premium" })
local KeybindListObj = Aurora:KeybindList({ Enabled = true })

-- Create draggable HUD monitor panel (NEW FEATURE)
local HUDObj = Aurora:CreateHUD({ Title = "Script Status Monitor", Width = 220 })
HUDObj:SetItem("Status", "Idle")
HUDObj:SetItem("Activity", "None")
HUDObj:SetItem("FPS", "60")
HUDObj:SetItem("Ping", "0ms")

-- Live update FPS/Ping inside HUD
task.spawn(function()
    local runService = game:GetService("RunService")
    local stats = game:GetService("Stats")
    while task.wait(1) do
        local fps = math.floor(1 / runService.RenderStepped:Wait())
        local ping = 0
        pcall(function()
            ping = math.floor(stats.Network.ServerStatsItem["Data Ping"]:GetValue())
        end)
        HUDObj:SetItem("FPS", tostring(fps))
        HUDObj:SetItem("Ping", tostring(ping) .. "ms")
    end
end)

-- 4. CATEGORIES
local CatHome = Window:AddCategory("Homepage")
local CatGame = Window:AddCategory("Booga Booga")
local CatUI   = Window:AddCategory("UI Settings")

-- 5. TABS
local HomeTab       = CatHome:AddTab({ Title="Welcome",    Icon="solar/home-bold" })
local InfoTab       = CatHome:AddTab({ Title="Info & News", Icon="solar/document-bold" })

local BoogaTab      = CatGame:AddTab({ Title="Main Features", Icon="solar/danger-bold" })
local VisualsTab    = CatGame:AddTab({ Title="Visuals & ESP", Icon="solar/eye-bold" })

local UiSettingsTab = CatUI:AddTab({ Title="Interface Settings", Icon="solar/settings-bold" })
local TestTab       = CatUI:AddTab({ Title="Testing & Debug", Icon="solar/bug-bold" })

-- ================================================================================
--  WELCOME TAB (Showcasing New Elements: Images, Spaces, Code Blocks, Audio)
-- ================================================================================
local HomeLeft, HomeRight = HomeTab:AddColumns()

-- Left Column: Hello & Controls
local SecWelcome = HomeLeft:AddSection("Welcome to Aurora")
SecWelcome:AddParagraph({
    Title = "AuroraLib Premium",
    Content = "The next-generation UI library for Roblox. Fully supports edge-dragging to resize from any side, native local and cloud configuration sharing, and progressive rendering."
})
SecWelcome:AddSpace(8)
local MyLabel = SecWelcome:AddLabel("StatusLabel", "System Status: Operating normally")
SecWelcome:AddSpace(8)

SecWelcome:AddButton({
    Title = "Launch Test Dialog",
    Icon = "solar/info-circle-bold",
    Callback = function()
        Window:Dialog({
            Title = "Premium Modal Dialog",
            Content = "This is a premium modal popup block that stays centered and overlays the script menu. You can configure multiple callback buttons.",
            Buttons = {
                {
                    Title = "Cancel",
                    Callback = function()
                        MyLabel:SetText("System Status: Dialog canceled")
                    end
                },
                {
                    Title = "Confirm Action",
                    Callback = function()
                        MyLabel:SetText("System Status: Action Confirmed at " .. os.date("%X"))
                    end
                }
            }
        })
    end
})

SecWelcome:AddSeparator("HUD & OVERLAY CONTROLS")

local WatermarkTgl = SecWelcome:AddToggle("WatermarkTgl", {
    Title = "Enable Stats Watermark",
    Default = true,
    Tooltip = "Toggle the real-time HUD stats watermark overlay.",
    Callback = function(v)
        Aurora:Watermark({ Enabled = v, Title = "Aurora Premium" })
    end
})

local KeybindListTgl = SecWelcome:AddToggle("KeybindListTgl", {
    Title = "Enable Keybind List Overlay",
    Default = true,
    Tooltip = "Toggle the draggable active keybinds list overlay.",
    Callback = function(v)
        Aurora:KeybindList({ Enabled = v })
    end
})

local HUDTgl = SecWelcome:AddToggle("HUDTgl", {
    Title = "Enable Stats HUD Monitor",
    Default = true,
    Tooltip = "Toggle the draggable script metrics HUD panel.",
    Callback = function(v)
        HUDObj:Toggle(v)
    end
})

SecWelcome:AddSeparator("INTERACTIVE DEMOS")

local TestInput = SecWelcome:AddInput("TestInput", {
    Title = "Custom Text Status",
    Placeholder = "Enter status note...",
    Tooltip = "Type anything here to dynamically update the status label above.",
    Callback = function(v)
        MyLabel:SetText("System Status: " .. v)
    end
})

local DemoProgress = SecWelcome:AddProgressBar("DemoProgressBar", {
    Title = "Simulated Task Progress"
})
DemoProgress:SetProgress(25)

SecWelcome:AddButton({
    Title = "Run Progress Simulation",
    Icon = "solar/play-bold",
    Callback = function()
        task.spawn(function()
            for i = 0, 100, 5 do
                DemoProgress:SetProgress(i)
                HUDObj:SetItem("Status", i == 100 and "Idle" or "Processing...")
                HUDObj:SetItem("Activity", string.format("Task Run (%d%%)", i))
                task.wait(0.08)
            end
            task.wait(1)
            HUDObj:SetItem("Activity", "None")
        end)
    end
})

local TestKeybind = SecWelcome:AddKeybind("TestKeybind", {
    Title = "Standalone Keybind Trigger",
    Default = Enum.KeyCode.H,
    Tooltip = "Press this hotkey or bind it to trigger a custom alert notification.",
    Callback = function(key)
        Aurora:Notify({
            Title = "Keybind Triggered",
            Content = "You pressed the key: " .. tostring(key.Name or key),
            Type = "Info",
            Duration = 3
        })
    end
})

local StandaloneCP = SecWelcome:AddColorpicker("StandaloneCPDemo", {
    Title = "UI Highlight Color",
    Default = Color3.fromRGB(0, 255, 200),
    Tooltip = "Choose a highlight color for custom visual elements.",
    Callback = function(color)
        MyLabel:SetText(string.format("Highlight Color set to RGB(%d, %d, %d)", math.floor(color.R*255), math.floor(color.G*255), math.floor(color.B*255)))
    end
})

local ComboToggle = SecWelcome:AddToggle("ComboToggleDemo", {
    Title = "Auto-Farm Resources (Combo)",
    Default = false,
    Tooltip = "Showcase of a toggle with both inline keybind and colorpicker.",
    Keybind = {
        Default = Enum.KeyCode.K,
        Callback = function(key)
            MyLabel:SetText("Combo Keybind changed to: " .. tostring(key.Name or key))
        end
    },
    Colorpicker = {
        Default = Color3.fromRGB(220, 55, 55),
        Callback = function(color)
            MyLabel:SetText(string.format("Combo Color set to RGB(%d, %d, %d)", math.floor(color.R*255), math.floor(color.G*255), math.floor(color.B*255)))
        end
    },
    Callback = function(v)
        MyLabel:SetText("Auto-Farm Resource state: " .. (v and "ENABLED" or "DISABLED"))
    end
})

local MultiDropdown = SecWelcome:AddDropdown("MultiDropdownDemo", {
    Title = "Filter Targets (Multi-Select)",
    Tooltip = "Select multiple target filters for visual indicators.",
    Values = { "Enemies", "Friendlies", "NPCs", "Items", "Vehicles" },
    Default = { "Enemies", "NPCs" },
    Multi = true,
    Callback = function(tbl)
        local selected = {}
        for k, v in pairs(tbl) do
            if v then table.insert(selected, k) end
        end
        MyLabel:SetText("Selected targets: " .. (#selected > 0 and table.concat(selected, ", ") or "None"))
    end
})

SecWelcome:AddAlert({
    Title = "Progressive Rendering Loaded",
    Content = "All GUI elements, tabs, and sections have loaded sequentially with smooth fade-in animations.",
    Type = "Success"
})

SecWelcome:AddSeparator("DEVELOPER ZONE")

SecWelcome:AddCode("LoadStringCode", {
    Title = "How to run AuroraLib",
    Code = 'local Aurora = loadstring(game:HttpGet("https://raw.githubusercontent.com/DrakarDev/XAuroraLibX/refs/heads/main/AuroraLibrary.lua"))()'
})

local SecNotifDemo = HomeLeft:AddSection("Notification Showcase")
SecNotifDemo:AddParagraph({
    Title = "Interactive & Actionable Notifications",
    Content = "Test our upgraded notification system featuring spring bouncy entries, custom sound presets, automatic card collapsing, inline inputs, and dynamic updates."
})

SecNotifDemo:AddButton({
    Title = "Trigger Success Alert (Actionable)",
    Icon = "solar/check-circle-bold",
    Callback = function()
        Aurora:Notify({
            Title = "<b>Action Required</b>",
            Content = "Data synchronization complete. Proceed with execution?",
            Type = "Success",
            Duration = 6,
            Buttons = {
                {
                    Title = "Confirm",
                    Callback = function()
                        MyLabel:SetText("System Status: Synchronized successfully at " .. os.date("%X"))
                    end
                },
                {
                    Title = "Dismiss"
                }
            }
        })
    end
})

SecNotifDemo:AddButton({
    Title = "Trigger Dynamic Progress (Manual Update)",
    Icon = "solar/download-bold",
    Callback = function()
        local notif = Aurora:Notify({
            Title = "Assets Downloading",
            Content = "Initializing assets streaming...",
            Type = "Info",
            Duration = 0,
            PlaySound = true
        })
        
        task.spawn(function()
            for i = 1, 10 do
                task.wait(0.3)
                notif:SetProgress(i / 10)
                notif:Update({
                    Content = string.format("Streaming assets packs... (%d%%)", i * 10)
                })
            end
            task.wait(0.2)
            notif:Update({
                Title = "Download Completed",
                Content = "All assets successfully loaded into workspace cache.",
                Type = "Success",
                Duration = 4,
                Buttons = {
                    {
                        Title = "Sweet!"
                    }
                }
            })
        end)
    end
})

SecNotifDemo:AddButton({
    Title = "Trigger Key Validation (Inline Input)",
    Icon = "solar/key-bold",
    Callback = function()
        Aurora:Notify({
            Title = "Enter Access Key",
            Content = "Please type the security authorization key to unlock Premium exploits (Key is AURORA2026).",
            Type = "Warning",
            Duration = 0,
            Input = true,
            InputPlaceholder = "Enter key code here...",
            InputCallback = function(keyVal)
                if keyVal == "AURORA2026" or keyVal == "admin" then
                    Window:Dialog({
                        Title = "Premium Unlocked",
                        Content = "Access key validated successfully! All developer features are now enabled.",
                        Buttons = {
                            { Title = "Awesome", Callback = function() end }
                        }
                    })
                    MyLabel:SetText("System Status: Premium Activated (Key Valid)")
                else
                    Aurora:Notify({
                        Title = "Invalid Access Key",
                        Content = "The key entered is incorrect or expired. Please try again.",
                        Type = "Error",
                        Duration = 4
                    })
                    MyLabel:SetText("System Status: Activation Failed")
                end
            end
        })
    end
})

-- Right Column: Media (Image & Audio & Video)
local SecMedia = HomeRight:AddSection("Media Elements", { Collapsible = true, DefaultExpanded = true })
SecMedia:AddImage("LogoImage", {
    Size = UDim2.fromOffset(180, 100),
    Image = "rbxassetid://10849890695"
})
SecMedia:AddSpace(10)
SecMedia:AddAudio("RetroSound", {
    Title = "Retro Ambient Music",
    SoundId = 1843431602,
    Volume = 0.5,
    Looped = true
})
SecMedia:AddSpace(10)
SecMedia:AddVideo("DemoVideo", {
    Title = "Premium Video Showcase",
    Video = 5608688234,
    Volume = 0.3,
    Looped = true,
    AutoPlay = true,
    Height = 120
})

local SecExtra = HomeRight:AddSection("Extra Info (Collapsible)", { Collapsible = true, DefaultExpanded = false })
SecExtra:AddParagraph({
    Title = "Tidbits & Info",
    Content = "This section is collapsible and starts collapsed by default. Chevrons in the header let you toggle the visibility dynamically!"
})

-- ================================================================================
--  BOOGA BOOGA TAB (Horizontal SubTabs & Dual-Column Sections)
-- ================================================================================
local SubCombat   = BoogaTab:AddSubTab("Combat")
local SubAuto     = BoogaTab:AddSubTab("Automation")
local SubEcon     = BoogaTab:AddSubTab("Auto Economy")
local SubFarm     = BoogaTab:AddSubTab("Auto Farm")
local SubLife     = BoogaTab:AddSubTab("Auto Life")
local SubMovement = BoogaTab:AddSubTab("Movement")

-- ─────────────────────────────────────────────────────────────────
--  COMBAT SUB-TAB (Two Columns)
-- ─────────────────────────────────────────────────────────────────
local CmbLeft, CmbRight = SubCombat:AddColumns()

-- Left Column: Mining & Range Options
local SecMining = CmbLeft:AddSection("Mining Settings")
local MineTgl = SecMining:AddToggle("MineAura", { Title="Mine Aura", Tooltip="When enabled, automatically swings your tools to mine resources within range." })
MineTgl:AddKeybind("MineAuraBind", { Default=Enum.KeyCode.F })
SecMining:AddSlider("MineRange", { Title="Mine Range (studs)", Tooltip="The maximum distance in studs that your character will mine resources.", Min=0, Max=50, Default=15, Suffix=" studs" })
SecMining:AddToggle("SwingAnim", { Title="Swing Animation", Default=true })
SecMining:AddDivider()
SecMining:AddToggle("TgtCritters", { Title="Filter: Critters", Default=true })
SecMining:AddToggle("TgtResources", { Title="Filter: Resources", Default=true })

-- Right Column: KillAura & Aiming Options
local SecMelee = CmbRight:AddSection("Melee Combat")
local KillTgl = SecMelee:AddToggle("KillAura", {
    Title = "Kill Aura",
    Tooltip = "When enabled, automatically attacks hostile animals and nearby players.",
    Callback = function(v)
        -- Can also use Callback instead of OnChanged if preferred
    end
})
KillTgl:AddKeybind("KillAuraBind", { Default=Enum.KeyCode.G })

local KillRangeSlider = SecMelee:AddSlider("KillRange", { Title="Kill Range (studs)", Tooltip="The maximum combat reach in studs for attacking targets.", Min=0, Max=30, Default=8, Suffix=" studs" })

-- Initially hide the sub-option slider
KillRangeSlider:SetVisible(false)

-- Dynamically toggle visibility based on KillAura state
KillTgl:OnChanged(function(v)
    KillRangeSlider:SetVisible(v)
end)

local SecProj = CmbRight:AddSection("Projectiles")
SecProj:AddToggle("SilentAim", { Title="Silent Aim" })
SecProj:AddToggle("AutoHit", { Title="Auto Hit Projectiles", Default=false })
SecProj:AddSlider("FOVRadius", { Title="Aim FOV", Min=10, Max=500, Default=150, Suffix=" px" })

-- ─────────────────────────────────────────────────────────────────
--  AUTOMATION SUB-TAB (Two Columns)
-- ─────────────────────────────────────────────────────────────────
local AutLeft, AutRight = SubAuto:AddColumns()

local SecHeal = AutLeft:AddSection("Auto Heal")
SecHeal:AddToggle("DoHeal", { Title="Enable Auto Heal", Default=true })
SecHeal:AddSlider("HealPercent", { Title="Heal Threshold", Min=10, Max=95, Default=75, Suffix="%" })

local SecHarvest = AutRight:AddSection("Auto Harvest")
SecHarvest:AddToggle("DoHarvest", { Title="Harvest Plants", Default=false })
SecHarvest:AddSlider("HarvestRange", { Title="Harvest Range", Min=5, Max=40, Default=15, Suffix=" studs" })

-- ================================================================================
--  INTERFACE SETTINGS (SaveManager & Themes)
-- ================================================================================
local UiLeft, UiRight = UiSettingsTab:AddColumns()

-- Left Column: Style & Custom Colors
local SecTheme = UiLeft:AddSection("Style Customize")
SecTheme:AddDropdown("ThemeSelector", {
    Title    = "Select Active Theme",
    Tooltip  = "Select your preferred color theme preset. Cycle modes like RGB animate colors automatically.",
    Values   = { "Dark", "Ocean", "Amethyst", "Neon", "BloodRed", "Midnight", "RGB", "NeonCyber", "ArcticFrost", "CottonCandy", "Orange", "Cyanic", "AmberGlow", "DeepViolet", "Charcoal", "PearlWhite", "Galaxy", "AMOLED", "AshGray", "NeonPurple", "RoyalBlue", "DeepOcean", "MidnightBlue", "CosmicViolet", "CyberGlow" },
    Default  = "Dark",
    Callback = function(v) Aurora:SetTheme(v) end
})
SecTheme:AddSpace(8)

SecTheme:AddSlider("GlassTrans", {
    Title    = "Glass Transparency",
    Tooltip  = "Controls the transparency of the frosted glass background. Lower is more solid, higher is more transparent.",
    Min      = 0.0,
    Max      = 0.95,
    Decimals = 2,
    Default  = 0.45,
    Callback = function(v)
        Window:SetAcrylicTransparency(v)
    end
})
SecTheme:AddSpace(8)

SecTheme:AddSlider("GlassBlurStrength", {
    Title    = "Glass Blur Strength",
    Tooltip  = "Controls the background viewport blur intensity. Lower is less blur, higher is more blur.",
    Min      = 0.0,
    Max      = 1.0,
    Decimals = 2,
    Default  = 1.0,
    Callback = function(v)
        Window:SetBlurIntensity(v)
    end
})
SecTheme:AddSpace(8)

SecTheme:AddParagraph({
    Title = "Interactive Resizing",
    Content = "Grab any outer border or corner of the window frame to dynamically resize the interface. Your cursor will highlight the borders as you hover."
})

-- Right Column: Saved Configuration Manager
local SecConfig = UiRight:AddSection("Config Manager")
-- Build the Save/Load/Autoload/Delete panel automatically
Aurora.SaveManager:SetLibrary(Aurora)
Aurora.SaveManager:SetFolder("AuroraSettings/BoogaBooga")
Aurora.SaveManager:BuildConfigSection(SecConfig)

-- ================================================================================
--  TESTING & DEBUG TAB (Full Width & Constraint Tests)
-- ================================================================================
local SecTest = TestTab:AddSection("Full Width Responsiveness Test")

SecTest:AddParagraph({
    Title = "Component Scaling",
    Content = "Since this section doesn't use 'AddColumns()', it takes the full width of the window. Notice how elements like Dropdowns and Inputs are elegantly constrained so they don't stretch horribly!"
})

SecTest:AddInput("ConstraintInput", {
    Title = "Test Input Constraint",
    Placeholder = "This should not span the entire screen...",
})

SecTest:AddDropdown("ConstraintDropdown", {
    Title = "Test Dropdown Constraint",
    Values = {"Option 1", "Option 2", "Option 3"},
    Default = "Option 1",
})

SecTest:AddToggle("TestTgl", {
    Title = "Test Toggle Switch",
    Default = true
})

SecTest:AddSlider("TestSlider", {
    Title = "Test Slider Constraints",
    Min = 0,
    Max = 100,
    Default = 50,
    Decimals = 1,
    Suffix = "%"
})

SecTest:AddButton({
    Title = "Test Button with Description",
    Description = "This button has a secondary description text below the title. This is great for detailed explanations.",
    Icon = "solar/star-bold",
    Callback = function() print("Test button clicked!") end
})

local SecAlerts = TestTab:AddSection("Alert Variants")
SecAlerts:AddAlert({ Title = "Information Alert", Content = "This is a standard information alert.", Type = "Info" })
SecAlerts:AddAlert({ Title = "Success Alert", Content = "This is a success alert.", Type = "Success" })
SecAlerts:AddAlert({ Title = "Warning Alert", Content = "This is a warning alert.", Type = "Warning" })
SecAlerts:AddAlert({ Title = "Error Alert", Content = "This is an error alert.", Type = "Error" })

-- ================================================================================
--  INITIALIZATION NOTIFICATION
-- ================================================================================
Aurora:Notify({
    Title    = "Aurora Loaded!",
    Content  = "Press LeftShift to hide or show the GUI.",
    Type     = "Success",
    Duration = 5
})

-- Load auto-saving configs if previously set
Aurora.SaveManager:LoadAutoloadConfig()
