#import "XCFileRef.h"

#import <Foundation/NSString.h>

@implementation XCFileRef

- (NSString *) location
{
  return _location;
}

- (void) setLocation: (NSString *)loc
{
  ASSIGN(_location, loc);
}

@end
