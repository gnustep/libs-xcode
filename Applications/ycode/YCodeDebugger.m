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

#import "YCodeDebugger.h"

/* Like ProjectCenter's GDBWrapper, decode MI tuples, lists and C strings.
 * Always advance on malformed input, and retain bytes until a complete record
 * arrives (including when a UTF-8 character spans two pipe reads).
 */
static id YCReadValue(NSScanner *scanner);
static NSDictionary *YCReadFields(NSScanner *scanner)
{
  NSMutableDictionary *fields = [NSMutableDictionary dictionary];
  while (![scanner isAtEnd])
    {
      NSString *key = nil;
      if ([scanner scanString:@"}" intoString:NULL]) break;
      [scanner scanUpToCharactersFromSet:[NSCharacterSet characterSetWithCharactersInString:@"=,}]"] intoString:&key];
      if (![scanner scanString:@"=" intoString:NULL]) break;
      id value = YCReadValue(scanner);
      if (key && value) [fields setObject:value forKey:key];
      if (![scanner scanString:@"," intoString:NULL])
        { [scanner scanString:@"}" intoString:NULL]; break; }
    }
  return fields;
}
static id YCReadValue(NSScanner *scanner)
{
  if ([scanner scanString:@"\"" intoString:NULL])
    {
      NSMutableString *value = [NSMutableString string];
      NSString *text = [scanner string];
      NSUInteger i = [scanner scanLocation];
      while (i < [text length])
        {
          unichar c = [text characterAtIndex:i++];
          if (c == '"') break;
          if (c == '\\' && i < [text length])
            {
              c = [text characterAtIndex:i++];
              if (c == 'n') c = '\n';
              else if (c == 'r') c = '\r';
              else if (c == 't') c = '\t';
              else if (c >= '0' && c <= '7')
                {
                  unsigned int n = c - '0', count = 1;
                  while (count < 3 && i < [text length] &&
                    [text characterAtIndex:i] >= '0' && [text characterAtIndex:i] <= '7')
                    { n = n * 8 + [text characterAtIndex:i++] - '0'; count++; }
                  c = n;
                }
            }
          [value appendFormat:@"%C", c];
        }
      [scanner setScanLocation:i];
      return value;
    }
  if ([scanner scanString:@"{" intoString:NULL]) return YCReadFields(scanner);
  if ([scanner scanString:@"[" intoString:NULL])
    {
      NSMutableArray *values = [NSMutableArray array];
      while (![scanner isAtEnd] && ![scanner scanString:@"]" intoString:NULL])
        {
          NSUInteger start = [scanner scanLocation];
          NSString *key = nil;
          unichar c = [[scanner string] characterAtIndex:start];
          if (c != '"' && c != '{' && c != '[')
            {
              [scanner scanUpToString:@"=" intoString:&key];
              [scanner scanString:@"=" intoString:NULL];
            }
          id value = YCReadValue(scanner);
          if (value) [values addObject:key ? [NSDictionary dictionaryWithObject:value forKey:key] : value];
          [scanner scanString:@"," intoString:NULL];
          if ([scanner scanLocation] <= start) break;
        }
      return values;
    }
  return nil;
}

@implementation YCodeDebugger
- (id)init
{
  if ((self = [super init]))
    { _pending = [NSMutableData new]; _breakpoints = [NSMutableDictionary new]; }
  return self;
}
- (void)dealloc
{
  RELEASE(_storageKey); RELEASE(_pending); RELEASE(_breakpoints); [super dealloc];
}
- (void)setDelegate:(id<YCodeDebuggerDelegate>)delegate { _delegate = delegate; }
- (BOOL)isReady { return _ready; }
- (BOOL)isRunning { return _running; }
- (void)setBreakpointStorageKey:(NSString *)key
{
  ASSIGN(_storageKey, key);
  [_breakpoints removeAllObjects];
  id saved = [[NSUserDefaults standardUserDefaults] objectForKey:key];
  if ([saved isKindOfClass:[NSArray class]])
    for (id location in saved)
      if ([location isKindOfClass:[NSString class]]) [_breakpoints setObject:@"" forKey:location];
}
- (void)saveBreakpoints
{
  if (_storageKey) [[NSUserDefaults standardUserDefaults] setObject:[_breakpoints allKeys] forKey:_storageKey];
}
- (void)restart
{
  if (_running)
    { _restartPending = YES; [self command:@"-exec-interrupt --all"]; }
  else [self command:@"-exec-run"];
}
- (void)reset
{
  _ready = _running = _restartPending = NO;
  [_pending setLength:0];
  for (NSString *location in [_breakpoints allKeys]) [_breakpoints setObject:@"" forKey:location];
}
+ (NSString *)quote:(NSString *)string
{
  string = [string stringByReplacingOccurrencesOfString:@"\\" withString:@"\\\\"];
  string = [string stringByReplacingOccurrencesOfString:@"\"" withString:@"\\\""];
  string = [string stringByReplacingOccurrencesOfString:@"\n" withString:@"\\n"];
  string = [string stringByReplacingOccurrencesOfString:@"\r" withString:@"\\r"];
  return [NSString stringWithFormat:@"\"%@\"", string];
}
+ (NSDictionary *)parseRecord:(NSString *)record
{
  NSScanner *scanner = [NSScanner scannerWithString:record];
  [scanner setCharactersToBeSkipped:nil];
  [scanner scanCharactersFromSet:[NSCharacterSet decimalDigitCharacterSet] intoString:NULL];
  if ([scanner isAtEnd]) return nil;
  NSString *type = [record substringWithRange:NSMakeRange([scanner scanLocation], 1)];
  [scanner setScanLocation:[scanner scanLocation] + 1];
  if ([@"~@&" rangeOfString:type].location != NSNotFound)
    return [NSDictionary dictionaryWithObjectsAndKeys:type, @"type", YCReadValue(scanner) ?: @"", @"text", nil];
  if ([@"^*=+" rangeOfString:type].location == NSNotFound) return nil;
  NSString *event = nil;
  [scanner scanUpToString:@"," intoString:&event];
  [scanner scanString:@"," intoString:NULL];
  NSMutableDictionary *result = [NSMutableDictionary dictionaryWithDictionary:YCReadFields(scanner)];
  [result setObject:type forKey:@"type"];
  [result setObject:event ?: @"" forKey:@"event"];
  return result;
}
- (void)command:(NSString *)command
{
  if (_ready) [_delegate debugger:self sendCommand:[command stringByAppendingString:@"\n"]];
}
- (void)consoleCommand:(NSString *)command
{
  [self command:[@"-interpreter-exec console " stringByAppendingString:[[self class] quote:command]]];
}
- (void)toggleBreakpointAtFile:(NSString *)file line:(NSUInteger)line
{
  if (![file length] || line == 0 || _running) return;
  NSString *location = [NSString stringWithFormat:@"%@:%lu", file, (unsigned long)line];
  NSString *number = [_breakpoints objectForKey:location];
  BOOL removing = (number != nil);
  if (removing)
    {
      if ([number length]) [self command:[@"-break-delete " stringByAppendingString:number]];
      else if (_ready) [self consoleCommand:[@"clear " stringByAppendingString:[[self class] quote:location]]];
      [_breakpoints removeObjectForKey:location];
    }
  else
    {
      [_breakpoints setObject:@"" forKey:location];
      [self command:[@"-break-insert -f " stringByAppendingString:[[self class] quote:location]]];
    }
  [_delegate debugger:self output:[NSString stringWithFormat:@"Breakpoint %@: %@\n", removing ? @"removed" : @"added", location]];
  [self saveBreakpoints];
}
- (void)handleLine:(NSString *)line
{
  if ([line hasPrefix:@"(gdb)"])
    {
      if (!_ready)
        {
          _ready = YES;
          [self command:@"-gdb-set confirm off"];
          [self command:@"-gdb-set pagination off"];
          [self command:@"-gdb-set mi-async on"];
          for (NSString *location in _breakpoints)
            [self command:[@"-break-insert -f " stringByAppendingString:[[self class] quote:location]]];
          [_delegate debugger:self output:@"Debugger ready. Use Go to run, or set breakpoints first.\n"];
        }
      return;
    }
  NSDictionary *record = [[self class] parseRecord:line];
  NSString *type = [record objectForKey:@"type"], *event = [record objectForKey:@"event"];
  if (!record || [type isEqual:@"~"] || [type isEqual:@"@"])
    [_delegate debugger:self output:record ? [record objectForKey:@"text"] : [line stringByAppendingString:@"\n"]];
  if ([event isEqual:@"error"])
    [_delegate debugger:self output:[NSString stringWithFormat:@"Debugger error: %@\n", [record objectForKey:@"msg"]]];
  if ([event isEqual:@"running"]) _running = YES;
  if ([event isEqual:@"stopped"])
    {
      _running = NO;
      [_delegate debugger:self output:[NSString stringWithFormat:@"Stopped: %@\n", [record objectForKey:@"reason"] ?: @"paused"]];
    }
  if (_restartPending && [event isEqual:@"stopped"])
    { _restartPending = NO; [self command:@"-exec-run"]; }
  NSDictionary *frame = [record objectForKey:@"frame"];
  NSString *file = [frame objectForKey:@"fullname"] ?: [frame objectForKey:@"file"];
  if (file && [[frame objectForKey:@"line"] integerValue] > 0)
    [_delegate debugger:self stoppedAtFile:file line:[[frame objectForKey:@"line"] integerValue]];
  NSDictionary *bp = [record objectForKey:@"bkpt"];
  file = [bp objectForKey:@"fullname"] ?: [bp objectForKey:@"file"];
  if (file && [bp objectForKey:@"line"] && [bp objectForKey:@"number"])
    {
      NSString *location = [bp objectForKey:@"original-location"];
      NSString *number = [bp objectForKey:@"number"];
      if (!location || ![_breakpoints objectForKey:location])
        {
          location = nil;
          for (NSString *existing in _breakpoints)
            if ([[_breakpoints objectForKey:existing] isEqual:number])
              { location = existing; break; }
          if (!location) location = [NSString stringWithFormat:@"%@:%@", file, [bp objectForKey:@"line"]];
        }
      /* GDB may move a breakpoint from a blank line to executable code.
       * Keep its requested location so toggling that line still removes it.
       */
      [_breakpoints setObject:number forKey:location];
    }
  if ([event isEqual:@"breakpoint-deleted"])
    for (NSString *location in [_breakpoints allKeys])
      if ([[_breakpoints objectForKey:location] isEqual:[record objectForKey:@"id"]]) [_breakpoints removeObjectForKey:location];
  if (bp || [event isEqual:@"breakpoint-deleted"]) [self saveBreakpoints];
}
- (void)receiveData:(NSData *)data
{
  [_pending appendData:data];
  while ([_pending length])
    {
      const unsigned char *bytes = [_pending bytes];
      NSUInteger i = 0;
      while (i < [_pending length] && bytes[i] != '\n') i++;
      if (i == [_pending length]) break;
      NSData *record = [_pending subdataWithRange:NSMakeRange(0, i)];
      NSString *line = AUTORELEASE([[NSString alloc] initWithData:record encoding:NSUTF8StringEncoding]);
      if (!line) line = AUTORELEASE([[NSString alloc] initWithData:record encoding:NSISOLatin1StringEncoding]);
      [self handleLine:[line stringByTrimmingCharactersInSet:[NSCharacterSet newlineCharacterSet]]];
      [_pending replaceBytesInRange:NSMakeRange(0, i + 1) withBytes:NULL length:0];
    }
}
@end
