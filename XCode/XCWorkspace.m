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

#import "XCWorkspace.h"
#import "XCFileRef.h"
#import "PBXNativeTarget.h"
#import "GSXCCommon.h"

#import <Foundation/NSString.h>
#import <Foundation/NSArray.h>
#import <Foundation/NSEnumerator.h>
#import <Foundation/NSAutoreleasePool.h>
#import <Foundation/NSXMLDocument.h>
#import <Foundation/NSFileManager.h>

@implementation XCWorkspace

+ (instancetype) workspace
{
  return AUTORELEASE([[self alloc] init]);
}

- (instancetype) init
{
  self = [super init];

  if (self != nil)
    {
      [self setFileRefs: [NSArray array]];
      [self setVersion: nil];
    }

  return self;
}

- (NSString *) version
{
  return _version;
}

- (void) setVersion: (NSString *)v
{
  ASSIGN(_version, v);
}

- (NSArray *) fileRefs
{
  return _fileRefs;
}

- (void) setFileRefs: (NSArray *)refs
{
  ASSIGN(_fileRefs, refs);
}

- (NSString *) filename
{
  return _filename;
}

- (void) setFilename: (NSString *)filename
{
  ASSIGN(_filename, filename);
}

- (NSString *) _collectWorkspaceLinkDirs
{
  NSString *result = @"";
  NSEnumerator *en = [_fileRefs reverseObjectEnumerator];
  XCFileRef *ref = nil;
  
  while ((ref = [en nextObject]) != nil)
    {
      NSString *loc = [ref location];
      NSString *projRoot = [loc stringByDeletingLastPathComponent];
      NSString *buildDir = [projRoot stringByAppendingPathComponent: @"build"];

      NSArray *targets = [ref targets];
      NSEnumerator *ten = [targets objectEnumerator];
      PBXNativeTarget *t = nil;
      
      while ((t = [ten nextObject]) != nil)
	{
	  NSString *name = [t productName];
	  NSString *targetDir = [[buildDir stringByAppendingPathComponent: name]
				  stringByReplacingOccurrencesOfString: @"group:" withString: @""];
	  NSString *prodDir = [targetDir stringByAppendingPathComponent: @"Products"];
	  result = [result stringByAppendingFormat: @" -L./%@ ", prodDir];
	}
    }

  return result;
}

- (NSString *) _collectWorkspaceLinkLibs
{
  NSString *result = @"";
  NSEnumerator *en = [_fileRefs reverseObjectEnumerator];
  XCFileRef *ref = nil;
  
  while ((ref = [en nextObject]) != nil)
    {
      NSArray *targets = [ref targets];
      NSEnumerator *ten = [targets objectEnumerator];
      PBXNativeTarget *t = nil;
      
      while ((t = [ten nextObject]) != nil)
	{
	  NSString *type = [t productType];

	  if ([type isEqualToString: LIBRARY_TYPE]
	      || [type isEqualToString: DYNAMIC_LIBRARY_TYPE]
	      || [type isEqualToString: FRAMEWORK_TYPE])
	    {	     
	      NSString *name = [t productName];
	      NSString *libName = [name stringByReplacingOccurrencesOfString: @"group:" withString: @""];
	      result = [result stringByAppendingFormat: @" -l%@ ", libName];
	    }
	}
    }

  return result;
}

- (NSString *) _collectWorkspaceIncludeDirs
{
  NSString *result = @"";
  NSEnumerator *en = [_fileRefs reverseObjectEnumerator];
  XCFileRef *ref = nil;
  
  while ((ref = [en nextObject]) != nil)
    {
      NSString *loc = [ref location];
      NSString *projRoot = [loc stringByDeletingLastPathComponent];

      NSArray *targets = [ref targets];
      NSEnumerator *ten = [targets objectEnumerator];
      PBXNativeTarget *t = nil;
      
      while ((t = [ten nextObject]) != nil)
	{
	  NSString *targetDir = [projRoot stringByReplacingOccurrencesOfString: @"group:" withString: @""];
	  result = [result stringByAppendingFormat: @" -I./%@ ", targetDir];
	}
    }

  return result;
}

- (BOOL) build
{
  NSAutoreleasePool *p = [[NSAutoreleasePool alloc] init]; // start pool for workspace
  NSEnumerator *en = [_fileRefs reverseObjectEnumerator];
  XCFileRef *ref = nil;
  NSString *display = [[self filename]
                        stringByDeletingLastPathComponent];
  NSString *workspaceLinkDirs = [self _collectWorkspaceLinkDirs];
  NSString *workspaceIncDirs = [self _collectWorkspaceIncludeDirs];
  NSString *workspaceLinkLibs = [self _collectWorkspaceLinkLibs];
  
  NSDebugLog(@"\n\n\nWorkspace Include Dirs = %@\n\n\n", workspaceIncDirs);
  NSDebugLog(@"\n\n\nWorkspace Link Libs = %@\n\n\n", workspaceLinkLibs);
  printf("+++ Building projects workspace.. %s\n", [display cString]);

  while ((ref = [en nextObject]) != nil)
    {
      [ref setWorkspaceIncludes: workspaceIncDirs];
      [ref setWorkspaceLink: workspaceLinkDirs];
      [ref setWorkspaceLibs: workspaceLinkLibs];
      BOOL s = [ref build];
      if (s == NO)
        {
          printf("+++ Workspace build FAILED %s\n", [display cString]);
          return NO;
        }
      }
  printf("+++ Workspace build completed... %s\n", [display cString]);

  RELEASE(p);

  return YES;
}

- (BOOL) clean
{
  NSEnumerator *en = [_fileRefs reverseObjectEnumerator];
  XCFileRef *ref = nil;

  printf("+++ Cleaning projects in workspace.. %s\n", [[[self filename] stringByDeletingLastPathComponent] cString]);
  while ((ref = [en nextObject]) != nil)
    {
      BOOL s = [ref clean];
      if (s == NO)
        {
          return NO;
        }
    }
  printf("+++ Workspace clean complete\n");
  
  return YES;
}

- (BOOL) install
{
  NSEnumerator *en = [_fileRefs reverseObjectEnumerator];
  XCFileRef *ref = nil;

  printf("+++ Installing projects in workspace.. %s\n",
         [[[self filename] stringByDeletingLastPathComponent] cString]);
  while ((ref = [en nextObject]) != nil)
    {
      BOOL s = [ref install];
      if (s == NO)
        {
          return NO;
        }
    }
  printf("+++ Workspace install complete\n");
  
  return YES;
}

- (BOOL) link
{
  NSEnumerator *en = [_fileRefs reverseObjectEnumerator];
  XCFileRef *ref = nil;
  NSString *display = [[self filename]
                        stringByDeletingLastPathComponent];
  
  printf("+++ Building projects workspace.. %s\n", [display cString]);
  while ((ref = [en nextObject]) != nil)
    {
      NSAutoreleasePool *p = [[NSAutoreleasePool alloc] init];
      BOOL s = [ref link];
      if (s == NO)
        {
          printf("+++ Workspace build FAILED %s\n", [display cString]);
          return NO;
        }
      RELEASE(p);
    }
  printf("+++ Workspace build completed... %s\n", [display cString]);
  
  return YES;
}

@end
