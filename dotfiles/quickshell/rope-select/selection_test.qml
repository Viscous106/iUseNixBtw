// Lives at the config root, not tests/: Quickshell resolves QML components
// relative to the directory it is pointed at, so a test under tests/ cannot
// see Selection.qml. Same reason as wallpaper-picker's *_test.qml files.
//
// Selection holds ALL the geometry maths, deliberately split out of Geom.qml,
// because Geom is a PanelWindow and a PanelWindow cannot be instantiated
// without a live compositor -- which means it cannot be tested headlessly.
// Everything that can be got wrong (min/max normalisation, global-coordinate
// offsetting for multi-monitor, the degenerate-drag cancel rule, the output
// format grim is handed) lives here instead, and is covered below.

import QtQuick
import Quickshell

ShellRoot {
    property int fails: 0
    function check(label, expected, actual) {
        if (String(expected) === String(actual)) console.log("  ok: " + label);
        else { console.log("  FAIL: " + label + " expected=" + expected + " actual=" + actual); fails++; }
    }

    // Plain top-left -> bottom-right drag on the primary screen.
    Selection { id: plain;  anchorX: 100; anchorY: 200; cursorX: 400; cursorY: 600 }

    // The same region dragged backwards (bottom-right -> top-left). Must
    // normalise to exactly the same string: slurp never emits a negative size
    // and neither may we, or `grim -g` fails.
    Selection { id: rev;    anchorX: 400; anchorY: 600; cursorX: 100; cursorY: 200 }

    // Mixed: drag right-to-left but top-to-bottom.
    Selection { id: mixed;  anchorX: 400; anchorY: 200; cursorX: 100; cursorY: 600 }

    // On a second monitor placed at x=1920. Local QML coords are per-surface,
    // but grim wants GLOBAL compositor coords, so screenX/screenY must be added.
    Selection { id: second; screenX: 1920; screenY: 0; anchorX: 10; anchorY: 20; cursorX: 110; cursorY: 70 }

    // Vertically stacked monitor.
    Selection { id: below;  screenX: 0; screenY: 1080; anchorX: 5; anchorY: 5; cursorX: 15; cursorY: 25 }

    // A bare click: no drag at all. `grim -g "0,0 0x0"` errors out, so this
    // must report invalid and be treated as a cancel rather than passed on.
    Selection { id: click;  anchorX: 300; anchorY: 300; cursorX: 300; cursorY: 300 }

    // A 1px-tall sliver is degenerate in one axis only -- still unusable.
    Selection { id: sliver; anchorX: 0; anchorY: 0; cursorX: 500; cursorY: 0 }

    // Smallest region that IS usable.
    Selection { id: tiny;   anchorX: 0; anchorY: 0; cursorX: 1; cursorY: 1 }

    Timer {
        running: true; interval: 100
        onTriggered: {
            check("plain: geometry",    "100,200 300x400", plain.geometry());
            check("plain: valid",       "true",            String(plain.valid));

            check("reversed: normalises to same string", "100,200 300x400", rev.geometry());
            check("mixed: normalises",  "100,200 300x400", mixed.geometry());

            check("second screen: x offset applied", "1930,20 100x50", second.geometry());
            check("below screen: y offset applied",  "5,1085 10x20",   below.geometry());

            check("click: invalid",     "false", String(click.valid));
            check("sliver: invalid",    "false", String(sliver.valid));
            check("tiny: valid",        "true",  String(tiny.valid));
            check("tiny: geometry",     "0,0 1x1", tiny.geometry());

            console.log(fails === 0 ? "ALL PASS" : "FAILURES=" + fails);
            Qt.exit(fails === 0 ? 0 : 1);
        }
    }
}
