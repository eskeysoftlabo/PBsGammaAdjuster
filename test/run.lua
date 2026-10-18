-- Behavioural tests for PB's GammaAdjuster.
--
-- The add-on runs on a console, where one real test costs a whole session: build, upload, boot
-- the PS5, log in. harness.lua stubs the part of the client the add-on touches -- the live
-- GAMMA_ADJUSTMENT CVar and the stored graphics setting (two stores, as measured), ApplySettings
-- and the functions that say how the client classes it, a clock with timers, saved variables and
-- LibHarvensAddonSettings -- so the logic can be exercised here instead.
--
--   lua test/run.lua        (from the add-on folder; any Lua 5.1+, luajit included)
--
-- The game as measured on PS5 right after login: live CVar 100, stored setting 133 (the value the
-- player saved). ApplySettings pushed the stored value to the live one; RefreshSettings did the
-- opposite and overwrote the stored value, so the harness lets a test notice if it is ever called.

local HERE = (debug.getinfo(1, "S").source:match("^@(.*)/") or ".")
ADDON_DIR = HERE .. "/.."
dofile(HERE .. "/harness.lua")

local failures = 0
local function check(label, got, want)
	local ok = got == want
	if not ok then failures = failures + 1 end
	print(string.format("%s %-66s got=%s want=%s", ok and "PASS" or "FAIL", label, tostring(got), tostring(want)))
end

local function ChatHas(needle)
	for _, line in ipairs(Chat) do
		if line:find(needle, 1, true) then return true end
	end
	return false
end

local function LogHas(addon, needle)
	for _, line in ipairs(addon.log) do
		if line:find(needle, 1, true) then return true end
	end
	return false
end

local function Row(type, index)
	local n = 0
	for _, row in ipairs(PanelRows) do
		if row.type == type then
			n = n + 1
			if n == (index or 1) then return row end
		end
	end
end

-- A session as measured: live 100, saved 133. `options` overrides the game; the player enters the
-- world and the clock runs on past the last look.
local function Login(options)
	options = options or {}
	options.gamma = options.gamma or "100"
	options.split = true
	options.settingGamma = options.settingGamma or "133"
	options.resync = options.resync or "apply"
	options.saved = options.saved or {}
	local addon = Boot(options)
	Fire(EVENT_PLAYER_ACTIVATED)
	Advance(20000)
	return addon
end

print("\n== 1. manifest, strings, panel ==")
local addon = Boot()
local manifestVersion = Manifest:match("## Version: ([^\n]+)")
check("version read from ## Title matches ## Version", addon.version, manifestVersion)
check("title carries the display name and version", addon.title, "PB’s GammaAdjuster " .. manifestVersion)
for _, file in ipairs({ "lang/strings.lua", "lang/$(language).lua", "Main.lua", "Settings.lua" }) do
	check("manifest lists " .. file, Manifest:find("\n" .. file .. "\n", 1, true) ~= nil, true)
end
local missing = {}
for id in pairs(EnglishIds) do if not JapaneseIds[id] then missing[#missing + 1] = id end end
for id in pairs(JapaneseIds) do if not EnglishIds[id] then missing[#missing + 1] = id end end
check("English and Japanese define the same string ids", #missing, 0)
local empty = 0
for _, value in pairs(EnglishIds) do if value == "" then empty = empty + 1 end end
for _, value in pairs(JapaneseIds) do if value == "" then empty = empty + 1 end end
check("no empty string", empty, 0)
check("slash command registered", type(SLASH_COMMANDS["/pbgamma"]), "function")
check("panel rows (label, checkbox, button, label)", #PanelRows, 4)
check("there is no slider any more", Row("slider"), nil)
check("checkbox default is on", Row("checkbox").default, true)
check("there is a restore button", Row("button") ~= nil, true)

print("\n== 2. login with the saved brightness not applied ==")
addon = Boot({ gamma = "100", split = true, settingGamma = "133", resync = "apply", saved = {} })
check("nothing is called while the add-on loads", Game.applyCalls, 0)
check("loading logs both values", LogHas(addon, "addon loaded: live \"100\", saved \"133\""), true)
Fire(EVENT_PLAYER_ACTIVATED)
check("applied as soon as the player is activated", Game.applyCalls, 1)
check("the live value follows the saved one", Game.gamma, "133")
check("the saved value is untouched", Game.settingGamma, "133")
check("result pushed", addon.lastResult, "pushed")
Advance(20000)
check("the later looks find it right and call nothing", Game.applyCalls, 1)
check("nothing said in chat when it works", #Chat, 0)
check("the log names the call", LogHas(addon, "player activated: ApplySettings called; live 100 -> 133, saved 133 -> 133 => pushed"), true)

print("\n== 3. nothing to do ==")
addon = Login({ gamma = "133", settingGamma = "133" })
check("live already at the saved value: not called", Game.applyCalls, 0)
check("result agree", addon.lastResult, "agree")
check("silent", #Chat, 0)
addon = Login({ gamma = "133.000000", settingGamma = "133" })
check("a CVar read back with decimals counts as equal", Game.applyCalls, 0)
addon = Login({ gamma = "100", settingGamma = "100" })
check("nothing saved apart from the default: not called", Game.applyCalls, 0)

print("\n== 4. the game puts its own value back later ==")
addon = Boot({ gamma = "100", split = true, settingGamma = "133", resync = "apply", saved = {} })
Fire(EVENT_PLAYER_ACTIVATED)
Later(3000, function() Game.gamma = "100" end)
Advance(20000)
check("a reset at +3s is undone at the +5s look", Game.gamma, "133")
check("two calls: activation and +5s", Game.applyCalls, 2)
check("the log names the look that fixed it", LogHas(addon, "recheck +5s: ApplySettings called; live 100 -> 133"), true)

addon = Boot({ gamma = "100", split = true, settingGamma = "133", resync = "apply", saved = {} })
Fire(EVENT_PLAYER_ACTIVATED)
Later(25000, function() Game.gamma = "100" end)
Advance(40000)
check("a change after the last look is left alone", Game.gamma, "100")
check("and not fought over", Game.applyCalls, 1)

print("\n== 5. only the first activation is a login ==")
addon = Login()
Game.gamma = "100" -- the player used the calibration screen
Fire(EVENT_PLAYER_ACTIVATED)
Advance(20000)
check("a zone change does not restore again", Game.gamma, "100")
check("no further calls", Game.applyCalls, 1)
check("no timers left", PendingTimers(), 0)

print("\n== 6. ApplySettings does nothing ==")
addon = Login({ resync = "none" })
check("limited to three automatic calls", Game.applyCalls, 3)
check("the game is left as it was", Game.gamma .. "/" .. Game.settingGamma, "100/133")
check("result unchanged", addon.lastResult, "unchanged")
local notices = 0
for _, line in ipairs(Chat) do if line:find("/pbgamma", 1, true) then notices = notices + 1 end end
check("exactly one failure notice, pointing at the command", notices, 1)
check("the limit is logged", LogHas(addon, "already tried 3 times"), true)

print("\n== 7. ApplySettings overwrites the saved brightness ==")
addon = Login({ resync = "apply-overwrites" })
check("saved value lost, as the stub models", Game.settingGamma, "100")
check("after the later looks the result is halted", addon.lastResult, "halted")
check("called once and then stopped", Game.applyCalls, 1)
check("logged as an overwrite", LogHas(addon, "saved 133 -> 100 => overwrote"), true)
check("later looks say they are halted", LogHas(addon, "an earlier call overwrote the saved brightness"), true)
check("the player is told, and how to put it back", ChatHas("overwrote your saved brightness") and ChatHas("Calibrate Brightness"), true)
check("it is never reported as a success", LogHas(addon, "=> pushed"), false)

print("\n== 8. the client says ApplySettings is off limits ==")
addon = Login({ private = { SetSetting = true, ApplySettings = true } })
check("private: not called", Game.applyCalls, 0)
check("private: the game is left alone", Game.gamma, "100")
check("private: logged as skipped", LogHas(addon, "skipped (private)"), true)
check("private: one failure notice", ChatHas("could not restore the saved brightness (unchanged)"), true)

addon = Login({ protected = { ApplySettings = true } })
check("protected: goes through CallSecureProtected", Game.secureCalls[1], "ApplySettings")
check("protected: and works", Game.gamma, "133")

addon = Login({ noClassify = true })
check("no classification API: nothing is called", Game.applyCalls, 0)
check("no classification API: logged as n/a", LogHas(addon, "skipped (n/a)"), true)

print("\n== 9. values that cannot be read ==")
addon = Login({ noSetting = true })
check("saved value unreadable: nothing is called", Game.applyCalls, 0)
check("result unreadable", addon.lastResult, "unreadable")
check("one failure notice", ChatHas("could not restore the saved brightness (unreadable)"), true)

print("\n== 10. turned off ==")
addon = Login({ saved = { enabled = false } })
check("nothing is called", Game.applyCalls, 0)
check("result off", addon.lastResult, "off")
check("no timers are started", PendingTimers(), 0)
check("checkbox shows off", Row("checkbox").getFunction(), false)

print("\n== 11. settings panel ==")
addon = Boot({ gamma = "100", split = true, settingGamma = "133", resync = "apply", saved = {} })
Row("checkbox").setFunction(false)
check("switch off stored", SavedStore.PBsGammaAdjuster_Data.enabled, false)
Row("checkbox").setFunction(true)
check("switch on stored", SavedStore.PBsGammaAdjuster_Data.enabled, true)
check("changing the switch calls nothing", Game.applyCalls, 0)
Chat = {}
Row("button").clickHandler()
check("the button restores now", Game.gamma, "133")
check("and says so", ChatHas("the screen now follows the brightness you saved"), true)
Chat = {}
Row("button").clickHandler()
check("pressing it again says there is nothing to do", ChatHas("nothing to do"), true)
check("and calls nothing more", Game.applyCalls, 1)

addon = Boot({ gamma = "100", split = true, settingGamma = "133", resync = "none", saved = {} })
Chat = {}
Row("button").clickHandler()
check("the button says when it did not work", ChatHas("not restored (unchanged)"), true)
check("and where to send the lines", ChatHas("/pbgamma"), true)

print("\n== 12. slash command ==")
addon = Boot({ gamma = "100", split = true, settingGamma = "133", resync = "apply", saved = {} })
Chat = {}
SLASH_COMMANDS["/pbgamma"]("resync")
check("resync restores now", Game.gamma, "133")
check("and says so", ChatHas("the screen now follows the brightness you saved"), true)
SLASH_COMMANDS["/pbgamma"]("120")
check("a number is explained, not written", ChatHas("cannot be set from an add-on"), true)
SLASH_COMMANDS["/pbgamma"]("nonsense")
check("anything else prints usage", ChatHas("restore the saved brightness now"), true)
SLASH_COMMANDS["/pbgamma"]("off")
check("off stored", SavedStore.PBsGammaAdjuster_Data.enabled, false)
SLASH_COMMANDS["/pbgamma"]("on")
check("on stored", SavedStore.PBsGammaAdjuster_Data.enabled, true)
Chat = {}
SLASH_COMMANDS["/pbgamma"]("")
check("status prints the version", ChatHas(addon.version), true)
check("status prints the live value", ChatHas("live brightness  : \"133\""), true)
check("status prints the saved value", ChatHas("saved brightness : \"133\""), true)
check("status prints how the client classes ApplySettings", ChatHas("ApplySettings neither"), true)
check("status prints the log", ChatHas("slash resync"), true)
HDR = true
Chat = {}
SLASH_COMMANDS["/pbgamma"]("status")
check("status reports HDR", ChatHas("HDR true"), true)
HDR = false

-- A restore the player asks for is not held back by what the automatic path has done.
addon = Login({ resync = "apply-overwrites" })
Game.settingGamma = "133"
Game.resync = "apply"
Chat = {}
SLASH_COMMANDS["/pbgamma"]("resync")
check("a manual restore ignores the halt", Game.gamma, "133")

print("\n== 13. old saved variables ==")
addon = Boot({ gamma = "100", split = true, settingGamma = "100", resync = "apply", saved = { gamma = 143, enabled = true } })
check("the retired brightness field is dropped", SavedStore.PBsGammaAdjuster_Data.gamma, nil)
check("and never written to the game", ForbiddenCalls(), 0)

print("\n== 14. what this add-on must never call ==")
check("SetCVar, SetSetting and RefreshSettings: not once in any session above", ForbiddenCalls(), 0)

print(failures == 0 and "\nALL PASSED" or ("\n" .. failures .. " FAILED"))
os.exit(failures == 0 and 0 or 1)
