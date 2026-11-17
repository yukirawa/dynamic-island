import QtQuick
import org.kde.plasma.private.volume
import "logic.js" as L

// Speakers, microphones and app streams from Plasma's own volume module.
QtObject {
    id: sound

    // Only listen to the mic while the mixer is on screen.
    property bool monitorMic: false
    property var outputs: []
    property var inputs: []
    property var apps: []
    // Apps recording from a microphone right now.
    property var recorders: []
    readonly property var defaultInput: inputs.find(d => d.default) || null
    readonly property var defaultOutput: outputs.find(d => d.default) || null
    readonly property real micLevel: monitorMic && monitor.available ? monitor.volume : -1

    function collect(list) {
        const out = []
        for (let i = 0; i < list.count; ++i)
            out.push(list.objectAt(i).p)
        return out
    }
    // The Pulse objects behind the arrays are stable, so element identity tells a real
    // change apart: a list is only replaced when its contents changed, so one chatty
    // Instantiator doesn't churn every view bound to the others.
    function sameItems(a, b) {
        if (a === b)
            return true
        if (!a || !b || a.length !== b.length)
            return false
        for (let i = 0; i < a.length; ++i)
            if (a[i] !== b[i])
                return false
        return true
    }
    function setList(name, next) {
        if (!sameItems(sound[name], next))
            sound[name] = next
    }
    // Each list comes from its own Instantiator, so a change only re-collects that one.
    function syncOutputs() { setList("outputs", collect(sinkList).filter(d => !d.virtualDevice)) }
    function syncInputs() { setList("inputs", collect(sourceList).filter(d => !d.virtualDevice && !d.name.endsWith(".monitor"))) }
    function syncApps() { setList("apps", collect(appList).filter(a => !a.virtualStream)) }
    function syncRecorders() { setList("recorders", L.recordingApps(collect(recordList))) }
    function rebuild() {
        syncOutputs()
        syncInputs()
        syncApps()
        syncRecorders()
    }

    property Instantiator sinkList: Instantiator {
        model: SinkModel {}
        delegate: QtObject { required property var model; readonly property var p: model.PulseObject }
        onObjectAdded: Qt.callLater(sound.syncOutputs)
        onObjectRemoved: Qt.callLater(sound.syncOutputs)
    }
    property Instantiator sourceList: Instantiator {
        model: SourceModel {}
        delegate: QtObject { required property var model; readonly property var p: model.PulseObject }
        onObjectAdded: Qt.callLater(sound.syncInputs)
        onObjectRemoved: Qt.callLater(sound.syncInputs)
    }
    property Instantiator appList: Instantiator {
        model: SinkInputModel {}
        delegate: QtObject { required property var model; readonly property var p: model.PulseObject }
        onObjectAdded: Qt.callLater(sound.syncApps)
        onObjectRemoved: Qt.callLater(sound.syncApps)
    }

    property Instantiator recordList: Instantiator {
        model: SourceOutputModel {}
        delegate: QtObject { required property var model; readonly property var p: model.PulseObject }
        onObjectAdded: Qt.callLater(sound.syncRecorders)
        onObjectRemoved: Qt.callLater(sound.syncRecorders)
    }

    property VolumeMonitor monitor: VolumeMonitor {
        target: sound.monitorMic ? sound.defaultInput : null
    }
}
