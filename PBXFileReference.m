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
      NSString *fileName = [path lastPathComponent];
      NSString *buildDir = [NSString stringWithCString: getenv("TARGET_BUILD_DIR")];
      /*
      NSString *systemIncludeDir = [[[NSString stringWithCString: getenv("GNUSTEP_SYSTEM_ROOT")] 
				      stringByAppendingPathComponent: @"Library"] 
				     stringByAppendingPathComponent: @"Headers"];
      NSString *localIncludeDir = [[[NSString stringWithCString: getenv("GNUSTEP_LOCAL_ROOT")] 
				     stringByAppendingPathComponent: @"Library"] 
				    stringByAppendingPathComponent: @"Headers"];
      NSString *userIncludeDir = [[[NSString stringWithCString: getenv("GNUSTEP_USER_ROOT")] 
				    stringByAppendingPathComponent: @"Library"] 
				   stringByAppendingPathComponent: @"Headers"];
      */
      NSString *additionalHeaderDirs = [context objectForKey:@"INCLUDE_DIRS"];
      NSString *derivedSrcHeaderDir = [context objectForKey: @"DERIVED_SOURCE_HEADER_DIR"];
      NSString *compiler = [NSString stringWithCString: getenv("CC")];
      NSString *headerSearchPaths = [[context objectForKey: @"HEADER_SEARCH_PATHS"] 
				      implodeArrayWithSeparator: @" -I"];
      NSString *warningCflags = [[context objectForKey: @"WARNING_CFLAGS"] 
				  implodeArrayWithSeparator: @" "];

      // blank these out if they are not used...
      if(headerSearchPaths == nil)
	{
	  headerSearchPaths = @"";
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
	}
      
      NSString *buildPath = [[NSString stringWithCString: getenv("PROJECT_ROOT")] 
				         stringByAppendingPathComponent: 
	 			[self buildPath]];
      if(targetInSubdir)
	{
	  buildPath = [self path]; //[buildPath stringByDeletingFirstPathComponent];
	}

      NSString *outputPath = [buildDir stringByAppendingPathComponent: 
				    [fileName stringByAppendingString: @".o"]];
      outputFiles = [[outputFiles stringByAppendingString: outputPath] 
		      stringByAppendingString: @" "];
      if([compiler isEqualToString: @""] ||
	 compiler == nil)
	{
	  compiler = @"`gnustep-config --variable=CC`";
	}

      NSString *objCflags = @"";
      if([lastKnownFileType isEqualToString: @"sourcecode.c.objc"])
	{
	  objCflags = @"-fgnu-runtime -fconstant-string-class=NSConstantString";
	}
    
      NSString *configString = [context objectForKey: @"CONFIG_STRING"]; 
      NSString *buildTemplate = @"%@ %@ -c %@ %@ %@ -o %@";
      
      NSString *buildCommand = [NSString stringWithFormat: buildTemplate, 
					 compiler,
					 [buildPath stringByEscapingSpecialCharacters], 
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
	      NSLog(@"\t** Rebuilding: %@",buildCommand);
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
	      NSLog(@"\t** Already built, nothing to be done for %@",buildPath);
	    }
	}
      else
	{
	  NSLog(@"\t%@",buildCommand);
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

@end
