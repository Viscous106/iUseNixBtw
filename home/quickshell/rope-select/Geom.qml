// The selection overlay: one fullscreen layer surface per monitor.
//
// Ported from flickowoa/zephyr, quickshell/windows/Geom.qml
// (https://github.com/flickowoa/zephyr). That repo ships no LICENSE file.
// The visual design -- dimmed backdrop with a cleared cutout, a solid frame and
// four corner discs, and a rope hauled in from each screen corner -- is
// upstream's.
//
// Changed from upstream:
//   * The socket is gone. Upstream kept a resident quickshell holding this
//     window and poked it over /tmp/quickshell_zephyr.sock with socat; here the
//     process is launched per selection and reports via signals, so there is no
//     always-on instance and no socket to go stale.
//   * Geometry maths moved to Selection.qml, where it can be tested headlessly.
//   * Added Escape and right-click to cancel. Upstream had no way out but to
//     complete a drag.
//   * Added keyboardFocus, without which Escape never arrives.
//   * Multi-monitor: upstream emitted surface-local coordinates, which are
//     wrong on any screen that is not at the origin. Selection adds the screen
//     offset so the output is global, like slurp's.
import QtQuick
import Quickshell
import Quickshell.Wayland

PanelWindow {
    id: geom

    // Set by the Variants in shell.qml -- one instance per connected screen.
    required property var modelData
    screen: modelData

    property color primaryColour: "#ffb68e"
    property color surfaceColour: "#1a120d"

    // Thickness of the frame drawn around the selection, and the basis for the
    // corner disc radius.
    property int borderWidth: 6

    signal selected(string geometry)
    signal cancelled

    // Overlay so the selector covers everything, fullscreen windows included.
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.namespace: "rope-select"
    // Exclusive, or Escape never reaches the QML: a layer surface gets no key
    // events at all by default, and OnDemand would require a click first --
    // by which point the drag has already started.
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.Exclusive
    // Ignore: a selector must never push other windows around while it is up.
    exclusionMode: ExclusionMode.Ignore

    color: "transparent"

    anchors {
        top: true
        left: true
        right: true
        bottom: true
    }

    Selection {
        id: sel

        screenX: geom.modelData.x
        screenY: geom.modelData.y

        // Before the first press both ends sit at the centre of the screen, so
        // the ropes hang toward the middle on appear rather than whipping in
        // from a corner. Pressing assigns these, which breaks the bindings --
        // that is intended, they are start values and not a live centre.
        anchorX: geom.width / 2
        anchorY: geom.height / 2
        cursorX: geom.width / 2
        cursorY: geom.height / 2
    }

    // Escape is delivered to the focused item, not to the window, so the
    // keyboardFocus above is necessary but not sufficient -- something inside
    // has to hold focus too.
    Item {
        anchors.fill: parent
        focus: true
        Keys.onEscapePressed: geom.cancelled()
    }

    Canvas {
        id: canvas
        anchors.fill: parent

        onPaint: {
            const ctx = getContext("2d");
            ctx.reset();

            // Dim everything...
            ctx.fillStyle = geom.surfaceColour;
            ctx.globalAlpha = 0.8;
            ctx.fillRect(0, 0, width, height);
            ctx.globalAlpha = 1;

            // ...then lay the frame and corner discs down over the dimming...
            ctx.fillStyle = geom.primaryColour;
            ctx.fillRect(sel.x1 - geom.borderWidth, sel.y1 - geom.borderWidth, sel.selWidth + geom.borderWidth * 2, sel.selHeight + geom.borderWidth * 2);

            const r = geom.borderWidth * 4;
            for (const corner of [[sel.x1, sel.y1], [sel.x2, sel.y1], [sel.x1, sel.y2], [sel.x2, sel.y2]]) {
                ctx.beginPath();
                ctx.arc(corner[0], corner[1], r, 0, 2 * Math.PI);
                ctx.fill();
            }

            // ...and punch the selection itself back out to fully transparent,
            // which is what turns the frame into a frame and lets you see what
            // you are actually about to capture.
            ctx.clearRect(sel.x1, sel.y1, sel.selWidth, sel.selHeight);
        }
    }

    // One rope per screen corner, each hauled to the nearest selection corner.
    Rope {
        anchors.fill: parent
        strokeColour: geom.primaryColour
        anchorX: 0
        anchorY: 0
        pullX: sel.x1
        pullY: sel.y1
    }

    Rope {
        anchors.fill: parent
        strokeColour: geom.primaryColour
        anchorX: geom.width
        anchorY: 0
        pullX: sel.x2
        pullY: sel.y1
    }

    Rope {
        anchors.fill: parent
        strokeColour: geom.primaryColour
        anchorX: 0
        anchorY: geom.height
        pullX: sel.x1
        pullY: sel.y2
    }

    Rope {
        anchors.fill: parent
        strokeColour: geom.primaryColour
        anchorX: geom.width
        anchorY: geom.height
        pullX: sel.x2
        pullY: sel.y2
    }

    // Last, so it sits above the canvas and the ropes and actually gets the
    // events.
    MouseArea {
        anchors.fill: parent
        cursorShape: Qt.CrossCursor
        acceptedButtons: Qt.LeftButton | Qt.RightButton

        onPressed: mouse => {
            if (mouse.button === Qt.RightButton) {
                geom.cancelled();
                return;
            }
            sel.anchorX = mouse.x;
            sel.anchorY = mouse.y;
            sel.cursorX = mouse.x;
            sel.cursorY = mouse.y;
            canvas.requestPaint();
        }

        onPositionChanged: mouse => {
            sel.cursorX = mouse.x;
            sel.cursorY = mouse.y;
            canvas.requestPaint();
        }

        onReleased: mouse => {
            if (mouse.button === Qt.RightButton)
                return;
            // A click with no drag is a cancel, not a 0x0 capture -- grim would
            // fail on the latter and leave an empty file behind.
            if (sel.valid)
                geom.selected(sel.geometry());
            else
                geom.cancelled();
        }
    }
}
