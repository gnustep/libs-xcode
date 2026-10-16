/* 
   Project: Ycode

   Author: Gregory John Casamento,,,

   Created: 2017-08-15 03:31:31 -0400 by heron
   
   Application Controller
*/

#import "YCodePreferences.h"
#import "YCodeControlIcons.h"
#import "YCodeSyntaxHighlighter.h"
#import "AppController.h"
#import "YCodeWindowController.h"
#import "YCodeDocumentController.h"
#import "YCodeProject.h"
#import "YCodeEditorController.h"
#import "YCodeEditorDocument.h"
#import "YCodeTextView.h"

@interface AppController (Private)
- (void)updateApplicationMenuName;
- (void)updateApplicationNameItemsInMenu:(NSMenu *)menu appName:(NSString *)applicationName;
- (void)connectDocumentMenuActions;
- (void)connectDocumentMenuActionsInMenu:(NSMenu *)menu;
- (BOOL)saveActiveProjectShowingPanel:(BOOL)showPanel;
- (YCodeProject *)currentProject;
- (YCodeWindowController *)currentProjectWindowController;
- (YCodeEditorController *)currentEditorController;
- (NSView *)newProjectAccessoryView;
- (void)createNewProjectAtURL:(NSURL *)url format:(NSString *)format productType:(NSString *)productType;
@end

/* The Fonts panel routes actions to the main window when it becomes key. */
@interface YCodePreferencesPanel : NSPanel
@end

@implementation YCodePreferencesPanel
- (BOOL)canBecomeMainWindow
{
    return YES;
}
@end

/* Keep font-panel actions in the responder chain of the selected preference. */
@interface YCodePreferenceFontButton : NSButton
@end

@implementation YCodePreferenceFontButton
- (BOOL)acceptsFirstResponder
{
    return YES;
}
- (void)changeFont:(id)sender
{
    NSString *pane = [[YCodePreferences fontPanes] objectAtIndex:[self tag]];
    NSFont *font = [sender convertFont:[YCodePreferences fontForPane:pane]];
    if (font && [font pointSize] >= 6 && [font pointSize] <= 144) {
        [YCodePreferences setFont:font forPane:pane];
        [[NSFontManager sharedFontManager] setSelectedFont:font isMultiple:NO];
        [[self target] performSelector:@selector(refreshFontPreferences)];
    }
}
@end

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
  RELEASE(_fontChoices);
  RELEASE(_editorColorWells);
  RELEASE(_preferencesPanel);
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
    [fileMenu addItem:YCodeMenuItem(@"Create .ycode.plist", @selector(createProjectSettings:), @"", self)];
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
    [editMenu addItem:[NSMenuItem separatorItem]];
    [editMenu addItem:YCodeMenuItem(@"Comment/Uncomment Lines", @selector(toggleLineComment:), @"", nil)];
    [editMenu addItem:YCodeMenuItem(@"Convert Tabs to Spaces", @selector(convertTabsToSpaces:), @"", self)];
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
    NSUInteger i;
    for (i = 0; i < [debugLabels count]; i++) {
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
    NSEnumerator *documents = [[[NSDocumentController sharedDocumentController] documents] objectEnumerator];
    YCodeProject *project;
    while ((project = [documents nextObject]) != nil)
        if (![project canCloseDocument]) return NSTerminateCancel;

    return NSTerminateNow;
}

- (void) applicationWillTerminate: (NSNotification *)aNotif
{
    // Clean up
    if (windowController) {
        [windowController closeProject];
    }
}

- (NSView *)newProjectAccessoryView
{
    NSView *view = AUTORELEASE([[NSView alloc] initWithFrame:NSMakeRect(0, 0, 360, 76)]);
    NSUInteger index;
    for (index = 0; index < 2; index++) {
        CGFloat y = index == 0 ? 42 : 8;
        NSTextField *label = AUTORELEASE([[NSTextField alloc] initWithFrame:NSMakeRect(12, y, 104, 24)]);
        [label setStringValue:index == 0 ? @"Project type:" : @"Format:"];
        [label setEditable:NO];
        [label setBezeled:NO];
        [label setDrawsBackground:NO];
        [view addSubview:label];
        NSPopUpButton *popup = AUTORELEASE([[NSPopUpButton alloc] initWithFrame:NSMakeRect(120, y, 228, 26) pullsDown:NO]);
        [popup setTag:100 + index];
        NSArray *values = index == 0 ? [YCodeProject newProjectTypes] :
            [NSArray arrayWithObjects:@"Xcode", @"ProjectCenter", nil];
        NSEnumerator *enumerator = [values objectEnumerator];
        NSString *value;
        while ((value = [enumerator nextObject]) != nil) {
            NSString *title = [value isEqual:@"Library"] ? @"Dynamic Library" :
                [value isEqual:@"StaticLibrary"] ? @"Static Library" : value;
            [popup addItemWithTitle:title];
            [[popup lastItem] setRepresentedObject:value];
        }
        [view addSubview:popup];
    }
    return view;
}

- (IBAction) newProject: (id)sender
{
    // A save panel accepts a new folder name; an open panel requires an
    // existing item and disables its confirmation button for a new name.
    NSSavePanel *panel = [NSSavePanel savePanel];
    [panel setCanCreateDirectories:YES];
    [panel setAllowedFileTypes:nil];
    [panel setNameFieldStringValue:@"MyProject"];
    [panel setTitle:@"Create New Project"];
    [panel setPrompt:@"Create"];
    [panel setNameFieldLabel:@"Project name:"];
    [panel setMessage:@"Choose a location and name for the new project folder."];
    
    NSView *accessory = [self newProjectAccessoryView];
    [panel setAccessoryView:accessory];
#ifdef GNUSTEP
    // GNUstep's runModal uses the previous filename, not nameFieldStringValue.
    NSInteger result = [panel runModalForDirectory:[panel directory] file:@"MyProject"];
#else
    NSInteger result = [panel runModal];
#endif
    NSString *productType = [[(NSPopUpButton *)[accessory viewWithTag:100] selectedItem] representedObject];
    NSString *format = [[(NSPopUpButton *)[accessory viewWithTag:101] selectedItem] representedObject];
    [panel setAccessoryView:nil];
    if (result == NSModalResponseOK) {
        NSURL *selectedURL = [panel URL];
        if (selectedURL) {
            [self createNewProjectAtURL:selectedURL format:format productType:productType];
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
    [self createNewProjectAtURL:projectURL format:@"Xcode" productType:@"Application"];
}

- (void)createNewProjectAtURL:(NSURL *)projectURL format:(NSString *)format productType:(NSString *)productType
{
    NSString *projectPath = [[projectURL path] stringByStandardizingPath];
    NSString *projectName = [projectPath lastPathComponent];

    // Create the project
    YCodeProject *newProject = [YCodeProject createNewProjectAtPath:projectPath 
                                                               name:projectName 
                                                               type:format productType:productType];
    
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
        [errorAlert setInformativeText:@"Could not create the project. Choose an empty, writable folder and try again."];
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

- (IBAction)createProjectSettings:(id)sender
{
    YCodeProject *project = [self currentProject];
    if (![project canCreateSettingsFile]) return;
    NSString *chosenExecutable = nil;
    if (![[project settingsExecutablePath] length]) {
        NSOpenPanel *panel = [NSOpenPanel openPanel];
        [panel setTitle:@"Choose Project Executable"];
        [panel setMessage:@"Select the executable to use for Run and Debug. For an application, select the executable inside its bundle."];
        [panel setCanChooseDirectories:NO];
        [panel setCanChooseFiles:YES];
        [panel setAllowsMultipleSelection:NO];
        [panel setTreatsFilePackagesAsDirectories:YES];
        [panel setDirectoryURL:[NSURL fileURLWithPath:[project projectDirectoryPath]]];
        if ([panel runModal] != NSModalResponseOK) return;
        chosenExecutable = [[panel URL] path];
        if (![[NSFileManager defaultManager] isExecutableFileAtPath:chosenExecutable]) {
            NSAlert *alert = AUTORELEASE([[NSAlert alloc] init]);
            [alert setMessageText:@"The selected file is not executable."];
            [alert runModal];
            return;
        }
        NSString *root = [[project projectDirectoryPath] stringByAppendingString:@"/"];
        if ([chosenExecutable hasPrefix:root]) chosenExecutable = [chosenExecutable substringFromIndex:[root length]];
        [[project settings] setObject:chosenExecutable forKey:@"Executable"];
    }
    NSError *error = nil;
    if (![project createSettingsFile:&error]) {
        if (chosenExecutable) [[project settings] removeObjectForKey:@"Executable"];
        [[NSAlert alertWithError:error] runModal];
        return;
    }
    [[project editorController] openFile:
        [[project projectDirectoryPath] stringByAppendingPathComponent:@".ycode.plist"]];
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
    if (![project isDirectoryProject] && (showPanel || importedProject || projectPath == nil || [projectPath length] == 0)) {
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

- (BOOL) application: (NSApplication *)application
	    openFile: (NSString *)fileName
{
    NSError *error = nil;
    BOOL opened = [(YCodeDocumentController *)[NSDocumentController sharedDocumentController]
        openWorkspaceFile:fileName error:&error];
    if (!opened && error) [[NSDocumentController sharedDocumentController] presentError:error];
    return opened;
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

- (IBAction)convertTabsToSpaces:(id)sender
{
    [(YCodeTextView *)[[[self currentEditorController] currentDocument] textView]
        convertTabsToSpaces:sender];
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
    if (action == @selector(createProjectSettings:)) return [[self currentProject] canCreateSettingsFile];
    if (action == @selector(convertTabsToSpaces:))
        return [[[[self currentEditorController] currentDocument] textView] isEditable];
    if (action == @selector(findInFile:) || action == @selector(replaceInFile:))
        return [[[self currentEditorController] currentDocument] textView] != nil;
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

- (void)refreshEditorColorWells
{
    NSArray *keys = [YCodeSyntaxHighlighter colorPreferenceKeys];
    NSUInteger i;
    for (i = 0; i < [_editorColorWells count]; i++)
        [[_editorColorWells objectAtIndex:i] setColor:
            [YCodeSyntaxHighlighter preferredColorForKey:[keys objectAtIndex:i]]];
}

- (void)changeEditorColor:(NSColorWell *)sender
{
    NSString *key = [[YCodeSyntaxHighlighter colorPreferenceKeys] objectAtIndex:[sender tag]];
    [YCodeSyntaxHighlighter setPreferredColor:[sender color] forKey:key];
    [self refreshEditorColorWells];
}

- (void)resetEditorColors:(id)sender
{
    [YCodeSyntaxHighlighter resetColorPreferences];
    [self refreshEditorColorWells];
}

- (void)changeTabPreferences:(id)sender
{
    [YCodePreferences setControlIndentWidth:[_controlIndentChoice indexOfSelectedItem] + 1];
    [YCodePreferences setTabWidth:[_tabWidthChoice indexOfSelectedItem] + 1
        useSpaces:[_spacesForTabs state] == NSOnState
        useProjectSettings:[_projectIndentation state] == NSOnState];
}

- (void)setupTabPreferences
{
    _tabPreferencesView = AUTORELEASE([[NSView alloc] initWithFrame:NSMakeRect(0, 0, 390, 450)]);
    [[_preferencesPanel contentView] addSubview:_tabPreferencesView];
    NSTextField *label = AUTORELEASE([[NSTextField alloc] initWithFrame:NSMakeRect(20, 404, 190, 24)]);
    [label setStringValue:@"Tab / indent width (spaces):"];
    [label setEditable:NO]; [label setSelectable:NO];
    [label setBezeled:NO]; [label setDrawsBackground:NO];
    [_tabPreferencesView addSubview:label];
    _tabWidthChoice = AUTORELEASE([[NSPopUpButton alloc] initWithFrame:NSMakeRect(260, 401, 110, 28) pullsDown:NO]);
    NSUInteger width;
    for (width = 1; width <= 16; width++)
        [_tabWidthChoice addItemWithTitle:[NSString stringWithFormat:@"%lu", (unsigned long)width]];
    [_tabWidthChoice setTarget:self]; [_tabWidthChoice setAction:@selector(changeTabPreferences:)];
    [_tabPreferencesView addSubview:_tabWidthChoice];
    _spacesForTabs = AUTORELEASE([[NSButton alloc] initWithFrame:NSMakeRect(20, 360, 350, 28)]);
    [_spacesForTabs setButtonType:NSSwitchButton];
    [_spacesForTabs setTitle:@"Insert spaces instead of tab characters"];
    [_spacesForTabs setTarget:self]; [_spacesForTabs setAction:@selector(changeTabPreferences:)];
    [_tabPreferencesView addSubview:_spacesForTabs];
    _projectIndentation = AUTORELEASE([[NSButton alloc] initWithFrame:NSMakeRect(20, 320, 350, 28)]);
    [_projectIndentation setButtonType:NSSwitchButton];
    [_projectIndentation setTitle:@"Honor project .clang-format settings"];
    [_projectIndentation setTarget:self]; [_projectIndentation setAction:@selector(changeTabPreferences:)];
    [_tabPreferencesView addSubview:_projectIndentation];
    NSTextField *controlLabel = AUTORELEASE([[NSTextField alloc] initWithFrame:NSMakeRect(20, 276, 230, 24)]);
    [controlLabel setStringValue:@"Auto indentation (spaces):"];
    [controlLabel setEditable:NO]; [controlLabel setSelectable:NO];
    [controlLabel setBezeled:NO]; [controlLabel setDrawsBackground:NO];
    [_tabPreferencesView addSubview:controlLabel];
    _controlIndentChoice = AUTORELEASE([[NSPopUpButton alloc] initWithFrame:NSMakeRect(260, 273, 110, 28) pullsDown:NO]);
    for (width = 1; width <= 16; width++)
        [_controlIndentChoice addItemWithTitle:[NSString stringWithFormat:@"%lu", (unsigned long)width]];
    [_controlIndentChoice setTarget:self]; [_controlIndentChoice setAction:@selector(changeTabPreferences:)];
    [_tabPreferencesView addSubview:_controlIndentChoice];
    NSTextField *hint = AUTORELEASE([[NSTextField alloc] initWithFrame:NSMakeRect(20, 140, 350, 120)]);
    [hint setStringValue:@"Auto indentation adds spaces after control statements and opening braces, and removes the same amount after closing braces. It is independent of tab width and project settings. Changes apply immediately; existing whitespace is preserved."];
    [hint setEditable:NO]; [hint setSelectable:NO];
    [hint setBezeled:NO]; [hint setDrawsBackground:NO];
    [hint setFont:[NSFont systemFontOfSize:12]];
    [_tabPreferencesView addSubview:hint];
}

- (void)selectPreferenceGroup:(id)sender
{
    if ([_fontChoices containsObject:[_preferencesPanel firstResponder]])
        [_preferencesPanel makeFirstResponder:_preferencesGroup];
    BOOL colors = [_preferencesGroup indexOfSelectedItem] == 0;
    [_colorPreferencesView setHidden:!colors];
    [_editorPreferencesView setHidden:[_preferencesGroup indexOfSelectedItem] != 1];
    [_fontPreferencesView setHidden:[_preferencesGroup indexOfSelectedItem] != 2];
    [_tabPreferencesView setHidden:[_preferencesGroup indexOfSelectedItem] != 3];
    if (!colors) {
        NSEnumerator *enumerator = [_editorColorWells objectEnumerator];
        NSColorWell *well;
        while ((well = [enumerator nextObject]) != nil) [well deactivate];
    }
}

- (void)changeMatchingDelimiters:(NSButton *)sender
{
    [YCodePreferences setHighlightMatchingDelimiters:[sender state] == NSOnState];
}

- (void)changeEditorRulers:(NSButton *)sender
{
    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
    [defaults setBool:[sender state] != NSOnState forKey:@"YCodeHideEditorRulers"];
    [defaults synchronize];
    [[NSNotificationCenter defaultCenter] postNotificationName:@"YCodeEditorRulersDidChange" object:nil];
}

- (void)refreshFontPreferences
{
    NSUInteger i;
    NSArray *panes = [YCodePreferences fontPanes];
    for (i = 0; i < [_fontChoices count]; i++) {
        NSFont *font = [YCodePreferences fontForPane:[panes objectAtIndex:i]];
        NSButton *choice = [_fontChoices objectAtIndex:i];
        NSString *name = [font displayName];
        if (![name length]) name = [font fontName];
        [choice setTitle:[NSString stringWithFormat:@"%@ — %g pt", name, (double)[font pointSize]]];
        /* Preview the chosen face while keeping the preference row readable. */
        [choice setFont:[[NSFontManager sharedFontManager] convertFont:font
            toSize:MIN(18, MAX(12, [font pointSize]))]];
        [choice setNeedsDisplay:YES];
    }
}

- (void)choosePreferenceFont:(NSButton *)sender
{
    [[sender window] makeKeyAndOrderFront:nil];
    [[sender window] makeMainWindow];
    [[sender window] makeFirstResponder:sender];
    NSFontManager *manager = [NSFontManager sharedFontManager];
    [manager setSelectedFont:[YCodePreferences fontForPane:
        [[YCodePreferences fontPanes] objectAtIndex:[sender tag]]] isMultiple:NO];
    [manager orderFrontFontPanel:sender];
}

- (void)resetPreferenceFonts:(id)sender
{
    [YCodePreferences resetFonts];
    [_matchingDelimitersCheckbox setState:[YCodePreferences highlightMatchingDelimiters] ? NSOnState : NSOffState];
    [self refreshFontPreferences];
    id responder = [_preferencesPanel firstResponder];
    if ([_fontChoices containsObject:responder])
        [[NSFontManager sharedFontManager] setSelectedFont:[YCodePreferences fontForPane:
            [[YCodePreferences fontPanes] objectAtIndex:[responder tag]]] isMultiple:NO];
}

- (void)setupFontPreferences
{
    _fontPreferencesView = AUTORELEASE([[NSView alloc] initWithFrame:NSMakeRect(0, 0, 390, 450)]);
    [[_preferencesPanel contentView] addSubview:_fontPreferencesView];
    _fontChoices = [NSMutableArray new];
    NSArray *panes = [YCodePreferences fontPanes];
    NSUInteger i;
    for (i = 0; i < [panes count]; i++) {
        CGFloat y = 407 - i * 85;
        NSTextField *label = AUTORELEASE([[NSTextField alloc] initWithFrame:NSMakeRect(20, y, 350, 22)]);
        [label setStringValue:[panes objectAtIndex:i]];
        [label setEditable:NO]; [label setBezeled:NO]; [label setDrawsBackground:NO];
        [_fontPreferencesView addSubview:label];
        NSButton *font = AUTORELEASE([[YCodePreferenceFontButton alloc]
            initWithFrame:NSMakeRect(20, y - 34, 350, 30)]);
        [font setBezelStyle:NSRoundedBezelStyle];
        [font setTag:i];
        [font setToolTip:@"Choose the font and size in the Fonts panel"];
        [font setTarget:self]; [font setAction:@selector(choosePreferenceFont:)];
        [_fontPreferencesView addSubview:font]; [_fontChoices addObject:font];
    }
    NSButton *reset = AUTORELEASE([[NSButton alloc] initWithFrame:NSMakeRect(215, 16, 155, 30)]);
    [reset setTitle:@"Restore Defaults"]; [reset setBezelStyle:NSRoundedBezelStyle];
    [reset setTarget:self]; [reset setAction:@selector(resetPreferenceFonts:)];
    [_fontPreferencesView addSubview:reset];
}

- (void) showPrefPanel: (id)sender
{
    if (!_preferencesPanel) {
        _preferencesPanel = [[YCodePreferencesPanel alloc] initWithContentRect:NSMakeRect(0, 0, 390, 500)
            styleMask:NSTitledWindowMask | NSClosableWindowMask
            backing:NSBackingStoreBuffered defer:NO];
        [_preferencesPanel setTitle:@"Preferences"];
        [_preferencesPanel setReleasedWhenClosed:NO];
        [_preferencesPanel center];
        NSView *content = [_preferencesPanel contentView];
        _preferencesGroup = AUTORELEASE([[NSPopUpButton alloc]
            initWithFrame:NSMakeRect(20, 458, 350, 28) pullsDown:NO]);
        [_preferencesGroup addItemsWithTitles:[NSArray arrayWithObjects:@"Editor Colors", @"Editor", @"Fonts", @"Indentation", nil]];
        [_preferencesGroup setTarget:self];
        [_preferencesGroup setAction:@selector(selectPreferenceGroup:)];
        [content addSubview:_preferencesGroup];
        _colorPreferencesView = AUTORELEASE([[NSView alloc] initWithFrame:NSMakeRect(0, 0, 390, 450)]);
        [content addSubview:_colorPreferencesView];
        _editorPreferencesView = AUTORELEASE([[NSView alloc] initWithFrame:NSMakeRect(0, 0, 390, 450)]);
        [content addSubview:_editorPreferencesView];
        _showEditorRulers = AUTORELEASE([[NSButton alloc] initWithFrame:NSMakeRect(20, 401, 350, 28)]);
        [_showEditorRulers setButtonType:NSSwitchButton];
        [_showEditorRulers setTitle:@"Show editor rulers (lines and columns)"];
        [_showEditorRulers setTarget:self];
        [_showEditorRulers setAction:@selector(changeEditorRulers:)];
        [_editorPreferencesView addSubview:_showEditorRulers];
        _matchingDelimitersCheckbox = AUTORELEASE([[NSButton alloc] initWithFrame:NSMakeRect(20, 361, 350, 28)]);
        [_matchingDelimitersCheckbox setButtonType:NSSwitchButton];
        [_matchingDelimitersCheckbox setTitle:@"Highlight matching delimiters"];
        [_matchingDelimitersCheckbox setTarget:self];
        [_matchingDelimitersCheckbox setAction:@selector(changeMatchingDelimiters:)];
        [_editorPreferencesView addSubview:_matchingDelimitersCheckbox];
        [self setupFontPreferences];
        [self setupTabPreferences];
        _editorColorWells = [NSMutableArray new];
        NSArray *labels = [NSArray arrayWithObjects:@"Editor background", @"Plain text", @"Keywords",
            @"Strings", @"Comments", @"Numbers", @"Preprocessor directives", @"Types",
            @"Symbols", @"Constants", @"Insertion cursor", nil];
        NSUInteger i;
        for (i = 0; i < [labels count]; i++) {
            CGFloat y = 405 - i * 30;
            NSTextField *label = AUTORELEASE([[NSTextField alloc] initWithFrame:NSMakeRect(20, y, 250, 24)]);
            [label setStringValue:[labels objectAtIndex:i]];
            [label setEditable:NO];
            [label setSelectable:NO];
            [label setBezeled:NO];
            [label setDrawsBackground:NO];
            [_colorPreferencesView addSubview:label];
            NSColorWell *well = AUTORELEASE([[NSColorWell alloc] initWithFrame:NSMakeRect(290, y, 80, 26)]);
            [well setTag:i];
            [well setTarget:self];
            [well setAction:@selector(changeEditorColor:)];
            [well setContinuous:YES];
            [_colorPreferencesView addSubview:well];
            [_editorColorWells addObject:well];
        }
        NSTextField *hint = AUTORELEASE([[NSTextField alloc] initWithFrame:NSMakeRect(20, 58, 350, 22)]);
        [hint setStringValue:@"Changes are saved and applied immediately."];
        [hint setEditable:NO];
        [hint setBezeled:NO];
        [hint setDrawsBackground:NO];
        [hint setFont:[NSFont systemFontOfSize:12]];
        [_colorPreferencesView addSubview:hint];
        NSButton *reset = AUTORELEASE([[NSButton alloc] initWithFrame:NSMakeRect(215, 16, 155, 30)]);
        [reset setTitle:@"Restore Defaults"];
        [reset setBezelStyle:NSRoundedBezelStyle];
        [reset setTarget:self];
        [reset setAction:@selector(resetEditorColors:)];
        [_colorPreferencesView addSubview:reset];
    }
    [self refreshEditorColorWells];
    [_matchingDelimitersCheckbox setState:[YCodePreferences highlightMatchingDelimiters] ? NSOnState : NSOffState];
    [self refreshFontPreferences];
    [_tabWidthChoice selectItemAtIndex:[YCodePreferences tabWidth] - 1];
    [_controlIndentChoice selectItemAtIndex:[YCodePreferences controlIndentWidth] - 1];
    [_spacesForTabs setState:[YCodePreferences useSpacesForTabs] ? NSOnState : NSOffState];
    [_projectIndentation setState:[YCodePreferences useProjectIndentation] ? NSOnState : NSOffState];
    [_showEditorRulers setState:[[NSUserDefaults standardUserDefaults]
        boolForKey:@"YCodeHideEditorRulers"] ? NSOffState : NSOnState];
    [self selectPreferenceGroup:nil];
    [_preferencesPanel makeKeyAndOrderFront:sender];
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
    [openPanel setMessage:@"Choose a project or a folder containing GNUmakefile, makefile, or Makefile"];
    
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
