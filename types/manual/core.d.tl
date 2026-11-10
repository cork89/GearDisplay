-- Hand-written core globals that the generator cannot express or gets wrong.
-- Loaded AFTER the generated API, so every generated type is available here.

--------------------------------------------------------------------------------
-- CreateFrame
-- Teal has no string-literal types, so each frame type gets its own one-member
-- enum and its own __call overload. Overloads are tried in order; the last one
-- catches any other FrameType.
--------------------------------------------------------------------------------

global enum FrameTypeFrame "Frame" end
global enum FrameTypeButton "Button" end
global enum FrameTypeCheckButton "CheckButton" end
global enum FrameTypeSlider "Slider" end
global enum FrameTypeStatusBar "StatusBar" end
global enum FrameTypeEditBox "EditBox" end
global enum FrameTypeScrollFrame "ScrollFrame" end
global enum FrameTypeGameTooltip "GameTooltip" end
global enum FrameTypeCooldown "Cooldown" end
global enum FrameTypeColorSelect "ColorSelect" end
global enum FrameTypeMessageFrame "MessageFrame" end
global enum FrameTypeSimpleHTML "SimpleHTML" end
global enum FrameTypeModel "Model" end
global enum FrameTypePlayerModel "PlayerModel" end
global enum FrameTypeDressUpModel "DressUpModel" end
global enum FrameTypeModelScene "ModelScene" end

global record CreateFrameFunction
   metamethod __call: function(self, frameType: FrameTypeFrame, name?: string, parent?: Frame | string, template?: string, id?: number): Frame
   metamethod __call: function(self, frameType: FrameTypeButton, name?: string, parent?: Frame | string, template?: string, id?: number): Button
   metamethod __call: function(self, frameType: FrameTypeCheckButton, name?: string, parent?: Frame | string, template?: string, id?: number): CheckButton
   metamethod __call: function(self, frameType: FrameTypeSlider, name?: string, parent?: Frame | string, template?: string, id?: number): Slider
   metamethod __call: function(self, frameType: FrameTypeStatusBar, name?: string, parent?: Frame | string, template?: string, id?: number): StatusBar
   metamethod __call: function(self, frameType: FrameTypeEditBox, name?: string, parent?: Frame | string, template?: string, id?: number): EditBox
   metamethod __call: function(self, frameType: FrameTypeScrollFrame, name?: string, parent?: Frame | string, template?: string, id?: number): ScrollFrame
   metamethod __call: function(self, frameType: FrameTypeGameTooltip, name?: string, parent?: Frame | string, template?: string, id?: number): GameTooltip
   metamethod __call: function(self, frameType: FrameTypeCooldown, name?: string, parent?: Frame | string, template?: string, id?: number): Cooldown
   metamethod __call: function(self, frameType: FrameTypeColorSelect, name?: string, parent?: Frame | string, template?: string, id?: number): ColorSelect
   metamethod __call: function(self, frameType: FrameTypeMessageFrame, name?: string, parent?: Frame | string, template?: string, id?: number): MessageFrame
   metamethod __call: function(self, frameType: FrameTypeSimpleHTML, name?: string, parent?: Frame | string, template?: string, id?: number): SimpleHTML
   metamethod __call: function(self, frameType: FrameTypeModel, name?: string, parent?: Frame | string, template?: string, id?: number): Model
   metamethod __call: function(self, frameType: FrameTypePlayerModel, name?: string, parent?: Frame | string, template?: string, id?: number): PlayerModel
   metamethod __call: function(self, frameType: FrameTypeDressUpModel, name?: string, parent?: Frame | string, template?: string, id?: number): DressUpModel
   metamethod __call: function(self, frameType: FrameTypeModelScene, name?: string, parent?: Frame | string, template?: string, id?: number): ModelScene
   metamethod __call: function(self, frameType: FrameType, name?: string, parent?: Frame | string, template?: string, id?: number): Frame
end

global CreateFrame: CreateFrameFunction

--------------------------------------------------------------------------------
-- Secure hooks
--------------------------------------------------------------------------------

global record HookSecureFuncFunction
   metamethod __call: function(self, functionName: string, hook: function(...: any))
   metamethod __call: function(self, tbl: any, functionName: string, hook: function(...: any))
end
global hooksecurefunc: HookSecureFuncFunction

global securecall: function(func: function | string, ...: any): any...
global securecallfunction: function(func: function, ...: any): any...

--------------------------------------------------------------------------------
-- Legacy item/inventory API (still present in 1.60; Ketho's types are too loose)
--------------------------------------------------------------------------------

-- [nilable return] nil when the slot is empty.
global GetInventoryItemLink: function(unit: UnitToken, invSlotId: number): string
-- [nilable return] nil when the slot is empty.
global GetInventoryItemQuality: function(unit: UnitToken, invSlotId: number): integer

-- Returns nothing when the item is not cached yet (GET_ITEM_INFO_RECEIVED fires later).
global GetItemInfo: function(item: integer | string): string, string, integer, integer, integer, string, string, integer, string, integer, integer, integer, integer, integer, integer, integer, boolean
