/*
   Project: Ycode

   Copyright (C) 2025 Free Software Foundation

   Author: Gregory Casamento

   Created: 2025-01-15

   This application is free software; you can redistribute it and/or
   modify it under the terms of the GNU General Public
   License as published by the Free Software Foundation; either
   version 2 of the License, or (at your option) any later version.

   This application is distributed in the hope that it will be useful,
   but WITHOUT ANY WARRANTY; without even the implied warranty of
   MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
   Library General Public License for more details.

   You should have received a copy of the GNU General Public
   License along with this library; if not, write to the Free
   Software Foundation, Inc., 59 Temple Place, Suite 330, Boston, MA 02111 USA.
*/

#import "YCodeProject.h"
#import "YCodeWindowController.h"
#import "YCodeProjectNavigatorController.h"
#import "YCodeEditorController.h"
#import "YCodeBuildSystem.h"
#import <XCode/PBXProject.h>
#import <XCode/PBXContainer.h>
#import <XCode/PBXFileReference.h>
#import <XCode/PBXTarget.h>
#import <XCode/PBXGroup.h>
#import <XCode/PBXBuildFile.h>
#import <XCode/PBXSourcesBuildPhase.h>
#import <XCode/PBXResourcesBuildPhase.h>
#import <XCode/PBXHeadersBuildPhase.h>
#import <XCode/PBXFrameworksBuildPhase.h>
#import <XCode/PBXNativeTarget.h>
#import <XCode/PBXCoder.h>
#import <XCode/XCBuildConfiguration.h>
#import <XCode/XCConfigurationList.h>

/* Resolve group-relative references without depending on the visible outline. */
static NSString *YCodeReferencePath(id object, NSString *parent, NSString *root)
{
    NSString *path = [object path];
    NSString *tree = [object sourceTree];
    if ([path isAbsolutePath]) return [path stringByStandardizingPath];
    NSString *base = nil;
    if (![tree length] || [tree isEqual:@"<group>"]) base = parent;
    else if ([tree isEqual:@"SOURCE_ROOT"]) base = root;
    if (!base) return nil;
    return [path length] ? [[base stringByAppendingPathComponent:path] stringByStandardizingPath] : base;
}

static void YCodeCollectFileEntries(PBXGroup *group, NSString *parent, NSString *root, NSMutableArray *entries)
{
    NSString *directory = YCodeReferencePath(group, parent, root);
    {
      NSEnumerator *childEnumerator = [[group children] objectEnumerator];
      id child;
      while ((child = [childEnumerator nextObject]) != nil)
        {
          if ([child isKindOfClass:[PBXGroup class]])
              YCodeCollectFileEntries(child, directory, root, entries);
          else if ([child isKindOfClass:[PBXFileReference class]]) {
              NSMutableDictionary *entry = [NSMutableDictionary dictionaryWithObjectsAndKeys:
                  child, @"file", group, @"group", nil];
              NSString *path = YCodeReferencePath(child, directory, root);
              if (path) [entry setObject:path forKey:@"path"];
              [entries addObject:entry];
          }
        }
    }
}

static NSMutableDictionary *
YCodeBuildSettingsForProduct(NSString *productName)
{
    NSMutableDictionary *settings = [NSMutableDictionary dictionary];

    [settings setObject:@"macosx" forKey:@"SDKROOT"];
    [settings setObject:@"$(inherited)" forKey:@"HEADER_SEARCH_PATHS"];
    [settings setObject:@"$(inherited)" forKey:@"LIBRARY_SEARCH_PATHS"];
    [settings setObject:productName forKey:@"PRODUCT_NAME"];
    [settings setObject:@"YES" forKey:@"GCC_ENABLE_OBJC_EXCEPTIONS"];

    return settings;
}

static XCConfigurationList *
YCodeConfigurationList(NSString *productName)
{
    XCBuildConfiguration *debug = nil;
    XCBuildConfiguration *release = nil;
    XCConfigurationList *list = nil;
    NSMutableDictionary *debugSettings = nil;
    NSMutableDictionary *releaseSettings = nil;
    NSMutableArray *configs = nil;

    debugSettings = YCodeBuildSettingsForProduct(productName);
    [debugSettings setObject:@"YES" forKey:@"GCC_GENERATE_DEBUGGING_SYMBOLS"];
    [debugSettings setObject:@"0" forKey:@"GCC_OPTIMIZATION_LEVEL"];

    releaseSettings = [NSMutableDictionary dictionaryWithDictionary:
        YCodeBuildSettingsForProduct(productName)];
    [releaseSettings setObject:@"NO" forKey:@"GCC_GENERATE_DEBUGGING_SYMBOLS"];
    [releaseSettings setObject:@"s" forKey:@"GCC_OPTIMIZATION_LEVEL"];

    debug = AUTORELEASE([[XCBuildConfiguration alloc]
        initWithName:@"Debug"
        buildSettings:debugSettings]);
    release = AUTORELEASE([[XCBuildConfiguration alloc]
        initWithName:@"Release"
        buildSettings:releaseSettings]);
    configs = [NSMutableArray arrayWithObjects:debug, release, nil];

    list = AUTORELEASE([[XCConfigurationList alloc] initWithConfigurations:configs]);
    [list setDefaultConfigurationName:@"Debug"];
    [list setDefaultConfigurationIsVisible:@"0"];

    return list;
}

static PBXBuildFile *
YCodeBuildFile(PBXFileReference *fileRef)
{
    PBXBuildFile *buildFile = AUTORELEASE([[PBXBuildFile alloc] init]);
    [buildFile setFileRef:fileRef];
    return buildFile;
}

static PBXFileReference *
YCodeFileReference(NSString *path)
{
    PBXFileReference *fileRef = AUTORELEASE([[PBXFileReference alloc]
        initWithPath:path]);
    [fileRef setSourceTree:@"<group>"];
    return fileRef;
}

static PBXBuildPhase *
YCodeBuildPhase(Class phaseClass, NSMutableArray *files, PBXNativeTarget *target,
    NSString *name)
{
    PBXBuildPhase *phase = AUTORELEASE([[phaseClass alloc]
        initWithFiles:files
        buildActionMask:@"2147483647"
        runOnlyForDeployment:@"0"
        target:target
        name:name]);
    return phase;
}

static NSString *
YCodeProjectFilePathForPath(NSString *path)
{
    if (path == nil || [path length] == 0) {
        return nil;
    }

    if ([[path pathExtension] isEqualToString:@"pbxproj"]) {
        return path;
    }

    if ([[path pathExtension] isEqualToString:@"pcproj"]) {
        return [[[path stringByDeletingPathExtension] stringByAppendingPathExtension:@"xcodeproj"]
                stringByAppendingPathComponent:@"project.pbxproj"];
    }

    if ([[path pathExtension] isEqualToString:@"xcodeproj"]) {
        return [path stringByAppendingPathComponent:@"project.pbxproj"];
    }

    return [[path stringByAppendingPathExtension:@"xcodeproj"]
        stringByAppendingPathComponent:@"project.pbxproj"];
}

static NSString *YCodeRelativeFilePath(NSString *path, NSString *directory)
{
    NSArray *fileParts = [[path stringByStandardizingPath] pathComponents];
    NSArray *baseParts = [[directory stringByStandardizingPath] pathComponents];
    NSUInteger common = 0;
    while (common < [fileParts count] && common < [baseParts count]
        && [[fileParts objectAtIndex:common] isEqual:[baseParts objectAtIndex:common]]) common++;
    if (common == 0) return path;
    NSMutableArray *parts = [NSMutableArray array];
    NSUInteger i;
    for (i = common; i < [baseParts count]; i++) [parts addObject:@".."];
    for (i = common; i < [fileParts count]; i++) [parts addObject:[fileParts objectAtIndex:i]];
    return [parts count] ? [NSString pathWithComponents:parts] : @".";
}

static void YCodeAppendProjectFile(NSMutableDictionary *dictionary, NSString *key, NSString *file)
{
    NSMutableArray *files = [dictionary objectForKey:key];
    if ([file length] && ![files containsObject:file]) [files addObject:file];
}

static NSArray *YCodeSettingWords(id value)
{
    if ([value isKindOfClass:[NSArray class]]) return value;
    if (![value isKindOfClass:[NSString class]]) return [NSArray array];
    NSMutableArray *words = [NSMutableArray array];
    NSMutableString *word = [NSMutableString string];
    unichar quote = 0;
    BOOL escaped = NO, started = NO;
    NSUInteger i;
    for (i = 0; i < [value length]; i++) {
        unichar c = [value characterAtIndex:i];
        if (escaped) { [word appendFormat:@"%C", c]; escaped = NO; started = YES; }
        else if (c == '\\' && quote != '\'') { escaped = YES; started = YES; }
        else if (quote) { if (c == quote) quote = 0; else [word appendFormat:@"%C", c]; }
        else if (c == '\'' || c == '"') { quote = c; started = YES; }
        else if ([[NSCharacterSet whitespaceAndNewlineCharacterSet] characterIsMember:c]) {
            if (started) { [words addObject:[NSString stringWithString:word]]; [word setString:@""]; started = NO; }
        } else { [word appendFormat:@"%C", c]; started = YES; }
    }
    if (escaped) [word appendString:@"\\"];
    if (started) [words addObject:word];
    return words;
}

static NSString *YCodeQuotedFlags(NSArray *words)
{
    NSMutableArray *quoted = [NSMutableArray array];
    {
      NSEnumerator *wordEnumerator = [words objectEnumerator];
      NSString *word;
      while ((word = [wordEnumerator nextObject]) != nil)
        {
          NSString *escaped = [word stringByReplacingOccurrencesOfString:@"\\" withString:@"\\\\"];
          escaped = [escaped stringByReplacingOccurrencesOfString:@"\"" withString:@"\\\""];
          [quoted addObject:[NSString stringWithFormat:@"\"%@\"", escaped]];
        }
    }
    return [quoted componentsJoinedByString:@" "];
}

static NSString *
YCodeProjectPackagePathForPath(NSString *path)
{
    if (path == nil || [path length] == 0) {
        return nil;
    }

    if ([[path pathExtension] isEqualToString:@"pbxproj"]) {
        return [path stringByDeletingLastPathComponent];
    }

    if ([[path pathExtension] isEqualToString:@"pcproj"]) {
        return [[path stringByDeletingPathExtension] stringByAppendingPathExtension:@"xcodeproj"];
    }

    if ([[path pathExtension] isEqualToString:@"xcodeproj"]) {
        return path;
    }

    return [path stringByAppendingPathExtension:@"xcodeproj"];
}

@implementation YCodeProject

+ (NSArray *)readableTypes
{
    return [NSArray arrayWithObjects:@"YCodeXcodeProjectType",
        @"YCodeProjectCenterProjectType", @"xcodeproj", @"pcproj", nil];
}

+ (NSArray *)writableTypes
{
    return [NSArray arrayWithObjects:@"YCodeXcodeProjectType",
        @"xcodeproj", nil];
}

+ (BOOL)isNativeType:(NSString *)type
{
    return ([type isEqualToString:@"YCodeXcodeProjectType"] ||
            [type isEqualToString:@"xcodeproj"]);
}

#pragma mark - Class Methods

+ (YCodeProject *)createNewProjectAtPath:(NSString *)path name:(NSString *)name type:(NSString *)type
{
    NSFileManager *fileManager = [NSFileManager defaultManager];
    
    // Create project directory if it doesn't exist
    if (![fileManager fileExistsAtPath:path]) {
        NSError *error;
        if (![fileManager createDirectoryAtPath:path withIntermediateDirectories:YES attributes:nil error:&error]) {
            NSLog(@"Failed to create project directory: %@", [error localizedDescription]);
            return nil;
        }
    }
    
    // Create project instance
    YCodeProject *project = [[YCodeProject alloc] init];
    [project setProjectPath:path];
    
    if ([type isEqualToString:@"Xcode"]) {
        [project createXcodeProjectWithName:name atPath:path];
    } else {
        [project createProjectCenterProjectWithName:name atPath:path];
    }
    
    return AUTORELEASE(project);
}

- (BOOL)createXcodeProjectWithName:(NSString *)name atPath:(NSString *)path
{
    NSString *projectFile = [NSString stringWithFormat:@"%@.xcodeproj", name];
    NSString *projectPath = [path stringByAppendingPathComponent:projectFile];
    NSString *projectPBXPath = [projectPath stringByAppendingPathComponent:@"project.pbxproj"];
    NSString *productPath = [NSString stringWithFormat:@"%@.app", name];
    PBXFileReference *mainFile = nil;
    PBXFileReference *productReference = nil;
    PBXBuildFile *mainBuildFile = nil;
    PBXSourcesBuildPhase *sourcesPhase = nil;
    PBXResourcesBuildPhase *resourcesPhase = nil;
    PBXFrameworksBuildPhase *frameworksPhase = nil;
    NSMutableArray *mainChildren = nil;
    NSMutableArray *productChildren = nil;
    NSMutableArray *targets = nil;
    NSMutableArray *buildPhases = nil;
    
    NSFileManager *fileManager = [NSFileManager defaultManager];
    if (![fileManager createDirectoryAtPath:projectPath withIntermediateDirectories:YES attributes:nil error:nil]) {
        return NO;
    }
    
    // Create project structure
    PBXProject *pbxProject = [[PBXProject alloc] init];
    [pbxProject setProjectDirPath:@""];
    [pbxProject setProjectRoot:@""];
    [pbxProject setCompatibilityVersion:@"Xcode 15.0"];
    [pbxProject setDevelopmentRegion:@"en"];
    [pbxProject setKnownRegions:[NSMutableArray arrayWithObjects:@"en", @"Base", nil]];
    [pbxProject setBuildConfigurationList:YCodeConfigurationList(name)];
    
    // Create main group
    PBXGroup *mainGroup = [[PBXGroup alloc] init];
    [mainGroup setName:name];
    [mainGroup setSourceTree:@"<group>"];
    [pbxProject setMainGroup:mainGroup];

    PBXGroup *productsGroup = [[PBXGroup alloc] init];
    [productsGroup setName:@"Products"];
    [productsGroup setSourceTree:@"<group>"];
    [pbxProject setProductRefGroup:productsGroup];
    
    // Create a simple target
    PBXNativeTarget *target = [[PBXNativeTarget alloc] init];
    [target setName:name];
    [target setProductName:name];
    [target setProductType:@"com.apple.product-type.application"];
    [target setBuildConfigurationList:YCodeConfigurationList(name)];
    [target setDependencies:[NSMutableArray array]];
    [target setBuildRules:[NSMutableArray array]];

    productReference = YCodeFileReference(productPath);
    [productReference setExplicitFileType:@"wrapper.application"];
    [productReference setSourceTree:@"BUILT_PRODUCTS_DIR"];
    [target setProductReference:productReference];

    mainFile = YCodeFileReference(@"main.m");
    mainBuildFile = YCodeBuildFile(mainFile);

    sourcesPhase = (PBXSourcesBuildPhase *)YCodeBuildPhase([PBXSourcesBuildPhase class],
        [NSMutableArray arrayWithObject:mainBuildFile], target, @"Sources");
    resourcesPhase = (PBXResourcesBuildPhase *)YCodeBuildPhase([PBXResourcesBuildPhase class],
        [NSMutableArray array], target, @"Resources");
    frameworksPhase = (PBXFrameworksBuildPhase *)YCodeBuildPhase([PBXFrameworksBuildPhase class],
        [NSMutableArray array], target, @"Frameworks");

    buildPhases = [NSMutableArray arrayWithObjects:
        sourcesPhase, resourcesPhase, frameworksPhase, nil];
    [target setBuildPhases:buildPhases];

    mainChildren = [NSMutableArray arrayWithObjects:mainFile, productsGroup, nil];
    productChildren = [NSMutableArray arrayWithObject:productReference];
    [mainGroup setChildren:mainChildren];
    [productsGroup setChildren:productChildren];

    targets = [NSMutableArray arrayWithObject:target];
    [pbxProject setTargets:targets];
    
    // Create container
    PBXContainer *container = [[PBXContainer alloc] initWithRootObject:pbxProject];
    [container setFilename:projectPBXPath];
    [container setParameter:projectPath];
    [pbxProject setContainer:container];
    
    [self setProject:pbxProject];
    [self setContainer:container];
    
    // Create basic main.m file
    [self createMainFileAtPath:path];
    [self saveProjectToPath:projectPath];
    
    RELEASE(pbxProject);
    RELEASE(mainGroup);
    RELEASE(productsGroup);
    RELEASE(target);
    RELEASE(container);
    
    return YES;
}

- (BOOL)createProjectCenterProjectWithName:(NSString *)name atPath:(NSString *)path
{
    // Create ProjectCenter project file
    NSString *projectFile = [NSString stringWithFormat:@"%@.pcproj", name];
    NSString *projectPath = [path stringByAppendingPathComponent:projectFile];
    NSString *projectInfoPath = [projectPath stringByAppendingPathComponent:@"PC.project"];
    NSFileManager *fileManager = [NSFileManager defaultManager];
    
    NSMutableDictionary *projectDict = [NSMutableDictionary dictionary];
    [projectDict setObject:name forKey:@"PROJECT_NAME"];
    [projectDict setObject:@"Application" forKey:@"PROJECT_TYPE"];
    [projectDict setObject:name forKey:@"PRINCIPAL_CLASS"];
    [projectDict setObject:[NSArray array] forKey:@"CLASS_FILES"];
    [projectDict setObject:[NSArray array] forKey:@"HEADER_FILES"];
    [projectDict setObject:[NSArray array] forKey:@"LOCALIZED_RESOURCES"];
    [projectDict setObject:[NSArray array] forKey:@"LIBRARIES"];
    
    if (![fileManager createDirectoryAtPath:projectPath
                withIntermediateDirectories:YES
                                 attributes:nil
                                      error:nil]) {
        return NO;
    }

    BOOL success = [projectDict writeToFile:projectInfoPath atomically:YES];
    
    if (success) {
        // Load the project we just created
        [self convertProjectCenterProject:projectDict fromPath:projectPath];
        
        // Create basic main.m file
        [self createMainFileAtPath:path];
        
        // Create basic GNUmakefile
        [self createGNUMakefileAtPath:path withName:name];
    }
    
    return success;
}

- (void)createMainFileAtPath:(NSString *)path
{
    NSString *mainContent = @"#import <Foundation/Foundation.h>\n"
                           @"#import <AppKit/AppKit.h>\n\n"
                           @"int main(int argc, const char *argv[])\n"
                           @"{\n"
                           @"    return NSApplicationMain(argc, argv);\n"
                           @"}\n";
    
    NSString *mainPath = [path stringByAppendingPathComponent:@"main.m"];
    [mainContent writeToFile:mainPath atomically:YES encoding:NSUTF8StringEncoding error:nil];
}

- (void)createGNUMakefileAtPath:(NSString *)path withName:(NSString *)name
{
    NSString *makefileContent = [NSString stringWithFormat:
        @"include $(GNUSTEP_MAKEFILES)/common.make\n\n"
        @"APP_NAME = %@\n"
        @"%@_OBJC_FILES = main.m\n"
        @"%@_RESOURCE_FILES = \n\n"
        @"include $(GNUSTEP_MAKEFILES)/application.make\n",
        name, name, name];
    
    NSString *makefilePath = [path stringByAppendingPathComponent:@"GNUmakefile"];
    [makefileContent writeToFile:makefilePath atomically:YES encoding:NSUTF8StringEncoding error:nil];
}

- (PBXContainer *)convertProjectCenterProject:(NSDictionary *)projectDict fromPath:(NSString *)path
{
    PBXContainer *container = [self loadProjectCenterProject:projectDict fromPath:path];

    if (container != nil) {
        [self setContainer:container];
        [self setProject:[container rootObject]];
        [self setProjectPath:path];
    }

    return container;
}

- (PBXContainer *)loadProjectCenterProject:(NSDictionary *)projectDict fromPath:(NSString *)path
{
    if (![projectDict isKindOfClass:[NSDictionary class]]) return nil;
    NSMutableDictionary *normalized = [NSMutableDictionary dictionaryWithDictionary:projectDict];
    NSArray *listKeys = [NSArray arrayWithObjects:@"CLASS_FILES", @"OTHER_SOURCES", @"HEADER_FILES",
        @"PUBLIC_HEADERS", @"IMAGES", @"INTERFACES", @"LOCALIZED_RESOURCES", @"OTHER_RESOURCES",
        @"SUPPORTING_FILES", @"DOCU_FILES", @"OTHER_FILES", @"NON_PROJECT_FILES", @"FRAMEWORKS",
        @"LIBRARIES", @"SEARCH_HEADER_DIRS", @"SEARCH_LIB_DIRS", @"SUBPROJECTS", nil];
    {
      NSEnumerator *keyEnumerator = [listKeys objectEnumerator];
      NSString *key;
      while ((key = [keyEnumerator nextObject]) != nil)
        {
          id value = [normalized objectForKey:key];
          if ([value isKindOfClass:[NSString class]])
              [normalized setObject:[value length] ? [NSArray arrayWithObject:value] : [NSArray array] forKey:key];
        }
    }
    NSString *legacyType = [normalized objectForKey:@"PROJECT_TYPE"];
    if ([legacyType isKindOfClass:[NSString class]]) {
        NSDictionary *aliases = [NSDictionary dictionaryWithObjectsAndKeys:
            @"Application", @"PCAppProject", @"Tool", @"PCToolProject",
            @"Library", @"PCLibProject", @"Framework", @"PCFrameworkProject",
            @"Bundle", @"PCBundleProject", nil];
        if ([aliases objectForKey:legacyType])
            [normalized setObject:[aliases objectForKey:legacyType] forKey:@"PROJECT_TYPE"];
    }
    NSString *root = [path stringByDeletingLastPathComponent];
    id localized = [normalized objectForKey:@"LOCALIZED_RESOURCES"];
    NSString *language = [normalized objectForKey:@"LANGUAGE"];
    if (![language isKindOfClass:[NSString class]] || ![language length]) language = @"English";
    {
      NSEnumerator *keyEnumerator = [[NSArray arrayWithObjects:@"IMAGES", @"INTERFACES", @"OTHER_RESOURCES", @"LOCALIZED_RESOURCES", nil] objectEnumerator];
      NSString *key;
      while ((key = [keyEnumerator nextObject]) != nil)
        {
          id entries = [normalized objectForKey:key];
          if (![entries isKindOfClass:[NSArray class]]) continue;
          NSMutableArray *resolved = [NSMutableArray array];
          {
            NSEnumerator *entryEnumerator = [entries objectEnumerator];
            id entry;
            while ((entry = [entryEnumerator nextObject]) != nil)
              {
                if (![entry isKindOfClass:[NSString class]] || ![entry length]) return nil;
                NSString *file = entry;
                NSString *firstComponent = [[file pathComponents] count] ? [[file pathComponents] objectAtIndex:0] : @"";
                BOOL explicitResourcePath = [firstComponent isEqual:@"Resources"] || [[firstComponent pathExtension] isEqual:@"lproj"];
                if (![file isAbsolutePath] && !explicitResourcePath) {
                    BOOL isLocalized = [localized isKindOfClass:[NSArray class]] && [localized containsObject:entry];
                    NSString *base = isLocalized ? [language stringByAppendingPathExtension:@"lproj"] : @"Resources";
                    NSString *candidate = [base stringByAppendingPathComponent:file];
                    if ([[NSFileManager defaultManager] fileExistsAtPath:[root stringByAppendingPathComponent:candidate]]
                        || ![[NSFileManager defaultManager] fileExistsAtPath:[root stringByAppendingPathComponent:file]])
                        file = [candidate stringByStandardizingPath];
                }
                [resolved addObject:file];
              }
          }
          [normalized setObject:resolved forKey:key];
        }
    }
    PBXContainer *container = [self convertProjectCenterProject:normalized];
    NSString *projectPath = YCodeProjectPackagePathForPath(path);
    [container setFilename:[projectPath stringByAppendingPathComponent:@"project.pbxproj"]];
    [container setParameter:projectPath];

    return container;
}

- (id)init
{
    self = [super init];
    if (self) {
        _settings = [[NSMutableDictionary alloc] init];
        _fileWatchers = [[NSMutableDictionary alloc] init];
        
        // Initialize controllers
        _navigatorController = [[YCodeProjectNavigatorController alloc] init];
        [_navigatorController setProject:self];
        
        _editorController = [[YCodeEditorController alloc] init];
        [_editorController setProject:self];
        
        _buildSystem = [[YCodeBuildSystem alloc] initWithProject:self];
    }
    return self;
}

- (void)dealloc
{
    [self stopWatchingFiles];
    RELEASE(_project);
    RELEASE(_container);
    RELEASE(_projectPath);
    RELEASE(_navigatorController);
    RELEASE(_editorController);
    RELEASE(_buildSystem);
    RELEASE(_settings);
    RELEASE(_fileWatchers);
    [super dealloc];
}

#pragma mark - NSDocument overrides

- (void)close
{
    [_buildSystem stop];
    [_buildSystem setDelegate:nil];
    [super close];
}


- (NSString *)windowNibName
{
    return nil;
}

- (void)makeWindowControllers
{
    YCodeWindowController *controller = nil;

    controller = [[YCodeWindowController alloc] init];
    [controller setProject: self];
    [self addWindowController:controller];
    RELEASE(controller);
}

- (BOOL)readFromURL:(NSURL *)url ofType:(NSString *)typeName error:(NSError **)outError
{
    NSString *path = [url path];
    BOOL success = NO;

    if (path == nil || [path length] == 0) {
        if (outError) {
            NSDictionary *userInfo = [NSDictionary dictionaryWithObject:@"The project URL does not contain a valid file path"
                                                                 forKey:NSLocalizedDescriptionKey];
            *outError = [NSError errorWithDomain:NSCocoaErrorDomain
                                            code:NSFileReadInvalidFileNameError
                                        userInfo:userInfo];
        }
        return NO;
    }
    
    if ([[path pathExtension] isEqualToString:@"xcodeproj"]) {
        success = [self loadXcodeProjectAtPath:path];
    } else if ([[path pathExtension] isEqualToString:@"pcproj"]) {
        success = [self loadProjectCenterProjectAtPath:path];
    } else {
        if (outError) {
            NSDictionary *userInfo = [NSDictionary dictionaryWithObject:@"Unsupported project format"
                                                                 forKey:NSLocalizedDescriptionKey];
            *outError = [NSError errorWithDomain:NSCocoaErrorDomain
                                            code:NSFileReadUnsupportedSchemeError
                                        userInfo:userInfo];
        }
        return NO;
    }

    if (success) {
        [self setFileURL:url];
        return YES;
    }

    if (outError) {
        NSDictionary *userInfo = [NSDictionary dictionaryWithObject:@"The selected project could not be opened"
                                                             forKey:NSLocalizedDescriptionKey];
        *outError = [NSError errorWithDomain:NSCocoaErrorDomain 
                                        code:NSFileReadUnknownError
                                    userInfo:userInfo];
    }
    return NO;
}

- (BOOL)writeToURL:(NSURL *)url ofType:(NSString *)typeName error:(NSError **)outError
{
    NSString *path = [url path];

    if (path == nil || [path length] == 0) {
        if (outError) {
            NSDictionary *userInfo = [NSDictionary dictionaryWithObject:@"The project URL does not contain a valid file path"
                                                                 forKey:NSLocalizedDescriptionKey];
            *outError = [NSError errorWithDomain:NSCocoaErrorDomain
                                            code:NSFileWriteInvalidFileNameError
                                        userInfo:userInfo];
        }
        return NO;
    }

    if (_container == nil) {
        if (outError) {
            NSDictionary *userInfo = [NSDictionary dictionaryWithObject:@"No project container to save"
                                                                 forKey:NSLocalizedDescriptionKey];
            *outError = [NSError errorWithDomain:NSCocoaErrorDomain
                                            code:NSFileWriteUnknownError
                                        userInfo:userInfo];
        }
        return NO;
    }
    
    if (![self saveProjectToPath:path]) {
        if (outError) {
            NSDictionary *userInfo = [NSDictionary dictionaryWithObject:@"The project could not be saved"
                                                                 forKey:NSLocalizedDescriptionKey];
            *outError = [NSError errorWithDomain:NSCocoaErrorDomain
                                            code:NSFileWriteUnknownError
                                        userInfo:userInfo];
        }
        return NO;
    }

    return YES;
}

#pragma mark - Project Loading

- (BOOL)loadXcodeProjectAtPath:(NSString *)path
{
    PBXCoder *coder = nil;
    BOOL success = NO;

    if (path == nil || [path length] == 0) {
        return NO;
    }

    @try {
        NSString *projectFile = YCodeProjectFilePathForPath(path);
        if (projectFile == nil) {
            return NO;
        }

        coder = [[PBXCoder alloc] initWithContentsOfFile:projectFile];
        if (coder) {
            PBXContainer *container = [coder unarchive];
            PBXProject *project = [container rootObject];
            if ([project isKindOfClass:[PBXProject class]] &&
                [[project mainGroup] isKindOfClass:[PBXGroup class]]) {
                [container setFilename:projectFile];
                [container setParameter:YCodeProjectPackagePathForPath(path)];
                [project setContainer:container];
                [self setContainer:container];
                [self setProjectPath:YCodeProjectPackagePathForPath(path)];
                [self setProject:project];
                [_settings removeObjectForKey:@"ProjectCenterMetadata"];
                
                // Start watching files
                [self startWatchingFiles];
                
                success = YES;
            }
        }
    }
    @catch (NSException *exception) {
        NSLog(@"Error loading Xcode project: %@", [exception reason]);
    }
    @finally {
        RELEASE(coder);
    }
    return success;
}

- (BOOL)loadProjectCenterProjectAtPath:(NSString *)path
{
    if (path == nil || [path length] == 0) {
        return NO;
    }

    @try {
        BOOL directory = NO;
        [[NSFileManager defaultManager] fileExistsAtPath:path isDirectory:&directory];
        NSString *projectFile = directory ? [path stringByAppendingPathComponent:@"PC.project"] : path;
        NSDictionary *projectDict = [NSDictionary dictionaryWithContentsOfFile:projectFile];
        if (projectDict) {
            PBXContainer *container = [self loadProjectCenterProject:projectDict fromPath:path];
            if (container) {
                [self setContainer:container];
                [self setProjectPath:path];
                [self setProject:[container rootObject]];
                [_settings setObject:projectDict forKey:@"ProjectCenterMetadata"];
                [self startWatchingFiles];
                return YES;
            }
        }
    }
    @catch (NSException *exception) {
        NSLog(@"Error importing ProjectCenter project: %@", [exception reason]);
    }
    return NO;
}

- (PBXContainer *)convertProjectCenterProject:(NSDictionary *)projectDict
{
    if (![projectDict isKindOfClass:[NSDictionary class]]) return nil;
    NSString *projectName = [projectDict objectForKey:@"PROJECT_NAME"];
    NSString *projectType = [projectDict objectForKey:@"PROJECT_TYPE"];
    NSDictionary *productTypes = [NSDictionary dictionaryWithObjectsAndKeys:
        @"application", @"Application", @"tool", @"Tool",
        @"library.dynamic", @"Library", @"library.static", @"StaticLibrary",
        @"framework", @"Framework", @"bundle", @"Bundle", nil];
    if (![projectName isKindOfClass:[NSString class]] || ![projectName length]
        || ![projectType isKindOfClass:[NSString class]] || ![productTypes objectForKey:projectType])
        return nil;
    NSArray *fileKeys = [NSArray arrayWithObjects:@"CLASS_FILES", @"OTHER_SOURCES",
        @"HEADER_FILES", @"PUBLIC_HEADERS", @"IMAGES", @"INTERFACES", @"LOCALIZED_RESOURCES",
        @"OTHER_RESOURCES", @"SUPPORTING_FILES", @"DOCU_FILES", @"FRAMEWORKS",
        @"LIBRARIES", @"SEARCH_HEADER_DIRS", @"SEARCH_LIB_DIRS", @"SUBPROJECTS", @"OTHER_FILES", @"NON_PROJECT_FILES", nil];
    {
      NSEnumerator *keyEnumerator = [fileKeys objectEnumerator];
      NSString *key;
      while ((key = [keyEnumerator nextObject]) != nil)
        {
          id values = [projectDict objectForKey:key];
          if (values && ![values isKindOfClass:[NSArray class]]) return nil;
          {
            NSEnumerator *valueEnumerator = [values objectEnumerator];
            id value;
            while ((value = [valueEnumerator nextObject]) != nil)
              if (![value isKindOfClass:[NSString class]] || ![value length]) return nil;
          }
        }
    }
    {
      NSEnumerator *keyEnumerator = [[NSArray arrayWithObjects:@"COMPILEROPTIONS", @"CPPOPTIONS",
        @"OBJC_COMPILEROPTIONS", @"LINKEROPTIONS", @"BUNDLE_IDENTIFIER", nil] objectEnumerator];
      NSString *key;
      while ((key = [keyEnumerator nextObject]) != nil)
        {
          id value = [projectDict objectForKey:key];
          if (value && ![value isKindOfClass:[NSString class]]) return nil;
        }
    }
    PBXNativeTarget *target = nil;
    PBXGroup *mainGroup = nil;
    PBXGroup *productsGroup = nil;
    PBXFileReference *productReference = nil;
    NSMutableArray *children = nil;
    NSMutableArray *productChildren = nil;
    NSMutableArray *targets = nil;
    NSMutableArray *buildPhases = nil;
    PBXSourcesBuildPhase *sourcesPhase = nil;
    PBXResourcesBuildPhase *resourcesPhase = nil;
    PBXFrameworksBuildPhase *frameworksPhase = nil;
    NSString *productPath = nil;

    // Create project structure
    PBXProject *project = [[PBXProject alloc] init];
    [project setProjectDirPath:@""];
    [project setProjectRoot:@""];
    [project setCompatibilityVersion:@"Xcode 15.0"];
    [project setDevelopmentRegion:@"en"];
    [project setKnownRegions:[NSMutableArray arrayWithObjects:@"en", @"Base", nil]];
    [project setBuildConfigurationList:YCodeConfigurationList(projectName)];
    
    // Create main group
    mainGroup = [[PBXGroup alloc] init];
    [mainGroup setName:projectName];
    [mainGroup setSourceTree:@"<group>"];
    [project setMainGroup:mainGroup];

    productsGroup = [[PBXGroup alloc] init];
    [productsGroup setName:@"Products"];
    [productsGroup setSourceTree:@"<group>"];
    [project setProductRefGroup:productsGroup];

    target = [[PBXNativeTarget alloc] init];
    [target setName:projectName];
    [target setProductName:projectName];
    [target setProductType:[@"com.apple.product-type." stringByAppendingString:
        [productTypes objectForKey:projectType]]];
    [target setBuildConfigurationList:YCodeConfigurationList(projectName)];
    [target setDependencies:[NSMutableArray array]];
    [target setBuildRules:[NSMutableArray array]];

    productPath = [NSString stringWithFormat:@"%@.app", projectName];
    NSString *productFileType = @"wrapper.application";
    if ([projectType isEqual:@"Tool"]) {
        productPath = projectName;
        productFileType = @"compiled.mach-o.executable";
    } else if ([projectType isEqual:@"Framework"] || [projectType isEqual:@"Bundle"]) {
        NSString *extension = [projectType lowercaseString];
        productPath = [projectName stringByAppendingPathExtension:extension];
        productFileType = [@"wrapper." stringByAppendingString:extension];
    } else if ([projectType isEqual:@"Library"] || [projectType isEqual:@"StaticLibrary"]) {
        BOOL isStatic = [projectType isEqual:@"StaticLibrary"];
        productPath = [NSString stringWithFormat:@"lib%@.%@", projectName, isStatic ? @"a" : @"dylib"];
        productFileType = isStatic ? @"archive.ar" : @"compiled.mach-o.dylib";
    }
    productReference = YCodeFileReference(productPath);
    [productReference setExplicitFileType:productFileType];
    [productReference setSourceTree:@"BUILT_PRODUCTS_DIR"];
    [target setProductReference:productReference];

    sourcesPhase = (PBXSourcesBuildPhase *)YCodeBuildPhase([PBXSourcesBuildPhase class],
        [NSMutableArray array], target, @"Sources");
    resourcesPhase = (PBXResourcesBuildPhase *)YCodeBuildPhase([PBXResourcesBuildPhase class],
        [NSMutableArray array], target, @"Resources");
    frameworksPhase = (PBXFrameworksBuildPhase *)YCodeBuildPhase([PBXFrameworksBuildPhase class],
        [NSMutableArray array], target, @"Frameworks");
    buildPhases = [NSMutableArray arrayWithObjects:
        sourcesPhase, resourcesPhase, frameworksPhase, nil];
    [target setBuildPhases:buildPhases];

    children = [NSMutableArray arrayWithObject:productsGroup];
    productChildren = [NSMutableArray arrayWithObject:productReference];
    [mainGroup setChildren:children];
    [productsGroup setChildren:productChildren];

    targets = [NSMutableArray arrayWithObject:target];
    [project setTargets:targets];
    
    PBXBuildPhase *headersPhase = YCodeBuildPhase([PBXHeadersBuildPhase class],
        [NSMutableArray array], target, @"Headers");
    [buildPhases addObject:headersPhase];
    NSMutableDictionary *references = [NSMutableDictionary dictionary];
    NSArray *categories = [NSArray arrayWithObjects:
        [NSArray arrayWithObjects:@"Sources", @"CLASS_FILES", @"OTHER_SOURCES", nil],
        [NSArray arrayWithObjects:@"Headers", @"HEADER_FILES", @"PUBLIC_HEADERS", nil],
        [NSArray arrayWithObjects:@"Resources", @"IMAGES", @"INTERFACES", @"LOCALIZED_RESOURCES", @"OTHER_RESOURCES", nil],
        [NSArray arrayWithObjects:@"Supporting Files", @"SUPPORTING_FILES", @"DOCU_FILES", @"SUBPROJECTS", @"OTHER_FILES", @"NON_PROJECT_FILES", nil],
        [NSArray arrayWithObjects:@"Frameworks", @"FRAMEWORKS", nil], nil];
    NSArray *phases = [NSArray arrayWithObjects:sourcesPhase, headersPhase,
        resourcesPhase, [NSNull null], frameworksPhase, nil];
    NSUInteger categoryIndex = 0;
    {
      NSEnumerator *categoryEnumerator = [categories objectEnumerator];
      NSArray *category;
      while ((category = [categoryEnumerator nextObject]) != nil)
        {
          PBXGroup *group = AUTORELEASE([[PBXGroup alloc] init]);
          [group setName:[category objectAtIndex:0]];
          [group setSourceTree:@"<group>"];
          [group setChildren:[NSMutableArray array]];
          id phase = [phases objectAtIndex:categoryIndex++];
          NSUInteger index;
          for (index = 1; index < [category count]; index++) {
              NSString *key = [category objectAtIndex:index];
              {
                NSEnumerator *entryEnumerator = [[projectDict objectForKey:key] objectEnumerator];
                NSString *entry;
                while ((entry = [entryEnumerator nextObject]) != nil)
                  {
                    NSString *file = entry;
                    if ([key isEqual:@"FRAMEWORKS"] && ![[file pathExtension] length])
                        file = [file stringByAppendingPathExtension:@"framework"];
                    PBXFileReference *reference = [references objectForKey:file];
                    if (!reference) {
                        reference = YCodeFileReference(file);
                        if ([key isEqual:@"FRAMEWORKS"] && [[entry lastPathComponent] isEqual:entry]) {
                            [reference setPath:[@"System/Library/Frameworks" stringByAppendingPathComponent:file]];
                            [reference setSourceTree:@"SDKROOT"];
                        }
                        [references setObject:reference forKey:file];
                        [[group children] addObject:reference];
                    }
                    if (phase != [NSNull null]) {
                        PBXBuildFile *buildFile = nil;
                        {
                          NSEnumerator *existingEnumerator = [[phase files] objectEnumerator];
                          PBXBuildFile *existing;
                          while ((existing = [existingEnumerator nextObject]) != nil)
                            if ([existing fileRef] == reference) buildFile = existing;
                        }
                        if (!buildFile) {
                            buildFile = YCodeBuildFile(reference);
                            [[phase files] addObject:buildFile];
                        }
                        if ([key isEqual:@"PUBLIC_HEADERS"])
                            [buildFile setSettings:[NSMutableDictionary dictionaryWithObject:
                                [NSArray arrayWithObject:@"Public"] forKey:@"ATTRIBUTES"]];
                    }
                  }
              }
          }
          if ([[group children] count]) [children addObject:group];
        }
    }
    {
      NSEnumerator *configurationEnumerator = [[[target buildConfigurationList] buildConfigurations] objectEnumerator];
      XCBuildConfiguration *configuration;
      while ((configuration = [configurationEnumerator nextObject]) != nil)
        {
          NSMutableDictionary *settings = [configuration buildSettings];
          NSDictionary *mapping = [NSDictionary dictionaryWithObjectsAndKeys:
              @"HEADER_SEARCH_PATHS", @"SEARCH_HEADER_DIRS", @"LIBRARY_SEARCH_PATHS", @"SEARCH_LIB_DIRS",
              @"PRODUCT_BUNDLE_IDENTIFIER", @"BUNDLE_IDENTIFIER", nil];
          {
            NSEnumerator *keyEnumerator = [mapping keyEnumerator];
            NSString *key;
            while ((key = [keyEnumerator nextObject]) != nil)
              {
                id value = [projectDict objectForKey:key];
                if (([value isKindOfClass:[NSArray class]] && [value count] > 0)
                    || ([value isKindOfClass:[NSString class]] && [value length] > 0))
                    [settings setObject:value forKey:[mapping objectForKey:key]];
              }
          }
          NSMutableArray *cflags = [NSMutableArray array];
          {
            NSEnumerator *keyEnumerator = [[NSArray arrayWithObjects:@"CPPOPTIONS", @"COMPILEROPTIONS", @"OBJC_COMPILEROPTIONS", nil] objectEnumerator];
            NSString *key;
            while ((key = [keyEnumerator nextObject]) != nil)
              if ([[projectDict objectForKey:key] length]) [cflags addObject:[projectDict objectForKey:key]];
          }
          if ([cflags count]) [settings setObject:[cflags componentsJoinedByString:@" "] forKey:@"OTHER_CFLAGS"];
          NSMutableArray *ldflags = [NSMutableArray array];
          if ([[projectDict objectForKey:@"LINKEROPTIONS"] length])
              [ldflags addObject:[projectDict objectForKey:@"LINKEROPTIONS"]];
          {
            NSEnumerator *libraryEnumerator = [[projectDict objectForKey:@"LIBRARIES"] objectEnumerator];
            NSString *library;
            while ((library = [libraryEnumerator nextObject]) != nil)
              [ldflags addObject:[library hasPrefix:@"-l"] ? library : [@"-l" stringByAppendingString:library]];
          }
          if ([ldflags count]) [settings setObject:[ldflags componentsJoinedByString:@" "] forKey:@"OTHER_LDFLAGS"];
          {
            NSEnumerator *fileEnumerator = [[projectDict objectForKey:@"SUPPORTING_FILES"] objectEnumerator];
            NSString *file;
            while ((file = [fileEnumerator nextObject]) != nil)
              if ([file hasSuffix:@"Info.plist"] || [[file lastPathComponent] isEqual:@"Info.plist"])
                    [settings setObject:file forKey:@"INFOPLIST_FILE"];
          }
        }
    }
    
    PBXContainer *container = [[PBXContainer alloc] initWithRootObject:project];
    [project setContainer:container];

    RELEASE(project);
    RELEASE(mainGroup);
    RELEASE(productsGroup);
    RELEASE(target);
    
    return AUTORELEASE(container);
}

#pragma mark - Project Saving

- (BOOL)exportProjectCenterToPath:(NSString *)path error:(NSError **)error
{
    PBXNativeTarget *target = nil;
    NSArray *targets = [_project targets];
    {
      NSEnumerator *candidateEnumerator = [targets objectEnumerator];
      PBXNativeTarget *candidate;
      while ((candidate = [candidateEnumerator nextObject]) != nil)
        if ([[candidate name] isEqual:[_buildSystem targetName]]) target = candidate;
    }
    if (!target && [targets count] == 1) target = [targets objectAtIndex:0];
    NSDictionary *types = [NSDictionary dictionaryWithObjectsAndKeys:
        @"Application", @"com.apple.product-type.application", @"Tool", @"com.apple.product-type.tool",
        @"Library", @"com.apple.product-type.library.dynamic", @"Library", @"com.apple.product-type.library.static",
        @"Framework", @"com.apple.product-type.framework", @"Bundle", @"com.apple.product-type.bundle", nil];
    NSString *type = target ? [types objectForKey:[target productType]] : nil;
    if (![path length] || !type) {
        if (error) *error = [NSError errorWithDomain:NSCocoaErrorDomain code:NSFileWriteUnknownError
            userInfo:[NSDictionary dictionaryWithObject:
                @"Select an application, tool, library, framework, or bundle target to export."
                forKey:NSLocalizedDescriptionKey]];
        return NO;
    }
    NSString *destination = [path stringByDeletingLastPathComponent];
    NSDictionary *metadata = [_settings objectForKey:@"ProjectCenterMetadata"];
    NSMutableDictionary *output = metadata ? [NSMutableDictionary dictionaryWithDictionary:metadata]
        : [NSMutableDictionary dictionary];
    NSArray *keys = [NSArray arrayWithObjects:@"CLASS_FILES", @"OTHER_SOURCES", @"HEADER_FILES",
        @"PUBLIC_HEADERS", @"IMAGES", @"INTERFACES", @"LOCALIZED_RESOURCES", @"OTHER_RESOURCES",
        @"SUPPORTING_FILES", @"DOCU_FILES", @"OTHER_FILES", @"NON_PROJECT_FILES", @"FRAMEWORKS",
        @"LIBRARIES", @"SUBPROJECTS", nil];
    {
      NSEnumerator *keyEnumerator = [keys objectEnumerator];
      NSString *key;
      while ((key = [keyEnumerator nextObject]) != nil)
        [output setObject:[NSMutableArray array] forKey:key];
    }
    [output setObject:[target name] forKey:@"PROJECT_NAME"];
    [output setObject:type forKey:@"PROJECT_TYPE"];
    NSString *language = [output objectForKey:@"LANGUAGE"];
    if (![language isKindOfClass:[NSString class]] || ![language length]) language = @"English";
    [output setObject:language forKey:@"LANGUAGE"];
    NSString *languageDirectory = [language stringByAppendingPathExtension:@"lproj"];
    NSMutableArray *entries = [NSMutableArray array];
    YCodeCollectFileEntries([_project mainGroup], [self projectDirectoryPath], [self projectDirectoryPath], entries);
    NSMutableDictionary *paths = [NSMutableDictionary dictionary];
    NSMutableSet *used = [NSMutableSet set];
    {
      NSEnumerator *entryEnumerator = [entries objectEnumerator];
      NSDictionary *entry;
      while ((entry = [entryEnumerator nextObject]) != nil)
        if ([entry objectForKey:@"path"])
              [paths setObject:[entry objectForKey:@"path"]
                  forKey:[NSValue valueWithPointer:[entry objectForKey:@"file"]]];
    }
    {
      NSEnumerator *phaseEnumerator = [[target buildPhases] objectEnumerator];
      PBXBuildPhase *phase;
      while ((phase = [phaseEnumerator nextObject]) != nil)
        {
          {
            NSEnumerator *buildFileEnumerator = [[phase files] objectEnumerator];
            PBXBuildFile *buildFile;
            while ((buildFile = [buildFileEnumerator nextObject]) != nil)
              {
                PBXFileReference *reference = [buildFile fileRef];
                NSValue *identity = [NSValue valueWithPointer:reference];
                NSString *absolute = [paths objectForKey:identity];
                NSString *file = absolute ? YCodeRelativeFilePath(absolute, destination) : [reference path];
                NSString *extension = [[file pathExtension] lowercaseString];
                NSString *key = nil;
                if ([phase isKindOfClass:[PBXSourcesBuildPhase class]])
                    key = ([extension isEqual:@"m"] || [extension isEqual:@"mm"]) ? @"CLASS_FILES" : @"OTHER_SOURCES";
                else if ([phase isKindOfClass:[PBXHeadersBuildPhase class]]) {
                    key = @"HEADER_FILES";
                    if ([[[buildFile settings] objectForKey:@"ATTRIBUTES"] containsObject:@"Public"])
                        YCodeAppendProjectFile(output, @"PUBLIC_HEADERS", file);
                } else if ([phase isKindOfClass:[PBXResourcesBuildPhase class]]) {
                    if (!absolute) continue;
                    BOOL localized = [[absolute pathComponents] containsObject:languageDirectory];
                    file = YCodeRelativeFilePath(absolute, [destination stringByAppendingPathComponent:
                        localized ? languageDirectory : @"Resources"]);
                    if (localized) YCodeAppendProjectFile(output, @"LOCALIZED_RESOURCES", file);
                    if ([[NSArray arrayWithObjects:@"gorm", @"nib", @"xib", @"gsmarkup", nil] containsObject:extension]) key = @"INTERFACES";
                    else if ([[NSImage imageFileTypes] containsObject:extension]) key = @"IMAGES";
                    else key = @"OTHER_RESOURCES";
                } else if ([phase isKindOfClass:[PBXFrameworksBuildPhase class]]) {
                    if ([extension isEqual:@"framework"]) {
                        key = @"FRAMEWORKS";
                        if ([[reference sourceTree] isEqual:@"SDKROOT"])
                            file = [[file lastPathComponent] stringByDeletingPathExtension];
                    } else {
                        key = @"LIBRARIES";
                        file = [[file lastPathComponent] stringByDeletingPathExtension];
                        if ([file hasPrefix:@"lib"]) file = [file substringFromIndex:3];
                    }
                }
                if (key) {
                    YCodeAppendProjectFile(output, key, file);
                    [used addObject:identity];
                }
              }
          }
        }
    }
    {
      NSEnumerator *entryEnumerator = [entries objectEnumerator];
      NSDictionary *entry;
      while ((entry = [entryEnumerator nextObject]) != nil)
        {
          PBXFileReference *reference = [entry objectForKey:@"file"];
          NSString *absolute = [entry objectForKey:@"path"];
          if (!absolute || [used containsObject:[NSValue valueWithPointer:reference]]) continue;
          NSString *file = YCodeRelativeFilePath(absolute, destination);
          NSString *extension = [[file pathExtension] lowercaseString];
          NSString *key = [[NSArray arrayWithObjects:@"h", @"hpp", @"hh", nil] containsObject:extension]
              ? @"HEADER_FILES" : @"SUPPORTING_FILES";
          if ([extension isEqual:@"pcproj"] || [extension isEqual:@"subproj"]) key = @"SUBPROJECTS";
          YCodeAppendProjectFile(output, key, file);
        }
    }
    NSDictionary *settings = [[[target buildConfigurationList] defaultConfiguration] buildSettings];
    {
      NSEnumerator *keyEnumerator = [[NSArray arrayWithObjects:@"HEADER_SEARCH_PATHS", @"LIBRARY_SEARCH_PATHS", nil] objectEnumerator];
      NSString *key;
      while ((key = [keyEnumerator nextObject]) != nil)
        {
          id value = [settings objectForKey:key];
          NSArray *values = YCodeSettingWords(value);
          NSMutableArray *rebased = [NSMutableArray array];
          {
            NSEnumerator *itemEnumerator = [values objectEnumerator];
            NSString *item;
            while ((item = [itemEnumerator nextObject]) != nil)
              {
                if ([item isEqual:@"$(inherited)"] || [item isEqual:@"${inherited}"]) continue;
                NSString *absolute = [item isAbsolutePath] ? item : [[self projectDirectoryPath] stringByAppendingPathComponent:item];
                [rebased addObject:[item hasPrefix:@"$"] ? item : YCodeRelativeFilePath(absolute, destination)];
              }
          }
          [output setObject:rebased forKey:[key isEqual:@"HEADER_SEARCH_PATHS"] ? @"SEARCH_HEADER_DIRS" : @"SEARCH_LIB_DIRS"];
        }
    }
    {
      NSEnumerator *keyEnumerator = [[NSArray arrayWithObjects:@"OTHER_CFLAGS", @"OTHER_LDFLAGS", nil] objectEnumerator];
      NSString *key;
      while ((key = [keyEnumerator nextObject]) != nil)
        {
          id value = [settings objectForKey:key];
          if ([key isEqual:@"OTHER_LDFLAGS"]) {
              NSMutableArray *remaining = [NSMutableArray array];
              {
                NSEnumerator *flagEnumerator = [YCodeSettingWords(value) objectEnumerator];
                NSString *flag;
                while ((flag = [flagEnumerator nextObject]) != nil)
                  {
                    if ([flag hasPrefix:@"-l"] && [flag length] > 2)
                        YCodeAppendProjectFile(output, @"LIBRARIES", [flag substringFromIndex:2]);
                    else if (![flag isEqual:@"$(inherited)"] && ![flag isEqual:@"${inherited}"])
                        [remaining addObject:flag];
                  }
              }
              value = YCodeQuotedFlags(remaining);
          } else if ([value isKindOfClass:[NSArray class]]) value = YCodeQuotedFlags(value);
          [output setObject:value ? value : @"" forKey:[key isEqual:@"OTHER_CFLAGS"] ? @"COMPILEROPTIONS" : @"LINKEROPTIONS"];
        }
    }
    [output setObject:@"" forKey:@"CPPOPTIONS"];
    [output setObject:@"" forKey:@"OBJC_COMPILEROPTIONS"];
    if ([settings objectForKey:@"PRODUCT_BUNDLE_IDENTIFIER"])
        [output setObject:[settings objectForKey:@"PRODUCT_BUNDLE_IDENTIFIER"] forKey:@"BUNDLE_IDENTIFIER"];
    BOOL directory = NO;
    NSFileManager *manager = [NSFileManager defaultManager];
    BOOL exists = [manager fileExistsAtPath:path isDirectory:&directory];
    if (!exists && ![manager createDirectoryAtPath:path withIntermediateDirectories:YES attributes:nil error:error]) return NO;
    NSString *file = (!exists || directory) ? [path stringByAppendingPathComponent:@"PC.project"] : path;
    BOOL success = [output writeToFile:file atomically:YES];
    if (!success && error) *error = [NSError errorWithDomain:NSCocoaErrorDomain code:NSFileWriteUnknownError
        userInfo:[NSDictionary dictionaryWithObject:@"The ProjectCenter project could not be written." forKey:NSLocalizedDescriptionKey]];
    return success;
}

- (BOOL)saveProjectToPath:(NSString *)path
{
    NSString *projectPath = YCodeProjectPackagePathForPath(path);
    NSString *projectFile = nil;
    BOOL isDirectory = NO;
    BOOL saved = NO;
    BOOL relocatedImport = [[_projectPath pathExtension] isEqual:@"pcproj"]
        && ![[projectPath stringByDeletingLastPathComponent] isEqual:[self projectDirectoryPath]];
    NSString *originalGroupPath = [[[_project mainGroup] path] copy];
    NSMutableArray *originalSettings = [NSMutableArray array];

    if (!_container || projectPath == nil) {
        RELEASE(originalGroupPath);
        return NO;
    }

    if ([[NSFileManager defaultManager] fileExistsAtPath:projectPath isDirectory:&isDirectory] && !isDirectory) {
        RELEASE(originalGroupPath);
        return NO;
    }

    if (![[NSFileManager defaultManager] fileExistsAtPath:projectPath]) {
        if (![[NSFileManager defaultManager] createDirectoryAtPath:projectPath
                                       withIntermediateDirectories:YES
                                                        attributes:nil
                                                             error:nil]) {
            RELEASE(originalGroupPath);
            return NO;
        }
    }
    
    @try {
        if (relocatedImport) {
            NSString *sourceRoot = [self projectDirectoryPath];
            [[_project mainGroup] setPath:sourceRoot];
            {
              NSEnumerator *targetEnumerator = [[_project targets] objectEnumerator];
              PBXNativeTarget *target;
              while ((target = [targetEnumerator nextObject]) != nil)
                {
                  {
                    NSEnumerator *configurationEnumerator = [[[target buildConfigurationList] buildConfigurations] objectEnumerator];
                    XCBuildConfiguration *configuration;
                    while ((configuration = [configurationEnumerator nextObject]) != nil)
                      {
                        NSMutableDictionary *settings = [configuration buildSettings];
                        [originalSettings addObject:[NSArray arrayWithObjects:configuration,
                            [NSDictionary dictionaryWithDictionary:settings], nil]];
                        {
                          NSEnumerator *keyEnumerator = [[NSArray arrayWithObjects:@"HEADER_SEARCH_PATHS", @"LIBRARY_SEARCH_PATHS", nil] objectEnumerator];
                          NSString *key;
                          while ((key = [keyEnumerator nextObject]) != nil)
                            {
                              id paths = [settings objectForKey:key];
                              if (![paths isKindOfClass:[NSArray class]]) continue;
                              NSMutableArray *resolved = [NSMutableArray array];
                              {
                                NSEnumerator *entryEnumerator = [paths objectEnumerator];
                                NSString *entry;
                                while ((entry = [entryEnumerator nextObject]) != nil)
                                  [resolved addObject:([entry isAbsolutePath] || [entry hasPrefix:@"$"])
                                        ? entry : [sourceRoot stringByAppendingPathComponent:entry]];
                              }
                              [settings setObject:resolved forKey:key];
                            }
                        }
                        NSString *info = [settings objectForKey:@"INFOPLIST_FILE"];
                        if ([info length] && ![info isAbsolutePath] && ![info hasPrefix:@"$"])
                            [settings setObject:[sourceRoot stringByAppendingPathComponent:info] forKey:@"INFOPLIST_FILE"];
                      }
                  }
                }
            }
        }
        projectFile = [projectPath stringByAppendingPathComponent:@"project.pbxproj"];
        [_container setParameter:projectPath];
        [_container setFilename:projectFile];

        if (_project) {
            [_project setContainer:_container];
        }

        BOOL success = [_container save];
        saved = success;
        
        if (success) {
            [self updateChangeCount:NSChangeCleared];
            [self setProjectPath:projectPath];
            [self setFileURL:[NSURL fileURLWithPath:projectPath]];
            [self setFileType:@"YCodeXcodeProjectType"];
        }
        
        return success;
    }
    @catch (NSException *exception) {
        NSLog(@"Error saving project: %@", [exception reason]);
        return NO;
    }
    @finally {
        if (relocatedImport && !saved) {
            [[_project mainGroup] setPath:originalGroupPath];
            {
              NSEnumerator *entryEnumerator = [originalSettings objectEnumerator];
              NSArray *entry;
              while ((entry = [entryEnumerator nextObject]) != nil)
                [[entry objectAtIndex:0] setBuildSettings:
                      [NSMutableDictionary dictionaryWithDictionary:[entry objectAtIndex:1]]];
            }
        }
        RELEASE(originalGroupPath);
    }
}

#pragma mark - Accessors

- (PBXProject *)project
{
    return _project;
}

- (void)setProject:(PBXProject *)project
{
    ASSIGN(_project, project);
    
    // Notify controllers
    [_navigatorController projectDidChange];
}

- (PBXContainer *)container
{
    return _container;
}

- (void)setContainer:(PBXContainer *)container
{
    ASSIGN(_container, container);
}

- (NSString *)projectPath
{
    return _projectPath;
}

- (void)setProjectPath:(NSString *)path
{
    ASSIGN(_projectPath, path);
}

- (NSString *)projectDirectoryPath
{
    if (_projectPath) {
        return [_projectPath stringByDeletingLastPathComponent];
    }
    return nil;
}

- (YCodeProjectNavigatorController *)navigatorController
{
    return _navigatorController;
}

- (YCodeEditorController *)editorController
{
    return _editorController;
}

- (YCodeBuildSystem *)buildSystem
{
    return _buildSystem;
}

#pragma mark - Project Operations

- (BOOL)buildProject
{
    if (_buildSystem) {
        return [_buildSystem build];
    }
    return NO;
}

- (BOOL)cleanProject
{
    if (_buildSystem) {
        return [_buildSystem clean];
    }
    return NO;
}

- (BOOL)runProject
{
    if (_buildSystem) {
        return [_buildSystem run];
    }
    return NO;
}

#pragma mark - File Management

- (NSArray *)projectFileEntries
{
    NSMutableArray *entries = [NSMutableArray array];
    NSString *root = [self projectDirectoryPath];
    YCodeCollectFileEntries([_project mainGroup], root, root, entries);
    return entries;
}

- (void)addFilesToProject:(NSArray *)filePaths
{
    PBXGroup *mainGroup = [_project mainGroup];
    if (!mainGroup || ![filePaths count]) return;
    NSMutableSet *knownPaths = [NSMutableSet set];
    {
      NSEnumerator *entryEnumerator = [[self projectFileEntries] objectEnumerator];
      NSDictionary *entry;
      while ((entry = [entryEnumerator nextObject]) != nil)
        if ([entry objectForKey:@"path"]) [knownPaths addObject:[entry objectForKey:@"path"]];
    }
    BOOL changed = NO;
    {
      NSEnumerator *filePathEnumerator = [filePaths objectEnumerator];
      NSString *filePath;
      while ((filePath = [filePathEnumerator nextObject]) != nil)
        {
          if (![filePath length]) continue;
          NSString *absolute = [filePath isAbsolutePath] ? filePath :
              [[self projectDirectoryPath] stringByAppendingPathComponent:filePath];
          absolute = [absolute stringByStandardizingPath];
          if (!absolute || [knownPaths containsObject:absolute]) continue;
          NSString *root = [[self projectDirectoryPath] stringByAppendingString:@"/"];
          BOOL local = root && [absolute hasPrefix:root];
          NSString *storedPath = local ? [absolute substringFromIndex:[root length]] : absolute;
          PBXFileReference *fileRef = [[PBXFileReference alloc] initWithPath:storedPath];
          [fileRef setSourceTree:local ? @"SOURCE_ROOT" : @"<absolute>"];
          if (![mainGroup children]) [mainGroup setChildren:[NSMutableArray array]];
          [[mainGroup children] addObject:fileRef];
          [self addFileToBuildPhases:fileRef];
          RELEASE(fileRef);
          [knownPaths addObject:absolute];
          changed = YES;
        }
    }
    if (changed) {
        [self updateChangeCount:NSChangeDone];
        [_navigatorController projectDidChange];
    }
}

- (void)removeFileReferencesFromProject:(NSArray *)references
{
    if (![references count]) return;
    BOOL changed = NO;
    {
      NSEnumerator *entryEnumerator = [[self projectFileEntries] objectEnumerator];
      NSDictionary *entry;
      while ((entry = [entryEnumerator nextObject]) != nil)
        {
          if ([references containsObject:[entry objectForKey:@"file"]]) {
              [[[entry objectForKey:@"group"] children] removeObjectIdenticalTo:[entry objectForKey:@"file"]];
              changed = YES;
          }
        }
    }
    if (!changed) return;
    {
      NSEnumerator *targetEnumerator = [[_project targets] objectEnumerator];
      PBXTarget *target;
      while ((target = [targetEnumerator nextObject]) != nil)
        {
            NSEnumerator *phaseEnumerator = [[target buildPhases] objectEnumerator];
            PBXBuildPhase *phase;
            while ((phase = [phaseEnumerator nextObject]) != nil)
              {
                  NSEnumerator *fileEnumerator = [[NSArray arrayWithArray:[phase files] ?: [NSArray array]] objectEnumerator];
                  PBXBuildFile *file;
                  while ((file = [fileEnumerator nextObject]) != nil)
                    if ([references containsObject:[file fileRef]])
                          [[phase files] removeObjectIdenticalTo:file];
              }
        }
    }
    [self updateChangeCount:NSChangeDone];
    [_navigatorController projectDidChange];
}

- (void)removeFileReferenceFromProject:(PBXFileReference *)reference
{
    if (reference) [self removeFileReferencesFromProject:[NSArray arrayWithObject:reference]];
}

- (void)removeFilesFromProject:(NSArray *)filePaths
{
    NSMutableSet *paths = [NSMutableSet set];
    {
      NSEnumerator *pathEnumerator = [filePaths objectEnumerator];
      NSString *path;
      while ((path = [pathEnumerator nextObject]) != nil)
        {
          if (![path length]) continue;
          NSString *absolute = [path isAbsolutePath] ? path :
              [[self projectDirectoryPath] stringByAppendingPathComponent:path];
          if (absolute) [paths addObject:[absolute stringByStandardizingPath]];
        }
    }
    NSMutableArray *references = [NSMutableArray array];
    {
      NSEnumerator *entryEnumerator = [[self projectFileEntries] objectEnumerator];
      NSDictionary *entry;
      while ((entry = [entryEnumerator nextObject]) != nil)
        if ([entry objectForKey:@"path"] && [paths containsObject:[entry objectForKey:@"path"]])
              [references addObject:[entry objectForKey:@"file"]];
    }
    [self removeFileReferencesFromProject:references];
}

- (BOOL)addGroupToProject:(NSString *)groupName
{
    if (![_project mainGroup] || ![groupName length]) {
        return NO;
    }
    
    PBXGroup *newGroup = [[PBXGroup alloc] init];
    [newGroup setName:groupName];
    
    PBXGroup *mainGroup = [_project mainGroup];
    NSMutableArray *children = [mainGroup children];

    if (children == nil) {
        children = [NSMutableArray array];
        [mainGroup setChildren:children];
    }
    [children addObject:newGroup];
    
    [self updateChangeCount:NSChangeDone];
    [_navigatorController projectDidChange];
    RELEASE(newGroup);
    return YES;
}

- (void)addFileToBuildPhases:(PBXFileReference *)fileRef
{
    NSString *extension = [[[fileRef path] pathExtension] lowercaseString];
    NSArray *targets = [_project targets];
    
    NSEnumerator *targetEnum = [targets objectEnumerator];
    PBXTarget *target;
    
    while ((target = [targetEnum nextObject]) != nil) {
        NSEnumerator *phaseEnum = [[target buildPhases] objectEnumerator];
        PBXBuildPhase *phase = nil;
        PBXBuildPhase *destinationPhase = nil;

        if ([extension isEqualToString:@"m"] || [extension isEqualToString:@"mm"] || 
            [extension isEqualToString:@"c"] || [extension isEqualToString:@"cpp"] ||
            [extension isEqualToString:@"cc"] || [extension isEqualToString:@"cp"] ||
            [extension isEqualToString:@"cxx"] || [extension isEqualToString:@"c++"]) {
            while ((phase = [phaseEnum nextObject]) != nil) {
                if ([phase isKindOfClass:[PBXSourcesBuildPhase class]]) {
                    destinationPhase = phase;
                    break;
                }
            }
        } else if ([extension isEqualToString:@"xib"] || [extension isEqualToString:@"nib"] ||
                   [extension isEqualToString:@"plist"] || [extension isEqualToString:@"png"]) {
            while ((phase = [phaseEnum nextObject]) != nil) {
                if ([phase isKindOfClass:[PBXResourcesBuildPhase class]]) {
                    destinationPhase = phase;
                    break;
                }
            }
        }

        if (destinationPhase != nil) {
            PBXBuildFile *buildFile = [[PBXBuildFile alloc] init];
            NSMutableArray *files = [destinationPhase files];

            if (files == nil) {
                files = [NSMutableArray array];
                [destinationPhase setFiles:files];
            }
            [buildFile setFileRef:fileRef];
            [files addObject:buildFile];
            RELEASE(buildFile);
        }
    }
}

#pragma mark - Settings

- (NSMutableDictionary *)settings
{
    return _settings;
}

- (void)setSettings:(NSMutableDictionary *)settings
{
    ASSIGN(_settings, settings);
}

#pragma mark - File Watching

- (void)startWatchingFiles
{
    if (!_projectPath) {
        return;
    }
    
    // Simple file watching implementation
    // In a real implementation, you'd use FSEvents or similar
    NSLog(@"Started watching files in project: %@", _projectPath);
}

- (void)stopWatchingFiles
{
    // Stop file system monitoring
    [_fileWatchers removeAllObjects];
    NSLog(@"Stopped watching files");
}

@end
