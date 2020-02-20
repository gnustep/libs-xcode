#import <stdlib.h>

#import "PBXCommon.h"
#import "PBXFileReference.h"
#import "PBXGroup.h"
#import "GSXCBuildContext.h"
#import "NSArray+Additions.h"
#import "NSString+PBXAdditions.h"

@implementation PBXFileReference

// Methods....
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
  NSDebugLog(@"apath = %@", apath);
  NSMutableArray *results = [NSMutableArray arrayWithCapacity:10];
  NSFileManager *manager = [[NSFileManager alloc] init];
  NSDirectoryEnumerator *en = [manager enumeratorAtPath:apath];
  NSString *fileName = nil;
  NSDebugLog(@"cwd = %@", [manager currentDirectoryPath]);
  
  while((fileName = [en nextObject]) != nil)
    {
      BOOL isDir = NO;
      NSString *dirToAdd = fileName; //[fileName stringByDeletingLastPathComponent];
      [manager fileExistsAtPath: fileName
                    isDirectory: &isDir];

      if (isDir && [results containsObject: dirToAdd] == NO)
        {
          NSString *ext = [dirToAdd pathExtension];
          if ([ext isEqualToString: @"app"] ||
              [ext isEqualToString: @"xcassets"] ||
              [ext isEqualToString: @"lproj"] ||
              [dirToAdd containsString: @"build"] ||
              [dirToAdd containsString: @"xcassets"] ||
              [dirToAdd containsString: @"lproj"] ||
              [dirToAdd containsString: @"xcodeproj"])
            {
              continue;
            }
          [results addObject: [dirToAdd stringByEscapingSpecialCharacters]];
          NSDebugLog(@"adding dirToAdd = %@", dirToAdd);
        }
    }

  NSDebugLog(@"results = %@", results);
  RELEASE(manager);
  return results;
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

- (BOOL) build
{  
  GSXCBuildContext *context = [GSXCBuildContext sharedBuildContext];
  BOOL targetInSubdir = [[context objectForKey:@"TARGET_IN_SUBDIR"] isEqualToString:@"YES"];
  NSString *of = [context objectForKey: @"OUTPUT_FILES"];
  NSString *modified = [context objectForKey: @"MODIFIED_FLAG"];
  NSString *outputFiles = (of == nil)?@"":of;
  int result = 0;
  NSError *error = nil;
  NSFileManager *manager = [NSFileManager defaultManager];

  // NSDebugLog(@"*** %@", sourceTree);
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
      char *proj_root = getenv("PROJECT_ROOT");
      if (proj_root == NULL ||
          strcmp(proj_root, "") == 0)
        {
          proj_root = "";
        }
      
      char *cc = getenv("CC");
      if (cc == NULL ||
          strcmp(cc, "") == 0)
        {
          cc = "`gnustep-config --variable=CC`";
        }

      NSString *buildPath = [[NSString stringWithCString: proj_root] 
				         stringByAppendingPathComponent: 
				    [self buildPath]];
      NSArray *localHeaderPathsArray = [self allSubdirsAtPath:@"."];
      NSString *fileName = [path lastPathComponent];
      NSString *buildDir = [NSString stringWithCString: getenv("TARGET_BUILD_DIR")];
      NSString *additionalHeaderDirs = [context objectForKey:@"INCLUDE_DIRS"];
      NSString *derivedSrcHeaderDir = [context objectForKey: @"DERIVED_SOURCE_HEADER_DIR"];
      NSString *compiler = [NSString stringWithCString: cc];
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

      NSString *outputPath = [buildDir stringByAppendingPathComponent: 
				    [fileName stringByAppendingString: @".o"]];
      outputFiles = [[outputFiles stringByAppendingString: outputPath] 
		      stringByAppendingString: @" "];
      if([compiler isEqualToString: @""] ||
	 compiler == nil)
	{
	  compiler = @"`gnustep-config --variable=CC` -DGNUSTEP";
	}

      NSString *objCflags = @"";
      if([lastKnownFileType isEqualToString: @"sourcecode.c.objc"])
	{
	  objCflags = @"-fgnu-runtime -fconstant-string-class=NSConstantString";
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
    
      NSString *configString = [context objectForKey: @"CONFIG_STRING"]; 
      NSString *buildTemplate = @"%@ %@ -c %@ %@ %@ -o %@";
      NSDebugLog(@"*** %@ %@", path, buildPath);
      NSString *compilePath = ([[[self buildPath] pathComponents] count] > 1)?
        [[self buildPath] stringByEscapingSpecialCharacters]:[self buildPath];
      NSString *buildCommand = [NSString stringWithFormat: buildTemplate, 
					 compiler,
					 compilePath,
					 objCflags,
					 configString,
					 headerSearchPaths,
					 [outputPath stringByEscapingSpecialCharacters]];

      NSDictionary *buildPathAttributes =  [[NSFileManager defaultManager] attributesOfItemAtPath: buildPath
											    error: &error];
      NSDictionary *outputPathAttributes = [[NSFileManager defaultManager] attributesOfItemAtPath: outputPath
											    error: &error];
      NSDate *buildPathDate = [buildPathAttributes fileModificationDate];
      NSDate *outputPathDate = [outputPathAttributes fileModificationDate];

      if(outputPathDate != nil)
	{
	  if([buildPathDate compare: outputPathDate] == NSOrderedDescending)
	    {	  
	      // puts([[NSString stringWithFormat: @"\t** Rebuilding: %@",buildCommand] cString]);
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

      [context setObject: outputFiles forKey: @"OUTPUT_FILES"];
    }

  return (result == 0);
}

- (NSString *) description
{
  NSString *s = [super description];
  return [s stringByAppendingFormat: @" <%@, %@>", path, lastKnownFileType];
}
@end
