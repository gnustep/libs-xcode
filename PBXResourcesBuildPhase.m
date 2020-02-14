#import "PBXCommon.h"
#import "PBXResourcesBuildPhase.h"
#import "PBXFileReference.h"
#import "PBXBuildFile.h"
#import "PBXVariantGroup.h"
#import "NSString+PBXAdditions.h"
#import "GSXCBuildContext.h"

@implementation PBXResourcesBuildPhase
- (instancetype) init
{
  self = [super init];
  if (self != nil)
    {
      NSArray *objs = nil;
      objs = [[[GSXCBuildContext sharedBuildContext] objectForKey: @"objects"] allValues];
      
      ASSIGNCOPY(files, objs);
    }
  return self;
}

- (BOOL) build
{
  puts("=== Executing Resources Build Phase");
  // char *proot = getenv("PROJECT_ROOT");
  // NSString *projectRoot = [NSString stringWithCString: proot == NULL?"":proot ];
  NSString *productOutputDir = [NSString stringWithCString: getenv("PRODUCT_OUTPUT_DIR")];
  NSString *resourcesDir = [productOutputDir stringByAppendingPathComponent: @"Resources"];
  // NSString *currentDir = [[NSFileManager defaultManager] currentDirectoryPath];
  NSError *error = nil;

  [[NSFileManager defaultManager] createDirectoryAtPath:resourcesDir
			    withIntermediateDirectories:YES
					     attributes:nil
						  error:&error];

  // Copy all resources...
  NSEnumerator *en = [files objectEnumerator];
  BOOL result = YES;
  id file = nil;
  while((file = [en nextObject]) != nil && result)
    {
      id fileRef = [file fileRef];
      NSLog(@"fileRef = %@", fileRef); /// , fileType);
      if ([fileRef isKindOfClass: [PBXVariantGroup class]])
        {
          NSArray *children = [fileRef children];
          NSEnumerator *e = [children objectEnumerator];
          id child = nil;
          while ((child = [e nextObject]) != nil)
            {
              NSLog(@"\t%@", child);
              NSLog(@"child = %@", child); /// , fileType);
              NSString *filePath = [child path]; // [[child buildPath] stringByDeletingFirstPathComponent];
              NSString *fileDir = [resourcesDir stringByAppendingPathComponent: [filePath stringByDeletingLastPathComponent]];
              NSString *fileName = [filePath lastPathComponent];
              NSString *destPath = [resourcesDir stringByAppendingPathComponent: fileName];
              NSFileManager *mgr = [NSFileManager defaultManager];
              NSError *error = nil;
              BOOL copyResult = NO; 
              
              // If there is more than one path component... then the intervening directories need to
              // be created.
              if([[filePath pathComponents] count] > 1)
                {
                  NSString *dirs = [filePath stringByDeletingLastPathComponent];
                  
                  destPath = [resourcesDir stringByAppendingPathComponent: dirs];
                  destPath = [destPath stringByAppendingPathComponent: fileName];
                }
              
              NSLog(@"\tCreate %@",fileDir);
              copyResult = [mgr       createDirectoryAtPath: fileDir
                                withIntermediateDirectories: YES
                                                 attributes: nil
                                                      error: &error];
              if (copyResult == NO)
                {
                  NSLog(@"\t(create error = %@)", error);
                }

              NSLog(@"\tCopy child %@  -> %@",filePath,destPath);
              copyResult = [[NSFileManager defaultManager] copyItemAtPath: filePath
                                                                   toPath: destPath
                                                                    error: &error];
              if (copyResult == NO)
                {
                  NSLog(@"\t(error = %@)", error);
                }
            }
          continue;
        }
      
      // NSString *fileType = [fileRef explicitFileType];
      NSString *filePath = [file path]; //  stringByDeletingFirstPathComponent];
      NSString *fileName = [filePath lastPathComponent];
      NSString *destPath = [resourcesDir stringByAppendingPathComponent: fileName];
      NSError *error = nil;
      BOOL copyResult = NO; 

      // If there is more than one path component... then the intervening directories need to
      // be created.
      if([[filePath pathComponents] count] > 1)
	{
	  NSString *dirs = [filePath stringByDeletingLastPathComponent];

	  destPath = [resourcesDir stringByAppendingPathComponent: dirs];
	  destPath = [destPath stringByAppendingPathComponent: fileName];
	}
      
      NSLog(@"\tX Copy %@ -> %@",filePath,destPath);
      copyResult = [[NSFileManager defaultManager] copyItemAtPath: filePath
							   toPath: destPath
							    error: &error];

      if(!copyResult)
	{
	  NSDebugLog(@"\tCopy Error: %@ copying %@ -> %@",[error localizedDescription],
                     filePath, destPath);
	}
    }

  //
  // Copy XIBs...
  // NSString *origPath = [currentDir stringByAppendingPathComponent:@"Base.lproj/*"];
  // NSString *copyCmd = [NSString stringWithFormat: @"cp %@ %@", origPath, resourcesDir];
  // int r = 0;
  // puts([[NSString stringWithFormat: @"COPYING: %@", copyCmd] cString]);
  // r = system([copyCmd cString]);
  //
  // return, if we failed...
  // if(r != 0)
  //  {
  //    puts("Error copying...");
  //  }
  //
  
  // Handle Info.plist....
  NSString *inputPlist = [[NSString stringWithCString: getenv("INFOPLIST_FILE")] lastPathComponent];
  NSString *outputPlist = [resourcesDir stringByAppendingPathComponent: @"Info-gnustep.plist"];
  NSString *awkCommand = [NSString stringWithFormat: @"awk '{while(match($0,\"[$]{[^}]*}\")) "
                                   @"{var=substr($0,RSTART+2,RLENGTH -3);gsub(\"[$]{\"var\"}\","
                                   @"ENVIRON[var])}}1' < %@ > %@",
				   [inputPlist stringByEscapingSpecialCharacters],
                                   [outputPlist stringByEscapingSpecialCharacters]];
  int sysresult = 0;
  NSDebugLog(@"\t%@",awkCommand);
  sysresult = system([awkCommand cString]);
  result = (sysresult == 0);
  
  puts("=== Resources Build Phase Completed");
  return result;
}
@end
