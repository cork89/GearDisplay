return {
   -- WoW globals (generated + hand-written declarations under types/)
   global_env_def = "types.wow",
   -- WoW runs Lua 5.1 and has no `require`, so no compat53 shims.
   gen_target = "5.1",
   gen_compat = "off",
}
