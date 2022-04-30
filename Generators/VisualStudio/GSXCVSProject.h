// Released under the terms of LGPLv2.1, please see COPYING.LIB

#import <Foundation/NSObject.h>

@class NSString;
@class NSUUID;
@class GSXCVSSolution;

@interface GSXCVSProject : NSObject
{
  NSString *_name;
  NSString *_path;
  NSUUID   *_uuid;
  NSUUID   *_root;
  GSXCVSSolution *_solution;
}

+ (instancetype) project;
+ (instancetype) projectWithSolution: (GSXCVSSolution *)s;

- (NSString *) string;
- (NSString *) name;
- (NSString *) path;
- (NSUUID *) uuid;
- (NSUUID *) root;

- (GSXCVSSolution *) solution;

@end
