// Released under the terms of LGPLv2.1, please see COPYING.LIB

#import <Foundation/NSString.h>
#import <Foundation/NSXMLDocument.h>
#import <Foundation/NSUUID.h>

#import "GSXCVSProject.h"
#import "GSXCCommon.h"

@implementation GSXCVSProject

+ (instancetype) project
{
  return AUTORELEASE([[self alloc] init]);
}

- (instancetype) init
{
  self = [super init];

  if (self != nil)
    {
      _uuid = [NSUUID UUID];
    }
  
  return self;
}

- (NSString *) name
{
  return _name;
}

- (NSString *) path
{
  return _path;
}

- (NSString *) uuidString
{
  return [_uuid uuidString];
}

- (NSUUID *) uuid
{
  return _uuid;
}

- (NSString *) string
{
  NSString *result = @"";

  return result;
}

@end
