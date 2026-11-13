/*
   Project: Ycode

   Copyright (C) 2025 Free Software Foundation

   Author: Gregory Casamento

   Created: 2025-01-15

   This application is free software; you can redistribute it and/or
   modify it under the terms of the GNU General Public
   License as published by the Free Software Foundation; either
   version 3 of the License, or (at your option) any later version.

   This application is distributed in the hope that it will be useful,
   but WITHOUT ANY WARRANTY; without even the implied warranty of
   MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
   General Public License for more details.

   You should have received a copy of the GNU General Public
   License along with this application; if not, see
   <https://www.gnu.org/licenses/>.
*/

#ifndef YCODE_COMPILER_SETTINGS_H
#define YCODE_COMPILER_SETTINGS_H
#import <AppKit/AppKit.h>
@class YCodeProject;
extern NSString *YCodeCompilerSettingsDidChangeNotification;
/** Per-user compiler overrides. A nil project addresses global defaults. */
@interface YCodeCompilerSettings : NSObject
{
  YCodeProject *_project;
  NSPanel *_panel;
  NSButton *_inherit;
  NSTextField *_database;
  NSTextView *_flags;
  NSTextField *_status;
}

+ (NSString *) defaultsKeyForProject: (YCodeProject *)project;
+ (NSDictionary *) settingsForProject: (YCodeProject *)project;
+ (void) saveSettings: (NSDictionary *)settings
          forProject: (YCodeProject *)project;
+ (NSArray *) flagsFromText: (NSString *)text;
/** Resolve the source database without modifying it. */
+ (NSDictionary *) configurationForProject: (YCodeProject *)project
                               sourcePath: (NSString *)path;
/** Prepare private compiler commands with overrides, or report an error. */
+ (NSDictionary *) prepareConfiguration: (NSDictionary *)configuration;
+ (void) removePreparedConfiguration: (NSDictionary *)configuration;
+ (NSString *) noDefinitionMessageForConfiguration:
    (NSDictionary *)configuration;
- (id) initWithProject: (YCodeProject *)project;
- (void) show;
- (void) apply: (id)sender;
- (void) changeInheritance: (id)sender;
@end
#endif
