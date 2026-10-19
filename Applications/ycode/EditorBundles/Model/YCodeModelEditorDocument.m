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
#ifdef GNUSTEP
#import <GNUstepGUI/GSGormLoading.h>
#import <GNUstepGUI/GSNibLoading.h>
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

/* Intercept input before it reaches any archived control. The surrounding
 * scroll view remains interactive, but the model cannot receive actions. */
@interface YCModelCanvas : NSView
{
  BOOL _objectsPane;
  BOOL _layingOut;
  CGFloat _previewTop;
  NSMutableArray *_previewViews;
  NSMutableArray *_previewSizes;
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
  [super dealloc];
}
- (void) addPreviewView: (NSView *)view
{
  if (_previewViews == nil)
    {
      _previewViews = [[NSMutableArray alloc] init];
      _previewSizes = [[NSMutableArray alloc] init];
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
          x += size.width + 24;
          rowHeight = MAX (rowHeight, size.height);
        }
      [self setFrameSize: NSMakeSize (width, MAX (y + rowHeight + 20,
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
- (void) drawRect: (NSRect)rect
{
  [YCModelBackground (_objectsPane) set];
  NSRectFill (rect);
}
@end

/* These frames are views, not application windows: the archived interface
 * stays inside the editor and never enters NSApplication's window lifecycle. */
static const CGFloat YCModelTitleHeight = 22;

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

@interface YCModelWindowFrame : NSView
{
  NSUInteger _previewStyle;
}
- (id) initWithContentView: (NSView *)view
                    title: (NSString *)title
                styleMask: (NSUInteger)style;
@end
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

@interface YCodeModelEditorDocument : YCodeEditorDocument
{
  NSView *_editorView;
  NSScrollView *_objectScrollView;
  NSScrollView *_scrollView;
  NSArray *_objects;
}
- (void) addLabel: (NSString *)label toCanvas: (NSView *)canvas y: (CGFloat *)y;
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
      _editorView = [[NSView alloc] initWithFrame: NSMakeRect (0, 0, 600, 400)];
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
          [[NSScrollView alloc] initWithFrame: NSMakeRect (141, 0, 459, 400)];
      [_editorView addSubview: _scrollView];
      [_scrollView setHasVerticalScroller: YES];
      [_scrollView setHasHorizontalScroller: NO];
      [_scrollView setAutohidesScrollers: YES];
      [_scrollView setBackgroundColor: YCModelBackground (NO)];
      [_scrollView
          setAutoresizingMask: NSViewWidthSizable | NSViewHeightSizable];
    }
  return self;
}
- (void) dealloc
{
  [_editorView release];
  [_objectScrollView release];
  [_scrollView release];
  [_objects release];
  [super dealloc];
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
          NSDictionary *names = [container nameTable];
          NSEnumerator *keys = [[[names allKeys]
              sortedArrayUsingSelector: @selector (compare:)] objectEnumerator];
          NSString *key;
          while ((key = [keys nextObject]))
            {
              id object = [names objectForKey: key];
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
          NSDictionary *decoded = [(GSXibKeyedUnarchiver *)decoder decoded];
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
          id owner = [(NSIBObjectData *)container root];
          if (owner)
            [roles setObject: @"File's Owner"
                      forKey: [NSValue valueWithNonretainedObject: owner]];
        }
#else
      problem = @"Model previews require GNUstep GUI's archive decoders.";
#endif
    }
  @catch (NSException *exception)
    {
      problem = [NSString
          stringWithFormat: @"Unable to preview model: %@", [exception reason]];
      [objects removeAllObjects];
    }
  @finally
    {
      [container release];
      [decoder release];
#ifdef GNUSTEP
      [NSClassSwapper setIsInInterfaceBuilder: wasInBuilder];
#endif
    }

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
      if ([specialObjects count])
        [objectLabels
            addObjectsFromArray: [NSArray arrayWithObjects: @"File's Owner",
                                                          @"First Responder",
                                                          nil]];
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
              [frame release];
            }
          else
            {
              NSString *role = [roles
                  objectForKey: [NSValue valueWithNonretainedObject: object]];
              if ([title isEqual: @"FirstResponder"])
                role = @"First Responder";
              [objectLabels addObject: role ? role : title];
            }
        }
      if ([objectLabels count])
        {

          NSEnumerator *labels = [objectLabels objectEnumerator];
          NSString *label;
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
