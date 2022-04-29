// Released under the terms of the LGPL2.1, Please see COPYING.LIB

#import "GSXCCommon.h"
#import "GSXCVSGlobalSection.h"

@implementation GSXCVSGlobalSection

- (id) objectForKey: (NSString *)k
{
  return [_values objectForKey: k];
}
    
- (void) setObject: (id)o forKey: (NSString *)k
{
  [_values setObject: o
              forKey: k];
}

- (GSXCVSGlobalSectionType) type
{
  return _type;
}

- (void) setType: (GSXCVSGlobalSectionType)type
{
  _type = type;
}

- (BOOL) preSolution
{
  return _preSolution;
}

- (void) setPreSolution: (BOOL)f
{
  _preSolution = f;
}

- (NSString *) stringForType
{
  NSString *result = nil;
  
  switch (_type)
    {
    case SolutionConfigurationPlatforms:
      {
        result = @"SolutionConfigurationPlatforms";
        break;
      }
    case ProjectConfigurationPlatforms:
      {
        result = @"ProjectConfigurationPlatforms";
        break;
      }
    case ProjectSolutionProperties: 
      {
        result = @"ProjectSolutionProperties";
        break;
      }
    case ExtensibilityGlobals:
      {
        result = @"ExtensibilityGoals";
        break;
      }
    default:
      {
        result = nil;
        break;
      }
    }

  return result;
}

- (NSString *) string
{
  NSString *result = [NSString stringWithFormat: @"\tGlobalSection(%@) = %@\n", [self stringForType], _preSolution ? @"preSolution":@"postSolution"];
  NSEnumerator *en = [_values keyEnumerator];
  NSString *k = nil;

  while ((k = [en nextObject]) != nil)
    {
      id v = [_values objectForKey: k];
      result = [result stringByAppendingString: [NSString stringWithFormat: @"\t\t%@ = %@\n", k, v]];
    }

  result = [result stringByAppendingString: @"\tEndGlobalSection"];
  
  return result;
}

@end
