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

#import "YCodeCodeBrowser.h"
@implementation YCodeCodeBrowser
- (id) initWithTarget: (id)target
{
  if ((self = [super init]))
    {
      _target = target;
      _visibleItems = [NSMutableArray new];
      _panel = [[NSPanel alloc]
          initWithContentRect: NSMakeRect (160, 180, 640, 440)
                    styleMask: NSTitledWindowMask | NSClosableWindowMask
                              | NSResizableWindowMask
                      backing: NSBackingStoreBuffered
                        defer: NO];
      [_panel setReleasedWhenClosed: NO];
      [_panel setMinSize: NSMakeSize (420, 320)];
      NSView *content = [_panel contentView];
      _filter =
          [[NSTextField alloc] initWithFrame: NSMakeRect (12, 402, 616, 26)];
      [_filter setAutoresizingMask: NSViewWidthSizable | NSViewMinYMargin];
      [_filter
          setToolTip:
              @"Filter results by name or path. Press Return to open the selected result."];
      [_filter setDelegate: self];
      [_filter setTarget: self];
      [_filter setAction: @selector (activate:)];
      [content addSubview: _filter];
      NSScrollView *scroll = AUTORELEASE (
          [[NSScrollView alloc] initWithFrame: NSMakeRect (12, 146, 616, 246)]);
      [scroll setHasVerticalScroller: YES];
      [scroll setAutoresizingMask: NSViewWidthSizable | NSViewHeightSizable];
      _table = [[NSTableView alloc] initWithFrame: [scroll bounds]];
      NSTableColumn *column
          = AUTORELEASE ([[NSTableColumn alloc] initWithIdentifier: @"title"]);
      [column setWidth: 590];
      [_table addTableColumn: column];
      [_table setHeaderView: nil];
      [_table setDataSource: self];
      [_table setDelegate: self];
      [_table setTarget: self];
      [_table setDoubleAction: @selector (activate:)];
      [scroll setDocumentView: _table];
      [content addSubview: scroll];
      NSScrollView *detailsScroll = AUTORELEASE (
          [[NSScrollView alloc] initWithFrame: NSMakeRect (12, 12, 616, 122)]);
      [detailsScroll setHasVerticalScroller: YES];
      [detailsScroll setAutoresizingMask: NSViewWidthSizable];
      _details = [[NSTextView alloc] initWithFrame: [detailsScroll bounds]];
      [_details setEditable: NO];
      [_details setFont: [NSFont userFixedPitchFontOfSize: 12]];
      [_details setAutoresizingMask: NSViewWidthSizable];
      [[_details textContainer] setWidthTracksTextView: YES];
      [detailsScroll setDocumentView: _details];
      [content addSubview: detailsScroll];
    }
  return self;
}

- (void) dealloc
{
  [_table setDataSource: nil];
  [_table setDelegate: nil];
  [_filter setDelegate: nil];
  [_panel close];
  RELEASE (_panel);
  RELEASE (_filter);
  RELEASE (_table);
  RELEASE (_details);
  RELEASE (_items);
  RELEASE (_visibleItems);
  [super dealloc];
}

- (void) filterItems
{
  [_visibleItems removeAllObjects];
  NSString *query = [_filter stringValue];
  NSEnumerator *enumerator = [_items objectEnumerator];
  NSDictionary *item;
  while ((item = [enumerator nextObject]))
    {
      NSString *title = [item objectForKey: @"title"];
      if ([title isKindOfClass: [NSString class]]
          && (![query length] ||
              [title rangeOfString: query options: NSCaseInsensitiveSearch]
                      .location
                  != NSNotFound))
        [_visibleItems addObject: item];
    }
  [_table reloadData];
  if ([_visibleItems count])
    [_table selectRowIndexes: [NSIndexSet indexSetWithIndex: 0]
        byExtendingSelection: NO];
  [self tableViewSelectionDidChange: nil];
}

- (void) controlTextDidChange: (NSNotification *)notification
{
  [self filterItems];
}

- (void) showItems: (NSArray *)items title: (NSString *)title
{
  [_panel setTitle: title];
  [_filter setStringValue: @""];
  [self updateItems: items];
  [_panel makeKeyAndOrderFront: nil];
  [_panel makeFirstResponder: _filter];
}

- (void) updateItems: (NSArray *)items
{
  ASSIGN (_items, items);
  [self filterItems];
}

- (BOOL) isShowingTitle: (NSString *)title
{
  return [_panel isVisible] && [[_panel title] isEqual: title];
}

- (NSInteger) numberOfRowsInTableView: (NSTableView *)tableView
{
  return [_visibleItems count];
}

- (id) tableView: (NSTableView *)tableView
    objectValueForTableColumn: (NSTableColumn *)column
                          row: (NSInteger)row
{
  return [[_visibleItems objectAtIndex: row] objectForKey: @"title"];
}

- (void) tableViewSelectionDidChange: (NSNotification *)notification
{
  NSInteger row = [_table selectedRow];
  NSDictionary *item = row >= 0 && row < (NSInteger)[_visibleItems count]
                           ? [_visibleItems objectAtIndex: row]
                           : nil;
  [_details setString: [item objectForKey: @"detail"] ?: [item objectForKey: @"title"] ?: @"No results."];
}

- (void) activate: (id)sender
{
  NSInteger row = [_table selectedRow];
  if (row >= 0 && row < (NSInteger)[_visibleItems count])
    [_target activateCodeItem: [_visibleItems objectAtIndex: row]];
}

- (void) close
{
  [_panel orderOut: nil];
}

@end
