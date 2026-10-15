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

#import "YCodeDocumentController.h"
#import "YCodeProject.h"
#import "YCodeEditorController.h"

@implementation YCodeDocumentController

- (BOOL)openWorkspaceFile:(NSString *)path error:(NSError **)error
{
    NSFileManager *manager = [NSFileManager defaultManager];
    BOOL directory = NO;
    path = [path stringByStandardizingPath];
    if (![manager fileExistsAtPath:path isDirectory:&directory]) return NO;
    NSString *extension = [[path pathExtension] lowercaseString];
    if (directory || [extension isEqual:@"xcodeproj"] || [extension isEqual:@"pcproj"])
        return [self openDocumentWithContentsOfURL:[NSURL fileURLWithPath:path]
            display:YES error:error] != nil;

    NSString *folder = [path stringByDeletingLastPathComponent];
    NSString *projectPath = nil;
    NSString *search = folder;
    while ([search length]) {
        NSArray *entries = [[manager contentsOfDirectoryAtPath:search error:NULL]
            sortedArrayUsingSelector:@selector(compare:)];
        NSEnumerator *extensions = [[NSArray arrayWithObjects:@"xcodeproj", @"pcproj", nil] objectEnumerator];
        NSString *projectExtension;
        while (!projectPath && (projectExtension = [extensions nextObject]) != nil) {
            NSEnumerator *names = [entries objectEnumerator];
            NSString *name;
            while ((name = [names nextObject]) != nil) {
                if ([[[name pathExtension] lowercaseString] isEqual:projectExtension]) {
                    projectPath = [search stringByAppendingPathComponent:name];
                    break;
                }
            }
        }
        if (!projectPath && [YCodeProject isMakeProjectDirectory:search]) projectPath = search;
        if (projectPath) break;
        NSString *parent = [search stringByDeletingLastPathComponent];
        if ([parent isEqual:search]) break;
        search = parent;
    }
    if (!projectPath) projectPath = folder;
    YCodeProject *project = [self openDocumentWithContentsOfURL:[NSURL fileURLWithPath:projectPath]
        display:YES error:error];
    return project != nil && [[project editorController] openFile:path];
}

- (NSMenu *)recentDocumentsMenu
{
    NSMenu *menu = AUTORELEASE([[NSMenu alloc] initWithTitle:@"Recent Documents"]);
    [menu setDelegate:self];
    [menu setAutoenablesItems:NO];
    [self menuNeedsUpdate:menu];
    return menu;
}

- (void)menuNeedsUpdate:(NSMenu *)menu
{
    while ([menu numberOfItems]) [menu removeItemAtIndex:0];
    NSArray *urls = [self recentDocumentURLs];
#ifdef GNUSTEP
    // GNUstep stores the most recently opened URL at the end.
    urls = [[urls reverseObjectEnumerator] allObjects];
#endif
    {
      NSEnumerator *urlEnumerator = [urls objectEnumerator];
      NSURL *url;
      while ((url = [urlEnumerator nextObject]) != nil)
        {
          NSString *path = [url path];
          NSString *title = [path lastPathComponent];
          if (![title length]) title = [url absoluteString];
          NSUInteger matches = 0;
          {
            NSEnumerator *otherEnumerator = [urls objectEnumerator];
            NSURL *other;
            while ((other = [otherEnumerator nextObject]) != nil)
              if ([[[other path] lastPathComponent] isEqual:title]) matches++;
          }
          if (matches > 1)
              title = [NSString stringWithFormat:@"%@ — %@", title, [path stringByDeletingLastPathComponent]];
          NSMenuItem *item = AUTORELEASE([[NSMenuItem alloc] initWithTitle:title
              action:@selector(openRecentProject:) keyEquivalent:@""]);
          [item setTarget:self];
          [item setRepresentedObject:url];
          [item setToolTip:path];
          [item setEnabled:[url isFileURL] && [[NSFileManager defaultManager] fileExistsAtPath:path]];
          [menu addItem:item];
        }
    }
    if ([urls count]) [menu addItem:[NSMenuItem separatorItem]];
    NSMenuItem *clear = AUTORELEASE([[NSMenuItem alloc] initWithTitle:@"Clear Menu"
        action:@selector(clearRecentProjects:) keyEquivalent:@""]);
    [clear setTarget:self];
    [clear setEnabled:[urls count] > 0];
    [menu addItem:clear];
}

- (IBAction)openRecentProject:(id)sender
{
    NSURL *url = [sender representedObject];
    if (![url isKindOfClass:[NSURL class]] || ![url isFileURL]) return;
    NSError *error = nil;
    [self openDocumentWithContentsOfURL:url display:YES error:&error];
    if (error) [self presentError:error];
}

- (IBAction)clearRecentProjects:(id)sender
{
    AUTORELEASE(RETAIN(sender));
    [self clearRecentDocuments:sender];
    if ([sender respondsToSelector:@selector(menu)] && [sender menu])
        [self menuNeedsUpdate:[sender menu]];
}

- (NSString *)typeForContentsOfURL:(NSURL *)url error:(NSError **)error
{
    if ([YCodeProject isProjectDirectory:[url path]] &&
        ![[NSArray arrayWithObjects:@"xcodeproj", @"pcproj", nil] containsObject:[[url path] pathExtension]])
        return @"YCodeMakeProjectType";
    return [super typeForContentsOfURL:url error:error];
}

- (NSString *)typeFromFileExtension:(NSString *)fileExtension
{
    if ([fileExtension isEqualToString:@"xcodeproj"]) {
        return @"YCodeXcodeProjectType";
    }

    if ([fileExtension isEqualToString:@"pcproj"]) {
        return @"YCodeProjectCenterProjectType";
    }

    return [super typeFromFileExtension:fileExtension];
}

- (Class)documentClassForType:(NSString *)type
{
    if ([type isEqualToString:@"YCodeMakeProjectType"]) return [YCodeProject class];
    if ([type isEqualToString:@"YCodeXcodeProjectType"] ||
        [type isEqualToString:@"YCodeProjectCenterProjectType"] ||
        [type isEqualToString:@"xcodeproj"] ||
        [type isEqualToString:@"pcproj"]) {
        return [YCodeProject class];
    }

    return [super documentClassForType:type];
}

- (NSArray *)fileExtensionsFromType:(NSString *)type
{
    if ([type isEqualToString:@"YCodeXcodeProjectType"] ||
        [type isEqualToString:@"xcodeproj"]) {
        return [NSArray arrayWithObject:@"xcodeproj"];
    }

    if ([type isEqualToString:@"YCodeProjectCenterProjectType"] ||
        [type isEqualToString:@"pcproj"]) {
        return [NSArray arrayWithObject:@"pcproj"];
    }

    return [super fileExtensionsFromType:type];
}

- (NSString *)displayNameForType:(NSString *)type
{
    if ([type isEqual:@"YCodeMakeProjectType"]) return @"Project folder";
    if ([type isEqualToString:@"YCodeXcodeProjectType"] ||
        [type isEqualToString:@"xcodeproj"]) {
        return @"Xcode project";
    }

    if ([type isEqualToString:@"YCodeProjectCenterProjectType"] ||
        [type isEqualToString:@"pcproj"]) {
        return @"ProjectCenter project";
    }

    return [super displayNameForType:type];
}

@end
