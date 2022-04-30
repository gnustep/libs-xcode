// Released under the terms of the LGPLv2.1, See COPYING.LIB

#import <Foundation/NSObject.h>

@class NSString;
@class NSUUID;
@class NSDictionary;

@class GSXCVSProject;
@class GSXCVSGlobalSectionContainer;

@interface GSXCVSSolution : NSObject
{
  NSUUID *_uuid;
  NSDictionary *_dictionary;
  GSXCVSProject *_project;
  GSXCVSGlobalSectionContainer *_container;
}

- (NSUUID *) uuid;
- (NSDictionary *) dictionary;
- (void) setDictionary: (NSDictionary *)d;
- (GSXCVSGlobalSectionContainer *) container;
- (GSXCVSProject *) project;
- (NSString *) string;

@end
