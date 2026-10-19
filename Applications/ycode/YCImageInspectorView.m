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

#import "YCImageInspectorView.h"
#import "YCodeEditorDocument.h"

@implementation YCImageInspectorView
- (NSString *) inspectorIdentifier
{
  return @"image";
}

- (NSString *) inspectorTitle
{
  return @"Image";
}

- (void) inspectDocument: (YCodeEditorDocument *)document
{
  if (![document isImageDocument])
    {
      [_details setString: @"No image selected."];
      return;
    }
  [super inspectDocument: document];
  NSImageRep *representation =
      [[[document image] representations] firstObject];
  NSString *dimensions = @"Unavailable";
  if ([representation pixelsWide] > 0 && [representation pixelsHigh] > 0)
    dimensions = [NSString stringWithFormat: @"%ld × %ld pixels",
                                            (long)[representation pixelsWide],
                                            (long)[representation pixelsHigh]];
  NSString *depth =
      [representation bitsPerSample] > 0
          ? [NSString stringWithFormat: @"%ld bits per sample",
                                       (long)[representation bitsPerSample]]
          : @"Unavailable";
  NSString *colorSpace = [representation colorSpaceName];
  NSString *details = [NSString
      stringWithFormat:
          @"%@\n\nDimensions\n%@\n\nColor Space\n%@\n\nColor Depth\n%@\n\nTransparency\n%@\n\nEditing\nRead-only preview",
          [_details string], dimensions,
          colorSpace ? colorSpace : @"Unavailable", depth,
          [representation hasAlpha] ? @"Yes" : @"No"];
  [_details setString: details];
}

@end
