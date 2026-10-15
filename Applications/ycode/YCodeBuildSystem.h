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

#ifndef _YCODEBUILDSYSTEM_H_
#define _YCODEBUILDSYSTEM_H_

#import <Foundation/Foundation.h>
#import "YCodeDebugger.h"

@class YCodeProject;

typedef enum {
    YCodeBuildStatusIdle,
    YCodeBuildStatusBuilding,
    YCodeBuildStatusRunning,
    YCodeBuildStatusCleaning,
    YCodeBuildStatusTesting,
    YCodeBuildStatusSuccess,
    YCodeBuildStatusFailed,
    YCodeBuildStatusCancelled
} YCodeBuildStatus;

@protocol YCodeBuildSystemDelegate <NSObject>
@end

/* Informal delegate methods are dispatched only when implemented. */
@interface NSObject (YCodeBuildSystemDelegate)
- (void)buildSystem:(id)buildSystem didReceiveDebuggerOutput:(NSString *)output;
- (void)buildSystem:(id)buildSystem stoppedAtFile:(NSString *)file line:(NSUInteger)line;
- (void)buildSystemDidStartBuild:(id)buildSystem;
- (void)buildSystemDidFinishBuild:(id)buildSystem success:(BOOL)success;
- (void)buildSystemDidStartRun:(id)buildSystem;
- (void)buildSystemDidFinishRun:(id)buildSystem;
- (void)buildSystemDidStartTests:(id)buildSystem;
- (void)buildSystemDidFinishTests:(id)buildSystem success:(BOOL)success;
- (void)buildSystemDidStartClean:(id)buildSystem;
- (void)buildSystemDidFinishClean:(id)buildSystem;
- (void)buildSystemDidCancel:(id)buildSystem;
- (void)buildSystem:(id)buildSystem didReceiveOutput:(NSString *)output;
- (void)buildSystem:(id)buildSystem didReceiveError:(NSString *)error;

@end

@interface YCodeBuildSystem : NSObject <YCodeDebuggerDelegate>
{
    YCodeProject *_project;
    YCodeBuildStatus _status;
    
    NSTask *_currentTask;
    NSPipe *_outputPipe;
    NSPipe *_errorPipe;
    BOOL _runAfterBuild;
    BOOL _testAfterBuild;
    BOOL _testFailed;
    NSMutableArray *_testBundles;
    BOOL _debugAfterBuild;
    BOOL _debugging;
    NSPipe *_inputPipe;
    YCodeDebugger *_debugger;
    BOOL _configureBeforeBuild;
    BOOL _taskTerminated;
    BOOL _outputClosed;
    BOOL _errorClosed;
    int _terminationStatus;
    
    id<YCodeBuildSystemDelegate> _delegate;
    
    // Build configuration
    NSString *_buildConfiguration;
    NSString *_targetName;
    NSString *_scheme;
    
    // Build output
    NSMutableString *_buildOutput;
    NSMutableString *_buildErrors;
    
    // Build environment
    NSMutableDictionary *_buildEnvironment;
}

/**
 * Initialization
 */
/** Architecture selection is persisted per project; nil uses the native toolchain. */
+ (NSString *)hostArchitecture;
- (NSString *)architecture;
- (void)setArchitecture:(NSString *)architecture;
- (NSArray *)availableArchitectures;

- (id)initWithProject:(YCodeProject *)project;

/**
 * Project association
 */
- (YCodeProject *)project;
- (void)setProject:(YCodeProject *)project;

/**
 * Delegate
 */
- (id<YCodeBuildSystemDelegate>)delegate;
- (void)setDelegate:(id<YCodeBuildSystemDelegate>)delegate;

/**
 * Build status
 */
- (YCodeBuildStatus)status;
- (BOOL)isBuilding;
- (BOOL)isRunning;
- (BOOL)isBusy;

/**
 * Build configuration
 */
- (NSString *)buildConfiguration;
- (void)setBuildConfiguration:(NSString *)configuration;
- (NSString *)targetName;
- (NSString *)findExecutable;
- (void)setTargetName:(NSString *)name;
- (NSString *)scheme;
- (void)setScheme:(NSString *)scheme;

/**
 * Build operations
 */
- (BOOL)build;
- (BOOL)clean;
/** Build the runnable target, then launch it only if the build succeeds. */
- (BOOL)run;
/** Build then open a GDB/MI session for the selected executable. */
- (BOOL)debug;
- (YCodeDebugger *)debugger;
- (BOOL)isDebugging;
- (BOOL)test;
- (BOOL)archive;
- (void)stop;

/**
 * Build output
 */
- (NSString *)buildOutput;
- (NSString *)buildErrors;
- (void)clearOutput;

/**
 * Build environment
 */
- (NSDictionary *)buildEnvironment;
- (void)setBuildEnvironment:(NSDictionary *)environment;
- (void)setEnvironmentVariable:(NSString *)value forKey:(NSString *)key;

/**
 * Build system detection
 */
- (NSString *)detectedBuildSystem;
- (BOOL)hasXcodeProject;
- (BOOL)hasMakefile;
- (BOOL)hasCMakeLists;
- (BOOL)hasGNUmakefile;

@end

#endif // _YCODEBUILDSYSTEM_H_
