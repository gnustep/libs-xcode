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
#import "YCodePreferences.h"
#import "YCEditorView.h"
#import "YCodeTextView.h"
#import "YCodeEditorController.h"
#import "YCodeSyntaxHighlighter.h"

@interface YCodeTextEditorDocument : YCodeEditorDocument
{
  NSString *_content;
  NSString *_savedContent;
  NSScrollView *_scrollView;
  NSTextView *_textView;
  NSRulerView *_lineNumberRuler;
  YCodeSyntaxHighlighter *_syntaxHighlighter;
}
@end

@implementation YCodeTextEditorDocument
+ (NSString *) editorIdentifier
{
  return @"text";
}
+ (NSString *) editorKind
{
  return @"text";
}
+ (NSInteger) editorPriority
{
  return -1000;
}
+ (BOOL) canOpenFilePath: (NSString *)path
{
  return [path length] > 0;
}
- (BOOL) isEditable
{
  return YES;
}
- (id) initWithFilePath: (NSString *)filePath
{
  self = [super initWithFilePath: filePath];
  if (self)
    {
      _content = [[NSString alloc] init];
      _savedContent = [[NSString alloc] init];
      _modified = NO;

      [self setupEditorView];
      [self setupSyntaxHighlighter];
      [[NSNotificationCenter defaultCenter]
          addObserver: self
             selector: @selector (editorColorsChanged:)
                 name: @"YCodeEditorColorsDidChange"
               object: nil];
      [[NSNotificationCenter defaultCenter]
          addObserver: self
             selector: @selector (editorRulersChanged:)
                 name: @"YCodeEditorRulersDidChange"
               object: nil];
      [[NSNotificationCenter defaultCenter]
          addObserver: self
             selector: @selector (editorFontsChanged:)
                 name: @"YCodeFontsDidChange"
               object: nil];
    }
  return self;
}

- (void) dealloc
{
  [NSObject cancelPreviousPerformRequestsWithTarget: self];
  [[NSNotificationCenter defaultCenter] removeObserver: self];
  [_textView setDelegate: nil];
  RELEASE (_content);
  RELEASE (_savedContent);
  RELEASE (_syntaxHighlighter);
  RELEASE (_scrollView);
  RELEASE (_textView);
  RELEASE (_lineNumberRuler);
  [super dealloc];
}
- (void) setupEditorView
{
  // Create scroll view
  _scrollView =
      [[NSScrollView alloc] initWithFrame: NSMakeRect (0, 0, 400, 300)];
  [_scrollView setHasVerticalScroller: YES];
  [_scrollView setHasHorizontalScroller: YES];
  [_scrollView setAutohidesScrollers: YES];
  [_scrollView setBorderType: NSNoBorder];
  [_scrollView setAutoresizingMask: NSViewWidthSizable | NSViewHeightSizable];

  // Create text view
  NSRect textFrame = NSMakeRect (0, 0, [_scrollView contentSize].width,
                                 [_scrollView contentSize].height);
  _textView = [[YCodeTextView alloc] initWithFrame: textFrame];
  [_textView setFont: [YCodePreferences fontForPane: @"Editor"]];
  [_textView setDelegate: self];
  [_textView setRichText: NO];
  [_textView setUsesFontPanel: YES];
  [_textView setUsesRuler: NO];
  [_textView setAllowsUndo: YES];
  [_textView setMinSize: NSMakeSize (0, 0)];
  [_textView setMaxSize: NSMakeSize (1e7, 1e7)];
  [_textView setVerticallyResizable: YES];
  [_textView setHorizontallyResizable: YES];
  [_textView setAutoresizingMask: NSViewNotSizable];

  // Configure text container
  NSTextContainer *textContainer = [_textView textContainer];
  [textContainer setWidthTracksTextView: NO];
  [textContainer setHeightTracksTextView: NO];
  [textContainer setContainerSize: NSMakeSize (1e7, 1e7)];

  [(YCodeTextView *)_textView setFilePath: _filePath];

  // Set up scroll view
  [_scrollView setDocumentView: _textView];

  // Add line number ruler (optional)
  [self setupLineNumberRuler];
}

- (void) setupLineNumberRuler
{
  _lineNumberRuler =
      [[YCEditorRulerView alloc] initWithScrollView: _scrollView
                                        orientation: NSVerticalRuler];
  [_lineNumberRuler setClientView: _textView];
  [_lineNumberRuler setRuleThickness: 50.0];
  [_scrollView setVerticalRulerView: _lineNumberRuler];
  [_scrollView setHasVerticalRuler: YES];
  NSRulerView *columns =
      [[YCEditorRulerView alloc] initWithScrollView: _scrollView
                                        orientation: NSHorizontalRuler];
  [columns setClientView: _textView];
  [columns setRuleThickness: 24.0];
  [_scrollView setHorizontalRulerView: columns];
  [_scrollView setHasHorizontalRuler: YES];
  RELEASE (columns);
  [(YCEditorRulerView *)_lineNumberRuler updateRulerVisibility];
}

- (void) setupSyntaxHighlighter
{
  DESTROY (_syntaxHighlighter);
  if (!_textView)
    return;
  _syntaxHighlighter =
      [[YCodeSyntaxHighlighter alloc] initWithFileExtension: [self fileName]];
  [_syntaxHighlighter setTextView: _textView];
}

- (void) setFilePath: (NSString *)filePath
{
  ASSIGN (_filePath, filePath);
  [(YCodeTextView *)_textView setFilePath: filePath];
  [self setupSyntaxHighlighter];
  [self applySyntaxHighlighting];
}

- (NSString *) content
{
  if (_textView)
    {
      return [_textView string];
    }
  return _content;
}

- (void) setContent: (NSString *)content
{
  if (content)
    {
      NSString *snapshot = [content copy];
      RELEASE (_content);
      _content = snapshot;
      if (_textView)
        {
          [_textView setString: content];
          [self applySyntaxHighlighting];
          // Update the scrollable extent immediately after loading a file.
          [_textView sizeToFit];
          [_lineNumberRuler setNeedsDisplay: YES];
        }
    }
}

- (void) setModified: (BOOL)modified
{
  BOOL external = _externalChange;
  if (!modified)
    {
      _externalChange = NO;
      NSString *snapshot = [[self content] copy];
      RELEASE (_savedContent);
      _savedContent = snapshot;
    }
  BOOL changed = modified && ![[self content] isEqualToString: _savedContent];
  if (_modified == changed && external == _externalChange)
    return;
  _modified = changed;
  [[NSNotificationCenter defaultCenter]
      postNotificationName: @"YCodeFileModificationDidChange"
                    object: _editorController];
}

- (NSView *) editorView
{
  return _scrollView;
}

- (NSTextView *) textView
{
  return _textView;
}

- (NSScrollView *) scrollView
{
  return _scrollView;
}

- (void) checkForExternalChanges
{
  // Text reloads are triggered by kernel events, never by a recurring timer.
  if (!_textView || ![_filePath isAbsolutePath])
    return;
  NSString *disk = [NSString stringWithContentsOfFile: _filePath
                                             encoding: NSUTF8StringEncoding
                                                error: NULL];
  BOOL changed = disk == nil || ![disk isEqual: _savedContent];
  if (changed && disk && !_modified)
    {
      NSRange selection = [_textView selectedRange];
      NSPoint origin = [[_scrollView contentView] bounds].origin;
      [self setContent: disk];
      NSDictionary *attributes =
          [[NSFileManager defaultManager] attributesOfItemAtPath: _filePath
                                                           error: NULL];
      ASSIGN (_lastModified, [attributes fileModificationDate]);
      [_undoManager removeAllActions];
      [self setModified: NO];
      selection.location = MIN (selection.location, [disk length]);
      selection.length
          = MIN (selection.length, [disk length] - selection.location);
      [_textView setSelectedRange: selection];
      [[_scrollView contentView] scrollToPoint: origin];
      [_scrollView reflectScrolledClipView: [_scrollView contentView]];
      changed = NO;
    }
  if (_externalChange != changed)
    {
      _externalChange = changed;
      [[NSNotificationCenter defaultCenter]
          postNotificationName: @"YCodeFileModificationDidChange"
                        object: _editorController];
    }
}

- (void) insertText: (NSString *)text atLocation: (NSUInteger)location
{
  if (_textView && text)
    {
      NSRange insertRange = NSMakeRange (location, 0);
      [_textView setSelectedRange: insertRange];
      [_textView insertText: text];
      [self setModified: YES];
    }
}

- (NSString *) selectedText
{
  if (_textView)
    {
      NSRange selectedRange = [_textView selectedRange];
      NSString *text = [_textView string];
      if (selectedRange.location != NSNotFound
          && selectedRange.location + selectedRange.length <= [text length])
        {
          return [text substringWithRange: selectedRange];
        }
    }
  return @"";
}

- (NSRange) selectedRange
{
  if (_textView)
    {
      return [_textView selectedRange];
    }
  return NSMakeRange (NSNotFound, 0);
}

- (void) setSelectedRange: (NSRange)range
{
  if (_textView)
    {
      [_textView setSelectedRange: range];
      [_textView scrollRangeToVisible: range];
    }
}

- (YCodeSyntaxHighlighter *) syntaxHighlighter
{
  return _syntaxHighlighter;
}

- (void) editorFontsChanged: (NSNotification *)notification
{
  [_textView setFont: [YCodePreferences fontForPane: @"Editor"]];
  [self applySyntaxHighlighting];
  [_lineNumberRuler setNeedsDisplay: YES];
  [[_scrollView horizontalRulerView] setNeedsDisplay: YES];
}

- (void) editorRulersChanged: (NSNotification *)notification
{
  [(YCEditorRulerView *)_lineNumberRuler updateRulerVisibility];
}

- (void) editorColorsChanged: (NSNotification *)notification
{
  [_syntaxHighlighter loadPreferredColors];
  [_textView setBackgroundColor: [YCodeSyntaxHighlighter
                                    preferredColorForKey: @"background"]];
  [_textView setInsertionPointColor: [YCodeSyntaxHighlighter
                                        preferredColorForKey: @"cursor"]];
  [self applySyntaxHighlighting];
}

- (void) applySyntaxHighlighting
{
  if (_syntaxHighlighter && _textView)
    {
      if (_editorController && ![_editorController syntaxHighlighting])
        {
          [_syntaxHighlighter removeHighlighting];
        }
      else
        {
          [_syntaxHighlighter highlightText];
        }
    }
}

- (NSUndoManager *) undoManagerForTextView: (NSTextView *)textView
{
  return _undoManager;
}

- (void) textDidChange: (NSNotification *)notification
{
  if ([notification object] != _textView)
    return;
  [self setModified: YES];

  // Apply syntax highlighting with a delay to avoid performance issues
  [NSObject cancelPreviousPerformRequestsWithTarget: self
                                           selector: @selector
                                           (applySyntaxHighlighting)
                                             object: nil];
  [self performSelector: @selector (applySyntaxHighlighting)
             withObject: nil
             afterDelay: 0.5];
}

- (BOOL) textView: (NSTextView *)textView
    shouldChangeTextInRange: (NSRange)affectedCharRange
          replacementString: (NSString *)replacementString
{
  return YES;
}

- (BOOL) loadFromFile
{
  NSError *error = nil;
  NSString *content = [NSString stringWithContentsOfFile: _filePath
                                                encoding: NSUTF8StringEncoding
                                                   error: &error];

  if (content)
    {
      [self setContent: content];
      [self setModified: NO];

      // Update last modified date
      NSDictionary *attributes =
          [[NSFileManager defaultManager] attributesOfItemAtPath: _filePath
                                                           error: nil];
      if (attributes)
        {
          ASSIGN (_lastModified, [attributes fileModificationDate]);
        }

      return YES;
    }
  else
    {
      NSLog (@"Error loading file %@: %@", _filePath,
             [error localizedDescription]);
      return NO;
    }
}

- (BOOL) writeContentsToFile
{
  NSError *error = nil;
  BOOL success = [[self content] writeToFile: _filePath
                                  atomically: YES
                                    encoding: NSUTF8StringEncoding
                                       error: &error];
  if (!success)
    NSLog (@"Error saving file %@: %@", _filePath,
           [error localizedDescription]);
  return success;
}
@end
