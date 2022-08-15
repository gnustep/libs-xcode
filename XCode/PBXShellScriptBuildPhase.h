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
#import "PBXAbstractBuildPhase.h"

@interface PBXShellScriptBuildPhase : PBXAbstractBuildPhase
{
  NSString *_shellPath;
  NSString *_shellScript;
  NSMutableArray *_inputPaths;
  NSMutableArray *_outputPaths;
  NSMutableArray *_inputFileListPaths;
  NSMutableArray *_outputFileListPaths;
}

// Methods....
- (NSString *) shellPath; // getter
- (void) setShellPath: (NSString *)object; // setter
- (NSString *) shellScript; // getter
- (void) setShellScript: (NSString *)object; // setter
- (NSMutableArray *) inputPaths; // getter
- (void) setInputPaths: (NSMutableArray *)object; // setter
- (NSMutableArray *) outputPaths; // getter
- (void) setOutputPaths: (NSMutableArray *)object; // setter
- (NSMutableArray *) inputFileListPaths; // getter
- (void) setInputFileListPaths: (NSMutableArray *)object; // setter
- (NSMutableArray *) outputFileListPaths; // getter
- (void) setOutputFileListPaths: (NSMutableArray *)object; // setter

// build...
- (BOOL) build;
@end
