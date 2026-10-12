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

#import "YCodeWindowController.h"
#import "YCodeProject.h"
#import "YCodeProjectNavigatorController.h"
#import "YCodeEditorController.h"
#import "YCodeEditorDocument.h"
#import "YCTreeView.h"
#import "YCEditorView.h"
#import "YCInspectorView.h"

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

@interface YCodeWindowController (BuildIssues)
- (void)appendConsoleOutput:(NSString *)output;
- (void)consumeDiagnostics:(NSString *)output buffer:(NSMutableString *)buffer;
- (void)finishDiagnostics;
- (void)parseDiagnosticLine:(NSString *)line;
- (void)openBuildIssue:(id)sender;
@end

@implementation YCodeWindowController

- (instancetype)init
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
        _navigatorVisible = YES;
        _inspectorVisible = YES;
        _bottomPanelVisible = NO;
        
        // Initialize controllers
        _navigatorController = [[YCodeProjectNavigatorController alloc] init];
        _editorController = [[YCodeEditorController alloc] init];

        [[self window] setTitle:@"Ycode"];
        [[self window] setMinSize:NSMakeSize(700, 420)];
        [self setupInterface];
    }
    return self;
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
    RELEASE(_bottomView);
    RELEASE(_buildIssues);
    RELEASE(_diagnosticOutput);
    RELEASE(_diagnosticErrors);
    RELEASE(_buildDirectories);
    RELEASE(_diagnosticPattern);
    RELEASE(_ansiPattern);
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
    }
}

- (void)setupNavigatorArea
{
    if (_navigatorSegmentControl == nil) {
        _navigatorSegmentControl = [[NSSegmentedControl alloc] initWithFrame:NSMakeRect(8, NSHeight([_navigatorView bounds]) - 32, 204, 24)];
        [_navigatorSegmentControl setAutoresizingMask:NSViewWidthSizable | NSViewMinYMargin];
        [_navigatorView addSubview:_navigatorSegmentControl];
        RELEASE(_navigatorSegmentControl);
    }

    if (_navigatorOutlineView == nil) {
        NSRect outlineFrame = NSMakeRect(0, 0, NSWidth([_navigatorView bounds]), NSHeight([_navigatorView bounds]) - 40);
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
        [_navigatorView addSubview:scrollView];
        [_navigatorOutlineView sizeToFit];
        RELEASE(_navigatorOutlineView);
    }

    if (_navigatorOutlineView) {
        [_navigatorController setOutlineView:_navigatorOutlineView];
        [_navigatorOutlineView setMenu:[_navigatorController contextMenu]];
    }
    
    if (_navigatorSegmentControl) {
        [_navigatorSegmentControl setTarget:self];
        [_navigatorSegmentControl setAction:@selector(selectNavigatorMode:)];
        [_navigatorSegmentControl setSegmentCount:4];
        [_navigatorSegmentControl setLabel:@"Project" forSegment:0];
        [_navigatorSegmentControl setLabel:@"Search" forSegment:1];
        [_navigatorSegmentControl setLabel:@"Issues" forSegment:2];
        [_navigatorSegmentControl setLabel:@"Test" forSegment:3];
        [_navigatorSegmentControl setSelectedSegment:0];
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
        _editorTabView = [[NSTabView alloc] initWithFrame:[_editorSplitView bounds]];
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

    if (_inspectorTabView) {
        [_inspectorTabView setDelegate:self];
        
        // Add inspector tabs
        NSTabViewItem *fileInspectorTab = [[NSTabViewItem alloc] initWithIdentifier:@"file"];
        [fileInspectorTab setLabel:@"File"];
        [_inspectorTabView addTabViewItem:fileInspectorTab];
        RELEASE(fileInspectorTab);
        
        NSTabViewItem *quickHelpTab = [[NSTabViewItem alloc] initWithIdentifier:@"quickhelp"];
        [quickHelpTab setLabel:@"Quick Help"];
        [_inspectorTabView addTabViewItem:quickHelpTab];
        RELEASE(quickHelpTab);
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
        _ansiPattern = [[NSRegularExpression alloc] initWithPattern:@"\033\\[[0-?]*[ -/]*[@-~]"
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
        if (_consoleTextView) {
            [consoleTab setView:YCodeScrollViewWithDocumentView(_consoleTextView)];
        }
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
    }
}

#pragma mark - Panel Visibility

- (BOOL)isNavigatorVisible
{
    return _navigatorVisible;
}

- (void)setNavigatorVisible:(BOOL)visible
{
    _navigatorVisible = visible;
    if (_navigatorView) {
        [_navigatorView setHidden:!visible];
        
        // Adjust split view
        if (_mainSplitView && [_mainSplitView subviews].count > 0) {
            NSView *firstSubview = [[_mainSplitView subviews] objectAtIndex:0];
            if (visible) {
                [firstSubview setFrame:NSMakeRect(0, 0, 250, NSHeight([firstSubview frame]))]; 
            } else {
                [firstSubview setFrame:NSMakeRect(0, 0, 0, NSHeight([firstSubview frame]))];
            }
            [_mainSplitView adjustSubviews];
        }
    }
}

- (BOOL)isInspectorVisible
{
    return _inspectorVisible;
}

- (void)setInspectorVisible:(BOOL)visible
{
    _inspectorVisible = visible;
    if (_inspectorView) {
        [_inspectorView setHidden:!visible];
        
        // Adjust split view
        if (_contentSplitView && [_contentSplitView subviews].count > 1) {
            NSView *lastSubview = [[_contentSplitView subviews] lastObject];
            if (visible) {
                [lastSubview setFrame:NSMakeRect(0, 0, 250, NSHeight([lastSubview frame]))]; 
            } else {
                [lastSubview setFrame:NSMakeRect(0, 0, 0, NSHeight([lastSubview frame]))];
            }
            [_contentSplitView adjustSubviews];
        }
    }
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

- (IBAction)selectNavigatorMode:(id)sender
{
    NSInteger selectedSegment = [_navigatorSegmentControl selectedSegment];
    
    switch (selectedSegment) {
        case 0: // Project
            // Show project navigator
            break;
        case 1: // Search
            // Show search navigator
            break;
        case 2: // Issues
            [self setBottomPanelVisible:YES];
            [_bottomTabView selectTabViewItemWithIdentifier:@"issues"];
            break;
        case 3: // Test
            // Show test navigator
            break;
    }
}

- (void)appendConsoleOutput:(NSString *)output
{
    if (!_consoleTextView || !output) return;
    NSTextStorage *storage = [_consoleTextView textStorage];
    NSAttributedString *text = [[NSAttributedString alloc] initWithString:output];
    [storage appendAttributedString:text];
    RELEASE(text);
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
    if ([item action] == @selector(stopProject:))
        return [[_project buildSystem] isBusy];
    if ([item action] == @selector(runProject:) || [item action] == @selector(buildProject:))
        return _project != nil && ![[_project buildSystem] isBusy];
    return YES;
}

- (void)buildSystemDidStartBuild:(id)buildSystem
{
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
    [self finishDiagnostics];
    [self appendConsoleOutput:success ? @"Build succeeded.\n" : @"Build failed.\n"];
    [self setBottomPanelVisible:YES];
    if ([_buildIssues count] > 0)
        [_bottomTabView selectTabViewItemWithIdentifier:@"issues"];
}

- (void)buildSystemDidStartRun:(id)buildSystem
{
    [self appendConsoleOutput:@"Running project...\n"];
}

- (void)buildSystemDidFinishRun:(id)buildSystem
{
    [self appendConsoleOutput:[(YCodeBuildSystem *)buildSystem status] == YCodeBuildStatusFailed
        ? @"Run failed.\n" : @"Project exited.\n"];
}

- (void)buildSystemDidCancel:(id)buildSystem
{
    [self finishDiagnostics];
    [self appendConsoleOutput:@"Project stopped.\n"];
}

- (void)buildSystem:(id)buildSystem didReceiveOutput:(NSString *)output
{
    [self appendConsoleOutput:output];
    if (_collectingBuildIssues) [self consumeDiagnostics:output buffer:_diagnosticOutput];
}

- (void)buildSystem:(id)buildSystem didReceiveError:(NSString *)error
{
    [self appendConsoleOutput:error];
    if (_collectingBuildIssues) [self consumeDiagnostics:error buffer:_diagnosticErrors];
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
        [self parseDiagnosticLine:line];
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
    line = [_ansiPattern stringByReplacingMatchesInString:line options:0
        range:NSMakeRange(0, [line length]) withTemplate:@""];
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
    return [_buildIssues count];
}

- (id)tableView:(NSTableView *)tableView objectValueForTableColumn:(NSTableColumn *)column row:(NSInteger)row
{
    if (row < 0 || row >= (NSInteger)[_buildIssues count]) return nil;
    NSDictionary *issue = [_buildIssues objectAtIndex:row];
    return [NSString stringWithFormat:@"%@: %@\n%@", [issue objectForKey:@"severity"],
        [issue objectForKey:@"location"], [issue objectForKey:@"message"]];
}

- (NSString *)tableView:(NSTableView *)tableView toolTipForCell:(NSCell *)cell
                  rect:(NSRectPointer)rect tableColumn:(NSTableColumn *)column
                   row:(NSInteger)row mouseLocation:(NSPoint)point
{
    if (row < 0 || row >= (NSInteger)[_buildIssues count]) return nil;
    NSDictionary *issue = [_buildIssues objectAtIndex:row];
    if (![issue objectForKey:@"path"]) return [issue objectForKey:@"message"];
    return [NSString stringWithFormat:@"%@:%@:%@\n%@", [issue objectForKey:@"path"],
        [issue objectForKey:@"line"], [issue objectForKey:@"column"], [issue objectForKey:@"message"]];
}

- (void)tableViewSelectionDidChange:(NSNotification *)notification
{
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
    return @[@"run", @"stop", @"scheme", NSToolbarSeparatorItemIdentifier,
             @"navigator", @"inspector", NSToolbarFlexibleSpaceItemIdentifier];
}

- (NSArray *)toolbarDefaultItemIdentifiers:(NSToolbar *)toolbar
{
    return @[@"run", @"stop", @"scheme", NSToolbarSeparatorItemIdentifier,
             NSToolbarFlexibleSpaceItemIdentifier, @"navigator", @"inspector"];
}

- (NSToolbarItem *)toolbar:(NSToolbar *)toolbar itemForItemIdentifier:(NSString *)itemIdentifier willBeInsertedIntoToolbar:(BOOL)flag
{
    NSToolbarItem *item = [[NSToolbarItem alloc] initWithItemIdentifier:itemIdentifier];
    
    if ([itemIdentifier isEqualToString:@"run"]) {
        [item setLabel:@"Run"];
        [item setPaletteLabel:@"Run"];
        [item setToolTip:@"Build and run the current project"];
        [item setTarget:self];
        [item setAction:@selector(runProject:)];
        [item setImage:[NSImage imageNamed:@"play"]];
    } else if ([itemIdentifier isEqualToString:@"stop"]) {
        [item setLabel:@"Stop"];
        [item setPaletteLabel:@"Stop"];
        [item setToolTip:@"Stop the running project"];
        [item setTarget:self];
        [item setAction:@selector(stopProject:)];
        [item setImage:[NSImage imageNamed:@"stop"]];
    } else if ([itemIdentifier isEqualToString:@"navigator"]) {
        [item setLabel:@"Navigator"];
        [item setPaletteLabel:@"Navigator"];
        [item setToolTip:@"Toggle navigator visibility"];
        [item setTarget:self];
        [item setAction:@selector(toggleNavigator:)];
        [item setImage:[NSImage imageNamed:@"navigator"]];
    } else if ([itemIdentifier isEqualToString:@"inspector"]) {
        [item setLabel:@"Inspector"];
        [item setPaletteLabel:@"Inspector"];
        [item setToolTip:@"Toggle inspector visibility"];
        [item setTarget:self];
        [item setAction:@selector(toggleInspector:)];
        [item setImage:[NSImage imageNamed:@"inspector"]];
    }
    
    return AUTORELEASE(item);
}

@end
