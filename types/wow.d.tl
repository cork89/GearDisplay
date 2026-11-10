-- Entry point for the WoW (Forever 1.60) global environment.
-- Referenced by tlconfig.lua as `global_env_def = "types.wow"`.
-- Order matters: Teal cannot forward-reference types across files.

require("types.manual.prelude")      -- hand-written types the generated API refers to
require("types.generated.wow_api")   -- GENERATED: tl run types/gen/build.tl
require("types.manual.core")         -- CreateFrame, hooksecurefunc, legacy item API
require("types.manual.framexml")     -- Blizzard UI Lua functions, named frames
require("types.manual.luaext")       -- WoW additions to the Lua stdlib
