/*
   Project: Ycode

   Copyright (C) 2023 Free Software Foundation

   Author: Gregory John Casamento,,,

   Created: 2023-11-01 11:42:13 -0400 by heron

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

#ifndef _YCODEWINDOWCONTROLLER_H_
#define _YCODEWINDOWCONTROLLER_H_

#import <Foundation/Foundation.h>
#import <AppKit/AppKit.h>

@class YCodeProject;
@class YCodeProjectNavigatorController;
@class YCodeEditorController;
@class YCTreeView;
@class YCEditorView;
@class YCInspectorView;

@interface YCodeWindowController : NSWindowController
{
    YCodeProject *_project;
    
    // Main interface elements
    IBOutlet NSToolbar *_toolbar;
    IBOutlet NSSplitView *_mainSplitView;
    IBOutlet NSSplitView *_contentSplitView;
    
    // Navigator area
    IBOutlet NSView *_navigatorView;
    IBOutlet NSSegmentedControl *_navigatorSegmentControl;
    IBOutlet YCTreeView *_treeView;
    IBOutlet NSOutlineView *_navigatorOutlineView;
    
    // Editor area
    IBOutlet NSView *_editorView;
    IBOutlet NSTabView *_editorTabView;
    IBOutlet YCEditorView *_editorTextView;
    
    // Inspector area
    IBOutlet NSView *_inspectorView;
    IBOutlet NSTabView *_inspectorTabView;
    IBOutlet YCInspectorView *_inspectorContentView;
    
    // Bottom panel (console, issues, etc.)
    IBOutlet NSView *_bottomView;
    IBOutlet NSTabView *_bottomTabView;
    IBOutlet NSTextView *_consoleTextView;
    IBOutlet NSTextView *_issuesTextView;
    
    // Controllers
    YCodeProjectNavigatorController *_navigatorController;
    YCodeEditorController *_editorController;
    
    // State
    BOOL _navigatorVisible;
    BOOL _inspectorVisible;
    BOOL _bottomPanelVisible;
}

/**
 * Project management
 */
- (YCodeProject *)project;
- (void)setProject:(YCodeProject *)project;
- (void)openProject:(NSString *)projectPath;
- (void)closeProject;

/**
 * Interface layout
 */
- (void)setupInterface;
- (void)setupToolbar;
- (void)setupNavigatorArea;
- (void)setupEditorArea;
- (void)setupInspectorArea;
- (void)setupBottomPanel;

/**
 * Panel visibility
 */
- (BOOL)isNavigatorVisible;
- (void)setNavigatorVisible:(BOOL)visible;
- (BOOL)isInspectorVisible;
- (void)setInspectorVisible:(BOOL)visible;
- (BOOL)isBottomPanelVisible;
- (void)setBottomPanelVisible:(BOOL)visible;

/**
 * Actions
 */
- (IBAction)toggleNavigator:(id)sender;
- (IBAction)toggleInspector:(id)sender;
- (IBAction)toggleBottomPanel:(id)sender;
- (IBAction)selectNavigatorMode:(id)sender;
- (IBAction)runProject:(id)sender;
- (IBAction)buildProject:(id)sender;
- (IBAction)stopProject:(id)sender;

/**
 * Controllers
 */
- (YCodeProjectNavigatorController *)navigatorController;
- (YCodeEditorController *)editorController;

@end

#endif // _YCODEWINDOWCONTROLLER_H_

