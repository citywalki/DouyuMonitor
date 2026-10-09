#include "app/system_tray_service_mac.h"

#include "app/system_tray_service.h"

#import <AppKit/AppKit.h>

#include <QIcon>
#include <QPixmap>

namespace {

constexpr CGFloat kStatusIconSize = 18.0;

// Status bar images come from the bundled PNG, so no icon theme or Qt Widgets
// dependency is involved.
NSImage *statusItemImage()
{
    const QIcon icon(QStringLiteral(":/app/assets/douyu_monitor.png"));
    if (icon.isNull()) return nil;
    const QPixmap pixmap = icon.pixmap(kStatusIconSize, kStatusIconSize);
    if (pixmap.isNull()) return nil;
    CGImageRef image = pixmap.toImage().toCGImage();
    if (image == nullptr) return nil;
    NSImage *result = [[NSImage alloc] initWithCGImage:image
                                                  size:NSMakeSize(kStatusIconSize, kStatusIconSize)];
    CGImageRelease(image);
    return [result autorelease];
}

} // namespace

// Forwards NSMenu actions to the Qt signals. Qt signals are public member
// functions, so the target emits them directly.
@interface DouyuTrayTarget : NSObject
@property(nonatomic, assign) SystemTrayService *owner;
- (void)handleShow:(id)sender;
- (void)handleQuit:(id)sender;
@end

@implementation DouyuTrayTarget
- (void)handleShow:(id)sender
{
    (void)sender;
    if (self.owner != nullptr) self.owner->showRequested();
}

- (void)handleQuit:(id)sender
{
    (void)sender;
    if (self.owner != nullptr) self.owner->quitRequested();
}
@end

namespace {

struct MacTrayState {
    SystemTrayService *owner = nullptr;
    NSStatusItem *statusItem = nil;
    NSMenu *menu = nil;
    DouyuTrayTarget *target = nil;
};

} // namespace

void *douyuMacTrayStart(SystemTrayService *owner)
{
    if (owner == nullptr) return nullptr;

    NSStatusItem *statusItem =
        [[NSStatusBar systemStatusBar] statusItemWithLength:NSSquareStatusItemLength];
    if (statusItem == nil) return nullptr;
    [statusItem retain];

    DouyuTrayTarget *target = [[DouyuTrayTarget alloc] init];
    target.owner = owner;

    statusItem.button.toolTip = @"DouyuMonitor";
    NSImage *image = statusItemImage();
    if (image != nil) {
        statusItem.button.image = image;
    } else {
        statusItem.button.title = @"斗鱼";
    }

    NSMenu *menu = [[NSMenu alloc] init];
    NSMenuItem *showItem = [[NSMenuItem alloc] initWithTitle:@"显示窗口"
                                                     action:@selector(handleShow:)
                                              keyEquivalent:@""];
    showItem.target = target;
    [menu addItem:showItem];
    [showItem release];

    NSMenuItem *quitItem = [[NSMenuItem alloc] initWithTitle:@"退出程序"
                                                     action:@selector(handleQuit:)
                                              keyEquivalent:@""];
    quitItem.target = target;
    [menu addItem:quitItem];
    [quitItem release];

    statusItem.menu = menu;

    auto *state = new MacTrayState{owner, statusItem, menu, target};
    return state;
}

void douyuMacTrayStop(void *handle)
{
    auto *state = static_cast<MacTrayState *>(handle);
    if (state == nullptr) return;

    state->statusItem.menu = nil;
    [[NSStatusBar systemStatusBar] removeStatusItem:state->statusItem];
    [state->statusItem release];
    [state->menu release];
    [state->target release];
    delete state;
}
