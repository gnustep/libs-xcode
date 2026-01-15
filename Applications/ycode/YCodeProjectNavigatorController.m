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

#import "YCodeProjectNavigatorController.h"
#import "YCodeProjectNavigatorItem.h"
#import "YCodeProject.h"
#import <XCode/PBXTarget.h>

@implementation YCodeProjectNavigatorController

- (instancetype)init
{
    self = [super init];
    if (self) {
        _rootItems = [[NSMutableArray alloc] init];
        _itemCache = [[NSMutableDictionary alloc] init];
        [self setupContextMenu];
    }
    return self;
}

- (void)dealloc
{
    RELEASE(_project);
    RELEASE(_outlineView);
    RELEASE(_rootItems);
    RELEASE(_itemCache);
    RELEASE(_contextMenu);
    [super dealloc];
}

#pragma mark - Project Association

- (YCodeProject *)project
{
    return _project;
}

- (void)setProject:(YCodeProject *)project
{
    ASSIGN(_project, project);
    [self projectDidChange];
}

#pragma mark - Outline View Association

- (NSOutlineView *)outlineView
{
    return _outlineView;
}

- (void)setOutlineView:(NSOutlineView *)outlineView
{
    ASSIGN(_outlineView, outlineView);
    [_outlineView setDataSource:self];
    [_outlineView setDelegate:self];
    [_outlineView setTarget:self];
    [_outlineView setDoubleAction:@selector(outlineViewDoubleClick:)];
}

#pragma mark - Project Tree Management

- (void)projectDidChange
{
    [self reloadProjectTree];
    if (_outlineView) {
        [_outlineView reloadData];
        [_outlineView expandItem:[_rootItems firstObject]];
    }
}

- (void)reloadProjectTree
{
    [_rootItems removeAllObjects];
    [_itemCache removeAllObjects];
    
    if (_project && [_project project]) {
        PBXProject *project = [_project project];
        
        // Create project root item
        YCodeProjectNavigatorItem *projectItem = 
            [[YCodeProjectNavigatorItem alloc] initWithRepresentedObject:project 
                                                                   type:YCodeNavigatorItemTypeProject];
        [_rootItems addObject:projectItem];
        [_itemCache setObject:projectItem forKey:[NSValue valueWithPointer:project]];
        
        // Add main group
        PBXGroup *mainGroup = [project mainGroup];
        if (mainGroup) {
            [self addGroupItem:mainGroup toParent:projectItem];
        }
        
        // Add targets
        NSArray *targets = [project targets];
        if (targets && [targets count] > 0) {
            // Create a targets group
            YCodeProjectNavigatorItem *targetsGroupItem = 
                [[YCodeProjectNavigatorItem alloc] initWithRepresentedObject:nil 
                                                                       type:YCodeNavigatorItemTypeGroup];
            [targetsGroupItem setDisplayName:@"Targets"];
            [projectItem addChild:targetsGroupItem];
            
            NSEnumerator *targetEnum = [targets objectEnumerator];
            PBXTarget *target;
            while ((target = [targetEnum nextObject]) != nil) {
                YCodeProjectNavigatorItem *targetItem = 
                    [[YCodeProjectNavigatorItem alloc] initWithRepresentedObject:target 
                                                                           type:YCodeNavigatorItemTypeTarget];
                [targetsGroupItem addChild:targetItem];
                [_itemCache setObject:targetItem forKey:[NSValue valueWithPointer:target]];
            }
        }
        
        RELEASE(projectItem);
    }
}

- (void)addGroupItem:(PBXGroup *)group toParent:(YCodeProjectNavigatorItem *)parentItem
{
    if (!group || !parentItem) {
        return;
    }
    
    YCodeProjectNavigatorItem *groupItem = 
        [[YCodeProjectNavigatorItem alloc] initWithRepresentedObject:group 
                                                               type:YCodeNavigatorItemTypeGroup];
    [parentItem addChild:groupItem];
    [_itemCache setObject:groupItem forKey:[NSValue valueWithPointer:group]];
    
    // Add children
    NSArray *children = [group children];
    NSEnumerator *childEnum = [children objectEnumerator];
    id child;
    
    while ((child = [childEnum nextObject]) != nil) {
        if ([child isKindOfClass:[PBXGroup class]]) {
            [self addGroupItem:child toParent:groupItem];
        } else if ([child isKindOfClass:[PBXFileReference class]]) {
            YCodeProjectNavigatorItem *fileItem = 
                [[YCodeProjectNavigatorItem alloc] initWithRepresentedObject:child 
                                                                       type:YCodeNavigatorItemTypeFile];
            [groupItem addChild:fileItem];
            [_itemCache setObject:fileItem forKey:[NSValue valueWithPointer:child]];
            RELEASE(fileItem);
        }
    }
    
    RELEASE(groupItem);
}

- (NSArray *)rootItems
{
    return _rootItems;
}

#pragma mark - Item Management

- (YCodeProjectNavigatorItem *)itemForObject:(id)object
{
    return [_itemCache objectForKey:[NSValue valueWithPointer:object]];
}

- (void)expandItem:(YCodeProjectNavigatorItem *)item
{
    if (_outlineView && item) {
        [item setExpanded:YES];
        [_outlineView expandItem:item];
    }
}

- (void)selectItem:(YCodeProjectNavigatorItem *)item
{
    if (_outlineView && item) {
        NSInteger row = [_outlineView rowForItem:item];
        if (row >= 0) {
            [_outlineView selectRowIndexes:[NSIndexSet indexSetWithIndex:row] 
                      byExtendingSelection:NO];
        }
    }
}

#pragma mark - NSOutlineViewDataSource

- (NSInteger)outlineView:(NSOutlineView *)outlineView numberOfChildrenOfItem:(id)item
{
    if (item == nil) {
        return [_rootItems count];
    }
    
    if ([item isKindOfClass:[YCodeProjectNavigatorItem class]]) {
        YCodeProjectNavigatorItem *navItem = (YCodeProjectNavigatorItem *)item;
        return [[navItem children] count];
    }
    
    return 0;
}

- (id)outlineView:(NSOutlineView *)outlineView child:(NSInteger)index ofItem:(id)item
{
    if (item == nil) {
        if (index < [_rootItems count]) {
            return [_rootItems objectAtIndex:index];
        }
    }
    
    if ([item isKindOfClass:[YCodeProjectNavigatorItem class]]) {
        YCodeProjectNavigatorItem *navItem = (YCodeProjectNavigatorItem *)item;
        NSArray *children = [navItem children];
        if (index < [children count]) {
            return [children objectAtIndex:index];
        }
    }
    
    return nil;
}

- (BOOL)outlineView:(NSOutlineView *)outlineView isItemExpandable:(id)item
{
    if ([item isKindOfClass:[YCodeProjectNavigatorItem class]]) {
        YCodeProjectNavigatorItem *navItem = (YCodeProjectNavigatorItem *)item;
        return ![navItem isLeaf] && [[navItem children] count] > 0;
    }
    return NO;
}

- (id)outlineView:(NSOutlineView *)outlineView objectValueForTableColumn:(NSTableColumn *)tableColumn byItem:(id)item
{
    if ([item isKindOfClass:[YCodeProjectNavigatorItem class]]) {
        YCodeProjectNavigatorItem *navItem = (YCodeProjectNavigatorItem *)item;
        
        if ([[tableColumn identifier] isEqualToString:@"name"]) {
            return [navItem displayName];
        }
    }
    
    return @"";
}

#pragma mark - NSOutlineViewDelegate

- (void)outlineView:(NSOutlineView *)outlineView willDisplayCell:(id)cell forTableColumn:(NSTableColumn *)tableColumn item:(id)item
{
    if ([item isKindOfClass:[YCodeProjectNavigatorItem class]] && 
        [[tableColumn identifier] isEqualToString:@"name"]) {
        YCodeProjectNavigatorItem *navItem = (YCodeProjectNavigatorItem *)item;
        
        if ([cell respondsToSelector:@selector(setImage:)]) {
            [cell setImage:[navItem icon]];
        }
    }
}

- (BOOL)outlineView:(NSOutlineView *)outlineView shouldSelectItem:(id)item
{
    return YES;
}

- (void)outlineViewSelectionDidChange:(NSNotification *)notification
{
    NSInteger selectedRow = [_outlineView selectedRow];
    if (selectedRow >= 0) {
        id selectedItem = [_outlineView itemAtRow:selectedRow];
        if ([selectedItem isKindOfClass:[YCodeProjectNavigatorItem class]]) {
            YCodeProjectNavigatorItem *navItem = (YCodeProjectNavigatorItem *)selectedItem;
            
            if ([navItem isFile]) {
                // Open file in editor
                NSString *filePath = [navItem filePath];
                if (filePath) {
                    [[_project editorController] openFile:filePath];
                }
            }
        }
    }
}

- (void)outlineViewDoubleClick:(id)sender
{
    NSInteger clickedRow = [_outlineView clickedRow];
    if (clickedRow >= 0) {
        id clickedItem = [_outlineView itemAtRow:clickedRow];
        if ([clickedItem isKindOfClass:[YCodeProjectNavigatorItem class]]) {
            YCodeProjectNavigatorItem *navItem = (YCodeProjectNavigatorItem *)clickedItem;
            
            if ([navItem isFile]) {
                // Open file in editor
                NSString *filePath = [navItem filePath];
                if (filePath) {
                    [[_project editorController] openFile:filePath];
                }
            } else if (![navItem isLeaf]) {
                // Toggle expansion
                if ([navItem isExpanded]) {
                    [_outlineView collapseItem:navItem];
                    [navItem setExpanded:NO];
                } else {
                    [_outlineView expandItem:navItem];
                    [navItem setExpanded:YES];
                }
            }
        }
    }
}

#pragma mark - Context Menu

- (NSMenu *)contextMenu
{
    return _contextMenu;
}

- (void)setupContextMenu
{
    _contextMenu = [[NSMenu alloc] initWithTitle:@"Navigator Context Menu"];
    
    NSMenuItem *addFileItem = [[NSMenuItem alloc] initWithTitle:@"Add File..." 
                                                         action:@selector(addFile:) 
                                                  keyEquivalent:@""];
    [addFileItem setTarget:self];
    [_contextMenu addItem:addFileItem];
    RELEASE(addFileItem);
    
    NSMenuItem *addGroupItem = [[NSMenuItem alloc] initWithTitle:@"Add Group..." 
                                                          action:@selector(addGroup:) 
                                                   keyEquivalent:@""];
    [addGroupItem setTarget:self];
    [_contextMenu addItem:addGroupItem];
    RELEASE(addGroupItem);
    
    [_contextMenu addItem:[NSMenuItem separatorItem]];
    
    NSMenuItem *deleteItem = [[NSMenuItem alloc] initWithTitle:@"Delete" 
                                                        action:@selector(deleteItem:) 
                                                 keyEquivalent:@""];
    [deleteItem setTarget:self];
    [_contextMenu addItem:deleteItem];
    RELEASE(deleteItem);
    
    NSMenuItem *renameItem = [[NSMenuItem alloc] initWithTitle:@"Rename..." 
                                                        action:@selector(renameItem:) 
                                                 keyEquivalent:@""];
    [renameItem setTarget:self];
    [_contextMenu addItem:renameItem];
    RELEASE(renameItem);
}

#pragma mark - File Operations

- (IBAction)addFile:(id)sender
{
    NSOpenPanel *openPanel = [NSOpenPanel openPanel];
    [openPanel setCanChooseFiles:YES];
    [openPanel setCanChooseDirectories:NO];
    [openPanel setAllowsMultipleSelection:YES];
    
    if ([openPanel runModal] == NSModalResponseOK) {
        NSArray *urls = [openPanel URLs];
        NSMutableArray *filePaths = [NSMutableArray array];
        
        NSEnumerator *urlEnum = [urls objectEnumerator];
        NSURL *url;
        while ((url = [urlEnum nextObject]) != nil) {
            [filePaths addObject:[url path]];
        }
        
        [_project addFilesToProject:filePaths];
    }
}

- (IBAction)addGroup:(id)sender
{
    // Show alert for group name
    NSAlert *alert = [[NSAlert alloc] init];
    [alert setMessageText:@"Create New Group"];
    [alert setInformativeText:@"Enter the name for the new group:"];
    [alert addButtonWithTitle:@"Create"];
    [alert addButtonWithTitle:@"Cancel"];
    
    NSTextField *input = [[NSTextField alloc] initWithFrame:NSMakeRect(0, 0, 200, 24)];
    [alert setAccessoryView:input];
    
    if ([alert runModal] == NSAlertFirstButtonReturn) {
        NSString *groupName = [input stringValue];
        if (groupName && [groupName length] > 0) {
            [_project addGroupToProject:groupName];
        }
    }
    
    RELEASE(alert);
    RELEASE(input);
}

- (IBAction)deleteItem:(id)sender
{
    NSInteger selectedRow = [_outlineView selectedRow];
    if (selectedRow >= 0) {
        id selectedItem = [_outlineView itemAtRow:selectedRow];
        if ([selectedItem isKindOfClass:[YCodeProjectNavigatorItem class]]) {
            // Implement deletion logic
            NSLog(@"Delete item: %@", selectedItem);
        }
    }
}

- (IBAction)renameItem:(id)sender
{
    NSInteger selectedRow = [_outlineView selectedRow];
    if (selectedRow >= 0) {
        id selectedItem = [_outlineView itemAtRow:selectedRow];
        if ([selectedItem isKindOfClass:[YCodeProjectNavigatorItem class]]) {
            // Implement rename logic
            NSLog(@"Rename item: %@", selectedItem);
        }
    }
}

#pragma mark - NSOutlineViewDataSource Protocol Stubs

- (BOOL)outlineView:(NSOutlineView *)outlineView acceptDrop:(id <NSDraggingInfo>)info item:(id)item childIndex:(NSInteger)index
{
    return NO; // TODO: Implement drag and drop support
}

- (id)outlineView:(NSOutlineView *)outlineView itemForPersistentObject:(id)object
{
    return nil; // TODO: Implement persistence support
}

- (id)outlineView:(NSOutlineView *)outlineView persistentObjectForItem:(id)item
{
    return nil; // TODO: Implement persistence support  
}

- (void)outlineView:(NSOutlineView *)outlineView setObjectValue:(id)object forTableColumn:(NSTableColumn *)tableColumn byItem:(id)item
{
    // TODO: Implement editing support
}

- (NSDragOperation)outlineView:(NSOutlineView *)outlineView validateDrop:(id <NSDraggingInfo>)info proposedItem:(id)item proposedChildIndex:(NSInteger)index
{
    return NSDragOperationNone; // TODO: Implement drag validation
}

- (BOOL)outlineView:(NSOutlineView *)outlineView writeItems:(NSArray *)items toPasteboard:(NSPasteboard *)pasteboard
{
    return NO; // TODO: Implement drag support
}

- (void)outlineView:(NSOutlineView *)outlineView sortDescriptorsDidChange:(NSArray *)oldDescriptors
{
    // TODO: Implement sorting support
}

- (NSArray *)outlineView:(NSOutlineView *)outlineView namesOfPromisedFilesDroppedAtDestination:(NSURL *)dropDestination forDraggedItems:(NSArray *)items
{
    return nil; // TODO: Implement promised files support
}

#pragma mark - NSOutlineViewDelegate Protocol Stubs

- (void)outlineViewColumnDidMove:(NSNotification *)notification { }
- (void)outlineViewColumnDidResize:(NSNotification *)notification { }
- (void)outlineViewItemDidCollapse:(NSNotification *)notification { }
- (void)outlineViewItemDidExpand:(NSNotification *)notification { }
- (void)outlineViewItemWillCollapse:(NSNotification *)notification { }
- (void)outlineViewItemWillExpand:(NSNotification *)notification { }
- (void)outlineViewSelectionIsChanging:(NSNotification *)notification { }

- (BOOL)outlineView:(NSOutlineView *)outlineView shouldCollapseItem:(id)item { return YES; }
- (BOOL)outlineView:(NSOutlineView *)outlineView shouldEditTableColumn:(NSTableColumn *)tableColumn item:(id)item { return NO; }
- (BOOL)outlineView:(NSOutlineView *)outlineView shouldExpandItem:(id)item { return YES; }
- (BOOL)outlineView:(NSOutlineView *)outlineView shouldSelectTableColumn:(NSTableColumn *)tableColumn { return YES; }

- (NSCell *)outlineView:(NSOutlineView *)outlineView dataCellForTableColumn:(NSTableColumn *)tableColumn item:(id)item { return nil; }
- (void)outlineView:(NSOutlineView *)outlineView willDisplayOutlineCell:(id)cell forTableColumn:(NSTableColumn *)tableColumn item:(id)item { }
- (BOOL)selectionShouldChangeInOutlineView:(NSOutlineView *)outlineView { return YES; }
- (void)outlineView:(NSOutlineView *)outlineView didClickTableColumn:(NSTableColumn *)tableColumn { }
- (NSView *)outlineView:(NSOutlineView *)outlineView viewForTableColumn:(NSTableColumn *)tableColumn item:(id)item { return nil; }
- (NSTableRowView *)outlineView:(NSOutlineView *)outlineView rowViewForItem:(id)item { return nil; }
- (void)outlineView:(NSOutlineView *)outlineView didAddRowView:(NSTableRowView *)rowView forRow:(NSInteger)row { }
- (void)outlineView:(NSOutlineView *)outlineView didRemoveRowView:(NSTableRowView *)rowView forRow:(NSInteger)row { }

@end