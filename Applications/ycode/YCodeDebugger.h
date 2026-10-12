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
#import <Foundation/Foundation.h>

@class YCodeDebugger;
@protocol YCodeDebuggerDelegate <NSObject>
- (void)debugger:(YCodeDebugger *)debugger sendCommand:(NSString *)command;
- (void)debugger:(YCodeDebugger *)debugger output:(NSString *)output;
- (void)debugger:(YCodeDebugger *)debugger stoppedAtFile:(NSString *)file line:(NSUInteger)line;
@end

/** GDB/MI session, following ProjectCenter's debugger command and event model. */
@interface YCodeDebugger : NSObject
{
  id<YCodeDebuggerDelegate> _delegate;
  NSMutableData *_pending;
  NSMutableDictionary *_breakpoints;
  BOOL _ready;
  BOOL _running;
  BOOL _restartPending;
  NSString *_storageKey;
}
- (void)setDelegate:(id<YCodeDebuggerDelegate>)delegate;
- (void)reset;
- (void)setBreakpointStorageKey:(NSString *)key;
- (void)restart;
- (BOOL)isReady;
- (BOOL)isRunning;
- (void)receiveData:(NSData *)data;
- (void)command:(NSString *)command;
- (void)consoleCommand:(NSString *)command;
- (void)toggleBreakpointAtFile:(NSString *)file line:(NSUInteger)line;
+ (NSString *)quote:(NSString *)string;
+ (NSDictionary *)parseRecord:(NSString *)record;
@end
#endif
