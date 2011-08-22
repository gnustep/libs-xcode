#import "PBXCoder.h"
#import "PBXContainer.h"

@implementation PBXCoder

- (id) initWithContentsOfFile: (NSString *)name
{
  if((self = [super init]) != nil)
    {
      objectCache = [[NSMutableDictionary alloc] initWithCapacity: 10];
      ASSIGN(fileName, name);
      ASSIGN(dictionary, [NSMutableDictionary dictionaryWithContentsOfFile: fileName]);
      ASSIGN(objects, [dictionary objectForKey: @"objects"]);
    }
  return self;
}

- (void) dealloc
{
  RELEASE(objectCache);
  RELEASE(fileName);
  RELEASE(dictionary);
  RELEASE(objects);
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
  
  object = [[classInstance alloc] init];
  object = [self applyKeysAndValuesFromDictionary: dict
					 toObject: object];

  if([object isKindOfClass: [PBXContainer class]])
    {
      [object setObjects: objectCache];
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
      [result addObject: obj];
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
	      id newValue = [self unarchiveObjectForKey: value];  
	      if(newValue != nil)
		{
		  value = newValue;
		}
	      [object setValue: value
			forKey: key];
	    }
	  NS_HANDLER
	    {
	      NSLog(@"%@, key = %@, object = %@",[localException reason], key, object);
	    }
	  NS_ENDHANDLER;
	}
    }

  return object;
}

@end
