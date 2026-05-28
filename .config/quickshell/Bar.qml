import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import QtQuick

Scope {
    id: root

    property string time: ""
    property bool wifi: false
    property bool bt: false
    property int bat: 100
    property bool plug: false
    property bool batFull: plug && bat >= 100
    property real pulse: 1
    property int tag: 1
    property var occ: [false,false,false,false,false]
    property bool barReady: false

    property bool attachedVisible: false

    function a(c, o) { return Qt.rgba(c.r, c.g, c.b, o) }

    function parseTagOutput(data) {
        var lines = data.trim().split("\n")
        var newOcc = [false, false, false, false, false]
        for (var i = 0; i < lines.length; i++) {
            var p = lines[i].split(" ")
            if (p.length >= 5 && p[1] === "tag") {
                var n = parseInt(p[2])
                if (n >= 1 && n <= 5) {
                    if (parseInt(p[3]) === 1) tag = n
                    newOcc[n - 1] = parseInt(p[4]) > 0
                }
            }
        }
        occ = newOcc
    }

    function volIcon() {
        if (UIState.muted) return "󰖁"
        if (UIState.volume > 60) return "󰕾"
        if (UIState.volume > 25) return "󰖀"
        return "󰕿"
    }

    function batIcon() {
        if (batFull) return "󰁹"
        if (plug) return "󰂄"
        if (bat > 90) return "󰁹"
        if (bat > 70) return "󰂁"
        if (bat > 50) return "󰁿"
        if (bat > 30) return "󰁾"
        if (bat > 15) return "󰁼"
        return "󰂃"
    }

    function batColor() {
        if (batFull) return Colors.green
        if (plug) return Colors.accent
        if (bat <= 15) return Colors.red
        if (bat <= 30) return Colors.yellow
        return Colors.fg
    }

    function adjustVol(delta) {
        UIState.setVolume(Math.max(0, Math.min(100, UIState.volume + delta)))
    }

    function showAttached() {
        attachedVisible = true
        attachedHideTimer.restart()
    }

    Process {
        id: tagWatch
        command: ["mmsg", "-w", "-t"]
        running: true
        stdout: SplitParser { splitMarker: ""; onRead: data => parseTagOutput(data) }
        onExited: tagRestart.start()
    }

    Timer { id: tagRestart; interval: 1000; onTriggered: tagWatch.running = true }

    Process {
        id: tagGet
        command: ["mmsg", "-g", "-t"]
        running: true
        stdout: SplitParser { splitMarker: ""; onRead: data => parseTagOutput(data) }
    }

    Process { id: tagSet }

    Timer {
        interval: 1000; running: true; repeat: true; triggeredOnStart: true
        onTriggered: time = Qt.formatDateTime(new Date(), "h:mm A")
    }

    Process {
        id: wifiWatch
        command: ["nmcli", "monitor"]
        running: true
        stdout: SplitParser { onRead: data => wifiDebounce.restart() }
        onExited: wifiWatchRestart.start()
    }

    Timer { id: wifiWatchRestart; interval: 1000; onTriggered: wifiWatch.running = true }
    Timer { id: wifiDebounce; interval: 80; onTriggered: wifiProc.running = true }

    Process {
        id: wifiProc
        command: ["bash", "-c", "nmcli -t -f active dev wifi 2>/dev/null | grep -q yes && echo 1 || echo 0"]
        running: true
        stdout: SplitParser { onRead: data => wifi = data.trim() === "1" }
    }

    Process {
        id: btWatch
        command: ["dbus-monitor", "--system", "type='signal',sender='org.bluez'"]
        running: true
        stdout: SplitParser { onRead: data => btDebounce.restart() }
        onExited: btWatchRestart.start()
    }

    Timer { id: btWatchRestart; interval: 1000; onTriggered: btWatch.running = true }
    Timer { id: btDebounce; interval: 80; onTriggered: btProc.running = true }

    Process {
        id: btProc
        command: ["bash", "-c", "for m in $(bluetoothctl devices 2>/dev/null | awk '{print $2}'); do bluetoothctl info $m 2>/dev/null | grep -q 'Connected: yes' && echo 1 && exit; done; echo 0"]
        running: true
        stdout: SplitParser { onRead: data => bt = data.trim() === "1" }
    }

    Process {
        id: batWatch
        command: ["upower", "--monitor-detail"]
        running: true
        stdout: SplitParser { onRead: data => batDebounce.restart() }
        onExited: batWatchRestart.start()
    }

    Timer { id: batWatchRestart; interval: 1000; onTriggered: batWatch.running = true }
    Timer { id: batDebounce; interval: 80; onTriggered: batProc.running = true }

    Process {
        id: batProc
        command: ["bash", "-c", "c=$(cat /sys/class/power_supply/BAT*/capacity 2>/dev/null | head -1); s=$(cat /sys/class/power_supply/BAT*/status 2>/dev/null | head -1); [ -z \"$c\" ] && c=100; echo \"$c|$s\""]
        running: true
        stdout: SplitParser {
            onRead: data => {
                var p = data.trim().split("|")
                bat = parseInt(p[0]) || 100
                plug = (p[1] === "Charging" || p[1] === "Full")
            }
        }
    }

    Process { id: volToggle; command: ["wpctl", "set-mute", "@DEFAULT_AUDIO_SINK@", "toggle"] }

    SequentialAnimation {
        running: plug && !batFull
        loops: Animation.Infinite
        NumberAnimation { target: root; property: "pulse"; to: 0.4; duration: 900; easing.type: Easing.InOutSine }
        NumberAnimation { target: root; property: "pulse"; to: 1;   duration: 900; easing.type: Easing.InOutSine }
    }

    Timer {
        id: startDelay
        interval: 80
        running: Colors.revision >= 0
        onTriggered: barReady = true
    }

    Timer {
        id: attachedHideTimer
        interval: 800
        onTriggered: {
            var dropdownOpen = UIState.activeDropdown === "dashboard" 
                            || UIState.activeDropdown === "calendar" 
                            || UIState.activeDropdown === "media"
            
            if (!dropdownOpen) {
                attachedVisible = false
            }
        }
    }

    Connections {
        target: UIState
        function onNotificationReceived(nid, app, title, body) {
            if (UIState.barMode === "autohide") showAttached()
        }
    }

    Connections {
        target: UIState
        function onActiveDropdownChanged() {
            if (UIState.barMode === "autohide") {
                var dropdownOpen = UIState.activeDropdown === "dashboard" 
                                || UIState.activeDropdown === "calendar" 
                                || UIState.activeDropdown === "music"
                
                if (dropdownOpen) {
                    attachedVisible = true
                    attachedHideTimer.stop()
                }
            }
        }
    }

    component BarContent: Item {
        id: barContent

        property bool compact: false

        anchors.fill: parent
        anchors.leftMargin: 14
        anchors.rightMargin: 14

        Row {
            anchors.left: parent.left
            anchors.verticalCenter: parent.verticalCenter
            spacing: 14

            Item {
                width: clockText.implicitWidth
                height: compact ? 18 : 22
                anchors.verticalCenter: parent.verticalCenter

                Text {
                    id: clockText
                    anchors.centerIn: parent
                    text: time
                    color: clockMa.containsMouse ? a(Colors.accent, 0.85) : a(Colors.fg, 0.70)
                    font { pixelSize: 11; family: "JetBrainsMono Nerd Font"; letterSpacing: 0.5 }
                    Behavior on color { ColorAnimation { duration: Animations.fast } }
                }

                Rectangle {
                    anchors {
                        bottom: parent.bottom
                        bottomMargin: 1
                        horizontalCenter: parent.horizontalCenter
                    }
                    width: clockMa.containsMouse ? parent.width + 4 : 0
                    height: 2
                    radius: 1
                    color: a(Colors.accent, 0.25)
                    Behavior on width { NumberAnimation { duration: Animations.medium; easing.type: Easing.OutBack; easing.overshoot: Animations.springPower } }
                }

                MouseArea {
                    id: clockMa
                    anchors.fill: parent
                    anchors.margins: compact ? -6 : -8
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: UIState.toggleDropdown("calendar")
                }
            }

            Row {
                spacing: 3
                anchors.verticalCenter: parent.verticalCenter

                Repeater {
                    model: 5

                    Item {
                        required property int index
                        property bool active: tag === index + 1
                        property bool used:   occ[index]
                        property bool show:   active || used
                        property bool hov:    tagMa.containsMouse

                        width:  show ? pill.width + 4 : 0
                        height: compact ? 18 : 22
                        clip:   true
                        anchors.verticalCenter: parent.verticalCenter

                        Behavior on width { NumberAnimation { duration: Animations.medium; easing.type: Easing.OutBack; easing.overshoot: 1.6 } }

                        onActiveChanged: {
                            if (active) activePop.restart()
                        }

                        SequentialAnimation {
                            id: activePop
                            NumberAnimation { target: pill; property: "scale"; to: 1.22; duration: Animations.snap; easing.type: Easing.OutQuad }
                            NumberAnimation { target: pill; property: "scale"; to: 1.0; duration: Animations.medium; easing.type: Easing.OutBack; easing.overshoot: Animations.springPower }
                        }

                        Rectangle {
                            id: pill
                            width: tagNum.implicitWidth + (compact ? 14 : 16)
                            height: compact ? 16 : 18
                            radius: compact ? 8 : 9
                            anchors.centerIn: parent
                            color: active ? a(Colors.accent, 0.10) : hov ? a(Colors.fg, 0.045) : "transparent"
                            border.width: active ? 1 : 0
                            border.color: a(Colors.accent, 0.15)
                            Behavior on color { ColorAnimation { duration: Animations.fast } }

                            Text {
                                id: tagNum
                                anchors.centerIn: parent
                                text: index + 1
                                color: active ? a(Colors.accent, 0.85) : hov ? a(Colors.fg, 0.70) : a(Colors.fg, 0.40)
                                font { pixelSize: compact ? 9 : 10; family: "JetBrainsMono Nerd Font"; bold: active }
                                Behavior on color { ColorAnimation { duration: Animations.fast } }
                            }
                        }

                        MouseArea {
                            id: tagMa
                            anchors.fill: parent
                            anchors.margins: -4
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: {
                                tagSet.command = ["mmsg", "-s", "-t", String(index + 1)]
                                tagSet.running = true
                            }
                        }
                    }
                }
            }
        }

        Item {
            anchors.centerIn: parent
            width: mediaVisible ? centerRow.implicitWidth : 0
            height: parent.height

            property bool mediaVisible: UIState.hasMedia
                                     && UIState.mediaDisplay !== ""
                                     && UIState.mediaState !== ""
                                     && UIState.mediaState !== "stopped"

            opacity: mediaVisible ? 1 : 0
            scale:   mediaVisible ? 1 : 0.86

            Behavior on width   { NumberAnimation { duration: Animations.slow; easing.type: Easing.OutExpo } }
            Behavior on opacity { NumberAnimation { duration: Animations.medium; easing.type: Easing.OutCubic } }
            Behavior on scale   { NumberAnimation { duration: Animations.medium; easing.type: Easing.OutBack; easing.overshoot: 1.4 } }

            Row {
                id: centerRow
                anchors.centerIn: parent
                spacing: 10

                Row {
                    spacing: 2
                    anchors.verticalCenter: parent.verticalCenter

                    Repeater {
                        model: 12
                        Rectangle {
                            required property int index
                            width: 2.5
                            height: Math.max(3, UIState.cava[index] * (compact ? 13 : 16))
                            radius: 1.25
                            anchors.verticalCenter: parent.verticalCenter
                            color: UIState.mediaState !== "playing"
                                ? a(Colors.accent, 0.10 + UIState.cava[index] * 0.35)
                                : UIState.cava[index] > 0.7
                                    ? a(Colors.accent, 0.70)
                                    : a(Colors.accent, 0.25 + UIState.cava[index] * 0.30)
                            Behavior on height { NumberAnimation { duration: 50; easing.type: Easing.OutQuad } }
                        }
                    }
                }

                Text {
                    text: UIState.mediaState === "playing" ? "󰏤" : "󰐊"
                    color: a(Colors.fg, 0.30)
                    font { pixelSize: compact ? 9 : 10; family: "JetBrainsMono Nerd Font" }
                    anchors.verticalCenter: parent.verticalCenter
                }

                Item {
                    id: marqueeRoot
                    property int  maxWidth:   140
                    property real gap:        36
                    property real unitWidth:  marqueeA.implicitWidth + gap
                    property bool scrolling:  marqueeA.implicitWidth > maxWidth

                    width:  scrolling ? maxWidth : marqueeA.implicitWidth
                    height: compact ? 18 : 22
                    clip:   true
                    anchors.verticalCenter: parent.verticalCenter

                    Row {
                        id: marqueeTrack
                        anchors.verticalCenter: parent.verticalCenter
                        spacing: 0

                        Text {
                            id: marqueeA
                            text: UIState.mediaDisplay
                            color: mediaMa.containsMouse ? a(Colors.fg, 0.85) : a(Colors.fg, UIState.mediaState === "playing" ? 0.55 : 0.32)
                            font { pixelSize: 10; family: "JetBrainsMono Nerd Font" }
                            Behavior on color { ColorAnimation { duration: Animations.fast } }
                        }

                        Item { width: marqueeRoot.gap; height: 1; visible: marqueeRoot.scrolling }

                        Text {
                            id: marqueeB
                            text: UIState.mediaDisplay
                            color: mediaMa.containsMouse ? a(Colors.fg, 0.85) : a(Colors.fg, UIState.mediaState === "playing" ? 0.55 : 0.32)
                            font { pixelSize: 10; family: "JetBrainsMono Nerd Font" }
                            visible: marqueeRoot.scrolling
                            Behavior on color { ColorAnimation { duration: Animations.fast } }
                        }
                    }

                    NumberAnimation {
                        id: marqueeAnim
                        target: marqueeTrack
                        property: "x"
                        from: 0
                        to: -marqueeRoot.unitWidth
                        duration: marqueeRoot.unitWidth * 24
                        loops: Animation.Infinite
                        running: marqueeRoot.scrolling
                        easing.type: Easing.Linear
                    }

                    Connections {
                        target: UIState
                        function onMediaDisplayChanged() {
                            marqueeAnim.stop()
                            marqueeTrack.x = 0
                            if (marqueeRoot.scrolling) marqueeAnim.start()
                        }
                    }

                    Rectangle {
                        anchors {
                            bottom: parent.bottom
                            bottomMargin: 1
                            horizontalCenter: parent.horizontalCenter
                        }
                        width: mediaMa.containsMouse ? parent.width + 4 : 0
                        height: 2
                        radius: 1
                        color: a(Colors.accent, 0.25)
                        Behavior on width { NumberAnimation { duration: Animations.medium; easing.type: Easing.OutBack; easing.overshoot: Animations.springPower } }
                    }
                }
            }

            MouseArea {
                id: mediaMa
                anchors.fill: parent
                anchors.margins: -8
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                acceptedButtons: Qt.LeftButton | Qt.RightButton
                onClicked: function(mouse) {
                    if (mouse.button === Qt.RightButton) UIState.toggleDropdown("media")
                    else UIState.doMedia("play-pause")
                }
                onWheel: function(wheel) {
                    UIState.doMedia(wheel.angleDelta.y > 0 ? "next" : "previous")
                }
            }
        }

        Row {
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            spacing: 12

            Row {
                spacing: 6
                anchors.verticalCenter: parent.verticalCenter

                Text {
                    text: wifi ? "󰤨" : "󰤭"
                    color: wifi ? a(Colors.accent, 0.70) : a(Colors.fg, 0.20)
                    font { pixelSize: 13; family: "JetBrainsMono Nerd Font" }
                    anchors.verticalCenter: parent.verticalCenter
                    Behavior on color { ColorAnimation { duration: Animations.fast } }
                }

                Text {
                    text: bt ? "󰂯" : "󰂲"
                    color: bt ? a(Colors.fg, 0.55) : a(Colors.fg, 0.18)
                    font { pixelSize: 12; family: "JetBrainsMono Nerd Font" }
                    anchors.verticalCenter: parent.verticalCenter
                    Behavior on color { ColorAnimation { duration: Animations.fast } }
                }
            }

            Item {
                width: volRow.width
                height: compact ? 18 : 22
                anchors.verticalCenter: parent.verticalCenter

                Row {
                    id: volRow
                    spacing: 5
                    anchors.centerIn: parent

                    Text {
                        text: volIcon()
                        color: UIState.muted ? a(Colors.fg, 0.18) : volMa.containsMouse ? a(Colors.fg, 0.85) : a(Colors.fg, 0.60)
                        font { pixelSize: 13; family: "JetBrainsMono Nerd Font" }
                        anchors.verticalCenter: parent.verticalCenter
                        Behavior on color { ColorAnimation { duration: Animations.fast } }
                    }

                    Text {
                        text: UIState.volume
                        color: UIState.muted ? a(Colors.fg, 0.18) : volMa.containsMouse ? a(Colors.fg, 0.85) : a(Colors.fg, 0.45)
                        font { pixelSize: 10; family: "JetBrainsMono Nerd Font" }
                        anchors.verticalCenter: parent.verticalCenter
                        Behavior on color { ColorAnimation { duration: Animations.fast } }
                    }
                }

                MouseArea {
                    id: volMa
                    anchors.fill: parent
                    anchors.margins: -8
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: volToggle.running = true
                    onWheel: function(wheel) { adjustVol(wheel.angleDelta.y > 0 ? 5 : -5) }
                }
            }

            Item {
                width: batRow.width
                height: compact ? 18 : 22
                anchors.verticalCenter: parent.verticalCenter

                Row {
                    id: batRow
                    spacing: 4
                    anchors.centerIn: parent

                    Text {
                        text: batIcon()
                        color: batColor()
                        font { pixelSize: 14; family: "JetBrainsMono Nerd Font" }
                        opacity: plug && !batFull ? pulse : 1
                        anchors.verticalCenter: parent.verticalCenter
                    }

                    Text {
                        text: bat + "%"
                        color: batColor()
                        font { pixelSize: 10; family: "JetBrainsMono Nerd Font" }
                        anchors.verticalCenter: parent.verticalCenter
                        opacity: bat <= 30 || plug || batMa.containsMouse ? 1 : 0.50
                        Behavior on opacity { NumberAnimation { duration: Animations.fast; easing.type: Easing.OutCubic } }
                    }
                }

                MouseArea {
                    id: batMa
                    anchors.fill: parent
                    anchors.margins: -6
                    hoverEnabled: true
                }
            }

            Item {
                width: 22
                height: 22
                anchors.verticalCenter: parent.verticalCenter

                Rectangle {
                    anchors.centerIn: parent
                    property bool lit: dma.containsMouse || UIState.activeDropdown === "dashboard"
                    width:  lit ? 21 : 17
                    height: width
                    radius: width / 2
                    color:  lit ? a(Colors.accent, 0.10) : a(Colors.fg, 0.035)
                    Behavior on width { NumberAnimation { duration: Animations.medium; easing.type: Easing.OutBack; easing.overshoot: Animations.springPower } }
                    Behavior on color { ColorAnimation { duration: Animations.fast } }
                }

                Text {
                    anchors.centerIn: parent
                    text: "󰺔"
                    property bool lit: dma.containsMouse || UIState.activeDropdown === "dashboard"
                    color: lit ? a(Colors.accent, 0.85) : a(Colors.fg, 0.30)
                    font { pixelSize: lit ? 12 : 11; family: "JetBrainsMono Nerd Font" }
                    Behavior on color          { ColorAnimation  { duration: Animations.fast } }
                    Behavior on font.pixelSize { NumberAnimation { duration: Animations.medium; easing.type: Easing.OutBack; easing.overshoot: 1.4 } }
                }

                MouseArea {
                    id: dma
                    anchors.fill: parent
                    anchors.margins: -8
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: UIState.toggleDropdown("dashboard")
                }
            }
        }
    }

    Variants {
        model: Quickshell.screens

        PanelWindow {
            property var modelData
            screen: modelData
            visible: UIState.barMode === "floating"
            anchors { top: true; left: true; right: true }
            height: 38
            color: "transparent"
            exclusionMode: ExclusionMode.Exclusive
            WlrLayershell.layer: WlrLayer.Top
            WlrLayershell.namespace: "bar"

            Rectangle {
                id: floatingBg
                anchors.fill: parent
                anchors.topMargin: 5
                anchors.leftMargin:   barReady ? 8 : parent.width * 0.4
                anchors.rightMargin:  barReady ? 8 : parent.width * 0.4
                anchors.bottomMargin: 3
                radius: 12
                color: a(Colors.bg, UIState.barOpacity)
                border.width: 1
                border.color: a(Colors.fg, 0.06)
                opacity: barReady ? 1 : 0
                scale:   barReady ? 1 : 0.94

                Behavior on anchors.leftMargin  { NumberAnimation { duration: Animations.xslow; easing.type: Easing.OutExpo } }
                Behavior on anchors.rightMargin { NumberAnimation { duration: Animations.xslow; easing.type: Easing.OutExpo } }
                Behavior on opacity { NumberAnimation { duration: Animations.slow; easing.type: Easing.OutCubic } }
                Behavior on scale   { NumberAnimation { duration: Animations.slow; easing.type: Easing.OutBack; easing.overshoot: Animations.springPower } }
                Behavior on color   { ColorAnimation { duration: Animations.slow } }

                BarContent {
                    compact: false
                    opacity: barReady ? 1 : 0
                    scale:   barReady ? 1 : 0.92
                    Behavior on opacity { NumberAnimation { duration: Animations.slow; easing.type: Easing.OutCubic } }
                    Behavior on scale   { NumberAnimation { duration: Animations.slow; easing.type: Easing.OutCubic } }
                }
            }
        }
    }

    Variants {
        model: Quickshell.screens

        PanelWindow {
            id: attachedBar
            property var modelData
            screen: modelData
            visible: UIState.barMode === "autohide"
            anchors { top: true; left: true; right: true }
            height: 30
            color: "transparent"
            exclusionMode: ExclusionMode.Ignore
            WlrLayershell.layer: WlrLayer.Top
            WlrLayershell.namespace: "bar-autohide"

            MouseArea {
                id: peekZone
                anchors.top: parent.top
                anchors.left: parent.left
                anchors.right: parent.right
                height: 3
                enabled: !attachedVisible
                hoverEnabled: true

                onEntered: {
                    attachedVisible = true
                    attachedHideTimer.stop()
                }
            }

            Rectangle {
                id: attachedBg
                anchors.left: parent.left
                anchors.right: parent.right
                height: 24
                y: attachedVisible ? 0 : -height
                color: a(Colors.bg, UIState.transparencyEnabled ? 0.88 : 1)
                radius: 0

                Behavior on y     { NumberAnimation { duration: Animations.medium; easing.type: Easing.OutExpo } }
                Behavior on color { ColorAnimation  { duration: Animations.slow } }

                Rectangle {
                    anchors.bottom: parent.bottom
                    anchors.left: parent.left
                    anchors.right: parent.right
                    height: 1
                    color: a(Colors.fg, 0.07)
                }

                BarContent {
                    compact: true
                }

                HoverHandler {
                    id: barHover
                    enabled: attachedVisible
                    margin: 6
                    onHoveredChanged: {
                        if (hovered) {
                            attachedVisible = true
                            attachedHideTimer.stop()
                        } else {
                            attachedHideTimer.restart()
                        }
                    }
                }
            }
        }
    }

    Variants {
        model: Quickshell.screens

        PanelWindow {
            property var modelData
            screen: modelData
            visible: UIState.barMode === "fixed"
            anchors { top: true; left: true; right: true }
            height: 24
            color: "transparent"
            exclusionMode: ExclusionMode.Exclusive
            WlrLayershell.layer: WlrLayer.Top
            WlrLayershell.namespace: "bar-fixed"

            Rectangle {
                id: fixedBg
                anchors.fill: parent
                color: a(Colors.bg, UIState.transparencyEnabled ? 0.88 : 1)
                radius: 0

                Behavior on color { ColorAnimation { duration: Animations.slow } }

                Rectangle {
                    anchors.bottom: parent.bottom
                    anchors.left: parent.left
                    anchors.right: parent.right
                    height: 1
                    color: a(Colors.fg, 0.07)
                }

                BarContent {
                    compact: true
                }
            }
        }
    }
}