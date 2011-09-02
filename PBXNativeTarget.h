#import <Foundation/Foundation.h>

// Local includes
#import "PBXCoder.h"
#import "XCConfigurationList.h"
#import "PBXFileReference.h"
#import "PBXAbstractTarget.h"

@interface PBXNativeTarget : PBXAbstractTarget
{
  PBXFileReference *productReference;
  NSString *productInstallPath;
  NSString *productType;
  NSMutableArray *buildRules;
  NSString *comments;
}

// Methods....
- (PBXFileReference *) productReference; // getter
- (void) setProductReference: (PBXFileReference *)object; // setter
- (NSString *) productInstallPath; // getter
- (void) setProductInstallPath: (NSString *)object; // setter
- (NSString *) productType; // getter
- (void) setProductType: (NSString *)object; // setter
- (NSMutableArray *) buildRules; // getter
- (void) setBuildRules: (NSMutableArray *)object; // setter

// build
- (BOOL) build;
@end
