#import "NSArray+Additions.h"

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

@end
