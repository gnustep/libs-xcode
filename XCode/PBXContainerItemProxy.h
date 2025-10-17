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
#import "PBXFileReference.h"


@interface PBXContainerItemProxy : NSObject
{
  NSString *proxyType;
  NSString *remoteGlobalIDString;
  id containerPortal;
  NSString *remoteInfo;
}

/**
 * Returns the proxy type for this container item proxy.
 */
- (NSString *) proxyType;

/**
 * Sets the proxy type for this container item proxy.
 */
- (void) setProxyType: (NSString *)object;

/**
 * Returns the remote global ID string.
 */
- (NSString *) remoteGlobalIDString;

/**
 * Sets the remote global ID string.
 */
- (void) setRemoteGlobalIDString: (NSString *)object;

/**
 * Returns the container portal.
 */
- (id) containerPortal;

/**
 * Sets the container portal.
 */
- (void) setContainerPortal: (id)object;

/**
 * Returns the remote info string.
 */
- (NSString *) remoteInfo;

/**
 * Sets the remote info string.
 */
- (void) setRemoteInfo: (NSString *)object;

/**
 * Builds the container item proxy.
 */
- (BOOL) build;

/**
 * Generates the container item proxy.
 */
- (BOOL) generate;

/**
 * Cleans the container item proxy.
 */
- (BOOL) clean;

/**
 * Saves the container item proxy.
 */
- (BOOL) save;

@end
