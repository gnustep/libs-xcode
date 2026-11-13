#import "AppDelegate.h"

@implementation AppDelegate
- (BOOL) launched
{
  return launched;
}

- (void) setLaunched: (BOOL)value
{
  launched = value;
}

- (void) applicationDidFinishLaunching: (NSNotification *)notification
{
  [self setLaunched: YES];
}
@end
