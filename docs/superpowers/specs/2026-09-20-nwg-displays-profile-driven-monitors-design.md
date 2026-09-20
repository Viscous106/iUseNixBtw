# Profile-Driven Monitor Management via nwg-displays

**Date:** 2026-09-20
**Status:** Approved, pending implementation

## Problem

Monitor layout on this machine is owned entirely by `home/hypr/scripts/monitor-auto.sh`,
which hardcodes its geometry. There is no way to choose a layout interactively: no mirror
/ duplicate mode, no way to pick which side the external sits on, no manual override of
the docked/undocked decision.

nwg-displays is installed and bound to `SUPER+ALT+M`, but every Apply is a silent no-op.
Three independent breaks cause this:

1. `~/.config/hypr/monitors.conf` is symlinked into place by `home/modules/hyprland.nix:83`
   but is never sourced. The Lua entry point `hyprland.lua` only does `require("lua.monitors")`.
2. nwg-displays 0.4.3 writes its Lua output to `~/.config/hypr/monitors.lua`, which is a
   different file from `~/.config/hypr/lua/monitors.lua`. Nothing requires it, and it is not
   symlinked into `/persist`, so it would not survive a rebuild.
3. `hyprctl reload` (issued at the end of every Apply) re-runs `lua/monitors.lua`, which
   re-pins `eDP-1` to `-1920x0` and can re-trigger `monitor-auto.sh`, reverting the change.

This is a known upstream problem, not a local mistake:

- [CachyOS/cachyos-hypr-noctalia#39](https://github.com/CachyOS/cachyos-hypr-noctalia/issues/39) —
  same class of Lua skeleton missing `require("monitors")`. Closed as not planned.
- [nwg-piotr/nwg-displays#143](https://github.com/nwg-piotr/nwg-displays/issues/143) —
  "Apply reports success even when the saved config is never loaded." Open.

## Goal

Make the nwg-displays GUI the source of truth for monitor layout, while keeping the
automatic docking behaviour that already works. Open `SUPER+ALT+M`, arrange anything,
and have it both take effect immediately and persist across hotplug, lid events, and
rebuilds.

## Key constraints

### The DP-link landmine

`monitor-auto.sh` documents that `hl.monitor({ disabled = true })` on `eDP-1` releases its
CRTC, and the resulting reshuffle drops the external's DP link entirely — the Dell goes to
`disconnected` at the kernel level and only returns on a physical replug. The script
therefore blanks with DPMS instead of disabling.

nwg-displays emits `disabled = true` whenever an output is unticked under `Active:`, which
would reintroduce exactly this bug. The apply path, however, treats `active` and `dpms` as
independent:

```python
if not d["active"]:
    lines_conf.append(f"monitor={name},disable")   # unsafe
    lua_props.append("    disabled = true")
else:
    ...
    cmd = "on" if d["dpms"] else "off"
    hyprctl(f"dispatch dpms {cmd} {d['name']}")    # safe: CRTC retained
```

**Rule: every profile keeps every output `Active`. Never untick `Active`.**

**AMENDED 2026-09-20 - profile DPMS does not work on this build.** The `Active` +
`DPMS`-off mechanism this spec was originally built around is inert here, verified
against the live compositor:

```
$ hyprctl dispatch dpms on eDP-1
error: [string "return hl.dispatch(dpms on eDP-1)"]:1: ')' expected near 'on'   exit=7
```

nwg-displays applies DPMS only through that plain-dispatch form
(`settings_applier.py:77,111-113`) and never reads the IPC reply
(`tools.py:92-104`), so on a Lua-parser build it fails silently and still reports
success. Its Lua output carries no DPMS field at all, so nothing survives into
`monitors.lua` either.

Consequently the ownership split narrows: **profiles own geometry only** - position,
mode, scale, mirror, transform. `monitor-auto.sh` retains ownership of DPMS through
its existing `dpms_set`, which uses the `hyprctl eval` + `hl.dsp.dpms` table form and
already encodes the toggle-not-set semantics. The `docked-external` profile is still
authored with `DPMS` unticked for documentation value, but the blanking that actually
happens is the script's.

### Reload reentrancy

`nwg-displays-apply` ends in `hyprctl reload`, which re-parses `hyprland.lua`. If
`hl.on("hyprland.start")` re-fires on reload, the selector re-invokes apply and oscillates.

### Environment

- Hyprland 0.56.2 (pinned in `flake.nix:31`), native Lua config parser.
- `hyprctl keyword` and plain `hyprctl dispatch <name> <args>` are rejected under this
  parser; everything goes through `hyprctl eval` against the `hl.*` API.
- nwg-displays 0.4.3, config dir symlinked live-editable from `/persist/nixos-config/home/nwg-displays`.
- `use-desc: true` — profiles match on monitor description, not connector name.
- `confirm-timeout: 10` — a confirm-or-revert dialog already guards bad applies.

## Architecture

`monitor-auto.sh` stops computing geometry and becomes a profile selector:

```
(external present?, lid state) --> profile name --> nwg-displays-apply -p <name>
```

It retains only what a profile cannot express:

- reading lid state (ACPI, plus the explicit `closed`/`open` argument)
- evacuating workspaces off the internal panel before it blanks
- the `flock` reentrancy guard
- the fallback path for unrecognised displays

All spatial configuration — position, mode, scale, mirror, transform, DPMS — lives in
profile JSON authored through the GUI.

### Profiles

Stored in `~/.config/nwg-displays/profiles/<name>.json`, which is already symlinked to
`/persist/nixos-config/home/nwg-displays/profiles/`, so they persist across rebuilds with
no Nix changes.

| Profile | eDP-1 | External | Selected when |
|---|---|---|---|
| `laptop-only` | active, dpms on, `0x0` | — | no external |
| `docked-extend` | active, dpms on, `-1920x0` | active, `0x0` | external + lid open |
| `docked-external` | active, `-1920x0` (blanked by the script, not the profile) | active, `0x0` | external + lid closed |
| `docked-mirror` | active, dpms on, mirrors external | active, `0x0` | manual only |

`docked-mirror` is never selected automatically; it is reachable from the picker.

**Precedence:** a manual pick is not sticky. The next hotplug or lid event re-runs the selector,
which computes the profile from state and overrides the manual choice. This is deliberate — it
keeps exactly one rule for what is on screen, and avoids a "why is it still mirrored?" state that
survives undocking. Picking `docked-mirror` and then closing the lid therefore lands on
`docked-external`, not on a mirrored blank panel.

Geometry rationale is unchanged from the current script: the external is pinned at `0x0`
and the panel sits at `-1920x0`, keeping the two regions disjoint in every intermediate
state so Hyprland never latches the "Monitor eDP-1 overlaps" warning.

### Fallback

If the profile for the current situation does not exist — an unrecognised external, or
before the profiles have been authored — the selector falls back to the existing
`mon_set` geometry. Auto-extend keeps working on unknown hardware, and profiles are a
refinement rather than a hard dependency.

### Loop prevention

The selector writes the applied profile name to `$XDG_RUNTIME_DIR/hypr-active-profile`
and returns immediately if the desired profile already matches. This breaks the
reload cycle independently of whether `hyprland.start` re-fires, and makes repeated
hotplug echoes free. The existing `flock` and `SETTLE` window remain as a second guard.

The reload-reentrancy question is resolved empirically as implementation step 1, before
any behaviour depends on the answer.

## File changes

| File | Change |
|---|---|
| `home/hypr/hyprland.lua` | add `require("monitors")` |
| `home/hypr/lua/monitors.lua` | remove the baseline `hl.monitor()` call; keep event hooks and lid binds |
| `home/hypr/monitors.lua` | new, empty — so `require` succeeds before the first Apply |
| `home/modules/hyprland.nix` | add `mkOutOfStoreSymlink` for `hypr/monitors.lua` |
| `home/hypr/scripts/monitor-auto.sh` | replace geometry logic with profile selection + fallback |
| `home/hypr/scripts/monitor-pick.sh` | new — rofi profile picker |
| `home/hypr/lua/keybinds.lua` | add `SUPER+SHIFT+M` -> `monitor-pick.sh` |

The baseline removal in `lua/monitors.lua` is required, not cosmetic: it runs at config-parse
time on every reload and would overwrite the profile's position for `eDP-1`.

Removing it does give up what the baseline was for — guaranteeing the panel has a picture during
boot, before any profile is applied. Hyprland's built-in default for an unconfigured output
(`preferred` mode, `auto` position) covers this, so the panel still lights up; what is lost is the
specific `-1920x0` placement during the window between parse and the first `monitor-auto.sh` run.
That window is the same one the current baseline already tolerates, and the selector runs on
`hyprland.start`. If it proves visible in practice, the fix is to seed `hypr/monitors.lua` with a
one-line panel entry rather than to restore the baseline in `lua/monitors.lua`.

## Verification

No test framework exists here, so verification is a scripted checklist run against
`hyprctl -j monitors` and `/sys/class/drm`:

1. Each of the four profiles applied in turn; assert position, scale, and DPMS state per output.
2. `DP-1` remains `connected` in `/sys/class/drm/card1-DP-1/status` throughout. This is the
   regression test for the landmine — a reintroduced `disabled = true` fails here.
3. Lid close/open cycle while docked: asserts `docked-external` / `docked-extend` transition
   and that workspaces were evacuated off `eDP-1` before it blanked.
4. Unplug/replug: asserts `laptop-only` / `docked-extend` transition and no oscillation
   (`hypr-active-profile` written once per transition).
5. Unknown-display fallback: assert the script still applies sane geometry with no profile present.

Rollback is `git checkout` in `/persist/nixos-config`.

## Out of scope

- Workspace-to-monitor assignment via `workspaces.conf` (nwg-displays writes it; nothing
  sources it). Current workspace handling in `evacuate_int` is preserved as-is.
- Power/AC-state-aware profiles.
- Packaging any third-party monitor daemon.

## Authoring note

Profiles cannot be written blind. `use-desc: true` means each profile JSON embeds the exact
monitor description string, so the four profiles must be created from the GUI with the
external physically attached. Implementation delivers the wiring plus per-profile
instructions; profile creation is a manual step by the user.
