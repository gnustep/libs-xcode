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

#import "PBXBuildFile.h"
#import "NSArray+Additions.h"
#import "NSString+PBXAdditions.h"

@implementation NSArray (Additions)

- (NSString *) implodeArrayWithSeparator: (NSString *)separator
{
  NSString *result = @"";
  NSEnumerator *en = [self objectEnumerator];
  id object = nil;
  while((object = [en nextObject]) != nil)
    {
      NSString *obj = [separator stringByAppendingString: object];
      result = [result stringByAppendingString: obj];
    }
  return result;
}

- (NSArray *) arrayByRemovingDuplicateEntries
{
  NSArray *result = [NSArray array];
  NSEnumerator *en = [self objectEnumerator];
  id o = nil;

  while ((o = [en nextObject]) != nil)
    {
      if ([result containsObject: o] == NO)
        {
          result = [result arrayByAddingObject: o];
        }
    }

  return result;
}

- (NSString *) removeDuplicatesAndImplodeWithSeparator: (NSString *)separator
{
  NSArray *result = [self arrayByRemovingDuplicateEntries];
  return [result implodeArrayWithSeparator: separator];
}

- (NSArray *) arrayByAddingQuotationMarksToEntries
{
  NSEnumerator *en = [self objectEnumerator];
  NSString *obj = nil;
  NSMutableArray *result = [NSMutableArray arrayWithCapacity: [self count]];
  
  while ((obj = [en nextObject]) != nil)
    {
      NSString *s = [obj stringByAddingQuotationMarks];
      [result addObject: s];
    }

  return [NSArray arrayWithArray: result];
}


- (NSString *) arrayToLinkList
{
  NSString *result = @"";
  NSEnumerator *en = [self objectEnumerator];
  NSString *aname = nil;

  while((aname = [en nextObject]) != nil)
    {
      if ([aname isEqualToString: [self firstObject]] == YES)
        {
          result = [result stringByAppendingString: [NSString stringWithFormat: @"%@ ", aname]];
        }
      else
        {
          result = [result stringByAppendingString: [NSString stringWithFormat: @"\t%@ ", aname]];
        }
      
      if ([aname isEqualToString: [self lastObject]] == NO)
        {
          result = [result stringByAppendingString: @"\\\n"];
        }
    }
  
  return result;
}

- (NSString *) arrayToIncludeList
{
  NSString *result = @"-I. \\\n";
  NSEnumerator *en = [self objectEnumerator];
  NSString *aname = nil;

  while((aname = [en nextObject]) != nil)
    {
      result = [result stringByAppendingString: [NSString stringWithFormat: @"\t-I./%@ ", aname]];
      if ([aname isEqualToString: [self lastObject]] == NO)
        {
          result = [result stringByAppendingString: @"\\\n"];
        }
    }
  
  return result;
}

- (NSString *) arrayToList
{
  NSString *result = @"";
  NSEnumerator *en = [self objectEnumerator];
  id o = nil;
  
  while((o = [en nextObject]) != nil)
    {
      NSString *aname = nil;          
      if ([o isKindOfClass: [NSString class]])
        {
          aname = o;
        }
      else if ([o isKindOfClass: [PBXBuildFile class]])
        {
          PBXBuildFile *f = o;
          PBXFileReference *r = [f fileRef];
          aname = [r path];
        }

      if (aname != nil)
        {
          if ([aname isEqualToString: [self firstObject]] == YES)
            {
              result = [result stringByAppendingString: [NSString stringWithFormat: @"%@ ", aname]];
            }
          else
            {
              result = [result stringByAppendingString: [NSString stringWithFormat: @"\t%@ ", aname]];
            }
          
          if ([aname isEqualToString: [self lastObject]] == NO)
            {
              result = [result stringByAppendingString: @"\\\n"];
            }
        }
    }
  
  return result;
}

@end

@implementation NSMutableArray (Additional)

- (void) prependObjectsFromArray: (NSArray *)array
{
  NSEnumerator *en = [array objectEnumerator];
  id o = nil;

  while ((o = [en nextObject]) != nil)
    {
      [self insertObject: o atIndex: 0];
    }
}

@end
