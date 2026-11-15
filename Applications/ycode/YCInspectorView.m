/*
   Project: Ycode

   Copyright (C) 2018 Free Software Foundation

   Author: Gregory John Casamento,,,

   Created: 2018-12-17 20:16:45 -0500 by heron

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

#import "YCInspectorView.h"

@implementation YCInspectorView

- (NSString *) inspectorIdentifier
{
  return NSStringFromClass ([self class]);
}

- (NSString *) inspectorTitle
{
  return [self inspectorIdentifier];
}

- (void) inspectDocument: (YCodeEditorDocument *)document
{
}

@end

#import "YCodeEditorDocument.h"
/* Keep fixed-size bundle controls at the top even when the sidebar is taller
 * than the supplied inspector, without changing the bundle's coordinates. */
@interface YCEditorInspectorContainer : NSView
@end

@implementation YCEditorInspectorContainer
- (BOOL) isFlipped
{
  return YES;
}

@end

@implementation YCEditorInspectorView
- (id) initWithFrame: (NSRect)frame
{
  self = [super initWithFrame: frame];
  if (self)
    {
      _scroll = [[NSScrollView alloc] initWithFrame: [self bounds]];
      [_scroll setHasVerticalScroller: YES];
      [_scroll setHasHorizontalScroller: YES];
      [_scroll setAutoresizingMask: NSViewWidthSizable | NSViewHeightSizable];
      [self addSubview: _scroll];
    }
  return self;
}

- (void) dealloc
{
  [_scroll release];
  [super dealloc];
}

- (NSString *) inspectorIdentifier
{
  return @"editor";
}

- (NSString *) inspectorTitle
{
  return @"Interface";
}

- (void) inspectDocument: (YCodeEditorDocument *)document
{
  NSView *view = [document inspectorView];
  if ([[[_scroll documentView] subviews] lastObject] != view)
    {
      if (view)
        {
          NSView *container = [[YCEditorInspectorContainer alloc]
              initWithFrame: NSMakeRect (0, 0, NSWidth ([view frame]),
                                        NSHeight ([view frame]))];
          [view setFrameOrigin: NSZeroPoint];
          [container addSubview: view];
          [_scroll setDocumentView: container];
          [container release];
          [[_scroll contentView] scrollToPoint: NSZeroPoint];
        }
      else
        [_scroll setDocumentView: nil];
    }
  if (view)
    [[_scroll documentView] setFrameSize: [view frame].size];
}

@end
