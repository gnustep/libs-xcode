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

#import "YCEditorView.h"
#import "YCodeDebugger.h"
#import "YCodeTextView.h"
#import "YCodeEditorDocument.h"
#import "YCodeSyntaxHighlighter.h"

@implementation YCEditorView

- (id) initWithFrame: (NSRect)frame
{
  self = [super initWithFrame: frame];
  if (self)
    {
      [self setupEditor];
      [self setupDefaultSettings];
    }
  return self;
}

- (void) dealloc
{
  RELEASE (_scrollView);
  RELEASE (_textView);
  RELEASE (_lineNumberView);
  RELEASE (_document);
  RELEASE (_syntaxHighlighter);
  RELEASE (_font);
  RELEASE (_textColor);
  RELEASE (_backgroundColor);
  RELEASE (_selectionColor);
  RELEASE (_currentLineColor);
  RELEASE (_findString);
  RELEASE (_replaceString);
  [super dealloc];
}

- (void) setupEditor
{
  // Create scroll view
  _scrollView = [[NSScrollView alloc] initWithFrame: [self bounds]];
  [_scrollView setHasVerticalScroller: YES];
  [_scrollView setHasHorizontalScroller: YES];
  [_scrollView setAutohidesScrollers: YES];
  [_scrollView setBorderType: NSNoBorder];
  [_scrollView setAutoresizingMask: (NSViewWidthSizable | NSViewHeightSizable)];

  // Create text view
  NSRect textFrame = [_scrollView documentVisibleRect];
  _textView = [[YCodeTextView alloc] initWithFrame: textFrame];
  [_textView setDelegate: self];
  [_textView setRichText: NO];
  [_textView setUsesFontPanel: YES];
  [_textView setUsesRuler: NO];
  [_textView setAllowsUndo: YES];
  [_textView setMaxSize: NSMakeSize (1e7, 1e7)];
  [_textView setMinSize: NSMakeSize (0, 0)];
  [_textView setVerticallyResizable: YES];
  [_textView setHorizontallyResizable: YES];
  [_textView setAutoresizingMask: NSViewNotSizable];

  // Configure text container
  NSTextContainer *textContainer = [_textView textContainer];
  [textContainer setWidthTracksTextView: NO];
  [textContainer setHeightTracksTextView: NO];
  [textContainer setContainerSize: NSMakeSize (1e7, 1e7)];

  // Set up scroll view
  [_scrollView setDocumentView: _textView];
  [self addSubview: _scrollView];

  // Create line number view
  [self setupLineNumberView];
}

- (void) setupLineNumberView
{
  _lineNumberView =
      [[YCEditorRulerView alloc] initWithScrollView: _scrollView
                                        orientation: NSVerticalRuler];
  [_lineNumberView setClientView: _textView];
  [_lineNumberView setRuleThickness: 50.0];
  [_scrollView setVerticalRulerView: _lineNumberView];
  [_scrollView setHasVerticalRuler: YES];
  NSRulerView *columns =
      [[YCEditorRulerView alloc] initWithScrollView: _scrollView
                                        orientation: NSHorizontalRuler];
  [columns setClientView: _textView];
  [columns setRuleThickness: 24.0];
  [_scrollView setHorizontalRulerView: columns];
  [_scrollView setHasHorizontalRuler: YES];
  RELEASE (columns);
  [_scrollView setRulersVisible: _showLineNumbers];
}

- (void) setupDefaultSettings
{
  // Default editor settings
  _font = [[NSFont userFixedPitchFontOfSize: 12.0] retain];
  _textColor = [[NSColor blackColor] retain];
  _backgroundColor = [[NSColor whiteColor] retain];
  _selectionColor = [[NSColor selectedTextBackgroundColor] retain];
  _currentLineColor = [[NSColor colorWithDeviceWhite: 0.95 alpha: 1.0] retain];

  _showLineNumbers = YES;
  _highlightCurrentLine = YES;
  _autoIndent = YES;
  _syntaxHighlighting = YES;
  _tabWidth = 2;
  _useSpacesForTabs = YES;

  _caseSensitive = NO;
  _useRegex = NO;

  [self applySettings];
}

- (void) applySettings
{
  if (_textView)
    {
      ASSIGN (_textColor, [YCodeSyntaxHighlighter
                              plainTextColorForBackground: _backgroundColor]);
      [_textView setFont: _font];
      [_textView setTextColor: _textColor];
      [_textView setBackgroundColor: _backgroundColor];
      [_textView setSelectedTextAttributes:
                     [NSDictionary
                         dictionaryWithObject: _selectionColor
                                       forKey: NSBackgroundColorAttributeName]];
      [_textView setInsertionPointColor: [YCodeSyntaxHighlighter
                                            preferredColorForKey: @"cursor"]];
      [self applySyntaxHighlighting];
      [[_scrollView horizontalRulerView] setNeedsDisplay: YES];
      [[_scrollView verticalRulerView] setNeedsDisplay: YES];
    }

  if (_scrollView)
    {
      [_scrollView setRulersVisible: _showLineNumbers];
    }
}

#pragma mark - Document Association

- (YCodeEditorDocument *) document
{
  return _document;
}

- (void) setDocument: (YCodeEditorDocument *)document
{
  ASSIGN (_document, document);
  [(YCodeTextView *)_textView setFilePath: [document filePath]];

  if (_document)
    {
      [self setText: [_document content]];

      // Setup syntax highlighter based on file extension
      NSString *extension = [_document fileExtension];
      if (extension && _syntaxHighlighting)
        {
          _syntaxHighlighter =
              [[YCodeSyntaxHighlighter alloc] initWithFileExtension: extension];
          [_syntaxHighlighter setTextView: _textView];
          [self applySyntaxHighlighting];
        }
    }
}

#pragma mark - Text View Access

- (NSTextView *) textView
{
  return _textView;
}

- (NSScrollView *) scrollView
{
  return _scrollView;
}

#pragma mark - Content Management

- (NSString *) text
{
  return [_textView string];
}

- (void) setText: (NSString *)text
{
  if (_textView)
    {
      [_textView setString: text ? text : @""];
      [self applySyntaxHighlighting];
      [_textView sizeToFit];
      [_lineNumberView setNeedsDisplay: YES];
    }
}

- (BOOL) hasSelection
{
  if (_textView)
    {
      NSRange selection = [_textView selectedRange];
      return selection.length > 0;
    }
  return NO;
}

- (NSString *) selectedText
{
  if (_textView && [self hasSelection])
    {
      NSRange selection = [_textView selectedRange];
      return [[_textView string] substringWithRange: selection];
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

#pragma mark - Editor Settings

- (NSFont *) font
{
  return _font;
}

- (void) setFont: (NSFont *)font
{
  ASSIGN (_font, font);
  [self applySettings];
}

- (NSColor *) textColor
{
  return _textColor;
}

- (void) setTextColor: (NSColor *)color
{
  ASSIGN (_textColor, color);
  [self applySettings];
}

- (NSColor *) backgroundColor
{
  return _backgroundColor;
}

- (void) setBackgroundColor: (NSColor *)color
{
  ASSIGN (_backgroundColor, color);
  [self applySettings];
}

- (BOOL) showLineNumbers
{
  return _showLineNumbers;
}

- (void) setShowLineNumbers: (BOOL)show
{
  _showLineNumbers = show;
  [_scrollView setRulersVisible: show];
}

- (BOOL) highlightCurrentLine
{
  return _highlightCurrentLine;
}

- (void) setHighlightCurrentLine: (BOOL)highlight
{
  _highlightCurrentLine = highlight;
  // TODO: Implement current line highlighting
}

- (NSInteger) tabWidth
{
  return [(YCodeTextView *)_textView editorTabWidth];
}

- (void) setTabWidth: (NSInteger)width
{
  _tabWidth = width;
  [(YCodeTextView *)_textView setEditorTabWidth: MAX (1, width)];
}

- (BOOL) useSpacesForTabs
{
  return ![(YCodeTextView *)_textView editorUsesTabs];
}

- (void) setUseSpacesForTabs: (BOOL)useSpaces
{
  _useSpacesForTabs = useSpaces;
  [(YCodeTextView *)_textView setEditorUsesTabs: !useSpaces];
}

#pragma mark - Syntax Highlighting

- (BOOL) syntaxHighlighting
{
  return _syntaxHighlighting;
}

- (void) setSyntaxHighlighting: (BOOL)highlighting
{
  _syntaxHighlighting = highlighting;
  if (highlighting)
    {
      [self applySyntaxHighlighting];
    }
  else
    {
      [_syntaxHighlighter removeHighlighting];
    }
}

- (YCodeSyntaxHighlighter *) syntaxHighlighter
{
  return _syntaxHighlighter;
}

- (void) applySyntaxHighlighting
{
  if (_syntaxHighlighter && _syntaxHighlighting)
    {
      [_syntaxHighlighter highlightText];
    }
}

#pragma mark - Text Operations

- (void) insertText: (NSString *)text
{
  if (_textView && text)
    {
      [_textView insertText: text];
    }
}

- (void) insertText: (NSString *)text atLocation: (NSUInteger)location
{
  if (_textView && text)
    {
      NSRange insertRange = NSMakeRange (location, 0);
      [_textView setSelectedRange: insertRange];
      [_textView insertText: text];
    }
}

- (void) deleteSelectedText
{
  if (_textView && [self hasSelection])
    {
      [_textView delete: self];
    }
}

- (void) selectAll
{
  if (_textView)
    {
      [_textView selectAll: self];
    }
}

- (void) copy
{
  if (_textView)
    {
      [_textView copy: self];
    }
}

- (void) cut
{
  if (_textView)
    {
      [_textView cut: self];
    }
}

- (void) paste
{
  if (_textView)
    {
      [_textView paste: self];
    }
}

#pragma mark - Line Operations

- (NSUInteger) currentLineNumber
{
  if (!_textView)
    return 0;

  NSString *text = [_textView string];
  NSRange selection = [_textView selectedRange];
  NSUInteger lineNumber = 1;

  NSUInteger i;
  for (i = 0; i < selection.location && i < [text length]; i++)
    {
      if ([text characterAtIndex: i] == '\n')
        {
          lineNumber++;
        }
    }

  return lineNumber;
}

- (NSUInteger) totalLineCount
{
  if (!_textView)
    return 0;

  NSString *text = [_textView string];
  NSUInteger lineCount = 1;

  NSUInteger i;
  for (i = 0; i < [text length]; i++)
    {
      if ([text characterAtIndex: i] == '\n')
        {
          lineCount++;
        }
    }

  return lineCount;
}

- (NSRange) rangeOfLine: (NSUInteger)lineNumber
{
  if (!_textView || lineNumber == 0)
    return NSMakeRange (NSNotFound, 0);

  NSString *text = [_textView string];
  NSUInteger currentLine = 1;
  NSUInteger start = 0;

  // Find start of target line
  NSUInteger i;
  for (i = 0; i < [text length] && currentLine < lineNumber; i++)
    {
      if ([text characterAtIndex: i] == '\n')
        {
          currentLine++;
          start = i + 1;
        }
    }

  if (currentLine < lineNumber)
    {
      return NSMakeRange (NSNotFound, 0);
    }

  // Find end of target line
  NSUInteger end = start;
  for (i = start; i < [text length]; i++)
    {
      if ([text characterAtIndex: i] == '\n')
        {
          break;
        }
      end = i + 1;
    }

  return NSMakeRange (start, end - start);
}

- (void) goToLine: (NSUInteger)lineNumber
{
  NSRange lineRange = [self rangeOfLine: lineNumber];
  if (lineRange.location != NSNotFound)
    {
      [self setSelectedRange: NSMakeRange (lineRange.location, 0)];
    }
}

- (void) selectLine: (NSUInteger)lineNumber
{
  NSRange lineRange = [self rangeOfLine: lineNumber];
  if (lineRange.location != NSNotFound)
    {
      [self setSelectedRange: lineRange];
    }
}

#pragma mark - Find and Replace

- (void) findText: (NSString *)searchText options: (NSStringCompareOptions)options
{
  if (!_textView || !searchText)
    return;

  NSString *text = [_textView string];
  NSRange searchRange = NSMakeRange (0, [text length]);
  NSRange foundRange = [text rangeOfString: searchText
                                   options: options
                                     range: searchRange];

  if (foundRange.location != NSNotFound)
    {
      [self setSelectedRange: foundRange];
    }
}

- (void) replaceText: (NSString *)searchText
           withText: (NSString *)replaceText
            options: (NSStringCompareOptions)options
{
  if (!_textView || !searchText || !replaceText)
    return;

  // Simple replacement - in a full implementation, you'd want more sophisticated handling
  NSString *text = [_textView string];
  NSString *newText = [text
      stringByReplacingOccurrencesOfString: searchText
                                withString: replaceText
                                   options: options
                                     range: NSMakeRange (0, [text length])];
  [self setText: newText];
}

- (void) findNext
{
  if (_findString)
    {
      // TODO: Implement find next
    }
}

- (void) findPrevious
{
  if (_findString)
    {
      // TODO: Implement find previous
    }
}

#pragma mark - Indentation

- (void) indentSelectedLines
{
  [_textView insertTab: self];
}

- (void) unindentSelectedLines
{
  [_textView insertBacktab: self];
}

- (void) commentSelectedLines
{
  // TODO: Implement line commenting based on language
}

- (void) uncommentSelectedLines
{
  // TODO: Implement line uncommenting
}

#pragma mark - Folding

- (BOOL) canFoldAtLine: (NSUInteger)lineNumber
{
  // TODO: Implement folding detection
  return NO;
}

- (void) foldAtLine: (NSUInteger)lineNumber
{
  // TODO: Implement code folding
}

- (void) unfoldAtLine: (NSUInteger)lineNumber
{
  // TODO: Implement code unfolding
}

#pragma mark - NSTextViewDelegate

- (void) textDidChange: (NSNotification *)notification
{
  // Update document modified state
  if (_document)
    {
      [_document setModified: YES];
    }

  // Apply syntax highlighting with delay
  [NSObject cancelPreviousPerformRequestsWithTarget: self
                                           selector: @selector
                                           (applySyntaxHighlighting)
                                             object: nil];
  [self performSelector: @selector (applySyntaxHighlighting)
             withObject: nil
             afterDelay: 0.5];

  // Update line numbers
  if (_lineNumberView)
    {
      [_lineNumberView setNeedsDisplay: YES];
    }
}

@end

#pragma mark - Line Number View Implementation

@implementation YCEditorRulerView

- (void) setDebugger: (YCodeDebugger *)debugger
               file: (NSString *)file
             active: (BOOL)active
{
  ASSIGN (_debugger, debugger);
  ASSIGN (_debugFile, file);
  _debugGutterVisible =
      [debugger canSetBreakpointAtFile: file]
      && (active || [[debugger breakpointLinesForFile: file] count] > 0);
  [self updateRulerVisibility];
  [self
      setToolTip:
          _debugGutterVisible
              ? @"Click to add/remove a breakpoint. Shift-click to enable/disable it."
              : nil];
  [self setNeedsDisplay: YES];
}

- (BOOL) debugGutterVisible
{
  return _debugGutterVisible;
}

- (void) updateRulerVisibility
{
  if ([self orientation] != NSVerticalRuler)
    return;
  BOOL rulers = ![[NSUserDefaults standardUserDefaults]
      boolForKey: @"YCodeHideEditorRulers"];
  NSScrollView *scroll = [self scrollView];
  [self setRuleThickness: (rulers ? 50.0 : 0.0)
                         + (_debugGutterVisible ? 22.0 : 0.0)];
  [scroll setHasHorizontalRuler: rulers];
  [scroll setHasVerticalRuler: rulers || _debugGutterVisible];
  [scroll setRulersVisible: rulers || _debugGutterVisible];
  [self setNeedsDisplay: YES];
}

- (NSUInteger) sourceLineAtPoint: (NSPoint)point
{
  NSTextView *textView = (NSTextView *)[self clientView];
  if (![textView isKindOfClass: [NSTextView class]])
    return 0;
  NSLayoutManager *layout = [textView layoutManager];
  NSPoint origin = [textView textContainerOrigin];
  NSString *text = [textView string];
  NSUInteger index = 0, line = 1;
  while (index <= [text length])
    {
      NSUInteger end, contentsEnd;
      [text getLineStart: NULL
                     end: &end
             contentsEnd: &contentsEnd
                forRange: NSMakeRange (index, 0)];
      NSRect fragment;
      if (index == [text length])
        fragment = [layout extraLineFragmentRect];
      else
        {
          NSRange glyphs = [layout
              glyphRangeForCharacterRange: NSMakeRange (index,
                                                       MAX (1, end - index))
                     actualCharacterRange: NULL];
          fragment = NSUnionRect (
              [layout lineFragmentRectForGlyphAtIndex: glyphs.location
                                       effectiveRange: NULL],
              [layout lineFragmentRectForGlyphAtIndex: NSMaxRange (glyphs) - 1
                                       effectiveRange: NULL]);
        }
      fragment.origin.x += origin.x;
      fragment.origin.y += origin.y;
      fragment = [self convertRect: fragment fromView: textView];
      if (point.y >= NSMinY (fragment) && point.y < NSMaxY (fragment))
        return line;
      if (end <= index || contentsEnd == end)
        break;
      index = end;
      line++;
    }
  return 0;
}

- (void) mouseDown: (NSEvent *)event
{
  NSPoint point = [self convertPoint: [event locationInWindow] fromView: nil];
  if ([self orientation] != NSVerticalRuler || !_debugGutterVisible
      || point.x > 22)
    {
      [super mouseDown: event];
      return;
    }
  NSUInteger line = [self sourceLineAtPoint: point];
  if (!line)
    return;
  if ([event modifierFlags] & NSShiftKeyMask)
    [_debugger toggleBreakpointEnabledAtFile: _debugFile line: line];
  else
    [_debugger toggleBreakpointAtFile: _debugFile line: line];
}

- (void) drawDebugMarkerAtPoint: (NSPoint)point
                        height: (CGFloat)height
                    breakpoint: (YCodeBreakpointState)state
                     execution: (BOOL)execution
{
  CGFloat middle = point.y + MAX (12, height) / 2;
  // Draw the execution arrow first, behind the breakpoint dot.
  if (execution)
    {
      NSBezierPath *arrow = [NSBezierPath bezierPath];
      [arrow moveToPoint: NSMakePoint (2, middle - 5)];
      [arrow lineToPoint: NSMakePoint (13, middle - 5)];
      [arrow lineToPoint: NSMakePoint (13, middle - 8)];
      [arrow lineToPoint: NSMakePoint (22, middle)];
      [arrow lineToPoint: NSMakePoint (13, middle + 8)];
      [arrow lineToPoint: NSMakePoint (13, middle + 5)];
      [arrow lineToPoint: NSMakePoint (2, middle + 5)];
      [arrow closePath];
      [[NSColor yellowColor] set];
      [arrow fill];
      [[NSColor darkGrayColor] set];
      [arrow stroke];
    }
  if (state != YCodeBreakpointNone)
    {
      NSBezierPath *dot = [NSBezierPath
          bezierPathWithOvalInRect: NSMakeRect (4, middle - 5, 10, 10)];
      [(state == YCodeBreakpointEnabled ? [NSColor redColor]
                                        : [NSColor grayColor]) set];
      [dot fill];
      [[NSColor darkGrayColor] set];
      [dot stroke];
    }
}

- (BOOL) isFlipped
{
  return YES;
}

- (void) setClientView: (NSView *)view
{
  [[NSNotificationCenter defaultCenter]
      removeObserver: self
                name: NSTextDidChangeNotification
              object: [self clientView]];
  [super setClientView: view];
  if (view)
    {
      [[NSNotificationCenter defaultCenter]
          addObserver: self
             selector: @selector (editorTextDidChange:)
                 name: NSTextDidChangeNotification
               object: view];
    }
}

- (void) dealloc
{
  [[NSNotificationCenter defaultCenter] removeObserver: self];
  RELEASE (_debugger);
  RELEASE (_debugFile);
  [super dealloc];
}

- (void) editorTextDidChange: (NSNotification *)notification
{
  [self setNeedsDisplay: YES];
}

- (void) drawHashMarksAndLabelsInRect: (NSRect)rect
{
  NSTextView *textView = (NSTextView *)[self clientView];
  if (![textView isKindOfClass: [NSTextView class]])
    {
      return;
    }
  NSFont *font = [textView font];
  if (!font)
    {
      font = [NSFont userFixedPitchFontOfSize: 12.0];
    }
  NSDictionary *attributes = [NSDictionary
      dictionaryWithObjectsAndKeys: [NSFont systemFontOfSize: 10.0],
                                   NSFontAttributeName,
                                   [NSColor controlTextColor],
                                   NSForegroundColorAttributeName, nil];
  NSPoint origin = [textView textContainerOrigin];
  NSTextContainer *container = [textView textContainer];

  if ([self orientation] == NSHorizontalRuler)
    {
      NSDictionary *fontAttributes =
          [NSDictionary dictionaryWithObject: font forKey: NSFontAttributeName];
      CGFloat advance = [@"0" sizeWithAttributes: fontAttributes].width;
      if (advance <= 0)
        {
          return;
        }
      NSClipView *clipView = [[self scrollView] contentView];
      NSRect viewport = [self convertRect: [clipView bounds] fromView: clipView];
      viewport.origin.y = NSMinY (rect);
      viewport.size.height = NSHeight (rect);
      rect = NSIntersectionRect (rect, viewport);
      [NSGraphicsContext saveGraphicsState];
      NSRectClip (rect);
      origin.x += [container lineFragmentPadding];
      NSPoint start = [self convertPoint: origin fromView: textView];
      NSInteger first
          = MAX (0, (NSInteger)((NSMinX (rect) - start.x) / advance));
      NSInteger last
          = MAX (0, (NSInteger)((NSMaxX (rect) - start.x) / advance) + 1);
      NSInteger column;
      [[NSColor controlTextColor] set];
      for (column = first; column <= last; column++)
        {
          CGFloat x = start.x + column * advance;
          BOOL labelled = column == 0 || (column + 1) % 10 == 0;
          NSRectFill (
              NSMakeRect (x, NSHeight ([self bounds]) - (labelled ? 7 : 3), 1,
                          labelled ? 7 : 3));
          if (labelled)
            {
              NSString *label =
                  [NSString stringWithFormat: @"%ld", (long)column + 1];
              [label drawAtPoint: NSMakePoint (x, 1) withAttributes: attributes];
            }
        }
      [NSGraphicsContext restoreGraphicsState];
    }
  else
    {
      if (_debugGutterVisible)
        {
          NSColor *background = [[self window] backgroundColor];
          if (!background)
            background = [NSColor windowBackgroundColor];
          [[background blendedColorWithFraction: 0.1
                                        ofColor: [NSColor whiteColor]] set];
          NSRectFill (NSIntersectionRect (
              rect, NSMakeRect (0, NSMinY (rect), 22, NSHeight (rect))));
          [[NSColor grayColor] set];
          NSRectFill (NSIntersectionRect (
              rect, NSMakeRect (22, NSMinY (rect), 1, NSHeight (rect))));
        }
      NSDictionary *breakpoints
          = _debugGutterVisible ? [_debugger breakpointLinesForFile: _debugFile]
                                : nil;
      BOOL executionFile = [[_debugFile stringByStandardizingPath]
          isEqual: [_debugger executionFile]];
      NSString *text = [textView string];
      NSLayoutManager *layout = [textView layoutManager];
      NSRect visible = [textView visibleRect];
      visible.origin.x -= origin.x;
      visible.origin.y -= origin.y;
      // Line labels must remain visible even when the text is scrolled sideways.
      visible.origin.x = 0;
      visible.size.width = [container containerSize].width;
      NSRange glyphs = [layout glyphRangeForBoundingRect: visible
                                         inTextContainer: container];
      NSRange characters = [layout characterRangeForGlyphRange: glyphs
                                              actualGlyphRange: NULL];
      NSUInteger index = 0;
      NSUInteger line = 1;
      while (index <= [text length])
        {
          NSUInteger end, contentsEnd;
          [text getLineStart: NULL
                         end: &end
                 contentsEnd: &contentsEnd
                    forRange: NSMakeRange (index, 0)];
          NSRange lineRange = NSMakeRange (index, end - index);
          if (NSMaxRange (lineRange) >= characters.location)
            {
              NSRect fragment;
              if (index == [text length])
                {
                  fragment = [layout extraLineFragmentRect];
                }
              else
                {
                  NSUInteger glyph =
                      [layout
                          glyphRangeForCharacterRange: NSMakeRange (index, 1)
                                 actualCharacterRange: NULL]
                          .location;
                  fragment = [layout lineFragmentRectForGlyphAtIndex: glyph
                                                      effectiveRange: NULL];
                }
              NSPoint point =
                  [self convertPoint: NSMakePoint (origin.x,
                                                  origin.y + NSMinY (fragment))
                            fromView: textView];
              if (point.y > NSMaxY (rect))
                {
                  break;
                }
              if (_debugGutterVisible)
                [self
                    drawDebugMarkerAtPoint: point
                                    height: NSHeight (fragment)
                                breakpoint:
                                    [[breakpoints
                                        objectForKey:
                                            [NSNumber
                                                numberWithUnsignedInteger:
                                                    line]] intValue]
                                 execution: executionFile &&
                                           [_debugger executionLine] == line];
              if (![[NSUserDefaults standardUserDefaults]
                      boolForKey: @"YCodeHideEditorRulers"])
                {
                  NSString *label =
                      [NSString stringWithFormat: @"%lu", (unsigned long)line];
                  NSSize size = [label sizeWithAttributes: attributes];
                  [label drawAtPoint: NSMakePoint (NSWidth ([self bounds])
                                                      - size.width - 5,
                                                  point.y)
                      withAttributes: attributes];
                }
            }
          if (end <= index || contentsEnd == end)
            {
              break;
            }
          index = NSMaxRange (lineRange);
          line++;
        }
    }
}

@end

@implementation YCEditorLineNumberView

- (id) initWithEditorView: (YCEditorView *)editorView
{
  self = [super initWithScrollView: [editorView scrollView]
                       orientation: NSVerticalRuler];
  if (self)
    {
      _editorView = editorView; // weak reference
      _backgroundColor = [[NSColor colorWithDeviceWhite: 0.9 alpha: 1.0] retain];
      _textColor = [[NSColor colorWithDeviceWhite: 0.5 alpha: 1.0] retain];
      _font = [[NSFont fontWithName: @"Menlo" size: 10.0] retain];

      [self setRuleThickness: 50.0];
      [self setClientView: [editorView textView]];
    }
  return self;
}

- (void) dealloc
{
  RELEASE (_backgroundColor);
  RELEASE (_textColor);
  RELEASE (_font);
  [super dealloc];
}

- (YCEditorView *) editorView
{
  return _editorView;
}

- (void) setEditorView: (YCEditorView *)editorView
{
  _editorView = editorView; // weak reference
}

- (void) drawRect: (NSRect)rect
{
  // Fill background
  [_backgroundColor set];
  NSRectFill (rect);

  if (!_editorView || ![_editorView textView])
    {
      return;
    }

  NSTextView *textView = [_editorView textView];
  NSString *text = [textView string];
  NSRect visibleRect = [textView visibleRect];
  NSRange visibleRange = [[textView layoutManager]
      glyphRangeForBoundingRect: visibleRect
                inTextContainer: [textView textContainer]];

  // Draw line numbers
  NSUInteger lineNumber = 1;
  NSUInteger characterIndex = 0;

  // Count lines up to visible range
  NSUInteger i;
  for (i = 0; i < visibleRange.location && i < [text length]; i++)
    {
      if ([text characterAtIndex: i] == '\n')
        {
          lineNumber++;
        }
    }

  // Draw visible line numbers
  NSLayoutManager *layoutManager = [textView layoutManager];
  NSTextContainer *textContainer = [textView textContainer];

  characterIndex = visibleRange.location;

  while (characterIndex < NSMaxRange (visibleRange)
         && characterIndex < [text length])
    {
      NSRange lineRange =
          [text lineRangeForRange: NSMakeRange (characterIndex, 0)];
      NSRect lineRect = [layoutManager
          boundingRectForGlyphRange: NSMakeRange (characterIndex, 1)
                    inTextContainer: textContainer];

      // Convert to ruler coordinate system
      NSPoint linePoint = [self convertPoint: lineRect.origin
                                    fromView: textView];

      // Draw line number
      NSString *lineNumberString =
          [NSString stringWithFormat: @"%lu", (unsigned long)lineNumber];
      NSDictionary *attributes = [NSDictionary
          dictionaryWithObjectsAndKeys: _font, NSFontAttributeName, _textColor,
                                       NSForegroundColorAttributeName, nil];

      NSSize textSize = [lineNumberString sizeWithAttributes: attributes];
      NSRect drawRect
          = NSMakeRect ([self ruleThickness] - textSize.width - 5, linePoint.y,
                        textSize.width, textSize.height);

      [lineNumberString drawInRect: drawRect withAttributes: attributes];

      lineNumber++;
      characterIndex = NSMaxRange (lineRange);
    }
}

@end
