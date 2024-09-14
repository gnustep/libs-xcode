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

#import <Foundation/NSFileManager.h>

#import "PBXCommon.h"
#import "PBXContainerItemProxy.h"
#import "PBXCoder.h"
#import "PBXContainer.h"
#import "GSXCBuildContext.h"

@implementation PBXContainerItemProxy

- (void) dealloc
{
  RELEASE(proxyType);
  RELEASE(remoteGlobalIDString);
  RELEASE(containerPortal);
  RELEASE(remoteInfo);

  [super dealloc];
}

// Methods....
- (NSString *) proxyType // getter
{
  return proxyType;
}

- (void) setProxyType: (NSString *)object; // setter
{
  ASSIGN(proxyType,object);
}

- (NSString *) remoteGlobalIDString // getter
{
  return remoteGlobalIDString;
}

- (void) setRemoteGlobalIDString: (NSString *)object; // setter
{
  ASSIGN(remoteGlobalIDString,object);
}

- (id) containerPortal // getter
{
  return containerPortal;
}

- (void) setContainerPortal: (id)object; // setter
{
  ASSIGN(containerPortal,object);
}

- (NSString *) remoteInfo // getter
{
  return remoteInfo;
}

- (void) setRemoteInfo: (NSString *)object; // setter
{
  ASSIGN(remoteInfo,object);
}

- (BOOL) build
{
  PBXContainer *currentContainer = [[GSXCBuildContext sharedBuildContext] objectForKey: @"CONTAINER"];
  NSFileManager *mgr = [NSFileManager defaultManager];
  
  containerPortal = [[currentContainer objects] objectForKey: containerPortal];
  if([containerPortal isKindOfClass: [PBXFileReference class]])
    {
      xcputs([[NSString stringWithFormat: @"=== Proxy Reading %s%@%s", GREEN, [containerPortal path], RESET] cString]);
      NSString *dir = [mgr currentDirectoryPath];
      PBXCoder *coder = [[PBXCoder alloc] initWithProjectFile: [containerPortal path]];
      [mgr changeCurrentDirectoryPath: [coder projectRoot]];
      PBXContainer *container = [coder unarchive];
      [container setFilename: [containerPortal path]];
      BOOL result = [container build];
      [mgr changeCurrentDirectoryPath: dir];

      return result;
    }
  else
    {
      return YES;
    }

  return NO;
}

- (BOOL) save
{
  return YES;  
}

- (BOOL) generate
{
  return YES;
}

- (BOOL) clean
{
  return YES;
}

@end
