local addonName, addonTable = ...
local L = addonTable.L

addonTable.tooltips = {}
addonTable.isShowing = false
addonTable.currentUnit = nil
addonTable.isCentered = false
addonTable.savedPoints = {}

-- =========================================================================
-- Safe Modern API Wrappers (Supports Modern Mainline / WoW Forever & Classic)
-- =========================================================================
local function SafeGetItemInfo(item)
    if not item then return nil end
    if C_Item and C_Item.GetItemInfo then
        return C_Item.GetItemInfo(item)
    elseif GetItemInfo then
        return GetItemInfo(item)
    end
    return nil
end

local function SafeGetDetailedItemLevelInfo(item)
    if not item then return nil end
    if C_Item and C_Item.GetDetailedItemLevelInfo then
        return C_Item.GetDetailedItemLevelInfo(item)
    elseif GetDetailedItemLevelInfo then
        return GetDetailedItemLevelInfo(item)
    end
    return nil
end

local function SafeGetInventoryItemLink(unit, slotId)
    if GetInventoryItemLink then
        local link = GetInventoryItemLink(unit, slotId)
        if link then return link end
    end
    if C_Item and C_Item.GetInventoryItemLink then
        local ok, link = pcall(C_Item.GetInventoryItemLink, unit, slotId)
        if ok and link then return link end
    end
    if unit == "player" and ItemLocation and ItemLocation.CreateFromEquipmentSlot and C_Item and C_Item.GetItemLink then
        local ok, loc = pcall(ItemLocation.CreateFromEquipmentSlot, ItemLocation, slotId)
        if ok and loc and loc:IsValid() and C_Item.DoesItemExist(loc) then
            local ok2, link = pcall(C_Item.GetItemLink, loc)
            if ok2 and link then return link end
        end
    end
    return nil
end

local function SafeGetItemQuality(unit, slotId, itemLink)
    -- 1. Try C_Item / GetInventoryItemQuality
    if C_Item and C_Item.GetInventoryItemQuality then
        local q = C_Item.GetInventoryItemQuality(unit, slotId)
        if q ~= nil then return q end
    elseif GetInventoryItemQuality then
        local q = GetInventoryItemQuality(unit, slotId)
        if q ~= nil then return q end
    end

    -- 2. Try C_Item.GetItemQualityByID
    if itemLink and C_Item and C_Item.GetItemQualityByID then
        local q = C_Item.GetItemQualityByID(itemLink)
        if q ~= nil then return q end
    end

    -- 3. Try SafeGetItemInfo
    if itemLink then
        local q = select(3, SafeGetItemInfo(itemLink))
        if q ~= nil then return q end

        -- 4. Extract from link color hex |cffRRGGBB
        local hex = itemLink:match("|cff(%x%x%x%x%x%x)")
        if hex then
            hex = hex:lower()
            if hex == "9d9d9d" then return 0      -- Poor
            elseif hex == "ffffff" then return 1  -- Common
            elseif hex == "1eff00" then return 2  -- Uncommon
            elseif hex == "0070dd" then return 3  -- Rare
            elseif hex == "a335ee" then return 4  -- Epic
            elseif hex == "ff8000" then return 5  -- Legendary
            elseif hex == "e6cc80" then return 6  -- Artifact
            elseif hex == "00ccff" then return 7  -- Heirloom
            end
        end
    end
    return nil
end

local function SafeGetItemQualityColor(quality, itemLink)
    if quality ~= nil then
        if C_Item and C_Item.GetItemQualityColor then
            local res1, res2, res3 = C_Item.GetItemQualityColor(quality)
            if type(res1) == "table" and res1.r and res1.g and res1.b then
                return res1.r, res1.g, res1.b
            elseif type(res1) == "number" and type(res2) == "number" and type(res3) == "number" then
                return res1, res2, res3
            end
        end
        if GetItemQualityColor then
            local r, g, b = GetItemQualityColor(quality)
            if r and g and b then return r, g, b end
        end
    end

    -- Link color fallback (|cffRRGGBB)
    if itemLink then
        local hex = itemLink:match("|cff(%x%x%x%x%x%x)")
        if hex then
            local r = tonumber(hex:sub(1, 2), 16)
            local g = tonumber(hex:sub(3, 4), 16)
            local b = tonumber(hex:sub(5, 6), 16)
            if r and g and b then
                return r / 255, g / 255, b / 255
            end
        end
    end

    return 0.6, 0.6, 0.6
end

local function SafeGetInventoryItemDurability(slotId)
    if GetInventoryItemDurability then
        return GetInventoryItemDurability(slotId)
    end
    return nil, nil
end

-- =========================================================================
-- Slot Definitions & Button Lookup
-- =========================================================================
local SLOTS_DATA = {
    -- Left Inner Column (adjacent to left edge of CharacterFrame)
    { id = 1,  key = "HEAD",      name = INVTYPE_HEAD or "Head",             slotName = "HeadSlot",          btn = "CharacterHeadSlot",          inspectBtn = "InspectHeadSlot",          group = "LEFT_INNER",  order = 1 },
    { id = 2,  key = "NECK",      name = INVTYPE_NECK or "Neck",             slotName = "NeckSlot",          btn = "CharacterNeckSlot",          inspectBtn = "InspectNeckSlot",          group = "LEFT_INNER",  order = 2 },
    { id = 3,  key = "SHOULDER",  name = INVTYPE_SHOULDER or "Shoulder",     slotName = "ShoulderSlot",      btn = "CharacterShouldersSlot",     inspectBtn = "InspectShouldersSlot",     group = "LEFT_INNER",  order = 3 },
    { id = 15, key = "BACK",      name = INVTYPE_CLOAK or "Back",            slotName = "BackSlot",          btn = "CharacterBackSlot",          inspectBtn = "InspectBackSlot",          group = "LEFT_INNER",  order = 4 },

    -- Left Outer Column (to the left of Left Inner)
    { id = 5,  key = "CHEST",     name = INVTYPE_CHEST or "Chest",           slotName = "ChestSlot",         btn = "CharacterChestSlot",         inspectBtn = "InspectChestSlot",         group = "LEFT_OUTER",  order = 1 },
    { id = 4,  key = "SHIRT",     name = INVTYPE_BODY or "Shirt",            slotName = "ShirtSlot",         btn = "CharacterShirtSlot",         inspectBtn = "InspectShirtSlot",         group = "LEFT_OUTER",  order = 2, cosmetic = true },
    { id = 19, key = "TABARD",    name = INVTYPE_TABARD or "Tabard",         slotName = "TabardSlot",        btn = "CharacterTabardSlot",        inspectBtn = "InspectTabardSlot",        group = "LEFT_OUTER",  order = 3, cosmetic = true },
    { id = 9,  key = "WRIST",     name = INVTYPE_WRIST or "Wrist",           slotName = "WristSlot",         btn = "CharacterWristSlot",         inspectBtn = "InspectWristSlot",         group = "LEFT_OUTER",  order = 4 },

    -- Right Inner Column (adjacent to right edge of CharacterFrame)
    { id = 10, key = "HANDS",     name = INVTYPE_HAND or "Hands",            slotName = "HandsSlot",         btn = "CharacterHandsSlot",         inspectBtn = "InspectHandsSlot",         group = "RIGHT_INNER", order = 1 },
    { id = 6,  key = "WAIST",     name = INVTYPE_WAIST or "Waist",           slotName = "WaistSlot",         btn = "CharacterWaistSlot",         inspectBtn = "InspectWaistSlot",         group = "RIGHT_INNER", order = 2 },
    { id = 7,  key = "LEGS",      name = INVTYPE_LEGS or "Legs",             slotName = "LegsSlot",          btn = "CharacterLegsSlot",          inspectBtn = "InspectLegsSlot",          group = "RIGHT_INNER", order = 3 },
    { id = 8,  key = "FEET",      name = INVTYPE_FEET or "Feet",             slotName = "FeetSlot",          btn = "CharacterFeetSlot",          inspectBtn = "InspectFeetSlot",          group = "RIGHT_INNER", order = 4 },

    -- Right Outer Column (to the right of Right Inner)
    { id = 11, key = "FINGER1",   name = (INVTYPE_FINGER or "Finger") .. " 1", slotName = "Finger0Slot",      btn = "CharacterFinger0Slot",      inspectBtn = "InspectFinger0Slot",      group = "RIGHT_OUTER", order = 1 },
    { id = 12, key = "FINGER2",   name = (INVTYPE_FINGER or "Finger") .. " 2", slotName = "Finger1Slot",      btn = "CharacterFinger1Slot",      inspectBtn = "InspectFinger1Slot",      group = "RIGHT_OUTER", order = 2 },
    { id = 13, key = "TRINKET1",  name = (INVTYPE_TRINKET or "Trinket") .. " 1", slotName = "Trinket0Slot",  btn = "CharacterTrinket0Slot",      inspectBtn = "InspectTrinket0Slot",      group = "RIGHT_OUTER", order = 3 },
    { id = 14, key = "TRINKET2",  name = (INVTYPE_TRINKET or "Trinket") .. " 2", slotName = "Trinket1Slot",  btn = "CharacterTrinket1Slot",      inspectBtn = "InspectTrinket1Slot",      group = "RIGHT_OUTER", order = 4 },

    -- Bottom Row (Weapons / Off-hand / Ranged)
    { id = 16, key = "MAINHAND",  name = INVTYPE_WEAPONMAINHAND or "Main Hand", slotName = "MainHandSlot",   btn = "CharacterMainHandSlot",      inspectBtn = "InspectMainHandSlot",      group = "BOTTOM",      order = 1 },
    { id = 17, key = "OFFHAND",   name = INVTYPE_WEAPONOFFHAND or "Off Hand",   slotName = "SecondaryHandSlot", btn = "CharacterSecondaryHandSlot", inspectBtn = "InspectSecondaryHandSlot", group = "BOTTOM",      order = 2 },
    { id = 18, key = "RANGED",    name = INVTYPE_RANGED or "Ranged",            slotName = "RangedSlot",        btn = "CharacterRangedSlot",         inspectBtn = "InspectRangedSlot",        group = "BOTTOM",      order = 3 },
}
addonTable.SLOTS_DATA = SLOTS_DATA

local function GetSlotButton(slot, unit)
    local isInspect = (unit == "target")
    local globalName = isInspect and slot.inspectBtn or slot.btn
    local btn = _G[globalName]
    if btn then return btn end

    -- Modern Mainline PaperDollItemsFrame hierarchy
    if not isInspect and PaperDollItemsFrame and slot.slotName then
        btn = PaperDollItemsFrame[slot.slotName]
        if btn then return btn end
    end
    if isInspect and InspectPaperDollItemsFrame and slot.slotName then
        btn = InspectPaperDollItemsFrame[slot.slotName]
        if btn then return btn end
    end
    return nil
end

-- =========================================================================
-- Tooltip Creation & Interaction
-- =========================================================================
function addonTable:CreateTooltips()
    if self.tooltipsCreated then return end

    local template = BackdropTemplateMixin and "BackdropTemplate,GameTooltipTemplate" or "GameTooltipTemplate"

    for _, slot in ipairs(SLOTS_DATA) do
        local ttName = "GearDisplayTooltip" .. slot.id
        local tt = CreateFrame("GameTooltip", ttName, UIParent, template)
        tt:SetScript("OnUpdate", nil)
        tt:SetFrameStrata("DIALOG")
        tt:SetFrameLevel(100)
        tt:SetClampedToScreen(true)
        tt:EnableMouse(true)

        -- Interaction
        tt:SetScript("OnEnter", function(s)
            addonTable:OnTooltipEnter(s, slot)
        end)

        tt:SetScript("OnLeave", function(s)
            addonTable:OnTooltipLeave(s, slot)
        end)

        tt:SetScript("OnMouseDown", function(s, button)
            addonTable:OnTooltipClick(s, slot, button)
        end)

        self.tooltips[slot.id] = tt
    end

    self.tooltipsCreated = true
end

function addonTable:OnTooltipClick(tooltip, slot, button)
    if not tooltip.itemLink then return end

    if button == "LeftButton" then
        if IsShiftKeyDown() then
            if ChatEdit_InsertLink then
                ChatEdit_InsertLink(tooltip.itemLink)
            end
        elseif IsControlKeyDown() then
            if DressUpItemLink then
                DressUpItemLink(tooltip.itemLink)
            elseif DressUpLink then
                DressUpLink(tooltip.itemLink)
            end
        end
    end
end

function addonTable:OnTooltipEnter(tooltip, slot)
    -- Highlight character sheet slot button
    local slotBtn = GetSlotButton(slot, self.currentUnit)
    if slotBtn and slotBtn.LockHighlight then
        slotBtn:LockHighlight()
    end

    -- Bright gold border highlight
    if tooltip.SetBackdropBorderColor then
        tooltip:SetBackdropBorderColor(1.0, 0.85, 0.1, 1.0)
    end
    if tooltip.NineSlice and tooltip.NineSlice.SetBorderColor then
        tooltip.NineSlice:SetBorderColor(1.0, 0.85, 0.1, 1.0)
    end
end

function addonTable:OnTooltipLeave(tooltip, slot)
    -- Unlock character sheet slot button highlight
    local slotBtn = GetSlotButton(slot, self.currentUnit)
    if slotBtn and slotBtn.UnlockHighlight then
        slotBtn:UnlockHighlight()
    end

    -- Restore normal border
    self:UpdateTooltipBorder(tooltip, slot.id, self.currentUnit)
end

function addonTable:PopulateTooltip(tooltip, slotId, unit)
    unit = unit or "player"
    local itemLink = SafeGetInventoryItemLink(unit, slotId)
    if not itemLink then
        tooltip:Hide()
        tooltip.itemLink = nil
        tooltip.slotId = nil
        return false
    end

    tooltip.itemLink = itemLink
    tooltip.slotId = slotId

    tooltip:SetOwner(UIParent, "ANCHOR_NONE")
    tooltip:ClearLines()

    -- 1. Populate using standard Blizzard SetInventoryItem API
    local hasLines = false
    if tooltip.SetInventoryItem then
        local ok = pcall(tooltip.SetInventoryItem, tooltip, unit, slotId)
        if ok and tooltip:NumLines() and tooltip:NumLines() > 0 then
            hasLines = true
        end
    end

    -- 2. Fallback to SetHyperlink if SetInventoryItem didn't populate lines
    if (not hasLines or (tooltip:NumLines() and tooltip:NumLines() == 0)) and itemLink and tooltip.SetHyperlink then
        pcall(tooltip.SetHyperlink, tooltip, itemLink)
    end

    if tooltip.SetBackdropColor then
        tooltip:SetBackdropColor(0.06, 0.06, 0.09, 0.95)
    end

    local scale = GearDisplayDB.scale or 0.85
    tooltip:SetScale(scale)
    tooltip:SetFrameStrata("DIALOG")
    tooltip:SetFrameLevel(100)

    self:UpdateTooltipBorder(tooltip, slotId, unit)

    tooltip:Show()
    return true
end

function addonTable:UpdateTooltipBorder(tooltip, slotId, unit)
    unit = unit or self.currentUnit or "player"
    if not tooltip.itemLink then return end

    if GearDisplayDB.qualityBorders then
        local quality = SafeGetItemQuality(unit, slotId, tooltip.itemLink)
        local r, g, b = SafeGetItemQualityColor(quality, tooltip.itemLink)
        if r and g and b then
            if tooltip.SetBackdropBorderColor then
                tooltip:SetBackdropBorderColor(r, g, b, 1.0)
            end
            if tooltip.NineSlice and tooltip.NineSlice.SetBorderColor then
                tooltip.NineSlice:SetBorderColor(r, g, b, 1.0)
            end
            return
        end
    end

    if tooltip.SetBackdropBorderColor then
        tooltip:SetBackdropBorderColor(0.6, 0.6, 0.6, 0.9)
    end
    if tooltip.NineSlice and tooltip.NineSlice.SetBorderColor then
        tooltip.NineSlice:SetBorderColor(0.6, 0.6, 0.6, 0.9)
    end
end

-- =========================================================================
-- Slot Highlighting & Hooking
-- =========================================================================
function addonTable:HookSlotButtons()
    if self.slotsHooked then return end

    for _, slot in ipairs(SLOTS_DATA) do
        local slotBtn = GetSlotButton(slot, "player")
        if slotBtn then
            slotBtn:HookScript("OnEnter", function()
                if addonTable.isShowing and addonTable.currentUnit == "player" then
                    addonTable:HighlightSlotTooltip(slot.id, true)
                    if GearDisplayDB.hideDefaultTooltipOnHover then
                        GameTooltip:Hide()
                    end
                end
            end)
            slotBtn:HookScript("OnLeave", function()
                if addonTable.isShowing and addonTable.currentUnit == "player" then
                    addonTable:HighlightSlotTooltip(slot.id, false)
                end
            end)
        end
    end

    self.slotsHooked = true
end

function addonTable:HookInspectSlotButtons()
    if self.inspectSlotsHooked then return end

    for _, slot in ipairs(SLOTS_DATA) do
        local slotBtn = GetSlotButton(slot, "target")
        if slotBtn then
            slotBtn:HookScript("OnEnter", function()
                if addonTable.isShowing and addonTable.currentUnit == "target" then
                    addonTable:HighlightSlotTooltip(slot.id, true)
                    if GearDisplayDB.hideDefaultTooltipOnHover then
                        GameTooltip:Hide()
                    end
                end
            end)
            slotBtn:HookScript("OnLeave", function()
                if addonTable.isShowing and addonTable.currentUnit == "target" then
                    addonTable:HighlightSlotTooltip(slot.id, false)
                end
            end)
        end
    end

    self.inspectSlotsHooked = true
end

function addonTable:HighlightSlotTooltip(slotId, isHighlighted)
    local tt = self.tooltips[slotId]
    if tt and tt:IsShown() then
        if isHighlighted then
            if tt.SetBackdropBorderColor then
                tt:SetBackdropBorderColor(1.0, 0.85, 0.1, 1.0)
            end
            if tt.NineSlice and tt.NineSlice.SetBorderColor then
                tt.NineSlice:SetBorderColor(1.0, 0.85, 0.1, 1.0)
            end
        else
            self:UpdateTooltipBorder(tt, slotId, self.currentUnit)
        end
    end
end

function addonTable:ClearAllHighlights()
    for _, slot in ipairs(SLOTS_DATA) do
        local slotBtn = GetSlotButton(slot, self.currentUnit)
        if slotBtn and slotBtn.UnlockHighlight then
            slotBtn:UnlockHighlight()
        end
    end
end

-- =========================================================================
-- Smart Layout Engine
-- =========================================================================
function addonTable:LayoutTooltips(targetFrame)
    targetFrame = targetFrame or CharacterFrame
    if not targetFrame then return end

    local scale = GearDisplayDB.scale or 0.85
    local layoutMode = GearDisplayDB.layout or "grid"
    local gapY = 6
    local gapX = 8

    local leftInner, leftOuter = {}, {}
    local rightInner, rightOuter = {}, {}
    local bottomList = {}

    for _, slot in ipairs(SLOTS_DATA) do
        local tt = self.tooltips[slot.id]
        if tt and tt:IsShown() then
            if slot.group == "LEFT_INNER" then
                table.insert(leftInner, tt)
            elseif slot.group == "LEFT_OUTER" then
                if not slot.cosmetic or GearDisplayDB.showCosmetics then
                    table.insert(leftOuter, tt)
                else
                    tt:Hide()
                end
            elseif slot.group == "RIGHT_INNER" then
                table.insert(rightInner, tt)
            elseif slot.group == "RIGHT_OUTER" then
                table.insert(rightOuter, tt)
            elseif slot.group == "BOTTOM" then
                table.insert(bottomList, tt)
            end
        end
    end

    if layoutMode == "single" then
        -- Single Column Layout
        local leftCombined = {}
        for _, tt in ipairs(leftInner) do table.insert(leftCombined, tt) end
        for _, tt in ipairs(leftOuter) do table.insert(leftCombined, tt) end

        local prev = nil
        for _, tt in ipairs(leftCombined) do
            tt:ClearAllPoints()
            if not prev then
                tt:SetPoint("TOPRIGHT", targetFrame, "TOPLEFT", -gapX / scale, -28 / scale)
            else
                tt:SetPoint("TOPRIGHT", prev, "BOTTOMRIGHT", 0, -gapY)
            end
            prev = tt
            tt:Show()
        end

        local rightCombined = {}
        for _, tt in ipairs(rightInner) do table.insert(rightCombined, tt) end
        for _, tt in ipairs(rightOuter) do table.insert(rightCombined, tt) end

        prev = nil
        for _, tt in ipairs(rightCombined) do
            tt:ClearAllPoints()
            if not prev then
                tt:SetPoint("TOPLEFT", targetFrame, "TOPRIGHT", gapX / scale, -28 / scale)
            else
                tt:SetPoint("TOPLEFT", prev, "BOTTOMLEFT", 0, -gapY)
            end
            prev = tt
            tt:Show()
        end
    else
        -- Compact Grid Layout (2 columns per side)
        if #leftInner == 0 and #leftOuter > 0 then
            leftInner = leftOuter
            leftOuter = {}
        end
        if #rightInner == 0 and #rightOuter > 0 then
            rightInner = rightOuter
            rightOuter = {}
        end

        -- 1. LEFT INNER COLUMN
        local prev = nil
        local maxInnerLeftWidth = 0
        for _, tt in ipairs(leftInner) do
            tt:ClearAllPoints()
            if not prev then
                tt:SetPoint("TOPRIGHT", targetFrame, "TOPLEFT", -gapX / scale, -28 / scale)
            else
                tt:SetPoint("TOPRIGHT", prev, "BOTTOMRIGHT", 0, -gapY)
            end
            prev = tt
            local w = tt:GetWidth()
            if w > maxInnerLeftWidth then maxInnerLeftWidth = w end
            tt:Show()
        end
        if maxInnerLeftWidth == 0 then maxInnerLeftWidth = 220 end

        -- 2. LEFT OUTER COLUMN
        prev = nil
        local outerLeftXOffset = (gapX + maxInnerLeftWidth + gapX) / scale
        for _, tt in ipairs(leftOuter) do
            tt:ClearAllPoints()
            if not prev then
                tt:SetPoint("TOPRIGHT", targetFrame, "TOPLEFT", -outerLeftXOffset, -28 / scale)
            else
                tt:SetPoint("TOPRIGHT", prev, "BOTTOMRIGHT", 0, -gapY)
            end
            prev = tt
            tt:Show()
        end

        -- 3. RIGHT INNER COLUMN
        prev = nil
        local maxInnerRightWidth = 0
        for _, tt in ipairs(rightInner) do
            tt:ClearAllPoints()
            if not prev then
                tt:SetPoint("TOPLEFT", targetFrame, "TOPRIGHT", gapX / scale, -28 / scale)
            else
                tt:SetPoint("TOPLEFT", prev, "BOTTOMLEFT", 0, -gapY)
            end
            prev = tt
            local w = tt:GetWidth()
            if w > maxInnerRightWidth then maxInnerRightWidth = w end
            tt:Show()
        end
        if maxInnerRightWidth == 0 then maxInnerRightWidth = 220 end

        -- 4. RIGHT OUTER COLUMN
        prev = nil
        local outerRightXOffset = (gapX + maxInnerRightWidth + gapX) / scale
        for _, tt in ipairs(rightOuter) do
            tt:ClearAllPoints()
            if not prev then
                tt:SetPoint("TOPLEFT", targetFrame, "TOPRIGHT", outerRightXOffset, -28 / scale)
            else
                tt:SetPoint("TOPLEFT", prev, "BOTTOMLEFT", 0, -gapY)
            end
            prev = tt
            tt:Show()
        end
    end

    -- 5. BOTTOM ROW (Weapons)
    local bottomCount = #bottomList
    local bottomOffsetY = -10 / scale
    if bottomCount == 1 then
        local tt = bottomList[1]
        tt:ClearAllPoints()
        tt:SetPoint("TOP", targetFrame, "BOTTOM", 0, bottomOffsetY)
        tt:Show()
    elseif bottomCount == 2 then
        local tt1, tt2 = bottomList[1], bottomList[2]
        tt1:ClearAllPoints()
        tt1:SetPoint("TOPRIGHT", targetFrame, "BOTTOM", -(gapX / 2) / scale, bottomOffsetY)
        tt1:Show()
        tt2:ClearAllPoints()
        tt2:SetPoint("TOPLEFT", targetFrame, "BOTTOM", (gapX / 2) / scale, bottomOffsetY)
        tt2:Show()
    elseif bottomCount >= 3 then
        local tt1, tt2, tt3 = bottomList[1], bottomList[2], bottomList[3]
        tt2:ClearAllPoints()
        tt2:SetPoint("TOP", targetFrame, "BOTTOM", 0, bottomOffsetY)
        tt2:Show()
        tt1:ClearAllPoints()
        tt1:SetPoint("TOPRIGHT", tt2, "TOPLEFT", -gapX, 0)
        tt1:Show()
        tt3:ClearAllPoints()
        tt3:SetPoint("TOPLEFT", tt2, "TOPRIGHT", gapX, 0)
        tt3:Show()
    end
end

-- =========================================================================
-- Gear Calculations (iLvl, Equipped, Durability)
-- =========================================================================
function addonTable:GetEquippedCount(unit)
    local equipped, total = 0, 0
    for _, slot in ipairs(SLOTS_DATA) do
        if not slot.cosmetic then
            total = total + 1
            if SafeGetInventoryItemLink(unit, slot.id) then
                equipped = equipped + 1
            end
        end
    end
    return equipped, total
end

function addonTable:GetAverageGearItemLevel(unit)
    if unit == "player" and GetAverageItemLevel then
        local _, avgEquipped = GetAverageItemLevel()
        if avgEquipped and avgEquipped > 0 then
            return string.format("%.1f", avgEquipped)
        end
    end

    local totalIlvl, count = 0, 0
    for _, slot in ipairs(SLOTS_DATA) do
        if not slot.cosmetic then
            local itemLink = SafeGetInventoryItemLink(unit, slot.id)
            if itemLink then
                local ilvl = SafeGetDetailedItemLevelInfo(itemLink)
                if not ilvl then
                    ilvl = select(4, SafeGetItemInfo(itemLink))
                end
                if ilvl and ilvl > 0 then
                    totalIlvl = totalIlvl + ilvl
                    count = count + 1
                end
            end
        end
    end

    if count > 0 then
        return string.format("%.1f", totalIlvl / count)
    end
    return nil
end

function addonTable:GetOverallDurabilityString()
    local totalCurrent, totalMax = 0, 0
    for _, slot in ipairs(SLOTS_DATA) do
        local cur, max = SafeGetInventoryItemDurability(slot.id)
        if cur and max and max > 0 then
            totalCurrent = totalCurrent + cur
            totalMax = totalMax + max
        end
    end

    if totalMax > 0 then
        local pct = math.floor((totalCurrent / totalMax) * 100)
        local color = "|cff00ff00"
        if pct < 40 then
            color = "|cffff4444"
        elseif pct < 80 then
            color = "|cffffff00"
        end
        return string.format("%s%d%%|r", color, pct)
    end
    return "|cff00ff00100%|r"
end

-- =========================================================================
-- Character Sheet Tab Pane (Replaces Floating Header Bar)
-- =========================================================================
function addonTable:CreateTabPane()
    if self.tabPane then return end

    local parent = PaperDollFrame or CharacterFrame
    if not parent then return end

    local template = BackdropTemplateMixin and "BackdropTemplate" or nil
    local pane = CreateFrame("Frame", "GearDisplayTabPane", parent, template)

    -- Anchor seamlessly into CharacterFrame sidebar area (matching CharacterStatsPane)
    if CharacterStatsPane then
        pane:SetAllPoints(CharacterStatsPane)
    elseif PaperDollSidebarTabs then
        pane:SetPoint("TOPLEFT", PaperDollSidebarTabs, "BOTTOMLEFT", -2, -1)
        pane:SetPoint("BOTTOMRIGHT", parent, "BOTTOMRIGHT", -4, 6)
    else
        pane:SetPoint("TOPRIGHT", parent, "TOPRIGHT", -4, -60)
        pane:SetPoint("BOTTOMRIGHT", parent, "BOTTOMRIGHT", -4, 6)
        pane:SetWidth(206)
    end

    pane:SetFrameStrata(parent:GetFrameStrata() or "MEDIUM")
    pane:SetFrameLevel((parent:GetFrameLevel() or 10) + 10)

    if pane.SetBackdrop then
        pane:SetBackdrop({
            bgFile = "Interface\\Tooltips\\UI-Tooltip-Background",
            edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
            tile = true, tileSize = 16, edgeSize = 12,
            insets = { left = 3, right = 3, top = 3, bottom = 3 }
        })
        pane:SetBackdropColor(0.04, 0.04, 0.07, 0.92)
        pane:SetBackdropBorderColor(0.38, 0.38, 0.42, 0.85)
    end

    -- 1. Top Title Header
    local headerFrame = CreateFrame("Frame", nil, pane)
    headerFrame:SetPoint("TOPLEFT", pane, "TOPLEFT", 6, -6)
    headerFrame:SetPoint("TOPRIGHT", pane, "TOPRIGHT", -6, -6)
    headerFrame:SetHeight(26)

    local icon = headerFrame:CreateTexture(nil, "ARTWORK")
    icon:SetSize(18, 18)
    icon:SetPoint("LEFT", headerFrame, "LEFT", 2, 0)
    icon:SetTexture("Interface\\Icons\\INV_Chest_Cloth_17")
    icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)

    local title = headerFrame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    title:SetPoint("LEFT", icon, "RIGHT", 6, 0)
    title:SetText("|cffffd100" .. L["TAB_TITLE"] .. "|r")

    local closeBtn = CreateFrame("Button", nil, headerFrame, "UIPanelCloseButton")
    closeBtn:SetSize(22, 22)
    closeBtn:SetPoint("RIGHT", headerFrame, "RIGHT", 2, 0)
    closeBtn:SetScript("OnClick", function()
        addonTable:SelectStatsTab()
    end)
    closeBtn:SetScript("OnEnter", function(s)
        GameTooltip:SetOwner(s, "ANCHOR_RIGHT")
        GameTooltip:AddLine(L["HEADER_CLOSE_TT"], 1, 0.82, 0)
        GameTooltip:Show()
    end)
    closeBtn:SetScript("OnLeave", function() GameTooltip:Hide() end)

    local divider = pane:CreateTexture(nil, "ARTWORK")
    divider:SetPoint("TOPLEFT", headerFrame, "BOTTOMLEFT", 0, -2)
    divider:SetPoint("TOPRIGHT", headerFrame, "BOTTOMRIGHT", 0, -2)
    divider:SetHeight(1)
    divider:SetColorTexture(1.0, 0.82, 0, 0.35)

    -- 2. Scroll Frame
    local scrollFrame = CreateFrame("ScrollFrame", "GearDisplayTabScrollFrame", pane, "UIPanelScrollFrameTemplate")
    scrollFrame:SetPoint("TOPLEFT", divider, "BOTTOMLEFT", 2, -4)
    scrollFrame:SetPoint("BOTTOMRIGHT", pane, "BOTTOMRIGHT", -22, 6)

    local scrollChild = CreateFrame("Frame", "GearDisplayTabScrollChild", scrollFrame)
    scrollChild:SetWidth(174)
    scrollChild:SetHeight(500)
    scrollFrame:SetScrollChild(scrollChild)
    pane.scrollFrame = scrollFrame
    pane.scrollChild = scrollChild

    -- 3. Live Summary Card
    local summaryCard = CreateFrame("Frame", nil, scrollChild, template)
    summaryCard:SetPoint("TOPLEFT", scrollChild, "TOPLEFT", 0, 0)
    summaryCard:SetPoint("TOPRIGHT", scrollChild, "TOPRIGHT", 0, 0)
    summaryCard:SetHeight(74)

    if summaryCard.SetBackdrop then
        summaryCard:SetBackdrop({
            bgFile = "Interface\\Tooltips\\UI-Tooltip-Background",
            edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
            tile = true, tileSize = 12, edgeSize = 8,
            insets = { left = 2, right = 2, top = 2, bottom = 2 }
        })
        summaryCard:SetBackdropColor(0.10, 0.10, 0.15, 0.8)
        summaryCard:SetBackdropBorderColor(0.38, 0.38, 0.45, 0.7)
    end

    local ilvlLabel = summaryCard:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    ilvlLabel:SetPoint("TOPLEFT", summaryCard, "TOPLEFT", 8, -8)
    ilvlLabel:SetText(L["HEADER_AVG_ILVL"] .. ":")

    local ilvlVal = summaryCard:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    ilvlVal:SetPoint("LEFT", ilvlLabel, "RIGHT", 6, 0)
    ilvlVal:SetText("-")
    pane.ilvlVal = ilvlVal

    local eqLabel = summaryCard:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    eqLabel:SetPoint("TOPLEFT", ilvlLabel, "BOTTOMLEFT", 0, -6)
    eqLabel:SetText(L["HEADER_EQUIPPED"] .. ":")

    local eqVal = summaryCard:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    eqVal:SetPoint("LEFT", eqLabel, "RIGHT", 6, 0)
    eqVal:SetText("-")
    pane.eqVal = eqVal

    local durLabel = summaryCard:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    durLabel:SetPoint("TOPLEFT", eqLabel, "BOTTOMLEFT", 0, -4)
    durLabel:SetText(L["HEADER_DURABILITY"] .. ":")

    local durVal = summaryCard:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    durVal:SetPoint("LEFT", durLabel, "RIGHT", 6, 0)
    durVal:SetText("-")
    pane.durVal = durVal

    pane.summaryCard = summaryCard

    -- Quick Action Buttons
    local refreshBtn = CreateFrame("Button", nil, scrollChild, "UIPanelButtonTemplate")
    refreshBtn:SetSize(82, 20)
    refreshBtn:SetPoint("TOPLEFT", summaryCard, "BOTTOMLEFT", 0, -6)
    refreshBtn:SetText(L["TAB_REFRESH"])
    refreshBtn:SetScript("OnClick", function()
        addonTable:RefreshGear()
    end)

    local hideBtn = CreateFrame("Button", nil, scrollChild, "UIPanelButtonTemplate")
    hideBtn:SetSize(86, 20)
    hideBtn:SetPoint("LEFT", refreshBtn, "RIGHT", 6, 0)
    hideBtn:SetText(L["TAB_HIDE"])
    hideBtn:SetScript("OnClick", function()
        addonTable:SelectStatsTab()
    end)

    -- 4. Settings Section Header
    local optHeader = scrollChild:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    optHeader:SetPoint("TOPLEFT", refreshBtn, "BOTTOMLEFT", 0, -10)
    optHeader:SetText("|cffffd100" .. L["CONFIG_TITLE"] .. "|r")

    local optDiv = scrollChild:CreateTexture(nil, "ARTWORK")
    optDiv:SetPoint("TOPLEFT", optHeader, "BOTTOMLEFT", 0, -2)
    optDiv:SetPoint("TOPRIGHT", scrollChild, "TOPRIGHT", 0, -2)
    optDiv:SetHeight(1)
    optDiv:SetColorTexture(1.0, 0.82, 0, 0.25)

    -- Layout Mode Toggle Buttons
    local layoutLabel = scrollChild:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    layoutLabel:SetPoint("TOPLEFT", optDiv, "BOTTOMLEFT", 0, -6)
    layoutLabel:SetText(L["CONFIG_LAYOUT_LABEL"] .. ":")

    local btnGrid = CreateFrame("Button", nil, scrollChild, "UIPanelButtonTemplate")
    btnGrid:SetSize(82, 20)
    btnGrid:SetPoint("TOPLEFT", layoutLabel, "BOTTOMLEFT", 0, -4)
    btnGrid:SetText(L["CONFIG_LAYOUT_GRID"])
    btnGrid:SetScript("OnClick", function()
        GearDisplayDB.layout = "grid"
        addonTable:RefreshTabPaneSettings()
        if addonTable.isShowing then addonTable:RefreshGear() end
    end)
    btnGrid:SetScript("OnEnter", function(s)
        GameTooltip:SetOwner(s, "ANCHOR_RIGHT")
        GameTooltip:AddLine(L["CONFIG_LAYOUT_GRID"], 1, 0.82, 0)
        GameTooltip:AddLine(L["CONFIG_LAYOUT_GRID_TT"], 1, 1, 1, true)
        GameTooltip:Show()
    end)
    btnGrid:SetScript("OnLeave", function() GameTooltip:Hide() end)
    pane.btnGrid = btnGrid

    local btnSingle = CreateFrame("Button", nil, scrollChild, "UIPanelButtonTemplate")
    btnSingle:SetSize(86, 20)
    btnSingle:SetPoint("LEFT", btnGrid, "RIGHT", 6, 0)
    btnSingle:SetText(L["CONFIG_LAYOUT_SINGLE"])
    btnSingle:SetScript("OnClick", function()
        GearDisplayDB.layout = "single"
        addonTable:RefreshTabPaneSettings()
        if addonTable.isShowing then addonTable:RefreshGear() end
    end)
    btnSingle:SetScript("OnEnter", function(s)
        GameTooltip:SetOwner(s, "ANCHOR_RIGHT")
        GameTooltip:AddLine(L["CONFIG_LAYOUT_SINGLE"], 1, 0.82, 0)
        GameTooltip:AddLine(L["CONFIG_LAYOUT_SINGLE_TT"], 1, 1, 1, true)
        GameTooltip:Show()
    end)
    btnSingle:SetScript("OnLeave", function() GameTooltip:Hide() end)
    pane.btnSingle = btnSingle

    -- Scale Slider
    local slider = CreateFrame("Slider", "GearDisplayTabScaleSlider", scrollChild, "OptionsSliderTemplate")
    slider:SetPoint("TOPLEFT", btnGrid, "BOTTOMLEFT", 4, -20)
    slider:SetWidth(164)
    slider:SetMinMaxValues(0.60, 1.20)
    slider:SetValueStep(0.05)
    slider:SetObeyStepOnDrag(true)

    local sLabel = _G[slider:GetName() .. "Text"]
    local sLow = _G[slider:GetName() .. "Low"]
    local sHigh = _G[slider:GetName() .. "High"]
    if sLow then sLow:SetText("60%") end
    if sHigh then sHigh:SetText("120%") end

    slider:SetScript("OnValueChanged", function(s, value)
        value = math.floor(value * 20 + 0.5) / 20
        GearDisplayDB.scale = value
        if sLabel then
            sLabel:SetText(string.format("%s: %d%%", L["CONFIG_SCALE_LABEL"], math.floor(value * 100 + 0.5)))
        end
        if addonTable.isShowing and not pane.isUpdating then
            addonTable:RefreshGear()
        end
    end)
    slider:SetScript("OnEnter", function(s)
        GameTooltip:SetOwner(s, "ANCHOR_RIGHT")
        GameTooltip:AddLine(L["CONFIG_SCALE_LABEL"], 1, 0.82, 0)
        GameTooltip:AddLine(L["CONFIG_SCALE_TT"], 1, 1, 1, true)
        GameTooltip:Show()
    end)
    slider:SetScript("OnLeave", function() GameTooltip:Hide() end)
    pane.scaleSlider = slider

    -- Checkbox Helper
    local function CreateTabCheck(text, ttDesc, dbKey, relativeTo, yOff)
        local cb = CreateFrame("CheckButton", nil, scrollChild, "InterfaceOptionsCheckButtonTemplate")
        cb:SetPoint("TOPLEFT", relativeTo, "BOTTOMLEFT", -4, yOff)
        local label = cb.Text or _G[cb:GetName() .. "Text"]
        if label then
            label:SetText(text)
            label:SetFontObject(GameFontHighlightSmall)
            label:SetWordWrap(true)
            label:SetWidth(140)
        end
        cb:SetScript("OnClick", function(s)
            GearDisplayDB[dbKey] = s:GetChecked()
            if addonTable.isShowing then
                addonTable:RefreshGear()
            end
        end)
        cb:SetScript("OnEnter", function(s)
            GameTooltip:SetOwner(s, "ANCHOR_RIGHT")
            GameTooltip:AddLine(text, 1, 0.82, 0)
            GameTooltip:AddLine(ttDesc, 1, 1, 1, true)
            GameTooltip:Show()
        end)
        cb:SetScript("OnLeave", function() GameTooltip:Hide() end)
        return cb
    end

    pane.cbAutoCenter = CreateTabCheck(L["CONFIG_AUTO_CENTER"], L["CONFIG_AUTO_CENTER_TT"], "autoCenter", slider, -14)
    pane.cbQuality = CreateTabCheck(L["CONFIG_QUALITY_BORDERS"], L["CONFIG_QUALITY_BORDERS_TT"], "qualityBorders", pane.cbAutoCenter, -10)
    pane.cbCosmetics = CreateTabCheck(L["CONFIG_SHOW_COSMETICS"], L["CONFIG_SHOW_COSMETICS_TT"], "showCosmetics", pane.cbQuality, -10)
    pane.cbHideDefault = CreateTabCheck(L["CONFIG_HIDE_DEFAULT_TT"], L["CONFIG_HIDE_DEFAULT_TT_TT"], "hideDefaultTooltipOnHover", pane.cbCosmetics, -10)

    -- Reset Defaults Button
    local resetBtn = CreateFrame("Button", nil, scrollChild, "UIPanelButtonTemplate")
    resetBtn:SetSize(168, 20)
    resetBtn:SetPoint("TOPLEFT", pane.cbHideDefault, "BOTTOMLEFT", 4, -12)
    resetBtn:SetText(L["CONFIG_RESET_DEFAULTS"])
    resetBtn:SetScript("OnClick", function()
        addonTable:ResetDB()
    end)

    -- 5. Equipped Items Section
    local itemsHeader = scrollChild:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    itemsHeader:SetPoint("TOPLEFT", resetBtn, "BOTTOMLEFT", 0, -14)
    itemsHeader:SetText("|cffffd100" .. L["TAB_ITEMS_HEADER"] .. "|r")
    pane.itemsHeader = itemsHeader

    local itemsDiv = scrollChild:CreateTexture(nil, "ARTWORK")
    itemsDiv:SetPoint("TOPLEFT", itemsHeader, "BOTTOMLEFT", 0, -2)
    itemsDiv:SetPoint("TOPRIGHT", scrollChild, "TOPRIGHT", 0, -2)
    itemsDiv:SetHeight(1)
    itemsDiv:SetColorTexture(1.0, 0.82, 0, 0.25)

    local itemsContainer = CreateFrame("Frame", nil, scrollChild)
    itemsContainer:SetPoint("TOPLEFT", itemsDiv, "BOTTOMLEFT", 0, -4)
    itemsContainer:SetPoint("TOPRIGHT", scrollChild, "TOPRIGHT", 0, -4)
    itemsContainer:SetHeight(10)
    pane.itemsContainer = itemsContainer
    pane.itemRows = {}

    pane:Hide()
    self.tabPane = pane
end

function addonTable:RefreshTabPaneSettings()
    local pane = self.tabPane
    if not pane then return end

    pane.isUpdating = true

    if pane.cbAutoCenter then pane.cbAutoCenter:SetChecked(GearDisplayDB.autoCenter) end
    if pane.cbQuality then pane.cbQuality:SetChecked(GearDisplayDB.qualityBorders) end
    if pane.cbCosmetics then pane.cbCosmetics:SetChecked(GearDisplayDB.showCosmetics) end
    if pane.cbHideDefault then pane.cbHideDefault:SetChecked(GearDisplayDB.hideDefaultTooltipOnHover) end

    if GearDisplayDB.layout == "single" then
        if pane.btnSingle then pane.btnSingle:Disable() end
        if pane.btnGrid then pane.btnGrid:Enable() end
    else
        if pane.btnGrid then pane.btnGrid:Disable() end
        if pane.btnSingle then pane.btnSingle:Enable() end
    end

    local curScale = GearDisplayDB.scale or 0.85
    if pane.scaleSlider then
        pane.scaleSlider:SetValue(curScale)
        local sLabel = _G[pane.scaleSlider:GetName() .. "Text"]
        if sLabel then
            sLabel:SetText(string.format("%s: %d%%", L["CONFIG_SCALE_LABEL"], math.floor(curScale * 100 + 0.5)))
        end
    end

    if pane.summaryCard then
        if GearDisplayDB.showSummary then
            pane.summaryCard:Show()
        else
            pane.summaryCard:Hide()
        end
    end

    pane.isUpdating = false
end

function addonTable:UpdateTabPaneItems(unit)
    unit = unit or "player"
    local pane = self.tabPane
    if not pane or not pane.itemsContainer then return end

    local container = pane.itemsContainer
    local rows = pane.itemRows

    for _, row in ipairs(rows) do
        row:Hide()
    end

    local rowIdx = 0
    local rowHeight = 22

    for _, slot in ipairs(SLOTS_DATA) do
        local itemLink = SafeGetInventoryItemLink(unit, slot.id)
        local shouldShow = itemLink and (not slot.cosmetic or GearDisplayDB.showCosmetics)

        if shouldShow then
            rowIdx = rowIdx + 1
            local row = rows[rowIdx]
            if not row then
                row = CreateFrame("Button", nil, container)
                row:SetHeight(rowHeight)
                row:SetPoint("LEFT", container, "LEFT", 0, 0)
                row:SetPoint("RIGHT", container, "RIGHT", 0, 0)

                local hl = row:CreateTexture(nil, "HIGHLIGHT")
                hl:SetAllPoints(row)
                hl:SetColorTexture(1.0, 1.0, 1.0, 0.1)

                local icon = row:CreateTexture(nil, "ARTWORK")
                icon:SetSize(18, 18)
                icon:SetPoint("LEFT", row, "LEFT", 2, 0)
                icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
                row.icon = icon

                local slotText = row:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
                slotText:SetPoint("LEFT", icon, "RIGHT", 4, 0)
                slotText:SetWidth(56)
                slotText:SetJustifyH("LEFT")
                slotText:SetWordWrap(false)
                row.slotText = slotText

                local ilvlText = row:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
                ilvlText:SetPoint("RIGHT", row, "RIGHT", -2, 0)
                ilvlText:SetJustifyH("RIGHT")
                row.ilvlText = ilvlText

                local nameText = row:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
                nameText:SetPoint("LEFT", slotText, "RIGHT", 2, 0)
                nameText:SetPoint("RIGHT", ilvlText, "LEFT", -4, 0)
                nameText:SetJustifyH("LEFT")
                nameText:SetWordWrap(false)
                row.nameText = nameText

                row:SetScript("OnEnter", function(s)
                    if not s.slotId then return end
                    addonTable:HighlightSlotTooltip(s.slotId, true)
                    local slotBtn = GetSlotButton(s.slot, addonTable.currentUnit or "player")
                    if slotBtn and slotBtn.LockHighlight then
                        slotBtn:LockHighlight()
                    end
                end)

                row:SetScript("OnLeave", function(s)
                    if not s.slotId then return end
                    addonTable:HighlightSlotTooltip(s.slotId, false)
                    local slotBtn = GetSlotButton(s.slot, addonTable.currentUnit or "player")
                    if slotBtn and slotBtn.UnlockHighlight then
                        slotBtn:UnlockHighlight()
                    end
                end)

                row:SetScript("OnClick", function(s, button)
                    if not s.itemLink then return end
                    if button == "LeftButton" then
                        if IsShiftKeyDown() then
                            if ChatEdit_InsertLink then ChatEdit_InsertLink(s.itemLink) end
                        elseif IsControlKeyDown() then
                            if DressUpItemLink then
                                DressUpItemLink(s.itemLink)
                            elseif DressUpLink then
                                DressUpLink(s.itemLink)
                            end
                        end
                    end
                end)

                rows[rowIdx] = row
            end

            row.slot = slot
            row.slotId = slot.id
            row.itemLink = itemLink

            local itemTexture = GetInventoryItemTexture(unit, slot.id)
            if not itemTexture and SafeGetItemInfo then
                itemTexture = select(10, SafeGetItemInfo(itemLink))
            end
            row.icon:SetTexture(itemTexture or "Interface\\Icons\\INV_Misc_QuestionMark")

            row.slotText:SetText(slot.name or slot.key)

            local ilvl = SafeGetDetailedItemLevelInfo(itemLink) or select(4, SafeGetItemInfo(itemLink))
            if ilvl and ilvl > 0 then
                row.ilvlText:SetText(string.format("|cffffd100%d|r", ilvl))
            else
                row.ilvlText:SetText("")
            end

            local itemName = SafeGetItemInfo(itemLink) or itemLink:match("%[(.-)%]") or "Unknown"
            local quality = SafeGetItemQuality(unit, slot.id, itemLink)
            local r, g, b = SafeGetItemQualityColor(quality, itemLink)
            row.nameText:SetText(itemName)
            row.nameText:SetTextColor(r, g, b)

            row:ClearAllPoints()
            row:SetPoint("TOPLEFT", container, "TOPLEFT", 0, -((rowIdx - 1) * (rowHeight + 2)))
            row:SetPoint("TOPRIGHT", container, "TOPRIGHT", 0, -((rowIdx - 1) * (rowHeight + 2)))
            row:Show()
        end
    end

    local totalY = rowIdx * (rowHeight + 2)
    container:SetHeight(math.max(10, totalY))

    local totalChildHeight = 370 + totalY + 20
    pane.scrollChild:SetHeight(math.max(400, totalChildHeight))
end

function addonTable:UpdateTabPane(unit)
    unit = unit or "player"
    if not self.tabPane then return end

    local equipped, total = self:GetEquippedCount(unit)
    local ilvlStr = self:GetAverageGearItemLevel(unit)
    local durStr = (unit == "player") and self:GetOverallDurabilityString() or nil

    if self.tabPane.ilvlVal then
        self.tabPane.ilvlVal:SetText(ilvlStr and ("|cffffd100" .. ilvlStr .. "|r") or "-")
    end
    if self.tabPane.eqVal then
        self.tabPane.eqVal:SetText(string.format("|cffffffff%d / %d|r", equipped, total))
    end
    if self.tabPane.durVal then
        self.tabPane.durVal:SetText(durStr or "-")
    end

    if self.tabPane.itemsHeader then
        self.tabPane.itemsHeader:SetText(string.format("|cffffd100%s (%d)|r", L["TAB_ITEMS_HEADER"], equipped))
    end

    self:RefreshTabPaneSettings()
    self:UpdateTabPaneItems(unit)
end

function addonTable:SelectGearDisplayTab()
    if not CharacterFrame:IsShown() then
        if ToggleCharacter then
            ToggleCharacter("PaperDollFrame")
        elseif ShowUIPanel then
            ShowUIPanel(CharacterFrame)
        end
    end

    -- Hide Blizzard's sidebar panes
    if CharacterStatsPane then CharacterStatsPane:Hide() end
    if PaperDollEquipmentManagerPane then PaperDollEquipmentManagerPane:Hide() end
    if PaperDollTitlesPane then PaperDollTitlesPane:Hide() end
    if PetPaperDollFrameCompanionFrame then PetPaperDollFrameCompanionFrame:Hide() end

    -- Deselect Blizzard sidebar tabs
    local tabs = { PaperDollSidebarTab1, PaperDollSidebarTab2, PaperDollSidebarTab3 }
    for _, tab in ipairs(tabs) do
        if tab then
            if tab.SetChecked then tab:SetChecked(false) end
            if tab.Hilight then tab.Hilight:Hide() end
            if tab.TabBg and tab.TabBg.SetTexCoord then
                tab.TabBg:SetTexCoord(0.01562500, 0.79687500, 0.61328125, 0.75781250)
            end
        end
    end

    self:CreateTabPane()
    if self.tabPane then
        self.tabPane:Show()
        self:UpdateTabPane("player")
    end

    self:ShowGear("player")
end

function addonTable:SelectStatsTab()
    if self.tabPane then
        self.tabPane:Hide()
    end
    self:HideGear()

    if PaperDollSidebarTab1 and PaperDollSidebarTab1:GetScript("OnClick") then
        PaperDollSidebarTab1:GetScript("OnClick")(PaperDollSidebarTab1)
    elseif PaperDollFrame_SetSidebar then
        PaperDollFrame_SetSidebar(PaperDollSidebarTab1, 1)
    elseif CharacterStatsPane then
        CharacterStatsPane:Show()
        if PaperDollSidebarTab1 and PaperDollSidebarTab1.Hilight then
            PaperDollSidebarTab1.Hilight:Show()
        end
    end
end

function addonTable:ToggleTab()
    if self.isShowing and self.tabPane and self.tabPane:IsShown() then
        self:SelectStatsTab()
    else
        self:SelectGearDisplayTab()
    end
end

function addonTable:HookSidebarTabs()
    if self.sidebarTabsHooked then return end

    local function OnBlizzardSidebarTabClicked()
        if addonTable.tabPane and addonTable.tabPane:IsShown() then
            addonTable.tabPane:Hide()
        end
        if addonTable.isShowing and addonTable.currentUnit == "player" then
            addonTable:HideGear()
        end
    end

    if PaperDollSidebarTab1 then
        PaperDollSidebarTab1:HookScript("OnClick", OnBlizzardSidebarTabClicked)
    end
    if PaperDollSidebarTab2 then
        PaperDollSidebarTab2:HookScript("OnClick", OnBlizzardSidebarTabClicked)
    end
    if PaperDollSidebarTab3 then
        PaperDollSidebarTab3:HookScript("OnClick", OnBlizzardSidebarTabClicked)
    end

    if PaperDollFrame_SetSidebar then
        hooksecurefunc("PaperDollFrame_SetSidebar", function(tab, tabId)
            if tabId ~= 4 then
                OnBlizzardSidebarTabClicked()
            end
        end)
    end

    self.sidebarTabsHooked = true
end

-- =========================================================================
-- Auto-Centering Mechanism
-- =========================================================================
function addonTable:CenterCharacterFrame()
    if self.isCentered or not CharacterFrame then return end

    local left = CharacterFrame:GetLeft()
    if left and left >= 350 then
        return
    end

    self.savedPoints = {}
    for i = 1, CharacterFrame:GetNumPoints() do
        local point, relativeTo, relativePoint, x, y = CharacterFrame:GetPoint(i)
        table.insert(self.savedPoints, { point, relativeTo, relativePoint, x, y })
    end

    CharacterFrame:SetMovable(true)
    CharacterFrame:SetUserPlaced(true)
    CharacterFrame:ClearAllPoints()
    CharacterFrame:SetPoint("CENTER", UIParent, "CENTER", 0, 20)
    self.isCentered = true
end

function addonTable:RestoreCharacterFrame()
    if not self.isCentered or not CharacterFrame then return end

    CharacterFrame:ClearAllPoints()
    if #self.savedPoints > 0 then
        for _, p in ipairs(self.savedPoints) do
            CharacterFrame:SetPoint(p[1], p[2], p[3], p[4], p[5])
        end
    else
        CharacterFrame:SetPoint("TOPLEFT", UIParent, "TOPLEFT", 16, -116)
    end

    CharacterFrame:SetUserPlaced(false)
    if UpdateUIPanelPositions then
        UpdateUIPanelPositions()
    end

    self.isCentered = false
    self.savedPoints = {}
end

-- =========================================================================
-- Button & Show/Hide Controls
-- =========================================================================
function addonTable:UpdateToggleButtonPosition()
    local btn = self.toggleBtn
    if not btn then return end

    -- Find the last visible sidebar tab (e.g. Pet tab, Equipment tab, or Character tab)
    local anchorTab = nil
    if PaperDollSidebarTab3 and PaperDollSidebarTab3:IsShown() then
        anchorTab = PaperDollSidebarTab3
    elseif PaperDollSidebarTab2 and PaperDollSidebarTab2:IsShown() then
        anchorTab = PaperDollSidebarTab2
    elseif PaperDollSidebarTab1 and PaperDollSidebarTab1:IsShown() then
        anchorTab = PaperDollSidebarTab1
    end

    btn:ClearAllPoints()

    if anchorTab then
        local parent = anchorTab:GetParent() or PaperDollSidebarTabs or PaperDollFrame or CharacterFrame
        btn:SetParent(parent)
        btn:SetFrameStrata(anchorTab:GetFrameStrata())
        btn:SetFrameLevel(anchorTab:GetFrameLevel())

        -- Match tab size dynamically
        local w, h = anchorTab:GetSize()
        if w and h and w > 0 and h > 0 then
            btn:SetSize(w, h)
            if btn.Icon then
                btn.Icon:SetSize(w - 6, h - 6)
            end
        end

        btn:SetPoint("LEFT", anchorTab, "RIGHT", 4, 0)
        btn:Show()
    else
        local parent = PaperDollFrame or CharacterFrame
        btn:SetParent(parent)
        btn:SetPoint("TOPRIGHT", parent, "TOPRIGHT", -38, -44)
        btn:Show()
    end
end

function addonTable:InitToggleButton()
    if self.toggleBtn then return end

    local anchorTab = PaperDollSidebarTab3 or PaperDollSidebarTab2 or PaperDollSidebarTab1
    local parent = (anchorTab and anchorTab:GetParent()) or PaperDollSidebarTabs or PaperDollFrame or CharacterFrame
    if not parent then return end

    local btn = CreateFrame("Button", "GearDisplayToggleBtn", parent)
    local width, height = 33, 35
    if anchorTab then
        local w, h = anchorTab:GetSize()
        if w and h and w > 0 and h > 0 then
            width, height = w, h
        end
    end
    btn:SetSize(width, height)
    btn.isIconButton = true

    -- Normal texture (clone from existing tab if available)
    local normalTex = (anchorTab and anchorTab:GetNormalTexture() and anchorTab:GetNormalTexture():GetTexture()) or "Interface\\Buttons\\UI-Quickslot2"
    btn:SetNormalTexture(normalTex)

    -- Pushed texture
    local pushedTex = anchorTab and anchorTab:GetPushedTexture() and anchorTab:GetPushedTexture():GetTexture()
    if pushedTex then
        btn:SetPushedTexture(pushedTex)
    end

    -- Highlight texture
    local hilightTex = (anchorTab and anchorTab:GetHighlightTexture() and anchorTab:GetHighlightTexture():GetTexture()) or "Interface\\Buttons\\ButtonHilight-Square"
    btn:SetHighlightTexture(hilightTex)

    -- Icon texture (Armor chestpiece)
    local icon = btn:CreateTexture(nil, "BACKGROUND")
    icon:SetSize(width - 6, height - 6)
    icon:SetPoint("CENTER", btn, "CENTER", 0, 0)
    icon:SetTexture("Interface\\Icons\\INV_Chest_Cloth_17")
    icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
    btn.Icon = icon

    -- Selected Gold Glowing Border (matching Tab 1 selected state)
    local sel = btn:CreateTexture(nil, "OVERLAY")
    sel:SetPoint("TOPLEFT", btn, "TOPLEFT", -2, 2)
    sel:SetPoint("BOTTOMRIGHT", btn, "BOTTOMRIGHT", 2, -2)
    sel:SetTexture("Interface\\Buttons\\UI-ActionButton-Border")
    sel:SetBlendMode("ADD")
    sel:SetVertexColor(1.0, 0.85, 0.1, 1.0)
    sel:Hide()
    btn.SelectedBorder = sel

    btn:SetScript("OnClick", function()
        addonTable:ToggleTab()
    end)

    btn:SetScript("OnEnter", function(s)
        GameTooltip:SetOwner(s, "ANCHOR_RIGHT")
        GameTooltip:AddLine(L["BTN_TOOLTIP_TITLE"], 1, 0.82, 0)
        GameTooltip:AddLine(L["BTN_TOOLTIP_DESC"], 1, 1, 1, true)
        GameTooltip:AddLine(" ", 1, 1, 1)
        GameTooltip:AddLine(L["BTN_TOOLTIP_TIPS_HEADER"], 1, 0.82, 0)
        GameTooltip:AddLine(L["BTN_TOOLTIP_TIP_LINK"], 0.8, 0.8, 0.8, true)
        GameTooltip:AddLine(L["BTN_TOOLTIP_TIP_DRESS"], 0.8, 0.8, 0.8, true)
        GameTooltip:AddLine(L["BTN_TOOLTIP_TIP_HOVER"], 0.8, 0.8, 0.8, true)
        GameTooltip:AddLine(L["BTN_TOOLTIP_TIP_CMD"], 0.7, 0.7, 0.7, true)
        GameTooltip:Show()
    end)

    btn:SetScript("OnLeave", function()
        GameTooltip:Hide()
    end)

    self.toggleBtn = btn
    self:UpdateToggleButtonPosition()
    self:HookSidebarTabs()

    -- Hook tab visibility changes so button automatically follows
    if PaperDollSidebarTab1 then
        PaperDollSidebarTab1:HookScript("OnShow", function() addonTable:UpdateToggleButtonPosition() end)
    end
    if PaperDollSidebarTab2 then
        PaperDollSidebarTab2:HookScript("OnShow", function() addonTable:UpdateToggleButtonPosition() end)
    end
    if PaperDollSidebarTab3 then
        PaperDollSidebarTab3:HookScript("OnShow", function() addonTable:UpdateToggleButtonPosition() end)
        PaperDollSidebarTab3:HookScript("OnHide", function() addonTable:UpdateToggleButtonPosition() end)
    end
    if PaperDollFrame then
        PaperDollFrame:HookScript("OnShow", function() addonTable:UpdateToggleButtonPosition() end)
    end
    if CharacterFrame then
        CharacterFrame:HookScript("OnShow", function() addonTable:UpdateToggleButtonPosition() end)
    end

    if PaperDollFrame_UpdateSidebarTabs then
        hooksecurefunc("PaperDollFrame_UpdateSidebarTabs", function()
            addonTable:UpdateToggleButtonPosition()
        end)
    end
end

function addonTable:InitInspectButton()
    if self.inspectBtn then return end

    local parent = InspectPaperDollFrame or InspectFrame
    if not parent then return end

    local btn = CreateFrame("Button", "GearDisplayInspectBtn", parent, "UIPanelButtonTemplate")
    btn:SetSize(84, 22)
    btn:SetPoint("TOPRIGHT", parent, "TOPRIGHT", -38, -44)
    btn:SetText(L["SHOW_GEAR"])

    btn:SetScript("OnClick", function()
        addonTable:Toggle("target")
    end)

    if InspectFrame then
        InspectFrame:HookScript("OnHide", function()
            if addonTable.currentUnit == "target" then
                addonTable:HideGear()
            end
        end)
    end

    self.inspectBtn = btn
    self:HookInspectSlotButtons()
end

function addonTable:UpdateButton(isShowing)
    local btn = self.toggleBtn
    if btn then
        if btn.SelectedBorder then
            if isShowing then
                btn.SelectedBorder:Show()
            else
                btn.SelectedBorder:Hide()
            end
        end
        if btn.SetText and not btn.isIconButton then
            btn:SetText(isShowing and L["HIDE_GEAR"] or L["SHOW_GEAR"])
        end
    end
    if self.inspectBtn and self.currentUnit == "target" then
        if self.inspectBtn.SelectedBorder then
            if isShowing then
                self.inspectBtn.SelectedBorder:Show()
            else
                self.inspectBtn.SelectedBorder:Hide()
            end
        end
        if self.inspectBtn.SetText and not self.inspectBtn.isIconButton then
            self.inspectBtn:SetText(isShowing and L["HIDE_GEAR"] or L["SHOW_GEAR"])
        end
    end
end

function addonTable:ShowGear(unit)
    unit = unit or "player"
    self.currentUnit = unit

    local targetFrame = (unit == "player") and CharacterFrame or InspectFrame
    if not targetFrame or not targetFrame:IsShown() then
        if unit == "player" then
            if ToggleCharacter then
                ToggleCharacter("PaperDollFrame")
            elseif ShowUIPanel then
                ShowUIPanel(CharacterFrame)
            end
        end
    end

    if unit == "player" and GearDisplayDB.autoCenter then
        self:CenterCharacterFrame()
    end

    self:CreateTooltips()

    if unit == "player" then
        self:CreateTabPane()
        if CharacterStatsPane then CharacterStatsPane:Hide() end
        if PaperDollEquipmentManagerPane then PaperDollEquipmentManagerPane:Hide() end
        if PaperDollTitlesPane then PaperDollTitlesPane:Hide() end
        if PetPaperDollFrameCompanionFrame then PetPaperDollFrameCompanionFrame:Hide() end
        if self.tabPane then
            self.tabPane:Show()
            self:UpdateTabPane(unit)
        end
    end

    for _, slot in ipairs(SLOTS_DATA) do
        local tt = self.tooltips[slot.id]
        if tt then
            self:PopulateTooltip(tt, slot.id, unit)
        end
    end

    self:LayoutTooltips(targetFrame)
    self:UpdateButton(true)
    self.isShowing = true
end

function addonTable:HideGear()
    if not self.isShowing and not (self.tabPane and self.tabPane:IsShown()) then return end

    for _, tt in pairs(self.tooltips) do
        tt:Hide()
        tt.itemLink = nil
        tt.slotId = nil
    end

    if self.tabPane then
        self.tabPane:Hide()
    end

    self:ClearAllHighlights()

    if self.currentUnit == "player" and GearDisplayDB.autoCenter then
        self:RestoreCharacterFrame()
    end

    self:UpdateButton(false)
    self.isShowing = false
    self.currentUnit = nil
end

function addonTable:Toggle(unit)
    if self.isShowing then
        self:HideGear()
    else
        self:ShowGear(unit)
    end
end

function addonTable:RefreshGear()
    if not self.isShowing then return end
    local unit = self.currentUnit or "player"
    local targetFrame = (unit == "player") and CharacterFrame or InspectFrame
    if not targetFrame then return end

    for _, slot in ipairs(SLOTS_DATA) do
        local tt = self.tooltips[slot.id]
        if tt then
            self:PopulateTooltip(tt, slot.id, unit)
        end
    end

    self:LayoutTooltips(targetFrame)
    if unit == "player" and self.tabPane and self.tabPane:IsShown() then
        self:UpdateTabPane(unit)
    end
end

-- =========================================================================
-- Event Handling & Initialization
-- =========================================================================
local eventFrame = CreateFrame("Frame")
eventFrame:RegisterEvent("PLAYER_LOGIN")
eventFrame:RegisterEvent("ADDON_LOADED")
eventFrame:RegisterEvent("PLAYER_EQUIPMENT_CHANGED")
eventFrame:RegisterEvent("UNIT_INVENTORY_CHANGED")
eventFrame:RegisterEvent("GET_ITEM_INFO_RECEIVED")
eventFrame:RegisterEvent("UNIT_PET")

eventFrame:SetScript("OnEvent", function(self, event, arg1, ...)
    if event == "PLAYER_LOGIN" then
        addonTable:InitDB()
        addonTable:InitToggleButton()
        addonTable:HookSidebarTabs()
        addonTable:HookSlotButtons()
        addonTable:RegisterSettingsCategory()

        if CharacterFrame then
            CharacterFrame:HookScript("OnShow", function()
                addonTable:UpdateToggleButtonPosition()
            end)
            CharacterFrame:HookScript("OnHide", function()
                if addonTable.isShowing and addonTable.currentUnit == "player" then
                    addonTable:HideGear()
                end
            end)
        end

        if PaperDollFrame then
            PaperDollFrame:HookScript("OnShow", function()
                addonTable:UpdateToggleButtonPosition()
            end)
            PaperDollFrame:HookScript("OnHide", function()
                if addonTable.isShowing and addonTable.currentUnit == "player" then
                    addonTable:HideGear()
                end
            end)
        end

    elseif event == "ADDON_LOADED" then
        if arg1 == "Blizzard_InspectUI" then
            addonTable:InitInspectButton()
        end

    elseif event == "UNIT_PET" then
        if arg1 == "player" then
            addonTable:UpdateToggleButtonPosition()
        end

    elseif event == "PLAYER_EQUIPMENT_CHANGED" then
        if addonTable.isShowing and addonTable.currentUnit == "player" then
            addonTable:RefreshGear()
        end

    elseif event == "UNIT_INVENTORY_CHANGED" then
        if addonTable.isShowing and arg1 == addonTable.currentUnit then
            addonTable:RefreshGear()
        end

    elseif event == "GET_ITEM_INFO_RECEIVED" then
        if addonTable.isShowing then
            addonTable:RefreshGear()
        end
    end
end)
