#import <Foundation/NSObject.h>

@class NSString;

@interface XCFileRef : NSObject
{
  NSString *_location;
}

- (NSString *) location;
- (void) setLocation: (NSString *)loc;

@end
