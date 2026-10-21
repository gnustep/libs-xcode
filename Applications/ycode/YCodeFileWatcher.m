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

#import "YCodeFileWatcher.h"

#if defined(_WIN32)
#include <windows.h>
#elif defined(__linux__)
#include <sys/inotify.h>
#include <poll.h>
#include <unistd.h>
#include <fcntl.h>
#include <errno.h>
#include <string.h>
#elif defined(__APPLE__) || defined(__FreeBSD__) || defined(__NetBSD__)       \
    || defined(__OpenBSD__) || defined(__DragonFly__)
#define YCODE_KQUEUE 1
#include <sys/event.h>
#include <unistd.h>
#include <fcntl.h>
#include <errno.h>
#endif

@implementation YCodeFileWatcher
- (id) initWithDirectory: (NSString *)directory paths: (NSArray *)paths
{
  self = [super init];
  if (!self)
    return nil;
  _directory = [directory copy];
  _paths = [paths copy];
  _lock = [NSLock new];
  _watchedDirectories = [NSMutableDictionary new];
  _directoryDescriptors = [NSMutableDictionary new];
  _changedDirectories = [NSMutableSet new];
  _stopPipe[0] = _stopPipe[1] = _eventFD = -1;
#if defined(_WIN32)
  unichar *wide = calloc ([directory length] + 1, sizeof (unichar));
  [directory getCharacters: wide];
  _changeHandle = FindFirstChangeNotificationW (
      (LPCWSTR)wide, FALSE,
      FILE_NOTIFY_CHANGE_FILE_NAME | FILE_NOTIFY_CHANGE_DIR_NAME
          | FILE_NOTIFY_CHANGE_LAST_WRITE | FILE_NOTIFY_CHANGE_SIZE);
  free (wide);
  _stopHandle = CreateEvent (NULL, TRUE, FALSE, NULL);
  if (_changeHandle == INVALID_HANDLE_VALUE || !_stopHandle)
    {
      [self release];
      return nil;
    }
#elif defined(__linux__) || defined(YCODE_KQUEUE)
  if (pipe (_stopPipe) != 0)
    {
      [self release];
      return nil;
    }
  fcntl (_stopPipe[0], F_SETFD, FD_CLOEXEC);
  fcntl (_stopPipe[1], F_SETFD, FD_CLOEXEC);
#if defined(__linux__)
  _eventFD = inotify_init1 (IN_CLOEXEC);
  if (_eventFD < 0 || ![self addDirectory: directory])
    {
      [self release];
      return nil;
    }
#else
  _eventFD = kqueue ();
  if (_eventFD < 0)
    {
      [self release];
      return nil;
    }
  fcntl (_eventFD, F_SETFD, FD_CLOEXEC);
#endif
#else
  NSLog (@"File notifications are unavailable on this platform: %@",
         directory);
  [self release];
  return nil;
#endif
  [NSThread detachNewThreadSelector: @selector (watch)
                           toTarget: self
                         withObject: nil];
  return self;
}

- (NSString *) directory
{
  return _directory;
}

- (BOOL) addDirectory: (NSString *)directory
{
#if defined(__linux__)
  [_lock lock];
  if ([_directoryDescriptors objectForKey: directory])
    {
      [_lock unlock];
      return YES;
    }
  int descriptor = inotify_add_watch (
      _eventFD, [directory fileSystemRepresentation],
      IN_CLOSE_WRITE | IN_MOVED_TO | IN_MOVED_FROM | IN_CREATE | IN_DELETE
          | IN_DELETE_SELF | IN_MOVE_SELF);
  if (descriptor >= 0)
    {
      NSNumber *key = [NSNumber numberWithInt: descriptor];
      NSString *previous = [_watchedDirectories objectForKey: key];
      if (previous)
        [_directoryDescriptors removeObjectForKey: previous];
      [_watchedDirectories setObject: directory forKey: key];
      [_directoryDescriptors setObject: key forKey: directory];
    }
  [_lock unlock];
  if (descriptor < 0)
    NSLog (@"Unable to watch directory %@: %s", directory, strerror (errno));
  return descriptor >= 0;
#else
  return NO;
#endif
}

- (void) removeDirectory: (NSString *)directory
{
#if defined(__linux__)
  [_lock lock];
  NSNumber *key = [_directoryDescriptors objectForKey: directory];
  if (key)
    {
      inotify_rm_watch (_eventFD, [key intValue]);
      [_watchedDirectories removeObjectForKey: key];
      [_directoryDescriptors removeObjectForKey: directory];
    }
  [_lock unlock];
#endif
}

- (NSArray *) paths
{
  return _paths;
}

- (void) stop
{
  if (_stopped)
    return;
  _stopped = YES;
#if defined(_WIN32)
  if (_stopHandle)
    SetEvent (_stopHandle);
#elif defined(__linux__) || defined(YCODE_KQUEUE)
  if (_stopPipe[1] >= 0)
    {
      char byte = 0;
      (void)write (_stopPipe[1], &byte, 1);
    }
#endif
}

- (void) dealloc
{
#if defined(_WIN32)
  if (_changeHandle && _changeHandle != INVALID_HANDLE_VALUE)
    FindCloseChangeNotification (_changeHandle);
  if (_stopHandle)
    CloseHandle (_stopHandle);
#elif defined(__linux__) || defined(YCODE_KQUEUE)
  if (_eventFD >= 0)
    close (_eventFD);
  if (_stopPipe[0] >= 0)
    close (_stopPipe[0]);
  if (_stopPipe[1] >= 0)
    close (_stopPipe[1]);
#endif
  [_directory release];
  [_paths release];
  [_watchedDirectories release];
  [_directoryDescriptors release];
  [_changedDirectories release];
  [_lock release];
  [super dealloc];
}

- (void) deliver
{
  [_lock lock];
  _pending = NO;
  NSArray *directories = [_changedDirectories allObjects];
  [_changedDirectories removeAllObjects];
  [_lock unlock];
  if (!_stopped)
    [[NSNotificationCenter defaultCenter]
        postNotificationName: @"YCodeDirectoryDidChange"
                      object: self
                    userInfo: [NSDictionary
                                 dictionaryWithObject: directories
                                               forKey: @"directories"]];
}

- (void) changed
{
  [_lock lock];
  BOOL schedule = !_pending;
  _pending = YES;
  [_lock unlock];
  if (schedule)
    [self performSelectorOnMainThread: @selector (deliver)
                           withObject: nil
                        waitUntilDone: NO];
}

- (void) watch
{
  NSAutoreleasePool *pool = [NSAutoreleasePool new];
#if defined(_WIN32)
  HANDLE handles[2] = { _stopHandle, _changeHandle };
  while (WaitForMultipleObjects (2, handles, FALSE, INFINITE)
         == WAIT_OBJECT_0 + 1)
    {
      if (!FindNextChangeNotification (_changeHandle))
        break;
      NSAutoreleasePool *iteration = [NSAutoreleasePool new];
      [self changed];
      [iteration drain];
    }
#elif defined(__linux__)
  struct pollfd descriptors[2]
      = { { _stopPipe[0], POLLIN, 0 }, { _eventFD, POLLIN, 0 } };
  for (;;)
    {
      int count = poll (descriptors, 2, -1);
      if (count < 0 && errno == EINTR)
        continue;
      if (count < 0 || descriptors[0].revents
          || !(descriptors[1].revents & POLLIN))
        break;
      char buffer[16384];
      ssize_t length = read (_eventFD, buffer, sizeof (buffer));
      if (length <= 0)
        break;
      NSAutoreleasePool *iteration = [NSAutoreleasePool new];
      BOOL relevant = NO;
      ssize_t offset = 0;
      while (offset + (ssize_t)sizeof (struct inotify_event) <= length)
        {
          struct inotify_event *event
              = (struct inotify_event *)(buffer + offset);
          BOOL eventRelevant = NO;
          if (event->mask & IN_IGNORED)
            {
              [_lock lock];
              NSNumber *key = [NSNumber numberWithInt: event->wd];
              NSString *directory = [_watchedDirectories objectForKey: key];
              if (directory)
                [_directoryDescriptors removeObjectForKey: directory];
              [_watchedDirectories removeObjectForKey: key];
              [_lock unlock];
              offset += sizeof (struct inotify_event) + event->len;
              continue;
            }
          if (!event->len || (event->mask & IN_Q_OVERFLOW)
              || (!_paths
                  && (event->mask
                      & (IN_CREATE | IN_DELETE | IN_MOVED_FROM
                         | IN_MOVED_TO))))
            eventRelevant = YES;
          else
            {
              NSString *name = [[NSFileManager defaultManager]
                  stringWithFileSystemRepresentation: event->name
                                              length: strlen (event->name)];
              NSEnumerator *paths = [_paths objectEnumerator];
              NSString *path;
              while ((path = [paths nextObject]) != nil)
                if ([[path lastPathComponent] isEqual: name])
                  {
                    eventRelevant = YES;
                    break;
                  }
            }
          if (eventRelevant)
            {
              relevant = YES;
              [_lock lock];
              NSString *directory = [_watchedDirectories
                  objectForKey: [NSNumber numberWithInt: event->wd]];
              /* Moves/deletions can replace a cached subtree at the same
                 path; rescan all listings in that uncommon case. */
              if (event->mask
                  & (IN_Q_OVERFLOW | IN_DELETE_SELF | IN_MOVE_SELF))
                [_changedDirectories
                    addObjectsFromArray: [_watchedDirectories allValues]];
              else if (directory)
                [_changedDirectories addObject: directory];
              [_lock unlock];
            }
          offset += sizeof (struct inotify_event) + event->len;
        }
      if (relevant)
        [self changed];
      [iteration drain];
    }
#elif defined(YCODE_KQUEUE)
  struct kevent event;
  EV_SET (&event, _stopPipe[0], EVFILT_READ, EV_ADD, 0, 0, NULL);
  kevent (_eventFD, &event, 1, NULL, 0, NULL);
  BOOL done = NO;
  while (!done)
    {
      NSAutoreleasePool *iteration = [NSAutoreleasePool new];
      NSMutableArray *fds = [NSMutableArray array];
      NSArray *watched = _paths ? [_paths arrayByAddingObject: _directory]
                                : [NSArray arrayWithObject: _directory];
      NSEnumerator *enumerator = [watched objectEnumerator];
      NSString *path;
      while ((path = [enumerator nextObject]) != nil)
        {
#ifdef O_EVTONLY
          int fd = open ([path fileSystemRepresentation], O_EVTONLY);
#else
          int fd
              = open ([path fileSystemRepresentation], O_RDONLY | O_NONBLOCK);
#endif
          if (fd < 0)
            continue;
          fcntl (fd, F_SETFD, FD_CLOEXEC);
          EV_SET (&event, fd, EVFILT_VNODE, EV_ADD | EV_CLEAR,
                  NOTE_WRITE | NOTE_DELETE | NOTE_RENAME | NOTE_EXTEND
                      | NOTE_ATTRIB,
                  0, NULL);
          if (kevent (_eventFD, &event, 1, NULL, 0, NULL) < 0)
            close (fd);
          else
            [fds addObject: [NSNumber numberWithInt: fd]];
        }
      [self changed]; // Also covers edits during watch attachment/replacement.
      int count;
      do
        {
          count = kevent (_eventFD, NULL, 0, &event, 1, NULL);
        }
      while (count < 0 && errno == EINTR);
      done = count < 0 || event.filter == EVFILT_READ;
      NSEnumerator *numbers = [fds objectEnumerator];
      NSNumber *number;
      while ((number = [numbers nextObject]) != nil)
        close ([number intValue]);
      if (!done)
        [self changed];
      /* Reattach file vnode watches after directory events/atomic saves. */
      [iteration drain];
    }
#endif
  [pool drain];
}

@end
