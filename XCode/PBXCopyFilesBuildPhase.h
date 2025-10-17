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
*/ #import <Foundation/Foundation.h>

// Local includes
#import "PBXCoder.h"
#import "PBXBuildPhase.h"

@interface PBXCopyFilesBuildPhase : PBXBuildPhase
{
  NSString *dstPath;
  NSString *dstSubfolderSpec;
}

/**
 * Returns the destination path for this copy files build phase.
 */
- (NSString *) dstPath;

/**
 * Sets the destination path for this copy files build phase.
 */
- (void) setDstPath: (NSString *)object;

/**
 * Returns the destination subfolder specification.
 */
- (NSString *) dstSubfolderSpec;

/**
 * Sets the destination subfolder specification.
 */
- (void) setDstSubfolderSpec: (NSString *)object;

@end
