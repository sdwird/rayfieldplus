--[[
    Rayfield Interface Suite — Complete Example Script
    Demonstrates every element type and feature available.
    
    Load Rayfield from your executor with:
    local Rayfield = loadstring(game:HttpGet('https://sirius.menu/rayfield'))()
]]

local success, Rayfield = pcall(function()
    return loadstring(game:HttpGet('https://sirius.menu/rayfield'))()
end)

if not success or not Rayfield then
    warn("Failed to load Rayfield: " .. tostring(Rayfield))
    return
end

-- ═══════════════════════════════════════════════════════════════════
--  WINDOW CREATION
-- ═══════════════════════════════════════════════════════════════════

local Window = Rayfield:CreateWindow({
    Name             = "Rayfield Example Hub",
    Icon             = "layout-dashboard",       -- Lucide icon name (string)
    LoadingTitle     = "Example Hub",
    LoadingSubtitle  = "by YourName",
    Theme            = "Midnight",               -- New: Midnight, Sunset, Nord, Dracula, Cyberpunk, Monochrome, Default, Ocean, AmberGlow, etc.

    ToggleUIKeybind  = "RightControl",           -- Hotkey to show/hide

    ConfigurationSaving = {
        Enabled  = true,
        FileName = "ExampleHubConfig",
    },

    -- KeySystem = true,
    -- KeySettings = {
    --     Title    = "Key System",
    --     Subtitle = "Example Hub",
    --     Note     = "Get the key at discord.gg/example",
    --     FileName = "ExampleHubKey",
    --     SaveKey  = true,
    --     GrabKeyFromSite = false,
    --     Key      = { "example-key-123" },
    -- },
})

-- ═══════════════════════════════════════════════════════════════════
--  TAB 1: MAIN TAB (with icon)
-- ═══════════════════════════════════════════════════════════════════

local MainTab = Window:CreateTab("Main", "home")

MainTab:CreateSection("Information")

-- Info Card (new element)
MainTab:CreateInfoCard({
    Title       = "Welcome to Example Hub",
    Description = "This script demonstrates all Rayfield Interface Suite elements. Press RightControl to toggle visibility.",
    Icon        = "info",
    Color       = Color3.fromRGB(88, 166, 255),
    ButtonText  = "Discord",
    Callback    = function()
        Rayfield:Notify({
            Title   = "Discord",
            Content = "Opening discord invite...",
            Type    = "info",
        })
    end,
})

MainTab:CreateSeparator("Elements")

-- Button
MainTab:CreateSection("Basic Elements")
local MyButton = MainTab:CreateButton({
    Name        = "Click Me",
    Description = "This button runs a callback when clicked.",
    Callback    = function()
        Rayfield:Notify({
            Title   = "Button Pressed",
            Content = "You clicked the button!",
            Type    = "success",
            Duration = 3,
        })
    end,
})

-- Toggle
local MyToggle = MainTab:CreateToggle({
    Name         = "Enable Feature",
    CurrentValue = false,
    Flag         = "ToggleExample",
    Callback     = function(Value)
        print("Toggle is now:", Value)
        Rayfield:Notify({
            Title   = "Toggle Changed",
            Content = "Feature is now " .. (Value and "enabled" or "disabled"),
            Type    = Value and "success" or "info",
            Duration = 2,
        })
    end,
})

-- Slider
local MySlider = MainTab:CreateSlider({
    Name         = "Walk Speed",
    Range        = {16, 100},
    Increment    = 2,
    Suffix       = "studs/s",
    CurrentValue = 16,
    Flag         = "WalkSpeedSlider",
    Callback     = function(Value)
        -- game.Players.LocalPlayer.Character.Humanoid.WalkSpeed = Value
        print("Walk Speed:", Value)
    end,
})

-- Number Stepper (new element)
MainTab:CreateSection("Enhanced Controls")
local MyStepper = MainTab:CreateNumberStepper({
    Name     = "Jump Count",
    Value    = 1,
    Min      = 1,
    Max      = 10,
    Step     = 1,
    Flag     = "JumpCount",
    Callback = function(Value)
        print("Jump count set to:", Value)
    end,
})

-- Progress Bar (new element)
local MyProgress = MainTab:CreateProgressBar({
    Name     = "Loading Progress",
    Progress = 0.0,
    Color    = Color3.fromRGB(88, 166, 255),
})

-- Animate the progress bar as a demo
task.spawn(function()
    task.wait(2)
    for i = 1, 10 do
        task.wait(0.5)
        MyProgress:Set(i / 10)
    end
end)

-- ═══════════════════════════════════════════════════════════════════
--  TAB 2: INPUTS TAB
-- ═══════════════════════════════════════════════════════════════════

local InputsTab = Window:CreateTab("Inputs", "type")

InputsTab:CreateSection("Dropdowns")

-- Dropdown (single select)
local MyDropdown = InputsTab:CreateDropdown({
    Name          = "Select Server Region",
    Options       = {"Auto", "NA East", "NA West", "EU", "Asia", "Oceania"},
    CurrentOption = "Auto",
    Flag          = "ServerRegion",
    Callback      = function(Option)
        print("Selected region:", Option[1])
        Rayfield:Notify({
            Title   = "Region Changed",
            Content = "Region set to: " .. tostring(Option[1]),
            Type    = "info",
            Duration = 2,
        })
    end,
})

-- Dropdown (multi-select)
local MyMultiDropdown = InputsTab:CreateDropdown({
    Name            = "Select Game Modes",
    Options         = {"PvP", "PvE", "Raid", "Dungeon", "Story", "Free Roam"},
    CurrentOption   = {"PvP"},
    MultipleOptions = true,
    Flag            = "GameModes",
    Callback        = function(Options)
        print("Selected modes:", table.concat(Options, ", "))
    end,
})

InputsTab:CreateSeparator("Text & Keys")

-- Text Input
local MyInput = InputsTab:CreateInput({
    Name                  = "Player Name",
    PlaceholderText       = "Enter player name...",
    CurrentValue          = "",
    Flag                  = "TargetPlayer",
    RemoveTextAfterFocusLost = false,
    Callback              = function(Value)
        print("Input value:", Value)
    end,
})

-- Keybind
local MyKeybind = InputsTab:CreateKeybind({
    Name            = "Activate Script",
    CurrentKeybind  = "F",
    HoldToInteract  = false,
    Flag            = "ActivateKey",
    CallOnChange    = false,
    Callback        = function()
        print("Keybind activated!")
        Rayfield:Notify({
            Title   = "Hotkey Triggered",
            Content = "Your keybind was pressed.",
            Type    = "info",
            Duration = 2,
        })
    end,
})

InputsTab:CreateSection("Color")

-- Color Picker
local MyColorPicker = InputsTab:CreateColorPicker({
    Name     = "Player ESP Color",
    Color    = Color3.fromRGB(255, 100, 100),
    Flag     = "ESPColor",
    Callback = function(Value)
        print(string.format("Color changed: R=%.0f G=%.0f B=%.0f", Value.R*255, Value.G*255, Value.B*255))
    end,
})

-- ═══════════════════════════════════════════════════════════════════
--  TAB 3: DISPLAY TAB
-- ═══════════════════════════════════════════════════════════════════

local DisplayTab = Window:CreateTab("Display", "eye")

DisplayTab:CreateSection("Text Elements")

-- Label (plain)
DisplayTab:CreateLabel("This is a plain label — use for status text")

-- Label with icon and custom color
DisplayTab:CreateLabel("⚡ VIP Rank", "zap", Color3.fromRGB(255, 200, 50), true)

-- Paragraph
DisplayTab:CreateParagraph({
    Title   = "About This Hub",
    Content = "This is a comprehensive example script for the Rayfield Interface Suite. It demonstrates all available UI elements including buttons, toggles, sliders, dropdowns, inputs, keybinds, color pickers, progress bars, info cards, number steppers, and separators.",
})

DisplayTab:CreateSeparator("Separators with Labels")

DisplayTab:CreateSeparator("Section A")

DisplayTab:CreateLabel("Content in section A")

DisplayTab:CreateSeparator("Section B")

DisplayTab:CreateLabel("Content in section B")

-- Divider (original element)
DisplayTab:CreateSection("Original Divider")
DisplayTab:CreateDivider()

-- ═══════════════════════════════════════════════════════════════════
--  TAB 4: THEMES TAB
-- ═══════════════════════════════════════════════════════════════════

local ThemesTab = Window:CreateTab("Themes", "palette")

ThemesTab:CreateSection("Choose Theme")

local themes = {
    "Default", "Ocean", "AmberGlow", "Light", "Amethyst",
    "Green", "Bloom", "DarkBlue", "Serenity",
    "Midnight", "Sunset", "Nord", "Dracula", "Cyberpunk", "Monochrome",
}

ThemesTab:CreateDropdown({
    Name          = "Interface Theme",
    Options       = themes,
    CurrentOption = "Midnight",
    Callback      = function(Option)
        Window.ModifyTheme(Option[1])
    end,
})

ThemesTab:CreateSection("Custom Theme")

ThemesTab:CreateButton({
    Name        = "Apply Cyberpunk Theme",
    Description = "Switch to the neon Cyberpunk theme",
    Callback    = function()
        Window.ModifyTheme("Cyberpunk")
    end,
})

ThemesTab:CreateButton({
    Name        = "Apply Nord Theme",
    Description = "Switch to the clean Nord theme",
    Callback    = function()
        Window.ModifyTheme("Nord")
    end,
})

ThemesTab:CreateButton({
    Name        = "Apply Custom Theme",
    Description = "Apply a fully custom color table",
    Callback    = function()
        Window.ModifyTheme({
            TextColor                     = Color3.fromRGB(240, 240, 240),
            Background                    = Color3.fromRGB(15, 15, 20),
            Topbar                        = Color3.fromRGB(20, 20, 30),
            Shadow                        = Color3.fromRGB(10, 10, 15),
            NotificationBackground        = Color3.fromRGB(18, 18, 25),
            NotificationActionsBackground = Color3.fromRGB(35, 35, 50),
            TabBackground                 = Color3.fromRGB(30, 30, 45),
            TabStroke                     = Color3.fromRGB(45, 45, 65),
            TabBackgroundSelected         = Color3.fromRGB(120, 80, 200),
            TabTextColor                  = Color3.fromRGB(200, 200, 220),
            SelectedTabTextColor          = Color3.fromRGB(255, 255, 255),
            ElementBackground             = Color3.fromRGB(22, 22, 35),
            ElementBackgroundHover        = Color3.fromRGB(30, 30, 48),
            SecondaryElementBackground    = Color3.fromRGB(18, 18, 28),
            ElementStroke                 = Color3.fromRGB(50, 50, 75),
            SecondaryElementStroke        = Color3.fromRGB(40, 40, 60),
            SliderBackground              = Color3.fromRGB(120, 80, 200),
            SliderProgress                = Color3.fromRGB(150, 100, 240),
            SliderStroke                  = Color3.fromRGB(160, 120, 255),
            ToggleBackground              = Color3.fromRGB(22, 22, 35),
            ToggleEnabled                 = Color3.fromRGB(120, 80, 200),
            ToggleDisabled                = Color3.fromRGB(60, 60, 80),
            ToggleEnabledStroke           = Color3.fromRGB(150, 100, 240),
            ToggleDisabledStroke          = Color3.fromRGB(80, 80, 100),
            ToggleEnabledOuterStroke      = Color3.fromRGB(100, 70, 170),
            ToggleDisabledOuterStroke     = Color3.fromRGB(50, 50, 70),
            DropdownSelected              = Color3.fromRGB(60, 40, 100),
            DropdownUnselected            = Color3.fromRGB(22, 22, 35),
            InputBackground               = Color3.fromRGB(22, 22, 35),
            InputStroke                   = Color3.fromRGB(55, 55, 80),
            PlaceholderColor              = Color3.fromRGB(120, 100, 160),
        })
    end,
})

-- ═══════════════════════════════════════════════════════════════════
--  TAB 5: PROFILES TAB
-- ═══════════════════════════════════════════════════════════════════

local ProfilesTab = Window:CreateTab("Profiles", "save")

ProfilesTab:CreateSection("Profile Management")

local profileInput = ProfilesTab:CreateInput({
    Name            = "Profile Name",
    PlaceholderText = "Enter profile name...",
    CurrentValue    = "",
    RemoveTextAfterFocusLost = false,
    Callback        = function() end,
})

ProfilesTab:CreateButton({
    Name        = "Save Profile",
    Description = "Save current settings to a named profile",
    Callback    = function()
        local name = profileInput.CurrentValue
        if name and #name > 0 then
            Rayfield:SaveProfile(name)
            profileInput:Set("")
        else
            Rayfield:Notify({Title = "Error", Content = "Please enter a profile name first.", Type = "error"})
        end
    end,
})

ProfilesTab:CreateButton({
    Name        = "Load Profile",
    Description = "Load settings from a named profile",
    Callback    = function()
        local name = profileInput.CurrentValue
        if name and #name > 0 then
            Rayfield:LoadProfile(name)
            profileInput:Set("")
        else
            Rayfield:Notify({Title = "Error", Content = "Please enter a profile name first.", Type = "error"})
        end
    end,
})

ProfilesTab:CreateButton({
    Name        = "List Profiles",
    Description = "Print all saved profiles to console",
    Callback    = function()
        local profiles = Rayfield:GetProfiles()
        if #profiles == 0 then
            Rayfield:Notify({Title = "Profiles", Content = "No profiles saved yet.", Type = "info"})
        else
            Rayfield:Notify({
                Title   = "Saved Profiles",
                Content = table.concat(profiles, ", "),
                Type    = "info",
                Duration = 5,
            })
        end
    end,
})

-- ═══════════════════════════════════════════════════════════════════
--  NOTIFICATIONS SHOWCASE
-- ═══════════════════════════════════════════════════════════════════

task.wait(3) -- Wait for window to fully load

-- Show off notification types
task.spawn(function()
    task.wait(1)
    Rayfield:Notify({
        Title   = "Welcome!",
        Content = "Rayfield v2.0 loaded successfully. Enjoy the new themes and elements!",
        Type    = "success",
        Duration = 5,
        Image   = "check-circle",
    })
    task.wait(2)
    Rayfield:Notify({
        Title   = "Tip",
        Content = "Press RightControl to toggle the interface. Use the Themes tab to change your color scheme.",
        Type    = "info",
        Duration = 5,
    })
end)

-- ═══════════════════════════════════════════════════════════════════
--  LOAD SAVED CONFIGURATION
-- ═══════════════════════════════════════════════════════════════════

Rayfield:LoadConfiguration()
