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
    }
  return self;
}

- (instancetype) initWithSections: (NSArray *)sections
{
  self = [super init];
  if (self != nil)
    {
      ASSIGN(_sections, sections);
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
  ASSIGN(_sections, sections);
}

- (NSArray *) sections
{
  return _sections;
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
