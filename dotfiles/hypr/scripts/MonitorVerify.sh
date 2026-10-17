#!/usr/bin/env bash
# Assert live display state matches a profile; exit 1 if any check fails.
# Usage: MonitorVerify.sh <laptop-only|docked-extend|docked-external|docked-mirror>

set -uo pipefail

INT="eDP-1"
WANT="${1:?usage: MonitorVerify.sh <profile-name>}"
fails=0

fail() { printf 'FAIL: %s\n' "$*" >&2; fails=$((fails + 1)); }
pass() { printf 'ok:   %s\n' "$*"; }

MONS="$(hyprctl -j monitors all)"
# The non-`all` list omits disabled outputs, which tells blanked from disabled.
INT_MONS="$(hyprctl -j monitors)"

field() {  # field <monitor-name> <jq-field>
  # Parenthesise before defaulting: tostring(null) is "null", which defeats //.
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

# Numeric compare for floats like scale ("1.000000" vs "1").
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

# Expected geometry comes from the profile JSON (the GUI is the source of truth);
# the constants are only for MonitorAuto.sh's fallback layout.
PROFILE_DIR="$HOME/.config/nwg-displays/profiles"
INT_POS_DOCKED="0 0"
INT_POS_SOLO="0 0"
EXT_POS="1920 0"
FALLBACK_SCALE="1"

profile_json_for() {  # profile_json_for <profile-name> -> path, or empty
  local f="$PROFILE_DIR/$1.json"
  [ -f "$f" ] && printf '%s' "$f"
}

# Profiles key outputs by description (use-desc), under .name or .description
# depending on the nwg-displays version.
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
  # Derived, not hardcoded: the external has been on both DP-1 and HDMI-A-1.
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
  # A disabled eDP-1 also reads dpmsStatus=false; only list presence tells them apart.
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
