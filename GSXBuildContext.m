#import "GSXCBuildContext.h"

id _sharedBuildContext = nil;

@implementation GSXCBuildContext

+ (id) sharedBuildContext
{
  if(_sharedBuildContext == nil)
    {
      _sharedBuildContext = [[GSXBuildContext alloc] init];
    }
  return _sharedBuildContext;
}

- (NSMutableDictionary *) contextDictionaryForProject: (NSString *)projectName
{
  return [contextDictionary objectForKey: projectName];
}

- (void) createContextForProject: (NSString *)name
{
  NSMutableDictionary *dict = [NSMutableDictionary dictionary];
  [contextDictionary setObject: dict forKey: name];
}
@end
