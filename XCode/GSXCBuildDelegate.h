/* Definition of protocol GSXCBuildDelegate
   Copyright (C) 2022 Free Software Foundation, Inc.
   
   By: Gregory John Casamento
   Date: 25-01-2022

   This file is part of GNUstep.
   
   This library is free software; you can redistribute it and/or
   modify it under the terms of the GNU Lesser General Public
   License as published by the Free Software Foundation; either
   version 2.1 of the License, or (at your option) any later version.
   
   This library is distributed in the hope that it will be useful,
   but WITHOUT ANY WARRANTY; without even the implied warranty of
   MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
   Lesser General Public License for more details.
   
   You should have received a copy of the GNU Lesser General Public
   License along with this library; if not, write to the Free
   Software Foundation, Inc., 51 Franklin Street, Fifth Floor,
   Boston, MA 02110 USA.
*/

#ifndef _GSXCBuildDelegate_h_INCLUDE
#define _GSXCBuildDelegate_h_INCLUDE

#import <Foundation/NSObject.h>
#import "PBXProject.h"

#if	defined(__cplusplus)
extern "C" {
#endif

@protocol GSXCBuildDelegate

@optional
/**
 * Called when the project publishes a message.
 */
- (void) project: (PBXProject *)project publishMessage: (NSString *)message;

@end

#if	defined(__cplusplus)
}
#endif

#endif	/* _GSXCBuildDelegate_h_INCLUDE */

