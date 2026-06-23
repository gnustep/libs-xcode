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
    [self updateApplicationMenuName];
    [self connectDocumentMenuActions];
}

- (void) applicationDidFinishLaunching: (NSNotification *)aNotif
{
    [self updateApplicationMenuName];
    [self connectDocumentMenuActions];

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
            if (![self saveActiveProjectShowingPanel:NO]) {
                return NO;
            }
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

- (IBAction)newDocument:(id)sender
{
    [self newProject:sender];
}

- (IBAction)openDocument:(id)sender
{
    [self openProject:sender];
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
        
        [[NSDocumentController sharedDocumentController] addDocument:newProject];
    } else {
        NSAlert *errorAlert = [[NSAlert alloc] init];
        [errorAlert setMessageText:@"Project Creation Failed"];
        [errorAlert setInformativeText:@"Could not create the new project. Please check the selected location and try again."];
        [errorAlert addButtonWithTitle:@"OK"];
        [errorAlert runModal];
        RELEASE(errorAlert);
    }
}

- (IBAction)saveDocument:(id)sender
{
    [self saveActiveProjectShowingPanel:NO];
}

- (IBAction)saveDocumentAs:(id)sender
{
    [self saveActiveProjectShowingPanel:YES];
}

- (IBAction)saveDocumentTo:(id)sender
{
    [self saveActiveProjectShowingPanel:YES];
}

- (IBAction)saveAllDocuments:(id)sender
{
    [self saveActiveProjectShowingPanel:NO];
}

- (BOOL)saveActiveProjectShowingPanel:(BOOL)showPanel
{
    YCodeProject *project = [windowController project];
    NSString *projectPath = [project projectPath];

    if (project == nil) {
        NSBeep();
        return NO;
    }

    if (showPanel || projectPath == nil || [projectPath length] == 0) {
        NSSavePanel *panel = [NSSavePanel savePanel];
        NSString *name = @"Project.xcodeproj";

        if (projectPath != nil && [projectPath length] > 0) {
            name = [projectPath lastPathComponent];
        }

        [panel setTitle:@"Save Project"];
        [panel setNameFieldStringValue:name];
        [panel setAllowedFileTypes:[NSArray arrayWithObject:@"xcodeproj"]];

        if ([panel runModal] != NSModalResponseOK) {
            return NO;
        }

        projectPath = [[panel URL] path];
    }

    if (![project saveProjectToPath:projectPath]) {
        NSAlert *alert = [[NSAlert alloc] init];
        [alert setMessageText:@"Unable to save project"];
        [alert setInformativeText:@"The project could not be saved to the selected location."];
        [alert addButtonWithTitle:@"OK"];
        [alert runModal];
        RELEASE(alert);
        return NO;
    }

    [[windowController window] setTitle:[[project projectPath] lastPathComponent]];
    return YES;
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
    
    // GNUstep compatibility: Try setAccessoryView, fallback if not available
    if ([alert respondsToSelector:@selector(setAccessoryView:)]) {
        if ([alert respondsToSelector:@selector(setAccessoryView:)]) {
            [alert setAccessoryView:input];
        }
    }
    
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

- (void)updateApplicationMenuName
{
    NSString *applicationName = [[[NSBundle mainBundle] infoDictionary] objectForKey:@"ApplicationName"];
    NSMenu *mainMenu = [NSApp mainMenu];
    NSMenuItem *applicationItem = nil;
    NSMenu *applicationMenu = nil;

    if (applicationName == nil || [applicationName length] == 0) {
        applicationName = [[NSProcessInfo processInfo] processName];
    }

    if (mainMenu == nil || [[mainMenu itemArray] count] == 0) {
        return;
    }

    applicationItem = [[mainMenu itemArray] objectAtIndex:0];
    applicationMenu = [applicationItem submenu];

    [applicationItem setTitle:applicationName];
    if (applicationMenu != nil) {
        NSMenuItem *infoItem = nil;

        [applicationMenu setTitle:applicationName];
        if ([[applicationMenu itemArray] count] > 0) {
            infoItem = [[applicationMenu itemArray] objectAtIndex:0];
            if ([[infoItem title] isEqualToString:@"Info"]) {
                [infoItem setTitle:applicationName];
                [[infoItem submenu] setTitle:applicationName];
            }
        }

        [self updateApplicationNameItemsInMenu:applicationMenu
                                      appName:applicationName];
    }
}

- (void)updateApplicationNameItemsInMenu:(NSMenu *)menu appName:(NSString *)applicationName
{
    NSEnumerator *enumerator = nil;
    NSMenuItem *item = nil;

    if (menu == nil) {
        return;
    }

    enumerator = [[menu itemArray] objectEnumerator];
    while ((item = [enumerator nextObject]) != nil) {
        if ([[item title] isEqualToString:@"Hide"]) {
            [item setTitle:[NSString stringWithFormat:@"Hide %@", applicationName]];
        } else if ([[item title] isEqualToString:@"Quit"]) {
            [item setTitle:[NSString stringWithFormat:@"Quit %@", applicationName]];
        }

        [self updateApplicationNameItemsInMenu:[item submenu]
                                      appName:applicationName];
    }
}

- (void)connectDocumentMenuActions
{
    NSMenu *mainMenu = [NSApp mainMenu];
    NSEnumerator *enumerator = nil;
    NSMenuItem *item = nil;

    if (mainMenu == nil) {
        return;
    }

    enumerator = [[mainMenu itemArray] objectEnumerator];
    while ((item = [enumerator nextObject]) != nil) {
        [self connectDocumentMenuActionsInMenu:[item submenu]];
    }
}

- (void)connectDocumentMenuActionsInMenu:(NSMenu *)menu
{
    NSEnumerator *enumerator = nil;
    NSMenuItem *item = nil;

    if (menu == nil) {
        return;
    }

    enumerator = [[menu itemArray] objectEnumerator];
    while ((item = [enumerator nextObject]) != nil) {
        SEL action = [item action];

        if (action == @selector(newDocument:)) {
            [item setTarget:self];
            [item setAction:@selector(newProject:)];
        } else if (action == @selector(openDocument:)) {
            [item setTarget:self];
            [item setAction:@selector(openProject:)];
        } else if (action == @selector(saveDocument:) ||
                   action == @selector(saveDocumentAs:) ||
                   action == @selector(saveDocumentTo:) ||
                   action == @selector(saveAllDocuments:)) {
            [item setTarget:self];
        }

        [self connectDocumentMenuActionsInMenu:[item submenu]];
    }
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
