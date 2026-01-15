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
 * Called when the application finishes launching.
 */
- (void) applicationDidFinishLaunching: (NSNotification *)aNotif;

/**
 * Creates a new project.
 */
- (IBAction) newProject: (id)sender;

/**
 * Creates a new project at the specified URL.
 */
- (void) createNewProjectAtURL:(NSURL *)projectURL;

/**
 * Gets project name from user input.
 */
- (NSString *) getProjectNameFromUser;

/**
 * Determines whether the application should terminate.
 */
- (BOOL) applicationShouldTerminate: (id)sender;

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

@end

#endif
