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

#import "YCodePreferences.h"
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
        _savedContent = [[NSString alloc] init];
        _modified = NO;
        _undoManager = [[NSUndoManager alloc] init];
        _lastModified = [[NSDate date] retain];
        
        [self setupEditorView];
        [self setupSyntaxHighlighter];
        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(editorColorsChanged:)
            name:@"YCodeEditorColorsDidChange" object:nil];
        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(editorRulersChanged:)
            name:@"YCodeEditorRulersDidChange" object:nil];
        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(editorFontsChanged:)
            name:@"YCodeFontsDidChange" object:nil];
    }
    return self;
}

- (id)initWithFilePath:(NSString *)filePath content:(NSString *)content
{
    self = [self initWithFilePath:filePath];
    if (self && content) {
        [self setContent:content];
        [self setModified:NO];
    }
    return self;
}

- (void)dealloc
{
    [[NSNotificationCenter defaultCenter] removeObserver:self];
    RELEASE(_image);
    RELEASE(_filePath);
    RELEASE(_content);
    RELEASE(_savedContent);
    RELEASE(_undoManager);
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
    [_textView setFont:[YCodePreferences fontForPane:@"Editor"]];
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
    [(YCEditorRulerView *)_lineNumberRuler updateRulerVisibility];
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
        NSString *snapshot = [content copy];
        RELEASE(_content);
        _content = snapshot;
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
    BOOL external = _externalChange;
    if (!modified) {
        _externalChange = NO;
        NSString *snapshot = [[self content] copy];
        RELEASE(_savedContent);
        _savedContent = snapshot;
    }
    BOOL changed = !_image && !_soundDocument && modified &&
        ![[self content] isEqualToString:_savedContent];
    if (_modified == changed && external == _externalChange) return;
    _modified = changed;
    [[NSNotificationCenter defaultCenter] postNotificationName:
        @"YCodeFileModificationDidChange" object:_editorController];
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

+ (BOOL)isSoundFilePath:(NSString *)path
{
    NSString *extension = [[path pathExtension] lowercaseString];
    return [[NSSound soundUnfilteredFileTypes] containsObject:extension] ||
        [[NSArray arrayWithObjects:@"wav", @"wave", @"aif", @"aiff", @"aifc", @"au", @"snd",
          @"mp3", @"flac", @"ogg", @"oga", @"m4a", @"aac", @"caf", @"opus", nil] containsObject:extension];
}

- (BOOL)isSoundDocument
{
    return _soundDocument;
}

- (BOOL)loadFromFile
{
    NSString *extension = [[self fileExtension] lowercaseString];
    if ([[self class] isSoundFilePath:_filePath]) {
        BOOL directory = NO;
        if (![[NSFileManager defaultManager] fileExistsAtPath:_filePath isDirectory:&directory] || directory)
            return NO;
        _soundDocument = YES;
        [NSObject cancelPreviousPerformRequestsWithTarget:self];
        [_textView setDelegate:nil];
        DESTROY(_syntaxHighlighter);
        [_scrollView setRulersVisible:NO];
        [_scrollView setVerticalRulerView:nil];
        [_scrollView setHorizontalRulerView:nil];
        DESTROY(_lineNumberRuler);
        NSTextField *preview = [[NSTextField alloc] initWithFrame:NSMakeRect(0, 0, 380, 100)];
        [preview setStringValue:[NSString stringWithFormat:@"%@\n\nUse the Sound inspector to view the waveform and play this file.", [self fileName]]];
        [preview setEditable:NO]; [preview setBezeled:NO]; [preview setDrawsBackground:NO];
        [preview setFont:[NSFont systemFontOfSize:14]];
        [_scrollView setDocumentView:preview]; RELEASE(preview);
        DESTROY(_textView);
        [self setModified:NO];
        return YES;
    }
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
    if (_image || _soundDocument) return YES;
    [self checkForExternalChanges];
    if (_externalChange) {
        NSAlert *alert = AUTORELEASE([[NSAlert alloc] init]);
        [alert setMessageText:@"File Changed Outside Ycode"];
        [alert setInformativeText:[NSString stringWithFormat:
            @"%@ has changed or is no longer readable on disk. Overwrite it with your edits, reload the disk version, or cancel saving.", [self fileName]]];
        [alert addButtonWithTitle:@"Overwrite"];
        [alert addButtonWithTitle:@"Reload"];
        [alert addButtonWithTitle:@"Cancel"];
        NSInteger choice = [alert runModal];
        if (choice == NSAlertSecondButtonReturn) {
            BOOL loaded = [self loadFromFile];
            if (loaded) [_undoManager removeAllActions];
            return loaded;
        }
        if (choice != NSAlertFirstButtonReturn) return NO;
    }
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

- (BOOL)hasExternalChanges { return _externalChange; }

- (void)checkForExternalChanges
{
    // Text reloads are triggered by kernel events, never by a recurring timer.
    if (!_textView || ![_filePath isAbsolutePath]) return;
    NSString *disk = [NSString stringWithContentsOfFile:_filePath encoding:NSUTF8StringEncoding error:NULL];
    BOOL changed = disk == nil || ![disk isEqual:_savedContent];
    if (changed && disk && !_modified) {
        NSRange selection = [_textView selectedRange];
        NSPoint origin = [[_scrollView contentView] bounds].origin;
        [self setContent:disk];
        NSDictionary *attributes = [[NSFileManager defaultManager] attributesOfItemAtPath:_filePath error:NULL];
        ASSIGN(_lastModified, [attributes fileModificationDate]);
        [_undoManager removeAllActions];
        [self setModified:NO];
        selection.location = MIN(selection.location, [disk length]);
        selection.length = MIN(selection.length, [disk length] - selection.location);
        [_textView setSelectedRange:selection];
        [[_scrollView contentView] scrollToPoint:origin];
        [_scrollView reflectScrolledClipView:[_scrollView contentView]];
        changed = NO;
    }
    if (_externalChange != changed) {
        _externalChange = changed;
        [[NSNotificationCenter defaultCenter] postNotificationName:
            @"YCodeFileModificationDidChange" object:_editorController];
    }
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

- (void)editorFontsChanged:(NSNotification *)notification
{
    [_textView setFont:[YCodePreferences fontForPane:@"Editor"]];
    [self applySyntaxHighlighting];
    [_lineNumberRuler setNeedsDisplay:YES];
    [[_scrollView horizontalRulerView] setNeedsDisplay:YES];
}

- (void)editorRulersChanged:(NSNotification *)notification
{
    if (!_image && !_soundDocument) [(YCEditorRulerView *)_lineNumberRuler updateRulerVisibility];
}

- (void)editorColorsChanged:(NSNotification *)notification
{
    [_syntaxHighlighter loadPreferredColors];
    [_textView setBackgroundColor:[YCodeSyntaxHighlighter preferredColorForKey:@"background"]];
    [self applySyntaxHighlighting];
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

- (NSUndoManager *)undoManagerForTextView:(NSTextView *)textView
{
    return _undoManager;
}

- (void)textDidChange:(NSNotification *)notification
{
    if ([notification object] != _textView) return;
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
