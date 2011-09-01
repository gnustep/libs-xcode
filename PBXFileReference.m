#import "PBXCommon.h"
#import "PBXFileReference.h"
#import <stdlib.h>

@implementation PBXFileReference

// Methods....
- (NSString *) sourceTree // getter
{
  return sourceTree;
}

- (void) setSourceTree: (NSString *)object; // setter
{
  ASSIGN(sourceTree,object);
}

- (NSString *) lastKnownFileType // getter
{
  return lastKnownFileType;
}

- (void) setLastKnownFileType: (NSString *)object; // setter
{
  ASSIGN(lastKnownFileType,object);
}

- (NSString *) path // getter
{
  return path;
}

- (void) setPath: (NSString *)object; // setter
{
  ASSIGN(path,object);
}

- (NSString *) fileEncoding // getter
{
  return fileEncoding;
}

- (void) setFileEncoding: (NSString *)object; // setter
{
  ASSIGN(fileEncoding,object);
}

- (NSString *) explicitFileType
{
  return explicitFileType;
}

- (void) setExplicitFileType: (NSString *)object
{
  ASSIGN(explicitFileType,object);
}

- (NSString *) name;
{
  return name;
}

- (void) setName: (NSString *)object
{
  ASSIGN(name,object);
}

- (BOOL) build
{  
  char *of = getenv("OUTPUT_FILES");
  NSString *outputFiles = (of == NULL)?@"":[NSString stringWithCString: of];
  int result = 0;
  if([lastKnownFileType isEqualToString: @"sourcecode.c.objc"] ||
     [lastKnownFileType isEqualToString: @"sourcecode.c.c"] || 
     [lastKnownFileType isEqualToString: @"sourcecode.c.cpp"])
    {
      NSString *fileName = [path lastPathComponent];
      NSString *buildDir = [NSString stringWithCString: getenv("TARGET_BUILD_DIR")];
      NSString *systemIncludeDir = [[[NSString stringWithCString: getenv("GNUSTEP_SYSTEM_ROOT")] 
				      stringByAppendingPathComponent: @"Library"] 
				     stringByAppendingPathComponent: @"Headers"];
      NSString *localIncludeDir = [[[NSString stringWithCString: getenv("GNUSTEP_LOCAL_ROOT")] 
				     stringByAppendingPathComponent: @"Library"] 
				    stringByAppendingPathComponent: @"Headers"];
      NSString *userIncludeDir = [[[NSString stringWithCString: getenv("GNUSTEP_USER_ROOT")] 
				    stringByAppendingPathComponent: @"Library"] 
				   stringByAppendingPathComponent: @"Headers"];
      NSString *compiler = [NSString stringWithCString: getenv("CC")];
      NSString *buildPath = [[[NSString stringWithCString: getenv("PROJECT_ROOT")] 
			       stringByAppendingPathComponent: 
				 [NSString stringWithCString: getenv("SOURCE_ROOT")]]
			      stringByAppendingPathComponent: fileName];
      NSString *outputPath = [buildDir stringByAppendingPathComponent: [fileName stringByAppendingString: @".o"]];
      outputFiles = [[outputFiles stringByAppendingString: outputPath] stringByAppendingString: @" "];
      if([compiler isEqualToString: @""] ||
	 compiler == nil)
	{
	  compiler = @"gcc";
	}

      NSString *buildTemplate = @"%@ %@ -c -MMD -MP -DGNUSTEP -DGNUSTEP_BASE_LIBRARY=1 -DGNU_GUI_LIBRARY=1 -DGNU_RUNTIME=1 -DGNUSTEP_BASE_LIBRARY=1 -fno-strict-aliasing -fexceptions -fobjc-exceptions -D_NATIVE_OBJC_EXCEPTIONS -fPIC -DDEBUG -fno-omit-frame-pointer -Wall -DGSWARN -DGSDIAGNOSE -Wno-import -g -fgnu-runtime -fconstant-string-class=NSConstantString -I. -I%@ -I%@ -I%@ -o %@";
      
      NSString *buildCommand = [NSString stringWithFormat: buildTemplate, 
					 compiler,
					 buildPath, 
					 userIncludeDir,
					 localIncludeDir, 
					 systemIncludeDir, 
					 outputPath];
      NSLog(@"\t%@",buildCommand);
      result = system([buildCommand cString]);
    }

  setenv("OUTPUT_FILES",[outputFiles cString],1);

  return (result != 127);
}
@end
