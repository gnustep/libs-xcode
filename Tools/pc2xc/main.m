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

PBXContainer *buildContainer(NSString *projectName,
			     NSArray *files,
			     NSArray *headers,
			     NSArray *resources,
			     NSArray *other,
			     NSArray *frameworks)
{
  NSLog(@"files = %@", files);
  return nil;
}


PBXContainer *convertPBProject(NSDictionary *proj)
{
  NSString *projectName = [proj objectForKey: @"PROJECTNAME"];
  NSDictionary *filesTable = [proj objectForKey: @"FILESTABLE"];
  NSArray *files = [filesTable objectForKey: @"CLASSES"];
  NSArray *headers = [filesTable objectForKey: @"H_FILES"];
  NSArray *resources = [filesTable objectForKey: @"INTERFACES"];
  NSArray *other = [filesTable objectForKey: @"OTHER_LINKED"];
  NSArray *frameworks = [filesTable objectForKey: @"FRAMEWORKS"];
  
  return buildContainer(projectName, files, headers, resources, other, frameworks);
}

PBXContainer *convertPCProject(NSDictionary *proj)
{
  NSString *projectName = [proj objectForKey: @"PROJECT_NAME"];
  NSArray *files = [proj objectForKey: @"CLASS_FILES"];
  NSArray *headers = [proj objectForKey: @"HEADER_FILES"];
  NSArray *resources = [proj objectForKey: @"LOCALIZED_RESOURCES"];
  NSArray *other = [proj objectForKey: @"OTHER_SOURCES"];
  NSArray *frameworks = [proj objectForKey: @"LIBRARIES"];
  
  return buildContainer(projectName, files, headers, resources, other, frameworks);
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

