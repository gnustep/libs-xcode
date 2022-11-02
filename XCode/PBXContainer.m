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

#import "PBXContainer.h"
#import "PBXCommon.h"
#import "PBXProject.h"
#import "PBXFileReference.h"

@implementation PBXContainer

- (void) dealloc
{
  RELEASE(archiveVersion);
  RELEASE(classes);
  RELEASE(objectVersion);
  RELEASE(objects);
  RELEASE(_filename);
  RELEASE(_parameter);
  [super dealloc];
}

- (void) setParameter: (NSString *)p
{
  ASSIGN(_parameter, p);
}
  
- (NSString *) parameter
{
  return _parameter;
}

- (void) setFilename: (NSString *)fn
{
  ASSIGN(_filename, fn);
}
  
- (NSString *) filename
{
  return _filename;
}

- (void) setArchiveVersion: (NSString *)version
{
  ASSIGN(archiveVersion,version);
}

- (NSString *) archiveVersion
{
  return archiveVersion;
}

- (void) setClasses: (NSMutableDictionary *)dict
{
  ASSIGN(classes,dict);
}

- (NSMutableDictionary *) classes
{
  return classes;
}

- (void) setObjectVersion: (NSString *)version
{
  ASSIGN(objectVersion,version);
}

- (NSString *) objectVersion
{
  return objectVersion;
}

- (void) setObjects: (NSMutableDictionary *)dict
{
  ASSIGN(objects,dict);
}

- (NSMutableDictionary *) objects
{
  return objects;
}

- (id) rootObject
{
  return rootObject;
}

- (void) setRootObject: (id)object
{
  ASSIGN(rootObject, object);
}

- (void) collectHeaderFileReferences
{
  NSString *includeDirs = @"";
  NSMutableArray *dirs = [NSMutableArray array];
  NSArray *array = [objects allValues];
  NSEnumerator *en = [array objectEnumerator];
  id obj = nil;

  while((obj = [en nextObject]) != nil)
    {
      if([obj isKindOfClass:[PBXFileReference class]])
	{
	  if([[obj lastKnownFileType] isEqualToString:@"sourcecode.c.h"])
	    {
	      NSString *includePath = [[obj path] stringByDeletingLastPathComponent];
	      if([includePath isEqualToString:@""] == NO)
		{
		  if([dirs containsObject:includePath] == NO)
		    {
		      [dirs addObject:includePath];
		      includeDirs = [includeDirs stringByAppendingFormat: @" -I./%@ ",includePath]; 
		    }
		}
	    }
	}
    }

  [rootObject setContext: [NSDictionary dictionaryWithObject:includeDirs forKey:@"INCLUDE_DIRS"]];
}

- (BOOL) build
{
  [self collectHeaderFileReferences];
  [rootObject setContainer: self];
  return [rootObject build];
}

- (BOOL) clean
{
  return [rootObject clean];
}

- (BOOL) install
{
  return [rootObject install];
}

- (BOOL) generate
{
  [self collectHeaderFileReferences];
  [rootObject setContainer: self];
  return [rootObject generate];
}

- (BOOL) link
{
  // Likely need to collect .o artifacts...
  [rootObject setContainer: self];
  return [rootObject link];
}

@end
