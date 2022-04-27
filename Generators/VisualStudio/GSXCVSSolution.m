// Released under the terms of LGPLv2.1, please see COPYING.LIB

#import "GSXCVSSolution.h"
#import "GSXCVSProject.h"
#import "GSXCCommon.h"
#import "GSXCVSGlobalSection.h"

@implementation GSXCVSSolution

- (instancetype) init
{
  self = [super init];

  if (self != nil)
    {
      _uuid = [NSUUID UUID];
      _sections = [[NSMutableArray alloc] init];
    }
  
  return self;
}

- (NSUUID *) uuid
{
  return _uuid;
}

- (NSString *) uuidString
{
  return [_uuid uuidString];
}

- (NSMutableArray *) sections
{
  return _sections;
}

- (NSString *) string
{
  NSUUID *uuid = [NSUUID UUID];
  NSString *solutionUUID = [uuid uuidString];
  GSXCVSProject *project = [[GSXCVSProject alloc] init];
  NSString *header = nil;

  header =  [NSString stringWithFormat:
                        @"Microsoft Visual Studio Solution File, Format Version 12.00\n"
                      @"# Visual Studio Version 17\n"
                      @"VisualStudioVersion = 17.0.31919.166\n"
                      @"MinimumVisualStudioVersion = 10.0.40219.1\n" // Copied from example...
                      @"Project(\"{%@}\") = \"%@\", \"%@\%@.vcproj\", \"{%@}\"\n"
                      @"EndProject\n"
                      @"Global\n"
                      @"\tGlobalSection(SolutionConfigurationPlatform) = preSolution\n"
                      @"\t\tDebug|x64 = Debug|x64\n"
                      @"\t\tDebug|x86 = Debug|x86\n"
                      @"\t\tRelease|x64 = Release|x64\n"
                      @"\t\tRelease|x86 = Release|x86\n"
                      @"\tEndGlobalSection\n"
                      @"\tGlobalSection(ProjectConfigurationPlatforms) = postSolution\n"
                      @"\t\t{%@}.Debug|x64.ActiveCfg = Debug|x64\n"
                      @"\t\t{%@}.Debug|x64.Build.0 = Debug|x64\n"
                      @"\t\t{%@}.Debug|x86.ActiveCfg = Debug|Win32\n"
                      @"\t\t{%@}.Debug|x86.Build.0 = Debug|Win32\n"
                      @"\t\t{%@}.Release|x64.ActiveCfg = Debug|x64\n"
                      @"\t\t{%@}.Release|x64.Build.0 = Debug|x64\n"
                      @"\t\t{%@}.Release|x86.ActiveCfg = Debug|Win32\n"
                      @"\t\t{%@}.Release|x86.Build.0 = Debug|Win32\n"
                      @"\tEndGlobalSection\n"
                      @"\tGlobalSection(SolutionProperties) = preSolution\n"
                      @"\t\tHideSolutionNode = FALSE\n"
                      @"\tEndGlobalSection\n"
                      @"\tGlobalSection(ExtensibilityGlobals) = postSolution\n"
                      @"\t\tSolutionGuid = {%@}\n"
                      @"\tEndGlobalSection\n"
                      @"EndGlobal\n", solutionUUID, [project name], [project path], [project projectTypeUUID],
                      [project projectTypeUUID],
                      [project projectTypeUUID],
                      [project projectTypeUUID],
                      [project projectTypeUUID],
                      [project projectTypeUUID],
                      [project projectTypeUUID],
                      [project projectTypeUUID],
                      [project projectTypeUUID],  
                      [self uuidString]];

  NSLog(@"header = %@", header);

  return header;
}

@end
