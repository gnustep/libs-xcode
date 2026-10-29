#import <AppKit/AppKit.h>
#import "AppDelegate.h"

int main(int argc, const char *argv[])
{
  NSApplication *app = [NSApplication sharedApplication];
  [app setDelegate: [[AppDelegate alloc] init]];
  [app run];
  return 0;
}
