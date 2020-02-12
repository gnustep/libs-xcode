#import <stdlib.h>
#import "PBXCommon.h"
#import "PBXAbstractTarget.h"

@implementation PBXAbstractTarget

- (void) dealloc
{
  [dependencies release];
  [buildConfigurationList release];
  [productName release];
  [buildPhases release];
  [name release];
  [super dealloc];
}

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
  puts([[NSString stringWithFormat: @"Building %@",self] cString]);
  return YES;
}

- (BOOL) clean
{
  puts([[NSString stringWithFormat: @"Cleaning %@",self] cString]);
  return YES;
}

- (BOOL) install
{
  puts([[NSString stringWithFormat: @"Installing %@",self] cString]);
  return YES;
}

@end
