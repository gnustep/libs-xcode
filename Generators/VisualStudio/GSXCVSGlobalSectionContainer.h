// Released under the terms of LGPLv2.1, please see COPYING.LIB

#import <Foundation/NSObject.h>

@class NSArray;
@class NSString;
@class GSXCVSSolution;

@interface GSXCVSGlobalSectionContainer : NSObject
{
  NSArray *_sections;
}

+ (instancetype) containerWithSolution: (GSXCVSSolution *)solution;

- (instancetype) initWithSolution: (GSXCVSSolution *)solution;
- (instancetype) initWithSections: (NSArray *)sections;

- (void) setSections: (NSArray *)sections;
- (NSArray *) sections;
- (NSString *) string;

@end
