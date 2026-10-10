local addonName, addonTable = ...
local SpellCheck = addonTable

local MainFrame = nil
local CurrentTab = 1
local ListFrames = {}

local function CreateMinimapButton()
    local btn = CreateFrame("Button", "SpellCheckMinimapButton", Minimap)
    btn:SetSize(32, 32)
    btn:SetFrameLevel(8)
    btn:RegisterForClicks("AnyUp")
    btn:SetMovable(true)
    
    local icon = btn:CreateTexture(nil, "BACKGROUND")
    icon:SetTexture("Interface\\Icons\\Spell_Holy_MagicalSentry")
    icon:SetSize(20, 20)
    icon:SetPoint("CENTER", 0, 0)
    
    local border = btn:CreateTexture(nil, "OVERLAY")
    border:SetTexture("Interface\\Minimap\\MiniMap-TrackingBorder")
    border:SetSize(54, 54)
    border:SetPoint("TOPLEFT")
    
    btn:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_LEFT")
        GameTooltip:AddLine("SpellCheck")
        GameTooltip:AddLine("Left-Click: Toggle Panel", 1, 1, 1)
        GameTooltip:AddLine("Right-Click: Options Help", 1, 1, 1)
        GameTooltip:Show()
    end)
    btn:SetScript("OnLeave", function(self)
        GameTooltip:Hide()
    end)

    btn:SetScript("OnClick", function(self, button)
        if button == "RightButton" then
            print("SpellCheck: Usage:")
            print("/sc - Toggle Main Window")
            print("/sc minimap - Toggle Minimap Button")
        else
            SpellCheck:ToggleUI()
        end
    end)
    
    btn:SetPoint("TOPLEFT", Minimap, "TOPLEFT", -5, -5)
    
    SpellCheck.MinimapButton = btn
    
    if SpellCheckDB.minimap.hide then
        btn:Hide()
    end
end

local function UpgradeSpell(oldSlot, newSpellId, newSpellIndex)
    if InCombatLockdown() then
        print("SpellCheck: Cannot upgrade spells while in combat.")
        return
    end
    SpellCheck.PickupSpell(newSpellIndex, newSpellId)
    PlaceAction(oldSlot)
    ClearCursor()
    -- Force rescan so UI updates immediately
    SpellCheck:ScanActionBars()
end

local function UpgradeAllSpells()
    if InCombatLockdown() then
        print("SpellCheck: Cannot upgrade spells while in combat.")
        return
    end
    for _, info in ipairs(SpellCheck.downrankedSpells) do
        SpellCheck.PickupSpell(info.highestRankInfo.index, info.highestRankInfo.spellId)
        PlaceAction(info.slot)
        ClearCursor()
    end
    -- Force rescan so UI updates immediately
    SpellCheck:ScanActionBars()
end

local function UpdateList()
    if not MainFrame:IsShown() then return end
    
    if MainFrame.UpgradeAllBtn then
        if CurrentTab == 1 then
            MainFrame.UpgradeAllBtn:Show()
        else
            MainFrame.UpgradeAllBtn:Hide()
        end
    end

    for _, f in ipairs(ListFrames) do f:Hide() end
    
    local data = CurrentTab == 1 and SpellCheck.downrankedSpells or SpellCheck.unboundSpells
    local scrollContent = MainFrame.ScrollFrame.Content
    
    for i, info in ipairs(data) do
        local f = ListFrames[i]
        if not f then
            f = CreateFrame("Button", nil, scrollContent)
            f:SetSize(340, 40)
            f:SetPoint("TOPLEFT", 5, -(i-1)*45)
            
            f.icon = f:CreateTexture(nil, "ARTWORK")
            f.icon:SetSize(32, 32)
            f.icon:SetPoint("LEFT", 0, 0)
            
            f.nameText = f:CreateFontString(nil, "OVERLAY", "GameFontNormal")
            f.nameText:SetPoint("LEFT", f.icon, "RIGHT", 10, 0)
            f.nameText:SetWidth(180)
            f.nameText:SetJustifyH("LEFT")
            
            f.actionBtn = CreateFrame("Button", nil, f, "UIPanelButtonTemplate")
            f.actionBtn:SetSize(80, 22)
            f.actionBtn:SetPoint("RIGHT", 0, 0)
            
            ListFrames[i] = f
        end
        f:Show()
        
        if CurrentTab == 1 then
            local spellName, _, spellIcon = SpellCheck.GetSpellInfo(info.highestRankInfo.spellId)
            if spellIcon then f.icon:SetTexture(spellIcon) end
            f.nameText:SetText(info.name .. " (S" .. info.slot .. "): " .. (info.oldRankStr or "None") .. " -> " .. (info.newRankStr or "None"))
            f.actionBtn:SetText("Upgrade")
            f.actionBtn:SetScript("OnClick", function() UpgradeSpell(info.slot, info.highestRankInfo.spellId, info.highestRankInfo.index) end)
        else
            local spellName, _, spellIcon = SpellCheck.GetSpellInfo(info.spellId)
            if spellIcon then f.icon:SetTexture(spellIcon) end
            f.nameText:SetText(info.name .. " " .. (info.rankStr or ""))
            f.actionBtn:SetText("Pickup")
            f.actionBtn:SetScript("OnClick", function() 
                if InCombatLockdown() then return end
                SpellCheck.PickupSpell(info.index, info.spellId) 
            end)
        end
    end

    scrollContent:SetHeight(#data * 45)
end

function SpellCheck:InitUI()
    if MainFrame then return end
    
    CreateMinimapButton()
    
    MainFrame = CreateFrame("Frame", "SpellCheckMainFrame", UIParent, "BasicFrameTemplateWithInset")
    MainFrame:SetSize(400, 500)
    MainFrame:SetPoint("CENTER")
    MainFrame:Hide()
    MainFrame:SetMovable(true)
    MainFrame:EnableMouse(true)
    MainFrame:RegisterForDrag("LeftButton")
    MainFrame:SetScript("OnDragStart", MainFrame.StartMoving)
    MainFrame:SetScript("OnDragStop", MainFrame.StopMovingOrSizing)
    
    MainFrame.title = MainFrame:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    MainFrame.title:SetPoint("CENTER", MainFrame.TitleBg, "CENTER", 0, 0)
    MainFrame.title:SetText("SpellCheck")

    -- Scroll Frame Setup
    local scrollFrame = CreateFrame("ScrollFrame", nil, MainFrame, "UIPanelScrollFrameTemplate")
    scrollFrame:SetPoint("TOPLEFT", MainFrame, "TOPLEFT", 10, -30)
    scrollFrame:SetPoint("BOTTOMRIGHT", MainFrame, "BOTTOMRIGHT", -30, 40)
    MainFrame.ScrollFrame = scrollFrame

    local scrollContent = CreateFrame("Frame", nil, scrollFrame)
    scrollContent:SetSize(340, 1)
    scrollContent:SetPoint("TOPLEFT", 0, 0) -- Ensure content starts at top left
    scrollFrame:SetScrollChild(scrollContent)
    scrollFrame.Content = scrollContent
    
    local tabTemplate = PanelTemplates_AnchorTabs and "PanelTabButtonTemplate" or "CharacterFrameTabButtonTemplate"
    
    local tab1 = CreateFrame("Button", "SpellCheckMainFrameTab1", MainFrame, tabTemplate)
    tab1:SetID(1)
    tab1:SetPoint("TOPLEFT", MainFrame, "BOTTOMLEFT", 10, 2)
    tab1:SetText("Downranked")
    if PanelTemplates_TabResize then PanelTemplates_TabResize(tab1, 0) end
    tab1:SetScript("OnClick", function(self) 
        CurrentTab = 1
        PanelTemplates_SetTab(MainFrame, 1)
        UpdateList() 
    end)
    
    local tab2 = CreateFrame("Button", "SpellCheckMainFrameTab2", MainFrame, tabTemplate)
    tab2:SetID(2)
    tab2:SetText("Unbound")
    if PanelTemplates_TabResize then PanelTemplates_TabResize(tab2, 0) end
    if not PanelTemplates_AnchorTabs then
        tab2:SetPoint("LEFT", tab1, "RIGHT", -16, 0)
    end
    tab2:SetScript("OnClick", function(self) 
        CurrentTab = 2
        PanelTemplates_SetTab(MainFrame, 2)
        UpdateList() 
    end)
    
    MainFrame.Tabs = { tab1, tab2 }
    PanelTemplates_SetNumTabs(MainFrame, 2)
    PanelTemplates_SetTab(MainFrame, 1)
    
    local upgradeAllBtn = CreateFrame("Button", nil, MainFrame, "UIPanelButtonTemplate")
    upgradeAllBtn:SetSize(100, 22)
    upgradeAllBtn:SetPoint("BOTTOM", MainFrame, "BOTTOM", 0, 10) -- Centered at the bottom
    upgradeAllBtn:SetText("Upgrade All")
    upgradeAllBtn:SetScript("OnClick", function() UpgradeAllSpells() end)
    MainFrame.UpgradeAllBtn = upgradeAllBtn
    
    MainFrame:SetScript("OnShow", function() 
        PanelTemplates_SetTab(MainFrame, CurrentTab)
        UpdateList() 
    end)
    
    self.UpdateUI = UpdateList
end

function SpellCheck:ToggleUI()
    if not MainFrame then self:InitUI() end
    if MainFrame:IsShown() then
        MainFrame:Hide()
    else
        SpellCheck:ScanSpellbook()
        SpellCheck:ScanActionBars()
        MainFrame:Show()
        UpdateList()
    end
end
