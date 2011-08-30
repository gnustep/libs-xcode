#import "PBXCommon.h"
#import "PBXTargetDependency.h"

@implementation PBXTargetDependency

// Methods....
- (PBXContainerItemProxy *) targetProxy // getter
{
  return targetProxy;
}

- (void) setTargetProxy: (PBXContainerItemProxy *)object; // setter
{
  ASSIGN(targetProxy,object);
}

- (NSString *) name // getter
{
  return name;
}

- (void) setName: (NSString *)object; // setter
{
  ASSIGN(name,object);
}

- (BOOL) build
{
  return [targetProxy build];
}
@end
