/*
   Project: Ycode

   Copyright (C) 2017 Free Software Foundation

   Author: Gregory John Casamento,,,

   Created: 2017-08-20 03:22:49 -0400 by heron

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

#import "YCodeDocumentController.h"
#import "YCodeProject.h"

@implementation YCodeDocumentController

- (NSString *)typeFromFileExtension:(NSString *)fileExtension
{
    if ([fileExtension isEqualToString:@"xcodeproj"]) {
        return @"YCodeXcodeProjectType";
    }

    if ([fileExtension isEqualToString:@"pcproj"]) {
        return @"YCodeProjectCenterProjectType";
    }

    return [super typeFromFileExtension:fileExtension];
}

- (Class)documentClassForType:(NSString *)type
{
    if ([type isEqualToString:@"YCodeXcodeProjectType"] ||
        [type isEqualToString:@"YCodeProjectCenterProjectType"] ||
        [type isEqualToString:@"xcodeproj"] ||
        [type isEqualToString:@"pcproj"]) {
        return [YCodeProject class];
    }

    return [super documentClassForType:type];
}

- (NSArray *)fileExtensionsFromType:(NSString *)type
{
    if ([type isEqualToString:@"YCodeXcodeProjectType"] ||
        [type isEqualToString:@"xcodeproj"]) {
        return [NSArray arrayWithObject:@"xcodeproj"];
    }

    if ([type isEqualToString:@"YCodeProjectCenterProjectType"] ||
        [type isEqualToString:@"pcproj"]) {
        return [NSArray arrayWithObject:@"pcproj"];
    }

    return [super fileExtensionsFromType:type];
}

- (NSString *)displayNameForType:(NSString *)type
{
    if ([type isEqualToString:@"YCodeXcodeProjectType"] ||
        [type isEqualToString:@"xcodeproj"]) {
        return @"Xcode project";
    }

    if ([type isEqualToString:@"YCodeProjectCenterProjectType"] ||
        [type isEqualToString:@"pcproj"]) {
        return @"ProjectCenter project";
    }

    return [super displayNameForType:type];
}

@end
