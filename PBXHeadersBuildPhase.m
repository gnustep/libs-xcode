#import <Foundation/Foundation.h>
#import "PBXCommon.h"
#import "PBXHeadersBuildPhase.h"
#import "PBXFileReference.h"
#import "PBXBuildFile.h"
#import "GSXCBuildContext.h"
#import "GSXCCommon.h"

@implementation PBXHeadersBuildPhase
- (BOOL) build
{
  puts("=== Executing Headers Build Phase");
  NSString *productType = [[GSXCBuildContext sharedBuildContext] objectForKey: @"PRODUCT_TYPE"];
  if([productType isEqualToString: BUNDLE_TYPE] ||
     [productType isEqualToString: TOOL_TYPE] ||
     [productType isEqualToString: APPLICATION_TYPE]) // ||
   //[productType isEqualToString: LIBRARY_TYPE])
    {
      puts([[NSString stringWithFormat: @"\t** WARN: No need to process headers for product type %@",productType] cString]);
      return YES;
    }

  puts([[NSString stringWithFormat: @"\t* Copying headers to derived sources folder..."] cString]);
  NSFileManager *defaultManager = [NSFileManager defaultManager];
  id file = nil;
  BOOL result = YES;
  GSXCBuildContext *context = [GSXCBuildContext sharedBuildContext];
  NSError *error = nil;

  NSEnumerator *en = [files objectEnumerator];
  NSString *derivedSourceHeaderDir = [context objectForKey: @"DERIVED_SOURCE_HEADER_DIR"];
  while((file = [en nextObject]) != nil && result)
    {
      NSString *path = [[file fileRef] path];
      NSString *srcFile = [[file fileRef] buildPath];
      NSString *dstFile = [derivedSourceHeaderDir stringByAppendingPathComponent: [path lastPathComponent]];
      BOOL copyResult = [defaultManager copyItemAtPath: srcFile
						toPath: dstFile
						 error: &error];
      puts([[NSString stringWithFormat: @"\tCopy %@ -> %@",srcFile,dstFile] cString]);
      if(!copyResult)
	{
	  puts([[NSString stringWithFormat: @"\t* Already exists"] cString]);
	}
    }

  // Only copy into the framework header folder, if it's a framework...
  if([productType isEqualToString: FRAMEWORK_TYPE])
    {
      puts([[NSString stringWithFormat: @"\t* Copying headers to framework header folder..."] cString]);
      en = [files objectEnumerator];
      NSString *headerDir = [context objectForKey: @"HEADER_DIR"];
      while((file = [en nextObject]) != nil && result)
	{
	  NSString *path = [[file fileRef] path];
	  NSString *srcFile = [[file fileRef] buildPath];
	  NSString *dstFile = [headerDir stringByAppendingPathComponent: [path lastPathComponent]];
	  BOOL copyResult = [defaultManager copyItemAtPath: srcFile
						    toPath: dstFile
						     error: &error];
	  puts([[NSString stringWithFormat: @"\tCopy %@ -> %@",srcFile,dstFile] cString]);      
	  if(!copyResult)
	    {
	      puts([[NSString stringWithFormat: @"\t* Already exists"] cString]);
	    }
	}
    }

  puts([[NSString stringWithFormat: @"=== Completed Headers Build Phase"] cString]);

  return result;
}
@end
