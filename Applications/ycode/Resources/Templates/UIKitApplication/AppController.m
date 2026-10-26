#import "AppController.h"

@implementation AppController

- (BOOL) application: (UIApplication *)application
    didFinishLaunchingWithOptions: (NSDictionary *)options
{
  window = [[UIWindow alloc] initWithFrame: [[UIScreen mainScreen] bounds]];
  UIViewController *controller = [[UIViewController alloc] init];
  [[controller view] setBackgroundColor: [UIColor whiteColor]];
  [window setRootViewController: controller];
  [controller release];
  [window makeKeyAndVisible];
  return YES;
}

- (void) dealloc
{
  [window release];
  [super dealloc];
}

@end
