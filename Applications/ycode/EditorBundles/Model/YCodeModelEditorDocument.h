/*
   Project: Ycode

   Copyright (C) 2025 Free Software Foundation

   Author: Gregory Casamento

   Created: 2025-01-15

   This application is free software; you can redistribute it and/or
   modify it under the terms of the GNU General Public
   License as published by the Free Software Foundation; either
   version 3 of the License, or (at your option) any later version.

   This application is distributed in the hope that it will be useful,
   but WITHOUT ANY WARRANTY; without even the implied warranty of
   MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
   General Public License for more details.

   You should have received a copy of the GNU General Public
   License along with this application; if not, see
   <https://www.gnu.org/licenses/>.
*/

#ifndef YCODE_MODEL_EDITOR_DOCUMENT_H
#define YCODE_MODEL_EDITOR_DOCUMENT_H
#import "YCodeEditorDocument.h"
@class YCModelCanvas;
@protocol YCModelEditing
- (void) selectModelObjectNamed: (NSString *)name;
- (void) moveSelectedModelBy: (NSSize)delta resize: (BOOL)resize;
- (void) beginModelConnectionTo: (NSString *)name;
- (NSArray *) modelPasteboardTypes;
- (BOOL) acceptModelPasteboard: (NSPasteboard *)pasteboard
                       target: (NSString *)name
                        point: (NSPoint)point
                      testing: (BOOL)testing;
@end
@interface YCodeModelEditorDocument : YCodeEditorDocument
{
  NSView *_editorView;
  NSScrollView *_objectScrollView;
  NSScrollView *_scrollView;
  NSArray *_objects;
  NSArray *_connections;
  NSTableView *_connectionTable;
  NSTextField *_connectionHeading;
  NSMutableDictionary *_endpointViews;
  NSMutableArray *_connectionLineWindows;
  NSMutableArray *_connectionTagWindows;
  BOOL _updatingConnectionLine;
  BOOL _applicationInactive;
  id<YCModelEditing> _editingDelegate;
  NSData *_archiveData;
  NSString *_selectedObjectName;
  NSString *_connectionDragSource;
  NSPoint _connectionDragPoint;
  NSDictionary *_namedObjects;
}

- (void) setEditingDelegate: (id<YCModelEditing>)delegate;
- (BOOL) loadGormData: (NSData *)data;
- (void) selectModelObjectNamed: (NSString *)name;
- (BOOL) hasEditingDelegate;
- (NSArray *) modelPasteboardTypes;
- (BOOL) acceptModelDrag: (id<NSDraggingInfo>)drag
               inCanvas: (NSView *)canvas
                testing: (BOOL)testing;
- (void) beginConnectionDragAtWindowPoint: (NSPoint)point;
- (void) updateConnectionDragAtWindowPoint: (NSPoint)point;
- (void) connectSelectionAtWindowPoint: (NSPoint)point;
- (NSString *) modelObjectAtPoint: (NSPoint)point inCanvas: (NSView *)canvas;
- (void) selectAtPoint: (NSPoint)point inCanvas: (NSView *)canvas;
- (void) moveSelectionBy: (NSSize)delta resize: (BOOL)resize;
- (void) drawSelectionInCanvas: (NSView *)canvas;
- (NSDictionary *) selectedConnection;
- (void) addLabel: (NSString *)label toCanvas: (NSView *)canvas y: (CGFloat *)y;
- (void) updateConnectionLine;
- (void) hideConnectionLine;
- (void) registerEndpointView: (NSView *)view forObject: (id)object;
- (void) registerEndpointHierarchy: (NSView *)view;
- (void) addMenu: (NSMenu *)menu
       toCanvas: (YCModelCanvas *)canvas
          depth: (NSUInteger)depth
        visited: (NSMutableSet *)visited;
@end

#endif
