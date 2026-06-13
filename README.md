# AuroraLib v4.0
**Premium, Scalable, and Icon-Ready Custom Roblox UI Library**

![Version](https://img.shields.io/badge/Version-4.0-red?style=for-the-badge)
![Lua](https://img.shields.io/badge/Language-Lua-blue?style=for-the-badge)
![Platform](https://img.shields.io/badge/Platform-Roblox-orange?style=for-the-badge)

AuroraLib is a premium UI library for Roblox executors. It features a glass-effect window inspired by FluentPro, a professional 2D colorpicker with SV canvas, 8-directional edge resizing, collapsible sidebar categories, horizontally scrollable sub-tabs, filtered searchable dropdowns, manual textbox sliders, and inline component chaining. Fully scalable and text-wrapping-safe.

---

## 🚀 Key Features in v4.0

- ↔️ **8-Directional Edge Resizing**: Grab any edge (`Top`, `Bottom`, `Left`, `Right`) or corner of the window frame to dynamically resize the interface. Features hover border highlights in the accent color.
- 🎨 **RGB Chroma Mode & 24+ Premium Themes**: Select from premium style presets (including `Dark`, `Ocean`, `Amethyst`, `Neon`, `BloodRed`, `Midnight`, `NeonCyber`, `ArcticFrost`, `CottonCandy`, `Orange`, `Cyanic`, `AmberGlow`, `DeepViolet`, `Charcoal`, `PearlWhite`, `Galaxy`, `AMOLED`, `AshGray`, `NeonPurple`, `RoyalBlue`, `DeepOcean`, `MidnightBlue`, `CosmicViolet`) or cycle smoothly with `RGB` Chroma mode. Custom themes fully support background images (`BackgroundImage` and `BackgroundImageTransparency`).
- 📹 **Premium Video Player**: Insert custom interactive video frames (`Section:AddVideo`) with play/pause buttons, loop configuration, volume control, and customizable player heights.
- 💾 **Native SaveManager**: Built-in config manager to save, load, delete, and autoload user options automatically using JSON workspace files.
- 📑 **Scrollable Sub-Tabs**: Multi-layer horizontal navigation bar that scrolls horizontally when sub-tabs exceed the panel width, complete with sliding underline indicators.
- 🎨 **2D Colorpicker (SV Canvas)**: Professional color editor with a 2D Saturation/Value canvas, Y-axis Hue bar, Alpha slider, Hex/RGB inputs, and old/new swatches.
- 🗂 **Sidebar Categories (Collapsible)**: Organize tabs under collapsible sidebar headers with rotating chevron indicators.
- 🎛 **Inline Component Add-ons**: Attach inline keybinds and colorpickers directly to Toggles, stacking neatly next to the toggle pill.
- 🔔 **Stacking Notifications**: Glassmorphic notifications supporting custom play sound beeps and a max limit of 5 stacked notification cards (auto-dismissing the oldest).
- 💻 **Window Controls + Global Bind**: Minimize, maximize, close with confirmation prompt, and toggle window visibility using `RightControl` keybind.

---

## ⚡ Quick Start

Load the library directly from GitHub in your executor:

```lua
local Aurora = loadstring(game:HttpGet(
    "https://raw.githubusercontent.com/DrakarDev/XAuroraLibX/refs/heads/main/AuroraLibrary.lua"
))()
```

---

## 🖥️ Window Initialization

Create the main window with custom configuration settings:

```lua
local Window = Aurora:CreateWindow({
    Title        = "Aurora Premium",        -- Main header title
    SubTitle     = "Booga Booga Edition",   -- Small subtext next to/below title
    Theme        = "Dark",                  -- Themes: "Dark", "Ocean", "Amethyst", "Neon", "BloodRed", "Midnight", "RGB", "AMOLED", "AshGray", "NeonPurple", "RoyalBlue", "DeepOcean", "MidnightBlue", "CosmicViolet", "CyberGlow"
    Scale        = 1.0,                     -- UI scale multiplier
    Size         = UDim2.fromOffset(800, 560), -- Default window size
    MinimizeKey  = Enum.KeyCode.RightControl, -- Keybind to hide/show the entire GUI
    Acrylic      = true,                    -- Enables the premium glass/acrylic blur background (Default: true)
    MobileButton = true,                    -- Forces the mobile float toggle button to show (Default: false, automatically shows on Touch devices)
    MobileButtonIcon = "solar/star-bold",   -- Custom Lucide/Solar icon for the mobile button
    MobileButtonPosition = UDim2.new(0, 20, 0, 150), -- Custom initial position of mobile button (UDim2)
    LazyLoad     = true,                    -- Enables progressive loading of elements to eliminate FPS lag (Default: false)
    DelayPerElement = 0.01,                 -- Loading delay in seconds per element (Default: 0.01)
    DelayPerSection = 0.02,                 -- Loading delay in seconds per section (Default: 0.02)
    DelayPerTab  = 0.05,                    -- Loading delay in seconds per tab (Default: 0.05)
    FadeIn       = true                     -- Elements progressively fade in as they are instantiated (Default: false)
})
```

---

## 👁️ Window Visibility & Styling API

Control window visibility and frosted glass properties programmatically:

```lua
Window:SetVisible(true)                     -- Shows the window
Window:SetVisible(false)                    -- Hides the window
Window:Toggle()                             -- Toggles the window visibility (fully synchronized with keybind and mobile button!)

-- Frosted glass (acrylic) customization:
Window:SetAcrylicTransparency(transparency) -- Tweens window transparency dynamically (e.g. 0.0 to 0.95)
Window:SetBlurIntensity(intensity)          -- Tweens depth-of-field blur strength dynamically (e.g. 0.0 to 1.0)
```

---

## 🎨 Theme & HUD Customization API

### 1. Custom Theme Creator
You can programmatically register new custom color palettes at runtime. Missing keys will automatically fall back to default Dark theme values:

```lua
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

Aurora:SetTheme("CyberGlow")
```

### 2. Stats Watermark HUD Overlay
Adds a floating translucent status bar showing active game details, LocalPlayer headshot, and dynamic client stats (FPS/Ping):

```lua
local Watermark = Aurora:Watermark({
    Enabled  = true,
    Title    = "Aurora Premium",                     -- Customizable title prefix
    Position = UDim2.new(0, 20, 0, 20)               -- Custom Screen Gui position
})

Watermark:SetTitle("Custom Overlay Title")           -- Dynamically update title
Watermark:Destroy()                                  -- Hide and clean up stats HUD
```

### 3. Keybinds List HUD Tracker
Creates a draggable floating HUD box that dynamically scans `Aurora.Options` for registered hotkeys and displays them. It auto-updates whenever keys are bound or changed in the menu:

```lua
local KeybindList = Aurora:KeybindList({
    Enabled  = true,
    Position = UDim2.new(1, -200, 0.5, -100)         -- Initial floating position
})

KeybindList:Refresh()                                -- Force manual refresh of keybind items
KeybindList:Destroy()                                -- Hide and clean up keybind HUD tracker
```

### 4. Draggable Status HUD Panel (NEW)
Creates a draggable custom HUD monitor overlay to display any script status or values (e.g. state, active process, etc.):

```lua
local HUD = Aurora:CreateHUD({
    Title = "Status Monitor",
    Width = 220,                                     -- Width in pixels
    Position = UDim2.new(0, 20, 0, 200)              -- Initial floating position
})

HUD:SetItem("Status", "Idle")                        -- Set item key and value
HUD:SetItem("Activity", "Harvesting")
HUD:Toggle(true)                                     -- Show/hide HUD
```

---

## 💬 Modal Dialog System

Create premium centered modal overlays on top of the main window with elastic open/close animations:

```lua
Window:Dialog({
    Title = "Premium Modal Dialog",
    Content = "This is a premium modal popup block that stays centered and overlays the script menu.",
    Buttons = {
        {
            Title = "Cancel",
            Callback = function()
                print("Clicked Cancel")
            end
        },
        {
            Title = "Confirm Action",
            Callback = function()
                print("Clicked Confirm")
            end
        }
    }
})
```

---

## 💾 SaveManager API

AuroraLib contains a built-in SaveManager to easily persist script options.

```lua
-- Initialize SaveManager
Aurora.SaveManager:SetLibrary(Aurora)
Aurora.SaveManager:SetFolder("AuroraSettings/BoogaBooga")

-- Build config options inside a UI section (creates input, dropdown, buttons automatically)
-- This automatically appends the "Auto-save on change" option checkbox!
Aurora.SaveManager:BuildConfigSection(Section)

-- Load previously autoloaded configurations at startup
Aurora.SaveManager:LoadAutoloadConfig()
```

### Native Autosave:
When `Auto-save on change` is toggled on in the UI, any modification to interactive elements (`Toggles`, `Sliders`, `Dropdowns`, `Keybinds`, `Colorpickers`, and `Inputs`) will trigger an automatic save.

### Excluded Options:
To ignore specific keybinds or settings from config saves (e.g. theme selectors, menu hotkeys):
```lua
Aurora.SaveManager:IgnoreIndexes({ "ThemeSelector", "AimbotBind" })
```

---

## 🔑 Built-in Key System

AuroraLib has a built-in premium license verification system. It blocks your script execution, prompts the user to enter a key with custom styled overlays, and supports caching keys locally in the Roblox `workspace/` folder.

```lua
local keyVerified = false
Aurora.KeySystem.new({
    Title = "Aurora Verification",
    SubTitle = "License Verification Required",
    Note = "Get your free license key from our Discord server. Keys update every 24 hours!",
    Keys = {"AuroraKey2026", "DevKey"},       -- Local valid keys list
    KeyLink = "https://discord.gg/auroralib", -- Link to obtain key
    SaveKey = true,                           -- Cache verified key to file
    FileName = "AuroraLicense_Cache.txt",     -- Cache file name in workspace/
    OnSuccess = function()
        keyVerified = true
    end,
    CustomValidate = function(key)            -- Optional custom validation (e.g. remote API fetch)
        return key == "SpecialRemoteKey"
    end
})

-- Wait for validation success
repeat task.wait(0.2) until keyVerified
```

---

## 🗂️ Navigation & Structure

AuroraLib v4.0 supports a structured layout: **Categories ➔ Tabs (Pages) ➔ Sub-Tabs ➔ Columns ➔ Sections ➔ Elements**.

### 1. Collapsible Sidebar Categories
```lua
local CatGame = Window:AddCategory("Booga Booga")
```

### 2. Tab Pages (Under Categories)
```lua
local BoogaTab = CatGame:AddTab({ Title = "Main Features", Icon = "solar/danger-bold" })
```

### 3. Horizontally Scrollable Sub-Tabs
Adds sub-navigation pages under tabs. If tabs overflow, the bar scroll-wheels horizontally automatically.
```lua
local SubCombat = BoogaTab:AddSubTab("Combat")
local SubAuto   = BoogaTab:AddSubTab("Automation")
```

### 4. Layout Columns & Sections
Inside any tab or sub-tab page, split elements into a dual-column layout. Sections can optionally be made collapsible with a rotating chevron:
```lua
local LeftCol, RightCol = SubCombat:AddColumns()

-- Standard Section
local MiningSec = LeftCol:AddSection("Mining Settings")

-- Collapsible Section (starts collapsed by default)
local CollapsibleSec = RightCol:AddSection("Extra Settings", {
    Collapsible = true,
    DefaultExpanded = false
})
```

---

## ⚙️ Interactive UI Elements

### 💡 Element Tooltips
Interactive elements (Toggles, Sliders, Dropdowns, Buttons, Inputs, Keybinds, and Colorpickers) support an optional `Tooltip` parameter in their configuration table. Hovering the element displays a sleek cursor-following information box.

```lua
Section:AddToggle("MyToggle", {
    Title = "Example Toggle",
    Tooltip = "This is a premium hover tooltip that dynamically tracks your cursor!",
    Default = false
})
```

### 1. Toggles (with Inline Chaining)
```lua
local MineTgl = MiningSec:AddToggle("MineAura", {
    Title = "Mine Aura",
    Description = "Automatically mines minerals within range.",
    Default = false
})

-- Chain inline Keybind
MineTgl:AddKeybind("MineBind", { Default = Enum.KeyCode.F })

-- Chain inline Colorpicker
MineTgl:AddColorpicker("MineIndicatorColor", { Default = Color3.fromRGB(255, 60, 60) })
```

### 2. Direct-Entry Sliders
```lua
MiningSec:AddSlider("MineRange", {
    Title = "Mine Range",
    Min = 5,
    Max = 55,
    Default = 15,
    Decimals = 0,
    Suffix = " studs",
    Callback = function(val)
        print("Range changed to:", val)
    end
})
```

### 3. Searchable Dropdowns
```lua
MiningSec:AddDropdown("OreFilter", {
    Title = "Target Ores",
    Values = { "Gold", "Iron", "God Rock", "Mojo" },
    Default = "Gold",
    Multi = false, -- Single-select (use Multi = true for multi-select)
    Callback = function(val)
        print("Selected ore:", val)
    end
})
```

### 4. Standalone Inputs
```lua
MiningSec:AddInput("ClanTag", {
    Title = "Clan Tag Customizer",
    Placeholder = "Enter tag...",
    Default = "Aurora",
    Callback = function(txt)
        print("Clan tag changed:", txt)
    end
})
```

### 5. Standalone Keybinds
Standalone keybind element. Supports binding to both standard keyboard keys AND mouse buttons (like `MouseButton2` / right click, displaying as `MB2` in the UI):
```lua
MiningSec:AddKeybind("AimbotHotkey", {
    Title = "Aimbot Keybind",
    Default = Enum.KeyCode.E,
    Callback = function(key)
        print("Aimbot key changed to:", key)
    end
})
```

### 6. Standalone Colorpickers
Standalone 2D SV Canvas colorpicker selector element:
```lua
MiningSec:AddColorpicker("ESPColor", {
    Title = "ESP Color Selector",
    Default = Color3.fromRGB(0, 255, 170),
    Callback = function(color)
        print("Selected color:", color)
    end
})
```

### 5. Advanced Elements (Label, Divider, Space, Image, Audio, Code, Video, Alert, Separator)

#### Label:
Inserts a simple read-only label.
```lua
local LabelObj = Section:AddLabel("StatusLabel", "System Status: Operating normally")
LabelObj:SetText("System Status: Updating...")
```

#### Divider:
Inserts a thin horizontal separator line.
```lua
Section:AddDivider()
```

#### Space:
Inserts a blank gap of a specified height.
```lua
Section:AddSpace(12)
```

#### Image:
Displays a static asset or logo.
```lua
local ImageObj = Section:AddImage("LogoGraphic", {
    Size = UDim2.fromOffset(200, 100),
    Image = "rbxassetid://10849890695"
})
ImageObj:SetImage("rbxassetid://new_id")
```

#### Audio Player:
A retro audio play/stop control bar.
```lua
local SoundObj = Section:AddAudio("BGMusic", {
    Title = "Game Music Loop",
    SoundId = 1843431602,
    Volume = 0.4,
    Looped = true
})
```

#### Code Block:
A code box with code font styling and a working Copy button.
```lua
local CodeObj = Section:AddCode("LoadScript", {
    Title = "Load Script Raw",
    Code = "print('Hello Aurora')"
})
CodeObj:SetCode("print('Hello World')")
```

#### Video Player:
A premium video player panel that plays Roblox video assets with custom playback controls.
```lua
local VideoObj = Section:AddVideo("DemoVid", {
    Title = "Cool Trailer Video",
    Video = 5608688234,      -- Roblox video asset ID (rbxassetid://... or number)
    Volume = 0.3,            -- Default volume (0.0 to 1.0)
    Looped = true,           -- Loops video play (Default: true)
    AutoPlay = true,         -- Plays on load (Default: true)
    Height = 150             -- Custom player height (Default: 160)
})

VideoObj:Play()
VideoObj:Pause()
VideoObj:SetVolume(0.5)
```

#### Alert Banner:
Inserts a beautiful warning, info, error, or success alert block:
```lua
Section:AddAlert({
    Title = "Database Sync",
    Content = "All user configurations are fully loaded and active.",
    Type = "Success" -- Types: "Info", "Warning", "Error", "Success"
})
```

#### Progress Bar:
Inserts a progress bar element to display loading/processing percentages.
```lua
local ProgressBar = Section:AddProgressBar("MyProgress", {
    Title = "Farming Process"
})

ProgressBar:SetProgress(65) -- Set progress percentage (0 - 100)
ProgressBar:SetTitle("Custom Farming Title")
```

#### Text Separator:
Inserts a horizontal separator line with a centered bold text label:
```lua
Section:AddSeparator("DEVELOPER SETTINGS")
```

---

## 👁️ Dynamic Element Visibility (SetVisible)

All elements returned by the library (such as Toggles, Sliders, Dropdowns, Paragraphs, Alerts, separators, etc.) expose a `:SetVisible(state)` method. This allows you to show or hide options dynamically at runtime. When elements are hidden, the layout automatically shifts items up to fill the empty space.

```lua
local AimbotTgl = Section:AddToggle("Aimbot", { Title = "Enable Aimbot" })
local FOVSlider = Section:AddSlider("FOV", { Title = "FOV Range", Default = 90 })

-- Hide FOV slider initially
FOVSlider:SetVisible(false)

-- Dynamically toggle visibility based on main Aimbot switch
AimbotTgl:OnChanged(function(v)
    FOVSlider:SetVisible(v)
end)
```

---

## 🎨 Global Options API

Retrieve any UI element's active value programmatically using its `id`:

```lua
local mineAuraActive = Aurora.Options.MineAura.Value       -- Boolean
local targetOre      = Aurora.Options.OreFilter.Value      -- String or Table
local rangeValue     = Aurora.Options.MineRange.Value      -- Number
local clanTagStr     = Aurora.Options.ClanTag.Value        -- String
```

---

## 🛠️ Complete Integration Example

To view a fully constructed script showing how all of these components work together, please refer to the [AuroraExample.lua](file:///c:/Users/locop/OneDrive/Desktop/scritp/Deds/UILibrary/AuroraExample.lua) file inside the project directory.

---

Made with ❤️ by **DrakarDev**
