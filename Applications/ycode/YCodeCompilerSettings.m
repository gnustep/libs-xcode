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

#import "YCodeCompilerSettings.h"
#import "YCodeProject.h"
#import "YCodeBuildSystem.h"

NSString *YCodeCompilerSettingsDidChangeNotification
    = @"YCodeCompilerSettingsDidChange";

/* Decode command-form entries without running a shell. Keep argument boundaries
   for quoted paths and backslashes, as required by compilation databases. */
static NSArray *
YCodeCompilerArguments (NSString *command)
{
  NSMutableArray *result = [NSMutableArray array];
  NSMutableString *word = [NSMutableString string];
  unichar quote = 0;
  BOOL started = NO;
  NSUInteger i;
  for (i = 0; i < [command length]; i++)
    {
      unichar c = [command characterAtIndex: i];
      if (c == '\\' && quote != '\'')
        {
          if (++i == [command length])
            return nil;
          unichar next = [command characterAtIndex: i];
          if (quote == '"' && next != '"' && next != '\\' && next != '$'
              && next != '`')
            [word appendFormat: @"%C", (unichar)'\\'];
          [word appendFormat: @"%C", next];
          started = YES;
        }
      else if (quote)
        {
          if (c == quote)
            quote = 0;
          else
            [word appendFormat: @"%C", c];
        }
      else if (c == '\'' || c == '"')
        {
          quote = c;
          started = YES;
        }
      else if ([[NSCharacterSet whitespaceAndNewlineCharacterSet]
                   characterIsMember: c])
        {
          if (started)
            {
              [result addObject: [[word copy] autorelease]];
              [word setString: @""];
              started = NO;
            }
        }
      else
        {
          [word appendFormat: @"%C", c];
          started = YES;
        }
    }
  if (quote)
    return nil;
  if (started)
    [result addObject: word];
  return result;
}

static NSString *
YCodeDatabaseInDirectory (NSString *directory)
{
  NSEnumerator *names =
      [[NSArray arrayWithObjects: @"compile_commands.json",
                                 @"compile_flags.txt", nil] objectEnumerator];
  NSString *name;
  while ((name = [names nextObject]))
    {
      NSString *path = [directory stringByAppendingPathComponent: name];
      BOOL isDirectory = NO;
      if ([[NSFileManager defaultManager] fileExistsAtPath: path
                                               isDirectory: &isDirectory]
          && !isDirectory)
        return path;
    }
  return nil;
}

@implementation YCodeCompilerSettings
+ (NSString *) defaultsKeyForProject: (YCodeProject *)project
{
  if (!project)
    return @"YCodeCompilerDefaults";
  NSString *path = [[[project projectPath] stringByStandardizingPath]
      stringByResolvingSymlinksInPath];
  return [path length]
             ? [@"YCodeCompilerSettings:" stringByAppendingString: path]
             : nil;
}

+ (NSDictionary *) settingsForProject: (YCodeProject *)project
{
  NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
  NSString *key = [self defaultsKeyForProject: project];
  NSDictionary *settings = key ? [defaults dictionaryForKey: key] : nil;
  if (!settings)
    settings = [defaults dictionaryForKey: @"YCodeCompilerDefaults"];
  id path = [settings objectForKey: @"DatabasePath"];
  id stored = [settings objectForKey: @"ExtraFlags"];
  NSMutableArray *flags = [NSMutableArray array];
  NSEnumerator *en =
      [stored isKindOfClass: [NSArray class]] ? [stored objectEnumerator] : nil;
  id flag;
  while ((flag = [en nextObject]))
    if ([flag isKindOfClass: [NSString class]] && [flag length])
      [flags addObject: flag];
  return [NSDictionary
      dictionaryWithObjectsAndKeys: [path isKindOfClass: [NSString class]] ? path
                                                                         : @"",
                                   @"DatabasePath", flags, @"ExtraFlags", nil];
}

+ (void) saveSettings: (NSDictionary *)settings
          forProject: (YCodeProject *)project
{
  NSString *key = [self defaultsKeyForProject: project];
  if (!key)
    return;
  NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
  if (settings)
    [defaults setObject: settings forKey: key];
  else
    [defaults removeObjectForKey: key];
  [defaults synchronize];
  [[NSNotificationCenter defaultCenter]
      postNotificationName: YCodeCompilerSettingsDidChangeNotification
                    object: project];
}

+ (NSArray *) flagsFromText: (NSString *)text
{
  NSMutableArray *flags = [NSMutableArray array];
  NSEnumerator *lines =
      [[text componentsSeparatedByCharactersInSet: [NSCharacterSet
                                                      newlineCharacterSet]]
          objectEnumerator];
  NSString *line;
  while ((line = [lines nextObject]))
    {
      line =
          [line stringByTrimmingCharactersInSet: [NSCharacterSet
                                                    whitespaceCharacterSet]];
      if ([line length])
        [flags addObject: line];
    }
  return flags;
}

+ (NSDictionary *) configurationForProject: (YCodeProject *)project
                               sourcePath: (NSString *)path
{
  NSDictionary *settings = [self settingsForProject: project];
  NSString *root = [project projectDirectoryPath]
                       ?: [path stringByDeletingLastPathComponent];
  if (![root length])
    root = NSHomeDirectory ();
  id value = [settings objectForKey: @"DatabasePath"];
  NSString *chosen =
      [value isKindOfClass: [NSString class]]
          ? [value stringByTrimmingCharactersInSet:
                       [NSCharacterSet whitespaceAndNewlineCharacterSet]]
          : @"";
  NSMutableArray *flags = [NSMutableArray array];
  id storedFlags = [settings objectForKey: @"ExtraFlags"];
  NSEnumerator *en = [storedFlags isKindOfClass: [NSArray class]]
                         ? [storedFlags objectEnumerator]
                         : nil;
  while ((value = [en nextObject]))
    if ([value isKindOfClass: [NSString class]] && [value length])
      [flags addObject: value];
  NSMutableDictionary *result = [NSMutableDictionary
      dictionaryWithObjectsAndKeys: root, @"root", flags, @"flags", nil];
  NSString *database = nil;
  if ([chosen length])
    {
      chosen = [chosen stringByExpandingTildeInPath];
      if (![chosen isAbsolutePath])
        chosen = [root stringByAppendingPathComponent: chosen];
      chosen = [chosen stringByStandardizingPath];
      BOOL directory = NO;
      BOOL exists =
          [[NSFileManager defaultManager] fileExistsAtPath: chosen
                                               isDirectory: &directory];
      if (exists && directory)
        database = YCodeDatabaseInDirectory (chosen);
      else if (exists &&
               [[NSArray arrayWithObjects: @"compile_commands.json",
                                          @"compile_flags.txt", nil]
                   containsObject: [chosen lastPathComponent]])
        database = chosen;
      if (!database)
        [result
            setObject:
                [NSString
                    stringWithFormat:
                        @"No compile_commands.json or compile_flags.txt found at %@. Choose a database in Code Intelligence Settings.",
                        chosen]
               forKey: @"error"];
    }
  else
    {
      database = YCodeDatabaseInDirectory (root);
      if (!database)
        database = YCodeDatabaseInDirectory (
            [root stringByAppendingPathComponent: @"build"]);
      if (!database && project)
        database = YCodeDatabaseInDirectory (
            [[project buildSystem] compilationDatabaseDirectory]);
      NSString *ancestor = [path stringByDeletingLastPathComponent] ?: root;
      while (!database && [ancestor length])
        {
          database = YCodeDatabaseInDirectory (ancestor);
          NSString *parent = [ancestor stringByDeletingLastPathComponent];
          if ([ancestor isEqual: parent])
            break;
          ancestor = parent;
        }
    }
  if (database)
    {
      [result setObject: database forKey: @"source"];
      [result setObject: [database stringByDeletingLastPathComponent]
                 forKey: @"directory"];
      [result setObject: [NSString
                            stringWithFormat: @"Selected compiler settings: %@",
                                             database]
                 forKey: @"description"];
    }
  else
    [result
        setObject:
            [result objectForKey: @"error"]
                ?: @"No compilation database was located. Build the project to capture commands, or choose a database in Code Intelligence Settings. clangd may be using fallback flags or .clangd settings."
           forKey: @"description"];
  return result;
}

+ (NSDictionary *) prepareConfiguration: (NSDictionary *)configuration
{
  NSMutableDictionary *result =
      [NSMutableDictionary dictionaryWithDictionary: configuration];
  NSString *source = [result objectForKey: @"source"];
  NSArray *flags = [result objectForKey: @"flags"];
  if ([result objectForKey: @"error"] || !source)
    return result;
  BOOL json = [[source lastPathComponent] isEqual: @"compile_commands.json"];
  id commands = nil;
  NSString *text = nil;
  if (json)
    {
      NSData *data = [NSData dataWithContentsOfFile: source];
      commands = data ? [NSJSONSerialization
                            JSONObjectWithData: data
                                       options: NSJSONReadingMutableContainers
                                         error: NULL]
                      : nil;
      if (![commands isKindOfClass: [NSArray class]])
        {
          [result
              setObject:
                  @"The selected compilation database is unreadable or is not a JSON array."
                 forKey: @"error"];
          return result;
        }
      NSEnumerator *en = [commands objectEnumerator];
      id entry;
      while ((entry = [en nextObject]))
        {
          if (![entry isKindOfClass: [NSDictionary class]]
              || ![[entry objectForKey: @"directory"]
                  isKindOfClass: [NSString class]]
              || ![[entry objectForKey: @"file"]
                  isKindOfClass: [NSString class]])
            {
              [result
                  setObject:
                      @"A compilation database entry is missing its file or working directory."
                     forKey: @"error"];
              return result;
            }
          id arguments = [entry objectForKey: @"arguments"];
          if (!arguments &&
              [[entry objectForKey: @"command"] isKindOfClass: [NSString class]])
            arguments
                = YCodeCompilerArguments ([entry objectForKey: @"command"]);
          if (![arguments isKindOfClass: [NSArray class]] || ![arguments count])
            {
              [result
                  setObject:
                      @"A compilation database entry has invalid compiler arguments."
                     forKey: @"error"];
              return result;
            }
          NSEnumerator *args = [arguments objectEnumerator];
          id argument;
          while ((argument = [args nextObject]))
            if (![argument isKindOfClass: [NSString class]])
              {
                [result setObject: @"Compiler arguments must be strings."
                           forKey: @"error"];
                return result;
              }
          if ([flags count])
            {
              NSMutableArray *adjusted =
                  [NSMutableArray arrayWithArray: arguments];
              NSUInteger index = [adjusted indexOfObject: @"--"];
              if (index == NSNotFound)
                index = [adjusted count];
              [adjusted
                  insertObjects: flags
                      atIndexes: [NSIndexSet
                                    indexSetWithIndexesInRange:
                                        NSMakeRange (index, [flags count])]];
              [entry setObject: adjusted forKey: @"arguments"];
              [entry removeObjectForKey: @"command"];
              NSString *directory = [entry objectForKey: @"directory"];
              if (![directory isAbsolutePath])
                [entry setObject: [[source stringByDeletingLastPathComponent]
                                     stringByAppendingPathComponent: directory]
                          forKey: @"directory"];
            }
        }
    }
  else
    {
      text = [NSString stringWithContentsOfFile: source
                                       encoding: NSUTF8StringEncoding
                                          error: NULL];
      if (!text)
        {
          [result
              setObject:
                  @"The selected compile_flags.txt could not be read as UTF-8."
                 forKey: @"error"];
          return result;
        }
    }
  /* clangd prefers JSON when both files share a directory. Isolate an
     explicitly selected flags file so that its selection is honored. */
  BOOL isolateFlags
      = !json &&
        [[NSFileManager defaultManager]
            fileExistsAtPath:
                [[source stringByDeletingLastPathComponent]
                    stringByAppendingPathComponent: @"compile_commands.json"]];
  if (![flags count] && !isolateFlags)
    return result;
  NSString *temporary = [NSTemporaryDirectory ()
      stringByAppendingPathComponent:
          [@"YcodeCompilerSettings-"
              stringByAppendingString: [[NSProcessInfo processInfo]
                                          globallyUniqueString]]];
  NSFileManager *manager = [NSFileManager defaultManager];
  BOOL saved = [manager createDirectoryAtPath: temporary
                  withIntermediateDirectories: YES
                                   attributes: nil
                                        error: NULL];
  NSString *output =
      [temporary stringByAppendingPathComponent: [source lastPathComponent]];
  if (saved && json)
    saved = [[NSJSONSerialization dataWithJSONObject: commands
                                             options: 0
                                               error: NULL] writeToFile: output
                                                            atomically: YES];
  else if (saved)
    {
      text = [NSString
          stringWithFormat: @"-working-directory=%@\n%@\n%@\n",
                           [source stringByDeletingLastPathComponent], text,
                           [flags componentsJoinedByString: @"\n"]];
      saved = [text writeToFile: output
                     atomically: YES
                       encoding: NSUTF8StringEncoding
                          error: NULL];
    }
  if (!saved)
    {
      [manager removeItemAtPath: temporary error: NULL];
      [result
          setObject:
              @"Could not create the private compilation database with extra flags."
             forKey: @"error"];
      return result;
    }
  [result setObject: temporary forKey: @"directory"];
  [result setObject: temporary forKey: @"temporary"];
  return result;
}

+ (void) removePreparedConfiguration: (NSDictionary *)configuration
{
  NSString *temporary = [configuration objectForKey: @"temporary"];
  if (temporary)
    [[NSFileManager defaultManager] removeItemAtPath: temporary error: NULL];
}

+ (NSString *) noDefinitionMessageForConfiguration: (NSDictionary *)configuration
{
  return [NSString stringWithFormat: @"clangd returned no definition for this symbol. Its definition may be unavailable, or parsing/indexing may be incomplete.\n\n%@\n\nReview Live Diagnostics for parsing errors.", [configuration objectForKey: @"error"] ?: [configuration objectForKey: @"description"] ?: @"Review the project's Code Intelligence Settings."];
}

- (NSTextField *) label: (NSString *)text frame: (NSRect)frame
{
  NSTextField *label = AUTORELEASE ([[NSTextField alloc] initWithFrame: frame]);
  [label setStringValue: text];
  [label setEditable: NO];
  [label setSelectable: YES];
  [label setBezeled: NO];
  [label setDrawsBackground: NO];
  [[_panel contentView] addSubview: label];
  return label;
}

- (id) initWithProject: (YCodeProject *)project
{
  if ((self = [super init]))
    {
      _project = [project retain];
      _panel = [[NSPanel alloc]
          initWithContentRect: NSMakeRect (180, 180, 620, 500)
                    styleMask: NSTitledWindowMask | NSClosableWindowMask
                      backing: NSBackingStoreBuffered
                        defer: NO];
      [_panel setReleasedWhenClosed: NO];
      [_panel
          setTitle: project
                       ? [NSString stringWithFormat: @"Code Intelligence — %@",
                                                    [[project projectPath]
                                                        lastPathComponent]]
                       : @"Code Intelligence Defaults"];
      [self
          label:
              project
                  ? @"Saved for this project on this computer. Build settings are unchanged."
                  : @"Defaults for projects without their own code-intelligence overrides."
          frame: NSMakeRect (20, 453, 580, 32)];
      _inherit =
          [[NSButton alloc] initWithFrame: NSMakeRect (20, 418, 580, 28)];
      [_inherit setButtonType: NSSwitchButton];
      [_inherit setTitle: @"Use global defaults"];
      [_inherit setTarget: self];
      [_inherit setAction: @selector (changeInheritance:)];
      [_inherit setHidden: project == nil];
      NSString *key = [[self class] defaultsKeyForProject: project];
      [_inherit setState: project
                                 && ![[NSUserDefaults standardUserDefaults]
                                     dictionaryForKey: key]
                             ? NSOnState
                             : NSOffState];
      [[_panel contentView] addSubview: _inherit];
      [self label: @"Compilation database (blank = automatic)"
            frame: NSMakeRect (20, 386, 580, 24)];
      _database =
          [[NSTextField alloc] initWithFrame: NSMakeRect (20, 350, 580, 28)];
      [_database
          setToolTip:
              @"Directory, compile_commands.json, or compile_flags.txt. Project paths can be relative to the project directory; global paths must be absolute."];
      [[_panel contentView] addSubview: _database];
      [self
          label:
              @"Extra compiler arguments — one argument per line, without shell quoting"
          frame: NSMakeRect (20, 315, 580, 24)];
      NSScrollView *scroll = AUTORELEASE (
          [[NSScrollView alloc] initWithFrame: NSMakeRect (20, 160, 580, 148)]);
      [scroll setHasVerticalScroller: YES];
      [scroll setBorderType: NSBezelBorder];
      _flags = [[NSTextView alloc] initWithFrame: [scroll bounds]];
      [_flags setRichText: NO];
      [_flags setFont: [NSFont userFixedPitchFontOfSize: 12]];
      [_flags setAutoresizingMask: NSViewWidthSizable];
      [[_flags textContainer] setWidthTracksTextView: YES];
      [scroll setDocumentView: _flags];
      [[_panel contentView] addSubview: scroll];
      _status = [[self label: @"" frame: NSMakeRect (20, 57, 580, 92)] retain];
      NSButton *apply = AUTORELEASE (
          [[NSButton alloc] initWithFrame: NSMakeRect (500, 14, 100, 32)]);
      [apply setTitle: @"Apply"];
      [apply setTarget: self];
      [apply setAction: @selector (apply:)];
      [[_panel contentView] addSubview: apply];
      NSDictionary *settings = [[self class] settingsForProject: project];
      [_database
          setStringValue: [settings objectForKey: @"DatabasePath"] ?: @""];
      [_flags setString: [[settings objectForKey: @"ExtraFlags"]
                            componentsJoinedByString: @"\n"]
                            ?: @""];
      [self changeInheritance: nil];
      NSDictionary *configuration =
          [[self class] configurationForProject: project sourcePath: nil];
      [_status setStringValue: [configuration objectForKey: @"description"]];
    }
  return self;
}

- (void) dealloc
{
  [_panel close];
  RELEASE (_panel);
  RELEASE (_project);
  RELEASE (_inherit);
  RELEASE (_database);
  RELEASE (_flags);
  RELEASE (_status);
  [super dealloc];
}

- (void) show
{
  [_panel makeKeyAndOrderFront: nil];
}

- (void) changeInheritance: (id)sender
{
  BOOL inherited = _project && [_inherit state] == NSOnState;
  [_database setEnabled: !inherited];
  [_flags setEditable: !inherited];
  if (inherited)
    {
      NSDictionary *settings = [[self class] settingsForProject: nil];
      [_database
          setStringValue: [settings objectForKey: @"DatabasePath"] ?: @""];
      [_flags setString: [[settings objectForKey: @"ExtraFlags"]
                            componentsJoinedByString: @"\n"]
                            ?: @""];
    }
}

- (void) apply: (id)sender
{
  [_panel makeFirstResponder: nil];
  NSString *path = [[_database stringValue]
      stringByTrimmingCharactersInSet: [NSCharacterSet
                                          whitespaceAndNewlineCharacterSet]];
  if (!_project && [path length]
      && ![[path stringByExpandingTildeInPath] isAbsolutePath])
    {
      [_status
          setStringValue:
              @"Global database paths must be absolute (or start with ~). Relative paths belong in project settings."];
      return;
    }
  NSDictionary *settings
      = _project && [_inherit state] == NSOnState
            ? nil
            : [NSDictionary
                  dictionaryWithObjectsAndKeys: path, @"DatabasePath",
                                               [[self class]
                                                   flagsFromText: [_flags
                                                                     string]],
                                               @"ExtraFlags", nil];
  [[self class] saveSettings: settings forProject: _project];
  NSDictionary *configuration = [[self class]
      prepareConfiguration: [[self class] configurationForProject: _project
                                                      sourcePath: nil]];
  [_status
      setStringValue:
          [NSString stringWithFormat: @"Saved. %@",
                                     [configuration objectForKey: @"error"]
                                         ?: [configuration
                                                objectForKey: @"description"]]];
  [[self class] removePreparedConfiguration: configuration];
}

@end
