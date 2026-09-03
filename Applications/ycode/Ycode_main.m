/* 
   Project: Ycode

   Author: Gregory John Casamento,,,

   Created: 2017-08-15 03:31:31 -0400 by heron
*/

#import <AppKit/AppKit.h>
#import "YCodeDocumentController.h"
#import "AppController.h"

int 
main(int argc, const char *argv[])
{
  CREATE_AUTORELEASE_POOL(pool);
  AppController *delegate = nil;

  [YCodeDocumentController sharedDocumentController];
  [NSApplication sharedApplication];

  delegate = [[AppController alloc] init];
  [NSApp setDelegate: delegate];
  [delegate buildMainMenu];

  RELEASE(pool);

// Uncomment if your application is Renaissance application
/*  CREATE_AUTORELEASE_POOL (pool);
  [NSApplication sharedApplication];
  [NSApp setDelegate: [AppController new]];

  #ifdef GNUSTEP
    [NSBundle loadGSMarkupNamed: @"MainMenu-GNUstep"  owner: [NSApp delegate]];
  #else
    [NSBundle loadGSMarkupNamed: @"MainMenu-OSX"  owner: [NSApp delegate]];
  #endif
   
  RELEASE (pool);
*/

  return NSApplicationMain (argc, argv);
}
