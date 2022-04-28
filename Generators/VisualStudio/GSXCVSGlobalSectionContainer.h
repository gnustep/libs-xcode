// Released under the terms of LGPLv2.1, please see COPYING.LIB

#import <Foundation/NSObject.h>

@class NSArray;
@class NSString;

@interface GSXCVSGlobalSectionContainer : NSObject
{
  NSArray *_sections;
}

- (instancetype) initWithSections: (NSArray *)sections;

- (NSArray *) sections;
- (NSString *) string;

@end

