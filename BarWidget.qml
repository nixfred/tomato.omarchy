import QtQuick
import Quickshell
import qs.Commons
import qs.Ui

// A ring that empties as the phase runs down, plus minutes left.
// Left click starts or pauses. Right click opens the panel. Middle click skips.
BarWidget {
  id: root
  moduleName: "nixfred.tomato"
  property var anchorItem: button

  readonly property var svc: bar && bar.shell ? bar.shell.serviceFor(moduleName) : null
  readonly property bool ready: svc ? svc.ready : false
  readonly property bool running: svc ? svc.running : false
  readonly property string phase: svc ? svc.phase : "focus"
  readonly property real progress: svc ? svc.progress : 0

  function setting(name, fallback) {
    var v = settings ? settings[name] : undefined
    return v === undefined ? fallback : v
  }
  readonly property bool showMinutes: String(setting("showMinutes", true)) !== "false"
  readonly property color foreground: bar ? bar.foreground : Color.foreground
  readonly property color ringColor: {
    if (svc && svc.error) return Color.urgent
    if (phase !== "focus") return foreground
    return Color.accent
  }
  readonly property string label: {
    if (!svc || !ready) return ""
    if (svc.idle) return svc.st.todayCount + "×"
    return Math.ceil(svc.remaining / 60) + "m"
  }

  readonly property real contentWidth: Style.space(showMinutes ? 50 : 24)
  implicitWidth: vertical ? barSize : contentWidth
  implicitHeight: vertical ? contentWidth : barSize

  WidgetButton {
    id: button
    anchors.fill: parent
    bar: root.bar
    text: ""
    labelVisible: false
    hasVisualContent: true
    active: false
    useActiveColor: false
    tooltipText: {
      if (!root.svc) return "Tomato"
      if (root.svc.error) return "Tomato: " + root.svc.error
      var ph = { "focus": "Focus", "short": "Short break", "long": "Long break" }[root.phase]
      var state = root.svc.idle ? "ready" : (root.running ? root.svc.clock + " left" : "paused at " + root.svc.clock)
      return "Tomato · " + ph + " · " + state + "\n"
           + (root.svc.st.todayCount || 0) + "/" + (root.svc.st.goal || 8) + " today · streak " + (root.svc.st.streak || 0) + "d\n"
           + "Left: start/pause · Right: panel · Middle: skip"
    }

    Row {
      anchors.centerIn: parent
      spacing: Style.space(5)

      Item {
        width: Style.space(18); height: width
        anchors.verticalCenter: parent.verticalCenter

        Canvas {
          id: ring
          anchors.fill: parent
          property real p: root.progress
          property color c: root.ringColor
          property color track: Util.alpha(root.foreground, 0.18)
          property bool live: root.running
          onPChanged: requestPaint()
          onCChanged: requestPaint()
          onLiveChanged: requestPaint()
          onPaint: {
            var ctx = getContext("2d")
            ctx.reset()
            var w = width, cx = w / 2, r = w / 2 - 2
            ctx.lineWidth = 2.5
            ctx.strokeStyle = track
            ctx.beginPath(); ctx.arc(cx, cx, r, 0, Math.PI * 2); ctx.stroke()
            var left = 1 - p
            if (left > 0.001) {
              ctx.strokeStyle = c
              ctx.globalAlpha = live ? 1.0 : 0.55
              ctx.beginPath()
              ctx.arc(cx, cx, r, -Math.PI / 2, -Math.PI / 2 + Math.PI * 2 * left)
              ctx.stroke()
            }
            // centre pip: solid while running, hollow when paused
            ctx.globalAlpha = 1.0
            ctx.fillStyle = c
            ctx.beginPath(); ctx.arc(cx, cx, live ? 2.5 : 1.5, 0, Math.PI * 2); ctx.fill()
          }
        }
      }

      Text {
        visible: root.showMinutes
        anchors.verticalCenter: parent.verticalCenter
        text: root.label
        color: root.running ? root.foreground : Util.alpha(root.foreground, 0.6)
        font.family: root.bar ? root.bar.fontFamily : Style.font.family
        font.pixelSize: Style.font.bodySmall
      }
    }

    onPressed: function(code) {
      if (root.bar) root.bar.hideTooltip(root)
      if (code === Qt.RightButton) root.toggle()
      else if (code === Qt.MiddleButton) { if (root.svc) root.svc.skip() }
      else if (root.svc) root.svc.toggle()
    }
  }

  readonly property bool opened: panel.opened
  function open() { panel.controller.show(); if (svc) svc.refresh() }
  function close() { panel.controller.hide() }
  function toggle() { opened ? close() : open() }
  function closeForPopoutSwitch() { close() }
  readonly property bool popoutSwitchClosing: false

  TomatoPanel { id: panel; widget: root }
}
