// Released under the terms of LGPL 2.1, Please see COPYING.LIB

#import "GSXCCMakeGenerator.h"
#import "PBXNativeTarget.h"
#import "XCConfigurationList.h"
#import "PBXBuildFile.h"
#import "PBXFileReference.h"

#import "NSArray+Additions.h"

@implementation GSXCCMakeGenerator

- (BOOL) generate
{
  BOOL result = YES;
  GSXCBuildContext *context = [GSXCBuildContext sharedBuildContext];
  NSString *name = [_target name];
  NSString *appName = [name stringByDeletingPathExtension];
  NSString *fileName = @"CMakeLists.txt";
  NSString *fileString = @"";
  NSString *headerFilesString = [[context objectForKey: @"HEADERS"] arrayToList];
  NSString *cFilesString = [[context objectForKey: @"C_FILES"] arrayToList];
  NSString *cppFilesString = [[context objectForKey: @"CPP_FILES"] arrayToList];
  NSString *objCPPFilesString = [[context objectForKey: @"OBJCPP_FILES"] arrayToList];  
  NSString *resourceFilesString = [[context objectForKey: @"RESOURCES"] arrayToList];
  NSString *additionalIncludes = [[context objectForKey: @"ADDITIONAL_INCLUDE_DIRS"] arrayToIncludeList];
  NSString *additionalOCflags = [[context objectForKey: @"ADDITIONAL_OBJC_LIBS"] arrayToLinkList];
  NSString *projectType = [context objectForKey: @"PROJECT_TYPE"];
  NSString *libType = @"SHARED";
  
  if ([projectType isEqualToString: @"framework"])
    {
      NSString *objCFilesString = [[context objectForKey: @"OBJC_FILES"] implodeArrayWithSeparator: @"\t\n"];

      fileString = [fileString stringByAppendingString: [NSString stringWithFormat: @"add_library(\n\t%@\n\t%@\n%@)\n",
								  appName, libType, objCFilesString]];
      
    }
  else
    {
    }	    

  NSLog(@"Project Type = %@, name = %@", projectType, fileName);
  result = [fileString writeToFile: fileName atomically: YES];
  
  return result;
}

@end
