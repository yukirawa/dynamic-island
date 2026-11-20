#include <LayerShellQt/Window>
#include <QGuiApplication>
#include <QDebug>
#include <QImageReader>
#include <QPixmapCache>
#include <QQmlApplicationEngine>
#include <QQmlContext>
#include <QQuickWindow>
#include <QTranslator>

#include "audiospectrum.h"

int main(int argc, char *argv[])
{
    // The settings window is QQC.ApplicationWindow, not a Qt Widget: QGuiApplication
    // is enough and avoids loading QtWidgets and its style plugins on every start.
    QGuiApplication app(argc, argv);
    // Bound image/pixmap memory caches to sensible limits for a persistent desktop overlay.
    QPixmapCache::setCacheLimit(8192);
    QImageReader::setAllocationLimit(64);
    // KGlobalAccel files the shortcut under this app in System Settings → Shortcuts.
    app.setDesktopFileName(QStringLiteral("dynamic-island"));
    app.setApplicationDisplayName(QStringLiteral("Dynamic Island"));

    // Japanese only: the one catalogue we ship is always applied, independent
    // of the desktop locale. Tests set DYNAMIC_ISLAND_TEST_EN so their English
    // source-string assertions still work; production never sets it.
    // The translator must outlive the application, hence the static storage.
    static QTranslator translator;
    if (!qEnvironmentVariableIsSet("DYNAMIC_ISLAND_TEST_EN")
        && translator.load(QStringLiteral(":/i18n/translations/dynamic-island-ja.qm"))) {
        app.installTranslator(&translator);
    }

    // Closing the settings window must not quit the island.
    app.setQuitOnLastWindowClosed(false);

    // Seven band levels from the playing sound; the pill's meter animates
    // from these when PulseAudio is reachable, and from its own motion otherwise.
    // The PulseAudio thread is started only while music is actually playing
    // (AudioLevels.enabled from QML), so an idle island has no audio thread at all.
    // Declared before the engine so the QML objects, which bind to it, are
    // gone before the levels object is destroyed.
    AudioLevels audioLevels;

    QQmlApplicationEngine engine;
    engine.rootContext()->setContextProperty(QStringLiteral("AudioLevels"), &audioLevels);
    engine.loadFromModule("Island", "Main");
    if (engine.rootObjects().isEmpty())
        return 1;

    auto *window = qobject_cast<QQuickWindow *>(engine.rootObjects().first());
    auto *layer = LayerShellQt::Window::get(window);
    if (!layer) {
        // Not a layer-shell surface (wrong platform, or no compositor support).
        // Continuing would dereference null; report it instead of crashing.
        qWarning("Dynamic Island needs a Wayland layer-shell compositor");
        return 1;
    }
    // KWin maps unknown scopes to a normal window, which Show Desktop hides.
    layer->setScope(QStringLiteral("dock"));
    layer->setLayer(LayerShellQt::Window::LayerTop);
    layer->setAnchors(LayerShellQt::Window::AnchorTop);
    layer->setExclusiveZone(0);
    layer->setKeyboardInteractivity(LayerShellQt::Window::KeyboardInteractivityNone);
    layer->setMargins({0, 0, 0, 0});
    window->show();

    return app.exec();
}
