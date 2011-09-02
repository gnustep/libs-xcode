#import <stdlib.h>
#import "PBXCommon.h"
#import "PBXAbstractTarget.h"

@implementation PBXAbstractTarget

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

- (NSString *) productName // getter
{
  return productName;
}

- (void) setProductName: (NSString *)object; // setter
{
  ASSIGN(productName,object);
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
  NSLog(@"%@",self);
  return YES;
}

@end
