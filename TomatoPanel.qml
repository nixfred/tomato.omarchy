import QtQuick
import QtQuick.Layouts
import Quickshell
import qs.Commons
import qs.Ui

// Everything on one screen (LAW 17). Width is the remedy, never height: a
// dial column on the left, the numbers on the right. The only thing that
// scrolls is today's session log, in place, inside its own bounded box.
Panel {
  id: panel
  moduleName: "nixfred.tomato"
  ipcTarget: "tomato"

  required property var widget
  readonly property var svc: widget.svc
  readonly property var st: svc ? svc.st : ({})

  readonly property color fg: widget.bar ? widget.bar.foreground : Color.foreground
  readonly property color dim: Util.alpha(fg, 0.62)
  readonly property color faint: Util.alpha(fg, 0.12)
  readonly property color accent: Color.accent
  readonly property string fontFamily: widget.bar ? widget.bar.fontFamily : Style.font.family
  readonly property string phase: svc ? svc.phase : "focus"
  readonly property bool running: svc ? svc.running : false
  readonly property color phaseColor: phase === "focus" ? accent : fg

  readonly property var presets: [
    { "name": "Classic", "f": 25, "s": 5,  "l": 15, "tip": "25 focus, 5 short, 15 long. The original." },
    { "name": "Deep",    "f": 50, "s": 10, "l": 30, "tip": "50 focus, 10 short, 30 long. For long builds." },
    { "name": "Sprint",  "f": 15, "s": 3,  "l": 10, "tip": "15 focus, 3 short, 10 long. For restarts and low energy." },
    { "name": "Flow",    "f": 90, "s": 15, "l": 30, "tip": "90 focus, 15 short, 30 long. One ultradian cycle." }
  ]
  readonly property int panelWidth: Style.space(860)

  // ------------------------------------------------------------ parts
  component Cap: Text {
    color: panel.dim
    font.family: panel.fontFamily
    font.pixelSize: Style.font.caption
    font.bold: true
    font.letterSpacing: 1.2
  }

  component Chip: Rectangle {
    id: chip
    property string label: ""
    property string tip: ""
    property bool selected: false
    property bool danger: false
    signal clicked()
    Layout.fillWidth: true
    Layout.preferredWidth: 1
    implicitHeight: Style.space(30)
    radius: Style.space(4)
    border.width: 1
    border.color: selected ? panel.accent : (hover.containsMouse ? Util.alpha(panel.fg, 0.35) : panel.faint)
    color: selected ? Util.alpha(panel.accent, 0.16) : (hover.containsMouse ? Util.alpha(panel.fg, 0.06) : "transparent")
    Text {
      anchors.centerIn: parent
      text: chip.label
      color: chip.danger ? Color.urgent : panel.fg
      font.family: panel.fontFamily
      font.pixelSize: Style.font.bodySmall
      font.bold: chip.selected
    }
    MouseArea {
      id: hover
      anchors.fill: parent
      hoverEnabled: true
      cursorShape: Qt.PointingHandCursor
      onClicked: chip.clicked()
    }
    PanelToolTip { text: chip.tip; visible: hover.containsMouse && chip.tip !== "" }
  }

  component Stat: ColumnLayout {
    property string cap: ""
    property string value: ""
    property string tip: ""
    Layout.fillWidth: true
    Layout.preferredWidth: 1
    spacing: 0
    Cap { text: parent.cap }
    Text {
      text: parent.value
      color: panel.fg
      font.family: panel.fontFamily
      font.pixelSize: Style.font.subtitle + 4
      font.bold: true
    }
  }

  KeyboardPanel {
    id: kpanel
    anchorItem: panel.widget.anchorItem
    owner: panel.widget
    bar: panel.widget.bar
    open: panel.opened
    focusTarget: keyCatcher
    contentWidth: kpanel.fittedContentWidth(panel.panelWidth)
    contentHeight: kpanel.fittedContentHeight(content.implicitHeight, Style.space(460))

    PanelKeyCatcher {
      id: keyCatcher
      anchors.fill: parent
      onCloseRequested: panel.widget.close()

      ColumnLayout {
        id: content
        width: parent.width
        spacing: Style.space(10)

        // ------------------------------------------------------ header
        RowLayout {
          Layout.fillWidth: true
          spacing: Style.space(8)
          Rectangle { width: Style.space(10); height: width; radius: width / 2; border.width: 0; color: panel.accent }
          Text {
            text: "TOMATO"
            color: panel.fg
            font.family: panel.fontFamily
            font.pixelSize: Style.font.subtitle
            font.bold: true
            font.letterSpacing: 2
          }
          Text {
            text: svc && svc.error ? svc.error
                  : ((st.focusMin || 25) + "/" + (st.shortMin || 5) + "/" + (st.longMin || 15)
                     + " min · long break every " + (st.longEvery || 4))
            color: svc && svc.error ? Color.urgent : panel.dim
            font.family: panel.fontFamily
            font.pixelSize: Style.font.caption
          }
          Item { Layout.fillWidth: true }
          Text {
            text: panel.running ? "RUNNING" : (st.idle ? "READY" : "PAUSED")
            color: panel.running ? panel.accent : panel.dim
            font.family: panel.fontFamily
            font.pixelSize: Style.font.caption
            font.bold: true
            font.letterSpacing: 1.5
          }
        }

        Rectangle { Layout.fillWidth: true; height: 1; color: panel.faint; border.width: 0 }

        RowLayout {
          Layout.fillWidth: true
          spacing: Style.space(18)

          // ================================================ left: the dial
          ColumnLayout {
            Layout.preferredWidth: Style.space(250)
            Layout.maximumWidth: Style.space(250)
            Layout.alignment: Qt.AlignTop
            spacing: Style.space(10)

            Item {
              Layout.alignment: Qt.AlignHCenter
              implicitWidth: Style.space(170)
              implicitHeight: Style.space(170)

              Canvas {
                id: dial
                anchors.fill: parent
                property real p: svc ? svc.progress : 0
                property color c: panel.phaseColor
                property color track: panel.faint
                property bool live: panel.running
                onPChanged: requestPaint()
                onCChanged: requestPaint()
                onLiveChanged: requestPaint()
                onPaint: {
                  var ctx = getContext("2d")
                  ctx.reset()
                  var w = width, cx = w / 2, r = w / 2 - 8
                  // minute ticks
                  ctx.strokeStyle = track
                  ctx.lineWidth = 1.5
                  for (var i = 0; i < 60; i++) {
                    var a = i / 60 * Math.PI * 2 - Math.PI / 2
                    var inner = r - (i % 5 === 0 ? 9 : 5)
                    ctx.beginPath()
                    ctx.moveTo(cx + Math.cos(a) * inner, cx + Math.sin(a) * inner)
                    ctx.lineTo(cx + Math.cos(a) * (r - 2), cx + Math.sin(a) * (r - 2))
                    ctx.stroke()
                  }
                  ctx.lineWidth = 6
                  ctx.beginPath(); ctx.arc(cx, cx, r + 4, 0, Math.PI * 2); ctx.stroke()
                  var left = 1 - p
                  if (left > 0.001) {
                    ctx.strokeStyle = c
                    ctx.globalAlpha = live ? 1.0 : 0.5
                    ctx.lineCap = "round"
                    ctx.beginPath()
                    ctx.arc(cx, cx, r + 4, -Math.PI / 2, -Math.PI / 2 + Math.PI * 2 * left)
                    ctx.stroke()
                  }
                }
              }

              Column {
                anchors.centerIn: parent
                spacing: 0
                Text {
                  anchors.horizontalCenter: parent.horizontalCenter
                  text: svc ? svc.clock : "--:--"
                  color: panel.fg
                  font.family: panel.fontFamily
                  font.pixelSize: Style.font.subtitle * 2.6
                  font.bold: true
                }
                Text {
                  anchors.horizontalCenter: parent.horizontalCenter
                  text: ({ "focus": "FOCUS", "short": "SHORT BREAK", "long": "LONG BREAK" })[panel.phase]
                  color: panel.phaseColor
                  font.family: panel.fontFamily
                  font.pixelSize: Style.font.caption
                  font.bold: true
                  font.letterSpacing: 1.5
                }
                Text {
                  anchors.horizontalCenter: parent.horizontalCenter
                  visible: panel.running && st.endsAt > 0
                  text: "ends " + Qt.formatTime(new Date((st.endsAt || 0) * 1000), "HH:mm")
                  color: panel.dim
                  font.family: panel.fontFamily
                  font.pixelSize: Style.font.caption
                }
              }
            }

            RowLayout {
              Layout.fillWidth: true
              spacing: Style.space(6)
              Chip {
                label: panel.running ? "Pause" : (st.idle ? "Start" : "Resume")
                selected: true
                tip: "Left click on the bar ring does the same"
                onClicked: if (svc) svc.toggle()
              }
              Chip { label: "Skip"; tip: "End this phase now. A skipped focus does not count."; onClicked: if (svc) svc.skip() }
              Chip { label: "Reset"; danger: true; tip: "Stop and return to a fresh focus phase. History is kept."; onClicked: if (svc) svc.reset() }
            }

            RowLayout {
              Layout.fillWidth: true
              spacing: Style.space(6)
              Chip { label: "Focus"; selected: panel.phase === "focus"; tip: "Start a focus phase now"; onClicked: if (svc) svc.start("focus") }
              Chip { label: "Short"; selected: panel.phase === "short"; tip: "Start a short break now"; onClicked: if (svc) svc.start("short") }
              Chip { label: "Long"; selected: panel.phase === "long"; tip: "Start a long break now"; onClicked: if (svc) svc.start("long") }
            }

            // cycle position toward the long break
            RowLayout {
              Layout.fillWidth: true
              spacing: Style.space(4)
              Cap { text: "CYCLE" }
              Repeater {
                model: st.longEvery || 4
                delegate: Rectangle {
                  required property int index
                  Layout.fillWidth: true
                  implicitHeight: Style.space(5)
                  radius: 2
                  border.width: 0
                  color: index < (st.cycle || 0) ? panel.accent : panel.faint
                }
              }
            }
          }

          Rectangle { Layout.fillHeight: true; width: 1; color: panel.faint; border.width: 0 }

          // ================================================ right: numbers
          ColumnLayout {
            Layout.fillWidth: true
            Layout.alignment: Qt.AlignTop
            spacing: Style.space(10)

            Cap { text: "PRESETS" }
            RowLayout {
              Layout.fillWidth: true
              spacing: Style.space(6)
              Repeater {
                model: panel.presets
                delegate: Chip {
                  required property var modelData
                  label: modelData.name + " " + modelData.f + "/" + modelData.s + "/" + modelData.l
                  tip: modelData.tip
                  selected: st.focusMin === modelData.f && st.shortMin === modelData.s && st.longMin === modelData.l
                  onClicked: if (svc) svc.preset(modelData.f, modelData.s, modelData.l)
                }
              }
            }

            // ------------------------------------------- today tomatoes
            RowLayout {
              Layout.fillWidth: true
              spacing: Style.space(6)
              Cap { text: "TODAY " + (st.todayCount || 0) + "/" + (st.goal || 8) }
              Item { Layout.fillWidth: true }
              Chip {
                Layout.fillWidth: false; Layout.preferredWidth: Style.space(24); implicitHeight: Style.space(20)
                label: "−"; tip: "Lower the daily goal"
                onClicked: if (svc) svc.setGoal(Math.max(1, (st.goal || 8) - 1))
              }
              Chip {
                Layout.fillWidth: false; Layout.preferredWidth: Style.space(24); implicitHeight: Style.space(20)
                label: "+"; tip: "Raise the daily goal"
                onClicked: if (svc) svc.setGoal(Math.min(24, (st.goal || 8) + 1))
              }
            }
            Flow {
              Layout.fillWidth: true
              spacing: Style.space(5)
              Repeater {
                model: Math.max(st.goal || 8, st.todayCount || 0)
                delegate: Item {
                  required property int index
                  readonly property bool done: index < (st.todayCount || 0)
                  width: Style.space(22); height: Style.space(22)
                  Rectangle {
                    anchors.fill: parent
                    anchors.topMargin: Style.space(3)
                    radius: width / 2
                    border.width: done ? 0 : 1
                    border.color: panel.faint
                    color: done ? (index >= (st.goal || 8) ? Qt.lighter(panel.accent, 1.3) : panel.accent) : "transparent"
                  }
                  // the stalk
                  Rectangle {
                    visible: done
                    width: Style.space(6); height: Style.space(4); radius: 2
                    anchors.horizontalCenter: parent.horizontalCenter
                    anchors.top: parent.top
                    border.width: 0
                    color: panel.fg
                    opacity: 0.8
                  }
                }
              }
            }

            // ------------------------------------------- stats
            RowLayout {
              Layout.fillWidth: true
              spacing: Style.space(10)
              Stat { cap: "FOCUS TODAY"; value: (st.todayMinutes || 0) + "m" }
              Stat { cap: "7 DAYS"; value: (st.weekCount || 0) + " · " + Math.round((st.weekMinutes || 0) / 6) / 10 + "h" }
              Stat { cap: "STREAK"; value: (st.streak || 0) + "d" }
              Stat { cap: "BEST"; value: (st.bestStreak || 0) + "d" }
              Stat { cap: "ALL TIME"; value: String(st.allTime || 0) }
            }

            // ------------------------------------------- 7 day bars + today log
            RowLayout {
              Layout.fillWidth: true
              spacing: Style.space(14)

              ColumnLayout {
                Layout.fillWidth: true
                Layout.preferredWidth: 3
                spacing: Style.space(4)
                Cap { text: "LAST 7 DAYS" }
                RowLayout {
                  id: bars
                  Layout.fillWidth: true
                  implicitHeight: Style.space(96)
                  spacing: Style.space(6)
                  readonly property int peak: {
                    var m = st.goal || 8
                    var w = st.week || []
                    for (var i = 0; i < w.length; i++) m = Math.max(m, w[i].count)
                    return m
                  }
                  Repeater {
                    model: st.week || []
                    delegate: ColumnLayout {
                      required property var modelData
                      required property int index
                      Layout.fillWidth: true
                      Layout.preferredWidth: 1
                      Layout.fillHeight: true
                      spacing: Style.space(2)
                      Text {
                        Layout.alignment: Qt.AlignHCenter
                        text: modelData.count > 0 ? modelData.count : ""
                        color: panel.fg
                        font.family: panel.fontFamily
                        font.pixelSize: Style.font.caption
                      }
                      Item {
                        Layout.fillWidth: true
                        Layout.fillHeight: true
                        Rectangle {
                          anchors.fill: parent
                          radius: 2; border.width: 0
                          color: panel.faint
                          opacity: 0.5
                        }
                        Rectangle {
                          anchors.bottom: parent.bottom
                          width: parent.width
                          height: Math.max(modelData.count > 0 ? 3 : 0, parent.height * modelData.count / Math.max(1, bars.peak))
                          radius: 2; border.width: 0
                          color: index === 6 ? panel.accent : Util.alpha(panel.accent, 0.55)
                        }
                        // goal line
                        Rectangle {
                          width: parent.width; height: 1; border.width: 0
                          y: parent.height * (1 - (st.goal || 8) / Math.max(1, bars.peak))
                          color: panel.dim
                          opacity: 0.6
                        }
                      }
                      Text {
                        Layout.alignment: Qt.AlignHCenter
                        text: modelData.dow
                        color: index === 6 ? panel.fg : panel.dim
                        font.family: panel.fontFamily
                        font.pixelSize: Style.font.caption
                        font.bold: index === 6
                      }
                    }
                  }
                }
              }

              ColumnLayout {
                Layout.fillWidth: true
                Layout.preferredWidth: 2
                Layout.alignment: Qt.AlignTop
                spacing: Style.space(4)
                Cap { text: "TODAY LOG" }
                // The one list. It scrolls in place inside this box only.
                Rectangle {
                  Layout.fillWidth: true
                  implicitHeight: Style.space(96)
                  radius: Style.space(4)
                  color: "transparent"
                  border.width: 1
                  border.color: panel.faint
                  ListView {
                    id: log
                    anchors.fill: parent
                    anchors.margins: Style.space(5)
                    clip: true
                    model: st.todayLog || []
                    boundsBehavior: Flickable.StopAtBounds
                    delegate: RowLayout {
                      required property var modelData
                      required property int index
                      width: log.width
                      Text {
                        text: "#" + ((st.todayLog || []).length - index)
                        color: panel.dim
                        font.family: panel.fontFamily
                        font.pixelSize: Style.font.caption
                      }
                      Text {
                        text: modelData.label
                        color: panel.fg
                        font.family: panel.fontFamily
                        font.pixelSize: Style.font.bodySmall
                      }
                      Item { Layout.fillWidth: true }
                      Text {
                        text: modelData.min + "m"
                        color: panel.accent
                        font.family: panel.fontFamily
                        font.pixelSize: Style.font.bodySmall
                      }
                    }
                  }
                  Text {
                    anchors.centerIn: parent
                    visible: log.count === 0
                    text: "No tomatoes yet"
                    color: panel.dim
                    font.family: panel.fontFamily
                    font.pixelSize: Style.font.caption
                  }
                }
              }
            }
          }
        }
      }
    }
  }
}
