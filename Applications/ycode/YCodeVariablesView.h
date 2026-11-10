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

#ifndef _YCODEVARIABLESVIEW_H_
#define _YCODEVARIABLESVIEW_H_
#import <AppKit/AppKit.h>
@class YCodeDebugger;
/** Vertical variables/transcript split for the debugger tab. */
@interface YCodeVariablesView : NSSplitView
{
  NSOutlineView *_outline;
  NSScrollView *_variablesScroll;
  NSScrollView *_transcriptScroll;
  YCodeDebugger *_debugger;
  BOOL _variablesVisible;
  BOOL _layingOut;
  CGFloat _fraction;
}

- (id) initWithFrame: (NSRect)frame transcript: (NSScrollView *)transcript;
- (void) setDebugger: (YCodeDebugger *)debugger;
- (BOOL) variablesVisible;
- (IBAction) toggleVariables: (id)sender;
@end
#endif
