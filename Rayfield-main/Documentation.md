# Rayfield Interface Suite — API Documentation

**Version:** Build 2.0  
**Enhanced Edition** with new themes, elements, and improvements.

---

## Table of Contents

1. [Getting Started](#getting-started)
2. [Window Configuration](#window-configuration)
3. [Tabs](#tabs)
4. [Elements Reference](#elements-reference)
   - [Button](#button)
   - [Toggle](#toggle)
   - [Slider](#slider)
   - [Dropdown](#dropdown)
   - [Input](#input)
   - [Keybind](#keybind)
   - [ColorPicker](#colorpicker)
   - [Label](#label)
   - [Paragraph](#paragraph)
   - [Section](#section)
   - [Divider](#divider)
   - [ProgressBar](#progressbar-new) ⭐ New
   - [Separator](#separator-new) ⭐ New
   - [InfoCard](#infocard-new) ⭐ New
   - [NumberStepper](#numberstepper-new) ⭐ New
5. [Themes](#themes)
6. [Notifications](#notifications)
7. [Configuration Saving](#configuration-saving)
8. [Profile System](#profile-system) ⭐ New
9. [Key System](#key-system)
10. [API Methods](#api-methods)
11. [Migration Guide](#migration-guide)

---

## Getting Started

Load the library in your script:

```lua
local Rayfield = loadstring(game:HttpGet('https://sirius.menu/rayfield'))()
```

Or from the local file:

```lua
local Rayfield = loadstring(game:HttpGet('https://raw.githubusercontent.com/SiriusSoftwareLtd/Rayfield/main/source.lua'))()
```

**With error handling (recommended):**

```lua
local success, Rayfield = pcall(function()
    return loadstring(game:HttpGet('https://sirius.menu/rayfield'))()
end)
if not success then warn("Rayfield failed to load: " .. tostring(Rayfield)) return end
```

---

## Window Configuration

```lua
local Window = Rayfield:CreateWindow({
    Name             = "My Script",           -- Window title (string)
    Icon             = "layout-dashboard",    -- Lucide icon name or asset ID
    LoadingTitle     = "My Script",           -- Title shown during load
    LoadingSubtitle  = "by Author",           -- Subtitle shown during load
    Theme            = "Default",             -- Theme name or custom theme table

    ToggleUIKeybind  = "RightControl",        -- Hotkey to show/hide (string or KeyCode)

    DisableBuildWarnings    = false,          -- Suppress build mismatch notification
    DisableRayfieldPrompts  = false,          -- Suppress Rayfield promotional notifications

    ConfigurationSaving = {
        Enabled  = true,                      -- Enable auto-save
        FileName = "MyScriptConfig",          -- Save file name (defaults to PlaceId)
        FolderName = "Rayfield/Configurations", -- Folder (optional override)
    },

    Discord = {
        Enabled     = true,
        Invite      = "discord.gg/yourinvite",  -- Discord invite code/URL
        RememberJoins = true,                   -- Don't re-prompt if already joined
    },

    KeySystem   = false,                      -- Enable key gate
    KeySettings = { ... },                    -- Key system config (see Key System section)
})
```

### Window Methods

| Method | Description |
|--------|-------------|
| `Window.ModifyTheme(theme)` | Change the theme. Pass a theme name string or custom table. |

---

## Tabs

```lua
local Tab = Window:CreateTab(
    "Tab Name",    -- Display name (string)
    "home",        -- Icon: Lucide name (string) or asset ID (number), or 0 for no icon
    false          -- Internal: set true for the Rayfield Settings tab
)
```

Tabs appear in the top tab bar and contain all elements.

---

## Elements Reference

### Button

```lua
local Button = Tab:CreateButton({
    Name        = "My Button",             -- Display name
    Description = "Optional subtitle",    -- ⭐ Optional description text below name
    Disabled    = false,                   -- ⭐ Gray out and disable interaction
    Callback    = function()
        -- Runs when clicked
    end,
})
```

**Methods:**

| Method | Description |
|--------|-------------|
| `Button:Set(name)` | Change the button label |
| `Button:SetDisabled(bool)` | Enable or disable the button |
| `Button:SetVisible(bool)` | Show or hide the element |

---

### Toggle

```lua
local Toggle = Tab:CreateToggle({
    Name         = "My Toggle",
    CurrentValue = false,          -- Starting state
    Flag         = "MyToggle",     -- Unique flag for config saving
    Callback     = function(Value) -- Value is boolean
        print("Toggle:", Value)
    end,
})
```

**Methods:**

| Method | Description |
|--------|-------------|
| `Toggle:Set(bool)` | Set the toggle state programmatically |
| `Toggle:SetVisible(bool)` | Show or hide |

---

### Slider

```lua
local Slider = Tab:CreateSlider({
    Name         = "My Slider",
    Range        = {0, 100},       -- {min, max}
    Increment    = 1,              -- Step size
    Suffix       = "%",            -- Text appended to value display
    CurrentValue = 50,             -- Starting value
    Flag         = "MySlider",
    Callback     = function(Value) -- Value is number
        print("Slider:", Value)
    end,
})
```

**Methods:**

| Method | Description |
|--------|-------------|
| `Slider:Set(number)` | Set value programmatically (clamped to Range) |
| `Slider:SetVisible(bool)` | Show or hide |

---

### Dropdown

```lua
-- Single select
local Dropdown = Tab:CreateDropdown({
    Name          = "My Dropdown",
    Options       = {"Option A", "Option B", "Option C"},
    CurrentOption = "Option A",    -- Starting selection (string or {string})
    Flag          = "MyDropdown",
    Callback      = function(Option)   -- Option is always a table
        print("Selected:", Option[1])
    end,
})

-- Multi-select
local MultiDropdown = Tab:CreateDropdown({
    Name            = "My Multi Dropdown",
    Options         = {"A", "B", "C"},
    CurrentOption   = {"A", "B"},  -- Starting selections
    MultipleOptions = true,
    Flag            = "MyMultiDropdown",
    Callback        = function(Options) -- Options is a table of strings
        print("Selected:", table.concat(Options, ", "))
    end,
})
```

**Methods:**

| Method | Description |
|--------|-------------|
| `Dropdown:Set(option)` | Set selected option(s). Pass string or table. |
| `Dropdown:Refresh(optionsTable)` | Replace the options list |
| `Dropdown:SetVisible(bool)` | Show or hide |

---

### Input

```lua
local Input = Tab:CreateInput({
    Name                     = "My Input",
    PlaceholderText          = "Type here...",
    CurrentValue             = "",             -- Starting value
    Flag                     = "MyInput",
    RemoveTextAfterFocusLost = false,          -- Clear box on focus loss
    Callback                 = function(Value) -- Fires on focus lost
        print("Input:", Value)
    end,
})
```

**Methods:**

| Method | Description |
|--------|-------------|
| `Input:Set(text)` | Set value programmatically |
| `Input:SetVisible(bool)` | Show or hide |

---

### Keybind

```lua
local Keybind = Tab:CreateKeybind({
    Name           = "My Keybind",
    CurrentKeybind = "F",           -- Starting key name
    HoldToInteract = false,         -- If true, callback fires every frame while held
    Flag           = "MyKeybind",
    CallOnChange   = false,         -- If true, callback fires when key is changed (not pressed)
    Callback       = function()     -- Fires when key is pressed (or changed if CallOnChange)
        print("Keybind triggered!")
    end,
})
```

**Methods:**

| Method | Description |
|--------|-------------|
| `Keybind:Set(keyName)` | Set the keybind string |
| `Keybind:SetVisible(bool)` | Show or hide |

---

### ColorPicker

```lua
local ColorPicker = Tab:CreateColorPicker({
    Name     = "My Color Picker",
    Color    = Color3.fromRGB(255, 100, 100),   -- Starting color
    Flag     = "MyColor",
    Callback = function(Value)   -- Value is Color3
        print("Color:", Value)
    end,
})
```

Click the element to expand the full HSV picker with RGB sliders and hex input.

**Methods:**

| Method | Description |
|--------|-------------|
| `ColorPicker:Set(Color3)` | Set color programmatically |
| `ColorPicker:SetVisible(bool)` | Show or hide |

---

### Label

```lua
-- Plain label
local Label = Tab:CreateLabel("Some status text")

-- With icon and custom color
local Label = Tab:CreateLabel(
    "⭐ Gold Member",        -- Text
    "star",                   -- Lucide icon name or asset ID (optional)
    Color3.fromRGB(255,200,0),-- Background/stroke color (optional)
    true                      -- IgnoreTheme: keep color when theme changes
)
```

**Methods:**

| Method | Description |
|--------|-------------|
| `Label:Set(text, icon?, color?)` | Update text, icon, or color |
| `Label:SetVisible(bool)` | Show or hide |

---

### Paragraph

```lua
local Paragraph = Tab:CreateParagraph({
    Title   = "My Paragraph",
    Content = "This is the body text. It wraps automatically for longer content.",
})
```

**Methods:**

| Method | Description |
|--------|-------------|
| `Paragraph:Set({Title, Content})` | Update title and/or content |
| `Paragraph:SetVisible(bool)` | Show or hide |

---

### Section

```lua
Tab:CreateSection("Section Name")
```

Creates a labeled section header. Sections have no return value or methods.

---

### Divider

```lua
local Divider = Tab:CreateDivider()
```

Creates a thin horizontal rule.

**Methods:**

| Method | Description |
|--------|-------------|
| `Divider:Set(bool)` | Show or hide |

---

### ProgressBar ⭐ New

A bar that fills from 0 to 100% with an animated fill and percentage label.

```lua
local Progress = Tab:CreateProgressBar({
    Name        = "Download Progress",
    Progress    = 0.0,               -- Starting progress (0.0 to 1.0)
    Color       = Color3.fromRGB(88, 166, 255),  -- Fill color (optional)
    Description = "Downloading...",  -- Optional subtitle (not yet displayed in v2.0)
})

-- Update the bar:
Progress:Set(0.5)  -- 50%
Progress:Set(1.0)  -- 100%
Progress:SetColor(Color3.fromRGB(45, 200, 120))
```

**Methods:**

| Method | Description |
|--------|-------------|
| `Progress:Set(number)` | Set progress (0.0–1.0) with animation |
| `Progress:SetColor(Color3)` | Change the fill color |
| `Progress:SetVisible(bool)` | Show or hide |

---

### Separator ⭐ New

A thin horizontal rule, optionally with a centered text label.

```lua
-- Plain line
Tab:CreateSeparator()

-- With centered label
Tab:CreateSeparator("Section Label")
```

**Methods:**

| Method | Description |
|--------|-------------|
| `Separator:SetVisible(bool)` | Show or hide |

---

### InfoCard ⭐ New

A rich card with an accent strip, optional icon, title, description, and action button.

```lua
local Card = Tab:CreateInfoCard({
    Title       = "Important Notice",
    Description = "This is a detailed description that can span multiple lines.",
    Icon        = "alert-triangle",             -- Optional Lucide icon
    Color       = Color3.fromRGB(255, 185, 50), -- Accent color (optional)
    ButtonText  = "Action",                     -- Optional button label
    Callback    = function()                    -- Optional button callback
        print("Card action pressed")
    end,
})
```

**Methods:**

| Method | Description |
|--------|-------------|
| `Card:SetVisible(bool)` | Show or hide |

---

### NumberStepper ⭐ New

An element with +/− buttons to increment or decrement a number within a range.

```lua
local Stepper = Tab:CreateNumberStepper({
    Name     = "Max Attempts",
    Value    = 3,        -- Starting value
    Min      = 1,        -- Minimum value
    Max      = 10,       -- Maximum value
    Step     = 1,        -- Increment/decrement amount
    Flag     = "MaxAttempts",
    Callback = function(Value)
        print("Steps:", Value)
    end,
})
```

**Methods:**

| Method | Description |
|--------|-------------|
| `Stepper:Set(number)` | Set value programmatically |
| `Stepper:SetVisible(bool)` | Show or hide |

---

## Themes

### Built-in Themes

| Theme | Style |
|-------|-------|
| `Default` | Classic dark gray |
| `Ocean` | Deep teal / cyan |
| `AmberGlow` | Warm orange / amber |
| `Light` | Clean white / light gray |
| `Amethyst` | Purple / violet |
| `Green` | Soft pastel green |
| `Bloom` | Pink / rose |
| `DarkBlue` | Deep navy blue |
| `Serenity` | Muted blue-gray |
| `Midnight` ⭐ | Deep navy with electric blue accents |
| `Sunset` ⭐ | Warm purple-dark with orange-pink accents |
| `Nord` ⭐ | Classic Nord color palette |
| `Dracula` ⭐ | Dracula theme: purple, pink, cyan |
| `Cyberpunk` ⭐ | Neon cyan/magenta on pure black |
| `Monochrome` ⭐ | Pure grayscale |

### Applying a Theme

```lua
-- On window creation:
local Window = Rayfield:CreateWindow({ Theme = "Midnight", ... })

-- At runtime:
Window.ModifyTheme("Dracula")

-- Custom theme table:
Window.ModifyTheme({
    TextColor              = Color3.fromRGB(240, 240, 240),
    Background             = Color3.fromRGB(15, 15, 20),
    Topbar                 = Color3.fromRGB(20, 20, 30),
    -- ... (all 33 properties required)
})
```

### Custom Theme Properties

| Property | Type | Description |
|----------|------|-------------|
| `TextColor` | Color3 | All text labels |
| `Background` | Color3 | Main window background |
| `Topbar` | Color3 | Top bar background |
| `Shadow` | Color3 | Drop shadow color |
| `NotificationBackground` | Color3 | Notification card background |
| `TabBackground` | Color3 | Unselected tab button |
| `TabBackgroundSelected` | Color3 | Selected tab button |
| `TabTextColor` | Color3 | Unselected tab text |
| `SelectedTabTextColor` | Color3 | Selected tab text |
| `TabStroke` | Color3 | Tab button stroke |
| `ElementBackground` | Color3 | Standard element background |
| `ElementBackgroundHover` | Color3 | Element background on hover |
| `SecondaryElementBackground` | Color3 | Label/paragraph background |
| `ElementStroke` | Color3 | Element border/stroke |
| `SecondaryElementStroke` | Color3 | Secondary element stroke |
| `SliderBackground` | Color3 | Slider track background |
| `SliderProgress` | Color3 | Slider fill color |
| `SliderStroke` | Color3 | Slider stroke |
| `ToggleBackground` | Color3 | Toggle switch background |
| `ToggleEnabled` | Color3 | Toggle knob when ON |
| `ToggleDisabled` | Color3 | Toggle knob when OFF |
| `ToggleEnabledStroke` | Color3 | Toggle knob stroke when ON |
| `ToggleDisabledStroke` | Color3 | Toggle knob stroke when OFF |
| `ToggleEnabledOuterStroke` | Color3 | Toggle outer ring when ON |
| `ToggleDisabledOuterStroke` | Color3 | Toggle outer ring when OFF |
| `DropdownSelected` | Color3 | Selected dropdown option |
| `DropdownUnselected` | Color3 | Unselected dropdown option |
| `InputBackground` | Color3 | Input field background |
| `InputStroke` | Color3 | Input field border |
| `PlaceholderColor` | Color3 | Input placeholder text |

---

## Notifications

```lua
Rayfield:Notify({
    Title    = "Notification Title",       -- Required
    Content  = "Notification message.",    -- Required
    Duration = 5,                          -- Seconds (auto-calculated if omitted)
    Image    = "check-circle",             -- Lucide icon name or asset ID (optional)
    Type     = "info",                     -- Accent type: "info" | "success" | "warning" | "error"
})
```

### Notification Types

| Type | Color | Use Case |
|------|-------|----------|
| `info` (default) | Blue | General information |
| `success` | Green | Positive confirmation |
| `warning` | Amber | Caution or advisory |
| `error` | Red | Failure or problem |

---

## Configuration Saving

Enable in `CreateWindow`:

```lua
ConfigurationSaving = {
    Enabled  = true,
    FileName = "MyScriptConfig",
}
```

Add `Flag` to any element you want to save:

```lua
Tab:CreateToggle({ Name = "Auto Farm", Flag = "AutoFarm", ... })
Tab:CreateSlider({ Name = "Speed",     Flag = "Speed",    ... })
Tab:CreateKeybind({ Name = "Key",      Flag = "MyKey",    ... })
```

Load at the end of your script:

```lua
Rayfield:LoadConfiguration()
```

Supported element types for flags: Toggle, Slider, Dropdown, Input, Keybind, ColorPicker, NumberStepper.

---

## Profile System

Save and restore multiple named configurations.

```lua
-- Save current flags to a profile
Rayfield:SaveProfile("myProfile")

-- Load a profile
Rayfield:LoadProfile("myProfile")

-- List all saved profiles
local profiles = Rayfield:GetProfiles()  -- Returns {string}
print(table.concat(profiles, ", "))

-- Delete a profile
Rayfield:DeleteProfile("myProfile")
```

Profiles are saved in `Rayfield/Profiles/` and are independent of the main configuration file.

---

## Key System

```lua
local Window = Rayfield:CreateWindow({
    KeySystem = true,
    KeySettings = {
        Title          = "Key Required",
        Subtitle       = "My Script",
        Note           = "Get the key at discord.gg/myserver",
        FileName       = "MyScriptKey",       -- File to save verified key
        SaveKey        = true,                -- Remember key between sessions
        GrabKeyFromSite = false,              -- If true, fetches key from URL
        MaxAttempts    = 5,                   -- Wrong attempts before kick
        Key            = { "my-secret-key" } -- One or more valid keys
    },
    ...
})
```

When `GrabKeyFromSite = true`, each entry in `Key` is treated as a URL to fetch the key from.

---

## API Methods

```lua
-- Show or hide the interface (no notification)
Rayfield:SetVisibility(true)
Rayfield:SetVisibility(false)

-- Check if visible
local visible = Rayfield:IsVisible()  -- Returns boolean

-- Destroy the entire interface
Rayfield:Destroy()

-- Load the saved configuration (call at end of script)
Rayfield:LoadConfiguration()

-- Profile system
Rayfield:SaveProfile(name)
Rayfield:LoadProfile(name)
Rayfield:GetProfiles()
Rayfield:DeleteProfile(name)

-- Send a notification
Rayfield:Notify({ Title, Content, Duration, Image, Type })
```

---

## Migration Guide

### What's New in Build 2.0

**New Elements:**
- `Tab:CreateProgressBar()` — animated progress bar
- `Tab:CreateSeparator(text?)` — thin horizontal rule with optional label
- `Tab:CreateInfoCard()` — rich card with icon, title, description, and action button
- `Tab:CreateNumberStepper()` — +/− value selector

**New Themes:**
- Midnight, Sunset, Nord, Dracula, Cyberpunk, Monochrome

**Enhanced Elements:**
- All elements now support `Description` (subtitle text)
- All elements now support `Disabled` (greyed out state)  
- All elements now have `SetVisible()` and `SetDisabled()` methods
- Dropdown now has `Refresh(options)` to replace options list

**New Notifications:**
- `Type` parameter: `"info"` | `"success"` | `"warning"` | `"error"`

**Profile System:**
- `Rayfield:SaveProfile(name)` / `LoadProfile(name)` / `GetProfiles()` / `DeleteProfile(name)`

**Performance:**
- Cached TweenInfo objects (no GC churn)
- ColorPicker RenderStepped early-exit when picker is closed
- Centralized theme change listener system
- Helper functions replace 200+ duplicated code blocks

**Bug Fixes:**
- Fixed: `LoadConfiguration()` was called incorrectly (`.` vs `:`)
- Fixed: Deprecated `:connect` calls replaced with `:Connect`
- Fixed: Variable shadowing of `Main` inside ColorPicker
- Fixed: Keybind hold-to-interact callbacks now wrapped in `pcall`
- Fixed: Invalid KeyCode string no longer crashes input handler
- Fixed: `getSetting` now guards against missing categories
- Fixed: `game:GetObjects` for assets now wrapped in `pcall`
- Removed: ~250 lines of dead/commented code

**Breaking Changes:** None. All existing API calls remain identical.
