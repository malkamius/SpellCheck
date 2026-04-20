local addonName, addonTable = ...
SpellCheck = addonTable

local frame = CreateFrame("Frame")
frame:RegisterEvent("ADDON_LOADED")
frame:RegisterEvent("SPELLS_CHANGED")
frame:RegisterEvent("ACTIONBAR_SLOT_CHANGED")
frame:RegisterEvent("PLAYER_ENTERING_WORLD")
frame:RegisterEvent("UPDATE_SHAPESHIFT_FORM")
frame:RegisterEvent("UPDATE_STEALTH")

SpellCheck.highestSpells = {}
SpellCheck.downrankedSpells = {}
SpellCheck.unboundSpells = {}

-- Reagent spells and ammo-dependent skills that shouldn't be hidden when unusable
SpellCheck.ReagentSpells = {
    ["Rebirth"] = true,
    ["Gift of the Wild"] = true,
    ["Prayer of Fortitude"] = true,
    ["Prayer of Spirit"] = true,
    ["Prayer of Shadow Protection"] = true,
    ["Levitate"] = true,
    ["Arcane Brilliance"] = true,
    ["Dalaran Brilliance"] = true,
    ["Slow Fall"] = true,
    ["Create Healthstone"] = true,
    ["Create Soulstone"] = true,
    ["Create Firestone"] = true,
    ["Create Spellstone"] = true,
    ["Soul Fire"] = true,
    ["Shadowburn"] = true,
    ["Inferno"] = true,
    ["Soulshatter"] = true,
    ["Ritual of Souls"] = true,
    ["Ritual of Doom"] = true,
    ["Ritual of Summoning"] = true,
    ["Reincarnation"] = true,
    ["Water Walking"] = true,
    ["Water Breathing"] = true,
    ["Divine Intervention"] = true,
    ["Blind"] = true,
    ["Vanish"] = true,
}

local function IsReagentSpell(spellName)
    if not spellName then return false end
    if SpellCheck.ReagentSpells[spellName] then return true end
    
    -- Handle match-based categorizations (Teleports, Portals, Blessings, Hunter abilities)
    if string.match(spellName, "^Teleport:") or string.match(spellName, "^Portal:") then return true end
    if string.match(spellName, "^Greater Blessing of") then return true end
    if string.match(spellName, " Shot$") or string.match(spellName, " Sting$") then return true end
    
    return false
end

local function ParseRank(rankStr)
    if not rankStr or rankStr == "" then return 0 end
    local _, _, num = string.find(rankStr, "(%d+)")
    if num then return tonumber(num) end
    return 0
end

local function Trim(s)
    return s:match("^%s*(.-)%s*$")
end

function SpellCheck:ScanSpellbook()
    wipe(self.highestSpells)
    for tab = 1, GetNumSpellTabs() do
        local _, _, offset, numSlots = GetSpellTabInfo(tab)
        for i = offset + 1, offset + numSlots do
            local sName, sRank = GetSpellBookItemName(i, BOOKTYPE_SPELL)
            if sName then
                local sType, sId = GetSpellBookItemInfo(i, BOOKTYPE_SPELL)
                if sType == "SPELL" and not IsPassiveSpell(i, BOOKTYPE_SPELL) then
                    -- Strip any "(Rank X)" suffix from the name if the API is including it
                    local cleanName = Trim(sName:gsub("%(Rank %d+%)", ""))
                    
                    -- Get the subtext (Rank string)
                    local subtext = GetSpellSubtext(sId) or sRank
                    local rankNum = ParseRank(subtext)
                    
                    if not self.highestSpells[cleanName] or rankNum > self.highestSpells[cleanName].rankNum then
                        self.highestSpells[cleanName] = { 
                            rankNum = rankNum, 
                            spellId = sId, 
                            index = i, 
                            name = cleanName, 
                            rankStr = subtext 
                        }
                    end
                end
            end
        end
    end
end

function SpellCheck:ScanActionBars()
    wipe(self.downrankedSpells)
    wipe(self.unboundSpells)
    
    local boundSpellIDs = {}
    local slotSpells = {}
    
    for slot = 1, 120 do
        local actionType, id, subType = GetActionInfo(slot)
        if actionType == "spell" then
            local spellName = GetSpellInfo(id)
            if spellName then
                local spellRank = GetSpellSubtext(id)
                boundSpellIDs[id] = true
                table.insert(slotSpells, { slot = slot, name = Trim(spellName), rankStr = spellRank, id = id })
            end
        elseif actionType == "macro" then
            local body = GetMacroBody(id)
            if body then
                for sName, info in pairs(self.highestSpells) do
                    if string.find(body, sName, 1, true) then
                        local sPos, ePos = string.find(body, sName, 1, true)
                        local remainder = string.sub(body, ePos + 1, ePos + 20)
                        local _, _, rMatch = string.find(remainder, "^%s*%(Rank (%d+)%)")
                        if not rMatch then
                            boundSpellIDs[info.spellId] = true
                        elseif tonumber(rMatch) == info.rankNum then
                            boundSpellIDs[info.spellId] = true
                        end
                    end
                end
            end
        end
    end
    
    for sName, info in pairs(self.highestSpells) do
        if not boundSpellIDs[info.spellId] then
            local isUsable, notEnoughMana = IsUsableSpell(info.index, BOOKTYPE_SPELL)
            if isUsable or notEnoughMana or IsReagentSpell(sName) then
                table.insert(self.unboundSpells, info)
            end
        end
    end
    
    for _, item in ipairs(slotSpells) do
        local info = self.highestSpells[item.name]
        if info and item.id ~= info.spellId then
            local currentRankNum = ParseRank(item.rankStr)
            -- Only flag if it's strictly lower. If it's a different variant (rank 0 vs 0), ignore.
            if currentRankNum < info.rankNum then
                table.insert(self.downrankedSpells, {
                    slot = item.slot,
                    name = item.name,
                    oldRankStr = item.rankStr or "Base",
                    newRankStr = info.rankStr or "Max",
                    highestRankInfo = info
                })
            end
        end
    end
    
    if self.UpdateUI then
        self:UpdateUI()
    end
end

frame:SetScript("OnEvent", function(self, event, ...)
    if event == "ADDON_LOADED" then
        local arg1 = ...
        if arg1 == addonName then
            SpellCheckDB = SpellCheckDB or { minimap = { hide = false } }
            if SpellCheck.InitUI then SpellCheck:InitUI() end
            SpellCheck:ScanSpellbook()
            SpellCheck:ScanActionBars()
            self:UnregisterEvent("ADDON_LOADED")
        end
    elseif event == "SPELLS_CHANGED" then
        SpellCheck:ScanSpellbook()
        SpellCheck:ScanActionBars()
    elseif event == "ACTIONBAR_SLOT_CHANGED" or event == "PLAYER_ENTERING_WORLD" or event == "UPDATE_SHAPESHIFT_FORM" or event == "UPDATE_STEALTH" then
        SpellCheck:ScanActionBars()
    end
end)

SLASH_SPELLCHECK1 = "/sc"
SLASH_SPELLCHECK2 = "/spellcheck"
SlashCmdList["SPELLCHECK"] = function(msg)
    local cmd, arg = strsplit(" ", msg, 2)
    cmd = string.lower(cmd or "")
    if cmd == "minimap" then
        SpellCheckDB.minimap.hide = not SpellCheckDB.minimap.hide
        if SpellCheck.MinimapButton then
            if SpellCheckDB.minimap.hide then
                SpellCheck.MinimapButton:Hide()
                print("SpellCheck: Minimap button hidden.")
            else
                SpellCheck.MinimapButton:Show()
                print("SpellCheck: Minimap button shown.")
            end
        end
    else
        if SpellCheck.ToggleUI then SpellCheck:ToggleUI() end
    end
end
