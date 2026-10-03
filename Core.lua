-- Wick's Seals and Things
-- Core.lua: WickCore addon object, saved variables, event dispatch, slash command.
--
-- The paladin kit for World of Warcraft: Forever. A paladin's setup is a
-- seal, a blessing, an aura and the weapon in hand. All four are
-- readable out of combat and none is a combat tracker, so the kit sits
-- inside Forever's addon rules. Through WickCore it adds the talent
-- layer, the pre-pull checklist and racials.

local ADDON, ns = ...

local Core = WickCore
if not Core then
    -- WickCore is missing or switched off.
    --
    -- The TOC asks for it with OptionalDeps rather than Dependencies on
    -- purpose. A hard dependency makes the client refuse to load this addon
    -- at all, so nothing of ours runs and the player is told nothing beyond
    -- a greyed line in the AddOns list. Loading anyway lets us say what is
    -- wrong and where to get it.
    --
    -- One line for the lot of them, not one per addon: with the whole suite
    -- installed and WickCore switched off, a line each would be a wall.
    local need = _G.WicksNeedCore
    if not need then
        need = {}
        _G.WicksNeedCore = need
        local f = CreateFrame("Frame")
        f:RegisterEvent("PLAYER_LOGIN")
        f:SetScript("OnEvent", function()
            table.sort(need)
            print(("|cff4FC778Wick's Mods|r: %s %s WickCore, which is not installed or not switched on. It is in the same download as the rest of the suite: |cffD4C8A1wicksmods.com|r")
                :format(table.concat(need, ", "), #need == 1 and "needs" or "need"))
        end)
    end
    need[#need + 1] = "Wick's Seals and Things"
    return
end
local D, R = Core.Dialect, Core.Restrict

ns.version = "0.9.0"

local PROFILE_DEFAULTS = {
    showStrip   = true,
    stripLocked = true,
    strip       = {},
    kitWindow   = {},
    swap        = true,    -- keep the two swap keys loaded
    pinned      = {},      -- twoHand / oneHand / shield -> itemID a key should always reach for
    wantFury    = false,   -- Righteous Fury on the checklist, for the tank
    reseal      = true,    -- the Judgement key puts the seal back after
    mainSeal    = nil,     -- the seal to fight under; nil follows what you had on
    blessing    = nil,     -- the blessing key's spell; nil follows what you had on
    cycle       = nil,     -- the cycle key's steps; nil is the default dance, false is off
    cycleReset  = 15,      -- seconds of quiet before the cycle starts over
}

-- What was last worn, per character: the exact pieces the swap keys
-- bring back. Gear is the character's own, whatever profile is in use.
local CHAR_DEFAULTS = {
    sets = {},
}

local A = Core:NewAddon("WicksSealsAndThings", {
    title    = "Wick's Seals and Things",
    version  = ns.version,
    savedVar = "WicksSealsSaved",
    defaults = { profile = PROFILE_DEFAULTS, char = CHAR_DEFAULTS, global = {} },
})
ns.A = A

-- ============================================================
-- Event dispatcher
-- ============================================================
local events = {}
function ns:On(event, fn)
    events[event] = events[event] or {}
    table.insert(events[event], fn)
end

local frame = CreateFrame("Frame", "WicksSealsEvents")
ns.eventFrame = frame
frame:SetScript("OnEvent", function(_, event, ...)
    if events[event] then
        for _, fn in ipairs(events[event]) do
            local ok, err = pcall(fn, event, ...)
            if not ok then A:Print(("error in %s: %s"):format(event, tostring(err))) end
        end
    end
end)
function ns.RegisterEvents(list)
    for _, ev in ipairs(list) do pcall(frame.RegisterEvent, frame, ev) end
end

local _, playerClass = UnitClass("player")
ns.isPaladin = playerClass == "PALADIN"

-- ============================================================
-- Lifecycle
-- ============================================================
function A:OnInitialize()
    ns.db = self.db
    self.db:On("OnProfileChanged", function()
        if ns.UI and ns.UI.ApplyStripVisibility then ns.UI:ApplyStripVisibility() end
        if ns.swap and ns.swap.Update then ns.swap:Update() end
    end)

    Core.Cooldowns:New(self, { key = "cooldownBar" })

    -- Everything here reads the character rather than a table of
    -- Classic facts: which seals, blessings and auras exist comes from
    -- the spellbook, and whether one is up comes from the player's own
    -- auras. Forever retunes Classic and a list written here would be a
    -- guess.
    local function tri(fn)
        return function()
            local v, why = fn()
            if why == "restricted" then return nil end
            return v ~= nil
        end
    end
    Core.Kit:New(self, {
        racials = true,
        checklist = {
            { label = "Seal active",     check = tri(function() return ns.Seals:ActiveSeal() end) },
            { label = "Blessing on you", check = tri(function() return ns.Seals:ActiveBlessing() end) },
            { label = "Aura on",         check = tri(function() return ns.Seals:ActiveAura() end) },
            { label = "Symbols of Kings", item = "Symbol of Kings", min = 5,
              when = function() return ns.Seals:Knows("Greater Blessing of") end },
            { label = "Symbol of Divinity", item = "Symbol of Divinity", min = 1,
              when = function() return ns.Seals:Knows("Divine Intervention") end },
            { label = "Righteous Fury", aura = "Righteous Fury", cast = "Righteous Fury",
              when = function()
                  local db = ns.db and ns.db.profile
                  return db and db.wantFury and ns.Seals:Knows("Righteous Fury")
              end },
        },
    })
end

function A:OnEnable()
    if not ns.isPaladin then
        self:Print("loaded (non-paladin: viewer mode).")
    else
        self:Print("loaded. /wsl for the seal strip, /wsl kit for talents and checklist.")
    end
    if ns.Seals and ns.Seals.Init then ns.Seals:Init() end
    if ns.swap and ns.swap.Init then ns.swap:Init() end
    if ns.UI and ns.UI.Init then ns.UI:Init() end

    self:RegisterLauncher({
        onClick = function(_, button)
            if button == "RightButton" then self.kit:Toggle()
            else ns.UI:Toggle() end
        end,
        tooltip = function(tt)
            tt:AddLine(Core.Chrome:TitleMarkup("Wick's Seals and Things"))
            tt:AddLine("Left-click: seals   Right-click: talents and checklist", 0.5, 0.5, 0.5)
        end,
    })

    if self.cooldowns then self.cooldowns:Init() end

    self:RegisterOptions(function(page, addon)
        local O = Core.Options
        local db = addon.db.profile
        local y = O:Heading(page, "Seal strip", 0)
        y = O:Check(page, "Show the seal strip", function() return db.showStrip ~= false end,
            function(v) db.showStrip = v; ns.UI:ApplyStripVisibility() end, y)
        y = O:Check(page, "Lock the strip", function() return db.stripLocked ~= false end,
            function(v) db.stripLocked = v end, y)
        y = O:Note(page, "Every seal you know, a Judgement key, and the two weapon swap keys in one row. The seal that is up is lit; click another to swap. Shift-drag moves the strip even when locked.", y)

        y = O:Heading(page, "Checklist", y - 6)
        y = O:Check(page, "Expect Righteous Fury (tanking)", function() return db.wantFury == true end,
            function(v) db.wantFury = v; if addon.kit and addon.kit.checklist then addon.kit.checklist:Refresh() end end, y)
        y = O:Button(page, "Open strip", function() ns.UI:Toggle() end, y, 100)
        y = O:Button(page, "Open kit", function() addon.kit:Toggle() end, y, 100)
        if ns.swap and ns.isPaladin then y = ns.swap:OptionRow(page, y - 6) end
        if addon.cooldowns then y = addon.cooldowns:OptionRow(page, y - 6) end
        y = O:ProfileSection(page, addon, y - 8)
    end)
end

-- Keybinding entry points
BINDING_HEADER_WICKSSEALS = "Wick's Seals and Things"
for i = 1, 6 do
    _G["BINDING_NAME_CLICK WicksSealsButton" .. i .. ":LeftButton"] = "Seal key " .. i
end
_G["BINDING_NAME_CLICK WicksSealsJudgeButton:LeftButton"] = "Judgement, then reseal"
_G["BINDING_NAME_CLICK WicksSealsCycleButton:LeftButton"] = "Seal cycle"
_G["BINDING_NAME_CLICK WicksSealsBlessButton:LeftButton"] = "Blessing"
_G["BINDING_NAME_CLICK WicksSealsTwoHandButton:LeftButton"] = "Two-hander"
_G["BINDING_NAME_CLICK WicksSealsShieldButton:LeftButton"] = "Sword and board"
BINDING_NAME_WICKSSEALS_TOGGLE = "Toggle seal strip"
function WicksSealsAndThings_Toggle() if ns.UI then ns.UI:Toggle() end end

-- ============================================================
-- Slash command
-- ============================================================
A:RegisterSlash(function(_, msg)
    msg = (msg or ""):gsub("^%s+", ""):gsub("%s+$", "")
    local lower = msg:lower()
    local db = A.db.profile

    if lower == "" or lower == "show" or lower == "toggle" then ns.UI:Toggle() return end
    if lower == "kit" or lower == "talents" or lower == "checklist" then A.kit:Toggle() return end
    if lower == "cd" or lower:match("^cd%s") then return A.cooldowns:Command(msg:match("^%a+%s*(.*)$")) end
    if lower == "options" or lower == "config" then A:OpenOptions() return end
    if lower == "strip" then
        db.showStrip = not (db.showStrip ~= false)
        ns.UI:ApplyStripVisibility()
        A:Print("strip " .. (db.showStrip and "shown" or "hidden") .. ".")
        return
    end
    if lower == "unlock" or lower == "move" then ns.UI:SetStripLocked(false) return end
    if lower == "lock" then ns.UI:SetStripLocked(true) return end

    if lower == "swap" or lower:match("^swap%s") then
        if ns.swap and ns.isPaladin then
            ns.swap:Command(msg:match("^%a+%s*(.*)$"), function(line) A:Print(line) end)
        else A:Print("the weapon swap keys are paladin only") end
        return
    end
    if lower:match("^pin") then
        if ns.swap and ns.isPaladin then
            ns.swap:Pin(msg:match("^%a+%s*(.*)$"), function(line) A:Print(line) end)
        else A:Print("the weapon swap keys are paladin only") end
        return
    end
    if lower:match("^seal") then
        local want = msg:match("^%a+%s+(.+)$")
        if not want then
            A:Print(("fighting seal: %s%s. /wsl seal <name> to choose one, /wsl seal auto to follow what you had on.")
                :format(ns.Seals:MainSeal() or "none known", db.mainSeal and "" or " (following you)"))
            return
        end
        if want:lower() == "auto" then db.mainSeal = nil
        else
            local found
            for _, e in ipairs(ns.Seals.seals or {}) do
                if e.name:lower() == want:lower() or e.name:lower():find(want:lower(), 1, true) then found = e.name break end
            end
            if not found then A:Print("no seal called " .. want .. " in your book.") return end
            db.mainSeal = found
        end
        ns.UI:Rebuild()
        A:Print(("fighting seal: %s."):format(ns.Seals:MainSeal() or "none"))
        return
    end
    if lower:match("^bless") then
        local want = msg:match("^%a+%s+(.+)$")
        if not want then
            A:Print(("blessing key: %s%s. /wsl bless <name> to choose one, /wsl bless auto to follow what you had on.")
                :format(ns.Seals:MainBlessing() or "none known", db.blessing and "" or " (following you)"))
            return
        end
        if want:lower() == "auto" then db.blessing = nil
        else
            local found
            for _, e in ipairs(ns.Seals.blessings or {}) do
                if e.name:lower() == want:lower() then found = e.name break end
            end
            if not found then
                for _, e in ipairs(ns.Seals.blessings or {}) do
                    if e.name:lower():find(want:lower(), 1, true) then found = e.name break end
                end
            end
            if not found then A:Print("no blessing called " .. want .. " in your book.") return end
            db.blessing = found
        end
        ns.UI:Rebuild()
        A:Print(("blessing key: %s."):format(ns.Seals:MainBlessing() or "none"))
        return
    end
    if lower:match("^reseal") then
        local want = lower:match("^reseal%s+(%a+)")
        if want == "on" then db.reseal = true
        elseif want == "off" then db.reseal = false
        else db.reseal = not (db.reseal ~= false) end
        ns.UI:Rebuild()
        A:Print("the Judgement key " .. (db.reseal ~= false and "reseals after judging." or "judges alone."))
        return
    end
    if lower:match("^cycle") then
        local rest = msg:match("^%a+%s+(.+)$")
        if not rest then
            local steps = ns.Seals:CycleSteps()
            A:Print("seal cycle: " .. (steps and table.concat(steps, ", ") or "off or not available"))
            A:Print("/wsl cycle <spell, spell, ...> | auto | off | reset <seconds>")
            return
        end
        local lr = rest:lower()
        if lr == "auto" then db.cycle = nil
        elseif lr == "off" then db.cycle = false
        elseif lr:match("^reset%s+%d+") then db.cycleReset = tonumber(lr:match("(%d+)"))
        else
            local steps = {}
            for part in rest:gmatch("[^,]+") do
                local step = (part:gsub("^%s+", ""):gsub("%s+$", ""))
                if step ~= "" then steps[#steps + 1] = step end
            end
            if #steps < 2 then A:Print("give at least two steps, separated by commas.") return end
            db.cycle = steps
        end
        ns.UI:Rebuild()
        local steps = ns.Seals:CycleSteps()
        A:Print("seal cycle: " .. (steps and table.concat(steps, ", ") or "off"))
        return
    end
    if lower:match("^fury") then
        local want = lower:match("^fury%s+(%a+)")
        if want == "on" then db.wantFury = true
        elseif want == "off" then db.wantFury = false
        else db.wantFury = not db.wantFury end
        if A.kit and A.kit.checklist then A.kit.checklist:Refresh() end
        A:Print("Righteous Fury " .. (db.wantFury and "is" or "is not") .. " on the checklist.")
        return
    end

    if lower == "status" or lower == "debug" then
        local S = ns.Seals
        local seal, sealWhy = S:ActiveSeal()
        local aura, auraWhy = S:ActiveAura()
        local bless, blessWhy = S:ActiveBlessing()
        local function say(v, why) return v or (why == "restricted" and "(in combat)" or "none") end
        A:Print(("seals known: %d   blessings: %d   auras: %d   judgement: %s"):format(
            #(S.seals or {}), #(S.blessings or {}), #(S.auras or {}), S.judge and S.judge.name or "not yet"))
        A:Print(("seal: %s   blessing: %s   aura: %s"):format(say(seal, sealWhy), say(bless, blessWhy), say(aura, auraWhy)))
        A:Print("judgement key: " .. (S:JudgeMacro():gsub("\n", " | ")))
        A:Print("blessing key: " .. ((S:BlessMacro() ~= "" and S:BlessMacro() or "empty"):gsub("\n", " | ")))
        A:Print("cycle key: " .. ((S:CycleMacro() ~= "" and S:CycleMacro() or "empty"):gsub("\n", " | ")))
        if ns.swap and ns.isPaladin then ns.swap:Report(function(line) A:Print(line) end) end
        return
    end

    A:Print("commands: show | strip | lock | unlock | kit | options | seal <name|auto> | bless <name|auto> | reseal [on|off] | cycle [...] | swap [on|off] | pin <2h|1h|shield> [link|clear] | fury [on|off] | cd | status")
end, "/wsl", "/wseals")
