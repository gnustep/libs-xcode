#import <Foundation/Foundation.h>

// Local includes
#import "PBXCoder.h"
#import "PBXFileReference.h"

@interface XCBuildConfiguration : NSObject
{
  NSMutableDictionary *buildSettings;
  NSString *name;
  PBXFileReference *baseConfigurationReference;
}

// Methods....
- (NSMutableDictionary *) buildSettings; // getter
- (void) setBuildSettings: (NSMutableDictionary *)object; // setter
- (NSString *) name; // getter
- (void) setName: (NSString *)object; // setter

- (void) apply;
@end
