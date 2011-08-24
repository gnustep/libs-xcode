#import <Foundation/Foundation.h>
#import "PBXCoder.h"

@interface PBXContainer : NSObject
{
  NSString *archiveVersion;
  NSMutableDictionary *classes;
  NSString *objectVersion;
  NSMutableDictionary *objects;
  id rootObject;
}

- (void) setArchiveVersion: (NSString *)version;
- (NSString *) archiveVersion;
- (void) setClasses: (NSMutableDictionary *)dict;
- (NSMutableDictionary *) classes;
- (void) setObjectVersion: (NSString *)version;
- (NSString *) objectVersion;
- (void) setObjects: (NSMutableDictionary *)dict;
- (NSMutableDictionary *) objects;
- (void) setRootObject: (id)object;
- (id) rootObject;

// Build...			  
- (BOOL) build;
@end
