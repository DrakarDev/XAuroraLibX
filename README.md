# AuroraLib v4.5
**Premium, Scalable, and Icon-Ready Custom Roblox UI Library**

![Version](https://img.shields.io/badge/Version-4.5-red?style=for-the-badge)
![Lua](https://img.shields.io/badge/Language-Lua-blue?style=for-the-badge)
![Platform](https://img.shields.io/badge/Platform-Roblox-orange?style=for-the-badge)
![Style](https://img.shields.io/badge/Style-Apple--Inspired-black?style=for-the-badge)

AuroraLib is a premium Roblox executor UI library with an Apple-inspired design language. Features fully rounded elements, pill-style sub-tabs, glass-effect windows, 8-directional resizing, searchable dropdowns, animated toggles, inline colorpickers, keybinds, and more. Fully scalable and theme-aware.

---

## ⚡ Quick Load

```lua
local Aurora = loadstring(game:HttpGet(
    "https://raw.githubusercontent.com/DrakarDev/XAuroraLibX/refs/heads/main/AuroraLibrary.lua"
))()
```

---

## 🖥️ Creating a Window

```lua
local Window = Aurora:CreateWindow({
    Title        = "My Script",          -- Title shown in sidebar
    SubTitle     = "By DyxDev",          -- Subtitle shown below title
    Theme        = "Dark",               -- See themes list below
    Scale        = 1.0,                  -- UI scale (0.7 to 2.0)
    Size         = UDim2.fromOffset(720, 530), -- Default window size
    MinimizeKey  = Enum.KeyCode.RightControl, -- Keybind to toggle GUI
    Acrylic      = false,                -- Glass/blur background effect
    LazyLoad     = true,                 -- Progressive element loading
    FadeIn       = true,                 -- Elements fade in on load
    DelayPerElement = 0.01,
    DelayPerSection = 0.02,
    DelayPerTab  = 0.05,
})
```

### Window Methods

```lua
Window:SetVisible(true)              -- Show/hide the window
Window:Toggle()                      -- Toggle visibility
Window:SetMinimizeKey(Enum.KeyCode.F) -- Change toggle keybind at runtime
Window:Destroy()                     -- Destroy UI and clean memory
```

---

## 🗂️ Navigation: Categories → Tabs → SubTabs → Sections

### 1. Add a Category (sidebar group header)

```lua
local MyCategory = Window:AddCategory("Main Features", "solar/star-bold")
```

### 2. Add a Tab (inside a category or standalone)

```lua
-- Inside a category:
local CombatTab = MyCategory:AddTab({ Title = "Combat", Icon = "solar/sword-bold" })

-- Standalone (no category):
local SettingsTab = Window:AddTab({ Title = "Settings", Icon = "solar/settings-bold" })
```

### 3. Add Sub-Tabs (pill-style, Apple-inspired)

```lua
local AimTab    = CombatTab:AddSubTab("Aimbot")
local ESPTab    = CombatTab:AddSubTab("ESP")
local MiscTab   = CombatTab:AddSubTab("Misc")
```

### 4. Add a Section (inside a tab or subtab)

```lua
-- Inside a normal tab:
local AimSection = CombatTab:AddSection("Aimbot Settings")

-- Inside a subtab:
local AimSection = AimTab:AddSection("Aimbot Settings")

-- Two-column layout:
local LeftCol, RightCol = CombatTab:AddColumns()
local LeftSec  = LeftCol:AddSection("Left Panel")
local RightSec = RightCol:AddSection("Right Panel")

-- Collapsible section:
local ExtraSec = LeftCol:AddSection("Extra", { Collapsible = true, DefaultExpanded = false })
ExtraSec:SetCollapsed(true) -- Collapse at runtime
```

---

## ⚙️ Elements

All elements accept an **id** (string) and a **cfg** table. The id is used to access the element via `Aurora.Options.MyId.Value`.

### Toggle

```lua
local Tgl = AimSection:AddToggle("AimbotEnabled", {
    Title       = "Enable Aimbot",
    Description = "Snaps aim to nearest target",  -- optional subtitle
    Default     = false,
    Icon        = "solar/cursor-bold",             -- optional icon
    Tooltip     = "Toggle aimbot on/off",          -- optional hover tip
    Callback    = function(value)
        print("Aimbot:", value)
    end
})

-- Methods:
Tgl:SetValue(true)                -- Set state programmatically
Tgl:OnChanged(function(v) end)    -- Subscribe to changes

-- Add inline keybind to toggle:
Tgl:AddKeybind("AimbotKey", { Default = Enum.KeyCode.E })

-- Add inline colorpicker:
Tgl:AddColorpicker("AimbotColor", { Default = Color3.fromRGB(255, 0, 0) })
```

### Slider

```lua
local Sld = AimSection:AddSlider("FOV", {
    Title    = "FOV Circle",
    Min      = 10,
    Max      = 500,
    Default  = 150,
    Suffix   = " px",
    Callback = function(value) print("FOV:", value) end
})

Sld:SetValue(200)
Sld:OnChanged(function(v) print(v) end)
```

### Dropdown

```lua
local Drop = AimSection:AddDropdown("TargetPart", {
    Title    = "Target Part",
    Values   = { "Head", "Torso", "Root" },
    Default  = "Head",
    Multi    = false,       -- true = multi-select
    Callback = function(value) print("Target:", value) end
})

Drop:Refresh({ "Head", "Torso", "Random" }) -- Replace options
Drop:SetValue("Torso")                       -- Set selection
Drop:OnChanged(function(v) print(v) end)
```

### Button

```lua
local Btn = AimSection:AddButton({
    Title       = "Execute Script",
    Description = "Runs the main loop",
    Icon        = "solar/play-bold",
    Callback    = function()
        print("Button clicked!")
    end
})

Btn:SetTitle("Running...")
Btn:SetDesc("Executing now...")
```

### Input (Text Box)

```lua
local Inp = AimSection:AddInput("PlayerName", {
    Title       = "Target Name",
    Default     = "",
    Placeholder = "Enter player name",
    Callback    = function(text)
        print("Input:", text)
    end
})

Inp:SetValue("Player1")
Inp:OnChanged(function(t) print(t) end)
```

### Keybind (Standalone)

```lua
local Key = AimSection:AddKeybind("PanicKey", {
    Title    = "Panic Key",
    Default  = Enum.KeyCode.Delete,
    Callback = function(key) print("Key changed to:", key) end
})

Key:SetValue(Enum.KeyCode.End)
Key:OnChanged(function(k) print(k) end)
```

### Colorpicker (Standalone)

```lua
local CP = AimSection:AddColorpicker("ESPColor", {
    Title    = "ESP Color",
    Default  = Color3.fromRGB(255, 0, 0),
    Callback = function(color) print(color) end
})

CP:SetValue(Color3.fromRGB(0, 255, 170))
CP:SetValueRGB(Color3.new(1, 0, 0), 0.5)  -- with transparency
CP:OnChanged(function(c) print(c) end)
```

### Label & Live Stat

```lua
local Lbl = AimSection:AddLabel("StatusLbl", "Status: Active")
Lbl:SetText("Status: Idle")

local Stat = AimSection:AddLiveStat("GoldDisplay", {
    Title   = "Total Gold",
    Default = "0",
    Icon    = "solar/wad-of-money-bold",
    Color   = Color3.fromRGB(255, 215, 0)
})
Stat:SetText("1500")
Stat:SetText("2000", Color3.fromRGB(0, 255, 100)) -- with new color
```

### Paragraph

```lua
local Para = AimSection:AddParagraph({
    Title   = "Notice",
    Content = "This feature requires the game to be in a public server."
})
Para:SetTitle("Updated Notice")
Para:SetContent("New content here.")
```

### Progress Bar

```lua
local Prog = AimSection:AddProgressBar("FarmProgress", {
    Title = "Farm Progress"
})
Prog:SetProgress(0.75)  -- 0.0 to 1.0
Prog:SetTitle("Almost done...")
```

### Alert, Divider, Space, Separator

```lua
AimSection:AddAlert({
    Title   = "Warning",
    Content = "This may cause lag.",
    Type    = "Warning"  -- "Info", "Success", "Error", "Warning"
})

AimSection:AddDivider()
AimSection:AddSpace(10)          -- pixel gap
AimSection:AddSeparator("──── SECTION LABEL ────")
```

---

## 🎨 Themes (25+ Built-in)

**Available:** `Dark`, `Light`, `Ocean`, `Amethyst`, `Neon`, `BloodRed`, `Midnight`, `NeonCyber`, `ArcticFrost`, `CottonCandy`, `Orange`, `Cyanic`, `AmberGlow`, `DeepViolet`, `Charcoal`, `PearlWhite`, `Galaxy`, `AMOLED`, `AshGray`, `NeonPurple`, `RoyalBlue`, `DeepOcean`, `MidnightBlue`, `CosmicViolet`, `Sakura` 🌸, `RGB` (chroma)

```lua
-- Switch theme at runtime:
Aurora:SetTheme("Ocean")

-- Create custom theme (missing keys fall back to Dark):
Aurora:CreateTheme("MyTheme", {
    Background = Color3.fromRGB(10, 10, 14),
    Accent     = Color3.fromRGB(0, 200, 255),
    Text       = Color3.fromRGB(240, 240, 255),
    Border     = Color3.fromRGB(40, 40, 55),
})
```

---

## 🔔 Notifications

```lua
-- Basic:
Aurora:Notify({ Title = "Done!", Content = "Script loaded.", Type = "Success", Duration = 5 })

-- With buttons:
Aurora:Notify({
    Title = "Confirm", Content = "Continue?", Type = "Warning", Duration = 0,
    Buttons = {
        { Title = "Yes",    Callback = function() print("confirmed") end },
        { Title = "Cancel", Callback = function() end },
    }
})

-- Dynamic progress:
local notif = Aurora:Notify({ Title = "Loading", Content = "Please wait...", Duration = 0 })
notif:SetProgress(0.5)
notif:Update({ Title = "Done!", Content = "Finished!", Type = "Success", Duration = 3 })
notif:Close()
```

---

## 💬 Modal Dialogs

```lua
Window:Dialog({
    Title   = "Confirmation",
    Content = "Are you sure you want to reset all settings?",
    Buttons = {
        { Title = "Cancel" },
        { Title = "Reset", Callback = function() resetAllSettings() end },
    }
})
```

---

## 💾 SaveManager

```lua
Aurora.SaveManager:SetLibrary(Aurora)
Aurora.SaveManager:SetFolder("MyScript/Config")
Aurora.SaveManager:IgnoreIndexes({ "ThemeSelector" })

-- Build a config UI section automatically:
Aurora.SaveManager:BuildConfigSection(SettingsSection)

-- Auto-load last saved config:
Aurora.SaveManager:LoadAutoloadConfig()

-- Cloud config sharing:
Aurora.SaveManager:SaveCloud("MyConfig", "DyxDev", "Best settings", "BoogaBooga")
Aurora.SaveManager:LoadCloud("MyConfig")
```

---

## 🔑 Key System

```lua
local verified = false
Aurora.KeySystem.new({
    Title    = "License Check",
    SubTitle = "Enter your key to continue",
    Note     = "Get a key at discord.gg/example",
    Keys     = { "FREE-KEY-2026", "VIP-KEY-ABC" },
    KeyLink  = "https://discord.gg/example",
    SaveKey  = true,
    FileName = "MyScript_Key.txt",
    OnSuccess = function()
        verified = true
    end
})
repeat task.wait(0.1) until verified
```

---

## 🌐 Global Options API

Access any element's current value from anywhere in your script:

```lua
local enabled = Aurora.Options.AimbotEnabled.Value
local fov     = Aurora.Options.FOV.Value
local target  = Aurora.Options.TargetPart.Value
local color   = Aurora.Options.ESPColor.Value
local key     = Aurora.Options.PanicKey.Value
```

---

## 📊 HUD & Overlays

```lua
-- Watermark:
local WM = Aurora:Watermark({ Enabled = true, Title = "My Script v1.0" })
WM:SetTitle("My Script | FPS: 60")
WM:Destroy()

-- Keybind tracker:
local KB = Aurora:KeybindList({ Enabled = true })
KB:Destroy()

-- Custom HUD panel:
local HUD = Aurora:CreateHUD({ Title = "Stats", Width = 220 })
HUD:SetItem("Status", "Running")
HUD:SetItem("FPS",    tostring(math.floor(1/game:GetService("RunService").RenderStepped:Wait())))
HUD:Toggle(true)
```

---

## 🖼️ Media Elements

```lua
-- Image:
local Img = Section:AddImage("Banner", { Size = UDim2.fromOffset(200, 80), Image = "rbxassetid://12345" })
Img:SetImage("rbxassetid://67890")

-- Audio:
local Audio = Section:AddAudio("BGM", { SoundId = 1843431602, Volume = 0.5, Looped = true })
Audio:Play(); Audio:Stop(); Audio:SetVolume(0.8)

-- Video:
local Vid = Section:AddVideo("Trailer", { Video = 5608688234, AutoPlay = true, Height = 150 })
Vid:Play(); Vid:Pause()

-- Code box (copyable):
local Code = Section:AddCode("Example", { Title = "Sample Code", Code = "print('Hello')" })
Code:SetCode("print('World')")
```

---

## 🎮 3D Viewport

```lua
local VP = Section:AddViewport("Preview", {
    Title = "Character Preview", Height = 220,
    AutoSpin = true, SpinSpeed = 25, CameraDistance = 7,
})
VP:SetPlayer("local")          -- Live character tracking
VP:SetPlayer("PlayerName")     -- Another player
VP:SetWorkspaceModel("Tree")   -- Any workspace model
VP:Spin(30)                    -- Spin at 30°/sec (0 = stop)
VP:SetCamera(10, 30)           -- Distance and elevation
VP:Clear()                     -- Remove model
```

---

## 📝 Complete Minimal Example

```lua
local Aurora = loadstring(game:HttpGet(
    "https://raw.githubusercontent.com/DrakarDev/XAuroraLibX/refs/heads/main/AuroraLibrary.lua"
))()

local Window = Aurora:CreateWindow({
    Title       = "My Script",
    SubTitle    = "By DyxDev",
    Theme       = "Dark",
    MinimizeKey = Enum.KeyCode.RightControl,
})

local Cat      = Window:AddCategory("Features", "solar/star-bold")
local MainTab  = Cat:AddTab({ Title = "Main", Icon = "solar/home-bold" })
local MainSec  = MainTab:AddSection("General")

-- Toggle with keybind
local TglAim = MainSec:AddToggle("AimbotOn", {
    Title    = "Aimbot",
    Default  = false,
    Callback = function(v) print("Aimbot:", v) end,
})
TglAim:AddKeybind("AimbotKey", { Default = Enum.KeyCode.E })

-- Slider
MainSec:AddSlider("AimFOV", {
    Title    = "FOV",
    Min      = 10, Max = 500, Default = 150,
    Suffix   = " px",
    Callback = function(v) print("FOV:", v) end,
})

-- Dropdown
MainSec:AddDropdown("AimPart", {
    Title    = "Target Part",
    Values   = { "Head", "Torso" },
    Default  = "Head",
    Callback = function(v) print("Part:", v) end,
})

-- Button
MainSec:AddButton({
    Title    = "Execute",
    Callback = function() Aurora:Notify({ Title = "Done!", Type = "Success", Duration = 3 }) end,
})

Aurora:Notify({ Title = "Loaded", Content = "My Script is ready!", Type = "Success", Duration = 4 })
```

---

> For a full showcase of all features, see `AuroraExample.lua`.

Made with ❤️ by **DrakarDev** · Design inspired by Apple HIG
