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
    // Create basic Xcode project structure
    NSString *projectFile = [NSString stringWithFormat:@"%@.xcodeproj", name];
    NSString *projectPath = [path stringByAppendingPathComponent:projectFile];
    
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
    
    // Create main group
    PBXGroup *mainGroup = [[PBXGroup alloc] init];
    [mainGroup setName:name];
    [pbxProject setMainGroup:mainGroup];
    
    // Create a simple target
    PBXNativeTarget *target = [[PBXNativeTarget alloc] init];
    [target setName:name];
    [target setProductName:name];
    [pbxProject addTarget:target];
    
    // Create container
    PBXContainer *container = [[PBXContainer alloc] init];
    [container setProject:pbxProject];
    
    [self setProject:pbxProject];
    [self setContainer:container];
    
    // Create basic main.m file
    [self createMainFileAtPath:path];
    
    RELEASE(pbxProject);
    RELEASE(mainGroup);
    RELEASE(target);
    RELEASE(container);
    
    return YES;
}

- (BOOL)createProjectCenterProjectWithName:(NSString *)name atPath:(NSString *)path
{
    // Create ProjectCenter project file
    NSString *projectFile = [NSString stringWithFormat:@"%@.pcproj", name];
    NSString *projectPath = [path stringByAppendingPathComponent:projectFile];
    
    NSMutableDictionary *projectDict = [NSMutableDictionary dictionary];
    [projectDict setObject:name forKey:@"PROJECT_NAME"];
    [projectDict setObject:@"Application" forKey:@"PROJECT_TYPE"];
    [projectDict setObject:name forKey:@"PRINCIPAL_CLASS"];
    [projectDict setObject:[NSArray array] forKey:@"CLASS_FILES"];
    [projectDict setObject:[NSArray array] forKey:@"HEADER_FILES"];
    [projectDict setObject:[NSArray array] forKey:@"LOCALIZED_RESOURCES"];
    [projectDict setObject:[NSArray array] forKey:@"LIBRARIES"];
    
    BOOL success = [projectDict writeToFile:projectPath atomically:YES];
    
    if (success) {
        // Load the project we just created
        [self loadProjectCenterProject:projectDict fromPath:path];
        
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

- (instancetype)init
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
    
    if ([[path pathExtension] isEqualToString:@"xcodeproj"]) {
        return [self loadXcodeProjectAtPath:path];
    } else if ([[path pathExtension] isEqualToString:@"pcproj"]) {
        return [self loadProjectCenterProjectAtPath:path];
    }
    
    if (outError) {
        *outError = [NSError errorWithDomain:NSCocoaErrorDomain 
                                        code:NSFileReadUnsupportedSchemeError 
                                    userInfo:@{NSLocalizedDescriptionKey: @"Unsupported project format"}];
    }
    return NO;
}

- (BOOL)writeToURL:(NSURL *)url ofType:(NSString *)typeName error:(NSError **)outError
{
    if (_container == nil) {
        if (outError) {
            *outError = [NSError errorWithDomain:NSCocoaErrorDomain
                                            code:NSFileWriteUnknownError
                                        userInfo:@{NSLocalizedDescriptionKey: @"No project container to save"}];
        }
        return NO;
    }
    
    return [self saveProjectToPath:[url path]];
}

#pragma mark - Project Loading

- (BOOL)loadXcodeProjectAtPath:(NSString *)path
{
    @try {
        PBXCoder *coder = [[PBXCoder alloc] initWithProjectFile:path];
        if (coder) {
            PBXContainer *container = [coder unarchive];
            if (container) {
                [self setContainer:container];
                [self setProject:[container rootObject]];
                [self setProjectPath:path];
                
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
    
    // Create project structure
    PBXProject *project = [[PBXProject alloc] init];
    [project setProjectDirPath:@""];
    [project setProjectRoot:@""];
    [project setCompatibilityVersion:@"Xcode 15.0"];
    [project setDevelopmentRegion:@"en"];
    
    // Create main group
    PBXGroup *mainGroup = [[PBXGroup alloc] init];
    [mainGroup setName:projectName];
    [project setMainGroup:mainGroup];
    
    // Add files to groups
    // ... (implementation details for file organization)
    
    PBXContainer *container = [[PBXContainer alloc] initWithRootObject:project];
    
    return container;
}

#pragma mark - Project Saving

- (BOOL)saveProjectToPath:(NSString *)path
{
    if (!_container) {
        return NO;
    }
    
    @try {
        NSString *projectFile = [path stringByAppendingPathComponent:@"project.pbxproj"];
        // For now, just create a simple placeholder save
        // This would need proper PBXCoder implementation
        NSString *placeholder = @"// Project placeholder";
        BOOL success = [placeholder writeToFile:projectFile 
                                      atomically:YES 
                                        encoding:NSUTF8StringEncoding 
                                           error:nil];
        
        if (success) {
            [self setProjectPath:path];
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
        [mainGroup addChild:fileRef];
        
        // Add to appropriate build phase based on file type
        [self addFileToBuildPhases:fileRef];
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
    [mainGroup addChild:newGroup];
    
    [_navigatorController projectDidChange];
    return YES;
}

- (void)addFileToBuildPhases:(PBXFileReference *)fileRef
{
    NSString *extension = [[fileRef path] pathExtension];
    NSArray *targets = [_project targets];
    
    NSEnumerator *targetEnum = [targets objectEnumerator];
    PBXTarget *target;
    
    while ((target = [targetEnum nextObject]) != nil) {
        if ([extension isEqualToString:@"m"] || [extension isEqualToString:@"mm"] || 
            [extension isEqualToString:@"c"] || [extension isEqualToString:@"cpp"]) {
            // Add to sources build phase
            PBXSourcesBuildPhase *sourcesPhase = [target sourcesBuildPhase];
            if (sourcesPhase) {
                PBXBuildFile *buildFile = [[PBXBuildFile alloc] init];
                [buildFile setFileRef:fileRef];
                [sourcesPhase addFile:buildFile];
            }
        } else if ([extension isEqualToString:@"xib"] || [extension isEqualToString:@"nib"] ||
                   [extension isEqualToString:@"plist"] || [extension isEqualToString:@"png"]) {
            // Add to resources build phase
            PBXResourcesBuildPhase *resourcesPhase = [target resourcesBuildPhase];
            if (resourcesPhase) {
                PBXBuildFile *buildFile = [[PBXBuildFile alloc] init];
                [buildFile setFileRef:fileRef];
                [resourcesPhase addFile:buildFile];
            }
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