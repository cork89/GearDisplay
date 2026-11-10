#!/usr/bin/env sh
# Compiles the addon's Teal sources to the .lua files the TOC loads.
set -eu
cd "$(dirname "$0")"
FILES="Locales.tl Config.tl GearDisplay.tl"
tl check $FILES
tl gen $FILES          # writes Locales.lua, Config.lua, GearDisplay.lua next to the sources
