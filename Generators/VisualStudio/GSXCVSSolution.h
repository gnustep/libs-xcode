// Released under the terms of the LGPLv2.1, See COPYING.LIB

#import <Foundation/NSObject.h>

@class NSString;
@class NSUUID;
@class GSXCVSProject;
@class GSXCVSGlobalSectionContainer;

@interface GSXCVSSolution : NSObject
{
  NSUUID *_uuid;
  GSXCVSProject *_project;
  GSXCVSGlobalSectionContainer *_container;
}

- (NSUUID *) uuid;
- (GSXCVSGlobalSectionContainer *) container;
- (NSString *) string;

@end
