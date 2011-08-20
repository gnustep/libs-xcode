#import <Foundation/Foundation.h>

// Local includes
#import "PBXCoder.h"


@interface XCBuildConfiguration : NSObject
{
  NSMutableDictionary *buildSettings;
  NSString *name;
}

// Methods....
- (NSMutableDictionary *) buildSettings; // getter
- (void) setBuildSettings: (NSMutableDictionary *)object; // setter
- (NSString *) name; // getter
- (void) setName: (NSString *)object; // setter

@end