// The geometry maths behind the region selector, with no visual parts at all.
//
// Split out of Geom.qml on purpose. Geom is a PanelWindow, and a PanelWindow
// needs a live Wayland compositor to instantiate -- so anything living inside
// it can only ever be checked by eye, on a real session. Everything here is
// pure arithmetic over four numbers, so it runs headless and is covered by
// selection_test.qml.
//
// Coordinates in, coordinates out:
//   anchor*/cursor* are LOCAL to one screen's layer surface, which is what the
//   MouseArea in Geom.qml reports. screenX/screenY are that screen's position
//   in the compositor's global layout. `grim -g` (and slurp's own output) use
//   GLOBAL coordinates, so the offset has to be added back on the way out --
//   without it, a selection on a right-hand monitor would crop the matching
//   rectangle from the left-hand one.
import QtQuick

QtObject {
    id: root

    // Position of this screen in the global layout.
    property int screenX: 0
    property int screenY: 0

    // Where the drag started, and where the pointer is now. Either may be the
    // larger of the pair -- a drag upwards and to the left is normal usage.
    property int anchorX: 0
    property int anchorY: 0
    property int cursorX: 0
    property int cursorY: 0

    readonly property int x1: Math.min(root.anchorX, root.cursorX)
    readonly property int y1: Math.min(root.anchorY, root.cursorY)
    readonly property int x2: Math.max(root.anchorX, root.cursorX)
    readonly property int y2: Math.max(root.anchorY, root.cursorY)

    readonly property int selWidth: root.x2 - root.x1
    readonly property int selHeight: root.y2 - root.y1

    // A bare click, or a drag degenerate in one axis, yields a zero-area
    // region. `grim -g "300,300 0x0"` exits non-zero with an empty file, so
    // these are reported invalid here and treated as a cancel by Geom.qml
    // rather than being handed on to grim.
    readonly property bool valid: root.selWidth > 0 && root.selHeight > 0

    // slurp's exact output format, which is what every caller already parses.
    function geometry(): string {
        return `${root.x1 + root.screenX},${root.y1 + root.screenY} ${root.selWidth}x${root.selHeight}`;
    }
}
