#import <Foundation/Foundation.h>
#import "PBXCommon.h"
#import "PBXHeadersBuildPhase.h"
#import "PBXFileReference.h"
#import "PBXBuildFile.h"
#import "GSXCBuildContext.h"

@implementation PBXHeadersBuildPhase
- (BOOL) build
{
  NSLog(@"=== Executing Headers Build Phase");

  NSLog(@"\t* Copying headers to derived sources folder...");
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
      NSLog(@"\tCopy %@ -> %@",srcFile,dstFile);
      if(!copyResult)
	{
	  NSLog(@"\t* Already exists");
	}
    }

  NSLog(@"\t* Copying headers to header folder...");
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
      NSLog(@"\tCopy %@ -> %@",srcFile,dstFile);      
      if(!copyResult)
	{
	  NSLog(@"\t* Already exists");
	}
    }
  NSLog(@"=== Completed Headers Build Phase");

  return result;
}
@end
