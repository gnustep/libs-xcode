// Released under the terms of LGPLv2.1, please see COPYING.LIB

#import <Foundation/NSObject.h>

@class NSString;
@class NSUUID;

@interface GSXCVSProject : NSObject
{
  NSString *_name;
  NSString *_path;
  NSUUID   *_uuid;
}

+ (instancetype) project;

- (NSString *) string;
- (NSString *) name;
- (NSString *) path;
- (NSString *) uuidString;
- (NSUUID *) uuid;

@end
