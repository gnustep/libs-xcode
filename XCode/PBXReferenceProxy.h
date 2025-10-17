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

#import <Foundation/Foundation.h>

// Local includes
#import "PBXCoder.h"
#import "PBXContainerItemProxy.h"


@interface PBXReferenceProxy : NSObject
{
  NSString *sourceTree;
  NSString *fileType;
  PBXContainerItemProxy *remoteRef;
  NSString *path;
}

/**
 * Returns the source tree for this reference proxy.
 */
- (NSString *) sourceTree;

/**
 * Sets the source tree for this reference proxy.
 */
- (void) setSourceTree: (NSString *)object;

/**
 * Returns the file type for this reference proxy.
 */
- (NSString *) fileType;

/**
 * Sets the file type for this reference proxy.
 */
- (void) setFileType: (NSString *)object;

/**
 * Returns the remote reference for this proxy.
 */
- (PBXContainerItemProxy *) remoteRef;

/**
 * Sets the remote reference for this proxy.
 */
- (void) setRemoteRef: (PBXContainerItemProxy *)object;

/**
 * Returns the path for this reference proxy.
 */
- (NSString *) path;

/**
 * Sets the path for this reference proxy.
 */
- (void) setPath: (NSString *)object;

@end
