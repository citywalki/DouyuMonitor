#pragma once

#include <memory>

class SystemNotificationSink;

// Creates the macOS notification backend on top of the UserNotifications
// framework. The returned sink reports `available() == false` until the user
// grants notification permission, or when the binary is not a bundle.
std::unique_ptr<SystemNotificationSink> douyuCreateMacNotificationSink();
