local addonName, addonTable = ...
SpellCheck = addonTable

local BOOKTYPE_SPELL = _G.BOOKTYPE_SPELL or "spell"

local function GetSpellInfoCompat(spellIdentifier)
    if not spellIdentifier then return nil, nil, nil end
    if C_Spell and C_Spell.GetSpellInfo then
        local info = C_Spell.GetSpellInfo(spellIdentifier)
        if info then
            local icon = info.iconID or (C_Spell.GetSpellTexture and C_Spell.GetSpellTexture(spellIdentifier))
            return info.name, nil, icon, info.castTime, info.minRange, info.maxRange, info.spellID, info.originalIconID
        end
        return nil
    elseif _G.GetSpellInfo then
        return _G.GetSpellInfo(spellIdentifier)
    end
    return nil
end

local function GetSpellSubtextCompat(spellIdentifier)
    if not spellIdentifier then return "" end
    if C_Spell and C_Spell.GetSpellSubtext then
        return C_Spell.GetSpellSubtext(spellIdentifier) or ""
    elseif _G.GetSpellSubtext then
        return _G.GetSpellSubtext(spellIdentifier) or ""
    end
    return ""
end

local function IsSpellUsableCompat(spellIdentifier)
    if not spellIdentifier then return false, false end
    if C_Spell and C_Spell.IsSpellUsable then
        local res1, res2 = C_Spell.IsSpellUsable(spellIdentifier)
        if type(res1) == "table" then
            return res1.isUsable or false, (res1.notEnoughMana or res1.insufficientPower) or false
        end
        return res1 or false, res2 or false
    elseif _G.IsUsableSpell then
        return _G.IsUsableSpell(spellIdentifier)
    end
    return true, false
end

local function PickupSpellCompat(index, spellId)
    if C_Spell and C_Spell.PickupSpell and spellId then
        C_Spell.PickupSpell(spellId)
    elseif C_SpellBook and C_SpellBook.PickupSpellBookItem and index then
        local bank = Enum and Enum.SpellBookSpellBank and Enum.SpellBookSpellBank.Player or 0
        C_SpellBook.PickupSpellBookItem(index, bank)
    elseif _G.PickupSpellBookItem and index then
        _G.PickupSpellBookItem(index, BOOKTYPE_SPELL)
    elseif _G.PickupSpell and spellId then
        _G.PickupSpell(spellId)
    end
end

SpellCheck.GetSpellInfo = GetSpellInfoCompat
SpellCheck.GetSpellSubtext = GetSpellSubtextCompat
SpellCheck.IsSpellUsable = IsSpellUsableCompat
SpellCheck.PickupSpell = PickupSpellCompat

local frame = CreateFrame("Frame")
frame:RegisterEvent("ADDON_LOADED")
frame:RegisterEvent("SPELLS_CHANGED")
frame:RegisterEvent("ACTIONBAR_SLOT_CHANGED")
frame:RegisterEvent("PLAYER_ENTERING_WORLD")
frame:RegisterEvent("UPDATE_SHAPESHIFT_FORM")
frame:RegisterEvent("UPDATE_STEALTH")
frame:RegisterEvent("ACTIVE_TALENT_GROUP_CHANGED")

if frame.RegisterEvent then
    pcall(function() frame:RegisterEvent("PLAYER_TALENT_UPDATE") end)
    pcall(function() frame:RegisterEvent("TRAIT_CONFIG_UPDATED") end)
    pcall(function() frame:RegisterEvent("ACTIONBAR_PAGE_CHANGED") end)
    pcall(function() frame:RegisterEvent("UPDATE_BONUS_ACTIONBAR") end)
end

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
    if not s then return "" end
    return s:match("^%s*(.-)%s*$") or ""
end

function SpellCheck:ScanSpellbook()
    wipe(self.highestSpells)
    
    if C_SpellBook and C_SpellBook.GetNumSpellBookSkillLines then
        local numSkillLines = C_SpellBook.GetNumSpellBookSkillLines()
        local spellBank = (Enum and Enum.SpellBookSpellBank and Enum.SpellBookSpellBank.Player) or 0
        
        for skillLineIndex = 1, numSkillLines do
            local skillLineInfo = C_SpellBook.GetSpellBookSkillLineInfo(skillLineIndex)
            if skillLineInfo and not skillLineInfo.shouldHide and skillLineInfo.numSpellBookItems and skillLineInfo.numSpellBookItems > 0 then
                local offset = skillLineInfo.itemIndexOffset or 0
                for i = 1, skillLineInfo.numSpellBookItems do
                    local spellIndex = offset + i
                    local itemType, actionID, spellID = C_SpellBook.GetSpellBookItemType(spellIndex, spellBank)
                    local isSpell = (Enum and Enum.SpellBookItemType and itemType == Enum.SpellBookItemType.Spell) or itemType == 1 or itemType == "SPELL"
                    local isPassive = C_SpellBook.IsSpellBookItemPassive and C_SpellBook.IsSpellBookItemPassive(spellIndex, spellBank)
                    local sId = spellID or (isSpell and actionID)
                    
                    if isSpell and not isPassive and sId then
                        local sName, sRank
                        if C_SpellBook.GetSpellBookItemName then
                            sName, sRank = C_SpellBook.GetSpellBookItemName(spellIndex, spellBank)
                        end
                        if not sName then
                            sName = GetSpellInfoCompat(sId)
                        end
                        
                        if sName then
                            local cleanName = Trim(sName:gsub("%(Rank %d+%)", ""))
                            local subtext = GetSpellSubtextCompat(sId)
                            if subtext == "" and sRank then
                                subtext = sRank
                            end
                            local rankNum = ParseRank(subtext)
                            
                            if not self.highestSpells[cleanName] or rankNum > self.highestSpells[cleanName].rankNum then
                                self.highestSpells[cleanName] = {
                                    rankNum = rankNum,
                                    spellId = sId,
                                    index = spellIndex,
                                    name = cleanName,
                                    rankStr = subtext
                                }
                            end
                        end
                    end
                end
            end
        end
    elseif _G.GetNumSpellTabs then
        for tab = 1, GetNumSpellTabs() do
            local _, _, offset, numSlots = GetSpellTabInfo(tab)
            for i = offset + 1, offset + numSlots do
                local sName, sRank = GetSpellBookItemName(i, BOOKTYPE_SPELL)
                if sName then
                    local sType, sId = GetSpellBookItemInfo(i, BOOKTYPE_SPELL)
                    if sType == "SPELL" and not IsPassiveSpell(i, BOOKTYPE_SPELL) then
                        local cleanName = Trim(sName:gsub("%(Rank %d+%)", ""))
                        local subtext = GetSpellSubtextCompat(sId)
                        if subtext == "" and sRank then
                            subtext = sRank
                        end
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
end

function SpellCheck:ScanActionBars()
    wipe(self.downrankedSpells)
    wipe(self.unboundSpells)
    
    local boundSpellIDs = {}
    local slotSpells = {}
    
    for slot = 1, 180 do
        local actionType, id, subType = GetActionInfo(slot)
        if actionType == "spell" then
            local spellName = GetSpellInfoCompat(id)
            if spellName then
                local spellRank = GetSpellSubtextCompat(id)
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
            if GetMacroSpell then
                local macroSpell = GetMacroSpell(id)
                if macroSpell then
                    local mId = type(macroSpell) == "number" and macroSpell or nil
                    if mId then
                        boundSpellIDs[mId] = true
                    end
                end
            end
        end
    end
    
    for sName, info in pairs(self.highestSpells) do
        if not boundSpellIDs[info.spellId] then
            local isUsable, notEnoughMana = IsSpellUsableCompat(info.spellId)
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
    elseif event == "SPELLS_CHANGED" or event == "PLAYER_ENTERING_WORLD" or event == "ACTIVE_TALENT_GROUP_CHANGED" or event == "PLAYER_TALENT_UPDATE" or event == "TRAIT_CONFIG_UPDATED" then
        SpellCheck:ScanSpellbook()
        SpellCheck:ScanActionBars()
    elseif event == "ACTIONBAR_SLOT_CHANGED" or event == "UPDATE_SHAPESHIFT_FORM" or event == "UPDATE_STEALTH" or event == "ACTIONBAR_PAGE_CHANGED" or event == "UPDATE_BONUS_ACTIONBAR" then
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

function SpellCheck_OnAddonCompartmentClick()
    SpellCheck:ToggleUI()
end

function SpellCheck_OnAddonCompartmentEnter(button)
    GameTooltip:SetOwner(button, "ANCHOR_LEFT")
    GameTooltip:AddLine("SpellCheck")
    GameTooltip:AddLine("Left-Click: Toggle Panel", 1, 1, 1)
    GameTooltip:Show()
end

function SpellCheck_OnAddonCompartmentLeave()
    GameTooltip:Hide()
end
