// Lives at the config root, not tests/: Quickshell resolves QML components
// relative to the directory it is pointed at, and neither `import ".."` nor
// `import ".." as P` works — a test under tests/ cannot see Applier.qml.
// (Confirmed experimentally the same way theme_test.qml documents for Theme.)

import QtQuick
import Quickshell
import Quickshell.Io

ShellRoot {
    property int fails: 0
    function check(label, expected, actual) {
        if (String(expected) === String(actual)) console.log("  ok: " + label);
        else { console.log("  FAIL: " + label + " expected=" + expected + " actual=" + actual); fails++; }
    }

    property bool debounceDone: false
    property bool revertDone: false
    property bool soundDone: false
    function maybeFinish() {
        if (debounceDone && revertDone && soundDone) {
            console.log(fails === 0 ? "ALL PASS" : "FAILURES=" + fails);
            Qt.exit(fails === 0 ? 0 : 1);
        }
    }

    // --- Test 1: debounce collapses rapid previews to one, latest-wins. ---

    // A stub that appends its argument to $WP_TEST_LOG instead of setting a wallpaper.
    Applier { id: app; script: Quickshell.env("WP_TEST_STUB") }

    // --- Test 2: revert() deferred until an in-flight captureOriginal() lands. ---

    // A stub whose `--current` reply is deliberately slow, so revert() is
    // guaranteed to be called while the capture is still in flight.
    Applier { id: app2; script: Quickshell.env("WP_TEST_STUB2") }

    // --- Test 3: sound reaches apply.sh, and a revert restores it. ---

    // A stub whose original is a video that was playing WITH sound.
    Applier { id: app3; script: Quickshell.env("WP_TEST_STUB3") }

    Component.onCompleted: {
        // Three rapid schedules must collapse to exactly one apply, of the last path.
        app.schedulePreview("/tmp/a.png");
        app.schedulePreview("/tmp/b.png");
        app.schedulePreview("/tmp/c.png");

        // captureOriginal() and revert() fired in the same tick: if revert()
        // gave up just because _original was still "", WP_TEST_LOG2 would
        // stay empty forever instead of eventually getting the captured path.
        app2.captureOriginal();
        app2.revert();

        // applyNow runs at once; the revert waits for the capture, so the
        // log order is deterministic.
        app3.captureOriginal();
        app3.applyNow("/tmp/new.mp4", true);
        app3.revert();
    }

    FileView {
        id: readLog3
        path: Quickshell.env("WP_TEST_LOG3")
        watchChanges: true
        onFileChanged: reload()
    }

    property string lastText3: ""
    property int stableTicks3: 0
    property int attempts3: 0

    Timer {
        id: poll3
        running: true
        interval: 50
        repeat: true
        onTriggered: {
            attempts3++;
            readLog3.reload();
            const text = readLog3.text();
            if (text === lastText3) {
                stableTicks3++;
            } else {
                lastText3 = text;
                stableTicks3 = 0;
            }

            if ((attempts3 >= 10 && stableTicks3 >= 5) || attempts3 >= 80) {
                poll3.stop();
                const log = lastText3.trim().split("\n").filter(l => l !== "");
                check("sound apply + revert ran", "2", String(log.length));
                check("applyNow(sound) passes --sound", "/tmp/new.mp4 --sound", log[0]);
                check("revert restores original sound", "/tmp/original.mp4 --sound", log[1]);
                soundDone = true;
                maybeFinish();
            }
        }
    }

    FileView {
        id: readLog
        path: Quickshell.env("WP_TEST_LOG")
        watchChanges: true
        onFileChanged: reload()
    }

    FileView {
        id: readLog2
        path: Quickshell.env("WP_TEST_LOG2")
        watchChanges: true
        onFileChanged: reload()
    }

    // The debounced apply fires the stub process ~250ms after the last
    // schedulePreview(), and Quickshell's file reads land asynchronously on
    // top of that (Task 4's FolderListModel lesson applies here too) — so a
    // single fixed-delay read is a flaky way to observe the result. Instead
    // poll on a short bounded timer and only assert once the log content has
    // stopped changing for a few consecutive ticks (or we've clearly waited
    // long enough that a hang would mean something is actually broken).
    property string lastText: ""
    property int stableTicks: 0
    property int attempts: 0

    Timer {
        id: poll
        running: true
        interval: 50
        repeat: true
        onTriggered: {
            attempts++;
            readLog.reload();
            const text = readLog.text();
            if (text === lastText) {
                stableTicks++;
            } else {
                lastText = text;
                stableTicks = 0;
            }

            // Settled: unchanged for 5 straight polls (250ms of quiet) *after*
            // giving the 250ms debounce itself room to fire, or we've polled
            // for 4s straight and should stop waiting either way.
            if ((attempts >= 10 && stableTicks >= 5) || attempts >= 80) {
                poll.stop();
                const log = lastText.trim().split("\n").filter(l => l !== "");
                check("debounced to one call", "1", String(log.length));
                check("kept the last path", "/tmp/c.png", log[0]);
                debounceDone = true;
                maybeFinish();
            }
        }
    }

    // Same bounded-poll approach for the deferred-revert log, but with a
    // longer floor: the stub's `--current` reply is deliberately delayed
    // ~300ms, well past the point revert() is called, and only *then* does
    // the deferred revert fire the real apply.
    property string lastText2: ""
    property int stableTicks2: 0
    property int attempts2: 0

    Timer {
        id: poll2
        running: true
        interval: 50
        repeat: true
        onTriggered: {
            attempts2++;
            readLog2.reload();
            const text = readLog2.text();
            if (text === lastText2) {
                stableTicks2++;
            } else {
                lastText2 = text;
                stableTicks2 = 0;
            }

            if ((attempts2 >= 14 && stableTicks2 >= 5) || attempts2 >= 80) {
                poll2.stop();
                const log = lastText2.trim().split("\n").filter(l => l !== "");
                check("deferred revert still applied", "1", String(log.length));
                check("deferred revert used captured original", "/tmp/original.png", log[0]);
                revertDone = true;
                maybeFinish();
            }
        }
    }
}
