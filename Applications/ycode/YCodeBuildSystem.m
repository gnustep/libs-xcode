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
#import <XCode/XCode.h>

@interface YCodeBuildSystem (Private)
- (BOOL)runCommand:(NSString *)command withArguments:(NSArray *)arguments;
- (BOOL)launchProduct;
- (BOOL)launchNextTestBundle;
- (NSString *)testHostProductForTarget:(PBXTarget *)target;
- (NSString *)findExecutable;
- (PBXNativeTarget *)runnableTarget;
- (void)releaseTask;
- (void)finishTaskIfReady;
- (void)reportError:(NSString *)message;
@end

@implementation YCodeBuildSystem

- (id)initWithProject:(YCodeProject *)project
{
    self = [super init];
    if (self) {
        _project = project; // Owned by the project.
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
    _delegate = nil;
    [self stop];
    [self releaseTask];
    RELEASE(_buildConfiguration);
    RELEASE(_targetName);
    RELEASE(_scheme);
    RELEASE(_testBundles);
    RELEASE(_buildOutput);
    RELEASE(_buildErrors);
    RELEASE(_buildEnvironment);
    [_debugger setDelegate:nil];
    RELEASE(_debugger);
    [super dealloc];
}

- (void)setupDefaultEnvironment
{
    // Set up default build environment
    NSProcessInfo *processInfo = [NSProcessInfo processInfo];
    NSMutableDictionary *environment = [[processInfo environment] mutableCopy];
    
    // Add common build tools to PATH if needed
    NSString *path = [environment objectForKey:@"PATH"] ?: @"";
    NSArray *additionalPaths = [NSArray arrayWithObjects:
        @"/usr/local/bin", @"/opt/local/bin", @"/usr/bin", @"/bin", nil];
    
    {
      NSEnumerator *additionalPathEnumerator = [additionalPaths objectEnumerator];
      NSString *additionalPath;
      while ((additionalPath = [additionalPathEnumerator nextObject]) != nil)
        {
          if (![path containsString:additionalPath]) {
              path = [path stringByAppendingFormat:@":%@", additionalPath];
          }
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
    if (_project != project) {
        [self stop];
        [_debugger setDelegate:nil];
        RELEASE(_debugger); _debugger = nil;
    }
    _project = project;
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
    return _currentTask != nil || _status == YCodeBuildStatusBuilding ||
           _status == YCodeBuildStatusRunning || 
           _status == YCodeBuildStatusCleaning || _status == YCodeBuildStatusTesting;
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
    
    if (![[_project projectDirectoryPath] length]) {
        _status = YCodeBuildStatusFailed;
        [self reportError:@"No project directory is available.\n"];
        return NO;
    }
    NSString *buildSystem = [self detectedBuildSystem];
    BOOL success = NO;
    
    _status = YCodeBuildStatusBuilding;
    [self clearOutput];
    
    if ([_delegate respondsToSelector:@selector(buildSystemDidStartBuild:)]) {
        [(id)_delegate buildSystemDidStartBuild:self];
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
    
    if (![[_project projectDirectoryPath] length]) {
        _status = YCodeBuildStatusFailed;
        [self reportError:@"No project directory is available.\n"];
        return NO;
    }
    NSString *buildSystem = [self detectedBuildSystem];
    BOOL success = NO;
    
    _status = YCodeBuildStatusCleaning;
    [self clearOutput];
    
    if ([_delegate respondsToSelector:@selector(buildSystemDidStartClean:)]) {
        [(id)_delegate buildSystemDidStartClean:self];
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

- (YCodeDebugger *)debugger
{
    if (!_debugger) {
        _debugger = [YCodeDebugger new];
        [_debugger setDelegate:self];
        [_debugger setSourceDirectory:[_project projectDirectoryPath]];
        if ([_project projectPath]) [_debugger setBreakpointStorageKey:
            [@"YCodeBreakpoints:" stringByAppendingString:[[_project projectPath] stringByStandardizingPath]]];
    }
    return _debugger;
}

- (BOOL)isDebugging { return _debugging; }

- (BOOL)debug
{
    if ([self isBusy]) return NO;
    _debugAfterBuild = YES;
    if (![self run]) { _debugAfterBuild = NO; return NO; }
    return YES;
}

- (void)debugger:(YCodeDebugger *)debugger sendCommand:(NSString *)command
{
    if (!_debugging || !_inputPipe || ![_currentTask isRunning]) return;
    @try {
        [[_inputPipe fileHandleForWriting] writeData:[command dataUsingEncoding:NSUTF8StringEncoding]];
    } @catch (NSException *exception) {
        [self reportError:[NSString stringWithFormat:@"Debugger input failed: %@\n", [exception reason]]];
    }
}

- (void)debugger:(YCodeDebugger *)debugger output:(NSString *)output
{
    [_buildOutput appendString:output];
    if ([_delegate respondsToSelector:@selector(buildSystem:didReceiveDebuggerOutput:)])
        [(id)_delegate buildSystem:self didReceiveDebuggerOutput:output];
    else if ([_delegate respondsToSelector:@selector(buildSystem:didReceiveOutput:)])
        [(id)_delegate buildSystem:self didReceiveOutput:output];
}

- (void)debugger:(YCodeDebugger *)debugger targetOutput:(NSString *)output
{
    [_buildOutput appendString:output];
    if ([_delegate respondsToSelector:@selector(buildSystem:didReceiveOutput:)])
        [(id)_delegate buildSystem:self didReceiveOutput:output];
}

- (void)debugger:(YCodeDebugger *)debugger stoppedAtFile:(NSString *)file line:(NSUInteger)line
{
    if (![file isAbsolutePath]) file = [[_project projectDirectoryPath] stringByAppendingPathComponent:file];
    if ([_delegate respondsToSelector:@selector(buildSystem:stoppedAtFile:line:)])
        [(id)_delegate buildSystem:self stoppedAtFile:file line:line];
}

- (BOOL)run
{
    if ([self isBusy]) return NO;
    if (![self runnableTarget] && !([_project isDirectoryProject] &&
        [[[_project settings] objectForKey:@"Executable"] isKindOfClass:[NSString class]] &&
        [[[_project settings] objectForKey:@"Executable"] length])) {
        [self clearOutput];
        _status = YCodeBuildStatusFailed;
        [self reportError:[_project isDirectoryProject]
            ? @"Set Executable in .ycode.plist and reopen the folder to enable Run and Debug.\n"
            : @"The project has no runnable application or command-line target.\n"];
        return NO;
    }
    _runAfterBuild = YES;
    if (![self build]) {
        _runAfterBuild = NO;
        return NO;
    }
    return YES;
}

- (BOOL)launchProduct
{
    BOOL debug = _debugAfterBuild;
    _debugAfterBuild = NO;
    NSString *executablePath = [self findExecutable];
    if (!executablePath) {
        _status = YCodeBuildStatusFailed;
        [self reportError:@"Build succeeded, but the target executable could not be found.\n"];
        if ([_delegate respondsToSelector:@selector(buildSystemDidFinishRun:)])
            [(id)_delegate buildSystemDidFinishRun:self];
        return NO;
    }
    _status = YCodeBuildStatusRunning;
    _debugging = debug;
    if ([_delegate respondsToSelector:@selector(buildSystemDidStartRun:)])
        [(id)_delegate buildSystemDidStartRun:self];
    if (debug) {
        _debugging = YES;
        [[self debugger] reset];
        NSString *path = [[NSUserDefaults standardUserDefaults] stringForKey:@"DebuggerPath"];
        if (![path length]) path = @"gdb";
        return [self runCommand:path withArguments:[NSArray arrayWithObjects:
            @"--interpreter=mi2", @"--quiet", @"--nx", @"-f", executablePath, nil]];
    }
    return [self runCommand:executablePath withArguments:[NSArray array]];
}

- (BOOL)test
{
    if ([self isBusy] || ![[_project projectDirectoryPath] length]) return NO;
    [self clearOutput];
    _testFailed = NO;
    _status = YCodeBuildStatusTesting;
    if ([_delegate respondsToSelector:@selector(buildSystemDidStartTests:)])
        [(id)_delegate buildSystemDidStartTests:self];
    if ([[self detectedBuildSystem] isEqualToString:@"xcode"]) {
#ifdef GNUSTEP
        RELEASE(_testBundles);
        _testBundles = [NSMutableArray new];
        NSEnumerator *enumerator = [[[_project project] targets] objectEnumerator];
        PBXTarget *target;
        while ((target = [enumerator nextObject]) != nil) {
            if (_targetName && ![[target name] isEqual:_targetName]) continue;
            if (![target isKindOfClass:[PBXNativeTarget class]] ||
                ![[target productType] isEqual:@"com.apple.product-type.bundle.unit-test"]) continue;
            NSString *product = [[(PBXNativeTarget *)target productReference] path];
            if (![product length]) continue;
            NSString *path = [[[_project projectDirectoryPath]
                stringByAppendingPathComponent:[NSString stringWithFormat:@"build/%@/Products", [target name]]]
                stringByAppendingPathComponent:product];
            NSMutableDictionary *test = [NSMutableDictionary dictionaryWithObject:path forKey:@"bundle"];
            NSString *host = [self testHostProductForTarget:target];
            if (host) [test setObject:host forKey:@"host"];
            [_testBundles addObject:test];
        }
        if (![_testBundles count]) {
            _status = YCodeBuildStatusFailed;
            [self reportError:@"No XCTest targets are available.\n"];
            if ([_delegate respondsToSelector:@selector(buildSystemDidFinishTests:success:)])
                [(id)_delegate buildSystemDidFinishTests:self success:NO];
            return NO;
        }
        _testAfterBuild = YES;
        return [self buildWithXcode];
#else
        return [self testWithXcode];
#endif
    }
    return [self testWithMake];
}

- (NSString *)testHostProductForTarget:(PBXTarget *)target
{
    XCBuildConfiguration *configuration = [[target buildConfigurationList]
        configurationWithName:_buildConfiguration];
    if (!configuration) configuration = [[target buildConfigurationList] defaultConfiguration];
    NSString *host = [[configuration buildSettings] objectForKey:@"TEST_HOST"];
    if (!host) {
        configuration = [[[_project project] buildConfigurationList] configurationWithName:_buildConfiguration];
        host = [[configuration buildSettings] objectForKey:@"TEST_HOST"];
    }
    if (![host isKindOfClass:[NSString class]] || ![host length]) return nil;
    NSEnumerator *targets = [[[_project project] targets] objectEnumerator];
    PBXTarget *candidate;
    while ((candidate = [targets nextObject]) != nil) {
        if (![candidate isKindOfClass:[PBXNativeTarget class]] ||
            ![[candidate productType] isEqual:@"com.apple.product-type.application"]) continue;
        NSString *product = [[(PBXNativeTarget *)candidate productReference] path];
        if (![product length]) continue;
        BOOL matches = [[host pathComponents] containsObject:product];
        NSEnumerator *dependencies = [[target dependencies] objectEnumerator];
        PBXTargetDependency *dependency;
        while ((dependency = [dependencies nextObject]) != nil)
            if ([dependency target] == candidate) matches = YES;
        if (matches) return [[[_project projectDirectoryPath] stringByAppendingPathComponent:
            [NSString stringWithFormat:@"build/%@/Products", [candidate name]]]
            stringByAppendingPathComponent:product];
    }
    // Preserve an unresolved host as a failure, rather than running hosted tests standalone.
    return host;
}

- (BOOL)launchNextTestBundle
{
    if (![_testBundles count]) return NO;
    NSDictionary *test = [[[_testBundles objectAtIndex:0] retain] autorelease];
    [_testBundles removeObjectAtIndex:0];
    NSString *path = [test objectForKey:@"bundle"];
    NSString *host = [test objectForKey:@"host"];
    if (!host) return [self runCommand:@"xctest" withArguments:[NSArray arrayWithObject:path]];

    NSString *helper = [[NSBundle mainBundle] pathForResource:@"YCodeTestHost" ofType:@"bundle"];
    NSString *executable = [[NSBundle bundleWithPath:host] executablePath];
    if (![executable length]) executable = [host stringByAppendingPathComponent:
        [[host lastPathComponent] stringByDeletingPathExtension]];
    if (!helper || ![[NSFileManager defaultManager] isExecutableFileAtPath:executable]) {
        [self reportError:[NSString stringWithFormat:
            @"Cannot start hosted XCTest: host application or YCodeTestHost helper is missing (%@).\n", host]];
        _testFailed = YES;
        [_testBundles removeAllObjects];
        _status = YCodeBuildStatusFailed;
        if ([_delegate respondsToSelector:@selector(buildSystemDidFinishTests:success:)])
            [(id)_delegate buildSystemDidFinishTests:self success:NO];
        return NO;
    }
    return [self runCommand:executable withArguments:[NSArray arrayWithObjects:
        @"-GSAppKitUserBundles", [[NSArray arrayWithObject:helper] description],
        @"-YCodeTestBundle", path, nil]];
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
    _testAfterBuild = NO;
    [_testBundles removeAllObjects];
    _debugAfterBuild = NO;
    if (_debugging) {
        [_debugger command:@"-gdb-exit"];
        [_debugger reset];
    }
    _runAfterBuild = NO;
    _configureBeforeBuild = NO;
    if (_currentTask && _status != YCodeBuildStatusCancelled) {
        _status = YCodeBuildStatusCancelled;
        if ([_currentTask isRunning]) [_currentTask terminate];
        if ([_delegate respondsToSelector:@selector(buildSystemDidCancel:)])
            [(id)_delegate buildSystemDidCancel:self];
    }
}

- (NSString *)xcodeCommand
{
#ifdef GNUSTEP
    return @"buildtool";
#else
    return @"xcodebuild";
#endif
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
    
    NSString *target = _targetName;
    if (_runAfterBuild && !target && !_scheme) target = [[self runnableTarget] name];
    if (target) {
        [arguments addObject:@"-target"];
        [arguments addObject:target];
    }
    if (_scheme) {
        [arguments addObject:@"-scheme"];
        [arguments addObject:_scheme];
    }
    
    [arguments addObject:@"build"];
    
    return [self runCommand:[self xcodeCommand] withArguments:arguments];
}

- (NSArray *)makeArgumentsForSetting:(NSString *)key defaultTarget:(NSString *)fallback
{
    NSMutableArray *arguments = [NSMutableArray array];
    id target = [_project isDirectoryProject] ? [[_project settings] objectForKey:key] : nil;
    if ([_project isDirectoryProject] && [key isEqual:@"BuildTarget"] && [_targetName length]) target = _targetName;
    if (![target isKindOfClass:[NSString class]] || ![target length]) target = fallback;
    if (target) {
        [arguments addObject:@"--"];
        [arguments addObject:target];
    }
    return arguments;
}

- (BOOL)buildWithMake
{
    return [self runCommand:@"make" withArguments:[self makeArgumentsForSetting:@"BuildTarget" defaultTarget:nil]];
}

- (BOOL)buildWithGNUMake
{
    NSMutableArray *arguments = [NSMutableArray array];
    if ([_buildConfiguration isEqual:@"Debug"]) [arguments addObject:@"debug=yes"];
    else if ([_buildConfiguration isEqual:@"Release"]) [arguments addObject:@"debug=no"];
    [arguments addObjectsFromArray:[self makeArgumentsForSetting:@"BuildTarget" defaultTarget:nil]];
    return [self runCommand:@"make" withArguments:arguments];
}

- (BOOL)buildWithCMake
{
    NSString *cache = [[_project projectDirectoryPath]
        stringByAppendingPathComponent:@"build/CMakeCache.txt"];
    if (![[NSFileManager defaultManager] fileExistsAtPath:cache]) {
        _configureBeforeBuild = YES;
        return [self runCommand:@"cmake" withArguments:
            [NSArray arrayWithObjects:@"-S", @".", @"-B", @"build", nil]];
    }
    return [self runCommand:@"cmake" withArguments:
        [NSArray arrayWithObjects:@"--build", @"build", nil]];
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
    
    return [self runCommand:[self xcodeCommand] withArguments:arguments];
}

- (BOOL)cleanWithMake
{
    return [self runCommand:@"make" withArguments:[self makeArgumentsForSetting:@"CleanTarget" defaultTarget:@"clean"]];
}

- (BOOL)cleanWithGNUMake
{
    return [self runCommand:@"make" withArguments:[self makeArgumentsForSetting:@"CleanTarget" defaultTarget:@"clean"]];
}

- (BOOL)cleanWithCMake
{
    return [self runCommand:@"cmake" withArguments:
        [NSArray arrayWithObjects:@"--build", @"build", @"--target", @"clean", nil]];
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
    if (_scheme) [arguments addObjectsFromArray:[NSArray arrayWithObjects:@"-scheme", _scheme, nil]];
    if (_targetName) [arguments addObjectsFromArray:[NSArray arrayWithObjects:@"-target", _targetName, nil]];
    [arguments addObject:@"test"];
    
    return [self runCommand:[self xcodeCommand] withArguments:arguments];
}

- (BOOL)testWithMake
{
    return [self runCommand:@"make" withArguments:[self makeArgumentsForSetting:@"TestTarget" defaultTarget:
        [self hasGNUmakefile] ? @"check" : @"test"]];
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
    
    return [self runCommand:[self xcodeCommand] withArguments:arguments];
}

- (BOOL)archiveWithMake
{
    return [self runCommand:@"make" withArguments:[NSArray arrayWithObject:@"install"]];
}

#pragma mark - Command Execution

- (BOOL)runCommand:(NSString *)command withArguments:(NSArray *)arguments
{
    if (!command) {
        return NO;
    }
    
    if (_currentTask) return NO;
    _taskTerminated = _outputClosed = _errorClosed = NO;
    
    _currentTask = [[NSTask alloc] init];
#ifdef _WIN32
    [_currentTask setLaunchPath:command];
    [_currentTask setArguments:arguments];
#else
    // env resolves tool names using the same PATH as the child environment.
    if ([command isAbsolutePath]) {
        [_currentTask setLaunchPath:command];
        [_currentTask setArguments:arguments];
    } else {
        [_currentTask setLaunchPath:@"/usr/bin/env"];
        NSMutableArray *resolvedArguments = [NSMutableArray arrayWithObject:command];
        [resolvedArguments addObjectsFromArray:arguments];
        [_currentTask setArguments:resolvedArguments];
    }
#endif
    [_currentTask setEnvironment:_buildEnvironment];
    
    if (_project) {
        [_currentTask setCurrentDirectoryPath:[_project projectDirectoryPath]];
    }
    
    if (_debugging) {
        _inputPipe = [NSPipe new];
        [_currentTask setStandardInput:_inputPipe];
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
        [self reportError:[NSString stringWithFormat:@"Failed to launch %@: %@\n",
            command, [exception reason]]];
        _taskTerminated = _outputClosed = _errorClosed = YES;
        _terminationStatus = 1;
        [self finishTaskIfReady];
        return NO;
    }
}

- (PBXNativeTarget *)runnableTarget
{
    NSString *selection = _targetName ?: _scheme;
    {
      NSEnumerator *targetEnumerator = [[[_project project] targets] objectEnumerator];
      PBXTarget *target;
      while ((target = [targetEnumerator nextObject]) != nil)
        {
          if (selection && ![[target name] isEqualToString:selection]) continue;
          if ([target isKindOfClass:[PBXNativeTarget class]] &&
              ([[target productType] isEqualToString:@"com.apple.product-type.application"] ||
               [[target productType] isEqualToString:@"com.apple.product-type.tool"]))
              return (PBXNativeTarget *)target;
        }
    }
    return nil;
}

- (NSString *)findExecutable
{
    if ([_project isDirectoryProject]) {
        id path = [[_project settings] objectForKey:@"Executable"];
        if (![path isKindOfClass:[NSString class]] || ![path length]) return nil;
        if (![path isAbsolutePath]) path = [[_project projectDirectoryPath] stringByAppendingPathComponent:path];
        BOOL directory = NO;
        NSFileManager *manager = [NSFileManager defaultManager];
        return [manager fileExistsAtPath:path isDirectory:&directory] && !directory &&
            [manager isExecutableFileAtPath:path] ? path : nil;
    }
    PBXNativeTarget *target = [self runnableTarget];
    NSString *product = [[target productReference] path];
    NSString *directory = [_project projectDirectoryPath];
    if (!target || !product || !directory) return nil;
    NSArray *roots = [NSArray arrayWithObjects:
        [directory stringByAppendingPathComponent:[NSString stringWithFormat:
            @"build/%@/Products", [target name]]],
        [directory stringByAppendingPathComponent:[@"build" stringByAppendingPathComponent:_buildConfiguration]],
        [directory stringByAppendingPathComponent:@"build"],
        [directory stringByAppendingPathComponent:@"obj"], directory, nil];
    NSFileManager *manager = [NSFileManager defaultManager];
    {
      NSEnumerator *rootEnumerator = [roots objectEnumerator];
      NSString *root;
      while ((root = [rootEnumerator nextObject]) != nil)
        {
          NSString *path = [root stringByAppendingPathComponent:product];
          if ([[product pathExtension] isEqualToString:@"app"]) {
              NSString *executable = [[NSBundle bundleWithPath:path] executablePath];
              if (executable && [manager isExecutableFileAtPath:executable]) return executable;
              NSString *name = [[product lastPathComponent] stringByDeletingPathExtension];
              NSArray *relativePaths = [NSArray arrayWithObjects:
                  [@"Contents/MacOS" stringByAppendingPathComponent:name], name, nil];
              {
                NSEnumerator *relativeEnumerator = [relativePaths objectEnumerator];
                NSString *relative;
                while ((relative = [relativeEnumerator nextObject]) != nil)
                  {
                    executable = [path stringByAppendingPathComponent:relative];
                    if ([manager isExecutableFileAtPath:executable]) return executable;
                  }
              }
          } else {
              BOOL directoryFlag = NO;
              if ([manager fileExistsAtPath:path isDirectory:&directoryFlag] &&
                  !directoryFlag && [manager isExecutableFileAtPath:path]) return path;
          }
        }
    }
    return nil;
}

#pragma mark - Task Notifications

- (void)releaseTask
{
    NSNotificationCenter *center = [NSNotificationCenter defaultCenter];
    if (_currentTask) [center removeObserver:self name:nil object:_currentTask];
    if (_outputPipe) [center removeObserver:self name:nil object:[_outputPipe fileHandleForReading]];
    if (_errorPipe) [center removeObserver:self name:nil object:[_errorPipe fileHandleForReading]];
    RELEASE(_inputPipe); _inputPipe = nil;
    _debugging = NO;
    [_debugger reset];
    RELEASE(_currentTask); _currentTask = nil;
    RELEASE(_outputPipe); _outputPipe = nil;
    RELEASE(_errorPipe); _errorPipe = nil;
}

- (void)taskDidTerminate:(NSNotification *)notification
{
    if ([notification object] != _currentTask) return;
    _terminationStatus = [_currentTask terminationStatus];
    _taskTerminated = YES;
    [self finishTaskIfReady];
}

- (void)finishTaskIfReady
{
    if (!_taskTerminated || !_outputClosed || !_errorClosed) return;
    BOOL success = (_terminationStatus == 0);
    YCodeBuildStatus operation = _status;
    BOOL launch = _runAfterBuild && success && operation == YCodeBuildStatusBuilding;
    [self releaseTask];
    if (_configureBeforeBuild && success && operation == YCodeBuildStatusBuilding) {
        _configureBeforeBuild = NO;
        [self runCommand:@"cmake" withArguments:
            [NSArray arrayWithObjects:@"--build", @"build", nil]];
        return;
    }
    _configureBeforeBuild = NO;
    _runAfterBuild = NO;
    if (!launch) _debugAfterBuild = NO;
    if (operation == YCodeBuildStatusCancelled) return;
    _status = success ? YCodeBuildStatusSuccess : YCodeBuildStatusFailed;
    if (operation == YCodeBuildStatusTesting) {
        BOOL built = _testAfterBuild;
        _testAfterBuild = NO;
        if (!success) _testFailed = YES;
        if ((!built || success) && [_testBundles count]) {
            _status = YCodeBuildStatusTesting;
            [self launchNextTestBundle];
            return;
        }
        [_testBundles removeAllObjects];
        _status = _testFailed ? YCodeBuildStatusFailed : YCodeBuildStatusSuccess;
        if ([_delegate respondsToSelector:@selector(buildSystemDidFinishTests:success:)])
            [(id)_delegate buildSystemDidFinishTests:self success:!_testFailed];
    } else if (operation == YCodeBuildStatusBuilding) {
        if ([_delegate respondsToSelector:@selector(buildSystemDidFinishBuild:success:)])
            [(id)_delegate buildSystemDidFinishBuild:self success:success];
        if (launch) [self launchProduct];
    } else if (operation == YCodeBuildStatusRunning) {
        if (success) _status = YCodeBuildStatusIdle;
        if ([_delegate respondsToSelector:@selector(buildSystemDidFinishRun:)])
            [(id)_delegate buildSystemDidFinishRun:self];
    } else if (operation == YCodeBuildStatusCleaning) {
        if ([_delegate respondsToSelector:@selector(buildSystemDidFinishClean:)])
            [(id)_delegate buildSystemDidFinishClean:self];
    }
}

- (void)reportError:(NSString *)message
{
    [_buildErrors appendString:message];
    if ([_delegate respondsToSelector:@selector(buildSystem:didReceiveError:)])
        [(id)_delegate buildSystem:self didReceiveError:message];
}

- (void)receiveData:(NSNotification *)notification error:(BOOL)isError
{
    NSFileHandle *handle = [notification object];
    NSFileHandle *expected = isError ? [_errorPipe fileHandleForReading] : [_outputPipe fileHandleForReading];
    if (handle != expected) return;
    NSData *data = [[notification userInfo] objectForKey:NSFileHandleNotificationDataItem];
    if ([data length] == 0) {
        if (isError) _errorClosed = YES; else _outputClosed = YES;
        [self finishTaskIfReady];
        return;
    }
    if (_debugging && !isError) {
        [_debugger receiveData:data];
        [handle readInBackgroundAndNotify];
        return;
    }
    NSString *output = AUTORELEASE([[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding]);
    if (!output) output = AUTORELEASE([[NSString alloc] initWithData:data encoding:NSISOLatin1StringEncoding]);
    if (isError) {
        [self reportError:output];
    } else {
        [_buildOutput appendString:output];
        if ([_delegate respondsToSelector:@selector(buildSystem:didReceiveOutput:)])
            [(id)_delegate buildSystem:self didReceiveOutput:output];
    }
    [handle readInBackgroundAndNotify];
}

- (void)outputDataAvailable:(NSNotification *)notification
{
    [self receiveData:notification error:NO];
}

- (void)errorDataAvailable:(NSNotification *)notification
{
    [self receiveData:notification error:YES];
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
    if ([_project isDirectoryProject]) return [self hasGNUmakefile] ? @"gnumake" : @"make";
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
    return [[NSFileManager defaultManager] fileExistsAtPath:makefilePath] ||
        [[NSFileManager defaultManager] fileExistsAtPath:[projectDir stringByAppendingPathComponent:@"makefile"]];
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
