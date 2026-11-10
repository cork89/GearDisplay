-- Generates types/generated/wow_api.d.tl from:
--   1. Blizzard_APIDocumentationGenerated (wow-ui-source, `forever` branch)  -- C API, enums, structures, widgets, events
--   2. Ketho/vscode-wow-api annotations (MIT)                                -- aliases, string enums, legacy globals
--
-- Usage: types/gen/build.sh (fetches pinned sources into types/.cache, then runs
--   `tl run build.tl <wow-ui-source dir> <vscode-wow-api dir>` from types/gen).

-- Run from types/gen (it has its own empty tlconfig.lua, so the WoW globals of
-- the addon's tlconfig don't apply to this script). Paths are relative to types/.
local TYPES = arg[3] or ".."
local OUT_FILE = TYPES .. "/generated/wow_api.d.tl"
local REPORT_FILE = TYPES .. "/generated/REPORT.md"
local PRELUDE_FILE = TYPES .. "/manual/prelude.d.tl"

local ui_source = arg[1] or (TYPES .. "/.cache/wow-ui-source")
local ketho_root = arg[2] or (TYPES .. "/.cache/vscode-wow-api")
local BLIZZ_DOCS = ui_source .. "/Interface/AddOns/Blizzard_APIDocumentationGenerated"
local KETHO = ketho_root .. "/Annotations/Core"

--------------------------------------------------------------------------------
-- Blizzard documentation shapes
--------------------------------------------------------------------------------

local record Field
   Name: string
   Type: string
   InnerType: string
   Mixin: string
   Nilable: boolean
   Default: any
   StrideIndex: integer
   EnumValue: integer
   Value: any
   Documentation: {string}
end

local record Func
   Name: string
   Type: string
   Arguments: {Field}
   Returns: {Field}
   Documentation: {string}
   IsProtectedFunction: boolean
   MayReturnNothing: boolean
end

local record Event
   Name: string
   LiteralName: string
   Payload: {Field}
   Documentation: {string}
end

local record TableDef
   Name: string
   Type: string
   Fields: {Field}
   Values: {Field}
   Arguments: {Field}
   Returns: {Field}
   Documentation: {string}
end

local record Doc
   Name: string
   Type: string
   Namespace: string
   Environment: string
   Functions: {Func}
   Events: {Event}
   Tables: {TableDef}
   file: string
end

--------------------------------------------------------------------------------
-- Static knowledge
--------------------------------------------------------------------------------

-- Widget hierarchy (from Ketho's Widget/*.lua `---@class X : Parents`) and the
-- Blizzard ScriptObject documentation table(s) whose methods each class owns.
local record WidgetClass
   name: string
   parents: {string}
   apis: {string}
   -- Emit as a `record` instead of an `interface`: needed when a global *value*
   -- has the same name (e.g. the `GameTooltip` frame). Teal types and globals
   -- share one namespace; a record is both a type and a value. Records cannot
   -- be inherited, so only leaf classes may set this.
   is_record: boolean
end

local WIDGETS: {WidgetClass} = {
   { name = "FrameScriptObject", parents = {}, apis = { "SimpleFrameScriptObjectAPI" } },
   { name = "Object", parents = { "FrameScriptObject" }, apis = { "SimpleObjectAPI" } },
   -- ScriptObject: script handler methods; filled in from SCRIPT_HANDLERS below.
   { name = "ScriptObject", parents = {}, apis = {} },
   { name = "ScriptRegion", parents = { "Object", "ScriptObject" }, apis = { "SimpleScriptRegionAPI" } },
   { name = "ScriptRegionResizing", parents = { "Object" }, apis = { "SimpleScriptRegionResizingAPI" } },
   { name = "AnimatableObject", parents = { "Object" }, apis = { "SimpleAnimatableObjectAPI" } },
   { name = "Region", parents = { "ScriptRegion", "ScriptRegionResizing", "AnimatableObject" }, apis = { "SimpleRegionAPI" } },
   { name = "TextureBase", parents = { "Region" }, apis = { "SimpleTextureBaseAPI" } },
   { name = "Texture", parents = { "TextureBase" }, apis = { "SimpleTextureAPI" } },
   { name = "MaskTexture", parents = { "TextureBase" }, apis = { "SimpleMaskTextureAPI" } },
   { name = "Line", parents = { "TextureBase" }, apis = { "SimpleLineAPI" } },
   { name = "Font", parents = { "FrameScriptObject" }, apis = { "SimpleFontAPI" } },
   { name = "FontString", parents = { "Region" }, apis = { "SimpleFontStringAPI" } },
   { name = "Frame", parents = { "Region" }, apis = { "SimpleFrameAPI" } },
   { name = "Button", parents = { "Frame" }, apis = { "SimpleButtonAPI" } },
   { name = "CheckButton", parents = { "Button" }, apis = { "SimpleCheckboxAPI" } },
   { name = "ColorSelect", parents = { "Frame" }, apis = { "SimpleColorSelectAPI" } },
   { name = "Cooldown", parents = { "Frame" }, apis = { "FrameAPICooldown" } },
   { name = "EditBox", parents = { "Frame" }, apis = { "SimpleEditBoxAPI" } },
   { name = "MessageFrame", parents = { "Frame" }, apis = { "SimpleMessageFrameAPI" } },
   { name = "ScrollFrame", parents = { "Frame" }, apis = { "SimpleScrollFrameAPI" } },
   { name = "SimpleHTML", parents = { "Frame" }, apis = { "SimpleHTMLAPI" } },
   { name = "Slider", parents = { "Frame" }, apis = { "SimpleSliderAPI" } },
   { name = "StatusBar", parents = { "Frame" }, apis = { "SimpleStatusBarAPI" } },
   { name = "Browser", parents = { "Frame" }, apis = { "SimpleBrowserAPI" } },
   { name = "MovieFrame", parents = { "Frame" }, apis = { "SimpleMovieAPI" } },
   { name = "OffScreenFrame", parents = { "Frame" }, apis = { "SimpleOffScreenFrameAPI" } },
   { name = "Checkout", parents = { "Frame" }, apis = { "FrameAPISimpleCheckout" } },
   { name = "GameTooltip", parents = { "Frame" }, apis = { "FrameAPITooltip" }, is_record = true },
   { name = "FogOfWarFrame", parents = { "Frame" }, apis = { "FrameAPIFogOfWarFrame" } },
   { name = "UnitPositionFrame", parents = { "Frame" }, apis = { "FrameAPIUnitPositionFrame" } },
   { name = "Blob", parents = { "Frame" }, apis = { "FrameAPIBlob" } },
   { name = "ArchaeologyDigSiteFrame", parents = { "Blob" }, apis = { "FrameAPIArchaeologyDigSiteFrame" } },
   { name = "QuestPOIFrame", parents = { "Blob" }, apis = { "FrameAPIQuestPOI" } },
   { name = "ScenarioPOIFrame", parents = { "Blob" }, apis = { "FrameAPIScenarioPOI" } },
   { name = "Model", parents = { "Frame" }, apis = { "SimpleModelAPI" } },
   { name = "ModelFFX", parents = { "Model" }, apis = { "SimpleModelFFXAPI" } },
   { name = "CharacterModelBase", parents = { "Model" }, apis = { "FrameAPICharacterModelBase" } },
   { name = "PlayerModel", parents = { "CharacterModelBase" }, apis = {} },
   { name = "CinematicModel", parents = { "PlayerModel" }, apis = { "FrameAPICinematicModel" } },
   { name = "DressUpModel", parents = { "PlayerModel" }, apis = { "FrameAPIDressUpModel" } },
   { name = "TabardModelBase", parents = { "PlayerModel" }, apis = { "FrameAPITabardModelBase" } },
   { name = "TabardModel", parents = { "TabardModelBase" }, apis = { "FrameAPITabardModel" } },
   { name = "ModelScene", parents = { "Frame" }, apis = { "FrameAPIModelSceneFrame" } },
   { name = "ModelSceneActorBase", parents = { "Object" }, apis = { "FrameAPIModelSceneFrameActorBase" } },
   { name = "ModelSceneActor", parents = { "ModelSceneActorBase" }, apis = { "FrameAPIModelSceneFrameActor" } },
   { name = "AnimationGroup", parents = { "Object" }, apis = { "SimpleAnimGroupAPI" } },
   { name = "Animation", parents = { "Object" }, apis = { "SimpleAnimAPI" } },
   { name = "Alpha", parents = { "Animation" }, apis = { "SimpleAnimAlphaAPI" } },
   { name = "FlipBook", parents = { "Animation" }, apis = { "SimpleAnimFlipBookAPI" } },
   { name = "Path", parents = { "Animation" }, apis = { "SimpleAnimPathAPI" } },
   { name = "Rotation", parents = { "Animation" }, apis = { "SimpleAnimRotationAPI" } },
   { name = "Scale", parents = { "Animation" }, apis = { "SimpleAnimScaleAPI" } },
   { name = "LineScale", parents = { "Scale" }, apis = { "SimpleAnimScaleLineAPI" } },
   { name = "Translation", parents = { "Animation" }, apis = { "SimpleAnimTranslationAPI" } },
   { name = "LineTranslation", parents = { "Translation" }, apis = { "SimpleAnimTranslationLineAPI" } },
   { name = "TextureCoordTranslation", parents = { "Animation" }, apis = { "SimpleAnimTextureCoordTranslationAPI" } },
   { name = "VertexColor", parents = { "Animation" }, apis = { "SimpleAnimVertexColorAPI" } },
   { name = "RadialProgress", parents = { "Animation" }, apis = { "SimpleAnimRadialProgressAPI" } },
   { name = "ControlPoint", parents = { "Object" }, apis = { "SimpleControlPointAPI" } },
}

-- Script handlers, grouped by handler signature. Each group becomes a Teal enum
-- and one SetScript/HookScript overload on ScriptObject. `self` is the widget.
local record HandlerGroup
   enum_name: string
   params: string -- handler params after `frame: self`
   names: {string}
end

local SCRIPT_HANDLERS: {HandlerGroup} = {
   { enum_name = "ScriptTypeNoArgs", params = "", names = {
      "OnShow", "OnHide", "OnLoad", "OnDragStart", "OnDragStop", "OnReceiveDrag", "OnEnable", "OnDisable",
      "OnTooltipCleared", "OnEditFocusGained", "OnEditFocusLost", "OnEnterPressed", "OnEscapePressed",
      "OnTabPressed", "OnSpacePressed", "OnTextSet", "OnMovieFinished", "OnMinMaxChanged",
      "OnScrollRangeChanged", "OnTooltipSetDefaultAnchor", "OnAttributeChanged",
   } },
   { enum_name = "ScriptTypeMotion", params = ", motion: boolean", names = { "OnEnter", "OnLeave" } },
   { enum_name = "ScriptTypeMouseButton", params = ", button: string", names = { "OnMouseDown", "OnMouseUp" } },
   { enum_name = "ScriptTypeClick", params = ", button: string, down: boolean", names = { "PreClick", "OnClick", "PostClick", "OnDoubleClick" } },
   { enum_name = "ScriptTypeWheel", params = ", delta: number", names = { "OnMouseWheel" } },
   { enum_name = "ScriptTypeEvent", params = ", event: string, ...: any", names = { "OnEvent" } },
   { enum_name = "ScriptTypeUpdate", params = ", elapsed: number", names = { "OnUpdate" } },
   { enum_name = "ScriptTypeSize", params = ", width: number, height: number", names = { "OnSizeChanged" } },
   { enum_name = "ScriptTypeKey", params = ", key: string", names = { "OnKeyDown", "OnKeyUp", "OnChar" } },
   { enum_name = "ScriptTypeValue", params = ", value: number, userInput: boolean", names = { "OnValueChanged" } },
   { enum_name = "ScriptTypeText", params = ", userInput: boolean", names = { "OnTextChanged" } },
   { enum_name = "ScriptTypeHyperlink", params = ", link: string, text: string, region: Region, left: number, bottom: number, width: number, height: number", names = { "OnHyperlinkEnter", "OnHyperlinkLeave", "OnHyperlinkClick" } },
}

-- Blizzard pseudo-types that map straight to Teal types.
local PRIMITIVES: {string:string} = {
   number = "number",
   bool = "boolean",
   boolean = "boolean",
   string = "string",
   cstring = "string",
   -- Lua 5.1 has no integer subtype; `integer` here only adds friction (loop
   -- counters and API counts are `number`), so indices are plain numbers.
   luaIndex = "number",
   LuaValueVariant = "any",
   LuaValueReference = "any",
   LuaFunctionReference = "function",
   ["function"] = "function",
   userdata = "any",
   ScriptObject = "FrameScriptObject",
}

-- Blizzard "SimpleXxx" type names that do not follow the "Simple" .. ClassName rule.
local WIDGET_TYPE_RENAMES: {string:string} = {
   SimpleAnimGroup = "AnimationGroup",
   SimpleAnim = "Animation",
   SimpleCheckbox = "CheckButton",
   SimpleFrameScriptObject = "FrameScriptObject",
   SimplePathAnim = "Path",
   CScriptObject = "FrameScriptObject",
   ModelSceneFrame = "ModelScene",
   ModelSceneFrameActor = "ModelSceneActor",
   Tooltip = "GameTooltip",
   NamePlateFrame = "Frame",
}

-- Widget methods whose Blizzard signature is wrong or too strict (the docs mark
-- optional arguments as required, or omit overloads). Each entry replaces the
-- generated declaration with one or more overloads.
local REGION_OR_NAME = "ScriptRegion | string"
local METHOD_OVERRIDES: {string:{string}} = {
   ["*:SetPoint"] = {
      "function(self, point: FramePoint, offsetX?: number, offsetY?: number)",
      "function(self, point: FramePoint, relativeTo?: " .. REGION_OR_NAME .. ", relativePoint?: FramePoint, offsetX?: number, offsetY?: number)",
   },
   -- Blizzard's untyped script methods would accept any script name; the typed
   -- overloads on ScriptObject (an ancestor of ScriptRegion) replace them.
   ["ScriptRegion:SetScript"] = {},
   ["ScriptRegion:HookScript"] = {},
   ["ScriptRegion:GetScript"] = {},
   ["ScriptRegion:HasScript"] = {},
   ["*:SetAllPoints"] = {
      "function(self, relativeTo?: " .. REGION_OR_NAME .. ", doResize?: boolean)",
   },
}

-- Namespaced/global functions whose Blizzard signature is wrong. Key: "Namespace.Name" or "Name".
local FUNCTION_OVERRIDES: {string:{string}} = {
   -- Docs say these return the callback; they return a cancellable handle.
   ["C_Timer.NewTimer"] = { "function(seconds: number, callback: function(timer: FunctionContainer)): FunctionContainer" },
   ["C_Timer.NewTicker"] = { "function(seconds: number, callback: function(ticker: FunctionContainer), iterations?: number): FunctionContainer" },
   ["C_Timer.After"] = { "function(seconds: number, callback: function())" },
}

-- Globals defined by hand (types/manual) or by Teal's own standard library.
-- Ketho's Wiki.lua entries with these names are skipped.
local SKIP_GLOBALS: {string:boolean} = {}
for _, n in ipairs({
   -- manual/core.d.tl
   "CreateFrame", "hooksecurefunc", "GetInventoryItemLink", "GetInventoryItemQuality", "GetItemInfo",
   -- Lua standard library (Teal already declares these)
   "assert", "collectgarbage", "error", "getmetatable", "ipairs", "next", "pairs", "pcall", "print",
   "rawequal", "rawget", "rawset", "select", "setmetatable", "tonumber", "tostring", "type", "xpcall",
   "unpack", "require", "load", "loadstring", "dofile", "loadfile",
}) do SKIP_GLOBALS[n] = true end

local LUA_KEYWORDS: {string:boolean} = {}
for _, k in ipairs({
   "and", "break", "do", "else", "elseif", "end", "false", "for", "function", "goto", "if", "in",
   "local", "nil", "not", "or", "repeat", "return", "then", "true", "until", "while",
   -- Teal
   "record", "enum", "interface", "global", "type", "where", "is", "as", "self",
}) do LUA_KEYWORDS[k] = true end

--------------------------------------------------------------------------------
-- Utilities
--------------------------------------------------------------------------------

local function read_file(path: string): string
   local f = io.open(path, "rb")
   if not f then return nil end
   local s = f:read("a")
   f:close()
   return s
end

local function write_file(path: string, contents: string)
   local f = assert(io.open(path, "wb"))
   f:write(contents)
   f:close()
end

local function is_identifier(s: string): boolean
   return s:match("^[%a_][%w_]*$") ~= nil and not LUA_KEYWORDS[s]
end

local function field_key(s: string): string
   if is_identifier(s) then return s end
   return string.format("[%q]", s)
end

local function param_name(s: string, index: integer): string
   if s == nil or s == "" then return "arg" .. index end
   s = s:gsub("[^%w_]", "_")
   if s:match("^%d") then s = "_" .. s end
   if LUA_KEYWORDS[s] then s = s .. "_" end
   return s
end

local function sorted_keys<V>(t: {string:V}): {string}
   local ks: {string} = {}
   for k in pairs(t) do table.insert(ks, k) end
   table.sort(ks)
   return ks
end

local function doc_comment(out: {string}, indent: string, docs: {string}, extra: {string})
   local parts: {string} = {}
   for _, d in ipairs(docs or {}) do table.insert(parts, (d:gsub("[\r\n]+", " "))) end
   for _, e in ipairs(extra or {}) do table.insert(parts, e) end
   if #parts > 0 then
      table.insert(out, indent .. "-- " .. table.concat(parts, " "))
   end
end

--------------------------------------------------------------------------------
-- Load Blizzard docs
--------------------------------------------------------------------------------

local function load_blizzard_docs(): {Doc}
   local toc = read_file(BLIZZ_DOCS .. "/Blizzard_APIDocumentationGenerated.toc")
   if not toc then
      error("cannot read Blizzard docs TOC under " .. BLIZZ_DOCS)
   end
   local docs: {Doc} = {}

   -- Enum.X.Y and Constants.X.Y are referenced by some doc tables; stub them.
   local type Stub = {any:any}
   local stub_mt: metatable<Stub> = {}
   local function new_stub(): Stub
      local t: Stub = {}
      return setmetatable(t, stub_mt)
   end
   stub_mt.__index = function(_: Stub, _: any): any return new_stub() end
   -- Some doc tables compute values (e.g. `Constants.X.Y * 2`); the result is irrelevant to typing.
   local function zero(_: any, _: any): any return 0 end
   stub_mt.__add = zero
   stub_mt.__sub = zero
   stub_mt.__mul = zero
   stub_mt.__div = zero
   stub_mt.__mod = zero
   stub_mt.__unm = function(_: Stub): any return 0 end
   stub_mt.__concat = function(_: any, _: any): any return "" end
   local env: {string:any} = {
      Enum = new_stub(),
      Constants = new_stub(),
   }
   env.APIDocumentation = {
      AddDocumentationTable = function(_: any, t: Doc) table.insert(docs, t) end,
   }

   for line in toc:gmatch("[^\r\n]+") do
      local file = line:match("^%s*([%w_]+%.lua)%s*$")
      if file then
         local chunk, err = loadfile(BLIZZ_DOCS .. "/" .. file, "t", env)
         if not chunk then error(err) end
         local before = #docs
         local ok, run_err = pcall(chunk)
         if not ok then
            -- `tl run` exits silently on uncaught errors, so report and skip instead.
            io.stderr:write("warning: failed to load " .. file .. ": " .. tostring(run_err) .. "\n")
         end
         for i = before + 1, #docs do docs[i].file = file end
      end
   end
   return docs
end

--------------------------------------------------------------------------------
-- Load Ketho annotations
--------------------------------------------------------------------------------

local record KAlias
   name: string
   literals: {string} -- string enum values, if the alias is a pure string-literal union
   expr: string       -- otherwise, a LuaLS type expression
   source: string
end

local record KParam
   name: string
   type: string
   optional: boolean
end

local record KFunc
   name: string
   params: {KParam}
   returns: {string}
   variadic_return: boolean
   generic: boolean
   deprecated: boolean
   url: string
end

local function parse_ketho_aliases(path: string, into: {KAlias}, source: string)
   local text = read_file(path)
   if not text then
      io.stderr:write("warning: missing " .. path .. "\n")
      return
   end
   local current: KAlias = nil
   for line in text:gmatch("[^\r\n]*") do
      local name, rest = line:match("^%-%-%-@alias%s+([%w_%.]+)%s*(.-)%s*$")
      if name then
         current = { name = name, literals = {}, source = source }
         local expr = rest:match("^(%S+)")
         if expr and not expr:match("^#") then
            current.expr = expr
         end
         table.insert(into, current)
      elseif current and not current.expr then
         local member = line:match("^%-%-%-|%s*(%S+)")
         if member then
            local lit = member:match('^"(.*)"$') or member:match("^'(.*)'$")
            if lit then
               table.insert(current.literals, lit)
            else
               -- Non-literal member: treat the alias as a union expression.
               current.expr = current.expr and (current.expr .. "|" .. member) or member
            end
         elseif not line:match("^%-%-%-") then
            current = nil
         end
      else
         current = nil
      end
   end
end

local function parse_ketho_functions(path: string): {KFunc}
   local text = read_file(path)
   local funcs: {KFunc} = {}
   if not text then
      io.stderr:write("warning: missing " .. path .. "\n")
      return funcs
   end
   local params: {string:KParam} = {}
   local returns: {string} = {}
   local variadic_return = false
   local generic = false
   local deprecated = false
   local url: string = nil
   local function reset()
      params, returns, variadic_return, generic, deprecated, url = {}, {}, false, false, false, nil
   end
   for line in text:gmatch("[^\r\n]*") do
      local u = line:match("^%-%-%-%[Documentation%]%((.-)%)")
      if u then url = u end
      local pname, ptype = line:match("^%-%-%-@param%s+([%w_%.]+%??)%s+(%S+)")
      if pname then
         local optional = pname:sub(-1) == "?" or ptype:sub(-1) == "?"
         pname = pname:gsub("%?$", "")
         params[pname] = { name = pname, type = ptype, optional = optional }
      end
      local rtype, rname = line:match("^%-%-%-@return%s+(%S+)%s*(%S*)")
      if rtype then
         if rname == "..." or rtype:match("%.%.%.$") then
            variadic_return = true
            rtype = rtype:gsub("%.%.%.$", "")
         end
         table.insert(returns, rtype)
      end
      if line:match("^%-%-%-@generic") then generic = true end
      if line:match("^%-%-%-@deprecated") then deprecated = true end
      local fname, fargs = line:match("^function%s+([%w_%.:]+)%s*%((.-)%)")
      if fname then
         local f: KFunc = {
            name = fname, params = {}, returns = returns, variadic_return = variadic_return,
            generic = generic, deprecated = deprecated, url = url,
         }
         for a in fargs:gmatch("[^,%s]+") do
            table.insert(f.params, params[a] or { name = a, type = "any", optional = false })
         end
         table.insert(funcs, f)
         reset()
      elseif not line:match("^%-%-%-") and line ~= "" then
         reset()
      end
   end
   return funcs
end

--------------------------------------------------------------------------------
-- Type resolution
--------------------------------------------------------------------------------

-- Teal resolves `global type A = B` eagerly, so an alias cannot refer to a type
-- declared later in the file (forward declarations don't help either). Interface
-- and record *fields* can. So aliases (Ketho aliases, Blizzard enumerations and
-- callback types, unresolved names) are inlined at every use site, and their
-- names are emitted at the very end of the file for hand-written code to use.

local defined: {string:string} = {}       -- type name -> kind ("Structure", "Enumeration", "Widget", "Alias", ...)
local unresolved: {string:integer} = {}   -- type name -> reference count
local alias_exprs: {string:string} = {}   -- Ketho alias name -> LuaLS type expression
local callback_defs: {string:TableDef} = {}
local resolved_cache: {string:string} = {}
local resolving: {string:boolean} = {}
local redirects: {string:string} = {}     -- from `-- @redirect` lines in the prelude

local luals_to_tl: function(expr: string): string
local callback_type: function(t: TableDef): string

local function resolve_name(name: string): string
   local p = PRIMITIVES[name]
   if p then return p end
   if redirects[name] then return redirects[name] end
   if WIDGET_TYPE_RENAMES[name] then return WIDGET_TYPE_RENAMES[name] end
   local stripped = name:match("^Simple(.+)$")
   if stripped and defined[stripped] == "Widget" then return stripped end
   local kind = defined[name]
   if kind == "Widget" or kind == "Structure" or kind == "StringEnum" or kind == "Prelude" then
      return name
   elseif kind == "Enumeration" then
      -- `Enum.X.Y` constants are integers; arguments accept any number (see luaIndex).
      return "number"
   elseif kind == "Alias" or kind == "CallbackType" then
      if resolved_cache[name] then return resolved_cache[name] end
      if resolving[name] then return "any" end -- cycle
      resolving[name] = true
      local t: string
      if kind == "Alias" then
         t = luals_to_tl(alias_exprs[name])
      else
         t = callback_type(callback_defs[name])
      end
      resolving[name] = nil
      resolved_cache[name] = t
      return t
   end
   unresolved[name] = (unresolved[name] or 0) + 1
   return "any"
end

local function blizz_type(f: Field): string
   if f.Type == "table" then
      if f.InnerType then
         return "{" .. resolve_name(f.InnerType) .. "}"
      end
      return "{any:any}"
   end
   return resolve_name(f.Type)
end

local TEAL_PRIMITIVE_UNION_OK: {string:boolean} = {
   string = true, number = true, integer = true, boolean = true,
}

-- Convert a LuaLS type expression to a Teal type, conservatively.
local function split_top(expr: string, sep: string): {string}
   local parts: {string} = {}
   local depth = 0
   local start = 1
   for i = 1, #expr do
      local c = expr:sub(i, i)
      if c == "(" or c == "<" or c == "[" or c == "{" then depth = depth + 1
      elseif c == ")" or c == ">" or c == "]" or c == "}" then depth = depth - 1
      elseif c == sep and depth == 0 then
         table.insert(parts, expr:sub(start, i - 1))
         start = i + 1
      end
   end
   table.insert(parts, expr:sub(start))
   return parts
end

luals_to_tl = function(expr: string): string
   if not expr or expr == "" then return "any" end
   expr = expr:gsub("^%s+", ""):gsub("%s+$", "")
   if expr:match("^fun%(") or expr == "function" then return "function" end

   local parts = split_top(expr, "|")
   if #parts > 1 then
      local seen: {string:boolean} = {}
      local out: {string} = {}
      local non_primitive = 0
      for _, p in ipairs(parts) do
         local t = luals_to_tl(p)
         if t ~= "nil" and not seen[t] then
            seen[t] = true
            table.insert(out, t)
            if not TEAL_PRIMITIVE_UNION_OK[t] then non_primitive = non_primitive + 1 end
         end
      end
      if seen["number"] and seen["integer"] then
         for i, t in ipairs(out) do if t == "integer" then table.remove(out, i) break end end
      end
      if #out == 0 then return "any" end
      if #out == 1 then return out[1] end
      if non_primitive > 1 or seen["any"] or seen["function"] then return "any" end
      return table.concat(out, " | ")
   end

   expr = expr:gsub("%?$", "")
   if expr == "nil" then return "nil" end
   if expr:match('^".*"$') or expr:match("^'.*'$") then return "string" end
   if expr:match("^%-?%d+$") then return "integer" end
   if expr:match("^%-?[%d%.]+$") then return "number" end
   if expr == "true" or expr == "false" then return "boolean" end
   if expr:match("^`") then return "any" end
   local inner = expr:match("^(.+)%[%]$")
   if inner then return "{" .. luals_to_tl(inner) .. "}" end
   local k, v = expr:match("^table<(.-),(.+)>$")
   if k then return "{" .. luals_to_tl(k) .. ":" .. luals_to_tl(v) .. "}" end
   if expr == "table" then return "{any:any}" end
   if expr == "any" or expr == "unknown" or expr == "userdata" or expr == "lightuserdata" or expr == "thread" then
      return "any"
   end
   if expr == "integer" then return "integer" end
   local enum_name = expr:match("^Enum%.([%w_]+)$")
   if enum_name then
      return "integer"
   end
   if expr:match("[^%w_]") then return "any" end
   return resolve_name(expr)
end

--------------------------------------------------------------------------------
-- Emitters
--------------------------------------------------------------------------------

local function emit_args(args: {Field}): string
   local out: {string} = {}
   for i, a in ipairs(args or {}) do
      if a.StrideIndex then
         table.insert(out, "...: " .. blizz_type(a))
         break
      end
      local opt = (a.Nilable or a.Default ~= nil) and "?" or ""
      table.insert(out, param_name(a.Name, i) .. opt .. ": " .. blizz_type(a))
   end
   return table.concat(out, ", ")
end

local function emit_returns(rets: {Field}): string
   if not rets or #rets == 0 then return "" end
   local out: {string} = {}
   for _, r in ipairs(rets) do
      if r.StrideIndex then
         table.insert(out, blizz_type(r) .. "...")
         break
      end
      table.insert(out, blizz_type(r))
   end
   return ": " .. table.concat(out, ", ")
end

callback_type = function(c: TableDef): string
   return "function(" .. emit_args(c.Arguments) .. ")" .. emit_returns(c.Returns)
end

local function func_tags(f: Func): {string}
   local tags: {string} = {}
   if f.IsProtectedFunction then table.insert(tags, "[protected]") end
   if f.MayReturnNothing then table.insert(tags, "[may return nothing]") end
   for _, r in ipairs(f.Returns or {}) do
      if r.Nilable then table.insert(tags, "[nilable: " .. r.Name .. "]") end
   end
   return tags
end

local function func_type(f: Func, method: boolean): string
   local args = emit_args(f.Arguments)
   if method then
      args = args == "" and "self" or ("self, " .. args)
   end
   return "function(" .. args .. ")" .. emit_returns(f.Returns)
end

-- Teal function type for a parsed Ketho function (without `self`).
local function ketho_signature(f: KFunc): string
   local args: {string} = {}
   for i, p in ipairs(f.params) do
      if p.name == "..." then
         table.insert(args, "...: " .. luals_to_tl(p.type))
      else
         table.insert(args, param_name(p.name, i) .. (p.optional and "?" or "") .. ": " .. luals_to_tl(p.type))
      end
   end
   local rets: {string} = {}
   for i, r in ipairs(f.returns) do
      local t = luals_to_tl(r)
      if t == "nil" then t = "any" end
      if f.variadic_return and i == #f.returns then t = t .. "..." end
      table.insert(rets, t)
   end
   return "function(" .. table.concat(args, ", ") .. ")" .. (#rets > 0 and (": " .. table.concat(rets, ", ")) or "")
end

local function list_lua_files(dir: string): {string}
   local cmd: string
   if package.config:sub(1, 1) == "\\" then
      cmd = 'dir /s /b "' .. (dir:gsub("/", "\\")) .. '\\*.lua" 2>nul'
   else
      cmd = 'find "' .. dir .. '" -name "*.lua" 2>/dev/null'
   end
   local files: {string} = {}
   local p = io.popen(cmd)
   if p then
      for line in p:lines() do table.insert(files, line) end
      p:close()
   end
   table.sort(files)
   return files
end

--------------------------------------------------------------------------------
-- Main
--------------------------------------------------------------------------------

local docs = load_blizzard_docs()

-- Pass 1: register every type name so references resolve regardless of order.
local widget_by_name: {string:WidgetClass} = {}
for _, w in ipairs(WIDGETS) do
   defined[w.name] = "Widget"
   widget_by_name[w.name] = w
end

-- Hand-written prelude types (loaded before the generated file, so generated code
-- may reference them by name). `-- @redirect blizzType PreludeType` comments map
-- Blizzard pseudo-types onto prelude types.
local prelude = read_file(PRELUDE_FILE) or ""
for line in prelude:gmatch("[^\r\n]+") do
   local name = line:match("^global%s+record%s+([%w_]+)")
      or line:match("^global%s+interface%s+([%w_]+)")
      or line:match("^global%s+enum%s+([%w_]+)")
      or line:match("^global%s+type%s+([%w_]+)")
   if name then defined[name] = "Prelude" end
   local from, to = line:match("^%-%-%s*@redirect%s+([%w_]+)%s+([%w_]+)")
   if from then redirects[from] = to end
end

local enums: {string:TableDef} = {}
local structures: {string:TableDef} = {}
local constants: {string:TableDef} = {}
local callbacks: {string:TableDef} = {}
local duplicates: {string} = {}

for _, d in ipairs(docs) do
   if d.Environment ~= "SecureOnly" then
      for _, t in ipairs(d.Tables or {}) do
         local bucket: {string:TableDef} =
            t.Type == "Enumeration" and enums
            or t.Type == "Structure" and structures
            or t.Type == "Constants" and constants
            or t.Type == "CallbackType" and callbacks
            or nil
         if bucket then
            if defined[t.Name] and t.Type ~= "Constants" then
               table.insert(duplicates, t.Type .. " " .. t.Name .. " (" .. d.file .. ")")
            else
               bucket[t.Name] = t
               if t.Type ~= "Constants" then defined[t.Name] = t.Type end
               if t.Type == "CallbackType" then callback_defs[t.Name] = t end
            end
         end
      end
   end
end

-- Ketho aliases and string enums. Blizzard definitions take precedence.
local kaliases: {KAlias} = {}
parse_ketho_aliases(KETHO .. "/Type/BlizzardType.lua", kaliases, "Type/BlizzardType.lua")
parse_ketho_aliases(KETHO .. "/Type/StringEnum.lua", kaliases, "Type/StringEnum.lua")
parse_ketho_aliases(KETHO .. "/Type/UnitToken.lua", kaliases, "Type/UnitToken.lua")
for _, f in ipairs({ "UIType.lua", "FrameType.lua", "Template.lua", "Font.lua" }) do
   parse_ketho_aliases(KETHO .. "/Widget/UIType/" .. f, kaliases, "Widget/UIType/" .. f)
end
local kept_aliases: {KAlias} = {}
for _, a in ipairs(kaliases) do
   if not defined[a.name] and not PRIMITIVES[a.name] and not a.name:match("%.")
      and (a.expr or #a.literals > 0) then
      if #a.literals > 0 and not a.expr then
         defined[a.name] = "StringEnum"
      else
         defined[a.name] = "Alias"
         alias_exprs[a.name] = #a.literals > 0 and ("string|" .. a.expr) or a.expr
      end
      table.insert(kept_aliases, a)
   end
end
for _, g in ipairs(SCRIPT_HANDLERS) do defined[g.enum_name] = "StringEnum" end
defined["FrameEvent"] = "StringEnum"

-- Pass 2: emit.
local out: {string} = {}
local function w(s: string) table.insert(out, s) end

w("-- GENERATED by types/gen/build.tl -- DO NOT EDIT.")
w("-- Sources: Blizzard_APIDocumentationGenerated (" .. (read_file(ui_source .. "/version.txt") or "?"):gsub("%s+$", "") .. ")")
w("--          Ketho/vscode-wow-api annotations (MIT, see types/vendor/ketho/LICENSE)")
w("")

-- Aliases and string enums -----------------------------------------------------
w("------------------------------------------------------------------------------")
w("-- String enums (Ketho). Plain aliases are emitted at the end of the file.")
w("------------------------------------------------------------------------------")
for _, a in ipairs(kept_aliases) do
   if defined[a.name] == "StringEnum" then
      local vals: {string} = {}
      local seen: {string:boolean} = {}
      for _, l in ipairs(a.literals) do
         if not seen[l] then seen[l] = true; table.insert(vals, string.format("%q", l)) end
      end
      w("global enum " .. a.name)
      for _, v in ipairs(vals) do w("   " .. v) end
      w("end")
   end
end
w("")

-- Script handler enums
for _, g in ipairs(SCRIPT_HANDLERS) do
   w("global enum " .. g.enum_name)
   for _, n in ipairs(g.names) do w(string.format("   %q", n)) end
   w("end")
end
w("")

-- Blizzard enums -------------------------------------------------------------------
w("------------------------------------------------------------------------------")
w("-- Enumerations (Blizzard). `Enum.X.Y` values are integers; `X` is an integer alias (end of file).")
w("------------------------------------------------------------------------------")
local enum_names = sorted_keys(enums)
w("global record Enum")
for _, n in ipairs(enum_names) do
   w("   record " .. n)
   for _, f in ipairs(enums[n].Fields or {}) do
      w("      " .. field_key(f.Name) .. ": integer")
   end
   w("   end")
end
w("end")
w("")

-- Constants ------------------------------------------------------------------------
w("global record Constants")
for _, n in ipairs(sorted_keys(constants)) do
   w("   record " .. n)
   for _, f in ipairs(constants[n].Values or {}) do
      w("      " .. field_key(f.Name) .. ": " .. blizz_type(f))
   end
   w("   end")
end
w("end")
w("")

-- Structures -----------------------------------------------------------------------
w("------------------------------------------------------------------------------")
w("-- Structures (Blizzard)")
w("------------------------------------------------------------------------------")
for _, n in ipairs(sorted_keys(structures)) do
   local s = structures[n]
   doc_comment(out, "", s.Documentation, nil)
   w("global record " .. n)
   for _, f in ipairs(s.Fields or {}) do
      doc_comment(out, "   ", f.Documentation, f.Nilable and { "[nilable]" } or nil)
      w("   " .. field_key(f.Name) .. ": " .. blizz_type(f))
   end
   w("end")
end
w("")

-- Widgets ----------------------------------------------------------------------------
w("------------------------------------------------------------------------------")
w("-- Widgets (hierarchy from Ketho, methods from Blizzard Simple*API docs)")
w("------------------------------------------------------------------------------")
local widget_api: {string:Doc} = {}
for _, d in ipairs(docs) do
   if d.Type == "ScriptObject" then widget_api[d.Name] = d end
end
local used_api: {string:boolean} = {}

-- Methods already declared on an ancestor; Teal rejects redeclaring them with a different type.
local declared_methods: {string:{string:string}} = {}
local function ancestor_method(cls: WidgetClass, method: string): string
   for _, p in ipairs(cls.parents) do
      local pm = declared_methods[p]
      if pm and pm[method] then return pm[method] end
      local pw = widget_by_name[p]
      if pw then
         local r = ancestor_method(pw, method)
         if r then return r end
      end
   end
   return nil
end

local shadowed: {string} = {}

-- Ketho widget methods, by class.
local SKIP_KETHO_METHODS: {string:boolean} = { SetScript = true, HookScript = true, GetScript = true, HasScript = true }
local ketho_methods: {string:{KFunc}} = {}
local ketho_method_count = 0
for _, file in ipairs(list_lua_files(KETHO .. "/Widget")) do
   for _, f in ipairs(parse_ketho_functions(file)) do
      local cls = f.name:match("^([%w_]+):")
      if cls and widget_by_name[cls] then
         ketho_methods[cls] = ketho_methods[cls] or {}
         table.insert(ketho_methods[cls], f)
      end
   end
end
for _, cls in ipairs(WIDGETS) do
   -- A record class is emitted as `interface <Name>API` (all methods; addons can
   -- extend it) followed by `record <Name> is <Name>API end` (the type + value).
   local header = "global interface " .. (cls.is_record and (cls.name .. "API") or cls.name)
   if #cls.parents > 0 then header = header .. " is " .. table.concat(cls.parents, ", ") end
   w(header)
   declared_methods[cls.name] = {}
   if cls.name == "ScriptObject" then
      for _, g in ipairs(SCRIPT_HANDLERS) do
         local h = "function(frame: self" .. g.params .. ")"
         w("   SetScript: function(self, scriptType: " .. g.enum_name .. ", handler: " .. h .. ")")
         w("   HookScript: function(self, scriptType: " .. g.enum_name .. ", handler: " .. h .. ")")
         w("   GetScript: function(self, scriptType: " .. g.enum_name .. "): " .. h)
      end
      w("   HasScript: function(self, scriptType: string): boolean")
   end
   for _, api in ipairs(cls.apis) do
      local d = widget_api[api]
      if not d then
         io.stderr:write("warning: no Blizzard doc table " .. api .. " for widget " .. cls.name .. "\n")
      else
         used_api[api] = true
         local seen: {string:boolean} = {}
         for _, f in ipairs(d.Functions or {}) do
            local t = func_type(f, true)
            local key = f.Name .. "=" .. t
            local override = METHOD_OVERRIDES[cls.name .. ":" .. f.Name] or METHOD_OVERRIDES["*:" .. f.Name]
            if override then
               if not seen[f.Name] then
                  seen[f.Name] = true
                  doc_comment(out, "   ", f.Documentation, { "[signature overridden in types/gen/build.tl]" })
                  for _, sig in ipairs(override) do
                     w("   " .. field_key(f.Name) .. ": " .. sig)
                  end
                  declared_methods[cls.name][f.Name] = table.concat(override, ";")
               end
            elseif not seen[key] then
               seen[key] = true
               local prev = ancestor_method(cls, f.Name)
               if prev and prev ~= t then
                  table.insert(shadowed, cls.name .. ":" .. f.Name)
               elseif not prev then
                  doc_comment(out, "   ", f.Documentation, func_tags(f))
                  w("   " .. field_key(f.Name) .. ": " .. t)
                  declared_methods[cls.name][f.Name] = t
               end
            end
         end
      end
   end
   -- Fill gaps from Ketho's widget annotations (methods Blizzard's docs omit,
   -- e.g. GameTooltip:AddLine). Blizzard's declarations always win.
   for _, kf in ipairs(ketho_methods[cls.name] or {}) do
      local m = kf.name:match(":(.+)$")
      if not SKIP_KETHO_METHODS[m] and is_identifier(m)
         and not declared_methods[cls.name][m] and not ancestor_method(cls, m) then
         local t = "function(self" .. (#kf.params > 0 and ", " or "") .. ketho_signature(kf):sub(#"function(" + 1)
         w("   -- (Ketho)")
         w("   " .. m .. ": " .. t)
         declared_methods[cls.name][m] = t
         ketho_method_count = ketho_method_count + 1
      end
   end
   w("end")
   if cls.is_record then
      w("global record " .. cls.name .. " is " .. cls.name .. "API end")
   end
end
local unused_api: {string} = {}
for name in pairs(widget_api) do
   if not used_api[name] then table.insert(unused_api, name) end
end
table.sort(unused_api)
w("")

-- Systems --------------------------------------------------------------------------
w("------------------------------------------------------------------------------")
w("-- Namespaced C API (Blizzard)")
w("------------------------------------------------------------------------------")
local namespaces: {string:{Func}} = {}
local ns_sources: {string:{string}} = {}
local plain_globals: {Func} = {}
local plain_seen: {string:boolean} = {}
for _, d in ipairs(docs) do
   if d.Type == "System" and d.Environment ~= "SecureOnly" then
      if d.Namespace and d.Namespace ~= "" then
         namespaces[d.Namespace] = namespaces[d.Namespace] or {}
         ns_sources[d.Namespace] = ns_sources[d.Namespace] or {}
         table.insert(ns_sources[d.Namespace], d.file)
         for _, f in ipairs(d.Functions or {}) do table.insert(namespaces[d.Namespace], f) end
      else
         for _, f in ipairs(d.Functions or {}) do
            if not plain_seen[f.Name] then
               plain_seen[f.Name] = true
               table.insert(plain_globals, f)
            end
         end
      end
   end
end

for _, ns in ipairs(sorted_keys(namespaces)) do
   if ns:match("%.") then
      io.stderr:write("warning: skipping dotted namespace " .. ns .. "\n")
   else
      w("-- " .. table.concat(ns_sources[ns], ", "))
      w("global record " .. ns)
      local seen: {string:boolean} = {}
      for _, f in ipairs(namespaces[ns]) do
         local t = func_type(f, false)
         local override = FUNCTION_OVERRIDES[ns .. "." .. f.Name]
         if override then
            if not seen[f.Name] then
               seen[f.Name] = true
               doc_comment(out, "   ", f.Documentation, { "[signature overridden in types/gen/build.tl]" })
               for _, sig in ipairs(override) do w("   " .. field_key(f.Name) .. ": " .. sig) end
            end
         elseif not seen[f.Name .. "=" .. t] then
            seen[f.Name .. "=" .. t] = true
            doc_comment(out, "   ", f.Documentation, func_tags(f))
            w("   " .. field_key(f.Name) .. ": " .. t)
         end
      end
      w("end")
   end
end
w("")

w("------------------------------------------------------------------------------")
w("-- Global C API (Blizzard)")
w("------------------------------------------------------------------------------")
local global_names: {string:boolean} = {}
for _, f in ipairs(plain_globals) do
   if not SKIP_GLOBALS[f.Name] and is_identifier(f.Name) then
      global_names[f.Name] = true
      doc_comment(out, "", f.Documentation, func_tags(f))
      local override = FUNCTION_OVERRIDES[f.Name]
      w("global " .. f.Name .. ": " .. (override and override[1] or func_type(f, false)))
   end
end
w("")

-- Ketho legacy globals --------------------------------------------------------------
w("------------------------------------------------------------------------------")
w("-- Legacy global API (Ketho Data/Wiki.lua; not in Blizzard's generated docs)")
w("------------------------------------------------------------------------------")
local wiki = parse_ketho_functions(KETHO .. "/Data/Wiki.lua")
local wiki_skipped_generic: {string} = {}
local wiki_count = 0
for _, f in ipairs(wiki) do
   if f.name:match("[%.:]") or global_names[f.name] or SKIP_GLOBALS[f.name] or not is_identifier(f.name) then
      -- covered elsewhere
   elseif f.generic then
      table.insert(wiki_skipped_generic, f.name)
   else
      global_names[f.name] = true
      wiki_count = wiki_count + 1
      if f.deprecated then w("-- [deprecated]") end
      w("global " .. f.name .. ": " .. ketho_signature(f))
   end
end
w("")

-- Events ------------------------------------------------------------------------------
w("------------------------------------------------------------------------------")
w("-- Events (Blizzard)")
w("------------------------------------------------------------------------------")
local events: {string:Event} = {}
for _, d in ipairs(docs) do
   for _, e in ipairs(d.Events or {}) do
      if e.LiteralName then events[e.LiteralName] = e end
   end
end
local event_names = sorted_keys(events)
w("global enum FrameEvent")
for _, n in ipairs(event_names) do
   local e = events[n]
   local payload: {string} = {}
   for _, p in ipairs(e.Payload or {}) do
      table.insert(payload, p.Name .. ": " .. blizz_type(p))
   end
   w(string.format("   %q", n) .. (#payload > 0 and ("  -- " .. table.concat(payload, ", ")) or ""))
end
w("end")
w("")

-- Named aliases ---------------------------------------------------------------------------
-- Emitted last so every type they mention is already declared. Their uses above are
-- inlined. Names that collide with a global *value* (e.g. the `UnitSex` function vs
-- the `UnitSex` enumeration) are skipped: Teal globals share one namespace.
w("------------------------------------------------------------------------------")
w("-- Named aliases (Ketho aliases, Blizzard enumerations and callback types)")
w("------------------------------------------------------------------------------")
local value_names: {string:boolean} = { Enum = true, Constants = true }
for n in pairs(global_names) do value_names[n] = true end
for n in pairs(namespaces) do value_names[n] = true end
local alias_collisions: {string} = {}
local function emit_alias(name: string)
   if value_names[name] then
      table.insert(alias_collisions, name)
      return
   end
   local t = resolve_name(name)
   if t == name then t = "any" end
   w("global type " .. name .. " = " .. t)
end
for _, a in ipairs(kept_aliases) do
   if defined[a.name] == "Alias" then emit_alias(a.name) end
end
for _, n in ipairs(enum_names) do emit_alias(n) end
for _, n in ipairs(sorted_keys(callbacks)) do emit_alias(n) end
local unresolved_names = sorted_keys(unresolved)

write_file(OUT_FILE, table.concat(out, "\n") .. "\n")

-- Report ---------------------------------------------------------------------------------
local r: {string} = {}
table.insert(r, "# Generator report\n")
table.insert(r, "Generated by `types/gen/build.tl`. Do not edit.\n")
table.insert(r, string.format("- Blizzard doc tables: %d", #docs))
table.insert(r, string.format("- Enumerations: %d, Structures: %d, Constants tables: %d, Callback types: %d",
   #enum_names, #sorted_keys(structures), #sorted_keys(constants), #sorted_keys(callbacks)))
table.insert(r, string.format("- Namespaces: %d, plain C globals: %d, Ketho legacy globals: %d",
   #sorted_keys(namespaces), #plain_globals, wiki_count))
table.insert(r, string.format("- Events: %d, Ketho aliases/enums kept: %d, Ketho widget methods added: %d",
   #event_names, #kept_aliases, ketho_method_count))
table.insert(r, "\n## Unresolved type names (typed as `any`)\n")
for _, n in ipairs(unresolved_names) do
   table.insert(r, string.format("- `%s` (%d refs)", n, unresolved[n]))
end
table.insert(r, "\n## Aliases not emitted (name collides with a global value)\n")
for _, s in ipairs(alias_collisions) do table.insert(r, "- `" .. s .. "`") end
table.insert(r, "\n## Widget methods skipped (conflict with an ancestor's signature)\n")
for _, s in ipairs(shadowed) do table.insert(r, "- `" .. s .. "`") end
table.insert(r, "\n## Blizzard widget doc tables not mapped to a widget class\n")
for _, s in ipairs(unused_api) do table.insert(r, "- `" .. s .. "`") end
table.insert(r, "\n## Duplicate table definitions (first one kept)\n")
for _, s in ipairs(duplicates) do table.insert(r, "- " .. s) end
table.insert(r, "\n## Generic Ketho globals skipped (declare in types/manual)\n")
for _, s in ipairs(wiki_skipped_generic) do table.insert(r, "- `" .. s .. "`") end
write_file(REPORT_FILE, table.concat(r, "\n") .. "\n")

print("wrote " .. OUT_FILE .. " (" .. #out .. " lines) and " .. REPORT_FILE)
print(#unresolved_names .. " unresolved type names")
