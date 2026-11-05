#!/usr/bin/env bash
# Headless check: import the project, then run the bot playtest (tools/SmokeTest.tscn).
# Fails when Godot exits non-zero, the playtest never prints its DONE line, or either log has an ERROR.
# Usage: bash tools/check.sh [smoke args...]   (default: --waves=5 --speed=4 --spawn-all --lob-free --economy)
# Set GODOT to the Godot 4 binary when it isn't on PATH as godot, godot4 or Godot_v4*.
set -u
cd "$(dirname "$0")/.."

find_godot() {
	if [ -n "${GODOT:-}" ]; then echo "$GODOT"; return; fi
	command -v godot 2>/dev/null && return
	command -v godot4 2>/dev/null && return
	local IFS=: dir exe
	for dir in $PATH; do
		for exe in "$dir"/Godot_v4*_console.exe "$dir"/Godot_v4*; do
			[ -x "$exe" ] && { echo "$exe"; return; }
		done
	done
}

GODOT_BIN=$(find_godot)
if [ -z "$GODOT_BIN" ]; then
	echo "check: Godot 4 not found. Install it or set GODOT=/path/to/godot." >&2
	exit 2
fi
[ $# -eq 0 ] && set -- --waves=5 --speed=4 --spawn-all --lob-free --economy
log=$(mktemp)
trap 'rm -f "$log"' EXIT
ERR='^(SCRIPT )?ERROR:'

echo "check: Godot $("$GODOT_BIN" --version)"
"$GODOT_BIN" --headless --path . --editor --quit >"$log" 2>&1
status=$?
if [ $status -ne 0 ] || grep -q -E "$ERR" "$log"; then
	grep -A4 -E "$ERR" "$log"
	echo "check: FAIL import (exit=$status)"
	exit 1
fi

"$GODOT_BIN" --headless --path . res://tools/SmokeTest.tscn -- "$@" >"$log" 2>&1
status=$?
grep '^\[smoke\]' "$log"
errors=$(grep -c -E "$ERR" "$log")
if [ $status -ne 0 ] || [ "$errors" -gt 0 ] || ! grep -q '^\[smoke\] DONE' "$log"; then
	grep -A4 -E "$ERR" "$log"
	echo "check: FAIL smoke (exit=$status, errors=$errors)"
	exit 1
fi
echo "check: PASS"
