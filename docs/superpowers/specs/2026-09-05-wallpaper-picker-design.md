# Wallpaper picker — design

**Date:** 2026-09-05
**Status:** approved, ready for implementation planning
**Replaces:** `qs-wallpaper-picker` (third-party, `pkgs/qs-wallpaper-picker.nix`)

## Goal

A standalone Quickshell wallpaper selector on `SUPER+W`, styled after
[skwd-wall](https://github.com/liixini/skwd-wall)'s skewed carousel, themed from
caelestia's live colour scheme.

skwd-wall itself was rejected: v2 is a Rust rewrite (explicitly moved *off*
Quickshell), and its Nix flake points at a `github:liixini/skwd-wall/nix` ref
that does not exist — the README states NixOS support is WIP. Its v1 branch is
Quickshell but superseded. So: take the design, build it here.

## Decisions

| Question | Decision |
|---|---|
| Selector shape | **Skewed carousel** — sheared, overlapping cards, centred selection enlarged |
| Folder handling | **Browse into folders** — folders shown as cards, `Enter` descends, `Backspace` up |
| On apply | **Wallpaper only.** No scheme regeneration; colours stay where `SUPER+CTRL+R` put them |
| Live preview | **On pause** — 250 ms debounce, then apply for real; `Escape` restores the original |
| Theming | Read caelestia's `scheme.json`; do **not** patch caelestia |

## Architecture

Standalone Quickshell config, launched on demand. No daemon, no idle cost.

QML source lives in the repo at `home/quickshell/wallpaper-picker/` and is
symlinked live into `~/.config/quickshell/wallpaper-picker` with
`mkOutOfStoreSymlink` — matching the existing convention for `rofi`, `qt6ct` and
`hypr`, so the QML can be edited and re-run without a rebuild.

A Nix wrapper (`pkgs/wallpaper-picker.nix`) puts `wallpaper-picker` on `PATH`
with `quickshell`, `awww`, `mpvpaper`, `ffmpegthumbnailer` and `coreutils` bound
in, because Hyprland's exec environment does not reliably carry all of them.

### Why not patch it into caelestia

Considered and rejected. A caelestia drawer would open instantly and inherit its
tokens natively, but delivering a whole new QML module by `postPatch` is far
beyond the six one-line substitutions already carried in
`home/modules/caelestia-quickshell.nix`, and every caelestia update would risk
breaking it. Reading `scheme.json` gets the integration through a data file
instead of a code patch.

If cold start proves annoying, the picker can later run hidden at login and
toggle over IPC — a follow-up, not a rewrite.

## Components

| File | Responsibility |
|---|---|
| `shell.qml` | Entry point. One layer-shell overlay window, exclusive keyboard focus, dimmed backdrop |
| `Theme.qml` | Singleton. Reads `~/.local/state/caelestia/scheme.json`, exposes `background`/`surface`/`primary`/`onSurface`/`outline`. Watches the file so a scheme change re-themes it |
| `Library.qml` | Singleton. `FolderListModel` over the current directory, navigation stack, filter text, current index |
| `Carousel.qml` | The sheared card rail: card geometry, selection, neighbour falloff, animation |
| `Applier.qml` | `Process` wrappers for `awww`/`mpvpaper`, the preview debounce timer, and original-wallpaper bookkeeping |

`FolderListModel` (`Qt.labs.folderlistmodel`) is the file-listing backbone.
Verified working under Quickshell 0.3.0 — it lists the five subfolders with
`showDirsFirst` and `fileIsDir` intact. Caelestia's `FileSystemModel` is **not**
usable here: it comes from `Caelestia.Models`, a caelestia-private C++ plugin.

## Layout

- Cards sheared **−13°**; the photo is counter-sheared inside so the frame is a
  parallelogram but the image is not distorted
- Selected card centred, enlarged, accent ring (`primary`, 2px + 20% glow)
- Neighbours shrink and fade with distance (~7 cards visible)
- Search/filter field above the rail; filename, resolution and path below;
  position dots under that; key hints in a footer
- Floats over a dimmed live desktop
- Folder cards use the same sheared treatment with a folder glyph

## Interaction

| Key | Action |
|---|---|
| `Alt+H` / `Alt+L`, `←` / `→` | Move selection |
| `Enter` | Folder → descend. Image/video → apply and close |
| `Backspace` | Up one folder |
| `Escape` | Revert preview, close |
| any text | Filter current folder |

`Alt` matches the modifier now used for caelestia's launcher and session
navigation, so the whole desktop shares one convention.

## Data flow

1. Launch → read `scheme.json` → theme tokens (fallback palette if absent)
2. Record the current wallpaper for revert-on-escape
3. `FolderListModel` over `~/Pictures/wallpapers`, dirs first, filtered to image
   and video extensions
4. Selection change → restart 250 ms timer → on fire, apply for real (preview)
5. `Enter` on a file → apply, write state, close. `Escape` → restore recorded
   wallpaper, close

## Integration

**Apply.** Images: `awww img <path>` with the existing transition settings.
Video: `pkill mpvpaper` then `mpvpaper -o "no-audio --loop" <monitor> <path>`.

**Restore at login.** The picker owns its own state, written on every apply:

- `~/.local/state/wallpaper-picker/current` — absolute path of the wallpaper
- `~/.local/state/wallpaper-picker/kind` — `image` or `video`

`wallpaper-picker --restore` reads those two files and reapplies through the
same code path as a normal apply (awww for `image`, mpvpaper for `video`), so
restore and apply cannot drift apart. `startup_apps.lua` switches from
`qs-wallpaper-restore` to `wallpaper-picker --restore`.

Deliberately a fresh state location rather than reusing upstream's: this replaces
`qs-wallpaper-picker`, and sharing its state would couple the two while both are
installed during the changeover.

**Caelestia.** `background.wallpaperEnabled = false` is already set, so caelestia
does not paint a competing wallpaper. Nothing else changes.

**Thumbnails.** Images load through `Image` with `sourceSize` so Qt scales them;
only visible cards plus a buffer are loaded, which is what keeps 274 files cheap.
Video posters come from `ffmpegthumbnailer` into a cache dir.

## Error handling

| Condition | Behaviour |
|---|---|
| `scheme.json` missing or malformed | Fall back to a built-in dark palette |
| `awww-daemon` not running | Start it, then apply |
| `mpvpaper` missing | Inline error on the card; do not crash |
| Unreadable directory | Stay put, show a message |
| Video thumbnail fails | Film-strip placeholder |
| Empty directory | "No wallpapers here" with `Backspace` hint |

## Verification

No QML unit-test harness is available, so verification is behavioural and each
item gets run:

1. Launch; the five folders appear as sheared cards
2. Descend into `scene`; images appear; `Backspace` returns
3. Type to filter; the rail narrows
4. Pause on a card 250 ms; the desktop changes behind
5. `Escape`; the original wallpaper is restored
6. `Enter` on an image; `awww query` confirms it applied
7. `Enter` on a video; the `mpvpaper` process is running
8. `wallpaper-picker --restore` from a cold start reapplies the last wallpaper
9. Change scheme with `SUPER+CTRL+R`, reopen; the picker's colours followed

## Out of scope

Colour sorting/filtering, Wallhaven or Steam browsing, Wallpaper Engine scenes,
multi-monitor per-output wallpapers, matugen regeneration on apply. All are
possible later; none are needed for this to replace what exists.

## Follow-up

`pkgs/qs-wallpaper-picker.nix` and its `SUPER+W` binding stay in place until this
is proven, then are removed in a separate change.
