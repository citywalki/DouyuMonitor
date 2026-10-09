#include <QSignalSpy>
#include <QtTest/QtTest>

#include "app/system_tray_service.h"

class SystemTrayServiceTest final : public QObject {
    Q_OBJECT

private slots:
    void startsAndStopsIdempotently();
    void forwardsTestActions();
};

void SystemTrayServiceTest::startsAndStopsIdempotently()
{
    SystemTrayService service;
    QVERIFY(!service.isRunning());
    service.stop();
    QVERIFY(!service.isRunning());

#ifdef Q_OS_WIN
    QSKIP("Tray integration requires an interactive Windows shell; action hooks are tested separately.");
#else
    QVERIFY(!service.start(nullptr));
    QVERIFY(!service.isRunning());
#endif
}

void SystemTrayServiceTest::forwardsTestActions()
{
    SystemTrayService service;
    QSignalSpy showSpy(&service, &SystemTrayService::showRequested);
    QSignalSpy quitSpy(&service, &SystemTrayService::quitRequested);

#ifdef DOUYU_TESTING
    service.triggerShowForTest();
    service.triggerQuitForTest();
    QCOMPARE(showSpy.count(), 1);
    QCOMPARE(quitSpy.count(), 1);
#else
    QSKIP("Test hooks are disabled in this build.");
#endif
}

QTEST_GUILESS_MAIN(SystemTrayServiceTest)

#include "system_tray_service_test.moc"
