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

#ifndef _YCODEDEBUGGER_H_
#define _YCODEDEBUGGER_H_
#import "YCodeDebuggerBackend.h"

@class YCodeDebugger;
extern NSString *const YCodeDebuggerDidChangeNotification;
@protocol YCodeDebuggerDelegate <NSObject>
- (void) debugger: (YCodeDebugger *)debugger sendCommand: (NSString *)command;
- (void) debugger: (YCodeDebugger *)debugger output: (NSString *)output;
- (void) debugger: (YCodeDebugger *)debugger
    stoppedAtFile: (NSString *)file
             line: (NSUInteger)line;
@end
@interface NSObject (YCodeDebuggerDelegateOptional)
- (void) debugger: (YCodeDebugger *)debugger targetOutput: (NSString *)output;
@end

/** Backend-neutral debugger session. Transport and UI stay in the application. */
@interface YCodeDebugger : NSObject <YCodeDebuggerBackendDelegate>
{
  id<YCodeDebuggerDelegate> _delegate;
  id<YCodeDebuggerBackend> _backend;
}

- (id) initWithBackendIdentifier: (NSString *)identifier;
- (id) initWithBackend: (id<YCodeDebuggerBackend>)backend;
- (NSString *) backendIdentifier;
- (NSString *) displayName;
- (void) setDelegate: (id<YCodeDebuggerDelegate>)delegate;
- (id<YCodeDebuggerVariableSource>) variables;
- (NSString *) launchCommandForExecutable: (NSString *)executable;
- (NSArray *) launchArgumentsForExecutable: (NSString *)executable;
- (BOOL) canPerformAction: (YCodeDebuggerAction)action;
- (void) performAction: (YCodeDebuggerAction)action;
- (void) restart;
- (void) reset;
- (void) setBreakpointStorageKey: (NSString *)key;
- (void) setSourceDirectory: (NSString *)directory;
- (NSString *) executionFile;
- (NSUInteger) executionLine;
- (NSDictionary *) breakpointLinesForFile: (NSString *)file;
- (YCodeBreakpointState) breakpointStateAtFile: (NSString *)file
                                         line: (NSUInteger)line;
- (void) toggleBreakpointEnabledAtFile: (NSString *)file line: (NSUInteger)line;
- (BOOL) isReady;
- (BOOL) isRunning;
- (void) receiveData: (NSData *)data;
- (void) consoleCommand: (NSString *)command;
- (void) toggleBreakpointAtFile: (NSString *)file line: (NSUInteger)line;
- (BOOL) canSetBreakpointAtFile: (NSString *)file;
@end
#endif
