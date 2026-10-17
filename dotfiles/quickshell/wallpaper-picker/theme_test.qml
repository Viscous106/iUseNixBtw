// Lives at the config root, not tests/: Quickshell resolves QML components
// relative to the directory it is pointed at, and neither `import ".."` nor
// `import ".." as P` works — a test under tests/ cannot see Theme.qml.

import QtQuick
import Quickshell

ShellRoot {
    property int fails: 0
    function check(label, expected, actual) {
        if (String(expected) === String(actual)) console.log("  ok: " + label);
        else { console.log("  FAIL: " + label + " expected=" + expected + " actual=" + actual); fails++; }
    }

    Theme { id: good;    schemePath: Quickshell.env("WP_TEST_SCHEME") }
    Theme { id: bad;     schemePath: "/nonexistent/scheme.json" }
    Theme { id: noKey;   schemePath: Quickshell.env("WP_TEST_NOKEY") }
    Theme { id: partial; schemePath: Quickshell.env("WP_TEST_PARTIAL") }

    Timer {
        running: true; interval: 400
        onTriggered: {
            // good: valid complete scheme
            check("good: parses primary",    "#c2c1ff", String(good.primary));
            check("good: parses background", "#131317", String(good.background));
            check("good: marks loaded",      "true",    String(good.loaded));

            // bad: missing file
            check("bad: fallback literal",   "#131317", String(bad.background));
            check("bad: marks not loaded",   "false",   String(bad.loaded));

            // noKey: valid JSON, but no "colours" key — catches the undefined !== null bug
            check("noKey: not loaded",       "false",   String(noKey.loaded));
            check("noKey: primary fallback", "#c2c1ff", String(noKey.primary));
            check("noKey: bg fallback",      "#131317", String(noKey.background));

            // partial: valid JSON with "colours" object, but only some keys present
            check("partial: loaded",         "true",    String(partial.loaded));
            check("partial: bg from file",   "#010203", String(partial.background));
            check("partial: primary fallback","#c2c1ff", String(partial.primary));

            console.log(fails === 0 ? "ALL PASS" : "FAILURES=" + fails);
            Qt.exit(fails === 0 ? 0 : 1);
        }
    }
}
