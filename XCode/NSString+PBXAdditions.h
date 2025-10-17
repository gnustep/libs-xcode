/*
   Copyright (C) 2018, 2019, 2020, 2021 Free Software Foundation, Inc.

   Written by: Gregory John Casamento <greg.casamento@gmail.com>
   Date: 2022
   
   This file is part of the GNUstep XCode Library

   This library is free software; you can redistribute it and/or
   modify it under the terms of the GNU Lesser General Public
   License as published by the Free Software Foundation; either
   version 2 of the License, or (at your option) any later version.
   
   This library is distributed in the hope that it will be useful,
   but WITHOUT ANY WARRANTY; without even the implied warranty of
   MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
   Lesser General Public License for more details.
   
   You should have received a copy of the GNU Lesser General Public
   License along with this library; if not, write to the Free
   Software Foundation, Inc., 51 Franklin Street, Fifth Floor,
   Boston, MA 02110 USA.
*/

#import <Foundation/NSString.h>

@interface NSString (PBXAdditions)

/**
 * Returns the first path component of the receiver.
 */
- (NSString *) firstPathComponent;

/**
 * Returns a string with the path extension replaced.
 */
- (NSString *) stringByReplacingPathExtensionWith: (NSString *)ext;

/**
 * Returns a string with special characters escaped.
 */
- (NSString *) stringByEscapingSpecialCharacters;

/**
 * Returns a string with special characters eliminated.
 */
- (NSString *) stringByEliminatingSpecialCharacters;

/**
 * Returns a string with the first character capitalized.
 */
- (NSString *) stringByCapitalizingFirstCharacter;

/**
 * Returns a string with the first path component deleted.
 */
- (NSString *) stringByDeletingFirstPathComponent;

/**
 * Returns a string with environment variables replaced by their values.
 */
- (NSString *) stringByReplacingEnvironmentVariablesWithValues;

/**
 * Returns a string with quotation marks added.
 */
- (NSString *) stringByAddingQuotationMarks;

/**
 * Returns the executable path for this string.
 */
- (NSString *) execPathForString;

/**
 * Returns the output string from executing the given command.
 */
+ (NSString *) stringForCommand: (NSString *)command;

/**
 * Returns the string value for the given environment variable.
 */
+ (NSString *) stringForEnvironmentVariable: (char *)envvar;

/**
 * Returns the string value for the given environment variable with a default.
 */
+ (NSString *) stringForEnvironmentVariable: (NSString *)v
                               defaultValue: (NSString *)d;

/**
 * Returns a string with trailing characters from the set trimmed.
 */
- (NSString *) stringByTrimmingTrailingCharactersInSet: (NSCharacterSet *)characterSet;

/**
 * Returns a string with the path resolved.
 */
- (NSString *) stringByResolvingPath;

/**
 * Returns a string with the first character in lowercase.
 */
- (NSString *) lowercaseFirstCharacter;

@end
