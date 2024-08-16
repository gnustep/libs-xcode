#import "NSObject+KeyExtraction.h"

@implementation NSObject (KeyExtraction)

- (NSDictionary *) recursiveKeysAndValuesForObject: (id)object
{
  if (!object || [object isKindOfClass:[NSNull class]])
    {
      return [NSMutableDictionary dictionary];
    }
  
  NSMutableDictionary *keysAndValues = [NSMutableDictionary dictionary];
  unsigned int outCount, i;
  objc_property_t *properties = class_copyPropertyList([object class], &outCount);
  
  for (i = 0; i < outCount; i++)
    {
      objc_property_t property = properties[i];
      const char *propertyName = property_getName(property);
      NSString *key = [NSString stringWithUTF8String:propertyName];
      
      NS_DURING
	{
	  id value = [object valueForKey:key];

	  if ([value isKindOfClass:[NSArray class]])
	    {
	      NSMutableArray *arrayValues = [NSMutableArray array];
	      NSEnumerator *en = [value objectEnumerator];
	      id item = nil;

	      while ((item = [en nextObject]) != nil)
		{
		  [arrayValues addObject: [self recursiveKeysAndValuesForObject: item]];
		}
	      
	      [keysAndValues setObject: arrayValues forKey: key];
	    }
	  else if ([value isKindOfClass:[NSDictionary class]])
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
	      
	      [keysAndValues setObject: dictValues forKey: key];
	    }
	  else if ([value isKindOfClass: [NSObject class]]
		   && ![value isKindOfClass: [NSString class]]
		   && ![value isKindOfClass:[NSNumber class]])
	    {
	      [keysAndValues setObject: [self recursiveKeysAndValuesForObject: value]
	                        forKey: key];
	    }
	  else
	    {
	      if (value)
		{
		  [keysAndValues setObject: value forKey: key]; 
		}
	      else
		{
		  [keysAndValues setObject: [NSNull null] forKey: key];
		}
	    }
        }
      NS_HANDLER
	{
	  NSLog(@"Exception while retrieving value for key '%@': %@", key, localException);
	}
      NS_ENDHANDLER;
    }
  
  free(properties);
  
  return [keysAndValues copy];
}

- (NSDictionary *) allKeysAndValues
{
  return [self recursiveKeysAndValuesForObject: self];
}

@end
