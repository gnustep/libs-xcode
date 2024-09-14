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

#ifndef _XCSystem_h_INCLUDE
#define _XCSystem_h_INCLUDE

#import <Foundation/Foundation.h>

#if	defined(__cplusplus)
extern "C" {
#endif

NSInteger xcsystem(NSString *cmd);

void xcputs(const char *str);

void xcput_string(NSString *str);  

int xcprintf(const char *format, ...);

#if	defined(__cplusplus)
}
#endif

#endif	/* _XCSystem_h_INCLUDE */

