/* 
   Project: Ycode

   Author: Gregory John Casamento,,,

   Created: 2017-08-15 03:31:31 -0400 by heron
   
   Application Controller
*/

#import "YCodeControlIcons.h"
#import "AppController.h"
#import "YCodeWindowController.h"
#import "YCodeDocumentController.h"
#import "YCodeProject.h"
#import "YCodeEditorController.h"
#import "YCodeEditorDocument.h"

static NSMenuItem *
YCodeMenuItem(NSString *title, SEL action, NSString *keyEquivalent, id target)
{
    NSMenuItem *item = [[NSMenuItem alloc] initWithTitle:title
                                                  action:action
                                           keyEquivalent:keyEquivalent];
    [item setTarget:target];
    return AUTORELEASE(item);
}

static NSURL *
YCodeFileURLFromPath(NSString *path)
{
    if (path == nil || [path length] == 0) {
        return nil;
    }

    return [NSURL fileURLWithPath:path];
}

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
    [self buildMainMenu];
    [self updateApplicationMenuName];
    [self connectDocumentMenuActions];
}

- (void) applicationDidFinishLaunching: (NSNotification *)aNotif
{
    [self buildMainMenu];
    [self updateApplicationMenuName];
    [self connectDocumentMenuActions];
}

- (BOOL)applicationShouldOpenUntitledFile:(NSApplication *)application
{
    return NO;
}

- (void)buildMainMenu
{
    NSString *applicationName = [[[NSBundle mainBundle] infoDictionary] objectForKey:@"ApplicationName"];
    NSMenu *mainMenu = nil;
    NSMenu *appMenu = nil;
    NSMenu *fileMenu = nil;
    NSMenu *editMenu = nil;
    NSMenu *viewMenu = nil;
    NSMenu *productMenu = nil;
    NSMenu *windowMenu = nil;
    NSMenu *helpMenu = nil;
    NSMenuItem *menuItem = nil;
#ifdef GNUSTEP
    NSString *projectMenuTitle = @"Project";
    NSString *windowMenuTitle = @"Windows";
#else
    NSString *projectMenuTitle = @"Product";
    NSString *windowMenuTitle = @"Window";
#endif

    if ([NSApp mainMenu] != nil) {
        return;
    }

    if (applicationName == nil || [applicationName length] == 0) {
        applicationName = [[NSProcessInfo processInfo] processName];
    }

    mainMenu = [[NSMenu alloc] initWithTitle:applicationName];

#ifdef GNUSTEP
    appMenu = [[NSMenu alloc] initWithTitle:@"Info"];
#else
    appMenu = [[NSMenu alloc] initWithTitle:applicationName];
#endif
    [appMenu addItem:YCodeMenuItem([NSString stringWithFormat:@"About %@", applicationName],
                                   @selector(orderFrontStandardAboutPanel:), @"", NSApp)];
    [appMenu addItem:[NSMenuItem separatorItem]];
    [appMenu addItem:YCodeMenuItem(@"Preferences...", @selector(showPrefPanel:), @",", self)];
#ifdef GNUSTEP
    [appMenu addItem:YCodeMenuItem(@"Help", @selector(showHelp:), @"?", NSApp)];
    menuItem = [[NSMenuItem alloc] initWithTitle:@"Info" action:NULL keyEquivalent:@""];
#else
    [appMenu addItem:[NSMenuItem separatorItem]];
    [appMenu addItem:YCodeMenuItem([NSString stringWithFormat:@"Hide %@", applicationName],
                                   @selector(hide:), @"h", NSApp)];
    [appMenu addItem:YCodeMenuItem(@"Hide Others", @selector(hideOtherApplications:), @"h", NSApp)];
    [[appMenu itemAtIndex:[appMenu numberOfItems] - 1]
        setKeyEquivalentModifierMask:NSCommandKeyMask | NSAlternateKeyMask];
    [appMenu addItem:YCodeMenuItem(@"Show All", @selector(unhideAllApplications:), @"", NSApp)];
    [appMenu addItem:[NSMenuItem separatorItem]];
    [appMenu addItem:YCodeMenuItem([NSString stringWithFormat:@"Quit %@", applicationName],
                                   @selector(terminate:), @"q", NSApp)];
    menuItem = [[NSMenuItem alloc] initWithTitle:applicationName action:NULL keyEquivalent:@""];
#endif
    [menuItem setSubmenu:appMenu];
    [mainMenu addItem:menuItem];
    RELEASE(menuItem);
    RELEASE(appMenu);

    fileMenu = [[NSMenu alloc] initWithTitle:@"File"];
    [fileMenu addItem:YCodeMenuItem(@"New Project...", @selector(newProject:), @"n", self)];
    [fileMenu addItem:YCodeMenuItem(@"Open Project...", @selector(openProject:), @"o", self)];
    menuItem = [[NSMenuItem alloc] initWithTitle:@"Recent Documents" action:NULL keyEquivalent:@""];
    [menuItem setSubmenu:[(YCodeDocumentController *)[NSDocumentController sharedDocumentController] recentDocumentsMenu]];
    [fileMenu addItem:menuItem];
    RELEASE(menuItem);
    [fileMenu addItem:[NSMenuItem separatorItem]];
    [fileMenu addItem:YCodeMenuItem(@"New File", @selector(newFile:), @"", self)];
    [fileMenu addItem:YCodeMenuItem(@"Close File", @selector(closeCurrentFile:), @"w", self)];
    [fileMenu addItem:[NSMenuItem separatorItem]];
    [fileMenu addItem:YCodeMenuItem(@"Save", @selector(saveDocument:), @"s", self)];
    [fileMenu addItem:YCodeMenuItem(@"Save As...", @selector(saveDocumentAs:), @"S", self)];
    [fileMenu addItem:YCodeMenuItem(@"Save All", @selector(saveAllDocuments:), @"", self)];
    [fileMenu addItem:YCodeMenuItem(@"Save Project", @selector(saveProject:), @"", self)];
    [fileMenu addItem:YCodeMenuItem(@"Export ProjectCenter Project...", @selector(exportProjectCenter:), @"", self)];
    menuItem = [[NSMenuItem alloc] initWithTitle:@"File" action:NULL keyEquivalent:@""];
    [menuItem setSubmenu:fileMenu];
    [mainMenu addItem:menuItem];
    RELEASE(menuItem);
    RELEASE(fileMenu);

    editMenu = [[NSMenu alloc] initWithTitle:@"Edit"];
    [editMenu addItem:YCodeMenuItem(@"Undo", @selector(undo:), @"z", nil)];
    [editMenu addItem:YCodeMenuItem(@"Redo", @selector(redo:), @"Z", nil)];
    [editMenu addItem:[NSMenuItem separatorItem]];
    [editMenu addItem:YCodeMenuItem(@"Cut", @selector(cut:), @"x", nil)];
    [editMenu addItem:YCodeMenuItem(@"Copy", @selector(copy:), @"c", nil)];
    [editMenu addItem:YCodeMenuItem(@"Paste", @selector(paste:), @"v", nil)];
    [editMenu addItem:YCodeMenuItem(@"Select All", @selector(selectAll:), @"a", nil)];
    [editMenu addItem:[NSMenuItem separatorItem]];
    [editMenu addItem:YCodeMenuItem(@"Find...", @selector(findInFile:), @"f", self)];
    [editMenu addItem:YCodeMenuItem(@"Replace...", @selector(replaceInFile:), @"", self)];
    menuItem = [[NSMenuItem alloc] initWithTitle:@"Edit" action:NULL keyEquivalent:@""];
    [menuItem setSubmenu:editMenu];
    [mainMenu addItem:menuItem];
    RELEASE(menuItem);
    RELEASE(editMenu);

    viewMenu = [[NSMenu alloc] initWithTitle:@"View"];
    [viewMenu addItem:YCodeMenuItem(@"Show Navigator", @selector(toggleNavigator:), @"0", self)];
    [viewMenu addItem:YCodeMenuItem(@"Show Inspector", @selector(toggleInspector:), @"", self)];
    [viewMenu addItem:YCodeMenuItem(@"Show Debug Area", @selector(toggleBottomPanel:), @"", self)];
    menuItem = [[NSMenuItem alloc] initWithTitle:@"View" action:NULL keyEquivalent:@""];
    [menuItem setSubmenu:viewMenu];
    [mainMenu addItem:menuItem];
    RELEASE(menuItem);
    RELEASE(viewMenu);

    productMenu = [[NSMenu alloc] initWithTitle:projectMenuTitle];
    [productMenu addItem:YCodeMenuItem(@"Build", @selector(buildProject:), @"b", self)];
    [productMenu addItem:YCodeMenuItem(@"Clean", @selector(cleanProject:), @"k", self)];
    [productMenu addItem:YCodeMenuItem(@"Debug", @selector(debugProject:), @"", self)];
    NSMenu *debugMenu = AUTORELEASE([[NSMenu alloc] initWithTitle:@"Debugger"]);
    NSMenuItem *debugItem = YCodeMenuItem(@"Debugger", NULL, @"", nil);
    [debugItem setSubmenu:debugMenu];
    [debugItem setImage:YCodeControlIcon(@"debug", 16)];
    [productMenu addItem:debugItem];
    NSArray *debugLabels = [NSArray arrayWithObjects:@"Go", @"Pause", @"Continue", @"Restart",
        @"Next", @"Step Into", @"Step Out", @"Up", @"Down", nil];
    NSArray *debugIcons = [NSArray arrayWithObjects:@"go", @"pause", @"continue", @"restart", @"next", @"stepInto", @"stepOut", @"up", @"down", nil];
    for (NSUInteger i = 0; i < [debugLabels count]; i++) {
        NSMenuItem *item = YCodeMenuItem([debugLabels objectAtIndex:i], @selector(debugAction:), @"", self);
        [item setTag:i];
        [item setImage:YCodeControlIcon([debugIcons objectAtIndex:i], 16)];
        [debugMenu addItem:item];
    }
    [debugMenu addItem:YCodeMenuItem(@"Toggle Breakpoint at Selection", @selector(toggleBreakpoint:), @"", self)];
    [productMenu addItem:YCodeMenuItem(@"Run", @selector(runProject:), @"r", self)];
    [productMenu addItem:YCodeMenuItem(@"Stop", @selector(stopProject:), @".", self)];
    NSArray *controlTitles = [NSArray arrayWithObjects:@"Build", @"Clean", @"Debug", @"Run", @"Stop", nil];
    {
      NSEnumerator *titleEnumerator = [controlTitles objectEnumerator];
      NSString *title;
      while ((title = [titleEnumerator nextObject]) != nil)
        [[productMenu itemWithTitle:title] setImage:YCodeControlIcon([title lowercaseString], 16)];
    }
    [[debugMenu itemWithTitle:@"Toggle Breakpoint at Selection"] setImage:YCodeControlIcon(@"breakpoint", 16)];
    menuItem = [[NSMenuItem alloc] initWithTitle:projectMenuTitle action:NULL keyEquivalent:@""];
    [menuItem setSubmenu:productMenu];
    [mainMenu addItem:menuItem];
    RELEASE(menuItem);
    RELEASE(productMenu);

    windowMenu = [[NSMenu alloc] initWithTitle:windowMenuTitle];
    [windowMenu addItem:YCodeMenuItem(@"Minimize", @selector(performMiniaturize:), @"m", nil)];
    [windowMenu addItem:YCodeMenuItem(@"Zoom", @selector(performZoom:), @"", nil)];
    [windowMenu addItem:YCodeMenuItem(@"Close", @selector(performClose:), @"W", nil)];
    [windowMenu addItem:[NSMenuItem separatorItem]];
    [windowMenu addItem:YCodeMenuItem(@"Bring All to Front", @selector(arrangeInFront:), @"", NSApp)];
    menuItem = [[NSMenuItem alloc] initWithTitle:windowMenuTitle action:NULL keyEquivalent:@""];
    [menuItem setSubmenu:windowMenu];
    [mainMenu addItem:menuItem];
    [NSApp setWindowsMenu:windowMenu];
    RELEASE(menuItem);
    RELEASE(windowMenu);

#ifdef GNUSTEP
    helpMenu = [[NSMenu alloc] initWithTitle:@"Services"];
    menuItem = [[NSMenuItem alloc] initWithTitle:@"Services" action:NULL keyEquivalent:@""];
    [menuItem setSubmenu:helpMenu];
    [mainMenu addItem:menuItem];
    [NSApp setServicesMenu:helpMenu];
    RELEASE(menuItem);
    RELEASE(helpMenu);
    [mainMenu addItem:YCodeMenuItem(@"Hide", @selector(hide:), @"h", NSApp)];
    [mainMenu addItem:YCodeMenuItem(@"Quit", @selector(terminate:), @"q", NSApp)];
#else
    helpMenu = [[NSMenu alloc] initWithTitle:@"Help"];
    [helpMenu addItem:YCodeMenuItem(@"Ycode Help", @selector(showHelp:), @"?", NSApp)];
    menuItem = [[NSMenuItem alloc] initWithTitle:@"Help" action:NULL keyEquivalent:@""];
    [menuItem setSubmenu:helpMenu];
    [mainMenu addItem:menuItem];
    RELEASE(menuItem);
    RELEASE(helpMenu);
#endif

    [NSApp setMainMenu:mainMenu];
    RELEASE(mainMenu);
}

- (NSApplicationTerminateReply) applicationShouldTerminate: (NSApplication *)sender
{
    // Check if there are unsaved changes in open projects
    if ([[NSDocumentController sharedDocumentController] hasEditedDocuments]) {
        // TODO: Check for unsaved changes
        NSAlert *alert = [[NSAlert alloc] init];
        [alert setMessageText:@"Do you want to save your changes before closing?"];
        [alert addButtonWithTitle:@"Save"];
        [alert addButtonWithTitle:@"Don't Save"];
        [alert addButtonWithTitle:@"Cancel"];
        
        NSInteger result = [alert runModal];
        RELEASE(alert);
        
        if (result == NSAlertThirdButtonReturn) {
            return NSTerminateCancel;
        } else if (result == NSAlertFirstButtonReturn) {
            if (![self saveActiveProjectShowingPanel:NO]) {
                return NSTerminateCancel;
            }
        }
    }
    
    return NSTerminateNow;
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
        NSArray *urls = [panel URLs];
        NSURL *selectedURL = ([urls count] > 0) ? [urls objectAtIndex:0] : nil;
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
        NSURL *fileURL = YCodeFileURLFromPath([newProject projectPath]);

        if (fileURL != nil) {
            [newProject setFileURL:fileURL];
        }

        [[NSDocumentController sharedDocumentController] addDocument:newProject];
        [newProject makeWindowControllers];
        [newProject showWindows];
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
    YCodeEditorController *editor = [self currentEditorController];
    if ([editor currentDocument]) {
        if (![editor saveCurrentFile]) {
            NSAlert *alert = [[NSAlert alloc] init];
            [alert setMessageText:@"Unable to save file"];
            [alert setInformativeText:[NSString stringWithFormat:
                @"Could not save %@. Your changes remain open in the editor.",
                [[editor currentDocument] filePath]]];
            [alert addButtonWithTitle:@"OK"];
            [alert runModal];
            RELEASE(alert);
        }
        return;
    }
    [self saveActiveProjectShowingPanel:NO];
}

- (IBAction)saveDocumentAs:(id)sender
{
    [self saveActiveProjectShowingPanel:YES];
}

- (IBAction)saveProject:(id)sender
{
    [self saveActiveProjectShowingPanel:NO];
}

- (IBAction)exportProjectCenter:(id)sender
{
    YCodeProject *project = [self currentProject];
    if (!project) return;
    NSSavePanel *panel = [NSSavePanel savePanel];
    [panel setTitle:@"Export ProjectCenter Project"];
    [panel setAllowedFileTypes:[NSArray arrayWithObject:@"pcproj"]];
    [panel setDirectoryURL:[NSURL fileURLWithPath:[project projectDirectoryPath]]];
    NSString *name = [[[project projectPath] lastPathComponent] stringByDeletingPathExtension];
    [panel setNameFieldStringValue:[name stringByAppendingPathExtension:@"pcproj"]];
    if ([panel runModal] != NSModalResponseOK) return;
    NSError *error = nil;
    if (![project exportProjectCenterToPath:[[panel URL] path] error:&error]) {
        NSAlert *alert = [NSAlert alertWithError:error];
        [alert runModal];
    }
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
    YCodeProject *project = (YCodeProject *)[[NSDocumentController sharedDocumentController] currentDocument];
    NSString *projectPath = nil;

    if (project == nil || ![project isKindOfClass:[YCodeProject class]]) {
        NSBeep();
        return NO;
    }

    projectPath = [project projectPath];

    BOOL importedProject = [[projectPath pathExtension] isEqualToString:@"pcproj"];
    if (showPanel || importedProject || projectPath == nil || [projectPath length] == 0) {
        NSSavePanel *panel = [NSSavePanel savePanel];
        NSString *name = @"Project.xcodeproj";

        if (projectPath != nil && [projectPath length] > 0) {
            name = [projectPath lastPathComponent];
            if (importedProject)
                name = [[name stringByDeletingPathExtension] stringByAppendingPathExtension:@"xcodeproj"];
            [panel setDirectoryURL:[NSURL fileURLWithPath:[project projectDirectoryPath]]];
        }

        [panel setTitle:@"Save Project"];
        [panel setNameFieldStringValue:name];
        [panel setAllowedFileTypes:[NSArray arrayWithObject:@"xcodeproj"]];

        if ([panel runModal] != NSModalResponseOK) {
            return NO;
        }

        projectPath = [[panel URL] path];
        if (projectPath == nil || [projectPath length] == 0) {
            return NO;
        }
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

    [[project windowControllers] makeObjectsPerformSelector:@selector(synchronizeWindowTitleWithDocumentName)];
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
    // Check if it's a project file
    NSString *extension = [fileName pathExtension];
    if ([extension isEqualToString:@"xcodeproj"] || [extension isEqualToString:@"pcproj"]) {
        NSError *error = nil;
        NSURL *fileURL = YCodeFileURLFromPath(fileName);
        if (fileURL == nil) {
            return NO;
        }

        id document = [[NSDocumentController sharedDocumentController]
            openDocumentWithContentsOfURL:fileURL
                                  display:YES
                                    error:&error];
        return (document != nil && error == nil);
    }
    
    return NO;
}

- (void)updateApplicationMenuName
{
#ifdef GNUSTEP
    // GNUstep uses the main menu itself as the application menu.
    return;
#else
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
#endif
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

- (YCodeProject *)currentProject
{
    id document = [[NSDocumentController sharedDocumentController] currentDocument];

    if ([document isKindOfClass:[YCodeProject class]]) {
        return document;
    }

    return nil;
}

- (YCodeWindowController *)currentProjectWindowController
{
    YCodeProject *project = [self currentProject];
    NSWindow *keyWindow = [NSApp keyWindow];
    NSEnumerator *enumerator = nil;
    YCodeWindowController *controller = nil;

    if (project == nil) {
        return nil;
    }

    enumerator = [[project windowControllers] objectEnumerator];
    while ((controller = [enumerator nextObject]) != nil) {
        if ([controller window] == keyWindow) {
            return controller;
        }
    }

    return [[project windowControllers] count] > 0
        ? [[project windowControllers] objectAtIndex:0]
        : nil;
}

- (YCodeEditorController *)currentEditorController
{
    return [[self currentProject] editorController];
}

- (IBAction)newFile:(id)sender
{
    [[self currentEditorController] newFile:sender];
}

- (IBAction)closeCurrentFile:(id)sender
{
    [[self currentEditorController] closeCurrentFile:sender];
}

- (IBAction)findInFile:(id)sender
{
    [[self currentEditorController] findInFile:sender];
}

- (IBAction)replaceInFile:(id)sender
{
    [[self currentEditorController] replaceInFile:sender];
}

- (IBAction)buildProject:(id)sender
{
    YCodeWindowController *controller = [self currentProjectWindowController];

    if (controller != nil) {
        [controller buildProject:sender];
    } else {
        NSBeep();
    }
}

- (IBAction)cleanProject:(id)sender
{
    YCodeProject *project = [self currentProject];

    if (project != nil) {
        [project cleanProject];
    } else {
        NSBeep();
    }
}

- (BOOL)validateMenuItem:(NSMenuItem *)item
{
    SEL action = [item action];
    if (action == @selector(exportProjectCenter:)) return [self currentProject] != nil;
    if (action == @selector(debugProject:) || action == @selector(debugAction:) ||
        action == @selector(toggleBreakpoint:))
        return [[self currentProjectWindowController] validateDebuggerAction:action tag:[item tag]];
    return YES;
}

- (IBAction)debugProject:(id)sender
{
    [[self currentProjectWindowController] debugProject:sender];
}
- (IBAction)debugAction:(id)sender
{
    [[self currentProjectWindowController] debugAction:sender];
}
- (IBAction)toggleBreakpoint:(id)sender
{
    [[self currentProjectWindowController] toggleBreakpoint:sender];
}

- (IBAction)runProject:(id)sender
{
    YCodeWindowController *controller = [self currentProjectWindowController];

    if (controller != nil) {
        [controller runProject:sender];
    } else {
        NSBeep();
    }
}

- (IBAction)stopProject:(id)sender
{
    YCodeWindowController *controller = [self currentProjectWindowController];

    if (controller != nil) {
        [controller stopProject:sender];
    } else {
        NSBeep();
    }
}

- (IBAction)toggleNavigator:(id)sender
{
    [[self currentProjectWindowController] toggleNavigator:sender];
}

- (IBAction)toggleInspector:(id)sender
{
    [[self currentProjectWindowController] toggleInspector:sender];
}

- (IBAction)toggleBottomPanel:(id)sender
{
    [[self currentProjectWindowController] toggleBottomPanel:sender];
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
    NSError *error = nil;
    [openPanel setCanChooseFiles:YES];
    [openPanel setCanChooseDirectories:YES];
    [openPanel setAllowsMultipleSelection:NO];
    [openPanel setTreatsFilePackagesAsDirectories:NO];
    [openPanel setAllowedFileTypes:[NSArray arrayWithObjects:@"xcodeproj", @"pcproj", nil]];
    [openPanel setMessage:@"Choose a project to open"];
    
    if ([openPanel runModal] == NSModalResponseOK) {
        NSString *projectPath = [[openPanel URL] path];
        NSURL *projectURL = YCodeFileURLFromPath(projectPath);

        if (projectURL == nil) {
            NSBeep();
            return;
        }

        [[NSDocumentController sharedDocumentController]
            openDocumentWithContentsOfURL:projectURL
                                  display:YES
                                    error:&error];

        if (error != nil) {
            NSAlert *alert = [[NSAlert alloc] init];
            [alert setMessageText:@"Unable to open project"];
            [alert setInformativeText:[error localizedDescription]];
            [alert addButtonWithTitle:@"OK"];
            [alert runModal];
            RELEASE(alert);
        }
    }
}

@end
