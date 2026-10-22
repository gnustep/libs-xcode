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

#import "YCodeEditorDocument.h"
#import "YCodeEditorController.h"
#import "YCodePreferences.h"
#ifdef GNUSTEP
#import <GNUstepGUI/GSGormLoading.h>
#import <GNUstepGUI/GSNibLoading.h>
#import <GNUstepGUI/GSXibLoading.h>
#import <GNUstepGUI/GSXibKeyedUnarchiver.h>

/* Substitute only on this decoder, never on the process-wide class table. */
#define PREVIEW_TEMPLATE(base)                                                \
  @interface YCPreview                                                        \
  ##base : base @end                                                          \
  @implementation YCPreview                                                   \
  ##base - (BOOL)shouldSwapClass                                              \
  {                                                                           \
    return NO;                                                                \
  }                                                                           \
  @end
PREVIEW_TEMPLATE (GSWindowTemplate)
PREVIEW_TEMPLATE (GSViewTemplate)
PREVIEW_TEMPLATE (GSTextTemplate)
PREVIEW_TEMPLATE (GSTextViewTemplate)
PREVIEW_TEMPLATE (GSMenuTemplate)
PREVIEW_TEMPLATE (GSControlTemplate)
PREVIEW_TEMPLATE (GSObjectTemplate)

/* Older Gorm archives use GSNibItem for controllers and GSCustomView for
 * application views. Decode their descriptions without constructing the class. */
static NSString *
YCDecodeNibItem (NSCoder *coder, NSString *className, NSRect *frame)
{
  NSString *name = nil;
  unsigned int mask;
  int version = [coder versionForClassName: className];
  if (version != 0 && version != 1)
    [NSException raise: NSInvalidArgumentException
                format: @"Unsupported %@ version", className];
  [coder decodeValueOfObjCType: @encode (id) at: &name];
  *frame = [coder decodeRect];
  if (version == 1)
    [coder decodeValueOfObjCType: @encode (unsigned int) at: &mask];
  return [name autorelease];
}

@interface YCPreviewNibItem : NSObject <NSCoding>
{
  NSString *_modelClassName;
}

- (NSString *) className;
@end
@implementation YCPreviewNibItem
- (id) initWithCoder: (NSCoder *)coder
{
  if ((self = [super init]))
    {
      NSRect frame;
      _modelClassName = [YCDecodeNibItem (coder, @"GSNibItem", &frame) copy];
    }
  return self;
}

- (void) encodeWithCoder: (NSCoder *)coder
{
}

- (NSString *) className
{
  return _modelClassName;
}

- (void) dealloc
{
  [_modelClassName release];
  [super dealloc];
}

@end

@interface YCPreviewCustomView : NSView
@end
@implementation YCPreviewCustomView
- (id) initWithCoder: (NSCoder *)coder
{
  NSRect frame;
  NSString *name = YCDecodeNibItem (coder, @"GSCustomView", &frame);
  if ((self = [super initWithFrame: frame]))
    {
      NSTextField *label = [[NSTextField alloc]
          initWithFrame: NSMakeRect (4, 4, MAX (0, frame.size.width - 8), 24)];
      [label
          setStringValue: [NSString stringWithFormat: @"Custom view: %@", name]];
      [label setEditable: NO];
      [label setBezeled: NO];
      [label setDrawsBackground: NO];
      [self addSubview: label];
      [label release];
    }
  return self;
}

@end
#endif

/* Share the locally drawn paper with the scroll view's exposed background. */
static NSColor *
YCModelBackground (BOOL objectsPane)
{
  static NSColor *graphPaper = nil;

  if (objectsPane)
    return [NSColor blackColor];
  if (graphPaper == nil)
    {
      NSImage *tile = [[NSImage alloc] initWithSize: NSMakeSize (100, 100)];
      NSInteger position;

      [tile lockFocus];
      [[NSColor colorWithCalibratedRed: 0.10 green: 0.12 blue: 0.15 alpha: 1] set];
      NSRectFill (NSMakeRect (0, 0, 100, 100));
      [[NSColor colorWithCalibratedRed: 0.16 green: 0.19 blue: 0.23 alpha: 1] set];
      for (position = 20; position < 100; position += 20)
        {
          NSRectFill (NSMakeRect (position, 0, 1, 100));
          NSRectFill (NSMakeRect (0, position, 100, 1));
        }
      [[NSColor colorWithCalibratedRed: 0.23 green: 0.27 blue: 0.32 alpha: 1] set];
      NSRectFill (NSMakeRect (0, 0, 1, 100));
      NSRectFill (NSMakeRect (0, 0, 100, 1));
      [tile unlockFocus];
      graphPaper = [[NSColor colorWithPatternImage: tile] retain];
      [tile release];
    }
  return graphPaper;
}

static const CGFloat YCModelTitleHeight = 22;

@interface YCModelWindowFrame : NSView
{
  NSUInteger _previewStyle;
}

- (id) initWithContentView: (NSView *)view
                    title: (NSString *)title
                styleMask: (NSUInteger)style;
- (BOOL) isTitlePoint: (NSPoint)point;
@end

/* Intercept input before it reaches any archived control. The surrounding
 * scroll view remains interactive, but the model cannot receive actions. */
@interface YCModelCanvas : NSView
{
  BOOL _objectsPane;
  BOOL _layingOut;
  CGFloat _previewTop;
  NSMutableArray *_previewViews;
  NSMutableArray *_previewSizes;
  NSMutableDictionary *_previewOrigins;
  NSView *_draggedPreview;
  NSPoint _dragOffset;
}

- (void) setObjectsPane: (BOOL)flag;
- (void) addPreviewView: (NSView *)view;
- (void) setPreviewTop: (CGFloat)top;
- (void) layoutPreviews;
@end
@implementation YCModelCanvas
- (void) dealloc
{
  [[NSNotificationCenter defaultCenter] removeObserver: self];
  [_previewViews release];
  [_previewSizes release];
  [_previewOrigins release];
  [super dealloc];
}

- (void) addPreviewView: (NSView *)view
{
  if (_previewViews == nil)
    {
      _previewViews = [[NSMutableArray alloc] init];
      _previewSizes = [[NSMutableArray alloc] init];
      _previewOrigins = [[NSMutableDictionary alloc] init];
    }
  [_previewViews addObject: view];
  [_previewSizes addObject: [NSValue valueWithSize: [view bounds].size]];
  [view setAutoresizesSubviews: NO];
  [self addSubview: view];
}

- (void) setPreviewTop: (CGFloat)top
{
  _previewTop = top;
}

- (void) viewDidMoveToSuperview
{
  [super viewDidMoveToSuperview];
  [[NSNotificationCenter defaultCenter]
      removeObserver: self
                name: NSViewFrameDidChangeNotification
              object: nil];
  if (!_objectsPane && [[self superview] isKindOfClass: [NSClipView class]])
    {
      [[self superview] setPostsFrameChangedNotifications: YES];
      [[NSNotificationCenter defaultCenter]
          addObserver: self
             selector: @selector (previewViewportChanged:)
                 name: NSViewFrameDidChangeNotification
               object: [self superview]];
      [self layoutPreviews];
    }
}

- (void) previewViewportChanged: (NSNotification *)notification
{
  [self layoutPreviews];
}

- (void) layoutPreviews
{
  NSView *clip = [self superview];
  NSUInteger pass;

  if (_objectsPane || _layingOut || clip == nil)
    return;
  _layingOut = YES;
  /* A newly visible vertical scroller can reduce the available width. */
  for (pass = 0; pass < 3; pass++)
    {
      CGFloat width = MAX (1, [clip bounds].size.width);
      CGFloat inset = MIN (20, width / 4);
      CGFloat available = width - 2 * inset;
      CGFloat x = inset, y = _previewTop, rowHeight = 0;
      CGFloat bottom = _previewTop;
      NSUInteger index;
      NSEnumerator *labels = [[self subviews] objectEnumerator];
      NSView *label;

      while ((label = [labels nextObject]))
        if ([label isKindOfClass: [NSTextField class]])
          {
            NSRect frame = [label frame];
            frame.origin.x = inset;
            frame.size.width = available;
            [label setFrame: frame];
          }
      for (index = 0; index < [_previewViews count]; index++)
        {
          NSView *view = [_previewViews objectAtIndex: index];
          NSSize natural = [[_previewSizes objectAtIndex: index] sizeValue];
          CGFloat scale
              = natural.width > 0 ? MIN (1, available / natural.width) : 1;
          NSSize size
              = NSMakeSize (natural.width * scale, natural.height * scale);

          if (x > inset && x + size.width > width - inset)
            {
              x = inset;
              y += rowHeight + 24;
              rowHeight = 0;
            }
          /* Scale only oversized previews; retain the archived widget geometry. */
          [view setFrame: NSMakeRect (x, y, size.width, size.height)];
          [view setBoundsSize: natural];
          NSValue *origin = [_previewOrigins
              objectForKey: [NSValue valueWithNonretainedObject: view]];
          if (origin)
            {
              NSPoint point = [origin pointValue];
              point.x = MAX (0, MIN (point.x, width - size.width));
              point.y = MAX (_previewTop, point.y);
              [view setFrameOrigin: point];
            }
          bottom = MAX (bottom, NSMaxY ([view frame]));
          x += size.width + 24;
          rowHeight = MAX (rowHeight, size.height);
        }
      [self setFrameSize: NSMakeSize (width, MAX (bottom + 20,
                                                 [clip bounds].size.height))];
      if ([clip bounds].size.width == width)
        break;
    }
  _layingOut = NO;
  [self setNeedsDisplay: YES];
}

- (void) setObjectsPane: (BOOL)flag
{
  _objectsPane = flag;
  [self setNeedsDisplay: YES];
}

- (BOOL) isFlipped
{
  return YES;
}

- (NSView *) nextKeyView
{
  return nil;
}

- (NSView *) hitTest: (NSPoint)point
{
  return [super hitTest: point] ? self : nil;
}

- (void) mouseDown: (NSEvent *)event
{
  NSPoint point = [self convertPoint: [event locationInWindow] fromView: nil];
  NSEnumerator *views = [[self subviews] reverseObjectEnumerator];
  NSView *view;

  _draggedPreview = nil;
  if (_objectsPane)
    return;
  while ((view = [views nextObject]))
    if ([_previewViews containsObject: view]
        && NSPointInRect (point, [view frame]))
      {
        if ([view isKindOfClass: [YCModelWindowFrame class]] &&
            [(YCModelWindowFrame *)view isTitlePoint: [view convertPoint: point
                                                               fromView: self]])
          {
            _draggedPreview = view;
            _dragOffset = NSMakePoint (point.x - NSMinX ([view frame]),
                                       point.y - NSMinY ([view frame]));
            [self addSubview: view positioned: NSWindowAbove relativeTo: nil];
          }
        break;
      }
}

- (void) mouseDragged: (NSEvent *)event
{
  if (_draggedPreview)
    {
      NSPoint point = [self convertPoint: [event locationInWindow]
                                fromView: nil];
      point.x = MAX (0, MIN (point.x - _dragOffset.x,
                             [self bounds].size.width -
                                 [_draggedPreview frame].size.width));
      point.y = MAX (_previewTop, point.y - _dragOffset.y);
      [_previewOrigins
          setObject: [NSValue valueWithPoint: point]
             forKey: [NSValue valueWithNonretainedObject: _draggedPreview]];
      [self layoutPreviews];
      [self autoscroll: event];
    }
}

- (void) mouseUp: (NSEvent *)event
{
  _draggedPreview = nil;
}

- (void) drawRect: (NSRect)rect
{
  [YCModelBackground (_objectsPane) set];
  NSRectFill (rect);
}

@end

/* These frames are views, not application windows: the archived interface
 * stays inside the editor and never enters NSApplication's window lifecycle. */

/* Approximate Window Maker's raised, square title-bar segments locally,
 * independently of the AppKit theme and without live window buttons. */
static void
YCModelTitleSegment (NSRect rect)
{
  [[NSColor blackColor] set];
  NSRectFill (rect);
  [[NSColor colorWithCalibratedWhite: 0.38 alpha: 1] set];
  NSRectFill (
      NSMakeRect (NSMinX (rect), NSMaxY (rect) - 1, rect.size.width, 1));
  NSRectFill (NSMakeRect (NSMinX (rect), NSMinY (rect), 1, rect.size.height));
  [[NSColor colorWithCalibratedWhite: 0.16 alpha: 1] set];
  NSRectFill (NSMakeRect (NSMinX (rect), NSMinY (rect), rect.size.width, 1));
  NSRectFill (
      NSMakeRect (NSMaxX (rect) - 1, NSMinY (rect), 1, rect.size.height));
}

@implementation YCModelWindowFrame
- (id) initWithContentView: (NSView *)view
                    title: (NSString *)title
                styleMask: (NSUInteger)style
{
  NSSize size = [view frame].size;
  CGFloat barHeight = (style & NSTitledWindowMask) ? YCModelTitleHeight : 0;
  if ((self = [super initWithFrame: NSMakeRect (0, 0, size.width + 2,
                                               size.height + barHeight + 2)]))
    {
      _previewStyle = style;
      [view removeFromSuperview];
      [view setFrameOrigin: NSMakePoint (1, 1)];
      [self addSubview: view];
      if (barHeight)
        {
          CGFloat titleInset
              = (style & (NSClosableWindowMask | NSMiniaturizableWindowMask))
                    ? 24
                    : 4;
          NSTextField *label = [[NSTextField alloc]
              initWithFrame: NSMakeRect (1 + titleInset, size.height + 3,
                                        MAX (0, size.width - 2 * titleInset),
                                        18)];
          [label setStringValue: title ? title : @""];
          [label setAlignment: NSCenterTextAlignment];
          [label setFont: [NSFont boldSystemFontOfSize: 12]];
          [label setTextColor: [NSColor whiteColor]];
          [[label cell] setLineBreakMode: NSLineBreakByTruncatingTail];
          [label setEditable: NO];
          [label setBezeled: NO];
          [label setDrawsBackground: NO];
          [self addSubview: label];
          [label release];
        }
    }
  return self;
}

- (BOOL) isTitlePoint: (NSPoint)point
{
  NSRect bar = NSMakeRect (1, NSMaxY ([self bounds]) - YCModelTitleHeight - 1,
                           [self bounds].size.width - 2, YCModelTitleHeight);
  return (_previewStyle & NSTitledWindowMask) && NSPointInRect (point, bar);
}

- (void) drawRect: (NSRect)rect
{
  [[NSColor windowBackgroundColor] set];
  NSRectFill ([self bounds]);
  [[NSColor blackColor] set];
  NSFrameRect ([self bounds]);
  if (_previewStyle & NSTitledWindowMask)
    {
      NSRect bar
          = NSMakeRect (1, NSMaxY ([self bounds]) - YCModelTitleHeight - 1,
                        [self bounds].size.width - 2, YCModelTitleHeight);
      YCModelTitleSegment (bar);
      if ((_previewStyle & NSMiniaturizableWindowMask) && bar.size.width >= 44)
        {
          NSRect button = NSMakeRect (NSMinX (bar), NSMinY (bar),
                                      YCModelTitleHeight, YCModelTitleHeight);
          YCModelTitleSegment (button);
          [[NSColor whiteColor] set];
          NSRectFill (
              NSMakeRect (NSMinX (button) + 7, NSMinY (button) + 6, 8, 2));
        }
      if ((_previewStyle & NSClosableWindowMask)
          && bar.size.width >= YCModelTitleHeight)
        {
          NSRect button
              = NSMakeRect (NSMaxX (bar) - YCModelTitleHeight, NSMinY (bar),
                            YCModelTitleHeight, YCModelTitleHeight);
          NSBezierPath *cross = [NSBezierPath bezierPath];
          YCModelTitleSegment (button);
          [[NSColor whiteColor] set];
          [cross setLineWidth: 2];
          [cross moveToPoint: NSMakePoint (NSMinX (button) + 7,
                                          NSMinY (button) + 7)];
          [cross lineToPoint: NSMakePoint (NSMinX (button) + 15,
                                          NSMinY (button) + 15)];
          [cross moveToPoint: NSMakePoint (NSMinX (button) + 7,
                                          NSMinY (button) + 15)];
          [cross lineToPoint: NSMakePoint (NSMinX (button) + 15,
                                          NSMinY (button) + 7)];
          [cross stroke];
        }
    }
}

@end

#ifdef GNUSTEP
/* NSMenuView normally borrows its menu from NSMenu's own window. Our embedded
 * representation must retain it independently across document reloads. */
@interface YCModelMenuView : NSMenuView
{
  NSMenu *_previewMenu;
}

- (id) initWithPreviewMenu: (NSMenu *)menu;
@end
@implementation YCModelMenuView
- (id) initWithPreviewMenu: (NSMenu *)menu
{
  if ((self = [super initWithFrame: NSZeroRect]))
    {
      _previewMenu = [menu retain];
      [menu setAutoenablesItems: NO];
      [self setMenu: menu];
      [self sizeToFit];
    }
  return self;
}

- (void) dealloc
{
  [self setMenu: nil];
  [_previewMenu release];
  [super dealloc];
}

@end
#endif

/* Keep keyboard traversal from entering archived text fields or controls. */
static void
YCMakeModelViewReadOnly (NSView *view, NSView *canvas)
{
  NSEnumerator *enumerator = [[view subviews] objectEnumerator];
  NSView *child;
  [view setNextKeyView: canvas];
  if ([view isKindOfClass: [NSControl class]])
    [(NSControl *)view setRefusesFirstResponder: YES];
  if ([view isKindOfClass: [NSTextView class]])
    {
      [(NSTextView *)view setEditable: NO];
      [(NSTextView *)view setSelectable: NO];
    }
  while ((child = [enumerator nextObject]))
    YCMakeModelViewReadOnly (child, canvas);
}

/* The editor owns this view; its callback must not retain the document. */
@interface YCModelEditorView : NSView
{
  id _overlayOwner;
}

- (void) setOverlayOwner: (id)owner;
@end
@implementation YCModelEditorView
- (void) setOverlayOwner: (id)owner
{
  _overlayOwner = owner;
}

- (void) viewDidMoveToWindow
{
  [super viewDidMoveToWindow];
  [_overlayOwner performSelector: @selector (updateConnectionLine)];
}

- (void) setHidden: (BOOL)hidden
{
  [super setHidden: hidden];
  [_overlayOwner performSelector: @selector (updateConnectionLine)];
}

@end

@interface YCModelConnectionWindow : NSWindow
@end
@implementation YCModelConnectionWindow
- (BOOL) canBecomeKeyWindow
{
  return NO;
}

- (BOOL) canBecomeMainWindow
{
  return NO;
}

@end

@interface YCModelConnectionLineView : NSView
@end
@implementation YCModelConnectionLineView
- (void) drawRect: (NSRect)rect
{
  [[[self window] backgroundColor] set];
  NSRectFill (rect);
}

@end

/* Composite the tag over the editor's pixels so transparent icon corners
 * also work on X11 desktops without a compositing window manager. */
@interface YCModelConnectionTagView : NSImageView
{
  NSImage *_backdrop;
}

- (void) setBackdrop: (NSImage *)image;
@end
@implementation YCModelConnectionTagView
- (void) setBackdrop: (NSImage *)image
{
  ASSIGN (_backdrop, image);
  [self setNeedsDisplay: YES];
}

- (void) drawRect: (NSRect)rect
{
  [_backdrop drawInRect: [self bounds]
               fromRect: NSZeroRect
              operation: NSCompositeCopy
               fraction: 1];
  [super drawRect: rect];
}

- (void) dealloc
{
  [_backdrop release];
  [super dealloc];
}

@end

static id
YCConnectionKey (id object)
{
  if (!object)
    return [NSNull null];
  return [object isKindOfClass: [NSString class]]
             ? object
             : [NSValue valueWithNonretainedObject: object];
}

/* Never instantiate or establish a connection while inspecting it. */
static NSString *
YCConnectionObjectName (id object, NSDictionary *names)
{
  if (object == nil)
    return @"Unspecified";
  if ([object isKindOfClass: [NSString class]])
    {
      if ([object isEqual: @"NSOwner"])
        return @"File's Owner";
      if ([object isEqual: @"NSFirst"])
        return @"First Responder";
      return object;
    }
  NSString *name =
      [names objectForKey: [NSValue valueWithNonretainedObject: object]];
  if (name)
    return name;
  NSString *className = NSStringFromClass ([object class]);
  if ([object respondsToSelector: @selector (className)])
    className = [object className];
  if ([className isEqual: @"FirstResponder"])
    return @"First Responder";
  if ([object respondsToSelector: @selector (title)])
    {
      NSString *title = [object title];
      if ([title length])
        return [NSString stringWithFormat: @"%@ — %@", title, className];
    }
  return className ? className : @"Unknown object";
}

static NSDictionary *
YCConnectionRow (id connection, NSDictionary *names)
{
  NSString *kind = NSStringFromClass ([connection class]);
  id source = nil, destination = nil;
  NSString *label = @"";
  if ([connection respondsToSelector: @selector (source)])
    source = [connection source];
  if ([connection respondsToSelector: @selector (destination)])
    destination = [connection destination];
  if ([connection respondsToSelector: @selector (label)])
    label = [connection label];
#ifdef GNUSTEP
  /* XIB action records store the receiver as source, unlike NIB connectors. */
  if ([connection isKindOfClass: [IBActionConnection class]])
    {
      id sender = destination;
      destination = source;
      source = sender;
      kind = @"Action";
    }
  else if ([connection isKindOfClass: [IBOutletConnection class]])
    kind = @"Outlet";
  else if ([connection isKindOfClass: [IBBindingConnection class]])
    kind = @"Binding";
#endif
  if ([connection isKindOfClass: NSClassFromString (@"NSNibControlConnector")])
    kind = @"Action";
  else if ([connection
               isKindOfClass: NSClassFromString (@"NSNibOutletConnector")])
    kind = @"Outlet";
  else if ([kind rangeOfString: @"Binding"].location != NSNotFound)
    kind = @"Binding";
  return [NSDictionary
      dictionaryWithObjectsAndKeys: kind, @"type",
                                   YCConnectionObjectName (source, names),
                                   @"source", label ? label : @"", @"label",
                                   destination == nil &&
                                           [kind isEqual: @"Action"]
                                       ? @"First Responder"
                                       : YCConnectionObjectName (destination,
                                                                 names),
                                   @"destination", YCConnectionKey (source),
                                   @"sourceKey",
                                   destination == nil &&
                                           [kind isEqual: @"Action"]
                                       ? @"NSFirst"
                                       : YCConnectionKey (destination),
                                   @"destinationKey", nil];
}

@interface YCodeModelEditorDocument : YCodeEditorDocument
{
  NSView *_editorView;
  NSScrollView *_objectScrollView;
  NSScrollView *_scrollView;
  NSArray *_objects;
  NSArray *_connections;
  NSTableView *_connectionTable;
  NSTextField *_connectionHeading;
  NSMutableDictionary *_endpointViews;
  NSMutableArray *_connectionLineWindows;
  NSMutableArray *_connectionTagWindows;
  BOOL _updatingConnectionLine;
  BOOL _applicationInactive;
}

- (void) addLabel: (NSString *)label toCanvas: (NSView *)canvas y: (CGFloat *)y;
- (void) updateConnectionLine;
- (void) hideConnectionLine;
- (void) registerEndpointView: (NSView *)view forObject: (id)object;
- (void) registerEndpointHierarchy: (NSView *)view;
- (void) addMenu: (NSMenu *)menu
       toCanvas: (YCModelCanvas *)canvas
          depth: (NSUInteger)depth
        visited: (NSMutableSet *)visited;
@end

@implementation YCodeModelEditorDocument
+ (NSString *) editorIdentifier
{
  return @"model";
}

+ (NSString *) editorKind
{
  return @"model";
}

+ (NSInteger) editorPriority
{
  return 300;
}

+ (BOOL) canOpenFilePath: (NSString *)path
{
  return [[NSArray arrayWithObjects: @"gorm", @"xib", @"nib", nil]
      containsObject: [[path pathExtension] lowercaseString]];
}

- (id) initWithFilePath: (NSString *)path
{
  if ((self = [super initWithFilePath: path]))
    {
      _endpointViews = [[NSMutableDictionary alloc] init];
      _connectionLineWindows = [[NSMutableArray alloc] init];
      _connectionTagWindows = [[NSMutableArray alloc] init];
      _editorView = [[YCModelEditorView alloc]
          initWithFrame: NSMakeRect (0, 0, 600, 400)];
      [(YCModelEditorView *)_editorView setOverlayOwner: self];
      [_editorView
          setAutoresizingMask: NSViewWidthSizable | NSViewHeightSizable];
      _objectScrollView =
          [[NSScrollView alloc] initWithFrame: NSMakeRect (0, 0, 140, 400)];
      [_objectScrollView setHasVerticalScroller: YES];
      [_objectScrollView setAutohidesScrollers: YES];
      [_objectScrollView setBorderType: NSBezelBorder];
      [_objectScrollView setBackgroundColor: YCModelBackground (YES)];
      [_objectScrollView setAutoresizingMask: NSViewHeightSizable];
      [_editorView addSubview: _objectScrollView];
      _scrollView =
          [[NSScrollView alloc] initWithFrame: NSMakeRect (141, 170, 459, 230)];
      [_editorView addSubview: _scrollView];
      [_scrollView setHasVerticalScroller: YES];
      [_scrollView setHasHorizontalScroller: NO];
      [_scrollView setAutohidesScrollers: YES];
      [_scrollView setBackgroundColor: YCModelBackground (NO)];
      [_scrollView
          setAutoresizingMask: NSViewWidthSizable | NSViewHeightSizable];
      _connectionHeading =
          [[NSTextField alloc] initWithFrame: NSMakeRect (149, 144, 443, 22)];
      [_connectionHeading setEditable: NO];
      [_connectionHeading setBezeled: NO];
      [_connectionHeading setDrawsBackground: NO];
      [_connectionHeading setStringValue: @"Connections"];
      [_connectionHeading setAutoresizingMask: NSViewWidthSizable];
      [_editorView addSubview: _connectionHeading];
      NSScrollView *inspector =
          [[NSScrollView alloc] initWithFrame: NSMakeRect (141, 0, 459, 142)];
      [inspector setHasVerticalScroller: YES];
      [inspector setHasHorizontalScroller: YES];
      [inspector setAutohidesScrollers: YES];
      [inspector setBorderType: NSBezelBorder];
      [inspector setAutoresizingMask: NSViewWidthSizable];
      _connectionTable =
          [[NSTableView alloc] initWithFrame: [inspector bounds]];
      NSArray *keys = [NSArray
          arrayWithObjects: @"type", @"source", @"label", @"destination", nil];
      NSArray *titles =
          [NSArray arrayWithObjects: @"Type", @"Source", @"Outlet / Action",
                                    @"Destination", nil];
      NSUInteger index;
      for (index = 0; index < [keys count]; index++)
        {
          NSTableColumn *column = [[NSTableColumn alloc]
              initWithIdentifier: [keys objectAtIndex: index]];
          [[column headerCell] setStringValue: [titles objectAtIndex: index]];
          [column setEditable: NO];
          [column setWidth: index == 0 ? 90 : 190];
          [_connectionTable addTableColumn: column];
          [column release];
        }
      [_connectionTable setDataSource: self];
      [_connectionTable setDelegate: self];
      [_connectionTable setAllowsMultipleSelection: NO];
      [inspector setDocumentView: _connectionTable];
      [_editorView addSubview: inspector];
      [inspector release];
      NSArray *notifications = [NSArray
          arrayWithObjects: NSViewFrameDidChangeNotification,
                           NSViewBoundsDidChangeNotification,
                           NSWindowDidMoveNotification,
                           NSWindowDidResizeNotification,
                           NSWindowDidUpdateNotification,
                           NSWindowWillCloseNotification,
                           NSWindowDidMiniaturizeNotification,
                           NSWindowDidDeminiaturizeNotification,
                           NSApplicationDidResignActiveNotification,
                           NSApplicationDidBecomeActiveNotification,
                           YCodeConnectionPreferencesDidChangeNotification,
                           nil];
      NSEnumerator *names = [notifications objectEnumerator];
      NSString *name;
      while ((name = [names nextObject]))
        [[NSNotificationCenter defaultCenter]
            addObserver: self
               selector: @selector (connectionGeometryChanged:)
                   name: name
                 object: nil];
    }
  return self;
}

- (void) dealloc
{
  [[NSNotificationCenter defaultCenter] removeObserver: self];
  [(YCModelEditorView *)_editorView setOverlayOwner: nil];
  [self hideConnectionLine];
  [_connectionLineWindows makeObjectsPerformSelector: @selector (close)];
  [_connectionLineWindows release];
  [_connectionTagWindows makeObjectsPerformSelector: @selector (close)];
  [_connectionTagWindows release];
  [_endpointViews release];
  [_connectionTable setDataSource: nil];
  [_connectionTable setDelegate: nil];
  [_connectionTable release];
  [_connectionHeading release];
  [_connections release];
  [_editorView release];
  [_objectScrollView release];
  [_scrollView release];
  [_objects release];
  [super dealloc];
}

- (void) registerEndpointView: (NSView *)view forObject: (id)object
{
  if (object && view)
    {
      [_endpointViews setObject: [NSDictionary dictionaryWithObject: view
                                                            forKey: @"view"]
                         forKey: YCConnectionKey (object)];
      [view setPostsFrameChangedNotifications: YES];
      [view setPostsBoundsChangedNotifications: YES];
    }
}

- (void) registerEndpointHierarchy: (NSView *)view
{
  [self registerEndpointView: view forObject: view];
  if ([view isKindOfClass: [NSControl class]])
    [self registerEndpointView: view forObject: [(NSControl *)view cell]];
  if ([view isKindOfClass: [NSMatrix class]])
    {
      NSMatrix *matrix = (NSMatrix *)view;
      NSInteger row, column;
      for (row = 0; row < [matrix numberOfRows]; row++)
        for (column = 0; column < [matrix numberOfColumns]; column++)
          [_endpointViews
              setObject: [NSDictionary
                            dictionaryWithObjectsAndKeys:
                                view, @"view",
                                [NSValue
                                    valueWithRect: [matrix
                                                      cellFrameAtRow: row
                                                              column: column]],
                                @"rect", nil]
                 forKey: YCConnectionKey ([matrix cellAtRow: row
                                                    column: column])];
    }
  if ([view isKindOfClass: [NSTableView class]])
    {
      NSEnumerator *columns =
          [[(NSTableView *)view tableColumns] objectEnumerator];
      NSTableColumn *column;
      NSInteger index = 0;
      while ((column = [columns nextObject]))
        [_endpointViews
            setObject: [NSDictionary
                          dictionaryWithObjectsAndKeys:
                              view, @"view",
                              [NSValue
                                  valueWithRect: [(NSTableView *)view
                                                    rectOfColumn: index++]],
                              @"rect", nil]
               forKey: YCConnectionKey (column)];
    }
  NSEnumerator *children = [[view subviews] objectEnumerator];
  NSView *child;
  while ((child = [children nextObject]))
    [self registerEndpointHierarchy: child];
}

- (void) hideConnectionLine
{
  NSEnumerator *windows = [[_connectionLineWindows
      arrayByAddingObjectsFromArray: _connectionTagWindows] objectEnumerator];
  NSWindow *window;
  while ((window = [windows nextObject]))
    {
      [[window parentWindow] removeChildWindow: window];
      [window orderOut: nil];
    }
}

- (BOOL) connectionPointForKey: (id)key point: (NSPoint *)point
{
  NSDictionary *endpoint = [_endpointViews objectForKey: key];
  NSView *view = [endpoint objectForKey: @"view"];
  if (!view || [view window] != [_editorView window] ||
      [view isHiddenOrHasHiddenAncestor])
    return NO;
  NSValue *storedRect = [endpoint objectForKey: @"rect"];
  NSRect rect = storedRect ? [storedRect rectValue] : [view bounds];
  rect = NSIntersectionRect (rect, [view visibleRect]);
  if (NSIsEmptyRect (rect))
    return NO;
  *point = [view convertPoint: NSMakePoint (NSMidX (rect), NSMidY (rect))
                       toView: nil];
  *point = [[view window] convertBaseToScreen: *point];
  return YES;
}

- (void) connectionGeometryChanged: (NSNotification *)notification
{
  NSString *name = [notification name];
  id object = [notification object];
  if ([name isEqual: NSApplicationDidResignActiveNotification])
    _applicationInactive = YES;
  else if ([name isEqual: NSApplicationDidBecomeActiveNotification])
    _applicationInactive = NO;
  if ([object isKindOfClass: [NSView class]] && object != _editorView
      && ![object isDescendantOf: _editorView])
    return;
  if ([object isKindOfClass: [NSWindow class]])
    {
      if (object != [_editorView window])
        return;
      if ([name isEqual: NSWindowWillCloseNotification])
        {
          [self hideConnectionLine];
          return;
        }
    }
  [self updateConnectionLine];
}

- (void) updateConnectionTagAtPoint: (NSPoint)point
                             index: (NSUInteger)index
                              host: (NSWindow *)host
{
  NSWindow *tag;
  if (index >= [_connectionTagWindows count])
    {
      NSString *name = index == 0 ? @"GormSourceTag" : @"GormTargetTag";
      NSString *path =
          [[NSBundle bundleForClass: [self class]] pathForResource: name
                                                           ofType: @"tiff"];
      NSImage *image = [[NSImage alloc] initWithContentsOfFile: path];
      tag = [[YCModelConnectionWindow alloc]
          initWithContentRect: NSMakeRect (0, 0, 16, 16)
                    styleMask: NSBorderlessWindowMask
                      backing: NSBackingStoreBuffered
                        defer: YES];
      [tag setReleasedWhenClosed: NO];
      [tag setHasShadow: NO];
      [tag setOpaque: YES];
      [tag setBackgroundColor: [NSColor clearColor]];
      YCModelConnectionTagView *view = [[YCModelConnectionTagView alloc]
          initWithFrame: NSMakeRect (0, 0, 16, 16)];
      [view setImage: image];
      [view setImageScaling: NSImageScaleNone];
      [tag setContentView: view];
      [view release];
      [image release];
      [_connectionTagWindows addObject: tag];
      [tag release];
    }
  tag = [_connectionTagWindows objectAtIndex: index];
  NSRect frame = NSMakeRect (floor (point.x - 8), floor (point.y - 8), 16, 16);
  BOOL changed = !NSEqualRects ([tag frame], frame) || ![tag isVisible];
  if (!NSEqualRects ([tag frame], frame))
    [tag setFrame: frame display: NO];
  if ([tag parentWindow] != host)
    {
      [[tag parentWindow] removeChildWindow: tag];
      [host addChildWindow: tag ordered: NSWindowAbove];
    }
  if (![tag isVisible])
    [tag orderFront: nil];
  [tag setIgnoresMouseEvents: YES];
  if (changed)
    {
      NSView *content = [host contentView];
      NSRect sample = frame;
      sample.origin = [host convertScreenToBase: frame.origin];
      sample = [content convertRect: sample fromView: nil];
      NSBitmapImageRep *bitmap =
          [content bitmapImageRepForCachingDisplayInRect: sample];
      [content cacheDisplayInRect: sample toBitmapImageRep: bitmap];
      NSImage *backdrop = [[NSImage alloc] initWithSize: frame.size];
      if (bitmap)
        [backdrop addRepresentation: bitmap];
      [(YCModelConnectionTagView *)[tag contentView] setBackdrop: backdrop];
      [backdrop release];
      [[tag contentView] setNeedsDisplay: YES];
      [tag displayIfNeeded];
      [tag flushWindow];
    }
}

- (void) updateConnectionLine
{
  if (_updatingConnectionLine)
    return;
  _updatingConnectionLine = YES;
  NSWindow *host = [_editorView window];
  NSInteger row = [_connectionTable selectedRow];
  NSPoint source, destination;
  NSDictionary *connection = row >= 0 && (NSUInteger)row < [_connections count]
                                 ? [_connections objectAtIndex: row]
                                 : nil;
  if (!connection || !host || ![host isVisible] || [host isMiniaturized] ||
      [_editorView isHiddenOrHasHiddenAncestor] || _applicationInactive
      || ![self connectionPointForKey: [connection objectForKey: @"sourceKey"]
                                point: &source]
      || ![self
          connectionPointForKey: [connection objectForKey: @"destinationKey"]
                          point: &destination])
    {
      [self hideConnectionLine];
      _updatingConnectionLine = NO;
      return;
    }
  CGFloat width = [YCodePreferences connectionLineWidth];
  NSColor *color = [YCodePreferences connectionLineColor];
  NSPoint corner = NSMakePoint (destination.x, source.y);
  NSRect frames[2];
  frames[0]
      = NSMakeRect (MIN (source.x, corner.x) - width / 2, source.y - width / 2,
                    fabs (source.x - corner.x) + width, width);
  frames[1] = NSMakeRect (destination.x - width / 2,
                          MIN (corner.y, destination.y) - width / 2, width,
                          fabs (corner.y - destination.y) + width);
  NSUInteger index;
  for (index = 0; index < 2; index++)
    {
      NSWindow *segment;
      if (index >= [_connectionLineWindows count])
        {
          segment = [[YCModelConnectionWindow alloc]
              initWithContentRect: frames[index]
                        styleMask: NSBorderlessWindowMask
                          backing: NSBackingStoreBuffered
                            defer: YES];
          [segment setReleasedWhenClosed: NO];
          [segment setHasShadow: NO];
          [segment setOpaque: YES];
          YCModelConnectionLineView *view = [[YCModelConnectionLineView alloc]
              initWithFrame: NSMakeRect (0, 0, frames[index].size.width,
                                        frames[index].size.height)];
          [segment setContentView: view];
          [view release];
          [_connectionLineWindows addObject: segment];
          [segment release];
        }
      segment = [_connectionLineWindows objectAtIndex: index];
      BOOL changed = !NSEqualRects ([segment frame], frames[index])
                     || ![[segment backgroundColor] isEqual: color]
                     || ![segment isVisible];
      if (!NSEqualRects ([segment frame], frames[index]))
        [segment setFrame: frames[index] display: NO];
      if (![[segment backgroundColor] isEqual: color])
        [segment setBackgroundColor: color];
      if ([segment parentWindow] != host)
        {
          [[segment parentWindow] removeChildWindow: segment];
          [host addChildWindow: segment ordered: NSWindowAbove];
        }
      if (![segment isVisible])
        [segment orderFront: nil];
      /* GNUstep needs a native window before it can disable pointer input. */
      [segment setIgnoresMouseEvents: YES];
      if (changed)
        {
          [[segment contentView] setNeedsDisplay: YES];
          [segment displayIfNeeded];
          [segment flushWindow];
        }
    }
  /* Keep both tags readable for self-connections or coincident endpoints. */
  if (fabs (source.x - destination.x) < 16
      && fabs (source.y - destination.y) < 16)
    {
      source.x -= 8;
      destination.x += 8;
    }
  [self updateConnectionTagAtPoint: source index: 0 host: host];
  [self updateConnectionTagAtPoint: destination index: 1 host: host];
  _updatingConnectionLine = NO;
}

- (void) tableViewSelectionDidChange: (NSNotification *)notification
{
  [self updateConnectionLine];
}

- (NSInteger) numberOfRowsInTableView: (NSTableView *)table
{
  return [_connections count];
}

- (id) tableView: (NSTableView *)table
    objectValueForTableColumn: (NSTableColumn *)column
                          row: (NSInteger)row
{
  return [[_connections objectAtIndex: row] objectForKey: [column identifier]];
}

- (NSString *) tableView: (NSTableView *)table
         toolTipForCell: (NSCell *)cell
                   rect: (NSRectPointer)rect
            tableColumn: (NSTableColumn *)column
                    row: (NSInteger)row
          mouseLocation: (NSPoint)point
{
  if (row < 0 || (NSUInteger)row >= [_connections count])
    return nil;
  return [[_connections objectAtIndex: row] objectForKey: [column identifier]];
}

- (NSView *) editorView
{
  return _editorView;
}

- (NSScrollView *) scrollView
{
  return _scrollView;
}

- (void) addLabel: (NSString *)label toCanvas: (NSView *)canvas y: (CGFloat *)y
{
  NSTextField *field = [[NSTextField alloc]
      initWithFrame: NSMakeRect (20, *y,
                                MIN (700, [canvas frame].size.width - 40),
                                24)];
  [field setStringValue: label ? label : @""];
  [field setToolTip: label];
  [field setEditable: NO];
  [field setSelectable: NO];
  [field setBezeled: NO];
  [field setDrawsBackground: NO];
  [field setTextColor: [NSColor colorWithCalibratedWhite: 0.94 alpha: 1]];
  [canvas addSubview: field];
  [field release];
  *y += 28;
}

- (void) addMenu: (NSMenu *)menu
       toCanvas: (YCModelCanvas *)canvas
          depth: (NSUInteger)depth
        visited: (NSMutableSet *)visited
{
  NSEnumerator *enumerator;
  NSMenuItem *item;
  if ([visited containsObject: menu] || depth > 32)
    return;
  [visited addObject: menu];
#ifdef GNUSTEP
  YCModelMenuView *view = [[YCModelMenuView alloc] initWithPreviewMenu: menu];
  [canvas addPreviewView: view];
  [self registerEndpointView: view forObject: menu];
  NSUInteger index;
  for (index = 0; index < (NSUInteger)[menu numberOfItems]; index++)
    [_endpointViews
        setObject: [NSDictionary
                      dictionaryWithObjectsAndKeys:
                          view, @"view",
                          [NSValue
                              valueWithRect: [view rectOfItemAtIndex: index]],
                          @"rect", nil]
           forKey: YCConnectionKey ([menu itemAtIndex: index])];
  YCMakeModelViewReadOnly (view, canvas);
  [view release];
#endif
  enumerator = [[menu itemArray] objectEnumerator];
  while ((item = [enumerator nextObject]))
    if ([item submenu])
      [self addMenu: [item submenu]
           toCanvas: canvas
              depth: depth + 1
            visited: visited];
}

- (BOOL) loadFromFile
{
  BOOL directory = NO;
  NSString *extension = [[_filePath pathExtension] lowercaseString];
  NSString *path = _filePath;
  NSMutableArray *objects = [NSMutableArray array];
  NSMutableDictionary *roles = [NSMutableDictionary dictionary];
  NSMutableArray *specialObjects = [NSMutableArray array];
  NSMutableDictionary *connectionNames = [NSMutableDictionary dictionary];
  NSMutableDictionary *endpointAliases = [NSMutableDictionary dictionary];
  NSMutableArray *connections = [NSMutableArray array];
  NSMutableArray *rows = [NSMutableArray array];
  NSString *problem = nil;
  YCModelCanvas *canvas;
  YCModelCanvas *objectCanvas;
  CGFloat objectY = 20;
  CGFloat y = 20, width = 740;
  id decoder = nil;
  id container = nil;
#ifdef GNUSTEP
  BOOL wasInBuilder = [NSClassSwapper isInInterfaceBuilder];
#endif
  if (![[NSFileManager defaultManager] fileExistsAtPath: path
                                            isDirectory: &directory])
    return NO;
  [_connectionTable deselectAll: nil];
  [self hideConnectionLine];
  [_endpointViews removeAllObjects];
  if (directory)
    path = [path stringByAppendingPathComponent: [extension isEqual: @"gorm"]
                                                    ? @"objects.gorm"
                                                    : @"keyedobjects.nib"];
  @try
    {
#ifdef GNUSTEP
      NSData *data = [NSData dataWithContentsOfFile: path];
      if (![data length])
        [NSException raise: NSInvalidArgumentException
                    format: @"The model contains no readable archive."];
      [NSClassSwapper setIsInInterfaceBuilder: YES];
      if ([extension isEqual: @"gorm"])
        {
          NSArray *templates = [NSArray
              arrayWithObjects: @"GSWindowTemplate", @"GSViewTemplate",
                               @"GSTextTemplate", @"GSTextViewTemplate",
                               @"GSMenuTemplate", @"GSControlTemplate",
                               @"GSObjectTemplate", nil];
          NSEnumerator *enumerator = [templates objectEnumerator];
          NSString *name;
          decoder = [[NSUnarchiver alloc] initForReadingWithData: data];
          [decoder decodeClassName: @"GSNibItem"
                       asClassName: @"YCPreviewNibItem"];
          [decoder decodeClassName: @"GSCustomView"
                       asClassName: @"YCPreviewCustomView"];
          while ((name = [enumerator nextObject]))
            [decoder
                decodeClassName: name
                    asClassName: [@"YCPreview" stringByAppendingString: name]];
          container = [[decoder decodeObject] retain];
          if (![container isKindOfClass: [GSNibContainer class]])
            [NSException raise: NSInvalidArgumentException
                        format: @"Not a Gorm model archive."];
          [connections addObjectsFromArray: [container connections]];
          NSDictionary *names = [container nameTable];
          NSEnumerator *keys = [[[names allKeys]
              sortedArrayUsingSelector: @selector (compare:)] objectEnumerator];
          NSString *key;
          while ((key = [keys nextObject]))
            {
              id object = [names objectForKey: key];
              [endpointAliases setObject: YCConnectionKey (object) forKey: key];
              [connectionNames
                  setObject: YCConnectionObjectName (key, nil)
                     forKey: [NSValue valueWithNonretainedObject: object]];
              if ([key isEqual: @"NSOwner"] || [key isEqual: @"NSFirst"])
                [specialObjects addObject: object];
              else
                [objects addObject: object];
            }
          /* Gorm keeps these proxies separately from the archived objects. */
          [specialObjects addObject: @"File's Owner"];
          [specialObjects addObject: @"First Responder"];
          [objects
              addObjectsFromArray: [[container topLevelObjects] allObjects]];
        }
      else if ([extension isEqual: @"xib"])
        {
          decoder = [[GSXibKeyedUnarchiver unarchiverForReadingWithData: data]
              retain];
          NSArray *roots =
              [decoder decodeObjectForKey: @"IBDocument.RootObjects"];
          if (![roots isKindOfClass: [NSArray class]])
            [NSException
                 raise: NSInvalidArgumentException
                format: @"This XIB format is not supported by GNUstep GUI."];
          [objects addObjectsFromArray: roots];
          container =
              [[decoder decodeObjectForKey: @"IBDocument.Objects"] retain];
          NSEnumerator *records = [container connectionRecordEnumerator];
          IBConnectionRecord *record;
          while ((record = [records nextObject]))
            if ([record connection])
              [connections addObject: [record connection]];
          NSDictionary *decoded = [(GSXibKeyedUnarchiver *)decoder decoded];
          NSEnumerator *identifiers = [[[decoded allKeys]
              sortedArrayUsingSelector: @selector (compare:)] objectEnumerator];
          NSString *identifier;
          while ((identifier = [identifiers nextObject]))
            {
              id object = [decoded objectForKey: identifier];
              [connectionNames
                  setObject: [NSString stringWithFormat: @"%@ [%@]",
                                                       YCConnectionObjectName (
                                                           object, nil),
                                                       identifier]
                     forKey: [NSValue valueWithNonretainedObject: object]];
            }
          id owner = [decoded objectForKey: @"-2"];
          id responder = [decoded objectForKey: @"-1"];
          if (!owner && [roots count])
            owner = [roots objectAtIndex: 0];
          if (owner)
            [roles setObject: @"File's Owner"
                      forKey: [NSValue valueWithNonretainedObject: owner]];
          if (responder)
            [roles setObject: @"First Responder"
                      forKey: [NSValue valueWithNonretainedObject: responder]];
        }
      else
        {
          decoder = [[NSKeyedUnarchiver alloc] initForReadingWithData: data];
          container = [[decoder decodeObjectForKey: @"IB.objectdata"] retain];
          if (![container isKindOfClass: [NSIBObjectData class]])
            [NSException
                 raise: NSInvalidArgumentException
                format: @"This NIB format is not supported by GNUstep GUI."];
          [objects
              addObjectsFromArray: NSAllMapTableKeys (
                                      [(NSIBObjectData *)container objects])];
          [connections addObjectsFromArray: [container connections]];
          NSEnumerator *namedObjects =
              [NSAllMapTableKeys ([(NSIBObjectData *)container names])
                  objectEnumerator];
          id namedObject;
          while ((namedObject = [namedObjects nextObject]))
            {
              NSString *name = NSMapGet ([(NSIBObjectData *)container names],
                                         namedObject);
              if ([name length])
                [connectionNames
                    setObject: name
                       forKey: [NSValue
                                  valueWithNonretainedObject: namedObject]];
            }
          id owner = [(NSIBObjectData *)container root];
          if (owner)
            [roles setObject: @"File's Owner"
                      forKey: [NSValue valueWithNonretainedObject: owner]];
        }
      [connectionNames addEntriesFromDictionary: roles];
      NSEnumerator *connectionEnumerator = [connections objectEnumerator];
      id connection;
      while ((connection = [connectionEnumerator nextObject]))
        [rows addObject: YCConnectionRow (connection, connectionNames)];
#else
      problem = @"Model previews require GNUstep GUI's archive decoders.";
#endif
    }
  @catch (NSException *exception)
    {
      problem = [NSString
          stringWithFormat: @"Unable to preview model: %@", [exception reason]];
      [objects removeAllObjects];
      [rows removeAllObjects];
    }
  @finally
    {
      [container release];
      [decoder release];
#ifdef GNUSTEP
      [NSClassSwapper setIsInInterfaceBuilder: wasInBuilder];
#endif
    }

  ASSIGN (_connections, rows);
  [_connectionTable reloadData];
  [_connectionHeading
      setStringValue:
          problem ? @"Connections unavailable"
          : [rows count]
              ? [NSString stringWithFormat: @"Connections (%lu) — read only",
                                           (unsigned long)[rows count]]
              : @"Connections — none in this model"];
  objectCanvas =
      [[YCModelCanvas alloc] initWithFrame: NSMakeRect (0, 0, 120, 400)];
  [objectCanvas setObjectsPane: YES];
  [self addLabel: @"Objects" toCanvas: objectCanvas y: &objectY];
  canvas = [[YCModelCanvas alloc] initWithFrame: NSMakeRect (0, 0, width, 400)];
  [self addLabel: @"Interface preview — read only" toCanvas: canvas y: &y];
  [self
      addLabel:
          @"Custom controls use available base classes. Application code is not loaded."
      toCanvas: canvas
             y: &y];
  if (problem)
    [self addLabel: problem toCanvas: canvas y: &y];
  else
    {
      NSMutableSet *seen = [NSMutableSet set];
      NSMutableArray *objectLabels = [NSMutableArray array];
      NSMutableArray *objectKeys = [NSMutableArray array];
      if ([specialObjects count])
        {
          [objectLabels
              addObjectsFromArray: [NSArray arrayWithObjects: @"File's Owner",
                                                            @"First Responder",
                                                            nil]];
          [objectKeys
              addObjectsFromArray: [NSArray arrayWithObjects: @"NSOwner",
                                                            @"NSFirst", nil]];
        }
      NSEnumerator *enumerator = [objects objectEnumerator];
      id object;
      while ((object = [enumerator nextObject]))
        {
          NSView *view = nil;
          BOOL window = NO;
          NSUInteger style = 0;
          NSString *title = NSStringFromClass ([object class]);
          if ([seen containsObject: object] ||
              [specialObjects containsObject: object])
            continue;
          [seen addObject: object];
          /* Menu entries, table columns, and cells belong to their graphical
           * owners, not the nonvisual object palette. Include all subclasses. */
          if ([object isKindOfClass: [NSMenuItem class]] ||
              [object isKindOfClass: [NSTableColumn class]] ||
              [object isKindOfClass: [NSCell class]])
            continue;
          if ([object isKindOfClass: [NSWindow class]])
            {
              view = [object contentView];
              window = YES;
              style = [object styleMask];
              title = [object title];
              [object setReleasedWhenClosed: NO];
            }
#ifdef GNUSTEP
          else if ([object isKindOfClass: [NSWindowTemplate class]])
            {
              view = [object view];
              window = YES;
              style = [object windowStyle];
              title = [object title];
            }
          else if ([object isKindOfClass: [NSCustomObject class]] ||
                   [object isKindOfClass: [YCPreviewNibItem class]])
            title = [object className];
#endif
          else if ([object isKindOfClass: [NSView class]])
            {
              if ([object superview])
                continue;
              view = object;
            }
          else if ([object isKindOfClass: [NSMenu class]])
            {
              if ([object supermenu])
                continue;
              [self addMenu: object
                   toCanvas: canvas
                      depth: 1
                    visited: [NSMutableSet set]];
              continue;
            }
          if (view)
            {
              [view setAutoresizingMask: NSViewNotSizable];
              YCModelWindowFrame *frame = [[YCModelWindowFrame alloc]
                  initWithContentView: view
                                title: title
                            styleMask: window ? style : 0];
              YCMakeModelViewReadOnly (frame, canvas);
              [canvas addPreviewView: frame];
              [self registerEndpointHierarchy: frame];
              [self registerEndpointView: frame forObject: object];
              [frame release];
            }
          else
            {
              NSString *role = [roles
                  objectForKey: [NSValue valueWithNonretainedObject: object]];
              if ([title isEqual: @"FirstResponder"])
                role = @"First Responder";
              [objectLabels addObject: role ? role : title];
              [objectKeys addObject: YCConnectionKey (object)];
            }
        }
      if ([objectLabels count])
        {

          NSEnumerator *labels = [objectLabels objectEnumerator];
          NSString *label;
          NSUInteger objectIndex = 0;
          while ((label = [labels nextObject]))
            {
              NSString *icon = @"GormUnknown";
              if ([label isEqual: @"NSFontManager"])
                icon = @"GormFontManager";
              if ([label isEqual: @"File's Owner"])
                icon = @"GormFilesOwner";
              else if ([label isEqual: @"First Responder"])
                icon = @"GormFirstResponder";
              NSView *tile = [[NSView alloc]
                  initWithFrame: NSMakeRect (8, objectY, 104, 100)];
              NSString *imagePath = [[NSBundle bundleForClass: [self class]]
                  pathForResource: icon
                           ofType: @"tiff"];
              NSImage *image =
                  [[NSImage alloc] initWithContentsOfFile: imagePath];
              NSImageView *iconView = [[NSImageView alloc]
                  initWithFrame: NSMakeRect (28, 42, 48, 48)];
              [iconView setImage: image];
              [iconView setImageScaling: NSImageScaleProportionallyDown];
              [iconView setToolTip: label];
              [tile addSubview: iconView];
              [iconView release];
              [image release];
              NSTextField *caption = [[NSTextField alloc]
                  initWithFrame: NSMakeRect (0, 2, 104, 36)];
              [caption setStringValue: label];
              [caption setToolTip: label];
              [caption setEditable: NO];
              [caption setBezeled: NO];
              [caption setDrawsBackground: NO];
              [caption setTextColor: [NSColor colorWithCalibratedWhite: 0.94
                                                                alpha: 1]];
              [caption setAlignment: NSCenterTextAlignment];
              [tile addSubview: caption];
              [caption release];
              [objectCanvas addSubview: tile];
              NSDictionary *endpoint =
                  [NSDictionary dictionaryWithObject: iconView forKey: @"view"];
              [_endpointViews
                  setObject: endpoint
                     forKey: [objectKeys objectAtIndex: objectIndex++]];
              if ([label isEqual: @"File's Owner"])
                [_endpointViews setObject: endpoint forKey: @"NSOwner"];
              else if ([label isEqual: @"First Responder"])
                [_endpointViews setObject: endpoint forKey: @"NSFirst"];
              YCMakeModelViewReadOnly (tile, objectCanvas);
              [tile release];
              objectY += 108;
            }
        }
      if (![objects count])
        [self addLabel: @"No previewable objects in this model."
              toCanvas: canvas
                     y: &y];
    }
  NSEnumerator *aliases = [endpointAliases keyEnumerator];
  NSString *alias;
  while ((alias = [aliases nextObject]))
    {
      NSDictionary *endpoint =
          [_endpointViews objectForKey: [endpointAliases objectForKey: alias]];
      if (endpoint)
        [_endpointViews setObject: endpoint forKey: alias];
    }
  [canvas setPostsFrameChangedNotifications: YES];
  [canvas setPostsBoundsChangedNotifications: YES];
  [[_scrollView contentView] setPostsBoundsChangedNotifications: YES];
  [[_objectScrollView contentView] setPostsBoundsChangedNotifications: YES];
  [canvas setPreviewTop: y];
  [objectCanvas setFrameSize: NSMakeSize (120, MAX (objectY + 20, 400))];
  [_objectScrollView setDocumentView: objectCanvas];
  [objectCanvas release];
  [[_objectScrollView contentView] scrollToPoint: NSZeroPoint];
  [_scrollView setDocumentView: canvas];
  [canvas layoutPreviews];
  [canvas release];
  ASSIGN (_objects, objects);
  [[_scrollView contentView] scrollToPoint: NSZeroPoint];
  [self setModified: NO];
  ASSIGN (_lastModified,
          [[[NSFileManager defaultManager] attributesOfItemAtPath: path
                                                            error: NULL]
              fileModificationDate]);
  [[NSNotificationCenter defaultCenter]
      postNotificationName: YCodeCurrentDocumentDidChangeNotification
                    object: _editorController];
  return YES;
}

@end
