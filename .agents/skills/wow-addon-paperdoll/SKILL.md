---
name: wow-addon-paperdoll
description: >-
  Comprehensive guide and reference for World of Warcraft addon development, focusing on
  Character Frame (Paper Doll) integration, sidebar tab positioning, multi-flavor API compatibility
  (Modern Mainline, Dragonflight/TWW, WoW Forever/Camelot, and Classic Era), and custom GameTooltip architecture.
---

# World of Warcraft Addon Development & Paper Doll Integration

This skill provides patterns, architecture guidelines, and proven workarounds for developing World of Warcraft addons that integrate with the **Character Frame (`PaperDollFrame`)**, create custom **`GameTooltip`** displays, and support modern WoW client engines (Dragonflight, The War Within, WoW Forever/Camelot build 16001, and Classic Era).

---

## 1. Character Frame & Sidebar Tabs Architecture

### 1.1 The Sidebar Tab Row (`PaperDollSidebarTabs`)
In modern and mid-expansion clients (MoP+ and Dragonflight/Mainline), the top-right of the Character Sheet features square icon tabs:
- **Tab 1 (`PaperDollSidebarTab1`)**: Character Stats (Player portrait icon).
- **Tab 2 (`PaperDollSidebarTab2`)**: Equipment Manager (Helm with crossed swords).
- **Tab 3 (`PaperDollSidebarTab3`)**: Pet / Companion (Pet icon, dynamically shown/hidden depending on class and active pet).

### 1.2 Dynamic Anchoring for Custom Tabs
When adding an addon button beside these tabs, **never** hardcode an absolute offset from `CharacterFrame`. The Pet tab (`PaperDollSidebarTab3`) dynamically shows and hides, which will cause overlapping or gaps.

```lua
function addonTable:UpdateToggleButtonPosition()
    local btn = self.toggleBtn
    if not btn then return end

    -- Find rightmost visible sidebar tab
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
            if btn.Icon then btn.Icon:SetSize(w - 6, h - 6) end
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
```

### 1.3 Essential Hooks for Dynamic Tab Visibility
To ensure the custom tab repositions whenever the player summons, dismisses, or switches pets:
```lua
-- Hook tab show/hide events
if PaperDollSidebarTab1 then PaperDollSidebarTab1:HookScript("OnShow", function() addonTable:UpdateToggleButtonPosition() end) end
if PaperDollSidebarTab2 then PaperDollSidebarTab2:HookScript("OnShow", function() addonTable:UpdateToggleButtonPosition() end) end
if PaperDollSidebarTab3 then
    PaperDollSidebarTab3:HookScript("OnShow", function() addonTable:UpdateToggleButtonPosition() end)
    PaperDollSidebarTab3:HookScript("OnHide", function() addonTable:UpdateToggleButtonPosition() end)
end

-- Secure hook for internal Blizzard tab layout updates
if PaperDollFrame_UpdateSidebarTabs then
    hooksecurefunc("PaperDollFrame_UpdateSidebarTabs", function()
        addonTable:UpdateToggleButtonPosition()
    end)
end

-- Event hook for pet state changes
-- In OnEvent:
if event == "UNIT_PET" and arg1 == "player" then
    addonTable:UpdateToggleButtonPosition()
end
```

### 1.4 Native Blizzard Tab Styling & Active Glow
To make custom buttons visually indistinguishable from Blizzard sidebar tabs:
```lua
local btn = CreateFrame("Button", "MyCustomSidebarBtn", parent)
btn:SetSize(33, 35)

-- Textures
btn:SetNormalTexture("Interface\\Buttons\\UI-Quickslot2")
btn:SetHighlightTexture("Interface\\Buttons\\ButtonHilight-Square")

-- Icon inset (trim standard 2px icon borders)
local icon = btn:CreateTexture(nil, "BACKGROUND")
icon:SetSize(27, 29)
icon:SetPoint("CENTER", btn, "CENTER", 0, 0)
icon:SetTexture("Interface\\Icons\\INV_Chest_Cloth_17")
icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
btn.Icon = icon

-- Gold active/selected glow border (matches selected sidebar tab)
local sel = btn:CreateTexture(nil, "OVERLAY")
sel:SetPoint("TOPLEFT", btn, "TOPLEFT", -2, 2)
sel:SetPoint("BOTTOMRIGHT", btn, "BOTTOMRIGHT", 2, -2)
sel:SetTexture("Interface\\Buttons\\UI-ActionButton-Border")
sel:SetBlendMode("ADD")
sel:SetVertexColor(1.0, 0.85, 0.1, 1.0)
sel:Hide()
btn.SelectedBorder = sel
```

### 1.5 Dedicated Sidebar Tab Pane Integration
Rather than using floating windows or hovering bars above the character sheet, custom addons can create a dedicated pane directly inside `PaperDollFrame` (in the right sidebar area normally occupied by `CharacterStatsPane` or `PaperDollEquipmentManagerPane`):

```lua
-- Create custom pane matching Blizzard's stats pane
local parent = PaperDollFrame or CharacterFrame
local pane = CreateFrame("Frame", "MyCustomTabPane", parent, BackdropTemplateMixin and "BackdropTemplate" or nil)

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
```

#### Mutual Exclusivity and Clean Tab Switching
To maintain seamless UX with Blizzard's native tabs:
1. When selecting the custom tab, hide Blizzard panes (`CharacterStatsPane`, `PaperDollEquipmentManagerPane`, `PaperDollTitlesPane`, `PetPaperDollFrameCompanionFrame`) and deselect Blizzard tabs.
2. Hook `PaperDollSidebarTab1..3:HookScript("OnClick", ...)` and `hooksecurefunc("PaperDollFrame_SetSidebar", ...)` so switching to any Blizzard tab automatically hides the custom pane and un-centers the frame.
3. Clicking the custom tab when already active toggles back to `PaperDollSidebarTab1` (`CharacterStatsPane`).

---

## 2. Tooltip Architecture & Modern Mainline Gotchas

### 2.1 The `tooltip:ProcessInfo(data)` Trap
> [!CAUTION]
> **DO NOT** call `tooltip:ProcessInfo(data)` from an addon.
>
> In WoW 10.0+ (Dragonflight, The War Within, WoW Forever), `tooltip:ProcessInfo(data)` is an internal pipeline method belonging to `TooltipDataHandlerMixin`. It dispatches data callbacks to `TooltipDataProcessor`, but **does NOT render fontstrings or generate tooltip lines**.
> Calling it directly bypasses `tooltip:SetInventoryItem` / `tooltip:SetHyperlink` and results in completely empty/blank tooltips (0 height, 0 lines).

### 2.2 Correct Custom Tooltip Creation & Population
Always create custom GameTooltips with `GameTooltipTemplate`, set frame strata to `DIALOG` or `TOOLTIP`, and use standard public API methods:

```lua
-- Creation
local template = BackdropTemplateMixin and "BackdropTemplate,GameTooltipTemplate" or "GameTooltipTemplate"
local tt = CreateFrame("GameTooltip", "MyTooltip", UIParent, template)
tt:SetScript("OnUpdate", nil) -- Prevents default mouseover fadeout
tt:SetFrameStrata("DIALOG")   -- Guarantees tooltip sits above CharacterFrame
tt:SetFrameLevel(100)
tt:SetClampedToScreen(true)

-- Population
function PopulateItemTooltip(tooltip, unit, slotId, itemLink)
    tooltip:SetOwner(UIParent, "ANCHOR_NONE")
    tooltip:ClearLines()

    -- 1. Primary: Standard Blizzard SetInventoryItem
    local hasLines = false
    if tooltip.SetInventoryItem then
        local ok = pcall(tooltip.SetInventoryItem, tooltip, unit, slotId)
        if ok and tooltip:NumLines() and tooltip:NumLines() > 0 then
            hasLines = true
        end
    end

    -- 2. Fallback: SetHyperlink using verified itemLink
    if (not hasLines or (tooltip:NumLines() and tooltip:NumLines() == 0)) and itemLink and tooltip.SetHyperlink then
        pcall(tooltip.SetHyperlink, tooltip, itemLink)
    end

    tooltip:Show()
end
```

---

## 3. Multi-Flavor API Compatibility & Safe Wrappers

Modern WoW moved legacy globals into namespaces (`C_Item`, `C_TooltipInfo`, `Settings`). To support both modern Mainline/WoW Forever and Classic Era/Vanilla clients seamlessly:

### 3.1 Safe Item Link Retrieval
`GetInventoryItemLink("unit", slotId)` is universally available across all clients, whereas `C_Item.GetItemLink(itemLocation)` requires an `ItemLocation` structure.

```lua
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
```

### 3.2 Safe Item Quality & Zero-Latency Color Extraction
Items may not be cached immediately upon login or zone change. Extracting the hex color from the item link string (`|cffRRGGBB`) provides instantaneous, non-blocking rarity coloring:

```lua
local function SafeGetItemQualityColor(quality, itemLink)
    -- 1. Try C_Item / GetItemQualityColor
    if quality ~= nil then
        if C_Item and C_Item.GetItemQualityColor then
            local res1, res2, res3 = C_Item.GetItemQualityColor(quality)
            if type(res1) == "table" and res1.r and res1.g and res1.b then
                return res1.r, res1.g, res1.b -- ColorMixin
            elseif type(res1) == "number" and type(res2) == "number" and type(res3) == "number" then
                return res1, res2, res3
            end
        end
        if GetItemQualityColor then
            local r, g, b = GetItemQualityColor(quality)
            if r and g and b then return r, g, b end
        end
    end

    -- 2. Zero-latency fallback: parse hex directly from hyperlink
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

    return 0.6, 0.6, 0.6 -- Default neutral gray
end
```

### 3.3 Modern Settings API vs Legacy Interface Options
Starting in 10.0, `InterfaceOptions_AddCategory` was deprecated and later removed. Use `Settings.RegisterCanvasLayoutCategory`:

```lua
function RegisterAddonSettings(frame, name)
    if Settings and Settings.RegisterCanvasLayoutCategory and Settings.RegisterAddOnCategory then
        local category = Settings.RegisterCanvasLayoutCategory(frame, name)
        category.ID = name
        Settings.RegisterAddOnCategory(category)
    elseif InterfaceOptions_AddCategory then
        InterfaceOptions_AddCategory(frame)
    end
end
```

---

## 4. Equipment Slot Button Hierarchy

In Classic Era, slot buttons exist in `_G` (e.g., `_G["CharacterHeadSlot"]`). In modern Mainline, they are children of `PaperDollItemsFrame` (e.g., `PaperDollItemsFrame.HeadSlot` or `PaperDollItemsFrame["HeadSlot"]`).

```lua
local function GetSlotButton(slotKey, slotName, isInspect)
    local globalName = isInspect and ("Inspect" .. slotKey) or ("Character" .. slotKey)
    local btn = _G[globalName]
    if btn then return btn end

    if not isInspect and PaperDollItemsFrame and slotName then
        btn = PaperDollItemsFrame[slotName]
        if btn then return btn end
    end
    if isInspect and InspectPaperDollItemsFrame and slotName then
        btn = InspectPaperDollItemsFrame[slotName]
        if btn then return btn end
    end
    return nil
end
```

### Bi-Directional Hover Highlighting
To link hover states between character sheet buttons and custom tooltips:
- Use `slotButton:LockHighlight()` and `slotButton:UnlockHighlight()` to highlight character sheet slots when hovering custom UI elements.
- Hook `slotButton:HookScript("OnEnter", ...)` and `slotButton:HookScript("OnLeave", ...)` to highlight corresponding custom elements.
