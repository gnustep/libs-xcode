/* 
   Project: Ycode

   Author: Gregory John Casamento,,,

   Created: 2017-08-15 03:31:31 -0400 by heron
   
   Application Controller
*/
 
#ifndef _PCAPPPROJ_APPCONTROLLER_H
#define _PCAPPPROJ_APPCONTROLLER_H

#import <AppKit/AppKit.h>

@class YCodeWindowController;
@class YCodeProject;

@interface AppController : NSObject
{
  YCodeWindowController *windowController;
  NSPanel *_preferencesPanel;
  NSMutableArray *_editorColorWells;
  NSPopUpButton *_preferencesGroup;
  NSView *_colorPreferencesView;
  NSView *_editorPreferencesView;
  NSButton *_showEditorRulers;
  NSPopUpButton *_matchingDelimitersChoice;
  NSView *_fontPreferencesView;
  NSView *_tabPreferencesView;
  NSPopUpButton *_tabWidthChoice;
  NSPopUpButton *_controlIndentChoice;
  NSButton *_spacesForTabs;
  NSButton *_projectIndentation;
  NSMutableArray *_fontChoices;
}

/**
 * Initializes the class.
 */
+ (void)  initialize;

/**
 * Initializes the controller.
 */
- (id) init;

/**
 * Deallocates the controller.
 */
- (void) dealloc;

/**
 * Called when the controller awakes from nib.
 */
- (void) awakeFromNib;

/**
 * Builds the application main menu without loading gorm resources.
 */
- (void) buildMainMenu;

/**
 * Called when the application finishes launching.
 */
- (void) applicationDidFinishLaunching: (NSNotification *)aNotif;
- (BOOL)applicationShouldOpenUntitledFile:(NSApplication *)application;

/**
 * Creates a new project.
 */
- (IBAction) newProject: (id)sender;

/**
 * Creates a new project in the specified directory, using its name.
 */
- (void) createNewProjectAtURL:(NSURL *)projectURL;

/**
 * Saves the active source file, or the project when no source file is open.
 */
- (IBAction) saveDocument: (id)sender;
- (IBAction) saveDocumentAs: (id)sender;
- (IBAction) saveDocumentTo: (id)sender;
- (IBAction) saveAllDocuments: (id)sender;
/** Saves project structure while keeping source-file Save independent. */
- (IBAction) saveProject: (id)sender;
- (IBAction) createProjectSettings: (id)sender;
- (IBAction) exportProjectCenter: (id)sender;

/**
 * Determines whether the application should terminate.
 */
- (NSApplicationTerminateReply) applicationShouldTerminate: (NSApplication *)sender;

/**
 * Called when the application will terminate.
 */
- (void) applicationWillTerminate: (NSNotification *)aNotif;

/**
 * Called when the application should open a file.
 */
- (BOOL) application: (NSApplication *)application
	    openFile: (NSString *)fileName;

/**
 * Shows the preferences panel.
 */
- (void) showPrefPanel: (id)sender;

/**
 * Opens a project.
 */
- (IBAction) openProject: (id)sender;

/**
 * Standard document menu entry points.
 */
- (IBAction) newDocument: (id)sender;
- (IBAction) openDocument: (id)sender;

/**
 * Project and view menu entry points.
 */
- (IBAction) buildProject: (id)sender;
- (IBAction) cleanProject: (id)sender;
- (IBAction) runProject: (id)sender;
- (IBAction) debugProject: (id)sender;
- (IBAction) debugAction: (id)sender;
- (IBAction) toggleBreakpoint: (id)sender;
- (IBAction) stopProject: (id)sender;
- (IBAction) toggleNavigator: (id)sender;
- (IBAction) toggleInspector: (id)sender;
- (IBAction) toggleBottomPanel: (id)sender;

@end

#endif
