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
      ASSIGN(_project, [GSXCVSProject projectWithSolution: self]);
      ASSIGN(_container, [GSXCVSGlobalSectionContainer containerWithSolution: self]);
    }
  
  return self;
}

- (void) dealloc
{
  RELEASE(_uuid);
  RELEASE(_container);
  RELEASE(_project);
  RELEASE(_dictionary);
  
  [super dealloc];
}

- (NSDictionary *) dictionary
{
  return _dictionary;
}

- (void) setDictionary: (NSDictionary *)d
{
  ASSIGN(_dictionary, d);
}

- (NSUUID *) uuid
{
  return _uuid;
}

- (GSXCVSProject *) project
{
  return _project;
}

- (GSXCVSGlobalSectionContainer *) container
{
  return _container;
}

- (NSString *) string
{
  NSString *result = nil;

  result = [NSString stringWithFormat:
                       @"Microsoft Visual Studio Solution File, Format Version 12.00\n"
                     @"# Visual Studio Version 17\n"
                     @"VisualStudioVersion = 17.0.31919.166\n"
                     @"MinimumVisualStudioVersion = 10.0.40219.1\n" // Copied from example...
                     @"Project(\"{%@}\") = \"%@\", \"%@\", \"{%@}\"\nEndProject\n"
                     @"%@", [_project root], [_project name], [_project path], [_project uuid],
                     [_container string]]; // global container and sections...
  
  NSLog(@"result = %@", result);
  
  return result;
}

- (NSString *) description
{
  return [self string];
}

@end
