// Released under the terms of LGPLv2.1, please see COPYING.LIB

#import <Foundation/NSString.h>
#import <Foundation/NSXMLDocument.h>
#import <Foundation/NSUUID.h>

#import "GSXCVSProject.h"
#import "GSXCVSSolution.h"
#import "GSXCCommon.h"

@implementation GSXCVSProject

+ (instancetype) project
{
  return AUTORELEASE([[self alloc] init]);
}

+ (instancetype) projectWithSolution: (GSXCVSSolution *)s
{
  return AUTORELEASE([[self alloc] initWithSolution: s]);
}

- (instancetype) init
{
  self = [super init];

  if (self != nil)
    {
      ASSIGN(_uuid, [NSUUID UUID]);
    }
  
  return self;
}

- (instancetype) initWithSolution: (GSXCVSSolution *)s
{
  self = [self init];
  if (self != nil)
    {
      ASSIGN(_solution, s);
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

- (NSUUID *) uuid
{
  return _uuid;
}

- (GSXCVSSolution *) solution
{
  return _solution;
}

- (NSString *) string
{
  NSString *result = @"";

  return result;
}

@end
