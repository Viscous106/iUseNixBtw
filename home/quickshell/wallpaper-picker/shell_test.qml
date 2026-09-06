// Headless tests for the two things shell.qml's carousel depends on that are
// not visible in the running UI:
//
//   1. That navigating between folders with the SAME entry count actually
//      updates the model. The whole reactive-preview scheme hangs off
//      FolderListModel settling; if `count` never changed on a same-count
//      transition, `_rows` would never be rebuilt and the picker would keep
//      showing the folder you just left. The fixture is built so that EVERY
//      navigation here is a same-count transition.
//   2. That the stale-model guard used by shell.qml rejects exactly the reads
//      that are stale and no others.
//   3. Applier's exit-code signals, which shell.qml now uses to decide when it
//      is safe to close.
//   4. That an apply requested while a preview is still running closes the
//      window on the APPLY's completion and not the preview's. Quickshell
//      QUEUES a command assigned to a running Process rather than dropping it,
//      so both run and both report an exit; if the window acted on the first it
//      would close before apply.sh had even started.
//
// Run from inside home/quickshell/wallpaper-picker/ — see
// tests/run-qml-tests.sh, which builds the fixture and invokes this.
// (tests/shell_test.sh is a different, unrelated test: it drives the real
// shell.qml under a live Wayland session and sets none of the WP_TEST_*
// variables this file reads.)
import QtQuick
import Quickshell

ShellRoot {
    id: t

    property int fails: 0
    function check(label, expected, actual) {
        if (String(expected) === String(actual)) console.log("  ok: " + label);
        else { console.log("  FAIL: " + label + " expected=" + expected + " actual=" + actual); t.fails++; }
    }

    Library { id: lib; rootDir: Quickshell.env("WP_TEST_ROOT") }
    Applier { id: applier; script: Quickshell.env("WP_TEST_OK") }

    readonly property string root: Quickshell.env("WP_TEST_ROOT")

    function parentDir(p) { const i = p.lastIndexOf("/"); return i > 0 ? p.substring(0, i) : "/"; }

    // The guard from shell.qml, verbatim.
    readonly property var currentEntry: {
        const e = lib.entry(lib.index);
        if (!e || t.parentDir(e.path) !== lib.dir)
            return null;
        return e;
    }
    function currentPath() { return currentEntry ? currentEntry.path : "null"; }

    // Raw, unguarded reads — how many were actually stale. If this stays 0 the
    // guard is untested, so the test asserts it is non-zero.
    property int staleSeen: 0
    property int guardViolations: 0
    readonly property string rawPath: {
        const e = lib.entry(lib.index);
        return e ? e.path : "";
    }
    onRawPathChanged: if (rawPath !== "" && t.parentDir(rawPath) !== lib.dir) t.staleSeen++;
    onCurrentEntryChanged: if (currentEntry && t.parentDir(currentEntry.path) !== lib.dir) t.guardViolations++;

    // Mirror of the state shell.qml uses to decide it may close. shell.qml
    // itself cannot be loaded headlessly (PanelWindow needs a Wayland backend —
    // "No PanelWindow backend loaded."), so the correlation predicate is
    // duplicated here; the assertions that matter, on which path each exit is
    // reported under, are against the real Applier.
    property bool applying: false
    property bool exiting: false
    property string awaitingPath: ""
    function awaitedPath() {
        if (t.exiting)  return applier.original;
        if (t.applying) return t.awaitingPath;
        return "";
    }
    property var exitPaths: []
    property int exitTriggers: 0
    property string exitTriggerPath: ""

    readonly property string previewFile: "/fixture/preview.png"
    readonly property string applyFile:   "/fixture/apply.png"

    property int okCount: 0
    property string okPath: ""
    property int failCount: 0
    property string failPath: ""
    property int failCode: -1

    Connections {
        target: applier
        function onApplySucceeded(path) {
            t.okCount++; t.okPath = path;
            t.exitPaths = t.exitPaths.concat([path]);
            // shell.qml's predicate, verbatim.
            if (t.awaitedPath() !== "" && path === t.awaitedPath()) {
                t.exitTriggers++; t.exitTriggerPath = path;   // this is where Qt.exit(0) happens
            }
        }
        function onApplyFailed(path, code) {
            t.failCount++; t.failPath = path; t.failCode = code;
            t.exitPaths = t.exitPaths.concat([path]);
        }
    }

    property int step: 0
    Timer {
        running: true; interval: 300; repeat: true
        onTriggered: {
            t.step++;
            switch (t.step) {

            // ── same-count navigation ─────────────────────────────────────────
            case 1:
                check("root lists 2 entries",   2,     lib.count);
                check("root entry 0 is A",      "A",   lib.entry(0).name);
                break;
            case 2:
                lib.descend();                                  // root(2) -> A(2)
                break;
            case 3:
                check("descend changed dir",    t.root + "/A",          lib.dir);
                check("descend same count",     2,                      lib.count);
                check("descend updated model",  t.root + "/A/1.png",    t.currentPath());
                break;
            case 4:
                lib.ascend();                                   // A(2) -> root(2)
                break;
            case 5:
                check("ascend changed dir",     t.root,                 lib.dir);
                check("ascend same count",      2,                      lib.count);
                check("ascend updated model",   t.root + "/A",          t.currentPath());
                break;
            case 6:
                lib.move(1); lib.descend();                     // root(2) -> B(2)
                break;
            case 7:
                check("sibling descend dir",    t.root + "/B",          lib.dir);
                check("sibling same count",     2,                      lib.count);
                check("sibling updated model",  t.root + "/B/1.png",    t.currentPath());
                break;

            // ── the guard ─────────────────────────────────────────────────────
            case 8:
                check("stale reads do occur",   true,  t.staleSeen > 0);
                check("guard let none through", 0,     t.guardViolations);
                break;

            // ── Applier exit-code signals ─────────────────────────────────────
            case 9:
                applier.script = Quickshell.env("WP_TEST_OK");
                applier.applyNow("/fixture/ok.png");
                break;
            case 10:
                check("applySucceeded fired",   1,                    t.okCount);
                check("applySucceeded path",    "/fixture/ok.png",    t.okPath);
                check("no spurious failure",    0,                    t.failCount);
                break;
            case 11:
                applier.script = Quickshell.env("WP_TEST_FAIL");
                applier.applyNow("/fixture/bad.png");
                break;
            case 12:
                check("applyFailed fired",      1,                    t.failCount);
                check("applyFailed path",       "/fixture/bad.png",   t.failPath);
                check("applyFailed code",       3,                    t.failCode);
                check("no extra success",       1,                    t.okCount);
                break;

            // ── an apply requested while a preview is still running ───────────
            case 13:
                applier.script = Quickshell.env("WP_TEST_SLOW");
                t.exitPaths = []; t.okCount = 0; t.failCount = 0;
                applier.applyNow(t.previewFile);        // the preview starts
                break;
            case 14:
                // Still running (the stub sleeps 0.8 s, this is 300 ms later).
                // Exactly what activate() does on Enter.
                t.awaitingPath = t.applyFile;
                t.applying = true;
                applier.applyNow(t.applyFile);
                break;
            case 20:
                check("both commands ran",        2,                 t.exitPaths.length);
                check("1st exit is the preview",  t.previewFile,     t.exitPaths[0]);
                check("2nd exit is the apply",    t.applyFile,       t.exitPaths[1]);
                check("preview did not close it", 1,                 t.exitTriggers);
                check("the apply closed it",      t.applyFile,       t.exitTriggerPath);
                break;

            case 21:
                console.log(t.fails === 0 ? "ALL PASS" : "FAILURES=" + t.fails);
                Qt.exit(t.fails === 0 ? 0 : 1);
                break;
            }
        }
    }
}
