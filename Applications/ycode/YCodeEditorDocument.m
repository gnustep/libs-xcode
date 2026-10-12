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
#import "YCEditorView.h"
#import "YCodeTextView.h"
#import "YCodeEditorController.h"
#import "YCodeSyntaxHighlighter.h"

@interface YCodeImageClipView : NSClipView
@end

@implementation YCodeImageClipView
- (NSPoint)constrainScrollPoint:(NSPoint)point
{
    point = [super constrainScrollPoint:point];
    NSRect document = [[self documentView] frame];
    NSSize viewport = [self bounds].size;
    if (document.size.width < viewport.width)
        point.x = NSMidX(document) - viewport.width / 2;
    if (document.size.height < viewport.height)
        point.y = NSMidY(document) - viewport.height / 2;
    return point;
}
@end

@implementation YCodeEditorDocument

- (id)initWithFilePath:(NSString *)filePath
{
    self = [super init];
    if (self) {
        ASSIGN(_filePath, filePath);
        _content = [[NSString alloc] init];
        _modified = NO;
        _lastModified = [[NSDate date] retain];
        
        [self setupEditorView];
        [self setupSyntaxHighlighter];
    }
    return self;
}

- (id)initWithFilePath:(NSString *)filePath content:(NSString *)content
{
    self = [self initWithFilePath:filePath];
    if (self && content) {
        [self setContent:content];
    }
    return self;
}

- (void)dealloc
{
    RELEASE(_image);
    RELEASE(_filePath);
    RELEASE(_content);
    RELEASE(_lastModified);
    RELEASE(_scrollView);
    RELEASE(_textView);
    RELEASE(_lineNumberRuler);
    RELEASE(_syntaxHighlighter);
    [super dealloc];
}

- (void)setupEditorView
{
    // Create scroll view
    _scrollView = [[NSScrollView alloc] initWithFrame:NSMakeRect(0, 0, 400, 300)];
    [_scrollView setHasVerticalScroller:YES];
    [_scrollView setHasHorizontalScroller:YES];
    [_scrollView setAutohidesScrollers:YES];
    [_scrollView setBorderType:NSNoBorder];
    [_scrollView setAutoresizingMask:NSViewWidthSizable | NSViewHeightSizable];
    
    // Create text view
    NSRect textFrame = NSMakeRect(0, 0, [_scrollView contentSize].width, [_scrollView contentSize].height);
    _textView = [[YCodeTextView alloc] initWithFrame:textFrame];
    [_textView setFont:[NSFont userFixedPitchFontOfSize:12.0]];
    [_textView setDelegate:self];
    [_textView setRichText:NO];
    [_textView setUsesFontPanel:YES];
    [_textView setUsesRuler:NO];
    [_textView setAllowsUndo:YES];
    [_textView setMinSize:NSMakeSize(0, 0)];
    [_textView setMaxSize:NSMakeSize(1e7, 1e7)];
    [_textView setVerticallyResizable:YES];
    [_textView setHorizontallyResizable:YES];
    [_textView setAutoresizingMask:NSViewNotSizable];
    
    // Configure text container
    NSTextContainer *textContainer = [_textView textContainer];
    [textContainer setWidthTracksTextView:NO];
    [textContainer setHeightTracksTextView:NO];
    [textContainer setContainerSize:NSMakeSize(1e7, 1e7)];
    
    [(YCodeTextView *)_textView setFilePath:_filePath];

    // Set up scroll view
    [_scrollView setDocumentView:_textView];
    
    // Add line number ruler (optional)
    [self setupLineNumberRuler];
}

- (void)setupLineNumberRuler
{
    _lineNumberRuler = [[YCEditorRulerView alloc] initWithScrollView:_scrollView orientation:NSVerticalRuler];
    [_lineNumberRuler setClientView:_textView];
    [_lineNumberRuler setRuleThickness:50.0];
    [_scrollView setVerticalRulerView:_lineNumberRuler];
    [_scrollView setHasVerticalRuler:YES];
    NSRulerView *columns = [[YCEditorRulerView alloc] initWithScrollView:_scrollView orientation:NSHorizontalRuler];
    [columns setClientView:_textView];
    [columns setRuleThickness:24.0];
    [_scrollView setHorizontalRulerView:columns];
    [_scrollView setHasHorizontalRuler:YES];
    RELEASE(columns);
    [_scrollView setRulersVisible:YES];
}

- (void)setupSyntaxHighlighter
{
    DESTROY(_syntaxHighlighter);
    if (!_textView) return;
    NSString *extension = [self fileExtension];
    NSString *name = [[self fileName] lowercaseString];
    if ([name isEqual:@"gnumakefile"] || [name isEqual:@"makefile"] ||
        [name hasPrefix:@"gnumakefile."] || [name hasPrefix:@"makefile."])
        extension = @"make";
    else if ([name isEqual:@"cmakelists.txt"])
        extension = @"cmake";
    _syntaxHighlighter = [[YCodeSyntaxHighlighter alloc] initWithFileExtension:extension];
    [_syntaxHighlighter setTextView:_textView];
}

#pragma mark - File Properties

- (NSString *)filePath
{
    return _filePath;
}

- (void)setFilePath:(NSString *)filePath
{
    ASSIGN(_filePath, filePath);
    [(YCodeTextView *)_textView setFilePath:filePath];
    [self setupSyntaxHighlighter];
    [self applySyntaxHighlighting];
}

- (NSString *)fileName
{
    return [_filePath lastPathComponent];
}

- (NSString *)fileExtension
{
    return [_filePath pathExtension];
}

#pragma mark - Content Management

- (NSString *)content
{
    if (_textView) {
        return [_textView string];
    }
    return _content;
}

- (void)setContent:(NSString *)content
{
    if (content && !_image) {
        ASSIGN(_content, content);
        if (_textView) {
            [_textView setString:content];
            [self applySyntaxHighlighting];
            // Update the scrollable extent immediately after loading a file.
            [_textView sizeToFit];
            [_lineNumberRuler setNeedsDisplay:YES];
        }
    }
}

- (BOOL)isModified
{
    return _modified;
}

- (void)setModified:(BOOL)modified
{
    _modified = _image ? NO : modified;
    // TODO: Update tab title to show modification state
}

- (NSDate *)lastModified
{
    return _lastModified;
}

#pragma mark - UI Components

- (BOOL)isImageDocument
{
    return _image != nil;
}

- (NSImage *)image
{
    return _image;
}

- (NSView *)editorView
{
    return _scrollView;
}

- (NSTextView *)textView
{
    return _textView;
}

- (NSScrollView *)scrollView
{
    return _scrollView;
}

#pragma mark - File Operations

- (BOOL)loadFromFile
{
    NSString *extension = [[self fileExtension] lowercaseString];
    if (_image || [[NSImage imageFileTypes] containsObject:extension] ||
        [[NSArray arrayWithObjects:@"png", @"jpg", @"jpeg", @"gif", @"tif",
          @"tiff", @"bmp", @"ico", @"icns", @"webp", nil] containsObject:extension]) {
        NSImage *image = [[NSImage alloc] initWithContentsOfFile:_filePath];
        if (!image || ![image isValid]) {
            RELEASE(image);
            return NO;
        }
        ASSIGN(_image, image);
        RELEASE(image);
        [NSObject cancelPreviousPerformRequestsWithTarget:self];
        [_textView setDelegate:nil];
        DESTROY(_syntaxHighlighter);
        [_scrollView setRulersVisible:NO];
        [_scrollView setVerticalRulerView:nil];
        [_scrollView setHorizontalRulerView:nil];
        DESTROY(_lineNumberRuler);
        YCodeImageClipView *clip = [[YCodeImageClipView alloc]
            initWithFrame:[[_scrollView contentView] frame]];
        [_scrollView setContentView:clip];
        RELEASE(clip);
        NSImageView *preview = [[NSImageView alloc] initWithFrame:
            NSMakeRect(0, 0, [_image size].width, [_image size].height)];
        [preview setImage:_image];
        [preview setImageScaling:NSImageScaleNone];
        [preview setEditable:NO];
        [_scrollView setDocumentView:preview];
        [[_scrollView contentView] scrollToPoint:NSZeroPoint];
        RELEASE(preview);
        DESTROY(_textView);
        [self setModified:NO];
        NSDictionary *attributes = [[NSFileManager defaultManager]
            attributesOfItemAtPath:_filePath error:NULL];
        ASSIGN(_lastModified, [attributes fileModificationDate]);
        [[NSNotificationCenter defaultCenter] postNotificationName:
            YCodeCurrentDocumentDidChangeNotification object:_editorController];
        return YES;
    }
    NSError *error = nil;
    NSString *content = [NSString stringWithContentsOfFile:_filePath
                                                   encoding:NSUTF8StringEncoding
                                                      error:&error];
    
    if (content) {
        [self setContent:content];
        [self setModified:NO];
        
        // Update last modified date
        NSDictionary *attributes = [[NSFileManager defaultManager] attributesOfItemAtPath:_filePath error:nil];
        if (attributes) {
            ASSIGN(_lastModified, [attributes fileModificationDate]);
        }
        
        return YES;
    } else {
        NSLog(@"Error loading file %@: %@", _filePath, [error localizedDescription]);
        return NO;
    }
}

- (BOOL)saveToFile
{
    // Previewing an image must never overwrite its bytes with text.
    if (_image) return YES;
    NSString *content = [self content];
    NSError *error = nil;
    
    BOOL success = [content writeToFile:_filePath
                             atomically:YES
                               encoding:NSUTF8StringEncoding
                                  error:&error];
    
    if (success) {
        [self setModified:NO];
        ASSIGN(_lastModified, [NSDate date]);
        [[NSNotificationCenter defaultCenter] postNotificationName:
            YCodeCurrentDocumentDidChangeNotification object:_editorController];
    } else {
        NSLog(@"Error saving file %@: %@", _filePath, [error localizedDescription]);
    }
    
    return success;
}

- (BOOL)reloadFromFile
{
    if ([self isModified]) {
        NSAlert *alert = [[NSAlert alloc] init];
        [alert setMessageText:@"Reload File?"];
        [alert setInformativeText:@"This will discard any unsaved changes."];
        [alert addButtonWithTitle:@"Reload"];
        [alert addButtonWithTitle:@"Cancel"];
        
        NSInteger result = [alert runModal];
        RELEASE(alert);
        
        if (result != NSAlertFirstButtonReturn) {
            return NO;
        }
    }
    
    return [self loadFromFile];
}

#pragma mark - Text Operations

- (void)insertText:(NSString *)text atLocation:(NSUInteger)location
{
    if (_textView && text) {
        NSRange insertRange = NSMakeRange(location, 0);
        [_textView setSelectedRange:insertRange];
        [_textView insertText:text];
        [self setModified:YES];
    }
}

- (NSString *)selectedText
{
    if (_textView) {
        NSRange selectedRange = [_textView selectedRange];
        NSString *text = [_textView string];
        if (selectedRange.location != NSNotFound && 
            selectedRange.location + selectedRange.length <= [text length]) {
            return [text substringWithRange:selectedRange];
        }
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

#pragma mark - Syntax Highlighting

- (YCodeSyntaxHighlighter *)syntaxHighlighter
{
    return _syntaxHighlighter;
}

- (void)applySyntaxHighlighting
{
    if (_syntaxHighlighter && _textView) {
        if (_editorController && ![_editorController syntaxHighlighting]) {
            [_syntaxHighlighter removeHighlighting];
        } else {
            [_syntaxHighlighter highlightText];
        }
    }
}

#pragma mark - Editor Controller

- (YCodeEditorController *)editorController
{
    return _editorController;
}

- (void)setEditorController:(YCodeEditorController *)controller
{
    _editorController = controller; // weak reference
}

#pragma mark - NSTextViewDelegate

- (void)textDidChange:(NSNotification *)notification
{
    [self setModified:YES];
    
    // Apply syntax highlighting with a delay to avoid performance issues
    [NSObject cancelPreviousPerformRequestsWithTarget:self
                                             selector:@selector(applySyntaxHighlighting)
                                               object:nil];
    [self performSelector:@selector(applySyntaxHighlighting)
               withObject:nil
               afterDelay:0.5];
}

- (BOOL)textView:(NSTextView *)textView shouldChangeTextInRange:(NSRange)affectedCharRange replacementString:(NSString *)replacementString
{
    return YES;
}

@end
