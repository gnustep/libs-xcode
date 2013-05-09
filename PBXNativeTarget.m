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

- (void) _productWrapper
{
  GSXCBuildContext *context = [GSXCBuildContext sharedBuildContext];
  NSString *buildDir = [NSString stringWithCString: getenv("BUILT_PRODUCTS_DIR")];
  NSString *uninstalledProductsDir = [buildDir stringByAppendingPathComponent: @"UninstalledProducts"]; 
  NSString *fullPath = [[buildDir stringByAppendingPathComponent: @"UninstalledProducts"] 
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
  
  NSLog(@"=== Building Target %@",name);
  [buildConfigurationList applyDefaultConfiguration];
  [context setObject: productType
	      forKey: @"PRODUCT_TYPE"];

  NSLog(@"=== Checking Dependencies");  
  id dependency = nil;
  en = [dependencies objectEnumerator];
  while((dependency = [en nextObject]) != nil && result)
    {
      result = [dependency build];
    }
  NSLog(@"=== Done.");

  NSLog(@"=== Executing build phases...");
  [self _productWrapper];
  id phase = nil;
  en = [buildPhases objectEnumerator];
  while((phase = [en nextObject]) != nil && result)
    {
      result = [phase build];
      if(NO == result)
	{
	  NSLog(@"*** Failed build phase: %@",phase);
	}
    }
  NSLog(@"=== Done...");
  NSLog(@"=== Completed Executing Target %@", name);

  return result;
}

- (BOOL) clean
{
  NSLog(@"=== Cleaning Target %@",name);
  NSString *buildDir = [NSString stringWithCString: getenv("BUILT_PRODUCTS_DIR")];
  NSString *command = [NSString stringWithFormat: @"rm -rf %@",buildDir];

  NSLog(@"Cleaning build directory");
  int result = system([command cString]);

  if(result == 0)
    {
      if([[NSFileManager defaultManager] fileExistsAtPath: @"derived_src"])
	{
	  command = @"rm -rf derived_src";
	  NSLog(@"Cleaning derived_src directory");
	  result = system([command cString]);
	}
    }
  
  NSLog(@"=== Completed Cleaning Target %@",name);
  return (result == 0);
}

- (BOOL) install
{
  NSLog(@"=== Installing Target %@",name);
  NSString *buildDir = [NSString stringWithCString: getenv("BUILT_PRODUCTS_DIR")];
  NSString *uninstalledProductsDir = [buildDir stringByAppendingPathComponent: @"UninstalledProducts"]; 
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
	  NSLog(@"Error creating symbolic link...");
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
	  NSLog(@"Error creating symbolic link...");
	}

      /*
      [fileManager removeItemAtPath: [libsDir stringByAppendingPathComponent: 
						  [NSString stringWithFormat: @"lib%@.so.%@",execName,frameworkVersion]]
			      error:NULL];
      flag = [fileManager createSymbolicLinkAtPath: [libsDir stringByAppendingPathComponent: 
								 [NSString stringWithFormat: @"lib%@.so.%@",execName,frameworkVersion]]
				       pathContent: [frameworksLinkDir stringByAppendingPathComponent: 
									  [NSString stringWithFormat: @"lib%@.so",execName]]];
      if(!flag)
	{
	  NSLog(@"Error creating symbolic link...");
	}
      */
    }
  else if([productType isEqualToString: LIBRARY_TYPE])
    {
      NSString *headersDir = [[installDir stringByAppendingPathComponent: @"Library"] stringByAppendingPathComponent: @"Headers"];
      NSString *libsDir = [[installDir stringByAppendingPathComponent: @"Library"] stringByAppendingPathComponent: @"Libraries"];
      NSString *derivedSrcDir = @"derived_src";
      NSString *derivedSrcHeaderDir = derivedSrcDir;
      NSString *destPath = [libsDir stringByAppendingPathComponent: [productReference path]];

      NSLog(@"\tCopy %@ -> %@",fullPath,destPath);
      [fileManager copyItemAtPath: fullPath
			   toPath: destPath
			    error: &error];

      NSEnumerator *en = [fileManager enumeratorAtPath: derivedSrcHeaderDir];
      id file = nil;
      while((file = [en nextObject]) != nil)
	{
	  NSString *fileName = [file lastPathComponent];
	  NSString *destFile = [headersDir stringByAppendingPathComponent: fileName];
	  NSLog(@"\tCopy %@ -> %@",file,destFile);
	  [fileManager copyItemAtPath: file
			       toPath: destFile
				error: &error];
	}
    }
    

  NSLog(@"=== Completed Installing Target %@",name);

  return YES;
}
@end
