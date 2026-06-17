# AuroraLib v4.5
**Premium, Scalable, and Icon-Ready Custom Roblox UI Library**

![Version](https://img.shields.io/badge/Version-4.5-red?style=for-the-badge)
![Lua](https://img.shields.io/badge/Language-Lua-blue?style=for-the-badge)
![Platform](https://img.shields.io/badge/Platform-Roblox-orange?style=for-the-badge)

AuroraLib is a premium UI library for Roblox executors. It features a glass-effect window inspired by FluentPro, a professional 2D colorpicker with SV canvas, 8-directional edge resizing, collapsible sidebar categories, horizontally scrollable sub-tabs, filtered searchable dropdowns, manual textbox sliders, and inline component chaining. Fully scalable and text-wrapping-safe.

---

## 🚀 Features & What's New in v4.5

- 📱 **Smart Platform Auto-Detection**: No more manual mobile layout overrides! The library automatically detects if a player is on a touch-only mobile device or a desktop PC. Mobile features floating pill-toggles and a dedicated Show/Hide button, while PC maps actions purely to physical keybind inputs.
- 🔍 **Global Interactive Search Registry**: A global search bar in the sidebar that performs a full-script search to instantly find and navigate to any interactive element (Toggles, Buttons, Sliders, Dropdowns, etc.) across all tabs.
- 🔔 **Advanced Notification System**: Bouncy spring animations, actionable notifications with buttons, input fields inside notifications, and dynamic progress bars.
- 📊 **Draggable HUD Monitors**: Create custom draggable on-screen display panels to track script stats, FPS, Ping, or any custom variables in real-time.
- 🧹 **Complete Garbage Collection**: Safe script unloading (`Window:Destroy()`) to prevent memory leaks.
- ☁️ **Cloud Configuration Sharing**: Share and load configurations seamlessly across the cloud using the built-in SaveManager cloud API.
- 🎯 **Interactive Elements Enhancements**: Pill-style toggle switches, expanding slider knobs, expanding button ripple effects, and gradient section headers.
- 🌸 **New Theme - Sakura**: Cherry-blossom pink light theme.
- ⚡ **Performance Optimized**: Progressive rendering, debounced interactions, and tween caching.

---

## ⚡ Quick Start

Load the library directly from GitHub in your executor:

```lua
local Aurora = loadstring(game:HttpGet(
    "https://raw.githubusercontent.com/DrakarDev/XAuroraLibX/refs/heads/main/AuroraLibrary.lua"
))()
```

---

## 🖥️ Window Initialization & API

Create the main window with custom configuration settings:

```lua
local Window = Aurora:CreateWindow({
    Title        = "Aurora Premium",        -- Main header title
    SubTitle     = "Booga Booga Edition",   -- Small subtext next to/below title
    Theme        = "Dark",                  -- Themes: "Dark", "Ocean", "Amethyst", "Neon", "Sakura", etc.
    Scale        = 1.0,                     -- UI scale multiplier (0.7 to 2.0)
    Size         = UDim2.fromOffset(800, 560), -- Default window size
    MinimizeKey  = Enum.KeyCode.RightControl, -- Keybind to hide/show the entire GUI
    Acrylic      = false,                   -- Enables premium glass/acrylic blur background
    LazyLoad     = true,                    -- Enables progressive loading of elements (FPS friendly)
    DelayPerElement = 0.01,                 -- Loading delay in seconds per element
    DelayPerSection = 0.02,                 -- Loading delay in seconds per section
    DelayPerTab  = 0.05,                    -- Loading delay in seconds per tab
    FadeIn       = true                     -- Elements progressively fade in as they instantiate
})
```

### Window Methods

Control window properties programmatically at runtime:

```lua
Window:SetVisible(true/false)               -- Shows or hides the window
Window:Toggle()                             -- Toggles the window visibility state
Window:SetMinimizeKey(Enum.KeyCode.F)       -- Changes the toggle hotkey
Window:SetAcrylicTransparency(0.45)         -- Tweens window background transparency (e.g. 0.0 to 0.95)
Window:SetBlurIntensity(1.0)                -- Tweens depth-of-field blur strength (e.g. 0.0 to 1.0)
Window:Destroy()                            -- Completely destroys the UI and cleans memory
```

---

## 🎨 Themes (25+ Available)

**Built-in Themes:** `Dark`, `Light`, `Ocean`, `Amethyst`, `Neon`, `BloodRed`, `Midnight`, `NeonCyber`, `ArcticFrost`, `CottonCandy`, `Orange`, `Cyanic`, `AmberGlow`, `DeepViolet`, `Charcoal`, `PearlWhite`, `Galaxy`, `AMOLED`, `AshGray`, `NeonPurple`, `RoyalBlue`, `DeepOcean`, `MidnightBlue`, `CosmicViolet`, **`Sakura`** 🌸, `RGB` (chroma)

### Theme Methods
```lua
Aurora:SetTheme("CyberGlow")

-- Create custom theme palette (Missing keys fallback to Dark theme)
Aurora:CreateTheme("CyberGlow", {
    Background   = Color3.fromRGB(15, 10, 25),
    Sidebar      = Color3.fromRGB(18, 12, 30),
    Element      = Color3.fromRGB(28, 20, 45),
    Accent       = Color3.fromRGB(0, 255, 200),
    Text         = Color3.fromRGB(240, 255, 250),
    SubText      = Color3.fromRGB(150, 165, 180),
    Border       = Color3.fromRGB(50, 35, 75),
    ToggleOn     = Color3.fromRGB(0, 255, 200),
    SliderFill   = Color3.fromRGB(0, 255, 200),
})
```

---

## 🛡️ Key System & Verification

Built-in premium license verification system. Blocks script execution and prompts the user to enter a key.

```lua
local keyVerified = false
Aurora.KeySystem.new({
    Title = "Aurora Verification",
    SubTitle = "License Verification Required",
    Note = "Get your free license key from our Discord server.",
    Keys = {"AuroraKey2026", "DevKey"},       -- Local valid keys list
    KeyLink = "https://discord.gg/auroralib", -- Link to obtain key
    SaveKey = true,                           -- Cache verified key to file
    FileName = "AuroraLicense_Cache.txt",     -- Cache file name in workspace/
    OnSuccess = function()
        keyVerified = true
    end
})

repeat task.wait(0.2) until keyVerified
```

---

## 💾 SaveManager (Local & Cloud Configurations)

Built-in SaveManager to easily persist script options locally and share them over the cloud.

```lua
Aurora.SaveManager:SetLibrary(Aurora)
Aurora.SaveManager:SetFolder("AuroraSettings/MyGame")

-- Build config options inside a UI section automatically
Aurora.SaveManager:BuildConfigSection(Section)

-- Exclude specific elements from saving
Aurora.SaveManager:IgnoreIndexes({ "ThemeSelector", "AimbotBind" })

-- Ignore UI aesthetic settings
Aurora.SaveManager:IgnoreThemeSettings()

-- Load autoload configurations
Aurora.SaveManager:LoadAutoloadConfig()
```

### Cloud API Methods
```lua
Aurora.SaveManager:SaveCloud("ConfigName", "AuthorName", "Best legit config!", "GameName")
Aurora.SaveManager:LoadCloud("ConfigName")
Aurora.SaveManager:RefreshCloudConfigList()
```

---

## 📊 HUDs, Watermarks & Overlays

### 1. Stats Watermark
```lua
local Watermark = Aurora:Watermark({ Enabled = true, Title = "Aurora Premium" })
Watermark:SetTitle("New Title")
Watermark:Destroy()
```

### 2. Keybinds Tracker HUD
```lua
local KeybindList = Aurora:KeybindList({ Enabled = true })
KeybindList:Refresh()
KeybindList:Destroy()
```

### 3. Custom Script HUD
A custom draggable HUD panel for displaying real-time metrics.
```lua
local HUDObj = Aurora:CreateHUD({ Title = "Script Status", Width = 220 })
HUDObj:SetItem("Status", "Idle")
HUDObj:SetItem("FPS", "60")
HUDObj:Toggle(true)
```

---

## 💬 Notifications & Dialogs

### Advanced Notifications
Trigger notifications with animations, inputs, or dynamic progress bars.

```lua
-- Standard
Aurora:Notify({ Title = "Loaded", Content = "Features ready.", Type = "Success", Duration = 5 })

-- Actionable (Buttons)
Aurora:Notify({
    Title = "Warning", Content = "Proceed?", Type = "Warning", Duration = 8,
    Buttons = { { Title = "Confirm", Callback = function() end }, { Title = "Cancel" } }
})

-- Input field
Aurora:Notify({
    Title = "Access", Content = "Enter key", Type = "Info", Duration = 0,
    Input = true, InputPlaceholder = "Type...", InputCallback = function(text) print(text) end
})

-- Dynamic Progress
local notif = Aurora:Notify({ Title = "Downloading", Content = "Wait...", Duration = 0 })
notif:SetProgress(0.5) -- Updates bar to 50%
notif:Update({ Title = "Done", Content = "Finished!", Type = "Success", Duration = 3 })
notif:Close() -- Manually closes the notification
```

### Modal Dialogs
Centered modal overlays on top of the main UI window.
```lua
Window:Dialog({
    Title = "Premium Modal", Content = "Are you sure you want to delete this config?",
    Buttons = { { Title = "Cancel" }, { Title = "Delete", Callback = function() end } }
})
```

---

## 🗂️ Navigation & Layout Structure

The library uses a nested hierarchy: **Categories ➔ Tabs ➔ Sub-Tabs ➔ Columns ➔ Sections**.

```lua
local CatGame = Window:AddCategory("Main Features", "solar/danger-bold")
local MainTab = CatGame:AddTab({ Title = "Combat", Icon = "solar/danger-bold" })
local SubMelee = MainTab:AddSubTab("Melee")
local LeftCol, RightCol = SubMelee:AddColumns()

-- Sections can be collapsible
local KillAuraSec = LeftCol:AddSection("Kill Aura")
local ExtraSec = RightCol:AddSection("Extra Settings", { Collapsible = true, DefaultExpanded = false })
ExtraSec:SetCollapsed(true) -- Change collapse state at runtime
```

---

## ⚙️ Elements & Methods API

All UI elements returned by the library expose specific methods to modify them programmatically at runtime.  
**Global Visibility:** Every element has a `:SetVisible(boolean)` method.

### Toggles
```lua
local Tgl = Section:AddToggle("Aimbot", { Title = "Aimbot", Tooltip = "Auto aim.", Default = false })

Tgl:AddKeybind("AimbotBind", { Default = Enum.KeyCode.E })
Tgl:AddColorpicker("AimbotColor", { Default = Color3.fromRGB(255, 0, 0) })

Tgl:SetValue(true)
Tgl:OnChanged(function(val) print(val) end)
```

### Sliders
```lua
local Sld = Section:AddSlider("FOV", { Title = "FOV", Min = 10, Max = 500, Default = 150, Suffix = " px" })

Sld:SetValue(200)
Sld:OnChanged(function(val) print(val) end)
```

### Dropdowns
```lua
local Drop = Section:AddDropdown("TargetMode", { Title = "Target Mode", Values = { "Head", "Torso" }, Default = "Head", Multi = false })

Drop:Refresh({ "Head", "Torso", "Random" }) -- Update available options
Drop:SetValue("Random")                     -- Update selection
Drop:SetValues({ "Head", "Torso" })         -- Update multiple selections (if Multi = true)
Drop:OnChanged(function(val) print(val) end)
```

### Inputs (Text Boxes)
```lua
local Inp = Section:AddInput("CustomTag", { Title = "Chat Tag", Default = "[VIP]" })

Inp:SetValue("[ADMIN]")
Inp:OnChanged(function(text) print(text) end)
```

### Keybinds & Colorpickers (Standalone)
```lua
local Key = Section:AddKeybind("Panic", { Title = "Panic", Default = Enum.KeyCode.P })
Key:SetValue(Enum.KeyCode.L)
Key:OnChanged(function(k) print(k) end)

local CP = Section:AddColorpicker("ESPCol", { Title = "Color", Default = Color3.fromRGB(0, 255, 170) })
CP:SetValue(Color3.fromRGB(255, 0, 0))
CP:SetValueRGB(Color3.new(1, 0, 0), 0.5) -- Color with transparency
CP:OnChanged(function(c) print(c) end)
```

### Progress Bars
```lua
local Prog = Section:AddProgressBar("FarmingProg", { Title = "Farming Progress" })

Prog:SetProgress(50)      -- Set fill to 50%
Prog:SetValue(50)         -- Alias to SetProgress
Prog:SetTitle("Mining...")-- Update the label
```

### Advanced Text & Formatting Elements
```lua
local Lbl = Section:AddLabel("InfoLabel", "Status: Active")
Lbl:SetText("New Status")

local Stat = Section:AddLiveStat("GoldCoins", { 
    Title = "Total Gold", 
    Default = "0",
    Icon = "solar/wad-of-money-bold",  -- Any icon name
    Color = Color3.fromRGB(255, 215, 0) -- Neon glow color
})
-- Update the glowing stat in real-time, optionally changing its color:
Stat:SetText("1500", Color3.fromRGB(0, 255, 100)) 

local Btn = Section:AddButton({ Title = "Execute", Description = "Runs script", Icon = "solar/play-bold" })
Btn:SetTitle("Running")
Btn:SetDesc("Executing now...")

local Para = Section:AddParagraph({ Title = "Note", Content = "Read carefully." })
Para:SetTitle("Updated Note")
Para:SetContent("New content")

Section:AddSpace(10)
Section:AddDivider()
Section:AddSeparator("MEDIA SECTION")
Section:AddAlert({ Title = "Warning", Content = "Risk!", Type = "Warning" })
```

### Media Elements
```lua
local Img = Section:AddImage("Logo", { Size = UDim2.fromOffset(200, 100), Image = "rbxassetid://10849890695" })
Img:SetImage("rbxassetid://new_id")

local Audio = Section:AddAudio("Music", { Title = "BGM", SoundId = 1843431602, Volume = 0.5, Looped = true })
Audio:Play()
Audio:Stop()
Audio:SetVolume(1.0)
Audio:SetSoundId(123456789)

local Video = Section:AddVideo("Trailer", { Title = "Showcase", Video = 5608688234, AutoPlay = true, Looped = true, Height = 150 })
Video:Play()
Video:Pause()
Video:SetVolume(0.5)

local Code = Section:AddCode("ScriptBox", { Title = "Copy Me", Code = "print('Hello')" })
Code:SetCode("print('Goodbye')")
```

---

## 🎮 3D Viewport Element

`Section:AddViewport` — A premium embedded 3D viewer inside any section. Supports loading player characters, workspace models, or any custom Model/BasePart. Comes with an interactive orbital camera (drag to rotate, scroll to zoom), auto-spin, and a built-in toolbar.

### Configuration Options
```lua
local VP = Section:AddViewport("MyViewer", {
    Title          = "Character Preview", -- Header label above the viewer
    Height         = 220,                 -- Height of the viewer in pixels
    CameraDistance = 7,                   -- Initial camera distance from model
    CameraAngleY   = 20,                  -- Initial vertical camera elevation (degrees)
    AutoSpin       = true,                -- Start spinning the model on load
    SpinSpeed      = 25,                  -- Auto-spin speed in degrees per second
})
```

### Loading Models
```lua
-- 1. Show a player's character (Live Tracking)
-- Automatically tracks the player's character, updating the 3D model every time they respawn!
-- Fully supports R15/R6 characters without missing invisible parts.
VP:SetPlayer("local")                      -- Your own character
VP:SetPlayer("PlayerName")                 -- Any player in the server by name
VP:SetPlayer(game.Players.LocalPlayer)     -- By Player object

-- 2. Load any model from the Workspace by name (searches recursively)
VP:SetWorkspaceModel("Tree")
VP:SetWorkspaceModel("BossNPC")

-- 3. Load any Model or BasePart instance directly
local part = Instance.new("Part")
part.Size = Vector3.new(5, 5, 5)
VP:SetModel(part)
```

### Runtime Control
```lua
VP:Spin(45)          -- Start spinning at 45 degrees/sec (0 = stop)
VP:SetCamera(10, 30) -- Change camera distance and elevation angle at runtime
VP:SetTitle("New Title")
VP:Clear()           -- Remove the current model and show placeholder
VP:SetVisible(false) -- Hide/show the entire element
```

### Full Example — Character Viewer with Controls
```lua
local SecViewer = LeftCol:AddSection("Player Inspector")

local PlayerViewport = SecViewer:AddViewport("PlayerVP", {
    Title = "Live Character", Height = 220, AutoSpin = true, SpinSpeed = 22
})
PlayerViewport:SetPlayer("local")

SecViewer:AddDropdown("InspectTarget", {
    Title = "Select Player",
    Values = { "[Local]", "PlayerA", "PlayerB" },
    Default = "[Local]",
    Callback = function(name)
        if name == "[Local]" then
            PlayerViewport:SetPlayer("local")
        else
            PlayerViewport:SetPlayer(name)
        end
    end
})

SecViewer:AddSlider("VPDistance", {
    Title = "Zoom", Min = 3, Max = 20, Default = 7,
    Callback = function(v) PlayerViewport:SetCamera(v, nil) end
})

SecViewer:AddToggle("VPSpin", {
    Title = "Auto-Spin", Default = true,
    Callback = function(v) PlayerViewport:Spin(v and 22 or 0) end
})
```

> **Toolbar Buttons** built into every viewport:
> - 🔄 **Reset Camera** — Restores default distance and angle
> - ↺ **Toggle Spin** — Starts/stops auto-rotation
> - ✕ **Clear** — Removes the loaded model

---

## 🌐 Global Options API

Retrieve any UI element's active value dynamically from anywhere in your script using its registered ID:

```lua
local isAimbotEnabled = Aurora.Options.Aimbot.Value
local currentFOV      = Aurora.Options.FOV.Value
local currentFilters  = Aurora.Options.ESPFilters.Value
local customTagText   = Aurora.Options.CustomTag.Value
```

---

## 🛠️ Complete Integration Example

To view a fully constructed script showing how all of these components work together, please refer to the `AuroraExample.lua` file included in the library directory. It features a complete mock setup for a Booga Booga style script, plus the full **3D Viewers** tab demonstrating all `AddViewport` features.

---

Made with ❤️ by **DrakarDev**
