-- Wick's Seals and Things
-- Seals.lua: which seals, blessings and auras this paladin has, and
-- which of each is up right now.
--
-- All of it is read off the character. The spellbook says what exists,
-- the player's own auras say what is active, and the aura bar (the
-- shapeshift bar, which is where the client keeps paladin auras) says
-- which aura is on. Nothing here is a table of Classic facts: Forever is
-- Classic plus its own changes, and a list of seals written down would
-- be a guess about a game that keeps moving.
--
-- Nothing here tracks combat. A seal is a loadout, readable out of
-- combat, and while the client withholds auras mid-fight the strip
-- simply keeps showing the last thing it knew.

local ADDON, ns = ...
if not WickCore then return end   -- said once in Core.lua
local Core = WickCore
local D, R = Core.Dialect, Core.Restrict

local Seals = {}
ns.Seals = Seals

-- The strip has room for this many seal keys. Classic paladins have six
-- seals in total, and the keys are bindable, so the count is fixed.
Seals.MAX = 6

local function starts(name, prefix) return name:find(prefix, 1, true) == 1 end

-- ============================================================
-- The spellbook
-- ============================================================

-- One entry per spell name, ranks folded together. A spell button cast
-- by name reaches the best rank on its own.
function Seals:Scan()
    local seals, blessings, auras, judge = {}, {}, {}, nil
    local seen = {}
    for _, s in ipairs(D.SpellBookSpells()) do
        local name = s.name
        if name and not seen[name] and not s.isPassive then
            seen[name] = true
            local e = { name = name, icon = s.icon, spellID = s.spellID }
            if starts(name, "Seal of ") then
                if #seals < self.MAX then seals[#seals + 1] = e end
            elseif starts(name, "Blessing of ") or starts(name, "Greater Blessing of ") then
                blessings[#blessings + 1] = e
            elseif name:find(" Aura$") then
                auras[#auras + 1] = e
            elseif starts(name, "Judgement") and not judge then
                judge = e
            end
        end
    end
    self.seals, self.blessings, self.auras, self.judge = seals, blessings, auras, judge
    self.names = seen
    return seals
end

-- Does the character know any spell starting with this text. Asked for
-- the checklist, so a row about a reagent only appears once the spell
-- that eats it is learned.
function Seals:Knows(prefix)
    if not self.names then self:Scan() end
    for name in pairs(self.names or {}) do
        if starts(name, prefix) then return true end
    end
    return false
end

function Seals:Seal(i) return self.seals and self.seals[i] or nil end
function Seals:Count() return self.seals and #self.seals or 0 end

-- ============================================================
-- What is up
-- ============================================================

-- The first player aura the matcher accepts, or nil. The second return
-- is "restricted" while the client withholds auras, so a caller can
-- tell "none" from "would not say".
local function auraWith(matcher)
    if R:AurasBlocked() then return nil, "restricted" end
    for aura in D.IterateAuras("player", "HELPFUL") do
        if aura.name and matcher(aura.name) then return aura.name end
    end
    return nil
end

function Seals:ActiveSeal()
    local name, why = auraWith(function(n) return starts(n, "Seal of ") end)
    if why ~= "restricted" then self.lastSeal = name end
    return name, why
end

function Seals:ActiveBlessing()
    local name, why = auraWith(function(n)
        return starts(n, "Blessing of ") or starts(n, "Greater Blessing of ")
    end)
    if why ~= "restricted" then self.lastBlessing = name end
    return name, why
end

-- The aura bar first, since that is not withheld in combat, then the
-- player's auras. GetShapeshiftFormInfo names the form on the older
-- client and gives a spell id on the newer one; either is enough.
function Seals:ActiveAura()
    local get, info = rawget(_G, "GetShapeshiftForm"), rawget(_G, "GetShapeshiftFormInfo")
    if get and info then
        local ok, idx = pcall(get)
        if ok and type(idx) == "number" and idx > 0 then
            local okI, _, second, _, fourth = pcall(info, idx)
            if okI then
                if type(second) == "string" and second ~= "" then
                    self.lastAura = second
                    return second
                end
                if type(fourth) == "number" then
                    local n = D.GetSpellName(fourth)
                    if type(n) == "string" and n ~= "" then
                        self.lastAura = n
                        return n
                    end
                end
            end
        end
    end
    local name, why = auraWith(function(n) return n:find(" Aura$") ~= nil end)
    if why ~= "restricted" then self.lastAura = name end
    return name, why
end

-- ============================================================
-- The seal you fight with, and the keys built around it
-- ============================================================

local CRUSADER = "Seal of the Crusader"

local function db() return ns.db and ns.db.profile or {} end

function Seals:IconFor(name)
    if not name then return nil end
    for _, list in ipairs({ self.seals or {}, self.blessings or {}, self.auras or {} }) do
        for _, e in ipairs(list) do if e.name == name then return e.icon end end
    end
    if self.judge and self.judge.name == name then return self.judge.icon end
    local info = D.GetSpellInfo(name)
    return info and info.icon or nil
end

-- The seal the cycle ends on. Chosen by hand
-- with /wsl seal <name>, otherwise the seal that was on you the last
-- time the client would say, otherwise the first seal you know that
-- is not the Crusader, which is an opener rather than a seal to fight
-- under.
function Seals:MainSeal()
    if not self.seals then self:Scan() end
    local want = db().mainSeal
    if type(want) == "string" and want ~= "" then
        for _, e in ipairs(self.seals or {}) do
            if e.name:lower() == want:lower() then return e.name end
        end
    end
    if self.lastSeal and self.lastSeal ~= CRUSADER then return self.lastSeal end
    for _, e in ipairs(self.seals or {}) do
        if e.name ~= CRUSADER then return e.name end
    end
    local first = self.seals and self.seals[1]
    return first and first.name or nil
end

-- The blessing the key casts. Chosen with /wsl bless <name>, otherwise
-- the one that is on you, otherwise Might, otherwise the first one you
-- know. A Greater Blessing is allowed, with its reagent, if that is
-- what you name.
function Seals:MainBlessing()
    if not self.blessings then self:Scan() end
    local list = self.blessings or {}
    local want = db().blessing
    if type(want) == "string" and want ~= "" then
        for _, e in ipairs(list) do
            if e.name:lower() == want:lower() then return e.name end
        end
    end
    if self.lastBlessing then
        for _, e in ipairs(list) do if e.name == self.lastBlessing then return e.name end end
    end
    for _, e in ipairs(list) do
        if e.name == "Blessing of Might" then return e.name end
    end
    return list[1] and list[1].name or nil
end

-- On a friendly target when you have one, on yourself otherwise.
function Seals:BlessMacro()
    local b = self:MainBlessing()
    if not b then return "" end
    return ("#showtooltip %s\n/cast [help,nodead][@player] %s"):format(b, b)
end

-- The seal key, as the totem twist is for a shaman: one key, back and
-- forth. Crusader on, judge it with whatever key you judge with, then
-- the fighting seal; the next press is the Crusader again. It goes back
-- to the first step after a quiet spell about as long as a judgement
-- lasts, and when combat ends, so a new fight opens on the Crusader.
-- Set by hand with /wsl cycle a, b; off with /wsl cycle off.
function Seals:CycleSteps()
    local set = db().cycle
    if set == false then return nil end
    if type(set) == "table" and #set >= 1 then return set end
    if not self.names then self:Scan() end
    local main = self:MainSeal()
    if not main then return nil end
    if not (self.names and self.names[CRUSADER]) or main == CRUSADER then return { main } end
    return { CRUSADER, main }
end

function Seals:CycleMacro()
    local steps = self:CycleSteps()
    if not steps then return "" end
    local reset = tonumber(db().cycleReset) or 27
    return ("#showtooltip\n/castsequence reset=%d/combat %s"):format(reset, table.concat(steps, ", "))
end

-- ============================================================
-- Events
-- ============================================================

function Seals:Init()
    if self.inited then return end
    self.inited = true
    self:Scan()
    ns.RegisterEvents({ "SPELLS_CHANGED", "LEARNED_SPELL_IN_TAB", "PLAYER_ENTERING_WORLD",
                        "UNIT_AURA", "UPDATE_SHAPESHIFT_FORM", "UPDATE_SHAPESHIFT_FORMS" })
    local function relearn()
        Seals:Scan()
        if ns.UI and ns.UI.Rebuild then ns.UI:Rebuild() end
    end
    local function refresh()
        if ns.UI and ns.UI.Refresh then ns.UI:Refresh() end
    end
    ns:On("SPELLS_CHANGED", relearn)
    ns:On("LEARNED_SPELL_IN_TAB", relearn)
    ns:On("PLAYER_ENTERING_WORLD", relearn)
    ns:On("UNIT_AURA", function(_, unit) if unit == nil or unit == "player" then refresh() end end)
    ns:On("UPDATE_SHAPESHIFT_FORM", refresh)
    ns:On("UPDATE_SHAPESHIFT_FORMS", refresh)
end
