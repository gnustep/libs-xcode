#import "PBXCommon.h"
#import "XCVersionGroup.h"

@implementation XCVersionGroup

// Methods....
- (NSString *) sourceTree // getter
{
  return sourceTree;
}

- (void) setSourceTree: (NSString *)object; // setter
{
  ASSIGN(sourceTree,object);
}

- (PBXFileReference *) currentVersion // getter
{
  return currentVersion;
}

- (void) setCurrentVersion: (PBXFileReference *)object; // setter
{
  ASSIGN(currentVersion,object);
}

- (NSString *) versionGroupType // getter
{
  return versionGroupType;
}

- (void) setVersionGroupType: (NSString *)object; // setter
{
  ASSIGN(versionGroupType,object);
}

- (NSString *) path // getter
{
  return path;
}

- (void) setPath: (NSString *)object; // setter
{
  ASSIGN(path,object);
}

- (NSMutableArray *) children // getter
{
  return children;
}

- (void) setChildren: (NSMutableArray *)object; // setter
{
  ASSIGN(children,object);
}

- (BOOL) build
{
  NSEnumerator *en = [children objectEnumerator];
  id o = nil;
  BOOL result = YES;
  while((o = [en nextObject]) != nil && result)
    {
      NSLog(@"\tProcessing %@",[o path]);
    }
  return result;
}

@end
