// One hanging rope: a chain of point masses fixed at (anchorX, anchorY) whose
// tail is dragged to (pullX, pullY), drawn as a single curved stroke.
//
// Ported from flickowoa/zephyr, quickshell/windows/Rope.qml
// (https://github.com/flickowoa/zephyr). That repo ships no LICENSE file.
// The simulation itself -- segment count, spring/damping constants, gravity,
// the three-segment pinned tail -- is upstream's and is kept as-is, because it
// is what gives the selector its look.
//
// Changed from upstream:
//   * Rectangle -> Item. Upstream painted a transparent Rectangle, which is a
//     filled rect that happens to draw nothing; the ropes are drawn entirely by
//     the Shape below.
//   * Dropped `import QtMultimedia`, `import Quickshell*` and the empty `dots`
//     Shape -- none were used.
//   * Dropped two dead locals in the tick (`line`, `toDist`).
//   * Stroke colour is a property instead of a Colors singleton, so this file
//     has no dependency on the rest of the config.
//   * Added the count/position readers at the bottom for rope_test.qml.
import QtQuick
import QtQuick.Shapes

Item {
    id: ropeRect

    // The fixed end. The rope hangs from here.
    property int anchorX: 0
    property int anchorY: 0

    // The dragged end -- a corner of the selection rectangle.
    property int pullX: 100
    property int pullY: 100

    property color strokeColour: "#ffb68e"

    property int segments: 10
    property int segment_length: 5

    // ── Test readers ────────────────────────────────────────────────────────
    // pathElements is populated at runtime by the Instantiators below, so its
    // contents cannot be asserted from outside without these.
    //
    // These MUST be functions, not readonly property bindings. ShapePath's
    // pathElements is a non-bindable list property -- Qt says so out loud
    // ("Expression depends on non-bindable properties: QQuickShapePath::
    // pathElements") -- so a binding is evaluated once, at construction, before
    // either Instantiator has pushed anything, and then never again. It would
    // report 0 forever while the ropes were in fact working perfectly.
    function curveCount(): int { return pathCurves.pathElements.length; }
    function dotCount(): int { return dotPath.pathElements.length; }
    function dotX(i: int): real { return dotPath.pathElements[i].centerX; }
    function dotY(i: int): real { return dotPath.pathElements[i].centerY; }
    function curveX(i: int): real { return pathCurves.pathElements[i].x; }
    function curveY(i: int): real { return pathCurves.pathElements[i].y; }

    Shape {
        id: rope
        anchors.fill: parent
        preferredRendererType: Shape.CurveRenderer

        // The visible stroke. One PathCurve per segment, pushed in below; each
        // one's x/y is driven by the matching dot in dotPath.
        ShapePath {
            id: pathCurves
            strokeColor: ropeRect.strokeColour
            fillColor: "transparent"
            strokeWidth: 6
            startX: ropeRect.anchorX
            startY: ropeRect.anchorY
        }

        Instantiator {
            model: ropeRect.segments
            onObjectAdded: (index, pathCurve) => pathCurves.pathElements.push(pathCurve)
            delegate: PathCurve {
                property int index: model.index
                x: 500
                y: 500
            }
        }

        // The simulation state. Never stroked -- dotPath exists only to hold
        // the point masses; index 0 is the fixed end, 1..segments are free.
        ShapePath {
            id: dotPath

            PathAngleArc {
                id: startPoint
                property int index: -1

                property double dx: 0
                property double dy: 0
                property double vx: 0
                property double vy: 0

                onCenterXChanged: pathCurves.startX = centerX
                onCenterYChanged: pathCurves.startY = centerY

                centerX: ropeRect.anchorX
                centerY: ropeRect.anchorY
                radiusX: 3; radiusY: 3
                startAngle: 0
                sweepAngle: 360
            }
        }

        Instantiator {
            model: ropeRect.segments
            onObjectAdded: (index, point) => dotPath.pathElements.push(point)
            delegate: PathAngleArc {
                property int index: model.index

                property double dx: 0
                property double dy: 0
                property double vx: 0
                property double vy: 0

                // Guarded, unlike upstream. The two Instantiators populate
                // their lists independently, so a dot can exist -- and start
                // emitting centerXChanged -- before the curve it drives has
                // been pushed. Upstream threw a TypeError on every one of those
                // early signals (about thirty per rope at startup). They are
                // harmless, because the next tick assigns again once both lists
                // are full, but they bury real errors in the log.
                onCenterXChanged: if (index < pathCurves.pathElements.length)
                    pathCurves.pathElements[index].x = centerX
                onCenterYChanged: if (index < pathCurves.pathElements.length)
                    pathCurves.pathElements[index].y = centerY

                Component.onCompleted: {
                    if (index < pathCurves.pathElements.length) {
                        pathCurves.pathElements[index].x = centerX;
                        pathCurves.pathElements[index].y = centerY;
                    }
                }

                // Seeded in a diagonal line out from the anchor. Any non-
                // coincident start works; coincident points would make the
                // normalisation below divide by zero on the first tick.
                centerX: ropeRect.anchorX + index
                centerY: ropeRect.anchorY + index
                radiusX: 1; radiusY: 1
                startAngle: 0
                sweepAngle: 360
            }
        }

        Timer {
            interval: 1000 / 60
            running: true
            repeat: true

            onTriggered: {
                // Walked tail-first so each point sees the already-updated
                // position of the one behind it.
                for (var i = ropeRect.segments; i > 0; i--) {
                    var point = dotPath.pathElements[i];
                    var prev = dotPath.pathElements[i - 1];

                    var prevDx = prev.centerX - point.centerX;
                    var prevDy = prev.centerY - point.centerY;

                    var prevDist = Math.sqrt(Math.pow(prevDx, 2) + Math.pow(prevDy, 2));
                    var prevExtend = prevDist - ropeRect.segment_length;

                    var vx = (prevDx / prevDist) * prevExtend;
                    var vy = (prevDy / prevDist) * prevExtend + 9.8;

                    // Two coincident points give prevDist 0 and hence NaN, which
                    // would poison centerX/centerY permanently -- once a point is
                    // NaN it never recovers and that rope silently vanishes.
                    if (isNaN(vx)) {
                        vx = 0;
                    }
                    if (isNaN(vy)) {
                        vy = 0;
                    }

                    if (i < ropeRect.segments - 3) {
                        var next = dotPath.pathElements[i + 1];

                        var nextDx = next.centerX - point.centerX;
                        var nextDy = next.centerY - point.centerY;

                        var nextDist = Math.sqrt(Math.pow(nextDx, 2) + Math.pow(nextDy, 2));
                        var nextExtend = nextDist - ropeRect.segment_length;

                        vx += (nextDx / nextDist) * nextExtend;
                        vy += (nextDy / nextDist) * nextExtend;
                    } else {
                        // The last few segments are snapped straight onto the
                        // pull target rather than simulated, so the rope end
                        // tracks the selection corner exactly instead of
                        // lagging behind it.
                        point.centerX = ropeRect.pullX;
                        point.centerY = ropeRect.pullY;
                    }

                    point.vx = point.vx * 0.5 + vx * 0.45;
                    point.vy = point.vy * 0.5 + vy * 0.45;

                    point.centerX += point.vx;
                    point.centerY += point.vy;
                }
            }
        }
    }
}
