#import "AppController.h"

@implementation AppController
- (void) applicationDidFinishLaunching: (NSNotification *)notification
{
  [window center];
  [window makeKeyAndOrderFront: self];
}

- (BOOL) applicationShouldTerminateAfterLastWindowClosed:
    (NSApplication *)application
{
  return YES;
}

@end
