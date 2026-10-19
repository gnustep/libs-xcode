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

#ifndef YCODE_DEBUGGER_VARIABLES_H
#define YCODE_DEBUGGER_VARIABLES_H
#import <Foundation/Foundation.h>
/* Nodes are dictionaries with name, value, type, numchild and children keys.
 * Backends may keep additional private keys for lazy child loading. */
@protocol YCodeDebuggerVariableSource <NSObject>
- (NSArray *) groups;
- (void) setEnabled: (BOOL)enabled;
- (void) loadChildren: (NSMutableDictionary *)node;
@end
#endif
