#import <Foundation/NSObject.h>

@class NSString;
@class NSArray;

@interface XCWorkspace : NSObject
{
  NSString *_version;
  NSArray *_fileRefs;
  NSString *_filename;
}

+ (instancetype) workspace;

- (NSString *) version;
- (void) setVersion: (NSString *)v;

- (NSArray *) fileRefs;
- (void) setFileRefs: (NSArray *)refs;

- (NSString *) filename;
- (void) setFilename: (NSString *)filename;

- (BOOL) build;

- (BOOL) clean;

- (BOOL) install;

@end
