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

#import <Foundation/Foundation.h>

@interface NSArray (Additions)

/**
 * Returns a string by joining array elements with the given separator.
 */
- (NSString *) implodeArrayWithSeparator: (NSString *)separator;

/**
 * Returns an array with duplicate entries removed.
 */
- (NSArray *) arrayByRemovingDuplicateEntries;

/**
 * Returns a string by removing duplicates and joining with the separator.
 */
- (NSString *) removeDuplicatesAndImplodeWithSeparator: (NSString *)separator;

/**
 * Returns an array with quotation marks added to each entry.
 */
- (NSArray *) arrayByAddingQuotationMarksToEntries;

/**
 * Returns a string formatted as a link list.
 */
- (NSString *) arrayToLinkList;

/**
 * Returns a string formatted as an include list.
 */
- (NSString *) arrayToIncludeList;

/**
 * Returns a string formatted as a list.
 */
- (NSString *) arrayToList;

@end

@interface NSMutableArray (Additions)

/**
 * Prepends objects from the given array to the receiver.
 */
- (void) prependObjectsFromArray: (NSArray *)array;

@end
