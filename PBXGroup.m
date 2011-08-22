#import "PBXCommon.h"
#import "PBXGroup.h"

@implementation PBXGroup

// Methods....
- (NSString *) sourceTree // getter
{
  return sourceTree;
}

- (void) setSourceTree: (NSString *)object; // setter
{
  ASSIGN(sourceTree,object);
}

- (NSMutableArray *) children // getter
{
  return children;
}

- (void) setChildren: (NSMutableArray *)object; // setter
{
  ASSIGN(children,object);
}

- (NSString *) name // getter
{
  return name;
}

- (void) setName: (NSString *)object; // setter
{
  ASSIGN(name,object);
}


@end