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

    // Whether captureOriginal()'s Process is still in flight, and whether a
    // revert() arrived while it was — so a fast Escape right after opening
    // the picker defers instead of silently no-op'ing on a still-empty
    // `_original`.
    property bool _captureInFlight: false
    property bool _revertPending: false

    // Emitted when apply.sh exits non-zero. The UI shows this; without it a
    // failed apply is completely silent and looks like the key press did
    // nothing. Fires for previews, explicit applies, and reverts alike — a
    // failed revert is just as silent-looking otherwise, and tracking which
    // caller triggered it isn't worth the extra state.
    signal applyFailed(string path, int code)

    // Emitted when apply.sh exits zero. The UI waits for this before closing
    // after an explicit apply or a revert: apply.sh is a child of this shell,
    // so exiting on a fixed timer instead can kill it mid-`awww img` and leave
    // the state file unwritten. Fires for previews too; callers that only care
    // about an explicit apply must check their own state.
    signal applySucceeded(string path)

    // Paths handed to `proc`, oldest first — see the note above _run(). One
    // `_path` string is not enough: a second command assigned while the first
    // is still running is QUEUED, both children run, and the Process emits
    // `exited` once each. A single string would already have been overwritten,
    // so the first exit would be reported under the *later* path.
    property var _queue: []

    Process {
        id: proc
        onExited: (exitCode, exitStatus) => {
            const q = root._queue.slice();
            const path = q.length > 0 ? q.shift() : "";
            root._queue = q;
            if (exitCode !== 0)
                root.applyFailed(path, exitCode);
            else
                root.applySucceeded(path);
        }
    }
    Process {
        id: currentProc
        command: [root.script, "--current"]
        stdout: StdioCollector {
            onStreamFinished: {
                root._original = text.trim();
                root._captureInFlight = false;
                if (root._revertPending) {
                    root._revertPending = false;
                    root._doRevert();
                }
            }
        }
    }

    function captureOriginal() {
        _captureInFlight = true;
        currentProc.running = true;
    }

    // Single shared Process. NOTE: Quickshell 0.3.0 does NOT drop an in-flight
    // command when `command` is reassigned and `running` set again — it QUEUES
    // it. Measured: the second child does not start until the first has exited,
    // and both run to completion, in launch order, each producing its own
    // `exited`. So the final wallpaper is still the most recent intent (the last
    // command applied wins by running last), but every queued command really
    // executes, and `exited` fires once per command.
    //
    // That is why the paths ride in a FIFO rather than a single `_path`: the
    // exits arrive in launch order, so shifting the queue reports each one under
    // the path that actually ran. Consumers correlate on that path to tell their
    // own operation's completion from a preview's — without it, a preview's exit
    // is indistinguishable from the apply the user is waiting on.
    function _run(path) {
        root._queue = root._queue.concat([path]);
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

    // If captureOriginal() is still in flight, defer: remember the request and
    // run it once onStreamFinished lands and _original is populated. Only when
    // a capture has actually completed and _original is genuinely empty (no
    // wallpaper ever recorded) is doing nothing correct.
    function revert() {
        debounce.stop();
        if (_captureInFlight) {
            _revertPending = true;
            return;
        }
        _doRevert();
    }

    function _doRevert() {
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
