#import <Foundation/NSObject.h>

@class NSString;

@interface XCFileRef : NSObject
{
  NSString *_location;
}

+ (instancetype) fileRef;

- (NSString *) location;
- (void) setLocation: (NSString *)loc;

- (BOOL) build;

@end
