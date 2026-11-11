#!/usr/bin/env sh
# Compiles the addon's Teal sources to dist/*.lua, which the TOC loads.
set -eu
cd "$(dirname "$0")"
FILES="Locales Config GearDisplay"
mkdir -p dist
for f in $FILES; do set -- "$@" "$f.tl"; done
tl check "$@"
for f in $FILES; do
  tl gen "$f.tl" -o "dist/$f.lua"
done
