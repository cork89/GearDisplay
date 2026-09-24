local addonName, addonTable = ...
local L = addonTable.L

local DEFAULTS = {
    scale = 1.00,
    autoCenter = true,
    qualityBorders = true,
    showCosmetics = false,
    showSummary = true,
    hideDefaultTooltipOnHover = false,
    layout = "grid", -- "grid" or "single"
}

function addonTable:InitDB()
    if type(GearDisplayDB) ~= "table" then
        GearDisplayDB = {}
    end
    for k, v in pairs(DEFAULTS) do
        if GearDisplayDB[k] == nil then
            GearDisplayDB[k] = v
        end
    end
end

function addonTable:ResetDB()
    GearDisplayDB = {}
    for k, v in pairs(DEFAULTS) do
        GearDisplayDB[k] = v
    end
    if self.configFrame and self.configFrame:IsShown() then
        self:RefreshConfigFrame()
    end
    if self.tabPane and self.tabPane:IsShown() then
        self:RefreshTabPaneSettings()
    end
    if self.isShowing then
        self:RefreshGear()
    end
    print("|cff00ff00" .. L["MSG_RESET"] .. "|r")
end

-- =========================================================================
-- Slash Commands
-- =========================================================================
SLASH_GEARDISPLAY1 = "/geardisplay"
SLASH_GEARDISPLAY2 = "/gd"

local function SyncSettingsUI()
    if addonTable.configFrame and addonTable.configFrame:IsShown() then
        addonTable:RefreshConfigFrame()
    end
    if addonTable.tabPane and addonTable.tabPane:IsShown() then
        addonTable:RefreshTabPaneSettings()
    end
end

SlashCmdList["GEARDISPLAY"] = function(msg)
    local cmd, arg = msg:match("^(%S*)%s*(.-)$")
    cmd = (cmd or ""):lower()
    arg = (arg or ""):lower()

    if cmd == "" then
        if addonTable.ToggleTab then
            addonTable:ToggleTab()
        else
            addonTable:Toggle("player")
        end
    elseif cmd == "config" or cmd == "options" or cmd == "opt" then
        addonTable:ToggleConfig()
    elseif cmd == "autocenter" or cmd == "center" then
        GearDisplayDB.autoCenter = not GearDisplayDB.autoCenter
        print(GearDisplayDB.autoCenter and L["MSG_AUTOCENTER_ON"] or L["MSG_AUTOCENTER_OFF"])
        SyncSettingsUI()
    elseif cmd == "quality" or cmd == "border" or cmd == "borders" then
        GearDisplayDB.qualityBorders = not GearDisplayDB.qualityBorders
        print(GearDisplayDB.qualityBorders and L["MSG_QUALITY_ON"] or L["MSG_QUALITY_OFF"])
        if addonTable.isShowing then
            addonTable:RefreshGear()
        end
        SyncSettingsUI()
    elseif cmd == "layout" then
        if GearDisplayDB.layout == "grid" then
            GearDisplayDB.layout = "single"
            print(L["MSG_LAYOUT_SINGLE"])
        else
            GearDisplayDB.layout = "grid"
            print(L["MSG_LAYOUT_GRID"])
        end
        if addonTable.isShowing then
            addonTable:RefreshGear()
        end
        SyncSettingsUI()
    elseif cmd == "scale" then
        local num = tonumber(arg)
        if num and num >= 0.5 and num <= 1.5 then
            GearDisplayDB.scale = num
            print(string.format(L["MSG_SCALE_SET"], math.floor(num * 100 + 0.5)))
            if addonTable.isShowing then
                addonTable:RefreshGear()
            end
            SyncSettingsUI()
        else
            print(L["MSG_SCALE_INVALID"])
        end
    elseif cmd == "reset" then
        addonTable:ResetDB()
    else
        print("|cff00ff00" .. L["CMD_HELP_HEADER"] .. "|r")
        print(L["CMD_HELP_TOGGLE"])
        print(L["CMD_HELP_CONFIG"])
        print(L["CMD_HELP_AUTOCENTER"])
        print(L["CMD_HELP_QUALITY"])
        print(L["CMD_HELP_LAYOUT"])
        print(L["CMD_HELP_SCALE"])
        print(L["CMD_HELP_RESET"])
    end
end

-- =========================================================================
-- Graphical Configuration Frame
-- =========================================================================
function addonTable:ToggleConfig()
    if not self.configFrame then
        self:CreateConfigFrame()
    end
    if self.configFrame:IsShown() then
        self.configFrame:Hide()
    else
        self:RefreshConfigFrame()
        self.configFrame:Show()
    end
end

function addonTable:CreateConfigFrame()
    if self.configFrame then return end

    local template = BackdropTemplateMixin and "BackdropTemplate,BasicFrameTemplateWithInset" or "BasicFrameTemplateWithInset"
    local f = CreateFrame("Frame", "GearDisplayConfigFrame", UIParent, template)
    f:SetSize(360, 390)
    f:SetPoint("CENTER")
    f:SetFrameStrata("DIALOG")
    f:SetMovable(true)
    f:EnableMouse(true)
    f:RegisterForDrag("LeftButton")
    f:SetScript("OnDragStart", f.StartMoving)
    f:SetScript("OnDragStop", f.StopMovingOrSizing)
    f:SetClampedToScreen(true)

    -- Allow ESC to close
    tinsert(UISpecialFrames, "GearDisplayConfigFrame")

    -- Title
    f.title = f:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    f.title:SetPoint("TOP", f, "TOP", 0, -5)
    f.title:SetText(L["CONFIG_TITLE"])

    local content = CreateFrame("Frame", nil, f)
    content:SetPoint("TOPLEFT", f, "TOPLEFT", 12, -32)
    content:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", -12, 40)
    f.content = content

    -- Checkbox helper
    local function CreateCheck(text, ttDesc, dbKey, yOff)
        local cb = CreateFrame("CheckButton", nil, content, "InterfaceOptionsCheckButtonTemplate")
        cb:SetPoint("TOPLEFT", content, "TOPLEFT", 8, yOff)
        local label = cb.Text or _G[cb:GetName() .. "Text"]
        if label then
            label:SetText(text)
            label:SetFontObject(GameFontNormal)
        end
        cb:SetScript("OnClick", function(self)
            GearDisplayDB[dbKey] = self:GetChecked()
            if addonTable.isShowing then
                addonTable:RefreshGear()
            end
        end)
        cb:SetScript("OnEnter", function(self)
            GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
            GameTooltip:AddLine(text, 1, 0.82, 0)
            GameTooltip:AddLine(ttDesc, 1, 1, 1, true)
            GameTooltip:Show()
        end)
        cb:SetScript("OnLeave", function() GameTooltip:Hide() end)
        return cb
    end

    f.cbAutoCenter = CreateCheck(L["CONFIG_AUTO_CENTER"], L["CONFIG_AUTO_CENTER_TT"], "autoCenter", 0)
    f.cbQuality = CreateCheck(L["CONFIG_QUALITY_BORDERS"], L["CONFIG_QUALITY_BORDERS_TT"], "qualityBorders", -30)
    f.cbCosmetics = CreateCheck(L["CONFIG_SHOW_COSMETICS"], L["CONFIG_SHOW_COSMETICS_TT"], "showCosmetics", -60)
    f.cbSummary = CreateCheck(L["CONFIG_SHOW_SUMMARY"], L["CONFIG_SHOW_SUMMARY_TT"], "showSummary", -90)
    f.cbHideDefault = CreateCheck(L["CONFIG_HIDE_DEFAULT_TT"], L["CONFIG_HIDE_DEFAULT_TT_TT"], "hideDefaultTooltipOnHover", -120)

    -- Layout Mode Section
    local layoutLabel = content:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    layoutLabel:SetPoint("TOPLEFT", content, "TOPLEFT", 10, -162)
    layoutLabel:SetText(L["CONFIG_LAYOUT_LABEL"] .. ":")

    local btnGrid = CreateFrame("Button", nil, content, "UIPanelButtonTemplate")
    btnGrid:SetSize(140, 24)
    btnGrid:SetPoint("TOPLEFT", layoutLabel, "BOTTOMLEFT", 0, -8)
    btnGrid:SetText(L["CONFIG_LAYOUT_GRID"])
    btnGrid:SetScript("OnClick", function()
        GearDisplayDB.layout = "grid"
        addonTable:RefreshConfigFrame()
        if addonTable.isShowing then
            addonTable:RefreshGear()
        end
    end)
    btnGrid:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:AddLine(L["CONFIG_LAYOUT_GRID"], 1, 0.82, 0)
        GameTooltip:AddLine(L["CONFIG_LAYOUT_GRID_TT"], 1, 1, 1, true)
        GameTooltip:Show()
    end)
    btnGrid:SetScript("OnLeave", function() GameTooltip:Hide() end)
    f.btnGrid = btnGrid

    local btnSingle = CreateFrame("Button", nil, content, "UIPanelButtonTemplate")
    btnSingle:SetSize(140, 24)
    btnSingle:SetPoint("LEFT", btnGrid, "RIGHT", 12, 0)
    btnSingle:SetText(L["CONFIG_LAYOUT_SINGLE"])
    btnSingle:SetScript("OnClick", function()
        GearDisplayDB.layout = "single"
        addonTable:RefreshConfigFrame()
        if addonTable.isShowing then
            addonTable:RefreshGear()
        end
    end)
    btnSingle:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:AddLine(L["CONFIG_LAYOUT_SINGLE"], 1, 0.82, 0)
        GameTooltip:AddLine(L["CONFIG_LAYOUT_SINGLE_TT"], 1, 1, 1, true)
        GameTooltip:Show()
    end)
    btnSingle:SetScript("OnLeave", function() GameTooltip:Hide() end)
    f.btnSingle = btnSingle

    -- Scale Slider
    local slider = CreateFrame("Slider", "GearDisplayScaleSlider", content, "OptionsSliderTemplate")
    slider:SetPoint("TOPLEFT", btnGrid, "BOTTOMLEFT", 10, -36)
    slider:SetWidth(290)
    slider:SetMinMaxValues(0.60, 1.20)
    slider:SetValueStep(0.05)
    slider:SetObeyStepOnDrag(true)

    local sLabel = _G[slider:GetName() .. "Text"]
    local sLow = _G[slider:GetName() .. "Low"]
    local sHigh = _G[slider:GetName() .. "High"]
    if sLow then sLow:SetText("60%") end
    if sHigh then sHigh:SetText("120%") end

    slider:SetScript("OnValueChanged", function(self, value)
        value = math.floor(value * 20 + 0.5) / 20 -- Round to 0.05
        GearDisplayDB.scale = value
        if sLabel then
            sLabel:SetText(string.format("%s: %d%%", L["CONFIG_SCALE_LABEL"], math.floor(value * 100 + 0.5)))
        end
        if addonTable.isShowing then
            addonTable:RefreshGear()
        end
    end)
    slider:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:AddLine(L["CONFIG_SCALE_LABEL"], 1, 0.82, 0)
        GameTooltip:AddLine(L["CONFIG_SCALE_TT"], 1, 1, 1, true)
        GameTooltip:Show()
    end)
    slider:SetScript("OnLeave", function() GameTooltip:Hide() end)
    f.scaleSlider = slider

    -- Bottom Buttons
    local resetBtn = CreateFrame("Button", nil, f, "UIPanelButtonTemplate")
    resetBtn:SetSize(120, 22)
    resetBtn:SetPoint("BOTTOMLEFT", f, "BOTTOMLEFT", 16, 12)
    resetBtn:SetText(L["CONFIG_RESET_DEFAULTS"])
    resetBtn:SetScript("OnClick", function()
        addonTable:ResetDB()
    end)

    local closeBtn = CreateFrame("Button", nil, f, "UIPanelButtonTemplate")
    closeBtn:SetSize(90, 22)
    closeBtn:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", -16, 12)
    closeBtn:SetText(L["CONFIG_CLOSE"])
    closeBtn:SetScript("OnClick", function()
        f:Hide()
    end)

    f:Hide()
    self.configFrame = f
end

function addonTable:RefreshConfigFrame()
    local f = self.configFrame
    if not f then return end

    f.cbAutoCenter:SetChecked(GearDisplayDB.autoCenter)
    f.cbQuality:SetChecked(GearDisplayDB.qualityBorders)
    f.cbCosmetics:SetChecked(GearDisplayDB.showCosmetics)
    f.cbSummary:SetChecked(GearDisplayDB.showSummary)
    f.cbHideDefault:SetChecked(GearDisplayDB.hideDefaultTooltipOnHover)

    if GearDisplayDB.layout == "single" then
        f.btnSingle:Disable()
        f.btnGrid:Enable()
    else
        f.btnGrid:Disable()
        f.btnSingle:Enable()
    end

    local curScale = GearDisplayDB.scale or 0.85
    f.scaleSlider:SetValue(curScale)
    local sLabel = _G[f.scaleSlider:GetName() .. "Text"]
    if sLabel then
        sLabel:SetText(string.format("%s: %d%%", L["CONFIG_SCALE_LABEL"], math.floor(curScale * 100 + 0.5)))
    end
end

-- Modern Mainline Settings Registration (ESC -> Options -> AddOns -> Gear Display)
function addonTable:RegisterSettingsCategory()
    if self.settingsCategoryRegistered then return end

    local f = CreateFrame("Frame", "GearDisplaySettingsPanel", UIParent)
    f.name = L["ADDON_TITLE"]

    local title = f:CreateFontString(nil, "ARTWORK", "GameFontNormalLarge")
    title:SetPoint("TOPLEFT", f, "TOPLEFT", 16, -16)
    title:SetText(L["ADDON_TITLE"])

    local desc = f:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
    desc:SetPoint("TOPLEFT", title, "BOTTOMLEFT", 0, -8)
    desc:SetText(L["BTN_TOOLTIP_DESC"])

    local openBtn = CreateFrame("Button", nil, f, "UIPanelButtonTemplate")
    openBtn:SetSize(190, 26)
    openBtn:SetPoint("TOPLEFT", desc, "BOTTOMLEFT", 0, -16)
    openBtn:SetText("Open Settings Window")
    openBtn:SetScript("OnClick", function()
        if SettingsPanel and SettingsPanel:IsShown() then
            HideUIPanel(SettingsPanel)
        end
        addonTable:ToggleConfig()
    end)

    if Settings and Settings.RegisterCanvasLayoutCategory and Settings.RegisterAddOnCategory then
        local category = Settings.RegisterCanvasLayoutCategory(f, f.name)
        category.ID = f.name
        Settings.RegisterAddOnCategory(category)
        self.settingsCategoryRegistered = true
    elseif InterfaceOptions_AddCategory then
        InterfaceOptions_AddCategory(f)
        self.settingsCategoryRegistered = true
    end
end

