/*
   Copyright (C) 2022 Free Software Foundation, Inc.

   Written by: Gregory John Casamento <greg.casamento@gmail.com>
   Date: Nov 2022
   
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

#import <Foundation/NSDictionary.h>
#import <Foundation/NSArray.h>
#import <Foundation/NSString.h>
#import <Foundation/NSFileManager.h>

#import <XCode/GSXCBuildContext.h>
#import <XCode/GSXCBuildDatabase.h>
#import <XCode/PBXSourcesBuildPhase.h>
#import <XCode/PBXBuildFile.h>

#import "GSXCColors.h"
#import "xcsystem.h"

@implementation GSXCRecord : NSObject

+ (instancetype) recordWithContentsOfFile: (NSString *)path
{
  return [[self alloc] initWithContentsOfFile: path];
}

- (instancetype) initWithContentsOfFile: (NSString *)path
{
  NSDictionary *dict = [NSDictionary dictionaryWithContentsOfFile: path];
  return [self initWithDictionary: dict];
}

- (instancetype) initWithDictionary: (NSDictionary *)dict
{
  self = [super init];
  if (self != nil)
    {
      ASSIGN(_dictionary, [dict mutableCopy]);
    }
  return self;
}

- (instancetype) init
{
  self = [super init];
  if (self != nil)
    {
      ASSIGN(_dictionary, [NSMutableDictionary dictionary]);
    }
  return self;
}

- (void) dealloc
{
  RELEASE(_dictionary);

  [super dealloc];
}

- (id) copyWithZone: (NSZone *)z
{
  Class c = [self class];
  id copy = [[c alloc] initWithDictionary: _dictionary];

  return copy;
}

- (NSDictionary *) dictionary
{
  return [_dictionary copy];
}

@end

@implementation GSXCFileRecord : GSXCRecord

- (instancetype) initWithDictonary: (NSDictionary *)dict
{
  self = [super initWithDictionary: dict];
  if (self != nil)
    {
      NSString *fn = [dict objectForKey: @"fileName"];
      NSDate *dm = [dict objectForKey: @"dateModified"];
      NSDate *db = [dict objectForKey: @"dateBuilt"];

      [self setFileName: fn];
      [self setDateModified: dm];
      [self setDateBuilt: db];      
    }
  return self;
}

- (instancetype) initWithFile: (PBXBuildFile *)f path: (NSString *)path
{
  self = [super init];
  if (self != nil)
    {
      NSError *error = nil;
      NSFileManager *mgr = [NSFileManager defaultManager];
      PBXFileReference *fr = [f fileRef];
      NSString *fullPath = [fr buildPath];
      NSString *fileName = [fullPath lastPathComponent];
      NSDictionary *attrs = [mgr attributesOfItemAtPath: fullPath error: &error];

      ASSIGN(_fileReference, fr);
      [self setFileName: fileName];
      
      if (error == nil)
	{
	  NSDate *srcModified = [attrs objectForKey: NSFileModificationDate];
	  NSString *outputPath = [path stringByAppendingPathComponent: 
					 [fileName stringByAppendingString: @".o"]];
	  NSDictionary *objAttrs = [mgr attributesOfItemAtPath: outputPath error: &error];

	  if (srcModified == nil)
	    {
	      srcModified = [attrs objectForKey: NSFileCreationDate];
	      [self setDateModified: srcModified];
	    }
	  else
	    {
	      [self setDateModified: srcModified];
	    }

	  if (error == nil)
	    {
	      NSDate *objModified = [objAttrs objectForKey: NSFileModificationDate];
	      if (objModified == nil)
		{
		  objModified = [objAttrs objectForKey: NSFileCreationDate];
		}

	      [self setDateBuilt: objModified];
	    }
	  else
	    {
	      [self setDateBuilt: [NSDate distantPast]];
	    }	  
	}
      else
	{
	  NSDebugLog(@"file = %@, error = %@", fullPath, error);
	}

      NSDebugLog(@"%@ - %@, %@", _fileName, _dateModified, _dateBuilt);
    }
  return self;
}

+ (instancetype) recordWithBuildFile: (PBXBuildFile *)f path: (NSString *)path
{
  return AUTORELEASE( [[self alloc] initWithFile: f path: path] );
}

- (id) copyWithZone: (NSZone *)z
{
  Class c = [self class];
  id copy = [[c alloc] initWithDictionary: _dictionary];

  return copy;
}

- (void) dealloc
{
  RELEASE(_fileName);
  RELEASE(_dateModified);
  RELEASE(_dateBuilt);

  [super dealloc];
}

- (void) setFileName: (NSString *)fn
{
  [_dictionary setObject: fn forKey:  @"fileName"];
  ASSIGN(_fileName, fn);
}

- (NSString *) fileName
{
  return _fileName;
}

- (void) setDateModified: (NSDate *)d
{
  [_dictionary setObject: d forKey:  @"dateModified"];
  ASSIGN(_dateModified, d);
}

- (NSDate *) dateModified
{
  return _dateModified;
}

- (void) setDateBuilt: (NSDate *)d
{
  [_dictionary setObject: d forKey:  @"dateBuilt"];
  ASSIGN(_dateBuilt, d);
}

- (NSDate *) dateBuilt
{
  return _dateBuilt;
}

- (PBXFileReference *) fileReference
{
  return _fileReference;
}

@end

@implementation GSXCBuildDatabase : NSObject

+ (instancetype) buildDatabaseWithTarget: (PBXAbstractTarget *)target
{
  return AUTORELEASE( [[self alloc] initWithTarget: target] );
}

- (BOOL) _construct
{
  GSXCBuildContext *ctx = [GSXCBuildContext sharedBuildContext];
  NSFileManager *mgr = [NSFileManager defaultManager];
  NSEnumerator *en = [[_target buildPhases] objectEnumerator];
  PBXAbstractBuildPhase *p = nil;
  NSString *buildDir = [ctx objectForKey: @"TARGET_BUILD_DIR"];

  if (buildDir == nil)
    {
      buildDir = @"./build";
    }

  // if build dir doesn't exist, then it's a fresh build... just return.
  if ([mgr fileExistsAtPath: buildDir] == NO)
    {
      return NO;
    }
  
  buildDir = [buildDir stringByAppendingPathComponent: [_target name]];
  
  xcprintf("=== Evaluating existing build... %s\n", [[_target name] cStringUsingEncoding: NSUTF8StringEncoding]);
  while ( (p = [en nextObject]) != nil )
    {
      NSDebugLog(@"Phase = %@", p);
	   
      if ([p isKindOfClass: [PBXSourcesBuildPhase class]])
	{
	  NSArray *files = [p files];
	  NSEnumerator *fen = [files objectEnumerator];
	  PBXBuildFile *bf = nil;

	  while ( (bf = [fen nextObject]) != nil )
	    {
	      GSXCFileRecord *fr = [GSXCFileRecord recordWithBuildFile: bf path: buildDir];

	      if ([[fr dateModified] compare: [fr dateBuilt]] == NSOrderedDescending)
		{
		  xcprintf("\t* Checking %s%s%s%s - %smodified%s\n", BOLD, CYAN, [[fr fileName] cString], RESET, GREEN, RESET);
		  [self addRecord: fr];
		}
	      else
		{
		  xcprintf("\t* Checking %s%s%s%s - %salready built%s\n", BOLD, CYAN, [[fr fileName] cString], RESET, YELLOW, RESET);		  
		}
	    }	  
	}
    }

  return YES;
}

- (instancetype) init
{
  self = [super init];
  if (self != nil)
    {
      _records = [[NSMutableArray alloc] initWithCapacity: 10];
      [self setTarget: nil];
    }
  return self;
}

- (instancetype) initWithTarget: (PBXAbstractTarget *)target
{
  self = [super init];
  if (self != nil)
    {
      _records = [[NSMutableArray alloc] initWithCapacity: 10];
      [self setTarget: target];
      if( [self _construct] == NO )
	{
	  return nil;
	}
    }
  return self;
}

- (void) dealloc
{
  RELEASE(_records);
  _target = nil;

  [super dealloc];
}

- (void) setTarget: (PBXAbstractTarget *)target
{
  _target = target;
}

- (PBXAbstractTarget *) target
{
  return _target;
}

- (void) addRecord: (GSXCRecord *)record
{
  [_records addObject: record];
}

- (NSArray *) files
{
  NSMutableArray *array = [NSMutableArray arrayWithCapacity: [_records count]];
  NSEnumerator *en = [_records objectEnumerator];
  id f = nil;

  while ((f = [en nextObject]) != nil)
    {
      id fr = [f fileReference];
      [array addObject: fr];
    }

  return array;
}

@end
