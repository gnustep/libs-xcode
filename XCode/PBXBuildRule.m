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

#import "PBXCommon.h"
#import "PBXBuildRule.h"

@implementation PBXBuildRule

- (void) dealloc
{
  RELEASE(_fileType);
  RELEASE(_isEditable);
  RELEASE(_outputFiles);
  RELEASE(_compilerSpec);
  RELEASE(_script);
  RELEASE(_inputFiles);

  [super dealloc];
}

// Methods....
- (NSString *) fileType // getter
{
  return _fileType;
}

- (void) setFileType: (NSString *)object; // setter
{
  ASSIGN(_fileType,object);
}

- (NSString *) isEditable // getter
{
  return _isEditable;
}

- (void) setIsEditable: (NSString *)object; // setter
{
  ASSIGN(_isEditable,object);
}

- (NSMutableArray *) outputFiles // getter
{
  return _outputFiles;
}

- (void) setOutputFiles: (NSMutableArray *)object; // setter
{
  ASSIGN(_outputFiles,object);
}


- (NSMutableArray *) inputFiles // getter
{
  return _inputFiles;
}

- (void) setInputFiles: (NSMutableArray *)object; // setter
{
  ASSIGN(_inputFiles,object);
}

- (NSString *) compilerSpec // getter
{
  return _compilerSpec;
}

- (void) setCompilerSpec: (NSString *)object; // setter
{
  ASSIGN(_compilerSpec,object);
}

- (NSString *) script // getter
{
  return _compilerSpec;
}

- (void) setScript: (NSString *)object; // setter
{
  ASSIGN(_script,object);
}

- (NSString *) filePatterns // getter
{
  return _filePatterns;
}

- (void) setFilePatterns: (NSString *)object; // setter
{
  ASSIGN(_filePatterns,object);
}

@end
