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

#import "YCodeLanguageServer.h"
#import "YCodeLanguage.h"
#import "YCodePreferences.h"

/* A dedicated FIFO avoids blocking the UI and does not retain the client.
 * NSOperation dependencies can deadlock in some GNUstep KVO implementations. */
@interface YCodeLanguageServerWriter : NSObject
{
  NSFileHandle *_handle;
  NSCondition *_condition;
  NSMutableArray *_packets;
  BOOL _stopped;
}

- (id) initWithHandle: (NSFileHandle *)handle;
- (void) enqueueData: (NSData *)data;
- (void) stop;
@end

@implementation YCodeLanguageServerWriter
- (id) initWithHandle: (NSFileHandle *)handle
{
  if ((self = [super init]))
    {
      _handle = RETAIN (handle);
      _condition = [NSCondition new];
      _packets = [NSMutableArray new];
      [NSThread detachNewThreadSelector: @selector (run)
                               toTarget: self
                             withObject: nil];
    }
  return self;
}

- (void) dealloc
{
  RELEASE (_handle);
  RELEASE (_condition);
  RELEASE (_packets);
  [super dealloc];
}

- (void) enqueueData: (NSData *)data
{
  NSData *packet = [data copy];
  [_condition lock];
  if (!_stopped)
    {
      [_packets addObject: packet];
      [_condition signal];
    }
  [_condition unlock];
  [packet release];
}

- (void) stop
{
  [_condition lock];
  _stopped = YES;
  [_packets removeAllObjects];
  [_condition signal];
  [_condition unlock];
}

- (void) run
{
  NSAutoreleasePool *outerPool = [NSAutoreleasePool new];
  while (YES)
    {
      [_condition lock];
      while (!_stopped && ![_packets count])
        [_condition wait];
      if (_stopped)
        {
          [_condition unlock];
          break;
        }
      NSData *packet = [[_packets objectAtIndex: 0] retain];
      [_packets removeObjectAtIndex: 0];
      [_condition unlock];
      NSAutoreleasePool *pool = [NSAutoreleasePool new];
      NS_DURING
      [_handle writeData: packet];
      NS_HANDLER
      /* EOF, process exit, or a request timeout reports failure to the UI. */
      [self stop];
      NS_ENDHANDLER
      [packet release];
      [pool drain];
    }
  [outerPool drain];
}

@end

@interface YCodeLanguageServer (Private)
- (void) sendMethod: (NSString *)method
        parameters: (NSDictionary *)parameters
        identifier: (NSNumber *)identifier;
- (void) fail: (NSString *)message;
- (void) receiveMessage: (NSDictionary *)message;
- (void) sendMessage: (NSDictionary *)message;
- (void) requestTimeout: (NSNumber *)identifier;
@end

static BOOL
YCodeIsExecutableFile (NSString *path)
{
  BOOL directory = NO;
  NSFileManager *manager = [NSFileManager defaultManager];
  return [path isAbsolutePath] &&
         [manager fileExistsAtPath: path isDirectory: &directory] && !directory
         && [manager isExecutableFileAtPath: path];
}

@implementation YCodeLanguageServer
+ (NSString *) executablePath
{
  NSString *mode = [YCodePreferences languageServerMode];
  if ([mode isEqual: @"disabled"])
    return nil;
  if ([mode isEqual: @"custom"])
    {
      NSString *path =
          [[YCodePreferences languageServerPath] stringByExpandingTildeInPath];
      return YCodeIsExecutableFile (path) ? path : nil;
    }
  NSString *environmentPath =
      [[[NSProcessInfo processInfo] environment] objectForKey: @"PATH"];
#ifdef _WIN32
  NSString *separator = @";", *executableName = @"clangd.exe";
#else
  NSString *separator = @":", *executableName = @"clangd";
#endif
  NSEnumerator *directories = [[environmentPath
      componentsSeparatedByString: separator] objectEnumerator];
  NSString *directory;
  while ((directory = [directories nextObject]))
    {
      if (![directory isAbsolutePath])
        continue;
      NSString *path =
          [directory stringByAppendingPathComponent: executableName];
      if (YCodeIsExecutableFile (path))
        return path;
    }
  return nil;
}

+ (NSString *) languageIDForPath: (NSString *)path
{
  NSDictionary *configuration = [[[YCodeLanguageRegistry sharedRegistry]
      languageForFile: path] languageServerConfiguration];
  if (![[configuration objectForKey: @"Command"] isEqual: @"clangd"])
    return nil;
  id identifier = [configuration objectForKey: @"LanguageID"];
  return [identifier isKindOfClass: [NSString class]] ? identifier : nil;
}

+ (NSDictionary *) positionForOffset: (NSUInteger)offset inText: (NSString *)text
{
  offset = MIN (offset, [text length]);
  NSUInteger start = 0, line = 0;
  while (start < offset)
    {
      NSUInteger end, contentsEnd;
      [text getLineStart: NULL
                     end: &end
             contentsEnd: &contentsEnd
                forRange: NSMakeRange (start, 0)];
      if (end > offset || end <= start || end == contentsEnd)
        break;
      start = end;
      line++;
    }
  return [NSDictionary
      dictionaryWithObjectsAndKeys: [NSNumber numberWithUnsignedInteger: line],
                                   @"line",
                                   [NSNumber numberWithUnsignedInteger: offset -
                                                                       start],
                                   @"character", nil];
}

+ (NSUInteger) offsetForPosition: (NSDictionary *)position
                         inText: (NSString *)text
{
  if (![position isKindOfClass: [NSDictionary class]])
    return NSNotFound;
  id row = [position objectForKey: @"line"];
  id column = [position objectForKey: @"character"];
  if (![row isKindOfClass: [NSNumber class]]
      || ![column isKindOfClass: [NSNumber class]] || [row doubleValue] < 0 ||
      [column doubleValue] < 0)
    return NSNotFound;
  NSUInteger start = 0, line = 0, requested = [row unsignedIntegerValue];
  while (start < [text length] && line < requested)
    {
      NSUInteger end, contentsEnd;
      [text getLineStart: NULL
                     end: &end
             contentsEnd: &contentsEnd
                forRange: NSMakeRange (start, 0)];
      if (end <= start || end == contentsEnd)
        return NSNotFound;
      start = end;
      line++;
    }
  if (line != requested)
    return NSNotFound;
  NSUInteger contentsEnd;
  [text getLineStart: NULL
                 end: NULL
         contentsEnd: &contentsEnd
            forRange: NSMakeRange (start, 0)];
  return start + MIN ([column unsignedIntegerValue], contentsEnd - start);
}

- (id) initWithDelegate: (id<YCodeLanguageServerDelegate>)delegate
{
  if ((self = [super init]))
    {
      _delegate = delegate;
      _buffer = [NSMutableData new];
      _documents = [NSMutableDictionary new];
      _requests = [NSMutableDictionary new];
      _pending = [NSMutableArray new];
    }
  return self;
}

- (void) dealloc
{
  [self stop];
  RELEASE (_compilationDatabaseDirectory);
  RELEASE (_fallbackFlags);
  RELEASE (_buffer);
  RELEASE (_documents);
  RELEASE (_requests);
  RELEASE (_pending);
  [super dealloc];
}

- (BOOL) isRunning
{
  return _task && !_failed && [_task isRunning];
}

- (void) setFallbackFlags: (NSArray *)flags
{
  ASSIGN (_fallbackFlags, flags);
}

- (void) setCompilationDatabaseDirectory: (NSString *)directory
{
  ASSIGN (_compilationDatabaseDirectory, directory);
}

- (BOOL) startInDirectory: (NSString *)directory
{
  if ([self isRunning])
    return YES;
  [self stop];
  NSString *executable = [[self class] executablePath];
  if (!executable)
    return NO;
  _failed = NO;
  _task = [NSTask new];
  [_task setLaunchPath: executable];
  [_task setArguments: [NSArray arrayWithObjects: @"--background-index",
                                                @"--use-dirty-headers",
                                                @"--log=error", nil]];
  if (![directory isAbsolutePath])
    directory = [[[NSFileManager defaultManager] currentDirectoryPath]
        stringByAppendingPathComponent: directory ?: @""];
  [_task setCurrentDirectoryPath: directory];
  NSPipe *input = [NSPipe pipe], *output = [NSPipe pipe],
         *errors = [NSPipe pipe];
  [_task setStandardInput: input];
  [_task setStandardOutput: output];
  [_task setStandardError: errors];
  _input = RETAIN ([input fileHandleForWriting]);
  _output = RETAIN ([output fileHandleForReading]);
  _errors = RETAIN ([errors fileHandleForReading]);
  NSNotificationCenter *center = [NSNotificationCenter defaultCenter];
  [center addObserver: self
             selector: @selector (readOutput:)
                 name: NSFileHandleReadCompletionNotification
               object: _output];
  [center addObserver: self
             selector: @selector (readErrors:)
                 name: NSFileHandleReadCompletionNotification
               object: _errors];
  [center addObserver: self
             selector: @selector (taskExited:)
                 name: NSTaskDidTerminateNotification
               object: _task];
  NS_DURING
  [_task launch];
  [_output readInBackgroundAndNotify];
  [_errors readInBackgroundAndNotify];
  NS_HANDLER
  [self stop];
  return NO;
  NS_ENDHANDLER
  _writer = [[YCodeLanguageServerWriter alloc] initWithHandle: _input];
  NSDictionary *general =
      [NSDictionary dictionaryWithObject: [NSArray arrayWithObject: @"utf-16"]
                                  forKey: @"positionEncodings"];
  NSDictionary *parameters = [NSDictionary
      dictionaryWithObjectsAndKeys:
          [NSNumber
              numberWithInt: [[NSProcessInfo processInfo] processIdentifier]],
          @"processId", [[NSURL fileURLWithPath: directory] absoluteString],
          @"rootUri",
          [NSDictionary dictionaryWithObject: general forKey: @"general"],
          @"capabilities", nil];
  NSMutableDictionary *initialization =
      [NSMutableDictionary dictionaryWithDictionary: parameters];
  NSDictionary *textCapabilities = [NSDictionary
      dictionaryWithObject: [NSDictionary
                               dictionaryWithObject: [NSNumber
                                                        numberWithBool: YES]
                                             forKey: @"versionSupport"]
                    forKey: @"publishDiagnostics"];
  [initialization
      setObject: [NSDictionary dictionaryWithObjectsAndKeys: general, @"general",
                                                           textCapabilities,
                                                           @"textDocument",
                                                           nil]
         forKey: @"capabilities"];
  NSMutableDictionary *options = [NSMutableDictionary dictionary];
  if ([_compilationDatabaseDirectory length])
    [options setObject: _compilationDatabaseDirectory
                forKey: @"compilationDatabasePath"];
  if ([_fallbackFlags count])
    [options setObject: _fallbackFlags forKey: @"fallbackFlags"];
  [initialization setObject: options forKey: @"initializationOptions"];
  parameters = initialization;
  [self sendMethod: @"initialize"
        parameters: parameters
        identifier: [NSNumber numberWithInt: 0]];
  [self performSelector: @selector (requestTimeout:)
             withObject: [NSNumber numberWithInt: 0]
             afterDelay: 15];
  return YES;
}

- (void) stop
{
  [NSObject cancelPreviousPerformRequestsWithTarget: self];
  [[NSNotificationCenter defaultCenter] removeObserver: self];
  [_writer stop];
  DESTROY (_writer);
  if ([_task isRunning])
    [_task terminate];
  NS_DURING
  [_input closeFile];
  [_output closeFile];
  [_errors closeFile];
  NS_HANDLER
  NS_ENDHANDLER
  DESTROY (_task);
  DESTROY (_input);
  DESTROY (_output);
  DESTROY (_errors);
  [_buffer setLength: 0];
  [_documents removeAllObjects];
  [_requests removeAllObjects];
  [_pending removeAllObjects];
  _ready = NO;
}

- (void) sendMethod: (NSString *)method
        parameters: (NSDictionary *)parameters
        identifier: (NSNumber *)identifier
{
  if (!_input || _failed)
    return;
  NSMutableDictionary *message = [NSMutableDictionary
      dictionaryWithObjectsAndKeys: @"2.0", @"jsonrpc", method, @"method", nil];
  if (parameters)
    [message setObject: parameters forKey: @"params"];
  if (identifier)
    [message setObject: identifier forKey: @"id"];
  [self sendMessage: message];
}

- (void) sendMessage: (NSDictionary *)message
{
  NSData *body = [NSJSONSerialization dataWithJSONObject: message
                                                 options: 0
                                                   error: NULL];
  if (!body || !_input)
    return;
  NSMutableData *packet = [NSMutableData
      dataWithData: [[NSString stringWithFormat: @"Content-Length: %lu\r\n\r\n",
                                               (unsigned long)[body length]]
                       dataUsingEncoding: NSASCIIStringEncoding]];
  [packet appendData: body];
  [_writer enqueueData: packet];
}

- (void) readErrors: (NSNotification *)notification
{
  if ([[[notification userInfo] objectForKey: NSFileHandleNotificationDataItem]
          length])
    [_errors readInBackgroundAndNotify];
}

- (void) taskExited: (NSNotification *)notification
{
  [self
      fail:
          @"clangd stopped. Use Edit > Restart Code Intelligence to try again."];
}

- (void) fail: (NSString *)message
{
  if (_failed)
    return;
  _failed = YES;
  NSArray *contexts = [[_requests allValues] copy];
  [self stop];
  NSEnumerator *enumerator = [contexts objectEnumerator];
  id context;
  while ((context = [enumerator nextObject]))
    [_delegate languageServer: self
           receivedDefinition: nil
                      context: context
                        error: message];
  [contexts release];
}

- (void) requestTimeout: (NSNumber *)identifier
{
  if ([identifier integerValue] == 0)
    {
      [self
          fail:
              @"clangd initialization timed out. Check the executable in Preferences > Editor."];
      return;
    }
  id context = [[_requests objectForKey: identifier] retain];
  [_requests removeObjectForKey: identifier];
  if (context)
    {
      [self sendMethod: @"$/cancelRequest"
            parameters: [NSDictionary dictionaryWithObject: identifier
                                                   forKey: @"id"]
            identifier: nil];
      [_delegate
              languageServer: self
          receivedDefinition: nil
                     context: context
                       error:
                           @"Code intelligence request timed out. clangd may still be indexing this project."];
    }
  [context release];
}

- (void) readOutput: (NSNotification *)notification
{
  NSData *data =
      [[notification userInfo] objectForKey: NSFileHandleNotificationDataItem];
  if (![data length])
    {
      [self
          fail:
              @"clangd disconnected. Use Edit > Restart Code Intelligence to try again."];
      return;
    }
  [_buffer appendData: data];
  NSData *separator = [@"\r\n\r\n" dataUsingEncoding: NSASCIIStringEncoding];
  while ([_buffer length])
    {
      NSRange boundary =
          [_buffer rangeOfData: separator
                       options: 0
                         range: NSMakeRange (0, [_buffer length])];
      if (boundary.location == NSNotFound)
        {
          if ([_buffer length] > 8192)
            [self fail: @"Invalid clangd message header."];
          break;
        }
      NSString *header = AUTORELEASE ([[NSString alloc]
          initWithData: [_buffer
                           subdataWithRange: NSMakeRange (0, boundary.location)]
              encoding: NSASCIIStringEncoding]);
      NSEnumerator *lines =
          [[header componentsSeparatedByString: @"\r\n"] objectEnumerator];
      NSString *line;
      NSInteger length = -1;
      while ((line = [lines nextObject]))
        if ([[line lowercaseString] hasPrefix: @"content-length:"])
          {
            NSScanner *scanner =
                [NSScanner scannerWithString: [line substringFromIndex: 15]];
            if (![scanner scanInteger: &length] || ![scanner isAtEnd])
              length = -1;
          }
      if (length < 0 || length > 32 * 1024 * 1024)
        {
          [self fail: @"Invalid clangd message length."];
          return;
        }
      NSUInteger start = NSMaxRange (boundary);
      if ([_buffer length] - start < (NSUInteger)length)
        break;
      NSData *body = [_buffer subdataWithRange: NSMakeRange (start, length)];
      [_buffer replaceBytesInRange: NSMakeRange (0, start + length)
                         withBytes: NULL
                            length: 0];
      id message = [NSJSONSerialization JSONObjectWithData: body
                                                   options: 0
                                                     error: NULL];
      if (![message isKindOfClass: [NSDictionary class]])
        {
          [self fail: @"Invalid JSON received from clangd."];
          return;
        }
      [self receiveMessage: message];
      if (_failed)
        return;
    }
  if (_output)
    [_output readInBackgroundAndNotify];
}

- (void) receiveMessage: (NSDictionary *)message
{
  NSNumber *identifier = [message objectForKey: @"id"];
  if ([message objectForKey: @"method"])
    {
      if ([[message objectForKey: @"method"]
              isEqual: @"textDocument/publishDiagnostics"])
        {
          id params = [message objectForKey: @"params"];
          if (![params isKindOfClass: [NSDictionary class]])
            return;
          id uri = [params objectForKey: @"uri"];
          NSDictionary *document = [uri isKindOfClass: [NSString class]]
                                       ? [_documents objectForKey: uri]
                                       : nil;
          id version = [params objectForKey: @"version"];
          id diagnostics = [params objectForKey: @"diagnostics"];
          if (document && [diagnostics isKindOfClass: [NSArray class]]
              && ([version isKindOfClass: [NSNumber class]] &&
                  [version isEqual: [document objectForKey: @"version"]])
              && [_delegate respondsToSelector: @selector
                            (languageServer:diagnostics:forPath:text:)])
            [(id)_delegate languageServer: self
                              diagnostics: diagnostics
                                  forPath: [[NSURL URLWithString: uri] path]
                                     text: [document objectForKey: @"text"]];
          return;
        }

      /* We advertise no server-request capabilities. Reply rather than hang. */
      if (identifier)
        [self sendMessage: [NSDictionary
                              dictionaryWithObjectsAndKeys:
                                  @"2.0", @"jsonrpc", identifier, @"id",
                                  [NSDictionary
                                      dictionaryWithObjectsAndKeys:
                                          [NSNumber numberWithInt: -32601],
                                          @"code", @"Method not supported",
                                          @"message", nil],
                                  @"error", nil]];
      return;
    }
  if (![identifier isKindOfClass: [NSNumber class]])
    return;
  [NSObject cancelPreviousPerformRequestsWithTarget: self
                                           selector: @selector (requestTimeout:)
                                             object: identifier];
  if ([identifier integerValue] == 0 && !_ready)
    {
      id result = [message objectForKey: @"result"];
      if (![result isKindOfClass: [NSDictionary class]] ||
          [message objectForKey: @"error"])
        {
          [self fail: @"clangd initialization failed."];
          return;
        }
      id capabilities = [result objectForKey: @"capabilities"];
      NSString *encoding =
          [capabilities isKindOfClass: [NSDictionary class]]
              ? [capabilities objectForKey: @"positionEncoding"]
              : nil;
      if (encoding && ![encoding isEqual: @"utf-16"])
        {
          [self fail: @"clangd selected an unsupported position encoding."];
          return;
        }
      _ready = YES;
      [self sendMethod: @"initialized"
            parameters: [NSDictionary dictionary]
            identifier: nil];
      NSEnumerator *documents = [_documents objectEnumerator];
      NSDictionary *document;
      while ((document = [documents nextObject]))
        [self sendMethod: @"textDocument/didOpen"
              parameters: [NSDictionary dictionaryWithObject: document
                                                     forKey: @"textDocument"]
              identifier: nil];
      NSArray *pending = [[_pending copy] autorelease];
      [_pending removeAllObjects];
      NSEnumerator *requests = [pending objectEnumerator];
      NSDictionary *request;
      while ((request = [requests nextObject]))
        [self sendMessage: request];
      return;
    }
  id context = [[_requests objectForKey: identifier] retain];
  [_requests removeObjectForKey: identifier];
  if (context)
    [_delegate
            languageServer: self
        receivedDefinition: [message objectForKey: @"result"]
                   context: context
                     error:
                         [message objectForKey: @"error"]
                             ? @"clangd could not complete this request. Check the project's compiler settings."
                             : nil];
  [context release];
}

- (void) synchronizePath: (NSString *)path text: (NSString *)text
{
  NSString *language = [[self class] languageIDForPath: path];
  if (!language || ![self isRunning])
    return;
  NSString *uri = [[NSURL fileURLWithPath: path] absoluteString];
  NSDictionary *old = [_documents objectForKey: uri];
  if ([[old objectForKey: @"text"] isEqual: text])
    return;
  NSNumber *version = [NSNumber numberWithInteger: ++_documentVersion];
  NSDictionary *document = [NSDictionary
      dictionaryWithObjectsAndKeys: uri, @"uri", language, @"languageId",
                                   version, @"version",
                                   [[text copy] autorelease], @"text", nil];
  if (_ready)
    {
      if (!old)
        [self sendMethod: @"textDocument/didOpen"
              parameters: [NSDictionary dictionaryWithObject: document
                                                     forKey: @"textDocument"]
              identifier: nil];
      else
        [self
            sendMethod: @"textDocument/didChange"
            parameters:
                [NSDictionary
                    dictionaryWithObjectsAndKeys:
                        [NSDictionary
                            dictionaryWithObjectsAndKeys: uri, @"uri", version,
                                                         @"version", nil],
                        @"textDocument",
                        [NSArray
                            arrayWithObject: [NSDictionary
                                                dictionaryWithObject: text
                                                              forKey: @"text"]],
                        @"contentChanges", nil]
            identifier: nil];
    }
  [_documents setObject: document forKey: uri];
}

- (void) closePath: (NSString *)path
{
  NSString *uri = [[NSURL fileURLWithPath: path] absoluteString];
  if (_ready && [_documents objectForKey: uri])
    [self sendMethod: @"textDocument/didClose"
          parameters: [NSDictionary
                         dictionaryWithObject: [NSDictionary
                                                  dictionaryWithObject: uri
                                                                forKey: @"uri"]
                                       forKey: @"textDocument"]
          identifier: nil];
  [_documents removeObjectForKey: uri];
}

- (void) savedPath: (NSString *)path
{
  NSString *uri = [[NSURL fileURLWithPath: path] absoluteString];
  if (_ready && [_documents objectForKey: uri])
    [self sendMethod: @"textDocument/didSave"
          parameters: [NSDictionary
                         dictionaryWithObject: [NSDictionary
                                                  dictionaryWithObject: uri
                                                                forKey: @"uri"]
                                       forKey: @"textDocument"]
          identifier: nil];
}

- (void) definitionForPath: (NSString *)path
                   offset: (NSUInteger)offset
                  context: (id)context
{
  [self requestMethod: @"textDocument/definition"
                 path: path
               offset: offset
              context: context];
}

- (void) requestMethod: (NSString *)method
                 path: (NSString *)path
               offset: (NSUInteger)offset
              context: (id)context
{
  NSString *uri = [[NSURL fileURLWithPath: path] absoluteString];
  NSDictionary *document = [_documents objectForKey: uri];
  if (!document)
    return;
  NSNumber *identifier = [NSNumber numberWithInteger: ++_nextID];
  [_requests setObject: context forKey: identifier];
  NSMutableDictionary *parameters = [NSMutableDictionary
      dictionaryWithObjectsAndKeys:
          [NSDictionary dictionaryWithObject: uri forKey: @"uri"],
          @"textDocument",
          [[self class] positionForOffset: offset
                                   inText: [document objectForKey: @"text"]],
          @"position", nil];
  if ([method isEqual: @"textDocument/documentSymbol"])
    [parameters removeObjectForKey: @"position"];
  if ([method isEqual: @"textDocument/references"])
    [parameters
        setObject: [NSDictionary
                      dictionaryWithObject: [NSNumber numberWithBool: YES]
                                    forKey: @"includeDeclaration"]
           forKey: @"context"];
  if (_ready)
    [self sendMethod: method parameters: parameters identifier: identifier];
  else
    [_pending
        addObject: [NSDictionary
                      dictionaryWithObjectsAndKeys: @"2.0", @"jsonrpc",
                                                   identifier, @"id", method,
                                                   @"method", parameters,
                                                   @"params", nil]];
  [self performSelector: @selector (requestTimeout:)
             withObject: identifier
             afterDelay: 30];
}

@end
