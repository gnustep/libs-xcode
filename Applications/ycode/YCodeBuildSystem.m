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

#import "YCodeBuildSystem.h"
#import "YCodeProject.h"

@implementation YCodeBuildSystem

- (instancetype)initWithProject:(YCodeProject *)project
{
    self = [super init];
    if (self) {
        _project = [project retain];
        _status = YCodeBuildStatusIdle;
        _buildOutput = [[NSMutableString alloc] init];
        _buildErrors = [[NSMutableString alloc] init];
        _buildEnvironment = [[NSMutableDictionary alloc] init];
        
        // Default build configuration
        _buildConfiguration = [@"Debug" retain];
        
        [self setupDefaultEnvironment];
    }
    return self;
}

- (void)dealloc
{
    [self stop];
    RELEASE(_project);
    RELEASE(_currentTask);
    RELEASE(_outputPipe);
    RELEASE(_errorPipe);
    RELEASE(_buildConfiguration);
    RELEASE(_targetName);
    RELEASE(_scheme);
    RELEASE(_buildOutput);
    RELEASE(_buildErrors);
    RELEASE(_buildEnvironment);
    [super dealloc];
}

- (void)setupDefaultEnvironment
{
    // Set up default build environment
    NSProcessInfo *processInfo = [NSProcessInfo processInfo];
    NSMutableDictionary *environment = [[processInfo environment] mutableCopy];
    
    // Add common build tools to PATH if needed
    NSString *path = [environment objectForKey:@"PATH"];
    NSArray *additionalPaths = @[@"/usr/local/bin", @"/opt/local/bin", @"/usr/bin", @"/bin"];
    
    for (NSString *additionalPath in additionalPaths) {
        if (![path containsString:additionalPath]) {
            path = [path stringByAppendingFormat:@":%@", additionalPath];
        }
    }
    
    [environment setObject:path forKey:@"PATH"];
    [_buildEnvironment setDictionary:environment];
    RELEASE(environment);
}

#pragma mark - Project Association

- (YCodeProject *)project
{
    return _project;
}

- (void)setProject:(YCodeProject *)project
{
    ASSIGN(_project, project);
}

#pragma mark - Delegate

- (id<YCodeBuildSystemDelegate>)delegate
{
    return _delegate;
}

- (void)setDelegate:(id<YCodeBuildSystemDelegate>)delegate
{
    _delegate = delegate; // weak reference
}

#pragma mark - Build Status

- (YCodeBuildStatus)status
{
    return _status;
}

- (BOOL)isBuilding
{
    return _status == YCodeBuildStatusBuilding;
}

- (BOOL)isRunning
{
    return _status == YCodeBuildStatusRunning;
}

- (BOOL)isBusy
{
    return _status == YCodeBuildStatusBuilding || 
           _status == YCodeBuildStatusRunning || 
           _status == YCodeBuildStatusCleaning;
}

#pragma mark - Build Configuration

- (NSString *)buildConfiguration
{
    return _buildConfiguration;
}

- (void)setBuildConfiguration:(NSString *)configuration
{
    ASSIGN(_buildConfiguration, configuration);
}

- (NSString *)targetName
{
    return _targetName;
}

- (void)setTargetName:(NSString *)name
{
    ASSIGN(_targetName, name);
}

- (NSString *)scheme
{
    return _scheme;
}

- (void)setScheme:(NSString *)scheme
{
    ASSIGN(_scheme, scheme);
}

#pragma mark - Build Operations

- (BOOL)build
{
    if ([self isBusy]) {
        return NO;
    }
    
    NSString *buildSystem = [self detectedBuildSystem];
    BOOL success = NO;
    
    _status = YCodeBuildStatusBuilding;
    [self clearOutput];
    
    if ([_delegate respondsToSelector:@selector(buildSystemDidStartBuild:)]) {
        [_delegate buildSystemDidStartBuild:self];
    }
    
    if ([buildSystem isEqualToString:@"xcode"]) {
        success = [self buildWithXcode];
    } else if ([buildSystem isEqualToString:@"make"]) {
        success = [self buildWithMake];
    } else if ([buildSystem isEqualToString:@"gnumake"]) {
        success = [self buildWithGNUMake];
    } else if ([buildSystem isEqualToString:@"cmake"]) {
        success = [self buildWithCMake];
    } else {
        // Default to make if available
        success = [self buildWithMake];
    }
    
    return success;
}

- (BOOL)clean
{
    if ([self isBusy]) {
        return NO;
    }
    
    NSString *buildSystem = [self detectedBuildSystem];
    BOOL success = NO;
    
    _status = YCodeBuildStatusCleaning;
    [self clearOutput];
    
    if ([_delegate respondsToSelector:@selector(buildSystemDidStartClean:)]) {
        [_delegate buildSystemDidStartClean:self];
    }
    
    if ([buildSystem isEqualToString:@"xcode"]) {
        success = [self cleanWithXcode];
    } else if ([buildSystem isEqualToString:@"make"]) {
        success = [self cleanWithMake];
    } else if ([buildSystem isEqualToString:@"gnumake"]) {
        success = [self cleanWithGNUMake];
    } else if ([buildSystem isEqualToString:@"cmake"]) {
        success = [self cleanWithCMake];
    } else {
        success = [self cleanWithMake];
    }
    
    return success;
}

- (BOOL)run
{
    if ([self isBusy]) {
        return NO;
    }
    
    _status = YCodeBuildStatusRunning;
    
    if ([_delegate respondsToSelector:@selector(buildSystemDidStartRun:)]) {
        [_delegate buildSystemDidStartRun:self];
    }
    
    // Find executable to run
    NSString *executablePath = [self findExecutable];
    if (!executablePath) {
        _status = YCodeBuildStatusFailed;
        if ([_delegate respondsToSelector:@selector(buildSystemDidFinishRun:)]) {
            [_delegate buildSystemDidFinishRun:self];
        }
        return NO;
    }
    
    return [self runExecutable:executablePath];
}

- (BOOL)test
{
    if ([self isBusy]) {
        return NO;
    }
    
    NSString *buildSystem = [self detectedBuildSystem];
    
    if ([buildSystem isEqualToString:@"xcode"]) {
        return [self testWithXcode];
    } else {
        return [self testWithMake];
    }
}

- (BOOL)archive
{
    if ([self isBusy]) {
        return NO;
    }
    
    NSString *buildSystem = [self detectedBuildSystem];
    
    if ([buildSystem isEqualToString:@"xcode"]) {
        return [self archiveWithXcode];
    } else {
        return [self archiveWithMake];
    }
}

- (void)stop
{
    if (_currentTask && [_currentTask isRunning]) {
        [_currentTask terminate];
        _status = YCodeBuildStatusCancelled;
        
        if ([_delegate respondsToSelector:@selector(buildSystemDidCancel:)]) {
            [_delegate buildSystemDidCancel:self];
        }
    }
}

#pragma mark - Build System Specific Methods

- (BOOL)buildWithXcode
{
    NSString *projectPath = [_project projectPath];
    if (!projectPath) {
        return NO;
    }
    
    NSMutableArray *arguments = [NSMutableArray array];
    [arguments addObject:@"-project"];
    [arguments addObject:projectPath];
    [arguments addObject:@"-configuration"];
    [arguments addObject:_buildConfiguration];
    
    if (_scheme) {
        [arguments addObject:@"-scheme"];
        [arguments addObject:_scheme];
    }
    
    [arguments addObject:@"build"];
    
    return [self runCommand:@"xcodebuild" withArguments:arguments];
}

- (BOOL)buildWithMake
{
    return [self runCommand:@"make" withArguments:@[]];
}

- (BOOL)buildWithGNUMake
{
    NSMutableArray *arguments = [NSMutableArray array];
    
    if (_buildConfiguration) {
        if ([_buildConfiguration isEqualToString:@"Debug"]) {
            [arguments addObject:@"debug=yes"];
        } else if ([_buildConfiguration isEqualToString:@"Release"]) {
            [arguments addObject:@"debug=no"];
        }
    }
    
    return [self runCommand:@"make" withArguments:arguments];
}

- (BOOL)buildWithCMake
{
    // First, configure if needed
    NSString *projectDir = [_project projectDirectoryPath];
    NSString *buildDir = [projectDir stringByAppendingPathComponent:@"build"];
    
    NSFileManager *fileManager = [NSFileManager defaultManager];
    if (![fileManager fileExistsAtPath:buildDir]) {
        [fileManager createDirectoryAtPath:buildDir withIntermediateDirectories:YES attributes:nil error:nil];
        
        // Configure
        NSArray *configureArgs = @[@"-S", @".", @"-B", @"build"];
        if (![self runCommand:@"cmake" withArguments:configureArgs]) {
            return NO;
        }
    }
    
    // Build
    NSArray *buildArgs = @[@"--build", @"build"];
    return [self runCommand:@"cmake" withArguments:buildArgs];
}

- (BOOL)cleanWithXcode
{
    NSString *projectPath = [_project projectPath];
    if (!projectPath) {
        return NO;
    }
    
    NSMutableArray *arguments = [NSMutableArray array];
    [arguments addObject:@"-project"];
    [arguments addObject:projectPath];
    [arguments addObject:@"-configuration"];
    [arguments addObject:_buildConfiguration];
    [arguments addObject:@"clean"];
    
    return [self runCommand:@"xcodebuild" withArguments:arguments];
}

- (BOOL)cleanWithMake
{
    return [self runCommand:@"make" withArguments:@[@"clean"]];
}

- (BOOL)cleanWithGNUMake
{
    return [self runCommand:@"make" withArguments:@[@"clean"]];
}

- (BOOL)cleanWithCMake
{
    return [self runCommand:@"cmake" withArguments:@[@"--build", @"build", @"--target", @"clean"]];
}

- (BOOL)testWithXcode
{
    NSString *projectPath = [_project projectPath];
    if (!projectPath) {
        return NO;
    }
    
    NSMutableArray *arguments = [NSMutableArray array];
    [arguments addObject:@"-project"];
    [arguments addObject:projectPath];
    [arguments addObject:@"-configuration"];
    [arguments addObject:_buildConfiguration];
    [arguments addObject:@"test"];
    
    return [self runCommand:@"xcodebuild" withArguments:arguments];
}

- (BOOL)testWithMake
{
    return [self runCommand:@"make" withArguments:@[@"test"]];
}

- (BOOL)archiveWithXcode
{
    NSString *projectPath = [_project projectPath];
    if (!projectPath) {
        return NO;
    }
    
    NSMutableArray *arguments = [NSMutableArray array];
    [arguments addObject:@"-project"];
    [arguments addObject:projectPath];
    [arguments addObject:@"-configuration"];
    [arguments addObject:@"Release"];
    [arguments addObject:@"archive"];
    
    return [self runCommand:@"xcodebuild" withArguments:arguments];
}

- (BOOL)archiveWithMake
{
    return [self runCommand:@"make" withArguments:@[@"install"]];
}

#pragma mark - Command Execution

- (BOOL)runCommand:(NSString *)command withArguments:(NSArray *)arguments
{
    if (!command) {
        return NO;
    }
    
    [self stop]; // Stop any current task
    
    _currentTask = [[NSTask alloc] init];
    [_currentTask setLaunchPath:command];
    [_currentTask setArguments:arguments];
    [_currentTask setEnvironment:_buildEnvironment];
    
    if (_project) {
        [_currentTask setCurrentDirectoryPath:[_project projectDirectoryPath]];
    }
    
    // Set up pipes for output
    _outputPipe = [[NSPipe alloc] init];
    _errorPipe = [[NSPipe alloc] init];
    [_currentTask setStandardOutput:_outputPipe];
    [_currentTask setStandardError:_errorPipe];
    
    // Set up output monitoring
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(taskDidTerminate:)
                                                 name:NSTaskDidTerminateNotification
                                               object:_currentTask];
    
    NSFileHandle *outputHandle = [_outputPipe fileHandleForReading];
    NSFileHandle *errorHandle = [_errorPipe fileHandleForReading];
    
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(outputDataAvailable:)
                                                 name:NSFileHandleReadCompletionNotification
                                               object:outputHandle];
    
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(errorDataAvailable:)
                                                 name:NSFileHandleReadCompletionNotification
                                               object:errorHandle];
    
    @try {
        [_currentTask launch];
        [outputHandle readInBackgroundAndNotify];
        [errorHandle readInBackgroundAndNotify];
        return YES;
    }
    @catch (NSException *exception) {
        NSLog(@"Failed to launch task: %@", exception);
        _status = YCodeBuildStatusFailed;
        return NO;
    }
}

- (NSString *)findExecutable
{
    // Look for built executable in common locations
    NSString *projectDir = [_project projectDirectoryPath];
    NSArray *searchPaths = @[
        [projectDir stringByAppendingPathComponent:@"build/Debug"],
        [projectDir stringByAppendingPathComponent:@"build/Release"],
        [projectDir stringByAppendingPathComponent:@"build"],
        [projectDir stringByAppendingPathComponent:@"obj"],
        projectDir
    ];
    
    NSFileManager *fileManager = [NSFileManager defaultManager];
    
    for (NSString *searchPath in searchPaths) {
        NSArray *contents = [fileManager contentsOfDirectoryAtPath:searchPath error:nil];
        for (NSString *item in contents) {
            NSString *itemPath = [searchPath stringByAppendingPathComponent:item];
            BOOL isDirectory;
            
            if ([fileManager fileExistsAtPath:itemPath isDirectory:&isDirectory] && !isDirectory) {
                // Check if it's executable
                if ([fileManager isExecutableFileAtPath:itemPath]) {
                    // Skip certain file types
                    NSString *extension = [itemPath pathExtension];
                    if (![extension isEqualToString:@"o"] && 
                        ![extension isEqualToString:@"a"] && 
                        ![extension isEqualToString:@"dylib"]) {
                        return itemPath;
                    }
                }
            }
        }
    }
    
    return nil;
}

- (BOOL)runExecutable:(NSString *)executablePath
{
    return [self runCommand:executablePath withArguments:@[]];
}

#pragma mark - Task Notifications

- (void)taskDidTerminate:(NSNotification *)notification
{
    NSTask *task = [notification object];
    int terminationStatus = [task terminationStatus];
    
    [[NSNotificationCenter defaultCenter] removeObserver:self
                                                     name:NSTaskDidTerminateNotification
                                                   object:task];
    
    BOOL success = (terminationStatus == 0);
    
    if (_status == YCodeBuildStatusBuilding) {
        _status = success ? YCodeBuildStatusSuccess : YCodeBuildStatusFailed;
        if ([_delegate respondsToSelector:@selector(buildSystemDidFinishBuild:success:)]) {
            [_delegate buildSystemDidFinishBuild:self success:success];
        }
    } else if (_status == YCodeBuildStatusRunning) {
        _status = YCodeBuildStatusIdle;
        if ([_delegate respondsToSelector:@selector(buildSystemDidFinishRun:)]) {
            [_delegate buildSystemDidFinishRun:self];
        }
    } else if (_status == YCodeBuildStatusCleaning) {
        _status = success ? YCodeBuildStatusIdle : YCodeBuildStatusFailed;
        if ([_delegate respondsToSelector:@selector(buildSystemDidFinishClean:)]) {
            [_delegate buildSystemDidFinishClean:self];
        }
    }
    
    RELEASE(_currentTask);
    _currentTask = nil;
    RELEASE(_outputPipe);
    _outputPipe = nil;
    RELEASE(_errorPipe);
    _errorPipe = nil;
}

- (void)outputDataAvailable:(NSNotification *)notification
{
    NSFileHandle *fileHandle = [notification object];
    NSData *data = [[notification userInfo] objectForKey:NSFileHandleNotificationDataItem];
    
    if ([data length] > 0) {
        NSString *output = [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding];
        [_buildOutput appendString:output];
        
        if ([_delegate respondsToSelector:@selector(buildSystem:didReceiveOutput:)]) {
            [_delegate buildSystem:self didReceiveOutput:output];
        }
        
        RELEASE(output);
        [fileHandle readInBackgroundAndNotify];
    }
}

- (void)errorDataAvailable:(NSNotification *)notification
{
    NSFileHandle *fileHandle = [notification object];
    NSData *data = [[notification userInfo] objectForKey:NSFileHandleNotificationDataItem];
    
    if ([data length] > 0) {
        NSString *error = [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding];
        [_buildErrors appendString:error];
        
        if ([_delegate respondsToSelector:@selector(buildSystem:didReceiveError:)]) {
            [_delegate buildSystem:self didReceiveError:error];
        }
        
        RELEASE(error);
        [fileHandle readInBackgroundAndNotify];
    }
}

#pragma mark - Build Output

- (NSString *)buildOutput
{
    return _buildOutput;
}

- (NSString *)buildErrors
{
    return _buildErrors;
}

- (void)clearOutput
{
    [_buildOutput setString:@""];
    [_buildErrors setString:@""];
}

#pragma mark - Build Environment

- (NSDictionary *)buildEnvironment
{
    return _buildEnvironment;
}

- (void)setBuildEnvironment:(NSDictionary *)environment
{
    [_buildEnvironment setDictionary:environment];
}

- (void)setEnvironmentVariable:(NSString *)value forKey:(NSString *)key
{
    if (key && value) {
        [_buildEnvironment setObject:value forKey:key];
    }
}

#pragma mark - Build System Detection

- (NSString *)detectedBuildSystem
{
    if ([self hasXcodeProject]) {
        return @"xcode";
    } else if ([self hasGNUmakefile]) {
        return @"gnumake";
    } else if ([self hasCMakeLists]) {
        return @"cmake";
    } else if ([self hasMakefile]) {
        return @"make";
    }
    
    return @"unknown";
}

- (BOOL)hasXcodeProject
{
    NSString *projectPath = [_project projectPath];
    return projectPath && [[projectPath pathExtension] isEqualToString:@"xcodeproj"];
}

- (BOOL)hasMakefile
{
    NSString *projectDir = [_project projectDirectoryPath];
    if (!projectDir) return NO;
    
    NSString *makefilePath = [projectDir stringByAppendingPathComponent:@"Makefile"];
    return [[NSFileManager defaultManager] fileExistsAtPath:makefilePath];
}

- (BOOL)hasCMakeLists
{
    NSString *projectDir = [_project projectDirectoryPath];
    if (!projectDir) return NO;
    
    NSString *cmakeListsPath = [projectDir stringByAppendingPathComponent:@"CMakeLists.txt"];
    return [[NSFileManager defaultManager] fileExistsAtPath:cmakeListsPath];
}

- (BOOL)hasGNUmakefile
{
    NSString *projectDir = [_project projectDirectoryPath];
    if (!projectDir) return NO;
    
    NSString *gnumakefilePath = [projectDir stringByAppendingPathComponent:@"GNUmakefile"];
    return [[NSFileManager defaultManager] fileExistsAtPath:gnumakefilePath];
}

@end