-- Must type-check with 0 errors: `tl check types/tests/smoke.tl` (from the addon root).
-- Exercises the patterns addons rely on; keep it in sync when declarations change.

local record Namespace
   L: {string:string}
end
local addonName, ns = ... as (string, Namespace)
print(addonName, ns.L["TITLE"])

-- CreateFrame overloads pick the widget type from the literal
local f = CreateFrame("Frame", "SmokeFrame", UIParent)
local b = CreateFrame("Button", nil, f, "UIPanelButtonTemplate")
local cb = CreateFrame("CheckButton", nil, f)
local s = CreateFrame("Slider", nil, f)
local tt = CreateFrame("GameTooltip", "SmokeTooltip", UIParent, "GameTooltipTemplate")
b:Click()
cb:SetChecked(true)
s:SetMinMaxValues(0, 1)
tt:SetOwner(f, "ANCHOR_RIGHT")
tt:AddLine("hi", 1, 1, 1, true)

-- SetPoint overloads
f:SetPoint("CENTER")
f:SetPoint("TOPLEFT", 10, -10)
f:SetPoint("TOPLEFT", UIParent, "TOPRIGHT", 0, 0)
f:SetPoint("TOPLEFT", "UIParent", "TOPRIGHT")
f:SetAllPoints()
f:SetFrameStrata("HIGH")
f:SetSize(100, 50)

-- Regions
local tex = f:CreateTexture(nil, "ARTWORK")
tex:SetTexture("Interface/Icons/INV_Misc_QuestionMark")
tex:SetAllPoints(f)
local fs = f:CreateFontString(nil, "OVERLAY", "GameFontNormal")
fs:SetText("hello")

-- Script handlers: `self` is the widget type
b:SetScript("OnClick", function(self: Button, button: string, down: boolean)
   self:Disable()
   print(button, down)
end)
f:SetScript("OnEnter", function(self: Frame)
   GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
   GameTooltip:AddLine("tip")
   GameTooltip:Show()
end)
f:SetScript("OnLeave", function() GameTooltip:Hide() end)
f:RegisterEvent("PLAYER_EQUIPMENT_CHANGED")
f:SetScript("OnEvent", function(_: Frame, event: string, ...: any)
   print(event, ...)
end)
f:HookScript("OnShow", function(self: Frame) self:Raise() end)

-- C API
local link = GetInventoryItemLink("player", 1)
if link then
   local name, _, quality = C_Item.GetItemInfo(link)
   local r, g, bb = C_Item.GetItemQualityColor(quality)
   print(name, r, g, bb)
end
local loc = ItemLocation:CreateFromEquipmentSlot(1)
if loc:IsValid() and C_Item.DoesItemExist(loc) then
   print(C_Item.GetItemLink(loc))
end
local timer = C_Timer.NewTimer(0.5, function() end)
timer:Cancel()
C_Timer.After(1, function() print("later") end)
print(Enum.ItemQuality.Epic, UnitGUID("player"), InCombatLockdown(), IsShiftKeyDown())

-- FrameXML + Lua extensions
hooksecurefunc("ToggleCharacter", function(tab: string) print(tab) end)
hooksecurefunc(GameTooltip, "Show", function() end)
ShowUIPanel(CharacterFrame)
local category = Settings.RegisterCanvasLayoutCategory(f, "Smoke")
Settings.RegisterAddOnCategory(category)
tinsert(UISpecialFrames, "SmokeFrame")
local a, bpart = strsplit(",", "a,b")
print(a, bpart, format("%d", 1), wipe({}))

local bd = CreateFrame("Frame", nil, f, "BackdropTemplate") as BackdropFrame
bd:SetBackdropBorderColor(1, 1, 1, 1)
