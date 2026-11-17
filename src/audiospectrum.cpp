#include "audiospectrum.h"

#include <pulse/introspect.h>
#include <pulse/context.h>
#include <pulse/def.h>
#include <pulse/error.h>
#include <pulse/mainloop.h>
#include <pulse/sample.h>
#include <pulse/stream.h>
#include <pulse/subscribe.h>
#include <pulse/thread-mainloop.h>

#include <QMetaObject>
#include <QPointer>
#include <QVariantList>

#include <atomic>
#include <chrono>
#include <condition_variable>
#include <cmath>
#include <cstring>
#include <mutex>
#include <string>
#include <thread>
#include <utility>

namespace {

constexpr int FFT_SIZE = 512;          // spectrum resolution per audio batch
constexpr int BAND_COUNT = 7;          // matches the seven bars in the pill
constexpr int SAMPLE_RATE = 48000;     // PulseAudio resamples the capture into this
// Band edges in Hz: the left four bars carry the bass side, the right three
// the treble side, like the low/high split the meter draws.
constexpr int BAND_EDGES[BAND_COUNT + 1] = {0, 190, 380, 560, 940, 1880, 3750, 24000};
constexpr double GAIN = 16.0;           // amplitude -> 0..1 scale for typical music
constexpr long EMIT_US = 30000;         // band updates reach the pill ~33 times a second
// Must be double: declared as an integer type, 30000/1000000.0 truncates to 0,
// the release filter below then never advances, and every band reads as silence.
constexpr double EMIT_STEP = EMIT_US / 1000000.0; // seconds between updates
static_assert(EMIT_STEP > 0.0, "a zero dt pins the smoothed bands at zero");

void fft(double *re, double *im, int n)
{
    // Iterative radix-2 Cooley-Tukey; small and allocation-free.
    for (int i = 1, j = 0; i < n; ++i) {
        int bit = n >> 1;
        for (; j & bit; bit >>= 1)
            j ^= bit;
        j ^= bit;
        if (i < j) {
            std::swap(re[i], re[j]);
            std::swap(im[i], im[j]);
        }
    }
    for (int len = 2; len <= n; len <<= 1) {
        const double ang = -2.0 * M_PI / len;
        const double wr = std::cos(ang);
        const double wi = std::sin(ang);
        const int half = len / 2;
        for (int i = 0; i < n; i += len) {
            double cr = 1.0, ci = 0.0;
            for (int k = 0; k < half; ++k) {
                const double ur = re[i + k];
                const double ui = im[i + k];
                const int t = i + k + half;
                const double vr = re[t] * cr - im[t] * ci;
                const double vi = re[t] * ci + im[t] * cr;
                re[i + k] = ur + vr;
                im[i + k] = ui + vi;
                re[t] = ur - vr;
                im[t] = ui - vi;
                const double ncr = cr * wr - ci * wi;
                ci = cr * wi + ci * wr;
                cr = ncr;
            }
        }
    }
}

} // namespace

// The audio side lives on PulseAudio's threaded mainloop: the default sink
// name, the monitor source of that sink and the stream states all change from
// callbacks dispatched there, so touching them from the GUI thread would race.
class AudioLevels::Private
{
public:
    explicit Private(AudioLevels *owner) : q(owner) {}
    ~Private() { stop(); }

    void start()
    {
        if (started.exchange(true))
            return;
        stopping.store(false);
        thread = std::thread([this] { run(); });
    }

    void stop()
    {
        if (!started.load())
            return;
        // Waking the wait below lets the worker thread stop the mainloop
        // itself and tear the session down from there; joining then waits for
        // that to finish before the object goes away.
        if (!stopping.exchange(true))
            shutdownCv.notify_all();
        if (thread.joinable())
            thread.join();
        // Allow a later setEnabled(true) to start a fresh session.
        stopping.store(false);
        started.store(false);
    }

private:
    void run()
    {
        loop = pa_threaded_mainloop_new();
        if (!loop)
            return;
        if (pa_threaded_mainloop_start(loop) < 0) {
            pa_threaded_mainloop_free(loop);
            loop = nullptr;
            return;
        }
        pa_threaded_mainloop_lock(loop);

        auto *api = pa_threaded_mainloop_get_api(loop);
        ctx = pa_context_new(api, "Dynamic Island");
        if (!ctx) {
            pa_threaded_mainloop_unlock(loop);
            pa_threaded_mainloop_stop(loop);
            pa_threaded_mainloop_free(loop);
            loop = nullptr;
            return;
        }
        pa_context_set_state_callback(ctx, contextState, this);
        pa_context_connect(ctx, nullptr, PA_CONTEXT_NOFLAGS, nullptr);

        pa_threaded_mainloop_unlock(loop);

        // The loop thread now serves PulseAudio (callbacks, stream reads);
        // this thread simply waits for the shutdown signal. Waiting on
        // pa_threaded_mainloop_wait() instead would return as soon as the
        // connection starts, and the teardown below would kill the session.
        {
            std::unique_lock<std::mutex> lock(shutdownMutex);
            shutdownCv.wait(lock, [this] { return stopping.load(); });
        }
        // PulseAudio objects must be disconnected and unreffed with the
        // threaded mainloop locked. Doing it after stop(), unlocked, races
        // the loop thread's callbacks and can crash during shutdown.
        pa_threaded_mainloop_lock(loop);
        if (stream) {
            pa_stream_disconnect(stream);
            pa_stream_unref(stream);
            stream = nullptr;
        }
        if (ctx) {
            pa_context_disconnect(ctx);
            pa_context_unref(ctx);
            ctx = nullptr;
        }
        pa_threaded_mainloop_unlock(loop);
        pa_threaded_mainloop_stop(loop);
        pa_threaded_mainloop_free(loop);
        loop = nullptr;
    }

    static void contextState(pa_context *c, void *data)
    {
        auto self = static_cast<AudioLevels::Private *>(data);
        switch (pa_context_get_state(c)) {
        case PA_CONTEXT_READY:
            // Watch for the default sink moving (Bluetooth headphones plugged
            // in, output switched) so the meter keeps following what plays.
            pa_context_set_subscribe_callback(c, subscription, self);
            pa_context_subscribe(c, PA_SUBSCRIPTION_MASK_SERVER, nullptr, nullptr);
            self->refresh();
            break;
        case PA_CONTEXT_FAILED:
        case PA_CONTEXT_TERMINATED:
            if (self->live) {
                self->live = false;
                const QPointer<AudioLevels> guard(self->q);
                QMetaObject::invokeMethod(self->q, [guard] {
                    if (guard)
                        guard->setLive(false);
                }, Qt::QueuedConnection);
            }
            break;
        default:
            break;
        }
    }

    static void subscription(pa_context *c, pa_subscription_event_type_t type, uint32_t index, void *data)
    {
        Q_UNUSED(c)
        Q_UNUSED(index)
        auto self = static_cast<AudioLevels::Private *>(data);
        const int facility = type & PA_SUBSCRIPTION_EVENT_FACILITY_MASK;
        const int event = type & PA_SUBSCRIPTION_EVENT_TYPE_MASK;
        if (facility == PA_SUBSCRIPTION_EVENT_SERVER && event == PA_SUBSCRIPTION_EVENT_CHANGE)
            self->refresh();
    }

    void refresh()
    {
        if (!ctx || pa_context_get_state(ctx) != PA_CONTEXT_READY)
            return;
        pa_context_get_server_info(ctx, serverInfo, this);
    }

    static void serverInfo(pa_context *c, const pa_server_info *info, void *data)
    {
        Q_UNUSED(c)
        if (!info)
            return;
        auto self = static_cast<AudioLevels::Private *>(data);
        if (self->sink == info->default_sink_name)
            return;
        self->sink = info->default_sink_name;
        // Find the monitor source of that sink: the sound actually playing.
        pa_context_get_source_info_list(c, sourceInfo, data);
    }

    static void sourceInfo(pa_context *c, const pa_source_info *info, int eol, void *data)
    {
        auto self = static_cast<AudioLevels::Private *>(data);
        if (eol) {
            // No monitor found (a dummy sink): leave the old capture alone.
            return;
        }
        if (info->monitor_of_sink_name && self->sink == info->monitor_of_sink_name) {
            if (self->monitor == info->name)
                return;
            self->monitor = info->name;
            self->openStream(c);
        }
    }

    void openStream(pa_context *c)
    {
        // Called with the mainloop locked.
        if (stream) {
            pa_stream_disconnect(stream);
            pa_stream_unref(stream);
            stream = nullptr;
        }
        pa_sample_spec ss;
        ss.format = PA_SAMPLE_FLOAT32NE;
        ss.rate = SAMPLE_RATE;
        ss.channels = 1;
        stream = pa_stream_new(c, "Music level", &ss, nullptr);
        if (!stream)
            return;
        pa_stream_set_read_callback(stream, readSamples, this);
        pa_stream_set_state_callback(stream, streamState, this);
        pa_buffer_attr attr;
        std::memset(&attr, 0, sizeof(attr));
        attr.fragsize = sizeof(float) * 512;          // a few frames per read
        attr.maxlength = static_cast<uint32_t>(-1);
        pa_stream_connect_record(stream, monitor.c_str(), &attr, PA_STREAM_ADJUST_LATENCY);
    }

    static void streamState(pa_stream *s, void *data)
    {
        auto self = static_cast<AudioLevels::Private *>(data);
        const bool on = pa_stream_get_state(s) == PA_STREAM_READY;
        if (self->live != on) {
            self->live = on;
            const QPointer<AudioLevels> guard(self->q);
            QMetaObject::invokeMethod(self->q, [guard, on] {
                if (guard)
                    guard->setLive(on);
            }, Qt::QueuedConnection);
        }
    }

    static void readSamples(pa_stream *s, size_t length, void *data)
    {
        Q_UNUSED(length)
        auto self = static_cast<AudioLevels::Private *>(data);
        const double now = std::chrono::duration<double>(
            std::chrono::steady_clock::now().time_since_epoch()).count();

        const void *p = nullptr;
        while (pa_stream_peek(s, &p, &length) == 0 && length > 0) {
            if (p) {
                const auto *samples = static_cast<const float *>(p);
                for (size_t i = 0; i < length / sizeof(float); ++i)
                    self->push(samples[i]);
            }
            pa_stream_drop(s);
        }

        if (now - self->lastEmit >= EMIT_STEP) {
            self->lastEmit = now;
            QVariantList list;
            list.reserve(BAND_COUNT);
            for (int i = 0; i < BAND_COUNT; ++i)
                list << self->smoothed[i];
            const QPointer<AudioLevels> guard(self->q);
            QMetaObject::invokeMethod(self->q, [guard, list] {
                if (guard)
                    guard->setBands(list);
            }, Qt::QueuedConnection);
        }
    }

    void push(float sample)
    {
        ring[ringFill] = sample;
        if (++ringFill == FFT_SIZE) {
            transform();
            ringFill = 0;
        }
    }

    void transform()
    {
        double re[FFT_SIZE];
        double im[FFT_SIZE] = {};
        for (int i = 0; i < FFT_SIZE; ++i) {
            const double w = 0.5 - 0.5 * std::cos(2.0 * M_PI * i / (FFT_SIZE - 1));
            re[i] = ring[i] * w; // Hann: keeps each bar out of its neighbours
        }
        fft(re, im, FFT_SIZE);

        double power[BAND_COUNT] = {};
        int counts[BAND_COUNT] = {};
        const double binHz = (double)SAMPLE_RATE / FFT_SIZE;
        for (int k = 1; k < FFT_SIZE / 2; ++k) {
            const double hz = k * binHz;
            int band = BAND_COUNT - 1;
            for (int b = 0; b < BAND_COUNT; ++b) {
                if (hz >= BAND_EDGES[b] && hz < BAND_EDGES[b + 1]) {
                    band = b;
                    break;
                }
            }
            const double mag = 2.0 * std::hypot(re[k], im[k]) / FFT_SIZE;
            power[band] += mag * mag;
            counts[band]++;
        }
        // Fast attack, slower release: a drum hit snaps up, quiet falls away.
        // dt is the time since the previous transform (one per 512-sample
        // ring fill, ~11 ms here); measuring it keeps the rates below honest
        // whatever fragment size the server happens to deliver. It is measured
        // once per transform: inside the band loop every band after the first
        // would see a dt of zero and freeze.
        const double now = std::chrono::duration<double>(
            std::chrono::steady_clock::now().time_since_epoch()).count();
        const double dt = lastTransform > 0.0 ? std::min(0.05, now - lastTransform) : EMIT_STEP;
        lastTransform = now;

        for (int b = 0; b < BAND_COUNT; ++b) {
            const double mag = counts[b] ? std::sqrt(power[b] / counts[b]) : 0.0;
            const double level = std::min(1.0, mag * GAIN);
            const double rate = level > smoothed[b] ? 24.0 : 10.0;
            smoothed[b] += (level - smoothed[b]) * (1.0 - std::exp(-dt * rate));
        }
    }

    AudioLevels *q;
    std::thread thread;
    std::atomic<bool> stopping{false};
    std::atomic<bool> started{false};
    bool live = false;
    std::string sink;
    std::string monitor;
    double ring[FFT_SIZE] = {};
    int ringFill = 0;
    double smoothed[BAND_COUNT] = {};
    double lastTransform = 0.0;
    double lastEmit = 0.0;
    std::mutex shutdownMutex;
    std::condition_variable shutdownCv;

    struct pa_threaded_mainloop *loop = nullptr;    struct pa_context *ctx = nullptr;
    struct pa_stream *stream = nullptr;
};

AudioLevels::AudioLevels(QObject *parent) : QObject(parent), d(new Private(this))
{
    // No PulseAudio thread until QML asks for levels while music is playing.
}

AudioLevels::~AudioLevels()
{
    d->stop();
    delete d;
}

void AudioLevels::setEnabled(bool on)
{
    if (m_enabled == on)
        return;
    m_enabled = on;
    if (on)
        d->start();
    else {
        d->stop();
        m_live = false;
        m_bands.clear();
        Q_EMIT liveChanged();
        Q_EMIT bandsChanged();
    }
    Q_EMIT enabledChanged();
}

void AudioLevels::setLive(bool on)
{
    // A callback queued just before setEnabled(false) must not turn the meter
    // back on with stale data after the audio thread has been stopped.
    if (!m_enabled)
        on = false;
    if (m_live != on) {
        m_live = on;
        emit liveChanged();
    }
}

void AudioLevels::setBands(const QVariantList &bands)
{
    if (!m_enabled || bands == m_bands)
        return;
    m_bands = bands;
    emit bandsChanged();
}
