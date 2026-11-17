#include "inputregion.h"

#include <LayerShellQt/Window>
#include <QRegion>

namespace
{
// How long the mask waits for the island to settle. Long enough to swallow the
// frames of an animation, short enough that the pill takes clicks right away.
constexpr int kMaskUpdateMs = 35;
}

QRect InputRegion::maskRect(const QRectF &rect)
{
    const QRect r = rect.toAlignedRect();
    return r.isEmpty() ? QRect(r.topLeft(), QSize(1, 1)) : r;
}

void InputRegion::set(QWindow *window, const QRectF &rect)
{
    if (!window)
        return;
    // Another window gets its own mask; the old one keeps the rect it asked for.
    if (m_pendingWindow && m_pendingWindow != window)
        applyMask();
    m_pendingWindow = window;
    m_pendingRect = rect;
    if (!m_maskTimer) {
        m_maskTimer = new QTimer(this);
        m_maskTimer->setSingleShot(true);
        m_maskTimer->setInterval(kMaskUpdateMs);
        connect(m_maskTimer, &QTimer::timeout, this, &InputRegion::applyMask);
    }
    // The timer is not restarted: while the island grows or shrinks the mask
    // follows the newest rect every kMaskUpdateMs, and the last rect of the
    // animation is applied when the timer fires after it.
    if (!m_maskTimer->isActive())
        m_maskTimer->start();
}

void InputRegion::applyMask()
{
    QWindow *window = m_pendingWindow;
    if (!window)
        return;
    const QRectF rect = m_pendingRect;
    m_pendingWindow = nullptr;
    window->setMask(QRegion(maskRect(rect)));
}

void InputRegion::setKeyboard(QWindow *window, bool on, bool exclusive)
{
    if (window)
        LayerShellQt::Window::get(window)->setKeyboardInteractivity(!on      ? LayerShellQt::Window::KeyboardInteractivityNone
                                                                     : exclusive ? LayerShellQt::Window::KeyboardInteractivityExclusive
                                                                                 : LayerShellQt::Window::KeyboardInteractivityOnDemand);
}

void InputRegion::setLayer(QWindow *window, bool overlay)
{
    if (window)
        LayerShellQt::Window::get(window)->setLayer(overlay ? LayerShellQt::Window::LayerOverlay : LayerShellQt::Window::LayerTop);
}
