#import "PBXCommon.h"
#import "PBXFrameworksBuildPhase.h"
#import "PBXFileReference.h"
#import "PBXBuildFile.h"
#import "GSXCBuildContext.h"
#import "NSArray+Additions.h"
#import "NSString+PBXAdditions.h"
#import "GSXCCommon.h"

@implementation PBXFrameworksBuildPhase

- (void) generateDummyClass
{
  NSString *frameworkPath = [[[NSString stringWithCString: getenv("GNUSTEP_SYSTEM_ROOT")] 
				      stringByAppendingPathComponent: @"Library"] 
				     stringByAppendingPathComponent: @"Frameworks"];
  NSString *frameworkVersion = [NSString stringWithCString: getenv("FRAMEWORK_VERSION")];
  NSString *executableName = [NSString stringWithCString: getenv("EXECUTABLE_NAME")];
  NSString *classList = @"";
  NSString *outputDir = [[NSString stringWithCString: getenv("PROJECT_ROOT")] 
			  stringByAppendingPathComponent: @"derived_src"];
  NSString *fileName = [NSString stringWithFormat: @"NSFramework_%@.m",executableName];
  NSString *outputPath = [outputDir stringByAppendingPathComponent: fileName];
  NSString *buildDir = [NSString stringWithCString: getenv("TARGET_BUILD_DIR")];
  NSString *objDir = [NSString stringWithCString: getenv("BUILT_PRODUCTS_DIR")];
  NSError *error = nil;

  // Create the derived source directory...
  [[NSFileManager defaultManager] createDirectoryAtPath:outputDir
			    withIntermediateDirectories:YES
					     attributes:nil
						  error:&error];

  NSString *classesFilename = [[outputDir stringByAppendingPathComponent: executableName] stringByAppendingString: @"-class-list"];
  NSString *classesFormat = 
    @"echo \"(\" > %@; nm -Pg %@/*.o | grep __objc_class_name | "
    @"sed -e '/^__objc_class_name_[A-Za-z0-9_.]* [^U]/ {s/^__objc_class_name_\\([A-Za-z0-9_.]*\\) [^U].*/\\1/p;}' | "
    @"grep -v __objc_class_name | sort | uniq | while read class; do echo \"${class},\"; done >> %@; echo \")\" >> %@;"; 
  NSString *classesCommand = [NSString stringWithFormat: classesFormat,
				       classesFilename,
				       buildDir,
				       classesFilename,
				       classesFilename];
  system([classesCommand cString]);
  
  // build the list...
  NSArray *classArray = [NSArray arrayWithContentsOfFile: classesFilename];
  NSEnumerator *en = [classArray objectEnumerator];
  NSString *className = nil;
  while((className = [en nextObject]) != nil)
    {
      classList = [classList stringByAppendingString: [NSString stringWithFormat: @"@\"%@\",",className]];
    }

  // Write the file out...
  NSString *classTemplate = 
    @"#include <Foundation/Foundation.h>\n\n"
    @"@interface NSFramework_%@\n"
    @"+ (NSString *)frameworkEnv;\n"
    @"+ (NSString *)frameworkPath;\n"
    @"+ (NSString *)frameworkVersion;\n"
    @"+ (NSString *const*)frameworkClasses;\n"
    @"@end\n\n"
    @"@implementation NSFramework_%@\n"
    @"+ (NSString *)frameworkEnv { return nil; }\n"
    @"+ (NSString *)frameworkPath { return @\"%@\"; }\n"
    @"+ (NSString *)frameworkVersion { return @\"%@\"; }\n"
    @"static NSString *allClasses[] = {%@NULL};\n"
    @"+ (NSString *const*)frameworkClasses { return allClasses; }\n"
    @"@end\n";
  NSString *dummyClass = [NSString stringWithFormat: classTemplate, 
				   executableName,
				   executableName,
				   frameworkPath,
				   frameworkVersion,
				   classList];
  [dummyClass writeToFile: outputPath 
	       atomically: YES
		 encoding: NSASCIIStringEncoding
		    error: &error];
  
  // compile...
  NSString *compiler = [NSString stringWithCString: getenv("CC")];
  NSString *buildPath = outputPath;
  NSString *objPath = [objDir stringByAppendingPathComponent: [fileName stringByAppendingString: @".o"]];
  if([compiler isEqualToString: @""] ||
     compiler == nil)
    {
      compiler = @"`gnustep-config --variable=CC`";
    }
  GSXCBuildContext *context = [GSXCBuildContext sharedBuildContext];
  NSString *configString = [context objectForKey: @"CONFIG_STRING"]; 
  NSString *buildTemplate = @"%@ %@ -c %@ -o %@";
  NSString *buildCommand = [NSString stringWithFormat: buildTemplate, 
				     compiler,
				     [buildPath stringByEscapingSpecialCharacters],
				     configString,
				     [objPath stringByEscapingSpecialCharacters]];
  NSString *of = [context objectForKey: @"OUTPUT_FILES"];
  NSString *outputFiles = (of == nil)?@"":of;
  outputFiles = [[outputFiles stringByAppendingString: objPath] 
		  stringByAppendingString: @" "];
  [context setObject: outputFiles forKey: @"OUTPUT_FILES"];

  NSLog(@"\t%@",buildCommand);
  system([buildCommand cString]);
}

- (NSString *) frameworkLinkString: (NSString*)framework
{
  if ([framework isEqualToString: @"Cocoa"])
    {
      return @"`gnustep-config --gui-libs` ";
    }
  else if ([framework isEqualToString: @"Foundation"])
    {
      return @"`gnustep-config --base-libs` ";
    }
  else if ([framework isEqualToString: @"AppKit"])
    {
      return @"`gnustep-config --gui-libs` ";
    }
  else if ([framework isEqualToString: @"CoreFoundation"])
    {
      return @"-lcorebase ";
    }
  else if ([framework isEqualToString: @"CoreGraphics"])
    {
      return @"-lopal ";
    }
  else if ([framework isEqual: @"Carbon"] ||
           [framework isEqual: @"IOKit"] ||
           [framework isEqual: @"Quartz"] ||
           [framework isEqual: @"QuartzCore"] ||
           [framework isEqual: @"QuickTime"] ||
           [framework isEqual: @"ApplicationServices"])
    {
      return @"";
    }
  else
    {
      return [NSString stringWithFormat: @"-l%@ ", framework];
    }
}

- (NSString *) linkString
{
  NSString *systemLibDir = [@"`gnustep-config --variable=GNUSTEP_SYSTEM_LIBRARY`/"
			       stringByAppendingPathComponent: @"Libraries"];
  NSString *localLibDir = [@"`gnustep-config --variable=GNUSTEP_LOCAL_LIBRARY`/"
			      stringByAppendingPathComponent: @"Libraries"];
  NSString *userLibDir = [@"`gnustep-config --variable=GNUSTEP_USER_LIBRARY`/"
			     stringByAppendingPathComponent: @"Libraries"];
  NSString *buildDir = [NSString stringWithCString: getenv("TARGET_BUILD_DIR")];
  NSString *uninstalledProductsDir = [buildDir stringByAppendingPathComponent: @"UninstalledProducts"];
  NSEnumerator *en = [files objectEnumerator];
  id file = nil;
  NSString *linkString = [NSString stringWithFormat: @"-L%@ -L%@ -L%@ ",
				   userLibDir,
				   localLibDir,
				   systemLibDir];;
  NSFileManager *manager = [NSFileManager defaultManager];
  NSDirectoryEnumerator *dirEnumerator = [manager enumeratorAtPath:uninstalledProductsDir];

  while((file = [en nextObject]) != nil)
    {
      PBXFileReference *fileRef = [file fileRef];
      NSString *name = [[[fileRef path] lastPathComponent] stringByDeletingPathExtension];
      
      linkString = [linkString stringByAppendingString: [self frameworkLinkString: name]];
    }

  // Find any frameworks and add them to the -L directive...
  while((file = [dirEnumerator nextObject]) != nil)
    {
      NSString *ext = [file pathExtension];
      if([ext isEqualToString:@"framework"])
	{
	  NSString *headerDir = [file stringByAppendingPathComponent:@"Headers"];
	  linkString = [linkString stringByAppendingString:[NSString stringWithFormat:@"-I%@ ",[uninstalledProductsDir stringByAppendingPathComponent:headerDir]]];
	  linkString = [linkString stringByAppendingString:[NSString stringWithFormat:@"-L%@ ",[uninstalledProductsDir stringByAppendingPathComponent:file]]];
	}
    }

  GSXCBuildContext *context = [GSXCBuildContext sharedBuildContext];
  NSArray *otherLDFlags = [context objectForKey: @"OTHER_LDFLAGS"];
  en = [otherLDFlags objectEnumerator];
  while((file = [en nextObject]) != nil)
    {
      if ([file isEqualToString: @"-framework"])
        {
          NSString *framework = [en nextObject];
          linkString = [linkString stringByAppendingString: [self frameworkLinkString: framework]];
        }
      else
        {
          //linkString = [linkString stringByAppendingString:];
        }
    }

  linkString = [linkString stringByAppendingString: @"-lpthread -lobjc -lm "];

  return linkString;
}

- (BOOL) buildTool
{
  NSLog(@"=== Executing Frameworks Build Phase (Tool)");
  // GSXCBuildContext *context = [GSXCBuildContext sharedBuildContext];
  char *cc = getenv("CC");
  NSString *compiler = (cc == NULL)?@"`gnustep-config --variable=CC`":[NSString stringWithCString: cc];
  NSString *outputFiles = [[GSXCBuildContext sharedBuildContext] objectForKey: 
								   @"OUTPUT_FILES"];
  NSString *outputDir = [NSString stringWithCString: getenv("PRODUCT_OUTPUT_DIR")];
  NSString *executableName = [NSString stringWithCString: getenv("EXECUTABLE_NAME")];
  NSString *outputPath = [outputDir stringByAppendingPathComponent: executableName];
  NSString *linkString = [self linkString];
  linkString = [linkString stringByAppendingString: @"`gnustep-config --base-libs`"];

  NSString *command = [NSString stringWithFormat: 
				  @"%@ -rdynamic -shared-libgcc -fgnu-runtime -o %@ %@ %@",
				compiler, 
				[outputPath stringByEscapingSpecialCharacters],
				outputFiles,
				linkString];

  GSXCBuildContext *context = [GSXCBuildContext sharedBuildContext];
  NSString *modified = [context objectForKey: @"MODIFIED_FLAG"];
  int result = 0;
  if([modified isEqualToString: @"YES"])
    {
      NSLog(@"\t%@",command);
      result = system([command cString]);
    }
  else
    {
      NSLog(@"\t** Nothing to be done for %@, no modifications.",outputPath);
    }

  // NSLog(@"\t%@",command);
  // int result = system([command cString]);

  NSLog(@"=== Frameworks Build Phase Completed");
  return (result == 0);
}

- (BOOL) buildApp
{
  NSLog(@"=== Executing Frameworks Build Phase (Application)");
  GSXCBuildContext *context = [GSXCBuildContext sharedBuildContext];
  char *cc = getenv("CC");
  NSString *compiler = (cc == NULL)?@"`gnustep-config --variable=CC`":[NSString stringWithCString: cc];
  NSString *outputFiles = [context objectForKey: 
				     @"OUTPUT_FILES"];
  NSString *outputDir = [NSString stringWithCString: getenv("PRODUCT_OUTPUT_DIR")];
  NSString *executableName = [NSString stringWithCString: getenv("EXECUTABLE_NAME")];
  NSString *outputPath = [outputDir stringByAppendingPathComponent: executableName];
  NSString *linkString = [self linkString];
  // NSString *configString = [context objectForKey: @"CONFIG_STRING"]; 

  NSString *command = [NSString stringWithFormat: 
				  @"%@ -rdynamic -shared-libgcc -fgnu-runtime -o %@ %@ %@",
				compiler, 
				[outputPath stringByEscapingSpecialCharacters],
				outputFiles,
				linkString];

  NSString *modified = [context objectForKey: @"MODIFIED_FLAG"];
  int result = 0;
  if([modified isEqualToString: @"YES"])
    {
      NSLog(@"\t%@",command);
      result = system([command cString]);
    }
  else
    {
      NSLog(@"\t** Nothing to be done for %@, no modifications.",outputPath);
    }

  // NSLog(@"\t%@",command);
  // int result = system([command cString]);

  NSLog(@"=== Frameworks Build Phase Completed");
  return (result == 0);
}

- (BOOL) buildStaticLib
{
  NSLog(@"=== Executing Frameworks Build Phase (Static Library)");
  NSString *outputFiles = [[GSXCBuildContext sharedBuildContext] objectForKey: 
								   @"OUTPUT_FILES"];
  NSString *outputDir = [NSString stringWithCString: getenv("PRODUCT_OUTPUT_DIR")];
  NSString *executableName = [NSString stringWithCString: getenv("EXECUTABLE_NAME")];
  NSString *outputPath = [outputDir stringByAppendingPathComponent: executableName];
  NSString *commandTemplate = @"ar rc %@ %@; ranlib %@";
  NSString *command = [NSString stringWithFormat: commandTemplate,
				outputPath,
				outputFiles,
				outputPath];
  GSXCBuildContext *context = [GSXCBuildContext sharedBuildContext];
  NSString *modified = [context objectForKey: @"MODIFIED_FLAG"];
  int result = 0;
  if([modified isEqualToString: @"YES"])
    {
      NSLog(@"\t%@",command);
      result = system([command cString]);
    }
  else
    {
      NSLog(@"\t** Nothing to be done for %@, no modifications.",outputPath);
    }

  NSLog(@"=== Frameworks Build Phase Completed");

  return (result == 0);
}

- (BOOL) buildFramework
{
  int result = 0;
  NSLog(@"=== Executing Frameworks Build Phase (Framework)");
  [self generateDummyClass];
  GSXCBuildContext *context = [GSXCBuildContext sharedBuildContext];
  NSString *outputFiles = [context objectForKey: 
				     @"OUTPUT_FILES"];
  NSString *modified = [context objectForKey: @"MODIFIED_FLAG"];
  NSString *outputDir = [NSString stringWithCString: getenv("PRODUCT_OUTPUT_DIR")];
  NSString *executableName = [NSString stringWithCString: getenv("EXECUTABLE_NAME")];
  NSString *outputPath = [outputDir stringByAppendingPathComponent: executableName];
  NSString *frameworkVersion = [NSString stringWithCString: getenv("FRAMEWORK_VERSION")];
  NSString *libNameWithVersion =  [NSString stringWithFormat: @"lib%@.so.%@",
					    executableName,frameworkVersion];
  NSString *libName = [NSString stringWithFormat: @"lib%@.so",executableName];

  NSString *libraryPath = [outputDir stringByAppendingPathComponent: libNameWithVersion];
  NSString *libraryPathNoVersion = [outputDir stringByAppendingPathComponent: libName];
  NSString *systemLibDir = [[[NSString stringWithCString: getenv("GNUSTEP_SYSTEM_ROOT")] 
				      stringByAppendingPathComponent: @"Library"] 
				     stringByAppendingPathComponent: @"Libraries"];
  NSString *localLibDir = [[[NSString stringWithCString: getenv("GNUSTEP_LOCAL_ROOT")] 
				     stringByAppendingPathComponent: @"Library"] 
				    stringByAppendingPathComponent: @"Libraries"];
  NSString *userLibDir = [[[NSString stringWithCString: getenv("GNUSTEP_USER_ROOT")] 
				    stringByAppendingPathComponent: @"Library"] 
				   stringByAppendingPathComponent: @"Libraries"];
  NSString *frameworkRoot = [context objectForKey: @"FRAMEWORK_DIR"];
  NSString *libraryLink = [frameworkRoot stringByAppendingPathComponent: libName];
  NSString *execLink = [frameworkRoot stringByAppendingPathComponent: executableName];

  NSString *commandTemplate = @"%@ -shared -Wl,-soname,lib%@.so.%@  -rdynamic " 
    @"-shared-libgcc -o %@ %@ "
    @"-L%@ -L/%@ -L%@";     
  NSString *compiler = [NSString stringWithCString: getenv("CC")];
  if([compiler isEqualToString: @""] ||
     compiler == nil)
    {
      compiler = @"`gnustep-config --variable=CC`";
    }

  NSString *command = [NSString stringWithFormat: commandTemplate,
				compiler,
				executableName,
				frameworkVersion,
				libraryPath,
				outputFiles,
				userLibDir,
				localLibDir,
				systemLibDir];

  // Create link to library...
  [[NSFileManager defaultManager] createSymbolicLinkAtPath: outputPath
					       pathContent: libName];

  [[NSFileManager defaultManager] createSymbolicLinkAtPath: libraryPathNoVersion
					       pathContent: libNameWithVersion];

  [[NSFileManager defaultManager] createSymbolicLinkAtPath: libraryLink
					       pathContent: 
				[NSString stringWithFormat: @"Versions/Current/%@",libName]];

  [[NSFileManager defaultManager] createSymbolicLinkAtPath: execLink
					       pathContent: 
				[NSString stringWithFormat: @"Versions/Current/%@",executableName]];


  if([modified isEqualToString: @"YES"])
    {
      NSLog(@"\t%@",command);
      result = system([command cString]);
    }
  else
    {
      NSLog(@"\t** Nothing to be done for %@, no modifications.",outputPath);
    }

  NSLog(@"=== Frameworks Build Phase Completed");
  return (result == 0);
}

- (BOOL) buildBundle
{
  NSLog(@"=== Executing Frameworks Build Phase (Bundle)");
  // GSXCBuildContext *context = [GSXCBuildContext sharedBuildContext];
  char *cc = getenv("CC");
  NSString *compiler = (cc == NULL)?@"`gnustep-config --variable=CC`":[NSString stringWithCString: cc];
  NSString *outputFiles = [[GSXCBuildContext sharedBuildContext] objectForKey: 
								   @"OUTPUT_FILES"];
  NSString *outputDir = [NSString stringWithCString: getenv("PRODUCT_OUTPUT_DIR")];
  NSString *executableName = [NSString stringWithCString: getenv("EXECUTABLE_NAME")];
  NSString *outputPath = [outputDir stringByAppendingPathComponent: executableName];
  NSString *linkString = [self linkString];

  NSString *command = [NSString stringWithFormat: 
				  @"%@ -rdynamic -shared-libgcc -fgnu-runtime -o %@ %@ %@",
				compiler, 
				[outputPath stringByEscapingSpecialCharacters],
				outputFiles,
				linkString];

  GSXCBuildContext *context = [GSXCBuildContext sharedBuildContext];
  NSString *modified = [context objectForKey: @"MODIFIED_FLAG"];
  int result = 0;
  if([modified isEqualToString: @"YES"])
    {
      NSLog(@"\t%@",command);
      result = system([command cString]);
    }
  else
    {
      NSLog(@"\t** Nothing to be done for %@, no modifications.",outputPath);
    }

  // NSLog(@"\t%@",command);
  // int result = system([command cString]);

  NSLog(@"=== Frameworks Build Phase Completed");
  return (result == 0);
}

- (BOOL) build
{
  GSXCBuildContext *context = [GSXCBuildContext sharedBuildContext];
  NSString *productType = [context objectForKey: @"PRODUCT_TYPE"];
  if([productType isEqualToString: APPLICATION_TYPE])
    {
      return [self buildApp];
    }
  else if([productType isEqualToString: TOOL_TYPE])
    {
      return [self buildTool];
    }
  else if([productType isEqualToString: LIBRARY_TYPE])
    {
      return [self buildStaticLib];
    }
  else if([productType isEqualToString: FRAMEWORK_TYPE])
    {
      return [self buildFramework];
    }
  else if([productType isEqualToString: BUNDLE_TYPE])
    {
      return [self buildBundle];
    }
  else 
    {
      NSLog(@"***** ERROR: Unknown product type: %@",productType);
    }
  return NO;
}

@end
