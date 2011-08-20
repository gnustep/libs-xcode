#import <Foundation/Foundation.h>

// Local includes
#import "PBXCoder.h"


@interface XCConfigurationList : NSObject
{
  NSString *defaultConfigurationIsVisible;
  NSMutableArray *buildConfigurations;
  NSString *defaultConfigurationName;
}

// Methods....
- (id) initWithPBXCoder: (PBXCoder *)coder;

@end