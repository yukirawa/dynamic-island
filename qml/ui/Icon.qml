import QtQuick

// Self-drawn symbolic icon. Kirigami.Icon used to run an icon-theme scan at
// start-up; this draws the handful of shapes the island needs on a Canvas.
// Unknown names get a neutral dot, so a new app icon never breaks the UI.
Item {
    id: icon
    property string source: ""
    property string fallback: ""
    property color color: "#e8e2d0"
    property bool isMask: true
    implicitWidth: 16
    implicitHeight: 16

    Canvas {
        id: canvas
        anchors.fill: parent
        opacity: icon.enabled ? 1 : 0.35
        onPaint: {
            const ctx = getContext("2d")
            if (!ctx)
                return
            ctx.reset()
            ctx.strokeStyle = icon.color
            ctx.fillStyle = icon.color
            ctx.lineWidth = Math.max(1, width / 9)
            ctx.lineCap = "round"
            ctx.lineJoin = "round"
            const s = source || icon.fallback || ""
            const w = width, h = height, cx = w / 2, cy = h / 2
            if (s.indexOf("close") >= 0 || s.indexOf("remove") >= 0 || s.indexOf("delete") >= 0) {
                ctx.beginPath()
                ctx.moveTo(w * .25, h * .25); ctx.lineTo(w * .75, h * .75)
                ctx.moveTo(w * .75, h * .25); ctx.lineTo(w * .25, h * .75)
                ctx.stroke()
            } else if (s.indexOf("checkmark") >= 0) {
                ctx.beginPath()
                ctx.moveTo(w * .16, h * .55); ctx.lineTo(w * .42, h * .8); ctx.lineTo(w * .85, h * .2)
                ctx.stroke()
            } else if (s.indexOf("playback-start") >= 0 || s.indexOf("media-play") >= 0) {
                ctx.beginPath()
                ctx.moveTo(w * .3, h * .18); ctx.lineTo(w * .82, h * .5); ctx.lineTo(w * .3, h * .82)
                ctx.closePath(); ctx.fill()
            } else if (s.indexOf("pause") >= 0) {
                ctx.fillRect(w * .3, h * .2, w * .14, h * .6)
                ctx.fillRect(w * .56, h * .2, w * .14, h * .6)
            } else if (s.indexOf("battery") >= 0) {
                ctx.strokeRect(w * .12, h * .3, w * .7, h * .4)
                ctx.fillRect(w * .84, h * .42, w * .08, h * .16)
                if (s.indexOf("charging") >= 0) {
                    ctx.beginPath()
                    ctx.moveTo(cx + w * .04, h * .32); ctx.lineTo(cx - w * .08, h * .52)
                    ctx.lineTo(cx + w * .02, h * .52); ctx.lineTo(cx - w * .04, h * .7)
                    ctx.stroke()
                } else {
                    const level = Number(String(s).match(/battery-(\d+)/)?.[1] || 50) / 100
                    ctx.fillRect(w * .16, h * .34, w * .62 * level, h * .32)
                }
            } else if (s.indexOf("microphone") >= 0 || s.indexOf("audio-input") >= 0) {
                ctx.beginPath(); ctx.arc(cx, h * .38, w * .18, 0, Math.PI * 2); ctx.stroke()
                ctx.beginPath()
                ctx.moveTo(cx - w * .3, h * .52)
                ctx.arc(cx, h * .52, w * .3, 0, Math.PI)
                ctx.moveTo(cx, h * .82); ctx.lineTo(cx, h * .52)
                ctx.stroke()
            } else if (s.indexOf("camera") >= 0) {
                ctx.strokeRect(w * .12, h * .3, w * .76, h * .5)
                ctx.beginPath(); ctx.arc(cx, h * .55, w * .15, 0, Math.PI * 2); ctx.stroke()
            } else if (s.indexOf("folder") >= 0) {
                ctx.beginPath()
                ctx.moveTo(w * .1, h * .28); ctx.lineTo(w * .45, h * .28)
                ctx.lineTo(w * .55, h * .4); ctx.lineTo(w * .9, h * .4)
                ctx.lineTo(w * .9, h * .78); ctx.lineTo(w * .1, h * .78)
                ctx.closePath(); ctx.stroke()
            } else if (s.indexOf("globe") >= 0 || s.indexOf("link") >= 0 || s.indexOf("external") >= 0) {
                ctx.beginPath(); ctx.arc(cx, cy, w * .32, 0, Math.PI * 2); ctx.stroke()
                ctx.beginPath()
                ctx.moveTo(cx - w * .32, cy); ctx.lineTo(cx + w * .32, cy)
                ctx.moveTo(cx, cy - h * .32); ctx.lineTo(cx, cy + h * .32)
                ctx.stroke()
            } else if (s.indexOf("download") >= 0) {
                ctx.beginPath()
                ctx.moveTo(cx, h * .16); ctx.lineTo(cx, h * .65)
                ctx.moveTo(cx - w * .22, h * .45); ctx.lineTo(cx, h * .67); ctx.lineTo(cx + w * .22, h * .45)
                ctx.moveTo(w * .18, h * .8); ctx.lineTo(w * .82, h * .8)
                ctx.stroke()
            } else if (s.indexOf("go-up") >= 0) {
                ctx.beginPath()
                ctx.moveTo(cx, h * .78); ctx.lineTo(cx, h * .24)
                ctx.moveTo(cx - w * .22, h * .46); ctx.lineTo(cx, h * .24); ctx.lineTo(cx + w * .22, h * .46)
                ctx.stroke()
            } else if (s.indexOf("refresh") >= 0 || s.indexOf("reset") >= 0) {
                ctx.beginPath(); ctx.arc(cx, cy, w * .3, .5, Math.PI * 1.7); ctx.stroke()
                ctx.beginPath()
                ctx.moveTo(cx + w * .3, cy - h * .12); ctx.lineTo(cx + w * .32, cy + h * .16); ctx.lineTo(cx + w * .06, cy + h * .08)
                ctx.stroke()
            } else if (s.indexOf("volume") >= 0 || s.indexOf("audio-volume") >= 0) {
                ctx.beginPath()
                ctx.moveTo(w * .12, h * .4); ctx.lineTo(w * .36, h * .4); ctx.lineTo(w * .58, h * .2)
                ctx.lineTo(w * .58, h * .8); ctx.lineTo(w * .36, h * .6); ctx.lineTo(w * .12, h * .6)
                ctx.closePath(); ctx.fill()
                if (s.indexOf("muted") < 0) {
                    ctx.beginPath(); ctx.arc(w * .66, h * .5, w * .12, -.8, .8); ctx.stroke()
                    ctx.beginPath(); ctx.arc(w * .66, h * .5, w * .22, -.8, .8); ctx.stroke()
                }
            } else if (s.indexOf("configure") >= 0 || s.indexOf("settings") >= 0 || s.indexOf("preferences") >= 0) {
                ctx.beginPath(); ctx.arc(cx, cy, w * .16, 0, Math.PI * 2); ctx.stroke()
                for (let i = 0; i < 8; ++i) {
                    const a = i * Math.PI / 4
                    ctx.beginPath()
                    ctx.moveTo(cx + Math.cos(a) * w * .22, cy + Math.sin(a) * h * .22)
                    ctx.lineTo(cx + Math.cos(a) * w * .36, cy + Math.sin(a) * h * .36)
                    ctx.stroke()
                }
            } else if (s.indexOf("notification") >= 0) {
                ctx.beginPath()
                ctx.moveTo(cx - w * .26, h * .72); ctx.lineTo(cx + w * .26, h * .72)
                ctx.moveTo(cx - w * .22, h * .58)
                ctx.arc(cx, h * .58, w * .22, Math.PI, 0)
                ctx.closePath(); ctx.stroke()
                ctx.beginPath(); ctx.arc(cx, h * .8, w * .05, 0, Math.PI * 2); ctx.fill()
            } else if (s.indexOf("caps") >= 0) {
                ctx.beginPath()
                ctx.moveTo(cx, h * .8); ctx.lineTo(cx, h * .25)
                ctx.moveTo(cx - w * .2, h * .45); ctx.lineTo(cx, h * .23); ctx.lineTo(cx + w * .2, h * .45)
                ctx.stroke()
            } else if (s.indexOf("edit") >= 0 || s.indexOf("copy") >= 0) {
                ctx.strokeRect(w * .16, h * .16, w * .48, h * .48)
                ctx.strokeRect(w * .36, h * .36, w * .48, h * .48)
            } else if (s.indexOf("list-add") >= 0 || s.indexOf("add") >= 0) {
                ctx.beginPath()
                ctx.moveTo(cx, h * .2); ctx.lineTo(cx, h * .8)
                ctx.moveTo(w * .2, cy); ctx.lineTo(w * .8, cy)
                ctx.stroke()
            } else if (s.indexOf("color") >= 0 || s.indexOf("brightness") >= 0) {
                ctx.beginPath(); ctx.arc(cx, cy, w * .2, 0, Math.PI * 2); ctx.stroke()
                for (let i = 0; i < 8; ++i) {
                    const a = i * Math.PI / 4
                    ctx.beginPath()
                    ctx.moveTo(cx + Math.cos(a) * w * .28, cy + Math.sin(a) * h * .28)
                    ctx.lineTo(cx + Math.cos(a) * w * .4, cy + Math.sin(a) * h * .4)
                    ctx.stroke()
                }
            } else if (s.indexOf("document-open") >= 0) {
                ctx.beginPath()
                ctx.moveTo(w * .1, h * .35); ctx.lineTo(w * .9, h * .35)
                ctx.lineTo(w * .78, h * .78); ctx.lineTo(w * .22, h * .78)
                ctx.closePath(); ctx.stroke()
            } else if (s !== "") {
                ctx.beginPath(); ctx.arc(cx, cy, w * .22, 0, Math.PI * 2); ctx.fill()
            }
        }
        Connections {
            target: icon
            function onSourceChanged() { canvas.requestPaint() }
            function onColorChanged() { canvas.requestPaint() }
            function onFallbackChanged() { canvas.requestPaint() }
            function onEnabledChanged() { canvas.requestPaint() }
        }
        onWidthChanged: requestPaint()
        onHeightChanged: requestPaint()
    }
}
