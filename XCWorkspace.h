#import <Foundation/NSObject.h>

@class NSString;
@class NSArray;

@interface XCWorkspace : NSObject
{
  NSString *_version;
  NSArray *_fileRefs;
}

- (NSString *) version;
- (void) setVersion: (NSString *)v;

- (NSArray *) fileRefs;
- (void) setFileRefs: (NSArray *)refs;

@end
