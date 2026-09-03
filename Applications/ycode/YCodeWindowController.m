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
    RELEASE(_project);
    RELEASE(_navigatorController);
    RELEASE(_editorController);
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
    ASSIGN(_project, project);

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
        [_editorView addSubview:_bottomView];
        RELEASE(_bottomView);
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
        [_navigatorOutlineView setAutoresizingMask:NSViewWidthSizable | NSViewHeightSizable];
        [_navigatorOutlineView setHeaderView:nil];

        column = [[NSTableColumn alloc] initWithIdentifier:@"name"];
        [column setTitle:@"Project"];
        [column setWidth:NSWidth(outlineFrame)];
        [_navigatorOutlineView addTableColumn:column];
        [_navigatorOutlineView setOutlineTableColumn:column];
        RELEASE(column);

        scrollView = YCodeScrollViewWithDocumentView(_navigatorOutlineView);
        [scrollView setFrame:outlineFrame];
        [_navigatorView addSubview:scrollView];
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
    if (_editorTabView == nil) {
        NSRect tabFrame = [_editorView bounds];

        if (_bottomPanelVisible) {
            tabFrame.size.height -= NSHeight([_bottomView frame]);
            tabFrame.origin.y = NSHeight([_bottomView frame]);
        }

        _editorTabView = [[NSTabView alloc] initWithFrame:tabFrame];
        [_editorTabView setAutoresizingMask:NSViewWidthSizable | NSViewHeightSizable];
        [_editorView addSubview:_editorTabView];
        RELEASE(_editorTabView);
    }

    if (_editorTabView) {
        [_editorController setTabView:_editorTabView];
        [_editorTabView setDelegate:_editorController];
    }
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

    if (_issuesTextView == nil) {
        _issuesTextView = [[NSTextView alloc] initWithFrame:[_bottomView bounds]];
        [_issuesTextView setEditable:NO];
        [_issuesTextView setAutoresizingMask:NSViewWidthSizable | NSViewHeightSizable];
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
        if (_issuesTextView) {
            [issuesTab setView:YCodeScrollViewWithDocumentView(_issuesTextView)];
        }
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
    if (_bottomView) {
        [_bottomView setHidden:!visible];
        
        // Adjust layout
        if (visible) {
            [_bottomView setFrame:NSMakeRect(0, 0, NSWidth([_bottomView frame]), 200)];
        } else {
            [_bottomView setFrame:NSMakeRect(0, 0, NSWidth([_bottomView frame]), 0)];
        }
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
            // Show issues navigator
            break;
        case 3: // Test
            // Show test navigator
            break;
    }
}

- (IBAction)runProject:(id)sender
{
    if (_project) {
        [self setBottomPanelVisible:YES];
        
        // Switch to console tab
        if (_bottomTabView) {
            [_bottomTabView selectTabViewItemWithIdentifier:@"console"];
        }
        
        // Add console output
        if (_consoleTextView) {
            NSString *message = @"Running project...\n";
            [_consoleTextView insertText:message];
        }
        
        [_project runProject];
    }
}

- (IBAction)buildProject:(id)sender
{
    if (_project) {
        [self setBottomPanelVisible:YES];
        
        // Switch to console tab
        if (_bottomTabView) {
            [_bottomTabView selectTabViewItemWithIdentifier:@"console"];
        }
        
        // Add console output
        if (_consoleTextView) {
            NSString *message = @"Building project...\n";
            [_consoleTextView insertText:message];
        }
        
        [_project buildProject];
    }
}

- (IBAction)stopProject:(id)sender
{
    if (_consoleTextView) {
        NSString *message = @"Project stopped.\n";
        [_consoleTextView insertText:message];
    }
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
        [item setToolTip:@"Run the current scheme"];
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
