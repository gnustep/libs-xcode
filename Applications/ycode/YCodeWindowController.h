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
#import "YCodeBuildSystem.h"

@class YCodeProject;
@class YCodeProjectNavigatorController;
@class YCodeEditorController;
@class YCTreeView;
@class YCEditorView;
@class YCInspectorView;
@class YCodeVariablesView;
@class YCodeTerminalView;

@interface YCodeWindowController
    : NSWindowController <YCodeBuildSystemDelegate>
{
  YCodeProject *_project;
  NSTimer *_buildStatusTimer;
  NSTimeInterval _buildStartedAt;
  NSTimeInterval _buildDuration;
  BOOL _hasBuildDuration;

  // Main interface elements
  IBOutlet NSToolbar *_toolbar;
  IBOutlet NSSplitView *_mainSplitView;
  IBOutlet NSSplitView *_contentSplitView;

  // Navigator area
  NSSearchField *_projectSearchField;
  NSTableView *_searchResultsTable;
  NSTableView *_testResultsTable;
  NSTextField *_searchStatus;
  NSTextField *_testStatus;
  NSMutableArray *_searchResults;
  NSMutableArray *_testResults;
  NSMutableString *_testOutput;
  NSMutableString *_testErrors;
  BOOL _collectingTests;
  IBOutlet NSView *_navigatorView;
  IBOutlet NSTabView *_navigatorTabView;
  IBOutlet YCTreeView *_treeView;
  IBOutlet NSOutlineView *_navigatorOutlineView;

  // Editor area
  IBOutlet NSView *_editorView;
  NSSplitView *_editorSplitView;
  CGFloat _buildPanelHeight;
  IBOutlet NSTabView *_editorTabView;
  IBOutlet YCEditorView *_editorTextView;

  // Inspector area
  IBOutlet NSView *_inspectorView;
  IBOutlet NSTabView *_inspectorTabView;
  IBOutlet YCInspectorView *_inspectorContentView;

  // Build results pane (console and navigable diagnostics)
  IBOutlet NSView *_bottomView;
  IBOutlet NSTabView *_bottomTabView;
  IBOutlet NSTextView *_consoleTextView;
  YCodeTerminalView *_terminalView;
  NSTextView *_debuggerTextView;
  NSTextField *_debuggerCommandField;
  NSView *_debuggerControls;
  YCodeVariablesView *_debuggerVariablesView;
  NSOutlineView *_issuesOutlineView;
  NSMutableArray *_issueGroups;
  NSMutableDictionary *_issueGroupsByPath;
  BOOL _updatingIssueOutline;
  NSMutableArray *_buildIssues;
  NSMutableString *_diagnosticOutput;
  NSMutableString *_diagnosticErrors;
  NSMutableArray *_buildDirectories;
  NSRegularExpression *_diagnosticPattern;
  NSMutableDictionary *_ansiDecoders;
  NSRegularExpression *_toolDiagnosticPattern;
  NSRegularExpression *_directoryPattern;
  BOOL _collectingBuildIssues;

  // Controllers
  YCodeProjectNavigatorController *_navigatorController;
  YCodeEditorController *_editorController;

  // State
  CGFloat _navigatorWidth;
  CGFloat _inspectorWidth;
  BOOL _restoringSidebars;
  BOOL _navigatorVisible;
  BOOL _inspectorVisible;
  BOOL _bottomPanelVisible;
}

/**
 * Project management
 */
- (YCodeProject *) project;
- (void) setProject: (YCodeProject *)project;
- (void) openProject: (NSString *)projectPath;
/** Toggle terminal visibility while preserving the shell session. */
- (IBAction) openTerminal: (id)sender;
- (BOOL) isTerminalVisible;
- (void) closeProject;

/**
 * Interface layout
 */
- (void) setupInterface;
- (void) setupToolbar;
- (void) setupNavigatorArea;
- (void) setupEditorArea;
- (void) setupInspectorArea;
- (void) setupBottomPanel;

/**
 * Panel visibility
 */
- (BOOL) isNavigatorVisible;
- (void) setNavigatorVisible: (BOOL)visible;
- (BOOL) isInspectorVisible;
- (void) setInspectorVisible: (BOOL)visible;
- (BOOL) isBottomPanelVisible;
- (void) setBottomPanelVisible: (BOOL)visible;

/**
 * Actions
 */
- (IBAction) toggleNavigator: (id)sender;
- (IBAction) toggleInspector: (id)sender;
- (IBAction) toggleBottomPanel: (id)sender;
/** Register an inspector once per identifier; subsequent calls are ignored. */
- (void) registerInspectorView: (YCInspectorView *)inspector;
- (IBAction) runProject: (id)sender;
- (BOOL) validateDebuggerAction: (SEL)action tag: (NSInteger)tag;
- (IBAction) debugProject: (id)sender;
- (IBAction) debugAction: (id)sender;
- (IBAction) toggleBreakpoint: (id)sender;
- (IBAction) debugConsoleCommand: (id)sender;
- (IBAction) searchProject: (id)sender;
- (IBAction) testProject: (id)sender;
- (IBAction) buildProject: (id)sender;
- (IBAction) cleanProject: (id)sender;
- (IBAction) stopProject: (id)sender;

/**
 * Controllers
 */
- (YCodeProjectNavigatorController *) navigatorController;
- (YCodeEditorController *) editorController;

@end

#endif // _YCODEWINDOWCONTROLLER_H_
