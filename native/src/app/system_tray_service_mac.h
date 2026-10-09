#pragma once

class SystemTrayService;

// NSStatusItem backend (system_tray_service_mac.mm). The macOS branch in
// system_tray_service.cpp keeps ownership of the QObject so that Qt's meta
// object system stays out of the Objective-C++ translation unit.
//
// Returns an opaque handle for the status item, or nullptr when macOS refuses
// to create one.
void *douyuMacTrayStart(SystemTrayService *owner);
void douyuMacTrayStop(void *handle);
