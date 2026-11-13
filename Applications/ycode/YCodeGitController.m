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

#import "YCodeGitController.h"
#import "YCodeWindowController.h"
#import "YCodeProject.h"
#import "YCodeEditorController.h"
#import "YCodeEditorDocument.h"

@implementation YCodeGitController
- (id) initWithWindowController: (YCodeWindowController *)owner
{
  if ((self = [super init]))
    {
      _owner = owner;
      _directory = [[[owner project] projectDirectoryPath] copy];
      _buttons = [NSMutableArray new];
      _entries = [NSArray new];
      _panel = [[NSPanel alloc]
          initWithContentRect: NSMakeRect (140, 160, 900, 620)
                    styleMask: NSTitledWindowMask | NSClosableWindowMask
                              | NSResizableWindowMask
                      backing: NSBackingStoreBuffered
                        defer: NO];
      [_panel setReleasedWhenClosed: NO];
      [_panel setTitle: @"Source Control"];
      [_panel setMinSize: NSMakeSize (900, 520)];
      NSView *content = [_panel contentView];
      NSArray *titles = [NSArray
          arrayWithObjects: @"Refresh", @"Open File", @"Diff", @"Staged Diff",
                           @"Stage", @"Unstage", @"History", @"Cancel", nil];
      NSArray *actions =
          [NSArray arrayWithObjects: @"refresh:", @"openFile:", @"diff:",
                                    @"stagedDiff:", @"stage:", @"unstage:",
                                    @"history:", @"cancel:", nil];
      NSUInteger i;
      for (i = 0; i < [titles count]; i++)
        {
          NSButton *button = AUTORELEASE ([[NSButton alloc]
              initWithFrame: NSMakeRect (12 + i * 110, 576, 106, 30)]);
          [button setTitle: [titles objectAtIndex: i]];
          [button setBezelStyle: NSRoundedBezelStyle];
          [button setTarget: self];
          [button setAction: NSSelectorFromString ([actions objectAtIndex: i])];
          [button setAutoresizingMask: NSViewMinYMargin];
          [content addSubview: button];
          [_buttons addObject: button];
        }
      NSScrollView *scroll = AUTORELEASE (
          [[NSScrollView alloc] initWithFrame: NSMakeRect (12, 376, 876, 190)]);
      [scroll setHasVerticalScroller: YES];
      [scroll setHasHorizontalScroller: YES];
      [scroll setAutoresizingMask: NSViewWidthSizable | NSViewMinYMargin];
      _table = [[NSTableView alloc] initWithFrame: [scroll bounds]];
      NSTableColumn *column
          = AUTORELEASE ([[NSTableColumn alloc] initWithIdentifier: @"status"]);
      [[column headerCell] setStringValue: @"Index / Worktree"];
      [column setWidth: 120];
      [column setEditable: NO];
      [_table addTableColumn: column];
      column
          = AUTORELEASE ([[NSTableColumn alloc] initWithIdentifier: @"path"]);
      [[column headerCell]
          setStringValue:
              @"Repository-relative path (double-click to edit / resolve conflicts)"];
      [column setWidth: 730];
      [column setEditable: NO];
      [_table addTableColumn: column];
      [_table setAllowsMultipleSelection: YES];
      [_table setDataSource: self];
      [_table setDelegate: self];
      [_table setTarget: self];
      [_table setDoubleAction: @selector (openFile:)];
      [scroll setDocumentView: _table];
      [content addSubview: scroll];
      scroll = AUTORELEASE (
          [[NSScrollView alloc] initWithFrame: NSMakeRect (12, 112, 876, 254)]);
      [scroll setHasVerticalScroller: YES];
      [scroll setHasHorizontalScroller: YES];
      [scroll setAutoresizingMask: NSViewWidthSizable | NSViewHeightSizable];
      _details = [[NSTextView alloc] initWithFrame: [scroll bounds]];
      [_details setEditable: NO];
      [_details setFont: [NSFont userFixedPitchFontOfSize: 12]];
      [_details setAutoresizingMask: NSViewWidthSizable];
      [scroll setDocumentView: _details];
      [content addSubview: scroll];
      _message =
          [[NSTextField alloc] initWithFrame: NSMakeRect (12, 74, 658, 26)];
      [[_message cell]
          setPlaceholderString:
              @"Commit message (commits all staged changes in this repository)"];
      [_message setAutoresizingMask: NSViewWidthSizable];
      [content addSubview: _message];
      NSButton *commit = AUTORELEASE (
          [[NSButton alloc] initWithFrame: NSMakeRect (678, 72, 210, 30)]);
      [commit setTitle: @"Commit Staged Changes"];
      [commit setBezelStyle: NSRoundedBezelStyle];
      [commit setTarget: self];
      [commit setAction: @selector (commit:)];
      [commit setAutoresizingMask: NSViewMinXMargin];
      [content addSubview: commit];
      [_buttons addObject: commit];
      _status =
          [[NSTextField alloc] initWithFrame: NSMakeRect (12, 8, 876, 56)];
      [_status setEditable: NO];
      [_status setSelectable: NO];
      [_status setBezeled: NO];
      [_status setDrawsBackground: NO];
      [_status setAutoresizingMask: NSViewWidthSizable];
      [content addSubview: _status];
      [_panel setInitialFirstResponder: _table];
      [self updateControls];
    }
  return self;
}

- (void) dealloc
{
  [self close];
  [_panel release];
  [_table release];
  [_details release];
  [_message release];
  [_status release];
  [_buttons release];
  [_entries release];
  [_directory release];
  [_root release];
  [_operation release];
  [_pendingPaths release];
  [_output release];
  [super dealloc];
}

- (void) show
{
  _closed = NO;
  [_panel makeKeyAndOrderFront: nil];
  [self refresh: nil];
}

- (void) close
{
  _closed = YES;
  [[NSNotificationCenter defaultCenter] removeObserver: self];
  if ([_task isRunning])
    [_task terminate];
  [[_pipe fileHandleForReading] closeFile];
  [_task release];
  _task = nil;
  [_pipe release];
  _pipe = nil;
  [_panel close];
  [_table setDataSource: nil];
  [_table setDelegate: nil];
  [_table setTarget: nil];
}

- (BOOL) isBusy
{
  return _task != nil;
}

- (void) updateControls
{
  NSEnumerator *buttons = [_buttons objectEnumerator];
  NSButton *button;
  while ((button = [buttons nextObject]) != nil)
    {
      SEL action = [button action];
      BOOL enabled
          = !_task && (_root != nil || action == @selector (refresh:));
      if (action == @selector (cancel:))
        enabled = _task != nil;
      if (action == @selector (stage:) || action == @selector (unstage:)
          || action == @selector (openFile:))
        enabled = enabled && [_table numberOfSelectedRows] > 0;
      [button setEnabled: enabled];
    }
  [_message setEnabled: _task == nil];
}

+ (NSArray *) entriesFromStatusData: (NSData *)data
{
  if ([data length]
      && ((const unsigned char *)[data bytes])[[data length] - 1] != 0)
    return nil;
  NSString *text
      = AUTORELEASE ([[NSString alloc] initWithData: data
                                           encoding: NSUTF8StringEncoding]);
  if (!text)
    return nil;
  NSString *zero = [NSString stringWithFormat: @"%C", (unichar)0];
  NSArray *records = [text componentsSeparatedByString: zero];
  NSMutableArray *entries = [NSMutableArray array];
  NSUInteger i;
  for (i = 0; i < [records count]; i++)
    {
      NSString *record = [records objectAtIndex: i];
      if (![record length] && i == [records count] - 1)
        break;
      if ([record length] < 4 || [record characterAtIndex: 2] != ' ')
        return nil;
      NSString *status = [record substringToIndex: 2];
      NSString *path = [record substringFromIndex: 3];
      if ([path isAbsolutePath] ||
          [[path pathComponents] containsObject: @".."])
        return nil;
      NSMutableDictionary *entry = [NSMutableDictionary
          dictionaryWithObjectsAndKeys: status, @"status", path, @"path", nil];
      if ([status rangeOfString: @"R"].location != NSNotFound ||
          [status rangeOfString: @"C"].location != NSNotFound)
        {
          if (++i >= [records count])
            return nil;
          NSString *original = [records objectAtIndex: i];
          if (![original length] || [original isAbsolutePath] ||
              [[original pathComponents] containsObject: @".."])
            return nil;
          [entry setObject: original forKey: @"original"];
        }
      [entries addObject: entry];
    }
  return entries;
}

- (void) runArguments: (NSArray *)arguments operation: (NSString *)operation
{
  if (_task || _closed)
    return;
  ASSIGN (_operation, operation);
  ASSIGN (_output, [NSMutableData data]);
  _eof = _terminated = _cancelled = _truncated = NO;
  _exitStatus = 0;
  _task = [NSTask new];
  _pipe = [NSPipe new];
  NSMutableArray *args =
      [NSMutableArray arrayWithObjects: @"--no-pager", @"--literal-pathspecs",
                                       @"-c", @"color.ui=false", nil];
  [args addObjectsFromArray: arguments];
#ifdef _WIN32
  [_task setLaunchPath: @"git"];
#else
  [_task setLaunchPath: @"/usr/bin/env"];
  [args insertObject: @"git" atIndex: 0];
#endif
  [_task setArguments: args];
  [_task setCurrentDirectoryPath: _root ? _root : _directory];
  NSMutableDictionary *environment = [NSMutableDictionary
      dictionaryWithDictionary: [[NSProcessInfo processInfo] environment]];
  [environment
      removeObjectsForKeys:
          [NSArray arrayWithObjects: @"GIT_DIR", @"GIT_WORK_TREE",
                                    @"GIT_INDEX_FILE", @"GIT_COMMON_DIR",
                                    @"GIT_OBJECT_DIRECTORY",
                                    @"GIT_ALTERNATE_OBJECT_DIRECTORIES",
                                    @"GIT_PREFIX", nil]];
  [environment setObject: @"0" forKey: @"GIT_TERMINAL_PROMPT"];
  [environment setObject: @"0" forKey: @"GIT_OPTIONAL_LOCKS"];
  [_task setEnvironment: environment];
  [_task setStandardInput: [NSFileHandle fileHandleWithNullDevice]];
  [_task setStandardOutput: _pipe];
  [_task setStandardError: _pipe];
  NSNotificationCenter *center = [NSNotificationCenter defaultCenter];
  [center addObserver: self
             selector: @selector (taskExited:)
                 name: NSTaskDidTerminateNotification
               object: _task];
  [center addObserver: self
             selector: @selector (readOutput:)
                 name: NSFileHandleReadCompletionNotification
               object: [_pipe fileHandleForReading]];
  [_status setStringValue: [NSString stringWithFormat: @"Git: %@…", operation]];
  [self updateControls];
  @try
    {
      [_task launch];
      [[_pipe fileHandleForReading] readInBackgroundAndNotify];
    }
  @catch (NSException *exception)
    {
      NSString *error = [NSString
          stringWithFormat: @"Could not launch Git: %@", [exception reason]];
      [_output appendData: [error dataUsingEncoding: NSUTF8StringEncoding]];
      _eof = _terminated = YES;
      _exitStatus = 1;
      [self finishIfReady];
    }
}

- (void) readOutput: (NSNotification *)notification
{
  if ([notification object] != [_pipe fileHandleForReading])
    return;
  NSData *data =
      [[notification userInfo] objectForKey: NSFileHandleNotificationDataItem];
  if ([data length])
    {
      NSUInteger limit = 8 * 1024 * 1024;
      NSUInteger room = limit - [_output length];
      [_output appendData: [data subdataWithRange: NSMakeRange (
                                                     0, MIN (room,
                                                             [data length]))]];
      if ([data length] > room)
        _truncated = YES;
      [[_pipe fileHandleForReading] readInBackgroundAndNotify];
    }
  else
    {
      _eof = YES;
      [self finishIfReady];
    }
}

- (void) taskExited: (NSNotification *)notification
{
  if ([notification object] != _task)
    return;
  _exitStatus = [_task terminationStatus];
  _terminated = YES;
  [self finishIfReady];
}

- (void) finishIfReady
{
  if (!_eof || !_terminated)
    return;
  [[NSNotificationCenter defaultCenter]
      removeObserver: self
                name: NSTaskDidTerminateNotification
              object: _task];
  [[NSNotificationCenter defaultCenter]
      removeObserver: self
                name: NSFileHandleReadCompletionNotification
              object: [_pipe fileHandleForReading]];
  [_task release];
  _task = nil;
  [_pipe release];
  _pipe = nil;
  NSString *operation = [[_operation copy] autorelease];
  NSString *output
      = AUTORELEASE ([[NSString alloc] initWithData: _output
                                           encoding: NSUTF8StringEncoding]);
  if (!output)
    output = @"Git output could not be decoded as UTF-8.";
  [self updateControls];
  if (_closed)
    return;
  if (_cancelled)
    {
      [_status
          setStringValue:
              @"Git command cancelled. Refresh to see the current repository state."];
      return;
    }
  if ([operation isEqual: @"check HEAD"] && _exitStatus != 0)
    {
      NSMutableArray *args =
          [NSMutableArray arrayWithObjects: @"rm", @"--cached",
                                           @"--ignore-unmatch", @"--", nil];
      [args addObjectsFromArray: _pendingPaths];
      [self runArguments: args operation: @"unstage"];
      return;
    }
  if (_exitStatus != 0)
    {
      [_details setString: output];
      [_status
          setStringValue: [NSString
                             stringWithFormat:
                                 @"Git %@ failed (exit %d). See output above.",
                                 operation, _exitStatus]];
      return;
    }
  if ([operation isEqual: @"repository"])
    {
      if (_truncated || ![output hasSuffix: @"\n"])
        {
          [_status setStringValue: @"Invalid Git repository path."];
          return;
        }
      ASSIGN (_root, [output substringToIndex: [output length] - 1]);
      [_panel setTitle: [@"Source Control — " stringByAppendingString: _root]];
      [self
          runArguments: [NSArray arrayWithObjects: @"status", @"--porcelain=v1",
                                                 @"-z",
                                                 @"--untracked-files=all", nil]
             operation: @"status"];
      return;
    }
  if ([operation isEqual: @"status"])
    {
      NSArray *entries
          = _truncated ? nil : [[self class] entriesFromStatusData: _output];
      if (!entries)
        {
          [_status
              setStringValue:
                  @"Status is too large or contains unsupported filenames. Use Git in Terminal."];
          return;
        }
      ASSIGN (_entries, entries);
      [_table deselectAll: nil];
      [_table reloadData];
      [_status
          setStringValue:
              [NSString
                  stringWithFormat:
                      @"%lu changed paths. Index / Worktree: M modified, A added, D deleted, R renamed, ? untracked, U unmerged. Git uses saved files.",
                      (unsigned long)[entries count]]];
      [self updateControls];
      return;
    }
  if ([operation isEqual: @"check HEAD"])
    {
      NSMutableArray *args = [NSMutableArray
          arrayWithObjects: @"reset", @"-q", @"HEAD", @"--", nil];
      [args addObjectsFromArray: _pendingPaths];
      [self runArguments: args operation: @"unstage"];
      return;
    }
  [_details setString: _truncated
                          ? [output stringByAppendingString:
                                        @"\n[Output truncated at 8 MiB]"]
                          : output];
  if ([operation isEqual: @"stage"] || [operation isEqual: @"unstage"] ||
      [operation isEqual: @"commit"])
    {
      if ([operation isEqual: @"commit"])
        [_message setStringValue: @""];
      [self refresh: nil];
    }
  else
    [_status
        setStringValue: [NSString
                           stringWithFormat: @"Git %@ complete.%@", operation,
                                            _truncated ? @" Output truncated."
                                                       : @""]];
}

- (IBAction) refresh: (id)sender
{
  if (_task)
    return;
  [self runArguments: [NSArray arrayWithObjects: @"rev-parse",
                                               @"--show-toplevel", nil]
           operation: @"repository"];
}

- (NSArray *) selectedPaths
{
  NSMutableArray *paths = [NSMutableArray array];
  NSIndexSet *selection = [_table selectedRowIndexes];
  NSUInteger i = [selection firstIndex];
  while (i != NSNotFound)
    {
      if (i < [_entries count])
        {
          NSDictionary *entry = [_entries objectAtIndex: i];
          [paths addObject: [entry objectForKey: @"path"]];
          if ([entry objectForKey: @"original"])
            [paths addObject: [entry objectForKey: @"original"]];
        }
      i = [selection indexGreaterThanIndex: i];
    }
  return paths;
}

- (IBAction) stage: (id)sender
{
  NSArray *paths = [self selectedPaths];
  if (_task || !_root || ![paths count])
    return;
  NSEnumerator *enumerator = [paths objectEnumerator];
  NSString *path;
  while ((path = [enumerator nextObject]) != nil)
    {
      NSString *absolute = [[_root stringByAppendingPathComponent: path]
          stringByResolvingSymlinksInPath];
      NSEnumerator *documents =
          [[[_owner editorController] openDocuments] objectEnumerator];
      YCodeEditorDocument *document;
      while ((document = [documents nextObject]) != nil)
        if ([[[document filePath] stringByResolvingSymlinksInPath]
                isEqual: absolute])
          break;
      if ([document isModified])
        {
          [_status
              setStringValue:
                  @"Save the selected files before staging. Git stages disk contents."];
          return;
        }
    }
  NSMutableArray *args =
      [NSMutableArray arrayWithObjects: @"add", @"-A", @"--", nil];
  [args addObjectsFromArray: paths];
  [self runArguments: args operation: @"stage"];
}

- (IBAction) unstage: (id)sender
{
  NSArray *paths = [self selectedPaths];
  if (_task || !_root || ![paths count])
    return;
  ASSIGN (_pendingPaths, paths);
  [self runArguments: [NSArray arrayWithObjects: @"rev-parse", @"--verify",
                                               @"HEAD", nil]
           operation: @"check HEAD"];
}

- (void) showDiffStaged: (BOOL)staged
{
  if (_task || !_root)
    return;
  NSMutableArray *args = [NSMutableArray
      arrayWithObjects: @"diff", @"--no-ext-diff", @"--no-textconv", nil];
  if (staged)
    [args addObject: @"--cached"];
  [args addObject: @"--"];
  [args addObjectsFromArray: [self selectedPaths]];
  [self runArguments: args
           operation: staged ? @"staged diff"
                            : @"diff (untracked files are not included)"];
}

- (IBAction) diff: (id)sender
{
  [self showDiffStaged: NO];
}

- (IBAction) stagedDiff: (id)sender
{
  [self showDiffStaged: YES];
}

- (IBAction) history: (id)sender
{
  if (_task || !_root)
    return;
  [self
      runArguments: [NSArray arrayWithObjects: @"log", @"-50", @"--date=short",
                                             @"--format=%h %ad %an%n%s%n", nil]
         operation: @"history"];
}

- (IBAction) commit: (id)sender
{
  NSString *message = [_message stringValue];
  if (_task || !_root)
    return;
  if (![[message stringByTrimmingCharactersInSet:
                     [NSCharacterSet whitespaceAndNewlineCharacterSet]]
          length])
    {
      [_status setStringValue: @"Enter a commit message first."];
      return;
    }
  [self runArguments: [NSArray arrayWithObjects: @"commit", @"-m", message, nil]
           operation: @"commit"];
}

- (IBAction) openFile: (id)sender
{
  if (_task || !_root)
    return;
  NSIndexSet *selection = [_table selectedRowIndexes];
  NSUInteger i = [selection firstIndex];
  while (i != NSNotFound)
    {
      if (i < [_entries count])
        {
          NSString *path =
              [_root stringByAppendingPathComponent: [[_entries objectAtIndex: i]
                                                        objectForKey: @"path"]];
          if (![[NSFileManager defaultManager] fileExistsAtPath: path])
            [_status
                setStringValue: @"The selected file no longer exists on disk."];
          else
            [[_owner editorController] openFile: path];
        }
      i = [selection indexGreaterThanIndex: i];
    }
  [[_owner window] makeKeyAndOrderFront: nil];
}

- (IBAction) cancel: (id)sender
{
  if (_task)
    {
      _cancelled = YES;
      if ([_task isRunning])
        [_task terminate];
    }
}

- (NSInteger) numberOfRowsInTableView: (NSTableView *)table
{
  return [_entries count];
}

- (id) tableView: (NSTableView *)table
    objectValueForTableColumn: (NSTableColumn *)column
                          row: (NSInteger)row
{
  NSDictionary *entry = [_entries objectAtIndex: row];
  if ([[column identifier] isEqual: @"status"])
    return [entry objectForKey: @"status"];
  if ([entry objectForKey: @"original"])
    return [NSString stringWithFormat: @"%@ → %@",
                                      [entry objectForKey: @"original"],
                                      [entry objectForKey: @"path"]];
  return [entry objectForKey: @"path"];
}

- (void) tableViewSelectionDidChange: (NSNotification *)notification
{
  [self updateControls];
}

@end
