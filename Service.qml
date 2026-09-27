import QtQuick
import Quickshell
import Quickshell.Io

// One source of truth: bin/tomato (python3, stdlib only). It owns the state
// file and the phase transitions; this service only asks it for JSON, relays
// clicks, and ticks the visible countdown locally between polls from the
// stored end timestamp, so the ring moves every second without a process
// being spawned every second.
Item {
  id: root
  property var settings: ({})

  property bool ready: false
  property string error: ""
  property var st: ({})
  property double now: Date.now() / 1000

  readonly property string phase: st.phase || "focus"
  readonly property bool running: !!st.running
  readonly property bool idle: !!st.idle
  readonly property real total: st.total || 1
  readonly property real remaining: running ? Math.max(0, (st.endsAt || 0) - now) : (st.remaining || 0)
  readonly property real progress: Math.max(0, Math.min(1, 1 - remaining / total))

  function fmt(sec) {
    var s = Math.max(0, Math.round(sec))
    var m = Math.floor(s / 60), r = s % 60
    return m + ":" + (r < 10 ? "0" : "") + r
  }
  readonly property string clock: fmt(remaining)

  function localPath(relative) {
    return decodeURIComponent(String(Qt.resolvedUrl(relative)).replace(/^file:\/\//, ""))
  }
  readonly property string cli: localPath("bin/tomato")

  function apply(text) {
    var d
    try { d = JSON.parse(text) } catch (e) { root.error = "bad output from bin/tomato"; return }
    if (!d || !d.ok) { root.error = d && d.error ? d.error : "bin/tomato failed"; return }
    root.error = ""
    root.st = d
    root.now = Date.now() / 1000
    root.ready = true
  }

  Process {
    id: poll
    property bool launched: false
    command: ["python3", root.cli, "status"]
    onStarted: launched = true
    onRunningChanged: if (!running && !launched) root.error = "python3 not found"
    stdout: StdioCollector { waitForEnd: true; onStreamFinished: root.apply(text) }
  }

  // Actions are queued, never dropped, and never mutate the array in place.
  property var pending: []
  Process {
    id: act
    stdout: StdioCollector { waitForEnd: true; onStreamFinished: root.apply(text) }
    onRunningChanged: if (!running) root.drain()
  }
  function drain() {
    if (act.running || root.pending.length === 0) return
    act.command = root.pending[0]
    root.pending = root.pending.slice(1)
    act.running = true
  }
  function run(args) {
    var q = root.pending.slice(-3)
    q.push(["python3", root.cli].concat(args))
    root.pending = q
    drain()
  }

  function refresh() { if (!poll.running) { poll.launched = false; poll.running = true } }
  function toggle() { run(["toggle"]) }
  function start(ph) { run(["start", ph]) }
  function skip() { run(["skip"]) }
  function reset() { run(["reset"]) }
  function preset(f, s, l) { run(["preset", String(f), String(s), String(l)]) }
  function setGoal(n) { run(["goal", String(n)]) }

  // Local 1 Hz tick for the countdown; only while something is running.
  Timer {
    interval: 1000; repeat: true; running: root.running
    onTriggered: {
      root.now = Date.now() / 1000
      // Phase just ended: let the engine complete it (and notify) right away.
      if (root.remaining <= 0) root.refresh()
    }
  }
  // Slow poll keeps the bar honest if the CLI was used from a terminal.
  Timer { interval: 15000; repeat: true; running: true; triggeredOnStart: true; onTriggered: root.refresh() }
}
