// Folder navigation over the wallpaper library.
//
// Qt.labs.folderlistmodel, not caelestia's FileSystemModel — the latter comes
// from Caelestia.Models, a private C++ plugin unavailable outside that shell.
import QtQuick
import Quickshell
import Qt.labs.folderlistmodel

Item {
    id: root

    property string rootDir: Quickshell.env("HOME") + "/Pictures/wallpapers"
    property string dir: _root
    property string filter: ""
    property int index: 0

    // Trailing slashes break containment: `dir` is always slash-free after a
    // descend (paths come from _strip), so a rootDir of "/x/" would never again
    // string-equal dir and ascend() could climb out of the library.
    readonly property string _root: rootDir.endsWith("/") && rootDir.length > 1
                                    ? rootDir.slice(0, -1) : rootDir

    readonly property var imageExts: ["*.jpg", "*.jpeg", "*.png", "*.webp", "*.gif"]
    readonly property var videoExts: ["*.mp4", "*.mkv", "*.webm"]

    // Rows surviving the filter, as indices into the underlying model.
    property var _rows: []

    readonly property int count: _rows.length

    readonly property string breadcrumb: {
        if (dir === _root)
            return "";
        return dir.substring(_root.length + 1);
    }

    function _strip(u) {
        const s = String(u);
        return s.startsWith("file://") ? s.substring(7) : s;
    }

    function _rebuild() {
        const rows = [];
        for (let i = 0; i < fm.count; i++) {
            const name = fm.get(i, "fileName");
            if (filter === "" || name.toLowerCase().includes(filter.toLowerCase()))
                rows.push(i);
        }
        _rows = rows;
        if (index >= rows.length)
            index = Math.max(0, rows.length - 1);
    }

    // Derived from videoExts (each entry "*.ext") rather than re-listing the
    // extensions, so this and videoExts cannot drift apart. (apply.sh holds a
    // third, authoritative copy of this same list — kind_of() there — which
    // must be kept in agreement with this one by hand.)
    function _isVideoName(lower) {
        return videoExts.some(pat => lower.endsWith(pat.slice(1)));
    }

    function entry(i) {
        if (i < 0 || i >= _rows.length)
            return null;
        const r = _rows[i];
        const name = fm.get(r, "fileName");
        const isDir = fm.get(r, "fileIsDir");
        const lower = name.toLowerCase();
        return {
            name: name,
            path: _strip(fm.get(r, "filePath")),
            isDir: isDir,
            isVideo: !isDir && _isVideoName(lower)
        };
    }

    function move(delta) {
        if (count === 0)
            return;
        index = Math.max(0, Math.min(count - 1, index + delta));
    }

    function descend() {
        const e = entry(index);
        if (!e || !e.isDir)
            return false;
        dir = e.path;
        filter = "";
        index = 0;
        return true;
    }

    function ascend() {
        if (dir === _root)
            return false;                     // never escape the library
        const cut = dir.lastIndexOf("/");
        dir = cut > 0 ? dir.substring(0, cut) : _root;
        filter = "";
        index = 0;
        return true;
    }

    // NOTE for consumers: FolderListModel repopulates ASYNCHRONOUSLY. After
    // descend(), ascend(), or a filter change, `count` and `entry()` may still
    // describe the PREVIOUS folder for one event-loop turn. Bind reactively or
    // react to a change signal — never call a navigation function and read the
    // model in the same tick.
    FolderListModel {
        id: fm
        folder: "file://" + root.dir
        showDirs: true
        showDirsFirst: true
        showDotAndDotDot: false
        sortField: FolderListModel.Name
        caseSensitive: false   // apply.sh lowercases before matching; match it
        nameFilters: root.imageExts.concat(root.videoExts)
        onCountChanged: root._rebuild()
    }

    onFilterChanged: _rebuild()
}
