#import "GSXCMakefileGenerator.h"
#import "PBXNativeTarget.h"
#import "XCConfigurationList.h"

@implementation GSXCMakefileGenerator

- (NSString *) _arrayToLinkList: (NSArray *)arr
{
  NSString *result = @"";
  NSEnumerator *en = [arr objectEnumerator];
  NSString *aname = nil;

  while((aname = [en nextObject]) != nil)
    {
      if ([aname isEqualToString: [arr firstObject]] == YES)
        {
          result = [result stringByAppendingString: [NSString stringWithFormat: @"%@ ", aname]];
        }
      else
        {
          result = [result stringByAppendingString: [NSString stringWithFormat: @"\t%@ ", aname]];
        }
      
      if ([aname isEqualToString: [arr lastObject]] == NO)
        {
          result = [result stringByAppendingString: @"\\\n"];
        }
    }
  return result;
}

- (NSString *) _arrayToIncludeList: (NSArray *)arr
{
  NSString *result = @"-I. \\\n";
  NSEnumerator *en = [arr objectEnumerator];
  NSString *aname = nil;

  while((aname = [en nextObject]) != nil)
    {
      result = [result stringByAppendingString: [NSString stringWithFormat: @"\t-I./%@ ", aname]];
      if ([aname isEqualToString: [arr lastObject]] == NO)
        {
          result = [result stringByAppendingString: @"\\\n"];
        }
    }
  return result;
}

- (NSString *) _arrayToList: (NSArray *)arr
{
  NSString *result = @"";
  NSEnumerator *en = [arr objectEnumerator];
  NSString *aname = nil;

  while((aname = [en nextObject]) != nil)
    {
      if ([aname isEqualToString: [arr firstObject]] == YES)
        {
          result = [result stringByAppendingString: [NSString stringWithFormat: @"%@ ", aname]];
        }
      else
        {
          result = [result stringByAppendingString: [NSString stringWithFormat: @"\t%@ ", aname]];
        }
      
      if ([aname isEqualToString: [arr lastObject]] == NO)
        {
          result = [result stringByAppendingString: @"\\\n"];
        }
    }
  return result;
}

- (BOOL) generate
{
  BOOL result = YES;
  NSEnumerator *en = nil;
  GSXCBuildContext *context = [GSXCBuildContext sharedBuildContext];
  NSArray *buildPhases = [_target buildPhases];
  NSArray *dependencies = [_target dependencies];
  NSString *name = [_target name];
  XCConfigurationList *buildConfigurationList = [_target buildConfigurationList];
  NSString *productType = [_target productType];
  NSString *productSettingsXML = [_target productSettingsXML];
  
  xcputs([[NSString stringWithFormat: @"=== Generating Target: %@",name] cString]);
  [buildConfigurationList applyDefaultConfiguration];
  [context setObject: productType
	      forKey: @"PRODUCT_TYPE"];
  if(productSettingsXML != nil)
    {
      [context setObject: productSettingsXML 
                  forKey: @"PRODUCT_SETTINGS_XML"];
    }
  xcputs([[NSString stringWithFormat: @"=== Checking Dependencies"] cString]);  
  id dependency = nil;
  en = [dependencies objectEnumerator];
  while((dependency = [en nextObject]) != nil && result)
    {
      result = [dependency generate];
    }
  xcputs([[NSString stringWithFormat: @"=== Done."] cString]);

  xcputs([[NSString stringWithFormat: @"=== Interpreting build phases..."] cString]);

  // [self _productWrapper];
  id phase = nil;
  en = [buildPhases objectEnumerator];
  while((phase = [en nextObject]) != nil && result)
    {
      NSAutoreleasePool *p = [[NSAutoreleasePool alloc] init];
      
      [phase setTarget: _target];
      result = [phase generate];
      if(NO == result)
	{
	  xcputs([[NSString stringWithFormat: @"*** Failed build phase: %@",phase] cString]);
	}

      RELEASE(p);
    }
  xcputs([[NSString stringWithFormat: @"=== Done..."] cString]);

  NSString *appName = [name stringByDeletingPathExtension];
  
  // Construct the makefile out of the data we have thusfar collected.
  xcputs("\t** Generating GNUmakefile from data...");
  NSString *makefileName = @"GNUmakefile";
  NSString *makefileString = @"";
  NSString *objCFilesString = [self _arrayToList: [context objectForKey: @"OBJC_FILES"]];
  NSString *cFilesString = [self _arrayToList: [context objectForKey: @"C_FILES"]];
  NSString *cppFilesString = [self _arrayToList: [context objectForKey: @"CPP_FILES"]];
  NSString *objCPPFilesString = [self _arrayToList: [context objectForKey: @"OBJCPP_FILES"]];  
  NSString *resourceFilesString = [self _arrayToList: [context objectForKey: @"RESOURCES"]];
  NSString *additionalIncludes = [self _arrayToIncludeList: [context objectForKey: @"ADDITIONAL_INCLUDE_DIRS"]];
  NSString *additionalOCflags = [self _arrayToLinkList: [context objectForKey: @"ADDITIONAL_OBJC_LIBS"]];
  NSString *projectType = [context objectForKey: @"PROJECT_TYPE"];

  // Sometimes the build will generate all of the target makefiles in one place, depending on the version of
  // Xcode the project was created with.
  if([[NSFileManager defaultManager] fileExistsAtPath: @"GNUmakefile"])
    {
      // if it collides with the existing name, add the target name...
      makefileName = [makefileName stringByAppendingString: [NSString stringWithFormat: @"_%@", appName]];
    }

  makefileString = [makefileString stringByAppendingString: @"#\n"];
  makefileString = [makefileString stringByAppendingString: [NSString stringWithFormat: @"# GNUmakefile for target %@\n", name]];
  makefileString = [makefileString stringByAppendingString: @"# begin - generated by buildtool\n"];
  makefileString = [makefileString stringByAppendingString: @"#\n\n"];
  makefileString = [makefileString stringByAppendingString: @"include $(GNUSTEP_MAKEFILES)/common.make\n\n"];
  makefileString = [makefileString stringByAppendingString: [NSString stringWithFormat: @"APP_NAME = %@\n\n", appName]];
  makefileString = [makefileString stringByAppendingString: [NSString stringWithFormat: @"%@_OBJC_FILES = %@\n\n", appName, objCFilesString]];
  makefileString = [makefileString stringByAppendingString: [NSString stringWithFormat: @"%@_C_FILES = %@\n\n", appName, cFilesString]];
  makefileString = [makefileString stringByAppendingString: [NSString stringWithFormat: @"%@_CPP_FILES = %@\n\n", appName, cppFilesString]];
  makefileString = [makefileString stringByAppendingString: [NSString stringWithFormat: @"%@_OBJCPP_FILES = %@\n\n", appName, objCPPFilesString]];
  makefileString = [makefileString stringByAppendingString: [NSString stringWithFormat: @"%@_RESOURCE_FILES = %@\n\n", appName, resourceFilesString]];
  makefileString = [makefileString stringByAppendingString: [NSString stringWithFormat: @"ADDITIONAL_INCLUDE_DIRS += %@\n\n", additionalIncludes]];
  makefileString = [makefileString stringByAppendingString: [NSString stringWithFormat: @"ADDITIONAL_OBJC_LIBS += %@\n\n", additionalOCflags]];
  makefileString = [makefileString stringByAppendingString: @"include $(GNUSTEP_MAKEFILES)/common.make\n"];
  makefileString = [makefileString stringByAppendingString: [NSString stringWithFormat: @"include $(GNUSTEP_MAKEFILES)/%@.make\n\n", projectType]];
  makefileString = [makefileString stringByAppendingString: @"#\n"];
  makefileString = [makefileString stringByAppendingString: @"# end - generated makefile\n"];
  makefileString = [makefileString stringByAppendingString: @"#\n"];

  NSDebugLog(@"makefile = %@", makefileString);
  [makefileString writeToFile: makefileName atomically: YES];
  xcputs([[NSString stringWithFormat: @"=== Completed generation for target %@", name] cString]);

  return result;
}

@end
