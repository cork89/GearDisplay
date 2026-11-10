#!/usr/bin/env sh
# Regenerates types/generated/wow_api.d.tl.
#
#   types/gen/build.sh                      # fetch pinned sources into types/.cache, then generate
#   types/gen/build.sh <wow-ui-source> <vscode-wow-api>   # use local checkouts instead
#
# Requires `tl` (0.24+) and git on PATH.
set -eu
cd "$(dirname "$0")"

# Pinned sources. Bump these to update the types.
UI_SOURCE_REPO=https://github.com/Gethe/wow-ui-source
UI_SOURCE_REF=4cd0ab752a77164f654ccbca9d0c1fe8dafceebe  # branch `forever`, 1.60.1 (70888)
KETHO_REPO=https://github.com/Ketho/vscode-wow-api
KETHO_REF=d0b5b51fac4c52c493371b9b18e66ce604ea4326

fetch() { # repo ref dir
  if [ ! -d "$3/.git" ]; then
    git init -q "$3"
    git -C "$3" remote add origin "$1"
  fi
  if ! git -C "$3" cat-file -e "$2^{commit}" 2>/dev/null; then
    git -C "$3" fetch -q --depth 1 origin "$2" || git -C "$3" fetch -q origin
  fi
  git -C "$3" -c advice.detachedHead=false checkout -q "$2"
}

if [ $# -ge 2 ]; then
  UI_SOURCE=$1
  KETHO=$2
else
  mkdir -p ../.cache
  UI_SOURCE=../.cache/wow-ui-source
  KETHO=../.cache/vscode-wow-api
  fetch "$UI_SOURCE_REPO" "$UI_SOURCE_REF" "$UI_SOURCE"
  fetch "$KETHO_REPO" "$KETHO_REF" "$KETHO"
fi

# `tl run` exits silently on runtime errors, so compile and run through a traceback wrapper.
tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT
tl gen build.tl -o "$tmp/build.lua" >/dev/null
cat > "$tmp/run.lua" <<'LUA'
local script = table.remove(arg, 1)
local ok, err = xpcall(function() dofile(script) end, debug.traceback)
if not ok then io.stderr:write(tostring(err), "\n") os.exit(1) end
LUA
tl run "$tmp/run.lua" "$tmp/build.lua" "$UI_SOURCE" "$KETHO" ..

# Sanity check: the full environment must type-check.
cd ../..
tl check types/wow.d.tl >/dev/null || { tl check types/wow.d.tl; exit 1; }
echo "ok: types/wow.d.tl type-checks"
