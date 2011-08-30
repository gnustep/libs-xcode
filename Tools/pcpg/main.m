/*
   Project: pcpg

   Author: Gregory John Casamento,,,

   Created: 2011-08-16 14:11:00 -0400 by heron
*/

#import <Foundation/Foundation.h>
#import "PLCPG.h"

int
main(int argc, const char *argv[])
{
  id pool = [[NSAutoreleasePool alloc] init];

  // Your code here...
  if(argc > 0)
  {
    NSString *argument = [[NSString alloc] initWithCString: argv[1]];
    PLCPG *plcpg = [[PLCPG alloc] initWithPlist: argument];
    [plcpg generate];
    [argument release];
    [plcpg release];
  }
  // The end...

  [pool release];

  return 0;
}

