# Profile-Driven Monitor Management Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Make the nwg-displays GUI the source of truth for monitor layout, while keeping automatic docking, lid, and hotplug behaviour.

**Architecture:** `monitor-auto.sh` stops computing geometry and becomes a profile selector: it maps (external present?, lid state) to a profile name and calls `nwg-displays-apply -p <name>`. All spatial configuration lives in nwg-displays profile JSON authored through the GUI. An idempotence gate on `$XDG_RUNTIME_DIR/hypr-active-profile` prevents the `hyprctl reload` at the end of every apply from re-triggering the selector.

**Tech Stack:** Hyprland 0.56.2 (native Lua config parser), nwg-displays 0.4.3, bash, jq, rofi, home-manager (`mkOutOfStoreSymlink`).

**Spec:** `docs/superpowers/specs/2026-09-20-nwg-displays-profile-driven-monitors-design.md`

## Global Constraints

- **Never emit `disabled = true` for any output.** Blanking is expressed as `Active` ticked + `DPMS` unticked. Disabling `eDP-1` releases its CRTC and drops the external's DP link at the kernel level, requiring a physical replug.
- Hyprland 0.56.2 uses the **non-legacy Lua parser**. `hyprctl keyword` and plain `hyprctl dispatch <name> <args>` are rejected. All compositor calls go through `hyprctl eval` against the `hl.*` API.
- The external is pinned at `0x0`; the internal panel sits at `-1920x0` when docked, `0x0` when solo. Never place the panel at a positive x — the intermediate state overlaps the external and latches Hyprland's "Monitor eDP-1 overlaps with other monitor(s)" warning.
- Internal panel is `eDP-1`, mode `1920x1080@144`. External mode is always `preferred` — a hardcoded invalid mode silently falls back to 1024x768.
- nwg-displays config has `use-desc: true`. Profile JSON embeds the monitor's exact description string, so profiles are authored from the GUI with hardware attached, never hand-written.
- All edited files live under `/persist/nixos-config`. **The user runs every git command themselves** — tasks print commit commands in a copy-paste block, they never execute them.

---

### Task 1: Determine whether `hyprland.start` re-fires on `hyprctl reload`

The whole loop-prevention design hinges on this. `nwg-displays-apply` ends in `hyprctl reload`; if that re-fires `hyprland.start`, the selector re-invokes apply and oscillates. Resolve it by measurement before any behaviour depends on it.

**Files:**
- Create: `/tmp/reload-probe.log` (throwaway)
- Modify: none

- [ ] **Step 1: Add a probe to the start hook**

Temporarily append to `/persist/nixos-config/home/hypr/hyprland.lua`, at the end of the existing `hl.on("hyprland.start", ...)` block:

```lua
hl.on("hyprland.start", function()
  hl.exec_cmd("sh -c 'date +%s.%N >> /tmp/reload-probe.log'")
end)
```

- [ ] **Step 2: Reload and count**

```bash
: > /tmp/reload-probe.log
hyprctl reload
sleep 2
wc -l < /tmp/reload-probe.log
```

Expected: `0` means `hyprland.start` does NOT re-fire on reload. `1` means it does.

- [ ] **Step 3: Record the answer in the spec**

Append one line to the "Loop prevention" section of the spec stating the measured result and the date. The idempotence gate ships either way — this determines whether it is the primary defence (re-fires) or a belt-and-braces guard (does not).

- [ ] **Step 4: Remove the probe**

Delete the temporary `hl.on` block from `hyprland.lua`, then `hyprctl reload` and confirm `/tmp/reload-probe.log` stops growing. Delete the log.

- [ ] **Step 5: Commit (user runs this)**

```bash
cd /persist/nixos-config
git add docs/superpowers/specs/2026-09-20-nwg-displays-profile-driven-monitors-design.md
git commit -m "docs: record hyprland.start reload behaviour in monitor spec"
```

---

### Task 2: Verification harness

The test. No test framework exists here, so this script is what "run the tests" means for every later task. It must exist and fail before the selector is rewritten.

**Files:**
- Create: `/persist/nixos-config/home/hypr/scripts/monitor-verify.sh`

**Interfaces:**
- Produces: `monitor-verify.sh <profile-name>` — exit 0 if live state matches that profile, exit 1 otherwise, with per-assertion lines on stdout/stderr. Task 5 and Task 6 both call it.

- [ ] **Step 1: Write the harness**

```bash
#!/usr/bin/env bash
# monitor-verify.sh — assert live display state matches an expected profile.
#
# Usage: monitor-verify.sh <laptop-only|docked-extend|docked-external|docked-mirror>
# Exit 0 = every assertion passed. Exit 1 = at least one failed.
#
# check_dp_alive is the regression test for the DP-link landmine documented in
# monitor-auto.sh: a profile that emits `disabled = true` instead of blanking with
# DPMS drops the external's DP link at the kernel level, and this catches it.

set -uo pipefail

INT="eDP-1"
WANT="${1:?usage: monitor-verify.sh <profile-name>}"
fails=0

fail() { printf 'FAIL: %s\n' "$*" >&2; fails=$((fails + 1)); }
pass() { printf 'ok:   %s\n' "$*"; }

MONS="$(hyprctl -j monitors all)"

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

check_dp_alive() {
  local s
  s="$(cat /sys/class/drm/card1-DP-1/status 2>/dev/null)"
  if [ "$s" = connected ]; then
    pass "DP-1 kernel status connected"
  else
    fail "DP-1 kernel status=$s (expected connected) — the disabled= landmine may be back"
  fi
}

check_no_disable() {
  if grep -qE '(disabled\s*=\s*true|,disable\b)' "$HOME/.config/hypr/monitors.lua" \
                                                  "$HOME/.config/hypr/monitors.conf" 2>/dev/null; then
    fail "a disable directive is present in the generated monitor config"
  else
    pass "no disable directive in generated monitor config"
  fi
}

EXT="$(external_name)"

case "$WANT" in
  laptop-only)
    [ -z "$EXT" ] || fail "expected no external, found $EXT"
    assert "eDP-1 position" "$(field "$INT" x) $(field "$INT" y)" "0 0"
    assert "eDP-1 dpms"     "$(field "$INT" dpmsStatus)" "true"
    ;;
  docked-extend)
    [ -n "$EXT" ] || fail "expected an external, found none"
    check_dp_alive
    assert "eDP-1 position" "$(field "$INT" x) $(field "$INT" y)" "-1920 0"
    assert "$EXT position"  "$(field "$EXT" x) $(field "$EXT" y)" "0 0"
    assert "eDP-1 dpms"     "$(field "$INT" dpmsStatus)" "true"
    assert "$EXT dpms"      "$(field "$EXT" dpmsStatus)" "true"
    ;;
  docked-external)
    [ -n "$EXT" ] || fail "expected an external, found none"
    check_dp_alive
    assert "eDP-1 dpms"    "$(field "$INT" dpmsStatus)" "false"
    assert "$EXT dpms"     "$(field "$EXT" dpmsStatus)" "true"
    assert "$EXT position" "$(field "$EXT" x) $(field "$EXT" y)" "0 0"
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
    check_dp_alive
    assert "eDP-1 dpms" "$(field "$INT" dpmsStatus)" "true"
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
```

- [ ] **Step 2: Make it executable and run it to verify it fails**

```bash
chmod +x /persist/nixos-config/home/hypr/scripts/monitor-verify.sh
~/.config/hypr/scripts/monitor-verify.sh docked-extend
```

Expected: FAIL. With the current hardcoded script the positions may happen to match, but `check_no_disable` reads `~/.config/hypr/monitors.lua`, which does not exist yet — the profiles have not been authored, so at minimum the run is not a clean PASS. Record which assertions fail; they are the work of Tasks 3-5.

- [ ] **Step 3: Commit (user runs this)**

```bash
cd /persist/nixos-config
git add home/hypr/scripts/monitor-verify.sh
git commit -m "test: add monitor layout verification harness"
```

---

### Task 3: Wire nwg-displays output into the Lua config

Makes GUI Apply take effect and persist. Until this lands, every Apply is a silent no-op.

**Files:**
- Create: `/persist/nixos-config/home/hypr/monitors.lua` (empty placeholder)
- Modify: `/persist/nixos-config/home/hypr/hyprland.lua`
- Modify: `/persist/nixos-config/home/hypr/lua/monitors.lua` (remove baseline)
- Modify: `/persist/nixos-config/home/modules/hyprland.nix:83-86`

**Interfaces:**
- Produces: `~/.config/hypr/monitors.lua`, loaded by `require("monitors")`, written by nwg-displays on every Apply. Task 5 relies on this being live.

- [ ] **Step 1: Create the placeholder so `require` cannot fail**

```bash
cat > /persist/nixos-config/home/hypr/monitors.lua <<'EOF'
-- Generated by nwg-displays (Apply / nwg-displays-apply -p <profile>).
-- Hand edits are overwritten. Loaded via require("monitors") in hyprland.lua.
-- Empty until the first profile is applied; Hyprland then falls back to its
-- built-in default for unconfigured outputs (preferred mode, auto position).
EOF
```

- [ ] **Step 2: Add the symlink so the file persists across rebuilds**

In `/persist/nixos-config/home/modules/hyprland.nix`, immediately after the `"hypr/workspaces.conf"` entry (currently line 85-86), add:

```nix
    # monitors.lua — nwg-displays' Lua output, loaded by require("monitors").
    # Separate from lua/monitors.lua, which owns the event hooks and lid binds.
    "hypr/monitors.lua".source = config.lib.file.mkOutOfStoreSymlink
      "/persist/nixos-config/home/hypr/monitors.lua";
```

- [ ] **Step 3: Load it from the entry point**

In `/persist/nixos-config/home/hypr/hyprland.lua`, after the existing `require("lua.monitors")` line, add:

```lua
-- nwg-displays' generated layout. MUST come after lua.monitors: that module
-- registers the hotplug/lid hooks, this file carries the geometry those hooks
-- select. Resolves to ~/.config/hypr/monitors.lua via package.path.
require("monitors")
```

- [ ] **Step 4: Remove the competing baseline**

In `/persist/nixos-config/home/hypr/lua/monitors.lua`, delete the `hl.monitor({ output = "eDP-1", ... })` call and replace its comment block with:

```lua
-- No baseline hl.monitor() here. Geometry is owned by ~/.config/hypr/monitors.lua,
-- which nwg-displays regenerates on every Apply and hyprland.lua requires after
-- this module. A baseline would run at config-parse time on every reload and
-- overwrite the profile's position for eDP-1.
```

Leave the `hl.on(...)` hooks and the two `hl.bind("switch:...")` lid binds exactly as they are.

- [ ] **Step 5: Rebuild and reload**

```bash
sudo nixos-rebuild switch --flake /persist/nixos-config
hyprctl reload
ls -l ~/.config/hypr/monitors.lua
```

Expected: the symlink resolves to `/persist/nixos-config/home/hypr/monitors.lua` and `hyprctl reload` reports no parse error.

- [ ] **Step 6: Prove Apply now takes effect**

Open nwg-displays (`SUPER+ALT+M`), drag the external a visible distance, hit **Apply**, then:

```bash
grep -c 'hl.monitor' ~/.config/hypr/monitors.lua
hyprctl -j monitors all | jq -r '.[] | "\(.name) \(.x),\(.y)"'
hyprctl reload
hyprctl -j monitors all | jq -r '.[] | "\(.name) \(.x),\(.y)"'
```

Expected: the file now contains `hl.monitor` entries, the positions match what you dragged, and they are **unchanged** after `hyprctl reload`. The reload survival is the point of this task — that is what was broken.

- [ ] **Step 7: Commit (user runs this)**

```bash
cd /persist/nixos-config
git add home/hypr/monitors.lua home/hypr/hyprland.lua home/hypr/lua/monitors.lua home/modules/hyprland.nix
git commit -m "feat: load nwg-displays monitors.lua and drop competing baseline"
```

---

### Task 4: Author the four profiles

Manual, performed by the user with the external attached. Profile JSON embeds the exact monitor description string (`use-desc: true`), so it cannot be written blind.

**Files:**
- Create: `~/.config/nwg-displays/profiles/{laptop-only,docked-extend,docked-external,docked-mirror}.json` (written by the GUI, persisted via the existing `/persist` symlink)

**Interfaces:**
- Produces: four profile names consumed by `nwg-displays-apply -p` in Tasks 5 and 6.

- [ ] **Step 1: Author `docked-extend`**

With the external plugged in and the lid open, open `SUPER+ALT+M` and set:

| Output | Active | DPMS | Position | Mode | Scale | Mirror |
|---|---|---|---|---|---|---|
| `eDP-1` | ticked | ticked | `-1920`, `0` | 1920x1080@144.060 | 1.0 | None |
| external | ticked | ticked | `0`, `0` | preferred | 1.0 | None |

Click **New**, name it `docked-extend`, then **Save**, then **Apply**.

- [ ] **Step 2: Verify it**

```bash
~/.config/hypr/scripts/monitor-verify.sh docked-extend
```

Expected: PASS.

- [ ] **Step 3: Author `docked-external`**

Same as `docked-extend`, with one change: **untick `DPMS` for `eDP-1`**. Leave `Active` ticked — unticking `Active` emits `disabled = true` and drops the DP link. **New** -> `docked-external` -> **Save** -> **Apply**.

- [ ] **Step 4: Verify it**

```bash
~/.config/hypr/scripts/monitor-verify.sh docked-external
cat /sys/class/drm/card1-DP-1/status
```

Expected: PASS, and `connected`. If it reads `disconnected`, `Active` was unticked instead of `DPMS` — replug the monitor and redo Step 3.

Note: the workspace-evacuation assertion will fail here, because nothing moves workspaces yet. That is Task 5's job. Every other assertion must pass.

- [ ] **Step 5: Author `docked-mirror`**

Both outputs `Active` and `DPMS` ticked, external at `0`,`0`, and set `eDP-1`'s **Mirror** dropdown to the external. **New** -> `docked-mirror` -> **Save** -> **Apply**.

```bash
~/.config/hypr/scripts/monitor-verify.sh docked-mirror
```

Expected: PASS.

- [ ] **Step 6: Author `laptop-only`**

Unplug the external. `eDP-1` Active, DPMS ticked, position `0`,`0`, mode 1920x1080@144.060, scale 1.0, Mirror None. **New** -> `laptop-only` -> **Save** -> **Apply**.

```bash
~/.config/hypr/scripts/monitor-verify.sh laptop-only
```

Expected: PASS.

- [ ] **Step 7: Confirm all four persisted**

```bash
ls -1 /persist/nixos-config/home/nwg-displays/profiles/
```

Expected: exactly `docked-extend.json`, `docked-external.json`, `docked-mirror.json`, `laptop-only.json`.

- [ ] **Step 8: Commit (user runs this)**

```bash
cd /persist/nixos-config
git add home/nwg-displays/profiles
git commit -m "feat: add four nwg-displays monitor profiles"
```

---

### Task 5: Rewrite `monitor-auto.sh` as a profile selector

**Files:**
- Modify: `/persist/nixos-config/home/hypr/scripts/monitor-auto.sh`

**Interfaces:**
- Consumes: the four profile names from Task 4; `monitor-verify.sh` from Task 2.
- Produces: `$XDG_RUNTIME_DIR/hypr-active-profile` holding the currently applied profile name. Task 6's picker clears it to force a re-apply.

- [ ] **Step 1: Replace the decision block**

Keep everything from the top of the file through `external_name()` unchanged — the lock, `hy()`, `int_transform()`, `mon_set()`, `focus_mon()`, `ws_to_mon()`, `dpms_set()`, `lid_closed()` and `external_name()` are all still used by the fallback path. Replace `evacuate_int()` and everything from `EXT="$(external_name)"` to the end of the file with:

```bash
# --- profile selection -----------------------------------------------------
# Geometry now lives in nwg-displays profiles, authored through the GUI and
# applied with `nwg-displays-apply -p`. This script only decides WHICH profile
# the current state calls for. If the profile is missing (unrecognised external,
# or profiles not yet authored) it falls back to the hardcoded geometry below,
# so auto-extend still works on unknown hardware.
PROFILE_DIR="$HOME/.config/nwg-displays/profiles"
STATE="${XDG_RUNTIME_DIR:-/tmp}/hypr-active-profile"

have_profile() { [ -f "$PROFILE_DIR/$1.json" ]; }

# Idempotence gate. `nwg-displays-apply` ends in `hyprctl reload`, which can
# re-enter this script; re-applying the same profile would oscillate. Comparing
# against the last applied name breaks the cycle regardless of whether
# hyprland.start re-fires on reload (see Task 1 in the plan).
apply_profile() {
  local name="$1"
  if [ "$(cat "$STATE" 2>/dev/null)" = "$name" ]; then
    return 0
  fi
  nwg-displays-apply -p "$name" >/dev/null 2>&1 || return 1
  printf '%s' "$name" > "$STATE"
}

# Move every workspace off the internal panel. Split out of the old
# evacuate_int(): the profile now owns the dpms flip, so doing it here too would
# double-toggle (hl.dsp.dpms ignores `mode` and simply toggles).
move_ws_off_int() {
  local ext="$1" ws
  for ws in $(hyprctl -j workspaces | jq -r --arg i "$INT" \
                '.[] | select(.monitor == $i and .id > 0) | .id'); do
    ws_to_mon "$ws" "$ext"
  done
  focus_mon "$ext"
}

# Fallback: the pre-profile hardcoded path, kept verbatim in behaviour.
fallback_layout() {
  local ext="$1" closed="$2"
  if [ -n "$ext" ]; then
    mon_set "$INT" "$INT_MODE" "$INT_POS_DOCKED"
    mon_set "$ext" "$EXT_MODE" "$EXT_POS"
    if [ "$closed" = yes ]; then
      move_ws_off_int "$ext"; dpms_set off "$INT"
    else
      dpms_set on "$INT"
    fi
  else
    dpms_set on "$INT"
    mon_set "$INT" "$INT_MODE" "$INT_POS_SOLO"
  fi
}

notify_mode() {   # mode-label
  notify-send -e -u low -t 1500 -h string:x-canonical-private-synchronous:monitor-auto \
    "󰍹 Display" "$1" 2>/dev/null || true
}

EXT="$(external_name)"
if lid_closed "$1"; then CLOSED=yes; else CLOSED=no; fi

if [ -n "$EXT" ]; then
  if [ "$CLOSED" = yes ]; then want=docked-external; label="External only"
  else                          want=docked-extend;  label="Extended"; fi
else
  # no external + lid closed: nowhere to move the session to, leave it alone.
  [ "$CLOSED" = yes ] && exit 0
  want=laptop-only; label="Laptop only"
fi

if have_profile "$want"; then
  # Workspaces must leave the panel before the profile blanks it.
  [ "$want" = docked-external ] && move_ws_off_int "$EXT"
  if apply_profile "$want"; then
    notify_mode "$label"
    sleep "$SETTLE"
  fi
else
  fallback_layout "$EXT" "$CLOSED"
  rm -f "$STATE"          # fallback geometry is not a profile
  notify_mode "$label (fallback)"
  sleep "$SETTLE"
fi
```

- [ ] **Step 2: Run the harness for the docked, lid-open case**

```bash
rm -f "${XDG_RUNTIME_DIR:-/tmp}/hypr-active-profile"
~/.config/hypr/scripts/monitor-auto.sh open
~/.config/hypr/scripts/monitor-verify.sh docked-extend
cat "${XDG_RUNTIME_DIR:-/tmp}/hypr-active-profile"
```

Expected: PASS, and the state file reads `docked-extend`.

- [ ] **Step 3: Run the harness for the docked, lid-closed case**

```bash
~/.config/hypr/scripts/monitor-auto.sh closed
~/.config/hypr/scripts/monitor-verify.sh docked-external
```

Expected: PASS — including the workspace-evacuation assertion that failed in Task 4 Step 4, which `move_ws_off_int` now satisfies.

- [ ] **Step 4: Prove the idempotence gate stops oscillation**

```bash
for i in 1 2 3; do ~/.config/hypr/scripts/monitor-auto.sh closed; done
~/.config/hypr/scripts/monitor-verify.sh docked-external
```

Expected: PASS, no flicker, and repeat runs return immediately because the state file already matches.

- [ ] **Step 5: Prove the fallback path**

```bash
mv "$HOME/.config/nwg-displays/profiles/docked-extend.json" /tmp/
~/.config/hypr/scripts/monitor-auto.sh open
hyprctl -j monitors all | jq -r '.[] | "\(.name) \(.x),\(.y)"'
mv /tmp/docked-extend.json "$HOME/.config/nwg-displays/profiles/"
```

Expected: the OSD reads "Extended (fallback)", positions are still `-1920,0` and `0,0`, and the state file is gone.

- [ ] **Step 6: Physical hotplug and lid test**

Unplug the external, wait, replug it, then close and reopen the lid. After each:

```bash
~/.config/hypr/scripts/monitor-verify.sh <expected-profile>
cat /sys/class/drm/card1-DP-1/status
```

Expected: the right profile each time, `connected` throughout, and no oscillation.

- [ ] **Step 7: Commit (user runs this)**

```bash
cd /persist/nixos-config
git add home/hypr/scripts/monitor-auto.sh
git commit -m "feat: drive monitor layout from nwg-displays profiles"
```

---

### Task 6: rofi profile picker

Manual override without opening the full GUI. rofi is already the config's launcher (55 references).

**Files:**
- Create: `/persist/nixos-config/home/hypr/scripts/monitor-pick.sh`
- Modify: `/persist/nixos-config/home/hypr/lua/keybinds.lua:122`

**Interfaces:**
- Consumes: the profile names from Task 4 and `$XDG_RUNTIME_DIR/hypr-active-profile` from Task 5.

- [ ] **Step 1: Write the picker**

```bash
#!/usr/bin/env bash
# monitor-pick.sh — pick an nwg-displays profile from rofi and apply it.
#
# Bound to SUPER+SHIFT+M. SUPER+ALT+M still opens the full nwg-displays GUI for
# editing; this is the two-keystroke path for switching between saved layouts.
#
# The pick is deliberately NOT sticky: the next hotplug or lid event re-runs
# monitor-auto.sh, which recomputes from state and overrides this choice.

set -uo pipefail

PROFILE_DIR="$HOME/.config/nwg-displays/profiles"
STATE="${XDG_RUNTIME_DIR:-/tmp}/hypr-active-profile"

mapfile -t profiles < <(find "$PROFILE_DIR" -maxdepth 1 -name '*.json' -printf '%f\n' \
                        2>/dev/null | sed 's/\.json$//' | sort)

if [ "${#profiles[@]}" -eq 0 ]; then
  notify-send -e -u critical "󰍹 Display" "No profiles in $PROFILE_DIR" 2>/dev/null
  exit 1
fi

choice="$(printf '%s\n' "${profiles[@]}" | rofi -dmenu -i -p "Display layout")"
[ -n "$choice" ] || exit 0

# Clear the gate so monitor-auto.sh's idempotence check cannot swallow a
# deliberate re-pick of the profile that is already active.
rm -f "$STATE"

if nwg-displays-apply -p "$choice" >/dev/null 2>&1; then
  printf '%s' "$choice" > "$STATE"
  notify-send -e -u low -t 1500 -h string:x-canonical-private-synchronous:monitor-auto \
    "󰍹 Display" "$choice" 2>/dev/null || true
else
  notify-send -e -u critical "󰍹 Display" "Failed to apply $choice" 2>/dev/null || true
  exit 1
fi
```

- [ ] **Step 2: Make it executable and run it directly**

```bash
chmod +x /persist/nixos-config/home/hypr/scripts/monitor-pick.sh
~/.config/hypr/scripts/monitor-pick.sh
```

Expected: rofi lists all four profiles; picking `docked-mirror` mirrors the displays.

- [ ] **Step 3: Verify the picked profile**

```bash
~/.config/hypr/scripts/monitor-verify.sh docked-mirror
```

Expected: PASS.

- [ ] **Step 4: Add the keybind**

In `/persist/nixos-config/home/hypr/lua/keybinds.lua`, directly after line 122 (`hl.bind(mod .. " + ALT + M", hl.dsp.exec_cmd("nwg-displays"))`), add:

```lua
-- SUPER+ALT+M edits layouts in the GUI; SUPER+SHIFT+M switches between saved
-- profiles without opening it.
hl.bind(mod .. " + SHIFT + M", hl.dsp.exec_cmd(sd .. "/monitor-pick.sh"))
```

- [ ] **Step 5: Reload and test the bind**

```bash
hyprctl reload
```

Press `SUPER+SHIFT+M`. Expected: rofi opens with the profile list. Confirm `SUPER+ALT+M` still opens the GUI.

- [ ] **Step 6: Confirm the pick is not sticky**

Pick `docked-mirror`, then close and reopen the lid:

```bash
~/.config/hypr/scripts/monitor-verify.sh docked-extend
```

Expected: PASS — the lid event recomputed and overrode the manual mirror, exactly as the spec's precedence rule says.

- [ ] **Step 7: Commit (user runs this)**

```bash
cd /persist/nixos-config
git add home/hypr/scripts/monitor-pick.sh home/hypr/lua/keybinds.lua
git commit -m "feat: add rofi monitor profile picker on SUPER+SHIFT+M"
```

---

## Done when

All four profiles apply cleanly from both the GUI and the picker; hotplug and lid events select the right profile automatically; `monitor-verify.sh` passes for each of the four; and `/sys/class/drm/card1-DP-1/status` reads `connected` through every transition.
