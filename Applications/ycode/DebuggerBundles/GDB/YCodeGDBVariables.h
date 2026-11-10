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

#ifndef _YCODEDEBUGGERVARIABLES_H_
#define _YCODEDEBUGGERVARIABLES_H_
#import "YCodeDebuggerBackend.h"
@class YCodeGDBDebugger;
/** Read-only, stopped-frame variables, with lazily loaded children. */
@interface YCodeGDBVariables : NSObject <YCodeDebuggerVariableSource>
{
  YCodeGDBDebugger *_debugger;
  NSMutableArray *_groups;
  NSMutableDictionary *_requests;
  NSMutableArray *_objects;
  NSUInteger _token;
  NSUInteger _generation;
  BOOL _enabled;
  BOOL _stopped;
  NSString *_file;
}

- (id) initWithDebugger: (YCodeGDBDebugger *)debugger;
- (NSArray *) groups;
- (void) setEnabled: (BOOL)enabled;
- (void) reset;
- (BOOL) handleRecord: (NSDictionary *)record;
- (void) loadChildren: (NSMutableDictionary *)node;
@end
#endif
