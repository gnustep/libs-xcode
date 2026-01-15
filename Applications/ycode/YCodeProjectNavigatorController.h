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

#ifndef _YCODEPROJECTNAVIGATORCONTROLLER_H_
#define _YCODEPROJECTNAVIGATORCONTROLLER_H_

#import <Foundation/Foundation.h>
#import <AppKit/AppKit.h>

@class YCodeProject;
@class YCodeProjectNavigatorItem;

@interface YCodeProjectNavigatorController : NSObject <NSOutlineViewDataSource, NSOutlineViewDelegate>
{
    YCodeProject *_project;
    NSOutlineView *_outlineView;
    
    NSMutableArray *_rootItems;
    NSMutableDictionary *_itemCache;
    
    // Context menu
    NSMenu *_contextMenu;
}

/**
 * Project association
 */
- (YCodeProject *)project;
- (void)setProject:(YCodeProject *)project;

/**
 * Outline view association
 */
- (NSOutlineView *)outlineView;
- (void)setOutlineView:(NSOutlineView *)outlineView;

/**
 * Project tree management
 */
- (void)projectDidChange;
- (void)reloadProjectTree;
- (NSArray *)rootItems;

/**
 * Item management
 */
- (YCodeProjectNavigatorItem *)itemForObject:(id)object;
- (void)expandItem:(YCodeProjectNavigatorItem *)item;
- (void)selectItem:(YCodeProjectNavigatorItem *)item;

/**
 * File operations
 */
- (IBAction)addFile:(id)sender;
- (IBAction)addGroup:(id)sender;
- (IBAction)deleteItem:(id)sender;
- (IBAction)renameItem:(id)sender;

/**
 * Context menu
 */
- (NSMenu *)contextMenu;
- (void)setupContextMenu;

@end

#endif // _YCODEPROJECTNAVIGATORCONTROLLER_H_