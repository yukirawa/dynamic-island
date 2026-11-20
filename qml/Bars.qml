import QtQuick

// Music level indicator inside the closed pill, in the spirit of the iPhone's
// Dynamic Island: a run of small bars whose heights follow the sound. The run
// is split in two bands, low on the left and high on the right, so the bass
// side moves more slowly and taller than the treble side.
//
// Everything is driven by one FrameAnimation and frame-rate independent
// smoothing, so the motion is continuous instead of the stepped loop the old
// SequentialAnimation bars had. There is no MPRIS spectrum to read, so the
// levels are synthesised from layered sine noise with a slow beat envelope;
// the shape reads like music without jumping to unrelated values.
Item {
    id: bars

    property bool running: false
    property color color: "#e8e2d0"

    // Bars are only meaningful while the pill is on screen and playing.
    readonly property bool active: bars.running && bars.visible && bars.opacity > 0.02
    // Live band energies from the playing sound (PipeWire). Undefined in the
    // tests and when there is no PipeWire session, so the synthesised motion
    // below takes over.
    readonly property var levels: (typeof AudioLevels !== "undefined" && AudioLevels.live) ? AudioLevels.bands : null

    // 4 low bars on the left, 3 high bars on the right.
    readonly property int lowBars: 4
    readonly property int highBars: 3
    readonly property int barCount: bars.lowBars + bars.highBars
    readonly property real gap: 2
    readonly property real barWidth: 3
    readonly property real minHeight: 3
    readonly property real maxHeight: bars.height
    width: bars.barCount * bars.barWidth + (bars.barCount - 1) * bars.gap
    height: 14

    function noise(t, seed) {
        // Two layered harmonics per bar: enough organic variation without
        // ever approaching a real random walk that would look broken.
        return 0.5 + 0.31 * Math.sin(t * 1.7 + seed * 1.13)
             + 0.19 * Math.sin(t * 3.1 + seed * 2.71);
    }

    function stepToward(current, target, dt, rate) {
        // Exponential smoothing: identical motion on 60 Hz and 120 Hz.
        return current + (target - current) * (1 - Math.exp(-dt * rate));
    }

    // Frame-driven clock. Paused while hidden so a closed or tucked pill
    // costs nothing, and no Timer can fire out of step with the compositor.
    FrameAnimation {
        running: bars.active
        onTriggered: {
            var dt = Math.max(0.004, Math.min(0.05, frameTime));
            var t = elapsedTime;
            // A 125 bpm pulse the low band leans on; the high band runs twice
            // as fast and with less weight, which is what splits the two bands
            // apart visually.
            var beatLow = Math.pow(Math.max(0, Math.sin(t * Math.PI * (125 / 60))), 4);
            var beatHigh = Math.pow(Math.max(0, Math.sin(t * Math.PI * (250 / 60) + 0.4)), 6);

            for (var i = 0; i < repeater.count; i++) {
                var bar = repeater.itemAt(i);
                var low = i < bars.lowBars;
                var live = bars.levels && bars.levels.length > i ? bars.levels[i] : -1;
                var target;
                if (live >= 0) {
                    // Real sound: the bar rides the band it belongs to, the
                    // left four on low frequencies, the right three on high.
                    target = bars.minHeight + live * (bars.maxHeight - bars.minHeight)
                } else {
                    var seed = low ? i * 3.7 : (i - bars.lowBars) * 5.3 + 11;
                    // Low band sweeps a wide, slow range; high band stays short and busy.
                    var range = low ? 1 : 0.55;
                    var base = bars.noise(t * (low ? 1.0 : 2.2), seed) * range;
                    var pulse = low ? beatLow * 0.75 : beatHigh * 0.4;
                    var level = Math.min(1, base + pulse);
                    target = bars.minHeight + level * (bars.maxHeight - bars.minHeight)
                }
                // Quick attack, slower release: bars snap up and fall away.
                var rate = target > bar.height ? (live >= 0 ? 26 : 14) : (live >= 0 ? 12 : 6);
                bar.height = bars.stepToward(bar.height, target, dt, rate);
            }
        }
    }

    Repeater {
        id: repeater
        model: bars.barCount
        Rectangle {
            id: bar
            required property int index
            readonly property bool low: bar.index < bars.lowBars
            x: bar.index * (bars.barWidth + bars.gap)
            y: bars.height - bar.height
            width: bars.barWidth
            height: bars.minHeight
            radius: bars.barWidth / 2
            // The treble half sits a little back so the split reads at a glance.
            color: Qt.rgba(bars.color.r, bars.color.g, bars.color.b, bar.low ? 1 : 0.62)
        }
    }

    // Coming back from a pause the bars rise from the resting height instead
    // of jumping to a full-height shape.
    onRunningChanged: if (!running) {
        for (var i = 0; i < repeater.count; i++)
            repeater.itemAt(i).height = bars.minHeight
    }
}
