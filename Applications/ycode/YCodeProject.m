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
    if ([[path pathExtension] isEqualToString:@"pbxproj"]) {
        return path;
    }

    if ([[path pathExtension] isEqualToString:@"pcproj"]) {
        NSString *name = [[path lastPathComponent] stringByDeletingPathExtension];
        return [[path stringByAppendingPathComponent:
            [NSString stringWithFormat:@"%@.xcodeproj", name]]
                stringByAppendingPathComponent:@"project.pbxproj"];
    }

    if ([[path pathExtension] isEqualToString:@"xcodeproj"]) {
        return [path stringByAppendingPathComponent:@"project.pbxproj"];
    }

    return [[path stringByAppendingPathExtension:@"xcodeproj"]
        stringByAppendingPathComponent:@"project.pbxproj"];
}

static NSString *
YCodeProjectPackagePathForPath(NSString *path)
{
    if ([[path pathExtension] isEqualToString:@"pbxproj"]) {
        return [path stringByDeletingLastPathComponent];
    }

    if ([[path pathExtension] isEqualToString:@"pcproj"]) {
        NSString *name = [[path lastPathComponent] stringByDeletingPathExtension];
        return [path stringByAppendingPathComponent:
            [NSString stringWithFormat:@"%@.xcodeproj", name]];
    }

    if ([[path pathExtension] isEqualToString:@"xcodeproj"]) {
        return path;
    }

    return [path stringByAppendingPathExtension:@"xcodeproj"];
}

@implementation YCodeProject

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
    PBXContainer *container = [self convertProjectCenterProject:projectDict];
    NSString *projectName = [projectDict objectForKey:@"PROJECT_NAME"];
    NSString *projectPath = nil;

    if (projectName == nil) {
        projectName = [path lastPathComponent];
    }

    projectPath = [path stringByAppendingPathComponent:
        [NSString stringWithFormat:@"%@.xcodeproj", projectName]];
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

- (NSString *)windowNibName
{
    return @"YCodeProject";
}

- (BOOL)readFromURL:(NSURL *)url ofType:(NSString *)typeName error:(NSError **)outError
{
    NSString *path = [url path];
    BOOL success = NO;
    
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
    
    if (![self saveProjectToPath:[url path]]) {
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
    @try {
        NSString *projectFile = YCodeProjectFilePathForPath(path);
        PBXCoder *coder = [[PBXCoder alloc] initWithProjectFile:projectFile];
        if (coder) {
            PBXContainer *container = [coder unarchive];
            if (container) {
                [self setContainer:container];
                [self setProject:[container rootObject]];
                [self setProjectPath:YCodeProjectPackagePathForPath(path)];
                [container setFilename:projectFile];
                [container setParameter:[self projectPath]];
                
                // Start watching files
                [self startWatchingFiles];
                
                return YES;
            }
        }
    }
    @catch (NSException *exception) {
        NSLog(@"Error loading Xcode project: %@", [exception reason]);
    }
    return NO;
}

- (BOOL)loadProjectCenterProjectAtPath:(NSString *)path
{
    NSString *projectFile = [path stringByAppendingPathComponent:@"PC.project"];
    NSDictionary *projectDict = [NSDictionary dictionaryWithContentsOfFile:projectFile];
    
    if (projectDict) {
        // Convert ProjectCenter project to Xcode format
        PBXContainer *container = [self convertProjectCenterProject:projectDict];
        if (container) {
            [self setContainer:container];
            [self setProject:[container rootObject]];
            [self setProjectPath:path];
            
            // Start watching files
            [self startWatchingFiles];
            
            return YES;
        }
    }
    return NO;
}

- (PBXContainer *)convertProjectCenterProject:(NSDictionary *)projectDict
{
    // This is a simplified conversion - you might want to use the pc2xc logic
    NSString *projectName = [projectDict objectForKey:@"PROJECT_NAME"];
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

    if (projectName == nil) {
        projectName = [[self projectDirectoryPath] lastPathComponent];
    }
    
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
    [target setProductType:@"com.apple.product-type.application"];
    [target setBuildConfigurationList:YCodeConfigurationList(projectName)];
    [target setDependencies:[NSMutableArray array]];
    [target setBuildRules:[NSMutableArray array]];

    productPath = [NSString stringWithFormat:@"%@.app", projectName];
    productReference = YCodeFileReference(productPath);
    [productReference setExplicitFileType:@"wrapper.application"];
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
    
    // Add files to groups
    // ... (implementation details for file organization)
    
    PBXContainer *container = [[PBXContainer alloc] initWithRootObject:project];
    [project setContainer:container];

    RELEASE(project);
    RELEASE(mainGroup);
    RELEASE(productsGroup);
    RELEASE(target);
    
    return AUTORELEASE(container);
}

#pragma mark - Project Saving

- (BOOL)saveProjectToPath:(NSString *)path
{
    NSString *originalPath = path;
    NSString *projectPath = YCodeProjectPackagePathForPath(path);
    NSString *projectFile = nil;
    BOOL isDirectory = NO;

    if (!_container) {
        return NO;
    }

    if ([[NSFileManager defaultManager] fileExistsAtPath:projectPath isDirectory:&isDirectory] && !isDirectory) {
        return NO;
    }

    if (![[NSFileManager defaultManager] fileExistsAtPath:projectPath]) {
        if (![[NSFileManager defaultManager] createDirectoryAtPath:projectPath
                                       withIntermediateDirectories:YES
                                                        attributes:nil
                                                             error:nil]) {
            return NO;
        }
    }
    
    @try {
        projectFile = [projectPath stringByAppendingPathComponent:@"project.pbxproj"];
        [_container setParameter:projectPath];
        [_container setFilename:projectFile];

        if (_project) {
            [_project setContainer:_container];
        }

        BOOL success = [_container save];
        
        if (success) {
            if ([[originalPath pathExtension] isEqualToString:@"pcproj"]) {
                [self setProjectPath:originalPath];
            } else {
                [self setProjectPath:projectPath];
            }
        }
        
        return success;
    }
    @catch (NSException *exception) {
        NSLog(@"Error saving project: %@", [exception reason]);
        return NO;
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

- (void)addFilesToProject:(NSArray *)filePaths
{
    if (!_project || !filePaths) {
        return;
    }
    
    PBXGroup *mainGroup = [_project mainGroup];
    NSEnumerator *enumerator = [filePaths objectEnumerator];
    NSString *filePath;
    
    while ((filePath = [enumerator nextObject]) != nil) {
        PBXFileReference *fileRef = [[PBXFileReference alloc] initWithPath:filePath];
        NSMutableArray *children = [mainGroup children];

        if (children == nil) {
            children = [NSMutableArray array];
            [mainGroup setChildren:children];
        }
        [children addObject:fileRef];
        
        // Add to appropriate build phase based on file type
        [self addFileToBuildPhases:fileRef];
        RELEASE(fileRef);
    }
    
    // Notify navigator of changes
    [_navigatorController projectDidChange];
}

- (void)removeFilesFromProject:(NSArray *)filePaths
{
    // Implementation for removing files
    [_navigatorController projectDidChange];
}

- (BOOL)addGroupToProject:(NSString *)groupName
{
    if (!_project || !groupName) {
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
    
    [_navigatorController projectDidChange];
    RELEASE(newGroup);
    return YES;
}

- (void)addFileToBuildPhases:(PBXFileReference *)fileRef
{
    NSString *extension = [[fileRef path] pathExtension];
    NSArray *targets = [_project targets];
    
    NSEnumerator *targetEnum = [targets objectEnumerator];
    PBXTarget *target;
    
    while ((target = [targetEnum nextObject]) != nil) {
        NSEnumerator *phaseEnum = [[target buildPhases] objectEnumerator];
        PBXBuildPhase *phase = nil;
        PBXBuildPhase *destinationPhase = nil;

        if ([extension isEqualToString:@"m"] || [extension isEqualToString:@"mm"] || 
            [extension isEqualToString:@"c"] || [extension isEqualToString:@"cpp"]) {
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
