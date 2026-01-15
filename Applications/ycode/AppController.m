/* 
   Project: Ycode

   Author: Gregory John Casamento,,,

   Created: 2017-08-15 03:31:31 -0400 by heron
   
   Application Controller
*/

#import "AppController.h"
#import "YCodeWindowController.h"
#import "YCodeProject.h"

@implementation AppController

+ (void) initialize
{
  NSMutableDictionary *defaults = [NSMutableDictionary dictionary];

  /*
   * Register your app's defaults here by adding objects to the
   * dictionary, eg
   *
   * [defaults setObject:anObject forKey:keyForThatObject];
   *
   */
  
  [[NSUserDefaults standardUserDefaults] registerDefaults: defaults];
  [[NSUserDefaults standardUserDefaults] synchronize];
}

- (id) init
{
  if ((self = [super init]))
    {
    }
  return self;
}

- (void) dealloc
{
  [super dealloc];
}

- (void) awakeFromNib
{
}

- (void) applicationDidFinishLaunching: (NSNotification *)aNotif
{
    // Create and show the main window
    if (!windowController) {
        windowController = [[YCodeWindowController alloc] init];
    }
    
    [windowController showWindow:self];
    [[windowController window] makeKeyAndOrderFront:self];
}

- (BOOL) applicationShouldTerminate: (id)sender
{
    // Check if there are unsaved changes in open projects
    if (windowController && [windowController project]) {
        // TODO: Check for unsaved changes
        NSAlert *alert = [[NSAlert alloc] init];
        [alert setMessageText:@"Do you want to save your changes before closing?"];
        [alert addButtonWithTitle:@"Save"];
        [alert addButtonWithTitle:@"Don't Save"];
        [alert addButtonWithTitle:@"Cancel"];
        
        NSInteger result = [alert runModal];
        RELEASE(alert);
        
        if (result == NSAlertThirdButtonReturn) {
            return NO; // Cancel
        } else if (result == NSAlertFirstButtonReturn) {
            // Save before quitting
            // TODO: Implement save functionality
        }
    }
    
    return YES;
}

- (void) applicationWillTerminate: (NSNotification *)aNotif
{
    // Clean up
    if (windowController) {
        [windowController closeProject];
    }
}

- (IBAction) newProject: (id)sender
{
    // Show new project dialog
    NSOpenPanel *panel = [NSOpenPanel openPanel];
    [panel setCanChooseDirectories:YES];
    [panel setCanChooseFiles:NO];
    [panel setCanCreateDirectories:YES];
    [panel setAllowsMultipleSelection:NO];
    [panel setTitle:@"Create New Project"];
    [panel setPrompt:@"Create"];
    [panel setMessage:@"Choose location for new project:"];
    
    NSInteger result = [panel runModal];
    if (result == NSModalResponseOK) {
        NSURL *selectedURL = [[panel URLs] firstObject];
        if (selectedURL) {
            [self createNewProjectAtURL:selectedURL];
        }
    }
}

- (void) createNewProjectAtURL:(NSURL *)projectURL
{
    // Show project type selection dialog
    NSAlert *alert = [[NSAlert alloc] init];
    [alert setMessageText:@"Choose Project Type"];
    [alert setInformativeText:@"Select the type of project you want to create:"];
    [alert addButtonWithTitle:@"Xcode Project"];
    [alert addButtonWithTitle:@"ProjectCenter Project"];
    [alert addButtonWithTitle:@"Cancel"];
    
    NSInteger choice = [alert runModal];
    RELEASE(alert);
    
    if (choice == NSAlertThirdButtonReturn) {
        return; // Cancel
    }
    
    // Get project name
    NSString *projectName = [self getProjectNameFromUser];
    if (!projectName || [projectName length] == 0) {
        return;
    }
    
    BOOL isXcodeProject = (choice == NSAlertFirstButtonReturn);
    NSString *projectPath = [[projectURL path] stringByAppendingPathComponent:projectName];
    
    // Create the project
    YCodeProject *newProject = [YCodeProject createNewProjectAtPath:projectPath 
                                                               name:projectName 
                                                               type:isXcodeProject ? @"Xcode" : @"ProjectCenter"];
    
    if (newProject) {
        // Open the new project
        if (!windowController) {
            windowController = [[YCodeWindowController alloc] init];
        }
        [windowController setProject:newProject];
        [windowController showWindow:self];
        
        // Save the project immediately
        [newProject saveProjectToPath:projectPath];
    } else {
        NSAlert *errorAlert = [[NSAlert alloc] init];
        [errorAlert setMessageText:@"Project Creation Failed"];
        [errorAlert setInformativeText:@"Could not create the new project. Please check the selected location and try again."];
        [errorAlert addButtonWithTitle:@"OK"];
        [errorAlert runModal];
        RELEASE(errorAlert);
    }
}

- (NSString *) getProjectNameFromUser
{
    NSAlert *alert = [[NSAlert alloc] init];
    [alert setMessageText:@"Project Name"];
    [alert setInformativeText:@"Enter a name for your new project:"];
    [alert addButtonWithTitle:@"Create"];
    [alert addButtonWithTitle:@"Cancel"];
    
    NSTextField *input = [[NSTextField alloc] initWithFrame:NSMakeRect(0, 0, 200, 24)];
    [input setStringValue:@"MyProject"];
    [alert setAccessoryView:input];
    
    NSInteger result = [alert runModal];
    NSString *projectName = nil;
    
    if (result == NSAlertFirstButtonReturn) {
        projectName = [input stringValue];
    }
    
    RELEASE(input);
    RELEASE(alert);
    
    return projectName;
}

- (BOOL) application: (NSApplication *)application
	    openFile: (NSString *)fileName
{
    if (!windowController) {
        windowController = [[YCodeWindowController alloc] init];
        [windowController showWindow:self];
    }
    
    // Check if it's a project file
    NSString *extension = [fileName pathExtension];
    if ([extension isEqualToString:@"xcodeproj"] || [extension isEqualToString:@"pcproj"]) {
        [windowController openProject:fileName];
        return YES;
    }
    
    return NO;
}

- (void) showPrefPanel: (id)sender
{
    // TODO: Implement preferences panel
    NSAlert *alert = [[NSAlert alloc] init];
    [alert setMessageText:@"Preferences"];
    [alert setInformativeText:@"Preferences panel not yet implemented"];
    [alert runModal];
    RELEASE(alert);
}

- (IBAction) openProject: (id)sender
{
    NSOpenPanel *openPanel = [NSOpenPanel openPanel];
    [openPanel setCanChooseFiles:YES];
    [openPanel setCanChooseDirectories:YES];
    [openPanel setAllowsMultipleSelection:NO];
    [openPanel setAllowedFileTypes:@[@"xcodeproj", @"pcproj"]];
    [openPanel setMessage:@"Choose a project to open"];
    
    if ([openPanel runModal] == NSModalResponseOK) {
        NSString *projectPath = [[openPanel URL] path];
        
        if (!windowController) {
            windowController = [[YCodeWindowController alloc] init];
            [windowController showWindow:self];
        }
        
        [windowController openProject:projectPath];
    }
}

@end
