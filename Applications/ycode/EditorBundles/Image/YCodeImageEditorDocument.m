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

@interface YCodeImageClipView : NSClipView
@end

@implementation YCodeImageClipView
- (NSPoint) constrainScrollPoint: (NSPoint)point
{
  point = [super constrainScrollPoint: point];
  NSRect document = [[self documentView] frame];
  NSSize viewport = [self bounds].size;
  if (document.size.width < viewport.width)
    point.x = NSMidX (document) - viewport.width / 2;
  if (document.size.height < viewport.height)
    point.y = NSMidY (document) - viewport.height / 2;
  return point;
}

@end

@interface YCodeImageEditorDocument : YCodeEditorDocument
{
  NSScrollView *_scrollView;
  NSImage *_image;
}

@end

@implementation YCodeImageEditorDocument
+ (NSString *) editorIdentifier
{
  return @"image";
}

+ (NSString *) editorKind
{
  return @"image";
}

+ (NSInteger) editorPriority
{
  return 100;
}

+ (BOOL) canOpenFilePath: (NSString *)path
{
  NSString *extension = [[path pathExtension] lowercaseString];
  // Some image backends advertise TXT as an image interchange format.
  // Plain text files must remain editable by the fallback text bundle.
  if ([extension isEqual: @"txt"] || [extension isEqual: @"text"])
    return NO;
  return [[NSImage imageFileTypes] containsObject: extension] ||
         [[NSArray arrayWithObjects: @"png", @"jpg", @"jpeg", @"gif", @"tif",
                                    @"tiff", @"bmp", @"ico", @"icns", @"webp",
                                    nil] containsObject: extension];
}

- (NSImage *) image
{
  return _image;
}

- (id) initWithFilePath: (NSString *)path
{
  self = [super initWithFilePath: path];
  if (self)
    {
      _scrollView =
          [[NSScrollView alloc] initWithFrame: NSMakeRect (0, 0, 400, 300)];
      [_scrollView setHasVerticalScroller: YES];
      [_scrollView setHasHorizontalScroller: YES];
      [_scrollView setAutohidesScrollers: YES];
      [_scrollView setBorderType: NSNoBorder];
      [_scrollView
          setAutoresizingMask: NSViewWidthSizable | NSViewHeightSizable];
    }
  return self;
}

- (void) dealloc
{
  RELEASE (_scrollView);
  RELEASE (_image);
  [super dealloc];
}

- (NSView *) editorView
{
  return _scrollView;
}

- (NSScrollView *) scrollView
{
  return _scrollView;
}

- (BOOL) loadFromFile
{
  NSImage *image = [[NSImage alloc] initWithContentsOfFile: _filePath];
  if (!image || ![image isValid])
    {
      RELEASE (image);
      return NO;
    }
  ASSIGN (_image, image);
  RELEASE (image);
  YCodeImageClipView *clip = [[YCodeImageClipView alloc]
      initWithFrame: [[_scrollView contentView] frame]];
  [_scrollView setContentView: clip];
  RELEASE (clip);
  NSImageView *preview =
      [[NSImageView alloc] initWithFrame: NSMakeRect (0, 0, [_image size].width,
                                                     [_image size].height)];
  [preview setImage: _image];
  [preview setImageScaling: NSImageScaleNone];
  [preview setEditable: NO];
  [_scrollView setDocumentView: preview];
  [[_scrollView contentView] scrollToPoint: NSZeroPoint];
  RELEASE (preview);
  [self setModified: NO];
  NSDictionary *attributes =
      [[NSFileManager defaultManager] attributesOfItemAtPath: _filePath
                                                       error: NULL];
  ASSIGN (_lastModified, [attributes fileModificationDate]);
  [[NSNotificationCenter defaultCenter]
      postNotificationName: YCodeCurrentDocumentDidChangeNotification
                    object: _editorController];
  return YES;
}

@end
