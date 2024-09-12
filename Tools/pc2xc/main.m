/*
   Project: pc2xc

   Author: Gregory John Casamento,,,

   Created: 2023-10-16 23:37:42 -0400 by heron
*/

#import <Foundation/Foundation.h>

#import <XCode/PBXCoder.h>
#import <XCode/PBXContainer.h>
#import <XCode/PBXProject.h>
#import <XCode/GSXCColors.h>

#import <XCode/xcsystem.h>

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

BOOL buildXCodeProj(PBXContainer *container, NSString *dn)
{
  NSError *error = nil;
  NSString *fn = [[dn stringByAppendingPathExtension: @"xcodeproj"]
			 stringByAppendingPathComponent: @"project.pbxproj"];
  NSFileManager *fm = [NSFileManager defaultManager];
  BOOL created = [fm createDirectoryAtPath: fn
		     withIntermediateDirectories: YES
				attributes: NULL
				     error: &error];
  BOOL result = NO;
  
  if (created)
    {
      xcprintf("=== Saving Project %s%s%s%s -> %s%s%s\n",
	       BOLD, YELLOW, [fn cString], RESET, GREEN,
	       [dn cString], RESET);

      [container save]; // Setup to save...
  
      // Save the project...
      if (created && !error)
	{
	  id dictionary = [PBXCoder archiveWithRootObject: container];
	  BOOL result = [dictionary writeToFile: fn atomically: YES];

	  if (result)
	    {
	      xcprintf("=== Done Saving Project %s%s%s%s\n",
		       BOLD, GREEN, [dn cString], RESET);
	    }
	  else
	    {
	      xcprintf("=== Error Saving Project %s%s%s%s\n",
		       BOLD, GREEN, [dn cString], RESET);
	    }
	}

      return result;
    }
  
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

	  xcprintf("== Parsing an old style NeXT project: %s -> %s\n",
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
	  xcprintf("== Unknown project type");
	}

      if (container == nil)
	{
	  xcprintf("== Unable to parse project file %@", input);
	  return 255;
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
      xcprintf("== Not enough arguments");
    }
			    
  [pool release];

  return 0;
}

