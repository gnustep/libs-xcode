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

#ifndef YCODE_LANGUAGE_H
#define YCODE_LANGUAGE_H
#import <Foundation/Foundation.h>

#define YCodeLanguageAPIVersion 1

/* Optional principal class of an executable language bundle. Definitions use
 * the same schema as Languages in Language.plist. No AppKit dependency. */
@protocol YCodeLanguageProvider <NSObject>
- (NSUInteger) languageAPIVersion;
- (NSArray *) languageDefinitions;
@end

@interface YCodeLanguage : NSObject
{
  NSDictionary *_definition;
  NSDictionary *_patterns;
}

- (id) initWithDefinition: (NSDictionary *)definition;
- (NSString *) identifier;
- (BOOL) highlightStringKeys;
- (NSArray *) extensions;
- (NSArray *) fileNames;
- (NSRegularExpression *) patternForToken: (NSString *)token;
- (NSString *) codeByMaskingLiterals: (NSString *)text;
- (NSString *) indentationStyle;
- (NSArray *) completionKeywords;
- (NSArray *) controlKeywords;
- (NSArray *) standaloneControls;
- (NSString *) lineComment;
- (NSDictionary *) languageServerConfiguration;
@end

@interface YCodeLanguageRegistry : NSObject
{
  NSMutableDictionary *_extensions;
  NSMutableDictionary *_fileNames;
  NSMutableArray *_providers;
  NSMutableArray *_namedLanguages;
}

+ (YCodeLanguageRegistry *) sharedRegistry;
/* An explicit path list also permits isolated registries for tools/tests.
 * Later directories override earlier directories. */
- (id) initWithSearchPaths: (NSArray *)paths;
- (BOOL) loadBundleAtPath: (NSString *)path;
- (YCodeLanguage *) languageForFile: (NSString *)path;
@end
#endif
