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

- (instancetype) init
{
  self = [super init];

  if (self != nil)
    {
      archiveVersion = nil;
      classes = nil;
      objectVersion = nil;
      objects = nil;
      rootObject = nil;
      _filename = nil;
      _parameter = nil;
      _workspaceLink = nil;
      _workspaceLibs = nil;
      _workspaceIncludes = nil;
    }

  return self;
}

- (void) dealloc
{
  RELEASE(archiveVersion);
  RELEASE(classes);
  RELEASE(objectVersion);
  RELEASE(objects);
  RELEASE(_filename);
  RELEASE(_parameter);
  RELEASE(_workspaceLink);
  RELEASE(_workspaceLibs);
  RELEASE(_workspaceIncludes);
  [super dealloc];
}

- (void) setWorkspaceIncludes: (NSString *)i
{
  ASSIGN(_workspaceIncludes, i);
}

- (NSString *) workspaceIncludes
{
  return _workspaceIncludes;
}

- (void) setWorkspaceLibs: (NSString *)l
{
  ASSIGN(_workspaceLibs, l);
}

- (NSString *) workspaceLibs
{
  return _workspaceLibs;
}

- (void) setWorkspaceLink: (NSString *)w
{
  ASSIGN(_workspaceLink, w);
}

- (NSString *) workspaceLink
{
  return _workspaceLink;
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
  NSMutableDictionary *context = [NSMutableDictionary dictionary]; 

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

  // Add to the dictionary...
  [context setObject: includeDirs forKey:@"INCLUDE_DIRS"];

  // Add workspace info to the context...
  if (_workspaceLink != nil)
    {
      [context setObject: _workspaceLink forKey: @"WORKSPACE_LINK_LINE"];
    }

  NSDebugLog(@"\n\n\nlibs = %@\n\n\n", _workspaceLibs);  
  if (_workspaceLibs != nil)
    {
      [context setObject: _workspaceLibs forKey: @"WORKSPACE_LIBS_LINE"];
    }
  
  if (_workspaceIncludes != nil)
    {
      [context setObject: _workspaceIncludes forKey: @"WORKSPACE_INCLUDE_LINE"];
    }
  
  [rootObject setContext: context];
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

- (BOOL) save
{
  NSString *fn = [[self filename]
                   stringByDeletingLastPathComponent];
  NSString *of = @"project.pbxproj";
  NSString *dn = _parameter;
  NSFileManager *fm = [NSFileManager defaultManager];
  NSError *error = nil;
  BOOL created = [fm createDirectoryAtPath: dn
		     withIntermediateDirectories: YES
				attributes: NULL
				     error: &error];

  xcprintf("=== Saving Project %s%s%s%s -> %s%s%s\n",
	   BOLD, YELLOW, [fn cString], RESET, GREEN,
	   [dn cString], RESET);

  // Clear the cached objects dictionary;
  [self setObjects: [NSMutableDictionary dictionary]];

  // Save the project...
  if (created && !error)
    {
      PBXCoder *coder = [[PBXCoder alloc] initWithRootObject: self];
      NSDictionary *dictionary = [coder archive];
      NSString *path = [dn stringByAppendingPathComponent: of];
      BOOL result = [dictionary writeToFile: path atomically: YES];

      if (result)
	{
	  xcprintf("=== Done Saving Project %s%s%s%s\n",
		   BOLD, GREEN, [dn cString], RESET);
	}
      else
	{
	  xcprintf("=== Error Saving Project %s%s%s%s\n",
		   BOLD, GREEN, [dn cString], RESET);
	}
      
      return result;
    }
  else
    {
      xcprintf("=== Error creating directory %s", dn);
    }
  
  return NO;
}

@end
