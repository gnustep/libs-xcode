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
      ASSIGN(_container, [GSXCVSGlobalSectionContainer containerWithSolution: self]);
      _project = nil;
    }
  
  return self;
}

- (void) build
{        
  GSXCVSGlobalSection *section = nil;
  NSString *config = nil;
  
  // Solution
  section = [GSXCVSGlobalSection globalSection];
  [section setPreSolution: YES];
  [section setType: SolutionConfigurationPlatforms];
  [section setObject: @"Release|x64"
              forKey: @"Release|x64"];
  [_container addSection: section];
  
  // Project
  section = [GSXCVSGlobalSection globalSection];
  config = [NSString stringWithFormat: @"{%@}.Release|x64.ActiveCfg",
                     [[_project uuid] UUIDString]];      
  [section setType: ProjectConfigurationPlatforms];
  [section setObject: @"Release|x64"
              forKey: config];
  config = [NSString stringWithFormat: @"{%@}.Release|x64.Build.0",
                     [[_project uuid] UUIDString]];
  [section setObject: @"Release|x64"
              forKey: config];
  [_container addSection: section];

  // Properties
  section = [GSXCVSGlobalSection globalSection];
  [section setPreSolution: YES];
  [section setType: SolutionProperties];
  [section setObject: @"FALSE"
              forKey: @"HideSolutionNode"];
  [_container addSection: section];
  
  // Properties
  section = [GSXCVSGlobalSection globalSection];
  [section setType: ExtensibilityGlobals];
  [section setObject: [_uuid UUIDString]
              forKey: @"SolutionGuid"];
  [_container addSection: section];
}

- (instancetype) initWithDictionary: (NSDictionary *)d
                          andTarget: (PBXAbstractTarget *)t
{
  self = [self init];

  if(self != nil)
    {     
      ASSIGN(_dictionary, d);
      ASSIGN(_target, t);
      ASSIGN(_project, [GSXCVSProject projectWithSolution: self]);
      [self build];
    }
  
  return self;
}

- (void) dealloc
{
  RELEASE(_uuid);
  RELEASE(_container);
  RELEASE(_project);
  RELEASE(_dictionary);
  RELEASE(_target);
  
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

- (PBXAbstractTarget *) target
{
  return _target;
}

- (NSString *) string
{
  NSString *result = nil;

  result = [NSString stringWithFormat:
                       @"\nMicrosoft Visual Studio Solution File, Format Version 12.00\n"
                     @"# Visual Studio Version 17\n"
                     @"VisualStudioVersion = 17.0.31919.166\n"
                     @"MinimumVisualStudioVersion = 10.0.40219.1\n" // Copied from example...
                     @"Project(\"{%@}\") = \"%@\", \"%@\", \"{%@}\"\nEndProject\n"
                     @"%@", [[_project root] UUIDString], [_project name], [_project path], [[_project uuid] UUIDString],
                     [_container string]]; // global container and sections...
  
  return result;
}

- (NSString *) description
{
  return [self string];
}

@end
