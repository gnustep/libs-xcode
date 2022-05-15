// Released under the terms of LGPLv2.1, please see COPYING.LIB

#import <Foundation/NSString.h>
#import <Foundation/NSXMLDocument.h>
#import <Foundation/NSUUID.h>

#import "GSXCVSProject.h"
#import "GSXCVSSolution.h"
#import "GSXCCommon.h"
#import "NSString+PBXAdditions.h"

/*
@interface GSXCVSItem : NSObject <NSCopying>
{
  NSString *_label;
}

- (void) label;

@end

@interface GSXCVSProjectConfiguration : GSXCVSItem
{
  NSString *_configuration;
  NSString *_platform;
}

- (NSString *) configuration;
- (NSString *) platform;

@end

@interface GSXCVSItemGroup : NSObject <NSCopying>
{
  NSMutableArray *_items;
}

- (NSArray *) items;

@end
*/

@interface NSXMLElement (Additions)

- (NSXMLElement *) elementWithName: (NSString *) name;
- (NSXMLElement *) elementWithName: (NSString *) name stringValue: (NSString *) value;

@end

@implementation NSXMLElement (Additions)

- (NSXMLElement *) elementWithName: (NSString *) name
{
  return AUTORELEASE([[NSXMLElement alloc] initWithName: name]);
}

- (NSXMLElement *) elementWithName: (NSString *) name stringValue: (NSString *) value
{
  return AUTORELEASE([[NSXMLElement alloc] initWithName: name stringValue: value]);
}

@end

@interface NSString (Additions)

- (NSString *) convertPathSeparator;

@end

@implementation NSString (Additions)

- (NSString *) convertPathSeparator
{
  return [self stringByReplacingOccurrencesOfString: @"/"
                                         withString: @"\\"];
}

@end

@implementation GSXCVSProject

+ (instancetype) project
{
  return AUTORELEASE([[self alloc] init]);
}

+ (instancetype) projectWithSolution: (GSXCVSSolution *)s
{
  return AUTORELEASE([[self alloc] initWithSolution: s]);
}

- (instancetype) init
{
  self = [super init];

  if (self != nil)
    {
      ASSIGN(_uuid, [NSUUID UUID]);
      ASSIGN(_root, [NSUUID UUID]);
    }
  
  return self;
}

- (instancetype) initWithSolution: (GSXCVSSolution *)s
{
  self = [self init];
  if (self != nil)
    {
      PBXAbstractTarget *target = [s target];
      NSString *name = [target name];
      NSString *path = [NSString stringWithFormat: @"%@\\%@.vcxproj", name, name];

      ASSIGN(_solution, s);
      ASSIGN(_name, name);
      ASSIGN(_path, path);      
    }
  return self;
}

- (NSString *) name
{
  return _name;
}

- (NSString *) path
{
  return _path;
}

- (NSUUID *) uuid
{
  return _uuid;
}

- (NSUUID *) root
{
  return _root;
}

- (GSXCVSSolution *) solution
{
  return _solution;
}

- (NSString *) configurationType
{
  GSXCBuildContext *context = [GSXCBuildContext sharedBuildContext];
  NSString *projectType = [context objectForKey: @"PROJECT_TYPE"];
  NSString *result = @"";

  if ([projectType isEqualToString: @"application"])
    result = @"Application";
  else if ([projectType isEqualToString: @"tool"])
    result = @"Unknown";
  else if ([projectType isEqualToString: @"framework"])
    result = @"DynamicLibrary";
  else if ([projectType isEqualToString: @"dynamic-library"])
    result = @"DynamicLibrary";
  else if ([projectType isEqualToString: @"static-library"])
    result = @"StaticLibrary";

  return result;
}

- (NSString *) buildArchitecture
{
  return @"x64";
}

- (NSString *) buildRelease
{
  return @"Release";
}

- (NSString *) releaseString
{
  // this will be dynamic in the future...
  return [NSString stringWithFormat: @"%@|%@", [self buildRelease], [self buildArchitecture]];
}

- (NSXMLElement *) projectConfigItemGroup
{
  NSXMLNode *attr = nil;
  
  // Config & platform
  NSXMLElement *config = [NSXMLElement elementWithName: @"Configuration"];  
  NSXMLElement *platform = [NSXMLElement elementWithName: @"Platform"];
  [config setStringValue: [self buildRelease] resolvingEntities: NO];
  [platform setStringValue: [self buildArchitecture] resolvingEntities: NO];
  
  // Project Configuration
  NSXMLElement *projectConfiguration = [NSXMLElement elementWithName: @"ProjectConfiguration"];
  attr = [NSXMLNode attributeWithName: @"Include" stringValue: [self releaseString]];
  [projectConfiguration addAttribute: attr];
  [projectConfiguration addChild: config];
  [projectConfiguration addChild: platform];

  // Item Group
  NSXMLElement *itemGroup = [NSXMLElement elementWithName: @"ItemGroup"];
  attr = [NSXMLNode attributeWithName: @"Label" stringValue: @"ProjectConfigurations"];
  [itemGroup addAttribute: attr];
  [itemGroup addChild: projectConfiguration];

  return itemGroup;
}

- (NSXMLElement *) projectProperties
{
  NSXMLNode *attr = nil;
  
  // Config & platform
  NSXMLElement *projVersion = [NSXMLElement elementWithName: @"VCProjectVersion"];
  NSXMLElement *keyword = [NSXMLElement elementWithName: @"Keyword"];
  NSXMLElement *projGuid = [NSXMLElement elementWithName: @"ProjectGuid"];
  NSXMLElement *rootNamespace = [NSXMLElement elementWithName: @"RootNamespace"];
  NSXMLElement *windowsTarget = [NSXMLElement elementWithName: @"WindowsTargetPlatformVersion"];

  [projVersion setStringValue: @"16.0" resolvingEntities: NO];
  [keyword setStringValue: _name resolvingEntities: NO];
  [projGuid setStringValue: [NSString stringWithFormat: @"{%@}", [_uuid UUIDString]] resolvingEntities: NO];
  [rootNamespace setStringValue: _name resolvingEntities: NO];
  [windowsTarget setStringValue: @"10.0" resolvingEntities: NO];
  
  // Property Group
  attr = [NSXMLNode attributeWithName: @"Label" stringValue: @"Globals"];
  NSXMLElement *propertyGroup = [NSXMLElement elementWithName: @"PropertyGroup"];
  [propertyGroup addAttribute: attr];
  [propertyGroup addChild: projVersion];
  [propertyGroup addChild: keyword];
  [propertyGroup addChild: projGuid];
  [propertyGroup addChild: rootNamespace];
  [propertyGroup addChild: windowsTarget];

  return propertyGroup;
}

- (NSXMLElement *) configurationPropertyGroup
{
  NSXMLNode *attr = nil;
  
  NSXMLElement *configurationType = [NSXMLElement elementWithName: @"ConfigurationType"];
  NSXMLElement *useDebugLibraries = [NSXMLElement elementWithName: @"UseDebugLibraries"];
  NSXMLElement *platformToolset = [NSXMLElement elementWithName: @"PlatformToolset"];
  NSXMLElement *wholeProgramOpt = [NSXMLElement elementWithName: @"WholeProgramOptimization"];
  NSXMLElement *characterSet = [NSXMLElement elementWithName: @"CharacterSet"];

  [configurationType setStringValue: [self configurationType]];
  [useDebugLibraries setStringValue: @"false"];
  [platformToolset setStringValue: @"ClangCL"];
  [wholeProgramOpt setStringValue: @"true"];
  [characterSet setStringValue: @"Unicode"];

  // Configuration Property Group
  NSXMLElement *propertyGroup2 = [NSXMLElement elementWithName: @"PropertyGroup"];
  attr = [NSXMLNode attributeWithName: @"Label" stringValue: @"Configuration"];
  [propertyGroup2 addAttribute: attr];
  attr = [NSXMLNode attributeWithName: @"Condition" stringValue: [NSString stringWithFormat:
                                                                             @"'$(Configuration)|$(Platform)'=='%@'", [self releaseString]]];
  [propertyGroup2 addAttribute: attr];
  [propertyGroup2 addChild: configurationType];
  [propertyGroup2 addChild: useDebugLibraries];
  [propertyGroup2 addChild: platformToolset];
  [propertyGroup2 addChild: wholeProgramOpt];
  [propertyGroup2 addChild: characterSet];

  return propertyGroup2;
}

- (NSXMLElement *) importGroup
{
  NSXMLNode *attr = nil;
  
  // Import groups
  NSXMLElement *import = [NSXMLElement elementWithName: @"Import"];
  attr = [NSXMLNode attributeWithName: @"Project" stringValue: @"$(VCTargetsPath)\\Microsoft.Cpp.props"];
  [import addAttribute: attr];

  return import;
}

- (NSXMLElement *) importExtensionGroup
{
  NSXMLNode *attr = nil;
  NSXMLElement *importExtension = [NSXMLElement elementWithName: @"ImportGroup"];

  attr = [NSXMLNode attributeWithName: @"Label" stringValue: @"ExtensionSettings"];
  [importExtension addAttribute: attr];

  return importExtension;
}

- (NSXMLElement *) importSharedGroup
{
  NSXMLNode *attr = nil;
  NSXMLElement *importShared = [NSXMLElement elementWithName: @"ImportGroup"];

  attr = [NSXMLNode attributeWithName: @"Label" stringValue: @"Shared"];
  [importShared addAttribute: attr];

  return importShared;  
}

- (NSXMLElement *) importCondition
{
  NSXMLNode *attr = nil;
  NSXMLElement *importCondition = [NSXMLElement elementWithName: @"ImportGroup"];
  attr = [NSXMLNode attributeWithName: @"Label" stringValue: @"PropertySheets"];
  [importCondition addAttribute: attr];
  attr = [NSXMLNode attributeWithName: @"Condition" stringValue: [NSString stringWithFormat:
                                                                             @"'$(Configuration)|$(Platform)'=='%@'", [self releaseString]]];
  [importCondition addAttribute: attr];

  return importCondition;
}

- (NSXMLElement *) linkPropertyGroup
{
  NSXMLNode *attr = nil;

  // Property group
  NSXMLElement *linkPropertyGroup = [NSXMLElement elementWithName: @"PropertyGroup"];
  attr = [NSXMLNode attributeWithName: @"Condition" stringValue: [NSString stringWithFormat:
                                                                             @"'$(Configuration)|$(Platform)'=='%@'", [self releaseString]]];
  [linkPropertyGroup addAttribute: attr];
  [linkPropertyGroup addChild:
                       [NSXMLElement elementWithName: @"LinkIncremental"
                                         stringValue: @"false"]];
  [linkPropertyGroup addChild:
                       [NSXMLElement elementWithName: @"IncludePath"
                                         stringValue: @"C:\\GNUstep\\$(LibrariesArchitecture)\\include;$(IncludePath)"]];
  [linkPropertyGroup addChild:
                       [NSXMLElement elementWithName: @"LibraryPath"
                                         stringValue: @"C:\\GNUstep\\$(LibrariesArchitecture)\\lib;$(LibraryPath)"]];
  
  return linkPropertyGroup;
}

- (NSString *) preprocessDefinition
{
  // this should be dymamic at some point...
  return @"NDEBUG;_WINDOWS;GNUSTEP;GNUSTEP_WITH_DLL;GNUSTEP_RUNTIME=1;_NONFRAGILE_ABI=1;_NATIVE_OBJC_EXCEPTIONS;GSWARN;GSDIAGNOSE;%(PreprocessorDefinitions)";
}

- (NSString *) additionalOptions
{
  // This should be dynamic in the future...
  return @"-fobjc-runtime=gnustep-2.0 -Xclang -fexceptions -Xclang -fobjc-exceptions -fblocks -Xclang -fobjc-arc %(AdditionalOptions)";
}

- (NSString *) additionalDependencies
{
  NSString *configType = [self configurationType];
  NSString *result = @"";

  if ([configType isEqualToString: @"Application"])
    {
      result = @"gnustep-base.lib;gnustep-gui.lib;objc.lib;dispatch.lib;%(AdditionalDependencies)";
    }
  else if ([configType isEqualToString: @"Unknown"])
    {
      result = @"gnustep-base.lib;objc.lib;dispatch.lib;%(AdditionalDependencies)";
    }

  return result;
}

- (NSXMLElement *) linkItemDefinitionGroup
{
  NSXMLNode *attr = nil;
  NSXMLElement *linkItemDefinition = [NSXMLElement elementWithName: @"ItemDefinitionGroup"];
  attr = [NSXMLNode attributeWithName: @"Condition" stringValue: [NSString stringWithFormat:
                                                                             @"'$(Configuration)|$(Platform)'=='%@'", [self releaseString]]];
  [linkItemDefinition addAttribute: attr];
  NSXMLElement *clCompile = [NSXMLElement elementWithName: @"ClCompile"];
  NSXMLElement *warningLevel = [NSXMLElement elementWithName: @"WarningLevel" stringValue: @"Level3"];
  NSXMLElement *sdlCheck = [NSXMLElement elementWithName: @"SDLCheck" stringValue: @"true"];
  NSXMLElement *preprocessDefinitions = [NSXMLElement elementWithName: @"PreprocessDefinitions" stringValue: [self preprocessDefinition]];
  NSXMLElement *conformanceMode = [NSXMLElement elementWithName: @"ConformanceMode" stringValue: @"true"];
  NSXMLElement *additionalOptions = [NSXMLElement elementWithName: @"AdditionalOptions" stringValue: [self additionalOptions]];

  [clCompile addChild: warningLevel];
  [clCompile addChild: sdlCheck];
  [clCompile addChild: preprocessDefinitions];
  [clCompile addChild: conformanceMode];
  [clCompile addChild: additionalOptions];

  [linkItemDefinition addChild: clCompile];

  NSXMLElement *link = [NSXMLElement elementWithName: @"Link"];
  NSXMLElement *subsystem = [NSXMLElement elementWithName: @"Subsystem" stringValue: @"Windows"];
  NSXMLElement *enableComdatFolding = [NSXMLElement elementWithName: @"EnableCOMDATFolding" stringValue: @"true"];
  NSXMLElement *optimizeReferences = [NSXMLElement elementWithName: @"OptimizeReferences" stringValue: @"true"];
  NSXMLElement *generateDebugInformation = [NSXMLElement elementWithName: @"GenerateDebugInformation" stringValue: @"true"];
  NSXMLElement *additionalDependencies = [NSXMLElement elementWithName: @"AdditionalDependencies" stringValue: [self additionalDependencies]];

  [link addChild: subsystem];
  [link addChild: enableComdatFolding];
  [link addChild: optimizeReferences];
  [link addChild: generateDebugInformation];
  [link addChild: additionalDependencies];

  [linkItemDefinition addChild: link];

  return linkItemDefinition;
}

- (NSXMLElement *) includeItemGroup
{
  GSXCBuildContext *context = [GSXCBuildContext sharedBuildContext];
  NSArray *headers = [context objectForKey: @"HEADERS"];
  NSEnumerator *en = [headers objectEnumerator];
  NSString *o = nil;

  NSXMLElement *itemGroup = [NSXMLElement elementWithName: @"ItemGroup"];

  while ((o = [en nextObject]) != nil)
    {
      NSXMLElement *clInclude = [NSXMLElement elementWithName: @"ClInclude"];
      NSXMLNode *attr = [NSXMLNode attributeWithName: @"Include" stringValue: [o convertPathSeparator]];
      [clInclude addAttribute: attr];
      [itemGroup addChild: clInclude];
    }

  return itemGroup;
}

- (NSXMLElement *) compileItemGroup
{
  GSXCBuildContext *context = [GSXCBuildContext sharedBuildContext];
  NSMutableArray *files = [NSMutableArray array]; 
  NSString *o = nil;
  NSArray *arr = nil;

  arr = [context objectForKey: @"OBJC_FILES"];
  if (arr)
    [files addObjectsFromArray: arr];
  arr = [context objectForKey: @"C_FILES"];
  if (arr)
    [files addObjectsFromArray: arr];
  arr = [context objectForKey: @"CPP_FILES"];
  if (arr)
    [files addObjectsFromArray: arr];
  arr = [context objectForKey: @"OBJCPP_FILES"];
  if (arr)
    [files addObjectsFromArray: arr];
  
  NSXMLElement *itemGroup = [NSXMLElement elementWithName: @"ItemGroup"];
  NSEnumerator *en = [files objectEnumerator];

  while ((o = [en nextObject]) != nil)
    {
      NSXMLElement *clCompile = [NSXMLElement elementWithName: @"ClCompile"];
      NSXMLNode *attr = nil;
      attr = [NSXMLNode attributeWithName: @"Include" stringValue: [[o stringByDeletingFirstPathComponent] convertPathSeparator]];
      [clCompile addAttribute: attr];

      NSXMLElement *compileAs = [NSXMLElement elementWithName: @"CompileAs"];
      attr = [NSXMLNode attributeWithName: @"Condition" stringValue: [NSString stringWithFormat:
                                                                                 @"'$(Configuration)|$(Platform)'=='%@'", [self releaseString]]];
      [compileAs addAttribute: attr];
      [clCompile addChild: compileAs];
      [itemGroup addChild: clCompile];
    }

  return itemGroup;
}

/*
- (NSXMLElement *) resouceItemGroup
{
  GSXCBuildContext *context = [GSXCBuildContext sharedBuildContext];
  NSArray *files = [context objectForKey: @"RESOURCES"];
  NSString *o = nil;
  NSXMLElement *itemGroup = [NSXMLElement elementWithName: @"ItemGroup"];
  NSEnumerator *en = [files objectEnumerator];

  while ((o = [en nextObject]) != nil)
    {
      NSXMLElement *clCompile = [NSXMLElement elementWithName: @"ClCompile"];
      NSXMLNode *attr = nil;
      attr = [NSXMLNode attributeWithName: @"Include" stringValue: [[o stringByDeletingFirstPathComponent] convertPathSeparator]];
      [clCompile addAttribute: attr];

      NSXMLElement *compileAs = [NSXMLElement elementWithName: @"CompileAs"];
      attr = [NSXMLNode attributeWithName: @"Condition" stringValue: [NSString stringWithFormat:
                                                                                 @"'$(Configuration)|$(Platform)'=='%@'", [self releaseString]]];
      [compileAs addAttribute: attr];
      [clCompile addChild: compileAs];
      [itemGroup addChild: clCompile];
    }

  return itemGroup;
}
*/

- (NSXMLDocument *) build
{
  NSString *url = @"http://schemas.microsoft.com/developer/msbuild/2003";
  NSXMLDocument *projectXml = [[NSXMLDocument alloc] init];
  NSXMLNode *attr = nil;
 
  // Root
  NSXMLElement *rootElement = [NSXMLElement elementWithName: @"Project"];
  attr = [NSXMLNode attributeWithName: @"DefaultTargets" stringValue: @"Build"];
  [rootElement addAttribute: attr];
  attr = [NSXMLNode attributeWithName: @"xmlns" stringValue: url];
  [rootElement addAttribute: attr];
  [rootElement addChild: [self projectConfigItemGroup]];
  [rootElement addChild: [self projectProperties]];
  [rootElement addChild: [self configurationPropertyGroup]];
  [rootElement addChild: [self importGroup]];
  [rootElement addChild: [self importExtensionGroup]];
  [rootElement addChild: [self importSharedGroup]];
  [rootElement addChild: [self importCondition]];
  [rootElement addChild: [self linkPropertyGroup]];
  [rootElement addChild: [self linkItemDefinitionGroup]];

  NSXMLElement *element = [self includeItemGroup];
  if (element != nil)
    {
      [rootElement addChild: element];
    }

  element = [self compileItemGroup];
  if (element != nil)
    {
      [rootElement addChild: element];
    }
  
  // Root element for document...
  [projectXml setRootElement: rootElement];

  return projectXml;
  
}

- (NSString *) string
{
  NSXMLDocument *projectXml = [self build];
  NSData *data = [projectXml XMLDataWithOptions: NSXMLNodePrettyPrint];
  NSString *xmlString = [[NSString alloc] initWithData: data encoding: NSUTF8StringEncoding];
  return xmlString;
}

@end
