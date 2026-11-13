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

#ifndef YCODE_LANGUAGE_SERVER_H
#define YCODE_LANGUAGE_SERVER_H
#import <Foundation/Foundation.h>

@class YCodeLanguageServer;
@class YCodeLanguageServerWriter;
@protocol YCodeLanguageServerDelegate <NSObject>
- (void) languageServer: (YCodeLanguageServer *)server
    receivedDefinition: (id)result
               context: (id)context
                 error: (NSString *)error;
@end

/* Informal callbacks preserve Objective-C 1 compatibility for optional features. */
@interface NSObject (YCodeLanguageServerFeatures)
- (void) languageServer: (YCodeLanguageServer *)server
           diagnostics: (NSArray *)diagnostics
               forPath: (NSString *)path
                  text: (NSString *)text;
@end

/** Optional, asynchronous clangd connection. All public methods run on the main thread. */
@interface YCodeLanguageServer : NSObject
{
  NSTask *_task;
  NSFileHandle *_input;
  NSFileHandle *_output;
  NSFileHandle *_errors;
  YCodeLanguageServerWriter *_writer;
  NSMutableData *_buffer;
  NSMutableDictionary *_documents;
  NSMutableDictionary *_requests;
  NSMutableArray *_pending;
  id<YCodeLanguageServerDelegate> _delegate;
  NSInteger _nextID;
  NSInteger _documentVersion;
  NSString *_compilationDatabaseDirectory;
  NSArray *_fallbackFlags;
  BOOL _ready;
  BOOL _failed;
}

+ (NSString *) executablePath;
+ (NSString *) languageIDForPath: (NSString *)path;
+ (NSDictionary *) positionForOffset: (NSUInteger)offset inText: (NSString *)text;
+ (NSUInteger) offsetForPosition: (NSDictionary *)position
                         inText: (NSString *)text;
- (id) initWithDelegate: (id<YCodeLanguageServerDelegate>)delegate;
- (void) setFallbackFlags: (NSArray *)flags;
- (void) setCompilationDatabaseDirectory: (NSString *)directory;
- (void) requestMethod: (NSString *)method
                 path: (NSString *)path
               offset: (NSUInteger)offset
              context: (id)context;
- (BOOL) startInDirectory: (NSString *)directory;
- (void) stop;
- (void) synchronizePath: (NSString *)path text: (NSString *)text;
- (void) closePath: (NSString *)path;
- (void) savedPath: (NSString *)path;
- (void) definitionForPath: (NSString *)path
                   offset: (NSUInteger)offset
                  context: (id)context;
- (BOOL) isRunning;
@end
#endif
