#import <AppKit/AppKit.h>

@interface AppController : NSObject
{
  IBOutlet NSWindow *window;
}
- (void) applicationDidFinishLaunching: (NSNotification *)notification;
- (BOOL) applicationShouldTerminateAfterLastWindowClosed:
    (NSApplication *)application;
@end
