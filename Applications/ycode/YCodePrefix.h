/* Native compatibility definitions; GNUstep supplies these in Foundation. */
#ifdef __OBJC__
#import <XCode/GSXCCommon.h>
#ifndef CREATE_AUTORELEASE_POOL
#define CREATE_AUTORELEASE_POOL(pool)                                         \
  NSAutoreleasePool *pool = [NSAutoreleasePool new]
#endif
#ifndef RETAIN
#define RETAIN(object) [(object) retain]
#endif
#endif
