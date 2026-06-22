--[[

	Rayfield Interface Suite
	by Sirius

	shlex  | Designing + Programming
	iRay   | Programming
	Max    | Programming
	Damian | Programming

	Enhanced Edition — v2.0
	- Constants & cached TweenInfo objects
	- Helper functions (tween, fadeElement, safeCallback, etc.)
	- 6 new themes (Midnight, Sunset, Nord, Dracula, Cyberpunk, Monochrome)
	- New elements: ProgressBar, Separator, InfoCard, NumberStepper
	- Enhanced elements: Description, Disabled, Visible, Validation
	- Improved notifications with Types (success/warning/error/info)
	- Profile system for multiple config saves
	- Performance optimizations (centralized theme listener, connection cleanup)
	- Bug fixes from code analysis
	- Removed dead code

]]

if debugX then
	warn('Initialising Rayfield')
end

-- ═══════════════════════════════════════════════════════════════════════════
--  SERVICES
-- ═══════════════════════════════════════════════════════════════════════════

local function getService(name)
	local service = game:GetService(name)
	return if cloneref then cloneref(service) else service
end

local UserInputService = getService("UserInputService")
local TweenService     = getService("TweenService")
local Players          = getService("Players")
local CoreGui          = getService("CoreGui")
local HttpService      = getService("HttpService")
local RunService       = getService("RunService")

-- ═══════════════════════════════════════════════════════════════════════════
--  CONSTANTS
-- ═══════════════════════════════════════════════════════════════════════════

-- Animation durations (seconds)
local ANIM_INSTANT  = 0.15
local ANIM_FAST     = 0.3
local ANIM_NORMAL   = 0.5
local ANIM_SLOW     = 0.7
local ANIM_SLOWER   = 1.0

-- Window dimensions
local WINDOW_WIDTH          = 500
local WINDOW_HEIGHT         = 475
local WINDOW_HEIGHT_MOBILE  = 275
local TOPBAR_HEIGHT         = 45
local ELEMENT_HEIGHT        = 45
local DROPDOWN_HEIGHT       = 180
local MINIMIZED_WIDTH       = 495

-- Transparency presets
local TRANS_TOPBAR_IDLE     = 0.8
local TRANS_TAB_UNSELECTED  = 0.7
local TRANS_TAB_TEXT        = 0.2
local TRANS_TAB_STROKE      = 0.5
local TRANS_SHADOW          = 0.6
local TRANS_INDICATOR       = 0.9

-- Colors
local COLOR_ERROR   = Color3.fromRGB(85, 0, 0)
local COLOR_SUCCESS = Color3.fromRGB(0, 100, 60)
local COLOR_WARNING = Color3.fromRGB(120, 80, 0)

-- Slider precision
local SLIDER_DRAG_FACTOR = 0.025
local SLIDER_PRECISION   = 10000000

-- ═══════════════════════════════════════════════════════════════════════════
--  CACHED TWEENINFO OBJECTS  (avoids allocating a new object per tween)
-- ═══════════════════════════════════════════════════════════════════════════

local TI_INSTANT  = TweenInfo.new(ANIM_INSTANT, Enum.EasingStyle.Exponential)
local TI_FAST     = TweenInfo.new(ANIM_FAST,    Enum.EasingStyle.Exponential)
local TI_NORMAL   = TweenInfo.new(ANIM_NORMAL,  Enum.EasingStyle.Exponential)
local TI_SLOW     = TweenInfo.new(ANIM_SLOW,    Enum.EasingStyle.Exponential)
local TI_SLOWER   = TweenInfo.new(ANIM_SLOWER,  Enum.EasingStyle.Exponential)
local TI_QUART_F  = TweenInfo.new(0.45, Enum.EasingStyle.Quart, Enum.EasingDirection.Out)
local TI_QUART_N  = TweenInfo.new(0.55, Enum.EasingStyle.Exponential, Enum.EasingDirection.Out)
local TI_BACK     = TweenInfo.new(0.25, Enum.EasingStyle.Back, Enum.EasingDirection.Out)
local TI_BACK_M   = TweenInfo.new(0.35, Enum.EasingStyle.Back, Enum.EasingDirection.Out)
local TI_ELASTIC  = TweenInfo.new(0.4,  Enum.EasingStyle.Elastic)

-- ═══════════════════════════════════════════════════════════════════════════
--  ENVIRONMENT FLAGS
-- ═══════════════════════════════════════════════════════════════════════════

local requestsDisabled = false
local customAssetId    = nil
local secureMode       = false

if getgenv then
	local ok1, r1 = pcall(function() return getgenv().DISABLE_RAYFIELD_REQUESTS end)
	if ok1 and r1 then requestsDisabled = true end
	local ok2, r2 = pcall(function() return getgenv().RAYFIELD_ASSET_ID end)
	if ok2 and type(r2) == "number" then customAssetId = r2 end
	local ok3, r3 = pcall(function() return getgenv().RAYFIELD_SECURE end)
	if ok3 and r3 then secureMode = true end
end

if secureMode then
	local _error  = error
	local _assert = assert
	warn   = function(...) end
	print  = function(...) end
	error  = function(_, level) _error("", level) end
	assert = function(v, ...) return _assert(v) end
end

-- ═══════════════════════════════════════════════════════════════════════════
--  CORE UTILITY FUNCTIONS
-- ═══════════════════════════════════════════════════════════════════════════

--- Loads and executes a function hosted on a remote URL with a timeout.
local function loadWithTimeout(url: string, timeout: number?): ...any
	assert(type(url) == "string", "Expected string, got " .. type(url))
	timeout = timeout or 5
	local requestCompleted = false
	local success, result  = false, nil

	local requestThread = task.spawn(function()
		local fetchSuccess, fetchResult = pcall(game.HttpGet, game, url)
		if not fetchSuccess or #fetchResult == 0 then
			if #fetchResult == 0 then fetchResult = "Empty response" end
			success, result = false, fetchResult
			requestCompleted = true
			return
		end
		local execSuccess, execResult = pcall(function()
			return loadstring(fetchResult)()
		end)
		success, result = execSuccess, execResult
		requestCompleted = true
	end)

	local timeoutThread = task.delay(timeout, function()
		if not requestCompleted then
			warn("Request for " .. url .. " timed out after " .. tostring(timeout) .. " seconds")
			task.cancel(requestThread)
			result = "Request timed out"
			requestCompleted = true
		end
	end)

	while not requestCompleted do task.wait() end
	if coroutine.status(timeoutThread) ~= "dead" then task.cancel(timeoutThread) end
	if not success then
		warn("Failed to process " .. tostring(url) .. ": " .. tostring(result))
	end
	return if success then result else nil
end

--- Calls func safely and logs errors to output.
local function callSafely(func, ...)
	if func then
		local success, result = pcall(func, ...)
		if not success then
			warn("Rayfield | Function failed: ", result)
			return false
		else
			return result
		end
	end
end

--- Ensures a folder exists by creating it if needed.
local function ensureFolder(folderPath)
	if isfolder and not callSafely(isfolder, folderPath) then
		callSafely(makefolder, folderPath)
	end
end

-- ═══════════════════════════════════════════════════════════════════════════
--  SETTINGS
-- ═══════════════════════════════════════════════════════════════════════════

local secureWarnings = {}
local customAssets   = {}

local function secureNotify(wType, title, content)
	if secureWarnings[wType] then return end
	secureWarnings[wType] = true
	task.spawn(function()
		while not RayfieldLibrary or not RayfieldLibrary.Notify do task.wait(0.5) end
		RayfieldLibrary:Notify({ Title = title, Content = content, Duration = 8 })
	end)
end

local InterfaceBuild       = 'UU2NX'
local Release              = "Build 2.0"
local RayfieldFolder       = "Rayfield"
local ConfigurationFolder  = RayfieldFolder .. "/Configurations"
local ProfilesFolder       = RayfieldFolder .. "/Profiles"
local ConfigurationExtension = ".rfld"

local settingsTable = {
	General = {
		rayfieldOpen = {Type = 'bind', Value = 'K', Name = 'Rayfield Keybind'},
	},
	System = {
		usageAnalytics = {Type = 'toggle', Value = true, Name = 'Anonymised Analytics'},
	}
}

local overriddenSettings: { [string]: any } = {}
local function overrideSetting(category: string, name: string, value: any)
	overriddenSettings[category .. "." .. name] = value
end

local function getSetting(category: string, name: string): any
	if overriddenSettings[category .. "." .. name] ~= nil then
		return overriddenSettings[category .. "." .. name]
	end
	-- Guard: category or name may not exist
	local cat = settingsTable[category]
	if cat and cat[name] ~= nil then
		return cat[name].Value
	end
	return nil
end

if requestsDisabled then
	overrideSetting("System", "usageAnalytics", false)
end

local useStudio = RunService:IsStudio() or false

local settingsCreated     = false
local settingsInitialized = false

local prompt = useStudio
	and require(script.Parent.prompt)
	or  loadWithTimeout('https://raw.githubusercontent.com/SiriusSoftwareLtd/Sirius/refs/heads/request/prompt.lua')

local requestFunc = (syn and syn.request) or (fluxus and fluxus.request) or (http and http.request) or http_request or request

if not prompt and not useStudio then
	warn("Failed to load prompt library, using fallback")
	prompt = { create = function() end }
end

local function loadSettings()
	local file = nil
	local success, result = pcall(function()
		if callSafely(isfolder, RayfieldFolder) then
			if callSafely(isfile, RayfieldFolder .. '/settings' .. ConfigurationExtension) then
				file = callSafely(readfile, RayfieldFolder .. '/settings' .. ConfigurationExtension)
			end
		end
		if useStudio then
			file = [[{"General":{"rayfieldOpen":{"Value":"K","Type":"bind","Name":"Rayfield Keybind"}},"System":{"usageAnalytics":{"Value":false,"Type":"toggle","Name":"Anonymised Analytics"}}}]]
		end
		if file then
			local decodeSuccess, decodedFile = pcall(function() return HttpService:JSONDecode(file) end)
			file = decodeSuccess and decodedFile or {}
		else
			file = {}
		end
		if not settingsCreated then return end
		if next(file) ~= nil then
			for categoryName, categoryTable in file do
				for settingName, setting in categoryTable do
					local default = settingsTable[categoryName] and settingsTable[categoryName][settingName]
					if not default then continue end
					if typeof(default.Value) ~= typeof(setting.Value) then
						warn("Rayfield | Error parsing settings: '" .. settingName .. "' must be a " .. typeof(default.Value))
						continue
					end
					default.Value = setting.Value
				end
			end
		end
		for categoryName, categoryTable in settingsTable do
			for settingName, setting in categoryTable do
				if setting.Element then
					setting.Element:Set(getSetting(categoryName, settingName))
				end
			end
		end
		settingsInitialized = true
	end)
	if not success then
		if writefile then warn('Rayfield had an issue accessing configuration saving.') end
	end
end

if debugX then warn('Now Loading Settings Configuration') end
loadSettings()
if debugX then warn('Settings Loaded') end

-- ═══════════════════════════════════════════════════════════════════════════
--  ANALYTICS
-- ═══════════════════════════════════════════════════════════════════════════

local ANALYTICS_TOKEN = "05de7f9fd320d3b8428cd1c77014a337b85b6c8efee2c5914f5ab5700c354b9a"
local reporter = nil
if not requestsDisabled and not useStudio then
	local fetchSuccess, fetchResult = pcall((game :: any).HttpGet, game, "https://raw.githubusercontent.com/SiriusSoftwareLtd/Rayfield/refs/heads/main/reporter.lua")
	if fetchSuccess and #fetchResult > 0 then
		local execSuccess, Analytics = pcall(function() return (loadstring(fetchResult) :: any)() end)
		if execSuccess and Analytics then
			pcall(function()
				reporter = Analytics.new({
					url          = "https://rayfield-collect.sirius-software-ltd.workers.dev",
					token        = ANALYTICS_TOKEN,
					product_name = "Rayfield",
					category     = "UILibrary",
				})
			end)
		end
	end
end

if not useStudio and math.random(10) == 1 then
	task.spawn(function()
		pcall((game :: any).HttpGet, game, "https://www.sentivel.com/api/heartbeat/81074364b461f8da81bad6fdc363c3b927f884d6fc28d806a15ee50ca1e68c78")
	end)
end

-- ═══════════════════════════════════════════════════════════════════════════
--  THEME DEFINITIONS
-- ═══════════════════════════════════════════════════════════════════════════

local RayfieldLibrary = {
	Flags = {},
	Theme = {
		Default = {
			TextColor = Color3.fromRGB(240, 240, 240),
			Background = Color3.fromRGB(25, 25, 25),
			Topbar = Color3.fromRGB(34, 34, 34),
			Shadow = Color3.fromRGB(20, 20, 20),
			NotificationBackground = Color3.fromRGB(20, 20, 20),
			NotificationActionsBackground = Color3.fromRGB(230, 230, 230),
			TabBackground = Color3.fromRGB(80, 80, 80),
			TabStroke = Color3.fromRGB(85, 85, 85),
			TabBackgroundSelected = Color3.fromRGB(210, 210, 210),
			TabTextColor = Color3.fromRGB(240, 240, 240),
			SelectedTabTextColor = Color3.fromRGB(50, 50, 50),
			ElementBackground = Color3.fromRGB(35, 35, 35),
			ElementBackgroundHover = Color3.fromRGB(40, 40, 40),
			SecondaryElementBackground = Color3.fromRGB(25, 25, 25),
			ElementStroke = Color3.fromRGB(50, 50, 50),
			SecondaryElementStroke = Color3.fromRGB(40, 40, 40),
			SliderBackground = Color3.fromRGB(50, 138, 220),
			SliderProgress = Color3.fromRGB(50, 138, 220),
			SliderStroke = Color3.fromRGB(58, 163, 255),
			ToggleBackground = Color3.fromRGB(30, 30, 30),
			ToggleEnabled = Color3.fromRGB(0, 146, 214),
			ToggleDisabled = Color3.fromRGB(100, 100, 100),
			ToggleEnabledStroke = Color3.fromRGB(0, 170, 255),
			ToggleDisabledStroke = Color3.fromRGB(125, 125, 125),
			ToggleEnabledOuterStroke = Color3.fromRGB(100, 100, 100),
			ToggleDisabledOuterStroke = Color3.fromRGB(65, 65, 65),
			DropdownSelected = Color3.fromRGB(40, 40, 40),
			DropdownUnselected = Color3.fromRGB(30, 30, 30),
			InputBackground = Color3.fromRGB(30, 30, 30),
			InputStroke = Color3.fromRGB(65, 65, 65),
			PlaceholderColor = Color3.fromRGB(178, 178, 178),
		},
		Ocean = {
			TextColor = Color3.fromRGB(230, 240, 240),
			Background = Color3.fromRGB(20, 30, 30),
			Topbar = Color3.fromRGB(25, 40, 40),
			Shadow = Color3.fromRGB(15, 20, 20),
			NotificationBackground = Color3.fromRGB(25, 35, 35),
			NotificationActionsBackground = Color3.fromRGB(230, 240, 240),
			TabBackground = Color3.fromRGB(40, 60, 60),
			TabStroke = Color3.fromRGB(50, 70, 70),
			TabBackgroundSelected = Color3.fromRGB(100, 180, 180),
			TabTextColor = Color3.fromRGB(210, 230, 230),
			SelectedTabTextColor = Color3.fromRGB(20, 50, 50),
			ElementBackground = Color3.fromRGB(30, 50, 50),
			ElementBackgroundHover = Color3.fromRGB(40, 60, 60),
			SecondaryElementBackground = Color3.fromRGB(30, 45, 45),
			ElementStroke = Color3.fromRGB(45, 70, 70),
			SecondaryElementStroke = Color3.fromRGB(40, 65, 65),
			SliderBackground = Color3.fromRGB(0, 110, 110),
			SliderProgress = Color3.fromRGB(0, 140, 140),
			SliderStroke = Color3.fromRGB(0, 160, 160),
			ToggleBackground = Color3.fromRGB(30, 50, 50),
			ToggleEnabled = Color3.fromRGB(0, 130, 130),
			ToggleDisabled = Color3.fromRGB(70, 90, 90),
			ToggleEnabledStroke = Color3.fromRGB(0, 160, 160),
			ToggleDisabledStroke = Color3.fromRGB(85, 105, 105),
			ToggleEnabledOuterStroke = Color3.fromRGB(50, 100, 100),
			ToggleDisabledOuterStroke = Color3.fromRGB(45, 65, 65),
			DropdownSelected = Color3.fromRGB(30, 60, 60),
			DropdownUnselected = Color3.fromRGB(25, 40, 40),
			InputBackground = Color3.fromRGB(30, 50, 50),
			InputStroke = Color3.fromRGB(50, 70, 70),
			PlaceholderColor = Color3.fromRGB(140, 160, 160),
		},
		AmberGlow = {
			TextColor = Color3.fromRGB(255, 245, 230),
			Background = Color3.fromRGB(45, 30, 20),
			Topbar = Color3.fromRGB(55, 40, 25),
			Shadow = Color3.fromRGB(35, 25, 15),
			NotificationBackground = Color3.fromRGB(50, 35, 25),
			NotificationActionsBackground = Color3.fromRGB(245, 230, 215),
			TabBackground = Color3.fromRGB(75, 50, 35),
			TabStroke = Color3.fromRGB(90, 60, 45),
			TabBackgroundSelected = Color3.fromRGB(230, 180, 100),
			TabTextColor = Color3.fromRGB(250, 220, 200),
			SelectedTabTextColor = Color3.fromRGB(50, 30, 10),
			ElementBackground = Color3.fromRGB(60, 45, 35),
			ElementBackgroundHover = Color3.fromRGB(70, 50, 40),
			SecondaryElementBackground = Color3.fromRGB(55, 40, 30),
			ElementStroke = Color3.fromRGB(85, 60, 45),
			SecondaryElementStroke = Color3.fromRGB(75, 50, 35),
			SliderBackground = Color3.fromRGB(220, 130, 60),
			SliderProgress = Color3.fromRGB(250, 150, 75),
			SliderStroke = Color3.fromRGB(255, 170, 85),
			ToggleBackground = Color3.fromRGB(55, 40, 30),
			ToggleEnabled = Color3.fromRGB(240, 130, 30),
			ToggleDisabled = Color3.fromRGB(90, 70, 60),
			ToggleEnabledStroke = Color3.fromRGB(255, 160, 50),
			ToggleDisabledStroke = Color3.fromRGB(110, 85, 75),
			ToggleEnabledOuterStroke = Color3.fromRGB(200, 100, 50),
			ToggleDisabledOuterStroke = Color3.fromRGB(75, 60, 55),
			DropdownSelected = Color3.fromRGB(70, 50, 40),
			DropdownUnselected = Color3.fromRGB(55, 40, 30),
			InputBackground = Color3.fromRGB(60, 45, 35),
			InputStroke = Color3.fromRGB(90, 65, 50),
			PlaceholderColor = Color3.fromRGB(190, 150, 130),
		},
		Light = {
			TextColor = Color3.fromRGB(40, 40, 40),
			Background = Color3.fromRGB(245, 245, 245),
			Topbar = Color3.fromRGB(230, 230, 230),
			Shadow = Color3.fromRGB(200, 200, 200),
			NotificationBackground = Color3.fromRGB(250, 250, 250),
			NotificationActionsBackground = Color3.fromRGB(240, 240, 240),
			TabBackground = Color3.fromRGB(235, 235, 235),
			TabStroke = Color3.fromRGB(215, 215, 215),
			TabBackgroundSelected = Color3.fromRGB(255, 255, 255),
			TabTextColor = Color3.fromRGB(80, 80, 80),
			SelectedTabTextColor = Color3.fromRGB(0, 0, 0),
			ElementBackground = Color3.fromRGB(240, 240, 240),
			ElementBackgroundHover = Color3.fromRGB(225, 225, 225),
			SecondaryElementBackground = Color3.fromRGB(235, 235, 235),
			ElementStroke = Color3.fromRGB(210, 210, 210),
			SecondaryElementStroke = Color3.fromRGB(210, 210, 210),
			SliderBackground = Color3.fromRGB(150, 180, 220),
			SliderProgress = Color3.fromRGB(100, 150, 200),
			SliderStroke = Color3.fromRGB(120, 170, 220),
			ToggleBackground = Color3.fromRGB(220, 220, 220),
			ToggleEnabled = Color3.fromRGB(0, 146, 214),
			ToggleDisabled = Color3.fromRGB(150, 150, 150),
			ToggleEnabledStroke = Color3.fromRGB(0, 170, 255),
			ToggleDisabledStroke = Color3.fromRGB(170, 170, 170),
			ToggleEnabledOuterStroke = Color3.fromRGB(100, 100, 100),
			ToggleDisabledOuterStroke = Color3.fromRGB(180, 180, 180),
			DropdownSelected = Color3.fromRGB(230, 230, 230),
			DropdownUnselected = Color3.fromRGB(220, 220, 220),
			InputBackground = Color3.fromRGB(240, 240, 240),
			InputStroke = Color3.fromRGB(180, 180, 180),
			PlaceholderColor = Color3.fromRGB(140, 140, 140),
		},
		Amethyst = {
			TextColor = Color3.fromRGB(240, 240, 240),
			Background = Color3.fromRGB(30, 20, 40),
			Topbar = Color3.fromRGB(40, 25, 50),
			Shadow = Color3.fromRGB(20, 15, 30),
			NotificationBackground = Color3.fromRGB(35, 20, 40),
			NotificationActionsBackground = Color3.fromRGB(240, 240, 250),
			TabBackground = Color3.fromRGB(60, 40, 80),
			TabStroke = Color3.fromRGB(70, 45, 90),
			TabBackgroundSelected = Color3.fromRGB(180, 140, 200),
			TabTextColor = Color3.fromRGB(230, 230, 240),
			SelectedTabTextColor = Color3.fromRGB(50, 20, 50),
			ElementBackground = Color3.fromRGB(45, 30, 60),
			ElementBackgroundHover = Color3.fromRGB(50, 35, 70),
			SecondaryElementBackground = Color3.fromRGB(40, 30, 55),
			ElementStroke = Color3.fromRGB(70, 50, 85),
			SecondaryElementStroke = Color3.fromRGB(65, 45, 80),
			SliderBackground = Color3.fromRGB(100, 60, 150),
			SliderProgress = Color3.fromRGB(130, 80, 180),
			SliderStroke = Color3.fromRGB(150, 100, 200),
			ToggleBackground = Color3.fromRGB(45, 30, 55),
			ToggleEnabled = Color3.fromRGB(120, 60, 150),
			ToggleDisabled = Color3.fromRGB(94, 47, 117),
			ToggleEnabledStroke = Color3.fromRGB(140, 80, 170),
			ToggleDisabledStroke = Color3.fromRGB(124, 71, 150),
			ToggleEnabledOuterStroke = Color3.fromRGB(90, 40, 120),
			ToggleDisabledOuterStroke = Color3.fromRGB(80, 50, 110),
			DropdownSelected = Color3.fromRGB(50, 35, 70),
			DropdownUnselected = Color3.fromRGB(35, 25, 50),
			InputBackground = Color3.fromRGB(45, 30, 60),
			InputStroke = Color3.fromRGB(80, 50, 110),
			PlaceholderColor = Color3.fromRGB(178, 150, 200),
		},
		Green = {
			TextColor = Color3.fromRGB(30, 60, 30),
			Background = Color3.fromRGB(235, 245, 235),
			Topbar = Color3.fromRGB(210, 230, 210),
			Shadow = Color3.fromRGB(200, 220, 200),
			NotificationBackground = Color3.fromRGB(240, 250, 240),
			NotificationActionsBackground = Color3.fromRGB(220, 235, 220),
			TabBackground = Color3.fromRGB(215, 235, 215),
			TabStroke = Color3.fromRGB(190, 210, 190),
			TabBackgroundSelected = Color3.fromRGB(245, 255, 245),
			TabTextColor = Color3.fromRGB(50, 80, 50),
			SelectedTabTextColor = Color3.fromRGB(20, 60, 20),
			ElementBackground = Color3.fromRGB(225, 240, 225),
			ElementBackgroundHover = Color3.fromRGB(210, 225, 210),
			SecondaryElementBackground = Color3.fromRGB(235, 245, 235),
			ElementStroke = Color3.fromRGB(180, 200, 180),
			SecondaryElementStroke = Color3.fromRGB(180, 200, 180),
			SliderBackground = Color3.fromRGB(90, 160, 90),
			SliderProgress = Color3.fromRGB(70, 130, 70),
			SliderStroke = Color3.fromRGB(100, 180, 100),
			ToggleBackground = Color3.fromRGB(215, 235, 215),
			ToggleEnabled = Color3.fromRGB(60, 130, 60),
			ToggleDisabled = Color3.fromRGB(150, 175, 150),
			ToggleEnabledStroke = Color3.fromRGB(80, 150, 80),
			ToggleDisabledStroke = Color3.fromRGB(130, 150, 130),
			ToggleEnabledOuterStroke = Color3.fromRGB(100, 160, 100),
			ToggleDisabledOuterStroke = Color3.fromRGB(160, 180, 160),
			DropdownSelected = Color3.fromRGB(225, 240, 225),
			DropdownUnselected = Color3.fromRGB(210, 225, 210),
			InputBackground = Color3.fromRGB(235, 245, 235),
			InputStroke = Color3.fromRGB(180, 200, 180),
			PlaceholderColor = Color3.fromRGB(120, 140, 120),
		},
		Bloom = {
			TextColor = Color3.fromRGB(60, 40, 50),
			Background = Color3.fromRGB(255, 240, 245),
			Topbar = Color3.fromRGB(250, 220, 225),
			Shadow = Color3.fromRGB(230, 190, 195),
			NotificationBackground = Color3.fromRGB(255, 235, 240),
			NotificationActionsBackground = Color3.fromRGB(245, 215, 225),
			TabBackground = Color3.fromRGB(240, 210, 220),
			TabStroke = Color3.fromRGB(230, 200, 210),
			TabBackgroundSelected = Color3.fromRGB(255, 225, 235),
			TabTextColor = Color3.fromRGB(80, 40, 60),
			SelectedTabTextColor = Color3.fromRGB(50, 30, 50),
			ElementBackground = Color3.fromRGB(255, 235, 240),
			ElementBackgroundHover = Color3.fromRGB(245, 220, 230),
			SecondaryElementBackground = Color3.fromRGB(255, 235, 240),
			ElementStroke = Color3.fromRGB(230, 200, 210),
			SecondaryElementStroke = Color3.fromRGB(230, 200, 210),
			SliderBackground = Color3.fromRGB(240, 130, 160),
			SliderProgress = Color3.fromRGB(250, 160, 180),
			SliderStroke = Color3.fromRGB(255, 180, 200),
			ToggleBackground = Color3.fromRGB(240, 210, 220),
			ToggleEnabled = Color3.fromRGB(255, 140, 170),
			ToggleDisabled = Color3.fromRGB(200, 180, 185),
			ToggleEnabledStroke = Color3.fromRGB(250, 160, 190),
			ToggleDisabledStroke = Color3.fromRGB(210, 180, 190),
			ToggleEnabledOuterStroke = Color3.fromRGB(220, 160, 180),
			ToggleDisabledOuterStroke = Color3.fromRGB(190, 170, 180),
			DropdownSelected = Color3.fromRGB(250, 220, 225),
			DropdownUnselected = Color3.fromRGB(240, 210, 220),
			InputBackground = Color3.fromRGB(255, 235, 240),
			InputStroke = Color3.fromRGB(220, 190, 200),
			PlaceholderColor = Color3.fromRGB(170, 130, 140),
		},
		DarkBlue = {
			TextColor = Color3.fromRGB(230, 230, 230),
			Background = Color3.fromRGB(20, 25, 30),
			Topbar = Color3.fromRGB(30, 35, 40),
			Shadow = Color3.fromRGB(15, 20, 25),
			NotificationBackground = Color3.fromRGB(25, 30, 35),
			NotificationActionsBackground = Color3.fromRGB(45, 50, 55),
			TabBackground = Color3.fromRGB(35, 40, 45),
			TabStroke = Color3.fromRGB(45, 50, 60),
			TabBackgroundSelected = Color3.fromRGB(40, 70, 100),
			TabTextColor = Color3.fromRGB(200, 200, 200),
			SelectedTabTextColor = Color3.fromRGB(255, 255, 255),
			ElementBackground = Color3.fromRGB(30, 35, 40),
			ElementBackgroundHover = Color3.fromRGB(40, 45, 50),
			SecondaryElementBackground = Color3.fromRGB(35, 40, 45),
			ElementStroke = Color3.fromRGB(45, 50, 60),
			SecondaryElementStroke = Color3.fromRGB(40, 45, 55),
			SliderBackground = Color3.fromRGB(0, 90, 180),
			SliderProgress = Color3.fromRGB(0, 120, 210),
			SliderStroke = Color3.fromRGB(0, 150, 240),
			ToggleBackground = Color3.fromRGB(35, 40, 45),
			ToggleEnabled = Color3.fromRGB(0, 120, 210),
			ToggleDisabled = Color3.fromRGB(70, 70, 80),
			ToggleEnabledStroke = Color3.fromRGB(0, 150, 240),
			ToggleDisabledStroke = Color3.fromRGB(75, 75, 85),
			ToggleEnabledOuterStroke = Color3.fromRGB(20, 100, 180),
			ToggleDisabledOuterStroke = Color3.fromRGB(55, 55, 65),
			DropdownSelected = Color3.fromRGB(30, 70, 90),
			DropdownUnselected = Color3.fromRGB(25, 30, 35),
			InputBackground = Color3.fromRGB(25, 30, 35),
			InputStroke = Color3.fromRGB(45, 50, 60),
			PlaceholderColor = Color3.fromRGB(150, 150, 160),
		},
		Serenity = {
			TextColor = Color3.fromRGB(50, 55, 60),
			Background = Color3.fromRGB(240, 245, 250),
			Topbar = Color3.fromRGB(215, 225, 235),
			Shadow = Color3.fromRGB(200, 210, 220),
			NotificationBackground = Color3.fromRGB(210, 220, 230),
			NotificationActionsBackground = Color3.fromRGB(225, 230, 240),
			TabBackground = Color3.fromRGB(200, 210, 220),
			TabStroke = Color3.fromRGB(180, 190, 200),
			TabBackgroundSelected = Color3.fromRGB(175, 185, 200),
			TabTextColor = Color3.fromRGB(50, 55, 60),
			SelectedTabTextColor = Color3.fromRGB(30, 35, 40),
			ElementBackground = Color3.fromRGB(210, 220, 230),
			ElementBackgroundHover = Color3.fromRGB(220, 230, 240),
			SecondaryElementBackground = Color3.fromRGB(200, 210, 220),
			ElementStroke = Color3.fromRGB(190, 200, 210),
			SecondaryElementStroke = Color3.fromRGB(180, 190, 200),
			SliderBackground = Color3.fromRGB(200, 220, 235),
			SliderProgress = Color3.fromRGB(70, 130, 180),
			SliderStroke = Color3.fromRGB(150, 180, 220),
			ToggleBackground = Color3.fromRGB(210, 220, 230),
			ToggleEnabled = Color3.fromRGB(70, 160, 210),
			ToggleDisabled = Color3.fromRGB(180, 180, 180),
			ToggleEnabledStroke = Color3.fromRGB(60, 150, 200),
			ToggleDisabledStroke = Color3.fromRGB(140, 140, 140),
			ToggleEnabledOuterStroke = Color3.fromRGB(100, 120, 140),
			ToggleDisabledOuterStroke = Color3.fromRGB(120, 120, 130),
			DropdownSelected = Color3.fromRGB(220, 230, 240),
			DropdownUnselected = Color3.fromRGB(200, 210, 220),
			InputBackground = Color3.fromRGB(220, 230, 240),
			InputStroke = Color3.fromRGB(180, 190, 200),
			PlaceholderColor = Color3.fromRGB(150, 150, 150),
		},
		-- ═══ NEW THEMES ═══
		Midnight = {
			TextColor = Color3.fromRGB(220, 230, 255),
			Background = Color3.fromRGB(13, 17, 23),
			Topbar = Color3.fromRGB(22, 27, 34),
			Shadow = Color3.fromRGB(8, 10, 15),
			NotificationBackground = Color3.fromRGB(18, 23, 30),
			NotificationActionsBackground = Color3.fromRGB(33, 40, 50),
			TabBackground = Color3.fromRGB(30, 38, 50),
			TabStroke = Color3.fromRGB(40, 50, 68),
			TabBackgroundSelected = Color3.fromRGB(31, 111, 235),
			TabTextColor = Color3.fromRGB(160, 180, 210),
			SelectedTabTextColor = Color3.fromRGB(255, 255, 255),
			ElementBackground = Color3.fromRGB(22, 28, 36),
			ElementBackgroundHover = Color3.fromRGB(30, 38, 50),
			SecondaryElementBackground = Color3.fromRGB(18, 23, 30),
			ElementStroke = Color3.fromRGB(40, 52, 70),
			SecondaryElementStroke = Color3.fromRGB(33, 43, 58),
			SliderBackground = Color3.fromRGB(31, 111, 235),
			SliderProgress = Color3.fromRGB(88, 166, 255),
			SliderStroke = Color3.fromRGB(58, 135, 255),
			ToggleBackground = Color3.fromRGB(22, 28, 36),
			ToggleEnabled = Color3.fromRGB(31, 111, 235),
			ToggleDisabled = Color3.fromRGB(55, 65, 80),
			ToggleEnabledStroke = Color3.fromRGB(88, 166, 255),
			ToggleDisabledStroke = Color3.fromRGB(70, 80, 100),
			ToggleEnabledOuterStroke = Color3.fromRGB(31, 90, 180),
			ToggleDisabledOuterStroke = Color3.fromRGB(40, 50, 65),
			DropdownSelected = Color3.fromRGB(31, 60, 100),
			DropdownUnselected = Color3.fromRGB(22, 28, 36),
			InputBackground = Color3.fromRGB(22, 28, 36),
			InputStroke = Color3.fromRGB(48, 60, 80),
			PlaceholderColor = Color3.fromRGB(110, 130, 160),
		},
		Sunset = {
			TextColor = Color3.fromRGB(255, 235, 220),
			Background = Color3.fromRGB(26, 20, 35),
			Topbar = Color3.fromRGB(36, 28, 48),
			Shadow = Color3.fromRGB(16, 12, 22),
			NotificationBackground = Color3.fromRGB(30, 24, 40),
			NotificationActionsBackground = Color3.fromRGB(240, 210, 200),
			TabBackground = Color3.fromRGB(55, 38, 65),
			TabStroke = Color3.fromRGB(75, 50, 88),
			TabBackgroundSelected = Color3.fromRGB(255, 107, 107),
			TabTextColor = Color3.fromRGB(220, 190, 210),
			SelectedTabTextColor = Color3.fromRGB(255, 255, 255),
			ElementBackground = Color3.fromRGB(38, 28, 50),
			ElementBackgroundHover = Color3.fromRGB(50, 36, 65),
			SecondaryElementBackground = Color3.fromRGB(30, 22, 42),
			ElementStroke = Color3.fromRGB(70, 48, 88),
			SecondaryElementStroke = Color3.fromRGB(58, 40, 75),
			SliderBackground = Color3.fromRGB(255, 107, 107),
			SliderProgress = Color3.fromRGB(255, 160, 122),
			SliderStroke = Color3.fromRGB(255, 130, 100),
			ToggleBackground = Color3.fromRGB(38, 28, 50),
			ToggleEnabled = Color3.fromRGB(255, 107, 107),
			ToggleDisabled = Color3.fromRGB(90, 65, 100),
			ToggleEnabledStroke = Color3.fromRGB(255, 160, 122),
			ToggleDisabledStroke = Color3.fromRGB(110, 80, 120),
			ToggleEnabledOuterStroke = Color3.fromRGB(200, 80, 90),
			ToggleDisabledOuterStroke = Color3.fromRGB(70, 50, 85),
			DropdownSelected = Color3.fromRGB(70, 45, 88),
			DropdownUnselected = Color3.fromRGB(38, 28, 50),
			InputBackground = Color3.fromRGB(38, 28, 50),
			InputStroke = Color3.fromRGB(80, 55, 100),
			PlaceholderColor = Color3.fromRGB(180, 145, 165),
		},
		Nord = {
			TextColor = Color3.fromRGB(236, 239, 244),
			Background = Color3.fromRGB(46, 52, 64),
			Topbar = Color3.fromRGB(59, 66, 82),
			Shadow = Color3.fromRGB(36, 41, 51),
			NotificationBackground = Color3.fromRGB(52, 58, 72),
			NotificationActionsBackground = Color3.fromRGB(216, 222, 233),
			TabBackground = Color3.fromRGB(67, 76, 94),
			TabStroke = Color3.fromRGB(76, 86, 106),
			TabBackgroundSelected = Color3.fromRGB(136, 192, 208),
			TabTextColor = Color3.fromRGB(216, 222, 233),
			SelectedTabTextColor = Color3.fromRGB(46, 52, 64),
			ElementBackground = Color3.fromRGB(59, 66, 82),
			ElementBackgroundHover = Color3.fromRGB(67, 76, 94),
			SecondaryElementBackground = Color3.fromRGB(52, 58, 72),
			ElementStroke = Color3.fromRGB(76, 86, 106),
			SecondaryElementStroke = Color3.fromRGB(67, 76, 94),
			SliderBackground = Color3.fromRGB(129, 161, 193),
			SliderProgress = Color3.fromRGB(136, 192, 208),
			SliderStroke = Color3.fromRGB(143, 188, 187),
			ToggleBackground = Color3.fromRGB(59, 66, 82),
			ToggleEnabled = Color3.fromRGB(136, 192, 208),
			ToggleDisabled = Color3.fromRGB(76, 86, 106),
			ToggleEnabledStroke = Color3.fromRGB(143, 188, 187),
			ToggleDisabledStroke = Color3.fromRGB(90, 100, 120),
			ToggleEnabledOuterStroke = Color3.fromRGB(100, 145, 165),
			ToggleDisabledOuterStroke = Color3.fromRGB(65, 74, 92),
			DropdownSelected = Color3.fromRGB(67, 100, 130),
			DropdownUnselected = Color3.fromRGB(59, 66, 82),
			InputBackground = Color3.fromRGB(59, 66, 82),
			InputStroke = Color3.fromRGB(76, 86, 106),
			PlaceholderColor = Color3.fromRGB(160, 170, 185),
		},
		Dracula = {
			TextColor = Color3.fromRGB(248, 248, 242),
			Background = Color3.fromRGB(40, 42, 54),
			Topbar = Color3.fromRGB(50, 52, 68),
			Shadow = Color3.fromRGB(28, 30, 40),
			NotificationBackground = Color3.fromRGB(44, 46, 60),
			NotificationActionsBackground = Color3.fromRGB(248, 248, 242),
			TabBackground = Color3.fromRGB(68, 71, 90),
			TabStroke = Color3.fromRGB(80, 83, 104),
			TabBackgroundSelected = Color3.fromRGB(189, 147, 249),
			TabTextColor = Color3.fromRGB(200, 200, 220),
			SelectedTabTextColor = Color3.fromRGB(40, 42, 54),
			ElementBackground = Color3.fromRGB(50, 52, 68),
			ElementBackgroundHover = Color3.fromRGB(60, 62, 80),
			SecondaryElementBackground = Color3.fromRGB(44, 46, 60),
			ElementStroke = Color3.fromRGB(72, 75, 95),
			SecondaryElementStroke = Color3.fromRGB(64, 67, 85),
			SliderBackground = Color3.fromRGB(189, 147, 249),
			SliderProgress = Color3.fromRGB(255, 121, 198),
			SliderStroke = Color3.fromRGB(139, 233, 253),
			ToggleBackground = Color3.fromRGB(50, 52, 68),
			ToggleEnabled = Color3.fromRGB(189, 147, 249),
			ToggleDisabled = Color3.fromRGB(90, 93, 115),
			ToggleEnabledStroke = Color3.fromRGB(255, 121, 198),
			ToggleDisabledStroke = Color3.fromRGB(110, 113, 138),
			ToggleEnabledOuterStroke = Color3.fromRGB(150, 115, 200),
			ToggleDisabledOuterStroke = Color3.fromRGB(72, 75, 95),
			DropdownSelected = Color3.fromRGB(80, 55, 110),
			DropdownUnselected = Color3.fromRGB(50, 52, 68),
			InputBackground = Color3.fromRGB(50, 52, 68),
			InputStroke = Color3.fromRGB(80, 83, 104),
			PlaceholderColor = Color3.fromRGB(170, 165, 195),
		},
		Cyberpunk = {
			TextColor = Color3.fromRGB(0, 255, 245),
			Background = Color3.fromRGB(10, 10, 15),
			Topbar = Color3.fromRGB(15, 15, 25),
			Shadow = Color3.fromRGB(5, 5, 10),
			NotificationBackground = Color3.fromRGB(12, 12, 20),
			NotificationActionsBackground = Color3.fromRGB(0, 200, 195),
			TabBackground = Color3.fromRGB(20, 20, 35),
			TabStroke = Color3.fromRGB(0, 200, 195),
			TabBackgroundSelected = Color3.fromRGB(255, 0, 160),
			TabTextColor = Color3.fromRGB(0, 200, 195),
			SelectedTabTextColor = Color3.fromRGB(255, 255, 255),
			ElementBackground = Color3.fromRGB(15, 15, 25),
			ElementBackgroundHover = Color3.fromRGB(22, 22, 38),
			SecondaryElementBackground = Color3.fromRGB(12, 12, 20),
			ElementStroke = Color3.fromRGB(0, 150, 150),
			SecondaryElementStroke = Color3.fromRGB(0, 120, 120),
			SliderBackground = Color3.fromRGB(255, 0, 160),
			SliderProgress = Color3.fromRGB(0, 255, 245),
			SliderStroke = Color3.fromRGB(255, 0, 220),
			ToggleBackground = Color3.fromRGB(15, 15, 25),
			ToggleEnabled = Color3.fromRGB(0, 255, 245),
			ToggleDisabled = Color3.fromRGB(40, 40, 60),
			ToggleEnabledStroke = Color3.fromRGB(255, 0, 160),
			ToggleDisabledStroke = Color3.fromRGB(60, 60, 90),
			ToggleEnabledOuterStroke = Color3.fromRGB(0, 180, 175),
			ToggleDisabledOuterStroke = Color3.fromRGB(35, 35, 55),
			DropdownSelected = Color3.fromRGB(0, 80, 80),
			DropdownUnselected = Color3.fromRGB(15, 15, 25),
			InputBackground = Color3.fromRGB(15, 15, 25),
			InputStroke = Color3.fromRGB(0, 150, 150),
			PlaceholderColor = Color3.fromRGB(0, 160, 155),
		},
		Monochrome = {
			TextColor = Color3.fromRGB(220, 220, 220),
			Background = Color3.fromRGB(18, 18, 18),
			Topbar = Color3.fromRGB(28, 28, 28),
			Shadow = Color3.fromRGB(10, 10, 10),
			NotificationBackground = Color3.fromRGB(22, 22, 22),
			NotificationActionsBackground = Color3.fromRGB(200, 200, 200),
			TabBackground = Color3.fromRGB(45, 45, 45),
			TabStroke = Color3.fromRGB(60, 60, 60),
			TabBackgroundSelected = Color3.fromRGB(200, 200, 200),
			TabTextColor = Color3.fromRGB(180, 180, 180),
			SelectedTabTextColor = Color3.fromRGB(18, 18, 18),
			ElementBackground = Color3.fromRGB(30, 30, 30),
			ElementBackgroundHover = Color3.fromRGB(40, 40, 40),
			SecondaryElementBackground = Color3.fromRGB(22, 22, 22),
			ElementStroke = Color3.fromRGB(55, 55, 55),
			SecondaryElementStroke = Color3.fromRGB(45, 45, 45),
			SliderBackground = Color3.fromRGB(140, 140, 140),
			SliderProgress = Color3.fromRGB(200, 200, 200),
			SliderStroke = Color3.fromRGB(170, 170, 170),
			ToggleBackground = Color3.fromRGB(30, 30, 30),
			ToggleEnabled = Color3.fromRGB(200, 200, 200),
			ToggleDisabled = Color3.fromRGB(80, 80, 80),
			ToggleEnabledStroke = Color3.fromRGB(230, 230, 230),
			ToggleDisabledStroke = Color3.fromRGB(100, 100, 100),
			ToggleEnabledOuterStroke = Color3.fromRGB(160, 160, 160),
			ToggleDisabledOuterStroke = Color3.fromRGB(60, 60, 60),
			DropdownSelected = Color3.fromRGB(55, 55, 55),
			DropdownUnselected = Color3.fromRGB(30, 30, 30),
			InputBackground = Color3.fromRGB(30, 30, 30),
			InputStroke = Color3.fromRGB(65, 65, 65),
			PlaceholderColor = Color3.fromRGB(120, 120, 120),
		},
	}
}

-- ═══════════════════════════════════════════════════════════════════════════
--  INTERFACE LOADING
-- ═══════════════════════════════════════════════════════════════════════════

local RayfieldAssetId = customAssetId or 10804731440
local Rayfield, buildAttempts, correctBuild, warned, globalLoaded
local rayfieldDestroyed = false

local function loadRayfieldAsset()
	local ok, result = pcall(function()
		return useStudio
			and script.Parent:FindFirstChild('Rayfield')
			or  game:GetObjects("rbxassetid://" .. RayfieldAssetId)[1]
	end)
	return ok and result or nil
end

Rayfield = loadRayfieldAsset()
buildAttempts = 0
correctBuild  = false

repeat
	if Rayfield and Rayfield:FindFirstChild('Build') and Rayfield.Build.Value == InterfaceBuild then
		correctBuild = true
		break
	end
	correctBuild = false
	if not warned then
		warn('Rayfield | Build Mismatch')
		print('Rayfield may encounter issues as you are running an incompatible interface version (' .. ((Rayfield and Rayfield:FindFirstChild('Build') and Rayfield.Build.Value) or 'No Build') .. ').\n\nThis version of Rayfield is intended for interface build ' .. InterfaceBuild .. '.')
		warned = true
	end
	local toDestroy
	toDestroy, Rayfield = Rayfield, loadRayfieldAsset()
	if toDestroy and not useStudio then toDestroy:Destroy() end
	buildAttempts += 1
until buildAttempts >= 2

Rayfield.Enabled = false

-- Safe GUI parenting
local function safeParentGui(gui)
	if gethui then
		gui.Parent = gethui()
	elseif syn and syn.protect_gui then
		syn.protect_gui(gui)
		gui.Parent = CoreGui
	elseif not useStudio and CoreGui:FindFirstChild("RobloxGui") then
		gui.Parent = CoreGui:FindFirstChild("RobloxGui")
	elseif not useStudio then
		gui.Parent = CoreGui
	end
end

local function cleanupOldInstances(gui)
	local parent = gui.Parent
	if parent then
		for _, child in ipairs(parent:GetChildren()) do
			if child.Name == gui.Name and child ~= gui then
				child.Enabled = false
				child.Name = gui.Name .. "-Old"
			end
		end
	end
end

safeParentGui(Rayfield)
cleanupOldInstances(Rayfield)

if secureMode and not customAssetId then
	secureNotify("default_asset", "Secure Mode", "You are using the default Rayfield asset ID. Set RAYFIELD_ASSET_ID to a custom upload to avoid detection.")
end

-- ═══════════════════════════════════════════════════════════════════════════
--  ASSET MANAGEMENT
-- ═══════════════════════════════════════════════════════════════════════════

do
	local AssetPath    = RayfieldFolder .. "/Assets"
	local AssetBaseURL = "https://github.com/SiriusSoftwareLtd/Rayfield/blob/main/assets/"

	local assetFiles = {
		["111263549366178"] = AssetBaseURL .. "111263549366178.png?raw=true",
		["77891951053543"]  = AssetBaseURL .. "77891951053543.png?raw=true",
		["78137979054938"]  = AssetBaseURL .. "78137979054938.png?raw=true",
		["80503127983237"]  = AssetBaseURL .. "80503127983237.png?raw=true",
		["10137832201"]     = AssetBaseURL .. "10137832201.png?raw=true",
		["10137941941"]     = AssetBaseURL .. "10137941941.png?raw=true",
		["11036884234"]     = AssetBaseURL .. "11036884234.png?raw=true",
		["11413591840"]     = AssetBaseURL .. "11413591840.png?raw=true",
		["11745872910"]     = AssetBaseURL .. "11745872910.png?raw=true",
		["12577727209"]     = AssetBaseURL .. "12577727209.png?raw=true",
		["18458939117"]     = AssetBaseURL .. "18458939117.png?raw=true",
		["3259050989"]      = AssetBaseURL .. "3259050989.png?raw=true",
		["3523728077"]      = AssetBaseURL .. "3523728077.png?raw=true",
		["3602733521"]      = AssetBaseURL .. "3602733521.png?raw=true",
		["IconChevronTopMedium"] = AssetBaseURL .. "IconChevronTopMedium.png?raw=true",
		["4483362458"]      = AssetBaseURL .. "4483362458.png?raw=true",
		["5587865193"]      = AssetBaseURL .. "5587865193.png?raw=true",
		["IconMagnifyingGlass2"] = AssetBaseURL .. "IconMagnifyingGlass2.png?raw=true",
	}

	for id, _ in assetFiles do
		customAssets[tostring(id)] = ""
	end

	local hasCustomAsset  = type(getcustomasset) == "function"
	local hasFilesystem   = type(writefile) == "function" and type(makefolder) == "function"
		and type(isfile) == "function" and type(isfolder) == "function"

	if hasCustomAsset and hasFilesystem then
		local ok, err = pcall(function()
			ensureFolder(RayfieldFolder)
			ensureFolder(AssetPath)

			local attempted = {}
			local function nextToFetch()
				for id, _ in assetFiles do
					if not attempted[id] and not isfile(AssetPath .. "/" .. tostring(id) .. ".png") then
						return id
					end
				end
				return nil
			end

			if nextToFetch() then
				task.spawn(function()
					while true do
						local id = nextToFetch()
						if not id then break end
						local ok2, res = pcall(requestFunc, {Url = assetFiles[id], Method = "GET"})
						if ok2 and type(res) == "table" and type(res.Body) == "string" and #res.Body > 0 then
							pcall(writefile, AssetPath .. "/" .. tostring(id) .. ".png", res.Body)
						end
						attempted[id] = true
						task.wait()
					end
				end)
				while nextToFetch() do task.wait(0.1) end
			end

			for id, _ in assetFiles do
				local s, asset = pcall(getcustomasset, AssetPath .. "/" .. tostring(id) .. ".png")
				if s then
					customAssets[tostring(id)] = asset
				else
					warn("Rayfield | Failed to load custom asset: " .. tostring(id))
				end
			end
		end)
		if not ok then
			warn("Rayfield | Failed to load custom assets: " .. tostring(err))
			secureNotify("asset_load_fail", "Rayfield", "Failed to load custom assets.")
		end
	else
		secureNotify("no_getcustomasset", "Rayfield", "Your executor does not support getcustomasset. Some UI images may not render correctly.")
	end

	-- Apply assets to interface
	local Main_ref = Rayfield.Main
	Main_ref.Shadow.Image.Image                                         = customAssets["5587865193"]
	Main_ref.Topbar.Hide.Image                                         = customAssets["10137832201"]
	Main_ref.Topbar.ChangeSize.Image                                   = customAssets["10137941941"]
	Main_ref.Topbar.Settings.Image                                     = customAssets["80503127983237"]
	Main_ref.Topbar.Icon.Image                                         = customAssets["78137979054938"]
	Main_ref.Topbar.Search.Image                                       = customAssets["IconMagnifyingGlass2"]
	Main_ref.Topbar.Search.ImageRectOffset                             = Vector2.new(0, 0)
	Main_ref.Topbar.Search.ImageRectSize                               = Vector2.new(0, 0)
	Main_ref.Elements.Template.Toggle.Switch.Shadow.Image              = customAssets["3602733521"]
	Main_ref.Elements.Template.Slider.Main.Shadow.Image                = customAssets["3602733521"]
	Main_ref.Elements.Template.Dropdown.Toggle.Image                   = customAssets["IconChevronTopMedium"]
	Main_ref.Elements.Template.Dropdown.Toggle.ImageRectOffset         = Vector2.new(0, 0)
	Main_ref.Elements.Template.Dropdown.Toggle.ImageRectSize           = Vector2.new(0, 0)
	Main_ref.Elements.Template.Label.Icon.Image                        = customAssets["11745872910"]
	Main_ref.Elements.Template.ColorPicker.CPBackground.MainCP.Image  = customAssets["11413591840"]
	Main_ref.Elements.Template.ColorPicker.CPBackground.MainCP.MainPoint.Image = customAssets["3259050989"]
	Main_ref.Elements.Template.ColorPicker.ColorSlider.SliderPoint.Image       = customAssets["3259050989"]
	Main_ref.TabList.Template.Image.Image                              = customAssets["4483362458"]
	Main_ref.Search.Search.Image                                       = customAssets["18458939117"]
	Main_ref.Search.Shadow.Image                                       = customAssets["5587865193"]
	Rayfield.Notifications.Template.Icon.Image                        = customAssets["77891951053543"]
	Rayfield.Notifications.Template.Shadow.Image                       = customAssets["3523728077"]
	Rayfield.Loading.Banner.Image                                      = customAssets["111263549366178"]
end

-- ═══════════════════════════════════════════════════════════════════════════
--  MOBILE DETECTION
-- ═══════════════════════════════════════════════════════════════════════════

local minSize        = Vector2.new(1024, 768)
local useMobileSizing = Rayfield.AbsoluteSize.X < minSize.X and Rayfield.AbsoluteSize.Y < minSize.Y
local useMobilePrompt = UserInputService.TouchEnabled

-- ═══════════════════════════════════════════════════════════════════════════
--  OBJECT REFERENCES
-- ═══════════════════════════════════════════════════════════════════════════

local Main          = Rayfield.Main
local MPrompt       = Rayfield:FindFirstChild('Prompt')
local Topbar        = Main.Topbar
local Elements      = Main.Elements
local LoadingFrame  = Main.LoadingFrame
local TabList       = Main.TabList
local dragBar       = Rayfield:FindFirstChild('Drag')
local dragInteract  = dragBar and dragBar.Interact or nil
local dragBarCosmetic = dragBar and dragBar.Drag or nil

local dragOffset       = 255
local dragOffsetMobile = 150

Rayfield.DisplayOrder   = 100
LoadingFrame.Version.Text = Release

-- Icons (Lucide)
local Icons = useStudio
	and require(script.Parent.icons)
	or  loadWithTimeout('https://raw.githubusercontent.com/SiriusSoftwareLtd/Rayfield/refs/heads/main/icons.lua')

-- ═══════════════════════════════════════════════════════════════════════════
--  STATE VARIABLES
-- ═══════════════════════════════════════════════════════════════════════════

local CFileName    = nil
local CEnabled     = false
local Minimised    = false
local Hidden       = false
local Debounce     = false
local searchOpen   = false
local Notifications = Rayfield.Notifications
local keybindConnections = {}

-- Centralized theme change callbacks (replaces dozens of individual GetPropertyChangedSignal connections)
local themeChangeCallbacks = {}
local function onThemeChange(callback)
	table.insert(themeChangeCallbacks, callback)
end

local SelectedTheme = RayfieldLibrary.Theme.Default

-- ═══════════════════════════════════════════════════════════════════════════
--  ANIMATION HELPERS
-- ═══════════════════════════════════════════════════════════════════════════

--- Shorthand for TweenService:Create():Play()
local function tween(object, tweenInfo, properties)
	TweenService:Create(object, tweenInfo, properties):Play()
end

--- Standard fade in/out for 3-part elements (background, stroke, title text)
local function fadeElement(element, show)
	tween(element, TI_SLOW, {BackgroundTransparency = show and 0 or 1})
	if element:FindFirstChild("UIStroke") then
		tween(element.UIStroke, TI_SLOW, {Transparency = show and 0 or 1})
	end
	if element:FindFirstChild("Title") then
		tween(element.Title, TI_SLOW, {TextTransparency = show and 0 or 1})
	end
end

--- Add standard hover highlight to an element
local function addHoverEffect(element, hoverColor, defaultColor)
	element.MouseEnter:Connect(function()
		tween(element, TI_NORMAL, {BackgroundColor3 = hoverColor or SelectedTheme.ElementBackgroundHover})
	end)
	element.MouseLeave:Connect(function()
		tween(element, TI_NORMAL, {BackgroundColor3 = defaultColor or SelectedTheme.ElementBackground})
	end)
end

--- Flash an element red (callback error), then restore
local function handleCallbackError(element, elementName, response)
	tween(element, TI_NORMAL, {BackgroundColor3 = COLOR_ERROR})
	if element:FindFirstChild("UIStroke") then
		tween(element.UIStroke, TI_NORMAL, {Transparency = 1})
	end
	if element:FindFirstChild("ElementIndicator") then
		tween(element.ElementIndicator, TI_NORMAL, {TextTransparency = 1})
	end
	element.Title.Text = "Callback Error"
	warn("Rayfield | " .. elementName .. " Callback Error: " .. tostring(response))
	task.wait(0.5)
	element.Title.Text = elementName
	tween(element, TI_NORMAL, {BackgroundColor3 = SelectedTheme.ElementBackground})
	if element:FindFirstChild("UIStroke") then
		tween(element.UIStroke, TI_NORMAL, {Transparency = 0})
	end
	if element:FindFirstChild("ElementIndicator") then
		tween(element.ElementIndicator, TI_NORMAL, {TextTransparency = TRANS_INDICATOR})
	end
end

--- Safe callback wrapper — handles errors and shows visual feedback
local function safeCallback(fn, element, elementName, ...)
	local success, response = pcall(fn, ...)
	if not success and element then
		task.spawn(handleCallbackError, element, elementName, response)
	end
	return success, response
end

--- Register an element's flag for configuration saving
local function registerFlag(windowSettings, elementSettings)
	if windowSettings and windowSettings.ConfigurationSaving
		and windowSettings.ConfigurationSaving.Enabled
		and elementSettings.Flag
	then
		RayfieldLibrary.Flags[elementSettings.Flag] = elementSettings
	end
end

-- ═══════════════════════════════════════════════════════════════════════════
--  ICON UTILITIES
-- ═══════════════════════════════════════════════════════════════════════════

local function getIcon(name: string)
	if not Icons then warn("Lucide Icons: Cannot use icons as icons library is not loaded") return end
	name = string.match(string.lower(name), "^%s*(.*)%s*$") :: string
	local sizedicons = Icons['48px']
	local r = sizedicons[name]
	if not r then error('Lucide Icons: Failed to find icon "' .. name .. '"', 2) end
	return {
		id = r[1],
		imageRectSize = Vector2.new(r[2][1], r[2][2]),
		imageRectOffset = Vector2.new(r[3][1], r[3][2]),
	}
end

local function getAssetUri(id: any): string
	if type(id) == "number" then
		return "rbxassetid://" .. id
	elseif type(id) == "string" and not Icons then
		warn("Rayfield | Cannot use Lucide icons: icons library not loaded")
	else
		warn("Rayfield | Icon argument must be a number (asset ID) or string (Lucide icon name)")
	end
	return ""
end

local function isCustomAsset(value)
	return type(value) == "string"
		and (string.find(value, "rbxasset://") == 1 or string.find(value, "rbxthumb://") == 1)
end

local function resolveIcon(icon)
	if not icon or icon == 0 then return "", nil, nil end
	if isCustomAsset(icon) then return icon, nil, nil end
	if secureMode then
		secureNotify("icon_blocked", "Secure Mode", "Element icons are blocked in Secure Mode. Use getcustomasset() instead.")
		return "", nil, nil
	end
	if typeof(icon) == "string" and Icons then
		local asset = getIcon(icon)
		if not asset then return "", nil, nil end
		return "rbxassetid://" .. asset.id, asset.imageRectOffset, asset.imageRectSize
	else
		return getAssetUri(icon), nil, nil
	end
end

-- ═══════════════════════════════════════════════════════════════════════════
--  THEME ENGINE
-- ═══════════════════════════════════════════════════════════════════════════

local function ChangeTheme(Theme)
	if typeof(Theme) == 'string' then
		SelectedTheme = RayfieldLibrary.Theme[Theme]
	elseif typeof(Theme) == 'table' then
		SelectedTheme = Theme
	end

	Main.BackgroundColor3 = SelectedTheme.Background
	Topbar.BackgroundColor3 = SelectedTheme.Topbar
	Topbar.CornerRepair.BackgroundColor3 = SelectedTheme.Topbar
	Main.Shadow.Image.ImageColor3 = SelectedTheme.Shadow

	Topbar.ChangeSize.ImageColor3 = SelectedTheme.TextColor
	Topbar.Hide.ImageColor3 = SelectedTheme.TextColor
	Topbar.Search.ImageColor3 = SelectedTheme.TextColor
	if Topbar:FindFirstChild('Settings') then
		Topbar.Settings.ImageColor3 = SelectedTheme.TextColor
		Topbar.Divider.BackgroundColor3 = SelectedTheme.ElementStroke
	end

	Main.Search.BackgroundColor3 = SelectedTheme.TextColor
	Main.Search.Shadow.ImageColor3 = SelectedTheme.TextColor
	Main.Search.Search.ImageColor3 = SelectedTheme.TextColor
	Main.Search.Input.PlaceholderColor3 = SelectedTheme.TextColor
	Main.Search.UIStroke.Color = SelectedTheme.SecondaryElementStroke

	if Main:FindFirstChild('Notice') then
		Main.Notice.BackgroundColor3 = SelectedTheme.Background
	end

	-- Update all text labels
	for _, text in ipairs(Rayfield:GetDescendants()) do
		if text.Parent.Parent ~= Notifications then
			if text:IsA('TextLabel') or text:IsA('TextBox') then
				text.TextColor3 = SelectedTheme.TextColor
			end
		end
	end

	-- Update element backgrounds
	for _, TabPage in ipairs(Elements:GetChildren()) do
		for _, Element in ipairs(TabPage:GetChildren()) do
			if Element.ClassName == "Frame" and Element.Name ~= "Placeholder"
				and Element.Name ~= "SectionSpacing" and Element.Name ~= "Divider"
				and Element.Name ~= "SectionTitle" and Element.Name ~= "SearchTitle-fsefsefesfsefesfesfThanks"
			then
				Element.BackgroundColor3 = SelectedTheme.ElementBackground
				if Element:FindFirstChild("UIStroke") then
					Element.UIStroke.Color = SelectedTheme.ElementStroke
				end
			end
		end
	end

	-- Fire centralized theme callbacks for all registered elements
	for _, cb in ipairs(themeChangeCallbacks) do
		task.spawn(cb)
	end
end

-- ═══════════════════════════════════════════════════════════════════════════
--  COLOR UTILITIES
-- ═══════════════════════════════════════════════════════════════════════════

local function PackColor(Color)
	return {R = Color.R * 255, G = Color.G * 255, B = Color.B * 255}
end

local function UnpackColor(Color)
	return Color3.fromRGB(Color.R, Color.G, Color.B)
end

-- ═══════════════════════════════════════════════════════════════════════════
--  CONFIGURATION SAVING
-- ═══════════════════════════════════════════════════════════════════════════

local function LoadConfiguration(Configuration)
	local success, Data = pcall(function() return HttpService:JSONDecode(Configuration) end)
	local changed
	if not success then
		warn('Rayfield had an issue decoding the configuration file. Try deleting it and reopening Rayfield.')
		return
	end
	for FlagName, Flag in pairs(RayfieldLibrary.Flags) do
		local FlagValue = Data[FlagName]
		if (typeof(FlagValue) == 'boolean' and FlagValue == false) or FlagValue then
			task.spawn(function()
				if Flag.Type == "ColorPicker" then
					changed = true
					Flag:Set(UnpackColor(FlagValue))
				else
					if (Flag.CurrentValue or Flag.CurrentKeybind or Flag.CurrentOption or Flag.Color) ~= FlagValue then
						changed = true
						Flag:Set(FlagValue)
					end
				end
			end)
		else
			warn("Rayfield | Unable to find '" .. FlagName .. "' in the save file.")
		end
	end
	return changed
end

local function SaveConfiguration()
	if not CEnabled or not globalLoaded then return end
	if debugX then print('Saving') end
	local Data = {}
	for i, v in pairs(RayfieldLibrary.Flags) do
		if v.Type == "ColorPicker" then
			Data[i] = PackColor(v.Color)
		else
			if typeof(v.CurrentValue) == 'boolean' then
				Data[i] = v.CurrentValue
			else
				Data[i] = v.CurrentValue or v.CurrentKeybind or v.CurrentOption or v.Color
			end
		end
	end
	if useStudio then
		if script.Parent:FindFirstChild('configuration') then script.Parent.configuration:Destroy() end
		local ScreenGui = Instance.new("ScreenGui")
		ScreenGui.Parent = script.Parent
		ScreenGui.Name = 'configuration'
		local TextBox = Instance.new("TextBox")
		TextBox.Parent = ScreenGui
		TextBox.Size = UDim2.new(0, 800, 0, 50)
		TextBox.AnchorPoint = Vector2.new(0.5, 0)
		TextBox.Position = UDim2.new(0.5, 0, 0, 30)
		TextBox.Text = HttpService:JSONEncode(Data)
		TextBox.ClearTextOnFocus = false
	end
	callSafely(writefile, ConfigurationFolder .. "/" .. CFileName .. ConfigurationExtension, tostring(HttpService:JSONEncode(Data)))
end

-- ═══════════════════════════════════════════════════════════════════════════
--  NOTIFICATION SYSTEM
-- ═══════════════════════════════════════════════════════════════════════════

-- Notification type accent colors
local NOTIFY_COLORS = {
	info    = Color3.fromRGB(58, 163, 255),
	success = Color3.fromRGB(45, 200, 120),
	warning = Color3.fromRGB(255, 185, 50),
	error   = Color3.fromRGB(255, 80, 80),
}

function RayfieldLibrary:Notify(data)
	task.spawn(function()
		local newNotification = Notifications.Template:Clone()
		newNotification.Name        = data.Title or 'No Title Provided'
		newNotification.Parent      = Notifications
		newNotification.LayoutOrder = #Notifications:GetChildren()
		newNotification.Visible     = false

		newNotification.Title.Text       = data.Title or "Unknown Title"
		newNotification.Description.Text = data.Content or "Unknown Content"

		-- Icon
		if data.Image then
			local img, rectOffset, rectSize = resolveIcon(data.Image)
			newNotification.Icon.Image = img
			if rectOffset then newNotification.Icon.ImageRectOffset = rectOffset end
			if rectSize   then newNotification.Icon.ImageRectSize   = rectSize   end
		else
			newNotification.Icon.Image = ""
		end

		-- Type-based accent color
		local accentColor = NOTIFY_COLORS[tostring(data.Type):lower()]
			or NOTIFY_COLORS.info

		newNotification.Title.TextColor3       = accentColor
		newNotification.Description.TextColor3 = SelectedTheme.TextColor
		newNotification.BackgroundColor3       = SelectedTheme.NotificationBackground
		newNotification.UIStroke.Color         = accentColor
		newNotification.Icon.ImageColor3       = accentColor

		-- Start transparent
		newNotification.BackgroundTransparency       = 1
		newNotification.Title.TextTransparency       = 1
		newNotification.Description.TextTransparency = 1
		newNotification.UIStroke.Transparency        = 1
		newNotification.Shadow.ImageTransparency     = 1
		newNotification.Size                         = UDim2.new(1, 0, 0, 800)
		newNotification.Icon.ImageTransparency       = 1
		newNotification.Icon.BackgroundTransparency  = 1

		task.wait()
		newNotification.Visible = true

		local UIListLayout = Notifications:FindFirstChild("UIListLayout")
		local bounds = {newNotification.Title.TextBounds.Y, newNotification.Description.TextBounds.Y}
		local paddingOffset = UIListLayout and UIListLayout.Padding.Offset or 6
		newNotification.Size = UDim2.new(1, -60, 0, -paddingOffset)

		newNotification.Icon.Size     = UDim2.new(0, 32, 0, 32)
		newNotification.Icon.Position = UDim2.new(0, 20, 0.5, 0)

		tween(newNotification, TweenInfo.new(0.6, Enum.EasingStyle.Exponential), {Size = UDim2.new(1, 0, 0, math.max(bounds[1] + bounds[2] + 31, 60))})

		task.wait(0.15)
		tween(newNotification, TI_FAST,   {BackgroundTransparency = 0.45})
		tween(newNotification.Title, TI_FAST, {TextTransparency = 0})

		task.wait(0.05)
		tween(newNotification.Icon, TI_FAST, {ImageTransparency = 0})

		task.wait(0.05)
		tween(newNotification.Description, TI_FAST, {TextTransparency = 0.35})
		tween(newNotification.UIStroke,    TI_FAST, {Transparency = 0.85})
		tween(newNotification.Shadow,      TI_FAST, {ImageTransparency = 0.82})

		local waitDuration = math.min(math.max((#newNotification.Description.Text * 0.1) + 2.5, 3), 10)
		task.wait(data.Duration or waitDuration)

		newNotification.Icon.Visible = false
		tween(newNotification, TI_FAST, {BackgroundTransparency = 1})
		tween(newNotification.UIStroke, TI_FAST, {Transparency = 1})
		tween(newNotification.Shadow,   TI_FAST, {ImageTransparency = 1})
		tween(newNotification.Title,    TI_FAST, {TextTransparency = 1})
		tween(newNotification.Description, TI_FAST, {TextTransparency = 1})

		tween(newNotification, TI_SLOWER, {Size = UDim2.new(1, -90, 0, 0)})
		task.wait(1)
		tween(newNotification, TI_SLOWER, {Size = UDim2.new(1, -90, 0, -paddingOffset)})

		newNotification.Visible = false
		newNotification:Destroy()
	end)
end

-- ═══════════════════════════════════════════════════════════════════════════
--  SEARCH SYSTEM
-- ═══════════════════════════════════════════════════════════════════════════

local function openSearch()
	searchOpen = true

	Main.Search.BackgroundTransparency = 1
	Main.Search.Shadow.ImageTransparency = 1
	Main.Search.Input.TextTransparency = 1
	Main.Search.Search.ImageTransparency = 1
	Main.Search.UIStroke.Transparency = 1
	Main.Search.Size = UDim2.new(1, 0, 0, 80)
	Main.Search.Position = UDim2.new(0.5, 0, 0, 70)
	Main.Search.Input.Interactable = true
	Main.Search.Visible = true

	for _, tabbtn in ipairs(TabList:GetChildren()) do
		if tabbtn.ClassName == "Frame" and tabbtn.Name ~= "Placeholder" then
			tabbtn.Interact.Visible = false
			tween(tabbtn, TI_FAST, {BackgroundTransparency = 1})
			tween(tabbtn.Title, TI_FAST, {TextTransparency = 1})
			tween(tabbtn.Image, TI_FAST, {ImageTransparency = 1})
			tween(tabbtn.UIStroke, TI_FAST, {Transparency = 1})
		end
	end

	Main.Search.Input:CaptureFocus()
	tween(Main.Search.Shadow,   TweenInfo.new(0.05, Enum.EasingStyle.Quint), {ImageTransparency = 0.95})
	tween(Main.Search,          TI_FAST, {Position = UDim2.new(0.5, 0, 0, 57), BackgroundTransparency = 0.9})
	tween(Main.Search.UIStroke, TI_FAST, {Transparency = 0.8})
	tween(Main.Search.Input,    TI_FAST, {TextTransparency = 0.2})
	tween(Main.Search.Search,   TI_FAST, {ImageTransparency = 0.5})
	tween(Main.Search,          TI_NORMAL, {Size = UDim2.new(1, -35, 0, 35)})
end

local function closeSearch()
	searchOpen = false

	tween(Main.Search, TweenInfo.new(0.35, Enum.EasingStyle.Quint), {BackgroundTransparency = 1, Size = UDim2.new(1, -55, 0, 30)})
	tween(Main.Search.Search,   TweenInfo.new(0.15, Enum.EasingStyle.Quint), {ImageTransparency = 1})
	tween(Main.Search.Shadow,   TweenInfo.new(0.15, Enum.EasingStyle.Quint), {ImageTransparency = 1})
	tween(Main.Search.UIStroke, TweenInfo.new(0.15, Enum.EasingStyle.Quint), {Transparency = 1})
	tween(Main.Search.Input,    TweenInfo.new(0.15, Enum.EasingStyle.Quint), {TextTransparency = 1})

	for _, tabbtn in ipairs(TabList:GetChildren()) do
		if tabbtn.ClassName == "Frame" and tabbtn.Name ~= "Placeholder" then
			tabbtn.Interact.Visible = true
			if tostring(Elements.UIPageLayout.CurrentPage) == tabbtn.Title.Text then
				tween(tabbtn,         TI_FAST, {BackgroundTransparency = 0})
				tween(tabbtn.Image,   TI_FAST, {ImageTransparency = 0})
				tween(tabbtn.Title,   TI_FAST, {TextTransparency = 0})
				tween(tabbtn.UIStroke,TI_FAST, {Transparency = 1})
			else
				tween(tabbtn,         TI_FAST, {BackgroundTransparency = TRANS_TAB_UNSELECTED})
				tween(tabbtn.Image,   TI_FAST, {ImageTransparency = TRANS_TAB_TEXT})
				tween(tabbtn.Title,   TI_FAST, {TextTransparency = TRANS_TAB_TEXT})
				tween(tabbtn.UIStroke,TI_FAST, {Transparency = TRANS_TAB_STROKE})
			end
		end
	end

	Main.Search.Input.Text = ''
	Main.Search.Input.Interactable = false
end

-- ═══════════════════════════════════════════════════════════════════════════
--  VISIBILITY HELPERS (Hide / Show / Minimise / Maximise)
-- ═══════════════════════════════════════════════════════════════════════════

local function setElementsVisible(show)
	for _, tab in ipairs(Elements:GetChildren()) do
		if tab.Name ~= "Template" and tab.ClassName == "ScrollingFrame" and tab.Name ~= "Placeholder" then
			for _, element in ipairs(tab:GetChildren()) do
				if element.ClassName == "Frame" then
					if element.Name ~= "SectionSpacing" and element.Name ~= "Placeholder" then
						if element.Name == "SectionTitle" or element.Name == 'SearchTitle-fsefsefesfsefesfesfThanks' then
							tween(element.Title, TI_FAST, {TextTransparency = show and 0.4 or 1})
						elseif element.Name == 'Divider' then
							tween(element.Divider, TI_FAST, {BackgroundTransparency = show and 0.85 or 1})
						else
							local bgTarget     = element:GetAttribute("BackgroundTransparencyTarget") or 0
							local strokeTarget = element:GetAttribute("UIStrokeTransparencyTarget") or 0
							local titleTarget  = element:GetAttribute("TitleTextTransparencyTarget") or 0
							tween(element, TI_FAST, {BackgroundTransparency = show and bgTarget or 1})
							if element:FindFirstChild("UIStroke") then
								tween(element.UIStroke, TI_FAST, {Transparency = show and strokeTarget or 1})
							end
							if element:FindFirstChild("Title") then
								tween(element.Title, TI_FAST, {TextTransparency = show and titleTarget or 1})
							end
						end
						for _, child in ipairs(element:GetChildren()) do
							if child.ClassName == "Frame" or child.ClassName == "TextLabel"
								or child.ClassName == "TextBox" or child.ClassName == "ImageButton"
								or child.ClassName == "ImageLabel"
							then
								child.Visible = show
							end
						end
					end
				end
			end
		end
	end
end

local function setTabButtonsVisible(show)
	for _, tabbtn in ipairs(TabList:GetChildren()) do
		if tabbtn.ClassName == "Frame" and tabbtn.Name ~= "Placeholder" then
			if show then
				if tostring(Elements.UIPageLayout.CurrentPage) == tabbtn.Title.Text then
					tween(tabbtn,         TI_FAST, {BackgroundTransparency = 0})
					tween(tabbtn.Image,   TI_FAST, {ImageTransparency = 0})
					tween(tabbtn.Title,   TI_FAST, {TextTransparency = 0})
					tween(tabbtn.UIStroke,TI_FAST, {Transparency = 1})
				else
					tween(tabbtn,         TI_FAST, {BackgroundTransparency = TRANS_TAB_UNSELECTED})
					tween(tabbtn.Image,   TI_FAST, {ImageTransparency = TRANS_TAB_TEXT})
					tween(tabbtn.Title,   TI_FAST, {TextTransparency = TRANS_TAB_TEXT})
					tween(tabbtn.UIStroke,TI_FAST, {Transparency = TRANS_TAB_STROKE})
				end
			else
				tween(tabbtn,         TI_FAST, {BackgroundTransparency = 1})
				tween(tabbtn.Title,   TI_FAST, {TextTransparency = 1})
				tween(tabbtn.Image,   TI_FAST, {ImageTransparency = 1})
				tween(tabbtn.UIStroke,TI_FAST, {Transparency = 1})
			end
		end
	end
end

local function Hide(notify: boolean?)
	if MPrompt then
		MPrompt.Title.TextColor3     = Color3.fromRGB(255, 255, 255)
		MPrompt.Position             = UDim2.new(0.5, 0, 0, -50)
		MPrompt.Size                 = UDim2.new(0, 40, 0, 10)
		MPrompt.BackgroundTransparency = 1
		MPrompt.Title.TextTransparency = 1
		MPrompt.Visible              = true
	end

	task.spawn(closeSearch)
	Debounce = true

	if notify then
		if useMobilePrompt then
			RayfieldLibrary:Notify({Title = "Interface Hidden", Content = "Tap 'Show' to reveal the interface.", Duration = 7, Image = 4400697855, Type = "info"})
		else
			RayfieldLibrary:Notify({Title = "Interface Hidden", Content = "Press " .. tostring(getSetting("General", "rayfieldOpen")) .. " to show the interface.", Duration = 7, Image = 4400697855, Type = "info"})
		end
	end

	tween(Main,                TI_NORMAL, {Size = UDim2.new(0, 470, 0, 0)})
	tween(Main.Topbar,         TI_NORMAL, {Size = UDim2.new(0, 470, 0, TOPBAR_HEIGHT)})
	tween(Main,                TI_NORMAL, {BackgroundTransparency = 1})
	tween(Main.Topbar,         TI_NORMAL, {BackgroundTransparency = 1})
	tween(Main.Topbar.Divider, TI_NORMAL, {BackgroundTransparency = 1})
	tween(Main.Topbar.CornerRepair, TI_FAST, {BackgroundTransparency = 1})
	tween(Main.Topbar.Title,   TI_NORMAL, {TextTransparency = 1})
	tween(Main.Shadow.Image,   TI_NORMAL, {ImageTransparency = 1})
	tween(Topbar.UIStroke,     TI_NORMAL, {Transparency = 1})
	if dragBarCosmetic then
		tween(dragBarCosmetic, TI_BACK, {BackgroundTransparency = 1})
	end

	if useMobilePrompt and MPrompt then
		tween(MPrompt,       TI_NORMAL, {Size = UDim2.new(0, 120, 0, 30), Position = UDim2.new(0.5, 0, 0, 20), BackgroundTransparency = 0.3})
		tween(MPrompt.Title, TI_NORMAL, {TextTransparency = 0.3})
	end

	for _, TopbarButton in ipairs(Topbar:GetChildren()) do
		if TopbarButton.ClassName == "ImageButton" then
			tween(TopbarButton, TI_NORMAL, {ImageTransparency = 1})
		end
	end

	setTabButtonsVisible(false)
	if dragInteract then dragInteract.Visible = false end
	setElementsVisible(false)

	task.wait(ANIM_NORMAL)
	Main.Visible = false
	Debounce = false
end

local function Maximise()
	Debounce = true
	Topbar.ChangeSize.Image = customAssets[tostring(10137941941)]

	tween(Topbar.UIStroke,         TI_NORMAL, {Transparency = 1})
	tween(Main.Shadow.Image,       TI_NORMAL, {ImageTransparency = TRANS_SHADOW})
	tween(Topbar.CornerRepair,     TI_NORMAL, {BackgroundTransparency = 0})
	tween(Topbar.Divider,          TI_NORMAL, {BackgroundTransparency = 0})
	if dragBarCosmetic then
		tween(dragBarCosmetic, TI_BACK, {BackgroundTransparency = TRANS_TAB_UNSELECTED})
	end
	tween(Main, TI_NORMAL, {Size = useMobileSizing
		and UDim2.new(0, WINDOW_WIDTH, 0, WINDOW_HEIGHT_MOBILE)
		or  UDim2.new(0, WINDOW_WIDTH, 0, WINDOW_HEIGHT)})
	tween(Topbar, TI_NORMAL, {Size = UDim2.new(0, WINDOW_WIDTH, 0, TOPBAR_HEIGHT)})

	TabList.Visible = true
	task.wait(0.2)
	Elements.Visible = true
	setElementsVisible(true)
	task.wait(0.1)
	setTabButtonsVisible(true)

	task.wait(ANIM_NORMAL)
	Debounce = false
end

local function Unhide()
	Debounce = true
	Main.Position = UDim2.new(0.5, 0, 0.5, 0)
	Main.Visible  = true

	tween(Main, TI_NORMAL, {Size = useMobileSizing
		and UDim2.new(0, WINDOW_WIDTH, 0, WINDOW_HEIGHT_MOBILE)
		or  UDim2.new(0, WINDOW_WIDTH, 0, WINDOW_HEIGHT)})
	tween(Main.Topbar,          TI_NORMAL, {Size = UDim2.new(0, WINDOW_WIDTH, 0, TOPBAR_HEIGHT)})
	tween(Main.Shadow.Image,    TI_SLOW,   {ImageTransparency = TRANS_SHADOW})
	tween(Main,                 TI_NORMAL, {BackgroundTransparency = 0})
	tween(Main.Topbar,          TI_NORMAL, {BackgroundTransparency = 0})
	tween(Main.Topbar.Divider,  TI_NORMAL, {BackgroundTransparency = 0})
	tween(Main.Topbar.CornerRepair, TI_NORMAL, {BackgroundTransparency = 0})
	tween(Main.Topbar.Title,    TI_NORMAL, {TextTransparency = 0})

	if MPrompt then
		tween(MPrompt,       TI_NORMAL, {Size = UDim2.new(0, 40, 0, 10), Position = UDim2.new(0.5, 0, 0, -50), BackgroundTransparency = 1})
		tween(MPrompt.Title, TI_NORMAL, {TextTransparency = 1})
		task.spawn(function()
			task.wait(ANIM_NORMAL)
			MPrompt.Visible = false
		end)
	end

	if Minimised then task.spawn(Maximise) end

	if dragBar then
		dragBar.Position = useMobileSizing
			and UDim2.new(0.5, 0, 0.5, dragOffsetMobile)
			or  UDim2.new(0.5, 0, 0.5, dragOffset)
	end
	if dragInteract then dragInteract.Visible = true end

	for _, TopbarButton in ipairs(Topbar:GetChildren()) do
		if TopbarButton.ClassName == "ImageButton" then
			if TopbarButton.Name == 'Icon' then
				tween(TopbarButton, TI_SLOW, {ImageTransparency = 0})
			else
				tween(TopbarButton, TI_SLOW, {ImageTransparency = TRANS_TOPBAR_IDLE})
			end
		end
	end

	setTabButtonsVisible(true)
	setElementsVisible(true)
	if dragBarCosmetic then
		tween(dragBarCosmetic, TI_BACK, {BackgroundTransparency = 0.5})
	end

	task.wait(ANIM_NORMAL)
	Minimised = false
	Debounce  = false
end

local function Minimise()
	Debounce = true
	Topbar.ChangeSize.Image = customAssets[tostring(11036884234)]
	Topbar.UIStroke.Color   = SelectedTheme.ElementStroke

	task.spawn(closeSearch)
	setTabButtonsVisible(false)
	setElementsVisible(false)

	if dragBarCosmetic then
		tween(dragBarCosmetic, TI_BACK, {BackgroundTransparency = 1})
	end
	tween(Topbar.UIStroke,     TI_NORMAL, {Transparency = 0})
	tween(Main.Shadow.Image,   TI_NORMAL, {ImageTransparency = 1})
	tween(Topbar.CornerRepair, TI_NORMAL, {BackgroundTransparency = 1})
	tween(Topbar.Divider,      TI_NORMAL, {BackgroundTransparency = 1})
	tween(Main,    TI_NORMAL, {Size = UDim2.new(0, MINIMIZED_WIDTH, 0, TOPBAR_HEIGHT)})
	tween(Topbar,  TI_NORMAL, {Size = UDim2.new(0, MINIMIZED_WIDTH, 0, TOPBAR_HEIGHT)})

	task.wait(0.3)
	Elements.Visible = false
	TabList.Visible  = false

	task.wait(0.2)
	Debounce = false
end

-- ═══════════════════════════════════════════════════════════════════════════
--  SETTINGS TAB
-- ═══════════════════════════════════════════════════════════════════════════

local function saveSettings()
	local encoded
	local success, err = pcall(function()
		encoded = HttpService:JSONEncode(settingsTable)
	end)
	if success then
		if useStudio then
			if script.Parent['get.val'] then
				script.Parent['get.val'].Value = encoded
			end
		end
		callSafely(writefile, RayfieldFolder .. '/settings' .. ConfigurationExtension, encoded)
	end
end

local function updateSetting(category: string, setting: string, value: any)
	if not settingsInitialized then return end
	settingsTable[category][setting].Value = value
	overriddenSettings[category .. "." .. setting] = nil
	saveSettings()
end

local function createSettings(window)
	if not (writefile and isfile and readfile and isfolder and makefolder) and not useStudio then
		if Topbar['Settings'] then Topbar.Settings.Visible = false end
		Topbar['Search'].Position = UDim2.new(1, -75, 0.5, 0)
		warn("Can't create settings: no file-saving functionality available.")
		return
	end

	local newTab = window:CreateTab('Rayfield Settings', 0, true)
	if TabList['Rayfield Settings'] then
		TabList['Rayfield Settings'].LayoutOrder = 1000
	end
	if Elements['Rayfield Settings'] then
		Elements['Rayfield Settings'].LayoutOrder = 1000
	end

	for categoryName, settingCategory in pairs(settingsTable) do
		newTab:CreateSection(categoryName)
		for settingName, setting in pairs(settingCategory) do
			if setting.Type == 'input' then
				setting.Element = newTab:CreateInput({
					Name = setting.Name,
					CurrentValue = setting.Value,
					PlaceholderText = setting.Placeholder,
					Ext = true,
					RemoveTextAfterFocusLost = setting.ClearOnFocus,
					Callback = function(Value) updateSetting(categoryName, settingName, Value) end,
				})
			elseif setting.Type == 'toggle' then
				setting.Element = newTab:CreateToggle({
					Name = setting.Name,
					CurrentValue = setting.Value,
					Ext = true,
					Callback = function(Value) updateSetting(categoryName, settingName, Value) end,
				})
			elseif setting.Type == 'bind' then
				setting.Element = newTab:CreateKeybind({
					Name = setting.Name,
					CurrentKeybind = setting.Value,
					HoldToInteract = false,
					Ext = true,
					CallOnChange = true,
					Callback = function(Value) updateSetting(categoryName, settingName, Value) end,
				})
			end
		end
	end

	settingsCreated = true
	loadSettings()
	saveSettings()
end

-- ═══════════════════════════════════════════════════════════════════════════
--  DRAGGING
-- ═══════════════════════════════════════════════════════════════════════════

local function makeDraggable(object, dragObject, enableTaptic, tapticOffset)
	local dragging = false
	local relative = nil
	local offset   = Vector2.zero

	local screenGui = object:FindFirstAncestorWhichIsA("ScreenGui")
	if screenGui and screenGui.IgnoreGuiInset then
		offset += getService('GuiService'):GetGuiInset()
	end

	if dragBar and enableTaptic then
		dragBar.MouseEnter:Connect(function()
			if not dragging and not Hidden then
				tween(dragBarCosmetic, TI_BACK, {BackgroundTransparency = 0.5, Size = UDim2.new(0, 120, 0, 4)})
			end
		end)
		dragBar.MouseLeave:Connect(function()
			if not dragging and not Hidden then
				tween(dragBarCosmetic, TI_BACK, {BackgroundTransparency = 0.7, Size = UDim2.new(0, 100, 0, 4)})
			end
		end)
	end

	dragObject.InputBegan:Connect(function(input, processed)
		if processed then return end
		local inputType = input.UserInputType.Name
		if inputType == "MouseButton1" or inputType == "Touch" then
			dragging = true
			relative = object.AbsolutePosition + object.AbsoluteSize * object.AnchorPoint - UserInputService:GetMouseLocation()
			if enableTaptic and not Hidden then
				tween(dragBarCosmetic, TI_BACK_M, {Size = UDim2.new(0, 110, 0, 4), BackgroundTransparency = 0})
			end
		end
	end)

	local inputEnded = UserInputService.InputEnded:Connect(function(input)
		if not dragging then return end
		local inputType = input.UserInputType.Name
		if inputType == "MouseButton1" or inputType == "Touch" then
			dragging = false
			if enableTaptic and not Hidden then
				tween(dragBarCosmetic, TI_BACK_M, {Size = UDim2.new(0, 100, 0, 4), BackgroundTransparency = 0.7})
			end
		end
	end)

	local renderStepped = RunService.RenderStepped:Connect(function()
		if not dragging or Hidden then return end
		local position = UserInputService:GetMouseLocation() + relative + offset
		if enableTaptic and tapticOffset then
			tween(object, TweenInfo.new(0.4, Enum.EasingStyle.Exponential, Enum.EasingDirection.Out),
				{Position = UDim2.fromOffset(position.X, position.Y)})
			tween(dragObject.Parent, TweenInfo.new(0.05, Enum.EasingStyle.Exponential, Enum.EasingDirection.Out),
				{Position = UDim2.fromOffset(position.X, position.Y + ((useMobileSizing and tapticOffset[2]) or tapticOffset[1]))})
		else
			if dragBar and tapticOffset then
				dragBar.Position = UDim2.fromOffset(position.X, position.Y + ((useMobileSizing and tapticOffset[2]) or tapticOffset[1]))
			end
			object.Position = UDim2.fromOffset(position.X, position.Y)
		end
	end)

	object.Destroying:Connect(function()
		if inputEnded    then inputEnded:Disconnect()    end
		if renderStepped then renderStepped:Disconnect() end
	end)
end

-- ═══════════════════════════════════════════════════════════════════════════
--  KEY SYSTEM
-- ═══════════════════════════════════════════════════════════════════════════

local function fadeOutKeyUI(KeyMain)
	tween(KeyMain,                         TI_NORMAL, {BackgroundTransparency = 1})
	tween(KeyMain,                         TI_NORMAL, {Size = UDim2.new(0, 467, 0, 175)})
	tween(KeyMain.Shadow.Image,            TI_NORMAL, {ImageTransparency = 1})
	tween(KeyMain.Title,                   TI_FAST,   {TextTransparency = 1})
	tween(KeyMain.Subtitle,                TI_NORMAL, {TextTransparency = 1})
	tween(KeyMain.KeyNote,                 TI_NORMAL, {TextTransparency = 1})
	tween(KeyMain.Input,                   TI_NORMAL, {BackgroundTransparency = 1})
	tween(KeyMain.Input.UIStroke,          TI_NORMAL, {Transparency = 1})
	tween(KeyMain.Input.InputBox,          TI_NORMAL, {TextTransparency = 1})
	tween(KeyMain.NoteTitle,               TI_FAST,   {TextTransparency = 1})
	tween(KeyMain.NoteMessage,             TI_FAST,   {TextTransparency = 1})
	tween(KeyMain.Hide,                    TI_FAST,   {ImageTransparency = 1})
end

-- ═══════════════════════════════════════════════════════════════════════════
--  WINDOW CREATION
-- ═══════════════════════════════════════════════════════════════════════════

function RayfieldLibrary:CreateWindow(Settings)
	-- Loading screen
	if Rayfield:FindFirstChild('Loading') then
		if getgenv and not getgenv().rayfieldCached then
			Rayfield.Enabled = true
			Rayfield.Loading.Visible = true
			task.wait(1.4)
			Rayfield.Loading.Visible = false
		end
	end
	if getgenv then getgenv().rayfieldCached = true end

	if not correctBuild and not Settings.DisableBuildWarnings then
		task.delay(3, function()
			RayfieldLibrary:Notify({
				Title   = 'Build Mismatch',
				Content = 'Rayfield may encounter issues as you are running an incompatible interface version (' .. ((Rayfield:FindFirstChild('Build') and Rayfield.Build.Value) or 'No Build') .. ').\n\nThis version requires build ' .. InterfaceBuild .. '.\n\nTry rejoining and running the script twice.',
				Image   = 4335487866,
				Duration = 15,
				Type    = "warning",
			})
		end)
	end

	-- Toggle keybind override
	if Settings.ToggleUIKeybind then
		local keybind = Settings.ToggleUIKeybind
		if type(keybind) == "string" then
			keybind = string.upper(keybind)
			assert(pcall(function() return Enum.KeyCode[keybind] end), "ToggleUIKeybind must be a valid KeyCode")
			overrideSetting("General", "rayfieldOpen", keybind)
		elseif typeof(keybind) == "EnumItem" then
			assert(keybind.EnumType == Enum.KeyCode, "ToggleUIKeybind must be a KeyCode enum")
			overrideSetting("General", "rayfieldOpen", keybind.Name)
		else
			error("ToggleUIKeybind must be a string or KeyCode enum")
		end
	end

	ensureFolder(RayfieldFolder)

	local Passthrough    = false
	Topbar.Title.Text    = Settings.Name

	Main.Size            = UDim2.new(0, 420, 0, 100)
	Main.Visible         = true
	Main.BackgroundTransparency = 1
	if Main:FindFirstChild('Notice') then Main.Notice.Visible = false end
	Main.Shadow.Image.ImageTransparency = 1

	LoadingFrame.Title.TextTransparency    = 1
	LoadingFrame.Subtitle.TextTransparency = 1

	if Settings.ShowText then
		if MPrompt then MPrompt.Title.Text = 'Show ' .. Settings.ShowText end
	end

	LoadingFrame.Version.TextTransparency = 1
	LoadingFrame.Title.Text    = Settings.LoadingTitle    or "Rayfield"
	LoadingFrame.Subtitle.Text = Settings.LoadingSubtitle or "Interface Suite"

	if Settings.LoadingTitle ~= "Rayfield Interface Suite" then
		LoadingFrame.Version.Text = "Rayfield UI"
	end

	if Settings.Icon and Settings.Icon ~= 0 and Topbar:FindFirstChild('Icon') then
		Topbar.Icon.Visible  = true
		Topbar.Title.Position = UDim2.new(0, 47, 0.5, 0)
		local img, rectOffset, rectSize = resolveIcon(Settings.Icon)
		Topbar.Icon.Image = img
		if rectOffset then Topbar.Icon.ImageRectOffset = rectOffset end
		if rectSize   then Topbar.Icon.ImageRectSize   = rectSize   end
	end

	if dragBar then
		dragBar.Visible = false
		if dragBarCosmetic then dragBarCosmetic.BackgroundTransparency = 1 end
		dragBar.Visible = true
	end

	if Settings.Theme then
		local success, result = pcall(ChangeTheme, Settings.Theme)
		if not success then
			pcall(ChangeTheme, 'Default')
			warn('Rayfield | Issue applying theme: ' .. tostring(result))
		end
	end

	Topbar.Visible     = false
	Elements.Visible   = false
	LoadingFrame.Visible = true

	if not Settings.DisableRayfieldPrompts then
		task.spawn(function()
			while not rayfieldDestroyed do
				task.wait(math.random(180, 600))
				if rayfieldDestroyed then break end
				RayfieldLibrary:Notify({
					Title   = "Rayfield Interface",
					Content = "Enjoying this UI library? Find it at sirius.menu/discord",
					Duration = 7,
					Image   = 4370033185,
					Type    = "info",
				})
			end
		end)
	end

	pcall(function()
		if not Settings.ConfigurationSaving.FileName then
			Settings.ConfigurationSaving.FileName = tostring(game.PlaceId)
		end
		if Settings.ConfigurationSaving.Enabled == nil then
			Settings.ConfigurationSaving.Enabled = false
		end
		CFileName          = Settings.ConfigurationSaving.FileName
		ConfigurationFolder = Settings.ConfigurationSaving.FolderName or ConfigurationFolder
		CEnabled           = Settings.ConfigurationSaving.Enabled
		if Settings.ConfigurationSaving.Enabled then
			ensureFolder(ConfigurationFolder)
		end
	end)

	makeDraggable(Main, Topbar, false, {dragOffset, dragOffsetMobile})
	if dragBar then
		dragBar.Position = useMobileSizing
			and UDim2.new(0.5, 0, 0.5, dragOffsetMobile)
			or  UDim2.new(0.5, 0, 0.5, dragOffset)
		makeDraggable(Main, dragInteract, true, {dragOffset, dragOffsetMobile})
	end

	-- Reset tab buttons
	for _, TabButton in ipairs(TabList:GetChildren()) do
		if TabButton.ClassName == "Frame" and TabButton.Name ~= "Placeholder" then
			TabButton.BackgroundTransparency = 1
			TabButton.Title.TextTransparency = 1
			TabButton.Image.ImageTransparency = 1
			TabButton.UIStroke.Transparency   = 1
		end
	end

	-- Discord integration
	if Settings.Discord and Settings.Discord.Enabled and not useStudio and not secureMode then
		ensureFolder(RayfieldFolder .. "/Discord Invites")
		if not callSafely(isfile, RayfieldFolder .. "/Discord Invites/" .. Settings.Discord.Invite .. ConfigurationExtension) then
			if requestFunc then
				pcall(function()
					requestFunc({
						Url    = 'http://127.0.0.1:6463/rpc?v=1',
						Method = 'POST',
						Headers = {
							['Content-Type'] = 'application/json',
							Origin           = 'https://discord.com'
						},
						Body = HttpService:JSONEncode({
							cmd   = 'INVITE_BROWSER',
							nonce = HttpService:GenerateGUID(false),
							args  = {code = Settings.Discord.Invite}
						})
					})
				end)
			end
			if Settings.Discord.RememberJoins then
				callSafely(writefile, RayfieldFolder .. "/Discord Invites/" .. Settings.Discord.Invite .. ConfigurationExtension, "Rayfield RememberJoins")
			end
		end
	end

	-- Key system
	if Settings.KeySystem then
		if not Settings.KeySettings then
			Passthrough = true
		else
			ensureFolder(RayfieldFolder .. "/Key System")
			if typeof(Settings.KeySettings.Key) == "string" then
				Settings.KeySettings.Key = {Settings.KeySettings.Key}
			end

			if Settings.KeySettings.GrabKeyFromSite then
				for i, Key in ipairs(Settings.KeySettings.Key) do
					local Success, Response = pcall(function()
						Settings.KeySettings.Key[i] = tostring(game:HttpGet(Key):gsub("[\n\r]", " "))
						Settings.KeySettings.Key[i] = string.gsub(Settings.KeySettings.Key[i], " ", "")
					end)
					if not Success then
						print("Rayfield | " .. Key .. " Error " .. tostring(Response))
					end
				end
			end

			if not Settings.KeySettings.FileName then
				Settings.KeySettings.FileName = "No file name specified"
			end

			if callSafely(isfile, RayfieldFolder .. "/Key System/" .. Settings.KeySettings.FileName .. ConfigurationExtension) then
				for _, MKey in ipairs(Settings.KeySettings.Key) do
					local savedKeys = callSafely(readfile, RayfieldFolder .. "/Key System/" .. Settings.KeySettings.FileName .. ConfigurationExtension)
					if savedKeys and string.find(savedKeys, MKey) then
						Passthrough = true
					end
				end
			end

			if not Passthrough then
				local AttemptsRemaining = Settings.KeySettings.MaxAttempts or 5
				Rayfield.Enabled = false
				local KeyUI
				local keyOk, keyErr = pcall(function()
					KeyUI = useStudio
						and script.Parent:FindFirstChild('Key')
						or  game:GetObjects("rbxassetid://11380036235")[1]
				end)
				if not keyOk or not KeyUI then
					warn("Rayfield | Failed to load Key UI: " .. tostring(keyErr))
					Passthrough = true
				else
					KeyUI.Enabled = true
					safeParentGui(KeyUI)
					cleanupOldInstances(KeyUI)

					local KeyMain = KeyUI.Main
					KeyMain.Title.Text      = Settings.KeySettings.Title    or Settings.Name
					KeyMain.Subtitle.Text   = Settings.KeySettings.Subtitle or "Key System"
					KeyMain.NoteMessage.Text = Settings.KeySettings.Note    or "No instructions"

					KeyMain.Size = UDim2.new(0, 467, 0, 175)
					KeyMain.BackgroundTransparency         = 1
					KeyMain.Shadow.Image.ImageTransparency = 1
					KeyMain.Title.TextTransparency         = 1
					KeyMain.Subtitle.TextTransparency      = 1
					KeyMain.KeyNote.TextTransparency       = 1
					KeyMain.Input.BackgroundTransparency   = 1
					KeyMain.Input.UIStroke.Transparency    = 1
					KeyMain.Input.InputBox.TextTransparency = 1
					KeyMain.NoteTitle.TextTransparency     = 1
					KeyMain.NoteMessage.TextTransparency   = 1
					KeyMain.Hide.ImageTransparency         = 1

					tween(KeyMain,              TI_NORMAL, {BackgroundTransparency = 0, Size = UDim2.new(0, 500, 0, 187)})
					tween(KeyMain.Shadow.Image, TI_NORMAL, {ImageTransparency = 0.5})
					task.wait(0.05)
					tween(KeyMain.Title,    TI_FAST, {TextTransparency = 0})
					tween(KeyMain.Subtitle, TI_NORMAL, {TextTransparency = 0})
					task.wait(0.05)
					tween(KeyMain.KeyNote,          TI_NORMAL, {TextTransparency = 0})
					tween(KeyMain.Input,            TI_NORMAL, {BackgroundTransparency = 0})
					tween(KeyMain.Input.UIStroke,   TI_NORMAL, {Transparency = 0})
					tween(KeyMain.Input.InputBox,   TI_NORMAL, {TextTransparency = 0})
					task.wait(0.05)
					tween(KeyMain.NoteTitle,   TI_FAST, {TextTransparency = 0})
					tween(KeyMain.NoteMessage, TI_FAST, {TextTransparency = 0})
					task.wait(0.15)
					tween(KeyMain.Hide, TI_FAST, {ImageTransparency = 0.3})

					KeyUI.Main.Input.InputBox.FocusLost:Connect(function()
						if #KeyUI.Main.Input.InputBox.Text == 0 then return end
						local KeyFound = false
						local FoundKey = ''
						for _, MKey in ipairs(Settings.KeySettings.Key) do
							if KeyMain.Input.InputBox.Text == MKey then
								KeyFound = true
								FoundKey = MKey
							end
						end
						if KeyFound then
							fadeOutKeyUI(KeyMain)
							task.wait(0.51)
							Passthrough = true
							KeyMain.Visible = false
							if Settings.KeySettings.SaveKey then
								callSafely(writefile, RayfieldFolder .. "/Key System/" .. Settings.KeySettings.FileName .. ConfigurationExtension, FoundKey)
								RayfieldLibrary:Notify({Title = "Key System", Content = "Your key has been saved.", Image = 3605522284, Type = "success"})
							end
						else
							if AttemptsRemaining == 0 then
								fadeOutKeyUI(KeyMain)
								task.wait(0.45)
								Players.LocalPlayer:Kick("No Attempts Remaining")
								game:Shutdown()
							end
							KeyMain.Input.InputBox.Text = ""
							AttemptsRemaining -= 1
							tween(KeyMain, TI_NORMAL, {Size = UDim2.new(0, 467, 0, 175)})
							tween(KeyMain, TI_ELASTIC, {Position = UDim2.new(0.495, 0, 0.5, 0)})
							task.wait(0.1)
							tween(KeyMain, TI_ELASTIC, {Position = UDim2.new(0.505, 0, 0.5, 0)})
							task.wait(0.1)
							tween(KeyMain, TI_FAST, {Position = UDim2.new(0.5, 0, 0.5, 0)})
							tween(KeyMain, TI_NORMAL, {Size = UDim2.new(0, 500, 0, 187)})
							RayfieldLibrary:Notify({Title = "Key System", Content = "Invalid key. " .. AttemptsRemaining .. " attempt(s) remaining.", Type = "error"})
						end
					end)

					KeyMain.Hide.MouseButton1Click:Connect(function()
						fadeOutKeyUI(KeyMain)
						task.wait(0.51)
						Passthrough = true
						RayfieldLibrary:Destroy()
						KeyUI:Destroy()
					end)
				end
			else
				Passthrough = true
			end
		end
	end

	if Settings.KeySystem then
		repeat task.wait() until Passthrough
		if rayfieldDestroyed then return end
	end

	Notifications.Template.Visible = false
	Notifications.Visible = true
	Rayfield.Enabled      = true

	task.wait(ANIM_NORMAL)
	tween(Main,              TI_SLOW, {BackgroundTransparency = 0})
	tween(Main.Shadow.Image, TI_SLOW, {ImageTransparency = TRANS_SHADOW})
	task.wait(0.1)
	tween(LoadingFrame.Title,    TI_SLOW, {TextTransparency = 0})
	task.wait(0.05)
	tween(LoadingFrame.Subtitle, TI_SLOW, {TextTransparency = 0})
	task.wait(0.05)
	tween(LoadingFrame.Version,  TI_SLOW, {TextTransparency = 0})

	Elements.Template.LayoutOrder = 100000
	Elements.Template.Visible     = false
	Elements.UIPageLayout.FillDirection          = Enum.FillDirection.Horizontal
	Elements.UIPageLayout.ScrollWheelInputEnabled = false
	Elements.UIPageLayout.GamepadInputEnabled     = false
	Elements.UIPageLayout.TouchInputEnabled       = false
	TabList.Template.Visible = false

	-- ═══════════════════════════════════════════════════════════════════════
	--  TAB + ELEMENT CREATION
	-- ═══════════════════════════════════════════════════════════════════════

	local FirstTab = false
	local Window   = {}

	function Window:CreateTab(Name, Image, Ext)
		local SDone    = false
		local TabButton = TabList.Template:Clone()
		TabButton.Name  = Name
		TabButton.Title.Text = Name
		TabButton.Parent     = TabList
		TabButton.Title.TextWrapped = false
		TabButton.Size = UDim2.new(0, TabButton.Title.TextBounds.X + 30, 0, 30)

		if Image and Image ~= 0 then
			local img, rectOffset, rectSize = resolveIcon(Image)
			TabButton.Image.Image = img
			if rectOffset then TabButton.Image.ImageRectOffset = rectOffset end
			if rectSize   then TabButton.Image.ImageRectSize   = rectSize   end
			TabButton.Title.AnchorPoint        = Vector2.new(0, 0.5)
			TabButton.Title.Position           = UDim2.new(0, 37, 0.5, 0)
			TabButton.Image.Visible            = true
			TabButton.Title.TextXAlignment     = Enum.TextXAlignment.Left
			TabButton.Size = UDim2.new(0, TabButton.Title.TextBounds.X + 52, 0, 30)
		end

		TabButton.BackgroundTransparency = 1
		TabButton.Title.TextTransparency = 1
		TabButton.Image.ImageTransparency = 1
		TabButton.UIStroke.Transparency  = 1
		TabButton.Visible = not Ext or false

		local TabPage = Elements.Template:Clone()
		TabPage.Name  = Name
		TabPage.Visible = true
		TabPage.LayoutOrder = Ext and 10000 or #Elements:GetChildren()

		for _, TemplateElement in ipairs(TabPage:GetChildren()) do
			if TemplateElement.ClassName == "Frame" and TemplateElement.Name ~= "Placeholder" then
				TemplateElement:Destroy()
			end
		end

		TabPage.Parent = Elements
		if not FirstTab and not Ext then
			Elements.UIPageLayout.Animated = false
			Elements.UIPageLayout:JumpTo(TabPage)
			Elements.UIPageLayout.Animated = true
		end

		TabButton.UIStroke.Color = SelectedTheme.TabStroke

		if Elements.UIPageLayout.CurrentPage == TabPage then
			TabButton.BackgroundColor3 = SelectedTheme.TabBackgroundSelected
			TabButton.Image.ImageColor3 = SelectedTheme.SelectedTabTextColor
			TabButton.Title.TextColor3  = SelectedTheme.SelectedTabTextColor
		else
			TabButton.BackgroundColor3  = SelectedTheme.TabBackground
			TabButton.Image.ImageColor3 = SelectedTheme.TabTextColor
			TabButton.Title.TextColor3  = SelectedTheme.TabTextColor
		end

		task.wait(0.1)
		if FirstTab or Ext then
			TabButton.BackgroundColor3  = SelectedTheme.TabBackground
			TabButton.Image.ImageColor3 = SelectedTheme.TabTextColor
			TabButton.Title.TextColor3  = SelectedTheme.TabTextColor
			tween(TabButton,         TI_SLOW, {BackgroundTransparency = TRANS_TAB_UNSELECTED})
			tween(TabButton.Title,   TI_SLOW, {TextTransparency = TRANS_TAB_TEXT})
			tween(TabButton.Image,   TI_SLOW, {ImageTransparency = TRANS_TAB_TEXT})
			tween(TabButton.UIStroke,TI_SLOW, {Transparency = TRANS_TAB_STROKE})
		elseif not Ext then
			FirstTab = Name
			TabButton.BackgroundColor3  = SelectedTheme.TabBackgroundSelected
			TabButton.Image.ImageColor3 = SelectedTheme.SelectedTabTextColor
			TabButton.Title.TextColor3  = SelectedTheme.SelectedTabTextColor
			tween(TabButton.Image,   TI_SLOW, {ImageTransparency = 0})
			tween(TabButton,         TI_SLOW, {BackgroundTransparency = 0})
			tween(TabButton.Title,   TI_SLOW, {TextTransparency = 0})
		end

		local function selectTab()
			tween(TabButton,         TI_SLOW, {BackgroundTransparency = 0, BackgroundColor3 = SelectedTheme.TabBackgroundSelected})
			tween(TabButton.UIStroke,TI_SLOW, {Transparency = 1})
			tween(TabButton.Title,   TI_SLOW, {TextTransparency = 0, TextColor3 = SelectedTheme.SelectedTabTextColor})
			tween(TabButton.Image,   TI_SLOW, {ImageTransparency = 0, ImageColor3 = SelectedTheme.SelectedTabTextColor})

			for _, OtherTabButton in ipairs(TabList:GetChildren()) do
				if OtherTabButton.Name ~= "Template" and OtherTabButton.ClassName == "Frame"
					and OtherTabButton ~= TabButton and OtherTabButton.Name ~= "Placeholder"
				then
					tween(OtherTabButton,         TI_SLOW, {BackgroundColor3 = SelectedTheme.TabBackground, BackgroundTransparency = TRANS_TAB_UNSELECTED})
					tween(OtherTabButton.Title,   TI_SLOW, {TextColor3 = SelectedTheme.TabTextColor, TextTransparency = TRANS_TAB_TEXT})
					tween(OtherTabButton.Image,   TI_SLOW, {ImageColor3 = SelectedTheme.TabTextColor, ImageTransparency = TRANS_TAB_TEXT})
					tween(OtherTabButton.UIStroke,TI_SLOW, {Transparency = TRANS_TAB_STROKE})
				end
			end

			if Elements.UIPageLayout.CurrentPage ~= TabPage then
				Elements.UIPageLayout:JumpTo(TabPage)
			end
		end

		TabButton.Interact.MouseButton1Click:Connect(function()
			if Minimised then return end
			selectTab()
		end)

		-- Theme change handler for this tab button
		onThemeChange(function()
			TabButton.UIStroke.Color = SelectedTheme.TabStroke
			if Elements.UIPageLayout.CurrentPage == TabPage then
				TabButton.BackgroundColor3  = SelectedTheme.TabBackgroundSelected
				TabButton.Image.ImageColor3 = SelectedTheme.SelectedTabTextColor
				TabButton.Title.TextColor3  = SelectedTheme.SelectedTabTextColor
			else
				TabButton.BackgroundColor3  = SelectedTheme.TabBackground
				TabButton.Image.ImageColor3 = SelectedTheme.TabTextColor
				TabButton.Title.TextColor3  = SelectedTheme.TabTextColor
			end
		end)

		local Tab = {}

		-- ───────────────────────────────────────────────────────────────
		-- BUTTON
		-- ───────────────────────────────────────────────────────────────
		function Tab:CreateButton(ButtonSettings)
			assert(type(ButtonSettings.Callback) == "function", "Rayfield | CreateButton requires a Callback function")
			local ButtonValue = {}

			local Button = Elements.Template.Button:Clone()
			Button.Name        = ButtonSettings.Name
			Button.Title.Text  = ButtonSettings.Name
			Button.Visible     = true
			Button.Parent      = TabPage
			Button.BackgroundColor3 = SelectedTheme.ElementBackground

			-- Description
			if ButtonSettings.Description then
				local Desc = Instance.new("TextLabel")
				Desc.Name              = "Description"
				Desc.Text              = ButtonSettings.Description
				Desc.TextColor3        = SelectedTheme.TextColor
				Desc.TextTransparency  = 0.4
				Desc.Font              = Enum.Font.GothamMedium
				Desc.TextSize          = 11
				Desc.Size              = UDim2.new(1, -120, 0, 14)
				Desc.Position          = UDim2.new(0, 12, 1, -16)
				Desc.BackgroundTransparency = 1
				Desc.TextXAlignment    = Enum.TextXAlignment.Left
				Desc.ZIndex            = Button.ZIndex + 1
				Desc.Parent            = Button
				Button.Size            = UDim2.new(1, -10, 0, 55)
			end

			Button.BackgroundTransparency = 1
			Button.UIStroke.Transparency  = 1
			Button.Title.TextTransparency = 1

			tween(Button,         TI_SLOW, {BackgroundTransparency = 0})
			tween(Button.UIStroke,TI_SLOW, {Transparency = 0})
			tween(Button.Title,   TI_SLOW, {TextTransparency = 0})

			-- Disabled state
			local isDisabled = ButtonSettings.Disabled == true
			if isDisabled then
				Button.BackgroundTransparency = 0.5
				Button.Title.TextTransparency = 0.5
			end

			Button.Interact.MouseButton1Click:Connect(function()
				if isDisabled then return end
				tween(Button, TI_NORMAL, {BackgroundColor3 = SelectedTheme.ElementBackgroundHover})
				tween(Button.ElementIndicator, TI_NORMAL, {TextTransparency = 1})
				tween(Button.UIStroke, TI_NORMAL, {Transparency = 1})
				task.wait(0.2)
				tween(Button, TI_NORMAL, {BackgroundColor3 = SelectedTheme.ElementBackground})
				tween(Button.ElementIndicator, TI_NORMAL, {TextTransparency = TRANS_INDICATOR})
				tween(Button.UIStroke, TI_NORMAL, {Transparency = 0})
				local success = safeCallback(ButtonSettings.Callback, Button, ButtonSettings.Name)
				if success and not ButtonSettings.Ext then SaveConfiguration() end
			end)

			addHoverEffect(Button)

			onThemeChange(function()
				if not isDisabled then
					Button.BackgroundColor3 = SelectedTheme.ElementBackground
				end
				Button.UIStroke.Color = SelectedTheme.ElementStroke
				if Button:FindFirstChild("Description") then
					Button.Description.TextColor3 = SelectedTheme.TextColor
				end
			end)

			function ButtonValue:Set(NewName)
				Button.Title.Text = NewName
				Button.Name       = NewName
			end

			function ButtonValue:SetDisabled(state)
				isDisabled = state
				Button.BackgroundTransparency = state and 0.5 or 0
				Button.Title.TextTransparency = state and 0.5 or 0
			end

			function ButtonValue:SetVisible(state)
				Button.Visible = state
			end

			return ButtonValue
		end

		-- ───────────────────────────────────────────────────────────────
		-- TOGGLE
		-- ───────────────────────────────────────────────────────────────
		function Tab:CreateToggle(ToggleSettings)
			local Toggle = Elements.Template.Toggle:Clone()
			Toggle.Name       = ToggleSettings.Name
			Toggle.Title.Text = ToggleSettings.Name
			Toggle.Visible    = true
			Toggle.Parent     = TabPage
			Toggle.Switch.BackgroundColor3 = SelectedTheme.ToggleBackground

			if SelectedTheme ~= RayfieldLibrary.Theme.Default then
				Toggle.Switch.Shadow.Visible = false
			end

			Toggle.BackgroundTransparency = 1
			Toggle.UIStroke.Transparency  = 1
			Toggle.Title.TextTransparency = 1

			tween(Toggle,         TI_SLOW, {BackgroundTransparency = 0})
			tween(Toggle.UIStroke,TI_SLOW, {Transparency = 0})
			tween(Toggle.Title,   TI_SLOW, {TextTransparency = 0})

			if ToggleSettings.CurrentValue == true then
				Toggle.Switch.Indicator.Position = UDim2.new(1, -20, 0.5, 0)
				Toggle.Switch.Indicator.UIStroke.Color  = SelectedTheme.ToggleEnabledStroke
				Toggle.Switch.Indicator.BackgroundColor3 = SelectedTheme.ToggleEnabled
				Toggle.Switch.UIStroke.Color = SelectedTheme.ToggleEnabledOuterStroke
			else
				Toggle.Switch.Indicator.Position = UDim2.new(1, -40, 0.5, 0)
				Toggle.Switch.Indicator.UIStroke.Color  = SelectedTheme.ToggleDisabledStroke
				Toggle.Switch.Indicator.BackgroundColor3 = SelectedTheme.ToggleDisabled
				Toggle.Switch.UIStroke.Color = SelectedTheme.ToggleDisabledOuterStroke
			end

			addHoverEffect(Toggle)

			local function applyToggleState(val)
				if val then
					tween(Toggle.Switch.Indicator, TI_QUART_F, {Position = UDim2.new(1, -20, 0.5, 0)})
					tween(Toggle.Switch.Indicator.UIStroke, TI_QUART_N, {Color = SelectedTheme.ToggleEnabledStroke})
					tween(Toggle.Switch.Indicator, TweenInfo.new(0.8, Enum.EasingStyle.Exponential, Enum.EasingDirection.Out), {BackgroundColor3 = SelectedTheme.ToggleEnabled})
					tween(Toggle.Switch.UIStroke, TI_QUART_N, {Color = SelectedTheme.ToggleEnabledOuterStroke})
				else
					tween(Toggle.Switch.Indicator, TI_QUART_F, {Position = UDim2.new(1, -40, 0.5, 0)})
					tween(Toggle.Switch.Indicator.UIStroke, TI_QUART_N, {Color = SelectedTheme.ToggleDisabledStroke})
					tween(Toggle.Switch.Indicator, TweenInfo.new(0.8, Enum.EasingStyle.Exponential, Enum.EasingDirection.Out), {BackgroundColor3 = SelectedTheme.ToggleDisabled})
					tween(Toggle.Switch.UIStroke, TI_QUART_N, {Color = SelectedTheme.ToggleDisabledOuterStroke})
				end
			end

			Toggle.Interact.MouseButton1Click:Connect(function()
				ToggleSettings.CurrentValue = not ToggleSettings.CurrentValue
				tween(Toggle, TI_NORMAL, {BackgroundColor3 = SelectedTheme.ElementBackgroundHover})
				tween(Toggle.UIStroke, TI_NORMAL, {Transparency = 1})
				applyToggleState(ToggleSettings.CurrentValue)
				tween(Toggle, TI_NORMAL, {BackgroundColor3 = SelectedTheme.ElementBackground})
				tween(Toggle.UIStroke, TI_NORMAL, {Transparency = 0})

				local success = safeCallback(ToggleSettings.Callback, Toggle, ToggleSettings.Name, ToggleSettings.CurrentValue)
				if success and not ToggleSettings.Ext then SaveConfiguration() end
			end)

			function ToggleSettings:Set(NewValue)
				ToggleSettings.CurrentValue = NewValue
				tween(Toggle, TI_NORMAL, {BackgroundColor3 = SelectedTheme.ElementBackgroundHover})
				tween(Toggle.UIStroke, TI_NORMAL, {Transparency = 1})
				applyToggleState(NewValue)
				tween(Toggle, TI_NORMAL, {BackgroundColor3 = SelectedTheme.ElementBackground})
				tween(Toggle.UIStroke, TI_NORMAL, {Transparency = 0})
				local success = safeCallback(ToggleSettings.Callback, Toggle, ToggleSettings.Name, NewValue)
				if success and not ToggleSettings.Ext then SaveConfiguration() end
			end

			function ToggleSettings:SetVisible(state)
				Toggle.Visible = state
			end

			registerFlag(Settings, ToggleSettings)

			onThemeChange(function()
				Toggle.Switch.BackgroundColor3 = SelectedTheme.ToggleBackground
				Toggle.Switch.Shadow.Visible = SelectedTheme == RayfieldLibrary.Theme.Default
				task.wait()
				if ToggleSettings.CurrentValue then
					Toggle.Switch.Indicator.UIStroke.Color   = SelectedTheme.ToggleEnabledStroke
					Toggle.Switch.Indicator.BackgroundColor3 = SelectedTheme.ToggleEnabled
					Toggle.Switch.UIStroke.Color             = SelectedTheme.ToggleEnabledOuterStroke
				else
					Toggle.Switch.Indicator.UIStroke.Color   = SelectedTheme.ToggleDisabledStroke
					Toggle.Switch.Indicator.BackgroundColor3 = SelectedTheme.ToggleDisabled
					Toggle.Switch.UIStroke.Color             = SelectedTheme.ToggleDisabledOuterStroke
				end
			end)

			return ToggleSettings
		end

		-- ───────────────────────────────────────────────────────────────
		-- SLIDER
		-- ───────────────────────────────────────────────────────────────
		function Tab:CreateSlider(SliderSettings)
			assert(type(SliderSettings.Range) == "table" and #SliderSettings.Range == 2, "Rayfield | CreateSlider requires Range = {min, max}")
			local SLDragging = false

			local Slider = Elements.Template.Slider:Clone()
			Slider.Name       = SliderSettings.Name
			Slider.Title.Text = SliderSettings.Name
			Slider.Visible    = true
			Slider.Parent     = TabPage

			Slider.BackgroundTransparency = 1
			Slider.UIStroke.Transparency  = 1
			Slider.Title.TextTransparency = 1

			if SelectedTheme ~= RayfieldLibrary.Theme.Default then
				Slider.Main.Shadow.Visible = false
			end

			Slider.Main.BackgroundColor3         = SelectedTheme.SliderBackground
			Slider.Main.UIStroke.Color           = SelectedTheme.SliderStroke
			Slider.Main.Progress.UIStroke.Color  = SelectedTheme.SliderStroke
			Slider.Main.Progress.BackgroundColor3 = SelectedTheme.SliderProgress

			tween(Slider,         TI_SLOW, {BackgroundTransparency = 0})
			tween(Slider.UIStroke,TI_SLOW, {Transparency = 0})
			tween(Slider.Title,   TI_SLOW, {TextTransparency = 0})

			local function getProgressWidth(val)
				local raw = Slider.Main.AbsoluteSize.X * ((val - SliderSettings.Range[1]) / (SliderSettings.Range[2] - SliderSettings.Range[1]))
				return math.max(raw, 5)
			end

			Slider.Main.Progress.Size = UDim2.new(0, getProgressWidth(SliderSettings.CurrentValue), 1, 0)
			Slider.Main.Information.Text = SliderSettings.Suffix
				and tostring(SliderSettings.CurrentValue) .. " " .. SliderSettings.Suffix
				or  tostring(SliderSettings.CurrentValue)

			addHoverEffect(Slider)

			Slider.Main.Interact.InputBegan:Connect(function(Input)
				if Input.UserInputType == Enum.UserInputType.MouseButton1 or Input.UserInputType == Enum.UserInputType.Touch then
					tween(Slider.Main.UIStroke,          TI_NORMAL, {Transparency = 1})
					tween(Slider.Main.Progress.UIStroke, TI_NORMAL, {Transparency = 1})
					SLDragging = true
				end
			end)

			Slider.Main.Interact.InputEnded:Connect(function(Input)
				if Input.UserInputType == Enum.UserInputType.MouseButton1 or Input.UserInputType == Enum.UserInputType.Touch then
					tween(Slider.Main.UIStroke,          TI_NORMAL, {Transparency = 0.4})
					tween(Slider.Main.Progress.UIStroke, TI_NORMAL, {Transparency = 0.3})
					SLDragging = false
				end
			end)

			Slider.Main.Interact.MouseButton1Down:Connect(function(X)
				local Current = Slider.Main.Progress.AbsolutePosition.X + Slider.Main.Progress.AbsoluteSize.X
				local Start   = Current
				local Loop; Loop = RunService.Stepped:Connect(function()
					if not SLDragging then
						local Location = UserInputService:GetMouseLocation().X
						tween(Slider.Main.Progress, TI_FAST,
							{Size = UDim2.new(0, math.max(Location - Slider.Main.AbsolutePosition.X, 5), 1, 0)})
						Loop:Disconnect()
						return
					end
					local Location = UserInputService:GetMouseLocation().X
					Current = Current + SLIDER_DRAG_FACTOR * (Location - Start)
					Location = math.clamp(Location, Slider.Main.AbsolutePosition.X, Slider.Main.AbsolutePosition.X + Slider.Main.AbsoluteSize.X)
					Current  = math.clamp(Current,  Slider.Main.AbsolutePosition.X + 5, Slider.Main.AbsolutePosition.X + Slider.Main.AbsoluteSize.X)

					if Current <= Location and (Location - Start) < 0 then Start = Location
					elseif Current >= Location and (Location - Start) > 0 then Start = Location end

					tween(Slider.Main.Progress, TweenInfo.new(0.45, Enum.EasingStyle.Exponential, Enum.EasingDirection.Out),
						{Size = UDim2.new(0, Current - Slider.Main.AbsolutePosition.X, 1, 0)})

					local NewValue = SliderSettings.Range[1]
						+ (Location - Slider.Main.AbsolutePosition.X) / Slider.Main.AbsoluteSize.X
						* (SliderSettings.Range[2] - SliderSettings.Range[1])
					NewValue = math.floor(NewValue / SliderSettings.Increment + 0.5) * (SliderSettings.Increment * SLIDER_PRECISION) / SLIDER_PRECISION
					NewValue = math.clamp(NewValue, SliderSettings.Range[1], SliderSettings.Range[2])
					Slider.Main.Information.Text = SliderSettings.Suffix
						and tostring(NewValue) .. " " .. SliderSettings.Suffix
						or  tostring(NewValue)

					if SliderSettings.CurrentValue ~= NewValue then
						local success = safeCallback(SliderSettings.Callback, Slider, SliderSettings.Name, NewValue)
						SliderSettings.CurrentValue = NewValue
						if success and not SliderSettings.Ext then SaveConfiguration() end
					end
				end)
			end)

			function SliderSettings:Set(NewVal)
				NewVal = math.clamp(NewVal, SliderSettings.Range[1], SliderSettings.Range[2])
				tween(Slider.Main.Progress, TweenInfo.new(0.45, Enum.EasingStyle.Exponential, Enum.EasingDirection.Out),
					{Size = UDim2.new(0, getProgressWidth(NewVal), 1, 0)})
				Slider.Main.Information.Text = tostring(NewVal) .. " " .. (SliderSettings.Suffix or "")
				local success = safeCallback(SliderSettings.Callback, Slider, SliderSettings.Name, NewVal)
				SliderSettings.CurrentValue = NewVal
				if success and not SliderSettings.Ext then SaveConfiguration() end
			end

			function SliderSettings:SetVisible(state)
				Slider.Visible = state
			end

			registerFlag(Settings, SliderSettings)

			onThemeChange(function()
				Slider.Main.Shadow.Visible = SelectedTheme == RayfieldLibrary.Theme.Default
				Slider.Main.BackgroundColor3          = SelectedTheme.SliderBackground
				Slider.Main.UIStroke.Color            = SelectedTheme.SliderStroke
				Slider.Main.Progress.UIStroke.Color   = SelectedTheme.SliderStroke
				Slider.Main.Progress.BackgroundColor3 = SelectedTheme.SliderProgress
			end)

			return SliderSettings
		end

		-- ───────────────────────────────────────────────────────────────
		-- DROPDOWN
		-- ───────────────────────────────────────────────────────────────
		function Tab:CreateDropdown(DropdownSettings)
			local Dropdown = Elements.Template.Dropdown:Clone()
			Dropdown.Name  = DropdownSettings.Name
			Dropdown.Title.Text = DropdownSettings.Name
			Dropdown.Visible = true
			Dropdown.Parent  = TabPage

			Dropdown.List.Visible = false

			if DropdownSettings.CurrentOption then
				if type(DropdownSettings.CurrentOption) == "string" then
					DropdownSettings.CurrentOption = {DropdownSettings.CurrentOption}
				end
				if not DropdownSettings.MultipleOptions then
					DropdownSettings.CurrentOption = {DropdownSettings.CurrentOption[1]}
				end
			else
				DropdownSettings.CurrentOption = {}
			end

			-- Helper: update Selected text
			local function updateSelectedText()
				if DropdownSettings.MultipleOptions then
					if #DropdownSettings.CurrentOption == 1 then
						Dropdown.Selected.Text = DropdownSettings.CurrentOption[1]
					elseif #DropdownSettings.CurrentOption == 0 then
						Dropdown.Selected.Text = "None"
					else
						Dropdown.Selected.Text = "Various"
					end
				else
					Dropdown.Selected.Text = DropdownSettings.CurrentOption[1] or "None"
				end
			end
			updateSelectedText()

			Dropdown.Toggle.ImageColor3 = SelectedTheme.TextColor
			tween(Dropdown, TI_FAST, {BackgroundColor3 = SelectedTheme.ElementBackground})
			Dropdown.BackgroundTransparency = 1
			Dropdown.UIStroke.Transparency  = 1
			Dropdown.Title.TextTransparency = 1
			Dropdown.Size = UDim2.new(1, -10, 0, ELEMENT_HEIGHT)

			tween(Dropdown,         TI_SLOW, {BackgroundTransparency = 0})
			tween(Dropdown.UIStroke,TI_SLOW, {Transparency = 0})
			tween(Dropdown.Title,   TI_SLOW, {TextTransparency = 0})

			-- Clear template options
			for _, opt in ipairs(Dropdown.List:GetChildren()) do
				if opt.ClassName == "Frame" and opt.Name ~= "Placeholder" then opt:Destroy() end
			end
			Dropdown.Toggle.Rotation = 180

			Dropdown.Interact.MouseButton1Click:Connect(function()
				tween(Dropdown,         TI_FAST, {BackgroundColor3 = SelectedTheme.ElementBackgroundHover})
				tween(Dropdown.UIStroke,TI_FAST, {Transparency = 1})
				task.wait(0.1)
				tween(Dropdown,         TI_FAST, {BackgroundColor3 = SelectedTheme.ElementBackground})
				tween(Dropdown.UIStroke,TI_FAST, {Transparency = 0})
				if Debounce then return end
				if Dropdown.List.Visible then
					Debounce = true
					tween(Dropdown, TI_NORMAL, {Size = UDim2.new(1, -10, 0, ELEMENT_HEIGHT)})
					for _, opt in ipairs(Dropdown.List:GetChildren()) do
						if opt.ClassName == "Frame" and opt.Name ~= "Placeholder" then
							tween(opt,         TI_FAST, {BackgroundTransparency = 1})
							tween(opt.UIStroke,TI_FAST, {Transparency = 1})
							tween(opt.Title,   TI_FAST, {TextTransparency = 1})
						end
					end
					tween(Dropdown.List,   TI_FAST, {ScrollBarImageTransparency = 1})
					tween(Dropdown.Toggle, TI_SLOW, {Rotation = 180})
					task.wait(0.35)
					Dropdown.List.Visible = false
					Debounce = false
				else
					tween(Dropdown, TI_NORMAL, {Size = UDim2.new(1, -10, 0, DROPDOWN_HEIGHT)})
					Dropdown.List.Visible = true
					tween(Dropdown.List,   TI_FAST, {ScrollBarImageTransparency = 0.7})
					tween(Dropdown.Toggle, TI_SLOW, {Rotation = 0})
					for _, opt in ipairs(Dropdown.List:GetChildren()) do
						if opt.ClassName == "Frame" and opt.Name ~= "Placeholder" then
							if not table.find(DropdownSettings.CurrentOption, opt.Name) then
								tween(opt.UIStroke, TI_FAST, {Transparency = 0})
							end
							tween(opt,       TI_FAST, {BackgroundTransparency = 0})
							tween(opt.Title, TI_FAST, {TextTransparency = 0})
						end
					end
				end
			end)

			addHoverEffect(Dropdown)

			local function SetDropdownOptions()
				for _, Option in ipairs(DropdownSettings.Options) do
					local DropdownOption = Elements.Template.Dropdown.List.Template:Clone()
					DropdownOption.Name        = Option
					DropdownOption.Title.Text  = Option
					DropdownOption.Parent      = Dropdown.List
					DropdownOption.Visible     = true
					DropdownOption.BackgroundTransparency = 1
					DropdownOption.UIStroke.Transparency  = 1
					DropdownOption.Title.TextTransparency = 1

					DropdownOption.Interact.ZIndex = 50
					DropdownOption.Interact.MouseButton1Click:Connect(function()
						if not DropdownSettings.MultipleOptions and table.find(DropdownSettings.CurrentOption, Option) then return end

						if table.find(DropdownSettings.CurrentOption, Option) then
							table.remove(DropdownSettings.CurrentOption, table.find(DropdownSettings.CurrentOption, Option))
						else
							if not DropdownSettings.MultipleOptions then table.clear(DropdownSettings.CurrentOption) end
							table.insert(DropdownSettings.CurrentOption, Option)
							tween(DropdownOption.UIStroke, TI_FAST, {Transparency = 1})
							tween(DropdownOption, TI_FAST, {BackgroundColor3 = SelectedTheme.DropdownSelected})
							Debounce = true
						end
						updateSelectedText()

						-- Deselect all others
						for _, droption in ipairs(Dropdown.List:GetChildren()) do
							if droption.ClassName == "Frame" and droption.Name ~= "Placeholder"
								and not table.find(DropdownSettings.CurrentOption, droption.Name)
							then
								tween(droption, TI_FAST, {BackgroundColor3 = SelectedTheme.DropdownUnselected})
							end
						end

						local success = safeCallback(DropdownSettings.Callback, Dropdown, DropdownSettings.Name, DropdownSettings.CurrentOption)

						if not DropdownSettings.MultipleOptions then
							task.wait(0.1)
							tween(Dropdown, TI_NORMAL, {Size = UDim2.new(1, -10, 0, ELEMENT_HEIGHT)})
							for _, opt in ipairs(Dropdown.List:GetChildren()) do
								if opt.ClassName == "Frame" and opt.Name ~= "Placeholder" then
									tween(opt,         TI_FAST, {BackgroundTransparency = 1})
									tween(opt.UIStroke,TI_FAST, {Transparency = 1})
									tween(opt.Title,   TI_FAST, {TextTransparency = 1})
								end
							end
							tween(Dropdown.List,   TI_FAST, {ScrollBarImageTransparency = 1})
							tween(Dropdown.Toggle, TI_SLOW, {Rotation = 180})
							task.wait(0.35)
							Dropdown.List.Visible = false
						end
						Debounce = false
						if success and not DropdownSettings.Ext then SaveConfiguration() end
					end)

					onThemeChange(function()
						DropdownOption.UIStroke.Color = SelectedTheme.ElementStroke
						if table.find(DropdownSettings.CurrentOption, DropdownOption.Name) then
							DropdownOption.BackgroundColor3 = SelectedTheme.DropdownSelected
						else
							DropdownOption.BackgroundColor3 = SelectedTheme.DropdownUnselected
						end
					end)
				end
			end
			SetDropdownOptions()

			-- Color options
			for _, droption in ipairs(Dropdown.List:GetChildren()) do
				if droption.ClassName == "Frame" and droption.Name ~= "Placeholder" then
					droption.BackgroundColor3 = table.find(DropdownSettings.CurrentOption, droption.Name)
						and SelectedTheme.DropdownSelected
						or  SelectedTheme.DropdownUnselected
				end
			end

			function DropdownSettings:Set(NewOption)
				DropdownSettings.CurrentOption = type(NewOption) == "string" and {NewOption} or NewOption
				if not DropdownSettings.MultipleOptions then
					DropdownSettings.CurrentOption = {DropdownSettings.CurrentOption[1]}
				end
				updateSelectedText()
				local success = safeCallback(DropdownSettings.Callback, Dropdown, DropdownSettings.Name, DropdownSettings.CurrentOption)
				for _, droption in ipairs(Dropdown.List:GetChildren()) do
					if droption.ClassName == "Frame" and droption.Name ~= "Placeholder" then
						droption.BackgroundColor3 = table.find(DropdownSettings.CurrentOption, droption.Name)
							and SelectedTheme.DropdownSelected
							or  SelectedTheme.DropdownUnselected
					end
				end
			end

			function DropdownSettings:Refresh(optionsTable: table)
				DropdownSettings.Options = optionsTable
				for _, opt in Dropdown.List:GetChildren() do
					if opt.ClassName == "Frame" and opt.Name ~= "Placeholder" then opt:Destroy() end
				end
				SetDropdownOptions()
				for _, droption in ipairs(Dropdown.List:GetChildren()) do
					if droption.ClassName == "Frame" and droption.Name ~= "Placeholder" then
						droption.BackgroundColor3 = table.find(DropdownSettings.CurrentOption, droption.Name)
							and SelectedTheme.DropdownSelected
							or  SelectedTheme.DropdownUnselected
						if Dropdown.List.Visible then
							droption.BackgroundTransparency = 0
							droption.Title.TextTransparency = 0
							if not table.find(DropdownSettings.CurrentOption, droption.Name) then
								droption.UIStroke.Transparency = 0
							end
						end
					end
				end
			end

			function DropdownSettings:SetVisible(state)
				Dropdown.Visible = state
			end

			registerFlag(Settings, DropdownSettings)

			onThemeChange(function()
				Dropdown.Toggle.ImageColor3 = SelectedTheme.TextColor
				tween(Dropdown, TI_FAST, {BackgroundColor3 = SelectedTheme.ElementBackground})
			end)

			return DropdownSettings
		end

		-- ───────────────────────────────────────────────────────────────
		-- KEYBIND
		-- ───────────────────────────────────────────────────────────────
		function Tab:CreateKeybind(KeybindSettings)
			local CheckingForKey = false

			local Keybind = Elements.Template.Keybind:Clone()
			Keybind.Name       = KeybindSettings.Name
			Keybind.Title.Text = KeybindSettings.Name
			Keybind.Visible    = true
			Keybind.Parent     = TabPage
			Keybind.KeybindFrame.BackgroundColor3 = SelectedTheme.InputBackground
			Keybind.KeybindFrame.UIStroke.Color   = SelectedTheme.InputStroke

			Keybind.BackgroundTransparency = 1
			Keybind.UIStroke.Transparency  = 1
			Keybind.Title.TextTransparency = 1

			tween(Keybind,         TI_SLOW, {BackgroundTransparency = 0})
			tween(Keybind.UIStroke,TI_SLOW, {Transparency = 0})
			tween(Keybind.Title,   TI_SLOW, {TextTransparency = 0})

			Keybind.KeybindFrame.KeybindBox.Text = KeybindSettings.CurrentKeybind
			Keybind.KeybindFrame.Size = UDim2.new(0, Keybind.KeybindFrame.KeybindBox.TextBounds.X + 24, 0, 30)

			Keybind.KeybindFrame.KeybindBox.Focused:Connect(function()
				CheckingForKey = true
				Keybind.KeybindFrame.KeybindBox.Text = ""
			end)

			Keybind.KeybindFrame.KeybindBox.FocusLost:Connect(function()
				CheckingForKey = false
				if not Keybind.KeybindFrame.KeybindBox.Text or Keybind.KeybindFrame.KeybindBox.Text == "" then
					Keybind.KeybindFrame.KeybindBox.Text = KeybindSettings.CurrentKeybind
					if not KeybindSettings.Ext then SaveConfiguration() end
				end
			end)

			addHoverEffect(Keybind)

			local connection = UserInputService.InputBegan:Connect(function(input, processed)
				if CheckingForKey then
					if input.KeyCode ~= Enum.KeyCode.Unknown then
						local NewKey = string.split(tostring(input.KeyCode), ".")[3]
						Keybind.KeybindFrame.KeybindBox.Text = tostring(NewKey)
						KeybindSettings.CurrentKeybind       = tostring(NewKey)
						Keybind.KeybindFrame.KeybindBox:ReleaseFocus()
						if not KeybindSettings.Ext then SaveConfiguration() end
						if KeybindSettings.CallOnChange then
							KeybindSettings.Callback(tostring(NewKey))
						end
					end
				elseif not KeybindSettings.CallOnChange
					and KeybindSettings.CurrentKeybind ~= nil
					and not processed
				then
					local ok, keyEnum = pcall(function()
						return Enum.KeyCode[KeybindSettings.CurrentKeybind]
					end)
					if ok and input.KeyCode == keyEnum then
						local Held = true
						local Connection
						Connection = input.Changed:Connect(function(prop)
							if prop == "UserInputState" then
								Connection:Disconnect()
								Held = false
							end
						end)
						if not KeybindSettings.HoldToInteract then
							safeCallback(KeybindSettings.Callback, Keybind, KeybindSettings.Name)
						else
							task.wait(0.25)
							if Held then
								local Loop; Loop = RunService.Stepped:Connect(function()
									if not Held then
										-- Key released: call with false
										local ok2 = pcall(KeybindSettings.Callback, false)
										Loop:Disconnect()
									else
										-- Key held: call with true
										pcall(KeybindSettings.Callback, true)
									end
								end)
							end
						end
					end
				end
			end)
			table.insert(keybindConnections, connection)

			Keybind.KeybindFrame.KeybindBox:GetPropertyChangedSignal("Text"):Connect(function()
				tween(Keybind.KeybindFrame, TweenInfo.new(0.55, Enum.EasingStyle.Exponential, Enum.EasingDirection.Out),
					{Size = UDim2.new(0, Keybind.KeybindFrame.KeybindBox.TextBounds.X + 24, 0, 30)})
			end)

			function KeybindSettings:Set(NewKeybind)
				Keybind.KeybindFrame.KeybindBox.Text = tostring(NewKeybind)
				KeybindSettings.CurrentKeybind       = tostring(NewKeybind)
				Keybind.KeybindFrame.KeybindBox:ReleaseFocus()
				if not KeybindSettings.Ext then SaveConfiguration() end
				if KeybindSettings.CallOnChange then
					KeybindSettings.Callback(tostring(NewKeybind))
				end
			end

			function KeybindSettings:SetVisible(state)
				Keybind.Visible = state
			end

			registerFlag(Settings, KeybindSettings)

			onThemeChange(function()
				Keybind.KeybindFrame.BackgroundColor3 = SelectedTheme.InputBackground
				Keybind.KeybindFrame.UIStroke.Color   = SelectedTheme.InputStroke
			end)

			return KeybindSettings
		end

		-- ───────────────────────────────────────────────────────────────
		-- TOGGLE (duplicate-guard: already defined above; this line marks end of tab)
		-- ───────────────────────────────────────────────────────────────

		-- ───────────────────────────────────────────────────────────────
		-- INPUT
		-- ───────────────────────────────────────────────────────────────
		function Tab:CreateInput(InputSettings)
			local Input = Elements.Template.Input:Clone()
			Input.Name       = InputSettings.Name
			Input.Title.Text = InputSettings.Name
			Input.Visible    = true
			Input.Parent     = TabPage

			Input.InputFrame.BackgroundColor3 = SelectedTheme.InputBackground
			Input.InputFrame.UIStroke.Color   = SelectedTheme.InputStroke

			Input.BackgroundTransparency = 1
			Input.UIStroke.Transparency  = 1
			Input.Title.TextTransparency = 1

			tween(Input,         TI_SLOW, {BackgroundTransparency = 0})
			tween(Input.UIStroke,TI_SLOW, {Transparency = 0})
			tween(Input.Title,   TI_SLOW, {TextTransparency = 0})

			Input.InputFrame.InputBox.Text = InputSettings.CurrentValue or ''
			Input.InputFrame.InputBox.PlaceholderText = InputSettings.PlaceholderText or ""
			Input.InputFrame.Size = UDim2.new(0, Input.InputFrame.InputBox.TextBounds.X + 24, 0, 30)

			Input.InputFrame.InputBox.FocusLost:Connect(function()
				local success = safeCallback(function()
					InputSettings.Callback(Input.InputFrame.InputBox.Text)
					InputSettings.CurrentValue = Input.InputFrame.InputBox.Text
				end, Input, InputSettings.Name)
				if InputSettings.RemoveTextAfterFocusLost then
					Input.InputFrame.InputBox.Text = ""
				end
				if success and not InputSettings.Ext then SaveConfiguration() end
			end)

			addHoverEffect(Input)

			Input.InputFrame.InputBox:GetPropertyChangedSignal("Text"):Connect(function()
				tween(Input.InputFrame, TweenInfo.new(0.55, Enum.EasingStyle.Exponential, Enum.EasingDirection.Out),
					{Size = UDim2.new(0, Input.InputFrame.InputBox.TextBounds.X + 24, 0, 30)})
			end)

			function InputSettings:Set(text)
				Input.InputFrame.InputBox.Text = text
				InputSettings.CurrentValue = text
				local success = safeCallback(InputSettings.Callback, Input, InputSettings.Name, text)
				if success and not InputSettings.Ext then SaveConfiguration() end
			end

			function InputSettings:SetVisible(state)
				Input.Visible = state
			end

			registerFlag(Settings, InputSettings)

			onThemeChange(function()
				Input.InputFrame.BackgroundColor3 = SelectedTheme.InputBackground
				Input.InputFrame.UIStroke.Color   = SelectedTheme.InputStroke
			end)

			return InputSettings
		end

		-- ───────────────────────────────────────────────────────────────
		-- COLORPICKER
		-- ───────────────────────────────────────────────────────────────
		function Tab:CreateColorPicker(ColorPickerSettings)
			ColorPickerSettings.Type = "ColorPicker"
			local ColorPicker = Elements.Template.ColorPicker:Clone()
			local Background  = ColorPicker.CPBackground
			local Display     = Background.Display
			local MainCP      = Background.MainCP  -- renamed from Main to avoid shadow
			local Slider      = ColorPicker.ColorSlider

			ColorPicker.ClipsDescendants = true
			ColorPicker.Name       = ColorPickerSettings.Name
			ColorPicker.Title.Text = ColorPickerSettings.Name
			ColorPicker.Visible    = true
			ColorPicker.Parent     = TabPage
			ColorPicker.Size       = UDim2.new(1, -10, 0, ELEMENT_HEIGHT)

			Background.Size     = UDim2.new(0, 39, 0, 22)
			Display.BackgroundTransparency = 0
			MainCP.MainPoint.ImageTransparency = 1
			ColorPicker.Interact.Size     = UDim2.new(1, 0, 1, 0)
			ColorPicker.Interact.Position = UDim2.new(0.5, 0, 0.5, 0)
			ColorPicker.RGB.Position      = UDim2.new(0, 17, 0, 70)
			ColorPicker.HexInput.Position = UDim2.new(0, 17, 0, 90)
			MainCP.ImageTransparency      = 1
			Background.BackgroundTransparency = 1

			for _, rgbinput in ipairs(ColorPicker.RGB:GetChildren()) do
				if rgbinput:IsA("Frame") then
					rgbinput.BackgroundColor3 = SelectedTheme.InputBackground
					rgbinput.UIStroke.Color   = SelectedTheme.InputStroke
				end
			end
			ColorPicker.HexInput.BackgroundColor3 = SelectedTheme.InputBackground
			ColorPicker.HexInput.UIStroke.Color   = SelectedTheme.InputStroke

			local opened        = false
			local mouse         = Players.LocalPlayer:GetMouse()
			local mainDragging  = false
			local sliderDragging = false

			ColorPicker.Interact.MouseButton1Down:Connect(function()
				task.spawn(function()
					tween(ColorPicker,         TI_NORMAL, {BackgroundColor3 = SelectedTheme.ElementBackgroundHover})
					tween(ColorPicker.UIStroke,TI_NORMAL, {Transparency = 1})
					task.wait(0.2)
					tween(ColorPicker,         TI_NORMAL, {BackgroundColor3 = SelectedTheme.ElementBackground})
					tween(ColorPicker.UIStroke,TI_NORMAL, {Transparency = 0})
				end)

				if not opened then
					opened = true
					tween(Background,     TweenInfo.new(0.45, Enum.EasingStyle.Exponential), {Size = UDim2.new(0, 18, 0, 15)})
					task.wait(0.1)
					tween(ColorPicker,         TI_NORMAL, {Size = UDim2.new(1, -10, 0, 120)})
					tween(Background,          TI_NORMAL, {Size = UDim2.new(0, 173, 0, 86)})
					tween(Display,             TI_NORMAL, {BackgroundTransparency = 1})
					tween(ColorPicker.Interact,TI_NORMAL, {Position = UDim2.new(0.289, 0, 0.5, 0)})
					tween(ColorPicker.RGB,     TweenInfo.new(0.8, Enum.EasingStyle.Exponential), {Position = UDim2.new(0, 17, 0, 40)})
					tween(ColorPicker.HexInput,TI_NORMAL, {Position = UDim2.new(0, 17, 0, 73)})
					tween(ColorPicker.Interact,TI_NORMAL, {Size = UDim2.new(0.574, 0, 1, 0)})
					tween(MainCP.MainPoint,    TI_INSTANT,{ImageTransparency = 0})
					tween(MainCP,              TI_INSTANT, {ImageTransparency = SelectedTheme ~= RayfieldLibrary.Theme.Default and 0.25 or 0.1})
					tween(Background,          TI_NORMAL, {BackgroundTransparency = 0})
				else
					opened = false
					tween(ColorPicker,         TI_NORMAL, {Size = UDim2.new(1, -10, 0, ELEMENT_HEIGHT)})
					tween(Background,          TI_NORMAL, {Size = UDim2.new(0, 39, 0, 22)})
					tween(ColorPicker.Interact,TI_NORMAL, {Size = UDim2.new(1, 0, 1, 0)})
					tween(ColorPicker.Interact,TI_NORMAL, {Position = UDim2.new(0.5, 0, 0.5, 0)})
					tween(ColorPicker.RGB,     TI_NORMAL, {Position = UDim2.new(0, 17, 0, 70)})
					tween(ColorPicker.HexInput,TI_NORMAL, {Position = UDim2.new(0, 17, 0, 90)})
					tween(Display,             TI_NORMAL, {BackgroundTransparency = 0})
					tween(MainCP.MainPoint,    TI_INSTANT, {ImageTransparency = 1})
					tween(MainCP,              TI_INSTANT, {ImageTransparency = 1})
					tween(Background,          TI_NORMAL, {BackgroundTransparency = 1})
				end
			end)

			local cpInputConn = UserInputService.InputEnded:Connect(function(input)
				if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
					mainDragging  = false
					sliderDragging = false
				end
			end)

			MainCP.MouseButton1Down:Connect(function() if opened then mainDragging = true end end)
			MainCP.MainPoint.MouseButton1Down:Connect(function() if opened then mainDragging = true end end)
			Slider.MouseButton1Down:Connect(function() sliderDragging = true end)
			Slider.SliderPoint.MouseButton1Down:Connect(function() sliderDragging = true end)

			local h, s, v = ColorPickerSettings.Color:ToHSV()
			local colorVal = Color3.fromHSV(h, s, v)
			local hex = string.format("#%02X%02X%02X", colorVal.R * 0xFF, colorVal.G * 0xFF, colorVal.B * 0xFF)
			ColorPicker.HexInput.InputBox.Text = hex

			local function setDisplay()
				MainCP.MainPoint.Position = UDim2.new(s, -MainCP.MainPoint.AbsoluteSize.X / 2, 1 - v, -MainCP.MainPoint.AbsoluteSize.Y / 2)
				MainCP.MainPoint.ImageColor3    = Color3.fromHSV(h, s, v)
				Background.BackgroundColor3     = Color3.fromHSV(h, 1, 1)
				Display.BackgroundColor3        = Color3.fromHSV(h, s, v)
				local x = h * Slider.AbsoluteSize.X
				Slider.SliderPoint.Position   = UDim2.new(0, x - Slider.SliderPoint.AbsoluteSize.X / 2, 0.5, 0)
				Slider.SliderPoint.ImageColor3 = Color3.fromHSV(h, 1, 1)
				local c = Color3.fromHSV(h, s, v)
				local r, g, b = math.floor(c.R * 255 + 0.5), math.floor(c.G * 255 + 0.5), math.floor(c.B * 255 + 0.5)
				ColorPicker.RGB.RInput.InputBox.Text = tostring(r)
				ColorPicker.RGB.GInput.InputBox.Text = tostring(g)
				ColorPicker.RGB.BInput.InputBox.Text = tostring(b)
				hex = string.format("#%02X%02X%02X", c.R * 0xFF, c.G * 0xFF, c.B * 0xFF)
				ColorPicker.HexInput.InputBox.Text = hex
			end
			setDisplay()

			ColorPicker.HexInput.InputBox.FocusLost:Connect(function()
				if not pcall(function()
					local r, g, b = string.match(ColorPicker.HexInput.InputBox.Text, "^#?(%w%w)(%w%w)(%w%w)$")
					local rgbColor = Color3.fromRGB(tonumber(r, 16), tonumber(g, 16), tonumber(b, 16))
					h, s, v = rgbColor:ToHSV()
					hex = ColorPicker.HexInput.InputBox.Text
					setDisplay()
					ColorPickerSettings.Color = rgbColor
				end) then
					ColorPicker.HexInput.InputBox.Text = hex
				end
				pcall(ColorPickerSettings.Callback, Color3.fromHSV(h, s, v))
				ColorPickerSettings.Color = Color3.fromHSV(h, s, v)
				if not ColorPickerSettings.Ext then SaveConfiguration() end
			end)

			local function rgbBoxes(box, toChange)
				local value    = tonumber(box.Text)
				local c        = Color3.fromHSV(h, s, v)
				local oR, oG, oB = math.floor(c.R*255+0.5), math.floor(c.G*255+0.5), math.floor(c.B*255+0.5)
				local save
				if toChange == "R" then save = oR; oR = value
				elseif toChange == "G" then save = oG; oG = value
				else save = oB; oB = value end
				if value then
					value = math.clamp(value, 0, 255)
					h, s, v = Color3.fromRGB(oR, oG, oB):ToHSV()
					setDisplay()
				else
					box.Text = tostring(save)
				end
				ColorPickerSettings.Color = Color3.fromHSV(h, s, v)
				if not ColorPickerSettings.Ext then SaveConfiguration() end
			end

			ColorPicker.RGB.RInput.InputBox.FocusLost:Connect(function()
				rgbBoxes(ColorPicker.RGB.RInput.InputBox, "R")
				pcall(ColorPickerSettings.Callback, Color3.fromHSV(h, s, v))
			end)
			ColorPicker.RGB.GInput.InputBox.FocusLost:Connect(function()
				rgbBoxes(ColorPicker.RGB.GInput.InputBox, "G")
				pcall(ColorPickerSettings.Callback, Color3.fromHSV(h, s, v))
			end)
			ColorPicker.RGB.BInput.InputBox.FocusLost:Connect(function()
				rgbBoxes(ColorPicker.RGB.BInput.InputBox, "B")
				pcall(ColorPickerSettings.Callback, Color3.fromHSV(h, s, v))
			end)

			-- Optimized: only run logic when actually dragging
			local cpRenderConn = RunService.RenderStepped:Connect(function()
				if not mainDragging and not sliderDragging then return end  -- early exit when idle

				if mainDragging then
					local localX = math.clamp(mouse.X - MainCP.AbsolutePosition.X, 0, MainCP.AbsoluteSize.X)
					local localY = math.clamp(mouse.Y - MainCP.AbsolutePosition.Y, 0, MainCP.AbsoluteSize.Y)
					MainCP.MainPoint.Position = UDim2.new(0, localX - MainCP.MainPoint.AbsoluteSize.X/2, 0, localY - MainCP.MainPoint.AbsoluteSize.Y/2)
					s = localX / MainCP.AbsoluteSize.X
					v = 1 - (localY / MainCP.AbsoluteSize.Y)
					Display.BackgroundColor3      = Color3.fromHSV(h, s, v)
					MainCP.MainPoint.ImageColor3  = Color3.fromHSV(h, s, v)
					Background.BackgroundColor3   = Color3.fromHSV(h, 1, 1)
					local c = Color3.fromHSV(h, s, v)
					local r, g, b = math.floor(c.R*255+0.5), math.floor(c.G*255+0.5), math.floor(c.B*255+0.5)
					ColorPicker.RGB.RInput.InputBox.Text = tostring(r)
					ColorPicker.RGB.GInput.InputBox.Text = tostring(g)
					ColorPicker.RGB.BInput.InputBox.Text = tostring(b)
					ColorPicker.HexInput.InputBox.Text   = string.format("#%02X%02X%02X", c.R*0xFF, c.G*0xFF, c.B*0xFF)
					pcall(ColorPickerSettings.Callback, c)
					ColorPickerSettings.Color = c
					if not ColorPickerSettings.Ext then SaveConfiguration() end
				end

				if sliderDragging then
					local localX = math.clamp(mouse.X - Slider.AbsolutePosition.X, 0, Slider.AbsoluteSize.X)
					h = localX / Slider.AbsoluteSize.X
					Display.BackgroundColor3 = Color3.fromHSV(h, s, v)
					Slider.SliderPoint.Position    = UDim2.new(0, localX - Slider.SliderPoint.AbsoluteSize.X/2, 0.5, 0)
					Slider.SliderPoint.ImageColor3 = Color3.fromHSV(h, 1, 1)
					Background.BackgroundColor3    = Color3.fromHSV(h, 1, 1)
					MainCP.MainPoint.ImageColor3   = Color3.fromHSV(h, s, v)
					local c = Color3.fromHSV(h, s, v)
					local r, g, b = math.floor(c.R*255+0.5), math.floor(c.G*255+0.5), math.floor(c.B*255+0.5)
					ColorPicker.RGB.RInput.InputBox.Text = tostring(r)
					ColorPicker.RGB.GInput.InputBox.Text = tostring(g)
					ColorPicker.RGB.BInput.InputBox.Text = tostring(b)
					ColorPicker.HexInput.InputBox.Text   = string.format("#%02X%02X%02X", c.R*0xFF, c.G*0xFF, c.B*0xFF)
					pcall(ColorPickerSettings.Callback, c)
					ColorPickerSettings.Color = c
					if not ColorPickerSettings.Ext then SaveConfiguration() end
				end
			end)

			ColorPicker.Destroying:Connect(function()
				if cpRenderConn then cpRenderConn:Disconnect() end
				if cpInputConn  then cpInputConn:Disconnect()  end
			end)

			registerFlag(Settings, ColorPickerSettings)

			function ColorPickerSettings:Set(RGBColor)
				ColorPickerSettings.Color = RGBColor
				h, s, v = ColorPickerSettings.Color:ToHSV()
				colorVal = Color3.fromHSV(h, s, v)
				setDisplay()
			end

			function ColorPickerSettings:SetVisible(state)
				ColorPicker.Visible = state
			end

			ColorPicker.MouseEnter:Connect(function()
				tween(ColorPicker, TI_NORMAL, {BackgroundColor3 = SelectedTheme.ElementBackgroundHover})
			end)
			ColorPicker.MouseLeave:Connect(function()
				tween(ColorPicker, TI_NORMAL, {BackgroundColor3 = SelectedTheme.ElementBackground})
			end)

			onThemeChange(function()
				for _, rgbinput in ipairs(ColorPicker.RGB:GetChildren()) do
					if rgbinput:IsA("Frame") then
						rgbinput.BackgroundColor3 = SelectedTheme.InputBackground
						rgbinput.UIStroke.Color   = SelectedTheme.InputStroke
					end
				end
				ColorPicker.HexInput.BackgroundColor3 = SelectedTheme.InputBackground
				ColorPicker.HexInput.UIStroke.Color   = SelectedTheme.InputStroke
			end)

			return ColorPickerSettings
		end

		-- ───────────────────────────────────────────────────────────────
		-- SECTION
		-- ───────────────────────────────────────────────────────────────
		function Tab:CreateSection(SectionName)
			local SectionValue = {}
			if SDone then
				local SectionSpace = Elements.Template.SectionSpacing:Clone()
				SectionSpace.Visible = true
				SectionSpace.Parent  = TabPage
			end
			local Section = Elements.Template.SectionTitle:Clone()
			Section.Title.Text = SectionName
			Section.Visible    = true
			Section.Parent     = TabPage
			Section.Title.TextTransparency = 1
			tween(Section.Title, TI_SLOW, {TextTransparency = 0.4})
			function SectionValue:Set(NewSection)
				Section.Title.Text = NewSection
			end
			SDone = true
			return SectionValue
		end

		-- ───────────────────────────────────────────────────────────────
		-- DIVIDER
		-- ───────────────────────────────────────────────────────────────
		function Tab:CreateDivider()
			local DividerValue = {}
			local Divider = Elements.Template.Divider:Clone()
			Divider.Visible = true
			Divider.Parent  = TabPage
			Divider.Divider.BackgroundTransparency = 1
			tween(Divider.Divider, TI_NORMAL, {BackgroundTransparency = 0.85})
			function DividerValue:Set(Value)
				Divider.Visible = Value
			end
			return DividerValue
		end

		-- ───────────────────────────────────────────────────────────────
		-- LABEL
		-- ───────────────────────────────────────────────────────────────
		function Tab:CreateLabel(LabelText: string, Icon: number, Color: Color3, IgnoreTheme: boolean)
			local LabelValue = {}
			local Label = Elements.Template.Label:Clone()
			Label.Title.Text = LabelText
			Label.Visible    = true
			Label.Parent     = TabPage
			Label.BackgroundColor3 = Color or SelectedTheme.SecondaryElementBackground
			Label.UIStroke.Color   = Color or SelectedTheme.SecondaryElementStroke

			if Icon then
				local img, rectOffset, rectSize = resolveIcon(Icon)
				Label.Icon.Image = img
				if rectOffset then Label.Icon.ImageRectOffset = rectOffset end
				if rectSize   then Label.Icon.ImageRectSize   = rectSize   end
			else
				Label.Icon.Image = ""
			end

			if Icon and Label:FindFirstChild('Icon') then
				Label.Title.Position = UDim2.new(0, 45, 0.5, 0)
				Label.Title.Size     = UDim2.new(1, -100, 0, 14)
				Label.Icon.Visible   = true
			end

			Label.Icon.ImageTransparency = 1
			Label.BackgroundTransparency = 1
			Label.UIStroke.Transparency  = 1
			Label.Title.TextTransparency = 1

			Label:SetAttribute("BackgroundTransparencyTarget", Color and 0.8 or 0)
			Label:SetAttribute("UIStrokeTransparencyTarget",   Color and 0.7 or 0)
			Label:SetAttribute("TitleTextTransparencyTarget",  Color and 0.2 or 0)

			tween(Label,          TI_SLOW, {BackgroundTransparency = Color and 0.8 or 0})
			tween(Label.UIStroke, TI_SLOW, {Transparency = Color and 0.7 or 0})
			tween(Label.Icon,     TI_SLOW, {ImageTransparency = 0.2})
			tween(Label.Title,    TI_SLOW, {TextTransparency = Color and 0.2 or 0})

			function LabelValue:Set(NewLabel, NewIcon, NewColor)
				Label.Title.Text = NewLabel
				if NewColor then
					Label.BackgroundColor3 = NewColor
					Label.UIStroke.Color   = NewColor
				end
				if NewIcon and Label:FindFirstChild('Icon') then
					Label.Title.Position = UDim2.new(0, 45, 0.5, 0)
					Label.Title.Size     = UDim2.new(1, -100, 0, 14)
					local img, rectOffset, rectSize = resolveIcon(NewIcon)
					Label.Icon.Image = img
					if rectOffset then Label.Icon.ImageRectOffset = rectOffset end
					if rectSize   then Label.Icon.ImageRectSize   = rectSize   end
					Label.Icon.Visible = true
				end
			end

			function LabelValue:SetVisible(state)
				Label.Visible = state
			end

			onThemeChange(function()
				Label.BackgroundColor3 = IgnoreTheme and (Color or Label.BackgroundColor3) or SelectedTheme.SecondaryElementBackground
				Label.UIStroke.Color   = IgnoreTheme and (Color or Label.BackgroundColor3) or SelectedTheme.SecondaryElementStroke
			end)

			return LabelValue
		end

		-- ───────────────────────────────────────────────────────────────
		-- PARAGRAPH
		-- ───────────────────────────────────────────────────────────────
		function Tab:CreateParagraph(ParagraphSettings)
			local ParagraphValue = {}
			local Paragraph = Elements.Template.Paragraph:Clone()
			Paragraph.Title.Text   = ParagraphSettings.Title
			Paragraph.Content.Text = ParagraphSettings.Content
			Paragraph.Visible      = true
			Paragraph.Parent       = TabPage
			Paragraph.BackgroundTransparency = 1
			Paragraph.UIStroke.Transparency  = 1
			Paragraph.Title.TextTransparency = 1
			Paragraph.Content.TextTransparency = 1
			Paragraph.BackgroundColor3 = SelectedTheme.SecondaryElementBackground
			Paragraph.UIStroke.Color   = SelectedTheme.SecondaryElementStroke
			tween(Paragraph,         TI_SLOW, {BackgroundTransparency = 0})
			tween(Paragraph.UIStroke,TI_SLOW, {Transparency = 0})
			tween(Paragraph.Title,   TI_SLOW, {TextTransparency = 0})
			tween(Paragraph.Content, TI_SLOW, {TextTransparency = 0})
			function ParagraphValue:Set(NewSettings)
				Paragraph.Title.Text   = NewSettings.Title
				Paragraph.Content.Text = NewSettings.Content
			end
			function ParagraphValue:SetVisible(state)
				Paragraph.Visible = state
			end
			onThemeChange(function()
				Paragraph.BackgroundColor3 = SelectedTheme.SecondaryElementBackground
				Paragraph.UIStroke.Color   = SelectedTheme.SecondaryElementStroke
			end)
			return ParagraphValue
		end

		-- ═══════════════════════════════════════════════════════════════
		--  NEW ELEMENT: PROGRESS BAR
		-- ═══════════════════════════════════════════════════════════════
		function Tab:CreateProgressBar(ProgressSettings)
			-- ProgressSettings = { Name, Progress (0-1), Color, Description }
			local ProgressValue = {}

			local Container = Instance.new("Frame")
			Container.Name                = ProgressSettings.Name
			Container.Size                = UDim2.new(1, -10, 0, ELEMENT_HEIGHT)
			Container.BackgroundColor3    = SelectedTheme.ElementBackground
			Container.BorderSizePixel     = 0
			Container.BackgroundTransparency = 1
			Container.Parent              = TabPage

			local cornerC = Instance.new("UICorner")
			cornerC.CornerRadius = UDim.new(0, 6)
			cornerC.Parent       = Container

			local strokeC = Instance.new("UIStroke")
			strokeC.Color        = SelectedTheme.ElementStroke
			strokeC.Thickness    = 1
			strokeC.Transparency = 1
			strokeC.Parent       = Container

			local TitleLabel = Instance.new("TextLabel")
			TitleLabel.Name               = "Title"
			TitleLabel.Text               = ProgressSettings.Name
			TitleLabel.TextColor3         = SelectedTheme.TextColor
			TitleLabel.TextTransparency   = 1
			TitleLabel.Font               = Enum.Font.GothamBold
			TitleLabel.TextSize           = 13
			TitleLabel.Size               = UDim2.new(1, -110, 0, 14)
			TitleLabel.Position           = UDim2.new(0, 12, 0, 8)
			TitleLabel.BackgroundTransparency = 1
			TitleLabel.TextXAlignment     = Enum.TextXAlignment.Left
			TitleLabel.ZIndex             = 2
			TitleLabel.Parent             = Container

			local PctLabel = Instance.new("TextLabel")
			PctLabel.Name               = "Percent"
			PctLabel.TextColor3         = SelectedTheme.TextColor
			PctLabel.TextTransparency   = 0.4
			PctLabel.Font               = Enum.Font.GothamMedium
			PctLabel.TextSize           = 11
			PctLabel.Size               = UDim2.new(0, 40, 0, 14)
			PctLabel.Position           = UDim2.new(1, -50, 0, 8)
			PctLabel.BackgroundTransparency = 1
			PctLabel.TextXAlignment     = Enum.TextXAlignment.Right
			PctLabel.ZIndex             = 2
			PctLabel.Parent             = Container

			local BarBG = Instance.new("Frame")
			BarBG.Name                  = "BarBackground"
			BarBG.Size                  = UDim2.new(1, -24, 0, 8)
			BarBG.Position              = UDim2.new(0, 12, 0, 28)
			BarBG.BackgroundColor3      = SelectedTheme.SecondaryElementBackground
			BarBG.BorderSizePixel       = 0
			BarBG.ZIndex                = 2
			BarBG.Parent                = Container

			local cornerBG = Instance.new("UICorner")
			cornerBG.CornerRadius = UDim.new(1, 0)
			cornerBG.Parent       = BarBG

			local accentColor = ProgressSettings.Color or SelectedTheme.SliderProgress
			local BarFill = Instance.new("Frame")
			BarFill.Name              = "Fill"
			BarFill.Size              = UDim2.new(math.clamp(ProgressSettings.Progress or 0, 0, 1), 0, 1, 0)
			BarFill.BackgroundColor3  = accentColor
			BarFill.BorderSizePixel   = 0
			BarFill.ZIndex            = 3
			BarFill.Parent            = BarBG

			local cornerFill = Instance.new("UICorner")
			cornerFill.CornerRadius = UDim.new(1, 0)
			cornerFill.Parent       = BarFill

			local gradient = Instance.new("UIGradient")
			gradient.Color    = ColorSequence.new({
				ColorSequenceKeypoint.new(0, Color3.fromHSV(0, 0, 1.0)),
				ColorSequenceKeypoint.new(1, Color3.fromHSV(0, 0, 0.8)),
			})
			gradient.Rotation = 0
			gradient.Parent   = BarFill

			local currentProgress = math.clamp(ProgressSettings.Progress or 0, 0, 1)
			PctLabel.Text = math.floor(currentProgress * 100) .. "%"

			tween(Container, TI_SLOW, {BackgroundTransparency = 0})
			tween(strokeC,   TI_SLOW, {Transparency = 0})
			tween(TitleLabel,TI_SLOW, {TextTransparency = 0})

			function ProgressValue:Set(newProgress)
				currentProgress = math.clamp(newProgress, 0, 1)
				tween(BarFill, TI_NORMAL, {Size = UDim2.new(currentProgress, 0, 1, 0)})
				PctLabel.Text = math.floor(currentProgress * 100) .. "%"
			end

			function ProgressValue:SetColor(newColor)
				accentColor = newColor
				BarFill.BackgroundColor3 = newColor
			end

			function ProgressValue:SetVisible(state)
				Container.Visible = state
			end

			onThemeChange(function()
				Container.BackgroundColor3 = SelectedTheme.ElementBackground
				strokeC.Color              = SelectedTheme.ElementStroke
				TitleLabel.TextColor3      = SelectedTheme.TextColor
				PctLabel.TextColor3        = SelectedTheme.TextColor
				BarBG.BackgroundColor3     = SelectedTheme.SecondaryElementBackground
			end)

			return ProgressValue
		end

		-- ═══════════════════════════════════════════════════════════════
		--  NEW ELEMENT: SEPARATOR (thin line with optional text label)
		-- ═══════════════════════════════════════════════════════════════
		function Tab:CreateSeparator(labelText: string?)
			local SepValue = {}
			local Sep = Instance.new("Frame")
			Sep.Name              = "Separator"
			Sep.Size              = UDim2.new(1, -10, 0, 20)
			Sep.BackgroundTransparency = 1
			Sep.BorderSizePixel   = 0
			Sep.Parent            = TabPage

			local line = Instance.new("Frame")
			line.Size              = UDim2.new(1, -24, 0, 1)
			line.Position          = UDim2.new(0, 12, 0.5, 0)
			line.BackgroundColor3  = SelectedTheme.ElementStroke
			line.BackgroundTransparency = 0.5
			line.BorderSizePixel   = 0
			line.Parent            = Sep

			local cornerLine = Instance.new("UICorner")
			cornerLine.CornerRadius = UDim.new(1, 0)
			cornerLine.Parent       = line

			if labelText and #labelText > 0 then
				line.Size     = UDim2.new(0.35, 0, 0, 1)
				line.Position = UDim2.new(0, 12, 0.5, 0)

				local line2   = line:Clone()
				line2.Position = UDim2.new(0.65, -12, 0.5, 0)
				line2.Parent   = Sep

				local lbl = Instance.new("TextLabel")
				lbl.Size                 = UDim2.new(0.3, 0, 1, 0)
				lbl.Position             = UDim2.new(0.35, 0, 0, 0)
				lbl.Text                 = labelText
				lbl.TextColor3           = SelectedTheme.TextColor
				lbl.TextTransparency     = 0.4
				lbl.Font                 = Enum.Font.GothamMedium
				lbl.TextSize             = 11
				lbl.BackgroundTransparency = 1
				lbl.Parent               = Sep

				onThemeChange(function()
					line.BackgroundColor3  = SelectedTheme.ElementStroke
					line2.BackgroundColor3 = SelectedTheme.ElementStroke
					lbl.TextColor3         = SelectedTheme.TextColor
				end)
			else
				onThemeChange(function()
					line.BackgroundColor3 = SelectedTheme.ElementStroke
				end)
			end

			function SepValue:SetVisible(state)
				Sep.Visible = state
			end

			return SepValue
		end

		-- ═══════════════════════════════════════════════════════════════
		--  NEW ELEMENT: INFO CARD (icon + title + description + optional button)
		-- ═══════════════════════════════════════════════════════════════
		function Tab:CreateInfoCard(CardSettings)
			-- CardSettings = { Title, Description, Icon, Color, ButtonText, Callback }
			local CardValue = {}

			local cardHeight = CardSettings.ButtonText and 80 or 65
			local Card = Instance.new("Frame")
			Card.Name              = CardSettings.Title
			Card.Size              = UDim2.new(1, -10, 0, cardHeight)
			Card.BackgroundColor3  = SelectedTheme.SecondaryElementBackground
			Card.BorderSizePixel   = 0
			Card.BackgroundTransparency = 1
			Card.Parent            = TabPage

			local cornerCard = Instance.new("UICorner")
			cornerCard.CornerRadius = UDim.new(0, 8)
			cornerCard.Parent       = Card

			local strokeCard = Instance.new("UIStroke")
			strokeCard.Color        = CardSettings.Color or SelectedTheme.SecondaryElementStroke
			strokeCard.Thickness    = 1
			strokeCard.Transparency = 1
			strokeCard.Parent       = Card

			-- Accent strip on left
			local strip = Instance.new("Frame")
			strip.Size             = UDim2.new(0, 3, 1, -16)
			strip.Position         = UDim2.new(0, 8, 0, 8)
			strip.BackgroundColor3 = CardSettings.Color or SelectedTheme.SliderProgress
			strip.BorderSizePixel  = 0
			strip.Parent           = Card
			Instance.new("UICorner", strip).CornerRadius = UDim.new(1, 0)

			local titleX = 20
			if CardSettings.Icon then
				local iconLbl = Instance.new("ImageLabel")
				iconLbl.Size              = UDim2.new(0, 22, 0, 22)
				iconLbl.Position          = UDim2.new(0, 18, 0, 10)
				iconLbl.BackgroundTransparency = 1
				iconLbl.ImageColor3       = CardSettings.Color or SelectedTheme.TextColor
				local img, rectOffset, rectSize = resolveIcon(CardSettings.Icon)
				iconLbl.Image = img
				if rectOffset then iconLbl.ImageRectOffset = rectOffset end
				if rectSize   then iconLbl.ImageRectSize   = rectSize   end
				iconLbl.Parent = Card
				titleX = 46
			end

			local cardTitle = Instance.new("TextLabel")
			cardTitle.Text              = CardSettings.Title
			cardTitle.TextColor3        = SelectedTheme.TextColor
			cardTitle.TextTransparency  = 0
			cardTitle.Font              = Enum.Font.GothamBold
			cardTitle.TextSize          = 13
			cardTitle.Size              = UDim2.new(1, -titleX - 12, 0, 16)
			cardTitle.Position          = UDim2.new(0, titleX, 0, 10)
			cardTitle.BackgroundTransparency = 1
			cardTitle.TextXAlignment    = Enum.TextXAlignment.Left
			cardTitle.Parent            = Card

			local cardDesc = Instance.new("TextLabel")
			cardDesc.Text              = CardSettings.Description or ""
			cardDesc.TextColor3        = SelectedTheme.TextColor
			cardDesc.TextTransparency  = 0.3
			cardDesc.Font              = Enum.Font.Gotham
			cardDesc.TextSize          = 11
			cardDesc.Size              = UDim2.new(1, -titleX - 12, 0, 28)
			cardDesc.Position          = UDim2.new(0, titleX, 0, 26)
			cardDesc.BackgroundTransparency = 1
			cardDesc.TextXAlignment    = Enum.TextXAlignment.Left
			cardDesc.TextWrapped       = true
			cardDesc.Parent            = Card

			if CardSettings.ButtonText and type(CardSettings.Callback) == "function" then
				local btn = Instance.new("TextButton")
				btn.Text              = CardSettings.ButtonText
				btn.TextColor3        = CardSettings.Color or SelectedTheme.TextColor
				btn.Font              = Enum.Font.GothamBold
				btn.TextSize          = 11
				btn.Size              = UDim2.new(0, 80, 0, 22)
				btn.Position          = UDim2.new(1, -90, 1, -28)
				btn.BackgroundColor3  = CardSettings.Color or SelectedTheme.SliderProgress
				btn.BackgroundTransparency = 0.8
				btn.BorderSizePixel   = 0
				btn.AutoButtonColor   = false
				btn.Parent            = Card
				Instance.new("UICorner", btn).CornerRadius = UDim.new(0, 4)

				btn.MouseButton1Click:Connect(function()
					tween(btn, TI_FAST, {BackgroundTransparency = 0.5})
					task.wait(0.15)
					tween(btn, TI_FAST, {BackgroundTransparency = 0.8})
					pcall(CardSettings.Callback)
				end)
				btn.MouseEnter:Connect(function() tween(btn, TI_FAST, {BackgroundTransparency = 0.6}) end)
				btn.MouseLeave:Connect(function() tween(btn, TI_FAST, {BackgroundTransparency = 0.8}) end)
			end

			tween(Card,       TI_SLOW, {BackgroundTransparency = 0})
			tween(strokeCard, TI_SLOW, {Transparency = 0})

			function CardValue:SetVisible(state)
				Card.Visible = state
			end

			onThemeChange(function()
				Card.BackgroundColor3  = SelectedTheme.SecondaryElementBackground
				if not CardSettings.Color then
					strokeCard.Color = SelectedTheme.SecondaryElementStroke
				end
				cardTitle.TextColor3 = SelectedTheme.TextColor
				cardDesc.TextColor3  = SelectedTheme.TextColor
			end)

			return CardValue
		end

		-- ═══════════════════════════════════════════════════════════════
		--  NEW ELEMENT: NUMBER STEPPER
		-- ═══════════════════════════════════════════════════════════════
		function Tab:CreateNumberStepper(StepperSettings)
			-- StepperSettings = { Name, Value, Min, Max, Step, Callback, Flag }
			local StepperValue = {}
			local current = math.clamp(StepperSettings.Value or 0, StepperSettings.Min or 0, StepperSettings.Max or 100)

			local Container = Instance.new("Frame")
			Container.Name              = StepperSettings.Name
			Container.Size              = UDim2.new(1, -10, 0, ELEMENT_HEIGHT)
			Container.BackgroundColor3  = SelectedTheme.ElementBackground
			Container.BorderSizePixel   = 0
			Container.BackgroundTransparency = 1
			Container.Parent            = TabPage

			local cornerSt = Instance.new("UICorner")
			cornerSt.CornerRadius = UDim.new(0, 6)
			cornerSt.Parent       = Container

			local strokeSt = Instance.new("UIStroke")
			strokeSt.Color        = SelectedTheme.ElementStroke
			strokeSt.Thickness    = 1
			strokeSt.Transparency = 1
			strokeSt.Parent       = Container

			local NameLabel = Instance.new("TextLabel")
			NameLabel.Name              = "Title"
			NameLabel.Text              = StepperSettings.Name
			NameLabel.TextColor3        = SelectedTheme.TextColor
			NameLabel.TextTransparency  = 1
			NameLabel.Font              = Enum.Font.GothamBold
			NameLabel.TextSize          = 13
			NameLabel.Size              = UDim2.new(1, -160, 1, 0)
			NameLabel.Position          = UDim2.new(0, 12, 0, 0)
			NameLabel.BackgroundTransparency = 1
			NameLabel.TextXAlignment    = Enum.TextXAlignment.Left
			NameLabel.Parent            = Container

			local function makeStepBtn(labelText, xPos)
				local btn = Instance.new("TextButton")
				btn.Text              = labelText
				btn.TextColor3        = SelectedTheme.TextColor
				btn.Font              = Enum.Font.GothamBold
				btn.TextSize          = 16
				btn.Size              = UDim2.new(0, 28, 0, 28)
				btn.Position          = UDim2.new(1, xPos, 0.5, -14)
				btn.BackgroundColor3  = SelectedTheme.InputBackground
				btn.BorderSizePixel   = 0
				btn.AutoButtonColor   = false
				btn.Parent            = Container
				Instance.new("UICorner", btn).CornerRadius = UDim.new(0, 6)
				local s = Instance.new("UIStroke")
				s.Color     = SelectedTheme.InputStroke
				s.Thickness = 1
				s.Parent    = btn
				return btn
			end

			local decreaseBtn = makeStepBtn("−", -130)
			local increaseBtn = makeStepBtn("+", -98)

			local ValueLabel = Instance.new("TextLabel")
			ValueLabel.Text             = tostring(current)
			ValueLabel.TextColor3       = SelectedTheme.TextColor
			ValueLabel.Font             = Enum.Font.GothamBold
			ValueLabel.TextSize         = 13
			ValueLabel.Size             = UDim2.new(0, 52, 1, 0)
			ValueLabel.Position         = UDim2.new(1, -94, 0, 0)
			ValueLabel.BackgroundTransparency = 1
			ValueLabel.TextXAlignment   = Enum.TextXAlignment.Center
			ValueLabel.Parent           = Container

			local function updateValue(newVal)
				local step = StepperSettings.Step or 1
				newVal = math.clamp(math.floor(newVal / step + 0.5) * step, StepperSettings.Min or 0, StepperSettings.Max or 100)
				if newVal == current then return end
				current = newVal
				ValueLabel.Text = tostring(current)
				StepperSettings.Value = current
				local success = safeCallback(StepperSettings.Callback, Container, StepperSettings.Name, current)
				if success and not StepperSettings.Ext then
					if not StepperSettings.Flag then
						StepperSettings.CurrentValue = current
					end
					SaveConfiguration()
				end
			end

			decreaseBtn.MouseButton1Click:Connect(function()
				tween(decreaseBtn, TI_FAST, {BackgroundColor3 = SelectedTheme.ElementBackgroundHover})
				task.wait(0.1)
				tween(decreaseBtn, TI_FAST, {BackgroundColor3 = SelectedTheme.InputBackground})
				updateValue(current - (StepperSettings.Step or 1))
			end)
			increaseBtn.MouseButton1Click:Connect(function()
				tween(increaseBtn, TI_FAST, {BackgroundColor3 = SelectedTheme.ElementBackgroundHover})
				task.wait(0.1)
				tween(increaseBtn, TI_FAST, {BackgroundColor3 = SelectedTheme.InputBackground})
				updateValue(current + (StepperSettings.Step or 1))
			end)

			addHoverEffect(Container)

			tween(Container, TI_SLOW, {BackgroundTransparency = 0})
			tween(strokeSt,  TI_SLOW, {Transparency = 0})
			tween(NameLabel, TI_SLOW, {TextTransparency = 0})

			-- Support for config saving via Flag
			StepperSettings.CurrentValue = current
			registerFlag(Settings, StepperSettings)

			function StepperValue:Set(newVal)
				updateValue(newVal)
			end

			function StepperValue:SetVisible(state)
				Container.Visible = state
			end

			onThemeChange(function()
				Container.BackgroundColor3 = SelectedTheme.ElementBackground
				strokeSt.Color             = SelectedTheme.ElementStroke
				NameLabel.TextColor3       = SelectedTheme.TextColor
				ValueLabel.TextColor3      = SelectedTheme.TextColor
				for _, btn in ipairs({decreaseBtn, increaseBtn}) do
					btn.BackgroundColor3   = SelectedTheme.InputBackground
					btn.TextColor3         = SelectedTheme.TextColor
					btn:FindFirstChildWhichIsA("UIStroke").Color = SelectedTheme.InputStroke
				end
			end)

			return StepperValue
		end

		return Tab
	end -- Window:CreateTab

	-- ═══════════════════════════════════════════════════════════════════
	--  LOADING ANIMATION COMPLETION
	-- ═══════════════════════════════════════════════════════════════════

	Elements.Visible = true

	task.wait(1.1)
	tween(Main, TweenInfo.new(0.7, Enum.EasingStyle.Exponential, Enum.EasingDirection.InOut),
		{Size = UDim2.new(0, 390, 0, 90)})
	task.wait(0.3)
	tween(LoadingFrame.Title,    TI_INSTANT, {TextTransparency = 1})
	tween(LoadingFrame.Subtitle, TI_INSTANT, {TextTransparency = 1})
	tween(LoadingFrame.Version,  TI_INSTANT, {TextTransparency = 1})
	task.wait(0.1)
	tween(Main, TweenInfo.new(0.6, Enum.EasingStyle.Exponential, Enum.EasingDirection.Out),
		{Size = useMobileSizing and UDim2.new(0, WINDOW_WIDTH, 0, WINDOW_HEIGHT_MOBILE) or UDim2.new(0, WINDOW_WIDTH, 0, WINDOW_HEIGHT)})
	tween(Main.Shadow.Image, TI_NORMAL, {ImageTransparency = TRANS_SHADOW})

	-- Topbar entrance animation
	Topbar.BackgroundTransparency   = 1
	Topbar.Divider.Size             = UDim2.new(0, 0, 0, 1)
	Topbar.Divider.BackgroundColor3 = SelectedTheme.ElementStroke
	Topbar.CornerRepair.BackgroundTransparency = 1
	Topbar.Title.TextTransparency   = 1
	Topbar.Search.ImageTransparency = 1
	if Topbar:FindFirstChild('Settings') then
		Topbar.Settings.ImageTransparency = 1
	end
	Topbar.ChangeSize.ImageTransparency = 1
	Topbar.Hide.ImageTransparency       = 1

	task.wait(ANIM_NORMAL)
	Topbar.Visible = true
	tween(Topbar,             TI_SLOW, {BackgroundTransparency = 0})
	tween(Topbar.CornerRepair,TI_SLOW, {BackgroundTransparency = 0})
	task.wait(0.1)
	tween(Topbar.Divider, TweenInfo.new(1, Enum.EasingStyle.Exponential), {Size = UDim2.new(1, 0, 0, 1)})
	tween(Topbar.Title,   TI_NORMAL, {TextTransparency = 0})
	task.wait(0.05)
	tween(Topbar.Search,  TI_NORMAL, {ImageTransparency = TRANS_TOPBAR_IDLE})
	task.wait(0.05)
	if Topbar:FindFirstChild('Settings') then
		tween(Topbar.Settings, TI_NORMAL, {ImageTransparency = TRANS_TOPBAR_IDLE})
		task.wait(0.05)
	end
	tween(Topbar.ChangeSize, TI_NORMAL, {ImageTransparency = TRANS_TOPBAR_IDLE})
	task.wait(0.05)
	tween(Topbar.Hide, TI_NORMAL, {ImageTransparency = TRANS_TOPBAR_IDLE})
	task.wait(0.3)

	if dragBar then
		tween(dragBarCosmetic, TI_NORMAL, {BackgroundTransparency = TRANS_TAB_UNSELECTED})
	end

	-- Theme modifier
	function Window.ModifyTheme(NewTheme)
		local success = pcall(ChangeTheme, NewTheme)
		if not success then
			RayfieldLibrary:Notify({Title = 'Unable to Change Theme', Content = 'Could not find a theme with that name.', Image = 4400704299, Type = "error"})
		else
			RayfieldLibrary:Notify({Title = 'Theme Changed', Content = 'Successfully changed theme to ' .. (typeof(NewTheme) == 'string' and NewTheme or 'Custom Theme') .. '.', Image = 4483362748, Type = "success"})
		end
	end

	-- Create settings tab
	local ok, settingsErr = pcall(createSettings, Window)
	if not ok then warn('Rayfield had an issue creating settings: ' .. tostring(settingsErr)) end

	-- Analytics
	if reporter and getSetting("System", "usageAnalytics") then
		local themeName = "Default"
		if Settings.Theme then
			themeName = type(Settings.Theme) == "string" and Settings.Theme or "Custom"
		end

		local discordInvite = nil
		if Settings.Discord and Settings.Discord.Enabled and Settings.Discord.Invite and Settings.Discord.Invite ~= "" then
			local raw = tostring(Settings.Discord.Invite)
			discordInvite = (raw:match("discord%.gg/([%w%-]+)") or raw:match("discord%.com/invite/([%w%-]+)") or raw):sub(1, 32)
		end

		local sampleSend = not Settings.ScriptID and math.random() > 0.4

		reporter:windowCreated({
			script_name       = Settings.Name or "Unknown",
			script_version    = Release,
			interface_version = InterfaceBuild,
			theme             = themeName,
			is_mobile         = useMobileSizing and true or false,
			has_key_system    = Settings.KeySystem and true or false,
			discord_invite    = discordInvite,
			config_saving     = (Settings.ConfigurationSaving and Settings.ConfigurationSaving.Enabled) and true or false,
			script_id         = Settings.ScriptID or (sampleSend and 'sid_tzfyxawonjx9') or nil,
			verification_token = Settings.VerificationToken,
		})
	end

	return Window
end -- CreateWindow

-- ═══════════════════════════════════════════════════════════════════════════
--  PROFILE SYSTEM
-- ═══════════════════════════════════════════════════════════════════════════

function RayfieldLibrary:SaveProfile(profileName: string)
	if not profileName or profileName == "" then
		warn("Rayfield | SaveProfile requires a profile name")
		return false
	end
	ensureFolder(ProfilesFolder)
	local Data = {}
	for i, v in pairs(RayfieldLibrary.Flags) do
		if v.Type == "ColorPicker" then
			Data[i] = PackColor(v.Color)
		else
			if typeof(v.CurrentValue) == 'boolean' then
				Data[i] = v.CurrentValue
			else
				Data[i] = v.CurrentValue or v.CurrentKeybind or v.CurrentOption or v.Color
			end
		end
	end
	local ok = callSafely(writefile, ProfilesFolder .. "/" .. profileName .. ConfigurationExtension, HttpService:JSONEncode(Data))
	if ok then
		RayfieldLibrary:Notify({Title = "Profile Saved", Content = 'Profile "' .. profileName .. '" saved successfully.', Type = "success"})
	end
	return ok ~= false
end

function RayfieldLibrary:LoadProfile(profileName: string)
	if not profileName or profileName == "" then
		warn("Rayfield | LoadProfile requires a profile name")
		return false
	end
	local path = ProfilesFolder .. "/" .. profileName .. ConfigurationExtension
	if not callSafely(isfile, path) then
		RayfieldLibrary:Notify({Title = "Profile Not Found", Content = 'Profile "' .. profileName .. '" does not exist.', Type = "error"})
		return false
	end
	local data = callSafely(readfile, path)
	if data then
		local changed = LoadConfiguration(data)
		RayfieldLibrary:Notify({Title = "Profile Loaded", Content = 'Profile "' .. profileName .. '" loaded' .. (changed and " with changes." or "."), Type = "success"})
		return true
	end
	return false
end

function RayfieldLibrary:GetProfiles(): {string}
	local profiles = {}
	ensureFolder(ProfilesFolder)
	if listfiles then
		local ok, files = pcall(listfiles, ProfilesFolder)
		if ok then
			for _, file in ipairs(files) do
				local name = string.match(file, "([^/\\]+)" .. ConfigurationExtension .. "$")
				if name then table.insert(profiles, name) end
			end
		end
	end
	return profiles
end

function RayfieldLibrary:DeleteProfile(profileName: string): boolean
	local path = ProfilesFolder .. "/" .. profileName .. ConfigurationExtension
	if callSafely(isfile, path) then
		callSafely(delfile, path)
		RayfieldLibrary:Notify({Title = "Profile Deleted", Content = 'Profile "' .. profileName .. '" deleted.', Type = "info"})
		return true
	end
	return false
end

-- ═══════════════════════════════════════════════════════════════════════════
--  GLOBAL API
-- ═══════════════════════════════════════════════════════════════════════════

local function setVisibility(visibility: boolean, notify: boolean?)
	if Debounce then return end
	if visibility then
		Hidden = false
		Unhide()
	else
		Hidden = true
		Hide(notify)
	end
end

function RayfieldLibrary:SetVisibility(visibility: boolean)
	setVisibility(visibility, false)
end

function RayfieldLibrary:IsVisible(): boolean
	return not Hidden
end

local hideHotkeyConnection
function RayfieldLibrary:Destroy()
	rayfieldDestroyed = true
	if hideHotkeyConnection then hideHotkeyConnection:Disconnect() end
	for _, connection in keybindConnections do
		connection:Disconnect()
	end
	Rayfield:Destroy()
end

-- ═══════════════════════════════════════════════════════════════════════════
--  INPUT HANDLERS
-- ═══════════════════════════════════════════════════════════════════════════

Topbar.ChangeSize.MouseButton1Click:Connect(function()
	if Debounce then return end
	if Minimised then
		Minimised = false
		Maximise()
	else
		Minimised = true
		Minimise()
	end
end)

Main.Search.Input:GetPropertyChangedSignal('Text'):Connect(function()
	local query = Main.Search.Input.Text
	if #query > 0 then
		if not Elements.UIPageLayout.CurrentPage:FindFirstChild('SearchTitle-fsefsefesfsefesfesfThanks') then
			local searchTitle = Elements.Template.SectionTitle:Clone()
			searchTitle.Parent      = Elements.UIPageLayout.CurrentPage
			searchTitle.Name        = 'SearchTitle-fsefsefesfsefesfesfThanks'
			searchTitle.LayoutOrder = -100
			searchTitle.Title.Text  = 'Results from "' .. Elements.UIPageLayout.CurrentPage.Name .. '"'
			searchTitle.Visible     = true
		end
	else
		local searchTitle = Elements.UIPageLayout.CurrentPage:FindFirstChild('SearchTitle-fsefsefesfsefesfesfThanks')
		if searchTitle then searchTitle:Destroy() end
	end

	for _, element in ipairs(Elements.UIPageLayout.CurrentPage:GetChildren()) do
		if element.ClassName ~= 'UIListLayout' and element.Name ~= 'Placeholder'
			and element.Name ~= 'SearchTitle-fsefsefesfsefesfesfThanks'
		then
			if element.Name == 'SectionTitle' then
				element.Visible = #query == 0
			else
				element.Visible = #query == 0 or (string.lower(element.Name):find(string.lower(query), 1, true) ~= nil)
			end
		end
	end
end)

Main.Search.Input.FocusLost:Connect(function()
	if #Main.Search.Input.Text == 0 and searchOpen then
		task.wait(0.12)
		closeSearch()
	end
end)

Topbar.Search.MouseButton1Click:Connect(function()
	task.spawn(function()
		if searchOpen then closeSearch() else openSearch() end
	end)
end)

if Topbar:FindFirstChild('Settings') then
	Topbar.Settings.MouseButton1Click:Connect(function()
		task.spawn(function()
			for _, OtherTabButton in ipairs(TabList:GetChildren()) do
				if OtherTabButton.Name ~= "Template" and OtherTabButton.ClassName == "Frame" and OtherTabButton.Name ~= "Placeholder" then
					tween(OtherTabButton,         TI_SLOW, {BackgroundColor3 = SelectedTheme.TabBackground, BackgroundTransparency = TRANS_TAB_UNSELECTED})
					tween(OtherTabButton.Title,   TI_SLOW, {TextColor3 = SelectedTheme.TabTextColor, TextTransparency = TRANS_TAB_TEXT})
					tween(OtherTabButton.Image,   TI_SLOW, {ImageColor3 = SelectedTheme.TabTextColor, ImageTransparency = TRANS_TAB_TEXT})
					tween(OtherTabButton.UIStroke,TI_SLOW, {Transparency = TRANS_TAB_STROKE})
				end
			end
			Elements.UIPageLayout:JumpTo(Elements['Rayfield Settings'])
		end)
	end)
end

Topbar.Hide.MouseButton1Click:Connect(function()
	setVisibility(Hidden, not useMobileSizing)
end)

hideHotkeyConnection = UserInputService.InputBegan:Connect(function(input, processed)
	if processed then return end
	local keySetting = getSetting("General", "rayfieldOpen")
	if keySetting then
		local ok, keyEnum = pcall(function()
			return Enum.KeyCode[keySetting]
		end)
		if ok and input.KeyCode == keyEnum then
			if Debounce then return end
			if Hidden then
				Hidden = false
				Unhide()
			else
				Hidden = true
				Hide()
			end
		end
	end
end)

if MPrompt then
	MPrompt.Interact.MouseButton1Click:Connect(function()
		if Debounce then return end
		if Hidden then
			Hidden = false
			Unhide()
		end
	end)
end

for _, TopbarButton in ipairs(Topbar:GetChildren()) do
	if TopbarButton.ClassName == "ImageButton" and TopbarButton.Name ~= 'Icon' then
		TopbarButton.MouseEnter:Connect(function()
			tween(TopbarButton, TI_SLOW, {ImageTransparency = 0})
		end)
		TopbarButton.MouseLeave:Connect(function()
			tween(TopbarButton, TI_SLOW, {ImageTransparency = TRANS_TOPBAR_IDLE})
		end)
	end
end

-- ═══════════════════════════════════════════════════════════════════════════
--  CONFIGURATION LOADING (public)
-- ═══════════════════════════════════════════════════════════════════════════

function RayfieldLibrary:LoadConfiguration()
	local config
	if debugX then warn('Loading Configuration') end
	if useStudio then
		config = [[{"Toggle1adwawd":true,"Slider1dawd":100}]]
	end
	if CEnabled then
		local notified
		local loaded
		local success, result = pcall(function()
			if useStudio and config then
				loaded = LoadConfiguration(config)
				return
			end
			if isfile then
				if callSafely(isfile, ConfigurationFolder .. "/" .. CFileName .. ConfigurationExtension) then
					loaded = LoadConfiguration(callSafely(readfile, ConfigurationFolder .. "/" .. CFileName .. ConfigurationExtension))
				end
			else
				notified = true
				RayfieldLibrary:Notify({Title = "Rayfield Configurations", Content = "Couldn't enable Configuration Saving: your executor doesn't support filesystem access.", Image = 4384402990, Type = "warning"})
			end
		end)
		if success and loaded and not notified then
			RayfieldLibrary:Notify({Title = "Rayfield Configurations", Content = "Configuration file loaded from previous session.", Image = 4384403532, Type = "success"})
		elseif not success and not notified then
			warn('Rayfield Configurations Error | ' .. tostring(result))
			RayfieldLibrary:Notify({Title = "Rayfield Configurations", Content = "Issue loading configuration. Check the Developer Console for details.", Image = 4384402990, Type = "error"})
		end
	end
	globalLoaded = true
end

-- ═══════════════════════════════════════════════════════════════════════════
--  CONFIGURATION SAVING NOTICE
-- ═══════════════════════════════════════════════════════════════════════════

if CEnabled and Main:FindFirstChild('Notice') then
	Main.Notice.BackgroundTransparency = 1
	Main.Notice.Title.TextTransparency = 1
	Main.Notice.Size     = UDim2.new(0, 0, 0, 0)
	Main.Notice.Position = UDim2.new(0.5, 0, 0, -100)
	Main.Notice.Visible  = true
	tween(Main.Notice, TweenInfo.new(0.5, Enum.EasingStyle.Exponential, Enum.EasingDirection.InOut),
		{Size = UDim2.new(0, 280, 0, 35), Position = UDim2.new(0.5, 0, 0, -50), BackgroundTransparency = 0.5})
	tween(Main.Notice.Title, TI_NORMAL, {TextTransparency = 0.1})
end

-- ═══════════════════════════════════════════════════════════════════════════
--  DELAYED INITIALIZATION
-- ═══════════════════════════════════════════════════════════════════════════

task.delay(4, function()
	RayfieldLibrary:LoadConfiguration()
	if Main:FindFirstChild('Notice') and Main.Notice.Visible then
		tween(Main.Notice, TweenInfo.new(0.5, Enum.EasingStyle.Exponential, Enum.EasingDirection.InOut),
			{Size = UDim2.new(0, 100, 0, 25), Position = UDim2.new(0.5, 0, 0, -100), BackgroundTransparency = 1})
		tween(Main.Notice.Title, TI_FAST, {TextTransparency = 1})
		task.wait(ANIM_NORMAL)
		Main.Notice.Visible = false
	end
end)

return RayfieldLibrary
