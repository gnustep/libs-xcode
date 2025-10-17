/* Definition of class GSXCBuildTask
   Copyright (C) 2022 Free Software Foundation, Inc.
   
   By: Gregory John Casamento
   Date: 24-01-2022

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

#ifndef _GSXCBuildTask_h_INCLUDE
#define _GSXCBuildTask_h_INCLUDE

#import <Foundation/NSOperation.h>
#import "GSXCCommon.h"

@class PBXBuildFile;

#if	defined(__cplusplus)
extern "C" {
#endif

@interface GSXCBuildOperation : NSOperation
{
  PBXBuildFile *_file;
}

/**
 * Creates an operation with the given file.
 */
+ (instancetype) operationWithFile: (PBXBuildFile *)file;

/**
 * Initializes the operation with the given file.
 */
- (instancetype) initWithFile: (PBXBuildFile *)file;

/**
 * Returns the file for this operation.
 */
- (PBXBuildFile *) file;

/**
 * Sets the file for this operation.
 */
- (void) setFile: (PBXBuildFile *)file;
  
@end

#if	defined(__cplusplus)
}
#endif

#endif	/* _GSXCBuildTask_h_INCLUDE */

