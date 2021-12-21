#import <Foundation/Foundation.h>
#import "PBXCoder.h"

@interface PBXContainer : NSObject
{
  NSString *archiveVersion;
  NSMutableDictionary *classes;
  NSString *objectVersion;
  NSMutableDictionary *objects;
  id rootObject;

  NSString *_filename;
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

- (void) setFilename: (NSString *)fn;
- (NSString *) filename;

// Build...			  
- (BOOL) build;
- (BOOL) clean;
- (BOOL) install;
- (BOOL) generate;

@end
