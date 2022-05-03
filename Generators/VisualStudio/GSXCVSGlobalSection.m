// Released under the terms of the LGPL2.1, Please see COPYING.LIB

#import "GSXCCommon.h"
#import "GSXCVSGlobalSection.h"

@implementation GSXCVSGlobalSection

+ (instancetype) globalSection
{
  return AUTORELEASE([[GSXCVSGlobalSection alloc] init]);
}

- (instancetype) init
{
  self = [super init];
  if (self != nil)
    {
      _values = [[NSMutableDictionary alloc] init];
    }
  return self;
}

- (void) dealloc
{
  RELEASE(_values);

  [super dealloc];
}

- (id) objectForKey: (NSString *)k
{
  return [_values objectForKey: k];
}
    
- (void) setObject: (id)o forKey: (NSString *)k
{
  [_values setObject: o
              forKey: k];
}

- (NSMutableDictionary *) values
{
  return _values;
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
    case SolutionProperties: 
      {
        result = @"SolutionProperties";
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

  result = [result stringByAppendingString: @"\tEndGlobalSection\n"];
  
  return result;
}

- (id) copyWithZone: (NSZone *)z
{
  id copy = [[GSXCVSGlobalSection allocWithZone: z] init];

  [[copy values] addEntriesFromDictionary: _values];
  [copy setType: _type];
  [copy setPreSolution: _preSolution];

  return copy;
}

@end
