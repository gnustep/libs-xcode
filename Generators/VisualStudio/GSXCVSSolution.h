// Released under the terms of the LGPLv2.1, See COPYING.LIB

#import <Foundation/NSObject.h>

@class NSString;
@class NSMutableArray;
@class NSUUID;
@class GSXCVSProject;

@interface GSXCVSSolution : NSObject
{
  NSMutableArray *_sections;
  NSUUID *_uuid;
  GSXCVSProject *_project;
}

- (NSUUID *) uuid;
- (NSString *) uuidString;
- (NSMutableArray *) sections;
- (NSString *) string;

@end
