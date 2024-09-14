/*
   Global include file for the GNUstep XCode Library.

   Copyright (C) 2024 Free Software Foundation, Inc.

   Written by:  Gregory John Casamento <greg.casamento@gmail.com>
   Date: Sep 2024
   
   This file is part of the GNUstep XCode Library.

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

#ifndef __XCode_h_GNUSTEP_INCLUDE
#define __XCode_h_GNUSTEP_INCLUDE

#import <XCode/GSXCBuildContext.h>
#import <XCode/GSXCBuildDatabase.h>
#import <XCode/GSXCBuildDelegate.h>
#import <XCode/GSXCBuildOperation.h>
#import <XCode/GSXCColors.h>
#import <XCode/GSXCCommon.h>
#import <XCode/GSXCGenerator.h>
#import <XCode/GSXCTask.h>
#import <XCode/NSArray+Additions.h>
#import <XCode/NSObject+KeyExtraction.h>
#import <XCode/NSString+PBXAdditions.h>
#import <XCode/PBXAggregateTarget.h>
#import <XCode/PBXApplicationTarget.h>
#import <XCode/PBXBuildFile.h>
#import <XCode/PBXBuildPhase.h>
#import <XCode/PBXBuildRule.h>
#import <XCode/PBXBundleTarget.h>
#import <XCode/PBXCoder.h>
#import <XCode/PBXCommon.h>
#import <XCode/PBXContainer.h>
#import <XCode/PBXContainerItemProxy.h>
#import <XCode/PBXCopyFilesBuildPhase.h>
#import <XCode/PBXFileReference.h>
#import <XCode/PBXFrameworksBuildPhase.h>
#import <XCode/PBXFrameworkTarget.h>
#import <XCode/PBXGroup.h>
#import <XCode/PBXHeadersBuildPhase.h>
#import <XCode/PBXLegacyTarget.h>
#import <XCode/PBXNativeTarget.h>
#import <XCode/PBXProject.h>
#import <XCode/PBXReferenceProxy.h>
#import <XCode/PBXResourcesBuildPhase.h>
#import <XCode/PBXRezBuildPhase.h>
#import <XCode/PBXShellScriptBuildPhase.h>
#import <XCode/PBXSourcesBuildPhase.h>
#import <XCode/PBXTargetDependency.h>
#import <XCode/PBXTarget.h>
#import <XCode/PBXVariantGroup.h>
#import <XCode/XCAbstractDelegate.h>
#import <XCode/XCBuildConfiguration.h>
#import <XCode/XCConfigurationList.h>
#import <XCode/XCFileRef.h>
#import <XCode/XCVersionGroup.h>
#import <XCode/XCWorkspace.h>
#import <XCode/XCWorkspaceParser.h>

#endif // __XCode_h_GNUSTEP_INCLUDE
