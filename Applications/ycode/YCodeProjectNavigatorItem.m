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

#import "YCodeProjectNavigatorItem.h"
#import <XCode/PBXFileReference.h>
#import <XCode/PBXGroup.h>

@implementation YCodeProjectNavigatorItem

- (instancetype)initWithRepresentedObject:(id)object type:(YCodeNavigatorItemType)type
{
    self = [super init];
    if (self) {
        _representedObject = [object retain];
        _itemType = type;
        _children = [[NSMutableArray alloc] init];
        _isExpanded = NO;
        _isLeaf = (type == YCodeNavigatorItemTypeFile);
        
        [self updateDisplayProperties];
    }
    return self;
}

- (void)dealloc
{
    RELEASE(_representedObject);
    RELEASE(_children);
    RELEASE(_parent);
    RELEASE(_displayName);
    RELEASE(_icon);
    [super dealloc];
}

- (void)updateDisplayProperties
{
    switch (_itemType) {
        case YCodeNavigatorItemTypeProject:
            if ([_representedObject respondsToSelector:@selector(name)]) {
                [self setDisplayName:[_representedObject name]];
            } else {
                [self setDisplayName:@"Project"];
            }
            [self setIcon:[NSImage imageNamed:@"project"]];
            break;
            
        case YCodeNavigatorItemTypeGroup:
            if ([_representedObject respondsToSelector:@selector(name)]) {
                NSString *groupName = [_representedObject name];
                [self setDisplayName:groupName ? groupName : @"Group"];
            } else {
                [self setDisplayName:@"Group"];
            }
            [self setIcon:[NSImage imageNamed:@"folder"]];
            break;
            
        case YCodeNavigatorItemTypeFile:
            if ([_representedObject respondsToSelector:@selector(path)]) {
                NSString *path = [_representedObject path];
                [self setDisplayName:[path lastPathComponent]];
                [self setIcon:[self iconForFileExtension:[path pathExtension]]];
            } else {
                [self setDisplayName:@"File"];
                [self setIcon:[NSImage imageNamed:@"document"]];
            }
            break;
            
        case YCodeNavigatorItemTypeTarget:
            if ([_representedObject respondsToSelector:@selector(name)]) {
                [self setDisplayName:[_representedObject name]];
            } else {
                [self setDisplayName:@"Target"];
            }
            [self setIcon:[NSImage imageNamed:@"target"]];
            break;
            
        case YCodeNavigatorItemTypeBuildPhase:
            [self setDisplayName:@"Build Phase"];
            [self setIcon:[NSImage imageNamed:@"buildphase"]];
            break;
    }
}

- (NSImage *)iconForFileExtension:(NSString *)extension
{
    if ([extension isEqualToString:@"h"]) {
        return [NSImage imageNamed:@"header"];
    } else if ([extension isEqualToString:@"m"] || [extension isEqualToString:@"mm"]) {
        return [NSImage imageNamed:@"objc"];
    } else if ([extension isEqualToString:@"c"]) {
        return [NSImage imageNamed:@"c"];
    } else if ([extension isEqualToString:@"cpp"] || [extension isEqualToString:@"cc"]) {
        return [NSImage imageNamed:@"cpp"];
    } else if ([extension isEqualToString:@"xib"] || [extension isEqualToString:@"nib"]) {
        return [NSImage imageNamed:@"nib"];
    } else if ([extension isEqualToString:@"plist"]) {
        return [NSImage imageNamed:@"plist"];
    } else if ([extension isEqualToString:@"png"] || [extension isEqualToString:@"jpg"] || 
               [extension isEqualToString:@"gif"]) {
        return [NSImage imageNamed:@"image"];
    }
    
    return [NSImage imageNamed:@"document"];
}

#pragma mark - Accessors

- (id)representedObject
{
    return _representedObject;
}

- (void)setRepresentedObject:(id)object
{
    ASSIGN(_representedObject, object);
    [self updateDisplayProperties];
}

- (YCodeNavigatorItemType)itemType
{
    return _itemType;
}

- (void)setItemType:(YCodeNavigatorItemType)type
{
    _itemType = type;
    _isLeaf = (type == YCodeNavigatorItemTypeFile);
    [self updateDisplayProperties];
}

- (NSString *)displayName
{
    return _displayName;
}

- (void)setDisplayName:(NSString *)name
{
    ASSIGN(_displayName, name);
}

- (NSImage *)icon
{
    return _icon;
}

- (void)setIcon:(NSImage *)icon
{
    ASSIGN(_icon, icon);
}

#pragma mark - Tree Structure

- (NSArray *)children
{
    return _children;
}

- (void)addChild:(YCodeProjectNavigatorItem *)child
{
    if (child && ![_children containsObject:child]) {
        [_children addObject:child];
        [child setParent:self];
    }
}

- (void)removeChild:(YCodeProjectNavigatorItem *)child
{
    if ([_children containsObject:child]) {
        [child setParent:nil];
        [_children removeObject:child];
    }
}

- (YCodeProjectNavigatorItem *)parent
{
    return _parent;
}

- (void)setParent:(YCodeProjectNavigatorItem *)parent
{
    _parent = parent; // weak reference to avoid cycles
}

#pragma mark - State

- (BOOL)isExpanded
{
    return _isExpanded;
}

- (void)setExpanded:(BOOL)expanded
{
    _isExpanded = expanded;
}

- (BOOL)isLeaf
{
    return _isLeaf;
}

- (void)setLeaf:(BOOL)leaf
{
    _isLeaf = leaf;
}

#pragma mark - Convenience Methods

- (BOOL)isGroup
{
    return _itemType == YCodeNavigatorItemTypeGroup;
}

- (BOOL)isFile
{
    return _itemType == YCodeNavigatorItemTypeFile;
}

- (BOOL)isProject
{
    return _itemType == YCodeNavigatorItemTypeProject;
}

- (BOOL)isTarget
{
    return _itemType == YCodeNavigatorItemTypeTarget;
}

- (NSString *)filePath
{
    if (_itemType == YCodeNavigatorItemTypeFile && 
        [_representedObject respondsToSelector:@selector(path)]) {
        return [_representedObject path];
    }
    return nil;
}

@end