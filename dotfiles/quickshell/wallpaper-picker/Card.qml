// One card in the carousel.
//
// The frame is sheared -13 degrees; the image inside is counter-sheared +13 so
// the card is a parallelogram while the photograph itself stays undistorted.
import QtQuick
import Qt.labs.folderlistmodel
import Quickshell
import Quickshell.Io

Item {
    id: root

    property var theme
    property string path: ""
    property string label: ""
    property bool isDir: false
    property bool isVideo: false
    property bool selected: false
    property int distance: 0            // 0 = selected, grows outward

    // Gates the Image so off-window cards cost nothing. Repeater instantiates
    // every delegate and `visible: false` does NOT stop an Image loading.
    property bool active: true

    // Image extensions, passed down from Library so this is not a fourth copy
    // of the list. apply.sh holds the authoritative one; Library derives from
    // it; this mirrors Library's.
    property var imageExts: []

    // Folder cards preview the first image inside the folder. Only peeked when
    // the card is active, so off-window folders cost no directory read.
    FolderListModel {
        id: folderPeek
        folder: (root.isDir && root.active && root.path !== "") ? "file://" + root.path : ""
        showDirs: false
        showDotAndDotDot: false
        sortField: FolderListModel.Name
        caseSensitive: false
        nameFilters: root.imageExts
    }

    // "" when the folder holds no images (or is still loading) — the card then
    // falls back to the folder glyph rather than showing an empty frame.
    readonly property string folderThumb: {
        if (!isDir || folderPeek.count === 0)
            return "";
        const u = String(folderPeek.get(0, "filePath"));
        return u.startsWith("file://") ? u.substring(7) : u;
    }

    readonly property real skew: -13

    implicitWidth: selected ? 330 : 190
    implicitHeight: selected ? 206 : 132

    opacity: selected ? 1.0 : Math.max(0.30, 0.85 - distance * 0.16)

    Behavior on implicitWidth  { NumberAnimation { duration: 160; easing.type: Easing.OutCubic } }
    Behavior on implicitHeight { NumberAnimation { duration: 160; easing.type: Easing.OutCubic } }
    Behavior on opacity        { NumberAnimation { duration: 160 } }

    transform: Matrix4x4 {
        matrix: Qt.matrix4x4(1, Math.tan(root.skew * Math.PI / 180), 0, 0,
                             0, 1, 0, 0,
                             0, 0, 1, 0,
                             0, 0, 0, 1)
    }

    // ── Video posters ──────────────────────────────────────────────────────
    // A QML Image cannot decode a video, so extract one frame to a cache file
    // and point the Image at that. Cached by mangled path, so it is generated
    // once per video and reused on every open.
    //
    // The mangled name alone is not a safe cache key: replacing "/", "." and
    // " " all with "_" collapses distinct paths onto the same string (e.g.
    // "a/b.mp4", "a.b.mp4" and "a b mp4" all mangle to "a_b_mp4"), so one
    // video's poster could be served for a completely different video. A
    // hash of the full, unmangled path is appended to disambiguate; the
    // mangled prefix is kept only so the cache directory stays human-readable.
    function _hashPath(str) {
        // FNV-1a 32-bit — fast, deterministic, good avalanche for short
        // strings. Not cryptographic, but collisions between the handful of
        // paths in a real wallpaper library are practically impossible.
        let h = 0x811c9dc5;
        for (let i = 0; i < str.length; i++) {
            h ^= str.charCodeAt(i);
            h = Math.imul(h, 0x01000193);
        }
        return (h >>> 0).toString(16);
    }

    readonly property string posterPath: {
        if (!isVideo || path === "")
            return "";
        const key = path.replace(/[\/. ]/g, "_") + "_" + root._hashPath(path);
        return Quickshell.env("HOME") + "/.cache/wallpaper-picker/" + key + ".jpg";
    }

    property bool _posterReady: false

    Process {
        id: posterProc
        // -s 480: match the Image sourceSize below. -f: overwrite a stale file.
        command: ["ffmpegthumbnailer", "-i", root.path, "-o", root.posterPath, "-s", "480", "-f"]
        onExited: root._posterReady = (exitCode === 0)
    }

    FileView {
        id: posterCheck
        path: root.posterPath
        onLoaded: root._posterReady = true
        // Not cached yet — generate it. A failure leaves _posterReady false and
        // the card falls back to the plain surface plus its ▶ badge.
        onLoadFailed: if (root.isVideo && root.path !== "") posterProc.running = true
    }

    Rectangle {
        id: frame
        anchors.fill: parent
        radius: 6
        clip: true
        color: root.theme ? root.theme.surfaceHigh : "#201f23"
        border.width: root.selected ? 2 : 1
        border.color: root.selected
            ? (root.theme ? root.theme.primary : "#c2c1ff")
            : Qt.rgba(1, 1, 1, 0.10)

        // Folder card: a glyph, counter-sheared so it reads upright.
        Text {
            visible: root.isDir && root.folderThumb === ""
            anchors.centerIn: parent
            // nf-md-folder is U+F024B. U+F004B (used here originally) is
            // nf-md-arrow_down_bold_circle — which is why folders rendered as a
            // down-arrow in a circle.
            text: "󰉋"
            font.pixelSize: root.selected ? 44 : 28
            color: root.theme ? root.theme.primary : "#c2c1ff"
            transform: Matrix4x4 {
                matrix: Qt.matrix4x4(1, -Math.tan(root.skew * Math.PI / 180), 0, 0,
                                     0, 1, 0, 0, 0, 0, 1, 0, 0, 0, 0, 1)
            }
        }

        // Image card: over-wide and counter-sheared so the shear crops rather
        // than distorts, and no transparent wedge shows at the edges.
        Image {
            visible: root.isDir ? root.folderThumb !== ""
                   : (!root.isVideo || root._posterReady)
            anchors.centerIn: parent
            width: parent.width * 1.35
            height: parent.height
            // `active` first: an inactive card must not decode anything, and
            // blanking `path` instead would yield a bare "file://" and spam the
            // error log.
            source: !root.active ? ""
                  : root.isDir ? (root.folderThumb !== "" ? "file://" + root.folderThumb : "")
                  : root.isVideo ? (root._posterReady ? "file://" + root.posterPath : "")
                  : "file://" + root.path
            fillMode: Image.PreserveAspectCrop
            asynchronous: true
            cache: true
            sourceSize.width: 480               // decode small; 274 files stay cheap
            transform: Matrix4x4 {
                matrix: Qt.matrix4x4(1, -Math.tan(root.skew * Math.PI / 180), 0, 0,
                                     0, 1, 0, 0, 0, 0, 1, 0, 0, 0, 0, 1)
            }
        }

        // Video badge
        Rectangle {
            visible: root.isVideo
            anchors { right: parent.right; bottom: parent.bottom; margins: 6 }
            width: 22; height: 14; radius: 3
            color: Qt.rgba(0, 0, 0, 0.65)
            Text {
                anchors.centerIn: parent
                text: "▶"; font.pixelSize: 8; color: "#ffffff"
            }
        }
    }

    // Filename under the card. Lives OUTSIDE `frame` (which has clip: true and
    // is sheared) so the text is neither clipped nor slanted, and is counter-
    // sheared to cancel the root transform so it reads upright.
    Text {
        id: caption
        anchors { top: frame.bottom; topMargin: 6; horizontalCenter: frame.horizontalCenter }
        width: frame.width * 0.92
        text: root.label
        elide: Text.ElideRight
        horizontalAlignment: Text.AlignHCenter
        font.family: "Fira Code"
        font.pixelSize: root.selected ? 12 : 10
        color: root.selected
            ? (root.theme ? root.theme.primary : "#c2c1ff")
            : (root.theme ? root.theme.onSurface : "#e5e1e7")
        opacity: root.selected ? 1.0 : 0.65
        transform: Matrix4x4 {
            matrix: Qt.matrix4x4(1, -Math.tan(root.skew * Math.PI / 180), 0, 0,
                                 0, 1, 0, 0, 0, 0, 1, 0, 0, 0, 0, 1)
        }
        Behavior on opacity { NumberAnimation { duration: 160 } }
    }

    // Selection glow, drawn outside the clipped frame.
    Rectangle {
        visible: root.selected
        anchors.fill: frame
        anchors.margins: -5
        radius: 10
        color: "transparent"
        border.width: 5
        border.color: root.theme
            ? Qt.rgba(root.theme.primary.r, root.theme.primary.g, root.theme.primary.b, 0.20)
            : Qt.rgba(0.76, 0.76, 1, 0.20)
        z: -1
    }
}
