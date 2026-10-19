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

#import "YCodeVariablesView.h"
#import "YCodeDebugger.h"
#import "YCodeDebuggerVariables.h"
#import "YCodeControlIcons.h"
#include <math.h>

@implementation YCodeVariablesView
- (id) initWithFrame: (NSRect)frame transcript: (NSScrollView *)transcript
{
  if ((self = [super initWithFrame: frame]))
    {
      NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
      _fraction = [defaults doubleForKey: @"YCodeDebuggerVariablesFraction"];
      if (!isfinite (_fraction) || _fraction < 0.1 || _fraction > 0.9)
        _fraction = 0.45;
      _variablesVisible
          = ![defaults boolForKey: @"YCodeDebuggerVariablesHidden"];
      [self setVertical: YES];
      [self setAutoresizingMask: NSViewWidthSizable | NSViewHeightSizable];
      _variablesScroll = [[NSScrollView alloc] initWithFrame: [self bounds]];
      [_variablesScroll setHasVerticalScroller: YES];
      [_variablesScroll setHasHorizontalScroller: YES];
      [_variablesScroll setAutohidesScrollers: YES];
      _outline = [[NSOutlineView alloc] initWithFrame: [self bounds]];
      NSArray *names =
          [NSArray arrayWithObjects: @"Name", @"Value", @"Type", nil];
      NSArray *keys =
          [NSArray arrayWithObjects: @"name", @"value", @"type", nil];
      NSUInteger i;
      for (i = 0; i < [keys count]; i++)
        {
          NSTableColumn *column = [[NSTableColumn alloc]
              initWithIdentifier: [keys objectAtIndex: i]];
          [[column headerCell] setStringValue: [names objectAtIndex: i]];
          [column setWidth: i == 1 ? 260 : 180];
          [column setEditable: NO];
          [_outline addTableColumn: column];
          if (i == 0)
            [_outline setOutlineTableColumn: column];
          RELEASE (column);
        }
      [_outline setGridStyleMask: NSTableViewGridNone];
      [_outline setAutoresizesAllColumnsToFit: YES];
      [_outline setDataSource: self];
      [_outline setDelegate: self];
      [_outline
          setToolTip:
              @"Variables in the paused frame. Expand a value to inspect its children. Globals are scoped to the current source file."];
      [_variablesScroll setDocumentView: _outline];
      _transcriptScroll = RETAIN (transcript);
      [self addSubview: _variablesScroll];
      [self addSubview: _transcriptScroll];
      [self setDelegate: self];
      [self layoutPanes];
      [[NSNotificationCenter defaultCenter]
          addObserver: self
             selector: @selector (variablesChanged:)
                 name: YCodeDebuggerDidChangeNotification
               object: nil];
    }
  return self;
}

- (void) dealloc
{
  [[NSNotificationCenter defaultCenter] removeObserver: self];
  [_outline setDataSource: nil];
  [_outline setDelegate: nil];
  [self setDelegate: nil];
  RELEASE (_debugger);
  RELEASE (_outline);
  RELEASE (_variablesScroll);
  RELEASE (_transcriptScroll);
  [super dealloc];
}

- (void) setDebugger: (YCodeDebugger *)debugger
{
  if (_debugger == debugger)
    return;
  [[_debugger variables] setEnabled: NO];
  ASSIGN (_debugger, debugger);
  [[_debugger variables] setEnabled: _variablesVisible];
  [self variablesChanged: nil];
}

- (BOOL) variablesVisible
{
  return _variablesVisible;
}

- (void) drawDividerInRect: (NSRect)rect
{
  if (_variablesVisible)
    [super drawDividerInRect: rect];
}

- (void) mouseDown: (NSEvent *)event
{
  if (_variablesVisible)
    [super mouseDown: event];
}

- (void) resetCursorRects
{
  if (_variablesVisible)
    [super resetCursorRects];
}

- (void) layoutPanes
{
  _layingOut = YES;
  CGFloat width = NSWidth ([self bounds]);
  CGFloat height = NSHeight ([self bounds]);
  CGFloat divider = _variablesVisible ? [self dividerThickness] : 0;
  CGFloat left = _variablesVisible ? MAX (0, width - divider) * _fraction : 0;
  [_variablesScroll setHidden: !_variablesVisible];
  [_variablesScroll setFrame: NSMakeRect (0, 0, left, height)];
  if (_variablesVisible)
    [_outline sizeToFit];
  [_transcriptScroll
      setFrame: NSMakeRect (left + divider, 0, MAX (0, width - left - divider),
                           height)];
  _layingOut = NO;
}

- (void) splitView: (NSSplitView *)split resizeSubviewsWithOldSize: (NSSize)size
{
  [self layoutPanes];
}

- (void) splitViewDidResizeSubviews: (NSNotification *)notification
{
  if (_layingOut || !_variablesVisible)
    return;
  CGFloat available = NSWidth ([self bounds]) - [self dividerThickness];
  if (available <= 0)
    return;
  CGFloat fraction = NSWidth ([_variablesScroll frame]) / available;
  if (fraction < 0.1 || fraction > 0.9)
    return;
  _fraction = fraction;
  [[NSUserDefaults standardUserDefaults]
      setDouble: _fraction
         forKey: @"YCodeDebuggerVariablesFraction"];
  [[NSUserDefaults standardUserDefaults] synchronize];
}

- (void) setPosition: (CGFloat)position ofDividerAtIndex: (NSInteger)index
{
  [super setPosition: position ofDividerAtIndex: index];
  // GNUstep's programmatic setter does not post the resize notification.
  [self splitViewDidResizeSubviews: nil];
}

- (CGFloat) splitView: (NSSplitView *)split
    constrainMinCoordinate: (CGFloat)proposed
               ofSubviewAt: (NSInteger)index
{
  return NSWidth ([self bounds]) * 0.1;
}

- (CGFloat) splitView: (NSSplitView *)split
    constrainMaxCoordinate: (CGFloat)proposed
               ofSubviewAt: (NSInteger)index
{
  return NSWidth ([self bounds]) * 0.9;
}

- (BOOL) splitView: (NSSplitView *)split
    shouldHideDividerAtIndex: (NSInteger)index
{
  return !_variablesVisible;
}

- (IBAction) toggleVariables: (id)sender
{
  _variablesVisible = !_variablesVisible;
  [[NSUserDefaults standardUserDefaults]
      setBool: !_variablesVisible
       forKey: @"YCodeDebuggerVariablesHidden"];
  [[NSUserDefaults standardUserDefaults] synchronize];
  [self layoutPanes];
  [[_debugger variables] setEnabled: _variablesVisible];
  [sender setImage: YCodeControlIcon (_variablesVisible ? @"variablesHide"
                                                       : @"variablesShow",
                                     20)];
  [sender
      setToolTip: _variablesVisible ? @"Hide variables" : @"Show variables"];
  [self setNeedsDisplay: YES];
  [[self window] invalidateCursorRectsForView: self];
}

- (void) variablesChanged: (NSNotification *)notification
{
  if (notification && [notification object] != _debugger)
    return;
  [_outline reloadData];
  NSEnumerator *groups = [[[_debugger variables] groups] objectEnumerator];
  id group;
  while ((group = [groups nextObject]) != nil)
    [_outline expandItem: group];
}

- (NSInteger) outlineView: (NSOutlineView *)outline
    numberOfChildrenOfItem: (id)item
{
  return item ? [[item objectForKey: @"children"] count]
              : [[[_debugger variables] groups] count];
}

- (id) outlineView: (NSOutlineView *)outline
            child: (NSInteger)index
           ofItem: (id)item
{
  return [(item ? [item objectForKey: @"children"]
                : [[_debugger variables] groups]) objectAtIndex: index];
}

- (BOOL) outlineView: (NSOutlineView *)outline isItemExpandable: (id)item
{
  return [[item objectForKey: @"children"] count] > 0 ||
         [[item objectForKey: @"numchild"] integerValue] > 0;
}

- (id) outlineView: (NSOutlineView *)outline
    objectValueForTableColumn: (NSTableColumn *)column
                       byItem: (id)item
{
  return [item objectForKey: [column identifier]] ?: @"";
}

- (BOOL) outlineView: (NSOutlineView *)outline shouldExpandItem: (id)item
{
  [[_debugger variables] loadChildren: item];
  return YES;
}

@end
