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

#ifndef _YCODEEDITORREGISTRY_H_
#define _YCODEEDITORREGISTRY_H_
#import "YCodeEditorDocument.h"

/** Discovers editor bundles in application resources and Library/Ycode/Editors.
 * Later search paths override matching identifiers. Equal priorities are ordered
 * by identifier. Bundles remain loaded for the lifetime of the process.
 */
@interface YCodeEditorRegistry : NSObject
{
  NSMutableDictionary *_classes;
  NSMutableArray *_bundles;
}

+ (YCodeEditorRegistry *) sharedRegistry;
- (id) initWithSearchPaths: (NSArray *)paths;
- (BOOL) loadBundleAtPath: (NSString *)path;
- (NSArray *) editorIdentifiers;
- (Class) editorClassForFilePath: (NSString *)path;
@end
#endif
