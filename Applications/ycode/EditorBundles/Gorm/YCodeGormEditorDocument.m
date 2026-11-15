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

#import "YCodeEditorDocument.h"
#import "YCodeEditorController.h"
#import "AppController.h"
#import "../Model/YCodeModelEditorDocument.h"
#import <GormCore/GormAbstractDelegate.h>
#import <InterfaceBuilder/IBInspector.h>
#import <GormCore/GormNSWindow.h>
#import <GormCore/GormDocument.h>
#import <GormCore/GormClassManager.h>
#import <GormCore/GormFilePrefsManager.h>
#import <GormCore/GormPalettesManager.h>
#import <GormCore/GormWrapperLoader.h>
#import <GormCore/GormWrapperBuilder.h>

/* Gorm owns the graph and archive format; Ycode owns every editing surface.
 * Suppress Gorm's floating editors even when attachObject opens an editor. */
@interface YCodeHostedGormDocument : GormDocument
@end
@implementation YCodeHostedGormDocument
- (void) touch
{
  [super touch];
  [[NSNotificationCenter defaultCenter]
      postNotificationName: @"YCodeGormDocumentChanged"
                    object: self];
}

- (GormFilePrefsManager *) filePrefsManager
{
  if (!filePrefsManager)
    {
      filePrefsManager = [GormFilePrefsManager new];
      if ([self infoData])
        [filePrefsManager loadFromData: [self infoData]];
    }
  return filePrefsManager;
}

- (id<IBEditors>) openEditorForObject: (id)object
{
  return nil;
}

- (id<IBEditors>) openEditorForObject: (id)object withParentObject: (id)parent
{
  return nil;
}

- (id<IBEditors>) editorForObject: (id)object
                        inEditor: (id<IBEditors>)editor
                          create: (BOOL)flag
{
  return nil;
}

/* The graph's windows are retained model objects, never presented windows.
 * Gorm's GUI close path sets releasedWhenClosed and consumes their ownership. */
- (void) close
{
  [self setDocumentOpen: NO];
  [[NSNotificationCenter defaultCenter] removeObserver: self];
}

- (void) detachObject: (id)object closeEditor: (BOOL)flag
{
  /* Gorm closes named windows with releasedWhenClosed enabled. Supply the
   * ownership consumed by that GUI convention for our retained graph. */
  if ([object isKindOfClass: [NSWindow class]] && [self nameForObject: object])
    [object retain];
  [super detachObject: object closeEditor: flag];
}

- (void) setDocumentActive: (BOOL)flag
{
}

- (void) setSelectionFromEditor: (id<IBEditors>)editor
{
}

@end

@interface YCodeGormPalettesManager : GormPalettesManager
@end
@implementation YCodeGormPalettesManager
- (id) init
{
  self = [super init];
  if (self)
    {
      [substituteClasses setObject: @"NSWindow" forKey: @"GormNSWindow"];
      [substituteClasses setObject: @"NSPanel" forKey: @"GormNSPanel"];
    }
  return self;
}

@end

@interface YCodeGormServices : GormAbstractDelegate
{
  GormDocument *_activeDocument;
}

+ (YCodeGormServices *) sharedServices;
- (void) setActiveDocument: (GormDocument *)document;
@end
@implementation YCodeGormServices
+ (YCodeGormServices *) sharedServices
{
  static YCodeGormServices *services = nil;
  if (!services)
    {
      services = [[self alloc] init];
      /* Palette bundles supply categories selecting the native inspectors.
       * Load their code without opening Gorm's palette windows. */
      NSString *path =
          [[NSWorkspace sharedWorkspace] fullPathForApplication: @"Gorm"];
      NSBundle *bundle = path ? [NSBundle bundleWithPath: path] : nil;
      NSEnumerator *paths =
          [[bundle pathsForResourcesOfType: @"palette"
                               inDirectory: nil] objectEnumerator];
      NSString *palette;
      while ((palette = [paths nextObject]))
        [[NSBundle bundleWithPath: palette] load];
    }
  if ([[NSApp delegate] respondsToSelector: @selector (setEditorServices:)])
    [(AppController *)[NSApp delegate] setEditorServices: services];
  return services;
}

- (BOOL) isInTool
{
  return YES;
}

- (GormPalettesManager *) palettesManager
{
  if (!_palettesManager)
    _palettesManager = [YCodeGormPalettesManager new];
  return _palettesManager;
}

- (void) setActiveDocument: (GormDocument *)document
{
  if (_activeDocument != document)
    {
      _connectSource = nil;
      _connectDestination = nil;
      _isConnecting = NO;
    }
  _activeDocument = document;
}

/* Embedded inspectors must never draw connection lines on graph windows. */
- (void) displayConnectionBetween: (id)source and: (id)destination
{
  _connectSource = source;
  _connectDestination = destination;
}

- (id<IBDocuments>) activeDocument
{
  return _activeDocument;
}

@end

@interface YCodeGormEditorDocument : YCodeEditorDocument <YCModelEditing>
{
  YCodeHostedGormDocument *_document;
  YCodeModelEditorDocument *_preview;
  NSView *_inspector;
  NSView *_objectControls;
  NSMutableDictionary *_nativeInspectors;
  NSMutableDictionary *_nativeSections;
  id _inspectedObject;
  NSMutableDictionary *_fields;
  NSPopUpButton *_objects;
  NSPopUpButton *_newObject;
  NSPopUpButton *_destination;
  NSPopUpButton *_connectionType;
  NSString *_selectedName;
  NSDictionary *_diskState;
  BOOL _refreshing;
}

- (NSDictionary *) diskState;
- (BOOL) refreshPreview;
- (void) refreshInspector;
- (void) refreshNativeInspectors;
- (void) gormDocumentChanged: (NSNotification *)notification;
- (void) applyAttributes: (id)sender;
- (void) chooseObject: (id)sender;
- (void) addObject: (id)sender;
- (void) deleteObject: (id)sender;
- (void) addConnection: (id)sender;
- (void) deleteConnection: (id)sender;
- (void) changed;
@end

static NSTextField *
YCField (NSView *view, NSString *title, CGFloat y)
{
  NSTextField *label =
      [[NSTextField alloc] initWithFrame: NSMakeRect (8, y, 76, 24)];
  [label setStringValue: title];
  [label setEditable: NO];
  [label setBezeled: NO];
  [label setDrawsBackground: NO];
  [view addSubview: label];
  [label release];
  NSTextField *field =
      [[NSTextField alloc] initWithFrame: NSMakeRect (86, y, 184, 24)];
  [view addSubview: field];
  return [field autorelease];
}
static void
YCButton (NSView *view, NSString *title, CGFloat x, CGFloat y, id target,
          SEL action)
{
  NSButton *button =
      [[NSButton alloc] initWithFrame: NSMakeRect (x, y, 126, 28)];
  [button setTitle: title];
  [button setTarget: target];
  [button setAction: action];
  [view addSubview: button];
  [button release];
}

static BOOL
YCWriteGormWrapper (NSFileWrapper *wrapper, NSString *path, NSError **error)
{
  NSFileManager *manager = [NSFileManager defaultManager];
  if ([wrapper isDirectory])
    {
      if (![manager createDirectoryAtPath: path
              withIntermediateDirectories: NO
                               attributes: nil
                                    error: error])
        return NO;
      NSDictionary *children = [wrapper fileWrappers];
      NSEnumerator *e = [children keyEnumerator];
      NSString *name;
      while ((name = [e nextObject]))
        if (![name isEqual: [name lastPathComponent]] || [name isEqual: @".."]
            || !YCWriteGormWrapper ([children objectForKey: name],
                                    [path stringByAppendingPathComponent: name],
                                    error))
          return NO;
      return YES;
    }
  if ([wrapper isRegularFile])
    return [[wrapper regularFileContents] writeToFile: path
                                              options: NSDataWritingAtomic
                                                error: error];
  return [wrapper writeToFile: path atomically: YES updateFilenames: NO];
}

@implementation YCodeGormEditorDocument
+ (NSString *) editorIdentifier
{
  return @"org.gnustep.ycode.gorm";
}

+ (NSString *) editorKind
{
  return @"model";
}

+ (NSInteger) editorPriority
{
  return 400;
}

+ (BOOL) canOpenFilePath: (NSString *)path
{
  BOOL directory = NO;
  if ([[NSFileManager defaultManager] fileExistsAtPath: path
                                           isDirectory: &directory]
      && !directory)
    return NO;
  return [[[path pathExtension] lowercaseString] isEqual: @"gorm"] &&
         [GormDocument
             instancesRespondToSelector: @selector (initWithDocumentPolicy:)]
         &&
         [[NSApp delegate] respondsToSelector: @selector (setEditorServices:)]
         && NSClassFromString (@"YCodeModelEditorDocument") != Nil;
}

- (id) initWithFilePath: (NSString *)path
{
  self = [super initWithFilePath: path];
  if (self)
    {
      [YCodeGormServices sharedServices];
      if (![[GormWrapperLoaderFactory sharedWrapperLoaderFactory]
              wrapperLoaderForType: @"GSGormFileType"]
          || ![[GormWrapperBuilderFactory sharedWrapperBuilderFactory]
              wrapperBuilderForType: @"GSGormFileType"])
        {
          [self release];
          return [[NSClassFromString (@"YCodeModelEditorDocument") alloc]
              initWithFilePath: path];
        }
      _preview = [[NSClassFromString (@"YCodeModelEditorDocument") alloc]
          initWithFilePath: path];
      [_preview setEditingDelegate: self];
      _inspector = [[NSView alloc] initWithFrame: NSMakeRect (0, 0, 280, 690)];
      _objectControls = [_inspector retain];
      _nativeInspectors = [NSMutableDictionary new];
      _nativeSections = [NSMutableDictionary new];
      _fields = [NSMutableDictionary new];
      _objects =
          [[NSPopUpButton alloc] initWithFrame: NSMakeRect (8, 650, 264, 28)
                                     pullsDown: NO];
      [_objects setTarget: self];
      [_objects setAction: @selector (chooseObject:)];
      [_inspector addSubview: _objects];
      NSArray *labels =
          [NSArray arrayWithObjects: @"Name", @"Title", @"X", @"Y", @"Width",
                                    @"Height", nil];
      NSUInteger i;
      for (i = 0; i < [labels count]; i++)
        {
          NSString *key = [labels objectAtIndex: i];
          NSTextField *field = YCField (_inspector, key, 614 - i * 32);
          [_fields setObject: field forKey: key];
        }
      YCButton (_inspector, @"Apply", 8, 414, self,
                @selector (applyAttributes:));
      YCButton (_inspector, @"Delete Object", 144, 414, self,
                @selector (deleteObject:));
      _newObject =
          [[NSPopUpButton alloc] initWithFrame: NSMakeRect (8, 370, 264, 28)
                                     pullsDown: NO];
      [_newObject
          addItemsWithTitles: [NSArray arrayWithObjects: @"Window", @"Button",
                                                       @"Text Field", @"Label",
                                                       @"View", @"Menu",
                                                       @"Menu Item", nil]];
      [_inspector addSubview: _newObject];
      YCButton (_inspector, @"Add Object", 8, 334, self,
                @selector (addObject:));
      NSTextField *help =
          [[NSTextField alloc] initWithFrame: NSMakeRect (8, 278, 264, 48)];
      [help
          setStringValue:
              @"Add controls inside the selected window or view; add items inside the selected menu."];
      [help setEditable: NO];
      [help setBezeled: NO];
      [help setDrawsBackground: NO];
      [_inspector addSubview: help];
      [help release];
      _destination =
          [[NSPopUpButton alloc] initWithFrame: NSMakeRect (8, 240, 264, 28)
                                     pullsDown: NO];
      [_inspector addSubview: _destination];
      _connectionType =
          [[NSPopUpButton alloc] initWithFrame: NSMakeRect (8, 204, 264, 28)
                                     pullsDown: NO];
      [_connectionType
          addItemsWithTitles: [NSArray
                                 arrayWithObjects: @"Outlet", @"Action", nil]];
      [_inspector addSubview: _connectionType];
      [_fields setObject: YCField (_inspector, @"Connection", 168)
                  forKey: @"Connection"];
      YCButton (_inspector, @"Connect", 8, 128, self,
                @selector (addConnection:));
      YCButton (_inspector, @"Disconnect", 144, 128, self,
                @selector (deleteConnection:));
      NSTextField *instructions =
          [[NSTextField alloc] initWithFrame: NSMakeRect (8, 10, 264, 104)];
      [instructions
          setStringValue:
              @"Select objects on the canvas or in the list above. Drag to move; Shift-drag to resize. Connections use the selected object as source and the destination chosen above. Select a connection in the canvas table to disconnect it."];
      [instructions setEditable: NO];
      [instructions setBezeled: NO];
      [instructions setDrawsBackground: NO];
      [_inspector addSubview: instructions];
      [instructions release];
      [_inspector release];
      _inspector = [[NSView alloc] initWithFrame: NSMakeRect (0, 0, 296, 730)];
      [_inspector addSubview: _objectControls];
      [[NSNotificationCenter defaultCenter]
          addObserver: self
             selector: @selector (gormDocumentChanged:)
                 name: @"YCodeGormDocumentChanged"
               object: nil];
    }
  return self;
}

- (void) dealloc
{
  [[NSNotificationCenter defaultCenter] removeObserver: self];
  [NSObject cancelPreviousPerformRequestsWithTarget: self];
  [_nativeSections release];
  [_nativeInspectors release];
  [_objectControls release];
  [_preview setEditingDelegate: nil];
  if ([[YCodeGormServices sharedServices] activeDocument] == _document)
    [[YCodeGormServices sharedServices] setActiveDocument: nil];
  [_document close];
  [_document release];
  [_preview release];
  [_inspector release];
  [_fields release];
  [_objects release];
  [_newObject release];
  [_destination release];
  [_connectionType release];
  [_selectedName release];
  [_diskState release];
  [super dealloc];
}

- (BOOL) isEditable
{
  return YES;
}

- (NSView *) editorView
{
  return [_preview editorView];
}

- (NSScrollView *) scrollView
{
  return [_preview scrollView];
}

- (NSView *) inspectorView
{
  [[YCodeGormServices sharedServices] setActiveDocument: _document];
  return _inspector;
}

- (BOOL) isModified
{
  return [_document isDocumentEdited];
}

- (BOOL) loadFromFile
{
  YCodeGormServices *services = [YCodeGormServices sharedServices];
  YCodeHostedGormDocument *document =
      [[YCodeHostedGormDocument alloc] initWithDocumentPolicy: services];
  BOOL loaded = NO;
  [services setActiveDocument: document];
  @try
    {
      [document setFileName: _filePath];
      [document setFileType: @"GSGormFileType"];
      loaded = [document readFromFile: _filePath ofType: @"GSGormFileType"];
      if (loaded &&
          [[document filePrefsManager] version] >
              [GormFilePrefsManager currentVersion])
        loaded = [services shouldLoadNewerArchive];
    }
  @catch (NSException *exception)
    {
      NSLog (@"Cannot load Gorm interface: %@", [exception reason]);
    }
  if (!loaded)
    {
      [services setActiveDocument: _document];
      [document release];
      return NO;
    }
  _inspectedObject = nil;
  [_nativeSections removeAllObjects];
  [_nativeInspectors removeAllObjects];
  [_document close];
  [_document release];
  _document = document;
  [document updateChangeCount: NSChangeCleared];
  ASSIGN (_diskState, [self diskState]);
  [self setModified: NO];
  return [self refreshPreview];
}

- (BOOL) refreshPreview
{
  if (_refreshing || !_document)
    return NO;
  _refreshing = YES;
  YCodeGormServices *services = [YCodeGormServices sharedServices];
  GormDocument *previous = (GormDocument *)[services activeDocument];
  [services setActiveDocument: _document];
  BOOL loaded = NO;
  BOOL older = [_document isOlderArchive];
  NSPoint scroll = [[[_preview scrollView] contentView] bounds].origin;
  @try
    {
      /* A display snapshot must not upgrade the on-disk archive or ask to save. */
      [_document setOlderArchive: NO];
      NSFileWrapper *wrapper =
          [_document fileWrapperRepresentationOfType: @"GSGormFileType"];
      NSData *data = [[[wrapper fileWrappers] objectForKey: @"objects.gorm"]
          regularFileContents];
      if (data)
        loaded = [_preview loadGormData: data];
      [[[_preview scrollView] contentView] scrollToPoint: scroll];
      [_preview selectModelObjectNamed: _selectedName];
    }
  @catch (NSException *exception)
    {
      NSLog (@"Cannot display Gorm interface: %@", [exception reason]);
    }
  @finally
    {
      [_document setOlderArchive: older];
      _refreshing = NO;
    }
  [self refreshInspector];
  [services setActiveDocument: previous];
  return loaded;
}

- (void) changed
{
  [_document touch];
  [self setModified: YES];
  [self refreshPreview];
}

- (void) selectModelObjectNamed: (NSString *)name
{
  ASSIGN (_selectedName, name);
  [_preview selectModelObjectNamed: name];
  [[YCodeGormServices sharedServices] setActiveDocument: _document];
  [self refreshInspector];
}

- (void) chooseObject: (id)sender
{
  [self selectModelObjectNamed: [_objects titleOfSelectedItem]];
}

- (void) gormDocumentChanged: (NSNotification *)notification
{
  if ([notification object] != _document || _refreshing)
    return;
  [self setModified: YES];
  [NSObject cancelPreviousPerformRequestsWithTarget: self
                                           selector: @selector (refreshPreview)
                                             object: nil];
  [self performSelector: @selector (refreshPreview)
             withObject: nil
             afterDelay: 0];
}

- (void) refreshNativeInspectors
{
  id selected = _selectedName ? [_document objectForName: _selectedName] : nil;
  if (selected == _inspectedObject && [[_inspector subviews] count])
    {
      NSEnumerator *inspectors =
          [[_nativeInspectors allValues] objectEnumerator];
      IBInspector *inspector;
      while ((inspector = [inspectors nextObject]))
        if ([inspector object] == selected && selected)
          [inspector revert: nil];
      return;
    }
  _inspectedObject = selected;
  [[YCodeGormServices sharedServices] setActiveDocument: _document];
  NSArray *old = [[_inspector subviews] copy];
  NSEnumerator *e = [old objectEnumerator];
  NSView *view;
  while ((view = [e nextObject]))
    [view removeFromSuperview];
  [old release];
  NSArray *titles =
      [NSArray arrayWithObjects: @"Attributes", @"Size", @"Connections",
                                @"Custom Class", @"Bindings", @"Help", nil];
  SEL selectors[] = { @selector (inspectorClassName),
                      @selector (sizeInspectorClassName),
                      @selector (connectInspectorClassName),
                      @selector (classInspectorClassName),
                      @selector (bindingsInspectorClassName),
                      @selector (helpInspectorClassName) };
  NSMutableArray *sections = [NSMutableArray array];
  CGFloat width = 296;
  NSUInteger i;
  for (i = 0; selected && i < [titles count]; i++)
    {
      NSString *name = [selected performSelector: selectors[i]];
      if (!name)
        continue;
      IBInspector *inspector = [_nativeInspectors objectForKey: name];
      if (!inspector)
        {
          inspector = [[NSClassFromString (name) alloc] init];
          if (inspector)
            {
              [_nativeInspectors setObject: inspector forKey: name];
              [inspector release];
            }
        }
      if (!inspector || ![inspector window])
        continue;
      [inspector setObject: selected];
      NSBox *section = [_nativeSections objectForKey: name];
      if (!section)
        {
          NSView *content = [[inspector window] contentView];
          NSSize size = [content frame].size;
          [content removeFromSuperview];
          CGFloat buttonsHeight = [inspector wantsButtons] ? 36 : 0;
          NSView *body = [[NSView alloc]
              initWithFrame: NSMakeRect (0, 0, size.width,
                                        size.height + buttonsHeight)];
          [content setFrameOrigin: NSMakePoint (0, buttonsHeight)];
          [body addSubview: content];
          if (buttonsHeight)
            {
              NSButton *ok = [inspector okButton];
              NSButton *revert = [inspector revertButton];
              [ok setFrame: NSMakeRect (size.width - 100, 4, 96, 28)];
              [revert setFrame: NSMakeRect (4, 4, 96, 28)];
              if (ok)
                [body addSubview: ok];
              if (revert)
                [body addSubview: revert];
            }
          section = [[NSBox alloc]
              initWithFrame: NSMakeRect (0, 0, size.width + 24,
                                        size.height + buttonsHeight + 40)];
          [section setTitle: [titles objectAtIndex: i]];
          [section setContentView: body];
          [body release];
          [_nativeSections setObject: section forKey: name];
          [section release];
        }
      width = MAX (width, NSWidth ([section frame]) + 16);
      [sections addObject: section];
    }
  NSBox *objects = [[NSBox alloc] initWithFrame: NSMakeRect (0, 0, 296, 730)];
  [objects setTitle: @"Objects and Connections"];
  [objects setContentView: _objectControls];
  [sections addObject: objects];
  [objects release];
  CGFloat height = 8;
  e = [sections reverseObjectEnumerator];
  while ((view = [e nextObject]))
    {
      [view setFrameOrigin: NSMakePoint (8, height)];
      [_inspector addSubview: view];
      height += NSHeight ([view frame]) + 8;
    }
  [_inspector setFrameSize: NSMakeSize (width, height)];
  if (_editorController && [_editorController currentDocument] == self)
    [[NSNotificationCenter defaultCenter]
        postNotificationName: YCodeCurrentDocumentDidChangeNotification
                      object: _editorController];
}

- (void) refreshInspector
{
  [self refreshNativeInspectors];
  NSString *destination = [[_destination titleOfSelectedItem] copy];
  NSMutableArray *names = [NSMutableArray array];
  NSEnumerator *objects = [[_document objects] objectEnumerator];
  id namedObject;
  while ((namedObject = [objects nextObject]))
    {
      NSString *name = [_document nameForObject: namedObject];
      if (name)
        [names addObject: name];
    }
  [names sortUsingSelector: @selector (compare:)];
  [_objects removeAllItems];
  [_objects addItemsWithTitles: names];
  [_destination removeAllItems];
  [_destination addItemsWithTitles: names];
  if ([destination length] && [names containsObject: destination])
    [_destination selectItemWithTitle: destination];
  else if ([names containsObject: @"NSOwner"])
    [_destination selectItemWithTitle: @"NSOwner"];
  [destination release];
  if (_selectedName)
    [_objects selectItemWithTitle: _selectedName];
  else
    [_objects selectItemAtIndex: -1];
  id object = _selectedName ? [_document objectForName: _selectedName] : nil;
  [[_fields objectForKey: @"Name"]
      setStringValue: _selectedName ? _selectedName : @""];
  NSString *title = @"";
  if ([object respondsToSelector: @selector (title)])
    title = [object title];
  else if ([object respondsToSelector: @selector (stringValue)])
    title = [object stringValue];
  [[_fields objectForKey: @"Title"] setStringValue: title ? title : @""];
  [[_fields objectForKey: @"Title"]
      setEnabled: [object respondsToSelector: @selector (setTitle:)] ||
                 [object respondsToSelector: @selector (setStringValue:)]];
  NSRect frame = NSZeroRect;
  BOOL geometry = [object isKindOfClass: [NSView class]] ||
                  [object isKindOfClass: [NSWindow class]];
  if (geometry)
    frame = [object frame];
  NSArray *keys =
      [NSArray arrayWithObjects: @"X", @"Y", @"Width", @"Height", nil];
  CGFloat values[] = { frame.origin.x, frame.origin.y, frame.size.width,
                       frame.size.height };
  NSUInteger i;
  for (i = 0; i < 4; i++)
    {
      NSTextField *field = [_fields objectForKey: [keys objectAtIndex: i]];
      [field setDoubleValue: values[i]];
      [field setEnabled: geometry];
    }
}

- (void) applyAttributes: (id)sender
{
  id object = _selectedName ? [_document objectForName: _selectedName] : nil;
  if (!object)
    return;
  NSString *name = [[_fields objectForKey: @"Name"] stringValue];
  if (![name length]
      || ([_document objectForName: name] &&
          [_document objectForName: name] != object))
    {
      NSBeep ();
      return;
    }
  if (![_selectedName isEqual: @"NSOwner"]
      && ![_selectedName isEqual: @"NSFirst"])
    {
      [_document setName: name forObject: object];
      ASSIGN (_selectedName, name);
    }
  NSString *title = [[_fields objectForKey: @"Title"] stringValue];
  if ([object respondsToSelector: @selector (setTitle:)])
    [object setTitle: title];
  else if ([object respondsToSelector: @selector (setStringValue:)])
    [object setStringValue: title];
  if ([object isKindOfClass: [NSView class]] ||
      [object isKindOfClass: [NSWindow class]])
    {
      NSRect rect = NSMakeRect (
          [[_fields objectForKey: @"X"] doubleValue],
          [[_fields objectForKey: @"Y"] doubleValue],
          MAX (1, [[_fields objectForKey: @"Width"] doubleValue]),
          MAX (1, [[_fields objectForKey: @"Height"] doubleValue]));
      if ([object isKindOfClass: [NSWindow class]])
        [object setFrame: rect display: NO];
      else
        [object setFrame: rect];
    }
  [self changed];
}

- (void) moveSelectedModelBy: (NSSize)delta resize: (BOOL)resize
{
  id object = _selectedName ? [_document objectForName: _selectedName] : nil;
  if (![object isKindOfClass: [NSView class]]
      && ![object isKindOfClass: [NSWindow class]])
    return;
  NSRect frame = [object frame];
  BOOL flipped =
      [object isKindOfClass: [NSView class]] && [[object superview] isFlipped];
  CGFloat dy = flipped ? -delta.height : delta.height;
  if (resize)
    {
      frame.size.width = MAX (1, frame.size.width + delta.width);
      frame.size.height = MAX (1, frame.size.height + dy);
    }
  else
    {
      frame.origin.x += delta.width;
      frame.origin.y += dy;
    }
  if ([object isKindOfClass: [NSWindow class]])
    [object setFrame: frame display: NO];
  else
    [object setFrame: frame];
  [self changed];
}

- (void) addObject: (id)sender
{
  NSString *kind = [_newObject titleOfSelectedItem];
  id parent = _selectedName ? [_document objectForName: _selectedName] : nil;
  id object = nil;
  if ([kind isEqual: @"Window"])
    object = [[GormNSWindow alloc]
        initWithContentRect: NSMakeRect (100, 100, 360, 240)
                  styleMask: NSTitledWindowMask | NSClosableWindowMask
                    backing: NSBackingStoreBuffered
                      defer: YES];
  else if ([kind isEqual: @"Menu"])
    object = [[NSMenu alloc] initWithTitle: @"Menu"];
  else if ([kind isEqual: @"Menu Item"])
    {
      if (![parent isKindOfClass: [NSMenu class]])
        {
          NSBeep ();
          return;
        }
      object = [[NSMenuItem alloc] initWithTitle: @"Item"
                                          action: NULL
                                   keyEquivalent: @""];
      [parent addItem: object];
    }
  else
    {
      if ([parent isKindOfClass: [NSWindow class]])
        parent = [parent contentView];
      if (![parent isKindOfClass: [NSView class]])
        {
          NSBeep ();
          return;
        }
      NSRect frame = NSMakeRect (20, 20, 120, 28);
      if ([kind isEqual: @"Button"])
        {
          object = [[NSButton alloc] initWithFrame: frame];
          [object setTitle: @"Button"];
        }
      else if ([kind isEqual: @"View"])
        object = [[NSView alloc] initWithFrame: NSMakeRect (20, 20, 160, 100)];
      else
        {
          object = [[NSTextField alloc] initWithFrame: frame];
          [object setStringValue: kind];
          if ([kind isEqual: @"Label"])
            {
              [object setEditable: NO];
              [object setBezeled: NO];
              [object setDrawsBackground: NO];
            }
        }
      [parent addSubview: object];
    }
  if ([object isKindOfClass: [NSWindow class]] ||
      [object isKindOfClass: [NSMenu class]])
    parent = nil;
  [_document attachObject: object toParent: parent];
  ASSIGN (_selectedName, [_document nameForObject: object]);
  [object release];
  [self changed];
}

- (void) deleteObject: (id)sender
{
  id object = _selectedName ? [_document objectForName: _selectedName] : nil;
  if (!object || object == [_document filesOwner]
      || object == [_document firstResponder])
    return;
  [_document detachObject: object];
  DESTROY (_selectedName);
  [self changed];
}

- (void) addConnection: (id)sender
{
  id source = _selectedName ? [_document objectForName: _selectedName] : nil;
  id destination =
      [_document objectForName: [_destination titleOfSelectedItem]];
  NSString *label = [[_fields objectForKey: @"Connection"] stringValue];
  if (!source || !destination || ![label length])
    {
      NSBeep ();
      return;
    }
  NSNibConnector *connector =
      [[[_connectionType titleOfSelectedItem] isEqual: @"Action"]
              ? [NSNibControlConnector alloc]
              : [NSNibOutletConnector alloc] init];
  [connector setSource: source];
  [connector setDestination: destination];
  [connector setLabel: label];
  [_document addConnector: (id<IBConnectors>)connector];
  [connector release];
  [self changed];
}

- (void) deleteConnection: (id)sender
{
  NSDictionary *row = [_preview selectedConnection];
  NSString *sourceName = [row objectForKey: @"source"];
  NSString *destinationName = [row objectForKey: @"destination"];
  if ([sourceName isEqual: @"File's Owner"])
    sourceName = @"NSOwner";
  if ([sourceName isEqual: @"First Responder"])
    sourceName = @"NSFirst";
  if ([destinationName isEqual: @"File's Owner"])
    destinationName = @"NSOwner";
  if ([destinationName isEqual: @"First Responder"])
    destinationName = @"NSFirst";
  NSEnumerator *e =
      [[NSArray arrayWithArray: [_document connections]] objectEnumerator];
  NSNibConnector *connector;
  while ((connector = [e nextObject]))
    if (([connector isKindOfClass: [NSNibControlConnector class]] ||
         [connector isKindOfClass: [NSNibOutletConnector class]])
        && [[connector label] isEqual: [row objectForKey: @"label"]] &&
        [[_document nameForObject: [connector source]] isEqual: sourceName] &&
        [[_document nameForObject: [connector destination]]
            isEqual: destinationName])
      {
        [_document removeConnector: (id<IBConnectors>)connector];
        [self changed];
        break;
      }
}

- (BOOL) writeContentsToFile
{
  NSError *error = nil;
  BOOL saved = NO;
  NSFileManager *manager = [NSFileManager defaultManager];
  NSString *temporary = [_filePath
      stringByAppendingFormat: @".%@.tmp", [[NSProcessInfo processInfo]
                                              globallyUniqueString]];
  NSString *backup = [temporary stringByAppendingString: @".backup"];
  BOOL movedOriginal = NO;
  @try
    {
      /* Build with Gorm, then stage the entire package before replacing it.
       * NSDocument saving requires the host app to register Gorm document
       * types globally, which would interfere with Ycode's project controller. */
      NSFileWrapper *wrapper =
          [_document fileWrapperRepresentationOfType: @"GSGormFileType"];
      if (wrapper && YCWriteGormWrapper (wrapper, temporary, &error))
        {
          BOOL exists = [manager fileExistsAtPath: _filePath];
          movedOriginal = exists &&
                          [manager moveItemAtPath: _filePath
                                           toPath: backup
                                            error: &error];
          if (!exists || movedOriginal)
            saved = [manager moveItemAtPath: temporary
                                     toPath: _filePath
                                      error: &error];
          if (movedOriginal)
            {
              if (saved)
                [manager removeItemAtPath: backup error: NULL];
              else if (![manager moveItemAtPath: backup
                                         toPath: _filePath
                                          error: NULL])
                NSLog (@"Original Gorm package retained at %@", backup);
            }
        }
    }
  @catch (NSException *exception)
    {
      NSLog (@"Cannot serialize Gorm interface: %@", [exception reason]);
    }
  [manager removeItemAtPath: temporary error: NULL];
  if (saved)
    {
      [_document updateChangeCount: NSChangeCleared];
      ASSIGN (_diskState, [self diskState]);
    }
  else
    NSLog (@"Cannot save Gorm interface %@: %@", _filePath, error);
  return saved;
}

- (NSDictionary *) diskState
{
  NSFileManager *manager = [NSFileManager defaultManager];
  NSMutableDictionary *state = [NSMutableDictionary dictionary];
  NSDirectoryEnumerator *e = [manager enumeratorAtPath: _filePath];
  NSString *relative;
  while ((relative = [e nextObject]))
    {
      NSDictionary *attributes = [manager
          attributesOfItemAtPath: [_filePath
                                     stringByAppendingPathComponent: relative]
                           error: NULL];
      if (attributes)
        [state setObject: [NSArray arrayWithObjects:
                                      [attributes objectForKey: NSFileType],
                                      [attributes objectForKey: NSFileSize],
                                      [attributes
                                          objectForKey: NSFileModificationDate],
                                      nil]
                  forKey: relative];
    }
  return state;
}

- (void) checkForExternalChanges
{
  if (![_diskState isEqual: [self diskState]])
    {
      _externalChange = YES;
      [[NSNotificationCenter defaultCenter]
          postNotificationName: @"YCodeFileModificationDidChange"
                        object: _editorController];
    }
}

@end
