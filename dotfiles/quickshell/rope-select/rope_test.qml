// Headless cover for the rope simulation ported from zephyr.
//
// The fragile part is not the maths, it is the WIRING: Rope builds its curve
// and dot lists at runtime by pushing Instantiator-created objects into
// ShapePath.pathElements, and then indexes the two lists against each other
// (dot i drives curve i-1). If push() ever stops populating those lists, or
// the off-by-one between them drifts, nothing throws -- the overlay just draws
// no ropes, which is invisible until someone takes a screenshot. These checks
// run without a compositor because Rope is a plain Item: it constructs and its
// Timer ticks even though nothing is ever rendered.

import QtQuick
import Quickshell

ShellRoot {
    property int fails: 0
    function check(label, expected, actual) {
        if (String(expected) === String(actual)) console.log("  ok: " + label);
        else { console.log("  FAIL: " + label + " expected=" + expected + " actual=" + actual); fails++; }
    }
    function checkThat(label, cond, detail) {
        if (cond) console.log("  ok: " + label);
        else { console.log("  FAIL: " + label + " (" + detail + ")"); fails++; }
    }

    // Anchored at the origin, pulled to a far corner.
    Rope {
        id: rope
        width: 1920; height: 1080
        anchorX: 0; anchorY: 0
        pullX: 800; pullY: 600
    }

    Timer {
        running: true
        // ~30 simulation ticks at 60fps: long enough for the pinned tail to be
        // pulled into place and for the free segments to have visibly moved.
        interval: 500
        onTriggered: {
            check("one curve per segment", rope.segments, rope.curveCount());
            // +1: the dot list carries the fixed start point at index 0 as well
            // as one dot per segment.
            check("dots = segments + 1",   rope.segments + 1, rope.dotCount());

            // The start point is the fixed end of the rope and must never be
            // moved by the simulation.
            check("start dot pinned to anchor x", 0, rope.dotX(0));
            check("start dot pinned to anchor y", 0, rope.dotY(0));

            // The tail is snapped onto the pull target every tick -- but NOT
            // left there: the snap happens before the shared `centerX += vx`
            // step at the end of the loop, so the tail always ends a few px off
            // the target, jittering around it. That overshoot is the springy
            // look, not a defect, so this asserts proximity rather than
            // equality. A regression that unhooked the tail entirely would
            // leave it hundreds of px away and still be caught.
            const last = rope.segments;
            const tailOff = Math.sqrt(Math.pow(rope.dotX(last) - 800, 2)
                                    + Math.pow(rope.dotY(last) - 600, 2));
            checkThat("tail dot tracks the pull point", tailOff < 25,
                      "off by " + tailOff.toFixed(1) + "px, at "
                      + rope.dotX(last).toFixed(1) + "," + rope.dotY(last).toFixed(1));

            // A free mid-segment must actually be simulating -- it starts at
            // (index, index) and gets dragged toward the pull point.
            const mid = 3;
            checkThat("mid dot has moved from its initial position",
                      rope.dotX(mid) !== mid || rope.dotY(mid) !== mid,
                      "still at " + rope.dotX(mid) + "," + rope.dotY(mid));
            checkThat("mid dot stays on screen",
                      rope.dotX(mid) >= -2000 && rope.dotX(mid) <= 4000
                      && rope.dotY(mid) >= -2000 && rope.dotY(mid) <= 4000,
                      "diverged to " + rope.dotX(mid) + "," + rope.dotY(mid));
            checkThat("mid dot is a real number, not NaN",
                      !isNaN(rope.dotX(mid)) && !isNaN(rope.dotY(mid)),
                      "got " + rope.dotX(mid) + "," + rope.dotY(mid));

            // Each curve point tracks its dot, which is what actually draws the
            // line. Curve i-1 is driven by dot i.
            checkThat("curve points track their dots",
                      rope.curveX(last - 1) === rope.dotX(last)
                      && rope.curveY(last - 1) === rope.dotY(last),
                      "curve=" + rope.curveX(last - 1) + "," + rope.curveY(last - 1)
                      + " dot=" + rope.dotX(last) + "," + rope.dotY(last));

            console.log(fails === 0 ? "ALL PASS" : "FAILURES=" + fails);
            Qt.exit(fails === 0 ? 0 : 1);
        }
    }
}
