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
#define PREVIEW_TEMPLATE(base) \
@interface YCPreview##base : base @end \
@implementation YCPreview##base \
- (BOOL)shouldSwapClass { return NO; } \
@end
PREVIEW_TEMPLATE(GSWindowTemplate)
PREVIEW_TEMPLATE(GSViewTemplate)
PREVIEW_TEMPLATE(GSTextTemplate)
PREVIEW_TEMPLATE(GSTextViewTemplate)
PREVIEW_TEMPLATE(GSMenuTemplate)
PREVIEW_TEMPLATE(GSControlTemplate)
PREVIEW_TEMPLATE(GSObjectTemplate)

/* Older Gorm archives use GSNibItem for controllers and GSCustomView for
 * application views. Decode their descriptions without constructing the class. */
static NSString *YCDecodeNibItem(NSCoder *coder, NSString *className, NSRect *frame)
{
  NSString *name = nil;
  unsigned int mask;
  int version = [coder versionForClassName:className];
  if (version != 0 && version != 1)
    [NSException raise:NSInvalidArgumentException format:@"Unsupported %@ version", className];
  [coder decodeValueOfObjCType:@encode(id) at:&name];
  *frame = [coder decodeRect];
  if (version == 1) [coder decodeValueOfObjCType:@encode(unsigned int) at:&mask];
  return [name autorelease];
}

@interface YCPreviewNibItem : NSObject <NSCoding>
{
  NSString *_modelClassName;
}
- (NSString *)className;
@end
@implementation YCPreviewNibItem
- (id)initWithCoder:(NSCoder *)coder
{
  if ((self = [super init]))
    {
      NSRect frame;
      _modelClassName = [YCDecodeNibItem(coder, @"GSNibItem", &frame) copy];
    }
  return self;
}
- (void)encodeWithCoder:(NSCoder *)coder {}
- (NSString *)className { return _modelClassName; }
- (void)dealloc { [_modelClassName release]; [super dealloc]; }
@end

@interface YCPreviewCustomView : NSView
@end
@implementation YCPreviewCustomView
- (id)initWithCoder:(NSCoder *)coder
{
  NSRect frame;
  NSString *name = YCDecodeNibItem(coder, @"GSCustomView", &frame);
  if ((self = [super initWithFrame:frame]))
    {
      NSTextField *label = [[NSTextField alloc] initWithFrame:NSMakeRect(4, 4, MAX(0, frame.size.width - 8), 24)];
      [label setStringValue:[NSString stringWithFormat:@"Custom view: %@", name]];
      [label setEditable:NO];
      [label setBezeled:NO];
      [label setDrawsBackground:NO];
      [self addSubview:label];
      [label release];
    }
  return self;
}
@end
#endif

/* Intercept input before it reaches any archived control. The surrounding
 * scroll view remains interactive, but the model cannot receive actions. */
@interface YCModelCanvas : NSView
@end
@implementation YCModelCanvas
- (BOOL)isFlipped { return YES; }
- (NSView *)nextKeyView { return nil; }
- (NSView *)hitTest:(NSPoint)point
{
  return [super hitTest:point] ? self : nil;
}
- (void)drawRect:(NSRect)rect
{
  [[NSColor windowBackgroundColor] set];
  NSRectFill(rect);
}
@end

/* These frames are views, not application windows: the archived interface
 * stays inside the editor and never enters NSApplication's window lifecycle. */
@interface YCModelWindowFrame : NSView
- (id)initWithContentView:(NSView *)view title:(NSString *)title styleMask:(NSUInteger)style;
@end
@implementation YCModelWindowFrame
- (id)initWithContentView:(NSView *)view title:(NSString *)title styleMask:(NSUInteger)style
{
  NSSize size = [view frame].size;
  CGFloat barHeight = (style & NSTitledWindowMask) ? 28 : 0;
  if ((self = [super initWithFrame:NSMakeRect(0, 0, size.width + 2, size.height + barHeight + 2)]))
    {
      [view removeFromSuperview];
      [view setFrameOrigin:NSMakePoint(1, 1)];
      [self addSubview:view];
      if (barHeight)
        {
          NSTextField *label = [[NSTextField alloc] initWithFrame:
            NSMakeRect(28, size.height + 5, MAX(0, size.width - 56), 22)];
          [label setStringValue:title ? title : @""];
          [label setAlignment:NSCenterTextAlignment];
          [label setFont:[NSFont boldSystemFontOfSize:[NSFont systemFontSize]]];
          [label setEditable:NO];
          [label setBezeled:NO];
          [label setDrawsBackground:NO];
          [self addSubview:label];
          [label release];
          if (style & NSClosableWindowMask)
            {
              NSButton *button = [NSWindow standardWindowButton:NSWindowCloseButton forStyleMask:style];
              [button setFrameOrigin:NSMakePoint(size.width - [button frame].size.width - 4, size.height + 5)];
              [button setTarget:nil];
              [button setAction:NULL];
              [self addSubview:button];
            }
        }
    }
  return self;
}
- (void)drawRect:(NSRect)rect
{
  [[NSColor windowBackgroundColor] set];
  NSRectFill([self bounds]);
  [[NSColor shadowColor] set];
  NSFrameRect([self bounds]);
  if ([[self subviews] count] > 1)
    {
      NSRect bar = NSMakeRect(1, [self bounds].size.height - 29, [self bounds].size.width - 2, 28);
      [[NSColor controlColor] set];
      NSRectFill(bar);
      [[NSColor shadowColor] set];
      NSRectFill(NSMakeRect(1, bar.origin.y, bar.size.width, 1));
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
- (id)initWithPreviewMenu:(NSMenu *)menu;
@end
@implementation YCModelMenuView
- (id)initWithPreviewMenu:(NSMenu *)menu
{
  if ((self = [super initWithFrame:NSZeroRect]))
    {
      _previewMenu = [menu retain];
      [menu setAutoenablesItems:NO];
      [self setMenu:menu];
      [self sizeToFit];
    }
  return self;
}
- (void)dealloc
{
  [self setMenu:nil];
  [_previewMenu release];
  [super dealloc];
}
@end
#endif

/* Keep keyboard traversal from entering archived text fields or controls. */
static void YCMakeModelViewReadOnly(NSView *view, NSView *canvas)
{
  NSEnumerator *enumerator = [[view subviews] objectEnumerator];
  NSView *child;
  [view setNextKeyView:canvas];
  if ([view isKindOfClass:[NSControl class]])
    [(NSControl *)view setRefusesFirstResponder:YES];
  if ([view isKindOfClass:[NSTextView class]])
    {
      [(NSTextView *)view setEditable:NO];
      [(NSTextView *)view setSelectable:NO];
    }
  while ((child = [enumerator nextObject])) YCMakeModelViewReadOnly(child, canvas);
}

@interface YCodeModelEditorDocument : YCodeEditorDocument
{
  NSScrollView *_scrollView;
  NSArray *_objects;
}
- (void)addLabel:(NSString *)label toCanvas:(NSView *)canvas y:(CGFloat *)y;
- (void)addMenu:(NSMenu *)menu toCanvas:(NSView *)canvas y:(CGFloat *)y
         depth:(NSUInteger)depth visited:(NSMutableSet *)visited width:(CGFloat *)width;
@end

@implementation YCodeModelEditorDocument
+ (NSString *)editorIdentifier { return @"model"; }
+ (NSString *)editorKind { return @"model"; }
+ (NSInteger)editorPriority { return 300; }
+ (BOOL)canOpenFilePath:(NSString *)path
{
  return [[NSArray arrayWithObjects:@"gorm", @"xib", @"nib", nil]
    containsObject:[[path pathExtension] lowercaseString]];
}
- (id)initWithFilePath:(NSString *)path
{
  if ((self = [super initWithFilePath:path]))
    {
      _scrollView = [[NSScrollView alloc] initWithFrame:NSMakeRect(0, 0, 600, 400)];
      [_scrollView setHasVerticalScroller:YES];
      [_scrollView setHasHorizontalScroller:YES];
      [_scrollView setAutohidesScrollers:YES];
      [_scrollView setAutoresizingMask:NSViewWidthSizable | NSViewHeightSizable];
    }
  return self;
}
- (void)dealloc
{
  [_scrollView release];
  [_objects release];
  [super dealloc];
}
- (NSView *)editorView { return _scrollView; }
- (NSScrollView *)scrollView { return _scrollView; }

- (void)addLabel:(NSString *)label toCanvas:(NSView *)canvas y:(CGFloat *)y
{
  NSTextField *field = [[NSTextField alloc] initWithFrame:NSMakeRect(20, *y, 700, 24)];
  [field setStringValue:label ? label : @""];
  [field setToolTip:label];
  [field setEditable:NO];
  [field setSelectable:NO];
  [field setBezeled:NO];
  [field setDrawsBackground:NO];
  [canvas addSubview:field];
  [field release];
  *y += 28;
}
- (void)addMenu:(NSMenu *)menu toCanvas:(NSView *)canvas y:(CGFloat *)y
         depth:(NSUInteger)depth visited:(NSMutableSet *)visited width:(CGFloat *)width
{
  NSEnumerator *enumerator;
  NSMenuItem *item;
  if ([visited containsObject:menu] || depth > 32) return;
  [visited addObject:menu];
#ifdef GNUSTEP
  YCModelMenuView *view = [[YCModelMenuView alloc] initWithPreviewMenu:menu];
  [view setFrameOrigin:NSMakePoint(20, *y)];
  [canvas addSubview:view];
  YCMakeModelViewReadOnly(view, canvas);
  *width = MAX(*width, [view frame].size.width + 40);
  *y += [view frame].size.height + 20;
  [view release];
#endif
  enumerator = [[menu itemArray] objectEnumerator];
  while ((item = [enumerator nextObject]))
    if ([item submenu])
      [self addMenu:[item submenu] toCanvas:canvas y:y depth:depth + 1 visited:visited width:width];
}

- (BOOL)loadFromFile
{
  BOOL directory = NO;
  NSString *extension = [[_filePath pathExtension] lowercaseString];
  NSString *path = _filePath;
  NSMutableArray *objects = [NSMutableArray array];
  NSString *problem = nil;
  YCModelCanvas *canvas;
  CGFloat y = 20, width = 740;
  id decoder = nil;
  id container = nil;
#ifdef GNUSTEP
  BOOL wasInBuilder = [NSClassSwapper isInInterfaceBuilder];
#endif
  if (![[NSFileManager defaultManager] fileExistsAtPath:path isDirectory:&directory]) return NO;
  if (directory)
    path = [path stringByAppendingPathComponent:[extension isEqual:@"gorm"] ? @"objects.gorm" : @"keyedobjects.nib"];
  @try
    {
#ifdef GNUSTEP
      NSData *data = [NSData dataWithContentsOfFile:path];
      if (![data length])
        [NSException raise:NSInvalidArgumentException format:@"The model contains no readable archive."];
      [NSClassSwapper setIsInInterfaceBuilder:YES];
      if ([extension isEqual:@"gorm"])
        {
          NSArray *templates = [NSArray arrayWithObjects:@"GSWindowTemplate", @"GSViewTemplate",
            @"GSTextTemplate", @"GSTextViewTemplate", @"GSMenuTemplate",
            @"GSControlTemplate", @"GSObjectTemplate", nil];
          NSEnumerator *enumerator = [templates objectEnumerator];
          NSString *name;
          decoder = [[NSUnarchiver alloc] initForReadingWithData:data];
          [decoder decodeClassName:@"GSNibItem" asClassName:@"YCPreviewNibItem"];
          [decoder decodeClassName:@"GSCustomView" asClassName:@"YCPreviewCustomView"];
          while ((name = [enumerator nextObject]))
            [decoder decodeClassName:name asClassName:[@"YCPreview" stringByAppendingString:name]];
          container = [[decoder decodeObject] retain];
          if (![container isKindOfClass:[GSNibContainer class]])
            [NSException raise:NSInvalidArgumentException format:@"Not a Gorm model archive."];
          [objects addObjectsFromArray:[[container nameTable] allValues]];
          [objects addObjectsFromArray:[[container topLevelObjects] allObjects]];
        }
      else if ([extension isEqual:@"xib"])
        {
          decoder = [[GSXibKeyedUnarchiver unarchiverForReadingWithData:data] retain];
          NSArray *roots = [decoder decodeObjectForKey:@"IBDocument.RootObjects"];
          if (![roots isKindOfClass:[NSArray class]])
            [NSException raise:NSInvalidArgumentException format:@"This XIB format is not supported by GNUstep GUI."];
          [objects addObjectsFromArray:roots];
        }
      else
        {
          decoder = [[NSKeyedUnarchiver alloc] initForReadingWithData:data];
          container = [[decoder decodeObjectForKey:@"IB.objectdata"] retain];
          if (![container isKindOfClass:[NSIBObjectData class]])
            [NSException raise:NSInvalidArgumentException format:@"This NIB format is not supported by GNUstep GUI."];
          [objects addObjectsFromArray:NSAllMapTableKeys([(NSIBObjectData *)container objects])];
        }
#else
      problem = @"Model previews require GNUstep GUI's archive decoders.";
#endif
    }
  @catch (NSException *exception)
    {
      problem = [NSString stringWithFormat:@"Unable to preview model: %@", [exception reason]];
      [objects removeAllObjects];
    }
  @finally
    {
      [container release];
      [decoder release];
#ifdef GNUSTEP
      [NSClassSwapper setIsInInterfaceBuilder:wasInBuilder];
#endif
    }

  canvas = [[YCModelCanvas alloc] initWithFrame:NSMakeRect(0, 0, width, 400)];
  [self addLabel:@"Interface preview — read only" toCanvas:canvas y:&y];
  [self addLabel:@"Custom controls use available base classes. Application code is not loaded."
       toCanvas:canvas y:&y];
  if (problem) [self addLabel:problem toCanvas:canvas y:&y];
  else
    {
      NSMutableSet *seen = [NSMutableSet set];
      NSMutableArray *objectLabels = [NSMutableArray array];
      NSEnumerator *enumerator = [objects objectEnumerator];
      id object;
      while ((object = [enumerator nextObject]))
        {
          NSView *view = nil;
          BOOL window = NO;
          NSUInteger style = 0;
          NSString *title = NSStringFromClass([object class]);
          if ([seen containsObject:object]) continue;
          [seen addObject:object];
          if ([object isKindOfClass:[NSWindow class]])
            {
              view = [object contentView];
              window = YES;
              style = [object styleMask];
              title = [object title];
              [object setReleasedWhenClosed:NO];
            }
#ifdef GNUSTEP
          else if ([object isKindOfClass:[NSWindowTemplate class]])
            {
              view = [object view];
              window = YES;
              style = [object windowStyle];
              title = [object title];
            }
          else if ([object isKindOfClass:[NSCustomObject class]] ||
                   [object isKindOfClass:[YCPreviewNibItem class]])
            title = [NSString stringWithFormat:@"Object: %@", [object className]];
#endif
          else if ([object isKindOfClass:[NSView class]])
            {
              if ([object superview]) continue;
              view = object;
            }
          else if ([object isKindOfClass:[NSMenu class]])
            {
              if ([object supermenu]) continue;
              [self addMenu:object toCanvas:canvas y:&y depth:1 visited:[NSMutableSet set] width:&width];
              continue;
            }
          if (view)
            {
              [view setAutoresizingMask:NSViewNotSizable];
              YCModelWindowFrame *frame = [[YCModelWindowFrame alloc] initWithContentView:view
                title:title styleMask:window ? style : 0];
              [frame setFrameOrigin:NSMakePoint(20, y)];
              YCMakeModelViewReadOnly(frame, canvas);
              [canvas addSubview:frame];
              width = MAX(width, [frame frame].size.width + 40);
              y += [frame frame].size.height + 24;
              [frame release];
            }
          else
            [objectLabels addObject:title];
        }
      if ([objectLabels count])
        {
          [self addLabel:@"Nonvisual objects" toCanvas:canvas y:&y];
          NSEnumerator *labels = [objectLabels objectEnumerator];
          NSString *label;
          while ((label = [labels nextObject])) [self addLabel:label toCanvas:canvas y:&y];
        }
      if (![objects count]) [self addLabel:@"No previewable objects in this model." toCanvas:canvas y:&y];
    }
  [canvas setFrameSize:NSMakeSize(width, MAX(y + 20, 400))];
  [_scrollView setDocumentView:canvas];
  [canvas release];
  ASSIGN(_objects, objects);
  [[_scrollView contentView] scrollToPoint:NSZeroPoint];
  [self setModified:NO];
  ASSIGN(_lastModified, [[[NSFileManager defaultManager] attributesOfItemAtPath:path error:NULL] fileModificationDate]);
  [[NSNotificationCenter defaultCenter] postNotificationName:YCodeCurrentDocumentDidChangeNotification
    object:_editorController];
  return YES;
}
@end
