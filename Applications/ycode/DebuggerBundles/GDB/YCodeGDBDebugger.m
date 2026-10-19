/*
   Project: Ycode

   Copyright (C) 2025 Free Software Foundation

   Author: Gregory Casamento

   Created: 2025-01-15

   This application is free software; you can redistribute it and/or
   modify it under the terms of the GNU General Public
   License as published by the Free Software Foundation; either
   version 2 of the License, or (at your option) any later version.

   This application is distributed in the hope that it will be useful,
   but WITHOUT ANY WARRANTY; without even the implied warranty of
   MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
   Library General Public License for more details.

   You should have received a copy of the GNU General Public
   License along with this library; if not, write to the Free
   Software Foundation, Inc., 59 Temple Place, Suite 330, Boston, MA 02111 USA.
*/

#import "YCodeGDBDebugger.h"
#import "YCodeGDBVariables.h"

/* Like ProjectCenter's GDBWrapper, decode MI tuples, lists and C strings.
 * Always advance on malformed input, and retain bytes until a complete record
 * arrives (including when a UTF-8 character spans two pipe reads).
 */
static id YCReadValue (NSScanner *scanner);
static NSDictionary *
YCReadFields (NSScanner *scanner)
{
  NSMutableDictionary *fields = [NSMutableDictionary dictionary];
  while (![scanner isAtEnd])
    {
      NSString *key = nil;
      if ([scanner scanString: @"}" intoString: NULL])
        break;
      [scanner scanUpToCharactersFromSet:
                   [NSCharacterSet characterSetWithCharactersInString: @"=,}]"]
                              intoString: &key];
      if (![scanner scanString: @"=" intoString: NULL])
        break;
      id value = YCReadValue (scanner);
      if (key && value)
        [fields setObject: value forKey: key];
      if (![scanner scanString: @"," intoString: NULL])
        {
          [scanner scanString: @"}" intoString: NULL];
          break;
        }
    }
  return fields;
}
static id
YCReadValue (NSScanner *scanner)
{
  if ([scanner scanString: @"\"" intoString: NULL])
    {
      NSMutableString *value = [NSMutableString string];
      NSString *text = [scanner string];
      NSUInteger i = [scanner scanLocation];
      while (i < [text length])
        {
          unichar c = [text characterAtIndex: i++];
          if (c == '"')
            break;
          if (c == '\\' && i < [text length])
            {
              c = [text characterAtIndex: i++];
              if (c == 'n')
                c = '\n';
              else if (c == 'r')
                c = '\r';
              else if (c == 't')
                c = '\t';
              else if (c >= '0' && c <= '7')
                {
                  unsigned int n = c - '0', count = 1;
                  while (count < 3 && i < [text length] &&
                         [text characterAtIndex: i] >= '0' &&
                         [text characterAtIndex: i] <= '7')
                    {
                      n = n * 8 + [text characterAtIndex: i++] - '0';
                      count++;
                    }
                  c = n;
                }
            }
          [value appendFormat: @"%C", c];
        }
      [scanner setScanLocation: i];
      return value;
    }
  if ([scanner scanString: @"{" intoString: NULL])
    return YCReadFields (scanner);
  if ([scanner scanString: @"[" intoString: NULL])
    {
      NSMutableArray *values = [NSMutableArray array];
      while (![scanner isAtEnd] && ![scanner scanString: @"]" intoString: NULL])
        {
          NSUInteger start = [scanner scanLocation];
          NSString *key = nil;
          unichar c = [[scanner string] characterAtIndex: start];
          if (c != '"' && c != '{' && c != '[')
            {
              [scanner scanUpToString: @"=" intoString: &key];
              [scanner scanString: @"=" intoString: NULL];
            }
          id value = YCReadValue (scanner);
          if (value)
            [values addObject: key ? [NSDictionary dictionaryWithObject: value
                                                                forKey: key]
                                  : value];
          [scanner scanString: @"," intoString: NULL];
          if ([scanner scanLocation] <= start)
            break;
        }
      return values;
    }
  return nil;
}

@implementation YCodeGDBDebugger
+ (NSUInteger) debuggerAPIVersion
{
  return YCodeDebuggerBackendAPIVersion;
}
+ (NSString *) debuggerIdentifier
{
  return @"gdb";
}
+ (NSString *) debuggerDisplayName
{
  return @"GDB";
}
- (NSString *) launchCommandForExecutable: (NSString *)executable
{
  NSString *path =
      [[NSUserDefaults standardUserDefaults] stringForKey: @"DebuggerPath"];
  return [path length] ? path : @"gdb";
}
- (NSArray *) launchArgumentsForExecutable: (NSString *)executable
{
  return [NSArray arrayWithObjects: @"--interpreter=mi2", @"--quiet", @"--nx",
                                   @"-f", executable, nil];
}
- (BOOL) canSetBreakpointAtFile: (NSString *)file
{
  return [[self class] canSetBreakpointAtFile: file];
}
- (BOOL) canPerformAction: (YCodeDebuggerAction)action
{
  if (!_ready || action < YCodeDebuggerRun || action > YCodeDebuggerStop)
    return NO;
  if (action == YCodeDebuggerPause)
    return _running;
  if (action == YCodeDebuggerRestart || action == YCodeDebuggerStop)
    return YES;
  return !_running;
}
- (void) performAction: (YCodeDebuggerAction)action
{
  if (![self canPerformAction: action])
    return;
  if (action == YCodeDebuggerRestart)
    {
      [self restart];
      return;
    }
  if (action == YCodeDebuggerStop)
    {
      [self command: @"-gdb-exit"];
      return;
    }
  NSArray *commands =
      [NSArray arrayWithObjects: @"-exec-run", @"-exec-interrupt --all",
                                @"-exec-continue", @"-exec-run", @"-exec-next",
                                @"-exec-step", @"-exec-finish",
                                @"-interpreter-exec console \"up\"",
                                @"-interpreter-exec console \"down\"", nil];
  [self command: [commands objectAtIndex: action]];
}
- (id) init
{
  if ((self = [super init]))
    {
      _pending = [NSMutableData new];
      _breakpoints = [NSMutableDictionary new];
      _disabledBreakpoints = [NSMutableSet new];
      _resolvedLocations = [NSMutableDictionary new];
      _variables = [[YCodeGDBVariables alloc] initWithDebugger: self];
    }
  return self;
}
- (void) dealloc
{
  [_variables release];
  [_storageKey release];
  [_pending release];
  [_breakpoints release];
  [_disabledBreakpoints release];
  [_resolvedLocations release];
  [_sourceDirectory release];
  [_executionFile release];
  [super dealloc];
}
- (void) setDelegate: (id<YCodeDebuggerBackendDelegate>)delegate
{
  _delegate = delegate;
}
- (id<YCodeDebuggerVariableSource>) variables
{
  return _variables;
}
- (BOOL) isReady
{
  return _ready;
}
- (BOOL) isRunning
{
  return _running;
}
- (void) notifyChange
{
  [_delegate debuggerBackendDidChange: self];
}
- (void) setSourceDirectory: (NSString *)directory
{
  do
    {
      id value = (directory);
      [value retain];
      [_sourceDirectory release];
      _sourceDirectory = value;
    }
  while (0);
}
- (NSString *) executionFile
{
  return _executionFile;
}
- (NSUInteger) executionLine
{
  return _executionLine;
}
- (void) updateSelectedFrame: (NSDictionary *)frame
{
  NSString *file =
      [frame objectForKey: @"fullname"] ?: [frame objectForKey: @"file"];
  if (file && [[frame objectForKey: @"line"] integerValue] > 0)
    {
      do
        {
          id value = ([self sourcePath: file]);
          [value retain];
          [_executionFile release];
          _executionFile = value;
        }
      while (0);
      _executionLine = [[frame objectForKey: @"line"] integerValue];
      [_delegate debuggerBackend: self
                   stoppedAtFile: _executionFile
                            line: _executionLine];
    }
}
- (NSString *) sourcePath: (NSString *)file
{
  if (![file isAbsolutePath])
    file = [(_sourceDirectory
                 ?: [[NSFileManager defaultManager] currentDirectoryPath])
        stringByAppendingPathComponent: file];
  return [file stringByStandardizingPath];
}
- (NSString *) locationAtFile: (NSString *)file line: (NSUInteger)line
{
  return [NSString
      stringWithFormat: @"%@:%lu", [self sourcePath: file], (unsigned long)line];
}
- (NSString *) storedLocationAtFile: (NSString *)file line: (NSUInteger)line
{
  NSString *location = [self locationAtFile: file line: line];
  if ([_breakpoints objectForKey: location])
    return location;
  {
    NSEnumerator *requestedEnumerator = [_resolvedLocations keyEnumerator];
    NSString *requested;
    while ((requested = [requestedEnumerator nextObject]) != nil)
      if ([[_resolvedLocations objectForKey: requested] isEqual: location])
        return requested;
  }
  return location;
}
- (YCodeBreakpointState) stateForLocation: (NSString *)location
{
  if (![_breakpoints objectForKey: location])
    return YCodeBreakpointNone;
  return [_disabledBreakpoints containsObject: location]
             ? YCodeBreakpointInactive
             : YCodeBreakpointEnabled;
}
- (YCodeBreakpointState) breakpointStateAtFile: (NSString *)file
                                         line: (NSUInteger)line
{
  if (![file length] || line == 0)
    return YCodeBreakpointNone;
  return [self stateForLocation: [self storedLocationAtFile: file line: line]];
}
- (NSDictionary *) breakpointLinesForFile: (NSString *)file
{
  NSMutableDictionary *lines = [NSMutableDictionary dictionary];
  if (![file length])
    return lines;
  NSString *prefix = [[self sourcePath: file] stringByAppendingString: @":"];
  {
    NSEnumerator *requestedEnumerator = [_breakpoints keyEnumerator];
    NSString *requested;
    while ((requested = [requestedEnumerator nextObject]) != nil)
      {
        NSString *location =
            [_resolvedLocations objectForKey: requested] ?: requested;
        if ([location hasPrefix: prefix])
          [lines
              setObject: [NSNumber
                            numberWithInt: [self stateForLocation: requested]]
                 forKey: [NSNumber
                            numberWithInteger:
                                [[location substringFromIndex: [prefix length]]
                                    integerValue]]];
      }
  }
  return lines;
}
- (void) setBreakpointStorageKey: (NSString *)key
{
  do
    {
      id value = (key);
      [value retain];
      [_storageKey release];
      _storageKey = value;
    }
  while (0);
  [_breakpoints removeAllObjects];
  [_disabledBreakpoints removeAllObjects];
  [_resolvedLocations removeAllObjects];
  id saved
      = key ? [[NSUserDefaults standardUserDefaults] objectForKey: key] : nil;
  // Older versions saved an array of enabled locations.
  if ([saved isKindOfClass: [NSArray class]] ||
      [saved isKindOfClass: [NSDictionary class]])
    {
      NSEnumerator *locationEnumerator
          = ([saved isKindOfClass: [NSDictionary class]]
                 ? [saved keyEnumerator]
                 : [saved objectEnumerator]);
      id location;
      while ((location = [locationEnumerator nextObject]) != nil)
        if ([location isKindOfClass: [NSString class]])
          {
            NSRange separator = [location rangeOfString: @":"
                                                options: NSBackwardsSearch];
            if (separator.location == NSNotFound
                || ![[self class]
                    canSetBreakpointAtFile:
                        [location substringToIndex: separator.location]])
              continue;
            [_breakpoints setObject: @"" forKey: location];
            if ([saved isKindOfClass: [NSDictionary class]]
                && ![[saved objectForKey: location] boolValue])
              [_disabledBreakpoints addObject: location];
          }
    }
  [self notifyChange];
}
- (void) saveBreakpoints
{
  if (_storageKey)
    {
      NSMutableDictionary *saved = [NSMutableDictionary dictionary];
      {
        NSEnumerator *locationEnumerator = [_breakpoints keyEnumerator];
        NSString *location;
        while ((location = [locationEnumerator nextObject]) != nil)
          [saved
              setObject: [NSNumber numberWithBool: ![_disabledBreakpoints
                                                     containsObject: location]]
                 forKey: location];
      }
      [[NSUserDefaults standardUserDefaults] setObject: saved
                                                forKey: _storageKey];
    }
  [self notifyChange];
}
- (void) insertBreakpointAtLocation: (NSString *)location
{
  NSString *options = [_disabledBreakpoints containsObject: location]
                          ? @"-break-insert -f -d "
                          : @"-break-insert -f ";
  [self
      command: [options stringByAppendingString: [[self class] quote: location]]];
}
+ (BOOL) canSetBreakpointAtFile: (NSString *)file
{
  NSString *extension = [[file pathExtension] lowercaseString];
  return [extension length] > 0 &&
         [[NSArray arrayWithObjects: @"c", @"m", @"mm", @"cc", @"cp", @"cpp",
                                    @"cxx", @"c++", @"swift", @"s", @"asm",
                                    @"l", @"lm", @"y", @"ym", nil]
             containsObject: extension];
}
- (void) toggleBreakpointEnabledAtFile: (NSString *)file line: (NSUInteger)line
{
  if (![[self class] canSetBreakpointAtFile: file] || line == 0)
    return;
  NSString *location = [self storedLocationAtFile: file line: line];
  NSString *number = [_breakpoints objectForKey: location];
  if (!number)
    return;
  BOOL enable = [_disabledBreakpoints containsObject: location];
  if (enable)
    [_disabledBreakpoints removeObject: location];
  else
    [_disabledBreakpoints addObject: location];
  if ([number length])
    [self command: [(enable ? @"-break-enable " : @"-break-disable ")
                      stringByAppendingString: number]];
  [self saveBreakpoints];
}
- (void) restart
{
  if (_running)
    {
      _restartPending = YES;
      [self command: @"-exec-interrupt --all"];
    }
  else
    [self command: @"-exec-run"];
}
- (void) reset
{
  [_variables reset];
  _ready = _running = _restartPending = NO;
  [_pending setLength: 0];
  [_executionFile release];
  _executionFile = nil;
  _executionLine = 0;
  [_resolvedLocations removeAllObjects];
  {
    NSEnumerator *locationEnumerator =
        [[_breakpoints allKeys] objectEnumerator];
    NSString *location;
    while ((location = [locationEnumerator nextObject]) != nil)
      [_breakpoints setObject: @"" forKey: location];
  }
  [self notifyChange];
}
+ (NSString *) quote: (NSString *)string
{
  string = [string stringByReplacingOccurrencesOfString: @"\\"
                                             withString: @"\\\\"];
  string = [string stringByReplacingOccurrencesOfString: @"\""
                                             withString: @"\\\""];
  string = [string stringByReplacingOccurrencesOfString: @"\n"
                                             withString: @"\\n"];
  string = [string stringByReplacingOccurrencesOfString: @"\r"
                                             withString: @"\\r"];
  return [NSString stringWithFormat: @"\"%@\"", string];
}
+ (NSDictionary *) parseRecord: (NSString *)record
{
  NSScanner *scanner = [NSScanner scannerWithString: record];
  [scanner setCharactersToBeSkipped: nil];
  NSString *token = nil;
  [scanner scanCharactersFromSet: [NSCharacterSet decimalDigitCharacterSet]
                      intoString: &token];
  if ([scanner isAtEnd])
    return nil;
  NSString *type =
      [record substringWithRange: NSMakeRange ([scanner scanLocation], 1)];
  [scanner setScanLocation: [scanner scanLocation] + 1];
  if ([@"~@&" rangeOfString: type].location != NSNotFound)
    return [NSDictionary
        dictionaryWithObjectsAndKeys: type, @"type",
                                     YCReadValue (scanner) ?: @"", @"text",
                                     nil];
  if ([@"^*=+" rangeOfString: type].location == NSNotFound)
    return nil;
  NSString *event = nil;
  [scanner scanUpToString: @"," intoString: &event];
  [scanner scanString: @"," intoString: NULL];
  NSMutableDictionary *result =
      [NSMutableDictionary dictionaryWithDictionary: YCReadFields (scanner)];
  if ([result objectForKey: @"type"])
    [result setObject: [result objectForKey: @"type"] forKey: @"valueType"];
  if (token)
    [result setObject: token forKey: @"token"];
  [result setObject: type forKey: @"type"];
  [result setObject: event ?: @"" forKey: @"event"];
  return result;
}
- (void) command: (NSString *)command
{
  if (_ready)
    [_delegate debuggerBackend: self
                   sendCommand: [command stringByAppendingString: @"\n"]];
}
- (void) consoleCommand: (NSString *)command
{
  [self command: [@"-interpreter-exec console "
                    stringByAppendingString: [[self class] quote: command]]];
}
- (void) toggleBreakpointAtFile: (NSString *)file line: (NSUInteger)line
{
  if (![[self class] canSetBreakpointAtFile: file] || line == 0)
    return;
  NSString *location = [self storedLocationAtFile: file line: line];
  NSString *number = [_breakpoints objectForKey: location];
  BOOL removing = (number != nil);
  if (removing)
    {
      if ([number length])
        [self command: [@"-break-delete " stringByAppendingString: number]];
      else if (_ready)
        [self consoleCommand: [@"clear "
                                 stringByAppendingString: [[self class]
                                                             quote: location]]];
      [_breakpoints removeObjectForKey: location];
      [_disabledBreakpoints removeObject: location];
      [_resolvedLocations removeObjectForKey: location];
    }
  else
    {
      [_breakpoints setObject: @"" forKey: location];
      [self insertBreakpointAtLocation: location];
    }
  [_delegate debuggerBackend: self
                      output: [NSString stringWithFormat: @"Breakpoint %@: %@\n",
                                                        removing ? @"removed"
                                                                 : @"added",
                                                        location]];
  [self saveBreakpoints];
}
- (void) handleLine: (NSString *)line
{
  if ([line hasPrefix: @"(gdb)"])
    {
      if (!_ready)
        {
          _ready = YES;
          [self command: @"-gdb-set confirm off"];
          [self command: @"-gdb-set pagination off"];
          [self command: @"-gdb-set mi-async on"];
          {
            NSEnumerator *locationEnumerator = [_breakpoints keyEnumerator];
            NSString *location;
            while ((location = [locationEnumerator nextObject]) != nil)
              [self insertBreakpointAtLocation: location];
          }
          [self notifyChange];
          [_delegate
              debuggerBackend: self
                       output:
                           @"Debugger ready. Use Go to run, or set breakpoints first.\n"];
        }
      return;
    }
  NSDictionary *record = [[self class] parseRecord: line];
  NSString *type = [record objectForKey: @"type"],
           *event = [record objectForKey: @"event"];
  if ([record objectForKey: @"token"] && [_variables handleRecord: record])
    return;
  if ((!record || [type isEqual: @"@"]) &&
      [_delegate respondsToSelector: @selector (debuggerBackend:targetOutput:)])
    [(id)_delegate
        debuggerBackend: self
           targetOutput: record ? [record objectForKey: @"text"]
                               : [line stringByAppendingString: @"\n"]];
  else if (!record || [type isEqual: @"~"] || [type isEqual: @"@"] ||
           [type isEqual: @"&"])
    [_delegate debuggerBackend: self
                        output: record ? [record objectForKey: @"text"]
                                      : [line stringByAppendingString: @"\n"]];
  if ([event isEqual: @"error"])
    [_delegate
        debuggerBackend: self
                 output: [NSString
                            stringWithFormat: @"Debugger error: %@\n",
                                             [record objectForKey: @"msg"]]];
  if ([event isEqual: @"running"])
    {
      _running = YES;
      [_executionFile release];
      _executionFile = nil;
      _executionLine = 0;
    }
  if ([event isEqual: @"thread-group-exited"])
    {
      _running = NO;
      [_executionFile release];
      _executionFile = nil;
      _executionLine = 0;
    }
  if ([event isEqual: @"stopped"])
    {
      _running = NO;
      [_executionFile release];
      _executionFile = nil;
      _executionLine = 0;
      [_delegate
          debuggerBackend: self
                   output: [NSString
                              stringWithFormat: @"Stopped: %@\n",
                                               [record objectForKey: @"reason"]
                                                   ?: @"paused"]];
    }
  if (_restartPending && [event isEqual: @"stopped"])
    {
      _restartPending = NO;
      [self command: @"-exec-run"];
    }
  NSDictionary *frame = [record objectForKey: @"frame"];
  NSString *file =
      [frame objectForKey: @"fullname"] ?: [frame objectForKey: @"file"];
  if (file && [[frame objectForKey: @"line"] integerValue] > 0)
    {
      do
        {
          id value = ([self sourcePath: file]);
          [value retain];
          [_executionFile release];
          _executionFile = value;
        }
      while (0);
      _executionLine = [[frame objectForKey: @"line"] integerValue];
      [_delegate debuggerBackend: self
                   stoppedAtFile: _executionFile
                            line: _executionLine];
    }
  if (![record objectForKey: @"token"])
    [_variables handleRecord: record];
  NSDictionary *bp = [record objectForKey: @"bkpt"];
  file = [bp objectForKey: @"fullname"] ?: [bp objectForKey: @"file"];
  NSString *number = [bp objectForKey: @"number"];
  if (number)
    {
      NSString *location = nil;
      {
        NSEnumerator *existingEnumerator = [_breakpoints keyEnumerator];
        NSString *existing;
        while ((existing = [existingEnumerator nextObject]) != nil)
          if ([[_breakpoints objectForKey: existing] isEqual: number])
            {
              location = existing;
              break;
            }
      }
      NSString *original = [bp objectForKey: @"original-location"];
      if (!location && [_breakpoints objectForKey: original ?: @""])
        location = original;
      if (!location && file && [bp objectForKey: @"line"])
        location =
            [self locationAtFile: file
                            line: [[bp objectForKey: @"line"] integerValue]];
      if (location)
        {
          BOOL awaitingInsert = ![[_breakpoints objectForKey: location] length];
          [_breakpoints setObject: number forKey: location];
          if (file && [bp objectForKey: @"line"])
            [_resolvedLocations
                setObject: [self locationAtFile: file
                                          line: [[bp objectForKey: @"line"]
                                                   integerValue]]
                   forKey: location];
          if (awaitingInsert && [_disabledBreakpoints containsObject: location]
              && [[bp objectForKey: @"enabled"] isEqual: @"y"])
            [self command: [@"-break-disable " stringByAppendingString: number]];
          else if ([[bp objectForKey: @"enabled"] isEqual: @"n"])
            [_disabledBreakpoints addObject: location];
          else if ([[bp objectForKey: @"enabled"] isEqual: @"y"])
            [_disabledBreakpoints removeObject: location];
          if ([bp objectForKey: @"pending"] ||
              [[bp objectForKey: @"addr"] isEqual: @"<PENDING>"])
            [_delegate
                debuggerBackend: self
                         output:
                             [NSString
                                 stringWithFormat:
                                     @"Breakpoint %@ is pending at %@. GDB accepted it and will try to resolve it when its library loads after Go. If it stays pending, check the source path and debug symbols.\n",
                                     number, location]];
        }
    }
  if ([event isEqual: @"breakpoint-deleted"])
    {
      NSEnumerator *locationEnumerator =
          [[_breakpoints allKeys] objectEnumerator];
      NSString *location;
      while ((location = [locationEnumerator nextObject]) != nil)
        if ([[_breakpoints objectForKey: location]
                isEqual: [record objectForKey: @"id"]])
          {
            [_breakpoints removeObjectForKey: location];
            [_disabledBreakpoints removeObject: location];
            [_resolvedLocations removeObjectForKey: location];
          }
    }
  if (bp || [event isEqual: @"breakpoint-deleted"])
    [self saveBreakpoints];
  else if (frame || [event isEqual: @"running"] || [event isEqual: @"stopped"] ||
           [event isEqual: @"thread-group-exited"])
    [self notifyChange];
}
- (void) receiveData: (NSData *)data
{
  [_pending appendData: data];
  while ([_pending length])
    {
      const unsigned char *bytes = [_pending bytes];
      NSUInteger i = 0;
      while (i < [_pending length] && bytes[i] != '\n')
        i++;
      if (i == [_pending length])
        break;
      NSData *record = [_pending subdataWithRange: NSMakeRange (0, i)];
      NSString *line =
          [[[NSString alloc] initWithData: record
                                 encoding: NSUTF8StringEncoding] autorelease];
      if (!line)
        line = [[[NSString alloc] initWithData: record
                                      encoding: NSISOLatin1StringEncoding]
            autorelease];
      [self handleLine: [line stringByTrimmingCharactersInSet:
                                 [NSCharacterSet newlineCharacterSet]]];
      [_pending replaceBytesInRange: NSMakeRange (0, i + 1)
                          withBytes: NULL
                             length: 0];
    }
}
@end
