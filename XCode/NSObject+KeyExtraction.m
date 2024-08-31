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

// Function to generate a 24-character GUID (uppercase, alphanumeric, no dashes)
NSString *generateGUID()
{
  NSString *characters = @"ABCDEF0123456789";
  NSMutableString *guid = [NSMutableString stringWithCapacity:24];
  
  for (int i = 0; i < 24; i++)
    {
      NSUInteger index = arc4random_uniform((uint32_t)[characters length]);
      unichar c = [characters characterAtIndex:index];
      [guid appendFormat:@"%C", c];
    }
  
  return guid;
}


id moveContainerProperties(NSDictionary *input)
{
  NSMutableDictionary *result =
    [NSMutableDictionary dictionaryWithDictionary: input];
  NSDictionary *objects = [result objectForKey: @"objects"];
  NSEnumerator *en = [objects keyEnumerator];
  id key = nil;
  id keyToRemove = nil;
  
  while ((key = [en nextObject]) != nil)
    {
      id d = [objects objectForKey: key];
      
      if ([d isKindOfClass: [NSDictionary class]])
	{
	  NSString *cn = [d objectForKey: @"isa"];

	  if ([cn isEqualToString: @"PBXContainer"])
	    {
	      // [result addEntriesFromDictionary: d];
	      // [result removeObjectForKey: @"isa"];
	      // keyToRemove = key;
	      NSLog(@"obj = %@", d);
	    }
	}
    }

  if (keyToRemove != nil)
    {
      [result removeObjectForKey: keyToRemove];
    }
  
  return result;
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
	  for (id key in dict)
	    {
	      flattenedDict[key] = flattenPropertyList([dict objectForKey:key], objects, rootObjectGUID);
	    }
	  [objects setObject:flattenedDict forKey:guid];
	  
	  // Return the GUID to replace the dictionary
	  return guid;
	}
      else
	{
	  // Recursively process each value in the dictionary
	  NSMutableDictionary *processedDict = [NSMutableDictionary dictionary];
	  for (id key in dict)
	    {
	      processedDict[key] = flattenPropertyList([dict objectForKey:key], objects, rootObjectGUID);
	    }
	  return processedDict;
	}
    }
  else if ([propertyList isKindOfClass:[NSArray class]])
    {
      // Recursively process each item in the array
      NSMutableArray *processedArray = [NSMutableArray array];
      for (id item in propertyList)
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
  
  // Flatten the property list and find the rootObjectGUID
  flattenPropertyList(propertyList, objects, &rootObjectGUID);
  
  // Return the final structure
  return @{@"rootObject": rootObjectGUID, @"objects": objects};
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
  return [NSArray arrayWithObjects: @"context", @"buildConfigurationList", @"buildConfigurations",
		  @"array", @"valueforKey", @"objectatIndexedSubscript", @"totalFiles",
		  @"filename", @"currentFile", nil];
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
		  [keysAndValues setObject: NSStringFromClass([object class])
				    forKey: @"isa"];
		  [keysAndValues setObject: [self recursiveKeysAndValuesForObject: value]
				    forKey: key];
		}
	      else
		{
		  if (value)
		    {
		      [keysAndValues setObject: NSStringFromClass([object class])
					forKey: @"isa"];
		      [keysAndValues setObject: value
					forKey: key];
		    }
		  /*
		  else
		    {
		      [keysAndValues setObject: [NSNull null]
					forKey: key];
		    }
		  */
		}
	    }
	  NS_HANDLER
	    {
	      NSLog(@"Exception while retrieving value for key '%@' on class %@", key,
		    NSStringFromClass([object class])); // , localException);
	      // [missingKeys addObject: key];
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
  id result = moveContainerProperties(d);

  return result;
}

@end
