-- Hand-written types loaded BEFORE the generated API.
--
-- types/gen/build.tl scans this file: every `global record|interface|enum|type X`
-- declared here is referenced by name from the generated file, and every
-- `-- @redirect blizzType X` line maps a Blizzard pseudo-type onto X.
--
-- Rule: nothing here may reference a generated type (Teal cannot forward-reference
-- across declaration files). Use primitives only.

--------------------------------------------------------------------------------
-- Colors and vectors (Blizzard_SharedXML: Color.lua, Vector2D.lua, Vector3D.lua)
--------------------------------------------------------------------------------

-- @redirect colorRGB ColorMixin
-- @redirect colorRGBA ColorMixin
global record ColorMixin
   r: number
   g: number
   b: number
   a: number
   GetRGB: function(self): number, number, number
   GetRGBA: function(self): number, number, number, number
   GetRGBAsBytes: function(self): number, number, number
   SetRGB: function(self, r: number, g: number, b: number)
   SetRGBA: function(self, r: number, g: number, b: number, a?: number)
   IsEqualTo: function(self, other: ColorMixin): boolean
   GenerateHexColor: function(self): string
   GenerateHexColorMarkup: function(self): string
   WrapTextInColorCode: function(self, text: string): string
end

-- @redirect vector2 Vector2DMixin
global record Vector2DMixin
   x: number
   y: number
   GetXY: function(self): number, number
   SetXY: function(self, x: number, y: number)
end

-- @redirect vector3 Vector3DMixin
global record Vector3DMixin
   x: number
   y: number
   z: number
   GetXYZ: function(self): number, number, number
   SetXYZ: function(self, x: number, y: number, z: number)
end

--------------------------------------------------------------------------------
-- ItemLocation (Blizzard_ObjectAPI/ItemLocation.lua)
-- At runtime `ItemLocation` is both the mixin table (with static constructors)
-- and the type of the objects it creates, so one record models both.
--------------------------------------------------------------------------------

-- @redirect EmptiableItemLocation ItemLocation
global record ItemLocation
   equipmentSlotIndex: number
   bagID: number
   slotIndex: number

   CreateEmpty: function(self): ItemLocation
   CreateFromBagAndSlot: function(self, bagID: number, slotIndex: number): ItemLocation
   CreateFromEquipmentSlot: function(self, equipmentSlotIndex: number): ItemLocation

   Clear: function(self)
   SetBagAndSlot: function(self, bagID: number, slotIndex: number)
   GetBagAndSlot: function(self): number, number
   SetEquipmentSlot: function(self, equipmentSlotIndex: number)
   GetEquipmentSlot: function(self): number
   IsEquipmentSlot: function(self): boolean
   IsBagAndSlot: function(self): boolean
   HasAnyLocation: function(self): boolean
   IsValid: function(self): boolean
   IsEqualToBagAndSlot: function(self, bagID: number, slotIndex: number): boolean
   IsEqualToEquipmentSlot: function(self, equipmentSlotIndex: number): boolean
   IsEqualTo: function(self, other: ItemLocation): boolean
end

--------------------------------------------------------------------------------
-- Timer handles returned by C_Timer.NewTimer / NewTicker
--------------------------------------------------------------------------------

global record FunctionContainer
   Cancel: function(self)
   IsCancelled: function(self): boolean
   Invoke: function(self, ...: any)
end

--------------------------------------------------------------------------------
-- Tooltip data (TooltipInfoShared). Blizzard documents these as opaque.
--------------------------------------------------------------------------------

global record TooltipDataLine
   type: number
   leftText: string
   rightText: string
   leftColor: ColorMixin
   rightColor: ColorMixin
   wrapText: boolean
end

global record TooltipData
   type: number
   id: number
   guid: string
   hyperlink: string
   lines: {TooltipDataLine}
end
