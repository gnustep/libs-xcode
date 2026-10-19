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

#import "YCodeLanguage.h"

static BOOL
YCodeStringArray (id value)
{
  if (![value isKindOfClass: [NSArray class]])
    return NO;
  NSEnumerator *e = [value objectEnumerator];
  id item;
  while ((item = [e nextObject]))
    if (![item isKindOfClass: [NSString class]] || ![item length])
      return NO;
  return YES;
}

@implementation YCodeLanguage
- (id) initWithDefinition: (NSDictionary *)definition
{
  self = [super init];
  if (self)
    {
      if (![definition isKindOfClass: [NSDictionary class]])
        {
          [self release];
          return nil;
        }
      id name = [definition objectForKey: @"Identifier"];
      id patterns = [definition objectForKey: @"Patterns"];
      id extensions = [definition objectForKey: @"Extensions"];
      id names = [definition objectForKey: @"FileNames"];
      id style = [definition objectForKey: @"Indentation"];
      id comment = [definition objectForKey: @"LineComment"];
      id server = [definition objectForKey: @"LanguageServer"];
      if (![name isKindOfClass: [NSString class]] || ![name length]
          || ![patterns isKindOfClass: [NSDictionary class]]
          || !YCodeStringArray (extensions)
          || (names && !YCodeStringArray (names))
          || ([definition objectForKey: @"ControlKeywords"]
              && !YCodeStringArray (
                  [definition objectForKey: @"ControlKeywords"]))
          || ([definition objectForKey: @"StandaloneControls"]
              && !YCodeStringArray (
                  [definition objectForKey: @"StandaloneControls"]))
          || (style
              && ![[NSArray arrayWithObjects: @"braces", @"colon", @"blocks",
                                             @"preserve", nil]
                  containsObject: style])
          || (comment
              && (![comment isKindOfClass: [NSString class]]
                  || ![comment length] ||
                  [comment rangeOfCharacterFromSet: [NSCharacterSet
                                                       newlineCharacterSet]]
                          .location
                      != NSNotFound))
          || ([definition objectForKey: @"HighlightStringKeys"]
              && ![[definition objectForKey: @"HighlightStringKeys"]
                  isKindOfClass: [NSNumber class]])
          || (server && ![server isKindOfClass: [NSDictionary class]]))
        {
          [self release];
          return nil;
        }
      NSMutableDictionary *compiled = [NSMutableDictionary dictionary];
      NSEnumerator *e = [patterns keyEnumerator];
      NSString *key;
      while ((key = [e nextObject]))
        {
          id pattern = [patterns objectForKey: key];
          if (![pattern isKindOfClass: [NSString class]])
            {
              [self release];
              return nil;
            }
          NSRegularExpression *regex = [NSRegularExpression
              regularExpressionWithPattern: pattern
                                   options: NSRegularExpressionAnchorsMatchLines
                                     error: NULL];
          if (!regex
              || ([key isEqual: @"literal"] &&
                  [regex numberOfCaptureGroups] < 1))
            {
              [self release];
              return nil;
            }
          [compiled setObject: regex forKey: key];
        }
      _patterns = [compiled copy];
      _definition = [definition copy];
    }
  return self;
}
- (void) dealloc
{
  [_definition release];
  [_patterns release];
  [super dealloc];
}
- (BOOL) highlightStringKeys
{
  return [[_definition objectForKey: @"HighlightStringKeys"] boolValue];
}
- (NSString *) identifier
{
  return [_definition objectForKey: @"Identifier"];
}
- (NSArray *) extensions
{
  return [_definition objectForKey: @"Extensions"];
}
- (NSArray *) fileNames
{
  return [_definition objectForKey: @"FileNames"];
}
- (NSRegularExpression *) patternForToken: (NSString *)token
{
  return [_patterns objectForKey: token];
}
- (NSString *) indentationStyle
{
  return [_definition objectForKey: @"Indentation"];
}
- (NSArray *) controlKeywords
{
  return [_definition objectForKey: @"ControlKeywords"];
}
- (NSArray *) standaloneControls
{
  return [_definition objectForKey: @"StandaloneControls"];
}
- (NSString *) lineComment
{
  return [_definition objectForKey: @"LineComment"];
}
- (NSDictionary *) languageServerConfiguration
{
  return [_definition objectForKey: @"LanguageServer"];
}

/* Preserve UTF-16 offsets and line endings. Strings remain nonblank so an
 * expression containing a literal does not become an empty control header. */
- (NSString *) codeByMaskingLiterals: (NSString *)text
{
  NSRegularExpression *regex = [self patternForToken: @"literal"];
  if (!regex)
    return text;
  NSMutableString *code = [[text mutableCopy] autorelease];
  NSEnumerator *e = [[regex matchesInString: text
                                    options: 0
                                      range: NSMakeRange (0, [text length])]
      objectEnumerator];
  NSTextCheckingResult *match;
  while ((match = [e nextObject]))
    {
      NSRange range = [match range];
      NSString *replacement =
          [match rangeAtIndex: 1].location == NSNotFound ? @"x" : @" ";
      NSUInteger i;
      for (i = range.location; i < NSMaxRange (range); i++)
        {
          unichar c = [text characterAtIndex: i];
          if (c != '\r' && c != '\n')
            [code replaceCharactersInRange: NSMakeRange (i, 1)
                                withString: replacement];
        }
    }
  return code;
}
@end

@implementation YCodeLanguageRegistry
+ (YCodeLanguageRegistry *) sharedRegistry
{
  static YCodeLanguageRegistry *registry = nil;
  if (!registry)
    {
      NSMutableArray *paths = [NSMutableArray array];
      NSString *resources = [[NSBundle mainBundle] pathForResource: @"Languages"
                                                            ofType: nil];
      if (resources)
        [paths addObject: resources];
      /* System, local, then user overrides. Foundation supplies platform paths. */
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
                                          @"Ycode/Languages"]];
        }
      registry = [[self alloc] initWithSearchPaths: paths];
    }
  return registry;
}
- (id) initWithSearchPaths: (NSArray *)paths
{
  self = [super init];
  if (self)
    {
      _extensions = [NSMutableDictionary new];
      _fileNames = [NSMutableDictionary new];
      _providers = [NSMutableArray new];
      _namedLanguages = [NSMutableArray new];
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
            if ([[file pathExtension] isEqual: @"ycode-language"])
              [self loadBundleAtPath: [directory
                                         stringByAppendingPathComponent: file]];
        }
    }
  return self;
}
- (void) dealloc
{
  [_extensions release];
  [_fileNames release];
  [_providers release];
  [_namedLanguages release];
  [super dealloc];
}
- (BOOL) loadBundleAtPath: (NSString *)path
{
  @try
    {
      NSBundle *bundle = [NSBundle bundleWithPath: path];
      NSString *manifest = [bundle pathForResource: @"Language"
                                            ofType: @"plist"];
      if (!manifest)
        manifest =
            [path stringByAppendingPathComponent: @"Resources/Language.plist"];
      NSDictionary *info =
          [NSDictionary dictionaryWithContentsOfFile: manifest];
      id version = [info objectForKey: @"APIVersion"];
      if (![version isKindOfClass: [NSNumber class]] ||
          [version unsignedIntegerValue] != YCodeLanguageAPIVersion)
        return NO;
      NSArray *definitions = [info objectForKey: @"Languages"];
      id provider = nil;
      if ([[bundle infoDictionary] objectForKey: @"NSPrincipalClass"])
        {
          provider = [[[bundle principalClass] alloc] init];
          [provider autorelease];
          if (![provider respondsToSelector: @selector (languageAPIVersion)]
              || ![provider respondsToSelector: @selector (languageDefinitions)]
              || [provider languageAPIVersion] != YCodeLanguageAPIVersion)
            return NO;
          definitions = [provider languageDefinitions];
        }
      if (![definitions isKindOfClass: [NSArray class]] || ![definitions count])
        return NO;
      NSMutableArray *languages = [NSMutableArray array];
      NSEnumerator *e = [definitions objectEnumerator];
      NSDictionary *definition;
      while ((definition = [e nextObject]))
        {
          if (![definition isKindOfClass: [NSDictionary class]])
            return NO;
          YCodeLanguage *language = [[[YCodeLanguage alloc]
              initWithDefinition: definition] autorelease];
          if (!language)
            return NO;
          [languages addObject: language];
        }
      /* Validate the entire bundle before changing the live registry. */
      e = [languages objectEnumerator];
      YCodeLanguage *language;
      while ((language = [e nextObject]))
        {
          if ([language patternForToken: @"fileName"])
            [_namedLanguages addObject: language];
          NSEnumerator *keys = [[language extensions] objectEnumerator];
          NSString *key;
          while ((key = [keys nextObject]))
            [_extensions setObject: language forKey: key];
          keys = [[language fileNames] objectEnumerator];
          while ((key = [keys nextObject]))
            [_fileNames setObject: language forKey: key];
        }
      if (provider)
        [_providers addObject: provider];
      return YES;
    }
  @catch (NSException *exception)
    {
      NSLog (@"Cannot load language bundle %@: %@", path, [exception reason]);
      return NO;
    }
}
- (YCodeLanguage *) languageForFile: (NSString *)path
{
  if (![path length])
    return nil;
  NSString *name = [path lastPathComponent];
  YCodeLanguage *language = [_fileNames objectForKey: name];
  if (language)
    return language;
  NSEnumerator *e = [_namedLanguages reverseObjectEnumerator];
  while ((language = [e nextObject]))
    if ([[language patternForToken: @"fileName"]
            firstMatchInString: name
                       options: 0
                         range: NSMakeRange (0, [name length])])
      return language;
  NSString *extension = [name pathExtension];
  if (![extension length])
    extension = name;
  language = [_extensions objectForKey: extension];
  return language ? language
                  : [_extensions objectForKey: [extension lowercaseString]];
}
@end
