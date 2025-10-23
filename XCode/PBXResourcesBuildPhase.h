/*
   Copyright (C) 2018, 2019, 2020, 2021 Free Software Foundation, Inc.

   Written by: Gregory John Casamento <greg.casamento@gmail.com>
   Date: 2022
   
   This file is part of the GNUstep XCode Library

   This library is free software; you can redistribute it and/or
   modify it under the terms of the GNU Lesser General Public
   License as published by the Free Software Foundation; either
   version 2 of the License, or (at your option) any later version.
   
   This library is distributed in the hope that it will be useful,
   but WITHOUT ANY WARRANTY; without even the implied warranty of
   MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
   Lesser General Public License for more details.
   
   You should have received a copy of the GNU Lesser General Public
   License along with this library; if not, write to the Free
   Software Foundation, Inc., 51 Franklin Street, Fifth Floor,
   Boston, MA 02110 USA.
*/

#import <Foundation/Foundation.h>

// Local includes
#import "PBXCoder.h"
#import "PBXBuildPhase.h"

// Forward declarations
@class XCBuildConfiguration;

@interface PBXResourcesBuildPhase : PBXBuildPhase

/**
 * Discovers the app icon filename from the Assets.xcassets directory.
 * Searches for a 32x32@1x icon in the AppIcon.appiconset Contents.json file.
 * Returns the filename of the discovered app icon, or nil if none found.
 */
- (NSString *) discoverAppIcon;

/**
 * Discovers the full path to the app icon file.
 * Combines the Assets.xcassets directory path with the discovered icon filename.
 * Returns the complete path to the app icon file, or nil if no icon is found.
 */
- (NSString *) discoverAppIconPath;

/**
 * Copies the specified icon file from Assets.xcassets to the resources directory.
 * Creates the resources directory if it doesn't exist and handles file overwriting.
 * Takes the name of the icon file to copy as parameter.
 * Returns YES if the copy operation succeeded, NO otherwise.
 */
- (BOOL) copyAppIconToResources: (NSString *)iconFilename;

/**
 * Escapes special characters in filenames for makefile compatibility.
 * Handles spaces, dollar signs, hash symbols, and colons that have special 
 * meaning in makefiles. Takes the filename to escape as parameter.
 * Returns the escaped filename suitable for use in makefiles, or nil if input is nil.
 */
- (NSString *) escapeFilenameForMakefile: (NSString *)filename;

/**
 * Generates Info.plist content for the application.
 * Creates a property list dictionary with application metadata.
 * Takes the name of the output plist file as parameter.
 * Returns the generated Info.plist content as a string.
 */
- (NSString *) generateInfoPlistOutput: (NSString *)outputPlist;

/**
 * Generates Info.plist content with app icon information.
 * Creates a property list dictionary including the specified icon file reference.
 * Takes the name of the output plist file and the name of the icon file as parameters.
 * Returns the generated Info.plist content as a string.
 */
- (NSString *) generateInfoPlistOutput: (NSString *)outputPlist withIconFile: (NSString *)iconFile;

/**
 * Converts build configuration to Info.plist dictionary.
 * Extracts relevant settings from the build configuration for plist generation.
 * Takes the build configuration to process as parameter.
 * Returns a mutable dictionary containing plist key-value pairs.
 */
- (NSMutableDictionary *) configToInfoPlist: (XCBuildConfiguration *)config;

/**
 * Converts build configuration to Info.plist dictionary with icon information.
 * Extracts settings and includes icon file reference in the generated dictionary.
 * Takes the build configuration to process and the name of the icon file as parameters.
 * Returns a mutable dictionary containing plist key-value pairs including icon info.
 */
- (NSMutableDictionary *) configToInfoPlist: (XCBuildConfiguration *)config withIconFile: (NSString *)iconFile;

/**
 * Processes an input Info.plist file and generates output with variable substitution.
 * Reads an existing plist file and performs environment variable substitution.
 * Takes the path to the input plist file and the path where the processed plist should be written as parameters.
 * Returns YES if processing succeeded, NO otherwise.
 */
- (BOOL) processInfoPlistInput: (NSString *)inputFileName
			output: (NSString *)outputFileName;

/**
 * Processes an input Info.plist file with icon information and generates output.
 * Reads an existing plist file, performs variable substitution, and adds icon info.
 * Takes the path to the input plist file, the path where the processed plist should be written, 
 * and the name of the icon file to include as parameters.
 * Returns YES if processing succeeded, NO otherwise.
 */
- (BOOL) processInfoPlistInput: (NSString *)inputFileName
			output: (NSString *)outputFileName
		  withIconFile: (NSString *)iconFileName;

/**
 * Legacy method for backward compatibility.
 * Processes assets and returns the discovered icon filename.
 */
- (NSString *) processAssets;

@end
