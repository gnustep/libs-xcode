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

#import "YCodeEditorRegistry.h"

@implementation YCodeEditorRegistry
+ (YCodeEditorRegistry *) sharedRegistry
{
  static YCodeEditorRegistry *registry = nil;
  if (!registry)
    {
      NSMutableArray *paths = [NSMutableArray array];
      NSString *resources = [[NSBundle mainBundle] pathForResource: @"Editors"
                                                            ofType: nil];
      if (resources)
        [paths addObject: resources];
      NSUInteger domains[]
          = { NSSystemDomainMask, NSLocalDomainMask, NSUserDomainMask };
      NSUInteger i;
      for (i = 0; i < 3; i++)
        {
          NSEnumerator *e = [NSSearchPathForDirectoriesInDomains (
              NSLibraryDirectory, domains[i], YES) objectEnumerator];
          NSString *library;
          while ((library = [e nextObject]))
            [paths addObject: [library stringByAppendingPathComponent:
                                          @"Ycode/Editors"]];
        }
      registry = [[self alloc] initWithSearchPaths: paths];
    }
  return registry;
}

- (id) initWithSearchPaths: (NSArray *)paths
{
  if ((self = [super init]))
    {
      _classes = [NSMutableDictionary new];
      _bundles = [NSMutableArray new];
      NSEnumerator *e = [paths objectEnumerator];
      NSString *directory;
      while ((directory = [e nextObject]))
        {
          NSArray *files = [[[NSFileManager defaultManager]
              contentsOfDirectoryAtPath: directory
                                  error: NULL]
              sortedArrayUsingSelector: @selector (compare:)];
          NSEnumerator *f = [files objectEnumerator];
          NSString *file;
          while ((file = [f nextObject]))
            if ([[file pathExtension] isEqual: @"bundle"])
              [self loadBundleAtPath: [directory
                                         stringByAppendingPathComponent: file]];
        }
    }
  return self;
}

- (void) dealloc
{
  [_classes release];
  [_bundles release];
  [super dealloc];
}

- (BOOL) loadBundleAtPath: (NSString *)path
{
  @try
    {
      NSBundle *bundle = [NSBundle bundleWithPath: path];
      Class principal = [bundle principalClass];
      if (![principal isSubclassOfClass: [YCodeEditorDocument class]] ||
          [principal editorAPIVersion] != 1)
        return NO;
      NSString *identifier = [principal editorIdentifier];
      if (![identifier isKindOfClass: [NSString class]] || ![identifier length])
        return NO;
      [_classes setObject: principal forKey: identifier];
      [_bundles addObject: bundle];
      return YES;
    }
  @catch (NSException *exception)
    {
      NSLog (@"Cannot load editor bundle %@: %@", path, [exception reason]);
      return NO;
    }
}

- (NSArray *) editorIdentifiers
{
  return [[_classes allKeys] sortedArrayUsingSelector: @selector (compare:)];
}

- (Class) editorClassForFilePath: (NSString *)path
{
  Class selected = Nil;
  NSEnumerator *enumerator = [[self editorIdentifiers] objectEnumerator];
  NSString *identifier;
  while ((identifier = [enumerator nextObject]))
    {
      Class candidate = [_classes objectForKey: identifier];
      @try
        {
          if ([candidate canOpenFilePath: path]
              && (!selected ||
                  [candidate editorPriority] > [selected editorPriority]))
            selected = candidate;
        }
      @catch (NSException *exception)
        {
          NSLog (@"Cannot select editor %@: %@", identifier,
                 [exception reason]);
        }
    }
  return selected;
}

@end
