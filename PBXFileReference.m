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

- (void) dealloc
{
  RELEASE(_sourceTree);
  RELEASE(_lastKnownFileType);
  RELEASE(_path);
  RELEASE(_fileEncoding);
  RELEASE(_explicitFileType);
  RELEASE(_usesTabs);
  RELEASE(_indentWidth);
  RELEASE(_tabWidth);
  RELEASE(_name);
  RELEASE(_includeInIndex);
  RELEASE(_comments);
  RELEASE(_plistStructureDefinitionIdentifier);
  RELEASE(_xcLanguageSpecificationIdentifier);
  RELEASE(_lineEnding);
  RELEASE(_wrapsLines);

  [super dealloc];
}

- (void) setTotalFiles: (NSUInteger)t
{
  _totalFiles = t;
}

- (void) setCurrentFile: (NSUInteger)n
{
  _currentFile = n;
}


// Methods....
- (void) setWrapsLines: (NSString *)o
{
  ASSIGN(_wrapsLines, o);
}

- (NSString *) sourceTree // getter
{
  return _sourceTree;
}

- (void) setSourceTree: (NSString *)object; // setter
{
  ASSIGN(_sourceTree,object);
}

- (NSString *) lastKnownFileType // getter
{
  return _lastKnownFileType;
}

- (void) setLastKnownFileType: (NSString *)object; // setter
{
  ASSIGN(_lastKnownFileType,object);
}

- (NSString *) path // getter
{
  return _path;
}

- (void) setPath: (NSString *)object; // setter
{
  ASSIGN(_path,object);
}

- (NSString *) fileEncoding // getter
{
  return _fileEncoding;
}

- (void) setFileEncoding: (NSString *)object; // setter
{
  ASSIGN(_fileEncoding,object);
}

- (NSString *) explicitFileType
{
  return _explicitFileType;
}

- (void) setExplicitFileType: (NSString *)object
{
  ASSIGN(_explicitFileType,object);
}

- (NSString *) name;
{
  return _name;
}

- (void) setName: (NSString *)object
{
  ASSIGN(_name,object);
}

- (NSString *) plistStructureDefinitionIdentifier
{
  return _plistStructureDefinitionIdentifier;
}

- (void) setPlistStructureDefinitionIdentifier: (NSString *)object
{
  ASSIGN(_plistStructureDefinitionIdentifier,object);
}

- (NSString *) xcLanguageSpecificationIdentifier
{
  return _xcLanguageSpecificationIdentifier;
}

- (void) setXcLanguageSpecificationIdentifier: (NSString *)object
{
  ASSIGN(_xcLanguageSpecificationIdentifier, object);
}

- (NSString *) lineEnding
{
  return _lineEnding;
}

- (void) setLineEnding: (NSString *)object
{
  ASSIGN(_lineEnding,object);
}

- (void) setTarget: (PBXNativeTarget *)t
{
  _target = t;
}

- (NSString *) _resolvePathFor: (id)object 
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
                                      [self _resolvePathFor: object 
                                                  withGroup: file
                                                      found: found]];
	}
    }
  return result;
}

- (NSArray *) _allSubdirsAtPath: (NSString *)apath
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
              dirToAdd = @".";
            }

          if ([[filename pathComponents] count] > 2)
            {
              continue;
            }
         
           if ([[filename pathExtension] isEqualToString: @"h"])
            {
              NSDebugLog(@"filename = %@", filename);
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
      
      if ([results containsObject: dirToAdd] == NO) // [dirToAdd stringByAddingQuotationMarks]] == NO)
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

          if ([dirToAdd isEqualToString: @""] == NO)
            {
              [results addObject: dirToAdd]; // [dirToAdd stringByAddingQuotationMarks]];
              NSDebugLog(@"adding dirToAdd = %@", dirToAdd);
            }
        }
    }

  // For some reason repeating the first -I directive helps resolve some issues with
  // finding headers.
  id o = [results count] > 1 ? [results objectAtIndex: 1] : @".";
  o = [o isEqualToString: @""] ? @"." : o;
  
  [results addObject: o];
  results = [[results arrayByRemovingDuplicateEntries] mutableCopy];
  
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
  GSXCBuildContext *context = [GSXCBuildContext sharedBuildContext];
  PBXGroup *mainGroup = [context objectForKey: @"MAIN_GROUP"];
  BOOL found = NO;
  NSString *result = nil, *r = nil;
  NSDictionary *plistFile = [context config];
  NSDictionary *remappedSource = [plistFile objectForKey: @"remappedSource"];
 
  // Resolve path for the current file reference...
  result = [self _resolvePathFor: self 
                       withGroup: mainGroup
                           found: &found];

  if ((r = [remappedSource objectForKey: result]) != nil)
    {
      xcputs([[NSString stringWithFormat: @"\n\t%@ remapped to -> %@", result, r] cString]);
      result = r;
    }
  
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
  NSDictionary *plistFile = [context config];
  NSArray *headerPaths = [plistFile objectForKey: @"headerPaths"];

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
      [allHeaders prependObjectsFromArray: headerPaths];
    }
  
  // get environment variables...
  char **env = NULL;
  for (env = environ; *env != 0; env++)
    {
      char *thisEnv = *env;
      NSString *envStr = [NSString stringWithCString: thisEnv
                                            encoding: NSUTF8StringEncoding];
      NSArray *components = [envStr componentsSeparatedByString: @"="];
      
      [dict setObject: [[components lastObject] stringByTrimmingCharactersInSet: [NSCharacterSet whitespaceCharacterSet]]
               forKey: [[components firstObject] stringByTrimmingCharactersInSet: [NSCharacterSet whitespaceCharacterSet]]];
    }
  
  // Get project root
  NSString *projDir = [NSString stringForEnvironmentVariable: @"PROJECT_ROOT"
                                                defaultValue: @"."];
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
      NSString *q = [o stringByReplacingEnvironmentVariablesWithValues];
      if ([result containsObject: o] == NO)
        {
          [result addObject: o];
          [result addObject: q];
        }
    }

  return result;
}

- (NSArray *) _addParentPath: (NSString *)parent toPaths: (NSArray *)paths
{
  NSMutableArray *result = [NSMutableArray arrayWithCapacity: [paths count]];
  NSEnumerator *en = [paths objectEnumerator];
  NSString *p = nil;

  [result addObject: parent];
  while((p = [en nextObject]) != nil)
    {
      NSString *newPath = [parent stringByAppendingPathComponent: p];
      [result addObject: newPath];
    }

  return result;
}

- (NSString *) _headerStringForPath: (NSString *)apath
{
  BOOL isDir;
  NSFileManager *manager = [NSFileManager defaultManager];
  NSArray *result = [NSArray array];

  [manager fileExistsAtPath:apath isDirectory:&isDir];
  if (isDir)
    {
      result = [self _allSubdirsAtPath: apath];
      result = [result arrayByAddingObjectsFromArray: [self _addParentPath: apath toPaths: result]];
      result = [result arrayByAddingObject: apath];
      result = [result arrayByRemovingDuplicateEntries];
      result = [result arrayByAddingQuotationMarksToEntries];
    }
  
  return [result removeDuplicatesAndImplodeWithSeparator:@" -I"];
}

- (NSString *) _compiler
{
  GSXCBuildContext *context = [GSXCBuildContext sharedBuildContext];
  NSDictionary *plistFile = [context config];
  NSProcessInfo *pi = [NSProcessInfo processInfo];
  NSString *winCompilerPfx = [plistFile objectForKey: @"win_compiler_prefix"];
  NSString *winCfgPfx = [plistFile objectForKey: @"win_config_prefix"];
  NSUInteger os = [pi operatingSystem];
  NSString *compiler = nil;  
  
  if (os == NSWindowsNTOperatingSystem || os == NSWindows95OperatingSystem)
    {
      if (winCompilerPfx == nil)
	{
	  winCompilerPfx = @"/mingw64/bin";
	}

      if (winCfgPfx == nil)
	{
	  winCfgPfx = @"/usr/GNUstep/System/Tools";
	}
      
      NSString *defaultValue = [NSString stringWithFormat: @"`%@/gnustep-config --variable=CC` "
					 @"`%@/gnustep-config --objc-flags`", winCfgPfx,
					 winCfgPfx];	  
      compiler = [NSString stringForEnvironmentVariable: @"CC"
					   defaultValue: defaultValue]; 
      compiler = [winCompilerPfx stringByAppendingPathComponent: compiler];	  
    }
  else
    {
      compiler = [NSString stringForEnvironmentVariable: @"CC"
					   defaultValue: @"`gnustep-config --variable=CC` "
			   @"`gnustep-config --objc-flags`"];	  
    }
  
  return compiler;
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

  xcprintf("%s",[[NSString stringWithFormat: @"\t* Building %s%s%@%s (%ld / %ld)... ",
                         BOLD, MAGENTA, [self buildPath], RESET, _currentFile, _totalFiles] cString]);

  if(modified == nil)
    {
      modified = @"NO";
      [context setObject: @"NO"
		  forKey: @"MODIFIED_FLAG"];
    }

  if([_lastKnownFileType isEqualToString: @"sourcecode.c.objc"] || [_explicitFileType isEqualToString: @"sourcecode.c.objc"] ||
     [_lastKnownFileType isEqualToString: @"sourcecode.c.c"] || [_explicitFileType isEqualToString: @"sourcecode.c.c"] || 
     [_lastKnownFileType isEqualToString: @"sourcecode.cpp.cpp"] || [_explicitFileType isEqualToString: @"sourcecode.cpp.cpp"] ||
     [_lastKnownFileType isEqualToString: @"sourcecode.cpp.objcpp"] || [_explicitFileType isEqualToString: @"sourcecode.cpp.objcpp"])
    {
      NSString *proj_root = [bs objectForKey: @"PROJECT_ROOT"];
      if (proj_root == nil ||
          [proj_root isEqualToString: @""])
        {
          proj_root = @".";
        }

      if ([_lastKnownFileType isEqualToString: @"sourcecode.cpp.cpp"] || [_explicitFileType isEqualToString: @"sourcecode.cpp.cpp"] ||
	  [_lastKnownFileType isEqualToString: @"sourcecode.cpp.objcpp"] || [_explicitFileType isEqualToString: @"sourcecode.cpp.objcpp"])
	{
	  [context setObject: @"YES" forKey: @"LINK_WITH_CPP"];
	}


      NSDictionary *plistFile = [context config];
      NSArray *skippedSource = [plistFile objectForKey:
                                            @"skippedSource"];

      NSString *bp = [self buildPath];
      if ([skippedSource containsObject: bp])
        {
          xcprintf("skipping file.\n");
          return YES;
        }

      NSString *compiler = [self _compiler];
      NSString *buildPath = [proj_root stringByAppendingPathComponent: bp];
      NSArray *localHeaderPathsArray = [self _allSubdirsAtPath:@"."];
      NSString *fileName = [_path lastPathComponent];
      NSString *buildDir = [NSString stringForEnvironmentVariable: @"TARGET_BUILD_DIR" defaultValue: @"build"];
      NSString *additionalHeaderDirs = [context objectForKey:@"INCLUDE_DIRS"];
      NSString *derivedSrcHeaderDir = [context objectForKey: @"DERIVED_SOURCE_HEADER_DIR"];
      NSString *headerSearchPaths = [[self substituteSearchPaths: [context objectForKey: @"HEADER_SEARCH_PATHS"]
                                                       buildPath: buildPath] 
                                      removeDuplicatesAndImplodeWithSeparator: @" -I"];
      NSString *warningCflags = [[context objectForKey: @"WARNING_CFLAGS"] 
				  removeDuplicatesAndImplodeWithSeparator: @" "];
      NSString *localHeaderPaths = [localHeaderPathsArray implodeArrayWithSeparator:@" -I"];
      
      buildDir = [buildDir stringByAppendingPathComponent: [_target name]];
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
                                                  [NSString stringWithFormat: @" -I'%@' ",
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
      outputFiles = [[outputFiles stringByAppendingString: [NSString stringWithFormat: @"'%@'",outputPath]] 
		      stringByAppendingString: @" "];
      NSString *objCflags = @"";
      if([_lastKnownFileType isEqualToString: @"sourcecode.c.objc"])
	{
          objCflags = @"";
	}

      NSString *std = [NSString stringForEnvironmentVariable: @"GCC_C_LANGUAGE_STANDARD"
                                                defaultValue: @""];
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
      
      NSString *configString = [context objectForKey: @"CONFIG_STRING"]; 
      NSString *buildTemplate = @"%@ 2> %@ -c %@ %@ %@ %@ %@ %@ -o %@";
      NSString *compilePath = bp;
      NSString *subdirHeaderSearchPaths = [self _headerStringForPath: compilePath];
      NSString *parentHeaderSearchPaths = [self _headerStringForPath: [[compilePath pathComponents] firstObject]];
      NSString *errorOutPath = [outputPath stringByAppendingString: @".err"];
      NSString *buildCommand = [NSString stringWithFormat: buildTemplate, 
					 compiler,
                                         [errorOutPath stringByAddingQuotationMarks],
					 [compilePath stringByAddingQuotationMarks],
					 objCflags,
					 configString,
                                         parentHeaderSearchPaths,
					 headerSearchPaths,
                                         subdirHeaderSearchPaths,
					 [outputPath stringByAddingQuotationMarks]];
      NSDictionary *buildPathAttributes =  [manager attributesOfItemAtPath: buildPath
                                                                     error: &error];
      NSDictionary *outputPathAttributes = [manager attributesOfItemAtPath: outputPath
                                                                     error: &error];
      NSDate *buildPathDate = [buildPathAttributes fileModificationDate];
      NSDate *outputPathDate = [outputPathAttributes fileModificationDate];

      buildCommand = [buildCommand stringByReplacingOccurrencesOfString: @"$(inherited)"
                                                             withString: @"."];

      NSDebugLog(@"%@", buildCommand);
      
      if(outputPathDate != nil)
	{
	  if([buildPathDate compare: outputPathDate] == NSOrderedDescending)
	    {	  
	      result = xcsystem(buildCommand);
	      if([modified isEqualToString: @"NO"])
		{
		  modified = @"YES";
		  [context setObject: @"YES"
			      forKey: @"MODIFIED_FLAG"];
		}
	    }
	  else
	    {
              xcprintf("%sexists%s\n", YELLOW, RESET);
	    }
	}
      else
	{
	  result = xcsystem(buildCommand);
	  if([modified isEqualToString: @"NO"])
	    {
	      modified = @"YES";
	      [context setObject: @"YES"
			  forKey: @"MODIFIED_FLAG"];
	    }

          if (result == 0)
            {
              xcprintf("%ssuccess%s\n", GREEN, RESET);
            }
        }

      // If the result is not successful, show the error...
      if (result != 0)
        {
          xcprintf("%serror%s\n\n", RED, RESET);

          NSString *errorString = [NSString stringWithContentsOfFile: errorOutPath];
          [NSException raise: NSGenericException
                      format: @"%sMessage:%s %@", RED, RESET, errorString];

          /*
          xcputs("=======================================================");
          xcputs([[NSString stringWithFormat: @"%sReturn Value:%s %d", RED, RESET, result] cString]);
          xcputs([[NSString stringWithFormat: @"%sCommand:%s %s%@%s", RED, RESET, CYAN, buildCommand, RESET] cString]);
          xcputs([[NSString stringWithFormat: @"%sCurrent Directory:%s %s%@%s", RED, RESET, CYAN,
                          [manager currentDirectoryPath], RESET] cString]);
          NSString *errorString = [NSString stringWithContentsOfFile: errorOutPath];
          xcputs([[NSString stringWithFormat: @"%sHeader Search Path:%s %@", RED, RESET,
                          [compilePath stringByDeletingLastPathComponent]] cString]);
          xcputs("=======================================================");
          */
        }

      [context setObject: outputFiles forKey: @"OUTPUT_FILES"];
    }

  fflush(stdout);
  return (result == 0);
}

- (BOOL) generate
{
  GSXCBuildContext *context = [GSXCBuildContext sharedBuildContext];
  NSMutableArray *objcFiles = [self _arrayForKey: @"OBJC_FILES"];
  NSMutableArray *cFiles = [self _arrayForKey: @"C_FILES"];
  NSMutableArray *cppFiles = [self _arrayForKey: @"CPP_FILES"];
  NSMutableArray *objcppFiles = [self _arrayForKey: @"OBJCPP_FILES"];
  NSMutableArray *addlIncDirs = [self _arrayForKey: @"ADDITIONAL_INCLUDE_DIRS"];
  NSString *of = [context objectForKey: @"OUTPUT_FILES"];
  NSString *modified = [context objectForKey: @"MODIFIED_FLAG"];
  NSString *outputFiles = (of == nil)?@"":of;
  int result = 0;
  NSFileManager *manager = [NSFileManager defaultManager];

  // NSDebugLog(@"*** %@", _sourceTree);
  if(modified == nil)
    {
      modified = @"NO";
      [context setObject: @"NO"
		  forKey: @"MODIFIED_FLAG"];
    }

  // Get project root
  NSString *projDir = [NSString stringForEnvironmentVariable: @"PROJECT_ROOT"
                                                defaultValue: @"."];
  
  NSString *buildPath = [projDir stringByAppendingPathComponent: 
                            [self buildPath]];


  NSArray *localHeaderPathsArray = [self _allSubdirsAtPath:@"."];
  NSString *buildDir = [NSString stringForEnvironmentVariable: @"TARGET_BUILD_DIR" defaultValue: @"build"];
  buildDir = [buildDir stringByAppendingPathComponent: [self productName]];
  NSString *additionalHeaderDirs = [context objectForKey:@"INCLUDE_DIRS"];
  NSString *derivedSrcHeaderDir = [context objectForKey: @"DERIVED_SOURCE_HEADER_DIR"];
  NSString *headerSearchPaths = [[context objectForKey: @"HEADER_SEARCH_PATHS"] 
				      removeDuplicatesAndImplodeWithSeparator: @" -I"];
  NSString *warningCflags = [[context objectForKey: @"WARNING_CFLAGS"] 
				  removeDuplicatesAndImplodeWithSeparator: @" "];
  NSString *localHeaderPaths = [localHeaderPathsArray removeDuplicatesAndImplodeWithSeparator:@" -I"];

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
  
  // Sometimes, for some incomprehensible reason, the buildpath doesn't 
  // need the project dir pre-pended.  This could be due to differences 
  // in different version of xcode.  It must be removed to successfully
  // compile the application...
  if([manager fileExistsAtPath:buildPath] == NO)
    {
      buildPath = [self path];
    }
  
  NSString *objCflags = @"";
  if([_lastKnownFileType isEqualToString: @"sourcecode.c.objc"])
    {
      // objCflags = @"-fconstant-string-class=NSConstantString";
      objCflags = @"";
    }

  if([_lastKnownFileType isEqualToString: @"sourcecode.cpp.objcpp"])
    {
      objCflags = [objCflags stringByReplacingOccurrencesOfString: @"-std=gnu99" withString: @""];
    }
  
  // remove flags incompatible with gnustep...
  objCflags = [objCflags stringByReplacingOccurrencesOfString: @"-std=gnu11" withString: @""];

  // get compile path
  BOOL exists = [manager fileExistsAtPath: [self buildPath]];
  NSString *compilePath = ([[[self buildPath] pathComponents] count] > 1 && !exists) ?
    [[[self buildPath] stringByDeletingFirstPathComponent] stringByEscapingSpecialCharacters] :
    [self buildPath];
  
  [context setObject: outputFiles forKey: @"OUTPUT_FILES"];

  if([_lastKnownFileType isEqualToString: @"sourcecode.c.objc"])
    {
      [objcFiles addObject: compilePath];
    }

  if([_lastKnownFileType isEqualToString: @"sourcecode.c.c"])
    {
      [cFiles addObject: compilePath];
    }
  
  if([_lastKnownFileType isEqualToString: @"sourcecode.cpp.cpp"])
    {
      [cppFiles addObject: compilePath];
    }

  if([_lastKnownFileType isEqualToString: @"sourcecode.cpp.objcpp"])
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
  return [s stringByAppendingFormat: @" <%@, %@>", _path, _lastKnownFileType];
}
@end
