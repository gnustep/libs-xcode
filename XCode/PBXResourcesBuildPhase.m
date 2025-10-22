/*
   Copyright (C) 2018, 2019, 2020, 2021 Free Software Foundation, Inc.

   Written by: Gregory John Casamento <greg.casamento@gmail.com>
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

#import <Foundation/NSJSONSerialization.h>

#import "PBXCommon.h"
#import "PBXGroup.h"
#import "PBXResourcesBuildPhase.h"
#import "PBXFileReference.h"
#import "PBXBuildFile.h"
#import "PBXVariantGroup.h"
#import "NSString+PBXAdditions.h"
#import "GSXCBuildContext.h"
#import "XCBuildConfiguration.h"
#import "XCConfigurationList.h"

@implementation PBXResourcesBuildPhase

- (instancetype) init
{
  self = [super init];
  if (self != nil)
    {
      NSArray *objs = nil;
      objs = [[[GSXCBuildContext sharedBuildContext]
		objectForKey: @"objects"]
	       allValues];

      [self setFiles: [objs mutableCopy]];
    }
  return self;
}

- (NSString *) productName
{
  GSXCBuildContext *context = [GSXCBuildContext sharedBuildContext];
  NSDictionary *ctx = [context currentContext];
  XCConfigurationList *xcl = [ctx objectForKey: @"buildConfig"];
  XCBuildConfiguration *xbc = [xcl defaultConfiguration];
  NSDictionary *bs = [xbc buildSettings];
  NSString *productName = [bs objectForKey: @"PRODUCT_NAME"];

  // NSProcessInfo *info = [NSProcessInfo processInfo];
  // NSDictionary *env = [info environment];
  NSDebugLog(@"bs = %@", bs);

  // This is kind of a kludge, but better than what was here before.
  // I believe that when the context has the variable name it means to use
  // the product name from the target.
  if ([productName isEqualToString: @"$(TARGET_NAME)"])
    {
      productName = [_target productName];
      NSDebugLog(@"* 2nd try %@", productName);
      if ([productName isEqualToString: @"$(TARGET_NAME)"])
	{
	  productName = [_target name];
	  NSDebugLog(@"* 3rd try %@", productName);
	}
    }

  return productName;
}

- (NSString *) processAssets
{
  NSFileManager *mgr = [NSFileManager defaultManager];
  NSString *filename = nil;
  NSString *productName = [_target name]; // [self productName];
  NSString *assetsDir = [productName stringByAppendingPathComponent: @"Assets.xcassets"];
  NSString *appIconDir = [assetsDir stringByAppendingPathComponent: @"AppIcon.appiconset"];
  NSString *contentsJson = [appIconDir stringByAppendingPathComponent: @"Contents.json"];
  NSData *data = [NSData dataWithContentsOfFile: contentsJson];

  if (data != nil)
    {
      NSDictionary *dict = [NSJSONSerialization JSONObjectWithData: data
							   options: 0L
							     error: NULL];
      NSArray *imagesArray = [dict objectForKey: @"images"];
      NSDictionary *imageDict = nil;
      NSEnumerator *en = [imagesArray objectEnumerator];

      while ((imageDict = [en nextObject]) != nil)
	{
	  NSString *size = [imageDict objectForKey: @"size"];
	  NSString *scale = [imageDict objectForKey: @"scale"];

	  if ([size isEqualToString: @"32x32"] &&
	      [scale isEqualToString: @"1x"])
	    {
	      filename = [imageDict objectForKey: @"filename"];
	      break;
	    }
	}

      // Copy icons to resource dir...
      GSXCBuildContext *context = [GSXCBuildContext sharedBuildContext];
      NSString *productOutputDir = [context objectForKey: @"PRODUCT_OUTPUT_DIR"];
      NSString *resourcesDir = [productOutputDir stringByAppendingPathComponent: @"Resources"];
      NSString *imagePath = [appIconDir stringByAppendingPathComponent: filename];
      NSString *destPath = [resourcesDir stringByAppendingPathComponent: filename];

      // Copy the item, remove it first to make sure there is no issue.
      //[mgr removeItemAtPath: destPath
      //	      error: NULL];

      [mgr copyItemAtPath: imagePath
		   toPath: destPath
		    error: NULL];
    }

  return filename;
}

- (BOOL) processInfoPlistInput: (NSString *)inputFileName
			output: (NSString *)outputFileName
{
  if (inputFileName != nil)
    {
      GSXCBuildContext *context = [GSXCBuildContext sharedBuildContext];
      NSString *settings = [context objectForKey: @"PRODUCT_SETTINGS_XML"];
      if(settings == nil)
	{
	  NSString *inputFileString = [NSString stringWithContentsOfFile: inputFileName];
	  NSString *outputFileString = [inputFileString stringByReplacingEnvironmentVariablesWithValues];
	  NSMutableDictionary *plistDict = [NSMutableDictionary dictionaryWithDictionary: [outputFileString propertyList]];
	  NSString *filename = [self processAssets];

	  if (filename != nil)
	    {
	      [plistDict setObject: filename forKey: @"NSIcon"];
	    }

	  [plistDict writeToFile: outputFileName
		      atomically: YES];

	  NSDebugLog(@"%@", plistDict);
	}
      else
	{
	  [settings writeToFile: outputFileName
		     atomically: YES
		       encoding: NSUTF8StringEncoding
			  error: NULL];
	}
    }
  else
    {
      NSArray *keys = [NSArray arrayWithObjects: @"NSPrincipalClass", @"NSMainNibFile", nil];
      NSArray *objs = [NSArray arrayWithObjects: @"NSApplication", @"MainMenu", nil];
      NSDictionary *ipl = [NSDictionary dictionaryWithObjects: objs
						      forKeys: keys];
      [ipl writeToFile: outputFileName
	    atomically: YES];
    }

  return YES;
}

- (BOOL) copyResourceFrom: (NSString *)srcPath to: (NSString *)dstPath
{
  BOOL result = NO;
  NSFileManager *mgr = [NSFileManager defaultManager];
  NSError *error = nil;

  NSDebugLog(@"\t* Copy child %@  -> %@",srcPath,dstPath);

  // Copy the item
  result = [mgr copyItemAtPath: srcPath
			toPath: dstPath
			 error: &error];
  if (error != nil)
    {
      xcputs([[NSString stringWithFormat: @"\t* Updating resource \"%s%@%s\" --> \"%s%@%s\"", CYAN, srcPath, RESET, GREEN, dstPath, RESET] cString]);
      [mgr removeItemAtPath: dstPath
		      error: NULL];

      result = [mgr copyItemAtPath: srcPath
			    toPath: dstPath
			     error: &error];
    }
  else
    {
      xcputs([[NSString stringWithFormat: @"\t* Copy resource \"%s%@%s\" --> \"%s%@%s\"", CYAN, srcPath, RESET, GREEN, dstPath, RESET] cString]);
    }
  return result;
}

- (NSMutableDictionary *) configToInfoPlist: (XCBuildConfiguration *)config
{
  NSMutableDictionary *ipd = [NSMutableDictionary dictionary];
  NSDictionary *buildSettings = [config buildSettings];
  // NSString *appIcon = [buildSettings objectForKey: @"ASSETCATALOG_COMPILER_APPICON_NAME"];
  NSString *version = [buildSettings objectForKey: @"CURRENT_PROJECT_VERSION"];
  NSString *copyright = [buildSettings objectForKey: @"INFOPLIST_KEY_NSHumanReadableCopyright"];
  NSString *mainNib = [buildSettings objectForKey: @"INFOPLIST_KEY_NSMainNibFile"];
  NSString *principalClass = [buildSettings objectForKey: @"INFOPLIST_KEY_NSPrincipalClass"];
  NSString *bundleIdentifier = [buildSettings objectForKey: @"PRODUCT_BUNDLE_IDENTIFIER"];
  NSString *iconFile = [self processAssets];

  [ipd setObject: version forKey: @"CFBundleVersion"];
  [ipd setObject: mainNib forKey: @"NSMainNibFile"];
  [ipd setObject: copyright forKey: @"NSHumanReadableCopyright"];
  [ipd setObject: principalClass forKey: @"NSPrincipalClass"];
  [ipd setObject: iconFile forKey: @"NSIcon"];
  [ipd setObject: @"$(DEVELOPMENT_LANGUAGE)" forKey: @"CFBundleDevelopmentRegion"];
  [ipd setObject: @"$(EXECUTABLE_NAME)" forKey: @"CFBundlExecutable"];
  [ipd setObject: bundleIdentifier forKey: @"CFBundleIdentifier"];

  return ipd;
}

- (NSString *) generateInfoPlistOutput: (NSString *)outputPlist
{
  GSXCBuildContext *context = [GSXCBuildContext sharedBuildContext];
  // NSString *productOutputDir = [context objectForKey: @"PRODUCT_OUTPUT_DIR"];
  NSDictionary *ctx = [context currentContext];
  XCConfigurationList *xcl = [ctx objectForKey: @"buildConfig"];
  XCBuildConfiguration *xbc = [xcl defaultConfiguration];
  NSDictionary *bs = [xbc buildSettings];
  NSString *infoPlist = [bs objectForKey: @"INFOPLIST_FILE"];
  NSFileManager *mgr = [NSFileManager defaultManager];
  NSString *pl = nil;
  
  if (infoPlist != nil)
    {
      if ([mgr fileExistsAtPath: infoPlist] == NO)
	{
	  infoPlist = [infoPlist lastPathComponent];
	}

      [self processInfoPlistInput: infoPlist
			   output: outputPlist];
    }
  else
    {
      xcputs([[NSString stringWithFormat: @"\t* Generating info plist --> %s%@%s", GREEN, outputPlist, RESET] cString]);
      XCBuildConfiguration *config = [xcl configurationWithName: @"Debug"];
      NSMutableDictionary *ipl = [self configToInfoPlist: config];
      pl = [ipl description];
    }

  return pl;
}

- (BOOL) build
{
  NSFileManager *mgr = [NSFileManager defaultManager];
  GSXCBuildContext *context = [GSXCBuildContext sharedBuildContext];
  NSString *productOutputDir = [context objectForKey: @"PRODUCT_OUTPUT_DIR"];
  NSString *resourcesDir = [productOutputDir stringByAppendingPathComponent: @"Resources"];
  NSString *outputPlist = [resourcesDir stringByAppendingPathComponent: @"Info-gnustep.plist"];
  NSError *error = nil;
  NSString *productName = [self productName];

  NSDebugLog(@"productName = %@", productName);
  xcputs("=== Executing Resources Build Phase");

  // Pre create directory....
  [mgr createDirectoryAtPath:resourcesDir
       withIntermediateDirectories:YES
		  attributes:nil
		       error:&error];

  // Copy all resources...
  NSArray *files = [self allFiles];
  NSEnumerator *en = [files objectEnumerator];
  BOOL result = YES;
  id file = nil;
  while((file = [en nextObject]) != nil && result)
    {
      id fileRef = [file fileRef];

      if ([fileRef isKindOfClass: [PBXVariantGroup class]])
	{
	  NSArray *children = [fileRef children];
	  NSEnumerator *e = [children objectEnumerator];
	  id child = nil;
	  while ((child = [e nextObject]) != nil)
	    {
	      NSString *filePath = [child path];
	      NSDebugLog(@"FILEPATH = %@", filePath);
	      NSString *resourceFilePath = [filePath stringByDeletingLastPathComponent];
	      BOOL edited = NO;
	      if ([mgr fileExistsAtPath: [child path]] == NO)
		{
		  edited = YES;
		  filePath = [productName stringByAppendingPathComponent: [child path]];
		  if ([mgr fileExistsAtPath: filePath] == NO)
		    {
		      filePath = [child buildPath];
		    }
		}

	      NSString *fileDir = [resourcesDir stringByAppendingPathComponent:
						  resourceFilePath];
	      NSString *fileName = [filePath lastPathComponent];
	      NSString *destPath = [resourcesDir stringByAppendingPathComponent: fileName];
	      NSError *error = nil;
	      BOOL copyResult = NO;

	      // If there is more than one path component...
	      // then the intervening directories need to
	      // be created.
	      if([[filePath pathComponents] count] > 1)
		{
		  NSString *dirs = [filePath stringByDeletingLastPathComponent];
		  if (edited)
		    {
		      dirs = [dirs stringByReplacingOccurrencesOfString: productName withString: @""];
		    }
		  destPath = [resourcesDir stringByAppendingPathComponent: dirs];
		  destPath = [destPath stringByAppendingPathComponent: fileName];
		}

	      NSDebugLog(@"\tCreate %@",fileDir);
	      copyResult = [mgr createDirectoryAtPath: fileDir
				withIntermediateDirectories: YES
					   attributes: nil
						error: &error];
	      if (copyResult == NO)
		{
		  NSLog(@"\tFILE CREATION ERROR:  %@, %@", error, fileDir);
		}

	      // kludge since Base/en etc is not supported yet.
	      destPath = [destPath stringByReplacingOccurrencesOfString: @"Base.lproj/"
							     withString: @""];

	      destPath = [destPath stringByReplacingOccurrencesOfString: @"en.lproj/"
							     withString: @""];

	      copyResult = [self copyResourceFrom: filePath to: destPath];
	      if (copyResult == NO)
		{
		  NSLog(@"\tFILE COPY ERROR:  %@", destPath);
		}
	    }
	  continue;
	}

      NSString *filePath = [file path];
      if ([mgr fileExistsAtPath: [file path]] == NO)
	{
	  filePath = [file buildPath];
	  if ([mgr fileExistsAtPath: filePath] == NO)
	    {
	      filePath = [productName stringByAppendingPathComponent: [file path]];
	    }
	}

      NSString *fileName = [filePath lastPathComponent];
      NSString *destPath = [resourcesDir stringByAppendingPathComponent: fileName];
      BOOL copyResult = NO;
      NSDebugLog(@"\tXXXX Copy %@ -> %@",filePath,destPath);

      copyResult = [self copyResourceFrom: filePath to: destPath];
      if (!copyResult)
	{
	  NSLog(@"File not copied: %@ -> %@", filePath, destPath);
	}
    }

  // Handle Info.plist....
  NSString *pl = [self generateInfoPlistOutput: outputPlist];
  BOOL f = [pl writeToFile: outputPlist atomically: YES];
  if (f == NO)
    {
      NSLog(@"ERROR: Issue writing out plist file");
    }
  
  xcputs("=== Resources Build Phase Completed");
  fflush(stdout);

  return result;
}

- (NSArray *) allFiles
{
  NSArray *synchronizedFiles = [_target synchronizedResources];
  NSArray *files = [_files arrayByAddingObjectsFromArray: synchronizedFiles];
  return files;
}

- (BOOL) generate
{
  GSXCBuildContext *context = [GSXCBuildContext sharedBuildContext];

  // Use the new allFiles method to include files from groups
  NSArray *allFiles = [self allFiles];
  NSMutableArray *resources = [NSMutableArray arrayWithCapacity: [allFiles count]];

  xcputs("=== Generating Resources Entries Build Phase");
  NSFileManager *mgr = [NSFileManager defaultManager];
  NSString *productName = [_target productName];
  NSString *appName = [productName stringByDeletingPathExtension];

  // Copy all resources...
  NSEnumerator *en = [allFiles objectEnumerator];
  BOOL result = YES;
  id file = nil;
  while((file = [en nextObject]) != nil && result)
    {
      id fileRef = [file fileRef];

      // Skip source code files - they should not be treated as resources
      if ([file respondsToSelector: @selector(fileRef)])
	{
	  PBXFileReference *fr = [file fileRef];
	  if (fr != nil && [fr respondsToSelector: @selector(path)])
	    {
	      NSString *path = [fr path];
	      NSString *ext = [[path pathExtension] lowercaseString];

	      // Skip common source code file extensions
	      if ([ext isEqualToString: @"m"] ||
		  [ext isEqualToString: @"mm"] ||
		  [ext isEqualToString: @"c"] ||
		  [ext isEqualToString: @"cc"] ||
		  [ext isEqualToString: @"cpp"] ||
		  [ext isEqualToString: @"cxx"] ||
		  [ext isEqualToString: @"swift"])
		{
		  // Skip this source file
		  xcputs([[NSString stringWithFormat: @"\tSkipping source file: %@", path] cString]);
		  continue;
		}
	    }
	}

      if ([fileRef isKindOfClass: [PBXVariantGroup class]])
	{
	  NSArray *children = [fileRef children];
	  NSEnumerator *e = [children objectEnumerator];
	  id child = nil;
	  while ((child = [e nextObject]) != nil)
	    {
	      NSString *filePath = [child path];

	      if ([mgr fileExistsAtPath: [child path]] == NO)
		{
		  filePath = [productName stringByAppendingPathComponent: [child path]];
		}

	      xcputs([[NSString stringWithFormat: @"\tAdd child resource entry %@", filePath] cString]);
	      [resources addObject: filePath];
	    }
	  continue;
	}

      NSString *filePath = [file path];
      if ([mgr fileExistsAtPath: [file path]] == NO)
	{
	  filePath = [productName stringByAppendingPathComponent: [file path]];
	}

      xcputs([[NSString stringWithFormat: @"\tAdd resource entry %@",filePath] cString]);

      [resources addObject: filePath];
    }

  // Handle Info.plist...
  /*
  NSDictionary *ctx = [context currentContext];
  XCConfigurationList *xcl = [ctx objectForKey: @"buildConfig"];
  XCBuildConfiguration *xbc = [xcl defaultConfiguration];
  NSDictionary *bs = [xbc buildSettings];
  NSString *inputPlist = [bs objectForKey: @"INFOPLIST_FILE"];
  if ([mgr fileExistsAtPath: inputPlist] == NO)
    {
      inputPlist = [inputPlist lastPathComponent];
    }
  */

  NSString *outputPlist = [NSString stringWithFormat: @"%@Info.plist",appName] ;
  //[self processInfoPlistInput: inputPlist
  //		       output: outputPlist];
  NSString *pl = [self generateInfoPlistOutput: outputPlist];
  BOOL f = [pl writeToFile: outputPlist atomically: YES];
  if (f == NO)
    {
      NSLog(@"ERROR: Issue writing out plist file");
    }
  

  // Move Base.lproj to English.lproj until Base.lproj is supported..
  // NSString *baseLproj =  @"Base.lproj/*";
  // NSString *engLproj =  @"English.lproj";
  // [resources addObject: engLproj];
  [resources addObject: outputPlist];

  [context setObject: resources forKey: @"RESOURCES"];
  xcputs("=== Resources Build Phase Completed (generate)");

  return result;
}

// Override filesFromGroups for resources - exclude source code files
- (NSArray *) filesFromGroups
{
  // For now, return empty array since resources are typically explicitly
  // added to the resources build phase, not automatically discovered from
  // synchronized groups. Synchronized groups are primarily for source files.
  //
  // If we need to support resource files from synchronized groups in the future,
  // we would need to filter them to exclude source code files here as well.
  return [NSArray array];
}

- (BOOL) link
{
  return [self build];
}

@end
