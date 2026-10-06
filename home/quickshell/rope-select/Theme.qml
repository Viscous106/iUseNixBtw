// Colours, read from caelestia's live scheme so the selector matches the shell.
//
// This is the whole of the "integration" with caelestia: one JSON file, no
// patching of caelestia itself. Change scheme with SUPER+CTRL+R and the next
// selection picks the new colours up.
//
// A near-copy of home/quickshell/wallpaper-picker/Theme.qml, trimmed to the two
// colours this config actually uses. It is duplicated rather than shared
// because Quickshell resolves components relative to the single directory it is
// pointed at -- a config cannot import a component from a sibling config.
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

    // Fallbacks are zephyr's own orange-on-near-black, so an absent scheme
    // still looks deliberate rather than defaulting to raw Qt white.
    readonly property color primary: _c("primary", "#ffb68e")
    readonly property color surface: _c("surface", "#1a120d")

    FileView {
        path: root.schemePath
        watchChanges: true
        onLoaded: {
            try {
                const parsed = JSON.parse(text()).colours;
                // `|| null` matters: a valid JSON file with no "colours" key yields
                // undefined, and `undefined !== null` would make `loaded` report true
                // while every colour is actually the fallback.
                root._colours = (parsed && typeof parsed === "object") ? parsed : null;
            } catch (e) {
                root._colours = null;   // malformed: fall back rather than crash
            }
        }
        onLoadFailed: root._colours = null
        onFileChanged: reload()
    }
}
