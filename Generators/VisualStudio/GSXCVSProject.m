// Released under the terms of LGPLv2.1, please see COPYING.LIB

#import <Foundation/NSString.h>
#import <Foundation/NSXMLDocument.h>
#import <Foundation/NSUUID.h>

#import "GSXCVSProject.h"
#import "GSXCVSSolution.h"
#import "GSXCCommon.h"

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


- (NSString *) build
{
  NSString *url = @"http://schemas.microsoft.com/developer/msbuild/2003";
  NSXMLDocument *projectXml = [[NSXMLDocument alloc] init];

  // Config & platform
  NSXMLElement *projVersion = [[NSXMLElement alloc] initWithName: @"VCProjectVersion"];
  NSXMLElement *keyword = [[NSXMLElement alloc] initWithName: @"Keyword"];
  NSXMLElement *projGuid = [[NSXMLElement alloc] initWithName: @"ProjectGuid"];
  NSXMLElement *rootNamespace = [[NSXMLElement alloc] initWithName: @"RootNamespace"];
  NSXMLElement *windowsTarget = [[NSXMLElement alloc] initWithName: @"WindowsTargetPlatformVersion"];

  [projVersion setStringValue: @"16.0" resolvingEntities: NO];
  [keyword setStringValue: _name resolvingEntities: NO];
  [projGuid setStringValue: [NSString stringWithFormat: @"{%@}", [_uuid UUIDString]] resolvingEntities: NO];
  [rootNamespace setStringValue: _name resolvingEntities: NO];
  [windowsTarget setStringValue: @"10.0" resolvingEntities: NO];
  
  // Project Configuration
  NSXMLNode *attr = [NSXMLNode attributeWithName: @"Label" stringValue: @"Globals"];
  NSXMLElement *propertyGroup = [[NSXMLElement alloc] initWithName: @"PropertyGroup"];
  [propertyGroup addAttribute: attr];
  [propertyGroup addChild: projVersion];
  [propertyGroup addChild: keyword];
  [propertyGroup addChild: projGuid];
  [propertyGroup addChild: rootNamespace];
  [propertyGroup addChild: windowsTarget];

  // Config & platform
  NSXMLElement *config = [[NSXMLElement alloc] initWithName: @"Configuration"];  
  NSXMLElement *platform = [[NSXMLElement alloc] initWithName: @"Platform"];
  [config setStringValue: @"Release" resolvingEntities: NO];
  [platform setStringValue: @"x64" resolvingEntities: NO];
  
  // Project Configuration
  NSXMLElement *projectConfiguration = [[NSXMLElement alloc] initWithName: @"ProjectConfiguration"];
  attr = [NSXMLNode attributeWithName: @"Include" stringValue: @"Release|x64"];
  [projectConfiguration addAttribute: attr];
  [projectConfiguration addChild: config];
  [projectConfiguration addChild: platform];

  // Item Group
  NSXMLElement *itemGroup = [[NSXMLElement alloc] initWithName: @"ItemGroup"];
  attr = [NSXMLNode attributeWithName: @"Label" stringValue: @"ProjectConfigurations"];
  [itemGroup addAttribute: attr];
  [itemGroup addChild: projectConfiguration];
  
  // Root
  NSXMLElement *rootElement = [[NSXMLElement alloc] initWithName: @"Project"];
  attr = [NSXMLNode attributeWithName: @"DefaultTargets" stringValue: @"Build"];
  [rootElement addAttribute: attr];
  attr = [NSXMLNode attributeWithName: @"xmlns" stringValue: url];
  [rootElement addAttribute: attr];
  [rootElement addChild: itemGroup];
  [rootElement addChild: propertyGroup];
  
  // Root element for document...
  [projectXml setRootElement: rootElement];

  NSData *data = [projectXml XMLDataWithOptions: NSXMLNodePrettyPrint];
  NSString *xmlString = [[NSString alloc] initWithData: data encoding: NSUTF8StringEncoding];
  return xmlString;
}

- (NSString *) string
{
  NSString *result = [self build];
  return result;
}

@end
