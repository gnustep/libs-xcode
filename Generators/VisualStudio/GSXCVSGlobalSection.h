// Released under the terms of LGPL2.1, please see COPYING.LIB

#import <Foundation/NSObject.h>

@class NSMutableDictionary;
@class NSString;

// Global Section Type...
enum
  {
    SolutionConfigurationPlatforms = 0, 
    ProjectConfigurationPlatforms,
    ProjectSolutionProperties,
    ExtensibilityGlobals,
  };
typedef NSUInteger GSXCVSGlobalSectionType;

@interface GSXCVSGlobalSection : NSObject
{
  NSMutableDictionary *_values; /* choosing to contain rather than subclass */
  GSXCVSGlobalSectionType _type;
}

- (NSString *) string;

- (id) objectForKey: (NSString *)k;
- (void) setObject: (id)o forKey: (NSString *)k;

- (GSXCVSGlobalSectionType) type;
- (void) setType: (GSXCVSGlobalSectionType)type;

@end

