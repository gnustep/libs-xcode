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
#import "YCodeBuildSystem.h"
#import <XCode/PBXProject.h>
#import <XCode/PBXGroup.h>
#import <XCode/PBXFileReference.h>
#import <XCode/PBXTarget.h>
#import <XCode/PBXNativeTarget.h>

/* NSTextFieldCell preserves the table's selection colors, including dark themes. */
@interface YCodeNavigatorCell : NSTextFieldCell
{
  NSImage *_navigatorImage;
}

@end

@implementation YCodeNavigatorCell
- (void) dealloc
{
  RELEASE (_navigatorImage);
  [super dealloc];
}

- (id) copyWithZone: (NSZone *)zone
{
  YCodeNavigatorCell *cell = [super copyWithZone: zone];
  cell->_navigatorImage = RETAIN (_navigatorImage);
  return cell;
}

- (void) setImage: (NSImage *)image
{
  ASSIGN (_navigatorImage, image);
}

- (NSImage *) image
{
  return _navigatorImage;
}

- (NSRect) imageRectForBounds: (NSRect)bounds
{
  NSSize size = [_navigatorImage size];
  return NSMakeRect (NSMinX (bounds) + 2 + (16 - size.width) / 2,
                     NSMidY (bounds) - size.height / 2, size.width,
                     size.height);
}

- (void) drawInteriorWithFrame: (NSRect)frame inView: (NSView *)view
{
  if (_navigatorImage)
    {
      [NSGraphicsContext saveGraphicsState];
      NSRectClip (frame);
      [_navigatorImage drawInRect: [self imageRectForBounds: frame]
                         fromRect: NSZeroRect
                        operation: NSCompositeSourceOver
                         fraction: 1.0
                   respectFlipped: YES
                            hints: nil];
      [NSGraphicsContext restoreGraphicsState];
      frame.origin.x += 20;
      frame.size.width = MAX (0, frame.size.width - 20);
    }
  [super drawInteriorWithFrame: frame inView: view];
}

- (NSSize) cellSize
{
  NSSize size = [super cellSize];
  if (_navigatorImage)
    size.width += 20;
  size.height = MAX (20, size.height);
  return size;
}

@end

@implementation YCodeProjectNavigatorController

- (NSString *) resolvedPathForNavigatorItem: (YCodeProjectNavigatorItem *)item
{
  id object = [item representedObject];
  NSString *path;
  NSString *sourceTree;
  NSString *basePath = nil;

  if (item == nil || object == [_project project])
    {
      return [_project projectDirectoryPath];
    }
  if (![object isKindOfClass: [PBXFileReference class]]
      && ![object isKindOfClass: [PBXGroup class]])
    {
      return nil;
    }

  path = [object path];
  sourceTree = [object sourceTree];
  if ([path isAbsolutePath])
    {
      return [path stringByStandardizingPath];
    }
  if ([sourceTree length] == 0 || [sourceTree isEqualToString: @"<group>"])
    {
      basePath = [self resolvedPathForNavigatorItem: [item parent]];
    }
  else if ([sourceTree isEqualToString: @"SOURCE_ROOT"])
    {
      basePath = [_project projectDirectoryPath];
    }
  else if ([sourceTree isEqualToString: @"BUILT_PRODUCTS_DIR"])
    {
      NSString *directory = [_project projectDirectoryPath];
      if (!directory || ![path length])
        return nil;
      NSMutableArray *roots = [NSMutableArray array];
      NSEnumerator *targets = [[[_project project] targets] objectEnumerator];
      PBXTarget *target;
      while ((target = [targets nextObject]) != nil)
        {
          if ([target isKindOfClass: [PBXNativeTarget class]] &&
              [(PBXNativeTarget *)target productReference] == object &&
              [[target name] length])
            [roots addObject: [directory
                                 stringByAppendingPathComponent:
                                     [NSString
                                         stringWithFormat: @"build/%@/Products",
                                                          [target name]]]];
        }
      NSString *configuration = [[_project buildSystem] buildConfiguration];
      if ([configuration length])
        [roots
            addObject: [directory stringByAppendingPathComponent:
                                     [@"build" stringByAppendingPathComponent:
                                                   configuration]]];
      [roots addObject: [directory stringByAppendingPathComponent: @"build"]];
      [roots addObject: [directory stringByAppendingPathComponent: @"obj"]];
      [roots addObject: directory];
      NSEnumerator *enumerator = [roots objectEnumerator];
      NSString *root;
      while ((root = [enumerator nextObject]) != nil)
        {
          NSString *candidate = [root stringByAppendingPathComponent: path];
          if ([[NSFileManager defaultManager] fileExistsAtPath: candidate])
            return candidate;
        }
      return nil;
    }
  else
    {
      // SDK locations need a configured build context.
      return nil;
    }

  if ([path length] == 0)
    {
      return basePath;
    }
  return [[basePath stringByAppendingPathComponent: path]
      stringByStandardizingPath];
}

- (NSString *) resolvedFilePathForNavigatorItem:
    (YCodeProjectNavigatorItem *)item
{
  if (![item isFile] || [[[item representedObject] path] length] == 0)
    {
      return nil;
    }
  return [self resolvedPathForNavigatorItem: item];
}

- (void) updateThumbnailForItem: (YCodeProjectNavigatorItem *)item
{
  NSString *path = [self resolvedFilePathForNavigatorItem: item];
  NSString *extension = [[path pathExtension] lowercaseString];
  if ([extension isEqual: @"app"] &&
      [[NSFileManager defaultManager] fileExistsAtPath: path])
    {
      NSImage *icon = [[NSWorkspace sharedWorkspace] iconForFile: path];
      if (icon)
        [item setIcon: icon];
      return;
    }
  if (!path
      || (![[NSImage imageFileTypes] containsObject: extension]
          && ![[NSArray arrayWithObjects: @"png", @"jpg", @"jpeg", @"gif",
                                         @"tif", @"tiff", @"bmp", @"ico",
                                         @"icns", @"webp", nil]
              containsObject: extension]))
    return;
  NSImage *image = [[NSImage alloc] initWithContentsOfFile: path];
  NSSize size = [image size];
  if ([image isValid] && size.width > 0 && size.height > 0)
    {
      [item setIcon: image];
    }
  RELEASE (image);
}

- (void) refreshApplicationIcons
{
  if ([_project isDirectoryProject])
    {
      // A successful build may have created a bundle absent from the old tree.
      [_project refreshDirectoryFiles];
      return;
    }
  NSEnumerator *items = [[_itemCache allValues] objectEnumerator];
  YCodeProjectNavigatorItem *item;
  while ((item = [items nextObject]) != nil)
    {
      if ([item isFile] &&
          [[[[[item representedObject] path] pathExtension] lowercaseString]
              isEqual: @"app"])
        {
          [item setRepresentedObject: [item representedObject]];
          [self updateThumbnailForItem: item];
        }
    }
  [_outlineView reloadData];
}

- (id) init
{
  self = [super init];
  if (self)
    {
      _rootItems = [[NSMutableArray alloc] init];
      _itemCache = [[NSMutableDictionary alloc] init];
      [self setupContextMenu];
    }
  return self;
}

- (void) dealloc
{
  if (_outlineView)
    {
      if ([_outlineView dataSource] == self)
        {
          [_outlineView setDataSource: nil];
        }
      if ([_outlineView delegate] == self)
        {
          [_outlineView setDelegate: nil];
        }
      if ([_outlineView target] == self)
        {
          [_outlineView setTarget: nil];
        }
    }

  RELEASE (_project);
  RELEASE (_outlineView);
  RELEASE (_rootItems);
  RELEASE (_itemCache);
  RELEASE (_contextMenu);
  [super dealloc];
}

#pragma mark - Project Association

- (YCodeProject *) project
{
  return _project;
}

- (void) setProject: (YCodeProject *)project
{
  ASSIGN (_project, project);
  [self projectDidChange];
}

#pragma mark - Outline View Association

- (NSOutlineView *) outlineView
{
  return _outlineView;
}

- (void) setOutlineView: (NSOutlineView *)outlineView
{
  if (_outlineView && _outlineView != outlineView)
    {
      if ([_outlineView dataSource] == self)
        {
          [_outlineView setDataSource: nil];
        }
      if ([_outlineView delegate] == self)
        {
          [_outlineView setDelegate: nil];
        }
      if ([_outlineView target] == self)
        {
          [_outlineView setTarget: nil];
        }
    }

  ASSIGN (_outlineView, outlineView);
  NSTableColumn *column = [_outlineView outlineTableColumn];
  YCodeNavigatorCell *cell = [[YCodeNavigatorCell alloc] initTextCell: @""];
  // The outline view supplies disclosure triangles; the cell supplies the icon.
  [cell setEditable: NO];
  [cell setFont: [NSFont systemFontOfSize: [NSFont smallSystemFontSize]]];
  [column setDataCell: cell];
  RELEASE (cell);
  [_outlineView setRowHeight: MAX (20, [_outlineView rowHeight])];
  [_outlineView setDataSource: self];
  [_outlineView setDelegate: self];
  [_outlineView setTarget: self];
  [_outlineView setDoubleAction: @selector (outlineViewDoubleClick:)];
  // A newly attached outline has no expansion or selection state to restore.
  [_rootItems removeAllObjects];
  [self projectDidChange];
}

#pragma mark - Project Tree Management

- (void) projectDidChange
{
  BOOL restore = [_project isDirectoryProject] && [_rootItems count] > 0 &&
                 [_outlineView numberOfRows] > 0;
  NSMutableSet *expanded = [NSMutableSet set];
  NSMutableSet *selected = [NSMutableSet set];
  NSInteger row;
  if (restore)
    for (row = 0; row < [_outlineView numberOfRows]; row++)
      {
        YCodeProjectNavigatorItem *item = [_outlineView itemAtRow: row];
        NSString *resolved = [self resolvedPathForNavigatorItem: item];
        NSString *path
            = resolved
                  ? [NSString stringWithFormat: @"%ld:%@",
                                               (long)[item itemType], resolved]
                  : nil;
        if (!path)
          continue;
        if ([_outlineView isItemExpanded: item])
          [expanded addObject: path];
        if ([_outlineView isRowSelected: row])
          [selected addObject: path];
      }
  [self reloadProjectTree];
  if (_outlineView)
    {
      [_outlineView reloadData];
      if (restore)
        {
          NSMutableIndexSet *selection = [NSMutableIndexSet indexSet];
          // Expanding a row exposes its children for the following iterations.
          for (row = 0; row < [_outlineView numberOfRows]; row++)
            {
              YCodeProjectNavigatorItem *item = [_outlineView itemAtRow: row];
              NSString *resolved = [self resolvedPathForNavigatorItem: item];
              NSString *path
                  = resolved
                        ? [NSString stringWithFormat: @"%ld:%@",
                                                     (long)[item itemType],
                                                     resolved]
                        : nil;
              if (path && [expanded containsObject: path])
                [_outlineView expandItem: item];
              if (path && [selected containsObject: path])
                [selection addIndex: row];
            }
          [_outlineView selectRowIndexes: selection byExtendingSelection: NO];
        }
      else if ([_rootItems count] > 0)
        {
          [_outlineView expandItem: [_rootItems objectAtIndex: 0]];
          YCodeProjectNavigatorItem *mainItem =
              [self itemForObject: [[_project project] mainGroup]];
          if (mainItem)
            [_outlineView expandItem: mainItem
                      expandChildren: [[[_project projectPath] pathExtension]
                                         isEqual: @"pcproj"]];
        }
    }
}

- (void) reloadProjectTree
{
  [_rootItems removeAllObjects];
  [_itemCache removeAllObjects];

  if (_project && [_project project])
    {
      PBXProject *project = [_project project];

      // Create project root item
      YCodeProjectNavigatorItem *projectItem =
          [[YCodeProjectNavigatorItem alloc]
              initWithRepresentedObject: project
                                   type: YCodeNavigatorItemTypeProject];
      [_rootItems addObject: projectItem];
      [_itemCache setObject: projectItem
                     forKey: [NSValue valueWithPointer: project]];

      // Add main group
      PBXGroup *mainGroup = [project respondsToSelector: @selector (mainGroup)]
                                ? [project mainGroup]
                                : nil;
      if (mainGroup)
        {
          [self addGroupItem: mainGroup toParent: projectItem];
        }

      // Add targets
      NSArray *targets = [project respondsToSelector: @selector (targets)]
                             ? [project targets]
                             : nil;
      if (targets && [targets count] > 0)
        {
          // Create a targets group
          YCodeProjectNavigatorItem *targetsGroupItem =
              [[YCodeProjectNavigatorItem alloc]
                  initWithRepresentedObject: nil
                                       type: YCodeNavigatorItemTypeGroup];
          [targetsGroupItem setDisplayName: @"Targets"];
          [projectItem addChild: targetsGroupItem];

          NSEnumerator *targetEnum = [targets objectEnumerator];
          PBXTarget *target;
          while ((target = [targetEnum nextObject]) != nil)
            {
              YCodeProjectNavigatorItem *targetItem =
                  [[YCodeProjectNavigatorItem alloc]
                      initWithRepresentedObject: target
                                           type: YCodeNavigatorItemTypeTarget];
              [targetsGroupItem addChild: targetItem];
              [_itemCache setObject: targetItem
                             forKey: [NSValue valueWithPointer: target]];
            }
        }

      RELEASE (projectItem);
    }
}

- (void) addGroupItem: (PBXGroup *)group
            toParent: (YCodeProjectNavigatorItem *)parentItem
{
  if (!group || !parentItem)
    {
      return;
    }

  YCodeProjectNavigatorItem *groupItem = [[YCodeProjectNavigatorItem alloc]
      initWithRepresentedObject: group
                           type: YCodeNavigatorItemTypeGroup];
  [parentItem addChild: groupItem];
  [_itemCache setObject: groupItem forKey: [NSValue valueWithPointer: group]];

  // Display groups first without changing the project's stored child order.
  NSArray *children = [group children];
  NSEnumerator *childEnum = [children objectEnumerator];
  id child;

  while ((child = [childEnum nextObject]) != nil)
    {
      if ([child isKindOfClass: [PBXGroup class]])
        {
          [self addGroupItem: child toParent: groupItem];
        }
    }
  childEnum = [children objectEnumerator];
  while ((child = [childEnum nextObject]) != nil)
    {
      if ([child isKindOfClass: [PBXFileReference class]])
        {
          YCodeProjectNavigatorItem *fileItem =
              [[YCodeProjectNavigatorItem alloc]
                  initWithRepresentedObject: child
                                       type: YCodeNavigatorItemTypeFile];
          [groupItem addChild: fileItem];
          [self updateThumbnailForItem: fileItem];
          [_itemCache setObject: fileItem
                         forKey: [NSValue valueWithPointer: child]];
          RELEASE (fileItem);
        }
    }

  RELEASE (groupItem);
}

- (NSArray *) rootItems
{
  return _rootItems;
}

#pragma mark - Item Management

- (YCodeProjectNavigatorItem *) itemForObject: (id)object
{
  return [_itemCache objectForKey: [NSValue valueWithPointer: object]];
}

- (void) expandItem: (YCodeProjectNavigatorItem *)item
{
  if (_outlineView && item)
    {
      [item setExpanded: YES];
      [_outlineView expandItem: item];
    }
}

- (void) selectItem: (YCodeProjectNavigatorItem *)item
{
  if (_outlineView && item)
    {
      NSInteger row = [_outlineView rowForItem: item];
      if (row >= 0)
        {
          [_outlineView selectRowIndexes: [NSIndexSet indexSetWithIndex: row]
                    byExtendingSelection: NO];
        }
    }
}

#pragma mark - NSOutlineViewDataSource

- (NSInteger) outlineView: (NSOutlineView *)outlineView
    numberOfChildrenOfItem: (id)item
{
  if (item == nil)
    {
      return [_rootItems count];
    }

  if ([item isKindOfClass: [YCodeProjectNavigatorItem class]])
    {
      YCodeProjectNavigatorItem *navItem = (YCodeProjectNavigatorItem *)item;
      return [[navItem children] count];
    }

  return 0;
}

- (id) outlineView: (NSOutlineView *)outlineView
            child: (NSInteger)index
           ofItem: (id)item
{
  if (item == nil)
    {
      if (index < [_rootItems count])
        {
          return [_rootItems objectAtIndex: index];
        }
    }

  if ([item isKindOfClass: [YCodeProjectNavigatorItem class]])
    {
      YCodeProjectNavigatorItem *navItem = (YCodeProjectNavigatorItem *)item;
      NSArray *children = [navItem children];
      if (index < [children count])
        {
          return [children objectAtIndex: index];
        }
    }

  return nil;
}

- (BOOL) outlineView: (NSOutlineView *)outlineView isItemExpandable: (id)item
{
  if ([item isKindOfClass: [YCodeProjectNavigatorItem class]])
    {
      YCodeProjectNavigatorItem *navItem = (YCodeProjectNavigatorItem *)item;
      return ![navItem isLeaf] && [[navItem children] count] > 0;
    }
  return NO;
}

- (id) outlineView: (NSOutlineView *)outlineView
    objectValueForTableColumn: (NSTableColumn *)tableColumn
                       byItem: (id)item
{
  if ([item isKindOfClass: [YCodeProjectNavigatorItem class]])
    {
      YCodeProjectNavigatorItem *navItem = (YCodeProjectNavigatorItem *)item;

      if ([[tableColumn identifier] isEqualToString: @"name"])
        {
          return [navItem displayName];
        }
    }

  return @"";
}

#pragma mark - NSOutlineViewDelegate

- (void) outlineView: (NSOutlineView *)outlineView
    willDisplayCell: (id)cell
     forTableColumn: (NSTableColumn *)tableColumn
               item: (id)item
{
  if ([item isKindOfClass: [YCodeProjectNavigatorItem class]] &&
      [[tableColumn identifier] isEqualToString: @"name"])
    {
      YCodeProjectNavigatorItem *navItem = (YCodeProjectNavigatorItem *)item;

      if ([cell respondsToSelector: @selector (setImage:)])
        {
          [cell setImage: [navItem icon]];
        }
    }
}

- (BOOL) outlineView: (NSOutlineView *)outlineView shouldSelectItem: (id)item
{
  return YES;
}

- (void) openNavigatorFile: (NSString *)filePath
{
  if (![[NSWorkspace sharedWorkspace] openFile: filePath])
    {
      NSRunAlertPanel (
          @"Unable to Open File",
          @"The default application could not open %@. Check the file's application association and that the file is accessible.",
          @"OK", nil, nil, filePath);
    }
}

- (void) outlineViewSelectionDidChange: (NSNotification *)notification
{
  NSInteger selectedRow = [_outlineView selectedRow];
  if (selectedRow >= 0)
    {
      id selectedItem = [_outlineView itemAtRow: selectedRow];
      if ([selectedItem isKindOfClass: [YCodeProjectNavigatorItem class]])
        {
          YCodeProjectNavigatorItem *navItem
              = (YCodeProjectNavigatorItem *)selectedItem;

          if ([navItem isFile])
            {
              // Single-click previews supported models internally; double-click
              // continues to open the workspace's associated application.
              NSString *filePath =
                  [self resolvedFilePathForNavigatorItem: navItem];
              NSArray *interfaceTypes =
                  [NSArray arrayWithObjects: @"nix", @"storyboard", @"gmodel",
                                            @"cib", nil];
              if (filePath
                  && ![interfaceTypes containsObject: [[filePath pathExtension]
                                                         lowercaseString]])
                {
                  [[_project editorController] openFile: filePath];
                }
            }
        }
    }
}

- (void) outlineViewDoubleClick: (id)sender
{
  NSInteger clickedRow = [_outlineView clickedRow];
  if (clickedRow >= 0)
    {
      id clickedItem = [_outlineView itemAtRow: clickedRow];
      if ([clickedItem isKindOfClass: [YCodeProjectNavigatorItem class]])
        {
          YCodeProjectNavigatorItem *navItem
              = (YCodeProjectNavigatorItem *)clickedItem;

          if ([navItem isFile])
            {
              // Respect the workspace association for every file type.
              NSString *filePath =
                  [self resolvedFilePathForNavigatorItem: navItem];
              if (filePath)
                {
                  [self openNavigatorFile: filePath];
                }
            }
          else if (![navItem isLeaf])
            {
              // Toggle expansion
              if ([navItem isExpanded])
                {
                  [_outlineView collapseItem: navItem];
                  [navItem setExpanded: NO];
                }
              else
                {
                  [_outlineView expandItem: navItem];
                  [navItem setExpanded: YES];
                }
            }
        }
    }
}

#pragma mark - Context Menu

- (NSMenu *) contextMenu
{
  return _contextMenu;
}

- (void) setupContextMenu
{
  _contextMenu = [[NSMenu alloc] initWithTitle: @"Navigator Context Menu"];

  NSMenuItem *refresh = AUTORELEASE ([[NSMenuItem alloc]
      initWithTitle: @"Refresh Folder"
             action: @selector (refreshFolder:)
      keyEquivalent: @""]);
  [refresh setTarget: self];
  [_contextMenu addItem: refresh];
  NSMenuItem *addFileItem =
      [[NSMenuItem alloc] initWithTitle: @"Add File..."
                                 action: @selector (addFile:)
                          keyEquivalent: @""];
  [addFileItem setTarget: self];
  [_contextMenu addItem: addFileItem];
  RELEASE (addFileItem);

  NSMenuItem *addGroupItem =
      [[NSMenuItem alloc] initWithTitle: @"Add Group..."
                                 action: @selector (addGroup:)
                          keyEquivalent: @""];
  [addGroupItem setTarget: self];
  [_contextMenu addItem: addGroupItem];
  RELEASE (addGroupItem);

  [_contextMenu addItem: [NSMenuItem separatorItem]];

  NSMenuItem *deleteItem =
      [[NSMenuItem alloc] initWithTitle: @"Remove File from Project"
                                 action: @selector (deleteItem:)
                          keyEquivalent: @""];
  [deleteItem setTarget: self];
  [_contextMenu addItem: deleteItem];
  RELEASE (deleteItem);

  NSMenuItem *renameItem =
      [[NSMenuItem alloc] initWithTitle: @"Rename..."
                                 action: @selector (renameItem:)
                          keyEquivalent: @""];
  [renameItem setTarget: self];
  [_contextMenu addItem: renameItem];
  RELEASE (renameItem);
}

#pragma mark - File Operations

- (IBAction) addFile: (id)sender
{
  NSOpenPanel *openPanel = [NSOpenPanel openPanel];
  [openPanel setCanChooseFiles: YES];
  [openPanel setCanChooseDirectories: NO];
  [openPanel setAllowsMultipleSelection: YES];

  if ([openPanel runModal] == NSModalResponseOK)
    {
      NSArray *urls = [openPanel URLs];
      NSMutableArray *filePaths = [NSMutableArray array];

      NSEnumerator *urlEnum = [urls objectEnumerator];
      NSURL *url;
      while ((url = [urlEnum nextObject]) != nil)
        {
          [filePaths addObject: [url path]];
        }

      [_project addFilesToProject: filePaths];
    }
}

- (IBAction) addGroup: (id)sender
{
  // Show alert for group name
  NSAlert *alert = [[NSAlert alloc] init];
  [alert setMessageText: @"Create New Group"];
  [alert setInformativeText: @"Enter the name for the new group:"];
  [alert addButtonWithTitle: @"Create"];
  [alert addButtonWithTitle: @"Cancel"];

  NSTextField *input =
      [[NSTextField alloc] initWithFrame: NSMakeRect (0, 0, 200, 24)];
  if ([alert respondsToSelector: @selector (setAccessoryView:)])
    {
      [alert performSelector: @selector (setAccessoryView:) withObject: input];
    }

  if ([alert runModal] == NSAlertFirstButtonReturn)
    {
      NSString *groupName = [input stringValue];
      if (groupName && [groupName length] > 0)
        {
          [_project addGroupToProject: groupName];
        }
    }

  RELEASE (alert);
  RELEASE (input);
}

- (IBAction) deleteItem: (id)sender
{
  NSInteger selectedRow = [_outlineView clickedRow];
  if (selectedRow < 0)
    selectedRow = [_outlineView selectedRow];
  if (selectedRow >= 0)
    {
      id selectedItem = [_outlineView itemAtRow: selectedRow];
      if ([selectedItem isKindOfClass: [YCodeProjectNavigatorItem class]])
        {
          if ([selectedItem isFile])
            [_project removeFileReferenceFromProject: [selectedItem
                                                         representedObject]];
        }
    }
}

- (IBAction) refreshFolder: (id)sender
{
  [_project refreshDirectoryFiles];
}

- (BOOL) validateMenuItem: (NSMenuItem *)item
{
  if ([item action] == @selector (refreshFolder:))
    return [_project isDirectoryProject];
  if ([_project isDirectoryProject]
      && ([item action] == @selector (deleteItem:) ||
          [item action] == @selector (addFile:)))
    return NO;
  if ([item action] == @selector (deleteItem:))
    {
      NSInteger row = [_outlineView clickedRow];
      if (row < 0)
        row = [_outlineView selectedRow];
      return row >= 0 && [[_outlineView itemAtRow: row] isFile];
    }
  return _project != nil;
}

- (IBAction) renameItem: (id)sender
{
  NSInteger selectedRow = [_outlineView selectedRow];
  if (selectedRow >= 0)
    {
      id selectedItem = [_outlineView itemAtRow: selectedRow];
      if ([selectedItem isKindOfClass: [YCodeProjectNavigatorItem class]])
        {
          // Implement rename logic
          NSLog (@"Rename item: %@", selectedItem);
        }
    }
}

#pragma mark - NSOutlineViewDataSource Protocol Stubs

- (BOOL) outlineView: (NSOutlineView *)outlineView
         acceptDrop: (id<NSDraggingInfo>)info
               item: (id)item
         childIndex: (NSInteger)index
{
  return NO; // TODO: Implement drag and drop support
}

- (id) outlineView: (NSOutlineView *)outlineView
    itemForPersistentObject: (id)object
{
  return nil; // TODO: Implement persistence support
}

- (id) outlineView: (NSOutlineView *)outlineView persistentObjectForItem: (id)item
{
  return nil; // TODO: Implement persistence support
}

- (void) outlineView: (NSOutlineView *)outlineView
     setObjectValue: (id)object
     forTableColumn: (NSTableColumn *)tableColumn
             byItem: (id)item
{
  // TODO: Implement editing support
}

- (NSDragOperation) outlineView: (NSOutlineView *)outlineView
                  validateDrop: (id<NSDraggingInfo>)info
                  proposedItem: (id)item
            proposedChildIndex: (NSInteger)index
{
  return NSDragOperationNone; // TODO: Implement drag validation
}

- (BOOL) outlineView: (NSOutlineView *)outlineView
         writeItems: (NSArray *)items
       toPasteboard: (NSPasteboard *)pasteboard
{
  return NO; // TODO: Implement drag support
}

- (void) outlineView: (NSOutlineView *)outlineView
    sortDescriptorsDidChange: (NSArray *)oldDescriptors
{
  // TODO: Implement sorting support
}

- (NSArray *) outlineView: (NSOutlineView *)outlineView
    namesOfPromisedFilesDroppedAtDestination: (NSURL *)dropDestination
                             forDraggedItems: (NSArray *)items
{
  return nil; // TODO: Implement promised files support
}

#pragma mark - NSOutlineViewDelegate Protocol Stubs

- (void) outlineViewColumnDidMove: (NSNotification *)notification
{
}

- (void) outlineViewColumnDidResize: (NSNotification *)notification
{
}

- (void) outlineViewItemDidCollapse: (NSNotification *)notification
{
}

- (void) outlineViewItemDidExpand: (NSNotification *)notification
{
}

- (void) outlineViewItemWillCollapse: (NSNotification *)notification
{
}

- (void) outlineViewItemWillExpand: (NSNotification *)notification
{
}

- (void) outlineViewSelectionIsChanging: (NSNotification *)notification
{
}

- (BOOL) outlineView: (NSOutlineView *)outlineView shouldCollapseItem: (id)item
{
  return YES;
}

- (BOOL) outlineView: (NSOutlineView *)outlineView
    shouldEditTableColumn: (NSTableColumn *)tableColumn
                     item: (id)item
{
  return NO;
}

- (BOOL) outlineView: (NSOutlineView *)outlineView shouldExpandItem: (id)item
{
  return YES;
}

- (BOOL) outlineView: (NSOutlineView *)outlineView
    shouldSelectTableColumn: (NSTableColumn *)tableColumn
{
  return YES;
}

- (NSCell *) outlineView: (NSOutlineView *)outlineView
    dataCellForTableColumn: (NSTableColumn *)tableColumn
                      item: (id)item
{
  return nil;
}

- (CGFloat) outlineView: (NSOutlineView *)outlineView heightOfRowByItem: (id)item
{
  return [outlineView rowHeight];
}

- (CGFloat) outlineView: (NSOutlineView *)outlineView
    sizeToFitWidthOfColumn: (NSInteger)column
{
  return 0;
}

- (void) outlineView: (NSOutlineView *)outlineView
    willDisplayOutlineCell: (id)cell
            forTableColumn: (NSTableColumn *)tableColumn
                      item: (id)item
{
}

- (BOOL) selectionShouldChangeInOutlineView: (NSOutlineView *)outlineView
{
  return YES;
}

- (void) outlineView: (NSOutlineView *)outlineView
    didClickTableColumn: (NSTableColumn *)tableColumn
{
}

- (NSView *) outlineView: (NSOutlineView *)outlineView
     viewForTableColumn: (NSTableColumn *)tableColumn
                   item: (id)item
{
  return nil;
}

- (NSTableRowView *) outlineView: (NSOutlineView *)outlineView
                 rowViewForItem: (id)item
{
  return nil;
}

- (void) outlineView: (NSOutlineView *)outlineView
      didAddRowView: (NSTableRowView *)rowView
             forRow: (NSInteger)row
{
}

- (void) outlineView: (NSOutlineView *)outlineView
    didRemoveRowView: (NSTableRowView *)rowView
              forRow: (NSInteger)row
{
}

@end
