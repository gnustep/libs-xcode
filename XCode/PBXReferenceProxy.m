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

#import "PBXCommon.h"
#import "PBXReferenceProxy.h"

@implementation PBXReferenceProxy

- (void) dealloc
{
  RELEASE(sourceTree);
  RELEASE(fileType);
  RELEASE(remoteRef);
  RELEASE(path);
  
  [super dealloc];
}

// Methods....
- (NSString *) sourceTree // getter
{
  return sourceTree;
}

- (void) setSourceTree: (NSString *)object; // setter
{
  ASSIGN(sourceTree,object);
}

- (NSString *) fileType // getter
{
  return fileType;
}

- (void) setFileType: (NSString *)object; // setter
{
  ASSIGN(fileType,object);
}

- (PBXContainerItemProxy *) remoteRef // getter
{
  return remoteRef;
}

- (void) setRemoteRef: (PBXContainerItemProxy *)object; // setter
{
  ASSIGN(remoteRef,object);
}

- (NSString *) path // getter
{
  return path;
}

- (void) setPath: (NSString *)object; // setter
{
  ASSIGN(path,object);
}


@end
