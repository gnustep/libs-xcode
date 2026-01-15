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
#import "YCodeEditorDocument.h"
#import "YCodeSyntaxHighlighter.h"

@implementation YCEditorView

- (instancetype)initWithFrame:(NSRect)frame
{
    self = [super initWithFrame:frame];
    if (self) {
        [self setupEditor];
        [self setupDefaultSettings];
    }
    return self;
}

- (void)dealloc
{
    RELEASE(_scrollView);
    RELEASE(_textView);
    RELEASE(_lineNumberView);
    RELEASE(_document);
    RELEASE(_syntaxHighlighter);
    RELEASE(_font);
    RELEASE(_textColor);
    RELEASE(_backgroundColor);
    RELEASE(_selectionColor);
    RELEASE(_currentLineColor);
    RELEASE(_findString);
    RELEASE(_replaceString);
    [super dealloc];
}

- (void)setupEditor
{
    // Create scroll view
    _scrollView = [[NSScrollView alloc] initWithFrame:[self bounds]];
    [_scrollView setHasVerticalScroller:YES];
    [_scrollView setHasHorizontalScroller:YES];
    [_scrollView setAutohidesScrollers:YES];
    [_scrollView setBorderType:NSNoBorder];
    [_scrollView setAutoresizingMask:(NSViewWidthSizable | NSViewHeightSizable)];
    
    // Create text view
    NSRect textFrame = [_scrollView documentVisibleRect];
    _textView = [[NSTextView alloc] initWithFrame:textFrame];
    [_textView setDelegate:self];
    [_textView setRichText:NO];
    [_textView setUsesFontPanel:YES];
    [_textView setUsesRuler:NO];
    [_textView setAllowsUndo:YES];
    [_textView setVerticallyResizable:YES];
    [_textView setHorizontallyResizable:YES];
    [_textView setAutoresizingMask:(NSViewWidthSizable | NSViewHeightSizable)];
    [_textView setMaxSize:NSMakeSize(1e7, 1e7)];
    [_textView setMinSize:NSMakeSize(0, 0)];
    
    // Configure text container
    NSTextContainer *textContainer = [_textView textContainer];
    [textContainer setWidthTracksTextView:YES];
    [textContainer setContainerSize:NSMakeSize(textFrame.size.width, 1e7)];
    
    // Set up scroll view
    [_scrollView setDocumentView:_textView];
    [self addSubview:_scrollView];
    
    // Create line number view
    [self setupLineNumberView];
}

- (void)setupLineNumberView
{
    _lineNumberView = [[YCEditorLineNumberView alloc] initWithEditorView:self];
    [_scrollView setVerticalRulerView:_lineNumberView];
    [_scrollView setHasVerticalRuler:YES];
    [_scrollView setRulersVisible:_showLineNumbers];
}

- (void)setupDefaultSettings
{
    // Default editor settings
    _font = [[NSFont fontWithName:@"Menlo" size:12.0] retain];
    _textColor = [[NSColor blackColor] retain];
    _backgroundColor = [[NSColor whiteColor] retain];
    _selectionColor = [[NSColor selectedTextBackgroundColor] retain];
    _currentLineColor = [[NSColor colorWithDeviceWhite:0.95 alpha:1.0] retain];
    
    _showLineNumbers = YES;
    _highlightCurrentLine = YES;
    _autoIndent = YES;
    _syntaxHighlighting = YES;
    _tabWidth = 4;
    _useSpacesForTabs = YES;
    
    _caseSensitive = NO;
    _useRegex = NO;
    
    [self applySettings];
}

- (void)applySettings
{
    if (_textView) {
        [_textView setFont:_font];
        [_textView setTextColor:_textColor];
        [_textView setBackgroundColor:_backgroundColor];
        [_textView setSelectedTextAttributes:@{NSBackgroundColorAttributeName: _selectionColor}];
    }
    
    if (_scrollView) {
        [_scrollView setRulersVisible:_showLineNumbers];
    }
}

#pragma mark - Document Association

- (YCodeEditorDocument *)document
{
    return _document;
}

- (void)setDocument:(YCodeEditorDocument *)document
{
    ASSIGN(_document, document);
    
    if (_document) {
        [self setText:[_document content]];
        
        // Setup syntax highlighter based on file extension
        NSString *extension = [_document fileExtension];
        if (extension && _syntaxHighlighting) {
            _syntaxHighlighter = [[YCodeSyntaxHighlighter alloc] initWithFileExtension:extension];
            [_syntaxHighlighter setTextView:_textView];
            [self applySyntaxHighlighting];
        }
    }
}

#pragma mark - Text View Access

- (NSTextView *)textView
{
    return _textView;
}

- (NSScrollView *)scrollView
{
    return _scrollView;
}

#pragma mark - Content Management

- (NSString *)text
{
    return [_textView string];
}

- (void)setText:(NSString *)text
{
    if (_textView) {
        [_textView setString:text ? text : @""];
        [self applySyntaxHighlighting];
    }
}

- (BOOL)hasSelection
{
    if (_textView) {
        NSRange selection = [_textView selectedRange];
        return selection.length > 0;
    }
    return NO;
}

- (NSString *)selectedText
{
    if (_textView && [self hasSelection]) {
        NSRange selection = [_textView selectedRange];
        return [[_textView string] substringWithRange:selection];
    }
    return @"";
}

- (NSRange)selectedRange
{
    if (_textView) {
        return [_textView selectedRange];
    }
    return NSMakeRange(NSNotFound, 0);
}

- (void)setSelectedRange:(NSRange)range
{
    if (_textView) {
        [_textView setSelectedRange:range];
        [_textView scrollRangeToVisible:range];
    }
}

#pragma mark - Editor Settings

- (NSFont *)font
{
    return _font;
}

- (void)setFont:(NSFont *)font
{
    ASSIGN(_font, font);
    [self applySettings];
}

- (NSColor *)textColor
{
    return _textColor;
}

- (void)setTextColor:(NSColor *)color
{
    ASSIGN(_textColor, color);
    [self applySettings];
}

- (NSColor *)backgroundColor
{
    return _backgroundColor;
}

- (void)setBackgroundColor:(NSColor *)color
{
    ASSIGN(_backgroundColor, color);
    [self applySettings];
}

- (BOOL)showLineNumbers
{
    return _showLineNumbers;
}

- (void)setShowLineNumbers:(BOOL)show
{
    _showLineNumbers = show;
    [_scrollView setRulersVisible:show];
}

- (BOOL)highlightCurrentLine
{
    return _highlightCurrentLine;
}

- (void)setHighlightCurrentLine:(BOOL)highlight
{
    _highlightCurrentLine = highlight;
    // TODO: Implement current line highlighting
}

- (NSInteger)tabWidth
{
    return _tabWidth;
}

- (void)setTabWidth:(NSInteger)width
{
    _tabWidth = width;
    // TODO: Update tab settings in text view
}

- (BOOL)useSpacesForTabs
{
    return _useSpacesForTabs;
}

- (void)setUseSpacesForTabs:(BOOL)useSpaces
{
    _useSpacesForTabs = useSpaces;
    // TODO: Update tab behavior
}

#pragma mark - Syntax Highlighting

- (BOOL)syntaxHighlighting
{
    return _syntaxHighlighting;
}

- (void)setSyntaxHighlighting:(BOOL)highlighting
{
    _syntaxHighlighting = highlighting;
    if (highlighting) {
        [self applySyntaxHighlighting];
    } else {
        [_syntaxHighlighter removeHighlighting];
    }
}

- (YCodeSyntaxHighlighter *)syntaxHighlighter
{
    return _syntaxHighlighter;
}

- (void)applySyntaxHighlighting
{
    if (_syntaxHighlighter && _syntaxHighlighting) {
        [_syntaxHighlighter highlightText];
    }
}

#pragma mark - Text Operations

- (void)insertText:(NSString *)text
{
    if (_textView && text) {
        [_textView insertText:text];
    }
}

- (void)insertText:(NSString *)text atLocation:(NSUInteger)location
{
    if (_textView && text) {
        NSRange insertRange = NSMakeRange(location, 0);
        [_textView setSelectedRange:insertRange];
        [_textView insertText:text];
    }
}

- (void)deleteSelectedText
{
    if (_textView && [self hasSelection]) {
        [_textView delete:self];
    }
}

- (void)selectAll
{
    if (_textView) {
        [_textView selectAll:self];
    }
}

- (void)copy
{
    if (_textView) {
        [_textView copy:self];
    }
}

- (void)cut
{
    if (_textView) {
        [_textView cut:self];
    }
}

- (void)paste
{
    if (_textView) {
        [_textView paste:self];
    }
}

#pragma mark - Line Operations

- (NSUInteger)currentLineNumber
{
    if (!_textView) return 0;
    
    NSString *text = [_textView string];
    NSRange selection = [_textView selectedRange];
    NSUInteger lineNumber = 1;
    
    for (NSUInteger i = 0; i < selection.location && i < [text length]; i++) {
        if ([text characterAtIndex:i] == '\n') {
            lineNumber++;
        }
    }
    
    return lineNumber;
}

- (NSUInteger)totalLineCount
{
    if (!_textView) return 0;
    
    NSString *text = [_textView string];
    NSUInteger lineCount = 1;
    
    for (NSUInteger i = 0; i < [text length]; i++) {
        if ([text characterAtIndex:i] == '\n') {
            lineCount++;
        }
    }
    
    return lineCount;
}

- (NSRange)rangeOfLine:(NSUInteger)lineNumber
{
    if (!_textView || lineNumber == 0) return NSMakeRange(NSNotFound, 0);
    
    NSString *text = [_textView string];
    NSUInteger currentLine = 1;
    NSUInteger start = 0;
    
    // Find start of target line
    for (NSUInteger i = 0; i < [text length] && currentLine < lineNumber; i++) {
        if ([text characterAtIndex:i] == '\n') {
            currentLine++;
            start = i + 1;
        }
    }
    
    if (currentLine < lineNumber) {
        return NSMakeRange(NSNotFound, 0);
    }
    
    // Find end of target line
    NSUInteger end = start;
    for (NSUInteger i = start; i < [text length]; i++) {
        if ([text characterAtIndex:i] == '\n') {
            break;
        }
        end = i + 1;
    }
    
    return NSMakeRange(start, end - start);
}

- (void)goToLine:(NSUInteger)lineNumber
{
    NSRange lineRange = [self rangeOfLine:lineNumber];
    if (lineRange.location != NSNotFound) {
        [self setSelectedRange:NSMakeRange(lineRange.location, 0)];
    }
}

- (void)selectLine:(NSUInteger)lineNumber
{
    NSRange lineRange = [self rangeOfLine:lineNumber];
    if (lineRange.location != NSNotFound) {
        [self setSelectedRange:lineRange];
    }
}

#pragma mark - Find and Replace

- (void)findText:(NSString *)searchText options:(NSStringCompareOptions)options
{
    if (!_textView || !searchText) return;
    
    NSString *text = [_textView string];
    NSRange searchRange = NSMakeRange(0, [text length]);
    NSRange foundRange = [text rangeOfString:searchText options:options range:searchRange];
    
    if (foundRange.location != NSNotFound) {
        [self setSelectedRange:foundRange];
    }
}

- (void)replaceText:(NSString *)searchText withText:(NSString *)replaceText options:(NSStringCompareOptions)options
{
    if (!_textView || !searchText || !replaceText) return;
    
    // Simple replacement - in a full implementation, you'd want more sophisticated handling
    NSString *text = [_textView string];
    NSString *newText = [text stringByReplacingOccurrencesOfString:searchText withString:replaceText options:options range:NSMakeRange(0, [text length])];
    [self setText:newText];
}

- (void)findNext
{
    if (_findString) {
        // TODO: Implement find next
    }
}

- (void)findPrevious
{
    if (_findString) {
        // TODO: Implement find previous
    }
}

#pragma mark - Indentation

- (void)indentSelectedLines
{
    // TODO: Implement line indentation
}

- (void)unindentSelectedLines
{
    // TODO: Implement line unindentation
}

- (void)commentSelectedLines
{
    // TODO: Implement line commenting based on language
}

- (void)uncommentSelectedLines
{
    // TODO: Implement line uncommenting
}

#pragma mark - Folding

- (BOOL)canFoldAtLine:(NSUInteger)lineNumber
{
    // TODO: Implement folding detection
    return NO;
}

- (void)foldAtLine:(NSUInteger)lineNumber
{
    // TODO: Implement code folding
}

- (void)unfoldAtLine:(NSUInteger)lineNumber
{
    // TODO: Implement code unfolding
}

#pragma mark - NSTextViewDelegate

- (void)textDidChange:(NSNotification *)notification
{
    // Update document modified state
    if (_document) {
        [_document setModified:YES];
    }
    
    // Apply syntax highlighting with delay
    [NSObject cancelPreviousPerformRequestsWithTarget:self
                                             selector:@selector(applySyntaxHighlighting)
                                               object:nil];
    [self performSelector:@selector(applySyntaxHighlighting)
               withObject:nil
               afterDelay:0.5];
    
    // Update line numbers
    if (_lineNumberView) {
        [_lineNumberView setNeedsDisplay:YES];
    }
}

@end

#pragma mark - Line Number View Implementation

@implementation YCEditorLineNumberView

- (instancetype)initWithEditorView:(YCEditorView *)editorView
{
    self = [super initWithScrollView:[editorView scrollView] orientation:NSVerticalRuler];
    if (self) {
        _editorView = editorView; // weak reference
        _backgroundColor = [[NSColor colorWithDeviceWhite:0.9 alpha:1.0] retain];
        _textColor = [[NSColor colorWithDeviceWhite:0.5 alpha:1.0] retain];
        _font = [[NSFont fontWithName:@"Menlo" size:10.0] retain];
        
        [self setRuleThickness:50.0];
        [self setClientView:[editorView textView]];
    }
    return self;
}

- (void)dealloc
{
    RELEASE(_backgroundColor);
    RELEASE(_textColor);
    RELEASE(_font);
    [super dealloc];
}

- (YCEditorView *)editorView
{
    return _editorView;
}

- (void)setEditorView:(YCEditorView *)editorView
{
    _editorView = editorView; // weak reference
}

- (void)drawRect:(NSRect)rect
{
    // Fill background
    [_backgroundColor set];
    NSRectFill(rect);
    
    if (!_editorView || ![_editorView textView]) {
        return;
    }
    
    NSTextView *textView = [_editorView textView];
    NSString *text = [textView string];
    NSRect visibleRect = [textView visibleRect];
    NSRange visibleRange = [[textView layoutManager] glyphRangeForBoundingRect:visibleRect
                                                                    inTextContainer:[textView textContainer]];
    
    // Draw line numbers
    NSUInteger lineNumber = 1;
    NSUInteger characterIndex = 0;
    
    // Count lines up to visible range
    for (NSUInteger i = 0; i < visibleRange.location && i < [text length]; i++) {
        if ([text characterAtIndex:i] == '\n') {
            lineNumber++;
        }
    }
    
    // Draw visible line numbers
    NSLayoutManager *layoutManager = [textView layoutManager];
    NSTextContainer *textContainer = [textView textContainer];
    
    characterIndex = visibleRange.location;
    
    while (characterIndex < NSMaxRange(visibleRange) && characterIndex < [text length]) {
        NSRange lineRange = [text lineRangeForRange:NSMakeRange(characterIndex, 0)];
        NSRect lineRect = [layoutManager boundingRectForGlyphRange:NSMakeRange(characterIndex, 1)
                                                   inTextContainer:textContainer];
        
        // Convert to ruler coordinate system
        NSPoint linePoint = [self convertPoint:lineRect.origin fromView:textView];
        
        // Draw line number
        NSString *lineNumberString = [NSString stringWithFormat:@"%lu", (unsigned long)lineNumber];
        NSDictionary *attributes = @{
            NSFontAttributeName: _font,
            NSForegroundColorAttributeName: _textColor
        };
        
        NSSize textSize = [lineNumberString sizeWithAttributes:attributes];
        NSRect drawRect = NSMakeRect([self ruleThickness] - textSize.width - 5,
                                   linePoint.y,
                                   textSize.width,
                                   textSize.height);
        
        [lineNumberString drawInRect:drawRect withAttributes:attributes];
        
        lineNumber++;
        characterIndex = NSMaxRange(lineRange);
    }
}

@end
