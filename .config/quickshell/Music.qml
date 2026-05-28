import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import QtQuick
import Qt5Compat.GraphicalEffects

PanelWindow {
    id: music
    property bool showing: UIState.activeDropdown === "media"
    property bool _visible: false
    property bool pickerOpen: false
    property int pickerTab: 0
    property var gifFiles: []
    property bool gifsLoaded: false
    property int previewIndex: 0
    property int displayMode: UIState.mediaDisplayMode
    property bool vinylWithArt: UIState.mediaVinylWithArt
    property bool applyingGif: false
    property bool gifReady: false
    property real vinylRotation: 0
    property bool vinylHeld: false
    property real dragStartPos: 0
    property real dragStartAngle: 0
    property real lastX: 0
    property real totalDrag: 0
    property bool wasPlaying: false
    property string vinylAsset: "file://" + Quickshell.env("HOME") + "/.config/quickshell/assets/Vinyl.png"

    property real br:     UIState.borderRadius
    property real brCard: Math.round(br * 0.75)
    property real brSm:   Math.round(br * 0.625)
    property real brTile: Math.round(br * 0.875)

    visible: _visible
    anchors { top: true; bottom: true; left: true; right: true }
    margins.top: 38
    color: "transparent"
    exclusionMode: ExclusionMode.Ignore
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.namespace: "music"
    WlrLayershell.keyboardFocus: showing ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None

    function a(c, o) { return Qt.rgba(c.r, c.g, c.b, o) }
    function formatTime(s) {
        var m = Math.floor(s / 60)
        var sec = Math.floor(s % 60)
        return m + ":" + (sec < 10 ? "0" : "") + sec
    }
    function gifName(path) {
        var parts = path.split("/")
        return parts[parts.length - 1].replace(".gif", "")
    }
    function isVinylMode() { return displayMode === 1 }

    function grabVinyl(mx) {
        vinylSpin.stop()
        wasPlaying = UIState.mediaState === "playing"
        vinylHeld = true
        totalDrag = 0
        lastX = mx
        dragStartPos = UIState.mediaPos
        dragStartAngle = vinylRotation
        UIState.blockMediaPosUpdate = true
        if (wasPlaying) UIState.doMedia("play-pause")
    }
    function scrubVinyl(mx) {
        if (!vinylHeld) return
        var dx = mx - lastX
        lastX = mx
        totalDrag += dx
        vinylRotation = dragStartAngle + totalDrag * 0.8
        var newPos = Math.max(0, Math.min(UIState.mediaLen, dragStartPos + totalDrag * (UIState.mediaLen / 600)))
        UIState.mediaPos = newPos
        seekDebounce.restart()
    }
    function releaseVinyl() {
        if (!vinylHeld) return
        seekDebounce.stop()
        vinylHeld = false
        var finalPos = Math.max(0, Math.min(UIState.mediaLen, dragStartPos + totalDrag * (UIState.mediaLen / 600)))
        UIState.mediaPos = finalPos
        UIState.seekMedia(Math.floor(finalPos))
        if (wasPlaying) resumeDelay.start()
        else unblockPoll.start()
    }

    function tryStartVinyl() {
        if (isVinylMode() && UIState.mediaState === "playing" && _visible && !vinylHeld)
            vinylSpin.kickoff()
    }

    Timer { id: resumeDelay; interval: 150; onTriggered: { UIState.doMedia("play-pause"); unblockPoll.start() } }
    Timer { id: unblockPoll; interval: 2500; onTriggered: UIState.blockMediaPosUpdate = false }
    Timer {
        id: seekDebounce
        interval: 60
        onTriggered: {
            if (!vinylHeld || UIState.mediaLen <= 0) return
            var pos = Math.floor(Math.max(0, Math.min(UIState.mediaLen, dragStartPos + totalDrag * (UIState.mediaLen / 600))))
            UIState.seekMedia(pos)
        }
    }
    Timer {
        id: vinylStartDelay
        interval: 80
        onTriggered: tryStartVinyl()
    }

    NumberAnimation {
        id: vinylSpin
        target: music
        property: "vinylRotation"
        to: vinylRotation + 36000
        duration: 36000 * 120
        loops: Animation.Infinite
        easing.type: Easing.Linear
        function kickoff() {
            stop()
            from = vinylRotation
            to = vinylRotation + 36000
            start()
        }
    }

    Connections {
        target: UIState
        function onMediaStateChanged() {
            if (UIState.mediaState === "playing" && isVinylMode() && _visible && !vinylHeld)
                vinylSpin.kickoff()
            else if (UIState.mediaState !== "playing")
                vinylSpin.stop()
        }
    }

    onDisplayModeChanged: {
        if (isVinylMode() && UIState.mediaState === "playing" && _visible && !vinylHeld)
            vinylSpin.kickoff()
        else if (!isVinylMode())
            vinylSpin.stop()
    }

    onShowingChanged: {
        if (showing) {
            _visible = true
            pickerOpen = false
            pickerTab = displayMode
            if (displayMode === 0) reloadGif()
            vinylStartDelay.start()
        } else {
            closeDelay.start()
        }
    }

    function reloadGif() {
        gifReady = false
        gifImage.playing = false
        gifImage.source = ""
        gifClearDelay.restart()
    }

    Timer {
        id: gifClearDelay
        interval: 150
        onTriggered: {
            applyingGif = false
            gifImage.source = "file://" + UIState._gifPath + "/current.gif"
        }
    }

    Timer {
        id: closeDelay
        interval: Animations.exitDuration + 60
        onTriggered: { _visible = false; pickerOpen = false; vinylSpin.stop() }
    }

    Process { id: seekClickProc }

    function loadGifs() {
        gifFiles = []
        gifsLoaded = false
        previewIndex = 0
        gifListProc.running = true
    }

    function applyGif() {
        if (applyingGif || gifFiles.length === 0 || previewIndex >= gifFiles.length) return
        applyingGif = true
        gifApplyProc.command = ["cp", gifFiles[previewIndex], UIState._gifPath + "/current.gif"]
        gifApplyProc.running = true
    }

    Process {
        id: gifListProc
        command: ["bash", "-c", "find '" + UIState._gifPath + "' -maxdepth 1 -name '*.gif' ! -name 'current.gif' -type f 2>/dev/null | sort"]
        stdout: SplitParser {
            onRead: data => {
                var f = data.trim()
                if (f.length > 0) {
                    var cur = gifFiles.slice()
                    cur.push(f)
                    gifFiles = cur
                }
            }
        }
        onExited: {
            gifsLoaded = true
            if (gifFiles.length > 0)
                previewIndex = Math.min(UIState.gifIndex, gifFiles.length - 1)
        }
    }

    Process {
        id: gifApplyProc
        onExited: code => {
            if (code === 0) {
                UIState.setGifIndex(previewIndex)
                pickerOpen = false
                gifReloadDelay.start()
            } else {
                applyingGif = false
            }
        }
    }

    Timer { id: gifReloadDelay; interval: 400; onTriggered: reloadGif() }

    MouseArea {
        anchors.fill: parent
        onClicked: UIState.closeDropdowns()
    }

    Rectangle {
        id: card
        property real cardWidth: Math.min(parent.width - 40, 460)
        property real cardHeight: pickerOpen ? 420 : 210

        width: cardWidth
        height: cardHeight
        x: (parent.width - cardWidth) / 2
        y: showing ? 8 : -(cardHeight + 20)
        opacity: showing ? 1 : 0

        Behavior on y {
            NumberAnimation { duration: Animations.enterDuration; easing.type: Easing.OutExpo }
        }
        Behavior on opacity {
            NumberAnimation { duration: Animations.medium; easing.type: Easing.OutCubic }
        }
        Behavior on cardHeight {
            NumberAnimation { duration: Animations.medium; easing.type: Easing.OutExpo }
        }
        Behavior on color {
            ColorAnimation { duration: Animations.slow }
        }
        Behavior on radius {
            NumberAnimation { duration: Animations.medium; easing.type: Easing.OutCubic }
        }

        radius: br
        color: a(Colors.bg, UIState.transparencyEnabled ? 0.92 : 1)
        border.width: 1
        border.color: a(Colors.fg, 0.08)

        MouseArea { anchors.fill: parent }
        focus: showing

        Keys.onPressed: function(event) {
            if (event.key === Qt.Key_Escape) {
                if (pickerOpen) pickerOpen = false
                else UIState.closeDropdowns()
                event.accepted = true
            } else if (event.key === Qt.Key_Space && !pickerOpen) {
                UIState.doMedia("play-pause")
                event.accepted = true
            } else if (event.key === Qt.Key_N && !pickerOpen) {
                UIState.doMedia("next")
                event.accepted = true
            } else if (event.key === Qt.Key_P && !pickerOpen) {
                UIState.doMedia("previous")
                event.accepted = true
            } else if (event.key === Qt.Key_Left && pickerOpen && pickerTab === 0 && gifFiles.length > 1) {
                previewIndex = previewIndex > 0 ? previewIndex - 1 : gifFiles.length - 1
                event.accepted = true
            } else if (event.key === Qt.Key_Right && pickerOpen && pickerTab === 0 && gifFiles.length > 1) {
                previewIndex = previewIndex < gifFiles.length - 1 ? previewIndex + 1 : 0
                event.accepted = true
            } else if ((event.key === Qt.Key_Return || event.key === Qt.Key_Enter) && pickerOpen && pickerTab === 0) {
                if (previewIndex !== UIState.gifIndex) applyGif()
                event.accepted = true
            }
        }

        Item {
            anchors.fill: parent
            anchors.margins: 16

            Item {
                id: mainSection
                anchors { top: parent.top; left: parent.left; right: parent.right }
                height: 178

                Item {
                    anchors { top: parent.top; bottom: parent.bottom; left: parent.left; right: mediaSide.left; rightMargin: 14 }

                    Item {
                        id: titleMarqueeRoot
                        property real gap: 40
                        property real unitWidth: titleMarqueeA.implicitWidth + gap
                        property bool scrolling: titleMarqueeA.implicitWidth > parent.width
                        anchors { top: parent.top; left: parent.left; right: parent.right }
                        height: 20
                        clip: true

                        Row {
                            id: titleMarqueeTrack
                            anchors.verticalCenter: parent.verticalCenter
                            spacing: 0
                            Text {
                                id: titleMarqueeA
                                text: UIState.mediaTitle || "Nothing playing"
                                color: Colors.fg
                                font { pixelSize: 14; family: "JetBrainsMono Nerd Font"; bold: true }
                            }
                            Item { width: titleMarqueeRoot.gap; height: 1; visible: titleMarqueeRoot.scrolling }
                            Text {
                                text: UIState.mediaTitle || "Nothing playing"
                                color: Colors.fg
                                font { pixelSize: 14; family: "JetBrainsMono Nerd Font"; bold: true }
                                visible: titleMarqueeRoot.scrolling
                            }
                        }

                        NumberAnimation {
                            id: titleMarqueeAnim
                            target: titleMarqueeTrack
                            property: "x"
                            from: 0
                            to: -titleMarqueeRoot.unitWidth
                            duration: titleMarqueeRoot.unitWidth * 22
                            loops: Animation.Infinite
                            running: titleMarqueeRoot.scrolling
                            easing.type: Easing.Linear
                        }

                        Connections {
                            target: UIState
                            function onMediaTitleChanged() {
                                titleMarqueeAnim.stop()
                                titleMarqueeTrack.x = 0
                                if (titleMarqueeRoot.scrolling) titleMarqueeAnim.start()
                            }
                        }
                    }

                    Text {
                        anchors { top: titleMarqueeRoot.bottom; topMargin: 3; left: parent.left; right: parent.right }
                        text: UIState.mediaArtist || ""
                        color: a(Colors.fg, 0.45)
                        font { pixelSize: 11; family: "JetBrainsMono Nerd Font" }
                        elide: Text.ElideRight
                        visible: UIState.mediaArtist !== ""
                    }

                    Item {
                        anchors { left: parent.left; right: parent.right; bottom: controlRow.top; bottomMargin: 10 }
                        height: 20
                        visible: UIState.hasMedia

                        Text {
                            id: posText
                            anchors { left: parent.left; verticalCenter: parent.verticalCenter }
                            text: formatTime(UIState.mediaPos)
                            color: a(Colors.fg, 0.3)
                            font { pixelSize: 9; family: "JetBrainsMono Nerd Font" }
                        }

                        Item {
                            id: seekTrack
                            anchors { left: posText.right; leftMargin: 8; right: lenText.left; rightMargin: 8; verticalCenter: parent.verticalCenter }
                            height: 4

                            Rectangle {
                                anchors.fill: parent
                                radius: 2
                                color: a(Colors.fg, 0.08)
                            }
                            Rectangle {
                                width: UIState.mediaLen > 0 ? parent.width * (UIState.mediaPos / UIState.mediaLen) : 0
                                height: parent.height
                                radius: 2
                                color: Colors.accent
                            }
                            Rectangle {
                                x: UIState.mediaLen > 0 ? Math.max(0, seekTrack.width * (UIState.mediaPos / UIState.mediaLen) - 5) : -5
                                anchors.verticalCenter: parent.verticalCenter
                                width: seekMa.containsMouse ? 12 : 10
                                height: width; radius: width / 2
                                color: Colors.fg
                                visible: UIState.hasMedia
                                Behavior on width { NumberAnimation { duration: 120 } }
                            }

                            MouseArea {
                                id: seekMa
                                anchors.fill: parent
                                anchors.margins: -8
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: function(mouse) {
                                    if (UIState.mediaLen > 0) {
                                        var ratio = Math.max(0, Math.min(1, mouse.x / seekTrack.width))
                                        var pos = Math.floor(ratio * UIState.mediaLen)
                                        UIState.seekMedia(pos)
                                        UIState.mediaPos = pos
                                    }
                                }
                            }
                        }

                        Text {
                            id: lenText
                            anchors { right: parent.right; verticalCenter: parent.verticalCenter }
                            text: formatTime(UIState.mediaLen)
                            color: a(Colors.fg, 0.3)
                            font { pixelSize: 9; family: "JetBrainsMono Nerd Font" }
                        }
                    }

                    Row {
                        id: controlRow
                        anchors { bottom: parent.bottom; horizontalCenter: parent.horizontalCenter }
                        spacing: 8

                        Rectangle {
                            width: 34; height: 34; radius: brCard
                            color: prevMa.containsMouse ? a(Colors.fg, 0.08) : "transparent"
                            Behavior on color  { ColorAnimation { duration: 120 } }
                            Behavior on radius { NumberAnimation { duration: Animations.medium; easing.type: Easing.OutCubic } }
                            Text {
                                anchors.centerIn: parent
                                text: "󰒮"
                                color: prevMa.containsMouse ? Colors.fg : a(Colors.fg, 0.5)
                                font { pixelSize: 16; family: "JetBrainsMono Nerd Font" }
                                Behavior on color { ColorAnimation { duration: 120 } }
                            }
                            MouseArea {
                                id: prevMa
                                anchors.fill: parent
                                hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                                onClicked: UIState.doMedia("previous")
                            }
                        }

                        Rectangle {
                            width: 44; height: 44; radius: 22
                            anchors.verticalCenter: parent.verticalCenter
                            color: playMa.containsMouse ? Colors.accent : a(Colors.accent, 0.9)
                            scale: playMa.pressed ? 0.92 : 1
                            Behavior on color { ColorAnimation { duration: 120 } }
                            Behavior on scale { NumberAnimation { duration: 80 } }
                            Text {
                                anchors.centerIn: parent
                                text: UIState.mediaState === "playing" ? "󰏤" : "󰐊"
                                color: Colors.bg
                                font { pixelSize: 18; family: "JetBrainsMono Nerd Font" }
                            }
                            MouseArea {
                                id: playMa
                                anchors.fill: parent
                                cursorShape: Qt.PointingHandCursor
                                onClicked: UIState.doMedia("play-pause")
                            }
                        }

                        Rectangle {
                            width: 34; height: 34; radius: brCard
                            color: nextMa.containsMouse ? a(Colors.fg, 0.08) : "transparent"
                            Behavior on color  { ColorAnimation { duration: 120 } }
                            Behavior on radius { NumberAnimation { duration: Animations.medium; easing.type: Easing.OutCubic } }
                            Text {
                                anchors.centerIn: parent
                                text: "󰒭"
                                color: nextMa.containsMouse ? Colors.fg : a(Colors.fg, 0.5)
                                font { pixelSize: 16; family: "JetBrainsMono Nerd Font" }
                                Behavior on color { ColorAnimation { duration: 120 } }
                            }
                            MouseArea {
                                id: nextMa
                                anchors.fill: parent
                                hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                                onClicked: UIState.doMedia("next")
                            }
                        }
                    }
                }

                Item {
                    id: mediaSide
                    anchors { top: parent.top; bottom: parent.bottom; right: parent.right }
                    width: 158

                    AnimatedImage {
                        id: gifImage
                        anchors.fill: parent
                        fillMode: Image.PreserveAspectCrop
                        playing: false
                        cache: false
                        asynchronous: true
                        visible: displayMode === 0
                        opacity: status === Image.Ready ? 1 : 0
                        onStatusChanged: {
                            if (status === Image.Ready) {
                                gifReady = true
                                playing = UIState.mediaState === "playing"
                            }
                        }
                        Behavior on opacity { NumberAnimation { duration: 200 } }
                    }

                    Connections {
                        target: UIState
                        function onMediaStateChanged() {
                            if (gifImage.status === Image.Ready)
                                gifImage.playing = UIState.mediaState === "playing"
                        }
                    }

                    Item {
                        anchors.centerIn: parent
                        width: Math.min(mediaSide.width, mediaSide.height) - 8
                        height: width
                        visible: isVinylMode()

                        Item {
                            id: vinylDisc
                            anchors.centerIn: parent
                            width: parent.width
                            height: parent.width
                            rotation: vinylRotation

                            Rectangle {
                                anchors.centerIn: parent
                                width: parent.width
                                height: parent.width
                                radius: width / 2
                                color: "#0d0d0d"
                            }

                            Repeater {
                                model: 8
                                Rectangle {
                                    anchors.centerIn: parent
                                    width: parent.width * (0.97 - index * 0.016)
                                    height: width
                                    radius: width / 2
                                    color: "transparent"
                                    border.width: index % 2 === 0 ? 1 : 0.5
                                    border.color: index % 2 === 0 ? Qt.rgba(1, 1, 1, 0.055) : Qt.rgba(1, 1, 1, 0.022)
                                }
                            }

                            Item {
                                anchors.centerIn: parent
                                width: parent.width * 0.75
                                height: width

                                Image {
                                    id: artImage
                                    anchors.fill: parent
                                    source: vinylWithArt && UIState.mediaArtUrl !== "" ? UIState.mediaArtUrl : vinylAsset
                                    fillMode: Image.PreserveAspectCrop
                                    smooth: true
                                    asynchronous: true
                                    sourceSize: Qt.size(300, 300)
                                    visible: false
                                }

                                Rectangle {
                                    id: artMask
                                    anchors.fill: parent
                                    radius: width / 2
                                    visible: false
                                }

                                OpacityMask {
                                    anchors.fill: artImage
                                    source: artImage
                                    maskSource: artMask
                                }

                                Rectangle {
                                    anchors.fill: parent
                                    radius: width / 2
                                    color: "transparent"
                                    border.width: 1
                                    border.color: Qt.rgba(1, 1, 1, 0.07)
                                }
                            }

                            Rectangle {
                                anchors.centerIn: parent
                                width: parent.width * 0.08
                                height: width
                                radius: width / 2
                                color: "#1e1e1e"
                                border.width: 1
                                border.color: Qt.rgba(1, 1, 1, 0.1)
                            }

                            Rectangle {
                                anchors.centerIn: parent
                                width: 4; height: 4; radius: 2
                                color: Colors.accent
                                opacity: 0.9
                            }
                        }

                        MouseArea {
                            id: vinylMa
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: vinylHeld ? Qt.ClosedHandCursor : Qt.OpenHandCursor
                            onPressed: grabVinyl(mouseX)
                            onReleased: releaseVinyl()
                            onCanceled: releaseVinyl()
                            onPositionChanged: scrubVinyl(mouseX)
                        }
                    }

                    Rectangle {
                        anchors { top: parent.top; right: parent.right }
                        width: 22; height: 22; radius: brSm
                        color: editMa.containsMouse ? a(Colors.accent, 0.2) : a(Colors.fg, 0.06)
                        Behavior on color  { ColorAnimation { duration: 120 } }
                        Behavior on radius { NumberAnimation { duration: Animations.medium; easing.type: Easing.OutCubic } }
                        Text {
                            anchors.centerIn: parent
                            text: "󰏫"
                            color: editMa.containsMouse ? Colors.accent : a(Colors.fg, 0.35)
                            font { pixelSize: 10; family: "JetBrainsMono Nerd Font" }
                            Behavior on color { ColorAnimation { duration: 120 } }
                        }
                        MouseArea {
                            id: editMa
                            anchors.fill: parent; anchors.margins: -4
                            hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                            onClicked: {
                                if (!pickerOpen) { loadGifs(); pickerOpen = true }
                                else pickerOpen = false
                            }
                        }
                    }
                }
            }

            Rectangle {
                anchors { top: mainSection.bottom; topMargin: 6; left: parent.left; right: parent.right }
                height: 1
                color: a(Colors.fg, 0.05)
                visible: pickerOpen
            }

            Item {
                anchors { top: mainSection.bottom; topMargin: 14; left: parent.left; right: parent.right; bottom: parent.bottom }
                visible: pickerOpen
                opacity: pickerOpen ? 1 : 0
                Behavior on opacity { NumberAnimation { duration: 200 } }

                Row {
                    id: tabRow
                    anchors { top: parent.top; left: parent.left }
                    spacing: 6

                    Rectangle {
                        width: gifTabLabel.implicitWidth + 20
                        height: 26; radius: brSm
                        color: pickerTab === 0 ? a(Colors.accent, 0.15) : gifTabMa.containsMouse ? a(Colors.fg, 0.06) : a(Colors.fg, 0.03)
                        border.width: pickerTab === 0 ? 1 : 0
                        border.color: a(Colors.accent, 0.3)
                        Behavior on color  { ColorAnimation { duration: 120 } }
                        Behavior on radius { NumberAnimation { duration: Animations.medium; easing.type: Easing.OutCubic } }
                        Text {
                            id: gifTabLabel
                            anchors.centerIn: parent
                            text: "GIF"
                            color: pickerTab === 0 ? Colors.accent : a(Colors.fg, 0.35)
                            font { pixelSize: 9; family: "JetBrainsMono Nerd Font"; bold: true; letterSpacing: 0.8 }
                            Behavior on color { ColorAnimation { duration: 120 } }
                        }
                        MouseArea {
                            id: gifTabMa
                            anchors.fill: parent
                            hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                            onClicked: { pickerTab = 0; displayMode = 0; UIState.setMediaDisplayMode(0) }
                        }
                    }

                    Rectangle {
                        width: vinylTabLabel.implicitWidth + 20
                        height: 26; radius: brSm
                        color: pickerTab === 1 ? a(Colors.accent, 0.15) : vinylTabMa.containsMouse ? a(Colors.fg, 0.06) : a(Colors.fg, 0.03)
                        border.width: pickerTab === 1 ? 1 : 0
                        border.color: a(Colors.accent, 0.3)
                        Behavior on color  { ColorAnimation { duration: 120 } }
                        Behavior on radius { NumberAnimation { duration: Animations.medium; easing.type: Easing.OutCubic } }
                        Text {
                            id: vinylTabLabel
                            anchors.centerIn: parent
                            text: "VINYL"
                            color: pickerTab === 1 ? Colors.accent : a(Colors.fg, 0.35)
                            font { pixelSize: 9; family: "JetBrainsMono Nerd Font"; bold: true; letterSpacing: 0.8 }
                            Behavior on color { ColorAnimation { duration: 120 } }
                        }
                        MouseArea {
                            id: vinylTabMa
                            anchors.fill: parent
                            hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                            onClicked: { pickerTab = 1; displayMode = 1; UIState.setMediaDisplayMode(1) }
                        }
                    }
                }

                Item {
                    anchors { top: tabRow.bottom; topMargin: 10; left: parent.left; right: parent.right; bottom: pickerBtnsArea.top; bottomMargin: 8 }

                    Rectangle {
                        anchors.fill: parent
                        radius: brCard
                        color: a(Colors.surface, 0.4)
                        border.width: 1
                        border.color: a(Colors.fg, 0.04)
                        clip: true
                        visible: pickerTab === 0
                        Behavior on radius { NumberAnimation { duration: Animations.medium; easing.type: Easing.OutCubic } }

                        AnimatedImage {
                            anchors.fill: parent
                            anchors.margins: 8
                            source: pickerOpen && gifsLoaded && gifFiles.length > 0 && pickerTab === 0 && previewIndex < gifFiles.length
                                ? "file://" + gifFiles[previewIndex] : ""
                            fillMode: Image.PreserveAspectFit
                            playing: pickerOpen && pickerTab === 0
                            cache: false
                            asynchronous: true
                            opacity: status === Image.Ready ? 1 : 0
                            Behavior on opacity { NumberAnimation { duration: 180 } }
                        }

                        Text {
                            anchors.centerIn: parent
                            visible: !gifsLoaded && pickerTab === 0
                            text: "Loading..."
                            color: a(Colors.fg, 0.15)
                            font { pixelSize: 10; family: "JetBrainsMono Nerd Font" }
                        }

                        Text {
                            anchors.centerIn: parent
                            visible: gifsLoaded && gifFiles.length === 0 && pickerTab === 0
                            text: "No gifs in assets/gifs"
                            color: a(Colors.fg, 0.15)
                            font { pixelSize: 10; family: "JetBrainsMono Nerd Font" }
                        }

                        Rectangle {
                            anchors { bottom: parent.bottom; horizontalCenter: parent.horizontalCenter; bottomMargin: 6 }
                            visible: gifsLoaded && gifFiles.length > 0 && pickerTab === 0
                            width: gifNameLabel.implicitWidth + 12; height: 18; radius: brSm
                            color: a("#000", 0.45)
                            Behavior on radius { NumberAnimation { duration: Animations.medium; easing.type: Easing.OutCubic } }
                            Text {
                                id: gifNameLabel
                                anchors.centerIn: parent
                                text: gifFiles.length > 0 ? gifName(gifFiles[previewIndex]) : ""
                                color: "#fff"
                                font { pixelSize: 8; family: "JetBrainsMono Nerd Font" }
                                opacity: 0.8
                            }
                        }
                    }

                    Item {
                        anchors.fill: parent
                        visible: pickerTab === 1

                        Item {
                            anchors.centerIn: parent
                            width: Math.min(parent.width, parent.height) - 16
                            height: width

                            Rectangle {
                                anchors.centerIn: parent
                                width: parent.width
                                height: parent.width
                                radius: width / 2
                                color: "#0d0d0d"
                                rotation: vinylRotation

                                Repeater {
                                    model: 8
                                    Rectangle {
                                        anchors.centerIn: parent
                                        width: parent.width * (0.97 - index * 0.016)
                                        height: width
                                        radius: width / 2
                                        color: "transparent"
                                        border.width: index % 2 === 0 ? 1 : 0.5
                                        border.color: index % 2 === 0 ? Qt.rgba(1, 1, 1, 0.055) : Qt.rgba(1, 1, 1, 0.022)
                                    }
                                }

                                Item {
                                    anchors.centerIn: parent
                                    width: parent.width * 0.75
                                    height: width

                                    Image {
                                        id: pickerArtImage
                                        anchors.fill: parent
                                        source: vinylWithArt && UIState.mediaArtUrl !== "" ? UIState.mediaArtUrl : vinylAsset
                                        fillMode: Image.PreserveAspectCrop
                                        smooth: true
                                        asynchronous: true
                                        sourceSize: Qt.size(300, 300)
                                        visible: false
                                    }

                                    Rectangle {
                                        id: pickerArtMask
                                        anchors.fill: parent
                                        radius: width / 2
                                        visible: false
                                    }

                                    OpacityMask {
                                        anchors.fill: pickerArtImage
                                        source: pickerArtImage
                                        maskSource: pickerArtMask
                                    }

                                    Rectangle {
                                        anchors.fill: parent
                                        radius: width / 2
                                        color: "transparent"
                                        border.width: 1
                                        border.color: Qt.rgba(1, 1, 1, 0.07)
                                    }
                                }

                                Rectangle {
                                    anchors.centerIn: parent
                                    width: parent.width * 0.08
                                    height: width
                                    radius: width / 2
                                    color: "#1e1e1e"
                                    border.width: 1
                                    border.color: Qt.rgba(1, 1, 1, 0.1)
                                }

                                Rectangle {
                                    anchors.centerIn: parent
                                    width: 4; height: 4; radius: 2
                                    color: Colors.accent
                                }
                            }
                        }

                        Row {
                            anchors { bottom: parent.bottom; horizontalCenter: parent.horizontalCenter; bottomMargin: 10 }
                            spacing: 8

                            Rectangle {
                                width: withArtLabel.implicitWidth + 16
                                height: 24; radius: brSm
                                color: vinylWithArt ? a(Colors.accent, 0.15) : withArtMa.containsMouse ? a(Colors.fg, 0.06) : a(Colors.fg, 0.03)
                                border.width: vinylWithArt ? 1 : 0
                                border.color: a(Colors.accent, 0.3)
                                Behavior on color  { ColorAnimation { duration: 120 } }
                                Behavior on radius { NumberAnimation { duration: Animations.medium; easing.type: Easing.OutCubic } }
                                Text {
                                    id: withArtLabel
                                    anchors.centerIn: parent
                                    text: "With Art"
                                    color: vinylWithArt ? Colors.accent : a(Colors.fg, 0.35)
                                    font { pixelSize: 9; family: "JetBrainsMono Nerd Font" }
                                    Behavior on color { ColorAnimation { duration: 120 } }
                                }
                                MouseArea {
                                    id: withArtMa
                                    anchors.fill: parent
                                    hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                                    onClicked: { vinylWithArt = true; UIState.setMediaVinylWithArt(true) }
                                }
                            }

                            Rectangle {
                                width: noArtLabel.implicitWidth + 16
                                height: 24; radius: brSm
                                color: !vinylWithArt ? a(Colors.accent, 0.15) : noArtMa.containsMouse ? a(Colors.fg, 0.06) : a(Colors.fg, 0.03)
                                border.width: !vinylWithArt ? 1 : 0
                                border.color: a(Colors.accent, 0.3)
                                Behavior on color  { ColorAnimation { duration: 120 } }
                                Behavior on radius { NumberAnimation { duration: Animations.medium; easing.type: Easing.OutCubic } }
                                Text {
                                    id: noArtLabel
                                    anchors.centerIn: parent
                                    text: "No Art"
                                    color: !vinylWithArt ? Colors.accent : a(Colors.fg, 0.35)
                                    font { pixelSize: 9; family: "JetBrainsMono Nerd Font" }
                                    Behavior on color { ColorAnimation { duration: 120 } }
                                }
                                MouseArea {
                                    id: noArtMa
                                    anchors.fill: parent
                                    hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                                    onClicked: { vinylWithArt = false; UIState.setMediaVinylWithArt(false) }
                                }
                            }
                        }
                    }
                }

                Item {
                    id: pickerBtnsArea
                    anchors { bottom: parent.bottom; left: parent.left; right: parent.right }
                    height: 30

                    Row {
                        anchors.fill: parent
                        spacing: 6
                        visible: pickerTab === 0

                        Rectangle {
                            width: 32; height: 30; radius: brSm
                            color: prevGif.containsMouse ? a(Colors.accent, 0.12) : a(Colors.fg, 0.05)
                            opacity: gifFiles.length > 1 ? 1 : 0.3
                            Behavior on color  { ColorAnimation { duration: 120 } }
                            Behavior on radius { NumberAnimation { duration: Animations.medium; easing.type: Easing.OutCubic } }
                            Text {
                                anchors.centerIn: parent
                                text: "󰅁"
                                color: prevGif.containsMouse ? Colors.accent : a(Colors.fg, 0.4)
                                font { pixelSize: 13; family: "JetBrainsMono Nerd Font" }
                                Behavior on color { ColorAnimation { duration: 120 } }
                            }
                            MouseArea {
                                id: prevGif
                                anchors.fill: parent
                                hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                                enabled: gifFiles.length > 1
                                onClicked: previewIndex = previewIndex > 0 ? previewIndex - 1 : gifFiles.length - 1
                            }
                        }

                        Rectangle {
                            width: 32; height: 30; radius: brSm
                            color: nextGif.containsMouse ? a(Colors.accent, 0.12) : a(Colors.fg, 0.05)
                            opacity: gifFiles.length > 1 ? 1 : 0.3
                            Behavior on color  { ColorAnimation { duration: 120 } }
                            Behavior on radius { NumberAnimation { duration: Animations.medium; easing.type: Easing.OutCubic } }
                            Text {
                                anchors.centerIn: parent
                                text: "󰅂"
                                color: nextGif.containsMouse ? Colors.accent : a(Colors.fg, 0.4)
                                font { pixelSize: 13; family: "JetBrainsMono Nerd Font" }
                                Behavior on color { ColorAnimation { duration: 120 } }
                            }
                            MouseArea {
                                id: nextGif
                                anchors.fill: parent
                                hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                                enabled: gifFiles.length > 1
                                onClicked: previewIndex = previewIndex < gifFiles.length - 1 ? previewIndex + 1 : 0
                            }
                        }

                        Item { width: parent.width - 32 * 2 - 6 * 2 - applyRect.width; height: 1 }

                        Rectangle {
                            id: applyRect
                            width: applyLabel.implicitWidth + 18
                            height: 30; radius: brSm
                            property bool canApply: previewIndex !== UIState.gifIndex && !applyingGif && gifFiles.length > 0
                            color: canApply ? (applyMa.containsMouse ? a(Colors.accent, 0.2) : a(Colors.accent, 0.1)) : a(Colors.fg, 0.03)
                            border.width: canApply ? 1 : 0
                            border.color: a(Colors.accent, applyMa.containsMouse ? 0.4 : 0.2)
                            Behavior on color  { ColorAnimation { duration: 120 } }
                            Behavior on radius { NumberAnimation { duration: Animations.medium; easing.type: Easing.OutCubic } }
                            Text {
                                id: applyLabel
                                anchors.centerIn: parent
                                text: applyingGif ? "..." : previewIndex === UIState.gifIndex ? "󰄬 Current" : "󰸞 Apply"
                                color: applyRect.canApply ? (applyMa.containsMouse ? Colors.accent : a(Colors.accent, 0.7)) : a(Colors.fg, 0.2)
                                font { pixelSize: 10; family: "JetBrainsMono Nerd Font"; bold: true }
                                Behavior on color { ColorAnimation { duration: 120 } }
                            }
                            MouseArea {
                                id: applyMa
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: applyRect.canApply ? Qt.PointingHandCursor : Qt.ArrowCursor
                                enabled: applyRect.canApply
                                onClicked: applyGif()
                            }
                        }
                    }

                    Row {
                        anchors { right: parent.right; verticalCenter: parent.verticalCenter }
                        visible: pickerTab === 1

                        Rectangle {
                            width: applyVinylLabel.implicitWidth + 18
                            height: 30; radius: brSm
                            color: applyVinylMa.containsMouse ? a(Colors.accent, 0.2) : a(Colors.accent, 0.1)
                            border.width: 1
                            border.color: a(Colors.accent, applyVinylMa.containsMouse ? 0.4 : 0.2)
                            Behavior on color  { ColorAnimation { duration: 120 } }
                            Behavior on radius { NumberAnimation { duration: Animations.medium; easing.type: Easing.OutCubic } }
                            Text {
                                id: applyVinylLabel
                                anchors.centerIn: parent
                                text: "󰸞 Apply"
                                color: applyVinylMa.containsMouse ? Colors.accent : a(Colors.accent, 0.7)
                                font { pixelSize: 10; family: "JetBrainsMono Nerd Font"; bold: true }
                                Behavior on color { ColorAnimation { duration: 120 } }
                            }
                            MouseArea {
                                id: applyVinylMa
                                anchors.fill: parent
                                hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                                onClicked: pickerOpen = false
                            }
                        }
                    }
                }
            }
        }
    }
}