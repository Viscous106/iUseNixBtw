# Wallpaper Picker Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** A standalone Quickshell wallpaper selector on `SUPER+W` — a skewed, overlapping card carousel that browses folders, previews on pause, and applies via awww/mpvpaper.

**Architecture:** QML lives in the repo and is symlinked live into `~/.config/quickshell/wallpaper-picker` (editable without a rebuild). A Nix wrapper puts `wallpaper-picker` on PATH with its dependencies bound in. All wallpaper application — from the UI and from `--restore` at login — goes through one shell script, so the two cannot drift apart. Theming reads caelestia's `scheme.json`; caelestia itself is never patched.

**Tech Stack:** Quickshell 0.3.0 (Qt6/QML), `Qt.labs.folderlistmodel`, bash, Nix (flakes, home-manager), awww, mpvpaper, ffmpegthumbnailer.

**Spec:** `docs/superpowers/specs/2026-09-05-wallpaper-picker-design.md`

## Global Constraints

- Wallpaper library root: `~/Pictures/wallpapers` (lowercase `w` — the filesystem is case-sensitive)
- State: `~/.local/state/wallpaper-picker/current` (absolute path) and `.../kind` (`image` or `video`)
- Caelestia scheme source: `~/.local/state/caelestia/scheme.json`; keys used are `colours.background`, `colours.surface`, `colours.surfaceContainer`, `colours.onSurface`, `colours.outline`, `colours.primary` — all **without** a leading `#`
- Card skew: `-13` degrees; photo counter-skewed `+13` inside
- Preview debounce: `250` ms
- Movement keys: `Alt+H` / `Alt+L` and `Left` / `Right`
- Image extensions: `*.jpg *.jpeg *.png *.webp *.gif`; video: `*.mp4 *.mkv *.webm`
- Do **not** run git write commands. Print them for the user instead.
- `FileSystemModel` is unavailable — it belongs to `Caelestia.Models`. Use `Qt.labs.folderlistmodel`.
- No `pragma Singleton`. Components are instantiated in `shell.qml` and passed by reference, so tests can instantiate them directly.
- **Divergence from the spec's component list:** the spec names a `Carousel.qml`. This plan instead has `Card.qml` (one card — the reusable unit worth isolating) and keeps the rail itself, which is a single `Row` inside a `Repeater`, in `shell.qml`. A file holding only that `Row` would have no independent responsibility.

## Testing approach

There is no QML unit-test runner here. Tests are QML harnesses run headlessly:

```bash
quickshell -p tests/<name>_test.qml   # prints ALL PASS / FAILURES=n, exits 0 or 1
```

Shell code is tested with plain bash assertions. Both give a real red/green cycle.

---

### Task 1: `apply.sh` — the single apply path

**Files:**
- Create: `home/quickshell/wallpaper-picker/apply.sh`
- Test: `home/quickshell/wallpaper-picker/tests/apply_test.sh`

**Interfaces:**
- Consumes: nothing
- Produces: `apply.sh <absolute-path>` applies a wallpaper and records state. `apply.sh --restore` re-applies the recorded one. `apply.sh --current` prints the recorded path or nothing. Exit 0 on success, 1 on bad arguments or a missing file.

- [ ] **Step 1: Write the failing test**

Create `home/quickshell/wallpaper-picker/tests/apply_test.sh`:

```bash
#!/usr/bin/env bash
# Tests apply.sh without touching the real desktop: AWWW_BIN/MPVPAPER_BIN are
# overridden with stubs that just log their arguments.
set -uo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SUT="$HERE/../apply.sh"
fails=0

work="$(mktemp -d)"; trap 'rm -rf "$work"' EXIT
export WP_STATE_DIR="$work/state"
export AWWW_BIN="$work/awww-stub"
export MPVPAPER_BIN="$work/mpvpaper-stub"
printf '#!/usr/bin/env bash\necho "awww $*" >> "%s/calls"\n' "$work" > "$AWWW_BIN"
printf '#!/usr/bin/env bash\necho "mpvpaper $*" >> "%s/calls"\n' "$work" > "$MPVPAPER_BIN"
chmod +x "$AWWW_BIN" "$MPVPAPER_BIN"

img="$work/pic.png"; : > "$img"
vid="$work/clip.mp4"; : > "$vid"

check() { # check <label> <expected> <actual>
  if [ "$2" = "$3" ]; then echo "  ok: $1"; else
    echo "  FAIL: $1"; echo "    expected: $2"; echo "    actual:   $3"; fails=$((fails+1)); fi
}

"$SUT" "$img" >/dev/null 2>&1
check "image records path"  "$img"   "$(cat "$WP_STATE_DIR/current" 2>/dev/null)"
check "image records kind"  "image"  "$(cat "$WP_STATE_DIR/kind" 2>/dev/null)"
check "image used awww"     "1"      "$(grep -c '^awww ' "$work/calls" 2>/dev/null || echo 0)"

"$SUT" "$vid" >/dev/null 2>&1
check "video records kind"  "video"  "$(cat "$WP_STATE_DIR/kind" 2>/dev/null)"
check "video used mpvpaper" "1"      "$(grep -c '^mpvpaper ' "$work/calls" 2>/dev/null || echo 0)"

check "--current prints path" "$vid" "$("$SUT" --current)"

: > "$work/calls"
"$SUT" --restore >/dev/null 2>&1
check "restore reapplied video" "1" "$(grep -c '^mpvpaper ' "$work/calls" 2>/dev/null || echo 0)"

"$SUT" "$work/missing.png" >/dev/null 2>&1
check "missing file exits 1" "1" "$?"

if [ "$fails" -eq 0 ]; then echo "ALL PASS"; exit 0; else echo "FAILURES=$fails"; exit 1; fi
```

- [ ] **Step 2: Run it to verify it fails**

```bash
chmod +x home/quickshell/wallpaper-picker/tests/apply_test.sh
bash home/quickshell/wallpaper-picker/tests/apply_test.sh
```

Expected: FAIL — `apply.sh` does not exist yet.

- [ ] **Step 3: Write the implementation**

Create `home/quickshell/wallpaper-picker/apply.sh`:

```bash
#!/usr/bin/env bash
# Single apply path for the wallpaper picker.
#
# Both the QML UI (via Applier.qml) and `wallpaper-picker --restore` call this,
# so what happens at login is byte-for-byte what happened when you picked it.
#
# Binaries are indirected through env vars so tests can stub them.
set -uo pipefail

STATE_DIR="${WP_STATE_DIR:-$HOME/.local/state/wallpaper-picker}"
AWWW="${AWWW_BIN:-awww}"
MPVPAPER="${MPVPAPER_BIN:-mpvpaper}"

TRANSITION_ARGS=(--transition-type random --transition-duration 0.6 --transition-fps 60)

die() { echo "wallpaper-picker: $*" >&2; exit 1; }

kind_of() {
  case "${1,,}" in
    *.mp4|*.mkv|*.webm) echo video ;;
    *)                  echo image ;;
  esac
}

apply_image() {
  # awww needs its daemon; starting it when absent is cheap and idempotent.
  if ! "$AWWW" query >/dev/null 2>&1; then
    "${AWWW}-daemon" >/dev/null 2>&1 &
    sleep 0.4
  fi
  pkill -f mpvpaper >/dev/null 2>&1
  "$AWWW" img "${TRANSITION_ARGS[@]}" "$1"
}

apply_video() {
  command -v "$MPVPAPER" >/dev/null 2>&1 || die "mpvpaper not found; cannot set a video wallpaper"
  pkill -f mpvpaper >/dev/null 2>&1
  local mon
  mon="$(hyprctl -j monitors 2>/dev/null | jq -r '.[0].name' 2>/dev/null)"
  [ -n "$mon" ] && [ "$mon" != "null" ] || mon="*"
  "$MPVPAPER" -o "no-audio --loop" "$mon" "$1" >/dev/null 2>&1 &
}

record() {
  mkdir -p "$STATE_DIR"
  printf '%s' "$1" > "$STATE_DIR/current"
  printf '%s' "$2" > "$STATE_DIR/kind"
}

apply_path() {
  local path="$1" kind
  [ -f "$path" ] || die "no such file: $path"
  kind="$(kind_of "$path")"
  if [ "$kind" = video ]; then apply_video "$path"; else apply_image "$path"; fi
  record "$path" "$kind"
}

case "${1-}" in
  --restore)
    path="$(cat "$STATE_DIR/current" 2>/dev/null)"
    [ -n "$path" ] || exit 0          # nothing recorded yet is not an error
    [ -f "$path" ] || exit 0          # wallpaper deleted since; stay quiet
    apply_path "$path"
    ;;
  --current)
    cat "$STATE_DIR/current" 2>/dev/null || true
    ;;
  "" | -*)
    die "usage: apply.sh <path> | --restore | --current"
    ;;
  *)
    apply_path "$1"
    ;;
esac
```

- [ ] **Step 4: Run the test to verify it passes**

```bash
chmod +x home/quickshell/wallpaper-picker/apply.sh
bash home/quickshell/wallpaper-picker/tests/apply_test.sh
```

Expected: `ALL PASS`, exit 0.

- [ ] **Step 5: Print the commit command for the user**

```bash
git -C /persist/nixos-config add home/quickshell/wallpaper-picker/apply.sh \
                                home/quickshell/wallpaper-picker/tests/apply_test.sh
git -C /persist/nixos-config commit -m "feat(wallpaper-picker): single apply path with state + restore"
```

---

### Task 2: Nix packaging and wiring

**Files:**
- Create: `pkgs/wallpaper-picker.nix`
- Create: `home/modules/wallpaper-picker.nix`
- Modify: `configuration.nix` (overlay — add beside `qs-wallpaper-picker`)
- Modify: `home/viscous.nix` (imports — add beside `./modules/icon-themes.nix`)

**Interfaces:**
- Consumes: `apply.sh` from Task 1.
- Produces: `wallpaper-picker` on PATH. With no arguments it runs `quickshell -p ~/.config/quickshell/wallpaper-picker`; with `--restore` it execs `apply.sh --restore` without starting Qt.

- [ ] **Step 1: Write the failing test**

Create `home/quickshell/wallpaper-picker/tests/package_test.sh`:

```bash
#!/usr/bin/env bash
set -uo pipefail
fails=0
check() { if [ "$2" = "$3" ]; then echo "  ok: $1"; else
  echo "  FAIL: $1 (expected '$2', got '$3')"; fails=$((fails+1)); fi }

out="$(nix build --no-link --print-out-paths \
  "path:/persist/nixos-config#nixosConfigurations.laptop.pkgs.wallpaper-picker" 2>/dev/null | head -1)"
check "package builds" "1" "$([ -n "$out" ] && echo 1 || echo 0)"
check "binary exists"  "1" "$([ -x "$out/bin/wallpaper-picker" ] && echo 1 || echo 0)"
check "quickshell on wrapped PATH" "1" \
  "$(grep -c 'quickshell' "$out/bin/wallpaper-picker" 2>/dev/null | head -1)"

if [ "$fails" -eq 0 ]; then echo "ALL PASS"; exit 0; else echo "FAILURES=$fails"; exit 1; fi
```

- [ ] **Step 2: Run it to verify it fails**

```bash
bash home/quickshell/wallpaper-picker/tests/package_test.sh
```

Expected: FAIL — the attribute does not exist.

- [ ] **Step 3: Write the package**

Create `pkgs/wallpaper-picker.nix`:

```nix
# ── wallpaper-picker ────────────────────────────────────────────────────────
# Wrapper for the Quickshell wallpaper selector whose QML lives at
# home/quickshell/wallpaper-picker/ and is symlinked live into
# ~/.config/quickshell/wallpaper-picker (see home/modules/wallpaper-picker.nix).
#
# The QML is deliberately NOT copied into the store: keeping it out-of-store
# means it can be edited and re-run without a rebuild, matching how rofi, qt6ct
# and hypr configs are handled in this repo.
#
# What the store DOES own is the dependency closure. Launched from a Hyprland
# keybind the process inherits Hyprland's PATH, which does not reliably carry
# quickshell/awww/mpvpaper/jq — hence the explicit wrapping.
{
  lib,
  writeShellApplication,
  quickshell,
  awww,
  mpvpaper,
  ffmpegthumbnailer,
  jq,
  procps,
  coreutils,
}:

writeShellApplication {
  name = "wallpaper-picker";

  runtimeInputs = [
    quickshell
    awww
    mpvpaper
    ffmpegthumbnailer
    jq
    procps        # pkill, used when swapping between image and video
    coreutils
  ];

  text = ''
    CONFIG_DIR="''${XDG_CONFIG_HOME:-$HOME/.config}/quickshell/wallpaper-picker"

    if [ "''${1-}" = "--restore" ]; then
      # Restore does not need Qt at all — go straight to the shared apply path
      # so login stays fast and cannot diverge from what the UI does.
      exec "$CONFIG_DIR/apply.sh" --restore
    fi

    if [ ! -d "$CONFIG_DIR" ]; then
      echo "wallpaper-picker: $CONFIG_DIR missing (is the home-manager module enabled?)" >&2
      exit 1
    fi

    exec quickshell -p "$CONFIG_DIR"
  '';

  meta = {
    description = "Skewed-carousel Quickshell wallpaper selector";
    mainProgram = "wallpaper-picker";
    platforms = lib.platforms.linux;
  };
}
```

- [ ] **Step 4: Write the home-manager module**

Create `home/modules/wallpaper-picker.nix`:

```nix
{ config, pkgs, ... }:

{
  # ── Wallpaper picker ────────────────────────────────────────────────────────
  # QML is symlinked out-of-store so it can be edited without a rebuild — same
  # convention as rofi/qt6ct/hypr elsewhere in this repo. Only the wrapper and
  # its dependency closure come from the store.
  xdg.configFile."quickshell/wallpaper-picker".source =
    config.lib.file.mkOutOfStoreSymlink
      "/persist/nixos-config/home/quickshell/wallpaper-picker";

  home.packages = [ pkgs.wallpaper-picker ];
}
```

- [ ] **Step 5: Wire the overlay and the import**

In `configuration.nix`, immediately after the `qs-wallpaper-picker` overlay line, add:

```nix
      # Our own Quickshell wallpaper selector; see pkgs/wallpaper-picker.nix and
      # docs/superpowers/specs/2026-09-05-wallpaper-picker-design.md
      wallpaper-picker = final.callPackage ./pkgs/wallpaper-picker.nix { };
```

In `home/viscous.nix`, immediately after `./modules/icon-themes.nix`, add:

```nix
    ./modules/wallpaper-picker.nix
```

- [ ] **Step 6: Run the test to verify it passes**

```bash
bash home/quickshell/wallpaper-picker/tests/package_test.sh
```

Expected: `ALL PASS`.

- [ ] **Step 7: Print the commit command**

```bash
git -C /persist/nixos-config add pkgs/wallpaper-picker.nix home/modules/wallpaper-picker.nix \
    configuration.nix home/viscous.nix home/quickshell/wallpaper-picker/tests/package_test.sh
git -C /persist/nixos-config commit -m "feat(wallpaper-picker): nix packaging and wiring"
```

---

### Task 3: `Theme.qml` — colours from caelestia

**Files:**
- Create: `home/quickshell/wallpaper-picker/Theme.qml`
- Test: `home/quickshell/wallpaper-picker/tests/theme_test.qml`

**Interfaces:**
- Consumes: nothing.
- Produces: a `Theme` component with read-only `color` properties `background`, `surface`, `surfaceHigh`, `onSurface`, `outline`, `primary`, and a `bool loaded` that is `false` when the fallback palette is in use. Property `schemePath : string` selects the file (tests point it elsewhere).

- [ ] **Step 1: Write the failing test**

Create `home/quickshell/wallpaper-picker/tests/theme_test.qml`:

```qml
import QtQuick
import Quickshell

ShellRoot {
    property int fails: 0
    function check(label, expected, actual) {
        if (String(expected) === String(actual)) console.log("  ok: " + label);
        else { console.log("  FAIL: " + label + " expected=" + expected + " actual=" + actual); fails++; }
    }

    Theme { id: good; schemePath: Quickshell.env("WP_TEST_SCHEME") }
    Theme { id: bad;  schemePath: "/nonexistent/scheme.json" }

    Timer {
        running: true; interval: 400
        onTriggered: {
            check("parses primary",    "#c2c1ff", String(good.primary));
            check("parses background", "#131317", String(good.background));
            check("marks loaded",      "true",    String(good.loaded));
            check("falls back",        "false",   String(bad.loaded));
            check("fallback usable",   "true",    String(bad.background !== ""));
            console.log(fails === 0 ? "ALL PASS" : "FAILURES=" + fails);
            Qt.exit(fails === 0 ? 0 : 1);
        }
    }
}
```

- [ ] **Step 2: Run it to verify it fails**

```bash
cd home/quickshell/wallpaper-picker
cat > /tmp/wp-scheme.json <<'JSON'
{"colours":{"background":"131317","surface":"131317","surfaceContainer":"201f23",
"onSurface":"e5e1e7","outline":"918f9a","primary":"c2c1ff"}}
JSON
WP_TEST_SCHEME=/tmp/wp-scheme.json quickshell -p tests/theme_test.qml
```

Expected: FAIL — `Theme` is not a known type.

- [ ] **Step 3: Write the implementation**

Create `home/quickshell/wallpaper-picker/Theme.qml`:

```qml
// Colours, read from caelestia's live scheme so the picker matches the shell.
//
// This is the whole of the "integration" with caelestia: one JSON file, no
// patching of caelestia itself. Change scheme with SUPER+CTRL+R and reopening
// the picker picks the new colours up.
import QtQuick
import Quickshell
import Quickshell.Io

Item {
    id: root

    property string schemePath: Quickshell.env("HOME") + "/.local/state/caelestia/scheme.json"

    // False while the fallback palette is in use (file missing or unparseable).
    readonly property bool loaded: _colours !== null

    property var _colours: null

    // caelestia stores colours as bare hex with no leading '#'.
    function _c(key, fallback) {
        if (_colours && _colours[key])
            return "#" + _colours[key];
        return fallback;
    }

    readonly property color background:   _c("background",       "#131317")
    readonly property color surface:      _c("surface",          "#131317")
    readonly property color surfaceHigh:  _c("surfaceContainer", "#201f23")
    readonly property color onSurface:    _c("onSurface",        "#e5e1e7")
    readonly property color outline:      _c("outline",          "#918f9a")
    readonly property color primary:      _c("primary",          "#c2c1ff")

    FileView {
        path: root.schemePath
        watchChanges: true
        onLoaded: {
            try {
                root._colours = JSON.parse(text()).colours;
            } catch (e) {
                root._colours = null;   // malformed: fall back rather than crash
            }
        }
        onLoadFailed: root._colours = null
        onFileChanged: reload()
    }
}
```

- [ ] **Step 4: Run the test to verify it passes**

```bash
cd home/quickshell/wallpaper-picker
WP_TEST_SCHEME=/tmp/wp-scheme.json quickshell -p tests/theme_test.qml
```

Expected: `ALL PASS`, exit 0.

- [ ] **Step 5: Print the commit command**

```bash
git -C /persist/nixos-config add home/quickshell/wallpaper-picker/Theme.qml \
                                home/quickshell/wallpaper-picker/tests/theme_test.qml
git -C /persist/nixos-config commit -m "feat(wallpaper-picker): theme from caelestia scheme.json"
```

---

### Task 4: `Library.qml` — folder navigation and filtering

**Files:**
- Create: `home/quickshell/wallpaper-picker/Library.qml`
- Test: `home/quickshell/wallpaper-picker/tests/library_test.qml`

**Interfaces:**
- Consumes: nothing.
- Produces: a `Library` component with:
  - `property string rootDir` — library root, defaults to `~/Pictures/wallpapers` (**not** `root`: that collides with the component's own `id: root`)
  - `property string dir` — directory currently shown
  - `property string filter` — substring filter, case-insensitive
  - `property int index` — selected row
  - `readonly property int count`
  - `function entry(i)` → `{ name, path, isDir, isVideo }` or `null`
  - `function descend()` — if the selection is a directory, enter it and reset `index` to 0
  - `function ascend()` — go up, stopping at `root`
  - `function move(delta)` — clamped selection movement
  - `readonly property string breadcrumb` — path relative to `root`

- [ ] **Step 1: Write the failing test**

Create `home/quickshell/wallpaper-picker/tests/library_test.qml`:

```qml
import QtQuick
import Quickshell

ShellRoot {
    property int fails: 0
    function check(label, expected, actual) {
        if (String(expected) === String(actual)) console.log("  ok: " + label);
        else { console.log("  FAIL: " + label + " expected=" + expected + " actual=" + actual); fails++; }
    }

    Library { id: lib; rootDir: Quickshell.env("WP_TEST_ROOT") }

    Timer {
        running: true; interval: 500; repeat: false
        onTriggered: {
            check("lists dirs first", "true", String(lib.entry(0).isDir));
            check("dir name",         "alpha", lib.entry(0).name);
            check("counts entries",   "3",    String(lib.count));   // alpha/, one.png, clip.mp4

            check("video flagged",    "true", String(lib.entry(2).isVideo));

            lib.move(1);
            check("move clamps low",  "1",    String(lib.index));
            lib.move(-5);
            check("move clamps high", "0",    String(lib.index));

            lib.descend();
            check("descended",        "true", String(lib.dir.endsWith("/alpha")));
            check("index reset",      "0",    String(lib.index));
            check("breadcrumb",       "alpha", lib.breadcrumb);

            lib.ascend();
            check("ascended",         "true", String(lib.dir === lib.rootDir));
            lib.ascend();
            check("stops at root",    "true", String(lib.dir === lib.rootDir));

            lib.filter = "ONE";
            check("filter matches ci","1",    String(lib.count));
            lib.filter = "";

            console.log(fails === 0 ? "ALL PASS" : "FAILURES=" + fails);
            Qt.exit(fails === 0 ? 0 : 1);
        }
    }
}
```

- [ ] **Step 2: Run it to verify it fails**

```bash
cd home/quickshell/wallpaper-picker
R=$(mktemp -d); mkdir -p "$R/alpha"; : > "$R/one.png"; : > "$R/clip.mp4"; : > "$R/alpha/deep.png"
WP_TEST_ROOT="$R" quickshell -p tests/library_test.qml
```

Expected: FAIL — `Library` is not a known type.

- [ ] **Step 3: Write the implementation**

Create `home/quickshell/wallpaper-picker/Library.qml`:

```qml
// Folder navigation over the wallpaper library.
//
// Qt.labs.folderlistmodel, not caelestia's FileSystemModel — the latter comes
// from Caelestia.Models, a private C++ plugin unavailable outside that shell.
import QtQuick
import Quickshell
import Qt.labs.folderlistmodel

Item {
    id: root

    property string rootDir: Quickshell.env("HOME") + "/Pictures/wallpapers"
    property string dir: rootDir
    property string filter: ""
    property int index: 0

    readonly property var imageExts: ["*.jpg", "*.jpeg", "*.png", "*.webp", "*.gif"]
    readonly property var videoExts: ["*.mp4", "*.mkv", "*.webm"]

    // Rows surviving the filter, as indices into the underlying model.
    property var _rows: []

    readonly property int count: _rows.length

    readonly property string breadcrumb: {
        if (dir === rootDir)
            return "";
        return dir.substring(rootDir.length + 1);
    }

    function _strip(u) {
        const s = String(u);
        return s.startsWith("file://") ? s.substring(7) : s;
    }

    function _rebuild() {
        const rows = [];
        for (let i = 0; i < fm.count; i++) {
            const name = fm.get(i, "fileName");
            if (filter === "" || name.toLowerCase().includes(filter.toLowerCase()))
                rows.push(i);
        }
        _rows = rows;
        if (index >= rows.length)
            index = Math.max(0, rows.length - 1);
    }

    function entry(i) {
        if (i < 0 || i >= _rows.length)
            return null;
        const r = _rows[i];
        const name = fm.get(r, "fileName");
        const isDir = fm.get(r, "fileIsDir");
        const lower = name.toLowerCase();
        return {
            name: name,
            path: _strip(fm.get(r, "filePath")),
            isDir: isDir,
            isVideo: !isDir && (lower.endsWith(".mp4") || lower.endsWith(".mkv") || lower.endsWith(".webm"))
        };
    }

    function move(delta) {
        if (count === 0)
            return;
        index = Math.max(0, Math.min(count - 1, index + delta));
    }

    function descend() {
        const e = entry(index);
        if (!e || !e.isDir)
            return false;
        dir = e.path;
        filter = "";
        index = 0;
        return true;
    }

    function ascend() {
        if (dir === rootDir)
            return false;                     // never escape the library
        const cut = dir.lastIndexOf("/");
        dir = cut > 0 ? dir.substring(0, cut) : rootDir;
        filter = "";
        index = 0;
        return true;
    }

    FolderListModel {
        id: fm
        folder: "file://" + root.dir
        showDirs: true
        showDirsFirst: true
        showDotAndDotDot: false
        sortField: FolderListModel.Name
        nameFilters: root.imageExts.concat(root.videoExts)
        onCountChanged: root._rebuild()
    }

    onFilterChanged: _rebuild()
}
```

- [ ] **Step 4: Run the test to verify it passes**

```bash
cd home/quickshell/wallpaper-picker
R=$(mktemp -d); mkdir -p "$R/alpha"; : > "$R/one.png"; : > "$R/clip.mp4"; : > "$R/alpha/deep.png"
WP_TEST_ROOT="$R" quickshell -p tests/library_test.qml
```

Expected: `ALL PASS`.

- [ ] **Step 5: Print the commit command**

```bash
git -C /persist/nixos-config add home/quickshell/wallpaper-picker/Library.qml \
                                home/quickshell/wallpaper-picker/tests/library_test.qml
git -C /persist/nixos-config commit -m "feat(wallpaper-picker): folder navigation and filtering"
```

---

### Task 5: `Applier.qml` — debounced preview and apply

**Files:**
- Create: `home/quickshell/wallpaper-picker/Applier.qml`
- Test: `home/quickshell/wallpaper-picker/tests/applier_test.qml`

**Interfaces:**
- Consumes: `apply.sh` (Task 1).
- Produces: an `Applier` component with `property string script`, `function schedulePreview(path)` (250 ms debounce, latest wins), `function applyNow(path)` (immediate, cancels a pending preview), `function captureOriginal()`, `function revert()`, and `readonly property string original`.

- [ ] **Step 1: Write the failing test**

Create `home/quickshell/wallpaper-picker/tests/applier_test.qml`:

```qml
import QtQuick
import Quickshell

ShellRoot {
    property int fails: 0
    function check(label, expected, actual) {
        if (String(expected) === String(actual)) console.log("  ok: " + label);
        else { console.log("  FAIL: " + label + " expected=" + expected + " actual=" + actual); fails++; }
    }

    // A stub that appends its argument to $WP_TEST_LOG instead of setting a wallpaper.
    Applier { id: app; script: Quickshell.env("WP_TEST_STUB") }

    // Three rapid schedules must collapse to exactly one apply, of the last path.
    Component.onCompleted: {
        app.schedulePreview("/tmp/a.png");
        app.schedulePreview("/tmp/b.png");
        app.schedulePreview("/tmp/c.png");
    }

    Timer {
        running: true; interval: 900
        onTriggered: {
            const log = readLog.text().trim().split("\n").filter(l => l !== "");
            check("debounced to one call", "1", String(log.length));
            check("kept the last path", "/tmp/c.png", log[0]);
            console.log(fails === 0 ? "ALL PASS" : "FAILURES=" + fails);
            Qt.exit(fails === 0 ? 0 : 1);
        }
    }

    FileView { id: readLog; path: Quickshell.env("WP_TEST_LOG"); watchChanges: true }
}
```

- [ ] **Step 2: Run it to verify it fails**

```bash
cd home/quickshell/wallpaper-picker
export WP_TEST_LOG=$(mktemp); export WP_TEST_STUB=$(mktemp)
printf '#!/usr/bin/env bash\necho "$1" >> "%s"\n' "$WP_TEST_LOG" > "$WP_TEST_STUB"
chmod +x "$WP_TEST_STUB"
quickshell -p tests/applier_test.qml
```

Expected: FAIL — `Applier` is not a known type.

- [ ] **Step 3: Write the implementation**

Create `home/quickshell/wallpaper-picker/Applier.qml`:

```qml
// Applies wallpapers by shelling out to apply.sh.
//
// Everything goes through that one script — including `wallpaper-picker
// --restore` at login — so the UI and login can never diverge in how a
// wallpaper gets set.
import QtQuick
import Quickshell
import Quickshell.Io

Item {
    id: root

    property string script: Quickshell.env("HOME") + "/.config/quickshell/wallpaper-picker/apply.sh"

    // Wallpaper in place when the picker opened, so Escape can put it back.
    readonly property string original: _original
    property string _original: ""

    property string _pending: ""

    Process { id: proc }
    Process {
        id: currentProc
        command: [root.script, "--current"]
        stdout: StdioCollector {
            onStreamFinished: root._original = text.trim()
        }
    }

    function captureOriginal() {
        currentProc.running = true;
    }

    function _run(path) {
        proc.command = [root.script, path];
        proc.running = true;
    }

    // Debounced: rapid selection changes collapse into a single apply of the
    // last path, so scrolling the carousel does not thrash awww.
    function schedulePreview(path) {
        _pending = path;
        debounce.restart();
    }

    function applyNow(path) {
        debounce.stop();
        _run(path);
    }

    function revert() {
        debounce.stop();
        if (_original !== "")
            _run(_original);
    }

    Timer {
        id: debounce
        interval: 250
        repeat: false
        onTriggered: if (root._pending !== "") root._run(root._pending)
    }
}
```

- [ ] **Step 4: Run the test to verify it passes**

```bash
cd home/quickshell/wallpaper-picker
export WP_TEST_LOG=$(mktemp); export WP_TEST_STUB=$(mktemp)
printf '#!/usr/bin/env bash\necho "$1" >> "%s"\n' "$WP_TEST_LOG" > "$WP_TEST_STUB"
chmod +x "$WP_TEST_STUB"
quickshell -p tests/applier_test.qml
```

Expected: `ALL PASS`.

- [ ] **Step 5: Print the commit command**

```bash
git -C /persist/nixos-config add home/quickshell/wallpaper-picker/Applier.qml \
                                home/quickshell/wallpaper-picker/tests/applier_test.qml
git -C /persist/nixos-config commit -m "feat(wallpaper-picker): debounced preview and apply"
```

---

### Task 6: `Card.qml` — one sheared card

**Files:**
- Create: `home/quickshell/wallpaper-picker/Card.qml`

**Interfaces:**
- Consumes: `Theme` (Task 3).
- Produces: a `Card` component with `property var theme`, `property string path`, `property string label`, `property bool isDir`, `property bool isVideo`, `property bool selected`, `property int distance` (0 = selected). Sizes and fades itself from `selected`/`distance`.

- [ ] **Step 1: Write the implementation**

There is no meaningful headless assertion for a purely visual component; it is verified on screen in Task 8. Create `home/quickshell/wallpaper-picker/Card.qml`:

```qml
// One card in the carousel.
//
// The frame is sheared -13 degrees; the image inside is counter-sheared +13 so
// the card is a parallelogram while the photograph itself stays undistorted.
import QtQuick

Item {
    id: root

    property var theme
    property string path: ""
    property string label: ""
    property bool isDir: false
    property bool isVideo: false
    property bool selected: false
    property int distance: 0            // 0 = selected, grows outward

    readonly property real skew: -13

    implicitWidth: selected ? 330 : 190
    implicitHeight: selected ? 206 : 132

    opacity: selected ? 1.0 : Math.max(0.30, 0.85 - distance * 0.16)

    Behavior on implicitWidth  { NumberAnimation { duration: 160; easing.type: Easing.OutCubic } }
    Behavior on implicitHeight { NumberAnimation { duration: 160; easing.type: Easing.OutCubic } }
    Behavior on opacity        { NumberAnimation { duration: 160 } }

    transform: Matrix4x4 {
        matrix: Qt.matrix4x4(1, Math.tan(root.skew * Math.PI / 180), 0, 0,
                             0, 1, 0, 0,
                             0, 0, 1, 0,
                             0, 0, 0, 1)
    }

    Rectangle {
        id: frame
        anchors.fill: parent
        radius: 6
        clip: true
        color: root.theme ? root.theme.surfaceHigh : "#201f23"
        border.width: root.selected ? 2 : 1
        border.color: root.selected
            ? (root.theme ? root.theme.primary : "#c2c1ff")
            : Qt.rgba(1, 1, 1, 0.10)

        // Folder card: a glyph, counter-sheared so it reads upright.
        Text {
            visible: root.isDir
            anchors.centerIn: parent
            text: "󰁋"                      // nf-md-folder
            font.pixelSize: root.selected ? 44 : 28
            color: root.theme ? root.theme.primary : "#c2c1ff"
            transform: Matrix4x4 {
                matrix: Qt.matrix4x4(1, -Math.tan(root.skew * Math.PI / 180), 0, 0,
                                     0, 1, 0, 0, 0, 0, 1, 0, 0, 0, 0, 1)
            }
        }

        // Image card: over-wide and counter-sheared so the shear crops rather
        // than distorts, and no transparent wedge shows at the edges.
        Image {
            visible: !root.isDir
            anchors.centerIn: parent
            width: parent.width * 1.35
            height: parent.height
            source: root.isDir ? "" : "file://" + root.path
            fillMode: Image.PreserveAspectCrop
            asynchronous: true
            cache: true
            sourceSize.width: 480               // decode small; 274 files stay cheap
            transform: Matrix4x4 {
                matrix: Qt.matrix4x4(1, -Math.tan(root.skew * Math.PI / 180), 0, 0,
                                     0, 1, 0, 0, 0, 0, 1, 0, 0, 0, 0, 1)
            }
        }

        // Video badge
        Rectangle {
            visible: root.isVideo
            anchors { right: parent.right; bottom: parent.bottom; margins: 6 }
            width: 22; height: 14; radius: 3
            color: Qt.rgba(0, 0, 0, 0.65)
            Text {
                anchors.centerIn: parent
                text: "▶"; font.pixelSize: 8; color: "#ffffff"
            }
        }
    }

    // Selection glow, drawn outside the clipped frame.
    Rectangle {
        visible: root.selected
        anchors.fill: frame
        anchors.margins: -5
        radius: 10
        color: "transparent"
        border.width: 5
        border.color: root.theme
            ? Qt.rgba(root.theme.primary.r, root.theme.primary.g, root.theme.primary.b, 0.20)
            : Qt.rgba(0.76, 0.76, 1, 0.20)
        z: -1
    }
}
```

- [ ] **Step 2: Add video poster frames**

The spec calls for video posters from `ffmpegthumbnailer`. Videos are a small
minority of the library (5 of 279), so this stays inside `Card.qml` rather than
becoming its own component. Add to `Card.qml`, inside the root `Item`:

```qml
    // ── Video posters ──────────────────────────────────────────────────────
    // A QML Image cannot decode a video, so extract one frame to a cache file
    // and point the Image at that. Cached by mangled path, so it is generated
    // once per video and reused on every open.
    readonly property string posterPath: {
        if (!isVideo || path === "")
            return "";
        const key = path.replace(/[\/. ]/g, "_");
        return Quickshell.env("HOME") + "/.cache/wallpaper-picker/" + key + ".jpg";
    }

    property bool _posterReady: false

    Process {
        id: posterProc
        // -s 480: match the Image sourceSize below. -f: overwrite a stale file.
        command: ["ffmpegthumbnailer", "-i", root.path, "-o", root.posterPath, "-s", "480", "-f"]
        onExited: root._posterReady = (exitCode === 0)
    }

    FileView {
        id: posterCheck
        path: root.posterPath
        onLoaded: root._posterReady = true
        // Not cached yet — generate it. A failure leaves _posterReady false and
        // the card falls back to the plain surface plus its ▶ badge.
        onLoadFailed: if (root.isVideo && root.path !== "") posterProc.running = true
    }
```

Add `import Quickshell` and `import Quickshell.Io` to the top of `Card.qml`,
and change the `Image`'s `source` and `visible` bindings to use the poster for
videos:

```qml
            visible: !root.isDir && (!root.isVideo || root._posterReady)
            source: root.isDir ? ""
                  : root.isVideo ? (root._posterReady ? "file://" + root.posterPath : "")
                  : "file://" + root.path
```

- [ ] **Step 3: Verify poster generation works on a real video**

```bash
mkdir -p ~/.cache/wallpaper-picker
VID=$(find -L ~/Pictures/wallpapers -type f \( -iname '*.mp4' -o -iname '*.mkv' -o -iname '*.webm' \) | head -1)
echo "using: $VID"
ffmpegthumbnailer -i "$VID" -o /tmp/poster_check.jpg -s 480 -f && echo "POSTER_OK $(stat -c %s /tmp/poster_check.jpg) bytes"
```

Expected: `POSTER_OK` with a non-zero byte count. This proves the command and
flags are right before wiring them into QML.

- [ ] **Step 4: Verify it parses**

```bash
cd home/quickshell/wallpaper-picker
cat > /tmp/card_smoke.qml <<'QML'
import QtQuick
import Quickshell
ShellRoot {
    Card { id: c; label: "x"; isDir: true }
    Component.onCompleted: { console.log("CARD_OK w=" + c.implicitWidth); Qt.exit(0); }
}
QML
cp /tmp/card_smoke.qml ./card_smoke.qml && quickshell -p card_smoke.qml; rm -f card_smoke.qml
```

Expected: prints `CARD_OK w=190`, exit 0.

- [ ] **Step 5: Print the commit command**

```bash
git -C /persist/nixos-config add home/quickshell/wallpaper-picker/Card.qml
git -C /persist/nixos-config commit -m "feat(wallpaper-picker): sheared card component"
```

---

### Task 7: `shell.qml` — window, carousel rail, key handling

**Files:**
- Create: `home/quickshell/wallpaper-picker/shell.qml`

**Interfaces:**
- Consumes: `Theme`, `Library`, `Applier`, `Card`.
- Produces: the running application. No exported interface.

- [ ] **Step 1: Write the implementation**

Create `home/quickshell/wallpaper-picker/shell.qml`:

```qml
// Skewed-carousel wallpaper selector.
//
// Layout and behaviour are specified in
// docs/superpowers/specs/2026-09-05-wallpaper-picker-design.md
import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Wayland

ShellRoot {
    Theme   { id: appTheme }
    Library { id: lib }
    Applier { id: applier }

    Component.onCompleted: applier.captureOriginal()

    PanelWindow {
        id: win
        anchors { top: true; bottom: true; left: true; right: true }
        color: "transparent"

        WlrLayershell.layer: WlrLayer.Overlay
        WlrLayershell.keyboardFocus: WlrKeyboardFocus.Exclusive
        WlrLayershell.namespace: "wallpaper-picker"

        // Dim the desktop, but leave it visible — the point of preview-on-pause
        // is judging the wallpaper behind this window.
        Rectangle {
            anchors.fill: parent
            color: Qt.rgba(0, 0, 0, 0.45)
        }

        function selectionChanged() {
            const e = lib.entry(lib.index);
            if (e && !e.isDir && !e.isVideo)
                applier.schedulePreview(e.path);   // video preview would fight mpvpaper
        }

        function activate() {
            const e = lib.entry(lib.index);
            if (!e)
                return;
            if (e.isDir) {
                lib.descend();
                selectionChanged();
                return;
            }
            applier.applyNow(e.path);
            Qt.exit(0);
        }

        Connections {
            target: lib
            function onIndexChanged() { win.selectionChanged(); }
        }

        Item {
            anchors.fill: parent
            focus: true

            Keys.onPressed: event => {
                if (event.key === Qt.Key_Escape) {
                    applier.revert();
                    Qt.exit(0);
                } else if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) {
                    win.activate();
                } else if (event.key === Qt.Key_Backspace) {
                    if (lib.filter !== "")
                        lib.filter = lib.filter.slice(0, -1);
                    else
                        lib.ascend();
                } else if (event.key === Qt.Key_Left
                        || (event.key === Qt.Key_H && (event.modifiers & Qt.AltModifier))) {
                    lib.move(-1);
                } else if (event.key === Qt.Key_Right
                        || (event.key === Qt.Key_L && (event.modifiers & Qt.AltModifier))) {
                    lib.move(1);
                } else if (event.text.length === 1 && event.text >= " ") {
                    lib.filter += event.text;
                }
                event.accepted = true;
            }

            ColumnLayout {
                anchors.centerIn: parent
                width: parent.width
                spacing: 18

                // Filter box / breadcrumb
                Rectangle {
                    Layout.alignment: Qt.AlignHCenter
                    Layout.preferredWidth: Math.min(420, parent.width * 0.7)
                    Layout.preferredHeight: 36
                    radius: 10
                    color: Qt.rgba(appTheme.surface.r, appTheme.surface.g, appTheme.surface.b, 0.82)
                    border.width: 1
                    border.color: Qt.rgba(1, 1, 1, 0.10)

                    Text {
                        anchors { fill: parent; leftMargin: 13; rightMargin: 13 }
                        verticalAlignment: Text.AlignVCenter
                        elide: Text.ElideRight
                        color: lib.filter === "" ? appTheme.outline : appTheme.onSurface
                        font.family: "Fira Code"
                        font.pixelSize: 13
                        text: lib.filter !== "" ? "▍ " + lib.filter
                            : (lib.breadcrumb !== "" ? "▍ " + lib.breadcrumb + "/"
                                                     : "▍ Search / Choose Wallpaper")
                    }
                }

                // The rail
                Item {
                    Layout.fillWidth: true
                    Layout.preferredHeight: 240

                    Row {
                        id: rail
                        anchors.centerIn: parent
                        spacing: -26                       // overlap

                        Repeater {
                            model: lib.count
                            Card {
                                required property int index
                                readonly property var e: lib.entry(index)
                                visible: Math.abs(index - lib.index) <= 3
                                theme: appTheme
                                path: e ? e.path : ""
                                label: e ? e.name : ""
                                isDir: e ? e.isDir : false
                                isVideo: e ? e.isVideo : false
                                selected: index === lib.index
                                distance: Math.abs(index - lib.index)
                                anchors.verticalCenter: parent.verticalCenter
                            }
                        }

                        // No transform needed: Row skips invisible children, so
                        // the <=7 visible cards are the only ones laid out and
                        // anchors.centerIn already centres them. At the very
                        // start or end of a folder the window is asymmetric and
                        // the selection sits slightly off-centre; that is
                        // accepted rather than fought with a scroll offset.
                    }
                }

                // Metadata
                ColumnLayout {
                    Layout.alignment: Qt.AlignHCenter
                    spacing: 4
                    Text {
                        Layout.alignment: Qt.AlignHCenter
                        text: { const e = lib.entry(lib.index); return e ? e.name : "No wallpapers here"; }
                        color: appTheme.onSurface
                        font.family: "Fira Code"; font.pixelSize: 15
                    }
                    Text {
                        Layout.alignment: Qt.AlignHCenter
                        text: (lib.breadcrumb !== "" ? lib.breadcrumb : "wallpapers")
                              + " · " + (lib.count > 0 ? (lib.index + 1) + " of " + lib.count
                                                       : "empty — backspace to go up")
                        color: appTheme.outline
                        font.family: "Fira Code"; font.pixelSize: 10
                    }
                }

                // Key hints
                Text {
                    Layout.alignment: Qt.AlignHCenter
                    text: "alt+h/l move   ↵ apply   ⌫ up   type to filter   esc revert"
                    color: appTheme.outline
                    font.family: "Fira Code"; font.pixelSize: 10.5
                }
            }
        }
    }
}
```

- [ ] **Step 2: Verify it launches and lists the real library**

```bash
cd /persist/nixos-config/home/quickshell/wallpaper-picker
quickshell -p . 2>&1 | head -20
```

Expected: `Configuration Loaded`, a window appears showing the five folders as sheared cards. Press `Escape` to close.

- [ ] **Step 3: Print the commit command**

```bash
git -C /persist/nixos-config add home/quickshell/wallpaper-picker/shell.qml
git -C /persist/nixos-config commit -m "feat(wallpaper-picker): carousel window and key handling"
```

---

### Task 8: Bind it, switch login restore, verify end to end

**Files:**
- Modify: `home/hypr/lua/keybinds.lua` (the `SUPER+W` line)
- Modify: `home/hypr/lua/startup_apps.lua` (the `qs-wallpaper-restore` line)

**Interfaces:**
- Consumes: everything above.
- Produces: `SUPER+W` opens the picker; login restores the last wallpaper through the new path.

- [ ] **Step 1: Repoint the keybind**

In `home/hypr/lua/keybinds.lua`, replace the `SUPER+W` binding and its comment block with:

```lua
-- Wallpaper picker: our own Quickshell skewed-carousel selector.
-- See docs/superpowers/specs/2026-09-05-wallpaper-picker-design.md
hl.bind(mod .. " + W", hl.dsp.exec_cmd("wallpaper-picker"))
```

- [ ] **Step 2: Switch login restore**

In `home/hypr/lua/startup_apps.lua`, replace `hl.exec_cmd("qs-wallpaper-restore")` with:

```lua
  -- Reapplies the last wallpaper through the same apply.sh the picker uses,
  -- so login cannot diverge from what picking a wallpaper does. No Qt startup.
  hl.exec_cmd("wallpaper-picker --restore")
```

- [ ] **Step 3: Verify the config still builds**

```bash
nix build --dry-run "path:/persist/nixos-config#nixosConfigurations.laptop.config.system.build.toplevel" 2>&1 | grep -E "will be built|error"
```

Expected: a derivation count, no `error:`.

- [ ] **Step 4: Run every automated test once more**

```bash
cd /persist/nixos-config/home/quickshell/wallpaper-picker
bash tests/apply_test.sh
bash tests/package_test.sh
WP_TEST_SCHEME=/tmp/wp-scheme.json quickshell -p tests/theme_test.qml
R=$(mktemp -d); mkdir -p "$R/alpha"; : > "$R/one.png"; : > "$R/clip.mp4"; : > "$R/alpha/deep.png"
WP_TEST_ROOT="$R" quickshell -p tests/library_test.qml
```

Expected: `ALL PASS` from each.

- [ ] **Step 5: Walk the spec's behavioural checks**

After the user runs `nixos-rebuild switch` and logs back in, confirm each:

1. `SUPER+W` — five folders appear as sheared cards
2. Descend into `scene`; images appear; `Backspace` returns
3. Type `lofi`; the rail narrows
4. Pause on a card for ~250 ms; the desktop changes behind
5. `Escape`; the original wallpaper is restored
6. `Enter` on an image; `awww query` confirms it applied
7. `Enter` on a video; `pgrep -a mpvpaper` shows it running
8. `wallpaper-picker --restore` reapplies the last wallpaper
9. Change scheme with `SUPER+CTRL+R`, reopen; the picker's colours followed

- [ ] **Step 6: Print the commit command**

```bash
git -C /persist/nixos-config add home/hypr/lua/keybinds.lua home/hypr/lua/startup_apps.lua
git -C /persist/nixos-config commit -m "feat(wallpaper-picker): bind SUPER+W and switch login restore"
```

---

## Follow-up (separate change, not this plan)

Once the above is proven in daily use, remove the third-party package it replaces:

- Delete `pkgs/qs-wallpaper-picker.nix`
- Remove `qs-wallpaper-picker` from the `configuration.nix` overlay
- Remove `pkgs.qs-wallpaper-picker` from `home/modules/caelestia-quickshell.nix`
- Drop the now-unused `QS_WALLPAPER_DIR` session variable
