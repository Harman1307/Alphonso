import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import QtQuick
import QtMultimedia

PanelWindow {
    id: wallpaper

    property bool showing: UIState.activeDropdown === "wallpaper"
    property bool ready: false
    property var walls: []
    property var filtered: []
    property string query: ""
    property int selected: 0
    property var _wallsBuild: []
    property string currentWall: ""
    property int thumbVersion: 0
    property bool _skipInitialAnim: true
    property bool searching: false
    property bool _extractionRan: false

    property real smoothSelected: 0
    Behavior on smoothSelected {
        NumberAnimation { duration: _skipInitialAnim ? 0 : Animations.slow; easing.type: Easing.OutExpo }
    }

    property string cachePath: Quickshell.env("HOME") + "/.cache/wallpaper-thumbs"
    property string wallDir:   Quickshell.env("HOME") + "/wallpapers"

    property real br:     UIState.borderRadius
    property real brCard: Math.round(br * 0.75)
    property real brSm:   Math.round(br * 0.625)

    property real cardW: Math.min(screen ? screen.width * 0.46 : 680, 860)
    property real cardH: Math.round(cardW / 1.6)

    property real angleStep: 38

    visible: showing
    anchors { top: true; bottom: true; left: true; right: true }
    color: "transparent"
    exclusionMode: ExclusionMode.Ignore
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.namespace: "wallpaper"
    WlrLayershell.keyboardFocus: showing ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None

    function a(c, o) { return Qt.rgba(c.r, c.g, c.b, o) }

    Component.onCompleted: cacheLoadProc.running = true

    onSelectedChanged: smoothSelected = selected

    onShowingChanged: {
        if (showing) {
            query            = ""
            selected         = 0
            smoothSelected   = 0
            keyInput.text    = ""
            _skipInitialAnim = true
            searching        = false
            ready            = false
            currentWallProc.running = true
        } else {
            ready     = false
            searching = false
        }
    }

    Timer {
        id: listReadyDelay
        interval: 50
        onTriggered: {
            ready = true
            enableAnimDelay.start()
            focusDelay.start()
        }
    }

    Timer {
        id: focusDelay
        interval: 80
        onTriggered: keyInput.forceActiveFocus()
    }

    Timer {
        id: enableAnimDelay
        interval: 120
        onTriggered: _skipInitialAnim = false
    }

    function filterWalls(preserve) {
        var prevName = preserve && selected < filtered.length ? filtered[selected].name : ""
        var result   = walls.slice()
        if (query !== "") {
            var q = query.toLowerCase()
            result = result.filter(w => w.name.toLowerCase().includes(q))
            result.sort((a, b) => {
                var ai = a.name.toLowerCase().indexOf(q)
                var bi = b.name.toLowerCase().indexOf(q)
                if (ai !== bi) return ai - bi
                return a.name.length - b.name.length
            })
        }
        filtered = result
        if (prevName) {
            for (var i = 0; i < result.length; i++) {
                if (result[i].name === prevName) { selected = i; return }
            }
        }
        selected = 0
    }

    function selectCurrentWall() {
        for (var i = 0; i < filtered.length; i++) {
            if (filtered[i].name === currentWall) { selected = i; return }
        }
    }

    function applyWallpaper(wall) {
        if (!wall) return
        var path = wallDir + "/" + wall.name
        if (wall.isVideo) {
            var tempFrame = cachePath + "/temp_firstframe.jpg"
            applyProc.command = ["bash", "-c",
                "pkill mpvpaper 2>/dev/null; " +
                "ln -sf '" + path + "' '" + wallDir + "/current' && " +
                "ffmpeg -y -i '" + path + "' -ss 00:00:01 -vframes 1 -q:v 2 '" + tempFrame + "' 2>/dev/null && " +
                "awww img '" + tempFrame + "' " +
                "--transition-type wipe " +
                "--transition-angle 30 " +
                "--transition-duration 1.5 " +
                "--transition-fps 60 && " +
                "sleep 1.5 && " +
                "mpvpaper --fork -o 'no-audio loop panscan=1.0' '*' '" + path + "'"]
        } else {
            applyProc.command = ["bash", "-c",
                "pkill mpvpaper 2>/dev/null; " +
                "ln -sf '" + path + "' '" + wallDir + "/current' && " +
                "awww img '" + path + "' " +
                "--transition-type wipe " +
                "--transition-angle 30 " +
                "--transition-duration 1.5 " +
                "--transition-fps 60"]
        }
        applyProc.running = true
        currentWall = wall.name
    }

    function prettyName(name) {
        var dot = name.lastIndexOf(".")
        var n   = dot > 0 ? name.substring(0, dot) : name
        return n.replace(/[-_]/g, " ")
    }

    function pickRandom() {
        if (filtered.length < 2) return
        var idx = selected
        while (idx === selected)
            idx = Math.floor(Math.random() * filtered.length)
        selected = idx
    }

    function writeCache() {
        var arr = []
        for (var i = 0; i < walls.length; i++)
            arr.push({ name: walls[i].name })
        var json = JSON.stringify(arr)
        writeCacheProc.command = ["bash", "-c",
            "mkdir -p '" + cachePath + "' && cat > '" + cachePath + "/walls.json' << 'WCEOF'\n" + json + "\nWCEOF"]
        writeCacheProc.running = true
    }

    Process {
        id: cacheLoadProc
        command: ["cat", cachePath + "/walls.json"]
        stdout: SplitParser {
            splitMarker: ""
            onRead: data => {
                try {
                    var arr    = JSON.parse(data.trim())
                    var result = []
                    for (var i = 0; i < arr.length; i++) {
                        var name  = arr[i].name
                        var lower = name.toLowerCase()
                        result.push({
                            name:    name,
                            isVideo: lower.endsWith(".mp4") || lower.endsWith(".webm") || lower.endsWith(".mkv"),
                            isGif:   lower.endsWith(".gif")
                        })
                    }
                    walls        = result
                    filtered     = walls.slice()
                    thumbVersion = 1
                } catch(e) {}
            }
        }
    }

    Process {
        id: currentWallProc
        command: ["bash", "-c", "basename $(readlink -f $HOME/wallpapers/current) 2>/dev/null"]
        stdout: SplitParser { onRead: data => currentWall = data.trim() }
        onExited: {
            if (walls.length > 0) {
                filterWalls()
                selectCurrentWall()
                listReadyDelay.start()
            }
            _wallsBuild = []
            wallListProc.running = true
        }
    }

    Process {
        id: wallListProc
        command: ["bash", "-c", [
            "shopt -s nullglob",
            "for f in \"$HOME\"/wallpapers/*.{jpg,jpeg,png,gif,webp,mp4,webm,mkv}; do",
            "  [ -L \"$f\" ] && continue",
            "  basename \"$f\"",
            "done"
        ].join("\n")]
        stdout: SplitParser {
            onRead: data => {
                var line = data.trim()
                if (line.length === 0) return
                var lower = line.toLowerCase()
                _wallsBuild.push({
                    name:    line,
                    isVideo: lower.endsWith(".mp4") || lower.endsWith(".webm") || lower.endsWith(".mkv"),
                    isGif:   lower.endsWith(".gif")
                })
            }
        }
        onExited: {
            var seen   = {}
            var result = []
            for (var i = 0; i < _wallsBuild.length; i++) {
                if (!seen[_wallsBuild[i].name]) {
                    seen[_wallsBuild[i].name] = true
                    result.push(_wallsBuild[i])
                }
            }
            walls       = result
            _wallsBuild = []
            if (ready) {
                filterWalls(true)
            } else {
                filterWalls()
                selectCurrentWall()
                listReadyDelay.start()
            }
            writeCache()
            if (!_extractionRan) {
                _extractionRan = true
                colorExtractDelay.start()
            }
        }
    }

    Timer {
        id: colorExtractDelay
        interval: 1500
        onTriggered: colorExtractProc.running = true
    }

    Process {
        id: colorExtractProc
        command: ["bash", "-c", [
            "shopt -s nullglob",
            "CACHE=\"$HOME/.cache/wallpaper-thumbs\"",
            "LOCK=\"$CACHE/.extraction.lock\"",
            "mkdir -p \"$CACHE\"",
            "[ -f \"$LOCK\" ] && exit 0",
            "touch \"$LOCK\"",
            "trap 'rm -f \"$LOCK\"' EXIT",
            "",
            "for f in \"$HOME\"/wallpapers/*.{jpg,jpeg,png,gif,webp,mp4,webm,mkv}; do",
            "  [ -L \"$f\" ] && continue",
            "  name=$(basename \"$f\")",
            "  thumb=\"$CACHE/${name}.thumb.jpg\"",
            "  [ -f \"$thumb\" ] && continue",
            "  ext=\"${name##*.}\"",
            "  if [[ \"$ext\" == \"mp4\" || \"$ext\" == \"webm\" || \"$ext\" == \"mkv\" ]]; then",
            "    nice -n 19 ionice -c3 ffmpeg -y -i \"$f\" -ss 00:00:01 -vframes 1 -vf scale=600:-1 \"$thumb\" 2>/dev/null &",
            "  else",
            "    nice -n 19 magick \"${f}[0]\" -resize 600x -quality 85 \"$thumb\" 2>/dev/null &",
            "  fi",
            "done",
            "wait",
            "echo 'THUMBS_READY'"
        ].join("\n")]
        stdout: SplitParser {
            onRead: data => {
                var line = data.trim()
                if (line === "THUMBS_READY") thumbVersion++
            }
        }
    }

    Process { id: applyProc }
    Process { id: writeCacheProc }

    MouseArea {
        anchors.fill: parent
        onClicked: UIState.closeDropdowns()
    }

    TextInput {
        id: keyInput
        visible: false
        color: Colors.fg
        font { pixelSize: 11; family: "JetBrainsMono Nerd Font" }
        selectByMouse: true
        readOnly: !searching

        onTextChanged: {
            query = text.toLowerCase()
            filterWalls()
        }

        Keys.onPressed: function(event) {
            if (searching) {
                if (event.key === Qt.Key_Escape || event.key === Qt.Key_Return || event.key === Qt.Key_Enter) {
                    searching = false
                    event.accepted = true
                }
            } else {
                if (event.key === Qt.Key_Slash) {
                    text = ""
                    query = ""
                    searching = true
                    event.accepted = true
                } else if (event.key === Qt.Key_H || event.key === Qt.Key_Left) {
                    if (selected > 0) selected--
                    event.accepted = true
                } else if (event.key === Qt.Key_L || event.key === Qt.Key_Right) {
                    if (selected < filtered.length - 1) selected++
                    event.accepted = true
                } else if (event.key === Qt.Key_Home) {
                    selected = 0
                    event.accepted = true
                } else if (event.key === Qt.Key_End) {
                    selected = Math.max(0, filtered.length - 1)
                    event.accepted = true
                } else if (event.key === Qt.Key_PageUp) {
                    selected = Math.max(0, selected - 5)
                    event.accepted = true
                } else if (event.key === Qt.Key_PageDown) {
                    selected = Math.min(filtered.length - 1, selected + 5)
                    event.accepted = true
                } else if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) {
                    if (filtered.length > 0) applyWallpaper(filtered[selected])
                    event.accepted = true
                } else if (event.key === Qt.Key_R) {
                    pickRandom()
                    event.accepted = true
                } else if (event.key === Qt.Key_Escape) {
                    if (query !== "") {
                        keyInput.text = ""
                        query = ""
                        filterWalls()
                    } else {
                        UIState.closeDropdowns()
                    }
                    event.accepted = true
                }
            }
        }
    }

    Item {
        anchors.fill: parent
        opacity: ready ? 1 : 0
        scale:   ready ? 1 : Animations.enterScale

        Behavior on opacity {
            NumberAnimation { duration: Animations.medium; easing.type: Easing.OutCubic }
        }
        Behavior on scale {
            NumberAnimation { duration: Animations.slow; easing.type: Easing.OutBack; easing.overshoot: Animations.springPower }
        }

        Item {
            id: sceneRoot
            anchors.centerIn: parent
            width:  parent.width
            height: cardH
            clip:   true

            function slotX(offset) {
                var rad = offset * angleStep * Math.PI / 180
                return parent.width / 2 - cardW / 2 + Math.sin(rad) * (cardW * 0.82)
            }

            function slotAngle(offset) {
                return offset * angleStep
            }

            function slotScale(offset) {
                var rad = offset * angleStep * Math.PI / 180
                return Math.max(0.35, 0.5 + 0.5 * Math.cos(rad))
            }

            function slotOpacity(offset) {
                var dist = Math.abs(offset)
                if (dist < 0.5)  return 1.0
                if (dist < 1.5)  return 1.0  - (dist - 0.5) * 0.25
                if (dist < 2.5)  return 0.75 - (dist - 1.5) * 0.30
                if (dist < 3.0)  return 0.45 * (3.0 - dist) / 0.5
                return 0.0
            }

            function thumbSource(idx) {
                if (idx < 0 || idx >= filtered.length) return ""
                if (thumbVersion > 0)
                    return "file://" + cachePath + "/" + filtered[idx].name + ".thumb.jpg"
                return "file://" + wallDir + "/" + filtered[idx].name
            }

            Repeater {
                model: filtered

                Item {
                    id: slotItem
                    required property int index
                    required property var modelData

                    property real offset:    index - smoothSelected
                    property real absOffset: Math.abs(offset)
                    property bool isCenter:  index === selected

                    width:  cardW
                    height: cardH
                    x:      sceneRoot.slotX(offset)
                    y:      0
                    scale:  sceneRoot.slotScale(offset)
                    opacity: sceneRoot.slotOpacity(offset)
                    visible: absOffset < 3.0
                    z:      isCenter ? 999 : Math.round((1.0 - Math.min(absOffset, 2.0) / 2.0) * 100)

                    transform: Rotation {
                        origin.x: cardW / 2
                        origin.y: cardH / 2
                        axis { x: 0; y: 1; z: 0 }
                        angle: sceneRoot.slotAngle(slotItem.offset)
                    }

                    Rectangle {
                        id: slotRect
                        anchors.fill: parent
                        radius: br
                        color:  "#000"
                        clip:   true

                        Behavior on radius { NumberAnimation { duration: Animations.medium; easing.type: Easing.OutCubic } }

                        property bool isGif:   slotItem.isCenter && modelData.isGif
                        property bool isVideo: slotItem.isCenter && modelData.isVideo

                        Image {
                            anchors.fill: parent
                            source: slotItem.isCenter && !slotRect.isGif && !slotRect.isVideo
                                ? (thumbVersion > 0
                                    ? "file://" + cachePath + "/" + slotItem.modelData.name + ".thumb.jpg"
                                    : "file://" + wallDir   + "/" + slotItem.modelData.name)
                                : (!slotItem.isCenter
                                    ? sceneRoot.thumbSource(slotItem.index)
                                    : "")
                            onStatusChanged: {
                                if (status === Image.Error && slotItem.isCenter)
                                    source = "file://" + wallDir + "/" + slotItem.modelData.name
                            }
                            fillMode: slotItem.isCenter ? Image.PreserveAspectFit : Image.PreserveAspectCrop
                            sourceSize.width: slotItem.isCenter ? 1920 : 400
                            asynchronous: true
                            cache: true
                            visible: !slotRect.isGif && !slotRect.isVideo
                        }

                        Loader {
                            anchors.fill: parent
                            active: slotRect.isGif
                            sourceComponent: AnimatedImage {
                                anchors.fill: parent
                                source: "file://" + wallDir + "/" + slotItem.modelData.name
                                fillMode: Image.PreserveAspectFit
                                playing: true
                                asynchronous: true
                            }
                        }

                        Loader {
                            anchors.fill: parent
                            active: slotRect.isVideo
                            sourceComponent: Item {
                                anchors.fill: parent
                                MediaPlayer {
                                    id: slotVid
                                    source: "file://" + wallDir + "/" + slotItem.modelData.name
                                    loops: MediaPlayer.Infinite
                                    audioOutput: AudioOutput { muted: true }
                                    videoOutput: slotVidOut
                                    Component.onCompleted: play()
                                }
                                VideoOutput {
                                    id: slotVidOut
                                    anchors.fill: parent
                                    fillMode: VideoOutput.PreserveAspectFit
                                }
                            }
                        }

                        Rectangle {
                            anchors.fill: parent
                            color: slotItem.isCenter ? "transparent" : a("#000", 0.35)
                            Behavior on color { ColorAnimation { duration: Animations.medium } }
                        }

                        Item {
                            anchors { bottom: parent.bottom; left: parent.left; right: parent.right }
                            height: 56
                            visible: slotItem.isCenter
                            opacity: slotItem.isCenter ? 1 : 0
                            Behavior on opacity { NumberAnimation { duration: Animations.fast } }

                            Rectangle {
                                anchors.fill: parent
                                gradient: Gradient {
                                    GradientStop { position: 0.0; color: "transparent" }
                                    GradientStop { position: 1.0; color: a("#000", 0.72) }
                                }
                            }

                            Row {
                                anchors { left: parent.left; bottom: parent.bottom }
                                anchors { leftMargin: 18; bottomMargin: 14 }
                                spacing: 10

                                Text {
                                    text:  prettyName(slotItem.modelData.name)
                                    color: "#fff"
                                    font { pixelSize: 12; family: "JetBrainsMono Nerd Font" }
                                    anchors.verticalCenter: parent.verticalCenter
                                }

                                Text {
                                    visible: slotItem.modelData.name === currentWall
                                    text:    "●"
                                    color:   Colors.green
                                    font { pixelSize: 8; family: "JetBrainsMono Nerd Font" }
                                    anchors.verticalCenter: parent.verticalCenter
                                }
                            }
                        }

                        Rectangle {
                            anchors.fill: parent
                            radius: br
                            color:  "transparent"
                            border.width: slotItem.isCenter ? 2 : slotItem.modelData.name === currentWall ? 1.5 : 0
                            border.color: slotItem.modelData.name === currentWall ? Colors.green : Colors.accent
                            Behavior on border.color { ColorAnimation  { duration: Animations.fast } }
                            Behavior on border.width { NumberAnimation { duration: Animations.fast } }
                            Behavior on radius       { NumberAnimation { duration: Animations.medium; easing.type: Easing.OutCubic } }
                        }
                    }

                    MouseArea {
                        anchors.fill: parent
                        cursorShape: slotItem.isCenter ? Qt.PointingHandCursor : Qt.ArrowCursor
                        onClicked: {
                            if (slotItem.isCenter) applyWallpaper(slotItem.modelData)
                            else selected = slotItem.index
                        }
                    }
                }
            }

            MouseArea {
                anchors.fill: parent
                propagateComposedEvents: true
                z: -999
                onWheel: function(wheel) {
                    if (wheel.angleDelta.y > 0 || wheel.angleDelta.x > 0) {
                        if (selected > 0) selected--
                    } else {
                        if (selected < filtered.length - 1) selected++
                    }
                }
            }
        }

        Rectangle {
            id: emptyCard
            anchors.centerIn: sceneRoot
            width:  cardW
            height: cardH
            radius: br
            color:  a(Colors.bg, UIState.transparencyEnabled ? 0.7 : 0.92)
            border.width: 1
            border.color: a(Colors.fg, 0.06)
            visible: ready && filtered.length === 0
            opacity: visible ? 1 : 0
            scale:   visible ? 1 : 0.96

            Behavior on opacity { NumberAnimation { duration: Animations.medium; easing.type: Easing.OutCubic } }
            Behavior on scale   { NumberAnimation { duration: Animations.slow;   easing.type: Easing.OutBack; easing.overshoot: Animations.springPower } }
            Behavior on radius  { NumberAnimation { duration: Animations.medium; easing.type: Easing.OutCubic } }
            Behavior on color   { ColorAnimation  { duration: Animations.slow } }

            Column {
                anchors.centerIn: parent
                spacing: 18

                Text {
                    anchors.horizontalCenter: parent.horizontalCenter
                    text:  walls.length === 0 ? "󰏗" : "󰍉"
                    color: a(Colors.fg, 0.1)
                    font { pixelSize: 48; family: "JetBrainsMono Nerd Font" }
                }

                Column {
                    anchors.horizontalCenter: parent.horizontalCenter
                    spacing: 8

                    Text {
                        anchors.horizontalCenter: parent.horizontalCenter
                        text:  walls.length === 0 ? "Scanning wallpapers" : "No results"
                        color: a(Colors.fg, 0.4)
                        font { pixelSize: 14; family: "JetBrainsMono Nerd Font" }
                    }

                    Text {
                        anchors.horizontalCenter: parent.horizontalCenter
                        visible: query !== ""
                        text:    "\"" + query + "\""
                        color:   a(Colors.fg, 0.2)
                        font { pixelSize: 11; family: "JetBrainsMono Nerd Font" }
                    }
                }

                Row {
                    anchors.horizontalCenter: parent.horizontalCenter
                    spacing: 8
                    visible: filtered.length === 0 && query !== ""

                    Text {
                        text: "Press"
                        color: a(Colors.fg, 0.2)
                        font { pixelSize: 10; family: "JetBrainsMono Nerd Font" }
                        anchors.verticalCenter: parent.verticalCenter
                    }

                    Rectangle {
                        width:  escLbl.width + 14
                        height: 20
                        radius: brSm
                        color:  a(Colors.fg, 0.05)
                        border.width: 1
                        border.color: a(Colors.fg, 0.08)
                        anchors.verticalCenter: parent.verticalCenter

                        Text {
                            id: escLbl
                            anchors.centerIn: parent
                            text:  "Esc"
                            color: a(Colors.fg, 0.3)
                            font { pixelSize: 9; family: "JetBrainsMono Nerd Font" }
                        }
                    }

                    Text {
                        text: "to clear"
                        color: a(Colors.fg, 0.2)
                        font { pixelSize: 10; family: "JetBrainsMono Nerd Font" }
                        anchors.verticalCenter: parent.verticalCenter
                    }
                }
            }
        }

        Rectangle {
            id: searchBar
            anchors {
                top:              sceneRoot.bottom
                topMargin:        24
                horizontalCenter: parent.horizontalCenter
            }
            width:  200
            height: 34
            radius: brSm
            color:  a(Colors.bg, 0.35)
            border.width: 1
            border.color: searching ? a(Colors.accent, 0.3) : a(Colors.fg, 0.05)
            opacity: ready ? 1 : 0
            scale:   ready ? 1 : 0.95

            Behavior on border.color { ColorAnimation  { duration: Animations.fast } }
            Behavior on radius       { NumberAnimation { duration: Animations.medium; easing.type: Easing.OutCubic } }
            Behavior on opacity      { NumberAnimation { duration: Animations.medium; easing.type: Easing.OutCubic } }
            Behavior on scale        { NumberAnimation { duration: Animations.slow;   easing.type: Easing.OutBack; easing.overshoot: Animations.springPower } }

            Row {
                anchors.fill: parent
                anchors.leftMargin:  11
                anchors.rightMargin: 11
                spacing: 8

                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    text:  ""
                    color: searching ? Colors.accent : a(Colors.fg, 0.3)
                    font { pixelSize: 11; family: "JetBrainsMono Nerd Font" }
                    Behavior on color { ColorAnimation { duration: Animations.fast } }
                }

                Text {
                    width: parent.width - 40
                    anchors.verticalCenter: parent.verticalCenter
                    text: keyInput.text || (searching ? "" : "/ search")
                    color: keyInput.text ? Colors.fg : a(Colors.fg, 0.25)
                    font { pixelSize: 11; family: "JetBrainsMono Nerd Font" }
                    elide: Text.ElideRight
                }

                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    text:    "󰅖"
                    color:   clrMa.containsMouse ? Colors.fg : a(Colors.fg, 0.3)
                    font { pixelSize: 9; family: "JetBrainsMono Nerd Font" }
                    visible: keyInput.text.length > 0
                    Behavior on color { ColorAnimation { duration: Animations.fast } }

                    MouseArea {
                        id: clrMa
                        anchors.fill: parent
                        anchors.margins: -6
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: { keyInput.text = ""; keyInput.forceActiveFocus() }
                    }
                }
            }

            MouseArea {
                id: searchMa
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.IBeamCursor
                onClicked: {
                    if (!searching) { searching = true; keyInput.text = ""; query = "" }
                    keyInput.forceActiveFocus()
                }
            }
        }
    }
}