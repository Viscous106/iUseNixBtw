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
