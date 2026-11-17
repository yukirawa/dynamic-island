#pragma once

#include <QObject>
#include <QPointer>
#include <QRectF>
#include <QTimer>
#include <QWindow>
#include <qqmlintegration.h>

class InputRegion : public QObject
{
    Q_OBJECT
    QML_ELEMENT
    QML_SINGLETON

public:
    using QObject::QObject;

    // On Qt Wayland, QWindow::setMask sets the surface input region, so clicks
    // outside the visible pill fall through to the panel underneath.
    // QML asks for a new rect on every animation frame, and every call reaches
    // the compositor, so the mask is updated on a timer instead: a burst of
    // rects ends up as one update with the last rect of the burst.
    Q_INVOKABLE void set(QWindow *window, const QRectF &rect);
    // The mask for rect; an empty one becomes 1x1, since an empty mask lets the whole window take clicks.
    static QRect maskRect(const QRectF &rect);
    // Lets the layer-shell surface take keyboard focus when clicked (OnDemand), or never.
    // Exclusive takes it straight away, for the panel opened with the shortcut.
    Q_INVOKABLE void setKeyboard(QWindow *window, bool on, bool exclusive = false);
    // Overlay sits above full-screen windows; Top, the usual layer, sits below them.
    Q_INVOKABLE void setLayer(QWindow *window, bool overlay);

private:
    // Applies the rect that was asked for last and clears it.
    void applyMask();

    QTimer *m_maskTimer = nullptr;
    QPointer<QWindow> m_pendingWindow;
    QRectF m_pendingRect;
};
