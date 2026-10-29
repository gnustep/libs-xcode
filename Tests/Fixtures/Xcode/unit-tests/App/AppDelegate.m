#import "AppDelegate.h"

@implementation AppDelegate
@synthesize launched;

- (void) applicationDidFinishLaunching: (NSNotification *)notification
{
  [self setLaunched: YES];
}
@end
