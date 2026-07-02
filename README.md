# AuroraLib — Complete Documentation

**Premium, scalable, icon-ready custom Roblox UI library** with an Apple-inspired design language: fully rounded elements, pill sub-tabs, glass windows, 8-direction resizing, searchable dropdowns, animated toggles, inline colorpickers, keybinds, a key system, config saving, notifications, and more.

---

## Table of Contents

1. [Quick Load](#quick-load)
2. [Creating a Window](#creating-a-window)
3. [Loading Screen](#loading-screen)
4. [Navigation: Categories → Tabs → SubTabs → Sections](#navigation)
5. [Elements](#elements)
6. [Themes](#themes)
7. [Notifications](#notifications)
8. [Dialogs](#dialogs)
9. [SaveManager](#savemanager)
10. [Key System](#key-system)
11. [Sounds](#sounds)
12. [Auto-Execute (load on rejoin)](#auto-execute)
13. [Executor & Platform Info](#executor--platform-info)
14. [Global Options API](#global-options-api)
15. [HUD & Overlays](#hud--overlays)
16. [Media Elements](#media-elements)
17. [3D Viewport](#3d-viewport)
18. [Full Example](#full-example)

---

## Quick Load

```lua
local Aurora = loadstring(game:HttpGet(
    "https://raw.githubusercontent.com/DrakarDev/XAuroraLibX/refs/heads/main/AuroraLibrary.lua"
))()
```

If you host your own copy, replace the URL. For local testing with an executor:

```lua
local Aurora = loadstring(readfile("AuroraLibrary.lua"))()
```

---

## Creating a Window

```lua
local Window = Aurora:CreateWindow({
    Title        = "My Script",                 -- Title shown in the sidebar
    SubTitle     = "By DyxDev",                 -- Subtitle under the title
    Theme        = "Dark",                      -- Any theme name (see Themes)
    Scale        = 1.0,                         -- UI scale (0.7 – 2.0)
    Size         = UDim2.fromOffset(720, 530),  -- Default window size
    MinimizeKey  = Enum.KeyCode.RightControl,   -- Key to toggle the GUI
    Acrylic      = false,                       -- Glass/blur background
    LazyLoad     = true,                        -- Progressive element loading
    FadeIn       = true,                        -- Elements fade in on load

    -- Loading screen (see next section)
    LoadingScreen   = true,                     -- false disables the intro
    LoadingText     = "Loading...",             -- Subtitle on the intro
    LoadingIcon     = "solar/star-bold",        -- Logo icon on the intro
    LoadingDuration = 2.0,                       -- Seconds

    -- Mobile
    MobileButton    = false,                    -- Force the floating toggle button on PC too

    -- Auto-execute (see Auto-Execute section)
    AutoExecute     = nil,                      -- URL/code to install into the executor autoexec folder
    AutoExecuteName = "AuroraAutoLoad.lua",

    DelayPerElement = 0.01,
    DelayPerSection = 0.02,
    DelayPerTab     = 0.05,
})
```

### Window Methods

```lua
Window:SetVisible(true)               -- Show or hide the window
Window:Toggle()                       -- Toggle visibility
Window:SetMinimizeKey(Enum.KeyCode.F) -- Change the toggle key at runtime
Window:Destroy()                      -- Destroy the UI and clean up connections
Window:Dialog({ ... })                -- Modal dialog (see Dialogs)
```

**Show/Hide performance:** hiding the window fades it out and disables the GUI so it no longer captures clicks (you can move your camera freely where the UI used to be). Showing it fades back in. There is no lag spike on toggle.

---

## Loading Screen

An animated intro plays when the window is created. It shows a glowing logo, a spinning ring, an animated title, and a real progress bar with a percentage counter, then fades into the window.

Control it from `CreateWindow`:

| Option | Default | Description |
|---|---|---|
| `LoadingScreen` | `true` | Set `false` to skip the intro |
| `LoadingText` | `SubTitle` | Subtitle text under the logo |
| `LoadingIcon` | `Icon` or `solar/star-bold` | Icon shown in the center |
| `LoadingDuration` | `2.0` | Length in seconds |

---

## Navigation

The layout hierarchy is: **Window → Category → Tab → SubTab → Section → Elements**

### 1. Category (sidebar group header)

```lua
local MyCategory = Window:AddCategory("Main Features", "solar/star-bold")
```

### 2. Tab (inside a category or standalone)

```lua
-- Inside a category:
local CombatTab = MyCategory:AddTab({ Title = "Combat", Icon = "solar/sword-bold" })

-- Standalone (no category):
local SettingsTab = Window:AddTab({ Title = "Settings", Icon = "solar/settings-bold" })
```

### 3. SubTabs (pill-style, shown at the top of a tab)

```lua
local AimTab  = CombatTab:AddSubTab("Aimbot")
local ESPTab  = CombatTab:AddSubTab("ESP")
local MiscTab = CombatTab:AddSubTab("Misc")
```

SubTabs animate with a slide transition when switching, and highlight on hover.

### 4. Sections (inside a tab or subtab)

```lua
-- Simple section:
local AimSection = CombatTab:AddSection("Aimbot Settings")

-- Inside a subtab:
local AimSection = AimTab:AddSection("Aimbot Settings")

-- Two-column layout:
local LeftCol, RightCol = CombatTab:AddColumns()
local LeftSec  = LeftCol:AddSection("Left Panel")
local RightSec = RightCol:AddSection("Right Panel")

-- Collapsible section:
local ExtraSec = LeftCol:AddSection("Extra", { Collapsible = true, DefaultExpanded = false })
ExtraSec:SetCollapsed(true) -- Collapse/expand at runtime
```

---

## Elements

Every element takes an **id** (string) and a **cfg** (table). The id lets you read the value anywhere via `Aurora.Options.<id>.Value`.

### Toggle

```lua
local Tgl = AimSection:AddToggle("AimbotEnabled", {
    Title       = "Enable Aimbot",
    Description = "Snaps aim to the nearest target",  -- optional subtitle
    Default     = false,
    Icon        = "solar/cursor-bold",                -- optional
    Tooltip     = "Toggle aimbot on/off",             -- optional hover tip
    Callback    = function(value) print("Aimbot:", value) end,
})

Tgl:SetValue(true)                 -- Set state programmatically
Tgl:OnChanged(function(v) end)     -- Subscribe to changes

-- Inline add-ons:
Tgl:AddKeybind("AimbotKey", { Default = Enum.KeyCode.E })
Tgl:AddColorpicker("AimbotColor", { Default = Color3.fromRGB(255, 0, 0) })
```

### Slider

```lua
local Sld = AimSection:AddSlider("FOV", {
    Title    = "FOV Circle",
    Min      = 10,
    Max      = 500,
    Default  = 150,
    Step     = 5,          -- OPTIONAL: snap to increments (0/5/10...). Omit for smooth.
    Suffix   = " px",
    Callback = function(value) print("FOV:", value) end,
})

Sld:SetValue(200)
Sld:OnChanged(function(v) print(v) end)
```

While dragging, a **value tooltip** floats above the knob. You can also **click the value** to type an exact number.

### Dropdown

```lua
local Drop = AimSection:AddDropdown("TargetPart", {
    Title           = "Target Part",
    Values          = { "Head", "Torso", "Root" },
    Default         = "Head",
    Multi           = false,   -- true = multi-select (Value is a table)
    SearchThreshold = 6,       -- OPTIONAL: only show the search box when options > this (default 6)
    Callback        = function(value) print("Target:", value) end,
})

Drop:Refresh({ "Head", "Torso", "Random" }) -- Replace options
Drop:SetValue("Torso")                       -- Set selection
Drop:OnChanged(function(v) print(v) end)
```

The search box appears automatically only for longer lists, so small dropdowns stay clean.

### Button

```lua
local Btn = AimSection:AddButton({
    Title       = "Execute Script",
    Description = "Runs the main loop",
    Icon        = "solar/play-bold",
    Callback    = function() print("Button clicked!") end,
})

Btn:SetTitle("Running...")
Btn:SetDesc("Executing now...")
```

Buttons play a click sound (see [Sounds](#sounds)) and show a ripple effect.

### Input (Text Box)

```lua
local Inp = AimSection:AddInput("PlayerName", {
    Title       = "Target Name",
    Default     = "",
    Placeholder = "Enter player name",
    Callback    = function(text) print("Input:", text) end,
})

Inp:SetValue("Player1")
Inp:OnChanged(function(t) print(t) end)
```

### Keybind (standalone)

```lua
local Key = AimSection:AddKeybind("PanicKey", {
    Title    = "Panic Key",
    Default  = Enum.KeyCode.Delete,
    Mode     = "Hold",   -- "Hold" (default) or "Toggle"
    Callback = function(key, active) print("Key:", key, "Active:", active) end,
})

Key:SetValue(Enum.KeyCode.End)
Key:OnChanged(function(k) print(k) end)
Key:IsActive()   -- true while the key is held (Hold) or toggled on (Toggle)
```

- **Mode `"Hold"`** (default): active only while the key is held down.
- **Mode `"Toggle"`**: one press flips active on/off (great for fly, noclip, etc.). The callback receives `(key, active)`.
- **Right-click** a keybind to clear it (set to `None`), or press **Escape** while rebinding.

### Colorpicker (standalone)

```lua
local CP = AimSection:AddColorpicker("ESPColor", {
    Title    = "ESP Color",
    Default  = Color3.fromRGB(255, 0, 0),
    Callback = function(color) print(color) end,
})

CP:SetValue(Color3.fromRGB(0, 255, 170))
CP:SetValueRGB(Color3.new(1, 0, 0), 0.5)  -- with transparency
CP:OnChanged(function(c) print(c) end)
```

The panel includes an HSV picker, a hue bar, and **Hex + RGB** input fields.

### Label & LiveStat

```lua
local Lbl = AimSection:AddLabel("StatusLbl", "Status: Active")
Lbl:SetText("Status: Idle")

local Stat = AimSection:AddLiveStat("GoldDisplay", {
    Title   = "Total Gold",
    Default = "0",
    Icon    = "solar/wad-of-money-bold",
    Color   = Color3.fromRGB(255, 215, 0),
})
Stat:SetText("1500")
Stat:SetText("2000", Color3.fromRGB(0, 255, 100)) -- new value with a new color
```

### Paragraph

```lua
local Para = AimSection:AddParagraph({
    Title   = "Notice",
    Content = "This feature requires a public server.",
})
Para:SetTitle("Updated Notice")
Para:SetContent("New content here.")
```

### Progress Bar

```lua
local Prog = AimSection:AddProgressBar("FarmProgress", { Title = "Farm Progress" })
Prog:SetProgress(0.75)          -- 0.0 to 1.0
Prog:SetTitle("Almost done...")
```

### Alert, Divider, Space, Separator

```lua
AimSection:AddAlert({
    Title   = "Warning",
    Content = "This may cause lag.",
    Type    = "Warning",   -- "Info", "Success", "Error", "Warning"
})

AimSection:AddDivider()
AimSection:AddSpace(10)                       -- pixel gap
AimSection:AddSeparator("──── SECTION ────")  -- labeled divider
```

---

## Themes

Over 25 built-in themes: `Dark`, `Light`, `Ocean`, `Amethyst`, `Neon`, `BloodRed`, `Midnight`, `NeonCyber`, `ArcticFrost`, `CottonCandy`, `Orange`, `Cyanic`, `AmberGlow`, `DeepViolet`, `Charcoal`, `PearlWhite`, `Galaxy`, `AMOLED`, `AshGray`, `NeonPurple`, `RoyalBlue`, `DeepOcean`, `MidnightBlue`, `CosmicViolet`, `Sakura`, `RGB` (chroma).

```lua
-- Switch theme at runtime:
Aurora:SetTheme("Ocean")

-- Create a custom theme (missing keys fall back to Dark):
Aurora:CreateTheme("MyTheme", {
    Background = Color3.fromRGB(10, 10, 14),
    Accent     = Color3.fromRGB(0, 200, 255),
    Text       = Color3.fromRGB(240, 240, 255),
    Border     = Color3.fromRGB(40, 40, 55),
})
```

---

## Notifications

```lua
-- Basic:
Aurora:Notify({ Title = "Done!", Content = "Script loaded.", Type = "Success", Duration = 5 })

-- With buttons:
Aurora:Notify({
    Title = "Confirm", Content = "Continue?", Type = "Warning", Duration = 0,
    Buttons = {
        { Title = "Yes",    Callback = function() print("confirmed") end },
        { Title = "Cancel", Callback = function() end },
    },
})

-- With an input field:
Aurora:Notify({
    Title = "Enter name", Input = true, InputPlaceholder = "Your name...",
    InputCallback = function(text) print("Got:", text) end,
})

-- Dynamic (returns a controller):
local notif = Aurora:Notify({ Title = "Loading", Content = "Please wait...", Duration = 0 })
notif:SetProgress(0.5)
notif:Update({ Title = "Done!", Content = "Finished!", Type = "Success", Duration = 3 })
notif:Close()
```

Notifications show a **countdown bar**, an animated icon, and **pause when you hover over them** (so you can finish reading before they close).

`Type` can be `Info`, `Success`, `Error`, or `Warning`. `Duration = 0` keeps it open until closed.

---

## Dialogs

```lua
Window:Dialog({
    Title   = "Confirmation",
    Content = "Reset all settings?",
    Buttons = {
        { Title = "Cancel" },
        { Title = "Reset", Callback = function() resetAllSettings() end },
    },
})
```

---

## SaveManager

```lua
Aurora.SaveManager:SetLibrary(Aurora)
Aurora.SaveManager:SetFolder("MyScript/Config")
Aurora.SaveManager:IgnoreIndexes({ "ThemeSelector" })

-- Build a config UI (save/load/list) automatically inside a section:
Aurora.SaveManager:BuildConfigSection(SettingsSection)

-- Auto-load the last used config (great for rejoins):
Aurora.SaveManager:LoadAutoloadConfig()

-- Cloud config sharing:
Aurora.SaveManager:SaveCloud("MyConfig", "DyxDev", "Best settings", "BoogaBooga")
Aurora.SaveManager:LoadCloud("MyConfig")
```

---

## Key System

A verification screen users must pass before your script loads. Supports a fixed key list, custom (server/Luarmor-style) validation, saved keys, a **method dropdown**, **social buttons**, and an **exit button**.

```lua
local verified = false

Aurora.KeySystem.new({
    Title    = "My Script",
    SubTitle = "License Verification",
    Note     = "Choose a method below to get your key.",

    -- Simple: fixed valid keys
    Keys     = { "FREE-KEY-2026", "VIP-KEY-ABC" },

    SaveKey  = true,                    -- Remember a valid key (skips the screen on rejoin)
    FileName = "MyScript_Key.txt",      -- Where the key is stored

    -- Method dropdown: users pick how to get the key; "Get Key" copies the chosen link
    KeyMethods = {
        { Name = "Linkvertise", Link = "https://linkvertise.com/xxxx" },
        { Name = "Lootlabs",    Link = "https://lootlabs.gg/xxxx" },
        { Name = "Discord",     Link = "https://discord.gg/example" },
    },

    -- Social / Discord-style buttons (each copies its link to clipboard)
    Links = {
        { Title = "Discord", Link = "https://discord.gg/example", Icon = "solar/chat-round-bold" }, -- auto blurple
        { Title = "YouTube", Link = "https://youtube.com/@x", Color = Color3.fromRGB(220,50,50), Icon = "solar/play-bold" },
    },

    ShowExit = true,                    -- X button (top-right). Default true.
    OnExit   = function() print("closed") end,

    OnSuccess = function() verified = true end,
})

repeat task.wait(0.1) until verified
```

### Custom validation (Luarmor / your own API)

Instead of a fixed key list, validate against a backend. `CustomValidate(key)` must return `true`/`false`.

```lua
local HWID = Aurora.KeySystem.GetHWID()   -- the user's HWID (for Luarmor, etc.)

Aurora.KeySystem.new({
    Title = "My Script", SubTitle = "License Verification",
    Note  = "HWID: " .. HWID,
    SaveKey = true, FileName = "MyScript_Key.txt",
    CustomValidate = function(key)
        local ok, res = pcall(function()
            return game:HttpGet("https://your-api.com/validate?key="..key.."&hwid="..HWID) == "valid"
        end)
        return ok and res
    end,
    OnSuccess = function() verified = true end,
})
```

**UX details:** an incorrect key shakes the window and flashes the input red; pressing **Enter** submits; the **Get Key** button copies the selected method's link; links **copy to clipboard** (executors can't reliably open a browser).

---

## Sounds

All UI sounds live in one central table so you can swap any of them.

```lua
Aurora.SoundEnabled = true                 -- master switch (false = mute everything)

-- Default keys (values are Roblox Creator Store asset IDs — swap as needed):
-- Click, Toggle, Open, Close, Hover, Success, Error, Warning, Info
Aurora:SetSound("Click", 876939830)        -- change one sound
Aurora:PlaySound("Success", 0.4)           -- play a sound manually (name, optional volume)
```

Buttons play `Click`, toggles play `Toggle`, notifications play their type sound. All calls are wrapped safely — if an asset can't load, nothing breaks, it just stays silent.

> Roblox audio availability changes (moderation/privacy). If a sound doesn't play, grab a free-to-use ID from the Creator Store (Toolbox → Audio → right-click → Copy Asset ID) and set it via `Aurora:SetSound`.

---

## Auto-Execute

Make the GUI come back automatically when the player rejoins. The library writes your script into the executor's **autoexec** folder so it re-runs on the next launch. Combined with `SaveKey` (key system) and `LoadAutoloadConfig` (SaveManager), the whole UI restores itself.

```lua
-- Install (URL is wrapped in loadstring(game:HttpGet(...)) automatically):
Aurora:SetupAutoExecute("https://raw.githubusercontent.com/you/repo/main/script.lua")

-- Or via CreateWindow:
Aurora:CreateWindow({ ..., AutoExecute = "https://.../script.lua" })

-- Remove it:
Aurora:RemoveAutoExecute()
```

> This depends on the executor supporting `writefile` and an autoexec folder. Everything is wrapped in `pcall`, so unsupported executors simply won't install it (no errors).

---

## Executor & Platform Info

The sidebar profile panel automatically shows the player's avatar, name, and a third line with the **executor name and platform** (e.g. `Synapse X • PC` or `Fluxus • Mobile`). It's detected via `identifyexecutor()` / `getexecutorname()` and the library's own mobile detection. No setup needed.

You can also read the HWID directly:

```lua
local hwid = Aurora.KeySystem.GetHWID()
```

---

## Global Options API

Read any element's current value from anywhere using its id:

```lua
local enabled = Aurora.Options.AimbotEnabled.Value
local fov     = Aurora.Options.FOV.Value
local target  = Aurora.Options.TargetPart.Value
local color   = Aurora.Options.ESPColor.Value
local key     = Aurora.Options.PanicKey.Value
```

---

## HUD & Overlays

```lua
-- Watermark:
local WM = Aurora:Watermark({ Enabled = true, Title = "My Script v1.0" })
WM:SetTitle("My Script | FPS: 60")
WM:Destroy()

-- Keybind tracker (lists active keybinds on screen):
local KB = Aurora:KeybindList({ Enabled = true })
KB:Destroy()

-- Custom HUD panel:
local HUD = Aurora:CreateHUD({ Title = "Stats", Width = 220 })
HUD:SetItem("Status", "Running")
HUD:SetItem("FPS", "60")
HUD:Toggle(true)
```

---

## Media Elements

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

## 3D Viewport

```lua
local VP = Section:AddViewport("Preview", {
    Title = "Character Preview", Height = 220,
    AutoSpin = true, SpinSpeed = 25, CameraDistance = 7,
})
VP:SetPlayer("local")          -- Live local character
VP:SetPlayer("PlayerName")     -- Another player
VP:SetWorkspaceModel("Tree")   -- Any workspace model
VP:Spin(30)                    -- Spin speed in °/sec (0 = stop)
VP:SetCamera(10, 30)           -- Distance and elevation
VP:Clear()                     -- Remove the model
```

---

## Full Example

```lua
local Aurora = loadstring(game:HttpGet(
    "https://raw.githubusercontent.com/DrakarDev/XAuroraLibX/refs/heads/main/AuroraLibrary.lua"
))()

-- Optional key gate
local verified = false
Aurora.KeySystem.new({
    Title = "My Script", SubTitle = "License Verification",
    Note  = "Get your key below.",
    Keys  = { "FREE-KEY-2026" },
    SaveKey = true, FileName = "MyScript_Key.txt",
    KeyMethods = { { Name = "Discord", Link = "https://discord.gg/example" } },
    Links      = { { Title = "Discord", Link = "https://discord.gg/example", Icon = "solar/chat-round-bold" } },
    ShowExit   = true,
    OnSuccess  = function() verified = true end,
})
repeat task.wait(0.1) until verified

-- Window
local Window = Aurora:CreateWindow({
    Title       = "My Script",
    SubTitle    = "By DyxDev",
    Theme       = "Dark",
    MinimizeKey = Enum.KeyCode.RightControl,
    LoadingText = "Preparing everything...",
})

local Cat     = Window:AddCategory("Features", "solar/star-bold")
local MainTab = Cat:AddTab({ Title = "Main", Icon = "solar/home-bold" })
local MainSec = MainTab:AddSection("General")

local TglAim = MainSec:AddToggle("AimbotOn", {
    Title = "Aimbot", Default = false,
    Callback = function(v) print("Aimbot:", v) end,
})
TglAim:AddKeybind("AimbotKey", { Default = Enum.KeyCode.E })

MainSec:AddSlider("AimFOV", {
    Title = "FOV", Min = 10, Max = 500, Default = 150, Step = 10, Suffix = " px",
    Callback = function(v) print("FOV:", v) end,
})

MainSec:AddDropdown("AimPart", {
    Title = "Target Part", Values = { "Head", "Torso" }, Default = "Head",
    Callback = function(v) print("Part:", v) end,
})

MainSec:AddKeybind("Fly", { Title = "Fly", Default = Enum.KeyCode.F, Mode = "Toggle",
    Callback = function(k, active) print("Fly:", active) end })

MainSec:AddButton({
    Title = "Execute",
    Callback = function() Aurora:Notify({ Title = "Done!", Type = "Success", Duration = 3 }) end,
})

-- Config saving
Aurora.SaveManager:SetLibrary(Aurora)
Aurora.SaveManager:SetFolder("MyScript/Config")

Aurora:Notify({ Title = "Loaded", Content = "My Script is ready!", Type = "Success", Duration = 4 })
```

---

*Design inspired by Apple HIG. Made with ❤️ by **DrakarDev**.*
