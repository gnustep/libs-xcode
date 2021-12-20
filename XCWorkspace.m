#import "XCWorkspace.h"

#import <Foundation/NSString.h>
#import <Foundation/NSArray.h>

@implementation XCWorkspace

- (NSString *) version
{
  return _version;
}

- (void) setVersion: (NSString *)v
{
  ASSIGN(_version, v);
}

- (NSArray *) fileRefs
{
  return _fileRefs;
}

- (void) setFileRefs: (NSArray *)refs
{
  ASSIGN(_fileRefs, refs);
}

@end
