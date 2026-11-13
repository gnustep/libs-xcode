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

#import "YCodeProjectReplace.h"
#import "YCodeWindowController.h"
#import "YCodeEditorController.h"
#import "YCodeEditorDocument.h"
#import "YCodeProject.h"

@implementation YCodeProjectReplace
- (id) initWithWindowController: (YCodeWindowController *)owner
{
  if ((self = [super init]))
    {
      _owner = owner;
      _changes = [NSMutableArray new];
      _panel = [[NSPanel alloc]
          initWithContentRect: NSMakeRect (160, 180, 760, 580)
                    styleMask: NSTitledWindowMask | NSClosableWindowMask
                              | NSResizableWindowMask
                      backing: NSBackingStoreBuffered
                        defer: NO];
      [_panel setReleasedWhenClosed: NO];
      [_panel setTitle: @"Replace in Project"];
      [_panel setMinSize: NSMakeSize (660, 480)];
      NSView *content = [_panel contentView];
      NSUInteger i;
      for (i = 0; i < 2; i++)
        {
          NSTextField *label = AUTORELEASE ([[NSTextField alloc]
              initWithFrame: NSMakeRect (12, 538 - i * 34, 90, 24)]);
          [label setStringValue: i ? @"Replace with:" : @"Find:"];
          [label setEditable: NO];
          [label setSelectable: NO];
          [label setBezeled: NO];
          [label setDrawsBackground: NO];
          [label setAutoresizingMask: NSViewMinYMargin];
          [content addSubview: label];
          NSTextField *field = [[NSTextField alloc]
              initWithFrame: NSMakeRect (108, 538 - i * 34, 640, 26)];
          [field setAutoresizingMask: NSViewWidthSizable | NSViewMinYMargin];
          [field setDelegate: self];
          [field setTarget: self];
          [field setAction: @selector (preview:)];
          [content addSubview: field];
          if (i)
            _replacement = field;
          else
            _find = field;
        }
      _caseSensitive =
          [[NSButton alloc] initWithFrame: NSMakeRect (12, 468, 170, 26)];
      [_caseSensitive setButtonType: NSSwitchButton];
      [_caseSensitive setTitle: @"Case sensitive"];
      [_caseSensitive setTarget: self];
      [_caseSensitive setAction: @selector (invalidate:)];
      [_caseSensitive setAutoresizingMask: NSViewMinYMargin];
      [content addSubview: _caseSensitive];
      NSButton *preview = AUTORELEASE (
          [[NSButton alloc] initWithFrame: NSMakeRect (420, 468, 120, 28)]);
      [preview setTitle: @"Preview"];
      [preview setBezelStyle: NSRoundedBezelStyle];
      [preview setTarget: self];
      [preview setAction: @selector (preview:)];
      [preview setAutoresizingMask: NSViewMinXMargin | NSViewMinYMargin];
      [content addSubview: preview];
      _apply = [[NSButton alloc] initWithFrame: NSMakeRect (548, 468, 200, 28)];
      [_apply setTitle: @"Apply to Editors"];
      [_apply setBezelStyle: NSRoundedBezelStyle];
      [_apply setTarget: self];
      [_apply setAction: @selector (apply:)];
      [_apply setEnabled: NO];
      [_apply setAutoresizingMask: NSViewMinXMargin | NSViewMinYMargin];
      [content addSubview: _apply];
      NSScrollView *scroll = AUTORELEASE (
          [[NSScrollView alloc] initWithFrame: NSMakeRect (12, 270, 736, 190)]);
      [scroll setHasVerticalScroller: YES];
      [scroll setHasHorizontalScroller: YES];
      [scroll setAutoresizingMask: NSViewWidthSizable | NSViewMinYMargin];
      _table = [[NSTableView alloc] initWithFrame: [scroll bounds]];
      NSTableColumn *include = AUTORELEASE (
          [[NSTableColumn alloc] initWithIdentifier: @"include"]);
      [include setWidth: 44];
      [[include headerCell] setStringValue: @"Apply"];
      NSButtonCell *cell = AUTORELEASE ([NSButtonCell new]);
      [cell setButtonType: NSSwitchButton];
      [cell setTitle: @""];
      [include setDataCell: cell];
      [include setEditable: YES];
      [_table addTableColumn: include];
      NSTableColumn *file
          = AUTORELEASE ([[NSTableColumn alloc] initWithIdentifier: @"file"]);
      [file setWidth: 665];
      [file setEditable: NO];
      [[file headerCell] setStringValue: @"File and replacement count"];
      [_table addTableColumn: file];
      [_table setDataSource: self];
      [_table setDelegate: self];
      [scroll setDocumentView: _table];
      [content addSubview: scroll];
      scroll = AUTORELEASE (
          [[NSScrollView alloc] initWithFrame: NSMakeRect (12, 62, 736, 198)]);
      [scroll setHasVerticalScroller: YES];
      [scroll setAutoresizingMask: NSViewWidthSizable | NSViewHeightSizable];
      _details = [[NSTextView alloc] initWithFrame: [scroll bounds]];
      [_details setEditable: NO];
      [_details setFont: [NSFont userFixedPitchFontOfSize: 12]];
      [_details setAutoresizingMask: NSViewWidthSizable];
      [scroll setDocumentView: _details];
      [content addSubview: scroll];
      _status =
          [[NSTextField alloc] initWithFrame: NSMakeRect (12, 8, 736, 46)];
      [_status setEditable: NO];
      [_status setSelectable: NO];
      [_status setBezeled: NO];
      [_status setDrawsBackground: NO];
      [_status setAutoresizingMask: NSViewWidthSizable];
      [_status
          setStringValue:
              @"Preview first. Changes remain unsaved in editor tabs; undo is available per file."];
      [content addSubview: _status];
      [_panel setInitialFirstResponder: _find];
    }
  return self;
}

- (void) dealloc
{
  [_panel close];
  [_table setDelegate: nil];
  [_table setDataSource: nil];
  [_find setDelegate: nil];
  [_replacement setDelegate: nil];
  [_panel release];
  [_find release];
  [_replacement release];
  [_caseSensitive release];
  [_apply release];
  [_status release];
  [_table release];
  [_details release];
  [_changes release];
  [super dealloc];
}

- (void) show
{
  [_panel makeKeyAndOrderFront: nil];
}

- (void) close
{
  [_panel close];
}

- (void) invalidate: (id)sender
{
  [_changes removeAllObjects];
  [_table reloadData];
  [_details setString: @""];
  [_apply setEnabled: NO];
  [_status setStringValue: @"Preview the new search before applying changes."];
}

- (void) controlTextDidChange: (NSNotification *)notification
{
  [self invalidate: nil];
}

- (NSString *) textAtPath: (NSString *)path
{
  YCodeEditorDocument *document =
      [[_owner editorController] documentForFilePath: path];
  if (document)
    return [document isEditable] && [document textView] ? [document content]
                                                        : nil;
  NSStringEncoding encoding;
  NSString *text = [NSString stringWithContentsOfFile: path
                                         usedEncoding: &encoding
                                                error: NULL];
  if (!text)
    return nil;
  if ([text rangeOfString: [NSString stringWithFormat: @"%C", (unichar)0]]
          .location
      != NSNotFound)
    return nil;
  return text;
}

- (IBAction) preview: (id)sender
{
  [self invalidate: nil];
  NSString *needle = [_find stringValue];
  if (![needle length])
    {
      [_status setStringValue: @"Enter text to find."];
      return;
    }
  NSUInteger options =
      [_caseSensitive state] == NSOnState ? 0 : NSCaseInsensitiveSearch;
  NSEnumerator *paths = [[_owner projectSearchPaths] objectEnumerator];
  NSString *path;
  NSUInteger total = 0;
  while ((path = [paths nextObject]) != nil)
    {
      NSArray *components = [path pathComponents];
      if ([components containsObject: @".git"] ||
          [components containsObject: @".svn"] ||
          [components containsObject: @".hg"])
        continue;
      NSString *before = [self textAtPath: path];
      if (!before)
        continue;
      NSMutableString *after = [NSMutableString stringWithString: before];
      NSUInteger count =
          [after replaceOccurrencesOfString: needle
                                 withString: [_replacement stringValue]
                                    options: options
                                      range: NSMakeRange (0, [after length])];
      if (!count || [after isEqual: before])
        continue;
      [_changes addObject: [NSMutableDictionary
                              dictionaryWithObjectsAndKeys:
                                  path, @"path", [[before copy] autorelease],
                                  @"before", after, @"after",
                                  [NSNumber numberWithUnsignedInteger: count],
                                  @"count", [NSNumber numberWithBool: YES],
                                  @"include", nil]];
      total += count;
    }
  [_table reloadData];
  [_apply setEnabled: [_changes count] > 0];
  [_status
      setStringValue:
          [NSString
              stringWithFormat:
                  @"%lu replacements in %lu files. Uncheck files to exclude them. Applying leaves changes unsaved.",
                  (unsigned long)total, (unsigned long)[_changes count]]];
  if ([_changes count])
    [_table selectRowIndexes: [NSIndexSet indexSetWithIndex: 0]
        byExtendingSelection: NO];
}

- (IBAction) apply: (id)sender
{
  NSMutableArray *selected = [NSMutableArray array];
  NSEnumerator *enumerator = [_changes objectEnumerator];
  NSDictionary *change;
  while ((change = [enumerator nextObject]) != nil)
    if ([[change objectForKey: @"include"] boolValue])
      [selected addObject: change];
  if (![selected count])
    {
      [_status setStringValue: @"Select at least one file."];
      return;
    }
  /* Validate the whole preview before changing any buffer. Opening files can
     fail or select a non-text editor, so preflight those as well. */
  YCodeEditorController *editor = [_owner editorController];
  enumerator = [selected objectEnumerator];
  while ((change = [enumerator nextObject]) != nil)
    {
      NSString *path = [change objectForKey: @"path"];
      if (![[self textAtPath: path] isEqual: [change objectForKey: @"before"]]
          || ![editor openFile: path])
        {
          [_apply setEnabled: NO];
          [_status
              setStringValue:
                  @"A file changed or could not be opened. Preview again; no replacements were applied."];
          return;
        }
      YCodeEditorDocument *document = [editor documentForFilePath: path];
      NSTextView *view = [document textView];
      [document checkForExternalChanges];
      if (!view || ![view isEditable] || [document hasExternalChanges]
          || ![[document content] isEqual: [change objectForKey: @"before"]])
        {
          [_apply setEnabled: NO];
          [_status
              setStringValue:
                  @"A file changed, has a disk conflict, or is not editable. Resolve it and preview again; no replacements were applied."];
          return;
        }
    }
  NSUInteger count = 0;
  enumerator = [selected objectEnumerator];
  while ((change = [enumerator nextObject]) != nil)
    {
      NSTextView *view = [[editor
          documentForFilePath: [change objectForKey: @"path"]] textView];
      NSRange range = NSMakeRange (0, [[view string] length]);
      NSUndoManager *undo = [view undoManager];
      [undo beginUndoGrouping];
      if ([view shouldChangeTextInRange: range
                      replacementString: [change objectForKey: @"after"]])
        {
          [[view textStorage]
              replaceCharactersInRange: range
                            withString: [change objectForKey: @"after"]];
          [view setSelectedRange: NSMakeRange (0, 0)];
          [view didChangeText];
          [undo setActionName: @"Replace in Project"];
          count++;
        }
      [undo endUndoGrouping];
    }
  [_apply setEnabled: NO];
  [_changes removeAllObjects];
  [_table reloadData];
  [_details setString: @""];
  [_status
      setStringValue:
          [NSString
              stringWithFormat:
                  @"Changed %lu of %lu selected files in editor tabs. Save when ready; undo is available in each file.",
                  (unsigned long)count, (unsigned long)[selected count]]];
}

- (NSInteger) numberOfRowsInTableView: (NSTableView *)table
{
  return [_changes count];
}

- (id) tableView: (NSTableView *)table
    objectValueForTableColumn: (NSTableColumn *)column
                          row: (NSInteger)row
{
  NSDictionary *change = [_changes objectAtIndex: row];
  if ([[column identifier] isEqual: @"include"])
    return [change objectForKey: @"include"];
  NSString *path = [change objectForKey: @"path"];
  NSString *prefix =
      [[[_owner project] projectDirectoryPath] stringByAppendingString: @"/"];
  if ([path hasPrefix: prefix])
    path = [path substringFromIndex: [prefix length]];
  return [NSString
      stringWithFormat: @"%@ — %@", path, [change objectForKey: @"count"]];
}

- (void) tableView: (NSTableView *)table
    setObjectValue: (id)value
    forTableColumn: (NSTableColumn *)column
               row: (NSInteger)row
{
  if ([[column identifier] isEqual: @"include"])
    [[_changes objectAtIndex: row] setObject: value forKey: @"include"];
}

- (void) tableViewSelectionDidChange: (NSNotification *)notification
{
  NSInteger row = [_table selectedRow];
  if (row < 0 || row >= (NSInteger)[_changes count])
    {
      [_details setString: @""];
      return;
    }
  NSDictionary *change = [_changes objectAtIndex: row];
  [_details
      setString: [NSString stringWithFormat: @"BEFORE\n%@\n\nAFTER\n%@",
                                           [change objectForKey: @"before"],
                                           [change objectForKey: @"after"]]];
}

@end
