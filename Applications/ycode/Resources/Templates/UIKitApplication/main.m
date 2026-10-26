#import <UIKit/UIKit.h>

int
main (int argc, char **argv)
{
  NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];
  int result = UIApplicationMain (argc, argv, nil, @"AppController");
  [pool drain];
  return result;
}
