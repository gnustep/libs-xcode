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

#ifndef YCODE_GDB_DEBUGGER_H
#define YCODE_GDB_DEBUGGER_H
#import "YCodeDebuggerBackend.h"
@class YCodeGDBVariables;
/** GDB/MI session, following ProjectCenter's debugger command and event model. */
@interface YCodeGDBDebugger : NSObject <YCodeDebuggerBackend>
{
  id<YCodeDebuggerBackendDelegate> _delegate;
  NSMutableData *_pending;
  NSMutableDictionary *_breakpoints;
  NSMutableSet *_disabledBreakpoints;
  NSMutableDictionary *_resolvedLocations;
  NSString *_sourceDirectory;
  NSString *_executionFile;
  NSUInteger _executionLine;
  BOOL _ready;
  BOOL _running;
  BOOL _restartPending;
  NSString *_storageKey;
  YCodeGDBVariables *_variables;
}

- (void) setDelegate: (id<YCodeDebuggerBackendDelegate>)delegate;
- (id<YCodeDebuggerVariableSource>) variables;
- (void) notifyChange;
- (void) reset;
- (void) setBreakpointStorageKey: (NSString *)key;
- (void) setSourceDirectory: (NSString *)directory;
/** Source location of the selected stopped frame; cleared on resume or exit. */
- (NSString *) executionFile;
- (NSUInteger) executionLine;
/** Map of source line numbers to YCodeBreakpointState values for this file. */
- (NSDictionary *) breakpointLinesForFile: (NSString *)file;
- (YCodeBreakpointState) breakpointStateAtFile: (NSString *)file
                                         line: (NSUInteger)line;
- (void) toggleBreakpointEnabledAtFile: (NSString *)file line: (NSUInteger)line;
- (void) restart;
- (BOOL) isReady;
- (BOOL) isRunning;
- (void) receiveData: (NSData *)data;
- (void) command: (NSString *)command;
- (void) consoleCommand: (NSString *)command;
- (void) toggleBreakpointAtFile: (NSString *)file line: (NSUInteger)line;
/** Whether the path names a source implementation file, excluding headers. */
+ (BOOL) canSetBreakpointAtFile: (NSString *)file;
+ (NSString *) quote: (NSString *)string;
+ (NSDictionary *) parseRecord: (NSString *)record;
@end

#endif
