/*
   Project: Ycode

   Copyright (C) 2018 Free Software Foundation

   Author: Gregory John Casamento,,,

   Created: 2018-12-17 20:16:45 -0500 by heron

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

#import "YCFileInspectorView.h"
#import "YCodeEditorDocument.h"

@implementation YCFileInspectorView
- (id) initWithFrame: (NSRect)frame
{
  self = [super initWithFrame: frame];
  if (self)
    {
      NSScrollView *scroll =
          [[NSScrollView alloc] initWithFrame: [self bounds]];
      [scroll setAutoresizingMask: NSViewWidthSizable | NSViewHeightSizable];
      [scroll setHasVerticalScroller: YES];
      _details = [[NSTextView alloc] initWithFrame: [scroll bounds]];
      [_details setEditable: NO];
      [_details setSelectable: YES];
      [_details setFont: [NSFont systemFontOfSize: 12]];
      [_details setTextContainerInset: NSMakeSize (8, 8)];
      [_details setAutoresizingMask: NSViewWidthSizable];
      [_details setHorizontallyResizable: NO];
      [[_details textContainer] setWidthTracksTextView: YES];
      [scroll setDocumentView: _details];
      [self addSubview: scroll];
      RELEASE (_details);
      RELEASE (scroll);
      [self inspectDocument: nil];
    }
  return self;
}

- (NSString *) inspectorIdentifier
{
  return @"file";
}
- (NSString *) inspectorTitle
{
  return @"File";
}

- (void) inspectDocument: (YCodeEditorDocument *)document
{
  if (!document)
    {
      [_details setString: @"No source file selected."];
      return;
    }
  NSString *path = [[document filePath] stringByStandardizingPath];
  if (![path isAbsolutePath])
    path = [[[NSFileManager defaultManager] currentDirectoryPath]
        stringByAppendingPathComponent: path];
  NSDictionary *attributes =
      [[NSFileManager defaultManager] attributesOfItemAtPath: path error: NULL];
  NSString *extension = [[document fileExtension] lowercaseString];
  NSDictionary *types = [NSDictionary
      dictionaryWithObjectsAndKeys: @"Objective-C source", @"m",
                                   @"Objective-C++ source", @"mm", @"C source",
                                   @"c", @"C++ source", @"cpp", @"C++ source",
                                   @"cc", @"C/C++ header", @"h", @"C++ header",
                                   @"hpp", @"Swift source", @"swift", nil];
  NSString *type = [types objectForKey: extension];
  if (!type)
    type = [extension length] ? [extension stringByAppendingString: @" file"]
                              : @"Text file";
  NSString *size
      = attributes
            ? [NSString stringWithFormat: @"%@ bytes",
                                         [attributes objectForKey: NSFileSize]]
            : @"Unavailable";
  NSString *date =
      [[attributes objectForKey: NSFileModificationDate] description];
  [_details
      setString:
          [NSString
              stringWithFormat:
                  @"Name\n%@\n\nType\n%@\n\nFull Path\n%@\n\nSize on Disk\n%@\n\nModified on Disk\n%@",
                  [document fileName], type, path, size,
                  date ? date : @"Unavailable"]];
}
@end
