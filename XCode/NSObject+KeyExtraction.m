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

#import <Foundation/NSObject.h>
#import <Foundation/NSArray.h>
#import <Foundation/NSDictionary.h>

#import "NSObject+KeyExtraction.h"
#import "NSString+PBXAdditions.h"

//
// Check dictionary to see if it's equvalent...
//
@interface NSDictionary (Private)
- (BOOL) isEqualDictionary: (NSDictionary *)dict;
@end

@implementation NSDictionary (Private)
- (BOOL) isEqualDictionary: (NSDictionary *)dict
{
  NSEnumerator *en = [self keyEnumerator];
  id k = nil;
  BOOL result = YES;

  while ((k = [en nextObject]) != nil)
    {
      id v1 = [self objectForKey: k];
      id v2 = [dict objectForKey: k];

      if ([v1 isKindOfClass: [NSDictionary class]]
	  && [v2 isKindOfClass: [NSDictionary class]])
	{
	  if ([v1 isEqualToDictionary: v2] == NO)
	    {
	      result = NO;
	      break;
	    }
	}
      else if ([v1 isEqual: v2] == NO)
	{
	  result = NO;
	  break;
	}
    }

  return result;
}
@end

// Function to generate a 24-character GUID (uppercase, alphanumeric, no dashes)
NSString *generateGUID()
{
  return [[NSUUID UUID] UUIDString];
}

// Move PBXContainer information to the top level dictionary...
id moveContainerProperties(NSDictionary *input)
{
  NSMutableDictionary *result =
    [NSMutableDictionary dictionaryWithDictionary: input];
  NSMutableDictionary *objects =
    [NSMutableDictionary dictionaryWithDictionary:
			     [result objectForKey: @"objects"]];
  NSEnumerator *en = [objects keyEnumerator];
  id key = nil;
  id keyToChange = nil;

  // NSLog(@"result = %@", result);
  while ((key = [en nextObject]) != nil)
    {
      id d = [objects objectForKey: key];
      
      if ([d isKindOfClass: [NSDictionary class]])
	{
	  NSString *cn = [d objectForKey: @"isa"];

	  if ([cn isEqualToString: @"PBXContainer"])
	    {
	      keyToChange = key;
	      break;
	    }
	}
    }

  // Update objects...
  if (keyToChange != nil)
    {
      NSMutableDictionary *containerDict = [objects objectForKey: keyToChange];

      [containerDict removeObjectForKey: @"rootObject"];
      [containerDict removeObjectForKey: @"isa"];
      [containerDict removeObjectForKey: @"objects"];
      
      [objects removeObjectForKey: keyToChange];
      [result addEntriesFromDictionary: containerDict];
      [result setObject: objects forKey: @"objects"];
    }

  // NSLog(@"result = %@", result); 
  
  return result;
}

NSString *guidInCachedObjects(NSDictionary *objects, NSDictionary *dict)
{
  NSString *guid = nil;
  NSEnumerator *en = [objects keyEnumerator];
  NSString *g = nil;
  
  while ((g = [en nextObject]) != nil)
    {
      NSDictionary *d = [objects objectForKey: g];

      if ([dict isEqualToDictionary: d])
	{
	  guid = g;
	  break;
	}
    }

  return guid;
}

// Recursive function to flatten the property list
id flattenPropertyList(id propertyList, NSMutableDictionary *objects, NSString **rootObjectGUID)
{
  if ([propertyList isKindOfClass:[NSDictionary class]])
    {
      NSDictionary *dict = (NSDictionary *)propertyList;
      
      // Check if the dictionary has an "isa" element
      if ([dict objectForKey:@"isa"])
	{
	  // Generate a GUID for this dictionary
	  NSString *guid = generateGUID();
	  
	  // If the "isa" is "PBXProject", set the rootObjectGUID
	  if ([[dict objectForKey:@"isa"] isEqualToString:@"PBXProject"])
	    {
	      *rootObjectGUID = guid;
	    }
	  
	  // Add the dictionary to the objects array with its GUID
	  NSMutableDictionary *flattenedDict = [NSMutableDictionary dictionary];
	  NSEnumerator *en = [dict keyEnumerator];
	  id key = nil;
	  
	  while ((key = [en nextObject]) != nil)
	    {
	      [flattenedDict setObject: flattenPropertyList([dict objectForKey:key], objects, rootObjectGUID)
				forKey: key];
	    }

	  NSString *existingGuid = guidInCachedObjects(objects, flattenedDict);
	  if (existingGuid != nil)
	    {
	      guid = existingGuid;
	    }
	  else
	    {
	      [objects setObject:flattenedDict forKey:guid];
	    }
	  
	  // Return the GUID to replace the dictionary
	  return guid;
	}
      else
	{
	  // Recursively process each value in the dictionary
	  NSMutableDictionary *processedDict = [NSMutableDictionary dictionary];
	  NSEnumerator *en = [dict keyEnumerator];
	  id key = nil;

	  while ((key = [en nextObject]) != nil)
	    {
	      [processedDict setObject: flattenPropertyList([dict objectForKey:key], objects, rootObjectGUID)
				forKey: key];
	    }
	  return processedDict;
	}
    }
  else if ([propertyList isKindOfClass:[NSArray class]])
    {
      // Recursively process each item in the array
      NSMutableArray *processedArray = [NSMutableArray array];
      NSEnumerator *en = [propertyList objectEnumerator];
      id item = nil;
      
      while((item = [en nextObject]) != nil)
	{
	  [processedArray addObject:flattenPropertyList(item, objects, rootObjectGUID)];
	}
      return processedArray;
    }
  else
    {
      // For non-collection types, return the item as-is
      return propertyList;
    }
}

// Main function to initiate the flattening process
NSDictionary *flattenPlist(id propertyList)
{
  NSMutableDictionary *objects = [NSMutableDictionary dictionary];
  NSString *rootObjectGUID = nil;
  NSMutableDictionary *results = [NSMutableDictionary dictionary];
  
  // Flatten the property list and find the rootObjectGUID
  flattenPropertyList(propertyList, objects, &rootObjectGUID);

  // Put the results together...
  [results setObject: rootObjectGUID
	      forKey: @"rootObject"];
  [results setObject: objects
	      forKey: @"objects"];
  
  // Return the final structure
  return results;
}

@implementation NSObject (KeyExtraction)

+ (void) getAllMethodsForClass: (Class)cls
		     intoArray: (NSMutableArray *)methodsArray
{
  if (cls == nil || cls == [NSObject class])
    {
      return;
    }
  
  unsigned int methodCount = 0;
  Method *methods = class_copyMethodList(cls, &methodCount);
  unsigned int i = 0;
  
  for (i = 0; i < methodCount; i++)
    {
      Method method = methods[i];
      [methodsArray addObject:NSStringFromSelector(method_getName(method))];
    }
  
  free(methods);  // Don't forget to free the list
  
  // Recursively call this method for the superclass
  [self getAllMethodsForClass:class_getSuperclass(cls) intoArray:methodsArray];
}

+ (NSArray *) recursiveGetAllMethodsForClass: (Class)cls
{
  NSMutableArray *methodsArray = [NSMutableArray array];
  [self getAllMethodsForClass: cls
		    intoArray: methodsArray];
  return [methodsArray copy];
}

+ (NSArray *) skippedKeys
{
  return [NSArray arrayWithObjects: @"context", // @"buildConfigurationList", @"buildConfigurations",
		  @"array", @"valueforKey", @"objectatIndexedSubscript", @"totalFiles",
		  @"filename", @"currentFile", @"parameter", @"showEnvVarsInLog", nil];
}

- (NSArray *) keysForObject: (id)object
{
  NSArray *methods = [NSObject recursiveGetAllMethodsForClass: [object class]];
  NSEnumerator *en = [methods objectEnumerator];
  NSString *selectorName = nil;
  NSMutableArray *result = [NSMutableArray arrayWithCapacity: [methods count]];
  
  while ((selectorName = [en nextObject]) != nil)
    {
      if ([selectorName hasPrefix: @"set"] && [selectorName isEqualToString: @"settings"] == NO)
	{
	  NSString *keyName = [selectorName substringFromIndex: 3];

	  keyName = [keyName stringByReplacingOccurrencesOfString: @":" withString: @""];
	  keyName = [keyName lowercaseFirstCharacter];
	  [result addObject: keyName];
	}
    }

  return result;
}

- (NSDictionary *) recursiveKeysAndValuesForObject: (id)object
{
  NSMutableDictionary *keysAndValues = nil;

  if (object && [object isKindOfClass: [NSNull class]] == NO)
    {
      NSArray *properties = [self keysForObject: object];
      NSEnumerator *pen = [properties objectEnumerator];
      id key = nil;

      keysAndValues = [NSMutableDictionary dictionary];
      while ((key = [pen nextObject]) != nil)
	{
	  if ([[NSObject skippedKeys] containsObject: key])
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
	      else if ([value isKindOfClass: [NSDictionary class]] // add a dictionary representing a class...
		       && [value objectForKey: @"isa"] != nil)
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
	      else if ([value isKindOfClass: [NSDictionary class]] // add a simple dictionary...
		       && [value objectForKey: @"isa"] == nil)
		{
		  [keysAndValues setObject: value
				    forKey: key];
		}
	      else if ([value isKindOfClass: [NSObject class]]
		       && ![value isKindOfClass: [NSString class]]
		       && ![value isKindOfClass: [NSNumber class]])
		{
		  [keysAndValues setObject: NSStringFromClass([object class])
				    forKey: @"isa"];
		  [keysAndValues setObject: [self recursiveKeysAndValuesForObject: value]
				    forKey: key];
		}
	      else
		{
		  [keysAndValues setObject: NSStringFromClass([object class])
				    forKey: @"isa"];
		  if (value)
		    {
		      [keysAndValues setObject: value
					forKey: key];
		    }
		}
	    }
	  NS_HANDLER
	    {
	      NSLog(@"Exception %@ while retrieving value for key '%@' on class %@", localException, key,
		    NSStringFromClass([object class]));
	    }
	  NS_ENDHANDLER;
	}
    }

  // NSLog(@"missingKeys are %@", missingKeys);
  return keysAndValues;
}

- (NSDictionary *) allKeysAndValues
{
  id r = flattenPlist([self recursiveKeysAndValuesForObject: self]);
  NSMutableDictionary *d = [NSMutableDictionary dictionaryWithDictionary: r];
  return moveContainerProperties(d);
}

@end
