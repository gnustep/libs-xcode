/*
   Copyright (C) 2024 Free Software Foundation, Inc.

   Written by: Gregory John Casamento <greg.casamento@gmail.com>
   Date: 2024
   
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

#import <objc/runtime.h>

#import "NSObject+KeyExtraction.h"
#import "NSString+PBXAdditions.h"

@implementation NSObject (KeyExtraction)

- (NSArray *) skippedKeys
{
  return [NSArray arrayWithObjects: @"context", nil];
}

- (NSArray *) keysForObject: (id)object
{
  unsigned int methodCount = 0;
  Method *methods = class_copyMethodList([object class], &methodCount);
  NSMutableArray *result = [NSMutableArray arrayWithCapacity: methodCount];
    
  for (unsigned int i = 0; i < methodCount; i++)
    {
      Method method = methods[i];
      const char *selName = sel_getName(method_getName(method));
      NSString *selectorName = [NSString stringWithUTF8String: selName];

      if ([selectorName hasPrefix: @"set"])
	{
	  NSString *keyName = [selectorName substringFromIndex: 3];

	  keyName = [keyName stringByReplacingOccurrencesOfString: @":" withString: @""];
	  keyName = [keyName lowercaseFirstCharacter];
	  [result addObject: keyName];
	}
    }
  
  free(methods);

  return result;
}

- (NSDictionary *) recursiveKeysAndValuesForObject: (id)object
{
  NSMutableDictionary *keysAndValues = [NSMutableDictionary dictionary];
  NSMutableArray *missingKeys = [NSMutableArray array];
  
  if (object && [object isKindOfClass: [NSNull class]] == NO)
    {
      NSArray *properties = [self keysForObject: object];
      NSEnumerator *pen = [properties objectEnumerator];
      id key = nil;
      
      while ((key = [pen nextObject]) != nil)
	{
	  if ([[self skippedKeys] containsObject: key])
	    {
	      continue;
	    }
	  
	  NS_DURING
	    {
	      id value = [object valueForKey: key];
	      
	      if ([value isKindOfClass: [NSArray class]])
		{
		  NSMutableArray *arrayValues = [NSMutableArray array];
		  NSEnumerator *en = [value objectEnumerator];
		  id item = nil;
		  
		  while ((item = [en nextObject]) != nil)
		    {
		      [arrayValues addObject: [self recursiveKeysAndValuesForObject: item]];
		    }
		  
		  [keysAndValues setObject: arrayValues
				    forKey: key];
		}
	      else if ([value isKindOfClass: [NSDictionary class]])
		{
		  NSMutableDictionary *dictValues = [NSMutableDictionary dictionary];
		  NSEnumerator *en = [value keyEnumerator];
		  id dictKey = nil;
		  
		  while ((dictKey = [en nextObject]) != nil)
		    {
		      id dictValue = [value objectForKey: dictKey];
		      [dictValues setObject: [self recursiveKeysAndValuesForObject: dictValue]
				     forKey: dictKey];
		    }
		  
		  [keysAndValues setObject: dictValues
				    forKey: key];
		}
	      else if ([value isKindOfClass: [NSObject class]]
		       && ![value isKindOfClass: [NSString class]]
		       && ![value isKindOfClass: [NSNumber class]])
		{
		  [keysAndValues setObject: [self recursiveKeysAndValuesForObject: value]
				    forKey: key];
		}
	      else
		{
		  if (value)
		    {
		      [keysAndValues setObject: value
					forKey: key]; 
		    }
		  else
		    {
		      // [keysAndValues setObject: [NSNull null]
		      //      forKey: key];
		    }
		}
	    }
	  NS_HANDLER
	    {
	      NSLog(@"Exception while retrieving value for key '%@' on class %@", key,
		    NSStringFromClass([object class])); // , localException);
	      [missingKeys addObject: key];
	    }
	  NS_ENDHANDLER;
	}
    }

  NSLog(@"missingKeys are %@", missingKeys);
  return [keysAndValues copy];
}

- (NSDictionary *) allKeysAndValues
{
  return [self recursiveKeysAndValuesForObject: self];
}

@end
