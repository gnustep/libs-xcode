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

@interface YCodeSoundEditorDocument : YCodeEditorDocument
{
  NSScrollView *_scrollView;
}
@end

@implementation YCodeSoundEditorDocument
+ (NSString *) editorIdentifier
{
  return @"sound";
}
+ (NSString *) editorKind
{
  return @"sound";
}
+ (NSInteger) editorPriority
{
  return 200;
}
+ (BOOL) canOpenFilePath: (NSString *)path
{
  NSString *extension = [[path pathExtension] lowercaseString];
  return [[NSSound soundUnfilteredFileTypes] containsObject: extension] ||
         [[NSArray arrayWithObjects: @"wav", @"wave", @"aif", @"aiff", @"aifc",
                                    @"au", @"snd", @"mp3", @"flac", @"ogg",
                                    @"oga", @"m4a", @"aac", @"caf", @"opus",
                                    nil] containsObject: extension];
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
  BOOL directory = NO;
  if (![[NSFileManager defaultManager] isReadableFileAtPath: _filePath]
      || ![[NSFileManager defaultManager] fileExistsAtPath: _filePath
                                               isDirectory: &directory]
      || directory)
    return NO;
  NSTextField *preview =
      [[NSTextField alloc] initWithFrame: NSMakeRect (0, 0, 380, 100)];
  [preview
      setStringValue:
          [NSString
              stringWithFormat:
                  @"%@\n\nUse the Sound inspector to view the waveform and play this file.",
                  [self fileName]]];
  [preview setEditable: NO];
  [preview setBezeled: NO];
  [preview setDrawsBackground: NO];
  [preview setFont: [NSFont systemFontOfSize: 14]];
  [_scrollView setDocumentView: preview];
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
