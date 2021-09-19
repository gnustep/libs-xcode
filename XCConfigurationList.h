#import <Foundation/Foundation.h>
#import "PBXCoder.h"

@class XCBuildConfiguration;

@interface XCConfigurationList : NSObject
{
  NSString *defaultConfigurationIsVisible;
  NSMutableArray *buildConfigurations;
  NSString *defaultConfigurationName;
}

// Methods....
- (NSString *) defaultConfigurationIsVisible; // getter
- (void) setDefaultConfigurationIsVisible: (NSString *)object; // setter
- (NSMutableArray *) buildConfigurations; // getter
- (void) setBuildConfigurations: (NSMutableArray *)object; // setter
- (NSString *) defaultConfigurationName; // getter
- (void) setDefaultConfigurationName: (NSString *)object; // setter
- (XCBuildConfiguration *) defaultConfiguration;

- (void) applyDefaultConfiguration;
@end
