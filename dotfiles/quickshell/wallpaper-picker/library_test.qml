// Lives at the config root, not tests/: Quickshell resolves QML components
// relative to the directory it is pointed at, and neither `import ".."` nor
// `import ".." as P` works — a test under tests/ cannot see Library.qml.
// (Confirmed experimentally the same way theme_test.qml documents for Theme.)

import QtQuick
import Quickshell

ShellRoot {
    property int fails: 0
    function check(label, expected, actual) {
        if (String(expected) === String(actual)) console.log("  ok: " + label);
        else { console.log("  FAIL: " + label + " expected=" + expected + " actual=" + actual); fails++; }
    }

    Library { id: lib; rootDir: Quickshell.env("WP_TEST_ROOT") }

    // Containment regression: rootDir with a trailing slash must not defeat
    // the ascend() guard. dir is slash-free after any descend() (paths come
    // from _strip), so an un-normalised rootDir of ".../alpha/" would never
    // again string-equal dir, and ascend() could walk above the library root.
    Library { id: libSlash; rootDir: Quickshell.env("WP_TEST_ROOT_SLASH") }

    Timer {
        running: true; interval: 500; repeat: false
        onTriggered: {
            check("lists dirs first", "true", String(lib.entry(0).isDir));
            check("dir name",         "alpha", lib.entry(0).name);
            check("counts entries",   "3",    String(lib.count));   // alpha/, one.png, clip.mp4

            // FolderListModel with showDirsFirst + name-ascending sort yields:
            // alpha(0), clip.mp4(1), one.png(2) — the video is at index 1, not 2.
            check("video flagged",    "true", String(lib.entry(1).isVideo));
            check("pins ordering",    "one.png", lib.entry(2).name);

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

            // FolderListModel reloads its folder asynchronously (a background
            // scan posted back via a queued signal), so fm.count from the
            // ascend()s above hasn't settled within this synchronous handler.
            // One event-loop turn is enough for it to catch up; confirmed
            // experimentally with Qt.callLater before relying on it here.
            Qt.callLater(function() {
                lib.filter = "ONE";
                check("filter matches ci","1",    String(lib.count));
                lib.filter = "";

                // Normalised root: strip the trailing slash off the raw env
                // value the same way the component should, so this check
                // doesn't just restate the bug.
                const normRoot = String(Quickshell.env("WP_TEST_ROOT_SLASH")).replace(/\/$/, "");
                libSlash.descend();
                libSlash.ascend();
                libSlash.ascend();
                check("trailing-slash root contained", normRoot, libSlash.dir);

                console.log(fails === 0 ? "ALL PASS" : "FAILURES=" + fails);
                Qt.exit(fails === 0 ? 0 : 1);
            });
        }
    }
}
