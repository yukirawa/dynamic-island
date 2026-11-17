#ifndef AUDIOSPECTRUM_H
#define AUDIOSPECTRUM_H

#include <QObject>
#include <QVariantList>

// Reads the default output's monitor stream through PipeWire and splits it
// into seven band energies, so the island's music indicator can follow the
// sound that is actually playing instead of a synthesised loop.
//
// When there is no PipeWire session (or the stream never reaches STREAMING),
// "live" stays false and the QML side falls back to its own animation.
class AudioLevels : public QObject
{
    Q_OBJECT
    Q_PROPERTY(bool enabled READ enabled WRITE setEnabled NOTIFY enabledChanged)
    Q_PROPERTY(bool live READ live NOTIFY liveChanged)
    Q_PROPERTY(QVariantList bands READ bands NOTIFY bandsChanged)
public:
    explicit AudioLevels(QObject *parent = nullptr);
    ~AudioLevels() override;

    // The PulseAudio monitor is only needed while music plays. Starting it on
    // demand keeps an idle island from carrying an audio thread and a stream.
    bool enabled() const { return m_enabled; }
    void setEnabled(bool on);

    bool live() const { return m_live; }
    QVariantList bands() const { return m_bands; }

signals:
    void enabledChanged();
    void liveChanged();
    void bandsChanged();

private:
    void setLive(bool on);
    void setBands(const QVariantList &bands);

    class Private;
    Private *const d;

    bool m_enabled = false;
    bool m_live = false;
    QVariantList m_bands;
};

#endif // AUDIOSPECTRUM_H
