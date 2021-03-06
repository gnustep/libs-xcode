#import <stdlib.h>
#import "PBXCommon.h"
#import "PBXNativeTarget.h"
#import "GSXCCommon.h"
#import "GSXCBuildContext.h"

@implementation PBXNativeTarget

- (void) dealloc
{
  [productReference release];
  [productInstallPath release];
  [productType release];
  [buildRules release];
  [comments release];
  [productSettingsXML release];
  [super dealloc];
}

// Methods....
- (PBXFileReference *) productReference // getter
{
  return productReference;
}

- (void) setProductReference: (PBXFileReference *)object; // setter
{
  ASSIGN(productReference,object);
}

- (NSString *) productInstallPath // getter
{
  return productInstallPath;
}

- (void) setProductInstallPath: (NSString *)object; // setter
{
  ASSIGN(productInstallPath,object);
}

- (NSString *) productType // getter
{
  return productType;
}

- (void) setProductType: (NSString *)object; // setter
{
  ASSIGN(productType,object);
}

- (NSMutableArray *) buildRules // getter
{
  return buildRules;
}

- (void) setBuildRules: (NSMutableArray *)object; // setter
{
  ASSIGN(buildRules,object);
}

- (NSString *) productSettingsXML // getter
{
  return productSettingsXML;
}

- (void) setProductSettingsXML: (NSString *)object // setter
{
  ASSIGN(productSettingsXML,object);
}

/*
- (XCConfigurationList *) buildConfigurationList
{
  return xcConfigurationList;
}

- (void) setBuildConfigurationList: (XCConfigurationList *)list
{
  NSLog(@"build config list = %@",list);
  ASSIGN(xcConfigurationList, list);
}
*/

- (void) _productWrapper
{
  GSXCBuildContext *context = [GSXCBuildContext sharedBuildContext];
  NSString *buildDir = [NSString stringWithCString: getenv("BUILT_PRODUCTS_DIR")];
  buildDir = [buildDir stringByAppendingPathComponent: [self name]];
  NSString *uninstalledProductsDir = [buildDir stringByAppendingPathComponent: @"Products"]; 
  NSString *fullPath = [[buildDir stringByAppendingPathComponent: @"Products"] 
			 stringByAppendingPathComponent: [productReference path]];
  NSError *error = nil;
  
  // Create directories...
  [[NSFileManager defaultManager] createDirectoryAtPath:uninstalledProductsDir
			    withIntermediateDirectories:YES
					     attributes:nil
						  error:&error];
  
  
  /*
  [[NSFileManager defaultManager] createDirectoryAtPath:buildDir
			    withIntermediateDirectories:YES
					     attributes:nil
						  error:&error];
  */

  setenv("inherited","",1); // probably from a parent project or target..
  if([productType isEqualToString: BUNDLE_TYPE] ||
     [productType isEqualToString: APPLICATION_TYPE]) 
    {
      NSString *execName = [[fullPath lastPathComponent] stringByDeletingPathExtension];

      // Create directories...
      [[NSFileManager defaultManager] createDirectoryAtPath:fullPath
				withIntermediateDirectories:YES
						 attributes:nil
						      error:&error];


      setenv("PRODUCT_OUTPUT_DIR",[fullPath cString],1);
      setenv("PRODUCT_NAME",[execName cString],1);
      setenv("EXECUTABLE_NAME",[execName cString],1);
    }
  else if([productType isEqualToString: FRAMEWORK_TYPE])
    {
      NSString *derivedSourceDir = 
	[[NSString stringWithCString: getenv("PROJECT_ROOT")] 
	  stringByAppendingPathComponent: @"derived_src"];
      NSString *execName = [[fullPath lastPathComponent] stringByDeletingPathExtension];
      NSString *derivedSourceHeaderDir = [derivedSourceDir stringByAppendingPathComponent: execName];
      NSString *frameworkVersion = 
	[NSString stringWithCString: getenv("FRAMEWORK_VERSION")];
      [context setObject: [NSString stringWithString: fullPath]
		  forKey: @"FRAMEWORK_DIR"];

      // Above "Versions"
      NSString *headersLink = [fullPath stringByAppendingPathComponent: @"Headers"];
      NSString *resourcesLink = [fullPath stringByAppendingPathComponent: @"Resources"];
      
      // Below "Versions"
      fullPath = [fullPath stringByAppendingPathComponent: @"Versions"];
      NSString *currentLink = [fullPath stringByAppendingPathComponent: @"Current"];
      fullPath = [fullPath stringByAppendingPathComponent: frameworkVersion];
      NSString *headerDir = [fullPath stringByAppendingPathComponent: @"Headers"];
      NSString *resourceDir = [fullPath stringByAppendingPathComponent: @"Resources"];
 
      // Create directories...
      [[NSFileManager defaultManager] createDirectoryAtPath:fullPath
				withIntermediateDirectories:YES
						 attributes:nil
						      error:&error];

      [[NSFileManager defaultManager] createDirectoryAtPath:derivedSourceHeaderDir
				withIntermediateDirectories:YES
						 attributes:nil
						      error:&error];

      [[NSFileManager defaultManager] createDirectoryAtPath:headerDir
				withIntermediateDirectories:YES
						 attributes:nil
						      error:&error];
      // Create links....
      [[NSFileManager defaultManager] createSymbolicLinkAtPath: currentLink
						   pathContent: frameworkVersion];

      [[NSFileManager defaultManager] createSymbolicLinkAtPath: headersLink
						   pathContent: @"Versions/Current/Headers"];

      [[NSFileManager defaultManager] createSymbolicLinkAtPath: resourcesLink
						   pathContent: @"Versions/Current/Resources"];

      // Things to pass on to the next phase...
      [context setObject: headerDir forKey: @"HEADER_DIR"];
      [context setObject: resourceDir forKey: @"RESOURCE_DIR"];
      [context setObject: derivedSourceHeaderDir forKey: @"DERIVED_SOURCE_HEADER_DIR"];
      [context setObject: derivedSourceDir forKey: @"DERIVED_SOURCE_DIR"];

      setenv("PRODUCT_OUTPUT_DIR",[fullPath cString],1);
      setenv("PRODUCT_NAME",[execName cString],1);
      setenv("EXECUTABLE_NAME",[execName cString],1);
    }
  else if([productType isEqualToString: LIBRARY_TYPE])
    {
      // for non-bundled packages...
      NSString *fileName = [fullPath lastPathComponent];
      NSString *path = [fullPath stringByDeletingLastPathComponent];
      setenv("PRODUCT_OUTPUT_DIR",[path cString],1);
      setenv("PRODUCT_NAME",[fileName cString],1);
      setenv("EXECUTABLE_NAME",[fileName cString],1);

      NSString *derivedSourceDir = 
	[[NSString stringWithCString: getenv("PROJECT_ROOT")] 
	  stringByAppendingPathComponent: @"derived_src"];
      NSString *derivedSourceHeaderDir = derivedSourceDir; // stringByAppendingPathComponent: @"Headers"];

      [context setObject: derivedSourceHeaderDir forKey: @"DERIVED_SOURCE_HEADER_DIR"];
      [context setObject: derivedSourceDir forKey: @"DERIVED_SOURCE_DIR"];

      [[NSFileManager defaultManager] createDirectoryAtPath:derivedSourceHeaderDir
				withIntermediateDirectories:YES
						 attributes:nil
						      error:&error];
    }
  else 
    {
      // for non-bundled packages...
      NSString *fileName = [fullPath lastPathComponent];
      NSString *path = [fullPath stringByDeletingLastPathComponent];

      setenv("PRODUCT_OUTPUT_DIR",[path cString],1);
      setenv("PRODUCT_NAME",[fileName cString],1);
      setenv("EXECUTABLE_NAME",[fileName cString],1);
    }
}

- (BOOL) build
{
  BOOL result = YES;
  NSEnumerator *en = nil;
  GSXCBuildContext *context = [GSXCBuildContext sharedBuildContext];
  
  puts([[NSString stringWithFormat: @"=== Building Target %@",name] cString]);
  [buildConfigurationList applyDefaultConfiguration];
  [context setObject: buildConfigurationList
              forKey: @"buildConfig"];
  [context setObject: productType
	      forKey: @"PRODUCT_TYPE"];
  if(productSettingsXML != nil)
    {
      [context setObject: productSettingsXML 
                  forKey: @"PRODUCT_SETTINGS_XML"];
    }
  puts([[NSString stringWithFormat: @"=== Checking Dependencies"] cString]);  
  id dependency = nil;
  en = [dependencies objectEnumerator];
  while((dependency = [en nextObject]) != nil && result)
    {
      result = [dependency build];
    }
  puts([[NSString stringWithFormat: @"=== Done."] cString]);

  puts([[NSString stringWithFormat: @"=== Executing build phases..."] cString]);
  [self _productWrapper];
  id phase = nil;
  en = [buildPhases objectEnumerator];
  while((phase = [en nextObject]) != nil && result)
    {
      [phase setTarget: self];
      result = [phase build];
      if(NO == result)
	{
	  puts([[NSString stringWithFormat: @"*** Failed build phase: %@",phase] cString]);
	}
    }
  puts([[NSString stringWithFormat: @"=== Done..."] cString]);
  puts([[NSString stringWithFormat: @"=== Completed Executing Target %@", name] cString]);

  return result;
}

- (BOOL) clean
{
  puts([[NSString stringWithFormat: @"=== Cleaning Target %@",name] cString]);
  NSString *buildDir = [NSString stringWithCString: getenv("BUILT_PRODUCTS_DIR")];
  buildDir = [buildDir stringByAppendingPathComponent: [self name]];
  NSString *command = [NSString stringWithFormat: @"rm -rf %@",buildDir];

  puts([[NSString stringWithFormat: @"Cleaning build directory"] cString]);
  int result = system([command cString]);

  if(result == 0)
    {
      if([[NSFileManager defaultManager] fileExistsAtPath: @"derived_src"])
	{
	  command = @"rm -rf derived_src";
	  puts([[NSString stringWithFormat: @"Cleaning derived_src directory"] cString]);
	  result = system([command cString]);
	}
    }
  
  puts([[NSString stringWithFormat: @"=== Completed Cleaning Target %@",name] cString]);
  return (result == 0);
}

- (BOOL) install
{
  puts([[NSString stringWithFormat: @"=== Installing Target %@",name] cString]);
  NSString *buildDir = [NSString stringWithCString: getenv("BUILT_PRODUCTS_DIR")];
  buildDir = [buildDir stringByAppendingPathComponent: [self name]];

  NSString *uninstalledProductsDir = [buildDir stringByAppendingPathComponent: @"Products"]; 
  NSString *fullPath = [uninstalledProductsDir stringByAppendingPathComponent: [productReference path]];
  NSString *installDir = [NSString stringWithCString: getenv("GNUSTEP_LOCAL_ROOT")]; // FIXME: Shouldn't always be local...
  NSString *fileName = [fullPath lastPathComponent];
  NSString *execName = [fileName stringByDeletingPathExtension];
  NSFileManager *fileManager = [NSFileManager defaultManager];
  NSError *error = nil;

  if([productType isEqualToString: APPLICATION_TYPE])
    {
      NSString *installDest = [[installDir stringByAppendingPathComponent: @"Applications"] stringByAppendingPathComponent: fileName]; 
      [fileManager copyItemAtPath: fullPath
			   toPath: installDest
			    error: &error];
    }
  else if([productType isEqualToString: FRAMEWORK_TYPE])
    {
      /*
      NSString *frameworkVersion = 
	[NSString stringWithCString: getenv("FRAMEWORK_VERSION")];
      */
      NSString *installDest = [[installDir stringByAppendingPathComponent: @"Library"] stringByAppendingPathComponent: @"Frameworks"]; 
      NSString *productDir = [installDest stringByAppendingPathComponent: [productReference path]];
      NSString *headersDir = [[installDir stringByAppendingPathComponent: @"Library"] stringByAppendingPathComponent: @"Headers"];
      NSString *libsDir = [[installDir stringByAppendingPathComponent: @"Library"] stringByAppendingPathComponent: @"Libraries"];
      NSString *frameworksLinkDir = [[[@"../Frameworks" stringByAppendingPathComponent: [productReference path]] stringByAppendingPathComponent:@"Versions"] stringByAppendingPathComponent:@"Current"];
      NSString *headersLinkDir = [[[@"../Frameworks" stringByAppendingPathComponent: [productReference path]] stringByAppendingPathComponent:@"Versions"] stringByAppendingPathComponent:@"Current"];

      // Copy
      [fileManager removeItemAtPath: productDir error:NULL];
      [fileManager copyItemAtPath: fullPath
			   toPath: productDir
			    error: &error];

      // Create links...
      [fileManager removeItemAtPath: [headersDir stringByAppendingPathComponent: execName]
			      error:NULL];
      BOOL flag = [fileManager createSymbolicLinkAtPath: [headersDir stringByAppendingPathComponent: execName]
					    pathContent: [headersLinkDir stringByAppendingPathComponent: @"Headers"]];
      if(!flag)
	{
	  puts([[NSString stringWithFormat: @"Error creating symbolic link..."] cString]);
	}

      [fileManager removeItemAtPath: [libsDir stringByAppendingPathComponent: 
								 [NSString stringWithFormat: @"lib%@.so",execName]]
			      error:NULL];
      flag = [fileManager createSymbolicLinkAtPath: [libsDir stringByAppendingPathComponent: 
								 [NSString stringWithFormat: @"lib%@.so",execName]]
				       pathContent: [frameworksLinkDir stringByAppendingPathComponent: 
								    [NSString stringWithFormat: @"lib%@.so",execName]]];
      if(!flag)
	{
	  puts([[NSString stringWithFormat: @"Error creating symbolic link..."] cString]);
	}
    }
  else if([productType isEqualToString: LIBRARY_TYPE])
    {
      NSString *headersDir = [[installDir stringByAppendingPathComponent: @"Library"] stringByAppendingPathComponent: @"Headers"];
      NSString *libsDir = [[installDir stringByAppendingPathComponent: @"Library"] stringByAppendingPathComponent: @"Libraries"];
      NSString *derivedSrcDir = @"derived_src";
      NSString *derivedSrcHeaderDir = derivedSrcDir;
      NSString *destPath = [libsDir stringByAppendingPathComponent: [productReference path]];

      puts([[NSString stringWithFormat: @"\tCopy %@ -> %@",fullPath,destPath] cString]);
      [fileManager copyItemAtPath: fullPath
			   toPath: destPath
			    error: &error];

      NSEnumerator *en = [fileManager enumeratorAtPath: derivedSrcHeaderDir];
      id file = nil;
      while((file = [en nextObject]) != nil)
	{
	  NSString *fileName = [file lastPathComponent];
	  NSString *destFile = [headersDir stringByAppendingPathComponent: fileName];
	  puts([[NSString stringWithFormat: @"\tCopy %@ -> %@",file,destFile] cString]);
	  [fileManager copyItemAtPath: file
			       toPath: destFile
				error: &error];
	}
    }
    

  puts([[NSString stringWithFormat: @"=== Completed Installing Target %@",name] cString]);

  return YES;
}

- (NSString *) _arrayToList: (NSArray *)arr
{
  NSString *result = @"";
  NSEnumerator *en = [arr objectEnumerator];
  NSString *aname = nil;

  while((aname = [en nextObject]) != nil)
    {
      if ([aname isEqualToString: [arr firstObject]] == YES)
        {
          result = [result stringByAppendingString: [NSString stringWithFormat: @"%@ ", aname]];
        }
      else
        {
          result = [result stringByAppendingString: [NSString stringWithFormat: @"\t%@ ", aname]];
        }
      
      if ([aname isEqualToString: [arr lastObject]] == NO)
        {
          result = [result stringByAppendingString: @"\\\n"];
        }
    }
  return result;
}

- (NSString *) _arrayToIncludeList: (NSArray *)arr
{
  NSString *result = @"-I. \\\n";
  NSEnumerator *en = [arr objectEnumerator];
  NSString *aname = nil;

  while((aname = [en nextObject]) != nil)
    {
      result = [result stringByAppendingString: [NSString stringWithFormat: @"\t-I./%@ ", aname]];
      if ([aname isEqualToString: [arr lastObject]] == NO)
        {
          result = [result stringByAppendingString: @"\\\n"];
        }
    }
  return result;
}


- (NSString *) _arrayToLinkList: (NSArray *)arr
{
  NSString *result = @"";
  NSEnumerator *en = [arr objectEnumerator];
  NSString *aname = nil;

  while((aname = [en nextObject]) != nil)
    {
      if ([aname isEqualToString: [arr firstObject]] == YES)
        {
          result = [result stringByAppendingString: [NSString stringWithFormat: @"%@ ", aname]];
        }
      else
        {
          result = [result stringByAppendingString: [NSString stringWithFormat: @"\t%@ ", aname]];
        }
      
      if ([aname isEqualToString: [arr lastObject]] == NO)
        {
          result = [result stringByAppendingString: @"\\\n"];
        }
    }
  return result;
}

- (BOOL) generate
{
  BOOL result = YES;
  NSEnumerator *en = nil;
  GSXCBuildContext *context = [GSXCBuildContext sharedBuildContext];
  
  puts([[NSString stringWithFormat: @"=== Generating Target: %@",name] cString]);
  [buildConfigurationList applyDefaultConfiguration];
  [context setObject: productType
	      forKey: @"PRODUCT_TYPE"];
  if(productSettingsXML != nil)
    {
      [context setObject: productSettingsXML 
                  forKey: @"PRODUCT_SETTINGS_XML"];
    }
  puts([[NSString stringWithFormat: @"=== Checking Dependencies"] cString]);  
  id dependency = nil;
  en = [dependencies objectEnumerator];
  while((dependency = [en nextObject]) != nil && result)
    {
      result = [dependency generate];
    }
  puts([[NSString stringWithFormat: @"=== Done."] cString]);

  puts([[NSString stringWithFormat: @"=== Interpreting build phases..."] cString]);
  [self _productWrapper];
  id phase = nil;
  en = [buildPhases objectEnumerator];
  while((phase = [en nextObject]) != nil && result)
    {
      [phase setTarget: self];
      result = [phase generate];
      if(NO == result)
	{
	  puts([[NSString stringWithFormat: @"*** Failed build phase: %@",phase] cString]);
	}
    }
  puts([[NSString stringWithFormat: @"=== Done..."] cString]);

  NSString *appName = [[self name] stringByDeletingPathExtension];
  
  // Construct the makefile out of the data we have thusfar collected.
  puts("\t** Generating GNUmakefile from data...");
  NSString *makefileName = @"GNUmakefile";
  NSString *makefileString = @"";
  NSString *objCFilesString = [self _arrayToList: [context objectForKey: @"OBJC_FILES"]];
  NSString *cFilesString = [self _arrayToList: [context objectForKey: @"C_FILES"]];
  NSString *cppFilesString = [self _arrayToList: [context objectForKey: @"CPP_FILES"]];
  NSString *objCPPFilesString = [self _arrayToList: [context objectForKey: @"OBJCPP_FILES"]];  
  NSString *resourceFilesString = [self _arrayToList: [context objectForKey: @"RESOURCES"]];
  NSString *additionalIncludes = [self _arrayToIncludeList: [context objectForKey: @"ADDITIONAL_INCLUDE_DIRS"]];
  NSString *additionalOCflags = [self _arrayToLinkList: [context objectForKey: @"ADDITIONAL_OBJC_LIBS"]];
  NSString *projectType = [context objectForKey: @"PROJECT_TYPE"];

  // Sometimes the build will generate all of the target makefiles in one place, depending on the version of
  // Xcode the project was created with.
  if([[NSFileManager defaultManager] fileExistsAtPath: @"GNUmakefile"])
    {
      // if it collides with the existing name, add the target name...
      makefileName = [makefileName stringByAppendingString: [NSString stringWithFormat: @"_%@", appName]];
    }

  makefileString = [makefileString stringByAppendingString: @"#\n"];
  makefileString = [makefileString stringByAppendingString: [NSString stringWithFormat: @"# GNUmakefile for target %@\n", name]];
  makefileString = [makefileString stringByAppendingString: @"# begin - generated by buildtool\n"];
  makefileString = [makefileString stringByAppendingString: @"#\n\n"];
  makefileString = [makefileString stringByAppendingString: @"include $(GNUSTEP_MAKEFILES)/common.make\n\n"];
  makefileString = [makefileString stringByAppendingString: [NSString stringWithFormat: @"APP_NAME = %@\n\n", appName]];
  makefileString = [makefileString stringByAppendingString: [NSString stringWithFormat: @"%@_OBJC_FILES = %@\n\n", appName, objCFilesString]];
  makefileString = [makefileString stringByAppendingString: [NSString stringWithFormat: @"%@_C_FILES = %@\n\n", appName, cFilesString]];
  makefileString = [makefileString stringByAppendingString: [NSString stringWithFormat: @"%@_CPP_FILES = %@\n\n", appName, cppFilesString]];
  makefileString = [makefileString stringByAppendingString: [NSString stringWithFormat: @"%@_OBJCPP_FILES = %@\n\n", appName, objCPPFilesString]];
  makefileString = [makefileString stringByAppendingString: [NSString stringWithFormat: @"%@_RESOURCE_FILES = %@\n\n", appName, resourceFilesString]];
  makefileString = [makefileString stringByAppendingString: [NSString stringWithFormat: @"ADDITIONAL_INCLUDE_DIRS += %@\n\n", additionalIncludes]];
  makefileString = [makefileString stringByAppendingString: [NSString stringWithFormat: @"ADDITIONAL_OBJC_LIBS += %@\n\n", additionalOCflags]];
  makefileString = [makefileString stringByAppendingString: @"include $(GNUSTEP_MAKEFILES)/common.make\n"];
  makefileString = [makefileString stringByAppendingString: [NSString stringWithFormat: @"include $(GNUSTEP_MAKEFILES)/%@.make\n\n", projectType]];
  makefileString = [makefileString stringByAppendingString: @"#\n"];
  makefileString = [makefileString stringByAppendingString: @"# end - generated makefile\n"];
  makefileString = [makefileString stringByAppendingString: @"#\n"];

  NSDebugLog(@"makefile = %@", makefileString);
  [makefileString writeToFile: makefileName atomically: YES];
  puts([[NSString stringWithFormat: @"=== Completed generation for target %@", name] cString]);

  return result;
}
@end
