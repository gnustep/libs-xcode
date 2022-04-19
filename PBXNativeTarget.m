/*
   Copyright (C) 2018, 2019, 2020, 2021 Free Software Foundation, Inc.

   Written by: Gregory John Casament <greg.casamento@gmail.com>
   Date: 2022
   
   This file is part of the GNUstep XCode Library

   This library is free software; you can redistribute it and/or
   modify it under the terms of the GNU Lesser General Public
   License as published by the Free Software Foundation; either
   version 2 of the License, or (at your option) any later version.
   
   This library is distributed in the hope that it will be useful,
   but WITHOUT ANY WARRANTY; without even the implied warranty of
   MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
   Lesser General Public License for more details.
   
   You should have received a copy of the GNU Lesser General Public
   License along with this library; if not, write to the Free
   Software Foundation, Inc., 51 Franklin Street, Fifth Floor,
   Boston, MA 02110 USA.
*/

#import <stdlib.h>
#import "PBXCommon.h"
#import "PBXNativeTarget.h"
#import "GSXCCommon.h"
#import "GSXCBuildContext.h"
#import "GSXCGenerator.h"
#import "NSString+PBXAdditions.h"

#ifdef _WIN32
#import "setenv.h"
#endif

@implementation PBXNativeTarget

- (void) dealloc
{
  RELEASE(productReference);
  RELEASE(productInstallPath);
  RELEASE(productType);
  RELEASE(buildRules);
  RELEASE(comments);
  RELEASE(productSettingsXML);
  
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

- (XCConfigurationList *) buildConfigurationList
{
  return xcConfigurationList;
}

- (void) setBuildConfigurationList: (XCConfigurationList *)list
{
  ASSIGN(xcConfigurationList, list);
}

- (void) _productWrapper
{
  GSXCBuildContext *context = [GSXCBuildContext sharedBuildContext];
  NSString *buildDir = [NSString stringForEnvironmentVariable: @"BUILT_PRODUCTS_DIR"
                                                 defaultValue: @"build"];
  NSString *aname = [self name];
  buildDir = [buildDir stringByAppendingPathComponent: aname];
  NSString *uninstalledProductsDir = [buildDir stringByAppendingPathComponent: @"Products"]; 
  NSString *fullPath = [[buildDir stringByAppendingPathComponent: @"Products"] 
			 stringByAppendingPathComponent: [productReference path]];

  NSError *error = nil;
  
  // Create directories...
  [[NSFileManager defaultManager] createDirectoryAtPath:uninstalledProductsDir
			    withIntermediateDirectories:YES
					     attributes:nil
						  error:&error];
  
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

      [context setObject: fullPath forKey: @"PRODUCT_OUTPUT_DIR"];
      [context setObject: execName forKey: @"PRODUCT_NAME"];
      [context setObject: execName forKey: @"EXECUTABLE_NAME"];        
    }
  else if([productType isEqualToString: FRAMEWORK_TYPE])
    {
      NSString *dir = [NSString stringForEnvironmentVariable: @"PROJECT_ROOT"
                                                defaultValue: @"./"];
      NSString *derivedSourceDir = [dir stringByAppendingPathComponent: @"derived_src"];
      NSString *execName = [[fullPath lastPathComponent] stringByDeletingPathExtension];
      NSString *derivedSourceHeaderDir = [derivedSourceDir stringByAppendingPathComponent: execName];
      NSString *frameworkVersion = [NSString stringForEnvironmentVariable: @"FRAMEWORK_VERSION"
                                                             defaultValue: @"0.0.0"];
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

      [context setObject: fullPath forKey: @"PRODUCT_OUTPUT_DIR"];
      [context setObject: execName forKey: @"PRODUCT_NAME"];
      [context setObject: execName forKey: @"EXECUTABLE_NAME"];        
    }
  else if([productType isEqualToString: LIBRARY_TYPE])
    {
      // for non-bundled packages...
      NSString *fileName = [fullPath lastPathComponent];
      NSString *path = [fullPath stringByDeletingLastPathComponent];
      NSString *dir = [NSString stringForEnvironmentVariable: @"PROJECT_ROOT"
                                                defaultValue: @"./"];      
      NSString *derivedSourceDir = [dir stringByAppendingPathComponent: @"derived_src"];
      NSString *derivedSourceHeaderDir = derivedSourceDir;
      
      setenv("PRODUCT_OUTPUT_DIR",[path cString],1);
      setenv("PRODUCT_NAME",[fileName cString],1);
      setenv("EXECUTABLE_NAME",[fileName cString],1);
      
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

      [context setObject: path forKey: @"PRODUCT_OUTPUT_DIR"];
      [context setObject: fileName forKey: @"PRODUCT_NAME"];
      [context setObject: fileName forKey: @"EXECUTABLE_NAME"];        
    }
}

- (BOOL) build
{
  BOOL result = YES;
  NSEnumerator *en = nil;
  GSXCBuildContext *context = [GSXCBuildContext sharedBuildContext];
  NSDictionary *plistFile = [NSDictionary dictionaryWithContentsOfFile:
                                            @"buildtool.plist"];
  NSArray *skippedTarget = [plistFile objectForKey:
                                        @"skippedTarget"];
  
  if ([skippedTarget containsObject: [self name]])
    {
      xcputs([[NSString stringWithFormat: @"=== Skipping Target %s%@%s", YELLOW, name, RESET] cString]);
      return YES;
    }
  
  xcputs([[NSString stringWithFormat: @"=== Building Target %s%@%s", GREEN, name, RESET] cString]);
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
  xcputs([[NSString stringWithFormat: @"=== Checking Dependencies"] cString]);  
  id dependency = nil;
  en = [dependencies objectEnumerator];
  while((dependency = [en nextObject]) != nil && result)
    {
      result = [dependency build];
    }
  xcputs([[NSString stringWithFormat: @"=== Done."] cString]);

  xcputs([[NSString stringWithFormat: @"=== Executing build phases..."] cString]);
  [self _productWrapper];
  id phase = nil;
  en = [buildPhases objectEnumerator];
  while((phase = [en nextObject]) != nil && result)
    {
      NSAutoreleasePool *p = [[NSAutoreleasePool alloc] init];

      [phase setTarget: self];
      result = [phase build];
      if(NO == result)
	{
	  xcputs([[NSString stringWithFormat: @"*** Failed build phase: %@",phase] cString]);
	}

      RELEASE(p);
    }
  xcputs([[NSString stringWithFormat: @"=== Done..."] cString]);
  xcputs([[NSString stringWithFormat: @"=== Completed Executing Target %@", name] cString]);

  return result;
}

- (BOOL) clean
{
  xcputs([[NSString stringWithFormat: @"=== Cleaning Target %@",name] cString]);
  NSString *buildDir = [NSString stringForEnvironmentVariable: @"BUILT_PRODUCTS_DIR"
                                                 defaultValue: @"build"];
  buildDir = [buildDir stringByAppendingPathComponent: [self name]];
  NSString *command = [NSString stringWithFormat: @"rm -rf \"%@\"",buildDir];

  xcputs([[NSString stringWithFormat: @"Cleaning build directory"] cString]);
  int result = xcsystem(command);

  if(result == 0)
    {
      if([[NSFileManager defaultManager] fileExistsAtPath: @"derived_src"])
	{
	  command = @"rm -rf derived_src";
	  xcputs([[NSString stringWithFormat: @"Cleaning derived_src directory"] cString]);
	  result = xcsystem(command);
	}
    }
  
  xcputs([[NSString stringWithFormat: @"=== Completed Cleaning Target %@",name] cString]);
  return (result == 0);
}

- (BOOL) install
{
  xcputs([[NSString stringWithFormat: @"=== Installing Target %@",name] cString]);
  NSString *buildDir = [NSString stringForEnvironmentVariable: @"BUILT_PRODUCTS_DIR"
                                                 defaultValue: @"build"];
  NSString *outputDir = [buildDir stringByAppendingPathComponent: [self productName]];
  NSString *uninstalledProductsDir = [outputDir stringByAppendingPathComponent: @"Products"]; 
  NSString *fullPath = [uninstalledProductsDir stringByAppendingPathComponent: [productReference path]];
  NSString *fileName = [fullPath lastPathComponent];
  NSString *execName = [fileName stringByDeletingPathExtension];
  NSFileManager *fileManager = [NSFileManager defaultManager];
  NSError *error = nil;

  if([productType isEqualToString: APPLICATION_TYPE])
    {
      NSArray *apps = NSSearchPathForDirectoriesInDomains(NSAllApplicationsDirectory, NSLocalDomainMask, YES);
      NSString *installDir = ([apps firstObject] != nil ? [apps firstObject] : @""); 
      NSString *installDest = [installDir stringByAppendingPathComponent: fileName]; 
      [fileManager copyItemAtPath: fullPath
			   toPath: installDest
			    error: &error];
    }
  else if([productType isEqualToString: FRAMEWORK_TYPE])
    {
      NSArray *paths = NSSearchPathForDirectoriesInDomains(NSLibraryDirectory, NSLocalDomainMask, YES);
      NSString *libraryPath = ([paths firstObject] != nil ? [paths firstObject] : @""); 
      NSString *frameworkPath = [libraryPath stringByAppendingPathComponent: @"Frameworks"];
      NSString *installDest = frameworkPath;
      NSString *productDir = [installDest stringByAppendingPathComponent: [productReference path]];
      NSString *headersDir = [libraryPath stringByAppendingPathComponent: @"Headers"];
      NSString *librariesDir = [libraryPath stringByAppendingPathComponent: @"Libraries"];
      NSString *frameworksLinkDir = [[[@"../Frameworks" stringByAppendingPathComponent: [productReference path]]
                                       stringByAppendingPathComponent:@"Versions"]
                                      stringByAppendingPathComponent:@"Current"];
      NSString *headersLinkDir = [[[@"../Frameworks" stringByAppendingPathComponent:
                                       [productReference path]] stringByAppendingPathComponent:@"Versions"]
                                   stringByAppendingPathComponent:@"Current"];

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
	  xcputs([[NSString stringWithFormat: @"Error creating symbolic link..."] cString]);
	}

      [fileManager removeItemAtPath: [librariesDir stringByAppendingPathComponent: 
								 [NSString stringWithFormat: @"lib%@.so",execName]]
			      error:NULL];
      flag = [fileManager createSymbolicLinkAtPath: [librariesDir stringByAppendingPathComponent: 
								 [NSString stringWithFormat: @"lib%@.so",execName]]
				       pathContent: [frameworksLinkDir stringByAppendingPathComponent: 
								    [NSString stringWithFormat: @"lib%@.so",execName]]];
      if(!flag)
	{
	  xcputs([[NSString stringWithFormat: @"Error creating symbolic link..."] cString]);
	}
    }
  else if([productType isEqualToString: LIBRARY_TYPE])
    {
      NSArray  *paths = NSSearchPathForDirectoriesInDomains(NSLibraryDirectory, NSLocalDomainMask, YES);
      NSString *libraryPath = ([paths firstObject] != nil ? [paths firstObject] : @""); 
      NSString *librariesDir = [libraryPath stringByAppendingPathComponent: @"Libraries"];
      NSString *headersDir = [libraryPath stringByAppendingPathComponent: @"Headers"];
      NSString *derivedSrcDir = @"derived_src";
      NSString *derivedSrcHeaderDir = derivedSrcDir;
      NSString *destPath = [librariesDir stringByAppendingPathComponent: [productReference path]];

      xcputs([[NSString stringWithFormat: @"\tCopy %@ -> %@",fullPath,destPath] cString]);
      [fileManager copyItemAtPath: fullPath
			   toPath: destPath
			    error: &error];
      if (error != nil)
        {
          xcputs([[NSString stringWithFormat: @"Error while copying: (%@)", error] cString]);
        }

      NSString *libName = [fullPath lastPathComponent];
      NSString *libHeaderDir = [libName stringByReplacingOccurrencesOfString: @"lib" withString: @""];
      libHeaderDir = [libHeaderDir stringByReplacingOccurrencesOfString: @".a" withString: @""];
      libHeaderDir = [libHeaderDir stringByReplacingOccurrencesOfString: @".so" withString: @""];
      NSString *libHeadersPath = [headersDir stringByAppendingPathComponent: libHeaderDir];
      [fileManager createDirectoryAtPath: libHeadersPath
             withIntermediateDirectories: NO
                              attributes: nil
                                   error: &error];
      if (error != nil)
        {
          xcputs([[NSString stringWithFormat: @"Error while creating directory %@ : (%@)",libHeadersPath, error] cString]);
        }

      NSEnumerator *en = [fileManager enumeratorAtPath: derivedSrcHeaderDir];
      id file = nil;
      while((file = [en nextObject]) != nil)
	{
          NSString *srcFile  = [libHeaderDir stringByAppendingPathComponent: file];
	  NSString *destFile = [libHeadersPath stringByAppendingPathComponent: file];
	  xcputs([[NSString stringWithFormat: @"\tCopy %@ -> %@",srcFile,destFile] cString]);
	  [fileManager copyItemAtPath: srcFile
			       toPath: destFile
				error: &error];
          if (error != nil)
            {
              xcputs([[NSString stringWithFormat: @"Error while copying: (%@)", error] cString]);
            }
	}
    }
    

  xcputs([[NSString stringWithFormat: @"=== Completed Installing Target %@",name] cString]);

  return YES;
}

- (BOOL) generate
{
  BOOL result = NO;
  NSEnumerator *en = nil;
  GSXCBuildContext *context = [GSXCBuildContext sharedBuildContext];
  
  xcputs([[NSString stringWithFormat: @"=== Generating Target: %@", name] cString]);
  [buildConfigurationList applyDefaultConfiguration];
  [context setObject: productType
	      forKey: @"PRODUCT_TYPE"];
  if(productSettingsXML != nil)
    {
      [context setObject: productSettingsXML 
                  forKey: @"PRODUCT_SETTINGS_XML"];
    }
  xcputs([[NSString stringWithFormat: @"=== Checking Dependencies"] cString]);  
  id dependency = nil;
  en = [[self dependencies] objectEnumerator];
  while((dependency = [en nextObject]) != nil && result)
    {
      result = [dependency generate];
    }
  xcputs([[NSString stringWithFormat: @"=== Done."] cString]);

  xcputs([[NSString stringWithFormat: @"=== Interpreting build phases..."] cString]);

  // [self _productWrapper];
  id phase = nil;
  en = [[self buildPhases] objectEnumerator];
  while((phase = [en nextObject]) != nil && result)
    {
      NSAutoreleasePool *p = [[NSAutoreleasePool alloc] init];
      
      [phase setTarget: self];
      result = [phase generate];
      if(NO == result)
	{
	  xcputs([[NSString stringWithFormat: @"*** Failed build phase: %@",phase] cString]);
	}

      RELEASE(p);
    }
  xcputs([[NSString stringWithFormat: @"=== Done..."] cString]);

  // Invoke generator bundle....
  NSBundle *bundle = [NSBundle bundleForClass: [self class]];
  NSString *generatorName = @"Makefile";  // default if not specified...
  NSString *bundlePath = [bundle pathForResource: generatorName
                                          ofType: @"generator"];
  NSBundle *generatorBundle = [NSBundle bundleWithPath: bundlePath];

  if (generatorBundle != nil)
    {
      NSString *className = [[generatorBundle infoDictionary] objectForKey: @"NSPrincipalClass"];

      if (className != nil)
        {
          Class cls = [generatorBundle classNamed: className];

          if (cls != nil)
            {
              GSXCGenerator *generator = [[cls alloc] initWithTarget: self];
              
              if (generator != nil)
                {
                  result = [generator generate];
                }
              else
                {
                  NSLog(@"Could not instantiate generator: %@", className);
                }
            }
          else
            {
              NSLog(@"Could not build class from string: %@", className);
            }
        }
      else
        {
          NSLog(@"NSPrincipalClass not specified in plist for bundle: %@", bundlePath);
        }
    }

  return result;
}

- (NSString *) description
{
  return [NSString stringWithFormat: @"%@-%@", [super description], [self name]];
}
@end
