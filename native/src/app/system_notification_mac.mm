#include "app/system_notification_mac.h"

#include "app/system_notification_service.h"

#import <Foundation/Foundation.h>
#import <UserNotifications/UserNotifications.h>

#include <QString>

#include <atomic>

namespace {

class MacNotificationSink final : public SystemNotificationSink {
public:
    MacNotificationSink()
    {
        // UNUserNotificationCenter requires a bundle identifier; a bare
        // executable (CTest binaries, --self-test) raises on authorization.
        if ([NSBundle mainBundle].bundleIdentifier == nil) return;

        UNUserNotificationCenter *center = [UNUserNotificationCenter currentNotificationCenter];
        [center requestAuthorizationWithOptions:(UNAuthorizationOptionAlert | UNAuthorizationOptionSound)
                      completionHandler:^(BOOL granted, NSError *error) {
                          (void)error;
                          authorized_.store(granted);
                      }];
    }

    bool available() const override
    {
        return authorized_.load();
    }

    void show(const QString &title, const QString &body) override
    {
        if (!authorized_.load()) return;

        UNMutableNotificationContent *content = [[UNMutableNotificationContent alloc] init];
        content.title = title.toNSString();
        content.body = body.toNSString();

        const quint64 sequence = ++sequence_;
        const QString identifier = QStringLiteral("douyu-monitor-%1").arg(sequence);
        UNNotificationRequest *request =
            [UNNotificationRequest requestWithIdentifier:identifier.toNSString()
                                                 content:content
                                                 trigger:nil];
        [[UNUserNotificationCenter currentNotificationCenter] addNotificationRequest:request
                                                               withCompletionHandler:nil];
        [content release];
    }

private:
    std::atomic_bool authorized_{false};
    std::atomic<quint64> sequence_{0};
};

} // namespace

std::unique_ptr<SystemNotificationSink> douyuCreateMacNotificationSink()
{
    return std::make_unique<MacNotificationSink>();
}
