#import "PBXCommon.h"
#import "PBXFrameworksBuildPhase.h"
#import "PBXFileReference.h"
#import "PBXBuildFile.h"
#import "GSXCBuildContext.h"
#import "NSArray+Additions.h"
#import "NSString+PBXAdditions.h"
#import "GSXCCommon.h"

#import <Foundation/NSPathUtilities.h>

@implementation PBXFrameworksBuildPhase

- (NSString *) linkerForBuild
{
  GSXCBuildContext *context = [GSXCBuildContext sharedBuildContext];
  BOOL linkWithCpp = [[context objectForKey: @"LINK_WITH_CPP"] isEqualToString: @"YES"];
  NSString *compiler = @"`gnustep-config --variable=CC`";

  if (linkWithCpp)
    {
      compiler = @"`gnustep-config --variable=CXX`";
    }

  return compiler;
}

- (void) generateDummyClass
{
  NSArray *libs = NSSearchPathForDirectoriesInDomains(NSAllLibrariesDirectory, NSLocalDomainMask, YES);
  NSString *frameworkPath = [([libs firstObject] != nil ? [libs firstObject] : @"") stringByAppendingPathComponent: @"Frameworks"];
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
      compiler = [self linkerForBuild]; // @"`gnustep-config --variable=CC`";
    }
  GSXCBuildContext *context = [GSXCBuildContext sharedBuildContext];
  NSString *configString = [context objectForKey: @"CONFIG_STRING"]; 
  NSString *buildTemplate = @"%@ %@ -c %@ -o %@";
  NSString *buildCommand = [NSString stringWithFormat: buildTemplate, 
				     compiler,
				     [buildPath stringByEscapingSpecialCharacters],
				     configString,
				     [objPath stringByEscapingSpecialCharacters]];
  NSString *of = [self processOutputFilesString];
  NSString *outputFiles = (of == nil)?@"":of;
  outputFiles = [[outputFiles stringByAppendingString: objPath] 
		  stringByAppendingString: @" "];
  [context setObject: outputFiles forKey: @"OUTPUT_FILES"];

  puts([[NSString stringWithFormat: @"\t%@",buildCommand] cString]);
  system([buildCommand cString]);
}

- (NSString *) frameworkLinkString: (NSString*)framework
{
  NSString *path = [[NSBundle bundleForClass: [self class]]
                     pathForResource: @"Framework-mapping" ofType: @"plist"];
  NSDictionary *propList = [[NSString stringWithContentsOfFile: path] propertyList];
  NSArray *ignored = [propList objectForKey: @"Ignored"];
  NSDictionary *mapped = [propList objectForKey: @"Mapped"];
  NSString *result = nil;
  
  NSDebugLog(@"path = %@", path);
  if ([ignored containsObject: framework])
    {
      return @"";
    }

  result = [mapped objectForKey: framework];
  result = result != nil ? result : [NSString stringWithFormat: @"-l%@ ", framework];

  return result;
} 

- (NSString *) processOutputFilesString
{
  NSString *outputString = @"";
  NSString *outputFiles = [[GSXCBuildContext sharedBuildContext] objectForKey: 
								   @"OUTPUT_FILES"];
  /*
  NSArray *strings = [outputFiles componentsSeparatedByString: @".o "];
  NSString *s = nil;
  NSEnumerator *en = [strings objectEnumerator];

  while ((s = [en nextObject]) != nil)
    {
      if ([s isEqualToString: @""] == NO)
	{
	  outputString = [outputString stringByAppendingString: [NSString stringWithFormat: @" \"%@.o\" ", s]];
	}
    }
  */
  outputString = outputFiles;

  return outputString;
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
  NSString *uninstalledProductsDir = [buildDir stringByAppendingPathComponent: @"Products"];
  NSString *linkString = [NSString stringWithFormat: @"-L%@ -L%@ -L%@ ",
				   userLibDir,
				   localLibDir,
				   systemLibDir];;
  NSFileManager *manager = [NSFileManager defaultManager];
  NSDirectoryEnumerator *dirEnumerator = [manager enumeratorAtPath:uninstalledProductsDir];

  // NSString *s = [self frameworkLinkString: @"AppKit"];
  NSEnumerator *en = [files objectEnumerator];
  id file = nil;

  // NSDebugLog(@"*** Frameworks build phase files = %@, %@", files, s);
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
	  linkString = [linkString stringByAppendingString:[NSString stringWithFormat:@"-I%@ ",
								     [uninstalledProductsDir stringByAppendingPathComponent:headerDir]]];
	  linkString = [linkString stringByAppendingString:[NSString stringWithFormat:@"-L%@ ",
								     [uninstalledProductsDir stringByAppendingPathComponent:file]]];
	}
    }

  GSXCBuildContext *context = [GSXCBuildContext sharedBuildContext];
  NSArray *otherLDFlags = [context objectForKey: @"OTHER_LDFLAGS"];
  NSDebugLog(@"OTHER_LDFLAGS = %@", otherLDFlags);
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

  linkString = [linkString stringByAppendingString: @" -lpthread -lobjc -lm "];

  // Do substitutions and additions for buildtool.plist...
  NSDictionary *plistFile = [NSDictionary dictionaryWithContentsOfFile: @"buildtool.plist"];
  NSDebugLog(@"%@",plistFile);
  NSDictionary *substitutionList = [plistFile objectForKey: @"substitutions"];
  NSArray *additionalFlags = [plistFile objectForKey: @"additional"];
  NSDebugLog(@"%@", additionalFlags);
  if (additionalFlags != nil)
    {
      [context setObject: additionalFlags forKey: @"ADDITIONAL_OBJC_LIBS"];
    }
  
  // Replace anything that needs substitution... not all libraries on macos map directly...
  en = [[substitutionList allKeys] objectEnumerator];
  id o = nil;
  while ((o = [en nextObject]) != nil)
    {
      NSString *r = [substitutionList objectForKey: o];
      linkString = [linkString stringByReplacingOccurrencesOfString: o
                                                         withString: r];
    }

  // Add any additional libs...
  en = [additionalFlags objectEnumerator];
  o = nil;
  while ((o = [en nextObject]) != nil)
    {
      linkString = [linkString stringByAppendingFormat: @" %@ ", o];
    }
  
  return linkString;
}

- (BOOL) buildTool
{
  puts([[NSString stringWithFormat: @"=== Executing Frameworks Build Phase (Tool)"] cString]);
  // GSXCBuildContext *context = [GSXCBuildContext sharedBuildContext];
  char *cc = getenv("CC");
  NSString *compiler = (cc == NULL)?[self linkerForBuild]:[NSString stringWithCString: cc];
  NSString *outputFiles = [self processOutputFilesString];
  NSString *outputDir = [NSString stringWithCString: getenv("PRODUCT_OUTPUT_DIR")];
  NSString *executableName = [NSString stringWithCString: getenv("EXECUTABLE_NAME")];
  NSString *outputPath = [outputDir stringByAppendingPathComponent: executableName];
  NSString *linkString = [self linkString];
  linkString = [linkString stringByAppendingString: @" `gnustep-config --base-libs` `gnustep-config --variable=LDFLAGS` -lgnustep-base "];

  NSString *command = [NSString stringWithFormat: 
				  @"%@ -rdynamic -shared-libgcc -fgnu-runtime -o \"%@\" %@ %@",
				compiler, 
				outputPath,
				outputFiles,
				linkString];

  NSDebugLog(@"command = %@", command);
  GSXCBuildContext *context = [GSXCBuildContext sharedBuildContext];
  NSString *modified = [context objectForKey: @"MODIFIED_FLAG"];
  int result = 0;
  if([modified isEqualToString: @"YES"])
    {
      // puts("\t%@",command);
      result = system([command cString]);
    }
  else
    {
      puts([[NSString stringWithFormat: @"\t** Nothing to be done for %@, no modifications.",outputPath] cString]);
    }

  puts("=== Frameworks Build Phase Completed");
  return (result == 0);
}

- (BOOL) buildApp
{
  puts("=== Executing Frameworks Build Phase (Application)");
  GSXCBuildContext *context = [GSXCBuildContext sharedBuildContext];
  char *cc = getenv("CC");
  NSString *compiler = (cc == NULL)?[self linkerForBuild]:[NSString stringWithCString: cc];
  NSString *outputFiles = [self processOutputFilesString];
  NSString *outputDir = [NSString stringWithCString: getenv("PRODUCT_OUTPUT_DIR")];
  NSString *executableName = [NSString stringWithCString: getenv("EXECUTABLE_NAME")];
  NSString *outputPath = [outputDir stringByAppendingPathComponent: executableName];
  NSString *linkString = [self linkString];
  linkString = [linkString stringByAppendingString: @" `gnustep-config --objc-flags --objs-libs --base-libs --gui-libs` `gnustep-config --variable=LDFLAGS` -lgnustep-base -lgnustep-gui "];
  NSDebugLog(@"LINK: %@", linkString);
           
  NSString *command = [NSString stringWithFormat: 
				  @"%@ -rdynamic -shared-libgcc -fgnu-runtime -o \"%@\" %@ %@",
				compiler, 
				outputPath,
				outputFiles,
				linkString];

  
  NSDebugLog(@"command = %@", command);
  NSString *modified = [context objectForKey: @"MODIFIED_FLAG"];
  int result = 0;
  if([modified isEqualToString: @"YES"])
    {
      puts([[NSString stringWithFormat: @"\t* Linking \"%@\"",outputPath] cString]);
      result = system([command cString]);
    }
  else
    {
      puts([[NSString stringWithFormat: @"\t** Nothing to be done for \"%@\", no modifications.",outputPath] cString]);
    }

  puts("=== Frameworks Build Phase Completed");
  return (result == 0);
}

- (BOOL) buildStaticLib
{
  puts("=== Executing Frameworks Build Phase (Static Library)");
  NSString *outputFiles = [self processOutputFilesString];
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
      puts([[NSString stringWithFormat: @"\t* Linking %@",outputPath] cString]);
      result = system([command cString]);
    }
  else
    {
      puts([[NSString stringWithFormat: @"\t** Nothing to be done for %@, no modifications.",outputPath] cString]);
    }

  puts("=== Frameworks Build Phase Completed");

  return (result == 0);
}

- (BOOL) buildFramework
{
  int result = 0;
  puts("=== Executing Frameworks Build Phase (Framework)");
  [self generateDummyClass];
  GSXCBuildContext *context = [GSXCBuildContext sharedBuildContext];
  NSString *outputFiles = [self processOutputFilesString];
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
  char *cc = getenv("CC");
  NSString *compiler = (cc == NULL)?[self linkerForBuild]:[NSString stringWithCString: cc];
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
      puts([[NSString stringWithFormat: @"\t* Linking %@",outputPath] cString]);      
      result = system([command cString]);
    }
  else
    {
      puts([[NSString stringWithFormat: @"\t** Nothing to be done for %@, no modifications.",outputPath] cString]);
    }

  puts("=== Frameworks Build Phase Completed");
  return (result == 0);
}

- (BOOL) buildBundle
{
  puts("=== Executing Frameworks Build Phase (Bundle)");
  // GSXCBuildContext *context = [GSXCBuildContext sharedBuildContext];
  char *cc = getenv("CC");
  NSString *compiler = (cc == NULL)?[self linkerForBuild]:[NSString stringWithCString: cc];
  NSString *outputFiles = [self processOutputFilesString];
  NSString *outputDir = [NSString stringWithCString: getenv("PRODUCT_OUTPUT_DIR")];
  NSString *executableName = [NSString stringWithCString: getenv("EXECUTABLE_NAME")];
  NSString *outputPath = [outputDir stringByAppendingPathComponent: executableName];
  NSString *linkString = [self linkString];

  NSString *command = [NSString stringWithFormat: 
				  @"%@ -rdynamic -shared-libgcc -fgnu-runtime -o \"%@\" %@ %@",
				compiler, 
				outputPath,
				outputFiles,
				linkString];

  GSXCBuildContext *context = [GSXCBuildContext sharedBuildContext];
  NSString *modified = [context objectForKey: @"MODIFIED_FLAG"];
  int result = 0;
  if([modified isEqualToString: @"YES"])
    {
      puts([[NSString stringWithFormat: @"\t* Linking %@",outputPath] cString]);            
      result = system([command cString]);
    }
  else
    {
      puts([[NSString stringWithFormat: @"\t** Nothing to be done for %@, no modifications.",outputPath] cString]);
    }

  puts("=== Frameworks Build Phase Completed");
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
      puts([[NSString stringWithFormat: @"***** ERROR: Unknown product type: %@",productType] cString]);
    }
  return NO;
}

- (BOOL) generate
{
  GSXCBuildContext *context = [GSXCBuildContext sharedBuildContext];
  NSString *productType = [context objectForKey: @"PRODUCT_TYPE"];

  NSDictionary *plistFile = [NSDictionary dictionaryWithContentsOfFile: @"buildtool.plist"];
  NSArray *additionalFlags = [plistFile objectForKey: @"additional"];
  
  NSDebugLog(@"%@", additionalFlags);
  if (additionalFlags != nil)
    {
      [context setObject: additionalFlags forKey: @"ADDITIONAL_OBJC_LIBS"];
    }

  printf("\t* Adding product type entry: %s\n", [productType cStringUsingEncoding: NSUTF8StringEncoding]);
  
  if([productType isEqualToString: APPLICATION_TYPE])
    {
      [context setObject: @"application"
                  forKey: @"PROJECT_TYPE"];
    }
  else if([productType isEqualToString: TOOL_TYPE])
    {
      [context setObject: @"tool"
                  forKey: @"PROJECT_TYPE"];
    }
  else if([productType isEqualToString: LIBRARY_TYPE])
    {
      [context setObject: @"library"
                  forKey: @"PROJECT_TYPE"];
    }
  else if([productType isEqualToString: FRAMEWORK_TYPE])
    {
      [context setObject: @"framework"
                  forKey: @"PROJECT_TYPE"];
    }
  else if([productType isEqualToString: BUNDLE_TYPE])
    {
      [context setObject: @"bundle"
                  forKey: @"PROJECT_TYPE"];
    }
  else 
    {
      puts([[NSString stringWithFormat: @"***** ERROR: Unknown product type: %@",productType] cString]);
    }
  
  return YES;
}
@end
