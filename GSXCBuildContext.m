#import "GSXCBuildContext.h"

id _sharedBuildContext = nil;

@implementation GSXCBuildContext

+ (id) sharedBuildContext
{
  if(_sharedBuildContext == nil)
    {
      _sharedBuildContext = [[GSXCBuildContext alloc] init];
    }
  return _sharedBuildContext;
}

- (id) init
{
  if((self = [super init]) != nil)
    {
      stack = [[NSMutableArray alloc] initWithCapacity: 10];
      contextDictionary = [[NSMutableDictionary alloc] init];
    }
  return self;
}

- (void) dealloc
{
  [stack release];
  [contextDictionary release];
  [super dealloc];
}

- (NSMutableDictionary *) currentContext
{
  return currentContext;
}

- (NSMutableDictionary *) contextDictionaryForName: (NSString *)name
{
  currentContext = [contextDictionary objectForKey: name];
  if(currentContext == nil)
    {
      currentContext = [NSMutableDictionary dictionary];
      [contextDictionary setObject: currentContext forKey: name];
      [stack addObject: currentContext];
    }
  return currentContext;
}

- (NSMutableDictionary *) popCurrentContext
{
  NSMutableDictionary *popped = [stack lastObject];
  [stack removeLastObject];
  currentContext = [stack lastObject];
  return popped;
}

- (void) setObject: (id)object forKey: (id)key
{
  [currentContext setObject: object forKey: key];
}

- (id) objectForKey: (id)key
{
  return [currentContext objectForKey: key];
}
@end
