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

- (NSString *) appIconSetDirectory
{
  NSString *productName = [_target name];
  NSString *assetsDir = [productName stringByAppendingPathComponent: @"Assets.xcassets"];

  return [assetsDir stringByAppendingPathComponent: @"AppIcon.appiconset"];
}

- (BOOL) parseIconSize: (NSString *)size
		 width: (double *)width
		height: (double *)height
{
  NSArray *components = [size componentsSeparatedByString: @"x"];

  if ([components count] != 2)
    {
      return NO;
    }

  *width = [[components objectAtIndex: 0] doubleValue];
  *height = [[components objectAtIndex: 1] doubleValue];

  return (*width > 0.0 && *height > 0.0);
}

- (NSString *) sanitizedIconFilename: (NSString *)filename
{
  NSString *extension = [filename pathExtension];
  NSString *baseName = [filename stringByDeletingPathExtension];
  NSCharacterSet *allowed = [NSCharacterSet characterSetWithCharactersInString:
					      @"abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789._-"];
  NSMutableString *sanitized = [NSMutableString string];
  NSUInteger i = 0;

  for (i = 0; i < [baseName length]; i++)
    {
      unichar c = [baseName characterAtIndex: i];

      if ([allowed characterIsMember: c])
	{
	  [sanitized appendFormat: @"%C", c];
	}
      else
	{
	  [sanitized appendString: @"_"];
	}
    }

  if ([sanitized length] == 0)
    {
      [sanitized appendString: @"AppIcon"];
    }

  [sanitized appendString: @"-48x48"];

  if ([extension length] > 0)
    {
      [sanitized appendString: @"."];
      [sanitized appendString: extension];
    }

  return [NSString stringWithString: sanitized];
}

- (NSString *) firstExecutablePathInArray: (NSArray *)paths
{
  NSFileManager *mgr = [NSFileManager defaultManager];
  NSEnumerator *en = [paths objectEnumerator];
  NSString *path = nil;

  while ((path = [en nextObject]) != nil)
    {
      if ([mgr isExecutableFileAtPath: path])
	{
	  return path;
	}
    }

  return nil;
}

- (NSArray *) resizeCommandForSource: (NSString *)sourcePath
			 destination: (NSString *)destPath
{
  NSString *sips = [self firstExecutablePathInArray:
			  [NSArray arrayWithObject: @"/usr/bin/sips"]];
  NSString *magick = [self firstExecutablePathInArray:
			    [NSArray arrayWithObjects: @"/opt/homebrew/bin/magick",
				   @"/usr/local/bin/magick", @"/usr/bin/magick", nil]];
  NSString *convert = [self firstExecutablePathInArray:
			     [NSArray arrayWithObjects: @"/opt/homebrew/bin/convert",
				    @"/usr/local/bin/convert", @"/usr/bin/convert", nil]];

  if (sips != nil)
    {
      return [NSArray arrayWithObjects: sips,
		      [NSArray arrayWithObjects: @"-z", @"48", @"48",
			       sourcePath, @"--out", destPath, nil],
		      nil];
    }
  else if (magick != nil)
    {
      return [NSArray arrayWithObjects: magick,
		      [NSArray arrayWithObjects: sourcePath, @"-resize",
			       @"48x48!", destPath, nil],
		      nil];
    }
  else if (convert != nil)
    {
      return [NSArray arrayWithObjects: convert,
		      [NSArray arrayWithObjects: sourcePath, @"-resize",
			       @"48x48!", destPath, nil],
		      nil];
    }

  return nil;
}

- (BOOL) resizeIconAtPath: (NSString *)sourcePath
		       toPath: (NSString *)destPath
{
  NSArray *command = [self resizeCommandForSource: sourcePath destination: destPath];
  NSTask *task = nil;
  int status = 0;

  if (command == nil)
    {
      xcputs("\t* ERROR: Could not find sips, magick, or convert to resize app icon");
      return NO;
    }

  task = [[NSTask alloc] init];
  [task setLaunchPath: [command objectAtIndex: 0]];
  [task setArguments: [command objectAtIndex: 1]];
  [task launch];
  [task waitUntilExit];
  status = [task terminationStatus];
  RELEASE(task);

  return status == 0;
}

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

  NSDebugLog(@"bs = %@", bs);

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

- (NSString *) discoverAppIcon
{
  NSString *filename = nil;
  NSString *appIconDir = [self appIconSetDirectory];
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
      double bestArea = 0.0;

      while ((imageDict = [en nextObject]) != nil)
	{
	  NSString *size = [imageDict objectForKey: @"size"];
	  NSString *scale = [imageDict objectForKey: @"scale"];
	  NSString *candidate = [imageDict objectForKey: @"filename"];
	  double width = 0.0;
	  double height = 0.0;
	  double scaleValue = 1.0;
	  double area = 0.0;

	  if (![candidate isKindOfClass: [NSString class]] ||
	      ![size isKindOfClass: [NSString class]])
	    {
	      continue;
	    }

	  if ([scale isKindOfClass: [NSString class]])
	    {
	      scaleValue = [scale doubleValue];
	      if (scaleValue <= 0.0)
		{
		  scaleValue = 1.0;
		}
	    }

	  if ([self parseIconSize: size width: &width height: &height])
	    {
	      width *= scaleValue;
	      height *= scaleValue;
	      area = width * height;

	      if (area > bestArea)
		{
		  filename = candidate;
		  bestArea = area;
		}
	    }
	}
    }

  return filename;
}

- (NSString *) discoverAppIconPath
{
  NSString *filename = [self discoverAppIcon];
  if (filename != nil)
    {
      NSString *appIconDir = [self appIconSetDirectory];
      return [appIconDir stringByAppendingPathComponent: filename];
    }
  return nil;
}

// Helper method to escape filenames for makefile compatibility
- (NSString *) escapeFilenameForMakefile: (NSString *)filename
{
  if (filename == nil)
    {
      return nil;
    }

  // Escape spaces and other special characters for makefile usage
  NSMutableString *escaped = [NSMutableString stringWithString: filename];
  
  // Replace spaces with escaped spaces
  [escaped replaceOccurrencesOfString: @" " 
                           withString: @"\\ " 
                              options: 0 
                                range: NSMakeRange(0, [escaped length])];
  
  // Escape other special makefile characters
  [escaped replaceOccurrencesOfString: @"$" 
                           withString: @"$$" 
                              options: 0 
                                range: NSMakeRange(0, [escaped length])];
  
  [escaped replaceOccurrencesOfString: @"#" 
                           withString: @"\\#" 
                              options: 0 
                                range: NSMakeRange(0, [escaped length])];
  
  [escaped replaceOccurrencesOfString: @":" 
                           withString: @"\\:" 
                              options: 0 
                                range: NSMakeRange(0, [escaped length])];
  
  return [NSString stringWithString: escaped];
}

- (BOOL) copyAppIconToResources: (NSString *)iconFilename
{
  if (iconFilename == nil)
    {
      return NO;
    }

  NSFileManager *mgr = [NSFileManager defaultManager];
  NSString *appIconDir = [self appIconSetDirectory];
  
  // Copy icons to resource dir...
  GSXCBuildContext *context = [GSXCBuildContext sharedBuildContext];
  NSString *productOutputDir = [context objectForKey: @"PRODUCT_OUTPUT_DIR"];
  if (productOutputDir == nil)
    {
      xcputs("\t* ERROR: Cannot copy app icon, PRODUCT_OUTPUT_DIR is not set");
      return NO;
    }

  NSString *resourcesDir = [productOutputDir stringByAppendingPathComponent: @"Resources"];
  NSString *imagePath = [appIconDir stringByAppendingPathComponent: iconFilename];
  NSString *resourceFilename = [self sanitizedIconFilename: iconFilename];
  NSString *destPath = [resourcesDir stringByAppendingPathComponent: resourceFilename];

  // Debug output for paths
  xcputs([[NSString stringWithFormat: @"\t* Icon filename: '%@'", iconFilename] cString]);
  xcputs([[NSString stringWithFormat: @"\t* Resource icon filename: '%@'", resourceFilename] cString]);
  xcputs([[NSString stringWithFormat: @"\t* Source path: '%@'", imagePath] cString]);
  if (destPath != NULL && destPath != nil)
    {
      xcputs([[NSString stringWithFormat: @"\t* Dest path: '%@'", destPath] cString]);
    }

  // Check if source file exists
  if (![mgr fileExistsAtPath: imagePath])
    {
      xcputs([[NSString stringWithFormat: @"\t* ERROR: Source icon file does not exist: %@", imagePath] cString]);
      return NO;
    }

  // Ensure resources directory exists
  NSError *error = nil;
  if (![mgr fileExistsAtPath: resourcesDir])
    {
      BOOL created = [mgr createDirectoryAtPath: resourcesDir
			    withIntermediateDirectories: YES
					     attributes: nil
						  error: &error];
      if (!created)
        {
          xcputs([[NSString stringWithFormat: @"\t* ERROR: Could not create resources directory: %@", [error localizedDescription]] cString]);
          return NO;
        }
    }

  // Remove existing file if it exists
  if ([mgr fileExistsAtPath: destPath])
    {
      [mgr removeItemAtPath: destPath error: NULL];
    }

  // Resize the icon file
  BOOL success = NO;
  if (destPath != NULL && destPath != nil)
    {
      success = [self resizeIconAtPath: imagePath toPath: destPath];
  
      if (!success)
	{
	  xcputs([[NSString stringWithFormat: @"\t* ERROR: Failed to resize icon file: %@", error ? [error localizedDescription] : @"Unknown error"] cString]);
	}
    }
  else
    {
      success = YES;
      xcputs("\t* WARN: Not copying icon file, no destination provided");
    }

  return success;
}

- (NSString *) processAssets
{
  NSString *filename = [self discoverAppIcon];
  if ([self copyAppIconToResources: filename])
    {
      return [self sanitizedIconFilename: filename];
    }

  return nil;
}

- (BOOL) processInfoPlistInput: (NSString *)inputFileName
			output: (NSString *)outputFileName
		  withIconFile: (NSString *)iconFileName
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

	  if (iconFileName != nil)
	    {
	      [plistDict setObject: iconFileName forKey: @"NSIcon"];
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

// Backward compatibility method
- (BOOL) processInfoPlistInput: (NSString *)inputFileName
			output: (NSString *)outputFileName
{
  NSString *iconFile = [self processAssets];
  return [self processInfoPlistInput: inputFileName
			      output: outputFileName
			withIconFile: iconFile];
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

- (NSMutableDictionary *) configToInfoPlist: (XCBuildConfiguration *)config withIconFile: (NSString *)iconFile
{
  NSMutableDictionary *ipd = [NSMutableDictionary dictionary];
  NSDictionary *buildSettings = [config buildSettings];
  NSString *version = [buildSettings objectForKey: @"CURRENT_PROJECT_VERSION"];
  NSString *copyright = [buildSettings objectForKey: @"INFOPLIST_KEY_NSHumanReadableCopyright"];
  NSString *mainNib = [buildSettings objectForKey: @"INFOPLIST_KEY_NSMainNibFile"];
  NSString *principalClass = [buildSettings objectForKey: @"INFOPLIST_KEY_NSPrincipalClass"];
  NSString *bundleIdentifier = [buildSettings objectForKey: @"PRODUCT_BUNDLE_IDENTIFIER"];

  if (version != nil)
    {
      [ipd setObject: version forKey: @"CFBundleVersion"];
    }

  if (mainNib != nil)
    {
      [ipd setObject: mainNib forKey: @"NSMainNibFile"];
    }

  if (copyright != nil)
    {
      [ipd setObject: copyright forKey: @"NSHumanReadableCopyright"];
    }

  if (principalClass != nil)
    {
      [ipd setObject: principalClass forKey: @"NSPrincipalClass"];
    }

  if (iconFile != nil)
    {
      [ipd setObject: iconFile forKey: @"NSIcon"];
    }

  [ipd setObject: @"$(DEVELOPMENT_LANGUAGE)" forKey: @"CFBundleDevelopmentRegion"];
  [ipd setObject: @"$(EXECUTABLE_NAME)" forKey: @"CFBundlExecutable"];

  if (bundleIdentifier != nil)
    {
      [ipd setObject: bundleIdentifier forKey: @"CFBundleIdentifier"];
    }

  return ipd;
}

- (NSString *) generateInfoPlistOutput: (NSString *)outputPlist withIconFile: (NSString *)iconFile
{
  GSXCBuildContext *context = [GSXCBuildContext sharedBuildContext];
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
			   output: outputPlist
		     withIconFile: iconFile];
    }
  else
    {
      xcputs([[NSString stringWithFormat: @"\t* Generating info plist --> %s%@%s", GREEN, outputPlist, RESET] cString]);
      XCBuildConfiguration *config = [xcl configurationWithName: @"Debug"];
      NSMutableDictionary *ipl = [self configToInfoPlist: config withIconFile: iconFile];
      pl = [ipl description];
    }

  return pl;
}

// Backward compatibility method
- (NSString *) generateInfoPlistOutput: (NSString *)outputPlist
{
  NSString *iconFile = [self processAssets];
  return [self generateInfoPlistOutput: outputPlist withIconFile: iconFile];
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
  // Discover, resize, and copy app icon first.
  NSString *iconFile = [self processAssets];
  
  // Generate Info.plist with the discovered icon
  NSString *pl = [self generateInfoPlistOutput: outputPlist withIconFile: iconFile];
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

	      NSString *escapedFilePath = [self escapeFilenameForMakefile: filePath];
	      xcputs([[NSString stringWithFormat: @"\tAdd child resource entry %@", filePath] cString]);
	      [resources addObject: escapedFilePath];
	    }
	  continue;
	}

      NSString *filePath = [file path];
      if ([mgr fileExistsAtPath: [file path]] == NO)
	{
	  filePath = [productName stringByAppendingPathComponent: [file path]];
	}

      NSString *escapedFilePath = [self escapeFilenameForMakefile: filePath];
      xcputs([[NSString stringWithFormat: @"\tAdd resource entry %@",filePath] cString]);

      [resources addObject: escapedFilePath];
    }

  // Discover app icon separately from Info.plist generation
  NSString *sourceIconFile = [self discoverAppIcon];
  NSString *iconPath = [self discoverAppIconPath];
  NSString *iconFile = nil;
  xcputs([[NSString stringWithFormat: @"\t* Discovered app icon: %@", sourceIconFile ? sourceIconFile : @"(none)"] cString]);

  // Add icon file to resources if found
  if (iconPath != nil)
    {
      xcputs([[NSString stringWithFormat: @"\t* Adding app icon to resources: %@", iconPath] cString]);

      iconFile = [self sanitizedIconFilename: sourceIconFile];
      if ([mgr fileExistsAtPath: iconFile])
	{
	  [mgr removeItemAtPath: iconFile error: NULL];
	}

      // Generate a local resized icon for the generated makefile resources.
      BOOL iconCopied = [self resizeIconAtPath: iconPath toPath: iconFile];
      if (iconCopied)
        {
	  NSString *escapedIconFile = nil;

	  escapedIconFile = [self escapeFilenameForMakefile: iconFile];
	  [resources addObject: escapedIconFile];
          xcputs([[NSString stringWithFormat: @"\t* Generated app icon resource: %@", iconFile] cString]);
        }
      else
        {
	  iconFile = nil;
          xcputs([[NSString stringWithFormat: @"\t* Failed to generate app icon resource: %@", sourceIconFile] cString]);
        }
    }

  // Generate Info.plist with the discovered icon
  NSString *outputPlist = [NSString stringWithFormat: @"%@Info.plist",appName] ;
  NSString *pl = [self generateInfoPlistOutput: outputPlist withIconFile: iconFile];
  BOOL f = [pl writeToFile: outputPlist atomically: YES];
  if (f == NO)
    {
      NSLog(@"ERROR: Issue writing out plist file");
    }
  

  NSString *escapedOutputPlist = [self escapeFilenameForMakefile: outputPlist];
  [resources addObject: escapedOutputPlist];

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
