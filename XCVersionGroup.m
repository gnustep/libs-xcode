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

- (NSString *) buildPath
{
  return [self path];
}

- (NSMutableArray *) children // getter
{
  return children;
}

- (void) setChildren: (NSMutableArray *)object; // setter
{
  ASSIGN(children,object);
}

- (void) setTarget: (NSString *)target
{
}

- (BOOL) build
{
  NSEnumerator *en = [children objectEnumerator];
  id o = nil;
  BOOL result = YES;
  while((o = [en nextObject]) != nil && result)
    {
      puts([[NSString stringWithFormat: @"\tProcessing %@",[o path]] cString]);
    }
  return result;
}

@end
