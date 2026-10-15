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

#ifndef _YCODEDOCUMENTCONTROLLER_H_
#define _YCODEDOCUMENTCONTROLLER_H_

#import <Foundation/Foundation.h>
#import <AppKit/AppKit.h>

@interface YCodeDocumentController : NSDocumentController
#ifndef GNUSTEP
    <NSMenuDelegate>
#endif
{

}

/** A menu backed by the document controller's persistent recent-project history. */
- (NSMenu *)recentDocumentsMenu;
- (BOOL)openWorkspaceFile:(NSString *)path error:(NSError **)error;
- (IBAction)openRecentProject:(id)sender;
- (IBAction)clearRecentProjects:(id)sender;

@end

#endif // _YCODEDOCUMENTCONTROLLER_H_

