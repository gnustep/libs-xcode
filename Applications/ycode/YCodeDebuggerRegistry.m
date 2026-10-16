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

#import "YCodeDebuggerRegistry.h"

@implementation YCodeDebuggerRegistry
+ (YCodeDebuggerRegistry *)sharedRegistry
{
  static YCodeDebuggerRegistry *registry = nil;
  if (!registry)
    {
      NSMutableArray *paths = [NSMutableArray array];
      NSString *resources = [[NSBundle mainBundle] pathForResource:@"Debuggers" ofType:nil];
      if (resources) [paths addObject:resources];
      NSUInteger domains[] = { NSSystemDomainMask, NSLocalDomainMask, NSUserDomainMask };
      NSUInteger i;
      for (i = 0; i < 3; i++)
        {
          NSEnumerator *e = [NSSearchPathForDirectoriesInDomains(NSLibraryDirectory, domains[i], YES) objectEnumerator];
          NSString *library;
          while ((library = [e nextObject]))
            [paths addObject:[library stringByAppendingPathComponent:@"Ycode/Debuggers"]];
        }
      registry = [[self alloc] initWithSearchPaths:paths];
    }
  return registry;
}
- (id)initWithSearchPaths:(NSArray *)paths
{
  if ((self = [super init]))
    {
      _classes = [NSMutableDictionary new];
      _bundles = [NSMutableArray new];
      NSEnumerator *e = [paths objectEnumerator];
      NSString *directory;
      while ((directory = [e nextObject]))
        {
          NSArray *files = [[[NSFileManager defaultManager] contentsOfDirectoryAtPath:directory error:NULL]
              sortedArrayUsingSelector:@selector(compare:)];
          NSEnumerator *f = [files objectEnumerator];
          NSString *file;
          while ((file = [f nextObject]))
            if ([[file pathExtension] isEqual:@"bundle"])
              [self loadBundleAtPath:[directory stringByAppendingPathComponent:file]];
        }
    }
  return self;
}
- (void)dealloc
{
  [_classes release]; [_bundles release]; [super dealloc];
}
- (BOOL)loadBundleAtPath:(NSString *)path
{
  @try
    {
      NSBundle *bundle = [NSBundle bundleWithPath:path];
      NSString *manifest = [bundle pathForResource:@"Debugger" ofType:@"plist"];
      NSDictionary *info = [NSDictionary dictionaryWithContentsOfFile:manifest];
      id version = [info objectForKey:@"APIVersion"];
      NSString *identifier = [info objectForKey:@"Identifier"];
      if (![version isKindOfClass:[NSNumber class]] ||
          ![version isEqual:[NSNumber numberWithInt:YCodeDebuggerBackendAPIVersion]] ||
          ![identifier isKindOfClass:[NSString class]] || ![identifier length]) return NO;
      Class principal = [bundle principalClass];
      if (![principal respondsToSelector:@selector(debuggerAPIVersion)] ||
          ![principal respondsToSelector:@selector(debuggerIdentifier)] ||
          ![principal respondsToSelector:@selector(debuggerDisplayName)] ||
          [principal debuggerAPIVersion] != YCodeDebuggerBackendAPIVersion ||
          ![[principal debuggerIdentifier] isEqual:identifier]) return NO;
      id name = [principal debuggerDisplayName];
      if (![name isKindOfClass:[NSString class]] || ![name length]) return NO;
      SEL required[] = {
        @selector(setDelegate:), @selector(launchCommandForExecutable:),
        @selector(launchArgumentsForExecutable:), @selector(canPerformAction:),
        @selector(performAction:), @selector(consoleCommand:), @selector(receiveData:),
        @selector(reset), @selector(isReady), @selector(isRunning),
        @selector(setSourceDirectory:), @selector(setBreakpointStorageKey:),
        @selector(canSetBreakpointAtFile:), @selector(breakpointLinesForFile:),
        @selector(breakpointStateAtFile:line:), @selector(toggleBreakpointAtFile:line:),
        @selector(toggleBreakpointEnabledAtFile:line:), @selector(executionFile),
        @selector(executionLine), @selector(variables)
      };
      NSUInteger i;
      for (i = 0; i < sizeof(required) / sizeof(required[0]); i++)
        if (![principal instancesRespondToSelector:required[i]]) return NO;
      [_classes setObject:principal forKey:identifier];
      [_bundles addObject:bundle];
      return YES;
    }
  @catch (NSException *exception)
    {
      NSLog(@"Cannot load debugger bundle %@: %@", path, [exception reason]);
      return NO;
    }
}
- (NSArray *)backendIdentifiers
{
  return [[_classes allKeys] sortedArrayUsingSelector:@selector(compare:)];
}
- (id<YCodeDebuggerBackend>)newBackendWithIdentifier:(NSString *)identifier
{
  if (![identifier length]) identifier = [[NSUserDefaults standardUserDefaults] stringForKey:@"YCodeDebuggerBackend"];
  if (![identifier length]) identifier = @"gdb";
  @try { return [[[_classes objectForKey:identifier] alloc] init]; }
  @catch (NSException *exception)
    {
      NSLog(@"Cannot create debugger %@: %@", identifier, [exception reason]);
      return nil;
    }
}
@end
