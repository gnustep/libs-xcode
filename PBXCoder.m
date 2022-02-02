/*
   Copyright (C) 2018, 2019, 2020, 2021 Free Software Foundation, Inc.

   Written by: Gregory John Casament <greg.casamento@gmail.com>
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

#import "PBXCoder.h"
#import "PBXContainer.h"
#import "PBXCommon.h"
#import "GSXCBuildContext.h"

#ifdef _WIN32
#import "setenv.h"
#endif

@implementation PBXCoder

- (id) initWithContentsOfFile: (NSString *)name
{
  if((self = [super init]) != nil)
    {
      objectCache = [[NSMutableDictionary alloc] initWithCapacity: 10];

      ASSIGN(fileName, name);
      ASSIGN(projectRoot,
             [[fileName stringByDeletingLastPathComponent]
               stringByDeletingLastPathComponent]);
      ASSIGN(dictionary,
             [NSMutableDictionary dictionaryWithContentsOfFile: fileName]);
      ASSIGN(objects, [dictionary objectForKey: @"objects"]);
      
      parents = [[NSMutableDictionary alloc] initWithCapacity: 10];
      [[GSXCBuildContext sharedBuildContext]
        setObject: objects forKey: @"objects"];

      setenv("PROJECT_DIR","./",1);      
      setenv("PROJECT_ROOT","./",1);      
      setenv("SRCROOT","./",1);      
    }
  return self;
}

- (id) initWithProjectFile: (NSString *)name
{
  NSString *newName = [name stringByAppendingPathComponent: @"project.pbxproj"];
  return [self initWithContentsOfFile: newName];
}

- (void) dealloc
{
  RELEASE(objectCache);
  RELEASE(fileName);
  RELEASE(dictionary);
  RELEASE(objects);
  RELEASE(parents);

  [super dealloc];
}

- (id) unarchive
{
  return [self unarchiveFromDictionary: dictionary];
}

- (id) unarchiveFromDictionary: (NSDictionary *)dict
{
  id object = nil;
  NSString *isaValue = [dict objectForKey: @"isa"];
  NSString *className = (isaValue == nil) ? @"PBXContainer" : isaValue;
  Class classInstance = NSClassFromString(className);
  
  if(classInstance == nil)
    {
      xcputs([[NSString stringWithFormat: @"Unknown class: %@",className] cString]);
      return nil;
    }

  object = AUTORELEASE([[classInstance alloc] init]);
  object = [self applyKeysAndValuesFromDictionary: dict
					 toObject: object];

  if([object isKindOfClass: [PBXContainer class]])
    {
      [object setObjects: objectCache];
      [object setFilename: fileName];
    }

  return object;
}

- (id) unarchiveObjectForKey: (NSString *)key
{
  id obj = [objectCache objectForKey: key];
  if(obj != nil)
    {
      return obj;
    }

  // cache the object, if it exists in objects... if not return nil
  NSDictionary *dict = [objects objectForKey: key];
  if(dict != nil)
    {
      obj = [self unarchiveFromDictionary: dict];
      [objectCache setObject: obj forKey: key];
    }

  return obj;
}

- (NSMutableArray *) resolveArrayMembers: (NSMutableArray *)array
{
  NSMutableArray *result = [[NSMutableArray alloc] initWithCapacity: 10];
  NSEnumerator *en = [array objectEnumerator];
  id key = nil;

  while((key = [en nextObject]) != nil)
    {
      id obj = [self unarchiveObjectForKey: key];
      if(obj != nil)
	{
	  [result addObject: obj];
	}
    }

  return result;
}

- (id) applyKeysAndValuesFromDictionary: (NSDictionary *)dict
			       toObject: (id)object
{
  NSEnumerator *en = [dict keyEnumerator];
  NSString *key = nil;

  while((key = [en nextObject]) != nil)
    {
      // continue if it's the isa pointer...
      if([key isEqualToString: @"isa"])
	{
	  continue;
	}

      id value = [dict objectForKey: key];
      if(value != nil)
	{
	  NS_DURING
	    {
	      // if it's an array, resolve the indexes of the array....
	      if([value isKindOfClass: [NSMutableArray class]])
		{
		  value = [self resolveArrayMembers: value];
		}
	      
	      // search the global dictionary...
	      if([key isEqualToString: @"containerPortal"] == NO &&
		 [key isEqualToString: @"remoteGlobalIDString"] == NO)
                // FIXME: Find a more generalized way to do lazy instantiation...
		{
		  id newValue = [self unarchiveObjectForKey: value];  
		  if(newValue != nil)
		    {
		      value = newValue;
		    }
		}
	      
	      if(value != nil)
		{
		  id currentValue = [object valueForKey: key];
		  if(currentValue == nil)
		    {
		      [object setValue: value
				forKey: key];
		    }
		}
	    }
	  NS_HANDLER
	    {
	      xcputs([[NSString stringWithFormat: @"%@, key = %@, value = %@, object = %@",
                              [localException reason], 
                              key, 
                              value, 
                              object] cString]);
	    }
	  NS_ENDHANDLER;
	}
    }

  return object;
}

- (NSString *) projectRoot
{
  return projectRoot;
}
@end
