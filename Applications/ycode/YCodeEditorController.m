/*
   Project: Ycode

   Copyright (C) 2025 Free Software Foundation

   Author: Gregory Casamento

   Created: 2025-01-15

   This application is free software; you can redistribute it and/or
   modify it under the terms of the GNU General Public
   License as published by the Free Software Foundation; either
   version 3 of the License, or (at your option) any later version.

   This application is distributed in the hope that it will be useful,
   but WITHOUT ANY WARRANTY; without even the implied warranty of
   MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
   General Public License for more details.

   You should have received a copy of the GNU General Public
   License along with this application; if not, see
   <https://www.gnu.org/licenses/>.
*/

#import "YCodePreferences.h"
#import "YCodeEditorController.h"
#import "YCodeCompilerSettings.h"
#import "YCodeBuildSystem.h"
#import "YCodeEditorDocument.h"
#import "YCodeProject.h"
#import "YCodeSyntaxHighlighter.h"
#import "YCodeFileWatcher.h"

@interface YCodeEditorTabItem : NSTabViewItem
{
  NSButton *_closeButton;
  BOOL _labelDrawn;
}

- (NSButton *) closeButton;
- (void) closeTab: (id)sender;
- (void) prepareToDrawLabel;
- (void) updateCloseButtonVisibility;
@end

@implementation YCodeEditorTabItem
- (id) initWithIdentifier: (id)identifier
{
  self = [super initWithIdentifier: identifier];
  if (self)
    {
      _closeButton = [[NSButton alloc] initWithFrame: NSZeroRect];
      [_closeButton setTitle: @"×"];
      [_closeButton setFont: [NSFont systemFontOfSize: 14]];
      [_closeButton setBordered: NO];
      [_closeButton setButtonType: NSMomentaryChangeButton];
      [_closeButton setToolTip: @"Close file"];
      [_closeButton setTarget: self];
      [_closeButton setAction: @selector (closeTab:)];
    }
  return self;
}

- (void) dealloc
{
  [_closeButton removeFromSuperview];
  RELEASE (_closeButton);
  [super dealloc];
}

- (NSButton *) closeButton
{
  return _closeButton;
}

- (void) prepareToDrawLabel
{
  _labelDrawn = NO;
}

- (void) updateCloseButtonVisibility
{
  [_closeButton setHidden: !_labelDrawn];
}

- (NSSize) sizeOfLabel: (BOOL)truncate
{
  NSSize size = [super sizeOfLabel: truncate];
  size.width += 22;
  size.height = MAX (size.height, 16);
  return size;
}

- (void) drawLabel: (BOOL)truncate inRect: (NSRect)rect
{
  NSRect labelRect = rect;
  labelRect.size.width = MAX (0, rect.size.width - 22);
  [super drawLabel: truncate inRect: labelRect];
  if (rect.size.width >= 22)
    {
      if ([_closeButton superview] != [self tabView])
        [[self tabView] addSubview: _closeButton];
      [_closeButton
          setFrame: NSMakeRect (NSMaxX (rect) - 18, NSMidY (rect) - 8, 16, 16)];
      _labelDrawn = YES;
    }
}

- (void) closeTab: (id)sender
{
  // Closing may release this item and its button during the action.
  AUTORELEASE (RETAIN (self));
  id controller = [[self tabView] delegate];
  if ([controller respondsToSelector: @selector (closeFile:)])
    [controller closeFile: [self identifier]];
}

@end

@implementation YCodeEditorTabView
- (void) drawRect: (NSRect)rect
{
  // A theme may omit tabs that no longer fit after resizing.
  {
    NSEnumerator *itemEnumerator = [[self tabViewItems] objectEnumerator];
    NSTabViewItem *item;
    while ((item = [itemEnumerator nextObject]) != nil)
      if ([item isKindOfClass: [YCodeEditorTabItem class]])
        [(YCodeEditorTabItem *)item prepareToDrawLabel];
  }
  [super drawRect: rect];
  {
    NSEnumerator *itemEnumerator = [[self tabViewItems] objectEnumerator];
    NSTabViewItem *item;
    while ((item = [itemEnumerator nextObject]) != nil)
      if ([item isKindOfClass: [YCodeEditorTabItem class]])
        [(YCodeEditorTabItem *)item updateCloseButtonVisibility];
  }
}

- (void) removeTabViewItem: (NSTabViewItem *)item
{
  if ([item isKindOfClass: [YCodeEditorTabItem class]])
    [[(YCodeEditorTabItem *)item closeButton] removeFromSuperview];
  [super removeTabViewItem: item];
}

@end

@interface YCodeEditorController (Session)
- (NSString *) lastSourceFileDefaultsKey;
- (void) rememberCurrentSourceFile;
- (void) restoreLastSourceFile;
- (NSString *) cursorPositionKeyForDocument: (YCodeEditorDocument *)document;
- (void) saveCursorPositionForDocument: (YCodeEditorDocument *)document;
- (void) saveCursorPositions: (NSNotification *)notification;
@end

@interface YCodeEditorController (CodeIntelligence)
- (void) synchronizeLanguageServer;
- (BOOL) ensureLanguageServer;
- (void) startCodeIntelligence;
- (void) requestCodeMethod: (NSString *)method;
- (void) showSemanticResult: (id)result context: (NSDictionary *)context;
- (void) clearCodeDiagnosticsForDocument: (YCodeEditorDocument *)document;
- (void) languageServerTextChanged: (NSNotification *)notification;
@end

@interface YCodeEditorController (FindPanel)
- (void) updateFindPanel;
@end

NSString *const YCodeCurrentDocumentDidChangeNotification
    = @"YCodeCurrentDocumentDidChangeNotification";

@implementation YCodeEditorController

- (id) init
{
  self = [super init];
  if (self)
    {
      [[NSNotificationCenter defaultCenter]
          addObserver: self
             selector: @selector (saveCursorPositions:)
                 name: NSApplicationWillTerminateNotification
               object: nil];
      _definitionHistory = [NSMutableArray new];
      _codeDiagnostics = [NSMutableDictionary new];
      [[NSNotificationCenter defaultCenter]
          addObserver: self
             selector: @selector (languageServerTextChanged:)
                 name: NSTextStorageDidProcessEditingNotification
               object: nil];
      [[NSNotificationCenter defaultCenter]
          addObserver: self
             selector: @selector (restartCodeIntelligence:)
                 name: YCodeLanguageServerPreferencesDidChangeNotification
               object: nil];
      [[NSNotificationCenter defaultCenter]
          addObserver: self
             selector: @selector (compilationDatabaseChanged:)
                 name: @"YCodeCompilationDatabaseChanged"
               object: nil];
      [[NSNotificationCenter defaultCenter]
          addObserver: self
             selector: @selector (compilerSettingsChanged:)
                 name: YCodeCompilerSettingsDidChangeNotification
               object: nil];
      _openDocuments = [[NSMutableArray alloc] init];
      _documentTabs = [[NSMutableDictionary alloc] init];
      _fileWatchers = [NSMutableDictionary new];
      _changedDirectories = [NSMutableSet new];
      [[NSNotificationCenter defaultCenter]
          addObserver: self
             selector: @selector (directoryChanged:)
                 name: @"YCodeDirectoryDidChange"
               object: nil];

      // Default editor settings
      [[NSNotificationCenter defaultCenter]
          addObserver: self
             selector: @selector (fileWatchingPreferencesChanged:)
                 name: YCodeFileWatchingPreferencesDidChangeNotification
               object: nil];
      _editorFont = [[YCodePreferences fontForPane: @"Editor"] retain];
      _backgroundColor =
          [[YCodeSyntaxHighlighter preferredColorForKey: @"background"] retain];
      _textColor = [[YCodeSyntaxHighlighter
          plainTextColorForBackground: _backgroundColor] retain];
      _showLineNumbers = ![[NSUserDefaults standardUserDefaults]
          boolForKey: @"YCodeHideEditorRulers"];
      _syntaxHighlighting = YES;
      [[NSNotificationCenter defaultCenter]
          addObserver: self
             selector: @selector (editorPreferencesChanged:)
                 name: @"YCodeEditorColorsDidChange"
               object: nil];
      [[NSNotificationCenter defaultCenter]
          addObserver: self
             selector: @selector (editorPreferencesChanged:)
                 name: @"YCodeEditorRulersDidChange"
               object: nil];
      [[NSNotificationCenter defaultCenter]
          addObserver: self
             selector: @selector (editorFontsChanged:)
                 name: @"YCodeFontsDidChange"
               object: nil];
      [[NSNotificationCenter defaultCenter]
          addObserver: self
             selector: @selector (fileModificationChanged:)
                 name: @"YCodeFileModificationDidChange"
               object: self];
    }
  return self;
}

- (void) dealloc
{
  if ([_tabView delegate] == self)
    [_tabView setDelegate: nil];
  [NSObject cancelPreviousPerformRequestsWithTarget: self];
  [_languageServer stop];
  DESTROY (_languageServer);
  [YCodeCompilerSettings removePreparedConfiguration: _compilerConfiguration];
  DESTROY (_compilerConfiguration);
  DESTROY (_codeBrowser);
  RELEASE (_codeDiagnostics);
  RELEASE (_definitionHistory);
  [self saveCursorPositions: nil];
  [self stopWatchingFiles];
  RELEASE (_fileWatchers);
  RELEASE (_changedDirectories);
  [[NSNotificationCenter defaultCenter] removeObserver: self];
  [self closeFindPanel];
  RELEASE (_findPanel);
  RELEASE (_findButtons);
  RELEASE (_project);
  RELEASE (_tabView);
  RELEASE (_openDocuments);
  RELEASE (_documentTabs);
  RELEASE (_currentDocument);
  RELEASE (_editorFont);
  RELEASE (_backgroundColor);
  RELEASE (_textColor);
  [super dealloc];
}

- (void) editorFontsChanged: (NSNotification *)notification
{
  [self setEditorFont: [YCodePreferences fontForPane: @"Editor"]];
}

- (void) fileModificationChanged: (NSNotification *)notification
{
  [self synchronizeLanguageServer];
  NSEnumerator *savedDocuments = [_openDocuments objectEnumerator];
  YCodeEditorDocument *savedDocument;
  while ((savedDocument = [savedDocuments nextObject]))
    if (![savedDocument isModified])
      [_languageServer savedPath: [savedDocument filePath]];
  NSEnumerator *enumerator = [_openDocuments objectEnumerator];
  YCodeEditorDocument *document;
  while ((document = [enumerator nextObject]) != nil)
    {
      NSString *path = [document filePath];
      NSString *name = [path lastPathComponent];
      NSTabViewItem *item = [_documentTabs objectForKey: path];
      [item setLabel: [document isModified]
                         ? [@"* " stringByAppendingString: name]
                         : name];
      if ([document hasExternalChanges])
        [item setLabel: [@"! " stringByAppendingString: [item label]]];
      [item
          setToolTip:
              [document hasExternalChanges]
                  ? [path
                        stringByAppendingString:
                            @" — Changed outside Ycode; local contents preserved"]
                  : path];
    }
  [_tabView setNeedsDisplay: YES];
}

- (void) startWatchingFiles
{
  _fileWatchingStopped = NO;
  [self updateFileWatchers];
}

- (void) fileWatchingPreferencesChanged: (NSNotification *)notification
{
  [self updateFileWatchers];
}

- (void) stopWatchingFiles
{
  _fileWatchingStopped = YES;
  [_codeBrowser close];
  [NSObject
      cancelPreviousPerformRequestsWithTarget: self
                                     selector: @selector (startCodeIntelligence)
                                       object: nil];
  [_languageServer stop];
  [YCodeCompilerSettings removePreparedConfiguration: _compilerConfiguration];
  DESTROY (_compilerConfiguration);
  [self clearFileWatchers];
}

- (void) clearFileWatchers
{
  [NSObject
      cancelPreviousPerformRequestsWithTarget: self
                                     selector: @selector (checkChangedFiles)
                                       object: nil];
  [[_fileWatchers allValues] makeObjectsPerformSelector: @selector (stop)];
  [_fileWatchers removeAllObjects];
  [_changedDirectories removeAllObjects];
}

- (void) updateFileWatchers
{
  if (_fileWatchingStopped || ![YCodePreferences fileWatchingEnabled])
    {
      [self clearFileWatchers];
      return;
    }
  NSMutableDictionary *directories = [NSMutableDictionary dictionary];
  NSEnumerator *documents = [_openDocuments objectEnumerator];
  YCodeEditorDocument *document;
  while ((document = [documents nextObject]) != nil)
    {
      NSString *path = [document filePath];
      if (![document textView] || ![path isAbsolutePath])
        continue;
      NSString *directory = [path stringByDeletingLastPathComponent];
      NSMutableArray *paths = [directories objectForKey: directory];
      if (!paths)
        {
          paths = [NSMutableArray array];
          [directories setObject: paths forKey: directory];
        }
      [paths addObject: path];
    }
  NSEnumerator *keys = [[_fileWatchers allKeys] objectEnumerator];
  NSString *directory;
  while ((directory = [keys nextObject]) != nil)
    {
      YCodeFileWatcher *watcher = [_fileWatchers objectForKey: directory];
      if (![[watcher paths] isEqual: [directories objectForKey: directory]])
        {
          [watcher stop];
          [_fileWatchers removeObjectForKey: directory];
        }
    }
  keys = [directories keyEnumerator];
  while ((directory = [keys nextObject]) != nil)
    {
      if ([_fileWatchers objectForKey: directory])
        continue;
      YCodeFileWatcher *watcher = [[YCodeFileWatcher alloc]
          initWithDirectory: directory
                      paths: [directories objectForKey: directory]];
      if (watcher)
        {
          [_fileWatchers setObject: watcher forKey: directory];
          [watcher release];
        }
      else
        NSLog (@"Unable to watch open files in %@", directory);
    }
  // Close the load/subscription race without introducing periodic polling.
  [_openDocuments
      makeObjectsPerformSelector: @selector (checkForExternalChanges)];
}

- (void) directoryChanged: (NSNotification *)notification
{
  NSArray *directories =
      [_fileWatchers allKeysForObject: [notification object]];
  if (![directories count])
    return;
  BOOL scheduled = [_changedDirectories count] > 0;
  [_changedDirectories addObjectsFromArray: directories];
  if (!scheduled)
    [self performSelector: @selector (checkChangedFiles)
               withObject: nil
               afterDelay: 0.1];
}

- (void) checkChangedFiles
{
  NSEnumerator *documents = [_openDocuments objectEnumerator];
  YCodeEditorDocument *document;
  while ((document = [documents nextObject]) != nil)
    if ([_changedDirectories
            containsObject: [[document filePath]
                               stringByDeletingLastPathComponent]])
      [document checkForExternalChanges];
  [_changedDirectories removeAllObjects];
}

- (void) editorPreferencesChanged: (NSNotification *)notification
{
  // Keep the settings applied by openFile: in sync with the saved preferences.
  ASSIGN (_backgroundColor,
          [YCodeSyntaxHighlighter preferredColorForKey: @"background"]);
  ASSIGN (_textColor, [YCodeSyntaxHighlighter preferredColorForKey: @"text"]);
  _showLineNumbers = ![[NSUserDefaults standardUserDefaults]
      boolForKey: @"YCodeHideEditorRulers"];
}

#pragma mark - Project Association

- (YCodeProject *) project
{
  return _project;
}

- (void) setProject: (YCodeProject *)project
{
  if (_project != project)
    {
      [self restartCodeIntelligence: nil];
      [_definitionHistory removeAllObjects];
    }
  ASSIGN (_project, project);
  [self restoreLastSourceFile];
}

#pragma mark - Tab View Association

- (NSTabView *) tabView
{
  return _tabView;
}

- (void) setTabView: (NSTabView *)tabView
{
  ASSIGN (_tabView, tabView);
  [_tabView setDelegate: self];
  [_tabView setTabViewType: NSTopTabsBezelBorder];
  [self restoreLastSourceFile];
}

#pragma mark - Document Management

- (NSArray *) openDocuments
{
  return _openDocuments;
}

- (YCodeEditorDocument *) currentDocument
{
  return _currentDocument;
}

- (void) setCurrentDocument: (YCodeEditorDocument *)document
{
  if (_currentDocument != document)
    {
      _definitionRequest++;
      [self saveCursorPositionForDocument: _currentDocument];
      ASSIGN (_currentDocument, document);
      [NSObject cancelPreviousPerformRequestsWithTarget: self
                                               selector: @selector
                                               (startCodeIntelligence)
                                                 object: nil];
      if (_project && [document textView])
        [self performSelector: @selector (startCodeIntelligence)
                   withObject: nil
                   afterDelay: 0.4];
      [self updateFindPanel];
      [self rememberCurrentSourceFile];
      [[NSNotificationCenter defaultCenter]
          postNotificationName: YCodeCurrentDocumentDidChangeNotification
                        object: self];

      // Update tab view selection
      if (document && _tabView)
        {
          NSTabViewItem *tab = [self tabForDocument: document];
          if (tab)
            {
              [_tabView selectTabViewItem: tab];
            }
        }
    }
}

#pragma mark - Project Editor Session

- (NSString *) cursorPositionKeyForDocument: (YCodeEditorDocument *)document
{
  NSString *path = [document filePath];
  if (![path length] || ![document textView])
    return nil;
  if (![path isAbsolutePath])
    path = [[[NSFileManager defaultManager] currentDirectoryPath]
        stringByAppendingPathComponent: path];
  path = [[path stringByStandardizingPath] stringByResolvingSymlinksInPath];
  return [@"YCodeCursorPosition:" stringByAppendingString: path];
}

- (void) saveCursorPositionForDocument: (YCodeEditorDocument *)document
{
  NSString *key = [self cursorPositionKeyForDocument: document];
  if (!key)
    return;
  NSUInteger location = [document selectedRange].location;
  if (location == NSNotFound)
    return;
  [[NSUserDefaults standardUserDefaults]
      setObject: [NSNumber numberWithUnsignedInteger: location]
         forKey: key];
  [[NSUserDefaults standardUserDefaults] synchronize];
}

- (void) saveCursorPositions: (NSNotification *)notification
{
  NSEnumerator *documents = [_openDocuments objectEnumerator];
  YCodeEditorDocument *document;
  while ((document = [documents nextObject]) != nil)
    [self saveCursorPositionForDocument: document];
}

- (NSString *) lastSourceFileDefaultsKey
{
  NSString *path = [_project projectPath];
  if (![path length])
    return nil;
  if (![path isAbsolutePath])
    {
      path = [[[NSFileManager defaultManager] currentDirectoryPath]
          stringByAppendingPathComponent: path];
    }
  path = [[path stringByStandardizingPath] stringByResolvingSymlinksInPath];
  return [@"YCodeLastSourceFile:" stringByAppendingString: path];
}

- (void) rememberCurrentSourceFile
{
  NSString *key = [self lastSourceFileDefaultsKey];
  if (!key)
    return;
  NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
  NSString *path = [_currentDocument filePath];
  BOOL isDirectory = NO;
  if (!_currentDocument)
    {
      [defaults removeObjectForKey: key];
    }
  else if ([[NSFileManager defaultManager] fileExistsAtPath: path
                                                isDirectory: &isDirectory]
           && (!isDirectory ||
               [[[_currentDocument class] editorKind] isEqual: @"model"]))
    {
      if (![path isAbsolutePath])
        {
          path = [[[NSFileManager defaultManager] currentDirectoryPath]
              stringByAppendingPathComponent: path];
        }
      [defaults setObject: [path stringByStandardizingPath] forKey: key];
    }
  [defaults synchronize];
}

- (void) restoreLastSourceFile
{
  if (!_tabView || _currentDocument)
    return;
  NSString *key = [self lastSourceFileDefaultsKey];
  if (!key)
    return;
  NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
  id path = [defaults objectForKey: key];
  if (!path)
    return;
  BOOL isDirectory = NO;
  if (![path isKindOfClass: [NSString class]]
      || ![[NSFileManager defaultManager] fileExistsAtPath: path
                                               isDirectory: &isDirectory]
      || (isDirectory
          && ![[NSArray arrayWithObjects: @"gorm", @"nib", nil]
              containsObject: [[path pathExtension] lowercaseString]])
      || ![self openFile: path])
    {
      // Deleted or unreadable files must not interfere with opening the project.
      [defaults removeObjectForKey: key];
      [defaults synchronize];
    }
  else
    {
      NSTextView *textView = [_currentDocument textView];
      if (textView)
        [[textView window] makeFirstResponder: textView];
    }
}

#pragma mark - Optional Code Intelligence

- (BOOL) canGoToDefinition
{
  return [_currentDocument textView] && [YCodeLanguageServer executablePath] &&
         [YCodeLanguageServer languageIDForPath: [_currentDocument filePath]];
}

- (BOOL) canGoBack
{
  return [_definitionHistory count] > 0;
}

- (IBAction) restartCodeIntelligence: (id)sender
{
  [_codeBrowser close];
  _definitionRequest++;
  [NSObject
      cancelPreviousPerformRequestsWithTarget: self
                                     selector: @selector (startCodeIntelligence)
                                       object: nil];
  [NSObject cancelPreviousPerformRequestsWithTarget: self
                                           selector: @selector
                                           (synchronizeLanguageServer)
                                             object: nil];
  [_languageServer stop];
  DESTROY (_languageServer);
  [YCodeCompilerSettings removePreparedConfiguration: _compilerConfiguration];
  DESTROY (_compilerConfiguration);
  NSEnumerator *documents = [_openDocuments objectEnumerator];
  YCodeEditorDocument *document;
  while ((document = [documents nextObject]))
    [self clearCodeDiagnosticsForDocument: document];
  if (_project)
    [self performSelector: @selector (startCodeIntelligence)
               withObject: nil
               afterDelay: 0.4];
}

- (void) synchronizeLanguageServer
{
  if (![_languageServer isRunning])
    return;
  NSEnumerator *documents = [_openDocuments objectEnumerator];
  YCodeEditorDocument *document;
  while ((document = [documents nextObject]))
    if ([document textView])
      [_languageServer synchronizePath: [document filePath]
                                  text: [document content]];
}

- (void) languageServerTextChanged: (NSNotification *)notification
{
  if (![_languageServer isRunning]
      || !([[notification object] editedMask] & NSTextStorageEditedCharacters))
    return;
  NSEnumerator *documents = [_openDocuments objectEnumerator];
  YCodeEditorDocument *document;
  while ((document = [documents nextObject]))
    if ([[document textView] textStorage] == [notification object])
      {
        /* Layout managers have not adjusted temporary ranges until this
           text-storage notification returns. Clear them on the next turn. */
        if ([document filePath])
          [_codeDiagnostics removeObjectForKey: [document filePath]];
        [NSObject
            cancelPreviousPerformRequestsWithTarget: self
                                           selector: @selector
                                           (clearCodeDiagnosticsForDocument:)
                                             object: document];
        [self performSelector: @selector (clearCodeDiagnosticsForDocument:)
                   withObject: document
                   afterDelay: 0];
        [NSObject cancelPreviousPerformRequestsWithTarget: self
                                                 selector: @selector
                                                 (synchronizeLanguageServer)
                                                   object: nil];
        [self performSelector: @selector (synchronizeLanguageServer)
                   withObject: nil
                   afterDelay: 0.15];
        return;
      }
}

- (void) compilationDatabaseChanged: (NSNotification *)notification
{
  if ([notification object] == [_project buildSystem])
    [self restartCodeIntelligence: nil];
}

- (void) compilerSettingsChanged: (NSNotification *)notification
{
  if (![notification object] ||
      [[YCodeCompilerSettings defaultsKeyForProject: [notification object]]
          isEqual: [YCodeCompilerSettings defaultsKeyForProject: _project]])
    [self restartCodeIntelligence: nil];
}

- (BOOL) ensureLanguageServer
{
  if (![self canGoToDefinition])
    return NO;
  if (![_languageServer isRunning])
    {
      [YCodeCompilerSettings
          removePreparedConfiguration: _compilerConfiguration];
      ASSIGN (
          _compilerConfiguration,
          [YCodeCompilerSettings
              prepareConfiguration:
                  [YCodeCompilerSettings
                      configurationForProject: _project
                                   sourcePath: [_currentDocument filePath]]]);
      if ([_compilerConfiguration objectForKey: @"error"])
        return NO;
      if (!_languageServer)
        _languageServer = [[YCodeLanguageServer alloc] initWithDelegate: self];
      [_languageServer
          setCompilationDatabaseDirectory: [_compilerConfiguration
                                              objectForKey: @"directory"]];
      NSMutableArray *flags = [NSMutableArray
          arrayWithObject:
              [@"-working-directory="
                  stringByAppendingString: [_compilerConfiguration
                                              objectForKey: @"root"]]];
      [flags
          addObjectsFromArray: [_compilerConfiguration objectForKey: @"flags"]];
      [_languageServer setFallbackFlags: flags];
      if (![_languageServer
              startInDirectory: [_compilerConfiguration objectForKey: @"root"]])
        return NO;
    }
  [self synchronizeLanguageServer];
  return YES;
}

- (void) startCodeIntelligence
{
  if (_project && !_fileWatchingStopped)
    [self ensureLanguageServer];
}

- (void) requestCodeMethod: (NSString *)method
{
  if (![self ensureLanguageServer])
    {
      if ([_compilerConfiguration objectForKey: @"error"])
        NSRunAlertPanel (@"Code Intelligence Settings", @"%@", @"OK", nil, nil,
                         [_compilerConfiguration objectForKey: @"error"]);
      else
        NSBeep ();
      return;
    }
  NSDictionary *context = [NSDictionary
      dictionaryWithObjectsAndKeys:
          [_currentDocument filePath], @"path", method, @"method",
          [NSNumber numberWithUnsignedInteger: [_currentDocument selectedRange]
                                                  .location],
          @"offset", [[[_currentDocument content] copy] autorelease], @"text",
          [NSNumber numberWithUnsignedInteger: ++_definitionRequest],
          @"request", nil];
  [_languageServer requestMethod: method
                            path: [_currentDocument filePath]
                          offset: [_currentDocument selectedRange].location
                         context: context];
}

- (IBAction) goToDefinition: (id)sender
{
  [self requestCodeMethod: @"textDocument/definition"];
}

- (void) showCodeInformation: (id)sender
{
  [self requestCodeMethod: @"textDocument/hover"];
}

- (void) showDocumentSymbols: (id)sender
{
  [self requestCodeMethod: @"textDocument/documentSymbol"];
}

- (void) findReferences: (id)sender
{
  [self requestCodeMethod: @"textDocument/references"];
}

- (void) completeCode: (id)sender
{
  if ([self canGoToDefinition])
    [self requestCodeMethod: @"textDocument/completion"];
  else
    [[_currentDocument textView] complete: sender];
}

- (void) languageServer: (YCodeLanguageServer *)server
    receivedDefinition: (id)result
               context: (id)context
                 error: (NSString *)error
{
  /* Never let a delayed reply move a caret the user has since moved or edited. */
  if (server != _languageServer ||
      [[context objectForKey: @"request"] unsignedIntegerValue]
          != _definitionRequest
      || ![[_currentDocument filePath] isEqual: [context objectForKey: @"path"]]
      || [_currentDocument selectedRange].location !=
             [[context objectForKey: @"offset"] unsignedIntegerValue]
      || ![[_currentDocument content] isEqual: [context objectForKey: @"text"]])
    return;
  if (error)
    {
      NSRunAlertPanel (@"Code Intelligence", @"%@", @"OK", nil, nil, error);
      return;
    }
  NSString *method = [context objectForKey: @"method"];
  if (method && ![method isEqual: @"textDocument/definition"])
    {
      [self showSemanticResult: result context: context];
      return;
    }
  if ([result isKindOfClass: [NSArray class]])
    result = [result count] ? [result objectAtIndex: 0] : nil;
  if (![result isKindOfClass: [NSDictionary class]])
    {
      NSRunAlertPanel (
          @"Go to Definition", @"%@", @"OK", nil, nil,
          [YCodeCompilerSettings
              noDefinitionMessageForConfiguration: _compilerConfiguration]);
      return;
    }
  id uri = [result objectForKey: @"uri"] ?: [result objectForKey: @"targetUri"];
  NSURL *url =
      [uri isKindOfClass: [NSString class]] ? [NSURL URLWithString: uri] : nil;
  id range = [result objectForKey: @"range"]
                 ?: [result objectForKey: @"targetSelectionRange"];
  if (![url isFileURL] || ![range isKindOfClass: [NSDictionary class]])
    return;
  NSString *path = [url path];
  YCodeEditorDocument *target = [self documentForFilePath: path];
  NSString *text
      = target ? [target content]
               : [NSString stringWithContentsOfFile: path
                                           encoding: NSUTF8StringEncoding
                                              error: NULL];
  NSUInteger offset = text
                          ? [YCodeLanguageServer
                                offsetForPosition: [range objectForKey: @"start"]
                                           inText: text]
                          : NSNotFound;
  if (offset == NSNotFound || ![self openFile: path])
    {
      NSRunAlertPanel (@"Go to Definition",
                       @"Unable to open the definition location.", @"OK", nil,
                       nil);
      return;
    }
  [_definitionHistory
      addObject: [NSDictionary
                    dictionaryWithObjectsAndKeys: [context
                                                     objectForKey: @"path"],
                                                 @"path",
                                                 [context
                                                     objectForKey: @"offset"],
                                                 @"offset", nil]];
  if ([_definitionHistory count] > 100)
    [_definitionHistory removeObjectAtIndex: 0];
  [_currentDocument
      setSelectedRange: NSMakeRange (
                           MIN (offset, [[_currentDocument content] length]),
                           0)];
  [[[_currentDocument textView] window]
      makeFirstResponder: [_currentDocument textView]];
}

- (IBAction) goBack: (id)sender
{
  NSDictionary *location =
      [[[_definitionHistory lastObject] retain] autorelease];
  if (!location)
    return;
  _definitionRequest++;
  if ([self openFile: [location objectForKey: @"path"]])
    {
      NSUInteger offset
          = MIN ([[location objectForKey: @"offset"] unsignedIntegerValue],
                 [[_currentDocument content] length]);
      [_currentDocument setSelectedRange: NSMakeRange (offset, 0)];
      [[[_currentDocument textView] window]
          makeFirstResponder: [_currentDocument textView]];
      [_definitionHistory removeLastObject];
    }
  else
    NSRunAlertPanel (@"Go Back",
                     @"The previous source file is no longer available.",
                     @"OK", nil, nil);
}

- (YCodeCodeBrowser *) codeBrowser
{
  if (!_codeBrowser)
    _codeBrowser = [[YCodeCodeBrowser alloc] initWithTarget: self];
  return _codeBrowser;
}

- (void) quickOpenFile: (id)sender
{
  NSMutableArray *items = [NSMutableArray array];
  NSEnumerator *entries = [[_project projectFileEntries] objectEnumerator];
  NSDictionary *entry;
  while ((entry = [entries nextObject]))
    {
      NSString *path = [entry objectForKey: @"path"];
      if ([path length])
        [items addObject: [NSDictionary
                             dictionaryWithObjectsAndKeys: path, @"path", path,
                                                          @"title", nil]];
    }
  [[self codeBrowser] showItems: items title: @"Open File Quickly"];
}

- (void) appendSymbols: (NSArray *)symbols
                 path: (NSString *)path
               prefix: (NSString *)prefix
              toItems: (NSMutableArray *)items
{
  NSEnumerator *enumerator = [symbols objectEnumerator];
  NSDictionary *symbol;
  while ((symbol = [enumerator nextObject]))
    {
      if (![symbol isKindOfClass: [NSDictionary class]])
        continue;
      NSString *name = [symbol objectForKey: @"name"];
      if (![name isKindOfClass: [NSString class]])
        continue;
      NSString *title = [prefix stringByAppendingString: name];
      id location = [symbol objectForKey: @"location"];
      id range = [symbol objectForKey: @"selectionRange"]
                     ?: [symbol objectForKey: @"range"];
      NSString *target = path;
      if ([location isKindOfClass: [NSDictionary class]])
        {
          id uri = [location objectForKey: @"uri"];
          NSURL *url = [uri isKindOfClass: [NSString class]]
                           ? [NSURL URLWithString: uri]
                           : nil;
          if ([url isFileURL])
            target = [url path];
          range = [location objectForKey: @"range"];
        }
      if ([range isKindOfClass: [NSDictionary class]] &&
          [[range objectForKey: @"start"] isKindOfClass: [NSDictionary class]])
        [items addObject: [NSDictionary
                             dictionaryWithObjectsAndKeys:
                                 title, @"title", target, @"path",
                                 [range objectForKey: @"start"], @"position",
                                 [symbol objectForKey: @"detail"] ?: title,
                                 @"detail", nil]];
      if ([[symbol objectForKey: @"children"] isKindOfClass: [NSArray class]])
        [self appendSymbols: [symbol objectForKey: @"children"]
                       path: target
                     prefix: [title stringByAppendingString: @" › "]
                    toItems: items];
    }
}

- (void) showSemanticResult: (id)result context: (NSDictionary *)context
{
  NSString *method = [context objectForKey: @"method"];
  NSMutableArray *items = [NSMutableArray array];
  NSString *title = @"Code Information";
  if ([method isEqual: @"textDocument/hover"])
    {
      id contents = [result isKindOfClass: [NSDictionary class]]
                        ? [result objectForKey: @"contents"]
                        : nil;
      NSArray *parts = [contents isKindOfClass: [NSArray class]] ? contents
                       : contents && contents != [NSNull null]
                           ? [NSArray arrayWithObject: contents]
                           : [NSArray array];
      NSMutableArray *text = [NSMutableArray array];
      NSEnumerator *enumerator = [parts objectEnumerator];
      id part;
      while ((part = [enumerator nextObject]))
        {
          id value = [part isKindOfClass: [NSDictionary class]]
                         ? [part objectForKey: @"value"]
                         : part;
          if ([value isKindOfClass: [NSString class]])
            [text addObject: value];
        }
      NSString *detail = [text componentsJoinedByString: @"\n\n"];
      if ([detail length])
        [items addObject: [NSDictionary dictionaryWithObjectsAndKeys:
                                           @"Type and documentation", @"title",
                                           detail, @"detail", nil]];
    }
  else if ([method isEqual: @"textDocument/documentSymbol"])
    {
      title = @"Document Symbols";
      if ([result isKindOfClass: [NSArray class]])
        [self appendSymbols: result
                       path: [context objectForKey: @"path"]
                     prefix: @""
                    toItems: items];
    }
  else if ([method isEqual: @"textDocument/references"])
    {
      title = @"References";
      NSEnumerator *enumerator = [result isKindOfClass: [NSArray class]]
                                     ? [result objectEnumerator]
                                     : nil;
      NSDictionary *location;
      while ((location = [enumerator nextObject]))
        {
          if (![location isKindOfClass: [NSDictionary class]])
            continue;
          id uri = [location objectForKey: @"uri"],
             range = [location objectForKey: @"range"];
          NSURL *url = [uri isKindOfClass: [NSString class]]
                           ? [NSURL URLWithString: uri]
                           : nil;
          id position = [range isKindOfClass: [NSDictionary class]]
                            ? [range objectForKey: @"start"]
                            : nil;
          if ([url isFileURL] && [position isKindOfClass: [NSDictionary class]])
            [items
                addObject: [NSDictionary
                              dictionaryWithObjectsAndKeys:
                                  [url path], @"path", position, @"position",
                                  [NSString stringWithFormat:
                                                @"%@:%lu", [url path],
                                                (unsigned long)[[position
                                                    objectForKey: @"line"]
                                                    unsignedIntegerValue]
                                                    + 1],
                                  @"title", nil]];
        }
    }
  else if ([method isEqual: @"textDocument/completion"])
    {
      title = @"Code Completion";
      id candidates = [result isKindOfClass: [NSDictionary class]]
                          ? [result objectForKey: @"items"]
                          : result;
      NSEnumerator *enumerator = [candidates isKindOfClass: [NSArray class]]
                                     ? [candidates objectEnumerator]
                                     : nil;
      NSDictionary *candidate;
      while ((candidate = [enumerator nextObject]))
        {
          if (![candidate isKindOfClass: [NSDictionary class]] ||
              [[candidate objectForKey: @"insertTextFormat"] integerValue] == 2
              || [[candidate objectForKey: @"additionalTextEdits"] count])
            continue;
          NSString *label = [candidate objectForKey: @"label"];
          if (![label isKindOfClass: [NSString class]])
            continue;
          [items addObject: [NSDictionary
                               dictionaryWithObjectsAndKeys:
                                   label, @"title",
                                   [candidate objectForKey: @"detail"] ?: label,
                                   @"detail", candidate, @"completion",
                                   context, @"context", nil]];
        }
      if (![items count])
        {
          [[_currentDocument textView] complete: nil];
          return;
        }
    }
  [[self codeBrowser] showItems: items title: title];
}

- (void) activateCodeItem: (NSDictionary *)item
{
  NSDictionary *completion = [item objectForKey: @"completion"];
  if (completion)
    {
      NSDictionary *context = [item objectForKey: @"context"];
      NSTextView *view = [_currentDocument textView];
      if (![[_currentDocument filePath] isEqual: [context objectForKey: @"path"]]
          || ![[view string] isEqual: [context objectForKey: @"text"]] ||
          [view selectedRange].location !=
              [[context objectForKey: @"offset"] unsignedIntegerValue])
        {
          [_codeBrowser close];
          return;
        }
      NSRange replacement = [view rangeForUserCompletion];
      if (replacement.location == NSNotFound)
        replacement = [view selectedRange];
      id edit = [completion objectForKey: @"textEdit"];
      NSString *text = [completion objectForKey: @"insertText"]
                           ?: [completion objectForKey: @"label"];
      if ([edit isKindOfClass: [NSDictionary class]])
        {
          id range =
              [edit objectForKey: @"range"] ?: [edit objectForKey: @"replace"];
          if (![range isKindOfClass: [NSDictionary class]])
            return;
          NSUInteger start = [YCodeLanguageServer
              offsetForPosition: [range objectForKey: @"start"]
                         inText: [view string]];
          NSUInteger end = [YCodeLanguageServer
              offsetForPosition: [range objectForKey: @"end"]
                         inText: [view string]];
          if (start == NSNotFound || end == NSNotFound || end < start)
            return;
          replacement = NSMakeRange (start, end - start);
          text = [edit objectForKey: @"newText"];
        }
      if (![text isKindOfClass: [NSString class]])
        return;
      [_codeBrowser close];
      if ([view shouldChangeTextInRange: replacement replacementString: text])
        {
          [[view textStorage] replaceCharactersInRange: replacement
                                            withString: text];
          [view didChangeText];
          [view setSelectedRange: NSMakeRange (
                                     replacement.location + [text length], 0)];
        }
      [[view window] makeKeyAndOrderFront: nil];
      [[view window] makeFirstResponder: view];
      return;
    }
  NSString *path = [item objectForKey: @"path"];
  if (!path)
    return;
  NSString *oldPath = [[_currentDocument filePath] copy];
  NSUInteger oldOffset = _currentDocument
                             ? [_currentDocument selectedRange].location
                             : NSNotFound;
  if ([self openFile: path])
    {
      if (oldPath && oldOffset != NSNotFound)
        [_definitionHistory
            addObject: [NSDictionary
                          dictionaryWithObjectsAndKeys:
                              oldPath, @"path",
                              [NSNumber numberWithUnsignedInteger: oldOffset],
                              @"offset", nil]];
      id position = [item objectForKey: @"position"];
      if (position)
        {
          NSUInteger offset = [YCodeLanguageServer
              offsetForPosition: position
                         inText: [_currentDocument content]];
          if (offset != NSNotFound)
            [_currentDocument setSelectedRange: NSMakeRange (offset, 0)];
        }
      [_codeBrowser close];
      [[[_currentDocument textView] window] makeKeyAndOrderFront: nil];
      [[[_currentDocument textView] window]
          makeFirstResponder: [_currentDocument textView]];
    }
  [oldPath release];
}

- (void) clearCodeDiagnosticsForDocument: (YCodeEditorDocument *)document
{
  [NSObject cancelPreviousPerformRequestsWithTarget: self
                                           selector: @selector
                                           (clearCodeDiagnosticsForDocument:)
                                             object: document];
  if (!document)
    return;
  NSLayoutManager *layout = [[document textView] layoutManager];
  NSRange range = NSMakeRange (0, [[document content] length]);
  [layout removeTemporaryAttribute: NSUnderlineStyleAttributeName
                 forCharacterRange: range];
  [layout removeTemporaryAttribute: NSUnderlineColorAttributeName
                 forCharacterRange: range];
  if ([document filePath])
    [_codeDiagnostics removeObjectForKey: [document filePath]];
  if ([_codeBrowser isShowingTitle: @"Live Diagnostics"])
    [self refreshCodeDiagnostics];
}

- (void) languageServer: (YCodeLanguageServer *)server
           diagnostics: (NSArray *)diagnostics
               forPath: (NSString *)path
                  text: (NSString *)text
{
  YCodeEditorDocument *document = [self documentForFilePath: path];
  if (server != _languageServer || !document
      || ![[document content] isEqual: text])
    return;
  [self clearCodeDiagnosticsForDocument: document];
  NSMutableArray *items = [NSMutableArray array];
  NSEnumerator *enumerator = [diagnostics objectEnumerator];
  NSDictionary *diagnostic;
  while ((diagnostic = [enumerator nextObject]))
    {
      if (![diagnostic isKindOfClass: [NSDictionary class]])
        continue;
      id range = [diagnostic objectForKey: @"range"],
         message = [diagnostic objectForKey: @"message"];
      if (![range isKindOfClass: [NSDictionary class]]
          || ![message isKindOfClass: [NSString class]])
        continue;
      NSUInteger start =
          [YCodeLanguageServer offsetForPosition: [range objectForKey: @"start"]
                                          inText: text];
      NSUInteger end =
          [YCodeLanguageServer offsetForPosition: [range objectForKey: @"end"]
                                          inText: text];
      if (start == NSNotFound || end == NSNotFound || end < start)
        continue;
      NSInteger severity =
          [[diagnostic objectForKey: @"severity"] integerValue];
      NSString *label = severity == 1   ? @"Error"
                        : severity == 2 ? @"Warning"
                                        : @"Note";
      [items addObject: [NSDictionary
                           dictionaryWithObjectsAndKeys:
                               path, @"path", [range objectForKey: @"start"],
                               @"position",
                               [NSString
                                   stringWithFormat: @"%@:%lu — %@: %@",
                                                    [path lastPathComponent],
                                                    (unsigned long)[[[range
                                                        objectForKey: @"start"]
                                                        objectForKey: @"line"]
                                                        unsignedIntegerValue]
                                                        + 1,
                                                    label, message],
                               @"title", message, @"detail", nil]];
      if (start < [text length])
        {
          NSRange underline
              = NSMakeRange (start, MIN (MAX ((NSUInteger)1, end - start),
                                         [text length] - start));
          [[[document textView] layoutManager]
              addTemporaryAttributes:
                  [NSDictionary
                      dictionaryWithObjectsAndKeys:
                          [NSNumber numberWithInt: NSUnderlineStyleSingle],
                          NSUnderlineStyleAttributeName,
                          severity == 1 ? [NSColor redColor]
                                        : [NSColor orangeColor],
                          NSUnderlineColorAttributeName, nil]
                   forCharacterRange: underline];
        }
    }
  [_codeDiagnostics setObject: items forKey: path];
  if ([_codeBrowser isShowingTitle: @"Live Diagnostics"])
    [self refreshCodeDiagnostics];
}

- (void) refreshCodeDiagnostics
{
  NSMutableArray *items = [NSMutableArray array];
  NSEnumerator *enumerator = [[[_codeDiagnostics allKeys]
      sortedArrayUsingSelector: @selector (compare:)] objectEnumerator];
  NSString *path;
  while ((path = [enumerator nextObject]))
    [items addObjectsFromArray: [_codeDiagnostics objectForKey: path]];
  [[self codeBrowser] updateItems: items];
}

- (void) showCodeDiagnostics: (id)sender
{
  [self ensureLanguageServer];
  [[self codeBrowser] showItems: [NSArray array] title: @"Live Diagnostics"];
  [self refreshCodeDiagnostics];
}

#pragma mark - File Operations

- (BOOL) openFile: (NSString *)filePath
{
  if (!filePath || [filePath length] == 0)
    {
      return NO;
    }

  // Check if file is already open
  YCodeEditorDocument *existingDoc = [self documentForFilePath: filePath];
  if (existingDoc)
    {
      [self setCurrentDocument: existingDoc];
      return YES;
    }

  // Create new document
  YCodeEditorDocument *document =
      [[YCodeEditorDocument alloc] initWithFilePath: filePath];
  [document setEditorController: self];

  // Apply editor settings
  NSTextView *textView = [document textView];
  if (textView)
    {
      [textView setFont: _editorFont];
      [textView setBackgroundColor: _backgroundColor];
      [textView setTextColor: _textColor];
    }

  // Load file content
  if ([document loadFromFile])
    {
      [_openDocuments addObject: document];

      // Create tab
      NSTabViewItem *tabItem =
          [[YCodeEditorTabItem alloc] initWithIdentifier: filePath];
      [tabItem setLabel: [filePath lastPathComponent]];
      [tabItem setView: [document editorView]];
      /* Avoid GNUstep key-loop reconstruction through a closed tab. */
      [tabItem setInitialFirstResponder: [document textView]
                                            ?: [document editorView]];
      [tabItem setToolTip: filePath];

      if (_tabView)
        {
          [_tabView addTabViewItem: tabItem];
        }

      [_documentTabs setObject: tabItem forKey: filePath];
      [self updateFileWatchers];
      [self setCurrentDocument: document];
      // Restore known files; unseen files begin at the first character.
      NSString *key = [self cursorPositionKeyForDocument: document];
      id saved = key ? [[NSUserDefaults standardUserDefaults] objectForKey: key]
                     : nil;
      NSUInteger location = 0;
      if ([saved isKindOfClass: [NSNumber class]] && [saved doubleValue] >= 0)
        location
            = MIN ([saved unsignedIntegerValue], [[textView string] length]);
      [document setSelectedRange: NSMakeRange (location, 0)];

      [self synchronizeLanguageServer];
      RELEASE (tabItem);
      RELEASE (document);
      return YES;
    }
  else
    {
      RELEASE (document);
      return NO;
    }
}

- (BOOL) confirmClosingDocument: (YCodeEditorDocument *)document
{
  // Check for unsaved changes
  if ([document isModified])
    {
      NSAlert *alert = [[NSAlert alloc] init];
      [alert
          setMessageText: [NSString
                             stringWithFormat:
                                 @"Do you want to save the changes to \"%@\"?",
                                 [document fileName]]];
      [alert setInformativeText:
                 @"Your changes will be lost if you don't save them."];
      [alert addButtonWithTitle: @"Save"];
      [alert addButtonWithTitle: @"Don't Save"];
      [alert addButtonWithTitle: @"Cancel"];

      NSInteger result = [alert runModal];
      RELEASE (alert);

      if (result == NSAlertThirdButtonReturn)
        {
          return NO; // Cancel
        }
      else if (result == NSAlertFirstButtonReturn)
        {
          if (![document saveToFile])
            {
              return NO; // Save failed
            }
        }
    }

  return YES;
}

- (BOOL) canCloseFiles
{
  NSEnumerator *documents = [[self openDocuments] objectEnumerator];
  YCodeEditorDocument *document;
  while ((document = [documents nextObject]) != nil)
    if (![self confirmClosingDocument: document])
      return NO;
  [self saveCursorPositions: nil];
  return YES;
}

- (BOOL) closeFile: (NSString *)filePath
{
  YCodeEditorDocument *document = [self documentForFilePath: filePath];
  if (!document)
    {
      return NO;
    }

  if (![self confirmClosingDocument: document])
    return NO;

  [self saveCursorPositionForDocument: document];

  [self clearCodeDiagnosticsForDocument: document];
  [_languageServer closePath: [document filePath]];

  // Remove tab
  NSTabViewItem *tabItem = [_documentTabs objectForKey: filePath];
  if (tabItem && _tabView)
    {
      [_tabView removeTabViewItem: tabItem];
    }
  [_documentTabs removeObjectForKey: filePath];

  // Remove document
  [_openDocuments removeObject: document];
  [self updateFileWatchers];

  // Update current document
  if (_currentDocument == document)
    {
      if ([_openDocuments count] > 0)
        {
          [self setCurrentDocument: [_openDocuments lastObject]];
        }
      else
        {
          [self setCurrentDocument: nil];
        }
    }

  return YES;
}

- (BOOL) saveCurrentFile
{
  if (_currentDocument)
    {
      return [_currentDocument saveToFile];
    }
  return NO;
}

- (BOOL) saveAllFiles
{
  BOOL allSaved = YES;
  NSEnumerator *enumerator = [_openDocuments objectEnumerator];
  YCodeEditorDocument *document;

  while ((document = [enumerator nextObject]) != nil)
    {
      if ([document isModified])
        {
          if (![document saveToFile])
            {
              allSaved = NO;
            }
        }
    }

  return allSaved;
}

#pragma mark - Document Operations

- (YCodeEditorDocument *) documentForFilePath: (NSString *)filePath
{
  NSEnumerator *enumerator = [_openDocuments objectEnumerator];
  YCodeEditorDocument *document;

  while ((document = [enumerator nextObject]) != nil)
    {
      if ([[document filePath] isEqualToString: filePath])
        {
          return document;
        }
    }

  return nil;
}

- (NSTabViewItem *) tabForDocument: (YCodeEditorDocument *)document
{
  if (document)
    {
      return [_documentTabs objectForKey: [document filePath]];
    }
  return nil;
}

#pragma mark - Editor Settings

- (NSFont *) editorFont
{
  return _editorFont;
}

- (void) setEditorFont: (NSFont *)font
{
  ASSIGN (_editorFont, font);

  // Apply to all open documents
  NSEnumerator *enumerator = [_openDocuments objectEnumerator];
  YCodeEditorDocument *document;

  while ((document = [enumerator nextObject]) != nil)
    {
      [[document textView] setFont: font];
      [[document textView] sizeToFit];
      [[[document scrollView] horizontalRulerView] setNeedsDisplay: YES];
      [[[document scrollView] verticalRulerView] setNeedsDisplay: YES];
    }
}

- (NSColor *) backgroundColor
{
  return _backgroundColor;
}

- (void) setBackgroundColor: (NSColor *)color
{
  ASSIGN (_backgroundColor, color);
  ASSIGN (_textColor,
          [YCodeSyntaxHighlighter plainTextColorForBackground: color]);

  // Apply to all open documents
  NSEnumerator *enumerator = [_openDocuments objectEnumerator];
  YCodeEditorDocument *document;

  while ((document = [enumerator nextObject]) != nil)
    {
      [[document textView] setBackgroundColor: color];
      [[document textView] setTextColor: _textColor];
      [document applySyntaxHighlighting];
    }
}

- (NSColor *) textColor
{
  return _textColor;
}

- (void) setTextColor: (NSColor *)color
{
  color =
      [YCodeSyntaxHighlighter plainTextColorForBackground: _backgroundColor];
  ASSIGN (_textColor, color);

  // Apply to all open documents
  NSEnumerator *enumerator = [_openDocuments objectEnumerator];
  YCodeEditorDocument *document;

  while ((document = [enumerator nextObject]) != nil)
    {
      [[document textView] setTextColor: color];
      [document applySyntaxHighlighting];
    }
}

- (BOOL) showLineNumbers
{
  return _showLineNumbers;
}

- (void) setShowLineNumbers: (BOOL)show
{
  _showLineNumbers = show;
  // TODO: Update line number display in all documents
}

- (BOOL) syntaxHighlighting
{
  return _syntaxHighlighting;
}

- (void) setSyntaxHighlighting: (BOOL)highlighting
{
  _syntaxHighlighting = highlighting;

  // Apply to all open documents
  NSEnumerator *enumerator = [_openDocuments objectEnumerator];
  YCodeEditorDocument *document;

  while ((document = [enumerator nextObject]) != nil)
    {
      [document applySyntaxHighlighting];
    }
}

#pragma mark - Editor Actions

- (IBAction) newFile: (id)sender
{
  // Create new untitled document
  static NSInteger untitledCounter = 1;
  NSString *fileName =
      [NSString stringWithFormat: @"Untitled-%ld", (long)untitledCounter++];

  YCodeEditorDocument *document =
      [[YCodeEditorDocument alloc] initWithFilePath: fileName content: @""];
  if (!document)
    {
      NSBeep ();
      return;
    }
  [document setEditorController: self];
  [_openDocuments addObject: document];

  // Create tab
  NSTabViewItem *tabItem =
      [[YCodeEditorTabItem alloc] initWithIdentifier: fileName];
  [tabItem setLabel: fileName];
  [tabItem setView: [document editorView]];
  /* Avoid GNUstep key-loop reconstruction through a closed tab. */
  [tabItem
      setInitialFirstResponder: [document textView] ?: [document editorView]];

  if (_tabView)
    {
      [_tabView addTabViewItem: tabItem];
    }

  [_documentTabs setObject: tabItem forKey: fileName];
  [self setCurrentDocument: document];

  RELEASE (tabItem);
  RELEASE (document);
}

- (IBAction) saveFile: (id)sender
{
  [self saveCurrentFile];
}

- (IBAction) closeCurrentFile: (id)sender
{
  if (_currentDocument)
    {
      [self closeFile: [_currentDocument filePath]];
    }
}

- (void) updateFindPanel
{
  if (!_findPanel)
    return;
  BOOL enabled = [_currentDocument textView] != nil;
  [_findPanel
      setTitle: enabled
                   ? [NSString stringWithFormat: @"Find / Replace — %@",
                                                [_currentDocument fileName]]
                   : @"Find / Replace"];
  [_findStatus
      setStringValue: enabled ? @"" : @"Open a text file to find or replace."];
  NSEnumerator *buttons = [_findButtons objectEnumerator];
  NSButton *button;
  while ((button = [buttons nextObject]) != nil)
    [button setEnabled: enabled];
}

- (void) createFindPanel
{
  if (_findPanel)
    return;
  _findPanel = [[NSPanel alloc]
      initWithContentRect: NSMakeRect (0, 0, 560, 224)
                styleMask: NSTitledWindowMask | NSClosableWindowMask
                  backing: NSBackingStoreBuffered
                    defer: NO];
  [_findPanel setReleasedWhenClosed: NO];
  [_findPanel setFloatingPanel: YES];
  [_findPanel setHidesOnDeactivate: YES];
  NSView *content = [_findPanel contentView];
  NSArray *labels = [NSArray arrayWithObjects: @"Find:", @"Replace:", nil];
  NSUInteger i;
  for (i = 0; i < 2; i++)
    {
      CGFloat y = 182 - i * 36;
      NSTextField *label =
          [[NSTextField alloc] initWithFrame: NSMakeRect (16, y, 76, 24)];
      [label setStringValue: [labels objectAtIndex: i]];
      [label setEditable: NO];
      [label setSelectable: NO];
      [label setBezeled: NO];
      [label setDrawsBackground: NO];
      [content addSubview: label];
      RELEASE (label);
      NSTextField *field =
          [[NSTextField alloc] initWithFrame: NSMakeRect (96, y, 448, 26)];
      [field setTarget: self];
      [field setAction: @selector (findNext:)];
      [content addSubview: field];
      if (i == 0)
        _findField = field;
      else
        _replaceField = field;
      RELEASE (field);
    }
  _findCaseSensitive =
      [[NSButton alloc] initWithFrame: NSMakeRect (96, 112, 170, 24)];
  [_findCaseSensitive setButtonType: NSSwitchButton];
  [_findCaseSensitive setTitle: @"Case sensitive"];
  [content addSubview: _findCaseSensitive];
  RELEASE (_findCaseSensitive);
  _findWrap = [[NSButton alloc] initWithFrame: NSMakeRect (290, 112, 180, 24)];
  [_findWrap setButtonType: NSSwitchButton];
  [_findWrap setTitle: @"Wrap around"];
  [_findWrap setState: NSOnState];
  [content addSubview: _findWrap];
  RELEASE (_findWrap);
  NSArray *titles =
      [NSArray arrayWithObjects: @"Previous", @"Next", @"Replace",
                                @"Replace & Find", @"Replace All", nil];
  NSArray *actions = [NSArray
      arrayWithObjects: @"findPrevious:", @"findNext:", @"replaceMatch:",
                       @"replaceAndFind:", @"replaceAll:", nil];
  _findButtons = [[NSMutableArray alloc] init];
  CGFloat x = 12;
  for (i = 0; i < [titles count]; i++)
    {
      CGFloat width = i == 3 ? 136 : 100;
      NSButton *button =
          [[NSButton alloc] initWithFrame: NSMakeRect (x, 64, width, 32)];
      [button setTitle: [titles objectAtIndex: i]];
      [button setBezelStyle: NSRoundedBezelStyle];
      [button setTarget: self];
      [button setAction: NSSelectorFromString ([actions objectAtIndex: i])];
      [content addSubview: button];
      [_findButtons addObject: button];
      RELEASE (button);
      x += width;
    }
  _findStatus =
      [[NSTextField alloc] initWithFrame: NSMakeRect (16, 16, 528, 32)];
  [_findStatus setEditable: NO];
  [_findStatus setSelectable: YES];
  [_findStatus setBezeled: NO];
  [_findStatus setDrawsBackground: NO];
  [content addSubview: _findStatus];
  RELEASE (_findStatus);
  [_findField setNextKeyView: _replaceField];
  [_replaceField setNextKeyView: _findCaseSensitive];
  [_findCaseSensitive setNextKeyView: _findWrap];
  [_findWrap setNextKeyView: _findField];
  [_findPanel center];
}

- (void) showFindPanelForReplacement: (BOOL)replacement
{
  [self createFindPanel];
  [self updateFindPanel];
  NSString *selected = [_currentDocument selectedText];
  if ([selected length] &&
      [selected rangeOfCharacterFromSet: [NSCharacterSet newlineCharacterSet]]
              .location
          == NSNotFound)
    [_findField setStringValue: selected];
  [_findPanel makeKeyAndOrderFront: nil];
  NSTextField *focus = replacement && [[_findField stringValue] length]
                           ? _replaceField
                           : _findField;
  [_findPanel makeFirstResponder: focus];
  [focus selectText: nil];
}

- (void) closeFindPanel
{
  [_findPanel orderOut: nil];
}

- (IBAction) findInFile: (id)sender
{
  [self showFindPanelForReplacement: NO];
}

- (IBAction) replaceInFile: (id)sender
{
  [self showFindPanelForReplacement: YES];
}

- (NSUInteger) findOptions
{
  return [_findCaseSensitive state] == NSOnState ? 0 : NSCaseInsensitiveSearch;
}

- (BOOL) findBackwards: (BOOL)backwards
{
  NSTextView *view = [_currentDocument textView];
  NSString *needle = [_findField stringValue];
  if (!view || ![needle length])
    {
      [_findStatus
          setStringValue: view ? @"Enter text to find."
                              : @"Open a text file to find or replace."];
      return NO;
    }
  NSString *text = [view string];
  NSRange selection = [view selectedRange];
  NSUInteger start = MIN (
      backwards ? selection.location : NSMaxRange (selection), [text length]);
  NSUInteger options =
      [self findOptions] | (backwards ? NSBackwardsSearch : 0);
  NSRange range = backwards ? NSMakeRange (0, start)
                            : NSMakeRange (start, [text length] - start);
  NSRange found = [text rangeOfString: needle options: options range: range];
  BOOL wrapped = NO;
  if (found.location == NSNotFound && [_findWrap state] == NSOnState)
    {
      range = backwards ? NSMakeRange (start, [text length] - start)
                        : NSMakeRange (0, start);
      found = [text rangeOfString: needle options: options range: range];
      wrapped = found.location != NSNotFound;
    }
  if (found.location == NSNotFound)
    {
      [_findStatus setStringValue: @"No match found."];
      return NO;
    }
  [view setSelectedRange: found];
  [view scrollRangeToVisible: found];
  [_findStatus setStringValue: wrapped ? @"Match found (wrapped around)."
                                      : @"Match found."];
  return YES;
}

- (IBAction) findNext: (id)sender
{
  [self findBackwards: NO];
}

- (IBAction) findPrevious: (id)sender
{
  [self findBackwards: YES];
}

- (BOOL) replaceRange: (NSRange)range
          withString: (NSString *)replacement
          actionName: (NSString *)name
{
  NSTextView *view = [_currentDocument textView];
  if (!view || ![view isEditable])
    return NO;
  if ([[[view string] substringWithRange: range] isEqual: replacement])
    return YES;
  NSUndoManager *undo = [view undoManager];
  [undo beginUndoGrouping];
  BOOL allowed = [view shouldChangeTextInRange: range
                             replacementString: replacement];
  if (allowed)
    {
      [[view textStorage] replaceCharactersInRange: range
                                        withString: replacement];
      [view
          setSelectedRange: NSMakeRange (range.location, [replacement length])];
      [view didChangeText];
      [undo setActionName: name];
    }
  [undo endUndoGrouping];
  return allowed;
}

- (BOOL) replaceSelectedMatch
{
  NSTextView *view = [_currentDocument textView];
  NSString *needle = [_findField stringValue];
  if (!view || ![needle length])
    return NO;
  NSRange selection = [view selectedRange];
  NSRange match = [[view string] rangeOfString: needle
                                       options: [self findOptions]
                                         range: selection];
  if (!selection.length || !NSEqualRanges (match, selection))
    return NO;
  return [self replaceRange: selection
                 withString: [_replaceField stringValue]
                 actionName: @"Replace"];
}

- (IBAction) replaceMatch: (id)sender
{
  if ([self replaceSelectedMatch])
    [_findStatus setStringValue: @"Replaced one match."];
  else
    [self findNext: sender];
}

- (IBAction) replaceAndFind: (id)sender
{
  [self replaceSelectedMatch];
  [self findNext: sender];
}

- (IBAction) replaceAll: (id)sender
{
  NSTextView *view = [_currentDocument textView];
  NSString *needle = [_findField stringValue];
  if (!view || ![needle length])
    {
      [self findNext: sender];
      return;
    }
  NSString *text = [view string];
  NSString *replacement = [_replaceField stringValue];
  NSMutableString *result = [NSMutableString string];
  NSUInteger position = 0, count = 0;
  while (position < [text length])
    {
      NSRange match = [text
          rangeOfString: needle
                options: [self findOptions]
                  range: NSMakeRange (position, [text length] - position)];
      if (match.location == NSNotFound)
        break;
      [result
          appendString: [text substringWithRange: NSMakeRange (position,
                                                             match.location
                                                                 - position)]];
      [result appendString: replacement];
      position = NSMaxRange (match);
      count++;
    }
  [result appendString: [text substringFromIndex: position]];
  if (count
      && ![self replaceRange: NSMakeRange (0, [text length])
                  withString: result
                  actionName: @"Replace All"])
    [_findStatus setStringValue: @"Unable to replace matches."];
  else
    [_findStatus
        setStringValue: [NSString stringWithFormat: @"Replaced %lu match%@.",
                                                  (unsigned long)count,
                                                  count == 1 ? @"" : @"es"]];
}

#pragma mark - NSTabViewDelegate

- (void) tabView: (NSTabView *)tabView
    didSelectTabViewItem: (NSTabViewItem *)tabViewItem
{
  NSString *filePath = [tabViewItem identifier];
  YCodeEditorDocument *document = [self documentForFilePath: filePath];
  if (document)
    {
      [self setCurrentDocument: document];
    }
}

- (BOOL) tabView: (NSTabView *)tabView
    shouldSelectTabViewItem: (NSTabViewItem *)tabViewItem
{
  return YES;
}

@end
