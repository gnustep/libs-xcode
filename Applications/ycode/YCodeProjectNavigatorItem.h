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

#ifndef _YCODEPROJECTNAVIGATORITEM_H_
#define _YCODEPROJECTNAVIGATORITEM_H_

#import <Foundation/Foundation.h>
#import <AppKit/AppKit.h>

@class PBXFileReference;
@class PBXGroup;

typedef enum {
    YCodeNavigatorItemTypeProject,
    YCodeNavigatorItemTypeGroup,
    YCodeNavigatorItemTypeFile,
    YCodeNavigatorItemTypeTarget,
    YCodeNavigatorItemTypeBuildPhase
} YCodeNavigatorItemType;

@interface YCodeProjectNavigatorItem : NSObject
{
    id _representedObject;
    YCodeNavigatorItemType _itemType;
    
    NSMutableArray *_children;
    YCodeProjectNavigatorItem *_parent;
    
    NSString *_displayName;
    NSImage *_icon;
    
    BOOL _isExpanded;
    BOOL _isLeaf;
}

/**
 * Initialization
 */
- (instancetype)initWithRepresentedObject:(id)object type:(YCodeNavigatorItemType)type;

/**
 * Represented object
 */
- (id)representedObject;
- (void)setRepresentedObject:(id)object;

/**
 * Item type
 */
- (YCodeNavigatorItemType)itemType;
- (void)setItemType:(YCodeNavigatorItemType)type;

/**
 * Display properties
 */
- (NSString *)displayName;
- (void)setDisplayName:(NSString *)name;
- (NSImage *)icon;
- (void)setIcon:(NSImage *)icon;

/**
 * Tree structure
 */
- (NSArray *)children;
- (void)addChild:(YCodeProjectNavigatorItem *)child;
- (void)removeChild:(YCodeProjectNavigatorItem *)child;
- (YCodeProjectNavigatorItem *)parent;
- (void)setParent:(YCodeProjectNavigatorItem *)parent;

/**
 * State
 */
- (BOOL)isExpanded;
- (void)setExpanded:(BOOL)expanded;
- (BOOL)isLeaf;
- (void)setLeaf:(BOOL)leaf;

/**
 * Convenience methods
 */
- (BOOL)isGroup;
- (BOOL)isFile;
- (BOOL)isProject;
- (BOOL)isTarget;

/**
 * File path for file items
 */
- (NSString *)filePath;

@end

#endif // _YCODEPROJECTNAVIGATORITEM_H_