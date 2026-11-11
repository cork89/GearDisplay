-- Hand-written FrameXML / SharedXML Lua API (Blizzard UI code, not C API).
-- Only what addons in this repo use; signatures checked against wow-ui-source `forever`.
-- Loaded AFTER the generated API.

--------------------------------------------------------------------------------
-- Panels
--------------------------------------------------------------------------------

-- Blizzard_UIParent: UIParentPanelManager
global ShowUIPanel: function(frame: Frame, force?: boolean, contextKey?: any)
global HideUIPanel: function(frame: Frame, skipSetPoint?: boolean, skipShownCheck?: boolean)
-- Frame *names* closed by Escape.
global UISpecialFrames: {string}

-- Blizzard_UIPanels_Game/CharacterFrame.lua
global ToggleCharacter: function(tab: string, onlyShow?: boolean)

-- Blizzard_UIParentPanelManager/Shared/UIParentPanelManager.lua
global UpdateUIPanelPositions: function(currentFrame?: Frame)

-- Blizzard_UIPanels_Game/{Mainline,Camelot}/PaperDollFrame.lua
global PaperDollFrame_UpdateSidebarTabs: function()

-- Blizzard_SharedXML/PanelTemplates.lua
global PanelTemplates_TabResize: function(tab: Button, padding?: number, absoluteSize?: number, minWidth?: number, maxWidth?: number, absoluteTextSize?: number)

--------------------------------------------------------------------------------
-- Item links
--------------------------------------------------------------------------------

-- Blizzard_FrameXMLUtil/ItemUtil: returns true if the click was consumed (chat link, dress up, ...).
global HandleModifiedItemClick: function(link: string, itemLocation?: ItemLocation): boolean
global DressUpLink: function(link: string, forcedFrame?: Frame): boolean
global DressUpItemLink: function(link: string, forcedFrame?: Frame): boolean
-- Deprecated alias of ChatFrameUtil.InsertLink.
global ChatEdit_InsertLink: function(text: string): boolean

--------------------------------------------------------------------------------
-- Settings (Blizzard_Settings_Shared)
--------------------------------------------------------------------------------

global record SettingsCategory
   -- An integer from idCounter(); addons commonly overwrite it with their name so
   -- Settings.OpenToCategory(name) works.
   ID: integer | string
   GetID: function(self): integer
   GetName: function(self): string
end

global record Settings
   RegisterCanvasLayoutCategory: function(frame: Frame, name: string): SettingsCategory, any
   RegisterVerticalLayoutCategory: function(name: string): SettingsCategory, any
   RegisterAddOnCategory: function(category: SettingsCategory)
   OpenToCategory: function(categoryID: integer | string, scrollToElementName?: string): boolean
end

global SettingsPanel: Frame

--------------------------------------------------------------------------------
-- Backdrop (Blizzard_SharedXML/Backdrop.lua)
-- Frames created with the "BackdropTemplate" template. Teal cannot derive this
-- from the template string, so cast: `CreateFrame("Frame", nil, p, "BackdropTemplate") as BackdropFrame`.
-- (The interface is `BackdropTemplate`; `BackdropTemplateMixin` is the runtime table.)
--------------------------------------------------------------------------------

global record BackdropInsets
   left: number
   right: number
   top: number
   bottom: number
end

global record BackdropInfo
   bgFile: string
   edgeFile: string
   tile: boolean
   tileEdge: boolean
   tileSize: number
   edgeSize: number
   insets: BackdropInsets
end

global interface BackdropTemplate
   SetBackdrop: function(self, backdropInfo: BackdropInfo)
   GetBackdrop: function(self): BackdropInfo
   ClearBackdrop: function(self)
   SetBackdropColor: function(self, r: number, g: number, b: number, a?: number)
   GetBackdropColor: function(self): number, number, number, number
   SetBackdropBorderColor: function(self, r: number, g: number, b: number, a?: number)
   GetBackdropBorderColor: function(self): number, number, number, number
end
global BackdropTemplateMixin: table

global interface BackdropFrame is Frame, BackdropTemplate end

--------------------------------------------------------------------------------
-- Named global frames
--------------------------------------------------------------------------------

global UIParent: Frame
global WorldFrame: Frame
-- `GameTooltip` (the frame) is the `GameTooltip` record itself; see types/gen/build.tl.
global ItemRefTooltip: GameTooltip

global CharacterFrame: Frame
global PaperDollFrame: Frame
global PaperDollItemsFrame: Frame

-- Blizzard_UIPanels_Game/{Mainline,Camelot}/PaperDollFrame.xml. The tabs are CheckButtons on
-- Camelot and Buttons on Mainline.
global PaperDollSidebarTabs: Frame
global PaperDollSidebarTab1: Button
global PaperDollSidebarTab2: Button
global PaperDollSidebarTab3: Button

-- Blizzard_UIPanels_Game/{Mainline,Camelot}/CharacterFrame.xml
global CharacterStatsPane: Frame
global CharacterStatsPaneScrollBox: Frame
global CharacterStatsPanePetScrollBox: Frame
-- Mainline/CharacterFrame.xml bottom tabs; nil on Camelot (it uses CharacterFrame.ModeTabs).
global CharacterFrameTab1: Button
global CharacterFrameTab2: Button
global CharacterFrameTab3: Button

-- Load-on-demand (Blizzard_InspectUI); nil until loaded.
global InspectFrame: Frame
global InspectPaperDollFrame: Frame
global InspectPaperDollItemsFrame: Frame

--------------------------------------------------------------------------------
-- Slash commands and sounds
-- Register with: `SLASH_MYADDON1 = "/my"` (declare `global SLASH_MYADDON1: string`
-- in the addon) and `SlashCmdList["MYADDON"] = function(msg) ... end`.
--------------------------------------------------------------------------------

global SlashCmdList: {string: function(msg: string, editBox: EditBox)}
-- SoundKitConstants.lua: name -> soundKitID
global SOUNDKIT: {string: number}

--------------------------------------------------------------------------------
-- Font objects (Blizzard_Fonts_Shared/Shared/FontStyles.xml)
--------------------------------------------------------------------------------

global GameFontNormal: Font
global GameFontNormalLarge: Font
global GameFontHighlight: Font
global GameFontHighlightSmall: Font
