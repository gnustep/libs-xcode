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

#ifndef YCODE_CODE_BROWSER_H
#define YCODE_CODE_BROWSER_H
#import <AppKit/AppKit.h>
/** Searchable, modeless locations and completion results. Items carry a title and optional detail. */
@interface YCodeCodeBrowser
    : NSObject <NSTableViewDataSource, NSTableViewDelegate,
                NSTextFieldDelegate>
{
  NSPanel *_panel;
  NSTextField *_filter;
  NSTableView *_table;
  NSTextView *_details;
  NSArray *_items;
  NSMutableArray *_visibleItems;
  id _target;
}

- (id) initWithTarget: (id)target;
- (void) showItems: (NSArray *)items title: (NSString *)title;
- (void) updateItems: (NSArray *)items;
- (BOOL) isShowingTitle: (NSString *)title;
- (void) close;
@end
@interface NSObject (YCodeCodeBrowserTarget)
- (void) activateCodeItem: (NSDictionary *)item;
@end
#endif
