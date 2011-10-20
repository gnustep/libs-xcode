#import "PBXCommon.h"
#import "PBXContainerItemProxy.h"
#import "PBXCoder.h"
#import "PBXContainer.h"
#import "GSXCBuildContext.h"

@implementation PBXContainerItemProxy

// Methods....
- (NSString *) proxyType // getter
{
  return proxyType;
}

- (void) setProxyType: (NSString *)object; // setter
{
  ASSIGN(proxyType,object);
}

- (NSString *) remoteGlobalIDString // getter
{
  return remoteGlobalIDString;
}

- (void) setRemoteGlobalIDString: (NSString *)object; // setter
{
  ASSIGN(remoteGlobalIDString,object);
}

- (id) containerPortal // getter
{
  return containerPortal;
}

- (void) setContainerPortal: (id)object; // setter
{
  ASSIGN(containerPortal,object);
}

- (NSString *) remoteInfo // getter
{
  return remoteInfo;
}

- (void) setRemoteInfo: (NSString *)object; // setter
{
  ASSIGN(remoteInfo,object);
}

- (BOOL) build
{
  PBXContainer *currentContainer = [[GSXCBuildContext sharedBuildContext] objectForKey: @"CONTAINER"];
  containerPortal = [[currentContainer objects] objectForKey: containerPortal];

  NSLog(@"Reading %@",[containerPortal path]);
  PBXCoder *coder = [[PBXCoder alloc] initWithProjectFile: [containerPortal path]];
  [coder changeToProjectRoot];
  PBXContainer *container = [coder unarchive];
  return [container build];
}

@end
