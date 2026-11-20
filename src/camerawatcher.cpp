#include "camerawatcher.h"

#include <QFile>

#include <cstring>
#include <dirent.h>
#include <fcntl.h>
#include <unistd.h>

CameraWatcher::CameraWatcher(QObject *parent)
    : QObject(parent)
{
    m_timer.setInterval(3000);
    connect(&m_timer, &QTimer::timeout, this, &CameraWatcher::poll);
}

void CameraWatcher::setEnabled(bool on)
{
    if (on == enabled())
        return;
    if (on) {
        m_timer.start();
        poll();
    } else {
        m_timer.stop();
        if (!m_apps.isEmpty()) {
            m_apps.clear();
            Q_EMIT appsChanged();
        }
    }
    Q_EMIT enabledChanged();
}

void CameraWatcher::poll()
{
    const QStringList found = scan(QStringLiteral("/proc"));
    if (found != m_apps) {
        m_apps = found;
        Q_EMIT appsChanged();
    }
}

QStringList CameraWatcher::scan(const QString &procRoot)
{
    // Plain openat/readdir/readlinkat with stack buffers avoids per-PID QByteArray/QFile heap allocations.
    QStringList names;
    const QByteArray root = QFile::encodeName(procRoot);
    const int procFd = ::open(root.constData(), O_RDONLY | O_DIRECTORY | O_CLOEXEC);
    if (procFd < 0)
        return names;
    DIR *proc = ::fdopendir(procFd);
    if (!proc) {
        ::close(procFd);
        return names;
    }
    while (const dirent *p = ::readdir(proc)) {
        if (p->d_name[0] < '0' || p->d_name[0] > '9')
            continue;
        const int pidFd = ::openat(procFd, p->d_name, O_RDONLY | O_DIRECTORY | O_CLOEXEC);
        if (pidFd < 0)
            continue;
        const int fdDirFd = ::openat(pidFd, "fd", O_RDONLY | O_DIRECTORY | O_CLOEXEC);
        if (fdDirFd < 0) {
            ::close(pidFd);
            continue;
        }
        // Other users' processes aren't readable; that's fine, the camera user is ours.
        DIR *fds = ::fdopendir(fdDirFd);
        if (!fds) {
            ::close(fdDirFd);
            ::close(pidFd);
            continue;
        }
        bool camera = false;
        char target[64];
        while (const dirent *fd = ::readdir(fds)) {
            const ssize_t n = ::readlinkat(fdDirFd, fd->d_name, target, sizeof target - 1);
            if (n >= 10 && std::memcmp(target, "/dev/video", 10) == 0) {
                camera = true;
                break;
            }
        }
        ::closedir(fds);
        if (camera) {
            const int commFd = ::openat(pidFd, "comm", O_RDONLY | O_CLOEXEC);
            if (commFd >= 0) {
                char buf[256];
                const ssize_t n = ::read(commFd, buf, sizeof buf);
                ::close(commFd);
                if (n > 0) {
                    const QString name = QString::fromUtf8(buf, int(n)).trimmed();
                    if (!name.isEmpty() && !names.contains(name))
                        names.append(name);
                }
            }
        }
        ::close(pidFd);
    }
    ::closedir(proc);
    names.sort();
    return names;
}
