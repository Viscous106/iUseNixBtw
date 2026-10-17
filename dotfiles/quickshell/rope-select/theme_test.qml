// Lives at the config root, not tests/: Quickshell resolves QML components
// relative to the directory it is pointed at, so a test under tests/ cannot see
// Theme.qml.
import QtQuick
import Quickshell

ShellRoot {
    property int fails: 0
    function check(label, expected, actual) {
        if (String(expected) === String(actual)) console.log("  ok: " + label);
        else { console.log("  FAIL: " + label + " expected=" + expected + " actual=" + actual); fails++; }
    }

    Theme { id: good;    schemePath: Quickshell.env("RS_TEST_SCHEME") }
    Theme { id: bad;     schemePath: "/nonexistent/scheme.json" }
    Theme { id: noKey;   schemePath: Quickshell.env("RS_TEST_NOKEY") }
    Theme { id: partial; schemePath: Quickshell.env("RS_TEST_PARTIAL") }

    Timer {
        running: true; interval: 400
        onTriggered: {
            check("good: parses primary", "#c2c1ff", String(good.primary));
            check("good: parses surface", "#131317", String(good.surface));
            check("good: marks loaded",   "true",    String(good.loaded));

            // Missing file: must not crash, must fall back.
            check("bad: fallback primary", "#ffb68e", String(bad.primary));
            check("bad: fallback surface", "#1a120d", String(bad.surface));
            check("bad: marks not loaded", "false",   String(bad.loaded));

            // Valid JSON, no "colours" key — catches the undefined !== null bug.
            check("noKey: not loaded",       "false",   String(noKey.loaded));
            check("noKey: primary fallback", "#ffb68e", String(noKey.primary));

            // "colours" present but missing keys: per-key fallback, not all-or-nothing.
            check("partial: loaded",          "true",    String(partial.loaded));
            check("partial: surface from file","#010203", String(partial.surface));
            check("partial: primary fallback","#ffb68e", String(partial.primary));

            console.log(fails === 0 ? "ALL PASS" : "FAILURES=" + fails);
            Qt.exit(fails === 0 ? 0 : 1);
        }
    }
}
