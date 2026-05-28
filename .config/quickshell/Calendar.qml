import Quickshell
import Quickshell.Wayland
import QtQuick

PanelWindow {
    id: calendar

    property bool showing: UIState.activeDropdown === "calendar"
    property bool _visible: false

    property int viewMonth:  new Date().getMonth()
    property int viewYear:   new Date().getFullYear()
    property int todayDay:   new Date().getDate()
    property int todayMonth: new Date().getMonth()
    property int todayYear:  new Date().getFullYear()
    property bool isCurrentMonth: viewMonth === todayMonth && viewYear === todayYear

    property var dayNames:     ["Mo", "Tu", "We", "Th", "Fr", "Sa", "Su"]
    property var monthNames:   ["January", "February", "March", "April", "May", "June",
                                "July", "August", "September", "October", "November", "December"]
    property var longDayNames: ["Sunday", "Monday", "Tuesday", "Wednesday", "Thursday", "Friday", "Saturday"]

    property real br:     UIState.borderRadius
    property real brCard: Math.round(br * 0.75)
    property real brSm:   Math.round(br * 0.625)

    visible: _visible
    anchors { top: true; left: true }
    margins.top: 44
    implicitWidth:  312
    implicitHeight: card.height + 16
    color: "transparent"
    exclusionMode: ExclusionMode.Ignore
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.namespace: "calendar"
    WlrLayershell.keyboardFocus: showing ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None

    function a(c, o) { return Qt.rgba(c.r, c.g, c.b, o) }

    function daysInMonth(m, y) { return new Date(y, m + 1, 0).getDate() }

    function firstDayOfWeek(m, y) {
        var d = new Date(y, m, 1).getDay()
        return d === 0 ? 6 : d - 1
    }

    function gridDays() {
        var first     = firstDayOfWeek(viewMonth, viewYear)
        var total     = daysInMonth(viewMonth, viewYear)
        var prevTotal = daysInMonth(viewMonth === 0 ? 11 : viewMonth - 1, viewMonth === 0 ? viewYear - 1 : viewYear)
        var cells     = []

        for (var i = first - 1; i >= 0; i--)
            cells.push({ day: prevTotal - i, current: false })
        for (var j = 1; j <= total; j++)
            cells.push({ day: j, current: true })
        var remaining = 42 - cells.length
        for (var k = 1; k <= remaining; k++)
            cells.push({ day: k, current: false })

        return cells
    }

    function prevMonth() {
        if (viewMonth === 0) { viewMonth = 11; viewYear-- }
        else viewMonth--
    }

    function nextMonth() {
        if (viewMonth === 11) { viewMonth = 0; viewYear++ }
        else viewMonth++
    }

    function goToday() {
        var now    = new Date()
        viewMonth  = now.getMonth()
        viewYear   = now.getFullYear()
        todayDay   = now.getDate()
        todayMonth = now.getMonth()
        todayYear  = now.getFullYear()
    }

    onShowingChanged: {
        if (showing) {
            _visible = true
            goToday()
        } else {
            closeDelay.start()
        }
    }

    Timer {
        id: closeDelay
        interval: Animations.exitDuration + 60
        onTriggered: _visible = false
    }

    Rectangle {
        id: card
        width:  280
        height: dateSection.height + monthGrid.height + 52
        anchors.top: parent.top
        anchors.topMargin: 8

        x:       showing ? 16 : -card.width - 12
        opacity: showing ? 1 : 0

        Behavior on x {
            NumberAnimation { duration: Animations.enterDuration; easing.type: Easing.OutExpo }
        }
        Behavior on opacity {
            NumberAnimation { duration: Animations.medium; easing.type: Easing.OutCubic }
        }
        Behavior on color {
            ColorAnimation { duration: Animations.slow }
        }
        Behavior on radius {
            NumberAnimation { duration: Animations.medium; easing.type: Easing.OutCubic }
        }

        radius: br
        color:  a(Colors.bg, UIState.transparencyEnabled ? 0.92 : 1)
        border.width: 1
        border.color: a(Colors.fg, 0.08)

        MouseArea { anchors.fill: parent }

        focus: showing

        Keys.onPressed: function(event) {
            if (event.key === Qt.Key_Escape) {
                UIState.closeDropdowns()
                event.accepted = true
            } else if (event.key === Qt.Key_Left) {
                prevMonth()
                event.accepted = true
            } else if (event.key === Qt.Key_Right) {
                nextMonth()
                event.accepted = true
            } else if (event.key === Qt.Key_T || event.key === Qt.Key_Home) {
                goToday()
                event.accepted = true
            }
        }

        Item {
            anchors.fill: parent
            anchors.margins: 16

            Item {
                id: dateSection
                anchors { top: parent.top; left: parent.left; right: parent.right }
                height: 56

                Text {
                    id: dayName
                    anchors { top: parent.top; left: parent.left }
                    text: longDayNames[new Date().getDay()]
                    color: Colors.accent
                    font { pixelSize: 18; family: "JetBrainsMono Nerd Font"; bold: true }
                }

                Text {
                    anchors { top: dayName.bottom; topMargin: 2; left: parent.left }
                    text: monthNames[todayMonth] + " " + todayDay + ", " + todayYear
                    color: a(Colors.fg, 0.4)
                    font { pixelSize: 11; family: "JetBrainsMono Nerd Font" }
                }
            }

            Item {
                id: monthGrid
                anchors { top: dateSection.bottom; topMargin: 4; left: parent.left; right: parent.right }
                height: navRow.height + dayHeaders.height + gridContainer.height + 12

                Row {
                    id: navRow
                    anchors { top: parent.top; left: parent.left; right: parent.right }
                    height: 28

                    Text {
                        text: monthNames[viewMonth] + " " + viewYear
                        color: Colors.fg
                        font { pixelSize: 12; family: "JetBrainsMono Nerd Font"; bold: true }
                        anchors.verticalCenter: parent.verticalCenter
                    }

                    Item { width: 6; height: 1 }

                    Rectangle {
                        visible: !isCurrentMonth
                        width: 18; height: 18; radius: 9
                        anchors.verticalCenter: parent.verticalCenter
                        color: todayBtn.containsMouse ? a(Colors.accent, 0.2) : a(Colors.accent, 0.08)
                        Behavior on color { ColorAnimation { duration: Animations.fast } }

                        Rectangle {
                            anchors.centerIn: parent
                            width: 6; height: 6; radius: 3
                            color: Colors.accent
                        }

                        MouseArea {
                            id: todayBtn
                            anchors.fill: parent; anchors.margins: -4
                            hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                            onClicked: goToday()
                        }
                    }

                    Item {
                        width: parent.width - navLeft.width - navRight.width - monthLabel.width - (isCurrentMonth ? 6 : 30)
                        height: 1
                    }

                    Text {
                        id: monthLabel
                        visible: false
                        text: monthNames[viewMonth] + " " + viewYear
                        font { pixelSize: 12; family: "JetBrainsMono Nerd Font" }
                    }

                    Rectangle {
                        id: navLeft
                        width: 26; height: 26; radius: brSm
                        anchors.verticalCenter: parent.verticalCenter
                        color: prevMa.containsMouse ? a(Colors.fg, 0.08) : "transparent"
                        scale: prevMa.pressed ? 0.88 : 1
                        Behavior on color  { ColorAnimation { duration: Animations.fast } }
                        Behavior on scale  { NumberAnimation { duration: Animations.snap; easing.type: Easing.OutQuad } }
                        Behavior on radius { NumberAnimation { duration: Animations.medium; easing.type: Easing.OutCubic } }

                        Text {
                            anchors.centerIn: parent
                            text: "󰅁"
                            color: prevMa.containsMouse ? Colors.fg : a(Colors.fg, 0.4)
                            font { pixelSize: 12; family: "JetBrainsMono Nerd Font" }
                            Behavior on color { ColorAnimation { duration: Animations.fast } }
                        }

                        MouseArea {
                            id: prevMa
                            anchors.fill: parent
                            hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                            onClicked: prevMonth()
                        }
                    }

                    Rectangle {
                        id: navRight
                        width: 26; height: 26; radius: brSm
                        anchors.verticalCenter: parent.verticalCenter
                        color: nextMa.containsMouse ? a(Colors.fg, 0.08) : "transparent"
                        scale: nextMa.pressed ? 0.88 : 1
                        Behavior on color  { ColorAnimation { duration: Animations.fast } }
                        Behavior on scale  { NumberAnimation { duration: Animations.snap; easing.type: Easing.OutQuad } }
                        Behavior on radius { NumberAnimation { duration: Animations.medium; easing.type: Easing.OutCubic } }

                        Text {
                            anchors.centerIn: parent
                            text: "󰅂"
                            color: nextMa.containsMouse ? Colors.fg : a(Colors.fg, 0.4)
                            font { pixelSize: 12; family: "JetBrainsMono Nerd Font" }
                            Behavior on color { ColorAnimation { duration: Animations.fast } }
                        }

                        MouseArea {
                            id: nextMa
                            anchors.fill: parent
                            hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                            onClicked: nextMonth()
                        }
                    }
                }

                Row {
                    id: dayHeaders
                    anchors { top: navRow.bottom; topMargin: 6; left: parent.left; right: parent.right }
                    height: 20

                    Repeater {
                        model: dayNames
                        Item {
                            required property string modelData
                            required property int index
                            width: parent.width / 7; height: 20

                            Text {
                                anchors.centerIn: parent
                                text: modelData
                                color: index >= 5 ? a(Colors.accent, 0.4) : a(Colors.fg, 0.25)
                                font { pixelSize: 9; family: "JetBrainsMono Nerd Font"; bold: true }
                            }
                        }
                    }
                }

                Grid {
                    id: gridContainer
                    anchors { top: dayHeaders.bottom; topMargin: 2; left: parent.left; right: parent.right }
                    columns: 7
                    property var cells: gridDays()
                    property real cellW: width / 7
                    property int todayWeekRow: {
                        if (!isCurrentMonth) return -1
                        var first = firstDayOfWeek(viewMonth, viewYear)
                        return Math.floor((first + todayDay - 1) / 7)
                    }

                    Repeater {
                        model: gridContainer.cells

                        Item {
                            required property int index
                            required property var modelData
                            property bool isToday:       modelData.current && modelData.day === todayDay && isCurrentMonth
                            property bool isWeekend:     (index % 7) >= 5
                            property int  weekRow:       Math.floor(index / 7)
                            property bool isCurrentWeek: weekRow === gridContainer.todayWeekRow
                            property bool hov:           dayMa.containsMouse && modelData.current

                            width:  gridContainer.cellW
                            height: 32

                            Rectangle {
                                anchors.fill: parent
                                color:  isCurrentWeek ? a(Colors.accent, 0.03) : "transparent"
                                radius: brSm
                                Behavior on radius { NumberAnimation { duration: Animations.medium; easing.type: Easing.OutCubic } }
                            }

                            Rectangle {
                                anchors.centerIn: parent
                                width:  isToday ? 26 : hov ? 24 : 0
                                height: width
                                radius: width / 2
                                color:  isToday ? a(Colors.accent, 0.15) : a(Colors.fg, 0.06)
                                border.width: isToday ? 1.5 : 0
                                border.color: a(Colors.accent, 0.4)

                                Behavior on width {
                                    NumberAnimation { duration: Animations.fast; easing.type: Easing.OutBack; easing.overshoot: 1.6 }
                                }
                                Behavior on color {
                                    ColorAnimation { duration: Animations.fast }
                                }
                            }

                            Text {
                                anchors.centerIn: parent
                                text: modelData.day
                                color: {
                                    if (isToday)            return Colors.accent
                                    if (!modelData.current) return a(Colors.fg, 0.12)
                                    if (isWeekend)          return a(Colors.fg, 0.35)
                                    return a(Colors.fg, 0.6)
                                }
                                font {
                                    pixelSize: 11
                                    family: "JetBrainsMono Nerd Font"
                                    bold: isToday
                                }
                                Behavior on color {
                                    ColorAnimation { duration: Animations.fast }
                                }
                            }

                            MouseArea {
                                id: dayMa
                                anchors.fill: parent
                                hoverEnabled: true
                                enabled: modelData.current
                                cursorShape: modelData.current ? Qt.PointingHandCursor : Qt.ArrowCursor
                            }
                        }
                    }
                }
            }
        }
    }
}