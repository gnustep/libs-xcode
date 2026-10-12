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

#import "YCodeControlIcons.h"

static void YCLine(CGFloat x1, CGFloat y1, CGFloat x2, CGFloat y2)
{
  NSBezierPath *path = [NSBezierPath bezierPath];
  [path setLineWidth:2];
  [path setLineCapStyle:NSRoundLineCapStyle];
  [path moveToPoint:NSMakePoint(x1, y1)];
  [path lineToPoint:NSMakePoint(x2, y2)];
  [path stroke];
}
static void YCPlay(CGFloat x)
{
  NSBezierPath *path = [NSBezierPath bezierPath];
  [path moveToPoint:NSMakePoint(x, 4)];
  [path lineToPoint:NSMakePoint(x + 13, 12)];
  [path lineToPoint:NSMakePoint(x, 20)];
  [path closePath];
  [path fill];
}

NSImage *YCodeControlIcon(NSString *name, CGFloat size)
{
  NSString *key = [NSString stringWithFormat:@"YCodeControl-%@-%g", name, (double)size];
  NSImage *image = [NSImage imageNamed:key];
  if (image) return image;
  image = AUTORELEASE([[NSImage alloc] initWithSize:NSMakeSize(size, size)]);
  [image lockFocus];
  NSAffineTransform *scale = [NSAffineTransform transform];
  [scale scaleBy:size / 24.0];
  [scale concat];
  [[NSColor colorWithCalibratedRed:0.18 green:0.43 blue:0.68 alpha:1] set];
  if ([name isEqual:@"run"] || [name isEqual:@"go"] || [name isEqual:@"continue"])
    {
      [[NSColor colorWithCalibratedRed:0.16 green:0.57 blue:0.29 alpha:1] set];
      YCPlay([name isEqual:@"continue"] ? 9 : 6);
      if ([name isEqual:@"continue"]) NSRectFill(NSMakeRect(3, 4, 3, 16));
    }
  else if ([name isEqual:@"stop"])
    {
      [[NSColor colorWithCalibratedRed:0.77 green:0.23 blue:0.22 alpha:1] set];
      [[NSBezierPath bezierPathWithRoundedRect:NSMakeRect(4, 4, 16, 16) xRadius:2 yRadius:2] fill];
    }
  else if ([name isEqual:@"pause"])
    { NSRectFill(NSMakeRect(5, 4, 5, 16)); NSRectFill(NSMakeRect(14, 4, 5, 16)); }
  else if ([name isEqual:@"debug"])
    {
      [[NSBezierPath bezierPathWithOvalInRect:NSMakeRect(7, 4, 10, 14)] fill];
      [[NSBezierPath bezierPathWithOvalInRect:NSMakeRect(9, 17, 6, 5)] fill];
      for (NSInteger y = 7; y <= 17; y += 5)
        { YCLine(3, y - 2, 8, y); YCLine(16, y, 21, y - 2); }
      [[NSColor whiteColor] set]; YCLine(12, 6, 12, 15);
    }
  else if ([name isEqual:@"restart"])
    {
      NSBezierPath *arc = [NSBezierPath bezierPath];
      [arc setLineWidth:2.5];
      [arc appendBezierPathWithArcWithCenter:NSMakePoint(12, 12) radius:8 startAngle:40 endAngle:320];
      [arc stroke];
      NSBezierPath *arrow = [NSBezierPath bezierPath];
      [arrow moveToPoint:NSMakePoint(20, 21)]; [arrow lineToPoint:NSMakePoint(20, 13)];
      [arrow lineToPoint:NSMakePoint(12, 17)]; [arrow closePath]; [arrow fill];
    }
  else if ([name isEqual:@"next"])
    {
      NSBezierPath *arc = [NSBezierPath bezierPath];
      [arc setLineWidth:2];
      [arc moveToPoint:NSMakePoint(4, 10)];
      [arc curveToPoint:NSMakePoint(20, 10) controlPoint1:NSMakePoint(4, 23) controlPoint2:NSMakePoint(20, 23)];
      [arc stroke]; YCLine(16, 14, 20, 10); YCLine(20, 10, 23, 15);
      [[NSBezierPath bezierPathWithOvalInRect:NSMakeRect(9, 4, 6, 6)] fill];
    }
  else if ([name isEqual:@"stepInto"] || [name isEqual:@"stepOut"] ||
           [name isEqual:@"up"] || [name isEqual:@"down"])
    {
      BOOL up = [name isEqual:@"stepOut"] || [name isEqual:@"up"];
      CGFloat tip = up ? 20 : 4, back = up ? 15 : 9;
      YCLine(12, up ? 5 : 19, 12, tip);
      YCLine(7, back, 12, tip); YCLine(12, tip, 17, back);
      if ([name hasPrefix:@"step"])
        { YCLine(5, up ? 3 : 1, 19, up ? 3 : 1); }
    }
  else if ([name isEqual:@"breakpoint"])
    {
      NSBezierPath *path = [NSBezierPath bezierPath];
      [path moveToPoint:NSMakePoint(3, 6)]; [path lineToPoint:NSMakePoint(16, 6)];
      [path lineToPoint:NSMakePoint(22, 12)]; [path lineToPoint:NSMakePoint(16, 18)];
      [path lineToPoint:NSMakePoint(3, 18)]; [path closePath]; [path fill];
    }
  else if ([name isEqual:@"build"])
    {
      NSAffineTransform *rotation = [NSAffineTransform transform];
      [rotation translateXBy:12 yBy:12]; [rotation rotateByDegrees:-40];
      [rotation translateXBy:-12 yBy:-12]; [rotation concat];
      NSRectFill(NSMakeRect(10, 3, 4, 14)); NSRectFill(NSMakeRect(5, 16, 14, 5));
    }
  else if ([name isEqual:@"clean"])
    {
      YCLine(7, 8, 17, 21);
      NSBezierPath *path = [NSBezierPath bezierPath];
      [path moveToPoint:NSMakePoint(3, 4)]; [path lineToPoint:NSMakePoint(7, 12)];
      [path lineToPoint:NSMakePoint(14, 7)]; [path lineToPoint:NSMakePoint(9, 2)];
      [path closePath]; [path fill];
    }
  else if ([name isEqual:@"navigator"] || [name isEqual:@"inspector"])
    {
      NSBezierPath *frame = [NSBezierPath bezierPathWithRect:NSMakeRect(3, 4, 18, 16)];
      [frame setLineWidth:2]; [frame stroke];
      NSRectFill(NSMakeRect([name isEqual:@"navigator"] ? 4 : 15, 5, 5, 14));
    }
  [image unlockFocus];
  [image setName:key];
  return image;
}
