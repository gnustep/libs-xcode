/*
   Project: buildtool

   Author: Gregory John Casamento,,,

   Created: 2011-08-20 11:42:51 -0400 by heron
*/

#import <Foundation/Foundation.h>
#import <XCode/PBXCoder.h>
#import <XCode/PBXContainer.h>
#import <XCode/NSString+PBXAdditions.h>
#import <XCode/XCWorkspaceParser.h>
#import <XCode/XCWorkspace.h>

NSString *
findProjectFilename(NSArray *projectDirEntries)
{
  NSEnumerator *e = [projectDirEntries objectEnumerator];
  NSString     *fileName;

  while ((fileName = [e nextObject]))
    {
      NSRange range = [fileName rangeOfString:@"._"];
      if ([[fileName pathExtension] isEqual: @"xcodeproj"] && range.location == NSNotFound)
	{
	  return [fileName stringByAppendingPathComponent: @"project.pbxproj"];
	}
    }

  return nil;
}

NSString *
findWorkspaceFilename(NSArray *projectDirEntries)
{
  NSEnumerator *e = [projectDirEntries objectEnumerator];
  NSString     *fileName;

  while ((fileName = [e nextObject]))
    {
      NSRange range = [fileName rangeOfString:@"._"];
      if ([[fileName pathExtension] isEqual: @"xcworkspace"] && range.location == NSNotFound)
	{
	  return [fileName stringByAppendingPathComponent: @"contents.xcworkspacedata"];
	}
    }

  return nil;
}

NSString *
resolveProjectName(BOOL *isProject)
{
  NSString      *fileName = nil;
  NSFileManager *fileManager = [NSFileManager defaultManager];
  NSString      *projectDir = [fileManager currentDirectoryPath];
  NSArray       *projectDirEntries = [fileManager directoryContentsAtPath: projectDir];

  fileName = findWorkspaceFilename(projectDirEntries);
  if (fileName != nil)
    {
      *isProject = NO;
    }
  else
    {
      *isProject = YES;
      fileName = findProjectFilename(projectDirEntries);
    }

  return fileName;
}

int main(int argc, const char *argv[])
{
  NSAutoreleasePool          *pool = [[NSAutoreleasePool alloc] init];
  NSString                   *fileName = nil;
  NSString                   *function = nil; 
  PBXCoder                   *coder = nil;
  PBXContainer               *container = nil;
  BOOL                        isProject = NO;
  NSString                   *argument = @"build";
  NSProcessInfo              *pi = [NSProcessInfo processInfo];
  NSMutableArray             *args = [NSMutableArray arrayWithArray: [pi arguments]];
  NSString                   *parameter = nil;
  
  setlocale(LC_ALL, "en_US.utf8");

  // Get filename
  if ([args count] > 1)
    {
      NSString *ext = [argument pathExtension];
      
      argument = [args objectAtIndex: 1]; // consume argument...
      if ([ext isEqualToString: @"xcworkspace"])
        {
          ASSIGN(fileName, argument);
          [args removeObjectAtIndex: 1];
          isProject = NO;
        } 
      else if ([ext isEqualToString: @"xcodeproj"])
        {
          ASSIGN(fileName, argument);
          [args removeObjectAtIndex: 1];                   
          isProject = YES;
        }

      if (fileName != nil)
        {
          fileName = [fileName stringByAppendingPathComponent: 
                                 @"project.pbxproj"];
        }
      else
        {
          fileName = resolveProjectName(&isProject);
        }
    }

  if ([args count] > 1)
    {
      argument = [args objectAtIndex: 1];

      if ([argument isEqualToString: @"build"] ||
          [argument isEqualToString: @"install"] ||
          [argument isEqualToString: @"clean"] ||
          [argument isEqualToString: @"generate"])
        {
          ASSIGN(function, argument);
          [args removeObjectAtIndex: 1];
        }
    }

  if ([args count] > 1)
    {
      ASSIGN(parameter, [args objectAtIndex: 1]);
      [args removeObjectAtIndex: 1];
    }
  
  if ([function isEqualToString: @""] || function == nil)
    {
      function = @"build"; // default action...
    }

  // If the paramter is empty then make default to Makefile...
  if ([function isEqualToString: @"generate"] && parameter == nil)
    {
      parameter = @"Makefile";
    }

  NS_DURING
    {
      NSString *display = [function stringByCapitalizingFirstCharacter];
      SEL operation = NSSelectorFromString(function);

      if (fileName == nil)
        {
          fileName = resolveProjectName(&isProject);
        }
      
      if (isProject)
	{
	  // Unarchive...
	  coder = [[PBXCoder alloc] initWithContentsOfFile: fileName];
	  container = [coder unarchive];
          [container setParameter: parameter];
	  
	  // Build...
	  if ([container respondsToSelector: operation])
	    {        
	      // build...
	      puts([[NSString stringWithFormat: @"\033[1;32m**\033[0m Start operation %@", display] cString]); 
	      if ([container performSelector: operation])
		{
		  puts([[NSString stringWithFormat: @"\033[1;32m**\033[0m %@ Succeeded", display] cString]);
		}
	      else
		{
		  puts([[NSString stringWithFormat: @"\033[1;31m**\033[0m %@ Failed", display] cString]);
		}
	    }
	  else
	    {
	      puts([[NSString stringWithFormat: @"Unknown build operation \"%@",display] cString]);
	    }
	}
      else
	{
	  XCWorkspaceParser *p = [XCWorkspaceParser parseWorkspaceFile: fileName];
	  XCWorkspace *w = [p workspace];
	  
	  if ([w respondsToSelector: operation])
	    {
	      [w performSelector: operation];
	    }
	}
    }
  NS_HANDLER
    {
      NSLog(@"%@", localException);
    }
  NS_ENDHANDLER;
  
  // The end...
  [pool release];

  return 0;
}

