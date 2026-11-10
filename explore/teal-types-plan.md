# Plan: Teal (tl) type declarations for the WoW addon API

Target: **WoW Forever** (`## Interface: 16001`, client 1.60.x, built on the modern engine).
Tooling on this machine: `tl` 0.24.8 (standalone, embeds Lua 5.4; no separate `lua` / `luarocks` / `cyan`).

## Status (2026-11-10)

Phases 1–5 are implemented. See `types/README.md` for layout, commands and the Teal limitations found.

- [x] Skeleton: `tlconfig.lua`, `types/wow.d.tl`, `.pkgmeta` ignores, `.gitignore` (`types/.cache/`)
- [x] Generator `types/gen/build.tl` + `build.sh` (pinned: wow-ui-source `forever` 4cd0ab75, Ketho d0b5b51f).
      Output is deterministic: 31k lines, 900 enums, 768 structures, 284 namespaces, 734 C globals,
      1,272 Ketho legacy globals, 1,816 events, 61 widget classes. All of it type-checks.
- [x] Ketho conversion: aliases and string enums, `Data/Wiki.lua` globals, widget methods Blizzard omits (111)
- [x] Hand-written: prelude (ItemLocation, ColorMixin, vectors, TooltipData, FunctionContainer), CreateFrame and
      hooksecurefunc overloads, script handler signatures, FrameXML used by GearDisplay, Lua extensions
- [x] Tests: `types/tests/smoke.tl` (must pass) and `expect_errors.tl` (7 deliberate errors), run by `types/check.sh`
- [x] CI: `.github/workflows/types.yml` checks the generated file is fresh, runs `check.sh`, and lax-checks the addon
      (informational only)
- [ ] Filter Ketho legacy globals to ones that really exist in Forever (in-game dump addon)
- [ ] Events: typed `RegisterEvent(FrameEvent)` and `OnEvent` payloads (the enum exists; payloads are only comments)
- [ ] Port GearDisplay to `.tl` (Phase 6)

Lax check of the current Lua: ~286 errors. ~200 of them are the untyped `addonTable` from `...`, which the
`.tl` port's cast fixes. The rest are what the port has to handle:
- custom fields on the addon's own frames (`f.title`, `pane.cbQuality`), which need local interfaces
- template children (`cb.Text`, `btn.Icon`) and Blizzard frame children (`CharacterFrame.ModeTabs`)
- `_G[name]` lookups, which need `(_G as {string:any})[name]`
- `pcall(CreateFrame, ...)`, which picks the first overload
- fallback branches for APIs Forever doesn't have (`C_Item.GetInventoryItemLink`,
  `C_Item.GetItemQualityColor` returning a table, `InterfaceOptions_AddCategory`). The checker is right to flag
  these as dead code on Forever.

Decisions made while implementing:
- `luaIndex` and Blizzard enum-typed *arguments* are `number`, not `integer` (Lua 5.1; less friction).
- Enum aliases are emitted for readability unless they collide with a global value.
- Converted globals are not yet filtered to Forever (open question 2 below is still open).

## 0. Decisions (2026-11-10)
- The types live **in this repo** under `types/` for now. They may be split out later.
- **Goal: port GearDisplay to Teal.** Lax-checking the existing `.lua` is just the first milestone on the way.
- **Source the types from two places** (see §7):
  - **Generate** every C API (`C_*`, documented globals, enums, structures, events) from Blizzard's `forever`-branch
    docs. This is the only source that exactly matches 1.60.
  - **Convert** the layers the Blizzard docs don't have from Ketho/vscode-wow-api (MIT): the widget hierarchy,
    legacy globals (`Data/Wiki.lua`), Lua extensions (`Lua/`), `FrameType` / `ScriptType` / `Template`
    string lists, and the FrameXML functions we actually use.

---

## 1. Findings

### 1.1 Source of truth
- `C:\Users\Sean\code\blizz\wow-ui-source` was on `live` (12.1.0). **I switched it to the `forever` branch**
  (`1.60.1.70888`, matching Interface 16001). Other branches (`classic_era` 1.15.9, `classic_beta` 5.5.0, `live`)
  could be added later as alternative profiles.
- `Interface/AddOns/Blizzard_APIDocumentationGenerated/*.lua` (639 files on `forever`) is machine-readable. Each
  file builds a table:
  ```lua
  { Name = "Container", Type = "System" | "ScriptObject", Namespace = "C_Container", Environment = "All" | "SecureOnly",
    Functions = { { Name, Type="Function", Arguments={...}, Returns={...}, MayReturnNothing, IsProtectedFunction,
                    SecretArguments, Documentation, ... } },
    Events    = { { Name, LiteralName = "BAG_UPDATE", Payload = {...} } },
    Tables    = { { Name, Type = "Enumeration" | "Structure" | "Constants" | "CallbackType", Fields/Values/Arguments } } }
  ```
  Each field/argument looks like `{ Name, Type, Nilable, Default, InnerType (for "table"), Mixin, StrideIndex, EnumValue }`.
- Primitive / alias types seen: `number`, `bool`, `string`, `cstring`, `table` (+`InnerType`), `luaIndex`,
  `WOWGUID`, `UnitToken`, `fileID`, `textureAtlas`, `textureKit`, `ItemLocation`, `colorRGB`(+`Mixin`), `vector2`, …
- Systems **without** a `Namespace` are plain globals (e.g. `UnitDocumentation.lua` → `UnitExists`, `UnitGUID`, …;
  `FrameScriptDocumentation.lua`, `InputDocumentation.lua`, …).
- Widget methods are in `Simple*APIDocumentation.lua` files (`Type = "ScriptObject"`): `SimpleObjectAPI`,
  `SimpleFrameScriptObjectAPI`, `SimpleScriptRegionAPI`, `SimpleRegionAPI`, `SimpleFrameAPI`, `SimpleButtonAPI`,
  `SimpleTextureAPI`, `SimpleFontStringAPI`, `FrameAPITooltipDocumentation` (GameTooltip), …

### 1.2 Things the generated docs do not cover
These have to be written by hand or pulled from other sources:

| Gap | Examples used by GearDisplay |
|---|---|
| Widget **inheritance** (the docs list methods per class, not the class tree) | `Frame is Region is ScriptRegion is Object` |
| Some core/legacy globals | `CreateFrame` (the documented `CreateFrame` is in the PingManager namespace, a different function), `GetInventoryItemLink`, `GetItemInfo`, `hooksecurefunc` |
| Script handlers (`SetScript("OnEnter", fn)` signatures) | `OnEvent`, `OnEnter`, `OnLeave`, `OnClick`, `OnShow`, `OnHide`, `OnValueChanged` |
| FrameXML / SharedXML Lua (Blizzard UI code, not C API) | `ShowUIPanel`, `HideUIPanel`, `ToggleCharacter`, `HandleModifiedItemClick`, `DressUpItemLink`, `ChatEdit_InsertLink`, `PanelTemplates_TabResize`, `InterfaceOptions_AddCategory`, `Settings.*`, `ItemLocation` mixin, `UISpecialFrames` |
| Named global frames | `CharacterFrame`, `PaperDollFrame`, `PaperDollItemsFrame`, `InspectFrame`, `GameTooltip`, `CharacterFrameTab*` |
| Templates → concrete type | `GameTooltipTemplate`, `UIPanelButtonTemplate`, `BasicFrameTemplateWithInset`, `InterfaceOptionsCheckButtonTemplate` |
| Event payloads keyed by the event *string* | `RegisterEvent("PLAYER_EQUIPMENT_CHANGED")` + `OnEvent` varargs |
| Lua stdlib extras the WoW VM adds | `strsplit`, `wipe`, `tinsert`, `format`, `strtrim`, `date`, `time`, `bit.*` |

### 1.3 Teal behaviour I checked with a prototype (tl 0.24.8, `global_env_def`)
Prototype is in the scratchpad (`tlproto/`). Results:

- ✅ `tlconfig.lua` `{ global_env_def = "wow", gen_target = "5.1", gen_compat = "off" }` works. Globals from
  `wow.d.tl` are visible in every checked file. Nothing runs at runtime, and no `require` is emitted.
- ✅ `global interface Region is ScriptObject … end` models the widget tree. Methods are written as
  `SetPoint: function(self, point: string, relativeTo?: Region | string, …)`, and optional args (`x?: T`) work.
- ✅ `global enum FrameStrata "LOW" "HIGH" … end` rejects bad string literals (`"NOPE" is not a member of FrameStrata`).
- ✅ Record **overloads** on enum-typed arguments work, so `CreateFrame("Button")` can return a `Button`
  (declare `CreateFrame` several times with different first-arg enums).
- ✅ A generic `CreateFrame: function<T is Frame>(...): T` works when inferred from the annotation
  (`local b: Button = CreateFrame(...)`). An explicit `CreateFrame<Button>(...)` with an interface is rejected
  ("interfaces are abstract").
- ✅ `//` compiles to `math.floor(a / b)` for target 5.1. `gen_compat = "off"` stops `compat53` requires (WoW has no `require`).
- ✅ `tl check SomeFile.lua` runs in **lax mode** on plain Lua. It still errors on bad method names
  (`invalid key 'Nope' in 'f' of interface type Frame`) and only warns on unknown globals. This gives type
  checking **without converting the addon**.
- ⚠️ `local addonName, ns = ...` types both as `string`. Fix: `local addonName, ns = ... as (string, Namespace)`.
- ⚠️ Declaring returns as `string | nil` is a trap. `if link then link:len() end` does **not** narrow it in 0.24.
  Teal values are already nilable, so declare plain `string` (as Blizzard's `Nilable = true` would suggest) and
  keep nilability as a doc comment.
- ℹ️ `tl run script.lua` runs Lua 5.4 and can `dofile` the Blizzard doc files. **The generator can be run with
  `tl run`**, so no extra Lua install is needed.

---

## 2. Proposed layout

```
types/                         -- (or a separate repo / git submodule later, reusable across addons)
  tlconfig.lua                 -- profile: forever
  gen/
    generate.tl                -- reads Blizzard_APIDocumentationGenerated → generated/*.d.tl
    typemap.tl                 -- Blizzard type → Teal type table
  generated/                   -- DO NOT EDIT; regenerated per client build
    systems.d.tl               -- C_* namespaces + un-namespaced globals
    enums.d.tl                 -- Enum.* (as `global record Enum` with integer constants + `enum`-ish aliases)
    structures.d.tl            -- Structure tables → records
    widgets.d.tl               -- Simple*API methods merged into widget interfaces
    events.d.tl                -- event name enum + payload records
  manual/
    widgets_hierarchy.d.tl     -- interface tree + script handler signatures
    globals_core.d.tl          -- CreateFrame overloads, hooksecurefunc, GetInventoryItemLink, …
    framexml.d.tl              -- ShowUIPanel, Settings, ItemLocation, named frames used by addons
    luaext.d.tl                -- strsplit, wipe, tinsert, bit, …
  wow.d.tl                     -- single entry: requires/re-exports everything above (global_env_def target)
```

`.pkgmeta` gets `- types`, `- tlconfig.lua`, `- "*.tl"` added to `ignore` so nothing ships.

Note: `global_env_def` takes **one** module. That module can `require` the others, as long as they only declare
`global`s. Verify this in Phase 1. If chained requires don't propagate globals, the generator concatenates
everything into one `wow.d.tl`.

---

## 3. Type mapping (generator rules)

| Blizzard | Teal |
|---|---|
| `number` | `number` |
| `luaIndex`, `fileID`, `BagIndex`, `*ID` integers | `integer` (aliases: `global type luaIndex = integer`) |
| `bool` | `boolean` |
| `string`, `cstring`, `WOWGUID`, `textureAtlas`, `textureKit`, `UnitToken*`, `uiUnit` | `string` (keep named aliases: `global type WOWGUID = string`) |
| `table` + `InnerType = X` | `{X}` |
| `table` w/o InnerType | `{any:any}` |
| Structure name | `global record <Name>` with fields |
| Enumeration name | `integer` alias + `Enum.<Name>.<Value>: integer` constants (Blizzard enums are numbers, not strings) |
| `Mixin = "ColorMixin"` | the mixin interface (hand-written, e.g. `ColorMixin`) |
| `ScriptObject` / widget names | the matching widget interface |
| `Nilable = true` arg | `name?: T` |
| `Nilable = true` return | plain `T` (see 1.3 ⚠️) |
| `Default = x` | optional arg `name?: T` |
| `StrideIndex` returns (repeating groups) | `...: any` (or hand-override) |
| variadic args (`...`) | `...: T` |
| `CallbackType` | `function(...)` type alias |
| `Documentation = {...}` | `-- ` comment above the field |
| `IsProtectedFunction`, `SecretArguments`, `Environment = "SecureOnly"` | comment tag; skip `SecureOnly` systems entirely |

Unknown/unresolved type names → `any` plus a generator warning listing them. The list shows what to hand-write next.

Name collisions: Teal reserved words (`record`, `enum`, `type`, `interface`, `global`, …) used as field names
must be quoted, `["record"]: T`. Check whether tl 0.24 allows that in records and have the generator handle it.

---

## 4. Widget hierarchy (hand-written, then merged with generated methods)

```
Object (SimpleObjectAPI)
└─ FrameScriptObject (SimpleFrameScriptObjectAPI)
   └─ ScriptRegion (SimpleScriptRegionAPI + SimpleScriptRegionResizingAPI)
      ├─ Region (SimpleRegionAPI)
      │  ├─ TextureBase → Texture, MaskTexture, Line
      │  └─ FontString (SimpleFontStringAPI + SimpleFontAPI-ish font instance methods)
      └─ Frame (SimpleFrameAPI)
         ├─ Button → CheckButton (SimpleCheckboxAPI)
         ├─ Slider, StatusBar, EditBox, ScrollFrame, Cooldown, Model…, MessageFrame, SimpleHTML
         └─ GameTooltip (FrameAPITooltipDocumentation)
AnimationGroup / Animation subclasses (SimpleAnim*API)
```

The generator emits methods into `global interface <Widget> is <Parent>`. The parent mapping is a small table in
`typemap.tl`.

Extra pieces:
- `SetScript` / `HookScript` / `GetScript` overloads per handler name. Use an enum per widget class
  (`FrameScriptType "OnEvent" "OnShow" …`) and one overload per handler signature group:
  `SetScript: function(self, s: "OnEvent"-enum, h: function(self: Frame, event: string, ...: any))`.
- `CreateFrame` overloads keyed by an enum per frame type (`"Frame"`, `"Button"`, `"CheckButton"`, `"Slider"`,
  `"GameTooltip"`, …), returning the matching interface. Also a generic fallback
  `function<T is Frame>(t: string, …): T`.
- `CreateTexture`, `CreateFontString` return `Texture` / `FontString`.

---

## 5. Using it in GearDisplay — two options

**A. Keep shipping `.lua`, type-check in lax mode (recommended first step)**
- `tl check Locales.lua Config.lua GearDisplay.lua` with `tlconfig.lua` pointing at `types/wow`.
- No source changes and no build step. CurseForge packaging is unchanged.
- Finds wrong method names, wrong arg counts/types for known APIs, and enum typos. Unknown globals only warn.
- Add an npm-free CI step: a GitHub Action that downloads the tl release binary and runs `tl check`.

**B. Port to `.tl`, compile to `.lua` (stricter, later)**
- Rename to `*.tl`. `tl gen --gen-target 5.1 --gen-compat off` writes the `.lua` the TOC loads.
- Either commit the generated `.lua` (simplest for CurseForge) or generate it in the packaging workflow before
  `BigWigsMods/packager` runs.
- Needs addon-local types: `Namespace` record (`addonTable`), `GearDisplayDB` shape (`global GearDisplayDB: DBSchema`),
  locale table `L: {string:string}`.
- Watch out for: the `...` cast (1.3 ⚠️); `pcall` wrappers around APIs that may not exist (`if C_Item and C_Item.GetItemInfo`).
  In Teal those globals are declared as always present, so the checks still compile but read as redundant. That is fine.

---

## 6. Phases

1. **Skeleton + config** (~1h)
   - Create `types/`, `tlconfig.lua`, and an empty `wow.d.tl`. Check that a chained `require` inside the env-def module
     exposes globals; otherwise switch to single-file output.
   - Add `.pkgmeta` ignores.
2. **Generator MVP** (`gen/generate.tl`, run with `tl run`)
   - Load every doc file with `dofile` into a sandbox env (the files reference `Enum.SecretAspect.*` and
     `APIDocumentation:AddDocumentationTable(...)` at the bottom, so stub both).
   - Emit `systems.d.tl` (namespaces + plain globals), `enums.d.tl`, `structures.d.tl`.
   - Output an "unresolved types" report.
3. **Widgets**
   - Hand-write the hierarchy (§4) and merge the generated `Simple*API` methods into it.
   - Hand-write `SetScript` handler overloads and `CreateFrame` overloads.
4. **Manual core globals + FrameXML used by this addon** (only what GearDisplay touches; list in §1.2)
   - Core: `GetInventoryItemLink`, `GetInventoryItemQuality`, `GetItemInfo`, `hooksecurefunc`, `InCombatLockdown`, `C_Timer`.
   - FrameXML: `ShowUIPanel`, `HideUIPanel`, `ToggleCharacter`, `HandleModifiedItemClick`, `DressUpItemLink`,
     `ChatEdit_InsertLink`, `PanelTemplates_TabResize`, `Settings.*`, `InterfaceOptions_AddCategory`,
     `ItemLocation`, `UISpecialFrames`.
   - Named frames: `CharacterFrame`, `PaperDollFrame`, `PaperDollItemsFrame`, `InspectFrame`,
     `InspectPaperDollFrame`, `GameTooltip`, `CharacterFrameTab1..n`.
   - Lua extensions: `strsplit`, `wipe`, `tinsert`, `format`, `bit`.
5. **Lax-check GearDisplay** (Option A). Fix real bugs it finds and tune declarations where they're wrong.
   Add the CI job.
6. **Events**: generate an `EventName` enum from `LiteralName`, plus payload records. Optionally add a typed
   `RegisterEvent` overload so typos in event names are caught.
7. **(Optional) Port to Teal** (Option B), one file at a time starting with `Locales.lua`.
8. **(Optional) Multi-flavor**: run the generator against `classic_era` / `live` branches into
   `generated/<flavor>/` and select the flavor in `tlconfig.lua`.

---

## 7. Converting from Ketho/vscode-wow-api

I inspected a shallow clone (`scratchpad/ketho`). The license is MIT (© 2020 Ketho). Keep their LICENSE next to
anything converted (`types/vendor/ketho/LICENSE`).

**What it has** (`Annotations/Core/`):

| Dir | Contents | Use? |
|---|---|---|
| `Blizzard_APIDocumentationGenerated/` | LuaLS version of Blizzard's docs, **mainline only** | ❌ Generate our own from `forever` |
| `Data/Enum.lua`, `Data/Event.lua` | mainline enums and events | ❌ Generate from `forever` |
| `Widget/` (`Base`, `Frame`, `Font`, `Texture`, `Animation`, `Intrinsic`) | `---@class Frame : Region, …` hierarchy + methods | ✅ Take the **hierarchy** (class → parents). Take methods only where `Simple*API` has gaps. |
| `Widget/UIType/` (`FrameType`, `ScriptType`, `Template`) | string unions (`---\|"OnEnter" # Frame`) | ✅ Becomes the Teal `enum`s for `CreateFrame` and `SetScript` |
| `Data/Wiki.lua` (~1,880 functions) | legacy globals: `CreateFrame`, `GetInventoryItemLink`, `GetItemInfo`, … | ✅ Convert, but only names that also exist in Forever (filter, see below) |
| `Lua/` (`basic`, `string`, `table`, `bit`, `compat`, …) | WoW Lua extensions (`strsplit`, `wipe`, `tinsert`, …) | ✅ Convert whole |
| `FrameXML/` (49 files) | Blizzard UI functions and mixins (`ShowUIPanel`, …) | ✅ Convert, allow-listed to what we use |
| `Data/Classic.lua`, `Libraries/` (Ace3, LibStub…) | classic extras and libraries | ⏸ Later, if needed |

**Caveats:**
- Ketho targets mainline 12.x (plus Mists and Vanilla badges, but these annotations are mainline). Forever is a
  modern-engine client, so signatures mostly match, but **which functions exist** differs. Filter converted
  globals: keep a name only if it exists in Forever. Two ways to check:
  - (a) Run `/dump` in game to export the list of global function names into SavedVariables. This is the most
    accurate.
  - (b) Grep the `forever` UI source for usages.
- The annotations don't type script handler signatures (`ScriptType` only lists names). Write the ~15
  handler signatures by hand (`OnEvent`, `OnEnter`, `OnClick`, …), grouped by argument shape.
- `CreateFrame` is a LuaLS generic over string literals (`` `T` ``). Teal has no literal types, so convert it to
  one overload per `FrameType` enum member (§4).

**Converter** (`types/gen/ketho2tl.tl`, run with `tl run`): a line-based parser for the LuaLS annotations it
needs to handle:
- `---@class A : B, C` → `global interface A is B, C`
- `---@param n T` / `---@param n? T` / `---@return T name` + `function X:M(...)` → a method field
- `---@alias` / `---|"x"` → `enum`
- `---@field`
- `T?` → `T`, `T[]` → `{T}`, `table<K,V>` → `{K:V}`, `fun(a: T): R` → `function(a: T): R`
- `A|B` → a union, but only if Teal allows it. Otherwise fall back to the first type or `any`, and log it.
- lowercase/uppercase alias classes (`---@class frame : Frame`) → skip

**Also:** `teal-language/teal-types` is the community declaration repo. A finished `wow` set could go there.

### Revised phases (replaces §6 ordering)
1. Skeleton: `types/`, `tlconfig.lua`, `.pkgmeta` ignores. Check whether chained `require` works for `global_env_def`.
2. Blizzard generator → `types/generated/` (C API, enums, structures, events) from the `forever` branch.
3. Ketho converter → `types/converted/` (widget hierarchy, UIType enums, `Lua/`, `Wiki.lua` filtered to Forever).
   `Simple*API` methods from step 2 are merged onto the converted hierarchy, and Blizzard's version wins.
4. Hand-written `types/manual/`: script handler signatures, `CreateFrame` overloads, GearDisplay-used FrameXML
   gaps, named frames.
5. `tl check` the current `.lua` files in lax mode. Fix declarations and real bugs. Add a CI job.
6. Port to Teal, one file at a time:
   - `Locales.lua` → `Config.lua` (introduces `DBSchema`, `global GearDisplayDB`) → `GearDisplay.lua`.
   - Commit the generated `.lua` next to the `.tl` so CurseForge packaging stays unchanged. CI checks that
     `tl gen` output matches what's committed.
   - Switch from lax `.lua` checks to strict `.tl` checks.

---

## 8. Open questions
1. Blizzard enums: plain `integer` constants (accurate at runtime), or also nominal `global type ItemQuality = integer`
   aliases for readability? Teal aliases are structural, so they don't add safety. Leaning: aliases, for documentation.
2. Filtering Ketho's globals to Forever: in-game dump (accurate, needs one manual step in the client), or grep the
   UI source (automatic, misses functions only C code exposes)? Leaning: in-game dump, using a tiny dev addon.
3. After the port, commit the generated `.lua` (simple), or build it in the release workflow (cleaner diffs)?
   Leaning: commit it.
