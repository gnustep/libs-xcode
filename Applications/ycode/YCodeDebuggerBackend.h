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

#ifndef YCODE_DEBUGGER_BACKEND_H
#define YCODE_DEBUGGER_BACKEND_H
#import <Foundation/Foundation.h>
#import "YCodeDebuggerVariables.h"
#define YCodeDebuggerBackendAPIVersion 1

typedef enum {
  YCodeBreakpointNone,
  YCodeBreakpointEnabled,
  YCodeBreakpointInactive
} YCodeBreakpointState;

/* Values 0..8 also identify the existing toolbar buttons. */
typedef enum {
  YCodeDebuggerRun, YCodeDebuggerPause, YCodeDebuggerContinue,
  YCodeDebuggerRestart, YCodeDebuggerNext, YCodeDebuggerStep,
  YCodeDebuggerFinish, YCodeDebuggerFrameUp, YCodeDebuggerFrameDown,
  YCodeDebuggerStop
} YCodeDebuggerAction;

@protocol YCodeDebuggerBackend;
@protocol YCodeDebuggerBackendDelegate <NSObject>
- (void)debuggerBackend:(id<YCodeDebuggerBackend>)backend sendCommand:(NSString *)command;
- (void)debuggerBackend:(id<YCodeDebuggerBackend>)backend output:(NSString *)output;
- (void)debuggerBackend:(id<YCodeDebuggerBackend>)backend targetOutput:(NSString *)output;
- (void)debuggerBackend:(id<YCodeDebuggerBackend>)backend stoppedAtFile:(NSString *)file line:(NSUInteger)line;
- (void)debuggerBackendDidChange:(id<YCodeDebuggerBackend>)backend;
@end

/* Principal class of a debugger bundle. Instances are independent sessions.
 * Only Foundation is required; callbacks occur on the main thread. */
@protocol YCodeDebuggerBackend <NSObject>
+ (NSUInteger)debuggerAPIVersion;
+ (NSString *)debuggerIdentifier;
+ (NSString *)debuggerDisplayName;
- (void)setDelegate:(id<YCodeDebuggerBackendDelegate>)delegate;
- (NSString *)launchCommandForExecutable:(NSString *)executable;
- (NSArray *)launchArgumentsForExecutable:(NSString *)executable;
- (BOOL)canPerformAction:(YCodeDebuggerAction)action;
- (void)performAction:(YCodeDebuggerAction)action;
- (void)consoleCommand:(NSString *)command;
- (void)receiveData:(NSData *)data;
- (void)reset;
- (BOOL)isReady;
- (BOOL)isRunning;
- (void)setSourceDirectory:(NSString *)directory;
- (void)setBreakpointStorageKey:(NSString *)key;
- (BOOL)canSetBreakpointAtFile:(NSString *)file;
- (NSDictionary *)breakpointLinesForFile:(NSString *)file;
- (YCodeBreakpointState)breakpointStateAtFile:(NSString *)file line:(NSUInteger)line;
- (void)toggleBreakpointAtFile:(NSString *)file line:(NSUInteger)line;
- (void)toggleBreakpointEnabledAtFile:(NSString *)file line:(NSUInteger)line;
- (NSString *)executionFile;
- (NSUInteger)executionLine;
/* Return nil if this backend does not expose variables. */
- (id<YCodeDebuggerVariableSource>)variables;
@end
#endif
