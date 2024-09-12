/*
   Project: pc2xc

   Author: Gregory John Casamento,,,

   Created: 2023-10-16 23:37:42 -0400 by heron
*/

#import <Foundation/Foundation.h>

#import <XCode/PBXCoder.h>
#import <XCode/PBXContainer.h>
#import <XCode/PBXProject.h>

PBXContainer *convertPBProject(NSDictionary *proj)
{
  NSLog(@"proj = %@", proj);

  return nil;
}

PBXContainer *convertPCProject(NSDictionary *proj)
{
  NSLog(@"proj = %@", proj);

  return nil;
}

BOOL buildXCodeProj(PBXContainer *container, NSString *output)
{
  
  return YES;
}

int main(int argc, const char *argv[])
{
  id pool = [[NSAutoreleasePool alloc] init];

  if (argc > 1)
    {
      NSString *input = [NSString stringWithUTF8String: argv[1]];
      NSString *output = [NSString stringWithUTF8String: argv[2]];
      PBXContainer *container = nil;
      
      if ([[input lastPathComponent] isEqualToString: @"PB.project"])
	{
	  NSDictionary *proj = [NSDictionary dictionaryWithContentsOfFile: input];

	  printf("== Parsing an old style NeXT project: %s -> %s\n",
		 [input UTF8String], [output UTF8String]);
	  container = convertPBProject(proj);
	}
      else if ([[input pathExtension] isEqualToString: @"pcproj"])
	{
	  NSString *path = [input stringByAppendingPathComponent: @"PC.project"];
	  NSDictionary *proj = [NSDictionary dictionaryWithContentsOfFile: path];	  

	  printf("== Parsing a ProjectCenter project: %s -> %s\n",
		 [input UTF8String], [output UTF8String]);
	  container = convertPCProject(proj);
	}
      else
	{
	  NSLog(@"Unknown project type");
	}

      if (container == nil)
	{
	  NSLog(@"Unable to parse project file %@", input);
	}
      else
	{
	  BOOL result = buildXCodeProj(container, output);
	  if (result == NO)
	    {
	      return 255;
	    }
	}
    }
  else
    {
      NSLog(@"Not enough arguments");
    }
			    
  [pool release];

  return 0;
}

