/*
   Project: Ycode

   Copyright (C) 2025 Free Software Foundation

   Author: Gregory Casamento

   Created: 2025-01-15

   This application is free software; you can redistribute it and/or
   modify it under the terms of the GNU General Public
   License as published by the Free Software Foundation; either
   version 2 of the License, or (at your option) any later version.

   This application is distributed in the hope that it will be useful,
   but WITHOUT ANY WARRANTY; without even the implied warranty of
   MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
   Library General Public License for more details.

   You should have received a copy of the GNU General Public
   License along with this library; if not, write to the Free
   Software Foundation, Inc., 59 Temple Place, Suite 330, Boston, MA 02111 USA.
*/

#ifndef _YCODEPROJECT_H_
#define _YCODEPROJECT_H_

#import <Foundation/Foundation.h>
#import <AppKit/AppKit.h>

@class YCodeProjectNavigatorController;
@class YCodeEditorController;
@class YCodeBuildSystem;
@class PBXProject;
@class PBXContainer;
@class PBXFileReference;

@interface YCodeProject : NSDocument
{
  PBXProject *_project;
  PBXContainer *_container;
  NSString *_projectPath;
  
  // Controllers
  YCodeProjectNavigatorController *_navigatorController;
  YCodeEditorController *_editorController;
  YCodeBuildSystem *_buildSystem;
  
  // Project settings
  NSMutableDictionary *_settings;
  
  // File watching
  NSMutableDictionary *_fileWatchers;
}

/**
 * Project access
 */
- (PBXProject *)project;
- (void)setProject:(PBXProject *)project;
- (PBXContainer *)container;
- (void)setContainer:(PBXContainer *)container;

/**
 * Project path management
 */
- (NSString *)projectPath;
- (void)setProjectPath:(NSString *)path;
- (NSString *)projectDirectoryPath;

/**
 * Controllers
 */
- (YCodeProjectNavigatorController *)navigatorController;
- (YCodeEditorController *)editorController;
- (YCodeBuildSystem *)buildSystem;

/**
 * Project operations
 */
- (BOOL)buildProject;
- (BOOL)cleanProject;
- (BOOL)runProject;

/**
 * File management
 */
- (void)addFilesToProject:(NSArray *)filePaths;
- (void)removeFilesFromProject:(NSArray *)filePaths;
- (BOOL)addGroupToProject:(NSString *)groupName;

/**
 * Project settings
 */
- (NSMutableDictionary *)settings;
- (void)setSettings:(NSMutableDictionary *)settings;

/**
 * File watching
 */
- (void)startWatchingFiles;
- (void)stopWatchingFiles;

@end

#endif // _YCODEPROJECT_H_