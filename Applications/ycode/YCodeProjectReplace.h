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

#ifndef YCODE_PROJECT_REPLACE_H
#define YCODE_PROJECT_REPLACE_H
#import <AppKit/AppKit.h>
@class YCodeWindowController;
/** Preview literal project replacements and apply them as unsaved, undoable edits. */
@interface YCodeProjectReplace
    : NSObject <NSTableViewDataSource, NSTableViewDelegate,
                NSTextFieldDelegate>
{
  YCodeWindowController *_owner;
  NSPanel *_panel;
  NSTextField *_find;
  NSTextField *_replacement;
  NSButton *_caseSensitive;
  NSButton *_apply;
  NSTextField *_status;
  NSTableView *_table;
  NSTextView *_details;
  NSMutableArray *_changes;
}

- (id) initWithWindowController: (YCodeWindowController *)owner;
- (void) show;
- (void) close;
- (IBAction) preview: (id)sender;
- (IBAction) apply: (id)sender;
@end
#endif
