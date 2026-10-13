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
#import "YCodeControlIcons.h"
#import "YCodeWindowController.h"
#import "YCodeProject.h"
#import <XCode/PBXProject.h>
#import <XCode/PBXTarget.h>
#import "YCodeProjectNavigatorController.h"
#import "YCodeEditorController.h"
#import "YCodeEditorDocument.h"
#import "YCTreeView.h"
#import "YCodeProjectNavigatorItem.h"
#import "YCEditorView.h"
#import "YCInspectorView.h"
#import "YCFileInspectorView.h"
#import "YCImageInspectorView.h"

/* Stateful ANSI transcript decoder. Cursor controls are consumed: these panes
   are append-only transcripts, rather than terminal emulators. */
@interface YCANSITranscript : NSObject
{
  NSMutableDictionary *_attributes;
  NSMutableString *_sequence;
  NSUInteger _state;
  NSFont *_font;
  BOOL _bold;
}
- (NSAttributedString *)decode:(NSString *)text;
- (void)setFont:(NSFont *)font;
@end

@implementation YCANSITranscript
- (id)init
{
  if ((self = [super init]))
    {
      _font = RETAIN([YCodePreferences fontForPane:@"Console"]);
      _attributes = [NSMutableDictionary new];
      _sequence = [NSMutableString new];
      [_attributes setObject:_font forKey:NSFontAttributeName];
      [_attributes setObject:[NSColor textColor] forKey:NSForegroundColorAttributeName];
    }
  return self;
}
- (void)dealloc
{
  [_font release];
  [_attributes release];
  [_sequence release];
  [super dealloc];
}
- (void)setFont:(NSFont *)font
{
    ASSIGN(_font, font);
    NSFont *styled = _bold ? [[NSFontManager sharedFontManager] convertFont:_font toHaveTrait:NSBoldFontMask] : _font;
    [_attributes setObject:styled ?: _font forKey:NSFontAttributeName];
}

- (NSColor *)color:(NSInteger)index
{
  static const unsigned char palette[16][3] = {
    {0,0,0}, {170,0,0}, {0,170,0}, {170,85,0},
    {0,0,170}, {170,0,170}, {0,170,170}, {170,170,170},
    {85,85,85}, {255,85,85}, {85,255,85}, {255,255,85},
    {85,85,255}, {255,85,255}, {85,255,255}, {255,255,255}
  };
  if (index < 0 || index > 255) return nil;
  if (index < 16)
    return [NSColor colorWithCalibratedRed:palette[index][0] / 255.0
      green:palette[index][1] / 255.0 blue:palette[index][2] / 255.0 alpha:1];
  if (index >= 232)
    return [NSColor colorWithCalibratedWhite:(8 + (index - 232) * 10) / 255.0 alpha:1];
  NSInteger n = index - 16;
  NSInteger r = n / 36, g = (n / 6) % 6, b = n % 6;
  return [NSColor colorWithCalibratedRed:(r ? 55 + r * 40 : 0) / 255.0
    green:(g ? 55 + g * 40 : 0) / 255.0 blue:(b ? 55 + b * 40 : 0) / 255.0 alpha:1];
}
- (void)applyStyle
{
  NSArray *codes = [_sequence componentsSeparatedByString:@";"];
  NSUInteger i;
  for (i = 0; i < [codes count]; i++)
    {
      NSInteger code = [[codes objectAtIndex:i] integerValue];
      NSColor *color = nil;
      NSString *key = NSForegroundColorAttributeName;
      if (code == 0)
        {
          _bold = NO;
          [_attributes removeAllObjects];
          [_attributes setObject:_font forKey:NSFontAttributeName];
          [_attributes setObject:[NSColor textColor] forKey:NSForegroundColorAttributeName];
        }
      else if (code == 1 || code == 22) {
        _bold = code == 1;
        [self setFont:_font];
      }
      else if (code == 4 || code == 24)
        [_attributes setObject:[NSNumber numberWithInt:code == 4 ? NSUnderlineStyleSingle : NSUnderlineStyleNone]
          forKey:NSUnderlineStyleAttributeName];
      else if (code == 39) [_attributes setObject:[NSColor textColor] forKey:NSForegroundColorAttributeName];
      else if (code == 49) [_attributes removeObjectForKey:NSBackgroundColorAttributeName];
      else if ((code >= 30 && code <= 37) || (code >= 90 && code <= 97))
        color = [self color:code >= 90 ? code - 90 + 8 : code - 30];
      else if ((code >= 40 && code <= 47) || (code >= 100 && code <= 107))
        {
          key = NSBackgroundColorAttributeName;
          color = [self color:code >= 100 ? code - 100 + 8 : code - 40];
        }
      else if ((code == 38 || code == 48) && i + 1 < [codes count])
        {
          key = code == 38 ? NSForegroundColorAttributeName : NSBackgroundColorAttributeName;
          NSInteger mode = [[codes objectAtIndex:++i] integerValue];
          if (mode == 5 && i + 1 < [codes count]) color = [self color:[[codes objectAtIndex:++i] integerValue]];
          else if (mode == 2 && i + 3 < [codes count])
            {
              NSInteger red = [[codes objectAtIndex:++i] integerValue];
              NSInteger green = [[codes objectAtIndex:++i] integerValue];
              NSInteger blue = [[codes objectAtIndex:++i] integerValue];
              CGFloat r = MAX(0, MIN(255, red)) / 255.0;
              CGFloat g = MAX(0, MIN(255, green)) / 255.0;
              CGFloat b = MAX(0, MIN(255, blue)) / 255.0;
              color = [NSColor colorWithCalibratedRed:r green:g blue:b alpha:1];
            }
          else break;
        }
      if (color) [_attributes setObject:color forKey:key];
    }
}
- (NSAttributedString *)decode:(NSString *)text
{
  NSMutableAttributedString *result = AUTORELEASE([[NSMutableAttributedString alloc] init]);
  NSUInteger i, start = 0;
  for (i = 0; i < [text length]; i++)
    {
      unichar c = [text characterAtIndex:i];
      if (_state == 0 && c != 27) continue;
      if (_state == 0)
        {
          if (i > start) [result appendAttributedString:AUTORELEASE([[NSAttributedString alloc]
            initWithString:[text substringWithRange:NSMakeRange(start, i - start)] attributes:_attributes])];
          _state = 1;
        }
      else if (_state == 1)
        {
          [_sequence setString:@""];
          _state = c == '[' ? 2 : (c == ']' || c == 'P' || c == '^' || c == '_' ? 3 : 0);
        }
      else if (_state == 2)
        {
          if (c >= 0x40 && c <= 0x7e)
            {
              if (c == 'm') [self applyStyle];
              _state = 0;
            }
          else if ([_sequence length] < 1024) [_sequence appendFormat:@"%C", c];
          else _state = 0;
        }
      else if (_state == 3) { if (c == 7) _state = 0; else if (c == 27) _state = 4; }
      else if (_state == 4) _state = c == '\\' || c == 7 ? 0 : 3;
      start = i + 1;
    }
  if (start < [text length]) [result appendAttributedString:AUTORELEASE([[NSAttributedString alloc]
    initWithString:[text substringFromIndex:start] attributes:_attributes])];
  return result;
}
@end

/* Custom toolbar views need their enabled state refreshed during validation,
   including after cancellation has finished draining the task's output. */
@interface YCodeTargetToolbarItem : NSToolbarItem
@end
@implementation YCodeTargetToolbarItem
- (void)validate
{
    [super validate];
    [(NSPopUpButton *)[self view] setEnabled:[[self target] validateToolbarItem:self]];
}
@end

static NSScrollView *
YCodeScrollViewWithDocumentView(NSView *documentView)
{
    NSScrollView *scrollView = [[NSScrollView alloc] initWithFrame:[documentView frame]];

    [scrollView setHasVerticalScroller:YES];
    [scrollView setHasHorizontalScroller:YES];
    [scrollView setAutoresizingMask:NSViewWidthSizable | NSViewHeightSizable];
    [scrollView setDocumentView:documentView];

    return AUTORELEASE(scrollView);
}

@interface YCodeWindowController (Private)
- (void)saveWindowFrame:(NSNotification *)notification;
- (void)restoreSidebarWidths;
- (void)fontsChanged:(NSNotification *)notification;
- (void)refreshTargetSelectors;
- (void)populateTargetSelector:(NSPopUpButton *)selector;
- (void)appendConsoleOutput:(NSString *)output;
- (NSAttributedString *)decodeOutput:(NSString *)output stream:(NSString *)stream;
- (void)consumeDiagnostics:(NSString *)output buffer:(NSMutableString *)buffer;
- (void)finishDiagnostics;
- (void)parseDiagnosticLine:(NSString *)line;
- (void)openBuildIssue:(id)sender;
- (void)setupResultNavigators;
- (void)consumeTestOutput:(NSString *)output buffer:(NSMutableString *)buffer;
@end

@implementation YCodeWindowController

- (id)init
{
    NSRect contentRect = NSMakeRect(100, 100, 980, 680);
    NSUInteger styleMask = NSTitledWindowMask | NSClosableWindowMask |
        NSMiniaturizableWindowMask | NSResizableWindowMask;
    NSWindow *window = [[NSWindow alloc] initWithContentRect:contentRect
                                                   styleMask:styleMask
                                                     backing:NSBackingStoreBuffered
                                                       defer:NO];

    self = [super initWithWindow:window];
    RELEASE(window);

    if (self) {
        NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
        _navigatorWidth = [defaults doubleForKey:@"YCodeNavigatorWidth"];
        _inspectorWidth = [defaults doubleForKey:@"YCodeInspectorWidth"];
        if (!isfinite(_navigatorWidth) || _navigatorWidth < 80) _navigatorWidth = 250;
        if (!isfinite(_inspectorWidth) || _inspectorWidth < 80) _inspectorWidth = 250;
        _navigatorVisible = ![defaults boolForKey:@"YCodeNavigatorHidden"];
        _inspectorVisible = ![defaults boolForKey:@"YCodeInspectorHidden"];
        _bottomPanelVisible = NO;
        
        // Initialize controllers
        _navigatorController = [[YCodeProjectNavigatorController alloc] init];
        _editorController = [[YCodeEditorController alloc] init];

        [[self window] setTitle:@"Ycode"];
        [[self window] setMinSize:NSMakeSize(700, 420)];
        [self setupInterface];
        [self setShouldCascadeWindows:NO];
        [[self window] setFrameUsingName:@"YCodeMainWindow"];
        [self restoreSidebarWidths];
        [self fontsChanged:nil];
        // Share the last position across projects. A frame autosave name can
        // only be owned by one live window, so save each window explicitly.
        NSNotificationCenter *center = [NSNotificationCenter defaultCenter];
        [center addObserver:self selector:@selector(fontsChanged:) name:@"YCodeFontsDidChange" object:nil];
        [center addObserver:self selector:@selector(sidebarResized:) name:NSSplitViewDidResizeSubviewsNotification object:_mainSplitView];
        [center addObserver:self selector:@selector(sidebarResized:) name:NSSplitViewDidResizeSubviewsNotification object:_contentSplitView];
        [_navigatorView setPostsFrameChangedNotifications:YES];
        [_inspectorView setPostsFrameChangedNotifications:YES];
        [center addObserver:self selector:@selector(sidebarResized:) name:NSViewFrameDidChangeNotification object:_navigatorView];
        [center addObserver:self selector:@selector(sidebarResized:) name:NSViewFrameDidChangeNotification object:_inspectorView];
        [center addObserver:self selector:@selector(saveWindowFrame:)
            name:NSWindowDidMoveNotification object:[self window]];
        [center addObserver:self selector:@selector(saveWindowFrame:)
            name:NSWindowDidResizeNotification object:[self window]];
        [center addObserver:self selector:@selector(saveWindowFrame:)
            name:NSWindowWillCloseNotification object:[self window]];
        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(debuggerDidChange:)
            name:YCodeDebuggerDidChangeNotification object:nil];
    }
    return self;
}

- (void)fontsChanged:(NSNotification *)notification
{
    NSArray *views = [NSArray arrayWithObjects:_consoleTextView, _debuggerTextView, nil];
    NSArray *panes = [NSArray arrayWithObjects:@"Console", @"Debugger", nil];
    NSUInteger i;
    for (i = 0; i < [views count]; i++) {
        NSTextView *view = [views objectAtIndex:i];
        NSFont *font = [YCodePreferences fontForPane:[panes objectAtIndex:i]];
        [YCodePreferences applyFont:font toText:[view textStorage]];
        NSMutableDictionary *typing = [NSMutableDictionary dictionaryWithDictionary:[view typingAttributes]];
        [typing setObject:font forKey:NSFontAttributeName];
        [view setTypingAttributes:typing];
    }
    NSFont *font = [YCodePreferences fontForPane:@"Issues"];
    NSEnumerator *enumerator = [_buildIssues objectEnumerator];
    NSDictionary *issue;
    while ((issue = [enumerator nextObject]) != nil)
        [YCodePreferences applyFont:font toText:[issue objectForKey:@"display"]];
    if ([[_issuesTableView tableColumns] count])
        [[[[_issuesTableView tableColumns] objectAtIndex:0] dataCell] setFont:font];
    [_issuesTableView setRowHeight:MAX(58, ceil(([font ascender] - [font descender] + [font leading]) * 2 + 12))];
    [_issuesTableView reloadData];
}

- (void)restoreSidebarWidths
{
    BOOL restoring = _restoringSidebars;
    _restoringSidebars = YES;
    if (_navigatorVisible) {
        CGFloat desired = MIN(_navigatorWidth, MAX(80, NSWidth([_mainSplitView bounds]) - 400));
        CGFloat position = NSMaxX([_navigatorView frame]);
#ifdef GNUSTEP
        position = (position + NSMinX([_contentSplitView frame])) / 2;
#endif
        [_mainSplitView setPosition:position + desired - NSWidth([_navigatorView frame]) ofDividerAtIndex:0];
    }
    if (_inspectorVisible) {
        CGFloat desired = MIN(_inspectorWidth, MAX(80, NSWidth([_contentSplitView bounds]) - 250));
        CGFloat position = NSMaxX([_editorView frame]);
#ifdef GNUSTEP
        position = (position + NSMinX([_inspectorView frame])) / 2;
#endif
        [_contentSplitView setPosition:position + NSWidth([_inspectorView frame]) - desired ofDividerAtIndex:0];
    }
    _restoringSidebars = restoring;
}

- (void)sidebarResized:(NSNotification *)notification
{
    if (_restoringSidebars) return;
    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
    CGFloat width = NSWidth([_navigatorView frame]);
    if (_navigatorVisible && width >= 80) {
        _navigatorWidth = width;
        [defaults setDouble:width forKey:@"YCodeNavigatorWidth"];
    }
    width = NSWidth([_inspectorView frame]);
    if (_inspectorVisible && width >= 80) {
        _inspectorWidth = width;
        [defaults setDouble:width forKey:@"YCodeInspectorWidth"];
    }
    [defaults synchronize];
}

- (void)saveWindowFrame:(NSNotification *)notification
{
    if (![[self window] isMiniaturized])
        [[self window] saveFrameUsingName:@"YCodeMainWindow"];
}

- (void)dealloc
{
    [[NSNotificationCenter defaultCenter] removeObserver:self];
    [[_project buildSystem] setDelegate:nil];
    [[_project buildSystem] stop];
    RELEASE(_project);
    RELEASE(_navigatorController);
    RELEASE(_editorController);
    [_issuesTableView setTarget:nil];
    [_issuesTableView setDelegate:nil];
    [_issuesTableView setDataSource:nil];
    [_searchResultsTable setDataSource:nil];
    [_searchResultsTable setDelegate:nil];
    [_testResultsTable setDataSource:nil];
    [_testResultsTable setDelegate:nil];
    RELEASE(_searchResults);
    RELEASE(_testResults);
    RELEASE(_testOutput);
    RELEASE(_testErrors);
    RELEASE(_bottomView);
    RELEASE(_buildIssues);
    RELEASE(_diagnosticOutput);
    RELEASE(_diagnosticErrors);
    RELEASE(_buildDirectories);
    RELEASE(_diagnosticPattern);
    RELEASE(_ansiDecoders);
    RELEASE(_toolDiagnosticPattern);
    RELEASE(_directoryPattern);
    [super dealloc];
}

- (void)windowDidLoad
{
    [super windowDidLoad];
    [self setupInterface];
}

#pragma mark - Project Management

- (YCodeProject *)project
{
    return _project;
}

- (void)setProject:(YCodeProject *)project
{
    if (_project != project) {
        [[_project buildSystem] setDelegate:nil];
        [[_project buildSystem] stop];
        _collectingTests = NO;
        [_searchResults removeAllObjects];
        [_testResults removeAllObjects];
        [_testOutput setString:@""];
        [_testErrors setString:@""];
        [_searchResultsTable reloadData];
        [_testResultsTable reloadData];
        [_projectSearchField setStringValue:@""];
        [_searchStatus setStringValue:@"Enter text and press Return."];
        [_testStatus setStringValue:@"No tests run yet."];
        _collectingBuildIssues = NO;
        [_issuesTableView deselectAll:nil];
        [_buildIssues removeAllObjects];
        [_issuesTableView reloadData];
    }
    ASSIGN(_project, project);
    [[_project buildSystem] setDelegate:self];

    if (_project) {
        ASSIGN(_navigatorController, [_project navigatorController]);
        ASSIGN(_editorController, [_project editorController]);
    }

    [_navigatorController setProject:_project];
    [_editorController setProject:_project];

    if (_navigatorOutlineView) {
        [_navigatorController setOutlineView:_navigatorOutlineView];
    }

    if (_editorTabView) {
        [_editorController setTabView:_editorTabView];
    }
    [self updateInspectors:nil];
    [self refreshTargetSelectors];
    
    if (_project)
      {
	if ([_project projectPath])
	  {
	    [[self window] setTitle:[[_project projectPath] lastPathComponent]];
	  }
      }
}

- (void)openProject:(NSString *)projectPath
{
    if (projectPath != nil && [projectPath length] > 0) {
        YCodeProject *project = [[YCodeProject alloc] init];
        NSError *error = nil;
        NSURL *projectURL = [NSURL fileURLWithPath:projectPath];
        
        if ([project readFromURL:projectURL ofType:@"xcodeproj" error:&error]) {
            [self setProject:project];
        } else {
            NSString *message = (error != nil)
                ? [error localizedDescription]
                : @"The selected project could not be opened.";
            NSAlert *alert = [[NSAlert alloc] init];
            [alert setMessageText:@"Unable to open project"];
            [alert setInformativeText:message];
            [alert runModal];
            RELEASE(alert);
        }
        
        RELEASE(project);
    }
}

- (void)closeProject
{
    [self setProject:nil];
    [[self window] setTitle:@"Ycode"];
}

#pragma mark - Interface Setup

- (void)setupInterface
{
    NSView *contentView = [[self window] contentView];
    NSRect bounds = [contentView bounds];
    CGFloat width = MAX(NSWidth(bounds), 700);
    CGFloat height = MAX(NSHeight(bounds), 420);
    CGFloat navigatorWidth = MIN(220, width * 0.3);
    CGFloat inspectorWidth = MIN(240, MAX(0, width - navigatorWidth - 240));
    CGFloat editorWidth = MAX(0, width - navigatorWidth - inspectorWidth);
    NSRect bottomFrame = NSMakeRect(0, 0, editorWidth, 170);
    NSRect mainFrame = NSMakeRect(0, 0, width, height);
    NSRect navigatorFrame = NSMakeRect(0, 0, navigatorWidth, NSHeight(mainFrame));
    NSRect contentFrame = NSMakeRect(0, 0, width - navigatorWidth, NSHeight(mainFrame));
    NSRect editorFrame = NSMakeRect(0, 0, editorWidth, NSHeight(contentFrame));
    NSRect inspectorFrame = NSMakeRect(0, 0, inspectorWidth, NSHeight(contentFrame));

    if (_mainSplitView == nil) {
        _mainSplitView = [[NSSplitView alloc] initWithFrame:mainFrame];
        [_mainSplitView setVertical:YES];
        [_mainSplitView setAutoresizingMask:NSViewWidthSizable | NSViewHeightSizable];
        [contentView addSubview:_mainSplitView];
        RELEASE(_mainSplitView);
    }

    if (_navigatorView == nil) {
        _navigatorView = [[NSView alloc] initWithFrame:navigatorFrame];
        [_navigatorView setAutoresizingMask:NSViewHeightSizable];
        [_mainSplitView addSubview:_navigatorView];
        RELEASE(_navigatorView);
    }

    if (_contentSplitView == nil) {
        _contentSplitView = [[NSSplitView alloc] initWithFrame:contentFrame];
        [_contentSplitView setVertical:YES];
        [_contentSplitView setAutoresizingMask:NSViewWidthSizable | NSViewHeightSizable];
        [_mainSplitView addSubview:_contentSplitView];
        RELEASE(_contentSplitView);
    }

    if (_editorView == nil) {
        _editorView = [[NSView alloc] initWithFrame:editorFrame];
        [_editorView setAutoresizingMask:NSViewWidthSizable | NSViewHeightSizable];
        [_contentSplitView addSubview:_editorView];
        RELEASE(_editorView);
    }

    if (_inspectorView == nil) {
        _inspectorView = [[NSView alloc] initWithFrame:inspectorFrame];
        [_inspectorView setAutoresizingMask:NSViewHeightSizable];
        [_contentSplitView addSubview:_inspectorView];
        RELEASE(_inspectorView);
    }

    if (_bottomView == nil) {
        _bottomView = [[NSView alloc] initWithFrame:bottomFrame];
        [_bottomView setAutoresizingMask:NSViewWidthSizable | NSViewMaxYMargin];
        // Retained while hidden and detached from the editor split view.
    }

    [self setupToolbar];
    [self setupNavigatorArea];
    [self setupEditorArea];
    [self setupInspectorArea];
    [self setupBottomPanel];
    
    // Configure split views
    if (_mainSplitView) {
        [_mainSplitView setDelegate:self];
        [_mainSplitView setDividerStyle:NSSplitViewDividerStyleThin];
    }
    
    if (_contentSplitView) {
        [_contentSplitView setDelegate:self];
        [_contentSplitView setDividerStyle:NSSplitViewDividerStyleThin];
    }
    
    // Set initial visibility
    [self setNavigatorVisible:_navigatorVisible];
    [self setInspectorVisible:_inspectorVisible];
    [self setBottomPanelVisible:_bottomPanelVisible];
}

- (void)setupToolbar
{
    if (!_toolbar) {
        _toolbar = [[NSToolbar alloc] initWithIdentifier:@"YCodeMainToolbar"];
        [_toolbar setDelegate:self];
        [_toolbar setAllowsUserCustomization:YES];
        [_toolbar setAutosavesConfiguration:YES];
        [[self window] setToolbar:_toolbar];
        if (![[NSUserDefaults standardUserDefaults] boolForKey:@"YCodeTargetToolbarItemAdded"]) {
            BOOL found = NO;
            NSEnumerator *enumerator = [[_toolbar items] objectEnumerator];
            NSToolbarItem *item;
            while ((item = [enumerator nextObject]) != nil)
                if ([[item itemIdentifier] isEqual:@"scheme"]) found = YES;
            if (!found) [_toolbar insertItemWithItemIdentifier:@"scheme" atIndex:MIN(3, [[_toolbar items] count])];
            [[NSUserDefaults standardUserDefaults] setBool:YES forKey:@"YCodeTargetToolbarItemAdded"];
        }
        // Migrate the target selector's position once, preserving other custom items.
        if (![[NSUserDefaults standardUserDefaults] boolForKey:@"YCodeTargetToolbarAfterSeparator"]) {
            NSArray *identifiers = [[_toolbar items] valueForKey:@"itemIdentifier"];
            NSUInteger targetIndex = [identifiers indexOfObject:@"scheme"];
            if (targetIndex != NSNotFound) [_toolbar removeItemAtIndex:targetIndex];
            identifiers = [[_toolbar items] valueForKey:@"itemIdentifier"];
            NSUInteger separatorIndex = [identifiers indexOfObject:NSToolbarSeparatorItemIdentifier];
            if (separatorIndex == NSNotFound) {
                separatorIndex = [identifiers count];
                [_toolbar insertItemWithItemIdentifier:NSToolbarSeparatorItemIdentifier atIndex:separatorIndex];
            }
            [_toolbar insertItemWithItemIdentifier:@"scheme" atIndex:separatorIndex + 1];
#ifdef GNUSTEP
            // GNUstep saves removals but not programmatic insertions.
            NSMutableDictionary *configuration = [NSMutableDictionary dictionaryWithDictionary:
                [[NSUserDefaults standardUserDefaults] dictionaryForKey:@"NSToolbar Config YCodeMainToolbar"]
                    ?: [NSDictionary dictionary]];
            [configuration setObject:[[_toolbar items] valueForKey:@"itemIdentifier"] forKey:@"items"];
            [[NSUserDefaults standardUserDefaults] setObject:configuration
                forKey:@"NSToolbar Config YCodeMainToolbar"];
#endif
            [[NSUserDefaults standardUserDefaults] setBool:YES forKey:@"YCodeTargetToolbarAfterSeparator"];
            [[NSUserDefaults standardUserDefaults] synchronize];
        }
        // Add Build to older saved layouts once; subsequent customization is respected.
        NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
        if (![defaults boolForKey:@"YCodeBuildToolbarItemAdded"]) {
            NSArray *items = [_toolbar items];
            NSUInteger index, insertionIndex = 0;
            BOOL hasBuild = NO;
            for (index = 0; index < [items count]; index++) {
                NSString *identifier = [[items objectAtIndex:index] itemIdentifier];
                if ([identifier isEqualToString:@"build"]) hasBuild = YES;
                if ([identifier isEqualToString:@"run"]) insertionIndex = index;
            }
            if (!hasBuild) [_toolbar insertItemWithItemIdentifier:@"build" atIndex:insertionIndex];
            [defaults setBool:YES forKey:@"YCodeBuildToolbarItemAdded"];
        }
    }
}

- (void)populateTargetSelector:(NSPopUpButton *)selector
{
    [selector removeAllItems];
    [selector addItemWithTitle:@"Automatic"];
    NSEnumerator *enumerator = [[[_project project] targets] objectEnumerator];
    PBXTarget *target;
    NSString *selection = [[_project buildSystem] targetName];
    while ((target = [enumerator nextObject]) != nil) {
        if (![[target name] length]) continue;
        // Insert individual items so a target named Automatic remains distinct.
        NSMenuItem *entry = AUTORELEASE([[NSMenuItem alloc] initWithTitle:[target name]
            action:NULL keyEquivalent:@""]);
        [entry setRepresentedObject:[target name]];
        [[selector menu] addItem:entry];
        if ([[target name] isEqual:selection]) [selector selectItem:entry];
    }
    [selector setEnabled:[selector numberOfItems] > 1 && ![[_project buildSystem] isBusy]];
}

- (void)refreshTargetSelectors
{
    NSEnumerator *enumerator = [[_toolbar items] objectEnumerator];
    NSToolbarItem *item;
    while ((item = [enumerator nextObject]) != nil) {
        if ([[item itemIdentifier] isEqual:@"scheme"] && [[item view] isKindOfClass:[NSPopUpButton class]])
            [self populateTargetSelector:(NSPopUpButton *)[item view]];
    }
}

- (void)selectBuildTarget:(NSPopUpButton *)sender
{
    if (!_project || [[_project buildSystem] isBusy]) {
        [self refreshTargetSelectors];
        return;
    }
    [[_project buildSystem] setTargetName:[[sender selectedItem] representedObject]];
    [[_project buildSystem] setScheme:nil];
    [self refreshTargetSelectors];
}

- (void)setupNavigatorArea
{
    if (_navigatorTabView == nil) {
        _navigatorTabView = [[NSTabView alloc] initWithFrame:[_navigatorView bounds]];
        [_navigatorTabView setAutoresizingMask:NSViewWidthSizable | NSViewHeightSizable];
        [_navigatorView addSubview:_navigatorTabView];
        RELEASE(_navigatorTabView);
        {
          NSEnumerator *titleEnumerator = [[NSArray arrayWithObjects:@"Project", @"Search", @"Test", nil] objectEnumerator];
          NSString *title;
          while ((title = [titleEnumerator nextObject]) != nil)
            {
              NSTabViewItem *item = [[NSTabViewItem alloc] initWithIdentifier:[title lowercaseString]];
              [item setLabel:title];
              NSView *content = [[NSView alloc] initWithFrame:[_navigatorTabView contentRect]];
              [item setView:content];
              RELEASE(content);
              [_navigatorTabView addTabViewItem:item];
              RELEASE(item);
            }
        }
    }

    [self setupResultNavigators];

    if (_navigatorOutlineView == nil) {
        NSView *projectView = [[_navigatorTabView tabViewItemAtIndex:0] view];
        NSRect outlineFrame = [projectView bounds];
        NSScrollView *scrollView = nil;
        NSTableColumn *column = nil;

        _navigatorOutlineView = [[NSOutlineView alloc] initWithFrame:outlineFrame];
        [_navigatorOutlineView setAutoresizingMask:NSViewNotSizable];
        [_navigatorOutlineView setHeaderView:nil];
        [_navigatorOutlineView setGridStyleMask:NSTableViewGridNone];
        [_navigatorOutlineView setColumnAutoresizingStyle:NSTableViewLastColumnOnlyAutoresizingStyle];

        column = [[NSTableColumn alloc] initWithIdentifier:@"name"];
        [column setTitle:@"Project"];
        [column setMinWidth:0];
        [column setResizingMask:NSTableColumnAutoresizingMask];
        [column setWidth:NSWidth(outlineFrame)];
        [_navigatorOutlineView addTableColumn:column];
        [_navigatorOutlineView setOutlineTableColumn:column];
        RELEASE(column);

        // A table's frame is sized by its columns and rows, not by its pane.
        scrollView = AUTORELEASE([[NSScrollView alloc] initWithFrame:outlineFrame]);
        [scrollView setAutoresizingMask:NSViewWidthSizable | NSViewHeightSizable];
        [scrollView setHasVerticalScroller:YES];
        [scrollView setBorderType:NSNoBorder];
        [scrollView setHasHorizontalScroller:NO];
        [scrollView setDocumentView:_navigatorOutlineView];
        [projectView addSubview:scrollView];
        [_navigatorOutlineView sizeToFit];
        RELEASE(_navigatorOutlineView);
    }

    if (_navigatorOutlineView) {
        [_navigatorController setOutlineView:_navigatorOutlineView];
        [_navigatorOutlineView setMenu:[_navigatorController contextMenu]];
    }
    

}

- (void)setupEditorArea
{
    if (_editorSplitView == nil) {
        _editorSplitView = [[NSSplitView alloc] initWithFrame:[_editorView bounds]];
        [_editorSplitView setVertical:NO];
        [_editorSplitView setDividerStyle:NSSplitViewDividerStyleThin];
        [_editorSplitView setAutoresizingMask:NSViewWidthSizable | NSViewHeightSizable];
        [_editorView addSubview:_editorSplitView];
        RELEASE(_editorSplitView);
    }
    if (_editorTabView == nil) {
        _editorTabView = [[YCodeEditorTabView alloc] initWithFrame:[_editorSplitView bounds]];
        [_editorTabView setAutoresizingMask:NSViewWidthSizable | NSViewHeightSizable];
        [_editorSplitView addSubview:_editorTabView];
        RELEASE(_editorTabView);
    }
    [_editorController setTabView:_editorTabView];
    [_editorTabView setDelegate:_editorController];
}

- (void)setupInspectorArea
{
    if (_inspectorTabView == nil) {
        _inspectorTabView = [[NSTabView alloc] initWithFrame:[_inspectorView bounds]];
        [_inspectorTabView setAutoresizingMask:NSViewWidthSizable | NSViewHeightSizable];
        [_inspectorView addSubview:_inspectorTabView];
        RELEASE(_inspectorTabView);
    }

    if ([_inspectorTabView numberOfTabViewItems] == 0) {
        YCFileInspectorView *inspector = [[YCFileInspectorView alloc]
            initWithFrame:[_inspectorTabView contentRect]];
        [self registerInspectorView:inspector];
        RELEASE(inspector);
        YCImageInspectorView *imageInspector = [[YCImageInspectorView alloc]
            initWithFrame:[_inspectorTabView contentRect]];
        [self registerInspectorView:imageInspector];
        RELEASE(imageInspector);
    }
    NSNotificationCenter *center = [NSNotificationCenter defaultCenter];
    [center removeObserver:self name:YCodeCurrentDocumentDidChangeNotification object:nil];
    [center addObserver:self selector:@selector(updateInspectors:)
        name:YCodeCurrentDocumentDidChangeNotification object:nil];
    [self updateInspectors:nil];
}

- (void)registerInspectorView:(YCInspectorView *)inspector
{
    {
      NSEnumerator *itemEnumerator = [[_inspectorTabView tabViewItems] objectEnumerator];
      NSTabViewItem *item;
      while ((item = [itemEnumerator nextObject]) != nil)
        if ([[item identifier] isEqual:[inspector inspectorIdentifier]]) return;
    }
    NSTabViewItem *item = [[NSTabViewItem alloc]
        initWithIdentifier:[inspector inspectorIdentifier]];
    [item setLabel:[inspector inspectorTitle]];
    [inspector setAutoresizingMask:NSViewWidthSizable | NSViewHeightSizable];
    [item setView:inspector];
    [_inspectorTabView addTabViewItem:item];
    RELEASE(item);
    [inspector inspectDocument:[_editorController currentDocument]];
}

- (void)updateInspectors:(NSNotification *)notification
{
    if (notification && [notification object] != _editorController) return;
    [self updateDebuggerViews];
    NSString *identifier = [[_editorController currentDocument] isImageDocument] ? @"image" : @"file";
    [_inspectorTabView selectTabViewItemWithIdentifier:identifier];
    {
      NSEnumerator *itemEnumerator = [[_inspectorTabView tabViewItems] objectEnumerator];
      NSTabViewItem *item;
      while ((item = [itemEnumerator nextObject]) != nil)
        [(YCInspectorView *)[item view] inspectDocument:
              _project ? [_editorController currentDocument] : nil];
    }
}

- (void)setupBottomPanel
{
    // Reusing the text view in a second scroll view leaves stale clip observers.
    if ([_bottomTabView numberOfTabViewItems] > 0) return;
    if (_bottomTabView == nil) {
        _bottomTabView = [[NSTabView alloc] initWithFrame:[_bottomView bounds]];
        [_bottomTabView setAutoresizingMask:NSViewWidthSizable | NSViewHeightSizable];
        [_bottomView addSubview:_bottomTabView];
        RELEASE(_bottomTabView);
    }

    if (_consoleTextView == nil) {
        _consoleTextView = [[NSTextView alloc] initWithFrame:[_bottomView bounds]];
        [_consoleTextView setEditable:NO];
        [_consoleTextView setAutoresizingMask:NSViewWidthSizable | NSViewHeightSizable];
    }

    if (_issuesTableView == nil) {
        _buildIssues = [[NSMutableArray alloc] init];
        _diagnosticOutput = [[NSMutableString alloc] init];
        _diagnosticErrors = [[NSMutableString alloc] init];
        _buildDirectories = [[NSMutableArray alloc] init];
        _diagnosticPattern = [[NSRegularExpression alloc] initWithPattern:
            @"^(.+?):([0-9]+):(?:([0-9]+):)?\\s*(fatal error|error|warning|note|remark):\\s*(.*)$"
            options:0 error:NULL];
        _toolDiagnosticPattern = [[NSRegularExpression alloc] initWithPattern:
            @"^(?:([^:]+):\\s*)?(fatal error|error|warning|note):\\s*(.*)$"
            options:0 error:NULL];
        _directoryPattern = [[NSRegularExpression alloc] initWithPattern:
            @"(?:g?make)(?:\\[[0-9]+\\])?: (Entering|Leaving) directory [\\x60'‘](.*)['’]$"
            options:0 error:NULL];
        _issuesTableView = [[NSTableView alloc] initWithFrame:[_bottomView bounds]];
        [_issuesTableView setAllowsMultipleSelection:NO];
        [_issuesTableView setAllowsEmptySelection:YES];
        [_issuesTableView setDataSource:self];
        [_issuesTableView setDelegate:self];
        [_issuesTableView setTarget:self];
        [_issuesTableView setAction:@selector(openBuildIssue:)];
        [_issuesTableView setAutoresizingMask:NSViewNotSizable];
        [_issuesTableView setColumnAutoresizingStyle:NSTableViewLastColumnOnlyAutoresizingStyle];
        [_issuesTableView setRowHeight:58];
        NSTableColumn *column = [[NSTableColumn alloc] initWithIdentifier:@"issue"];
        [[column headerCell] setStringValue:@"Build Issues"];
        [column setEditable:NO];
        [column setMinWidth:80];
        [column setWidth:250];
        [[column dataCell] setWraps:YES];
        [[column dataCell] setLineBreakMode:NSLineBreakByWordWrapping];
        [_issuesTableView addTableColumn:column];
        RELEASE(column);
    }

    if (_bottomTabView) {
        [_bottomTabView setDelegate:self];
        
        // Add console tab
        NSTabViewItem *consoleTab = [[NSTabViewItem alloc] initWithIdentifier:@"console"];
        [consoleTab setLabel:@"Console"];
        [consoleTab setView:YCodeScrollViewWithDocumentView(_consoleTextView)];
        [_bottomTabView addTabViewItem:consoleTab];
        RELEASE(consoleTab);
        
        // Add issues tab
        NSTabViewItem *issuesTab = [[NSTabViewItem alloc] initWithIdentifier:@"issues"];
        [issuesTab setLabel:@"Issues"];
        NSScrollView *issuesScroll = YCodeScrollViewWithDocumentView(_issuesTableView);
        [issuesScroll setHasHorizontalScroller:NO];
        [[issuesScroll contentView] setPostsFrameChangedNotifications:YES];
        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(sizeIssuesColumn:)
            name:NSViewFrameDidChangeNotification object:[issuesScroll contentView]];
        [issuesTab setView:issuesScroll];
        RELEASE(_issuesTableView);
        [_bottomTabView addTabViewItem:issuesTab];
        RELEASE(issuesTab);

        NSTabViewItem *debuggerTab = [[NSTabViewItem alloc] initWithIdentifier:@"debugger"];
        [debuggerTab setLabel:@"Debugger"];
        NSView *debuggerView = AUTORELEASE([[NSView alloc] initWithFrame:[_bottomTabView contentRect]]);
        NSRect bounds = [debuggerView bounds];
        _debuggerControls = AUTORELEASE([[NSView alloc] initWithFrame:
            NSMakeRect(0, 0, 494, 30)]);
        NSArray *titles = [NSArray arrayWithObjects:@"Go", @"Pause", @"Continue", @"Restart",
            @"Next", @"Step Into", @"Step Out", nil];
        CGFloat x = 2;
        NSUInteger index;
        for (index = 0; index < [titles count]; index++) {
            NSButton *button = AUTORELEASE([[NSButton alloc] initWithFrame:NSMakeRect(x, 3, 70, 24)]);
            [button setTitle:[titles objectAtIndex:index]];
            [button setFont:[NSFont systemFontOfSize:11]];
            [button setBezelStyle:NSRoundedBezelStyle];
            [button setTag:index];
            [button setTarget:self];
            [button setAction:@selector(debugAction:)];
            [button setEnabled:NO];
            [_debuggerControls addSubview:button];
            x += 70;
        }
        NSScrollView *controlsScroll = AUTORELEASE([[NSScrollView alloc] initWithFrame:
            NSMakeRect(0, MAX(0, NSHeight(bounds) - 46), NSWidth(bounds), 46)]);
        [controlsScroll setAutoresizingMask:NSViewWidthSizable | NSViewMinYMargin];
        [controlsScroll setHasHorizontalScroller:YES];
        [controlsScroll setAutohidesScrollers:YES];
        [controlsScroll setDocumentView:_debuggerControls];
        [debuggerView addSubview:controlsScroll];
        _debuggerTextView = AUTORELEASE([[NSTextView alloc] initWithFrame:
            NSMakeRect(0, 0, NSWidth(bounds), MAX(0, NSHeight(bounds) - 74))]);
        [_debuggerTextView setEditable:NO];
        [_debuggerTextView setFont:[NSFont userFixedPitchFontOfSize:12]];
        [_debuggerTextView setAutoresizingMask:NSViewWidthSizable];
        [_debuggerTextView setHorizontallyResizable:NO];
        [[_debuggerTextView textContainer] setWidthTracksTextView:YES];
        NSScrollView *debugScroll = YCodeScrollViewWithDocumentView(_debuggerTextView);
        [debugScroll setHasHorizontalScroller:NO];
        [debugScroll setFrame:NSMakeRect(0, 28, NSWidth(bounds), MAX(0, NSHeight(bounds) - 74))];
        [debuggerView addSubview:debugScroll];
        _debuggerCommandField = AUTORELEASE([[NSTextField alloc] initWithFrame:
            NSMakeRect(4, 2, MAX(0, NSWidth(bounds) - 8), 24)]);
        [_debuggerCommandField setAutoresizingMask:NSViewWidthSizable];
        [[_debuggerCommandField cell] setPlaceholderString:@"GDB command"];
        [_debuggerCommandField setToolTip:@"GDB command: print variable, backtrace, break main, disable 1, enable 1"];
        [_debuggerCommandField setTarget:self];
        [_debuggerCommandField setAction:@selector(debugConsoleCommand:)];
        [_debuggerCommandField setEnabled:NO];
        [debuggerView addSubview:_debuggerCommandField];
        [debuggerTab setView:debuggerView];
        [_bottomTabView addTabViewItem:debuggerTab];
        RELEASE(debuggerTab);
    }
}

#pragma mark - Panel Visibility

- (BOOL)isNavigatorVisible
{
    return _navigatorVisible;
}

- (void)setNavigatorVisible:(BOOL)visible
{
    if (_navigatorVisible != visible) {
        NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
        [defaults setBool:!visible forKey:@"YCodeNavigatorHidden"];
        [defaults synchronize];
    }
    _restoringSidebars = YES;
    _navigatorVisible = visible;
    if (_navigatorView) {
        [_navigatorView setHidden:!visible];
        
        // Adjust split view
        if (_mainSplitView && [_mainSplitView subviews].count > 0) {
            NSView *firstSubview = [[_mainSplitView subviews] objectAtIndex:0];
            if (visible) {
                [firstSubview setFrame:NSMakeRect(0, 0, _navigatorWidth, NSHeight([firstSubview frame]))];
            } else {
                [firstSubview setFrame:NSMakeRect(0, 0, 0, NSHeight([firstSubview frame]))];
            }
            [_mainSplitView adjustSubviews];
        }
    }
    [self restoreSidebarWidths];
    _restoringSidebars = NO;
}

- (BOOL)isInspectorVisible
{
    return _inspectorVisible;
}

- (void)setInspectorVisible:(BOOL)visible
{
    if (_inspectorVisible != visible) {
        NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
        [defaults setBool:!visible forKey:@"YCodeInspectorHidden"];
        [defaults synchronize];
    }
    _restoringSidebars = YES;
    _inspectorVisible = visible;
    if (_inspectorView) {
        [_inspectorView setHidden:!visible];
        
        // Adjust split view
        if (_contentSplitView && [_contentSplitView subviews].count > 1) {
            NSView *lastSubview = [[_contentSplitView subviews] lastObject];
            if (visible) {
                [lastSubview setFrame:NSMakeRect(0, 0, _inspectorWidth, NSHeight([lastSubview frame]))];
            } else {
                [lastSubview setFrame:NSMakeRect(0, 0, 0, NSHeight([lastSubview frame]))];
            }
            [_contentSplitView adjustSubviews];
        }
    }
    [self restoreSidebarWidths];
    _restoringSidebars = NO;
}

- (BOOL)isBottomPanelVisible
{
    return _bottomPanelVisible;
}

- (void)setBottomPanelVisible:(BOOL)visible
{
    _bottomPanelVisible = visible;
    if (!_editorSplitView || !_bottomView) return;
    if (visible && [_bottomView superview] == nil) {
        CGFloat height = NSHeight([_editorSplitView bounds]);
        CGFloat panelHeight = _buildPanelHeight > 0 ? _buildPanelHeight : 220;
        panelHeight = MIN(panelHeight, height * 0.5);
        [_bottomView setFrame:NSMakeRect(0, 0, NSWidth([_editorSplitView bounds]), panelHeight)];
        [_bottomView setAutoresizingMask:NSViewWidthSizable | NSViewHeightSizable];
        [_editorSplitView addSubview:_bottomView];
        [_editorSplitView adjustSubviews];
        [_editorSplitView setPosition:MAX(0, height - panelHeight - [_editorSplitView dividerThickness])
                    ofDividerAtIndex:0];
    } else if (!visible && [_bottomView superview]) {
        _buildPanelHeight = NSHeight([_bottomView frame]);
        [_bottomView removeFromSuperview];
        [_editorSplitView adjustSubviews];
    }
}

#pragma mark - Actions

- (IBAction)toggleNavigator:(id)sender
{
    [self setNavigatorVisible:!_navigatorVisible];
}

- (IBAction)toggleInspector:(id)sender
{
    [self setInspectorVisible:!_inspectorVisible];
}

- (IBAction)toggleBottomPanel:(id)sender
{
    [self setBottomPanelVisible:!_bottomPanelVisible];
}

- (NSAttributedString *)decodeOutput:(NSString *)output stream:(NSString *)stream
{
    if (!_ansiDecoders) _ansiDecoders = [NSMutableDictionary new];
    YCANSITranscript *decoder = [_ansiDecoders objectForKey:stream];
    if (!decoder) {
        decoder = AUTORELEASE([YCANSITranscript new]);
        [_ansiDecoders setObject:decoder forKey:stream];
    }
    NSString *pane = [stream hasPrefix:@"issue"] ? @"Issues" :
        ([stream isEqual:@"debugger"] ? @"Debugger" : @"Console");
    [decoder setFont:[YCodePreferences fontForPane:pane]];
    return [decoder decode:output];
}

- (void)appendConsoleOutput:(NSString *)output
{
    if (!_consoleTextView || !output) return;
    NSTextStorage *storage = [_consoleTextView textStorage];
    [storage appendAttributedString:[self decodeOutput:output stream:@"console"]];
    [_consoleTextView scrollRangeToVisible:NSMakeRange([storage length], 0)];
}

- (BOOL)prepareBuild
{
    if (!_project || [[_project buildSystem] isBusy]) return NO;
    [self setBottomPanelVisible:YES];
    [_bottomTabView selectTabViewItemWithIdentifier:@"console"];
    if (![_editorController saveAllFiles]) {
        [self appendConsoleOutput:@"Build cancelled: unable to save edited files.\n"];
        return NO;
    }
    if ([_project isDocumentEdited] && ![_project saveProjectToPath:[_project projectPath]]) {
        [self appendConsoleOutput:@"Build cancelled: unable to save the project.\n"];
        return NO;
    }
    return YES;
}

- (void)updateDebuggerViews
{
    YCodeDebugger *debugger = _project ? [[_project buildSystem] debugger] : nil;
    {
      NSEnumerator *documentEnumerator = [[_editorController openDocuments] objectEnumerator];
      YCodeEditorDocument *document;
      while ((document = [documentEnumerator nextObject]) != nil)
        {
          YCEditorRulerView *ruler = (YCEditorRulerView *)[[document scrollView] verticalRulerView];
          [ruler setDebugger:debugger file:[document filePath] active:[debugger isReady]];
        }
    }
    [_debuggerCommandField setEnabled:[debugger isReady] && ![debugger isRunning]];
    {
      NSEnumerator *buttonEnumerator = [[_debuggerControls subviews] objectEnumerator];
      NSButton *button;
      while ((button = [buttonEnumerator nextObject]) != nil)
        [button setEnabled:[self validateDebuggerAction:@selector(debugAction:) tag:[button tag]]];
    }
    [_toolbar validateVisibleItems];
}

- (void)debuggerDidChange:(NSNotification *)notification
{
    if (_project && [notification object] == [[_project buildSystem] debugger])
        [self updateDebuggerViews];
}

- (void)buildSystem:(id)buildSystem didReceiveDebuggerOutput:(NSString *)output
{
    NSTextStorage *storage = [_debuggerTextView textStorage];
    [storage appendAttributedString:[self decodeOutput:output stream:@"debugger"]];
    [_debuggerTextView scrollRangeToVisible:NSMakeRange([storage length], 0)];
}

- (BOOL)validateDebuggerAction:(SEL)action tag:(NSInteger)tag
{
    YCodeBuildSystem *build = [_project buildSystem];
    if (action == @selector(debugProject:)) return _project && ![build isBusy];
    YCodeDebugger *debugger = [build debugger];
    if (action == @selector(toggleBreakpoint:))
        return [_editorController currentDocument] != nil && ![debugger isRunning];
    if (![build isDebugging] || ![debugger isReady]) return NO;
    if (tag == 1) return [debugger isRunning];
    if (tag == 3) return YES;
    return ![debugger isRunning];
}

- (IBAction)debugProject:(id)sender
{
    if ([self prepareBuild] && [[_project buildSystem] debug]) {
        [_debuggerTextView setString:@""];
        [_bottomTabView selectTabViewItemWithIdentifier:@"debugger"];
    }
}

- (IBAction)debugAction:(id)sender
{
    NSArray *commands = [NSArray arrayWithObjects:@"-exec-run", @"-exec-interrupt --all",
        @"-exec-continue", @"-exec-run", @"-exec-next", @"-exec-step", @"-exec-finish",
        @"-interpreter-exec console \"up\"", @"-interpreter-exec console \"down\"", nil];
    if (![[_project buildSystem] isDebugging]) return;
    NSInteger index = [sender tag];
    if (index == 3) { [[[_project buildSystem] debugger] restart]; return; }
    if (index >= 0 && index < (NSInteger)[commands count])
        [[[_project buildSystem] debugger] command:[commands objectAtIndex:index]];
}

- (IBAction)debugConsoleCommand:(id)sender
{
    if (![[[_project buildSystem] debugger] isReady]) return;
    [self buildSystem:[_project buildSystem] didReceiveDebuggerOutput:
        [NSString stringWithFormat:@"(gdb) %@\n", [sender stringValue]]];
    [[[_project buildSystem] debugger] consoleCommand:[sender stringValue]];
    [sender setStringValue:@""];
}

- (IBAction)toggleBreakpoint:(id)sender
{
    YCodeEditorDocument *document = [_editorController currentDocument];
    if (!document) return;
    NSString *text = [document content];
    NSUInteger position = [[document textView] selectedRange].location;
    NSUInteger offset = 0, line = 1;
    while (offset < position && offset < [text length]) {
        NSUInteger end;
        [text getLineStart:NULL end:&end contentsEnd:NULL forRange:NSMakeRange(offset, 0)];
        if (end > position || end <= offset) break;
        offset = end; line++;
    }
    [[[_project buildSystem] debugger] toggleBreakpointAtFile:[document filePath] line:line];
    [self setBottomPanelVisible:YES];
    [_bottomTabView selectTabViewItemWithIdentifier:@"debugger"];
}

- (void)buildSystem:(id)buildSystem stoppedAtFile:(NSString *)file line:(NSUInteger)line
{
    if (![_editorController openFile:file]) return;
    YCodeEditorDocument *document = [_editorController currentDocument];
    NSString *text = [document content];
    NSUInteger offset = 0, current = 1, end = 0;
    while (offset < [text length] && current < line) {
        [text getLineStart:NULL end:&end contentsEnd:NULL forRange:NSMakeRange(offset, 0)];
        if (end <= offset) break;
        offset = end; current++;
    }
    [text getLineStart:NULL end:NULL contentsEnd:&end forRange:NSMakeRange(offset, 0)];
    [document setSelectedRange:NSMakeRange(offset, end - offset)];
    [self setBottomPanelVisible:YES];
    [_bottomTabView selectTabViewItemWithIdentifier:@"debugger"];
    [self updateDebuggerViews];
}

- (IBAction)runProject:(id)sender
{
    if ([self prepareBuild]) [_project runProject];
}

- (IBAction)buildProject:(id)sender
{
    if ([self prepareBuild]) [_project buildProject];
}

- (IBAction)stopProject:(id)sender
{
    [[_project buildSystem] stop];
}

- (BOOL)validateToolbarItem:(NSToolbarItem *)item
{
    if ([item action] == @selector(selectBuildTarget:))
        return [[[_project project] targets] count] > 0 && ![[_project buildSystem] isBusy];
    if ([item action] == @selector(debugProject:) || [item action] == @selector(debugAction:))
        return [self validateDebuggerAction:[item action] tag:[item tag]];
    if ([item action] == @selector(stopProject:))
        return [[_project buildSystem] isBusy];
    if ([item action] == @selector(runProject:) || [item action] == @selector(buildProject:))
        return _project != nil && ![[_project buildSystem] isBusy];
    return YES;
}

- (void)buildSystemDidStartBuild:(id)buildSystem
{
    [self refreshTargetSelectors];
    [_ansiDecoders removeAllObjects];
    [_issuesTableView deselectAll:nil];
    [_buildIssues removeAllObjects];
    [_issuesTableView reloadData];
    [_diagnosticOutput setString:@""];
    [_diagnosticErrors setString:@""];
    [_buildDirectories removeAllObjects];
    _collectingBuildIssues = YES;
    [[_bottomTabView tabViewItemAtIndex:1] setLabel:@"Issues"];
    [self appendConsoleOutput:@"Building project...\n"];
}

- (void)buildSystemDidFinishBuild:(id)buildSystem success:(BOOL)success
{
    [self refreshTargetSelectors];
    [self finishDiagnostics];
    [self appendConsoleOutput:success ? @"Build succeeded.\n" : @"Build failed.\n"];
    [self setBottomPanelVisible:YES];
    if ([_buildIssues count] > 0)
        [_bottomTabView selectTabViewItemWithIdentifier:@"issues"];
}

- (void)buildSystemDidStartRun:(id)buildSystem
{
    [self refreshTargetSelectors];
    [_ansiDecoders removeAllObjects];
    [_bottomTabView selectTabViewItemWithIdentifier:[buildSystem isDebugging] ? @"debugger" : @"console"];
    if ([buildSystem isDebugging])
        [self buildSystem:buildSystem didReceiveDebuggerOutput:
            @"Starting debugger. Click the source gutter to add/remove breakpoints; Shift-click to enable/disable.\n"];
    else [self appendConsoleOutput:@"Starting project session...\n"];
}

- (void)buildSystemDidFinishRun:(id)buildSystem
{
    [self refreshTargetSelectors];
    [self appendConsoleOutput:[(YCodeBuildSystem *)buildSystem status] == YCodeBuildStatusFailed
        ? @"Run failed.\n" : @"Project exited.\n"];
}

- (void)buildSystemDidStartClean:(id)buildSystem
{
    [self refreshTargetSelectors];
}

- (void)buildSystemDidFinishClean:(id)buildSystem
{
    [self refreshTargetSelectors];
}

- (void)buildSystemDidCancel:(id)buildSystem
{
    [self refreshTargetSelectors];
    if (_collectingTests) {
        _collectingTests = NO;
        [_testStatus setStringValue:@"Tests cancelled."];
    }
    [self finishDiagnostics];
    [self appendConsoleOutput:@"Project stopped.\n"];
}

- (void)buildSystem:(id)buildSystem didReceiveOutput:(NSString *)output
{
    [self appendConsoleOutput:output];
    if (_collectingTests) [self consumeTestOutput:output buffer:_testOutput];
    if (_collectingBuildIssues) [self consumeDiagnostics:output buffer:_diagnosticOutput];
}

- (void)buildSystem:(id)buildSystem didReceiveError:(NSString *)error
{
    if ([buildSystem isDebugging]) [self buildSystem:buildSystem didReceiveDebuggerOutput:error];
    else {
        NSTextStorage *storage = [_consoleTextView textStorage];
        [storage appendAttributedString:[self decodeOutput:error stream:@"consoleErrors"]];
        [_consoleTextView scrollRangeToVisible:NSMakeRange([storage length], 0)];
    }
    if (_collectingTests) [self consumeTestOutput:error buffer:_testErrors];
    if (_collectingBuildIssues) [self consumeDiagnostics:error buffer:_diagnosticErrors];
}

#pragma mark - Search and Tests

- (void)setupResultNavigators
{
    if (_searchResults) return;
    _searchResults = [NSMutableArray new];
    _testResults = [NSMutableArray new];
    _testOutput = [NSMutableString new];
    _testErrors = [NSMutableString new];
    NSUInteger index;
    for (index = 1; index <= 2; index++) {
        NSView *view = [[_navigatorTabView tabViewItemAtIndex:index] view];
        NSRect bounds = [view bounds];
        NSControl *control;
        if (index == 1) {
            _projectSearchField = AUTORELEASE([[NSSearchField alloc] initWithFrame:
                NSMakeRect(4, NSHeight(bounds) - 30, MAX(0, NSWidth(bounds) - 8), 24)]);
            [[_projectSearchField cell] setPlaceholderString:@"Search project"];
            [[_projectSearchField cell] setSendsWholeSearchString:YES];
            control = _projectSearchField;
            [control setAction:@selector(searchProject:)];
        } else {
            NSButton *button = AUTORELEASE([[NSButton alloc] initWithFrame:
                NSMakeRect(4, NSHeight(bounds) - 30, MAX(0, NSWidth(bounds) - 8), 24)]);
            [button setTitle:@"Run Tests"];
            [button setBezelStyle:NSRoundedBezelStyle];
            control = button;
            [control setAction:@selector(testProject:)];
        }
        [control setTarget:self];
        [control setAutoresizingMask:NSViewWidthSizable | NSViewMinYMargin];
        [view addSubview:control];
        NSTextField *status = AUTORELEASE([[NSTextField alloc] initWithFrame:
            NSMakeRect(4, NSHeight(bounds) - 58, MAX(0, NSWidth(bounds) - 8), 24)]);
        [status setEditable:NO];
        [status setBezeled:NO];
        [status setDrawsBackground:NO];
        [status setAutoresizingMask:NSViewWidthSizable | NSViewMinYMargin];
        [status setStringValue:index == 1 ? @"Enter text and press Return." : @"No tests run yet."];
        [view addSubview:status];
        NSRect resultsFrame = NSMakeRect(0, 0, NSWidth(bounds), MAX(0, NSHeight(bounds) - 62));
        NSTableView *table = AUTORELEASE([[NSTableView alloc] initWithFrame:resultsFrame]);
        NSTableColumn *column = AUTORELEASE([[NSTableColumn alloc] initWithIdentifier:@"result"]);
        [column setWidth:600];
        [column setEditable:NO];
        [table addTableColumn:column];
        [table setHeaderView:nil];
        [table setGridStyleMask:NSTableViewGridNone];
        [table setRowHeight:38];
        [[column dataCell] setWraps:YES];
        [table setDataSource:(id)self];
        [table setDelegate:(id)self];
        NSScrollView *scrollView = YCodeScrollViewWithDocumentView(table);
        // An empty table shrinks to its rows; the viewport must retain the
        // full area below the search controls rather than the table's frame.
        [scrollView setFrame:resultsFrame];
        [view addSubview:scrollView];
        if (index == 1) { _searchResultsTable = table; _searchStatus = status; }
        else { _testResultsTable = table; _testStatus = status; }
    }
}

- (IBAction)searchProject:(id)sender
{
    [_searchResultsTable deselectAll:nil];
    [_searchResults removeAllObjects];
    NSString *query = [_projectSearchField stringValue];
    if ([query length] && _project) {
        [_navigatorController reloadProjectTree];
        NSMutableArray *pending = [NSMutableArray arrayWithArray:[_navigatorController rootItems]];
        NSMutableSet *paths = [NSMutableSet set];
        while ([pending count]) {
            YCodeProjectNavigatorItem *item = [[[pending lastObject] retain] autorelease];
            [pending removeLastObject];
            [pending addObjectsFromArray:[item children]];
            NSString *path = [_navigatorController resolvedFilePathForNavigatorItem:item];
            if (path) {
                BOOL directory = NO;
                if ([[NSFileManager defaultManager] fileExistsAtPath:path isDirectory:&directory] && directory) {
                    NSDirectoryEnumerator *files = [[NSFileManager defaultManager] enumeratorAtPath:path];
                    NSString *relative;
                    while ((relative = [files nextObject]) != nil) {
                        NSString *child = [path stringByAppendingPathComponent:relative];
                        BOOL childDirectory = NO;
                        if ([[NSFileManager defaultManager] fileExistsAtPath:child isDirectory:&childDirectory]
                            && !childDirectory) [paths addObject:child];
                    }
                } else [paths addObject:path];
            }
        }
        NSEnumerator *enumerator = [[[paths allObjects] sortedArrayUsingSelector:@selector(compare:)] objectEnumerator];
        NSString *path;
        while ((path = [enumerator nextObject]) != nil) {
            NSString *text = nil;
            NSEnumerator *documents = [[_editorController openDocuments] objectEnumerator];
            YCodeEditorDocument *document;
            while ((document = [documents nextObject]) != nil)
                if ([[document filePath] isEqual:path] && ![document isImageDocument]) text = [document content];
            NSStringEncoding encoding;
            if (!text) text = [NSString stringWithContentsOfFile:path usedEncoding:&encoding error:NULL];
            if (!text || [text rangeOfString:[NSString stringWithFormat:@"%C", (unichar)0]].location != NSNotFound) continue;
            NSString *displayPath = path;
            NSString *prefix = [[_project projectDirectoryPath] stringByAppendingString:@"/"];
            if ([path hasPrefix:prefix]) displayPath = [path substringFromIndex:[prefix length]];
            NSUInteger offset = 0, line = 1;
            while (offset < [text length]) {
                NSUInteger end, contentsEnd;
                [text getLineStart:NULL end:&end contentsEnd:&contentsEnd forRange:NSMakeRange(offset, 0)];
                NSRange remaining = NSMakeRange(offset, contentsEnd - offset);
                while (remaining.length) {
                    NSRange match = [text rangeOfString:query options:NSCaseInsensitiveSearch range:remaining];
                    if (match.location == NSNotFound) break;
                    [_searchResults addObject:[NSDictionary dictionaryWithObjectsAndKeys:
                        path, @"path", [NSValue valueWithRange:match], @"range",
                        [NSString stringWithFormat:@"%@:%lu\n%@", displayPath, (unsigned long)line,
                            [text substringWithRange:NSMakeRange(offset, contentsEnd - offset)]], @"display", nil]];
                    remaining = NSMakeRange(NSMaxRange(match), contentsEnd - NSMaxRange(match));
                }
                offset = end;
                line++;
            }
        }
    }
    [_searchResultsTable reloadData];
    [_searchStatus setStringValue:[NSString stringWithFormat:@"%lu matches", (unsigned long)[_searchResults count]]];
}

- (void)openSearchResult:(id)sender
{
    NSInteger row = [_searchResultsTable selectedRow];
    if (row < 0 || row >= (NSInteger)[_searchResults count]) return;
    NSDictionary *result = [_searchResults objectAtIndex:row];
    if (![_editorController openFile:[result objectForKey:@"path"]]) return;
    YCodeEditorDocument *document = [_editorController currentDocument];
    NSRange range = [[result objectForKey:@"range"] rangeValue];
    if (NSMaxRange(range) <= [[document content] length]) [document setSelectedRange:range];
    [[self window] makeFirstResponder:[document textView]];
}

- (IBAction)testProject:(id)sender
{
    if (!_project) { [_testStatus setStringValue:@"Open a project to run tests."]; return; }
    if ([[_project buildSystem] isBusy]) {
        [_testStatus setStringValue:@"Project is busy. Stop it first."];
        return;
    }
    if ([self prepareBuild]) [[_project buildSystem] test];
    else [_testStatus setStringValue:@"Tests cancelled. See console."];
}

- (void)buildSystemDidStartTests:(id)buildSystem
{
    [self refreshTargetSelectors];
    [_testResults removeAllObjects];
    [_testOutput setString:@""];
    [_testErrors setString:@""];
    [_testResultsTable reloadData];
    _collectingTests = YES;
    [_testStatus setStringValue:@"Running tests…"];
    [_navigatorTabView selectTabViewItemWithIdentifier:@"test"];
    [self setBottomPanelVisible:YES];
}

- (void)consumeTestOutput:(NSString *)output buffer:(NSMutableString *)buffer
{
    [buffer appendString:output];
    NSRange newline;
    while ((newline = [buffer rangeOfString:@"\n"]).location != NSNotFound) {
        NSString *line = [buffer substringToIndex:newline.location];
        [buffer deleteCharactersInRange:NSMakeRange(0, NSMaxRange(newline))];
        NSString *name = nil;
        NSString *status = nil;
        NSRange start = [line rangeOfString:@"Test Case '"];
        if (start.location != NSNotFound) {
            NSString *tail = [line substringFromIndex:NSMaxRange(start)];
            NSRange quote = [tail rangeOfString:@"'"];
            if (quote.location == NSNotFound) continue;
            name = [tail substringToIndex:quote.location];
            NSString *state = [tail substringFromIndex:NSMaxRange(quote)];
            if ([state rangeOfString:@"passed"].location != NSNotFound) status = @"Passed";
            else if ([state rangeOfString:@"failed"].location != NSNotFound) status = @"Failed";
            else if ([state rangeOfString:@"skipped"].location != NSNotFound) status = @"Skipped";
            else if ([state rangeOfString:@"started"].location != NSNotFound) status = @"Running";
        } else {
            start = [line rangeOfString:@"XCTest:"];
            if (start.location == NSNotFound) continue;
            NSString *tail = [[line substringFromIndex:NSMaxRange(start)]
                stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
            if ([tail hasSuffix:@" PASSED"]) status = @"Passed";
            else if ([tail hasSuffix:@" FAILED"]) status = @"Failed";
            if (status) name = [tail substringToIndex:[tail length] - 7];
        }
        if (!status) continue;
        NSDictionary *result = [NSDictionary dictionaryWithObjectsAndKeys:name, @"name", status, @"status",
            [NSString stringWithFormat:@"%@: %@", status, name], @"display", nil];
        NSUInteger index;
        for (index = 0; index < [_testResults count]; index++)
            if ([[[_testResults objectAtIndex:index] objectForKey:@"name"] isEqual:name]) break;
        if (index == [_testResults count]) [_testResults addObject:result];
        else [_testResults replaceObjectAtIndex:index withObject:result];
    }
    [_testResultsTable reloadData];
}

- (void)buildSystemDidFinishTests:(id)buildSystem success:(BOOL)success
{
    [self refreshTargetSelectors];
    [self consumeTestOutput:@"\n" buffer:_testOutput];
    [self consumeTestOutput:@"\n" buffer:_testErrors];
    _collectingTests = NO;
    NSUInteger passed = 0, failed = 0, skipped = 0;
    NSEnumerator *enumerator = [_testResults objectEnumerator];
    NSDictionary *result;
    while ((result = [enumerator nextObject]) != nil) {
        NSString *status = [result objectForKey:@"status"];
        if ([status isEqual:@"Passed"]) passed++;
        else if ([status isEqual:@"Failed"]) failed++;
        else if ([status isEqual:@"Skipped"]) skipped++;
    }
    NSString *summary = success
        ? [NSString stringWithFormat:@"%lu passed, %lu failed, %lu skipped",
            (unsigned long)passed, (unsigned long)failed, (unsigned long)skipped]
        : @"Tests failed. See console.";
    if (success && ![_testResults count]) summary = @"No XCTest results. See console.";
    if (!success && ![_testResults count]) {
        NSString *details = [[buildSystem buildErrors]
            stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
        if (![details length]) details = @"Build or test runner failed. See console for details.";
        [_testResults addObject:[NSDictionary dictionaryWithObjectsAndKeys:
            @"Test run", @"name", @"Failed", @"status",
            [@"Unable to run tests: " stringByAppendingString:details], @"display", nil]];
        [_testResultsTable reloadData];
    }
    [_testStatus setStringValue:summary];
    [_testStatus setToolTip:summary];
}

#pragma mark - Build Issues

- (void)sizeIssuesColumn:(NSNotification *)notification
{
    CGFloat width = [[_issuesTableView enclosingScrollView] contentSize].width;
    if (width <= 0) return;
    NSTableColumn *column = [[_issuesTableView tableColumns] objectAtIndex:0];
    if (fabs([column width] - MAX(80, width - 3)) > 0.5)
        [column setWidth:MAX(80, width - 3)];
}

- (void)tabView:(NSTabView *)tabView didSelectTabViewItem:(NSTabViewItem *)item
{
    if (tabView == _bottomTabView) [self sizeIssuesColumn:nil];
}


- (void)consumeDiagnostics:(NSString *)output buffer:(NSMutableString *)buffer
{
    NSUInteger previousCount = [_buildIssues count];
    [buffer appendString:output];
    NSRange newline;
    while ((newline = [buffer rangeOfString:@"\n"]).location != NSNotFound) {
        NSString *line = [buffer substringToIndex:newline.location];
        NSAttributedString *styled = [self decodeOutput:line
            stream:buffer == _diagnosticOutput ? @"issueOutput" : @"issueErrors"];
        NSString *plain = [styled string];
        NSCharacterSet *space = [NSCharacterSet whitespaceAndNewlineCharacterSet];
        NSUInteger first = 0, last = [plain length];
        while (first < last && [space characterIsMember:[plain characterAtIndex:first]]) first++;
        while (last > first && [space characterIsMember:[plain characterAtIndex:last - 1]]) last--;
        styled = [styled attributedSubstringFromRange:NSMakeRange(first, last - first)];
        plain = [styled string];
        NSUInteger count = [_buildIssues count];
        [self parseDiagnosticLine:plain];
        if ([_buildIssues count] > count) {
            NSMutableDictionary *issue = [[[_buildIssues lastObject] mutableCopy] autorelease];
            NSTextCheckingResult *match = [_diagnosticPattern firstMatchInString:plain
                options:0 range:NSMakeRange(0, [plain length])];
            NSUInteger severity = 4, message = 5;
            if (!match) {
                match = [_toolDiagnosticPattern firstMatchInString:plain
                    options:0 range:NSMakeRange(0, [plain length])];
                severity = 2; message = 3;
            }
            NSMutableAttributedString *display = AUTORELEASE([[NSMutableAttributedString alloc]
                initWithAttributedString:[styled attributedSubstringFromRange:[match rangeAtIndex:severity]]]);
            [display appendAttributedString:AUTORELEASE([[NSAttributedString alloc]
                initWithString:[@": " stringByAppendingString:[[issue objectForKey:@"location"] stringByAppendingString:@"\n"]]])];
            [display appendAttributedString:[styled attributedSubstringFromRange:[match rangeAtIndex:message]]];
            [YCodePreferences applyFont:[YCodePreferences fontForPane:@"Issues"] toText:display];
            [issue setObject:display forKey:@"display"];
            [_buildIssues replaceObjectAtIndex:count withObject:issue];
        }
        [buffer deleteCharactersInRange:NSMakeRange(0, NSMaxRange(newline))];
    }
    if (previousCount == [_buildIssues count]) return;
    [_issuesTableView reloadData];
    [[_bottomTabView tabViewItemAtIndex:1] setLabel:
        [NSString stringWithFormat:@"Issues (%lu)", (unsigned long)[_buildIssues count]]];
}

- (void)finishDiagnostics
{
    if (!_collectingBuildIssues) return;
    // stdout and stderr can each end with an unterminated diagnostic.
    [self consumeDiagnostics:@"\n" buffer:_diagnosticOutput];
    [self consumeDiagnostics:@"\n" buffer:_diagnosticErrors];
    _collectingBuildIssues = NO;
}

- (void)parseDiagnosticLine:(NSString *)line
{
    line = [line stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
    NSTextCheckingResult *directory = [_directoryPattern firstMatchInString:line
        options:0 range:NSMakeRange(0, [line length])];
    if (directory) {
        NSString *path = [line substringWithRange:[directory rangeAtIndex:2]];
        if ([[line substringWithRange:[directory rangeAtIndex:1]] isEqualToString:@"Entering"]) {
            if (![path isAbsolutePath]) {
                NSString *base = [_buildDirectories lastObject] ?: [_project projectDirectoryPath];
                path = [base stringByAppendingPathComponent:path];
            }
            [_buildDirectories addObject:[path stringByStandardizingPath]];
        } else if ([_buildDirectories count]) {
            [_buildDirectories removeLastObject];
        }
        return;
    }
    NSTextCheckingResult *match = [_diagnosticPattern firstMatchInString:line
        options:0 range:NSMakeRange(0, [line length])];
    if (!match) {
        NSTextCheckingResult *tool = [_toolDiagnosticPattern firstMatchInString:line
            options:0 range:NSMakeRange(0, [line length])];
        if (tool) {
            NSRange name = [tool rangeAtIndex:1];
            [_buildIssues addObject:[NSDictionary dictionaryWithObjectsAndKeys:
                [line substringWithRange:[tool rangeAtIndex:2]], @"severity",
                [line substringWithRange:[tool rangeAtIndex:3]], @"message",
                name.location == NSNotFound ? @"Build" : [line substringWithRange:name], @"location", nil]];
        }
        return;
    }
    NSString *path = [line substringWithRange:[match rangeAtIndex:1]];
    if (![path isAbsolutePath]) {
        NSString *base = [_buildDirectories lastObject] ?: [_project projectDirectoryPath];
        path = [base stringByAppendingPathComponent:path];
    }
    if (!path) return;
    path = [path stringByStandardizingPath];
    NSInteger lineNumber = [[line substringWithRange:[match rangeAtIndex:2]] integerValue];
    NSRange columnRange = [match rangeAtIndex:3];
    NSInteger column = columnRange.location == NSNotFound ? 0 :
        [[line substringWithRange:columnRange] integerValue];
    NSString *location = [NSString stringWithFormat:@"%@:%ld", [path lastPathComponent], (long)lineNumber];
    if (column > 0) location = [location stringByAppendingFormat:@":%ld", (long)column];
    NSDictionary *issue = [NSDictionary dictionaryWithObjectsAndKeys:
        path, @"path", [NSNumber numberWithInteger:lineNumber], @"line",
        [NSNumber numberWithInteger:column], @"column", location, @"location",
        [line substringWithRange:[match rangeAtIndex:4]], @"severity",
        [line substringWithRange:[match rangeAtIndex:5]], @"message", nil];
    [_buildIssues addObject:issue];
}

- (NSInteger)numberOfRowsInTableView:(NSTableView *)tableView
{
    if (tableView == _searchResultsTable) return [_searchResults count];
    if (tableView == _testResultsTable) return [_testResults count];
    return [_buildIssues count];
}

- (id)tableView:(NSTableView *)tableView objectValueForTableColumn:(NSTableColumn *)column row:(NSInteger)row
{
    if (tableView == _searchResultsTable || tableView == _testResultsTable) {
        NSArray *results = tableView == _searchResultsTable ? _searchResults : _testResults;
        if (row < 0 || row >= (NSInteger)[results count]) return nil;
        return [[results objectAtIndex:row] objectForKey:@"display"];
    }
    if (row < 0 || row >= (NSInteger)[_buildIssues count]) return nil;
    NSDictionary *issue = [_buildIssues objectAtIndex:row];
    return [issue objectForKey:@"display"];
}

- (NSString *)tableView:(NSTableView *)tableView toolTipForCell:(NSCell *)cell
                  rect:(NSRectPointer)rect tableColumn:(NSTableColumn *)column
                   row:(NSInteger)row mouseLocation:(NSPoint)point
{
    if (tableView == _searchResultsTable || tableView == _testResultsTable) {
        NSArray *results = tableView == _searchResultsTable ? _searchResults : _testResults;
        if (row < 0 || row >= (NSInteger)[results count]) return nil;
        return [[results objectAtIndex:row] objectForKey:@"display"];
    }
    if (row < 0 || row >= (NSInteger)[_buildIssues count]) return nil;
    NSDictionary *issue = [_buildIssues objectAtIndex:row];
    if (![issue objectForKey:@"path"]) return [issue objectForKey:@"message"];
    return [NSString stringWithFormat:@"%@:%@:%@\n%@", [issue objectForKey:@"path"],
        [issue objectForKey:@"line"], [issue objectForKey:@"column"], [issue objectForKey:@"message"]];
}

- (void)tableViewSelectionDidChange:(NSNotification *)notification
{
    if ([notification object] == _searchResultsTable) [self openSearchResult:nil];
    if ([notification object] == _issuesTableView) [self openBuildIssue:nil];
}

- (void)openBuildIssue:(id)sender
{
    NSInteger row = [_issuesTableView selectedRow];
    if (row < 0 || row >= (NSInteger)[_buildIssues count]) return;
    NSDictionary *issue = [_buildIssues objectAtIndex:row];
    NSString *path = [issue objectForKey:@"path"];
    if (!path) return;
    if (![_editorController openFile:path]) {
        [self appendConsoleOutput:[NSString stringWithFormat:@"Unable to open issue source: %@\n", path]];
        return;
    }
    YCodeEditorDocument *document = [_editorController currentDocument];
    NSString *text = [document content];
    NSUInteger index = 0, lineNumber = 1, end = 0, contentsEnd = 0;
    NSUInteger requestedLine = MAX(1, [[issue objectForKey:@"line"] integerValue]);
    while (index < [text length] && lineNumber < requestedLine) {
        [text getLineStart:NULL end:&end contentsEnd:NULL forRange:NSMakeRange(index, 0)];
        if (end <= index) break;
        index = end;
        lineNumber++;
    }
    [text getLineStart:NULL end:&end contentsEnd:&contentsEnd forRange:NSMakeRange(index, 0)];
    NSUInteger column = [[issue objectForKey:@"column"] unsignedIntegerValue];
    NSRange selection = NSMakeRange(index, contentsEnd - index);
    if (column > 0) {
        selection.location += MIN(column - 1, contentsEnd - index);
        selection.length = selection.location < contentsEnd ? 1 : 0;
    }
    [document setSelectedRange:selection];
    [[self window] makeFirstResponder:[document textView]];
}

#pragma mark - Controllers

- (YCodeProjectNavigatorController *)navigatorController
{
    return _navigatorController;
}

- (YCodeEditorController *)editorController
{
    return _editorController;
}

#pragma mark - NSToolbarDelegate

- (NSArray *)toolbarAllowedItemIdentifiers:(NSToolbar *)toolbar
{
    return [NSArray arrayWithObjects:@"build", @"run", @"debug", @"stop", @"pause", @"continue", @"next", @"stepInto", @"stepOut", @"restart", @"go", @"up", @"down", NSToolbarSeparatorItemIdentifier, @"scheme",
             @"navigator", @"inspector", NSToolbarFlexibleSpaceItemIdentifier, nil];
}

- (NSArray *)toolbarDefaultItemIdentifiers:(NSToolbar *)toolbar
{
    return [NSArray arrayWithObjects:@"build", @"run", @"debug", @"stop", @"pause", @"continue", @"next", NSToolbarSeparatorItemIdentifier, @"scheme",
             NSToolbarFlexibleSpaceItemIdentifier, @"navigator", @"inspector", nil];
}

- (NSToolbarItem *)toolbar:(NSToolbar *)toolbar itemForItemIdentifier:(NSString *)itemIdentifier willBeInsertedIntoToolbar:(BOOL)flag
{
    Class itemClass = [itemIdentifier isEqual:@"scheme"] ? [YCodeTargetToolbarItem class] : [NSToolbarItem class];
    NSToolbarItem *item = [[itemClass alloc] initWithItemIdentifier:itemIdentifier];
    
    NSArray *debugIdentifiers = [NSArray arrayWithObjects:@"go", @"pause", @"continue", @"restart", @"next", @"stepInto", @"stepOut", @"up", @"down", nil];
    NSUInteger debugIndex = [debugIdentifiers indexOfObject:itemIdentifier];
    if ([itemIdentifier isEqualToString:@"scheme"]) {
        NSPopUpButton *selector = AUTORELEASE([[NSPopUpButton alloc]
            initWithFrame:NSMakeRect(0, 0, 190, 26) pullsDown:NO]);
        [selector setTarget:self];
        [selector setAction:@selector(selectBuildTarget:)];
        [selector setToolTip:@"Target for Build, Run, Debug, and Tests"];
        [self populateTargetSelector:selector];
        [item setTarget:self];
        [item setAction:@selector(selectBuildTarget:)];
        [item setLabel:@"Target"];
        [item setPaletteLabel:@"Target"];
        [item setView:selector];
        [item setMinSize:NSMakeSize(140, 26)];
        [item setMaxSize:NSMakeSize(260, 26)];
    } else if (debugIndex != NSNotFound) {
        NSArray *labels = [NSArray arrayWithObjects:@"Go", @"Pause", @"Continue", @"Restart", @"Next", @"Step Into", @"Step Out", @"Up", @"Down", nil];
        [item setLabel:[labels objectAtIndex:debugIndex]];
        [item setPaletteLabel:[labels objectAtIndex:debugIndex]];
        [item setToolTip:[@"Debugger: " stringByAppendingString:[labels objectAtIndex:debugIndex]]];
        [item setTarget:self];
        [item setAction:@selector(debugAction:)];
        [item setTag:debugIndex];
        [item setImage:YCodeControlIcon(itemIdentifier, 24)];
    } else if ([itemIdentifier isEqualToString:@"debug"]) {
        [item setLabel:@"Debug"];
        [item setPaletteLabel:@"Debug"];
        [item setToolTip:@"Build and open the debugger"];
        [item setTarget:self];
        [item setAction:@selector(debugProject:)];
        [item setImage:YCodeControlIcon(@"debug", 24)];
    } else if ([itemIdentifier isEqualToString:@"build"]) {
        [item setLabel:@"Build"];
        [item setPaletteLabel:@"Build"];
        [item setToolTip:@"Build the current project without running it"];
        [item setTarget:self];
        [item setAction:@selector(buildProject:)];
        [item setImage:YCodeControlIcon(@"build", 24)];
    } else if ([itemIdentifier isEqualToString:@"run"]) {
        [item setLabel:@"Run"];
        [item setPaletteLabel:@"Run"];
        [item setToolTip:@"Build and run the current project"];
        [item setTarget:self];
        [item setAction:@selector(runProject:)];
        [item setImage:YCodeControlIcon(@"run", 24)];
    } else if ([itemIdentifier isEqualToString:@"stop"]) {
        [item setLabel:@"Stop"];
        [item setPaletteLabel:@"Stop"];
        [item setToolTip:@"Stop the running project"];
        [item setTarget:self];
        [item setAction:@selector(stopProject:)];
        [item setImage:YCodeControlIcon(@"stop", 24)];
    } else if ([itemIdentifier isEqualToString:@"navigator"]) {
        [item setLabel:@"Navigator"];
        [item setPaletteLabel:@"Navigator"];
        [item setToolTip:@"Toggle navigator visibility"];
        [item setTarget:self];
        [item setAction:@selector(toggleNavigator:)];
        [item setImage:YCodeControlIcon(@"navigator", 24)];
    } else if ([itemIdentifier isEqualToString:@"inspector"]) {
        [item setLabel:@"Inspector"];
        [item setPaletteLabel:@"Inspector"];
        [item setToolTip:@"Toggle inspector visibility"];
        [item setTarget:self];
        [item setAction:@selector(toggleInspector:)];
        [item setImage:YCodeControlIcon(@"inspector", 24)];
    }
    
    return AUTORELEASE(item);
}

@end
