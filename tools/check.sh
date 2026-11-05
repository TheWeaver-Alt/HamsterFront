#!/usr/bin/env bash
# Headless check: import the project, fuzz the Learning Mode questions (tools/MathQuizPreview.tscn,
# --no-shots --no-mash), then run the bot playtest (tools/SmokeTest.tscn).
# Fails when Godot exits non-zero, a question fails validation, the playtest never prints its DONE line,
# or any log has an ERROR.
# Usage: bash tools/check.sh [smoke args...]   (default: --waves=5 --speed=4 --spawn-all --lob-free --stuck --economy --cards)
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
[ $# -eq 0 ] && set -- --waves=5 --speed=4 --spawn-all --lob-free --stuck --economy --cards
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

# Learning Mode questions: every type must validate against its own picture (a few seconds, no window).
"$GODOT_BIN" --headless --path . res://tools/MathQuizPreview.tscn -- --no-shots --no-mash >"$log" 2>&1
status=$?
grep -E '^\[quiz\] (validator|fuzz)' "$log"
errors=$(grep -c -E "$ERR" "$log")
if [ $status -ne 0 ] || [ "$errors" -gt 0 ] || ! grep -q -E '^\[quiz\] fuzz: .* 0 bad' "$log"; then
	grep -A4 -E "$ERR" "$log"
	echo "check: FAIL quiz questions (exit=$status, errors=$errors)"
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
