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

#ifndef YCODE_GIT_CONTROLLER_H
#define YCODE_GIT_CONTROLLER_H
#import <AppKit/AppKit.h>
@class YCodeWindowController;
/** Local Git status, review, staging and commits. No network operations. */
@interface YCodeGitController
    : NSObject <NSTableViewDataSource, NSTableViewDelegate>
{
  YCodeWindowController *_owner;
  NSPanel *_panel;
  NSTableView *_table;
  NSTextView *_details;
  NSTextField *_message;
  NSTextField *_status;
  NSMutableArray *_buttons;
  NSArray *_entries;
  NSString *_directory;
  NSString *_root;
  NSString *_operation;
  NSArray *_pendingPaths;
  NSTask *_task;
  NSPipe *_pipe;
  NSMutableData *_output;
  BOOL _eof;
  BOOL _terminated;
  BOOL _cancelled;
  BOOL _truncated;
  BOOL _closed;
  int _exitStatus;
}

- (id) initWithWindowController: (YCodeWindowController *)owner;
- (void) show;
- (void) close;
- (BOOL) isBusy;
/** Decode porcelain v1 -z, including rename source paths. */
+ (NSArray *) entriesFromStatusData: (NSData *)data;
- (IBAction) refresh: (id)sender;
- (IBAction) stage: (id)sender;
- (IBAction) unstage: (id)sender;
/** Confirm and restore selected tracked paths to HEAD in the index and worktree. */
- (IBAction) revert: (id)sender;
- (IBAction) diff: (id)sender;
- (IBAction) stagedDiff: (id)sender;
- (IBAction) history: (id)sender;
- (IBAction) commit: (id)sender;
- (IBAction) openFile: (id)sender;
- (IBAction) cancel: (id)sender;
@end
#endif
