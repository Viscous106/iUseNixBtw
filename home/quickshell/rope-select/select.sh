#!/usr/bin/env bash
# rope-select — pick a screen region, print it the way slurp does.
#
# A drop-in replacement for `slurp`: geometry as "X,Y WxH" on stdout and exit 0,
# or a non-zero exit and nothing on stdout. Callers (ScreenShot.sh,
# ScreenRecord.sh) need no special handling -- `grim -g "$(rope-select)"` works
# exactly as `grim -g "$(slurp)"` did.
#
# The selector itself is the Quickshell config beside this script; see shell.qml.
# It is launched per selection rather than kept resident: caelestia is already
# running as the session's quickshell shell, and a second always-on instance
# holding nothing but an invisible overlay would earn nothing.
#
# Falls back to slurp whenever the overlay cannot answer -- quickshell missing,
# or it died before deciding anything. A broken selector should cost you the
# animation, never the screenshot. A deliberate CANCEL is not a failure and does
# NOT fall back: being asked to pick a region twice because you pressed Escape
# would be worse than useless.
set -uo pipefail

CONFIG_DIR="${ROPE_SELECT_CONFIG_DIR:-$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)}"

out=""
cleanup() { [ -n "$out" ] && rm -f "$out"; }
trap cleanup EXIT

fallback() {
    if ! command -v slurp >/dev/null 2>&1; then
        echo "rope-select: neither quickshell nor slurp is available" >&2
        exit 1
    fi
    # exec replaces this process, so EXIT never fires -- clean up by hand first
    # or every fallback leaks a temp file.
    cleanup
    trap - EXIT
    exec slurp "$@"
}

command -v quickshell >/dev/null 2>&1 || fallback "$@"

out="$(mktemp -t rope-select.XXXXXXXX)" || fallback "$@"

# The result comes back through this file rather than stdout, because
# quickshell writes its own logging to stdout and the geometry would have to be
# fished back out of it.
if [ -n "${ROPE_SELECT_DEBUG:-}" ]; then
    ROPE_SELECT_OUT="$out" quickshell -p "$CONFIG_DIR"
else
    ROPE_SELECT_OUT="$out" quickshell -p "$CONFIG_DIR" >/dev/null 2>&1
fi

geometry="$(head -n1 "$out" 2>/dev/null)"

case "$geometry" in
    # Escape, right-click, or a click with no drag. slurp exits 1 here too.
    cancel)
        exit 1
        ;;
    # Nothing was written: the overlay never reached a decision, so this is a
    # crash and not an answer. Ask slurp instead.
    "")
        fallback "$@"
        ;;
    *)
        printf '%s\n' "$geometry"
        ;;
esac
