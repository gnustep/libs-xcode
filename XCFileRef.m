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
*/ #import "XCFileRef.h"
#import "PBXCoder.h"
#import "PBXContainer.h"
#import "NSString+PBXAdditions.h"

#import <Foundation/NSString.h>
#import <Foundation/NSDebug.h>

@implementation XCFileRef

+ (instancetype) fileRef
{
  return AUTORELEASE([[self alloc] init]);
}

- (instancetype) init
{
  self = [super init];

  if (self)
    {
      [self setLocation: nil];
    }

  return self;
}

- (NSString *) location
{
  return _location;
}

- (void) setLocation: (NSString *)loc
{
  ASSIGN(_location, loc);
}

- (BOOL) performLegacyOperation: (SEL)sel
{
  NSString *loc = [[self location] stringByReplacingOccurrencesOfString: @"group:" withString: @""];
  NSString *p = [loc stringByDeletingLastPathComponent];
  NSString *function = NSStringFromSelector(sel);
  NSString *display = [function stringByCapitalizingFirstCharacter];
  
  if (p != nil)
    {
      PBXCoder *coder = nil;
      NSFileManager *mgr = [NSFileManager defaultManager];
      NSString *cwd = [mgr currentDirectoryPath];

      // If the project is in a subdir, go to the subdir...
      if ([[p pathExtension] isEqualToString: @"xcodeproj"] == NO)
        {
          NSString *nwd = [cwd stringByAppendingPathComponent: p];

          printf("++ %s project in dir... %s\n", [display cString], [nwd cString]);
          [mgr changeCurrentDirectoryPath: nwd];
        }

      coder = [[PBXCoder alloc] initWithProjectFile: [loc lastPathComponent]];

      if (coder != nil)
        {
          PBXContainer *pc = [coder unarchive];
          [pc performSelector: sel];
        }
      
      // If the project is in a subdir, return to the previous dir...
      if ([[p pathExtension] isEqualToString: @"xcodeproj"] == NO)
        {
          printf("++ %s completed\n", [display cString]);                   
          [mgr changeCurrentDirectoryPath: cwd];
        }

      AUTORELEASE(coder);
        
    }
  return YES;
}

- (BOOL) build
{
  return [self performLegacyOperation: _cmd];
}

- (BOOL) clean
{
  return [self performLegacyOperation: _cmd];
}

- (BOOL) install
{
  return [self performLegacyOperation: _cmd];
}

@end
