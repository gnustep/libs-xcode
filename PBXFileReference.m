#import <stdlib.h>
#import <unistd.h>

#import "PBXCommon.h"
#import "PBXFileReference.h"
#import "PBXGroup.h"
#import "GSXCBuildContext.h"
#import "NSArray+Additions.h"
#import "NSString+PBXAdditions.h"
#import "PBXNativeTarget.h"
#import "XCConfigurationList.h"
#import "XCBuildConfiguration.h"

extern char **environ;

@implementation PBXFileReference

// Methods....
- (void) setWrapsLines: (NSString *)o
{
  ASSIGN(wrapsLines, o);
}

- (NSString *) sourceTree // getter
{
  return sourceTree;
}

- (void) setSourceTree: (NSString *)object; // setter
{
  ASSIGN(sourceTree,object);
}

- (NSString *) lastKnownFileType // getter
{
  return lastKnownFileType;
}

- (void) setLastKnownFileType: (NSString *)object; // setter
{
  ASSIGN(lastKnownFileType,object);
}

- (NSString *) path // getter
{
  return path;
}

- (void) setPath: (NSString *)object; // setter
{
  ASSIGN(path,object);
}

- (NSString *) fileEncoding // getter
{
  return fileEncoding;
}

- (void) setFileEncoding: (NSString *)object; // setter
{
  ASSIGN(fileEncoding,object);
}

- (NSString *) explicitFileType
{
  return explicitFileType;
}

- (void) setExplicitFileType: (NSString *)object
{
  ASSIGN(explicitFileType,object);
}

- (NSString *) name;
{
  return name;
}

- (void) setName: (NSString *)object
{
  ASSIGN(name,object);
}

- (NSString *) plistStructureDefinitionIdentifier
{
  return plistStructureDefinitionIdentifier;
}

- (void) setPlistStructureDefinitionIdentifier: (NSString *)object
{
  ASSIGN(plistStructureDefinitionIdentifier,object);
}

- (NSString *) xcLanguageSpecificationIdentifier
{
  return xcLanguageSpecificationIdentifier;
}

- (void) setXcLanguageSpecificationIdentifier: (NSString *)object
{
  ASSIGN(xcLanguageSpecificationIdentifier, object);
}

- (NSString *) lineEnding
{
  return lineEnding;
}

- (void) setLineEnding: (NSString *)object
{
  ASSIGN(lineEnding,object);
}

- (void) setTarget: (PBXNativeTarget *)t
{
  ASSIGN(target, t);
}

- (NSString *) resolvePathFor: (id)object 
		    withGroup: (PBXGroup *)group
			found: (BOOL *)found
{
  NSString *result = @"";
  NSArray *children = [group children];
  NSEnumerator *en = [children objectEnumerator];
  id file = nil;
  while((file = [en nextObject]) != nil && *found == NO)
    {
      if(file == self) // have we found ourselves??
	{
	  NSString *filePath = ([file path] == nil)?@"":[file path];
	  result = filePath;
	  *found = YES;
	  break;
	}
      else if([file isKindOfClass: [PBXGroup class]])
	{
	  NSString *filePath = ([file path] == nil)?@"":[file path];
	  result = [filePath stringByAppendingPathComponent: 
				      [self resolvePathFor: object 
						 withGroup: file
						     found: found]];
	}
    }
  return result;
}

- (NSArray *) allSubdirsAtPath: (NSString *)apath
{
  NSMutableArray *results = [NSMutableArray arrayWithCapacity:10];
  NSFileManager *manager = [[NSFileManager alloc] init];
  NSDirectoryEnumerator *en = [manager enumeratorAtPath:apath];
  NSString *filename = nil;

  NSDebugLog(@"apath = %@", apath);
  NSDebugLog(@"cwd = %@", [manager currentDirectoryPath]);
  
  while((filename = [en nextObject]) != nil)
    {
      BOOL isDir = NO;
      NSString *dirToAdd = nil;

      [manager fileExistsAtPath: filename
                    isDirectory: &isDir];

      if (isDir == NO)
        {
          if ([filename isEqualToString: @""])
            {
              dirToAdd = @"./";
            }

          if ([[filename pathComponents] count] > 2)
            {
              continue;
            }
         
           if ([[filename pathExtension] isEqualToString: @"h"])
            {
              NSDebugLog(@"filename = %@", filename); // , isDir = %d", filename, isDir);
              dirToAdd = [filename stringByDeletingLastPathComponent];
            }
        }
      else
        {
          NSDebugLog(@"dir = %@", filename);
          continue;
        }

      if (dirToAdd == nil)
        {
          continue;
        }
      
      if ([results containsObject: [dirToAdd stringByAddingQuotationMarks]] == NO)
        {
          NSString *ext = [dirToAdd pathExtension];
          if ([ext isEqualToString: @"app"] ||
              [ext isEqualToString: @"xcassets"] ||
              [ext isEqualToString: @"lproj"] ||
              [dirToAdd containsString: @"build"] ||
              [dirToAdd containsString: @"pbxbuild"] ||
              [dirToAdd containsString: @"xcassets"] ||
              [dirToAdd containsString: @"lproj"] ||
              [dirToAdd containsString: @"xcodeproj"] ||
	      [dirToAdd containsString: @".git"])
            {
              continue;
            }
          [results addObject: [dirToAdd stringByAddingQuotationMarks]];
          NSDebugLog(@"adding dirToAdd = %@", dirToAdd);
        }
    }

  // For some reason repeating the first -I directive helps resolve some issues with
  // finding headers.
  id o = [results count] > 1 ? [results objectAtIndex: 1] : @"./";
  [results addObject: o];

  NSDebugLog(@"results = %@", results);
  RELEASE(manager);
  return results;
}

- (NSString *) productName
{
  GSXCBuildContext *context = [GSXCBuildContext sharedBuildContext];
  NSDictionary *ctx = [context currentContext];
  XCConfigurationList *xcl = [ctx objectForKey: @"buildConfig"];
  XCBuildConfiguration *xbc = [xcl defaultConfiguration];
  NSDictionary *bs = [xbc buildSettings];
  NSString *productName = [bs objectForKey: @"PRODUCT_NAME"];

  return productName;
}

- (NSString *) buildPath
{
  PBXGroup *mainGroup = [[GSXCBuildContext sharedBuildContext] objectForKey: @"MAIN_GROUP"];
  BOOL found = NO;
  NSString *result = nil;

  // Resolve path for the current file reference...
  result = [self resolvePathFor: self 
		      withGroup: mainGroup
			  found: &found];
  
  return result;
}

- (NSArray *) substituteSearchPaths: (NSArray *)array
                          buildPath: (NSString *)buildPath
{
  GSXCBuildContext *context = [GSXCBuildContext sharedBuildContext];
  NSMutableArray *result = [NSMutableArray arrayWithCapacity: [array count]];
  NSMutableDictionary *dict = [NSMutableDictionary dictionaryWithCapacity: [array count]];
  XCConfigurationList *list = [context objectForKey: @"buildConfig"];
  NSMutableArray *allHeaders = [NSMutableArray arrayWithArray: array];
  NSDictionary *plistFile = [NSDictionary dictionaryWithContentsOfFile: @"buildtool.plist"];
  NSArray *headerPaths = [plistFile objectForKey: @"headerPaths"];
  //  NSLog(@"plist = %@", plistFile);
  // NSLog(@"BUILD CONFIG: %@", list);

  XCBuildConfiguration *config = [[list buildConfigurations] objectAtIndex: 0];
  NSDictionary *buildSettings = [config buildSettings];
  NSMutableArray *headers = [buildSettings objectForKey: @"HEADER_SEARCH_PATHS"];

  if ([headers isKindOfClass: [NSArray class]] &&
      headers != nil)
    {
      [allHeaders addObjectsFromArray: headers];
    }

  if ([headerPaths isKindOfClass: [NSArray class]] &&
      headerPaths != nil)
    {
      [allHeaders addObjectsFromArray: headerPaths];
    }
  
  // get environment variables...
  char **env = NULL;
  for (env = environ; *env != 0; env++)
    {
      char *thisEnv = *env;
      NSString *envStr = [NSString stringWithCString: thisEnv encoding: NSUTF8StringEncoding];
      NSArray *components = [envStr componentsSeparatedByString: @"="];
      [dict setObject: [components lastObject]
               forKey: [components firstObject]];
    }
  
  // Get project root
  char *proj_root = getenv("PROJECT_ROOT");
  if (proj_root == NULL ||
      strcmp(proj_root, "") == 0)
    {
      proj_root = NULL;
    }

  NSString *projDir = @".";
  if (proj_root != NULL)
    projDir = [NSString stringWithFormat: @"%s", proj_root];

  // NSLog(@"All Headers %@", allHeaders);
  
  NSEnumerator *en = [allHeaders objectEnumerator];
  NSString *s = nil;
  while ((s = [en nextObject]) != nil)
    {
      if ([s isEqualToString: @"$(inherited)"])
        continue;
      
      NSString *o = [s stringByReplacingOccurrencesOfString: @"$(PROJECT_DIR)"
                                                 withString: projDir];
      o = [o stringByReplacingOccurrencesOfString: @"${PROJECT_DIR}"
                                       withString: projDir];
      // [o stringByReplacingOccurrencesOfString: @"\"" withString: @""];
      NSString *q = [o stringByReplacingEnvironmentVariablesWithValues];
      NSString *p = [NSString stringWithFormat: @"../%@",o];
      if ([result containsObject: o] == NO)
        {
          [result addObject: o];
          [result addObject: p];
          [result addObject: q];
        }
    }

  return result;
}

- (NSString *) _findFile: (NSString *)apath
{
  NSString *currentPath = apath;
  NSFileManager *manager = [NSFileManager defaultManager];
  int i = 0;
  while ([manager fileExistsAtPath: currentPath] == NO && i < 100)
    {
      currentPath = [NSString stringWithFormat: @"../%@", currentPath];
      i++;
    }

  if (i == 100)
    {
      return nil;
    }
  
  return currentPath;
}

- (char *) getCompiler
{
  char *cc = getenv("CC");
  if (cc == NULL ||
      strcmp(cc, "") == 0)
    {
      cc = "`gnustep-config --variable=CC`";
    }
  return cc;
}

- (BOOL) build
{  
  GSXCBuildContext *context = [GSXCBuildContext sharedBuildContext];
  NSString *of = [context objectForKey: @"OUTPUT_FILES"];
  NSString *modified = [context objectForKey: @"MODIFIED_FLAG"];
  NSString *outputFiles = (of == nil)?@"":of;
  int result = 0;
  NSError *error = nil;
  NSFileManager *manager = [NSFileManager defaultManager];
  NSDictionary *ctx = [context currentContext];
  XCConfigurationList *xcl = [ctx objectForKey: @"buildConfig"];
  XCBuildConfiguration *xbc = [xcl defaultConfiguration];
  NSDictionary *bs = [xbc buildSettings];
  
  if(modified == nil)
    {
      modified = @"NO";
      [context setObject: @"NO"
		  forKey: @"MODIFIED_FLAG"];
    }

  if([lastKnownFileType isEqualToString: @"sourcecode.c.objc"] ||
     [lastKnownFileType isEqualToString: @"sourcecode.c.c"] || 
     [lastKnownFileType isEqualToString: @"sourcecode.cpp.cpp"] ||
     [lastKnownFileType isEqualToString: @"sourcecode.cpp.objcpp"])
    {
      NSString *proj_root = [bs objectForKey: @"PROJECT_ROOT"];
      if (proj_root == nil ||
          [proj_root isEqualToString: @""])
        {
          proj_root = @"";
        }

      if ([lastKnownFileType isEqualToString: @"sourcecode.cpp.cpp"] ||
	  [lastKnownFileType isEqualToString: @"sourcecode.cpp.objcpp"])
	{
	  [context setObject: @"YES" forKey: @"LINK_WITH_CPP"];
	}
      
      char *cc = [self getCompiler];
      NSString *buildPath = [proj_root stringByAppendingPathComponent: 
					 [self buildPath]];
      NSArray *localHeaderPathsArray = [self allSubdirsAtPath:@"."];
      NSString *fileName = [path lastPathComponent];
      NSString *buildDir = [NSString stringWithCString: getenv("TARGET_BUILD_DIR")];
      NSString *additionalHeaderDirs = [context objectForKey:@"INCLUDE_DIRS"];
      NSString *derivedSrcHeaderDir = [context objectForKey: @"DERIVED_SOURCE_HEADER_DIR"];
      NSString *compiler = [NSString stringWithCString: cc];
      NSString *headerSearchPaths = [[self substituteSearchPaths: [context objectForKey: @"HEADER_SEARCH_PATHS"]
                                                       buildPath: buildPath] 
                                      implodeArrayWithSeparator: @" -I"];
      NSString *warningCflags = [[context objectForKey: @"WARNING_CFLAGS"] 
				  implodeArrayWithSeparator: @" "];
      NSString *localHeaderPaths = [localHeaderPathsArray implodeArrayWithSeparator:@" -I"];
      
      buildDir = [buildDir stringByAppendingPathComponent: [target productName]];

      NSDebugLog(@"localHeaderPathsArray = %@, %@", localHeaderPathsArray, localHeaderPaths);
      NSDebugLog(@"Build path = %@, %@", [self buildPath], [[self buildPath] stringByDeletingFirstPathComponent]);
      // blank these out if they are not used...
      if(headerSearchPaths == nil)
	{
	  headerSearchPaths = @"";
	}
      if(localHeaderPaths == nil)
        {
	  localHeaderPaths = @"";
        }
      
      if(warningCflags == nil)
	{
	  warningCflags = @"";
	}

      // If we have derived sources, then get the header directory and add it to the search path....
      if(derivedSrcHeaderDir != nil)
	{
	  if([[derivedSrcHeaderDir pathComponents] count] > 1)
	    {
	      headerSearchPaths = [headerSearchPaths stringByAppendingString: 
						  [NSString stringWithFormat: @" -I\"%@\" ",
							    [derivedSrcHeaderDir stringByDeletingLastPathComponent]]];
	    }
	}

      // If we have additional header dirs specified... then add them.
      if(additionalHeaderDirs != nil)
	{
	  headerSearchPaths = [headerSearchPaths stringByAppendingString: additionalHeaderDirs];
	  headerSearchPaths = [headerSearchPaths stringByAppendingString: localHeaderPaths];
	}
      
      NSString *outputPath = [buildDir stringByAppendingPathComponent: 
				    [fileName stringByAppendingString: @".o"]];
      outputFiles = [[outputFiles stringByAppendingString: [NSString stringWithFormat: @"\"%@\"",outputPath]] 
		      stringByAppendingString: @" "];

      if([compiler isEqualToString: @""] ||
	 compiler == nil)
	{
	  compiler = @"`gnustep-config --variable=CC` -DGNUSTEP";
	}

      NSString *objCflags = @"";
      if([lastKnownFileType isEqualToString: @"sourcecode.c.objc"])
	{
	  // objCflags = @"-fconstant-string-class=NSConstantString";
          objCflags = @"";
	}
      NSString *std = [NSString stringWithCString: getenv("GCC_C_LANGUAGE_STANDARD") != NULL ?
                                getenv("GCC_C_LANGUAGE_STANDARD") : "" ];
      if ([std length] > 0)
        {
	    if([std isEqualToString:@"compiler-default"] == YES)
	    {
		std = @"gnu99";
	    }
	    objCflags = [NSString stringWithFormat: @"%@ -std=%@",
				  objCflags, std];
        }

      // remove flags incompatible with gnustep...
      objCflags = [objCflags stringByReplacingOccurrencesOfString: @"-std=gnu11" withString: @""];
      headerSearchPaths = [headerSearchPaths stringByReplacingEnvironmentVariablesWithValues];
      
      BOOL exists = [manager fileExistsAtPath: [self buildPath]];
      NSString *configString = [context objectForKey: @"CONFIG_STRING"]; 
      NSString *buildTemplate = @"%@ 2> %@ -c %@ %@ %@ %@ -o %@";
      NSString *compilePath = ([[[self buildPath] pathComponents] count] > 1 && !exists) ?
        [[[self buildPath] stringByDeletingFirstPathComponent] stringByEscapingSpecialCharacters] :
        [self buildPath];
      NSString *errorOutPath = [outputPath stringByAppendingString: @".err"];
      NSString *buildCommand = [NSString stringWithFormat: buildTemplate, 
					 compiler,
                                         [errorOutPath stringByAddingQuotationMarks],
					 [compilePath stringByAddingQuotationMarks],
					 objCflags,
					 configString,
					 headerSearchPaths,
					 [outputPath stringByAddingQuotationMarks]];

      NSDebugLog(@"buildCommand = %@", buildCommand);
      
      NSDictionary *buildPathAttributes =  [[NSFileManager defaultManager] attributesOfItemAtPath: buildPath
											    error: &error];
      NSDictionary *outputPathAttributes = [[NSFileManager defaultManager] attributesOfItemAtPath: outputPath
											    error: &error];
      NSDate *buildPathDate = [buildPathAttributes fileModificationDate];
      NSDate *outputPathDate = [outputPathAttributes fileModificationDate];

      NSDebugLog(@"buildCommand %@", buildCommand);
      buildCommand = [buildCommand stringByReplacingOccurrencesOfString: @"$(inherited)"
                                                             withString: @"."];
      
      if(outputPathDate != nil)
	{
	  if([buildPathDate compare: outputPathDate] == NSOrderedDescending)
	    {	  
	      result = system([buildCommand cString]);
	      if([modified isEqualToString: @"NO"])
		{
		  modified = @"YES";
		  [context setObject: @"YES"
			      forKey: @"MODIFIED_FLAG"];
		}
	    }
	  else
	    {
	      puts([[NSString stringWithFormat: @"\t** Already built: %@",buildPath] cString]);
	    }
	}
      else
	{
          NSDebugLog(@"\t%@",buildCommand); 
	  result = system([buildCommand cString]);
	  if([modified isEqualToString: @"NO"])
	    {
	      modified = @"YES";
	      [context setObject: @"YES"
			  forKey: @"MODIFIED_FLAG"];
	    }
	}

      // If the result is not successful, show the error...
      if (result != 0)
        {
          NSLog(@"%sReturn Value:%s %d", RED, RESET, result);
          NSLog(@"%sCommand:%s %s%@%s", RED, RESET, CYAN, buildCommand, RESET);
          NSLog(@"%sCurrent Directory:%s %s%@%s", RED, RESET, CYAN, [manager currentDirectoryPath], RESET);
          NSString *errorString = [NSString stringWithContentsOfFile: errorOutPath];
          NSLog(@"%sMessage:%s %@", RED, RESET, errorString);
        }

      [context setObject: outputFiles forKey: @"OUTPUT_FILES"];
    }

  return (result == 0);
}

- (NSMutableArray *) _arrayForKey: (NSString *)keyName
{
  GSXCBuildContext *context = [GSXCBuildContext sharedBuildContext];
  NSMutableArray *result = [context objectForKey: keyName];

  if (result == nil)
    {
      result = [NSMutableArray array];
      [context setObject: result forKey: keyName];
    }

  return result;
}

- (BOOL) generate
{
  GSXCBuildContext *context = [GSXCBuildContext sharedBuildContext];
  NSMutableArray *objcFiles = [self _arrayForKey: @"OBJC_FILES"];
  NSMutableArray *cFiles = [self _arrayForKey: @"C_FILES"];
  NSMutableArray *cppFiles = [self _arrayForKey: @"CPP_FILES"];
  NSMutableArray *objcppFiles = [self _arrayForKey: @"OBJCPP_FILES"];
  NSMutableArray *addlIncDirs = [self _arrayForKey: @"ADDITIONAL_INCLUDE_DIRS"];
  BOOL targetInSubdir = [[context objectForKey:@"TARGET_IN_SUBDIR"] isEqualToString:@"YES"];
  NSString *of = [context objectForKey: @"OUTPUT_FILES"];
  NSString *modified = [context objectForKey: @"MODIFIED_FLAG"];
  NSString *outputFiles = (of == nil)?@"":of;
  int result = 0;
  NSFileManager *manager = [NSFileManager defaultManager];

  // NSDebugLog(@"*** %@", sourceTree);
  if(modified == nil)
    {
      modified = @"NO";
      [context setObject: @"NO"
		  forKey: @"MODIFIED_FLAG"];
    }

  // Get project root
  char *proj_root = getenv("PROJECT_ROOT");
  if (proj_root == NULL ||
      strcmp(proj_root, "") == 0)
    {
      proj_root = "";
    }

  NSString *buildPath = [[NSString stringWithCString: proj_root] 
				         stringByAppendingPathComponent: 
                            [self buildPath]];


  NSArray *localHeaderPathsArray = [self allSubdirsAtPath:@"."];
  NSString *buildDir = [NSString stringWithCString: getenv("TARGET_BUILD_DIR")];
  buildDir = [buildDir stringByAppendingPathComponent: [self productName]];
  NSString *additionalHeaderDirs = [context objectForKey:@"INCLUDE_DIRS"];
  NSString *derivedSrcHeaderDir = [context objectForKey: @"DERIVED_SOURCE_HEADER_DIR"];
  NSString *headerSearchPaths = [[context objectForKey: @"HEADER_SEARCH_PATHS"] 
				      implodeArrayWithSeparator: @" -I"];
  NSString *warningCflags = [[context objectForKey: @"WARNING_CFLAGS"] 
				  implodeArrayWithSeparator: @" "];
  NSString *localHeaderPaths = [localHeaderPathsArray implodeArrayWithSeparator:@" -I"];

  NSDebugLog(@"localHeaderPathsArray = %@, %@", localHeaderPathsArray, localHeaderPaths);
  NSDebugLog(@"Build path = %@, %@", [self buildPath], [[self buildPath] stringByDeletingFirstPathComponent]);
  // blank these out if they are not used...
  if(headerSearchPaths == nil)
    {
      headerSearchPaths = @"";
    }
  if(localHeaderPaths == nil)
    {
      localHeaderPaths = @"";
    }
  
  if(warningCflags == nil)
    {
      warningCflags = @"";
    }
  
  // If we have derived sources, then get the header directory and add it to the search path....
  if(derivedSrcHeaderDir != nil)
    {
      if([[derivedSrcHeaderDir pathComponents] count] > 1)
        {
          headerSearchPaths = [headerSearchPaths stringByAppendingString: 
                                              [NSString stringWithFormat: @" -I%@ ",
                                                        [derivedSrcHeaderDir stringByDeletingLastPathComponent]]];
        }
    }
  
  // If we have additional header dirs specified... then add them.
  if(additionalHeaderDirs != nil)
    {
      headerSearchPaths = [headerSearchPaths stringByAppendingString: additionalHeaderDirs];
      headerSearchPaths = [headerSearchPaths stringByAppendingString: localHeaderPaths];
    }
  
  // If the target is in the subdirectory, then override the preprending of
  // the project root.
  if(targetInSubdir)
    {
      buildPath = [self path]; 
    }
  
  // Sometimes, for some incomprehensible reason, the buildpath doesn't 
  // need the project dir pre-pended.  This could be due to differences 
  // in different version of xcode.  It must be removed to successfully
  // compile the application...
  if([manager fileExistsAtPath:buildPath] == NO)
    {
      buildPath = [self path];
    }
  
  NSString *objCflags = @"";
  if([lastKnownFileType isEqualToString: @"sourcecode.c.objc"])
    {
      // objCflags = @"-fconstant-string-class=NSConstantString";
      objCflags = @"";
    }
  
  // remove flags incompatible with gnustep...
  objCflags = [objCflags stringByReplacingOccurrencesOfString: @"-std=gnu11" withString: @""];
  
  BOOL exists = [manager fileExistsAtPath: [self buildPath]];
  NSString *compilePath = ([[[self buildPath] pathComponents] count] > 1 && !exists) ?
    [[[self buildPath] stringByDeletingFirstPathComponent] stringByEscapingSpecialCharacters] :
    [self buildPath];
  
  [context setObject: outputFiles forKey: @"OUTPUT_FILES"];

  if([lastKnownFileType isEqualToString: @"sourcecode.c.objc"])
    {
      [objcFiles addObject: compilePath];
    }

  if([lastKnownFileType isEqualToString: @"sourcecode.c.c"])
    {
      [cFiles addObject: compilePath];
    }
  
  if([lastKnownFileType isEqualToString: @"sourcecode.cpp.cpp"])
    {
      [cppFiles addObject: compilePath];
    }

  if([lastKnownFileType isEqualToString: @"sourcecode.cpp.objcpp"])
    {
      [objcppFiles addObject: compilePath];
    }

  NSString *includePath = [compilePath stringByDeletingLastPathComponent];
  NSDebugLog(@"%@", includePath);
  if (includePath != nil && [includePath isEqualToString: @""] == NO)
    {
      if ([addlIncDirs containsObject: includePath] == NO)
        {
          [addlIncDirs addObject: includePath];
        }
    }
  NSDebugLog(@"Additional includes %@", addlIncDirs);

  return (result == 0);
}

- (NSString *) description
{
  NSString *s = [super description];
  return [s stringByAppendingFormat: @" <%@, %@>", path, lastKnownFileType];
}
@end
