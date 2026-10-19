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

#import <Foundation/Foundation.h>

/* One blocking OS event source per directory. Notifications arrive on the main
   thread; stopping does not wait for that thread or retain an editor. */
@interface YCodeFileWatcher : NSObject
{
  NSString *_directory;
  NSArray *_paths;
  NSLock *_lock;
  BOOL _pending;
  BOOL _stopped;
  int _stopPipe[2];
  int _eventFD;
  void *_changeHandle;
  void *_stopHandle;
}
- (id) initWithDirectory: (NSString *)directory paths: (NSArray *)paths;
- (NSArray *) paths;
- (void) stop;
@end
