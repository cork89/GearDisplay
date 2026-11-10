#!/usr/bin/env sh
# Type-checks the WoW declarations and their tests. Run from anywhere.
set -eu
cd "$(dirname "$0")/.."

tl check types/wow.d.tl >/dev/null || { tl check types/wow.d.tl; exit 1; }
echo "ok: types/wow.d.tl"

tl check types/tests/smoke.tl >/dev/null || { tl check types/tests/smoke.tl; exit 1; }
echo "ok: types/tests/smoke.tl"

expected=$(grep -c -- '-- ERR' types/tests/expect_errors.tl)
actual=$(tl check types/tests/expect_errors.tl 2>&1 | grep -cE '^types/tests/expect_errors\.tl:[0-9]+:[0-9]+: ' || true)
if [ "$expected" != "$actual" ]; then
  echo "FAIL: expected $expected errors in types/tests/expect_errors.tl, got $actual"
  tl check types/tests/expect_errors.tl || true
  exit 1
fi
echo "ok: types/tests/expect_errors.tl ($actual expected errors)"
