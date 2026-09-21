#!/usr/bin/env bash
# monitor-verify.sh — assert live display state matches an expected profile.
#
# Usage: monitor-verify.sh <laptop-only|docked-extend|docked-external|docked-mirror>
# Exit 0 = every assertion passed. Exit 1 = at least one failed.
#
# check_ext_link_alive is the regression test for the DP-link landmine documented
# in monitor-auto.sh: a profile that emits `disabled = true` instead of blanking
# with DPMS drops the external's DP link at the kernel level, and this catches it.

set -uo pipefail

INT="eDP-1"
WANT="${1:?usage: monitor-verify.sh <profile-name>}"
fails=0

fail() { printf 'FAIL: %s\n' "$*" >&2; fails=$((fails + 1)); }
pass() { printf 'ok:   %s\n' "$*"; }

MONS="$(hyprctl -j monitors all)"
# Non-`all` list excludes disabled outputs: presence here is what actually
# distinguishes a DPMS-blanked panel from a disabled one (I-6).
INT_MONS="$(hyprctl -j monitors)"

field() {  # field <monitor-name> <jq-field>
  # The // and | precedence matters: `.x | tostring // "MISSING"` parses as
  # `.x | (tostring // "MISSING")`, and tostring(null) is the truthy string
  # "null", so the fallback would never fire. Parenthesise before defaulting.
  printf '%s' "$MONS" | jq -r --arg m "$1" \
    "(map(select(.name == \$m)) | .[0].$2) // \"MISSING\" | tostring"
}

external_name() {
  printf '%s' "$MONS" | jq -r --arg i "$INT" \
    'map(select(.name != $i)) | .[0].name // empty'
}

assert() {  # assert <label> <actual> <expected>
  if [ "$2" = "$3" ]; then pass "$1 = $3"; else fail "$1 = $2 (expected $3)"; fi
}

# assert_num <label> <actual> <expected> [tolerance=0.01] — for floats like
# `scale`, where the compositor's formatting (e.g. "1.000000" vs a profile's
# "1") must not be compared as strings.
assert_num() {
  local label="$1" actual="$2" expected="$3" tol="${4:-0.01}"
  if [ -z "$actual" ] || [ -z "$expected" ] || [ "$actual" = MISSING ] || [ "$expected" = null ]; then
    fail "$label = $actual (expected $expected)"
    return
  fi
  if awk -v a="$actual" -v e="$expected" -v t="$tol" \
       'BEGIN{d=a-e; if (d<0) d=-d; exit !(d<=t)}' 2>/dev/null; then
    pass "$label = $actual (~ $expected)"
  else
    fail "$label = $actual (expected $expected)"
  fi
}

# --- geometry expectations: profile JSON first, hardcoded constants only as
# fallback ----------------------------------------------------------------
# The GUI is the source of truth for geometry (Task 3). Hardcoding this
# script's own idea of position/scale — as it used to — means any GUI-authored
# layout that differs fails verification forever, $STATE is never written by
# apply_profile()'s verify-gate, and the OSD reads "(failed)" permanently. So:
# read expected x/y/scale for each output out of the profile JSON itself when
# one exists, and fall back to the spec's hardcoded constants only when it
# does not (monitor-auto.sh's fallback_layout path, whose geometry never
# varies by construction).
PROFILE_DIR="$HOME/.config/nwg-displays/profiles"
INT_POS_DOCKED="-1920 0"
INT_POS_SOLO="0 0"
EXT_POS="0 0"
FALLBACK_SCALE="1"

profile_json_for() {  # profile_json_for <profile-name> -> path, or empty
  local f="$PROFILE_DIR/$1.json"
  [ -f "$f" ] && printf '%s' "$f"
}

# expected_field <profile-json-path> <monitor-connector-name> <x|y|scale>
# nwg-displays has use-desc:true, so profiles key each output by its
# DESCRIPTION string, not its connector name (schema: {"displays":[{"name" or
# "description": <desc>, "x", "y", "scale", "active"}], "config":{...}}). Look
# the connector's live description up first, then match on either key name
# since the exact field isn't pinned across nwg-displays versions.
expected_field() {
  local pf="$1" mon="$2" key="$3" desc
  desc="$(field "$mon" description)"
  jq -r --arg d "$desc" --arg k "$key" \
    '(.displays // [])
     | map(select(.name == $d or .description == $d))
     | .[0][$k] // empty' "$pf" 2>/dev/null
}

expect_xy() {   # expect_xy <profile-json-or-empty> <mon> <fallback "x y">
  local pf="$1" mon="$2" fb="$3" x y
  if [ -n "$pf" ]; then
    x="$(expected_field "$pf" "$mon" x)"
    y="$(expected_field "$pf" "$mon" y)"
    if [ -n "$x" ] && [ -n "$y" ]; then
      printf '%s %s' "$x" "$y"
      return
    fi
  fi
  printf '%s' "$fb"
}

expect_scale() {   # expect_scale <profile-json-or-empty> <mon> <fallback>
  local pf="$1" mon="$2" fb="$3" s
  if [ -n "$pf" ]; then
    s="$(expected_field "$pf" "$mon" scale)"
    if [ -n "$s" ]; then
      printf '%s' "$s"
      return
    fi
  fi
  printf '%s' "$fb"
}

check_ext_link_alive() {
  # Do NOT hardcode a connector: this box has had the external on both DP-1 and
  # HDMI-A-1, which is why external_name() derives it. A hardcoded connector makes
  # this check pass vacuously on the other one.
  local ext="$1" path s
  if [ -z "$ext" ]; then return 0; fi
  path="$(ls -d /sys/class/drm/card*-"$ext" 2>/dev/null | head -1)"
  if [ -z "$path" ]; then
    fail "no /sys/class/drm entry for $ext"
    return
  fi
  s="$(cat "$path/status" 2>/dev/null)"
  if [ "$s" = connected ]; then
    pass "$ext kernel status connected"
  else
    fail "$ext kernel status=$s (expected connected) — the disabled= landmine may be back"
  fi
}

check_int_not_disabled() {
  # dpmsStatus == false also matches a DISABLED eDP-1 (disabled outputs drop
  # out of the non-`all` monitors list, but their dpmsStatus reads false too).
  # Presence here is the assertion that actually catches the landmine at the
  # compositor level.
  if printf '%s' "$INT_MONS" | jq -e --arg i "$INT" 'any(.[]; .name == $i)' >/dev/null 2>&1; then
    pass "$INT present in active monitor list (not disabled)"
  else
    fail "$INT missing from active monitor list — may be disabled, not just blanked"
  fi
}

check_no_disable() {
  if grep -qE 'disabled\s*=\s*true' "$HOME/.config/hypr/monitors.lua" 2>/dev/null; then
    fail "a disable directive is present in the generated monitor config (monitors.lua)"
  else
    pass "no disable directive in generated monitor config"
  fi
  # ~/.config/hypr/configs/ is dead, unreferenced legacy from the pre-Lua
  # config (Monitor_Profiles/{External,Laptop}-Only.conf and configs/
  # monitors.conf still have `,disable` in them). Nothing sources it, so this
  # is detection, not deletion — deletion is the user's call on a tree with no
  # git to recover from it if that call is wrong. Informational only: it does
  # NOT fail verification.
  if grep -rqE '(disabled\s*=\s*true|,disable\b)' "$HOME/.config/hypr/configs/" 2>/dev/null; then
    printf 'note: a disable directive exists in a dead legacy conf under ~/.config/hypr/configs/ (not sourced, informational only)\n'
  fi
}

EXT="$(external_name)"
PF="$(profile_json_for "$WANT")"

case "$WANT" in
  laptop-only)
    [ -z "$EXT" ] || fail "expected no external, found $EXT"
    assert "eDP-1 position" "$(field "$INT" x) $(field "$INT" y)" "$(expect_xy "$PF" "$INT" "$INT_POS_SOLO")"
    assert_num "eDP-1 scale" "$(field "$INT" scale)" "$(expect_scale "$PF" "$INT" "$FALLBACK_SCALE")"
    assert "eDP-1 dpms"     "$(field "$INT" dpmsStatus)" "true"
    check_int_not_disabled
    ;;
  docked-extend)
    [ -n "$EXT" ] || fail "expected an external, found none"
    check_ext_link_alive "$EXT"
    assert "eDP-1 position" "$(field "$INT" x) $(field "$INT" y)" "$(expect_xy "$PF" "$INT" "$INT_POS_DOCKED")"
    assert "$EXT position"  "$(field "$EXT" x) $(field "$EXT" y)" "$(expect_xy "$PF" "$EXT" "$EXT_POS")"
    assert_num "eDP-1 scale" "$(field "$INT" scale)" "$(expect_scale "$PF" "$INT" "$FALLBACK_SCALE")"
    assert_num "$EXT scale"  "$(field "$EXT" scale)" "$(expect_scale "$PF" "$EXT" "$FALLBACK_SCALE")"
    assert "eDP-1 dpms"     "$(field "$INT" dpmsStatus)" "true"
    assert "$EXT dpms"      "$(field "$EXT" dpmsStatus)" "true"
    check_int_not_disabled
    ;;
  docked-external)
    [ -n "$EXT" ] || fail "expected an external, found none"
    check_ext_link_alive "$EXT"
    assert "eDP-1 dpms"    "$(field "$INT" dpmsStatus)" "false"
    assert "$EXT dpms"     "$(field "$EXT" dpmsStatus)" "true"
    assert "$EXT position" "$(field "$EXT" x) $(field "$EXT" y)" "$(expect_xy "$PF" "$EXT" "$EXT_POS")"
    assert_num "$EXT scale" "$(field "$EXT" scale)" "$(expect_scale "$PF" "$EXT" "$FALLBACK_SCALE")"
    check_int_not_disabled
    # every non-empty workspace must have been moved off the panel
    if printf '%s' "$(hyprctl -j workspaces)" \
       | jq -e --arg i "$INT" 'any(.[]; .monitor == $i and .windows > 0)' >/dev/null; then
      fail "windows still on $INT after evacuation"
    else
      pass "no windows left on $INT"
    fi
    ;;
  docked-mirror)
    [ -n "$EXT" ] || fail "expected an external, found none"
    check_ext_link_alive "$EXT"
    assert "eDP-1 dpms" "$(field "$INT" dpmsStatus)" "true"
    check_int_not_disabled
    grep -q 'mirror' "$HOME/.config/hypr/monitors.lua" 2>/dev/null \
      && pass "mirror directive present" \
      || fail "no mirror directive in generated monitor config"
    ;;
  *)
    fail "unknown profile '$WANT'"
    ;;
esac

check_no_disable

if [ "$fails" -eq 0 ]; then
  printf '\nPASS (%s)\n' "$WANT"; exit 0
else
  printf '\nFAILED: %d assertion(s) (%s)\n' "$fails" "$WANT" >&2; exit 1
fi
