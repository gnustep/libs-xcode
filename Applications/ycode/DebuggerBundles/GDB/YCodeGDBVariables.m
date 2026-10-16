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

#import "YCodeGDBVariables.h"
#import "YCodeGDBDebugger.h"

@interface YCodeGDBDebugger (VariableFrame)
- (void)updateSelectedFrame:(NSDictionary *)frame;
@end

@implementation YCodeGDBVariables
- (id)initWithDebugger:(YCodeGDBDebugger *)debugger
{
  if ((self = [super init])) {
    _debugger = debugger;
    _groups = [NSMutableArray new];
    _requests = [NSMutableDictionary new];
    _objects = [NSMutableArray new];
    _token = 1000000;
  }
  return self;
}
- (void)dealloc
{
  [_groups release]; [_requests release]; [_objects release]; [_file release];
  [super dealloc];
}
- (NSArray *)groups { return _groups; }
- (void)changed
{
  [_debugger notifyChange];
}
- (void)request:(NSString *)command kind:(NSString *)kind node:(NSMutableDictionary *)node
{
  NSString *token = [NSString stringWithFormat:@"%lu", (unsigned long)++_token];
  NSMutableDictionary *request = [NSMutableDictionary dictionaryWithObjectsAndKeys:
    kind, @"kind", [NSNumber numberWithUnsignedInteger:_generation], @"generation", nil];
  if (node) [request setObject:node forKey:@"node"];
  [_requests setObject:request forKey:token];
  [_debugger command:[token stringByAppendingString:command]];
}
- (void)clear
{
  _generation++;
  NSEnumerator *objects = [_objects objectEnumerator];
  NSString *name;
  while ((name = [objects nextObject]) != nil)
    [self request:[@"-var-delete " stringByAppendingString:name] kind:@"delete" node:nil];
  [_objects removeAllObjects];
  [_groups removeAllObjects];
}
- (void)reset
{
  _generation++;
  _stopped = NO;
  [_groups removeAllObjects]; [_objects removeAllObjects]; [_requests removeAllObjects];
  [_file release]; _file = nil;
}
- (void)refresh
{
  if (!_enabled || !_stopped || ![_debugger isReady] || [_debugger isRunning]) return;
  [self clear];
  [self request:@"-stack-info-frame" kind:@"frame" node:nil];
  [self changed];
}
- (void)setEnabled:(BOOL)enabled
{
  if (_enabled == enabled) return;
  _enabled = enabled;
  if (enabled) [self refresh];
  else { [self clear]; [self changed]; }
}
- (NSMutableDictionary *)group:(NSString *)name
{
  NSMutableDictionary *group = [NSMutableDictionary dictionaryWithObjectsAndKeys:
    name, @"name", [NSMutableArray array], @"children", @"", @"value", nil];
  [_groups addObject:group];
  return group;
}
- (void)addVariable:(NSDictionary *)variable expression:(NSString *)expression group:(NSMutableDictionary *)group
{
  NSMutableDictionary *node = [NSMutableDictionary dictionaryWithObjectsAndKeys:
    [variable objectForKey:@"name"] ?: expression, @"name",
    [variable objectForKey:@"value"] ?: @"Loading…", @"value",
    [variable objectForKey:@"type"] ?: @"", @"type", nil];
  [[group objectForKey:@"children"] addObject:node];
  NSString *name = [NSString stringWithFormat:@"yc_var_%lu", (unsigned long)++_token];
  [_objects addObject:name];
  [node setObject:name forKey:@"object"];
  [self request:[NSString stringWithFormat:@"-var-create %@ * %@", name,
    [YCodeGDBDebugger quote:expression]] kind:@"value" node:node];
}
- (void)loadChildren:(NSMutableDictionary *)node
{
  if (!_enabled || !_stopped || [_debugger isRunning] || [node objectForKey:@"children"] ||
      ![node objectForKey:@"object"]) return;
  [node setObject:[NSMutableArray array] forKey:@"children"];
  [self request:[NSString stringWithFormat:@"-var-list-children --all-values %@ 0 200",
    [node objectForKey:@"object"]] kind:@"children" node:node];
}
- (BOOL)handleRecord:(NSDictionary *)record
{
  NSString *token = [record objectForKey:@"token"];
  NSDictionary *request = token ? [_requests objectForKey:token] : nil;
  NSString *event = [record objectForKey:@"event"];
  if (!request) {
    if ([event isEqual:@"running"] || [event isEqual:@"thread-group-exited"] ||
        ([event isEqual:@"stopped"] && [[record objectForKey:@"reason"] hasPrefix:@"exited"])) {
      _stopped = NO; [self clear]; [self changed];
    } else if ([event isEqual:@"stopped"]) {
      _stopped = YES; [self refresh];
    } else if (_stopped && ([event isEqual:@"done"] || [event isEqual:@"thread-selected"])) {
      [self refresh];
    }
    return NO;
  }
  [request retain];
  [_requests removeObjectForKey:token];
  if ([[request objectForKey:@"generation"] unsignedIntegerValue] != _generation) {
    [request release]; return YES;
  }
  NSString *kind = [request objectForKey:@"kind"];
  NSMutableDictionary *node = [request objectForKey:@"node"];
  if ([event isEqual:@"error"]) {
    if (node) [node setObject:[record objectForKey:@"msg"] ?: @"Unavailable" forKey:@"value"];
    if ([kind isEqual:@"frame"]) {
      NSMutableDictionary *group = [self group:@"Variables"];
      [group setObject:@"No stopped frame available" forKey:@"value"];
    }
  } else if ([kind isEqual:@"frame"]) {
    NSDictionary *frame = [record objectForKey:@"frame"];
    [_debugger updateSelectedFrame:frame];
    do { id value = ([frame objectForKey:@"fullname"] ?: [frame objectForKey:@"file"]); [value retain]; [_file release]; _file = value; } while (0);
    NSMutableDictionary *locals = [self group:@"Locals"];
    NSMutableDictionary *globals = [self group:@"Globals (current file)"];
    [self request:@"-stack-list-variables --all-values" kind:@"locals" node:locals];
    if ([_file length]) [self request:@"-symbol-info-variables" kind:@"globals" node:globals];
    else [globals setObject:@"No source file for this frame" forKey:@"value"];
  } else if ([kind isEqual:@"locals"]) {
    NSEnumerator *variables = [[record objectForKey:@"variables"] objectEnumerator];
    NSDictionary *variable;
    while ((variable = [variables nextObject]) != nil)
      if ([[variable objectForKey:@"name"] length])
        [self addVariable:variable expression:[variable objectForKey:@"name"] group:node];
  } else if ([kind isEqual:@"globals"]) {
    NSEnumerator *files = [[[record objectForKey:@"symbols"] objectForKey:@"debug"] objectEnumerator];
    NSDictionary *file;
    while ((file = [files nextObject]) != nil) {
      NSString *path = [file objectForKey:@"fullname"] ?: [file objectForKey:@"filename"];
      if (![[path stringByStandardizingPath] isEqual:[_file stringByStandardizingPath]]) continue;
      NSEnumerator *symbols = [[file objectForKey:@"symbols"] objectEnumerator];
      NSDictionary *symbol;
      while ((symbol = [symbols nextObject]) != nil) {
        NSString *name = [symbol objectForKey:@"name"];
        if (![name length]) continue;
        // Qualify by source file so a local with the same name cannot shadow it.
        NSString *quotedFile = [_file stringByReplacingOccurrencesOfString:@"'" withString:@"\\'"];
        [self addVariable:symbol expression:[NSString stringWithFormat:@"'%@'::%@", quotedFile, name] group:node];
      }
    }
  } else if ([kind isEqual:@"value"]) {
    [node setObject:[record objectForKey:@"value"] ?: @"" forKey:@"value"];
    [node setObject:[record objectForKey:@"valueType"] ?: @"" forKey:@"type"];
    [node setObject:[record objectForKey:@"numchild"] ?: @"0" forKey:@"numchild"];
  } else if ([kind isEqual:@"children"]) {
    NSEnumerator *children = [[record objectForKey:@"children"] objectEnumerator];
    NSDictionary *entry;
    while ((entry = [children nextObject]) != nil) {
      NSDictionary *child = [entry objectForKey:@"child"] ?: entry;
      NSMutableDictionary *item = [NSMutableDictionary dictionaryWithObjectsAndKeys:
        [child objectForKey:@"exp"] ?: @"", @"name", [child objectForKey:@"value"] ?: @"", @"value",
        [child objectForKey:@"type"] ?: @"", @"type", [child objectForKey:@"numchild"] ?: @"0", @"numchild", nil];
      if ([child objectForKey:@"name"]) [item setObject:[child objectForKey:@"name"] forKey:@"object"];
      [[node objectForKey:@"children"] addObject:item];
    }
    if ([[record objectForKey:@"has_more"] boolValue])
      [[node objectForKey:@"children"] addObject:[NSMutableDictionary dictionaryWithObjectsAndKeys:
        @"…", @"name", @"First 200 children shown", @"value", nil]];
  }
  if (![kind isEqual:@"delete"]) [self changed];
  [request release];
  return YES;
}
@end
