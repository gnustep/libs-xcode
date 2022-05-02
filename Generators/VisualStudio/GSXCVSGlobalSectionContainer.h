// Released under the terms of LGPLv2.1, please see COPYING.LIB

#import <Foundation/NSObject.h>

@class NSArray;
@class NSString;
@class GSXCVSSolution;
@class GSXCVSGlobalSection;

@interface GSXCVSGlobalSectionContainer : NSObject
{
  NSMutableArray *_sections;
}

+ (instancetype) containerWithSolution: (GSXCVSSolution *)solution;

- (instancetype) initWithSolution: (GSXCVSSolution *)solution;
- (instancetype) initWithSections: (NSArray *)sections;

- (void) setSections: (NSArray *)sections;
- (NSArray *) sections;
- (void) addSection: (GSXCVSGlobalSection *)section;
- (void) addSections: (NSArray *)sections;
- (NSString *) string;

@end
