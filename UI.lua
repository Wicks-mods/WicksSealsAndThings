-- Wick's Seals and Things
-- UI.lua: the seal strip.
--
-- One 30px row: a key per seal you know, a Judgement key, the seal
-- cycle key, two lines saying what is up, and the two weapon swap keys.
-- The seal that is on you is ringed in fel green.
--
-- Every key is a SecureActionButton, which is the only way an addon may
-- cast anything or equip anything. Their attributes are rewritten out of
-- combat only; in combat they keep whatever they were last given, which
-- is the right answer anyway since a seal is a seal.

local ADDON, ns = ...
if not WickCore then return end   -- said once in Core.lua
local Core = WickCore
local Chrome, R, D = Core.Chrome, Core.Restrict, Core.Dialect
local C = Chrome.Colors

local UI = {}
ns.UI = UI

local QUESTION = "Interface\\Icons\\INV_Misc_QuestionMark"
local DIM = { 0.35, 0.33, 0.40, 1 }

local STRIP_H = 30
local BTN     = 26
local LABEL_W = 104
local PAD     = 4

local function tint(fs, c) fs:SetTextColor(c[1], c[2], c[3], c[4] or 1) end

-- ============================================================
-- Building
-- ============================================================

local function makeSecure(parent, name, kind)
    local b = CreateFrame("Button", name, parent, "SecureActionButtonTemplate")
    b:SetSize(BTN, BTN)
    b:SetAttribute("type", kind)
    b:SetAttribute("type1", kind)
    b:RegisterForClicks("AnyUp", "AnyDown")
    b.icon = b:CreateTexture(nil, "ARTWORK")
    b.icon:SetPoint("TOPLEFT", 2, -2)
    b.icon:SetPoint("BOTTOMRIGHT", -2, 2)
    b.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
    -- The lit ring for the seal that is on you. A border of our own
    -- rather than Blizzard's, so it takes the theme.
    b.ring = {}
    for _, p in ipairs({ { "TOPLEFT", "TOPRIGHT", nil, 1 }, { "BOTTOMLEFT", "BOTTOMRIGHT", nil, 1 },
                         { "TOPLEFT", "BOTTOMLEFT", 1, nil }, { "TOPRIGHT", "BOTTOMRIGHT", 1, nil } }) do
        local t = Chrome:Texture(b, "OVERLAY", C.border)
        t:SetPoint(p[1]); t:SetPoint(p[2])
        if p[3] then t:SetWidth(p[3]) end
        if p[4] then t:SetHeight(p[4]) end
        b.ring[#b.ring + 1] = t
    end
    b.hl = b:CreateTexture(nil, "HIGHLIGHT")
    b.hl:SetAllPoints()
    b.hl:SetColorTexture(1, 1, 1, 0.10)
    b:SetScript("OnLeave", function() GameTooltip:Hide() end)
    return b
end

local function ringColor(b, c)
    for _, t in ipairs(b.ring) do t:SetColorTexture(c[1], c[2], c[3], c[4] or 1) end
end

local function grey(line) return 0.5, 0.5, 0.5, true end

-- Each of the two swap keys. The icon is the piece that key puts in
-- your hands; the fel edge means that set is already on.
local function makeSwap(parent, which, name)
    local b = CreateFrame("Button", name, parent, "SecureActionButtonTemplate")
    b:SetSize(BTN, BTN)
    b:RegisterForClicks("AnyUp", "AnyDown")
    ns.swap:RegisterButton(which, b)
    b.icon = b:CreateTexture(nil, "ARTWORK")
    b.icon:SetPoint("TOPLEFT", 2, -2)
    b.icon:SetPoint("BOTTOMRIGHT", -2, 2)
    b.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
    b.live = Chrome:Texture(b, "OVERLAY", C.fel)
    b.live:SetPoint("BOTTOMLEFT", 1, 1)
    b.live:SetPoint("BOTTOMRIGHT", -1, 1)
    b.live:SetHeight(2)
    b.live:Hide()
    b.hl = b:CreateTexture(nil, "HIGHLIGHT")
    b.hl:SetAllPoints()
    b.hl:SetColorTexture(1, 1, 1, 0.10)
    b:SetScript("OnEnter", function(s)
        GameTooltip:SetOwner(s, "ANCHOR_TOP")
        local faces = ns.swap:Faces()
        local face = faces and faces[which]
        GameTooltip:SetText(which == "twoHand" and "Two-hander" or "Sword and board", 1, 1, 1)
        if not face then
            GameTooltip:AddLine(tostring(ns.swap:Why(which) or "nothing to swap"), grey())
        else
            local name = D.GetItemNameByID(face.id) or "that piece"
            if which == "twoHand" then
                GameTooltip:AddLine(name .. " to your main hand.", 0.8, 0.8, 0.8, true)
            else
                local weapon = D.GetItemNameByID(face.weapon) or "your one-hander"
                GameTooltip:AddLine(weapon .. " and " .. name .. ".", 0.8, 0.8, 0.8, true)
            end
            if face.live then GameTooltip:AddLine("Already on.", grey()) end
            GameTooltip:AddLine("Costs a swing. /wsl pin to choose a piece by hand.", grey())
        end
        GameTooltip:Show()
    end)
    b:SetScript("OnLeave", function() GameTooltip:Hide() end)
    return b
end

function UI:BuildStrip()
    if self.strip then return self.strip end
    local db = ns.db and ns.db.profile

    local f = CreateFrame("Frame", "WicksSealsStrip", UIParent)
    self.strip = f
    f:SetSize(200, STRIP_H)
    f:SetPoint("CENTER", 0, -200)
    f:SetFrameStrata("MEDIUM")
    f:SetMovable(true)
    f:SetClampedToScreen(true)
    f:EnableMouse(true)
    f:RegisterForDrag("LeftButton")
    f:SetScript("OnDragStart", function(s)
        -- A lock stops a nudge, not a deliberate move: shift overrides it.
        if Chrome:DragAllowed(db and db.stripLocked) then s:StartMoving() end
    end)
    f:SetScript("OnDragStop", function(s)
        s:StopMovingOrSizing()
        if db then db.strip = db.strip or {}; Chrome:SavePosition(s, db.strip) end
    end)
    if db and db.strip and db.strip.point then Chrome:RestorePosition(f, db.strip) end
    if ns.A.RegisterMovable then
        ns.A:RegisterMovable(f, { key = "WicksSealsStrip", title = "Seal strip" })
    end

    local bg = Chrome:Texture(f, "BACKGROUND", C.voidBG); bg:SetAllPoints()
    Chrome:AddBorder(f)

    -- A key per seal. All six exist from the start, since a protected
    -- button cannot be made mid-fight; the ones for seals you do not
    -- know yet stay hidden.
    f.seal = {}
    for i = 1, ns.Seals.MAX do
        local b = makeSecure(f, "WicksSealsButton" .. i, "spell")
        b.index = i
        b:SetScript("OnEnter", function(s)
            local e = ns.Seals:Seal(s.index)
            if not e then return end
            GameTooltip:SetOwner(s, "ANCHOR_TOP")
            GameTooltip:SetText(e.name, 1, 1, 1)
            local active = ns.Seals.lastSeal
            if active == e.name then
                GameTooltip:AddLine("On you.", C.fel[1], C.fel[2], C.fel[3])
            else
                GameTooltip:AddLine("Click to seal.", grey())
            end
            if ns.Seals:MainSeal() == e.name then
                GameTooltip:AddLine("Judgement reseals with this one.", grey())
            end
            GameTooltip:Show()
        end)
        b:Hide()
        f.seal[i] = b
    end

    -- Judgement, which reseals after it when asked to.
    f.judge = makeSecure(f, "WicksSealsJudgeButton", "macro")
    f.judge:SetScript("OnEnter", function(s)
        GameTooltip:SetOwner(s, "ANCHOR_TOP")
        local j = ns.Seals.judge
        GameTooltip:SetText(j and j.name or "Judgement", 1, 1, 1)
        if not j then
            GameTooltip:AddLine("Not learned yet.", grey())
        elseif ns.db and ns.db.profile.reseal ~= false then
            GameTooltip:AddLine(("Judges, then puts %s back on. If the judgement takes the global cooldown, the second press reseals.")
                :format(ns.Seals:MainSeal() or "your seal"), 0.8, 0.8, 0.8, true)
            GameTooltip:AddLine("/wsl reseal off to judge alone; /wsl seal <name> to choose the seal.", grey())
        else
            GameTooltip:AddLine("Judges. /wsl reseal on to put the seal back after.", grey())
        end
        GameTooltip:Show()
    end)

    -- The cycle key: a castsequence through the seal dance.
    f.cycle = makeSecure(f, "WicksSealsCycleButton", "macro")
    f.cycle:SetScript("OnEnter", function(s)
        GameTooltip:SetOwner(s, "ANCHOR_TOP")
        GameTooltip:SetText("Seal cycle", 1, 1, 1)
        local steps = ns.Seals:CycleSteps()
        if not steps then
            GameTooltip:AddLine(ns.db and ns.db.profile.cycle == false and "Off. /wsl cycle auto turns it on."
                or "Needs Seal of the Crusader and Judgement.", grey())
        else
            GameTooltip:AddLine("One press per step: " .. table.concat(steps, ", ") .. ".", 0.8, 0.8, 0.8, true)
            GameTooltip:AddLine(("Starts over on a new target or after %d seconds. /wsl cycle to change it.")
                :format((ns.db and ns.db.profile.cycleReset) or 15), grey())
        end
        GameTooltip:Show()
    end)

    -- The blessing key: a friendly target if you have one, you if not.
    f.bless = makeSecure(f, "WicksSealsBlessButton", "macro")
    f.bless:SetScript("OnEnter", function(s)
        GameTooltip:SetOwner(s, "ANCHOR_TOP")
        local b = ns.Seals:MainBlessing()
        GameTooltip:SetText(b or "Blessing", 1, 1, 1)
        if not b then
            GameTooltip:AddLine("No blessing learned yet.", grey())
        else
            if ns.Seals.lastBlessing == b then
                GameTooltip:AddLine("On you.", C.fel[1], C.fel[2], C.fel[3])
            end
            GameTooltip:AddLine("Casts on a friendly target, or on you with none.", 0.8, 0.8, 0.8, true)
            GameTooltip:AddLine("/wsl bless <name> to choose the blessing.", grey())
        end
        GameTooltip:Show()
    end)

    f.div1 = Chrome:Texture(f, "ARTWORK", C.border); f.div1:SetWidth(1)
    f.div2 = Chrome:Texture(f, "ARTWORK", C.border); f.div2:SetWidth(1)

    f.sealText = Chrome:Text(f, 11)
    f.sealText:SetJustifyH("LEFT")
    f.sealText:SetWordWrap(false)
    f.auraText = Chrome:Text(f, 9, C.muted)
    f.auraText:SetJustifyH("LEFT")
    f.auraText:SetWordWrap(false)

    if ns.swap and ns.swap:Shown() then
        f.swapTwo = makeSwap(f, "twoHand", "WicksSealsTwoHandButton")
        f.swapShield = makeSwap(f, "shield", "WicksSealsShieldButton")
    end

    -- Right-click anywhere on the strip opens the kit, matching the other
    -- kits' launcher. The keys are secure, so their right-click goes
    -- through the strip underneath rather than through them.
    f:SetScript("OnMouseUp", function(_, btn)
        if btn == "RightButton" then ns.A.kit:Toggle() end
    end)

    f:SetScript("OnShow", function() UI:Refresh() end)
    R:OnChange(function() if f:IsShown() then UI:Refresh() end end)

    self:Rebuild()
    return f
end

-- ============================================================
-- Layout and attributes
-- ============================================================
-- Out of combat only: this shows and hides protected buttons and
-- writes their attributes. In combat the request is kept and honoured
-- the moment the fight ends.

function UI:Rebuild()
    local f = self.strip
    if not f then return end
    if InCombatLockdown and InCombatLockdown() then
        self.rebuildStale = true
        return
    end
    self.rebuildStale = nil

    local x = PAD
    local n = ns.Seals:Count()
    for i = 1, ns.Seals.MAX do
        local b, e = f.seal[i], ns.Seals:Seal(i)
        if e then
            b:SetAttribute("spell", e.name)
            b:SetAttribute("spell1", e.name)
            b:ClearAllPoints()
            b:SetPoint("LEFT", x, 0)
            b:Show()
            x = x + BTN + 2
        else
            b:SetAttribute("spell", "")
            b:SetAttribute("spell1", "")
            b:Hide()
        end
    end

    local j = ns.Seals:JudgeMacro()
    f.judge:SetAttribute("macrotext", j)
    f.judge:SetAttribute("macrotext1", j)
    f.judge:ClearAllPoints()
    f.judge:SetPoint("LEFT", x, 0)
    x = x + BTN + 2

    local cy = ns.Seals:CycleMacro()
    f.cycle:SetAttribute("macrotext", cy)
    f.cycle:SetAttribute("macrotext1", cy)
    f.cycle:ClearAllPoints()
    f.cycle:SetPoint("LEFT", x, 0)
    x = x + BTN + 2

    local bl = ns.Seals:BlessMacro()
    f.bless:SetAttribute("macrotext", bl)
    f.bless:SetAttribute("macrotext1", bl)
    f.bless:ClearAllPoints()
    f.bless:SetPoint("LEFT", x, 0)
    x = x + BTN + 2

    f.div1:ClearAllPoints()
    f.div1:SetPoint("TOP", f, "TOPLEFT", x, -2)
    f.div1:SetPoint("BOTTOM", f, "BOTTOMLEFT", x, 2)
    x = x + 1 + PAD

    f.sealText:ClearAllPoints()
    f.sealText:SetPoint("LEFT", f, "LEFT", x, 5)
    f.sealText:SetWidth(LABEL_W)
    f.auraText:ClearAllPoints()
    f.auraText:SetPoint("LEFT", f, "LEFT", x, -6)
    f.auraText:SetWidth(LABEL_W)
    x = x + LABEL_W + PAD

    if f.swapTwo then
        f.div2:Show()
        f.div2:ClearAllPoints()
        f.div2:SetPoint("TOP", f, "TOPLEFT", x, -2)
        f.div2:SetPoint("BOTTOM", f, "BOTTOMLEFT", x, 2)
        x = x + 1 + PAD
        f.swapTwo:ClearAllPoints()
        f.swapTwo:SetPoint("LEFT", x, 0)
        x = x + BTN + 2
        f.swapShield:ClearAllPoints()
        f.swapShield:SetPoint("LEFT", x, 0)
        x = x + BTN + 2
    else
        f.div2:Hide()
    end

    f:SetWidth(x + PAD - 2)
    self:Refresh()
end

-- ============================================================
-- Painting
-- ============================================================

function UI:Refresh()
    local f = self.strip
    if not f or not f:IsShown() then return end
    if self.rebuildStale then self:Rebuild() return end

    local seal, sealWhy = ns.Seals:ActiveSeal()
    local aura, auraWhy = ns.Seals:ActiveAura()
    -- While the client withholds auras the strip keeps the last thing
    -- it knew rather than going blank mid-fight.
    if sealWhy == "restricted" then seal = ns.Seals.lastSeal end
    if auraWhy == "restricted" then aura = ns.Seals.lastAura end

    for i = 1, ns.Seals.MAX do
        local b, e = f.seal[i], ns.Seals:Seal(i)
        if e then
            b.icon:SetTexture(e.icon or QUESTION)
            ringColor(b, (seal == e.name) and C.fel or C.border)
        end
    end

    local j = ns.Seals.judge
    f.judge.icon:SetTexture(j and j.icon or QUESTION)
    f.judge.icon:SetDesaturated(j == nil)
    f.judge.icon:SetAlpha(j and 1 or 0.35)
    ringColor(f.judge, C.border)

    local steps = ns.Seals:CycleSteps()
    local first = steps and ns.Seals:IconFor(steps[1])
    f.cycle.icon:SetTexture(first or (j and j.icon) or QUESTION)
    f.cycle.icon:SetDesaturated(steps == nil)
    f.cycle.icon:SetAlpha(steps and 1 or 0.35)
    ringColor(f.cycle, C.border)

    local bless, blessWhy = ns.Seals:ActiveBlessing()
    if blessWhy == "restricted" then bless = ns.Seals.lastBlessing end
    local chosen = ns.Seals:MainBlessing()
    f.bless.icon:SetTexture(ns.Seals:IconFor(chosen) or QUESTION)
    f.bless.icon:SetDesaturated(chosen == nil)
    f.bless.icon:SetAlpha(chosen and 1 or 0.35)
    ringColor(f.bless, (chosen and bless == chosen) and C.fel or C.border)

    f.sealText:SetText(seal or "no seal")
    tint(f.sealText, seal and C.text or DIM)
    f.auraText:SetText(aura or "no aura")
    tint(f.auraText, aura and C.muted or DIM)

    self:RefreshSwap()
end

-- Icons and the live edge only. Nothing here shows, hides or moves a
-- protected frame, so it is safe to run mid-fight.
function UI:RefreshSwap()
    local f = self.strip
    if not (f and f.swapTwo) then return end
    local faces = ns.swap and ns.swap:Faces()
    for which, b in pairs({ twoHand = f.swapTwo, shield = f.swapShield }) do
        local face = faces and faces[which]
        b.icon:SetTexture(face and face.icon or QUESTION)
        -- A set it cannot make goes grey rather than disappearing, so
        -- the strip does not change shape on you.
        b.icon:SetDesaturated(face == nil)
        b.icon:SetAlpha(face and 1 or 0.35)
        b.live:SetShown(face ~= nil and face.live == true)
    end
end

-- ============================================================
-- Showing and hiding
-- ============================================================

function UI:ApplyStripVisibility()
    local db = ns.db and ns.db.profile
    local want = ns.isPaladin and db and db.showStrip ~= false
    if want then
        self:BuildStrip()
        self.strip:Show()
        self:Refresh()
    elseif self.strip then
        self.strip:Hide()
    end
end

function UI:SetStripLocked(locked)
    local db = ns.db and ns.db.profile
    if db then db.stripLocked = locked and true or false end
    ns.A:Print(locked and "strip locked." or "strip unlocked: drag it into place, then /wsl lock.")
end

function UI:Toggle()
    local db = ns.db and ns.db.profile
    if not db then return end
    if not ns.isPaladin then
        ns.A:Print("the seal strip is for paladins. /wsl kit has the talents and checklist.")
        return
    end
    db.showStrip = not (db.showStrip ~= false)
    self:ApplyStripVisibility()
end

function UI:Init()
    self:ApplyStripVisibility()
    -- Attributes could not be written while the character was in combat
    -- at login; write them the moment that clears.
    ns.RegisterEvents({ "PLAYER_REGEN_ENABLED" })
    ns:On("PLAYER_REGEN_ENABLED", function()
        if UI.rebuildStale then UI:Rebuild() end
    end)
end
