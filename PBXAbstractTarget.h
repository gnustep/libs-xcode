#import <Foundation/Foundation.h>

// Local includes
#import "PBXCoder.h"
#import "XCConfigurationList.h"
#import "PBXFileReference.h"


@interface PBXAbstractTarget : NSObject
{
  NSMutableArray *dependencies;
  XCConfigurationList *buildConfigurationList;
  NSString *productName;
  NSMutableArray *buildPhases;
  NSString *name;
}

// Methods....
- (NSMutableArray *) dependencies; // getter
- (void) setDependencies: (NSMutableArray *)object; // setter
- (XCConfigurationList *) buildConfigurationList; // getter
- (void) setBuildConfigurationList: (XCConfigurationList *)object; // setter
- (NSString *) productName; // getter
- (void) setProductName: (NSString *)object; // setter
- (NSMutableArray *) buildPhases; // getter
- (void) setBuildPhases: (NSMutableArray *)object; // setter
- (NSString *) name; // getter
- (void) setName: (NSString *)object; // setter

// build
- (BOOL) build;
@end
