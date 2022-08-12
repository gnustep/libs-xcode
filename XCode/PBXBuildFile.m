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
#import "PBXBuildFile.h"
#import "PBXNativeTarget.h"

@implementation PBXBuildFile

// Methods....
- (void) setPlatformFilter: (NSString *)f
{
  ASSIGN(_platformFilter, f);
}

- (PBXFileReference *) fileRef // getter
{
  return _fileRef;
}

- (void) setFileRef: (PBXFileReference *)object; // setter
{
  ASSIGN(_fileRef,object);
}

- (NSMutableDictionary *) settings // getter
{
  return _settings;
}

- (void) setSettings: (NSMutableDictionary *)object; // setter
{
  ASSIGN(_settings,object);
}

- (void) applySettings
{
  // xcputs("%@",settings);
}

- (NSString *) buildPath
{
  return [_fileRef buildPath];
}

- (NSString *) path
{
  return [_fileRef path];
}

- (void) setTarget: (PBXNativeTarget *)t
{
  _target = t;
}

- (void) setTotalFiles: (NSUInteger)t
{
  _totalFiles = t;
}

- (void) setCurrentFile: (NSUInteger)n
{
  _currentFile = n;
}

- (BOOL) build
{
  [self applySettings];
  [_fileRef setTarget: _target];
  [_fileRef setTotalFiles: _totalFiles];
  [_fileRef setCurrentFile: _currentFile];
  return [_fileRef build];
}

- (BOOL) generate
{
  [self applySettings];
  xcputs([[NSString stringWithFormat: @"\t* Creating entry for %@",[_fileRef buildPath]] cString]);
  [_fileRef setTarget: _target];
  return [_fileRef generate];
}

- (NSString *) description
{
  NSString *s = [super description];
  return [s stringByAppendingFormat: @" <%@>", _fileRef]; 
}

@end
