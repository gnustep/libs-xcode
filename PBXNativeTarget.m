#import "PBXCommon.h"
#import "PBXNativeTarget.h"

@implementation PBXNativeTarget

// Methods....
- (NSMutableArray *) dependencies // getter
{
  return dependencies;
}

- (void) setDependencies: (NSMutableArray *)object; // setter
{
  ASSIGN(dependencies,object);
}

- (XCConfigurationList *) buildConfigurationList // getter
{
  return buildConfigurationList;
}

- (void) setBuildConfigurationList: (XCConfigurationList *)object; // setter
{
  ASSIGN(buildConfigurationList,object);
}

- (PBXFileReference *) productReference // getter
{
  return productReference;
}

- (void) setProductReference: (PBXFileReference *)object; // setter
{
  ASSIGN(productReference,object);
}

- (NSString *) productInstallPath // getter
{
  return productInstallPath;
}

- (void) setProductInstallPath: (NSString *)object; // setter
{
  ASSIGN(productInstallPath,object);
}

- (NSString *) productName // getter
{
  return productName;
}

- (void) setProductName: (NSString *)object; // setter
{
  ASSIGN(productName,object);
}

- (NSString *) productType // getter
{
  return productType;
}

- (void) setProductType: (NSString *)object; // setter
{
  ASSIGN(productType,object);
}

- (NSMutableArray *) buildRules // getter
{
  return buildRules;
}

- (void) setBuildRules: (NSMutableArray *)object; // setter
{
  ASSIGN(buildRules,object);
}

- (NSString *) name // getter
{
  return name;
}

- (void) setName: (NSString *)object; // setter
{
  ASSIGN(name,object);
}

- (NSMutableArray *) buildPhases // getter
{
  return buildPhases;
}

- (void) setBuildPhases: (NSMutableArray *)object; // setter
{
  ASSIGN(buildPhases,object);
}

- (BOOL) build
{
  NSEnumerator *en = [buildPhases objectEnumerator];
  id phase = nil;
  BOOL result = YES;
  while((phase = [en nextObject]) != nil && result)
    {
      result = [phase build];
    }
  return result;
}

@end
