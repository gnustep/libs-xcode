// Released under the terms of LGPLv2.1, please see COPYING.LIB

#import "GSXCVSSolution.h"
#import "GSXCVSProject.h"
#import "GSXCCommon.h"
#import "GSXCVSGlobalSection.h"
#import "GSXCVSGlobalSectionContainer.h"

@implementation GSXCVSSolution

- (instancetype) init
{
  self = [super init];

  if (self != nil)
    {
      ASSIGN(_uuid, [NSUUID UUID]);
      ASSIGN(_project, [GSXCVSProject project]);
      [self setSections: [NSMutableArray array]];
    }
  
  return self;
}

- (void) dealloc
{
  RELEASE(_uuid);
  RELEASE(_sections);
  [super dealloc];
}

- (NSUUID *) uuid
{
  return _uuid;
}

- (void) setSections: (NSMutableArray *) sections
{
  ASSIGN(_sections, sections);
}

- (NSMutableArray *) sections
{
  return _sections;
}

- (NSString *) string
{
  GSXCVSProject *project = [[GSXCVSProject alloc] init];
  NSString *result = nil;

  result = [NSString stringWithFormat:
                       @"Microsoft Visual Studio Solution File, Format Version 12.00\n"
                     @"# Visual Studio Version 17\n"
                     @"VisualStudioVersion = 17.0.31919.166\n"
                     @"MinimumVisualStudioVersion = 10.0.40219.1\n" // Copied from example...
                     @"%@" // project
                     // @"Project(\"{%@}\") = \"%@\", \"%@\%@.vcproj\", \"{%@}\"\n"
                     // @"EndProject\n"
                     @"%@"]; // global container and sections...
  
  NSLog(@"result = %@", result);
  
  return result;
}

@end
