// rope-select — an animated region selector, drop-in compatible with slurp.
//
// Launched per selection by the `rope-select` wrapper (pkgs/rope-select.nix),
// which hands it ROPE_SELECT_OUT and reads the answer back out of that file.
// stdout is not used for the result: quickshell writes its own logging there,
// so the geometry would have to be dug back out of it.
//
// Lifecycle: Qt.exit() is what ends a quickshell process. Qt.quit() does NOT --
// it only emits QQmlEngine::quit(), which quickshell leaves unconnected
// ("Signal QQmlEngine::quit() emitted, but no receivers connected to handle
// it"), and the overlay would stay up over the screen forever.
//
// Exit codes match slurp's, so callers need no new error handling:
//   0  a region was selected; its geometry is in ROPE_SELECT_OUT
//   1  cancelled (Escape, right-click, or a click with no drag)
import QtQuick
import Quickshell
import Quickshell.Io

ShellRoot {
    id: root

    readonly property string outPath: Quickshell.env("ROPE_SELECT_OUT") ?? ""

    // Every screen gets its own overlay, and whichever one is used finishes the
    // whole process -- so this guards against a second screen's release landing
    // after the first has already decided.
    property bool done: false

    Theme {
        id: theme
    }

    FileView {
        id: out
        path: root.outPath
    }

    function finish(geometry: string): void {
        if (root.done)
            return;
        root.done = true;

        if (root.outPath === "") {
            // Run by hand rather than through the wrapper. Say so, rather than
            // dropping the result on the floor and exiting as if it had worked.
            console.log("rope-select: ROPE_SELECT_OUT unset, result was: " + (geometry === "" ? "cancel" : geometry));
            Qt.exit(1);
            return;
        }

        // A cancel MUST be written out, not merely exited on. select.sh treats
        // an empty file as "the overlay crashed before deciding" and falls back
        // to slurp -- so staying silent here would answer Escape by immediately
        // asking for the region again with a different tool.
        if (geometry === "") {
            out.setText("cancel\n");
            Qt.exit(1);
            return;
        }

        out.setText(geometry + "\n");
        Qt.exit(0);
    }

    Variants {
        model: Quickshell.screens

        delegate: Geom {
            primaryColour: theme.primary
            surfaceColour: theme.surface

            onSelected: geometry => root.finish(geometry)
            onCancelled: root.finish("")
        }
    }
}
