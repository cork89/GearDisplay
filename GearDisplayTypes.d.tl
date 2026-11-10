-- Addon-specific types shared by Locales.tl, Config.tl and GearDisplay.tl.
-- Import type-only (emits no code):
--   local type GD = require("GearDisplayTypes")
--   local addonName, addonTable = ... as (string, GD.Namespace)

local record GD

   -- SavedVariables (GearDisplay.toc: GearDisplayDB); defaults in Config.tl DEFAULTS.
   enum Layout "grid" "single" end
   record DB
      scale: number
      autoCenter: boolean
      qualityBorders: boolean
      showCosmetics: boolean
      hideDefaultTooltipOnHover: boolean
      layout: Layout
   end
   -- The boolean settings, so they can be read/written by key (checkbox helpers).
   enum BoolSetting "autoCenter" "qualityBorders" "showCosmetics" "hideDefaultTooltipOnHover" end

   -- Where a slot's tooltip goes around the character frame (GearDisplay.tl LayoutTooltips).
   -- "BOTTOM" is handled by the layout but no slot uses it.
   enum SlotGroup "LEFT_INNER" "LEFT_OUTER" "RIGHT_INNER" "RIGHT_OUTER" "WEAPONS" "BOTTOM" end

   -- GearDisplay.tl SLOTS_DATA entries
   record SlotData
      id: number
      key: string
      name: string
      slotName: string     -- child key on (Inspect)PaperDollItemsFrame
      btn: string          -- global name of the character-sheet slot button
      inspectBtn: string   -- global name of the inspect slot button
      group: SlotGroup
      order: number
      cosmetic: boolean    -- shirt/tabard; hidden unless DB.showCosmetics
   end

   -- One GetPoint() result, replayed with SetPoint() when restoring a frame.
   type SavedPoint = {FramePoint, ScriptRegion, FramePoint, number, number}

   -- Blizzard NineSlice border (Blizzard_SharedXML/NineSlice.lua NineSlicePanelMixin).
   interface NineSlicePanel is Frame
      SetBorderColor: function(self, r: number, g: number, b: number, a?: number)
   end

   -- Frames the addon creates and decorates with its own fields
   interface GlowFrame is BackdropFrame
      pulseAnim: AnimationGroup
   end
   -- GameTooltipTemplate (+ BackdropTemplate when BackdropTemplateMixin exists).
   -- The Backdrop methods and NineSlice may be nil depending on the client; check before use.
   interface GearTooltip is GameTooltipAPI, BackdropTemplate
      NineSlice: NineSlicePanel
      itemLink: string
      slotId: number
      HoverGlow: GlowFrame
   end
   interface LabeledCheck is CheckButton     -- InterfaceOptionsCheckButtonTemplate
      Text: FontString
   end
   -- Config.tl config frame, the Settings canvas panel, and GearDisplay.tl tab pane.
   interface SettingsPane is Frame
      title: FontString
      name: string
      content: Frame
      isUpdating: boolean
      btnGrid: Button
      btnSingle: Button
      scaleSlider: Slider
      cbAutoCenter: LabeledCheck
      cbQuality: LabeledCheck
      cbCosmetics: LabeledCheck
      cbHideDefault: LabeledCheck
   end
   -- The toggle control: the sidebar CheckButton tab (SidebarTab), the fallback icon Button
   -- (InitToggleButton), or the inspect UIPanelButton. Fields are nil when not applicable.
   interface ToggleButton is Button
      isIconButton: boolean
      Icon: Texture
      SelectedBorder: Texture
      -- Only on CheckButtons (the sidebar tab); nil on plain Buttons.
      SetChecked: function(self, checked?: boolean)
   end
   interface SidebarTab is CheckButton, ToggleButton
      Border: Texture
      CheckedTexture: Texture
      isSelected: boolean
   end

   -- Blizzard frames, with the children this addon touches. Cast at use.
   interface CharacterFrameEx is Frame
      numTabs: number                -- Classic Era (PanelTemplates); nil on modern clients
      ModeTabs: ModeTabs             -- modern clients only
   end
   interface ModeTab is Button
      frameName: string
   end
   record ModeTabs
      Tabs: {ModeTab}
   end
   interface PaperDollFrameEx is Frame
      EquipmentManagerPane: Frame    -- may be nil
   end

   record Namespace
      L: {string:string}
      SLOTS_DATA: {SlotData}

      -- state (initialised at the top of GearDisplay.tl)
      tooltips: {number:GearTooltip}      -- keyed by inventory slot id
      slotGlows: {Button:Texture}         -- slot button -> its highlight texture
      isShowing: boolean
      currentUnit: string
      isCentered: boolean
      isInspectCentered: boolean
      savedPoints: {SavedPoint}
      savedInspectPoints: {SavedPoint}
      pendingRestore: boolean
      pendingInspectRestore: boolean
      isSwitchingTabs: boolean
      -- A timer, or `true` when only C_Timer.After exists (no handle to cancel).
      refreshTimer: FunctionContainer | boolean

      -- frames and flags
      configFrame: SettingsPane
      tabPane: SettingsPane
      toggleBtn: ToggleButton
      inspectBtn: ToggleButton
      sidebarTab: SidebarTab
      bottomTab: Button
      bottomTabId: number
      settingsCategoryRegistered: boolean
      tooltipsCreated: boolean
      slotsHooked: boolean
      inspectSlotsHooked: boolean
      nativeTabsHooked: boolean
      sidebarTabsHooked: boolean
      sidebarVisibilityHooked: boolean
      sidebarTabInitialized: boolean
      bottomTabInitialized: boolean

      -- Config.tl
      InitDB: function(self)
      ResetDB: function(self)
      ToggleConfig: function(self)
      CreateConfigFrame: function(self)
      RefreshConfigFrame: function(self)
      RegisterSettingsCategory: function(self)

      -- GearDisplay.tl: tooltips
      CreateTooltips: function(self)
      OnTooltipClick: function(self, tooltip: GearTooltip, slot: SlotData, button: string)
      HighlightSlotButton: function(self, slot: SlotData, isHighlighted: boolean)
      SetTooltipHighlight: function(self, tooltip: GearTooltip, isHighlighted: boolean, slotId?: number)
      OnTooltipEnter: function(self, tooltip: GearTooltip, slot: SlotData)
      OnTooltipLeave: function(self, tooltip: GearTooltip, slot: SlotData)
      PopulateTooltip: function(self, tooltip: GearTooltip, slotId: number, unit?: string): boolean
      UpdateTooltipBorder: function(self, tooltip: GearTooltip, slotId: number, unit?: string)

      -- slot hooks and highlights
      HookSlotButtons: function(self)
      HookInspectSlotButtons: function(self)
      HighlightSlotTooltip: function(self, slotId: number, isHighlighted: boolean)
      ClearAllHighlights: function(self)

      -- layout
      LayoutTooltips: function(self, targetFrame?: Frame)

      -- tab pane
      GetTabPane: function(self): SettingsPane
      CreateTabPane: function(self): SettingsPane
      RefreshTabPaneSettings: function(self)
      UpdateTabPane: function(self, unit?: string)

      -- sidebar / bottom / mode tabs
      InitSidebarTab: function(self)
      SetSidebarTabSelected: function(self, selected: boolean)
      UpdateSidebarLayout: function(self)
      HookSidebarTabs: function(self)
      HookSidebarTabVisibility: function(self)
      InitBottomTab: function(self)
      HookNativeTabs: function(self)
      SelectGearDisplayTab: function(self)
      SelectStatsTab: function(self)
      ToggleTab: function(self)

      -- frame centering
      CenterCharacterFrame: function(self)
      RestoreCharacterFrame: function(self)
      CenterInspectFrame: function(self)
      RestoreInspectFrame: function(self)

      -- buttons and show/hide
      UpdateToggleButtonPosition: function(self)
      InitToggleButton: function(self)
      InitInspectButton: function(self)
      UpdateButton: function(self, isShowing: boolean)
      ShowGear: function(self, unit?: string)
      HideGear: function(self)
      Toggle: function(self, unit?: string)
      RefreshGear: function(self)
      RequestRefresh: function(self, delay?: number)
   end
end

return GD
