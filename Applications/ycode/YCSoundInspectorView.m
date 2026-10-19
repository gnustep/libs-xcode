/*
   Project: Ycode

   Copyright (C) 2018 Free Software Foundation

   Author: Gregory John Casamento,,,

   Created: 2018-12-17 20:16:45 -0500 by heron

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

#import "YCSoundInspectorView.h"
#import "YCodeEditorDocument.h"
#include <math.h>
#ifdef YCODE_HAVE_SNDFILE
#include <sndfile.h>
#endif

@interface YCSoundWaveformView : NSView
{
  NSData *_samples;
}
- (void) setSamples: (NSData *)samples;
@end

@implementation YCSoundWaveformView
- (void) dealloc
{
  RELEASE (_samples);
  [super dealloc];
}

- (void) setSamples: (NSData *)samples
{
  ASSIGN (_samples, samples);
  [self setNeedsDisplay: YES];
}

- (void) drawRect: (NSRect)rect
{
  [[NSColor textBackgroundColor] set];
  NSRectFill ([self bounds]);
  NSRect area = NSInsetRect ([self bounds], 4, 4);
  [[NSColor disabledControlTextColor] set];
  NSBezierPath *line = [NSBezierPath bezierPath];
  [line moveToPoint: NSMakePoint (NSMinX (area), NSMidY (area))];
  [line lineToPoint: NSMakePoint (NSMaxX (area), NSMidY (area))];
  [line stroke];
  const float *samples = [_samples bytes];
  NSUInteger count = [_samples length] / sizeof (float), i;
  [[NSColor selectedControlColor] set];
  NSBezierPath *wave = [NSBezierPath bezierPath];
  for (i = 0; i < count; i++)
    {
      CGFloat x = NSMinX (area) + (i + 0.5) * NSWidth (area) / count;
      CGFloat height = samples[i] * NSHeight (area) / 2;
      [wave moveToPoint: NSMakePoint (x, NSMidY (area) - height)];
      [wave lineToPoint: NSMakePoint (x, NSMidY (area) + height)];
    }
  [wave stroke];
}
@end

@implementation YCSoundInspectorView
- (id) initWithFrame: (NSRect)frame
{
  self = [super initWithFrame: frame];
  if (self)
    {
      CGFloat width = NSWidth (frame), height = NSHeight (frame);
      _title = [[NSTextField alloc]
          initWithFrame: NSMakeRect (8, height - 38, width - 16, 28)];
      [_title setEditable: NO];
      [_title setBezeled: NO];
      [_title setDrawsBackground: NO];
      [_title setAutoresizingMask: NSViewWidthSizable | NSViewMinYMargin];
      [self addSubview: _title];
      RELEASE (_title);
      _waveform = [[YCSoundWaveformView alloc]
          initWithFrame: NSMakeRect (8, height - 174, width - 16, 128)];
      [_waveform setAutoresizingMask: NSViewWidthSizable | NSViewMinYMargin];
      [self addSubview: _waveform];
      RELEASE (_waveform);
      _play = [[NSButton alloc]
          initWithFrame: NSMakeRect (8, height - 214, 88, 30)];
      [_play setTitle: @"Play"];
      [_play setTarget: self];
      [_play setAction: @selector (togglePlayback:)];
      [_play setAutoresizingMask: NSViewMinYMargin];
      [self addSubview: _play];
      RELEASE (_play);
      _stop = [[NSButton alloc]
          initWithFrame: NSMakeRect (100, height - 214, 72, 30)];
      [_stop setTitle: @"Stop"];
      [_stop setTarget: self];
      [_stop setAction: @selector (stopPlayback:)];
      [_stop setAutoresizingMask: NSViewMinYMargin];
      [self addSubview: _stop];
      RELEASE (_stop);
      _status = [[NSTextField alloc]
          initWithFrame: NSMakeRect (8, height - 288, width - 16, 66)];
      [_status setEditable: NO];
      [_status setBezeled: NO];
      [_status setDrawsBackground: NO];
      [_status setFont: [NSFont systemFontOfSize: 12]];
      [_status setAutoresizingMask: NSViewWidthSizable | NSViewMinYMargin];
      [self addSubview: _status];
      RELEASE (_status);
      [[NSNotificationCenter defaultCenter]
          addObserver: self
             selector: @selector (windowClosing:)
                 name: NSWindowWillCloseNotification
               object: nil];
      [self inspectDocument: nil];
    }
  return self;
}

- (NSString *) inspectorIdentifier
{
  return @"sound";
}
- (NSString *) inspectorTitle
{
  return @"Sound";
}

- (void) dealloc
{
  [[NSNotificationCenter defaultCenter] removeObserver: self];
  [_decoder cancel];
  RELEASE (_decoder);
  [self stopPlayback: nil];
  RELEASE (_path);
  RELEASE (_peaks);
  [super dealloc];
}

- (void) windowClosing: (NSNotification *)notification
{
  if ([notification object] == [self window])
    {
      [_decoder cancel];
      DESTROY (_decoder);
      [self stopPlayback: nil];
    }
}

- (void) inspectDocument: (YCodeEditorDocument *)document
{
  NSString *path = [document isSoundDocument] ? [document filePath] : nil;
  if (path && [_path isEqual: path])
    return;
  [self stopPlayback: nil];
  [_decoder cancel];
  DESTROY (_decoder);
  ASSIGN (_path, path);
  _generation++;
  _duration = 0;
  DESTROY (_peaks);
  [(YCSoundWaveformView *)_waveform setSamples: nil];
  [_title
      setStringValue: path ? [path lastPathComponent] : @"No sound selected."];
  [_play setEnabled: path != nil];
  [_status setStringValue: path ? @"Loading waveform…" : @""];
  if (path)
    {
      NSDictionary *request = [NSDictionary
          dictionaryWithObjectsAndKeys:
              path, @"path", [NSNumber numberWithUnsignedInteger: _generation],
              @"generation", nil];
      _decoder = [[NSThread alloc] initWithTarget: self
                                         selector: @selector (decodeWaveform:)
                                           object: request];
      [_decoder start];
    }
}

- (void) decodeWaveform: (NSDictionary *)request
{
  NSAutoreleasePool *pool = [NSAutoreleasePool new];
  NSMutableDictionary *result =
      [NSMutableDictionary dictionaryWithDictionary: request];
  [result setObject: @"Waveform unavailable for this audio format."
             forKey: @"message"];
#ifdef YCODE_HAVE_SNDFILE
  SF_INFO info;
  memset (&info, 0, sizeof (info));
  SNDFILE *file
      = sf_open ([[request objectForKey: @"path"] fileSystemRepresentation],
                 SFM_READ, &info);
  if (file && info.frames > 0 && info.samplerate > 0 && info.channels > 0
      && info.channels <= 256)
    {
      float peaks[1024] = { 0 };
      float *buffer = malloc (sizeof (float) * 4096 * info.channels);
      sf_count_t offset = 0, frames;
      if (buffer)
        {
          while (![[NSThread currentThread] isCancelled]
                 && (frames = sf_readf_float (file, buffer, 4096)) > 0)
            {
              sf_count_t i;
              for (i = 0; i < frames; i++)
                {
                  NSUInteger bin
                      = MIN (1023, (NSUInteger)(((double)offset + i) * 1024
                                                / info.frames));
                  int channel;
                  for (channel = 0; channel < info.channels; channel++)
                    {
                      float value
                          = fabsf (buffer[i * info.channels + channel]);
                      if (isfinite (value))
                        peaks[bin] = MAX (peaks[bin], MIN (1, value));
                    }
                }
              offset += frames;
            }
          free (buffer);
          if (offset > 0 && sf_error (file) == 0)
            {
              [result setObject: [NSData dataWithBytes: peaks
                                               length: sizeof (peaks)]
                         forKey: @"peaks"];
              [result setObject: [NSNumber numberWithDouble: (double)offset
                                                           / info.samplerate]
                         forKey: @"duration"];
              [result setObject: [NSString stringWithFormat:
                                              @"%.2f s · %d Hz · %d channel%@",
                                              (double)offset / info.samplerate,
                                              info.samplerate, info.channels,
                                              info.channels == 1 ? @"" : @"s"]
                         forKey: @"message"];
            }
        }
    }
  if (file)
    sf_close (file);
#else
  [result
      setObject:
          @"Waveform support requires libsndfile. Playback may still be available."
         forKey: @"message"];
#endif
  if (![[NSThread currentThread] isCancelled])
    [self performSelectorOnMainThread: @selector (waveformDecoded:)
                           withObject: result
                        waitUntilDone: NO];
  [pool drain];
}

- (void) waveformDecoded: (NSDictionary *)result
{
  if ([[result objectForKey: @"generation"] unsignedIntegerValue]
      != _generation)
    return;
  DESTROY (_decoder);
  ASSIGN (_peaks, [result objectForKey: @"peaks"]);
  _duration = [[result objectForKey: @"duration"] doubleValue];
  [(YCSoundWaveformView *)_waveform setSamples: _peaks];
  if (!_sound)
    [_status setStringValue: [result objectForKey: @"message"]];
}

- (void) togglePlayback: (id)sender
{
  if (!_path)
    return;
  if (!_paused && [_sound isPlaying])
    {
      if ([_sound pause])
        {
          _paused = YES;
          [_play setTitle: @"Resume"];
        }
      return;
    }
  if (!_sound)
    _sound = [[NSSound alloc] initWithContentsOfFile: _path byReference: YES];
  BOOL started = _paused ? [_sound resume] : [_sound play];
  if (!started)
    {
      [self stopPlayback: nil];
      [_status
          setStringValue:
              @"Unable to play this sound. Check the format and audio device."];
      return;
    }
  _paused = NO;
  _duration = [_sound duration];
  [_play setTitle: @"Pause"];
  [_stop setEnabled: YES];
  if (!_timer)
    _timer = RETAIN ([NSTimer
        scheduledTimerWithTimeInterval: 0.2
                                target: self
                              selector: @selector (updatePlayback:)
                              userInfo: nil
                               repeats: YES]);
}

- (void) updatePlayback: (id)sender
{
  if (!_paused && ![_sound isPlaying])
    {
      [self stopPlayback: nil];
      return;
    }
  [_status setStringValue: [NSString stringWithFormat: @"%@ %.1f / %.1f s",
                                                     _paused ? @"Paused"
                                                             : @"Playing",
                                                     [_sound currentTime],
                                                     [_sound duration]]];
}

- (void) stopPlayback: (id)sender
{
  [_timer invalidate];
  DESTROY (_timer);
  [_sound stop];
  DESTROY (_sound);
  _paused = NO;
  [_play setTitle: @"Play"];
  [_stop setEnabled: NO];
  if (_path)
    [_status setStringValue: [NSString stringWithFormat: @"Stopped · %.2f s",
                                                       _duration]];
}
@end
