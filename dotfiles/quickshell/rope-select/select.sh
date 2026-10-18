#!/usr/bin/env bash
# rope-select: drop-in slurp ("X,Y WxH" + exit 0, or non-zero and no stdout); overlay is shell.qml.
# Falls back to slurp if the overlay can't answer, but not on a deliberate cancel.
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

# Result comes back via this file because quickshell logs to stdout.
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
