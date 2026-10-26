/*
   Copyright (C) 2026 Free Software Foundation

   This file is part of Ycode and is distributed under the GNU General
   Public License, version 2 or (at your option) any later version.
   See COPYING for details. There is no warranty.
*/

#ifndef _XOPEN_SOURCE
#define _XOPEN_SOURCE 600
#endif
#import "YCodeTerminalView.h"
#import "YCodePreferences.h"
#include <math.h>
#include <errno.h>
#include <string.h>
#ifndef _WIN32
#include <unistd.h>
#include <fcntl.h>
#include <signal.h>
#include <termios.h>
#include <sys/ioctl.h>
#include <sys/wait.h>
#include <pwd.h>
#endif

@interface YCodeTerminalView (Private)
- (void) poll: (NSTimer *)timer;
- (void) queueBytes: (const char *)bytes length: (size_t)length;
- (void) clearHistory;
- (void) resizeTerminal;
- (void) updateScroller;
- (void) scrollHistory: (NSScroller *)sender;
- (void) preferencesChanged: (NSNotification *)notification;
- (void) ringBell;
- (void) invalidateTerminalRect: (YCodeTerminalRect)rect;
- (void) invalidateCursorAt: (YCodeTerminalPosition)position;
- (BOOL) cursorCanBlink;
- (void) advanceBlink;
- (void) windowFocusChanged: (NSNotification *)notification;
@end

static NSString *
terminalCellString (const YCodeTerminalGlyph *cell)
{
  unichar text[6 * 2];
  NSUInteger count = 0;
  int i;
  for (i = 0; i < 6 && cell->chars[i]; i++)
    {
      uint32_t c = cell->chars[i];
      if (c == (uint32_t)-1)
        break;
      if (c > 0xffff && c <= 0x10ffff)
        {
          c -= 0x10000;
          text[count++] = 0xd800 + (c >> 10);
          text[count++] = 0xdc00 + (c & 1023);
        }
      else if (c <= 0xffff)
        text[count++] = c;
    }
  return count ? [NSString stringWithCharacters: text length: count] : @" ";
}

@implementation YCodeTerminalView
- (id) initWithFrame: (NSRect)frame
{
  if ((self = [super initWithFrame: frame]))
    {
      _master = _child = -1;
      _selectionStart = _selectionEnd = -1;
      _cursorVisible = YES;
      _blinkOn = YES;
      _cursorShape = 1;
      _font = RETAIN ([YCodePreferences terminalFont]);
      _boldFont = RETAIN ([[NSFontManager sharedFontManager]
          convertFont: _font
          toHaveTrait: NSBoldFontMask]);
      _cellWidth = ceil (
          [@"M"
              sizeWithAttributes: [NSDictionary
                                     dictionaryWithObject: _font
                                                   forKey: NSFontAttributeName]]
              .width);
      _cellHeight = ceil ([_font ascender] - [_font descender] + 3);
      _history = [NSMutableArray new];
      _pendingInput = [NSMutableData new];
      CGFloat scrollerWidth = [NSScroller scrollerWidth];
      _historyScroller = [[NSScroller alloc]
          initWithFrame: NSMakeRect (MAX (0, frame.size.width - scrollerWidth),
                                    0, scrollerWidth, frame.size.height)];
      [_historyScroller
          setAutoresizingMask: NSViewMinXMargin | NSViewHeightSizable];
      [_historyScroller setTarget: self];
      [_historyScroller setAction: @selector (scrollHistory:)];
      [self addSubview: _historyScroller];
      RELEASE (_historyScroller);
      _rows = MAX (2, (int)(frame.size.height / _cellHeight));
      _columns = MAX (
          2, (int)(MAX (0, frame.size.width - scrollerWidth) / _cellWidth));
      _terminal = [[YCodeTerminalParser alloc] initWithTerminalScreen: self
                                                                width: _columns
                                                               height: _rows];
      [self preferencesChanged: nil];
      [[NSNotificationCenter defaultCenter]
          addObserver: self
             selector: @selector (preferencesChanged:)
                 name: YCodeTerminalPreferencesDidChangeNotification
               object: nil];
      [self setAutoresizingMask: NSViewWidthSizable | NSViewHeightSizable];
    }
  return self;
}

- (void) dealloc
{
  [[NSNotificationCenter defaultCenter] removeObserver: self];
  [self stop];
  RELEASE (_terminal);
  RELEASE (_font);
  RELEASE (_boldFont);
  RELEASE (_history);
  RELEASE (_foregroundColor);
  RELEASE (_backgroundColor);
  RELEASE (_cursorColor);
  RELEASE (_pendingInput);
  RELEASE (_directory);
  [super dealloc];
}

- (BOOL) isFlipped
{
  return YES;
}

- (void) ringBell
{
  if (_audibleBell)
    NSBeep ();
}

- (void) preferencesChanged: (NSNotification *)notification
{
  ASSIGN (_font, [YCodePreferences terminalFont]);
  NSFont *bold =
      [[NSFontManager sharedFontManager] convertFont: _font
                                         toHaveTrait: NSBoldFontMask];
  ASSIGN (_boldFont, bold ? bold : _font);
  _cellWidth = ceil (
      [@"M" sizeWithAttributes: [NSDictionary
                                   dictionaryWithObject: _font
                                                 forKey: NSFontAttributeName]]
          .width);
  _cellHeight = ceil ([_font ascender] - [_font descender] + 3);
  ASSIGN (_foregroundColor, [YCodePreferences terminalForegroundColor]);
  ASSIGN (_backgroundColor, [YCodePreferences terminalBackgroundColor]);
  ASSIGN (_cursorColor, [YCodePreferences terminalCursorColor]);
  _preferredCursorShape = [YCodePreferences terminalCursorShape];
  _scrollbackLimit = [YCodePreferences terminalScrollbackLines];
  if ([_history count] > _scrollbackLimit)
    {
      [_history removeObjectsInRange: NSMakeRange (0, [_history count]
                                                         - _scrollbackLimit)];
      _selectionStart = _selectionEnd = -1;
    }
  _scrollOffset = MIN (_scrollOffset, (NSInteger)[_history count]);
  _audibleBell = [YCodePreferences terminalAudibleBell];
  _allowCursorBlink = [YCodePreferences terminalCursorBlink];
  [self resizeTerminal];
  [self updateScroller];
  [self setNeedsDisplay: YES];
}

- (BOOL) isOpaque
{
  return YES;
}

- (BOOL) acceptsFirstResponder
{
  return YES;
}

- (BOOL) becomeFirstResponder
{
  _blinkOn = YES;
  _lastBlink = [NSDate timeIntervalSinceReferenceDate];
  [[self window] setAcceptsMouseMovedEvents: YES];
  [_terminal focusChanged: YES];
  [self setNeedsDisplay: YES];
  return YES;
}

- (BOOL) resignFirstResponder
{
  [_terminal focusChanged: NO];
  [self setNeedsDisplay: YES];
  return YES;
}

- (void) viewWillMoveToWindow: (NSWindow *)window
{
  NSNotificationCenter *center = [NSNotificationCenter defaultCenter];
  NSEnumerator *names =
      [[NSArray arrayWithObjects: NSWindowWillCloseNotification,
                                 NSWindowDidBecomeKeyNotification,
                                 NSWindowDidResignKeyNotification, nil]
          objectEnumerator];
  NSString *name;
  while ((name = [names nextObject]) != nil)
    {
      if ([self window])
        [center removeObserver: self name: name object: [self window]];
      if (window)
        [center addObserver: self
                   selector: [name isEqual: NSWindowWillCloseNotification]
                                ? @selector (windowClosing:)
                                : @selector (windowFocusChanged:)
                       name: name
                     object: window];
    }
  [super viewWillMoveToWindow: window];
}

- (void) windowFocusChanged: (NSNotification *)notification
{
  // Show the cursor immediately on either side of a focus change.
  _blinkOn = YES;
  _lastBlink = [NSDate timeIntervalSinceReferenceDate];
  [self setNeedsDisplay: YES];
}

- (void) windowClosing: (NSNotification *)notification
{
  [self stop];
}

- (BOOL) isRunning
{
  return _master >= 0;
}

- (void) invalidateTerminalRect: (YCodeTerminalRect)rect
{
  // While browsing history, screen rows and visible rows no longer coincide.
  if (_scrollOffset)
    {
      [self setNeedsDisplay: YES];
      return;
    }
  // Include neighbouring cells so either half of a wide glyph is repainted.
  int start = MAX (0, rect.start_col - 1),
      end = MIN (_columns, rect.end_col + 1);
  [self setNeedsDisplayInRect: NSMakeRect (start * _cellWidth,
                                          rect.start_row * _cellHeight,
                                          (end - start) * _cellWidth,
                                          (rect.end_row - rect.start_row)
                                              * _cellHeight)];
}

- (void) invalidateCursorAt: (YCodeTerminalPosition)position
{
  if (_scrollOffset)
    return;
  YCodeTerminalRect rect
      = { position.row, position.row + 1, position.col, position.col + 1 };
  [self invalidateTerminalRect: rect];
}

- (BOOL) cursorCanBlink
{
  return _allowCursorBlink && _cursorBlink && [self isRunning] &&
         [NSApp isActive] && [[self window] isKeyWindow] &&
         [[self window] firstResponder] == self;
}

- (void) advanceBlink
{
  _blinkOn = !_blinkOn;
  if (![[self window] isVisible] || [self isHiddenOrHasHiddenAncestor]
      || ![self superview])
    return;
  if (_cursorVisible && !_scrollOffset && [self cursorCanBlink])
    {
      YCodeTerminalPosition cursor = _cursor;
      [self invalidateCursorAt: cursor];
    }
  // ANSI blinking text remains independent of the cursor preference/focus.
  NSInteger first = (_alternateScreen ? 0 : [_history count]) - _scrollOffset;
  int row, col;
  for (row = 0; row < _rows; row++)
    for (col = 0; col < _columns; col++)
      {
        YCodeTerminalGlyph cell;
        if ([self cellAtRow: first + row column: col cell: &cell]
            && (cell.attributes & YCodeTerminalBlink))
          [self setNeedsDisplayInRect: NSMakeRect (
                                          col * _cellWidth, row * _cellHeight,
                                          MAX (1, cell.width) * _cellWidth,
                                          _cellHeight)];
      }
}

- (void) ts_sendCString: (const char *)bytes length: (int)length
{
  [self queueBytes: bytes length: length];
}

- (void) ts_goto: (int)column row: (int)row
{
  if (_cursor.row == row && _cursor.col == column)
    return;
  [self invalidateCursorAt: _cursor];
  _cursor.row = row;
  _cursor.col = column;
  [self invalidateCursorAt: _cursor];
}

- (void) ts_damageRow: (int)row
{
  YCodeTerminalRect rect = { row, row + 1, 0, _columns };
  [self invalidateTerminalRect: rect];
}

- (void) ts_setTitle: (NSString *)title type: (int)type
{
  // Child programs cannot rename the project window.
}

- (void) ts_setCursorVisible: (BOOL)visible
{
  if (_cursorVisible != visible)
    {
      _cursorVisible = visible;
      [self invalidateCursorAt: _cursor];
    }
}

- (void) ts_setCursorShape: (int)shape blink: (BOOL)blink
{
  if (_cursorShape != shape || _cursorBlink != blink)
    {
      _cursorShape = shape;
      _cursorBlink = blink;
      [self invalidateCursorAt: _cursor];
    }
}

- (void) ts_setAlternateScreen: (BOOL)alternate
{
  if (_alternateScreen != alternate)
    {
      _alternateScreen = alternate;
      _scrollOffset = 0;
      _selectionStart = _selectionEnd = -1;
      [self setNeedsDisplay: YES];
    }
}

- (void) ts_setMouseReporting: (BOOL)enabled
{
  _mouseReporting = enabled;
}

- (void) ts_bell
{
  [self ringBell];
}

- (void) ts_clearScrollback
{
  [self clearHistory];
}

- (void) clearHistory
{
  [_history removeAllObjects];
  _scrollOffset = 0;
  _selectionStart = _selectionEnd = -1;
  [self setNeedsDisplay: YES];
}

- (void) ts_appendScrollback: (const YCodeTerminalCell *)cells count: (int)columns
{
  [_history addObject: [NSData dataWithBytes: cells
                                     length: columns * sizeof (*cells)]];
  if ([_history count] > _scrollbackLimit)
    {
      [_history removeObjectAtIndex: 0];
      _selectionStart = _selectionEnd = -1;
    }
  if (_scrollOffset)
    _scrollOffset = MIN ((NSInteger)[_history count], _scrollOffset + 1);
}

- (BOOL) ts_popScrollback: (YCodeTerminalCell *)cells count: (int)columns
{
  NSData *line = [_history lastObject];
  if (!line)
    return 0;
  memset (cells, 0, columns * sizeof (*cells));
  memcpy (cells, [line bytes], MIN ([line length], columns * sizeof (*cells)));
  [_history removeLastObject];
  _scrollOffset = MIN (_scrollOffset, (NSInteger)[_history count]);
  return 1;
}

- (void) consumeData: (NSData *)data
{
  [_terminal processBytes: [data bytes] length: [data length]];
  [self updateScroller];
}

- (void) queueBytes: (const char *)bytes length: (size_t)length
{
  if (_master >= 0)
    [_pendingInput appendBytes: bytes length: length];
}

- (void) sendData: (NSData *)data
{
  [self queueBytes: [data bytes] length: [data length]];
}

- (void) setFrame: (NSRect)frame
{
  [super setFrame: frame];
  // NSTabView uses setFrame: when installing a selected tab. GNUstep does
  // not route that change through setFrameSize:.
  if (_terminal)
    [self resizeTerminal];
}

- (void) setFrameSize: (NSSize)size
{
  [super setFrameSize: size];
  if (_terminal)
    [self resizeTerminal];
}

- (void) resizeTerminal
{
  int rows
      = MIN (1000, MAX (2, (int)([self bounds].size.height / _cellHeight)));
  int cols = MIN (1000, MAX (2, (int)(MAX (0, [self bounds].size.width -
                                                  [NSScroller scrollerWidth])
                                      / _cellWidth)));
  [self updateScroller];
  if (rows == _rows && cols == _columns)
    return;
  _rows = rows;
  _columns = cols;
  _selectionStart = _selectionEnd = -1;
  [_terminal setTerminalScreenWidth: cols height: rows];
#ifndef _WIN32
  if (_master >= 0)
    {
      struct winsize size;
      memset (&size, 0, sizeof (size));
      size.ws_row = rows;
      size.ws_col = cols;
      ioctl (_master, TIOCSWINSZ, &size);
    }
#endif
  [self updateScroller];
  [self setNeedsDisplay: YES];
}

- (BOOL) startInDirectory: (NSString *)directory error: (NSError **)error
{
  // Use the final visible bounds before creating the PTY, and refresh an
  // existing session when a previously hidden tab is selected again.
  [self resizeTerminal];
  if ([self isRunning])
    return YES;
  int failure = 0;
#ifndef _WIN32
  NSDictionary *environment = [[NSProcessInfo processInfo] environment];
  NSString *shell = [environment objectForKey: @"SHELL"];
  if (![shell isAbsolutePath]
      || ![[NSFileManager defaultManager] isExecutableFileAtPath: shell])
    {
      struct passwd *user = getpwuid (getuid ());
      shell = user && user->pw_shell
                  ? [NSString stringWithUTF8String: user->pw_shell]
                  : @"/bin/sh";
    }
  if (![[NSFileManager defaultManager] isExecutableFileAtPath: shell])
    shell = @"/bin/sh";
  BOOL isDirectory = NO;
  if (![directory isAbsolutePath]
      || ![[NSFileManager defaultManager] fileExistsAtPath: directory
                                               isDirectory: &isDirectory]
      || !isDirectory)
    failure = ENOENT;
  else
    {
      _master = posix_openpt (O_RDWR | O_NOCTTY);
      if (_master < 0)
        failure = errno;
      else if (grantpt (_master) < 0 || unlockpt (_master) < 0)
        failure = errno;
    }
  char *slaveName = !failure ? ptsname (_master) : NULL;
  if (!failure && !slaveName)
    failure = errno ? errno : EIO;
  if (!failure)
    {
      fcntl (_master, F_SETFD, FD_CLOEXEC);
      fcntl (_master, F_SETFL, O_NONBLOCK);
      struct winsize size;
      memset (&size, 0, sizeof (size));
      size.ws_row = _rows;
      size.ws_col = _columns;
      ioctl (_master, TIOCSWINSZ, &size);
      // Prepare all strings before fork; the child only calls POSIX functions.
      NSMutableDictionary *env =
          [NSMutableDictionary dictionaryWithDictionary: environment];
      [env setObject: @"xterm-256color" forKey: @"TERM"];
      [env setObject: @"truecolor" forKey: @"COLORTERM"];
      [env setObject: directory forKey: @"PWD"];
      [env removeObjectForKey: @"COLUMNS"];
      [env removeObjectForKey: @"LINES"];
      char **envp = calloc ([env count] + 1, sizeof (char *));
      NSEnumerator *keys = [env keyEnumerator];
      NSString *key;
      NSUInteger index = 0;
      while ((key = [keys nextObject]) != nil)
        envp[index++] = strdup (
            [[NSString stringWithFormat: @"%@=%@", key, [env objectForKey: key]]
                UTF8String]);
      char *program = strdup ([shell fileSystemRepresentation]);
      char *cwd = strdup ([directory fileSystemRepresentation]);
      char *slave = strdup (slaveName);
      char *argv[] = { program, "-i", NULL };
      long maxFD = sysconf (_SC_OPEN_MAX);
      if (maxFD < 0)
        maxFD = 1024;
      pid_t child = fork ();
      if (child == 0)
        {
          int fd;
          unsigned int signalIndex;
          int signals[] = { SIGINT,  SIGQUIT, SIGTERM, SIGHUP,  SIGCHLD,
                            SIGPIPE, SIGTSTP, SIGTTIN, SIGTTOU, SIGWINCH };
          sigset_t mask;
          sigemptyset (&mask);
          sigprocmask (SIG_SETMASK, &mask, NULL);
          for (signalIndex = 0;
               signalIndex < sizeof (signals) / sizeof (signals[0]);
               signalIndex++)
            signal (signals[signalIndex], SIG_DFL);
          if (setsid () < 0)
            _exit (126);
          fd = open (slave, O_RDWR);
          if (fd < 0)
            _exit (126);
          ioctl (fd, TIOCSCTTY, 0);
#ifdef IUTF8
          struct termios settings;
          if (tcgetattr (fd, &settings) == 0)
            {
              settings.c_iflag |= IUTF8;
              tcsetattr (fd, TCSANOW, &settings);
            }
#endif
          dup2 (fd, 0);
          dup2 (fd, 1);
          dup2 (fd, 2);
          for (fd = 3; fd < maxFD; fd++)
            close (fd);
          if (chdir (cwd) < 0)
            {
              const char message[]
                  = "Ycode: cannot enter project directory\r\n";
              write (2, message, sizeof (message) - 1);
              _exit (126);
            }
          execve (program, argv, envp);
          {
            const char message[] = "Ycode: cannot execute shell\r\n";
            write (2, message, sizeof (message) - 1);
            _exit (127);
          }
        }
      if (child < 0)
        failure = errno;
      else
        _child = child;
      for (index = 0; envp[index]; index++)
        free (envp[index]);
      free (envp);
      free (program);
      free (cwd);
      free (slave);
    }
#else
  failure = ENOSYS;
#endif
  if (failure)
    {
#ifndef _WIN32
      if (_master >= 0)
        close (_master);
#endif
      _master = -1;
      if (error)
        *error = [NSError errorWithDomain: NSPOSIXErrorDomain
                                     code: failure
                                 userInfo: nil];
      return NO;
    }
  ASSIGN (_directory, directory);
  _ended = NO;
  _blinkOn = YES;
  _lastBlink = [NSDate timeIntervalSinceReferenceDate];
  [self clearHistory];
  [_pendingInput setLength: 0];
  [_terminal reset: YES];
  _timer = RETAIN ([NSTimer timerWithTimeInterval: 0.02
                                           target: self
                                         selector: @selector (poll:)
                                         userInfo: nil
                                          repeats: YES]);
  [[NSRunLoop mainRunLoop] addTimer: _timer forMode: NSDefaultRunLoopMode];
  [[NSRunLoop mainRunLoop] addTimer: _timer forMode: NSEventTrackingRunLoopMode];
  [[NSRunLoop mainRunLoop] addTimer: _timer forMode: NSModalPanelRunLoopMode];
  return YES;
}

#ifndef _WIN32
+ (void) reapChild: (NSArray *)processes
{
  NSAutoreleasePool *pool = [NSAutoreleasePool new];
  pid_t child = [[processes objectAtIndex: 0] intValue];
  pid_t foreground = [[processes objectAtIndex: 1] intValue];
  int status, attempts;
  BOOL reaped = NO;
  for (attempts = 0; attempts < 50; attempts++)
    {
      if (!reaped)
        {
          pid_t result = waitpid (child, &status, WNOHANG);
          reaped = result == child || (result < 0 && errno != EINTR);
        }
      // A foreground program can ignore HUP even after its shell has exited.
      if (reaped
          && !(foreground > 0 && foreground != child
               && getsid (foreground) == child))
        break;
      usleep (20000);
    }
  if (attempts == 50)
    {
      if (foreground > 0 && getsid (foreground) == child)
        kill (-foreground, SIGKILL);
      if (!reaped)
        {
          kill (-child, SIGKILL);
          kill (child, SIGKILL);
          while (waitpid (child, &status, 0) < 0 && errno == EINTR)
            {
            }
        }
    }
  [pool drain];
}

#endif
- (void) stop
{
  [_timer invalidate];
  DESTROY (_timer);
#ifndef _WIN32
  pid_t foreground = _master >= 0 ? tcgetpgrp (_master) : -1;
  if (_child > 0)
    {
      if (foreground > 0 && getsid (foreground) == _child)
        kill (-foreground, SIGHUP);
      int status;
      pid_t result;
      do
        {
          result = waitpid (_child, &status, WNOHANG);
        }
      while (result < 0 && errno == EINTR);
      // GNUstep's NSTask may already have reaped an unrelated child in its
      // SIGCHLD handler. Never signal a PID that is no longer our child.
      if (result == 0)
        {
          kill (-_child, SIGHUP);
          kill (_child, SIGHUP);
          [NSThread
              detachNewThreadSelector: @selector (reapChild:)
                             toTarget: [self class]
                           withObject: [NSArray
                                          arrayWithObjects:
                                              [NSNumber numberWithInt: _child],
                                              [NSNumber
                                                  numberWithInt: foreground],
                                              nil]];
        }
    }
  if (_master >= 0)
    close (_master);
#endif
  _child = _master = -1;
  [_pendingInput setLength: 0];
}

- (void) poll: (NSTimer *)timer
{
  NSTimeInterval now = [NSDate timeIntervalSinceReferenceDate];
  if (now - _lastBlink >= 0.5)
    {
      _lastBlink = now;
      [self advanceBlink];
    }
#ifndef _WIN32
  char buffer[8192];
  ssize_t count;
  NSUInteger total = 0;
  BOOL finished = NO;
  while (_master >= 0 && total < 262144)
    {
      count = read (_master, buffer, sizeof (buffer));
      if (count > 0)
        {
          [self consumeData: [NSData dataWithBytes: buffer length: count]];
          total += count;
        }
      else if (count < 0 && errno == EINTR)
        continue;
      else
        {
          if (count == 0 || (errno != EAGAIN && errno != EWOULDBLOCK))
            finished = YES;
          break;
        }
    }
  if (!finished && [_pendingInput length])
    {
      count = write (_master, [_pendingInput bytes], [_pendingInput length]);
      if (count > 0)
        [_pendingInput replaceBytesInRange: NSMakeRange (0, count)
                                 withBytes: NULL
                                    length: 0];
      else if (count < 0 && errno != EAGAIN && errno != EWOULDBLOCK
               && errno != EINTR)
        finished = YES;
    }
  int status;
  if (_child > 0)
    {
      pid_t result = waitpid (_child, &status, WNOHANG);
      if (result == _child || (result < 0 && errno == ECHILD))
        {
          _child = -1;
          // Keep draining output until EOF, including output larger than one poll budget.
          if (total == 0)
            finished = YES;
        }
    }
  if (finished)
    {
      [self stop];
      _ended = YES;
      [self consumeData:
                [@"\r\n[Shell exited. Press Return to start a new shell.]\r\n"
                    dataUsingEncoding: NSUTF8StringEncoding]];
    }
#endif
}

- (void) restart: (id)sender
{
  if (!_directory)
    return;
  [self stop];
  NSError *error = nil;
  if (![self startInDirectory: _directory error: &error])
    [[NSAlert alertWithError: error] runModal];
}

- (BOOL) cellAtRow: (NSInteger)row
           column: (int)column
             cell: (YCodeTerminalGlyph *)cell
{
  NSInteger history = _alternateScreen ? 0 : [_history count];
  memset (cell, 0, sizeof (*cell));
  if (row < 0 || column < 0 || column >= _columns)
    return NO;
  if (row < history)
    {
      NSData *line = [_history objectAtIndex: row];
      if ((column + 1) * sizeof (YCodeTerminalCell) > [line length])
        return NO;
      *cell = ((const YCodeTerminalCell *)[line bytes])[column].originalCell;
      return YES;
    }
  YCodeTerminalPosition position = { (int)(row - history), column };
  return position.row < _rows &&
         [_terminal getGlyph: cell row: position.row column: position.col];
}

- (NSString *) screenText
{
  NSMutableString *text = [NSMutableString string];
  int row, col;
  NSInteger history = _alternateScreen ? 0 : [_history count];
  for (row = 0; row < _rows; row++)
    {
      for (col = 0; col < _columns; col++)
        {
          YCodeTerminalGlyph cell;
          if ([self cellAtRow: history + row column: col cell: &cell]
              && cell.width != 0)
            [text appendString: terminalCellString (&cell)];
        }
      [text appendString: @"\n"];
    }
  return text;
}

- (NSColor *) color: (YCodeTerminalColor)color
{
  if (color.kind == YCodeTerminalColorDefaultForeground)
    return _foregroundColor;
  if (color.kind == YCodeTerminalColorDefaultBackground)
    return _backgroundColor;
  color = [_terminal resolvedColor: color];
  return [NSColor colorWithCalibratedRed: color.rgb.red / 255.0
                                   green: color.rgb.green / 255.0
                                    blue: color.rgb.blue / 255.0
                                   alpha: 1];
}

- (void) drawRect: (NSRect)dirty
{
  [_backgroundColor set];
  NSRectFill (dirty);
  NSInteger history = _alternateScreen ? 0 : [_history count];
  NSInteger first = history - _scrollOffset;
  NSInteger low = MIN (_selectionStart, _selectionEnd),
            high = MAX (_selectionStart, _selectionEnd);
  int row, col, pass;
  // Paint backgrounds before glyphs so a wide glyph is not erased by its
  // trailing cell. Clip each glyph to its terminal cell(s), not its font advance.
  int firstRow = MAX (0, (int)floor (NSMinY (dirty) / _cellHeight));
  int lastRow = MIN (_rows, (int)ceil (NSMaxY (dirty) / _cellHeight));
  int firstCol = MAX (0, (int)floor ((NSMinX (dirty)) / _cellWidth) - 1);
  int lastCol = MIN (_columns, (int)ceil ((NSMaxX (dirty)) / _cellWidth));
  for (pass = 0; pass < 2; pass++)
    for (row = firstRow; row < lastRow; row++)
      {
        for (col = firstCol; col < lastCol; col++)
          {
            NSRect rect = NSMakeRect (col * _cellWidth, row * _cellHeight,
                                      _cellWidth, _cellHeight);
            YCodeTerminalGlyph cell;
            if (![self cellAtRow: first + row column: col cell: &cell])
              continue;
            NSRect paintRect = rect;
            if (pass == 1)
              paintRect.size.width *= MAX (1, cell.width);
            if (!NSIntersectsRect (paintRect, dirty)
                || ![self needsToDrawRect: paintRect])
              continue;
            NSColor *fg = [self color: cell.fg], *bg = [self color: cell.bg];
            if ((cell.attributes & YCodeTerminalReverse))
              {
                NSColor *swap = fg;
                fg = bg;
                bg = swap;
              }
            NSInteger position = (first + row) * _columns + col;
            if (low >= 0 && position >= low && position <= high)
              {
                bg = [NSColor selectedTextBackgroundColor];
                fg = [NSColor selectedTextColor];
              }
            if (pass == 0)
              {
                [bg set];
                NSRectFill (rect);
                continue;
              }
            if (cell.width == 0 || (cell.attributes & YCodeTerminalConceal)
                || ((cell.attributes & YCodeTerminalBlink) && !_blinkOn))
              continue;
            // Keep backgrounds and decorations, but avoid shaping blank glyphs.
            if ((cell.chars[0] == 0
                 || (cell.chars[0] == ' ' && !cell.chars[1]))
                && !(cell.attributes & YCodeTerminalUnderline)
                && !(cell.attributes & YCodeTerminalStrike))
              continue;
            NSFont *font
                = (cell.attributes & YCodeTerminalBold) ? _boldFont : _font;
            if ((cell.attributes & YCodeTerminalItalic))
              {
                NSFont *italic = [[NSFontManager sharedFontManager]
                    convertFont: font
                    toHaveTrait: NSItalicFontMask];
                if (italic)
                  font = italic;
              }
            NSMutableDictionary *attributes = [NSMutableDictionary
                dictionaryWithObjectsAndKeys: font, NSFontAttributeName, fg,
                                             NSForegroundColorAttributeName,
                                             nil];
            if ((cell.attributes & YCodeTerminalUnderline))
              [attributes
                  setObject: [NSNumber
                                numberWithInt: (cell.attributes
                                               & YCodeTerminalDoubleUnderline)
                                                  ? NSUnderlineStyleDouble
                                                  : NSUnderlineStyleSingle]
                     forKey: NSUnderlineStyleAttributeName];
            if ((cell.attributes & YCodeTerminalStrike))
              [attributes
                  setObject: [NSNumber numberWithInt: NSUnderlineStyleSingle]
                     forKey: NSStrikethroughStyleAttributeName];
            [NSGraphicsContext saveGraphicsState];
            NSRectClip (NSMakeRect (rect.origin.x, rect.origin.y,
                                    _cellWidth * MAX (1, cell.width),
                                    _cellHeight));
            [[terminalCellString (&cell) precomposedStringWithCanonicalMapping]
                   drawAtPoint: rect.origin
                withAttributes: attributes];
            [NSGraphicsContext restoreGraphicsState];
          }
      }
  if (_cursorVisible && !_scrollOffset && (![self cursorCanBlink] || _blinkOn))
    {
      YCodeTerminalPosition cursor = _cursor;
      [_cursorColor set];
      NSInteger shape = _preferredCursorShape;
      if (shape == 0)
        shape = _cursorShape == 2 ? 4 : (_cursorShape == 3 ? 3 : 2);
      NSRect rect
          = NSMakeRect (cursor.col * _cellWidth, cursor.row * _cellHeight,
                        _cellWidth, _cellHeight);
      if (shape == 4)
        NSRectFill (
            NSMakeRect (rect.origin.x, NSMaxY (rect) - 2, _cellWidth, 2));
      else if (shape == 3)
        NSRectFill (NSMakeRect (rect.origin.x, rect.origin.y, 2, _cellHeight));
      else if (shape == 1)
        {
          NSRectFill (rect);
          YCodeTerminalGlyph cell;
          if ([_terminal getGlyph: &cell row: cursor.row column: cursor.col]
              && cell.width != 0 && !(cell.attributes & YCodeTerminalConceal))
            {
              NSColor *rgb = [_cursorColor
                  colorUsingColorSpaceName: NSCalibratedRGBColorSpace];
              NSColor *ink
                  = ([rgb redComponent] * 0.299 + [rgb greenComponent] * 0.587
                     + [rgb blueComponent] * 0.114)
                            > 0.5
                        ? [NSColor blackColor]
                        : [NSColor whiteColor];
              [NSGraphicsContext saveGraphicsState];
              NSRectClip (rect);
              [terminalCellString (&cell)
                     drawAtPoint: rect.origin
                  withAttributes: [NSDictionary
                                     dictionaryWithObjectsAndKeys:
                                         (cell.attributes & YCodeTerminalBold)
                                             ? _boldFont
                                             : _font,
                                         NSFontAttributeName, ink,
                                         NSForegroundColorAttributeName, nil]];
              [NSGraphicsContext restoreGraphicsState];
            }
        }
      else
        NSFrameRect (rect);
    }
}

- (void) keyDown: (NSEvent *)event
{
  NSString *characters = [event characters];
  if (![characters length])
    return;
  unichar c = [characters characterAtIndex: 0];
  if (_ended && (c == '\r' || c == '\n'))
    {
      [self restart: nil];
      return;
    }
  if (!_alternateScreen && ([event modifierFlags] & NSShiftKeyMask)
      && (c == NSPageUpFunctionKey || c == NSPageDownFunctionKey))
    {
      _scrollOffset
          = MIN ((NSInteger)[_history count],
                 MAX (0, _scrollOffset
                             + (c == NSPageUpFunctionKey ? _rows : -_rows)));
      [self updateScroller];
      [self setNeedsDisplay: YES];
      return;
    }
  BOOL redraw = _scrollOffset != 0 || _selectionStart >= 0;
  _scrollOffset = 0;
  _selectionStart = _selectionEnd = -1;
  _wheelRemainder = 0;
  [self updateScroller];
  [_terminal handleKeyEvent: event];
  if (redraw)
    [self setNeedsDisplay: YES];
  else if (!_blinkOn)
    {
      YCodeTerminalPosition cursor = _cursor;
      [self invalidateCursorAt: cursor];
    }
  _blinkOn = YES;
  _lastBlink = [NSDate timeIntervalSinceReferenceDate];
}

- (BOOL) performKeyEquivalent: (NSEvent *)event
{
  if ([[self window] firstResponder] == self
      && ([event modifierFlags] & NSControlKeyMask)
      && !([event modifierFlags] & NSCommandKeyMask))
    {
      [self keyDown: event];
      return YES;
    }
  return [super performKeyEquivalent: event];
}

- (NSInteger) positionForEvent: (NSEvent *)event
{
  NSPoint p = [self convertPoint: [event locationInWindow] fromView: nil];
  NSInteger history = _alternateScreen ? 0 : [_history count];
  int row = MIN (_rows - 1, MAX (0, (int)(p.y / _cellHeight)));
  int col = MIN (_columns - 1, MAX (0, (int)(p.x / _cellWidth)));
  return (history - _scrollOffset + row) * _columns + col;
}

- (BOOL) reportMouse: (NSEvent *)event button: (int)button pressed: (BOOL)pressed
{
  if (!_mouseReporting || ([event modifierFlags] & NSShiftKeyMask))
    return NO;
  NSPoint p = [self convertPoint: [event locationInWindow] fromView: nil];
  [_terminal mouseAtRow: MIN (_rows - 1, MAX (0, (int)(p.y / _cellHeight)))
                 column: MIN (_columns - 1, MAX (0, (int)(p.x / _cellWidth)))
                 button: button
                pressed: pressed
              modifiers: [event modifierFlags]];
  return YES;
}

- (void) mouseDown: (NSEvent *)event
{
  [[self window] makeFirstResponder: self];
  if ([self reportMouse: event button: 1 pressed: YES])
    return;
  _selectionStart = _selectionEnd = [self positionForEvent: event];
  [self setNeedsDisplay: YES];
}

- (void) mouseDragged: (NSEvent *)event
{
  if ([self reportMouse: event button: 0 pressed: NO])
    return;
  _selectionEnd = [self positionForEvent: event];
  [self setNeedsDisplay: YES];
}

- (void) mouseUp: (NSEvent *)event
{
  [self reportMouse: event button: 1 pressed: NO];
}

- (void) rightMouseDown: (NSEvent *)event
{
  if (![self reportMouse: event button: 3 pressed: YES])
    [super rightMouseDown: event];
}

- (void) rightMouseUp: (NSEvent *)event
{
  [self reportMouse: event button: 3 pressed: NO];
}

- (void) rightMouseDragged: (NSEvent *)event
{
  [self reportMouse: event button: 0 pressed: NO];
}

- (void) otherMouseDown: (NSEvent *)event
{
  [self reportMouse: event button: 2 pressed: YES];
}

- (void) otherMouseUp: (NSEvent *)event
{
  [self reportMouse: event button: 2 pressed: NO];
}

- (void) otherMouseDragged: (NSEvent *)event
{
  [self reportMouse: event button: 0 pressed: NO];
}

- (void) mouseMoved: (NSEvent *)event
{
  [self reportMouse: event button: 0 pressed: NO];
}

- (void) updateScroller
{
  NSInteger history = _alternateScreen ? 0 : [_history count];
  _scrollOffset = MIN (history, MAX (0, _scrollOffset));
  [_historyScroller
       setFloatValue: history ? 1.0 - (double)_scrollOffset / history : 1.0
      knobProportion: (double)_rows / MAX (1, history + _rows)];
  [_historyScroller setEnabled: history > 0];
}

- (void) scrollHistory: (NSScroller *)sender
{
  NSInteger history = _alternateScreen ? 0 : [_history count];
  switch ([sender hitPart])
    {
    case NSScrollerDecrementLine:
      _scrollOffset++;
      break;
    case NSScrollerIncrementLine:
      _scrollOffset--;
      break;
    case NSScrollerDecrementPage:
      _scrollOffset += MAX (1, _rows - 1);
      break;
    case NSScrollerIncrementPage:
      _scrollOffset -= MAX (1, _rows - 1);
      break;
    default:
      _scrollOffset = lround ((1.0 - [sender doubleValue]) * history);
      break;
    }
  _wheelRemainder = 0;
  [self updateScroller];
  [self setNeedsDisplay: YES];
}

- (void) scrollWheel: (NSEvent *)event
{
  if ([event deltaY] == 0)
    return;
  if ([self reportMouse: event button: [event deltaY] > 0 ? 4 : 5 pressed: YES])
    return;
  if (_alternateScreen)
    return;
  // Preserve fractional trackpad movement instead of truncating every event.
  _wheelRemainder += [event deltaY] * 3;
  NSInteger lines = (NSInteger)_wheelRemainder;
  _wheelRemainder -= lines;
  _scrollOffset += lines;
  [self updateScroller];
  [self setNeedsDisplay: YES];
}

- (void) selectAll: (id)sender
{
  _selectionStart = 0;
  _selectionEnd
      = ((_alternateScreen ? 0 : [_history count]) + _rows) * _columns - 1;
  [self setNeedsDisplay: YES];
}

- (NSPasteboard *) pasteboard
{
  return [NSPasteboard generalPasteboard];
}

- (void) copy: (id)sender
{
  if (_selectionStart < 0)
    return;
  NSInteger start = MIN (_selectionStart, _selectionEnd),
            end = MAX (_selectionStart, _selectionEnd);
  NSMutableString *result = [NSMutableString string],
                  *line = [NSMutableString string];
  NSInteger i;
  for (i = start; i <= end; i++)
    {
      YCodeTerminalGlyph cell;
      if ([self cellAtRow: i / _columns column: i % _columns cell: &cell]
          && cell.width != 0)
        [line appendString: terminalCellString (&cell)];
      if (i % _columns == _columns - 1 || i == end)
        {
          while ([line hasSuffix: @" "])
            [line deleteCharactersInRange: NSMakeRange ([line length] - 1, 1)];
          [result appendString: line];
          [line setString: @""];
          if (i != end)
            [result appendString: @"\n"];
        }
    }
  NSPasteboard *pasteboard = [self pasteboard];
  [pasteboard declareTypes: [NSArray arrayWithObject: NSStringPboardType]
                     owner: nil];
  [pasteboard setString: result forType: NSStringPboardType];
}

- (void) paste: (id)sender
{
  NSString *text = [[self pasteboard] stringForType: NSStringPboardType];
  if (![text length])
    return;
  // Strip escape bytes so pasted text cannot terminate bracketed-paste mode.
  text = [text stringByReplacingOccurrencesOfString: @"\033" withString: @""];
  text = [text stringByReplacingOccurrencesOfString: @"\r\n" withString: @"\n"];
  text = [text stringByReplacingOccurrencesOfString: @"\n" withString: @"\r"];
  [_terminal sendString: text];
  _scrollOffset = 0;
  _wheelRemainder = 0;
  [self updateScroller];
  [self setNeedsDisplay: YES];
}

- (NSMenu *) menuForEvent: (NSEvent *)event
{
  NSMenu *menu = AUTORELEASE ([[NSMenu alloc] initWithTitle: @"Terminal"]);
  NSArray *titles = [NSArray arrayWithObjects: @"Copy", @"Paste", @"Select All",
                                              @"Restart Terminal", nil];
  SEL actions[] = { @selector (copy:), @selector (paste:),
                    @selector (selectAll:), @selector (restart:) };
  NSUInteger i;
  for (i = 0; i < [titles count]; i++)
    {
      NSMenuItem *item =
          [[NSMenuItem alloc] initWithTitle: [titles objectAtIndex: i]
                                     action: actions[i]
                              keyEquivalent: @""];
      [item setTarget: self];
      [menu addItem: item];
      RELEASE (item);
    }
  return menu;
}

@end
