/*
    YCodeTextView.h

    Source editing rules adapted from ProjectCenter PCEditorView.

    Copyright (C) 2005-2021 Free Software Foundation
      Saso Kiselkov
      Serg Stoyan
      Riccardo Mottola

    This program is free software; you can redistribute it and/or modify
    it under the terms of the GNU General Public License as published by
    the Free Software Foundation; either version 2 of the License, or
    (at your option) any later version.

    This program is distributed in the hope that it will be useful,
    but WITHOUT ANY WARRANTY; without even the implied warranty of
    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
    GNU General Public License for more details.

    You should have received a copy of the GNU General Public License
    along with this program; if not, write to the Free Software
    Foundation, Inc., 31 Milk Street #960789 Boston, MA 02196 USA
*/

#ifndef _YCODETEXTVIEW_H_
#define _YCODETEXTVIEW_H_

#import <AppKit/AppKit.h>

/** Source editor with ProjectCenter indentation and selection rules. */
@interface YCodeTextView : NSTextView
{
  NSString *_filePath;
  NSUInteger editorIndentWidth;
  NSUInteger editorTabWidth;
  BOOL editorUsesTabs;
  BOOL editorIndentSettingsLoaded;
  BOOL _fittingViewport;
  NSDictionary *_delimiterMatches;
  NSRange _matchingDelimiterRange;
}
- (void)setFilePath:(NSString *)path;
- (NSUInteger)editorTabWidth;
- (NSUInteger)editorIndentWidth;
- (BOOL)editorUsesTabs;
- (void)setEditorTabWidth:(NSUInteger)width;
- (void)setEditorUsesTabs:(BOOL)usesTabs;
- (void)updateEditorParagraphStyle;
- (IBAction)toggleLineComment:(id)sender;
- (IBAction)convertTabsToSpaces:(id)sender;
@end

#endif
