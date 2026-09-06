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

        // Fullscreen overlay: never reserve screen space, or opening the picker
        // would reflow every tiled client on the workspace behind it.
        exclusionMode: ExclusionMode.Ignore

        WlrLayershell.layer: WlrLayer.Overlay
        WlrLayershell.keyboardFocus: WlrKeyboardFocus.Exclusive
        WlrLayershell.namespace: "wallpaper-picker"

        // Dim the desktop, but leave it visible — the point of preview-on-pause
        // is judging the wallpaper behind this window.
        Rectangle {
            anchors.fill: parent
            color: Qt.rgba(0, 0, 0, 0.45)
        }

        // ── Selection, guarded against the async model ────────────────────────
        //
        // Library's FolderListModel repopulates ASYNCHRONOUSLY: after descend(),
        // ascend() or a filter change, `count` and `entry()` can still describe
        // the PREVIOUS folder for one or more event-loop turns. So previews are
        // never driven by "navigate, then read" — they are driven reactively off
        // a binding, and every read is validated against `lib.dir` before it is
        // allowed to reach the Applier.
        //
        // The validation is structural rather than signal-based: an entry that
        // belongs to the settled model always sits DIRECTLY inside `lib.dir`, so
        // dirname(entry.path) === lib.dir. A leftover entry from the folder we
        // just left fails that test in both directions —
        //   descend: dirname(".../wallpapers/favs")      = ".../wallpapers"
        //            != lib.dir (".../wallpapers/favs")
        //   ascend:  dirname(".../wallpapers/favs/a.jpg") = ".../wallpapers/favs"
        //            != lib.dir (".../wallpapers")
        // — which is why a plain startsWith() would not do: on ascend the stale
        // path is still a descendant of the new dir.
        function _parentDir(p) {
            const i = p.lastIndexOf("/");
            return i > 0 ? p.substring(0, i) : "/";
        }

        readonly property var currentEntry: {
            const e = lib.entry(lib.index);
            if (!e || win._parentDir(e.path) !== lib.dir)
                return null;                   // model has not settled yet
            return e;
        }

        // The path whose preview is wanted, or "" for none. Deliberately a
        // string and not the entry object: entry() hands back a fresh object on
        // every call, so a var property would re-fire on every re-evaluation and
        // re-arm the debounce for a selection that never actually moved.
        // Videos are excluded on purpose — a preview would fight mpvpaper.
        readonly property string previewPath: {
            const e = win.currentEntry;
            return (e && !e.isDir && !e.isVideo) ? e.path : "";
        }

        // Whether anything has been previewed, i.e. whether the desktop has been
        // touched at all. Without this, Escape out of a picker that was only
        // ever used to browse folders would still re-apply the current wallpaper.
        property bool previewed: false

        onPreviewPathChanged: {
            if (previewPath !== "") {
                previewed = true;
                applier.schedulePreview(previewPath);
            }
        }

        // ── Failure reporting ─────────────────────────────────────────────────
        property string errorText: ""

        Timer {
            id: errorClear
            interval: 5000
            onTriggered: win.errorText = ""
        }

        // The path whose completion this window is waiting on, "" when idle.
        //
        // Applier reuses one Process and Quickshell QUEUES rather than drops, so
        // a preview that was already running when Enter or Escape was pressed
        // still runs and still reports an exit. Without correlating on the path,
        // that preview's exit is indistinguishable from the operation the user
        // is actually waiting for — and the window would close on it, before
        // apply.sh had even started the apply.
        //
        // A dismissal outranks an apply: cancel() dispatches last, so its revert
        // is the operation in flight. The revert's path is read here rather than
        // snapshotted in cancel(), because captureOriginal() may not have
        // returned when Escape is pressed — Applier defers the revert until it
        // has, and `original` is only populated then.
        property string awaitingPath: ""
        function awaitedPath() {
            if (win.exiting)  return applier.original;
            if (win.applying) return win.awaitingPath;
            return "";
        }

        Connections {
            target: applier

            function onApplyFailed(path, code) {
                // Not our operation: the death rattle of a superseded preview.
                if (win.awaitedPath() !== "" && path !== win.awaitedPath())
                    return;

                win.errorText = "apply failed (exit " + code + "): "
                              + path.substring(path.lastIndexOf("/") + 1);
                errorClear.restart();
                // Only an APPLY failure holds the window open to show the
                // message. A failed REVERT must never cancel a dismissal: this
                // window takes exclusive keyboard focus, so a revert that fails
                // every time (awww down, original file moved) would otherwise
                // trap the user with no way to reach a terminal. See cancel().
                if (win.applying && !win.exiting) {
                    exitGrace.stop();
                    win.applying = false;
                    win.awaitingPath = "";
                }
            }

            // apply.sh has actually finished. Previews succeed constantly and a
            // superseded one can still be in the queue, so only the completion
            // of the exact operation being awaited closes the window.
            function onApplySucceeded(path) {
                if (win.awaitedPath() === "" || path !== win.awaitedPath())
                    return;
                if (win.applying || win.exiting)
                    Qt.exit(0);
            }
        }

        // ── Exit ──────────────────────────────────────────────────────────────
        //
        // Not Qt.exit(0) the instant applyNow() returns: apply.sh is a child
        // process of this shell, and tearing the shell down immediately can kill
        // it mid-`awww img`, leaving the wallpaper unchanged and the state file
        // unwritten. It would also make applyFailed unreachable for the one case
        // that matters most. So the window closes on Applier.applySucceeded —
        // apply.sh having genuinely finished — rather than on a guessed delay.
        property bool applying: false     // an explicit apply is in flight
        property bool exiting: false      // a dismissal is in flight

        // Backstop only, for a child that hangs or never starts (e.g. apply.sh
        // missing, so no exit signal ever arrives). The normal path is
        // onApplySucceeded above; this must never be the thing we rely on.
        Timer {
            id: exitGrace
            interval: 3000
            onTriggered: Qt.exit(0)
        }

        function activate() {
            const e = win.currentEntry;
            if (!e)
                return;
            if (e.isDir) {
                lib.descend();      // the preview follows reactively once the
                return;             // model settles; never read it here
            }
            win.awaitingPath = e.path;
            applier.applyNow(e.path);
            win.previewed = true;
            win.applying = true;
            exitGrace.restart();
        }

        // INVARIANT: there is no state in which this window cannot be dismissed
        // from the keyboard. The first Escape starts a bounded close; a second
        // Escape exits immediately and unconditionally, however badly the revert
        // is going.
        function cancel() {
            if (win.exiting) {
                Qt.exit(0);
                return;
            }
            win.exiting = true;
            // Nothing was ever previewed → the desktop is untouched, so there is
            // nothing to put back and no child process to wait for.
            //
            // Same for a fresh install with no recorded original (applier.original
            // === ""): _doRevert() no-ops, nothing is dispatched, awaitedPath()
            // stays "", and the window would otherwise sit until the exitGrace
            // backstop for no reason. Exiting immediately here does not weaken the
            // "always dismissable" invariant -- win.exiting is already set above,
            // so a second Escape still exits at once regardless of this branch.
            if (!win.previewed || applier.original === "") {
                Qt.exit(0);
                return;
            }
            applier.revert();
            exitGrace.restart();
        }

        Item {
            anchors.fill: parent
            focus: true

            Keys.onPressed: event => {
                if (event.key === Qt.Key_Escape) {
                    win.cancel();
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
                } else if (event.text.length === 1
                        // Printable only. `>= " "` alone admits DEL (0x7f), which
                        // appends an invisible character and silently empties the
                        // list with no visible cause.
                        && event.text.charCodeAt(0) >= 0x20
                        && event.text.charCodeAt(0) !== 0x7f
                        && !(event.modifiers & (Qt.ControlModifier | Qt.AltModifier))) {
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
                                // Repeater instantiates ALL delegates and
                                // `visible` gates rendering only — without this
                                // a 121-file folder decodes ~60 MB of images.
                                active: Math.abs(index - lib.index) <= 3
                                imageExts: lib.imageExts
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
                        text: win.currentEntry ? win.currentEntry.name : "No wallpapers here"
                        color: appTheme.onSurface
                        font.family: "Fira Code"; font.pixelSize: 15
                    }
                    Text {
                        Layout.alignment: Qt.AlignHCenter
                        text: (lib.breadcrumb !== "" ? lib.breadcrumb : "wallpapers")
                              // With a filter active, Backspace deletes a
                              // character rather than going up a level.
                              + " · " + (lib.count > 0 ? (lib.index + 1) + " of " + lib.count
                                       : lib.filter === "" ? "empty — backspace to go up"
                                                           : "no matches")
                        color: appTheme.outline
                        font.family: "Fira Code"; font.pixelSize: 10
                    }
                    // Transient failure / progress line. Theme has no error
                    // role, hence the literal colour.
                    Text {
                        Layout.alignment: Qt.AlignHCenter
                        visible: win.errorText !== "" || win.applying
                        text: win.errorText !== "" ? "⚠ " + win.errorText : "applying…"
                        color: win.errorText !== "" ? "#ff8a80" : appTheme.primary
                        font.family: "Fira Code"; font.pixelSize: 11
                    }
                }

                // Key hints
                Text {
                    Layout.alignment: Qt.AlignHCenter
                    text: "alt+h/l move   ↵ apply   ⌫ up   type to filter   esc revert"
                    color: appTheme.outline
                    // 11, not the brief's 10.5: font.pixelSize is an int and
                    // a fractional literal is rejected at load time.
                    font.family: "Fira Code"; font.pixelSize: 11
                }
            }
        }
    }
}
