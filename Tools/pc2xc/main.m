/*
   Project: pc2xc

   Author: Gregory John Casamento,,,

   Created: 2023-10-16 23:37:42 -0400 by heron
*/

#import <Foundation/Foundation.h>
#import <XCode/PBXCoder.h>

int main(int argc, const char *argv[])
{
  id pool = [[NSAutoreleasePool alloc] init];

  if (argc > 1)
    {
      NSString *input = [NSString stringWithUTF8String: argv[1]];
      NSString *output = [NSString stringWithUTF8String: argv[2]];
      NSDictionary *proj = [NSDictionary dictionaryWithContentsOfFile: input];

      NSLog(@"proj = %@", proj);
    }
			    
  [pool release];

  return 0;
}

