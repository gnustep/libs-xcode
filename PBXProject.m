#import "PBXCommon.h"
#import "PBXProject.h"
#import "PBXNativeTarget.h"
#import "GSXCBuildContext.h"
#import "NSString+PBXAdditions.h"

#import <unistd.h>

@implementation PBXProject

// Methods....
- (NSString *) developmentRegion // getter
{
  return developmentRegion;
}

- (void) setDevelopmentRegion: (NSString *)object; // setter
{
  ASSIGN(developmentRegion,object);
}

- (NSMutableArray *) knownRegions // getter
{
  return knownRegions;
}

- (void) setKnownRegions: (NSMutableArray *)object; // setter
{
  ASSIGN(knownRegions,object);
}

- (NSString *) compatibilityVersion // getter
{
  return compatibilityVersion;
}

- (void) setCompatibilityVersion: (NSString *)object; // setter
{
  ASSIGN(compatibilityVersion,object);
}

- (NSMutableArray *) projectReferences // getter
{
  return projectReferences;
}

- (void) setProjectReferences: (NSMutableArray *)object; // setter
{
  ASSIGN(projectReferences,object);
}

- (NSMutableArray *) targets // getter
{
  return targets;
}

- (void) setTargets: (NSMutableArray *)object; // setter
{
  ASSIGN(targets,object);
}

- (NSString *) projectDirPath // getter
{
  return projectDirPath;
}

- (void) setProjectDirPath: (NSString *)object; // setter
{
  ASSIGN(projectDirPath,object);
}

- (NSString *) projectRoot // getter
{
  return projectRoot;
}

- (void) setProjectRoot: (NSString *)object; // setter
{
  ASSIGN(projectRoot,object);
}

- (XCConfigurationList *) buildConfigurationList // getter
{
  return buildConfigurationList;
}

- (void) setBuildConfigurationList: (XCConfigurationList *)object; // setter
{
  ASSIGN(buildConfigurationList,object);
}

- (PBXGroup *) mainGroup // getter
{
  return mainGroup;
}

- (void) setMainGroup: (PBXGroup *)object; // setter
{
  ASSIGN(mainGroup,object);
}

- (NSString *) hasScannedForEncodings // getter
{
  return hasScannedForEncodings;
}

- (void) setHasScannedForEncodings: (NSString *)object; // setter
{
  ASSIGN(hasScannedForEncodings,object);
}

- (PBXGroup *) productRefGroup // getter
{
  return productRefGroup;
}

- (void) setProductRefGroup: (PBXGroup *)object; // setter
{
  ASSIGN(productRefGroup,object);
}

- (PBXContainer *) container
{
  return container;
}

- (void) setContainer: (PBXContainer *)object
{
  container = object; // container retains us, do not retain it...
}

- (void) setContext: (NSDictionary *)context
{
  ASSIGN(ctx,context);
}

- (void) setFilename: (NSString *)fn
{
  ASSIGN(_filename, fn);
}
  
- (NSString *) filename
{
  return _filename;
}

- (void) _sourceRootFromMainGroup
{
  PBXGroup *sourceGroup = [[mainGroup children] objectAtIndex: 0]; 
  // get first group, which is the source group.
  NSString *sourceRoot = @"./"; // [[sourceGroup path] firstPathComponent];
  
  if(sourceRoot == nil || [sourceRoot isEqualToString: @""])
    {
      sourceRoot = @"./";
    }

  setenv("SOURCE_ROOT","./",1);
  setenv("SRCROOT","./",1);
  // NSLog(@"\tSOURCE_ROOT = %@",sourceRoot);
}

- (NSString *) buildString
{
  FILE *fp;
  char string[1035];
  NSString *output = @"";

  /* Open the command for reading. */
  fp = popen("gnustep-config --debug-flags", "r");
  if (fp == NULL) {
    puts("*** Failed to run command\n" );
    return nil;
  }

  /* Read the output a line at a time - output it. */
  while (fgets(string, sizeof(string)-1, fp) != NULL) {
    int len = strlen(string);
    int i = 0;
    for(i = 0; i < len; i++)
      {
	if(string[i] == '\n')
	  {
	    string[i] = ' ';
	  }
      }
    output = [output stringByAppendingString: 
		       [NSString stringWithCString: string]];
  }
  
  // Context...
  GSXCBuildContext *context = [GSXCBuildContext sharedBuildContext];
  [context setObject: output
	      forKey: @"CONFIG_STRING"];

  /* close */
  pclose(fp);
  return output;
}

- (BOOL) build
{
  NSString *fn = [[self container] filename];
  printf("=== Building Project %s\n", [fn cString]);
  [buildConfigurationList applyDefaultConfiguration];
  [self _sourceRootFromMainGroup];

  NSFileManager *fileManager = [NSFileManager defaultManager];
  GSXCBuildContext *context = [GSXCBuildContext sharedBuildContext];
  NSEnumerator *en = [targets objectEnumerator];
  id target = nil;
  BOOL result = YES;
  while((target = [en nextObject]) != nil && result)
    {
      BOOL targetInSubdir = NO;
      NSString *currentDirectory = [NSString stringWithCString: getcwd(NULL,0)];

      [context contextDictionaryForName: [target name]];
      [self buildString];

      // Go into the target...
      if(YES == [fileManager fileExistsAtPath:[target name]])
	{
	  targetInSubdir = YES;
	  [context setObject: @"YES"
		      forKey: @"TARGET_IN_SUBDIR"];
	}

      [context setObject: mainGroup 
		  forKey: @"MAIN_GROUP"]; 
      [context setObject: container
		  forKey: @"CONTAINER"];
      [context setObject: @"./"
		  forKey: @"PROJECT_ROOT"];
      [context setObject: @"./"
		  forKey: @"SRCROOT"];
      [context addEntriesFromDictionary:ctx];
      
      result = [target build];
      [context popCurrentContext];
    }
  printf("=== Completed Building Project %s\n", [[self projectDirPath] cString]);
  return result;
}

- (BOOL) clean
{
  puts("=== Cleaning Project");
  [buildConfigurationList applyDefaultConfiguration];

  NSFileManager *fileManager = [NSFileManager defaultManager];
  GSXCBuildContext *context = [GSXCBuildContext sharedBuildContext];
  NSEnumerator *en = [targets objectEnumerator];
  id target = nil;
  BOOL result = YES;
  
  while((target = [en nextObject]) != nil && result)
    {
      BOOL targetInSubdir = NO;
      // Go into the target...
      if(YES == [fileManager fileExistsAtPath:[target name]])
	{
	  targetInSubdir = YES;
	  // chdir([[target name] UTF8String]);
	  [context setObject: @"YES"
		      forKey: @"TARGET_IN_SUBDIR"];
	}

      [context contextDictionaryForName: [target name]];
      [context setObject: mainGroup 
		  forKey: @"MAIN_GROUP"]; 
      result = [target clean];
      [context popCurrentContext];

      // Back to the current dir...
      if(YES == targetInSubdir)
	{
	  // chdir([currentDirectory UTF8String]);
	}
    }
  puts("=== Completed Cleaning Project");
  return result;  
}

- (BOOL) install
{
  puts("=== Installing Project");
  [buildConfigurationList applyDefaultConfiguration];

  GSXCBuildContext *context = [GSXCBuildContext sharedBuildContext];
  NSEnumerator *en = [targets objectEnumerator];
  id target = nil;
  BOOL result = YES;
  while((target = [en nextObject]) != nil && result)
    {
      [context contextDictionaryForName: [target name]];
      [context setObject: mainGroup 
		  forKey: @"MAIN_GROUP"]; 
      result = [target install];
      [context popCurrentContext];
    }
  puts("=== Completed Installing Project");
  return result;  
}

- (BOOL) generate
{
  puts("=== Generating Project");
  [buildConfigurationList applyDefaultConfiguration];
  [self _sourceRootFromMainGroup];

  NSFileManager *fileManager = [NSFileManager defaultManager];
  GSXCBuildContext *context = [GSXCBuildContext sharedBuildContext];
  NSEnumerator *en = [targets objectEnumerator];
  id target = nil;
  BOOL result = YES;
  while((target = [en nextObject]) != nil && result)
    {
      BOOL targetInSubdir = NO;
      NSString *currentDirectory = [NSString stringWithCString: getcwd(NULL,0)];

      [context contextDictionaryForName: [target name]];
      [self buildString];

      // Go into the target...
      if(YES == [fileManager fileExistsAtPath:[target name]])
	{
	  targetInSubdir = YES;
	  // chdir([[target name] UTF8String]);
	  [context setObject: @"YES"
		      forKey: @"TARGET_IN_SUBDIR"];
	}

      [context setObject: mainGroup 
		  forKey: @"MAIN_GROUP"]; 
      [context setObject: container
		  forKey: @"CONTAINER"];
      [context setObject: currentDirectory
		  forKey: @"PROJECT_ROOT"];
      [context addEntriesFromDictionary:ctx];
      
      result = [target generate];
      [context popCurrentContext];

      // Back to the current dir...
      if(YES == targetInSubdir)
	{
	  // chdir([currentDirectory UTF8String]);
	}
    }
  puts("=== Completed Generating Project");
  return result;
}

@end
