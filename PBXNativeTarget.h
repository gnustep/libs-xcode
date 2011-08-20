#import <Foundation/Foundation.h>

// Local includes
#import "PBXCoder.h"
#import "XCConfigurationList.h"
#import "PBXFileReference.h"


@interface PBXNativeTarget : NSObject
{
  NSMutableArray *dependencies;
  XCConfigurationList *buildConfigurationList;
  PBXFileReference *productReference;
  NSString *productInstallPath;
  NSString *productName;
  NSString *productType;
  NSMutableArray *buildRules;
  NSString *name;
  NSMutableArray *buildPhases;
}

// Methods....
- (NSMutableArray *) dependencies; // getter
- (void) setDependencies: (NSMutableArray *)object; // setter
- (XCConfigurationList *) buildConfigurationList; // getter
- (void) setBuildConfigurationList: (XCConfigurationList *)object; // setter
- (PBXFileReference *) productReference; // getter
- (void) setProductReference: (PBXFileReference *)object; // setter
- (NSString *) productInstallPath; // getter
- (void) setProductInstallPath: (NSString *)object; // setter
- (NSString *) productName; // getter
- (void) setProductName: (NSString *)object; // setter
- (NSString *) productType; // getter
- (void) setProductType: (NSString *)object; // setter
- (NSMutableArray *) buildRules; // getter
- (void) setBuildRules: (NSMutableArray *)object; // setter
- (NSString *) name; // getter
- (void) setName: (NSString *)object; // setter
- (NSMutableArray *) buildPhases; // getter
- (void) setBuildPhases: (NSMutableArray *)object; // setter

@end