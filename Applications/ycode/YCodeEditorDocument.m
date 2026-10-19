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

#import "YCodeEditorDocument.h"
#import "YCodeEditorRegistry.h"
#import "YCodeEditorController.h"

@implementation YCodeEditorDocument

+ (NSUInteger) editorAPIVersion
{
  return 1;
}

+ (NSString *) editorIdentifier
{
  return nil;
}

+ (NSString *) editorKind
{
  return @"generic";
}

+ (NSInteger) editorPriority
{
  return 0;
}

+ (BOOL) canOpenFilePath: (NSString *)path
{
  return NO;
}

- (id) initWithFilePath: (NSString *)filePath
{
  if ([self class] == [YCodeEditorDocument class])
    {
      Class editor = [[YCodeEditorRegistry sharedRegistry]
          editorClassForFilePath: filePath];
      [self release];
      return [[editor alloc] initWithFilePath: filePath];
    }
  self = [super init];
  if (self)
    {
      ASSIGN (_filePath, filePath);
      _undoManager = [NSUndoManager new];
      _lastModified = [[NSDate date] retain];
    }
  return self;
}

- (void) dealloc
{
  [NSObject cancelPreviousPerformRequestsWithTarget: self];
  [[NSNotificationCenter defaultCenter] removeObserver: self];
  RELEASE (_filePath);
  RELEASE (_undoManager);
  RELEASE (_lastModified);
  [super dealloc];
}

- (void) setFilePath: (NSString *)path
{
  ASSIGN (_filePath, path);
}

- (BOOL) isEditable
{
  return NO;
}

- (BOOL) isImageDocument
{
  return [[[self class] editorKind] isEqual: @"image"];
}

- (BOOL) isSoundDocument
{
  return [[[self class] editorKind] isEqual: @"sound"];
}

+ (BOOL) isSoundFilePath: (NSString *)path
{
  Class editor =
      [[YCodeEditorRegistry sharedRegistry] editorClassForFilePath: path];
  return [[editor editorKind] isEqual: @"sound"];
}

- (NSImage *) image
{
  return nil;
}

- (NSView *) editorView
{
  return nil;
}

- (NSScrollView *) scrollView
{
  return nil;
}

- (NSTextView *) textView
{
  return nil;
}

- (NSString *) content
{
  return @"";
}

- (void) setContent: (NSString *)content
{
}

- (BOOL) loadFromFile
{
  return NO;
}

- (BOOL) writeContentsToFile
{
  return NO;
}

- (void) checkForExternalChanges
{
}

- (void) insertText: (NSString *)text atLocation: (NSUInteger)location
{
}

- (NSString *) selectedText
{
  return @"";
}

- (NSRange) selectedRange
{
  return NSMakeRange (NSNotFound, 0);
}

- (void) setSelectedRange: (NSRange)range
{
}

- (YCodeSyntaxHighlighter *) syntaxHighlighter
{
  return nil;
}

- (void) applySyntaxHighlighting
{
}

- (void) setModified: (BOOL)modified
{
  BOOL changed = [self isEditable] && modified;
  BOOL external = _externalChange;
  if (!modified)
    _externalChange = NO;
  if (_modified == changed && external == _externalChange)
    return;
  _modified = changed;
  [[NSNotificationCenter defaultCenter]
      postNotificationName: @"YCodeFileModificationDidChange"
                    object: _editorController];
}

- (id) initWithFilePath: (NSString *)filePath content: (NSString *)content
{
  self = [self initWithFilePath: filePath];
  if (self && content)
    {
      [self setContent: content];
      [self setModified: NO];
    }
  return self;
}

- (NSString *) filePath
{
  return _filePath;
}

- (NSString *) fileName
{
  return [_filePath lastPathComponent];
}

- (NSString *) fileExtension
{
  return [_filePath pathExtension];
}

- (BOOL) isModified
{
  return _modified;
}

- (NSDate *) lastModified
{
  return _lastModified;
}

- (BOOL) reloadFromFile
{
  if ([self isModified])
    {
      NSAlert *alert = [[NSAlert alloc] init];
      [alert setMessageText: @"Reload File?"];
      [alert setInformativeText: @"This will discard any unsaved changes."];
      [alert addButtonWithTitle: @"Reload"];
      [alert addButtonWithTitle: @"Cancel"];

      NSInteger result = [alert runModal];
      RELEASE (alert);

      if (result != NSAlertFirstButtonReturn)
        {
          return NO;
        }
    }

  return [self loadFromFile];
}

- (BOOL) hasExternalChanges
{
  return _externalChange;
}

- (YCodeEditorController *) editorController
{
  return _editorController;
}

- (void) setEditorController: (YCodeEditorController *)controller
{
  _editorController = controller; // weak reference
}

- (BOOL) saveToFile
{
  // Previewing an image must never overwrite its bytes with text.
  if (![self isEditable])
    return YES;
  [self checkForExternalChanges];
  if (_externalChange)
    {
      NSAlert *alert = AUTORELEASE ([[NSAlert alloc] init]);
      [alert setMessageText: @"File Changed Outside Ycode"];
      [alert
          setInformativeText:
              [NSString
                  stringWithFormat:
                      @"%@ has changed or is no longer readable on disk. Overwrite it with your edits, reload the disk version, or cancel saving.",
                      [self fileName]]];
      [alert addButtonWithTitle: @"Overwrite"];
      [alert addButtonWithTitle: @"Reload"];
      [alert addButtonWithTitle: @"Cancel"];
      NSInteger choice = [alert runModal];
      if (choice == NSAlertSecondButtonReturn)
        {
          BOOL loaded = [self loadFromFile];
          if (loaded)
            [_undoManager removeAllActions];
          return loaded;
        }
      if (choice != NSAlertFirstButtonReturn)
        return NO;
    }
  BOOL success = [self writeContentsToFile];

  if (success)
    {
      [self setModified: NO];
      ASSIGN (_lastModified, [NSDate date]);
      [[NSNotificationCenter defaultCenter]
          postNotificationName: YCodeCurrentDocumentDidChangeNotification
                        object: _editorController];
    }

  return success;
}

@end
