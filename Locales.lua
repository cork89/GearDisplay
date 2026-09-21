local addonName, addonTable = ...
_G[addonName] = addonTable

local L = {}
addonTable.L = L

-- English / Default strings
L["ADDON_TITLE"] = "Gear Display"
L["SHOW_GEAR"] = "Show Gear"
L["HIDE_GEAR"] = "Hide Gear"
L["BTN_TOOLTIP_TITLE"] = "Gear Display"
L["BTN_TOOLTIP_DESC"] = "Click to display all equipped gear tooltips surrounding your character sheet."
L["BTN_TOOLTIP_TIPS_HEADER"] = "Tips & Controls:"
L["BTN_TOOLTIP_TIP_LINK"] = "• Shift-Click any tooltip to link item in chat."
L["BTN_TOOLTIP_TIP_DRESS"] = "• Ctrl-Click any tooltip to preview in Dressing Room."
L["BTN_TOOLTIP_TIP_HOVER"] = "• Hovering slots on the character sheet highlights the corresponding tooltip."
L["BTN_TOOLTIP_TIP_CMD"] = "• Type /gd or /geardisplay for slash commands."

-- Header Bar / Tab Pane
L["HEADER_TITLE"] = "Gear Display"
L["HEADER_EQUIPPED"] = "Equipped"
L["HEADER_AVG_ILVL"] = "Avg iLvl"
L["HEADER_DURABILITY"] = "Durability"
L["HEADER_SETTINGS_TT"] = "Gear Display Settings"
L["HEADER_CLOSE_TT"] = "Close Gear Display"

L["TAB_TITLE"] = "Gear Display"
L["TAB_SUBTITLE"] = "Equipped Overview & Options"
L["TAB_REFRESH"] = "Refresh"
L["TAB_HIDE"] = "Hide Gear"
L["TAB_ITEMS_HEADER"] = "Equipped Items"
L["TAB_NO_ITEMS"] = "No items equipped"

-- Options Window
L["CONFIG_TITLE"] = "Gear Display Options"
L["CONFIG_AUTO_CENTER"] = "Auto-Center Character Sheet"
L["CONFIG_AUTO_CENTER_TT"] = "Automatically center the character sheet when displaying gear so left and right tooltips fit comfortably on screen."
L["CONFIG_QUALITY_BORDERS"] = "Item Quality Borders"
L["CONFIG_QUALITY_BORDERS_TT"] = "Color each tooltip's border with its item quality color (Epic purple, Rare blue, etc.)."
L["CONFIG_SHOW_COSMETICS"] = "Show Shirt & Tabard"
L["CONFIG_SHOW_COSMETICS_TT"] = "Show tooltips for equipped cosmetic slots (Shirt and Tabard)."
L["CONFIG_SHOW_SUMMARY"] = "Show Summary Header"
L["CONFIG_SHOW_SUMMARY_TT"] = "Display the top summary bar with Equipped slots, Average Item Level, and Durability."
L["CONFIG_HIDE_DEFAULT_TT"] = "Suppress Slot Hover Tooltip"
L["CONFIG_HIDE_DEFAULT_TT_TT"] = "Hide the default single tooltip when hovering over character sheet slots while Gear Display is active."
L["CONFIG_LAYOUT_LABEL"] = "Layout Mode"
L["CONFIG_LAYOUT_GRID"] = "Compact Grid"
L["CONFIG_LAYOUT_GRID_TT"] = "Arranges tooltips in 2 compact columns on each side to fit neatly within screen height."
L["CONFIG_LAYOUT_SINGLE"] = "Single Column"
L["CONFIG_LAYOUT_SINGLE_TT"] = "Arranges all left gear in 1 column and all right gear in 1 column."
L["CONFIG_SCALE_LABEL"] = "Tooltip Scale"
L["CONFIG_SCALE_TT"] = "Adjust the size of the surrounding gear tooltips."
L["CONFIG_RESET_DEFAULTS"] = "Reset Defaults"
L["CONFIG_CLOSE"] = "Close"

-- Slash Commands
L["CMD_HELP_HEADER"] = "Gear Display Commands:"
L["CMD_HELP_TOGGLE"] = "  /gd - Toggle gear display"
L["CMD_HELP_AUTOCENTER"] = "  /gd autocenter - Toggle auto-centering"
L["CMD_HELP_QUALITY"] = "  /gd quality - Toggle item quality borders"
L["CMD_HELP_LAYOUT"] = "  /gd layout - Toggle between Grid and Single column layout"
L["CMD_HELP_SCALE"] = "  /gd scale <0.6-1.2> - Set tooltip scale (e.g. /gd scale 0.9)"
L["CMD_HELP_CONFIG"] = "  /gd config - Open options window"
L["CMD_HELP_RESET"] = "  /gd reset - Reset settings to defaults"

L["MSG_AUTOCENTER_ON"] = "Gear Display: Auto-centering enabled."
L["MSG_AUTOCENTER_OFF"] = "Gear Display: Auto-centering disabled."
L["MSG_QUALITY_ON"] = "Gear Display: Item quality borders enabled."
L["MSG_QUALITY_OFF"] = "Gear Display: Item quality borders disabled."
L["MSG_LAYOUT_GRID"] = "Gear Display: Layout set to Compact Grid."
L["MSG_LAYOUT_SINGLE"] = "Gear Display: Layout set to Single Column."
L["MSG_SCALE_SET"] = "Gear Display: Tooltip scale set to %d%%."
L["MSG_SCALE_INVALID"] = "Gear Display: Scale must be a number between 0.6 and 1.2 (e.g. /gd scale 0.85)."
L["MSG_RESET"] = "Gear Display: Settings reset to defaults."
