#pragma once

#include <QObject>

class QWindow;

// Tray integration: Win32 Shell_NotifyIcon on Windows, NSStatusItem on macOS
// (src/app/system_tray_service_mac.mm). Platforms without a tray backend
// report `start() == false` and the application falls back to direct control.
class SystemTrayService final : public QObject {
    Q_OBJECT

public:
    explicit SystemTrayService(QObject *parent = nullptr);
    ~SystemTrayService() override;

    bool start(QWindow *window);
    void stop();
    bool isRunning() const noexcept;

#ifdef DOUYU_TESTING
    void triggerShowForTest();
    void triggerQuitForTest();
#endif

signals:
    void showRequested();
    void quitRequested();

public:
    class Private;

private:
    Private *d_ = nullptr;
};
