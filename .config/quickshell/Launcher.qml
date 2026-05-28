import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import QtQuick

PanelWindow {
    id: launcher

    property bool showing: UIState.activeDropdown === "launcher"
    property var apps: []
    property var filtered: []
    property string query: ""
    property int selected: 0
    property var _appsBuild: []

    property real br:     UIState.borderRadius
    property real brCard: Math.round(br * 0.75)
    property real brSm:   Math.round(br * 0.625)

    visible: showing
    anchors { top: true; bottom: true; left: true; right: true }
    color: "transparent"
    exclusionMode: ExclusionMode.Ignore
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.namespace: "launcher"
    WlrLayershell.keyboardFocus: showing ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None

    function a(c, o) { return Qt.rgba(c.r, c.g, c.b, o) }

    Component.onCompleted: appsProc.running = true

    onShowingChanged: {
        if (showing) {
            query = ""
            selected = 0
            searchInput.text = ""
            _appsBuild = []
            appsProc.running = true
            focusDelay.start()
        }
    }

    Timer {
        id: focusDelay
        interval: 100
        onTriggered: searchInput.forceActiveFocus()
    }

    property var topApps: {
        if (apps.length === 0) return []
        var sorted = apps.slice().sort((a, b) => {
            return UIState.getAppScore(b.id) - UIState.getAppScore(a.id)
        })
        return sorted.slice(0, 8)
    }

    function filterApps() {
        if (query === "") {
            var sorted = apps.slice().sort((a, b) => {
                return UIState.getAppScore(b.id) - UIState.getAppScore(a.id)
            })
            filtered = sorted
        } else {
            var q = query.toLowerCase()
            var matches = apps.filter(app => {
                var name = (app.name || "").toLowerCase()
                var desc = (app.desc || "").toLowerCase()
                return name.includes(q) || desc.includes(q)
            })
            matches.sort((a, b) => {
                var sa = UIState.getAppScore(a.id)
                var sb = UIState.getAppScore(b.id)
                var na = a.name.toLowerCase()
                var nb = b.name.toLowerCase()
                var startsA = na.startsWith(q) ? 1000 : 0
                var startsB = nb.startsWith(q) ? 1000 : 0
                return (sb + startsB) - (sa + startsA)
            })
            filtered = matches
        }
        selected = 0
    }

    function launch(app) {
        if (!app) return
        UIState.recordAppLaunch(app.id)
        launchProc.command = ["bash", "-c", app.exec + " &"]
        launchProc.running = true
        UIState.closeDropdowns()
    }

    function moveSelection(delta) {
        if (query === "") {
            if (delta === 1  && selected < topApps.length - 1)  selected++
            else if (delta === -1 && selected > 0)               selected--
            else if (delta === 4  && selected + 4 < topApps.length) selected += 4
            else if (delta === -4 && selected - 4 >= 0)          selected -= 4
        } else {
            var newSel = selected + delta
            if (newSel < 0) newSel = 0
            if (newSel >= filtered.length) newSel = filtered.length - 1
            selected = newSel
            appList.positionViewAtIndex(selected, ListView.Contain)
        }
    }

    Process {
        id: appsProc
        command: ["bash", "-c", [
            "shopt -s nullglob",
            "for f in /usr/share/applications/*.desktop \"$HOME\"/.local/share/applications/*.desktop /var/lib/flatpak/exports/share/applications/*.desktop; do",
            "  grep -q '^NoDisplay=true' \"$f\" && continue",
            "  grep -q '^Hidden=true' \"$f\" && continue",
            "  grep -q '^Type=Application' \"$f\" || continue",
            "  name=$(grep -m1 '^Name=' \"$f\" | cut -d= -f2-)",
            "  exec=$(grep -m1 '^Exec=' \"$f\" | cut -d= -f2- | sed 's/ %[fFuUdDnNickvm]//g')",
            "  icon=$(grep -m1 '^Icon=' \"$f\" | cut -d= -f2-)",
            "  desc=$(grep -m1 '^Comment=' \"$f\" | cut -d= -f2-)",
            "  id=$(basename \"$f\")",
            "  [ -z \"$name\" ] && continue",
            "  [ -z \"$exec\" ] && continue",
            "  echo \"${id}\t${name}\t${exec}\t${icon}\t${desc}\"",
            "done"
        ].join("\n")]
        stdout: SplitParser {
            onRead: data => {
                var line = data.trim()
                if (line.length === 0) return
                var p = line.split("\t")
                if (p.length >= 3) {
                    _appsBuild.push({
                        id:   p[0],
                        name: p[1],
                        exec: p[2],
                        icon: p[3] || "",
                        desc: p[4] || ""
                    })
                }
            }
        }
        onExited: {
            var seen   = {}
            var result = []
            for (var i = 0; i < _appsBuild.length; i++) {
                if (!seen[_appsBuild[i].name]) {
                    seen[_appsBuild[i].name] = true
                    result.push(_appsBuild[i])
                }
            }
            apps      = result
            _appsBuild = []
            filterApps()
        }
    }

    Process { id: launchProc }

    MouseArea {
        anchors.fill: parent
        onClicked: UIState.closeDropdowns()
    }

    Rectangle {
        id: card
        width:  520
        height: query === "" ? 380 : 480
        anchors.centerIn: parent
        transformOrigin: Item.Center
        radius: br
        color:  a(Colors.bg, UIState.transparencyEnabled ? 0.82 : 1)
        border.width: 1
        border.color: a(Colors.fg, 0.1)
        scale:   showing ? 1.0 : Animations.enterScale

        Behavior on scale {
            NumberAnimation {
                duration: Animations.enterDuration
                easing.type: Easing.OutBack
                easing.overshoot: Animations.springPower
            }
        }
        Behavior on height {
            NumberAnimation { duration: Animations.medium; easing.type: Easing.OutExpo }
        }
        Behavior on color {
            ColorAnimation { duration: Animations.slow }
        }
        Behavior on radius {
            NumberAnimation { duration: Animations.medium; easing.type: Easing.OutCubic }
        }

        Column {
            anchors.fill: parent
            anchors.margins: 20
            spacing: 16

            Rectangle {
                width:  parent.width
                height: 48
                radius: brCard
                color:  a(Colors.surface, 0.7)
                border.width: searchInput.activeFocus ? 2 : 1
                border.color: searchInput.activeFocus ? a(Colors.accent, 0.55) : a(Colors.fg, 0.06)

                Behavior on border.color {
                    ColorAnimation { duration: Animations.fast }
                }
                Behavior on radius {
                    NumberAnimation { duration: Animations.medium; easing.type: Easing.OutCubic }
                }

                Row {
                    anchors.fill: parent
                    anchors.leftMargin: 16
                    anchors.rightMargin: 16
                    spacing: 12

                    Text {
                        anchors.verticalCenter: parent.verticalCenter
                        text:  ""
                        color: searchInput.activeFocus ? Colors.accent : a(Colors.fg, 0.3)
                        font { pixelSize: 15; family: "JetBrainsMono Nerd Font" }
                        Behavior on color { ColorAnimation { duration: Animations.fast } }
                    }

                    TextInput {
                        id: searchInput
                        width: parent.width - 70
                        anchors.verticalCenter: parent.verticalCenter
                        color: Colors.fg
                        font { pixelSize: 14; family: "JetBrainsMono Nerd Font" }
                        selectByMouse: true
                        clip: true

                        Text {
                            anchors.left: parent.left
                            anchors.verticalCenter: parent.verticalCenter
                            text:    "Search apps..."
                            color:   a(Colors.fg, 0.25)
                            font:    parent.font
                            visible: !parent.text && !parent.activeFocus
                        }

                        onTextChanged: {
                            query = text.toLowerCase()
                            filterApps()
                        }

                        Keys.onPressed: function(event) {
                            if (event.key === Qt.Key_Down) {
                                moveSelection(query === "" ? 4 : 1)
                                event.accepted = true
                            } else if (event.key === Qt.Key_Up) {
                                moveSelection(query === "" ? -4 : -1)
                                event.accepted = true
                            } else if (event.key === Qt.Key_Left && query === "") {
                                moveSelection(-1)
                                event.accepted = true
                            } else if (event.key === Qt.Key_Right && query === "") {
                                moveSelection(1)
                                event.accepted = true
                            } else if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) {
                                if (query === "" && topApps.length > 0) launch(topApps[selected])
                                else if (filtered.length > 0) launch(filtered[selected])
                                event.accepted = true
                            } else if (event.key === Qt.Key_Escape) {
                                UIState.closeDropdowns()
                                event.accepted = true
                            } else if (event.key === Qt.Key_Tab) {
                                moveSelection(1)
                                event.accepted = true
                            }
                        }
                    }

                    Text {
                        anchors.verticalCenter: parent.verticalCenter
                        text:    "󰅖"
                        color:   clearMa.containsMouse ? Colors.fg : a(Colors.fg, 0.3)
                        font { pixelSize: 12; family: "JetBrainsMono Nerd Font" }
                        visible: searchInput.text.length > 0
                        Behavior on color { ColorAnimation { duration: Animations.fast } }

                        MouseArea {
                            id: clearMa
                            anchors.fill: parent
                            anchors.margins: -8
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: { searchInput.text = ""; searchInput.forceActiveFocus() }
                        }
                    }
                }
            }

            Item {
                width:  parent.width
                height: parent.height - 48 - 16

                Grid {
                    id: topGrid
                    anchors.fill: parent
                    columns: 4
                    spacing: 10
                    visible: query === "" && topApps.length > 0

                    Repeater {
                        model: topApps

                        Rectangle {
                            id: gridItem
                            required property int index
                            required property var modelData

                            width:  (topGrid.width - 30) / 4
                            height: width + 16
                            radius: brCard
                            color:  index === selected
                                ? a(Colors.accent, 0.15)
                                : gridMa.containsMouse ? a(Colors.fg, 0.06) : a(Colors.surface, 0.5)
                            border.width: index === selected ? 1.5 : 0
                            border.color: a(Colors.accent, 0.5)
                            scale: gridMa.pressed ? 0.9 : gridMa.containsMouse ? Animations.hoverScale : 1

                            Behavior on color {
                                ColorAnimation { duration: Animations.fast }
                            }
                            Behavior on scale {
                                NumberAnimation { duration: Animations.snap; easing.type: Easing.OutBack; easing.overshoot: 1.6 }
                            }
                            Behavior on radius {
                                NumberAnimation { duration: Animations.medium; easing.type: Easing.OutCubic }
                            }

                            Column {
                                anchors.centerIn: parent
                                spacing: 8

                                Rectangle {
                                    width:  40
                                    height: 40
                                    radius: brSm
                                    color:  a(Colors.fg, 0.06)
                                    anchors.horizontalCenter: parent.horizontalCenter

                                    Behavior on radius {
                                        NumberAnimation { duration: Animations.medium; easing.type: Easing.OutCubic }
                                    }

                                    Image {
                                        anchors.centerIn: parent
                                        width:  26
                                        height: 26
                                        source: {
                                            var icon = modelData.icon
                                            if (!icon || icon === "") return "image://icon/application-x-executable"
                                            if (icon.indexOf("/") === 0) return "file://" + icon
                                            return "image://icon/" + icon
                                        }
                                        fillMode: Image.PreserveAspectFit
                                        asynchronous: true
                                        cache: true
                                    }
                                }

                                Text {
                                    text:  modelData.name
                                    color: index === selected ? Colors.accent : Colors.fg
                                    font { pixelSize: 9; family: "JetBrainsMono Nerd Font"; bold: index === selected }
                                    width: gridItem.width - 12
                                    horizontalAlignment: Text.AlignHCenter
                                    elide: Text.ElideRight
                                    anchors.horizontalCenter: parent.horizontalCenter
                                    Behavior on color { ColorAnimation { duration: Animations.fast } }
                                }
                            }

                            MouseArea {
                                id: gridMa
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: launch(modelData)
                                onContainsMouseChanged: { if (containsMouse) selected = index }
                            }
                        }
                    }
                }

                ListView {
                    id: appList
                    anchors.fill: parent
                    clip: true
                    spacing: 4
                    model: filtered
                    visible: query !== ""
                    boundsBehavior: Flickable.StopAtBounds
                    highlightMoveDuration: Animations.snap

                    add: Transition {
                        ParallelAnimation {
                            NumberAnimation { property: "opacity"; from: 0; to: 1; duration: Animations.medium; easing.type: Easing.OutCubic }
                            NumberAnimation { property: "x"; from: 16; to: 0; duration: Animations.medium; easing.type: Easing.OutExpo }
                        }
                    }

                    displaced: Transition {
                        NumberAnimation { property: "y"; duration: Animations.fast; easing.type: Easing.OutExpo }
                    }

                    delegate: Rectangle {
                        id: listItem
                        required property int index
                        required property var modelData

                        width:  appList.width
                        height: 52
                        radius: brCard
                        color:  index === selected
                            ? a(Colors.accent, 0.12)
                            : itemMa.containsMouse ? a(Colors.fg, 0.05) : "transparent"
                        scale: itemMa.pressed ? 0.97 : 1

                        Behavior on color {
                            ColorAnimation { duration: Animations.fast }
                        }
                        Behavior on scale {
                            NumberAnimation { duration: Animations.snap; easing.type: Easing.OutQuad }
                        }
                        Behavior on radius {
                            NumberAnimation { duration: Animations.medium; easing.type: Easing.OutCubic }
                        }

                        Rectangle {
                            visible: index === selected
                            width:   3
                            height:  24
                            radius:  1.5
                            color:   Colors.accent
                            anchors { left: parent.left; leftMargin: 6; verticalCenter: parent.verticalCenter }

                            Behavior on color { ColorAnimation { duration: Animations.fast } }
                        }

                        Row {
                            anchors.fill: parent
                            anchors.leftMargin: 18
                            anchors.rightMargin: 18
                            spacing: 14

                            Rectangle {
                                width:  36
                                height: 36
                                radius: brSm
                                color:  a(Colors.fg, 0.05)
                                anchors.verticalCenter: parent.verticalCenter

                                Behavior on radius {
                                    NumberAnimation { duration: Animations.medium; easing.type: Easing.OutCubic }
                                }

                                Image {
                                    anchors.centerIn: parent
                                    width:  24
                                    height: 24
                                    source: {
                                        var icon = modelData.icon
                                        if (!icon || icon === "") return "image://icon/application-x-executable"
                                        if (icon.indexOf("/") === 0) return "file://" + icon
                                        return "image://icon/" + icon
                                    }
                                    fillMode: Image.PreserveAspectFit
                                    asynchronous: true
                                    cache: true
                                }
                            }

                            Column {
                                anchors.verticalCenter: parent.verticalCenter
                                spacing: 2
                                width: parent.width - 90

                                Text {
                                    text:  modelData.name
                                    color: index === selected ? Colors.accent : Colors.fg
                                    font { pixelSize: 12; family: "JetBrainsMono Nerd Font"; bold: index === selected }
                                    width: parent.width
                                    elide: Text.ElideRight
                                    Behavior on color { ColorAnimation { duration: Animations.fast } }
                                }

                                Text {
                                    text:    modelData.desc || ""
                                    color:   a(Colors.fg, 0.3)
                                    font { pixelSize: 9; family: "JetBrainsMono Nerd Font" }
                                    width:   parent.width
                                    elide:   Text.ElideRight
                                    visible: text !== ""
                                }
                            }

                            Text {
                                anchors.verticalCenter: parent.verticalCenter
                                text:    "↵"
                                color:   Colors.accent
                                font { pixelSize: 11; family: "JetBrainsMono Nerd Font"; bold: true }
                                visible: index === selected
                                opacity: index === selected ? 1 : 0
                                Behavior on opacity {
                                    NumberAnimation { duration: Animations.fast; easing.type: Easing.OutCubic }
                                }
                            }
                        }

                        MouseArea {
                            id: itemMa
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: launch(modelData)
                            onContainsMouseChanged: { if (containsMouse) selected = index }
                        }
                    }
                }

                Text {
                    anchors.centerIn: parent
                    text:    query !== "" && filtered.length === 0 ? "No results" : apps.length === 0 ? "Loading..." : ""
                    color:   a(Colors.fg, 0.2)
                    font { pixelSize: 13; family: "JetBrainsMono Nerd Font" }
                    visible: text !== ""
                    opacity: visible ? 1 : 0
                    Behavior on opacity {
                        NumberAnimation { duration: Animations.fast }
                    }
                }
            }
        }
    }
}