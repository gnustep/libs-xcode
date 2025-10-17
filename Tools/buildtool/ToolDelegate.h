/* ToolDelegate.m
 *
 * Copyright (C) 2023 Free Software Foundation, Inc.
 *
 * Author:	Gregory John Casamento <greg.casamento@gmail.com>
 * Date:	2023
 *
 * This file is part of GNUstep.
 *
 * This program is free software; you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation; either version 3 of the License, or
 * (at your option) any later version.
 *
 * This program is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU General Public License for more details.
 *
 * You should have received a copy of the GNU General Public License
 * along with this program; if not, write to the Free Software
 * Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston, MA 02111
 * USA.
 */

#import <Foundation/NSObject.h>
#import <XCode/XCAbstractDelegate.h>

@class NSDictionary;
@class NSMutableArray;
@class NSSet;

/**
 * Finds the project filename from directory entries.
 */
NSString *findProjectFilename(NSArray *projectDirEntries);

/**
 * Finds the workspace filename from directory entries.
 */
NSString *findWorkspaceFilename(NSArray *projectDirEntries);

/**
 * Resolves the project name and sets whether it is a project.
 */
NSString *resolveProjectName(BOOL *isProject);

@interface ToolDelegate : XCAbstractDelegate

/**
 * Parses command line arguments.
 */
- (NSDictionary *) parseArguments;

/**
 * Processes the tool operation.
 */
- (void) process;

@end
