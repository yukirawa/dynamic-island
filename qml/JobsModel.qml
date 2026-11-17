import QtQuick
import "logic.js" as L

QtObject {
    id: model

    property var now: () => Date.now()
    // Keyed by sender + object path; reassigned on every change so bindings follow.
    property var jobs: ({})
    property int tickCount: 0
    // The summary object is only replaced when its contents change: shown holds the
    // live job objects, so element identity tells "nothing happened" apart, and views
    // bound to the summary don't get rebuilt on every tick.
    readonly property var summary: summaryCache
    property var summaryCache: ({ shown: [], count: 0, percent: 0 })
    signal finished(var job)
    signal failed(var job, string error)

    function tick() {
        tickCount++
        refresh()
    }

    function sameShown(a, b) {
        if (a === b)
            return true
        if (!a || !b || a.length !== b.length)
            return false
        for (let i = 0; i < a.length; ++i)
            if (a[i] !== b[i])
                return false
        return true
    }

    function refresh() {
        const next = L.jobsSummary(jobs, now())
        const prev = summaryCache
        if (prev.count === next.count && prev.percent === next.percent && sameShown(prev.shown, next.shown))
            return
        summaryCache = next
    }

    // jobMerge starts from the old job, so key-by-key identity is enough to tell an
    // update that changed nothing apart from one that did.
    function sameJob(oldJob, merged) {
        if (!oldJob)
            return false
        let count = 0
        for (const k in merged) {
            if (merged[k] !== oldJob[k])
                return false
            count++
        }
        for (const k in oldJob)
            count--
        return count === 0
    }

    function update(key, props) {
        const merged = L.jobMerge(jobs[key] || {}, props, now())
        if (sameJob(jobs[key], merged))
            return
        const next = Object.assign({}, jobs)
        next[key] = merged
        jobs = next
        refresh()
    }

    function end(key, code, error) {
        const job = jobs[key]
        if (!job)
            return
        remove(k => k === key)
        // Code 1 is KDE's "killed": the user cancelled it, so no alert.
        if (now() - job.startMs < 2000 || code === 1)
            return
        const out = { name: L.jobName(job), title: job.title || "", folder: folderOf(job) }
        if (code === 0)
            finished(out)
        else
            failed(out, error)
    }

    function dropSender(sender) { remove(k => k.startsWith(sender + " ")) }
    function clear() {
        if (Object.keys(jobs).length === 0)
            return
        jobs = {}
        refresh()
    }

    function remove(match) {
        const next = {}
        let changed = false
        for (const k in jobs) {
            if (match(k))
                changed = true
            else
                next[k] = jobs[k]
        }
        if (!changed)
            return
        jobs = next
        refresh()
    }

    // destUrl is the target folder when the app sends it; otherwise the folder holding descriptionValue2,
    // which for an extraction is the destination folder itself.
    function folderOf(job) {
        if (job.destUrl)
            return job.destUrl
        let path = String(job.descriptionValue2 || "")
        if (!path.startsWith("/"))
            return ""
        if (job.title !== "Extracting Files")
            path = path.substring(0, path.lastIndexOf("/"))
        return "file://" + path.split("/").map(encodeURIComponent).join("/")
    }

    property Timer ticker: Timer {
        interval: 1000
        repeat: true
        running: Object.keys(model.jobs).length > 0
        onTriggered: model.tick()
    }
}
