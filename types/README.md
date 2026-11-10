# WoW API types for Teal

Teal declarations for the **WoW Forever (1.60, Interface 16001)** addon API. Nothing here ships:
`.pkgmeta` ignores `types/`, `tlconfig.lua` and `*.tl`.

```
tlconfig.lua                 global_env_def = "types.wow", gen_target 5.1, gen_compat off
types/
  wow.d.tl                   entry point; requires the files below in order
  manual/prelude.d.tl        hand-written types the generated file refers to (ItemLocation, ColorMixin, ...)
  generated/wow_api.d.tl     GENERATED. Do not edit
  generated/REPORT.md        what the generator couldn't resolve (worth reading)
  manual/core.d.tl           CreateFrame overloads, hooksecurefunc, legacy item API
  manual/framexml.d.tl       Blizzard UI Lua (ShowUIPanel, Settings, Backdrop, named frames)
  manual/luaext.d.tl         WoW additions to the Lua stdlib (strsplit, wipe, tinsert, bit, unpack, ...)
  manual/globalstrings.d.tl  Blizzard GlobalStrings we use (INVTYPE_*); add more as needed
  gen/build.tl, build.sh     generator + pinned sources
  tests/                     smoke.tl (must pass), expect_errors.tl (must fail exactly where marked)
  check.sh                   type-checks everything above
  vendor/ketho/LICENSE       MIT license for the converted Ketho annotations
```

## Commands (from the addon root; needs `tl` 0.24+ and git)

```sh
sh types/gen/build.sh   # regenerate (fetches pinned sources into types/.cache)
sh types/gen/build.sh <wow-ui-source> <vscode-wow-api>   # or use local checkouts
sh types/check.sh       # declarations + smoke tests
tl check GearDisplay.lua   # lax-check plain Lua against the WoW globals
```

To update to a new client build, bump `UI_SOURCE_REF` (Gethe/wow-ui-source, `forever` branch) or
`KETHO_REF` in `types/gen/build.sh`, regenerate, run `check.sh`, and read the diff of `REPORT.md`.

## Where the types come from

| What | Source |
|---|---|
| `C_*` namespaces, documented globals, `Enum`, `Constants`, structures, events, widget methods | Blizzard `Blizzard_APIDocumentationGenerated` (`forever` branch) |
| Widget class hierarchy | Ketho's `Widget/*.lua` `---@class` lines (hard-coded in `build.tl`) |
| Widget methods Blizzard omits (e.g. `GameTooltip:AddLine`) | Ketho `Widget/**` |
| Pseudo-type aliases, string enums (`FramePoint`, `FrameStrata`, ...) | Ketho `Type/*.lua`, `Widget/UIType/*.lua` |
| Legacy globals (`GetItemInfo`-era API) | Ketho `Data/Wiki.lua` (mainline: may include functions Forever lacks) |
| Script handler signatures, `CreateFrame` overloads, FrameXML | hand-written |

## Teal gotchas that shaped the layout

- **Types and global values share one namespace.** `GameTooltip` is both a widget class and a frame,
  so it is a `record` (records are both). Records can't be extended, so its methods live in
  `interface GameTooltipAPI`; extend that for tooltips with extra fields (`local interface MyTip is GameTooltipAPI`). For the same reason a Blizzard enum alias whose name is
  also a function (`UnitSex`) is not emitted.
- **`global type A = B` cannot refer to a type declared later**, not even with a forward declaration.
  Record and interface *fields* can. So aliases are inlined where they are used and emitted at the end.
  Across files nothing can be forward-referenced, which is why `prelude.d.tl` loads first and may only
  use primitives.
- **No literal types.** `CreateFrame("Button")` → `Button` works through one-member enums and
  `__call` overloads. Script handlers use one enum per handler signature (`ScriptTypeClick`, ...).
  `pcall(CreateFrame, "Button", ...)` loses this and picks the first overload.
- **`x: T | nil` doesn't narrow** in 0.24 (`if x then x:len() end` still errors). All Teal types are
  already nilable, so nilable returns are plain `T`, with `[nilable: name]` in the doc comment.
- **`...` in the main chunk is typed `string...`.** Use `local name, ns = ... as (string, MyNamespace)`.
- **`integer` only adds friction** on Lua 5.1. `luaIndex` and enum-typed arguments are `number`.
  `Enum.X.Y` constants are `integer`, which is assignable to `number`.
- `tl run` exits silently on uncaught runtime errors, so `build.sh` runs the generator through a traceback wrapper.

## Template-specific frames

Teal can't derive a type from a template string. Cast:
`CreateFrame("Frame", nil, parent, "BackdropTemplate") as BackdropFrame`. For an addon's own frames
with extra fields (`f.title`, `cb.Text`), declare a local interface `is Frame` and cast to it.
