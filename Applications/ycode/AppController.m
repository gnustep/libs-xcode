/* 
   Project: Ycode

   Author: Gregory John Casamento,,,

   Created: 2017-08-15 03:31:31 -0400 by heron
   
   Application Controller
*/

#import "AppController.h"
#import "YCodeWindowController.h"

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
