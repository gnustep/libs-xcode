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

#import "YCodeDebugger.h"
#import "YCodeDebuggerRegistry.h"
NSString * const YCodeDebuggerDidChangeNotification = @"YCodeDebuggerDidChangeNotification";
@implementation YCodeDebugger
- (id)init
{
  return [self initWithBackendIdentifier:nil];
}
- (id)initWithBackendIdentifier:(NSString *)identifier
{
  id backend = [[YCodeDebuggerRegistry sharedRegistry] newBackendWithIdentifier:identifier];
  self = [self initWithBackend:backend];
  [backend release];
  return self;
}
- (id)initWithBackend:(id<YCodeDebuggerBackend>)backend
{
  if ((self = [super init]))
    {
      if (!backend) { [self release]; return nil; }
      _backend = [backend retain];
      [_backend setDelegate:self];
    }
  return self;
}
- (void)dealloc
{
  [_backend setDelegate:nil]; [_backend release]; [super dealloc];
}
- (NSString *)backendIdentifier { return [[_backend class] debuggerIdentifier]; }
- (NSString *)displayName { return [[_backend class] debuggerDisplayName]; }
- (void)setDelegate:(id<YCodeDebuggerDelegate>)delegate { _delegate = delegate; }
- (id<YCodeDebuggerVariableSource>)variables { return [_backend variables]; }
- (NSString *)launchCommandForExecutable:(NSString *)executable { return [_backend launchCommandForExecutable:executable]; }
- (NSArray *)launchArgumentsForExecutable:(NSString *)executable { return [_backend launchArgumentsForExecutable:executable]; }
- (BOOL)canPerformAction:(YCodeDebuggerAction)action { return [_backend canPerformAction:action]; }
- (void)performAction:(YCodeDebuggerAction)action { [_backend performAction:action]; }
- (void)restart { [self performAction:YCodeDebuggerRestart]; }
- (void)reset { [_backend reset]; }
- (void)setBreakpointStorageKey:(NSString *)key { [_backend setBreakpointStorageKey:key]; }
- (void)setSourceDirectory:(NSString *)directory { [_backend setSourceDirectory:directory]; }
- (NSString *)executionFile { return [_backend executionFile]; }
- (NSUInteger)executionLine { return [_backend executionLine]; }
- (NSDictionary *)breakpointLinesForFile:(NSString *)file { return [_backend breakpointLinesForFile:file]; }
- (YCodeBreakpointState)breakpointStateAtFile:(NSString *)file line:(NSUInteger)line
{ return [_backend breakpointStateAtFile:file line:line]; }
- (void)toggleBreakpointEnabledAtFile:(NSString *)file line:(NSUInteger)line
{ [_backend toggleBreakpointEnabledAtFile:file line:line]; }
- (BOOL)isReady { return [_backend isReady]; }
- (BOOL)isRunning { return [_backend isRunning]; }
- (void)receiveData:(NSData *)data { [_backend receiveData:data]; }
- (void)consoleCommand:(NSString *)command { [_backend consoleCommand:command]; }
- (void)toggleBreakpointAtFile:(NSString *)file line:(NSUInteger)line
{ [_backend toggleBreakpointAtFile:file line:line]; }
- (BOOL)canSetBreakpointAtFile:(NSString *)file { return [_backend canSetBreakpointAtFile:file]; }
- (void)debuggerBackend:(id<YCodeDebuggerBackend>)backend sendCommand:(NSString *)command
{ [_delegate debugger:self sendCommand:command]; }
- (void)debuggerBackend:(id<YCodeDebuggerBackend>)backend output:(NSString *)output
{ [_delegate debugger:self output:output]; }
- (void)debuggerBackend:(id<YCodeDebuggerBackend>)backend targetOutput:(NSString *)output
{
  if ([_delegate respondsToSelector:@selector(debugger:targetOutput:)])
    [(id)_delegate debugger:self targetOutput:output];
  else [_delegate debugger:self output:output];
}
- (void)debuggerBackend:(id<YCodeDebuggerBackend>)backend stoppedAtFile:(NSString *)file line:(NSUInteger)line
{ [_delegate debugger:self stoppedAtFile:file line:line]; }
- (void)debuggerBackendDidChange:(id<YCodeDebuggerBackend>)backend
{ [[NSNotificationCenter defaultCenter] postNotificationName:YCodeDebuggerDidChangeNotification object:self]; }
@end
