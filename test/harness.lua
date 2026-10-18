-- Stub of just enough ESO client to exercise PBsGammaAdjuster.
--
-- The add-on touches the client in exactly two places, GetCVar and SetCVar, so those are the
-- ones the stub works hardest on. Four behaviours of SetCVar are modelled, because which one
-- the console really has is the one thing that cannot be known from here:
--
--   works    the CVar changes
--   private  the call raises, as the client does for a restricted function
--   ignore   the call returns normally and nothing changes
--
-- and a fourth, "the game puts its own value back later", is not a mode but a timed write the
-- test schedules with Later(). The stub is strict about what the real API is strict about:
-- GetCVar returns a string, and SetCVar raises if it is handed anything but strings.
local DIR = ADDON_DIR

-- ---- string table -------------------------------------------------------------------
local stringValues = {}
local nextId = 1
EnglishIds, JapaneseIds = {}, {}
function ZO_CreateStringId(id, value)
	if not _G[id] then _G[id] = nextId; nextId = nextId + 1 end
	stringValues[_G[id]] = value
	EnglishIds[id] = value
end
function SafeAddVersion() end
function SafeAddString(id, value)
	stringValues[id] = value
	for name, number in pairs(_G) do
		if number == id and type(name) == "string" and name:find("^SI_PBSGA_") then JapaneseIds[name] = value end
	end
end
function GetString(id) return stringValues[id] or ("<missing " .. tostring(id) .. ">") end

-- ---- clock and timers ---------------------------------------------------------------
local clock = 0
local timers = {}
function GetGameTimeMilliseconds() return clock end
function zo_callLater(fn, ms) timers[#timers + 1] = { due = clock + ms, fn = fn } end
function Later(ms, fn) timers[#timers + 1] = { due = clock + ms, fn = fn } end
function PendingTimers() return #timers end

-- Moves the clock forward, running everything that falls due on the way in order.
function Advance(ms)
	local target = clock + ms
	while true do
		local nextIndex
		for index, timer in ipairs(timers) do
			if timer.due <= target and (not nextIndex or timer.due < timers[nextIndex].due) then
				nextIndex = index
			end
		end
		if not nextIndex then break end
		local timer = table.remove(timers, nextIndex)
		clock = math.max(clock, timer.due)
		timer.fn()
	end
	clock = target
end

-- ---- the game's brightness ----------------------------------------------------------
Game = { gamma = "100", mode = "works", setCalls = {} }
function GetCVar(name)
	assert(name == "GAMMA_ADJUSTMENT", "unexpected CVar " .. tostring(name))
	return Game.gamma
end
function SetCVar(name, value)
	assert(type(name) == "string" and type(value) == "string", "SetCVar takes two strings")
	assert(name == "GAMMA_ADJUSTMENT", "unexpected CVar " .. tostring(name))
	Game.setCalls[#Game.setCalls + 1] = value
	if Game.mode == "private" then
		error("Attempt to access a private function 'SetCVar' from insecure code.", 2)
	elseif Game.mode == "ignore" then
		return
	end
	Game.gamma = value
end
HDR = false
function IsSystemUsingHDR() return HDR end

-- The graphics setting the options screen uses for the same brightness. Normally one variable
-- with the CVar; Game.split makes it a separate one, so a test can look at a game where the two
-- have come apart. SetSetting has the same three behaviours as SetCVar, in Game.settingMode.
SETTING_TYPE_GRAPHICS = 3
GRAPHICS_SETTING_GAMMA_ADJUSTMENT = 7
Game.settingCalls = {}
function GetSetting(system, id)
	assert(system == SETTING_TYPE_GRAPHICS and id == GRAPHICS_SETTING_GAMMA_ADJUSTMENT, "unexpected setting")
	if Game.split then return Game.settingGamma end
	return Game.gamma
end
GetSettingStub = GetSetting
function SetSetting(system, id, value)
	assert(system == SETTING_TYPE_GRAPHICS and id == GRAPHICS_SETTING_GAMMA_ADJUSTMENT, "unexpected setting")
	assert(type(value) == "string", "SetSetting takes the value as a string")
	Game.settingCalls[#Game.settingCalls + 1] = value
	if Game.settingMode == "private" then
		error("Attempt to access a private function 'SetSetting' from insecure code.", 2)
	elseif Game.settingMode == "ignore" then
		return
	end
	Game.gamma = value
	Game.settingGamma = value
end

-- How the client classes functions, and the documented door to protected ones. Game.protected
-- and Game.private are sets of function names. CallSecureProtected fails (returns false) for a
-- function that is not protected, as a ZOS developer has said it does; for a protected one it
-- performs the write unless Game.secureMode is "ignore", or raises when it is "private".
-- Game.noClassify removes the query functions, as on a client that lacks them.
Game.protected, Game.private, Game.secureCalls = {}, { SetSetting = true }, {}
function IsProtectedFunction(name) return Game.protected[name] == true end
function IsPrivateFunction(name) return Game.private[name] == true end
function CallSecureProtected(name, ...)
	local args = { ... }
	Game.secureCalls[#Game.secureCalls + 1] = name
	if Game.secureMode == "private" then
		error("Attempt to access a private function 'CallSecureProtected' from insecure code.", 2)
	end
	if not Game.protected[name] then return false end
	if Game.secureMode ~= "ignore" and name == "SetCVar" then Game.gamma = args[2] end
	if Game.secureMode ~= "ignore" and name == "RefreshSettings" then RefreshSettings() end
	if Game.secureMode ~= "ignore" and name == "ApplySettings" then ApplySettings() end
	return true
end

-- The two calls that touch the engine's stored settings. As measured on PS5, RefreshSettings
-- pulls the LIVE value into the stored setting, overwriting what the player saved (stored 135,
-- live 100 -> both 100), so the stub does exactly that and a test fails if it is ever called.
-- ApplySettings is the unknown: Game.resync says what it does -- "apply" pushes the stored
-- setting to the live CVar, "apply-overwrites" behaves like RefreshSettings, "none" does nothing.
-- Both count their calls and raise for a private function, as the client does.
Game.refreshCalls, Game.applyCalls = 0, 0
local function Touching(name, counter)
	if Game.private[name] then
		error("Attempt to access a private function '" .. name .. "' from insecure code.", 3)
	end
	Game[counter] = Game[counter] + 1
	if name == "RefreshSettings" then
		Game.settingGamma = Game.gamma
	elseif Game.resync == "apply" then
		Game.gamma = Game.settingGamma
	elseif Game.resync == "apply-overwrites" then
		Game.settingGamma = Game.gamma
	end
end
function RefreshSettings() Touching("RefreshSettings", "refreshCalls") end
function ApplySettings() Touching("ApplySettings", "applyCalls") end

-- ---- chat / misc --------------------------------------------------------------------
Chat = {}
CHAT_ROUTER = { AddSystemMessage = function(_, t) Chat[#Chat + 1] = t end }
function d(t) Chat[#Chat + 1] = tostring(t) end
SLASH_COMMANDS = {}

-- The manifest is read from the real file, so a version edited in one place and not the other
-- fails the test rather than a console.
local function ReadManifest()
	local file = assert(io.open(DIR .. "/PBsGammaAdjuster.addon", "r"))
	local text = file:read("*a")
	file:close()
	return text
end
Manifest = ReadManifest()
function GetAddOnManager()
	return {
		GetNumAddOns = function() return 1 end,
		GetAddOnInfo = function() return "PBsGammaAdjuster", Manifest:match("## Title: ([^\n]+)") end,
	}
end

-- ---- events -------------------------------------------------------------------------
EVENT_ADD_ON_LOADED = "EVENT_ADD_ON_LOADED"
EVENT_PLAYER_ACTIVATED = "EVENT_PLAYER_ACTIVATED"
local handlers = {}
EVENT_MANAGER = {
	RegisterForEvent = function(_, name, event, fn) handlers[event] = handlers[event] or {}; handlers[event][name] = fn end,
	UnregisterForEvent = function(_, name, event) if handlers[event] then handlers[event][name] = nil end end,
}
function Fire(event, ...) for _, fn in pairs(handlers[event] or {}) do fn(event, ...) end end

-- ---- saved variables ----------------------------------------------------------------
SavedStore = {}
local function DeepCopy(t)
	if type(t) ~= "table" then return t end
	local out = {}
	for k, v in pairs(t) do out[k] = DeepCopy(v) end
	return out
end
ZO_SavedVars = {
	NewAccountWide = function(_, name, version, namespace, defaults)
		SavedStore[name] = SavedStore[name] or {}
		local store = SavedStore[name]
		for k, v in pairs(defaults or {}) do if store[k] == nil then store[k] = DeepCopy(v) end end
		return store
	end,
}

-- ---- LibHarvensAddonSettings --------------------------------------------------------
PanelRows = {}
LibHarvensAddonSettings = {
	ST_LABEL = "label", ST_CHECKBOX = "checkbox", ST_SLIDER = "slider", ST_DROPDOWN = "dropdown", ST_BUTTON = "button",
	AddAddon = function(_, title)
		local panel = { title = title }
		function panel:AddSetting(row) PanelRows[#PanelRows + 1] = row end
		function panel:UpdateControls() end
		return panel
	end,
}

-- ---- load the add-on ----------------------------------------------------------------
-- The client's own order: every file first, then EVENT_ADD_ON_LOADED for the add-on. Boot()
-- starts a whole new session -- clock, timers, chat, game and event handlers are reset -- but
-- leaves SavedStore alone unless the test replaces it, because saved variables are what
-- survives a log-out.
dofile(DIR .. "/lang/strings.lua")
dofile(DIR .. "/lang/jp.lua")

-- Calls to the three client functions that must never be made by this add-on, summed over every
-- session the tests start: SetCVar and SetSetting are dropped or private on console, and
-- RefreshSettings overwrites the player's saved brightness. Read with ForbiddenCalls().
local forbidden = 0
function ForbiddenCalls()
	return forbidden + #Game.setCalls + #Game.settingCalls + Game.refreshCalls
end

function Boot(options)
	options = options or {}
	forbidden = ForbiddenCalls()
	PBS_GAMMA_ADJUSTER = nil
	handlers = {}
	timers = {}
	clock = 0
	Chat = {}
	PanelRows = {}
	SLASH_COMMANDS = {}
	Game.gamma = options.gamma or "100"
	Game.mode = options.mode or "works"
	Game.setCalls = {}
	Game.settingCalls = {}
	Game.protected = options.protected or {}
	Game.private = options.private or { SetSetting = true }
	Game.secureMode = options.secureMode or "works"
	Game.secureCalls = {}
	if options.noClassify then
		IsProtectedFunction, IsPrivateFunction = nil, nil
	else
		IsProtectedFunction = function(name) return Game.protected[name] == true end
		IsPrivateFunction = function(name) return Game.private[name] == true end
	end
	Game.resync = options.resync or "none"
	Game.refreshCalls, Game.applyCalls = 0, 0
	GetSetting = (not options.noSetting) and GetSettingStub or nil
	Game.settingMode = options.settingMode or "works"
	Game.split = options.split or false
	Game.settingGamma = options.settingGamma or Game.gamma
	if options.saved ~= nil then
		SavedStore = { PBsGammaAdjuster_Data = options.saved }
	end
	dofile(DIR .. "/Main.lua")
	dofile(DIR .. "/Settings.lua")
	Fire(EVENT_ADD_ON_LOADED, "PBsGammaAdjuster")
	return PBS_GAMMA_ADJUSTER
end
