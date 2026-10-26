#import <UIKit/UIKit.h>

@interface AppController : NSObject <UIApplicationDelegate>
{
  UIWindow *window;
}

- (BOOL) application: (UIApplication *)application
    didFinishLaunchingWithOptions: (NSDictionary *)options;

@end
