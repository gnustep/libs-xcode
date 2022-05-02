// Released under the terms of LGPLv2.1, please see COPYING.LIB

#import "GSXCCommon.h"
#import "GSXCVSGlobalSection.h"
#import "GSXCVSGlobalSectionContainer.h"

@implementation GSXCVSGlobalSectionContainer

+ (instancetype) containerWithSolution: (GSXCVSSolution *)solution
{
  return AUTORELEASE([[self alloc] initWithSolution: solution]);
}

- (instancetype) initWithSolution: (GSXCVSSolution *)solution
{
  self = [super init];
  if (self != nil)
    {
      _sections = [[NSMutableArray alloc] init];
    }
  return self;
}

- (instancetype) initWithSections: (NSArray *)sections
{
  self = [super init];
  if (self != nil)
    {
      _sections = [[NSMutableArray alloc] init];
      [self setSections: sections];
    }
  return self;
}

- (void) dealloc
{
  RELEASE(_sections);
  [super dealloc];
}

- (void) setSections: (NSArray *)sections
{
  [_sections removeAllObjects];
  [_sections addObjectsFromArray: sections];
}

- (NSArray *) sections
{
  return _sections;
}

- (void) addSection: (GSXCVSGlobalSection *)section
{
  [_sections addObject: section];
}

- (void) addSections: (NSArray *)sections
{
  [_sections addObjectsFromArray: sections];
}

- (NSString *) string
{
  NSString *result = @"Global\n";
  NSEnumerator *en = [_sections objectEnumerator];
  GSXCVSGlobalSection *s = nil;
  
  while((s = [en nextObject]) != nil)
    {
      result = [NSString stringWithFormat: @"\t%@", [s string]];
    }

  result = [result stringByAppendingString: @"EndGlobal\n"];
  
  return result;
}

@end
