#import "PBXCommon.h"
#import "PBXContainerItemProxy.h"
#import "PBXCoder.h"
#import "PBXContainer.h"
#import "GSXCBuildContext.h"

#import <unistd.h>

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
  // NSString *currentDir = [[GSXCBuildContext sharedBuildContext] objectForKey: @"PROJECT_ROOT"];
  containerPortal = [[currentContainer objects] objectForKey: containerPortal];

  if([containerPortal isKindOfClass: [PBXFileReference class]])
    {
      NSLog(@"Reading %@",[containerPortal path]);
      char *dir = getcwd(NULL, 0);
      PBXCoder *coder = [[PBXCoder alloc] initWithProjectFile: [containerPortal path]];
      NSLog(@"************************************* Changing to Project Root: %@",
            [coder projectRoot]);
      chdir([[coder projectRoot] cString]);
      PBXContainer *container = [coder unarchive];
      BOOL result = [container build];
      chdir(dir);
      NSLog(@"************************************ Changing back to %s", dir);
      free(dir);

      return result;
    }
  else
    {
      NSLog(@"***** Item Proxy is project = %@",containerPortal);
      return YES;
    }

  return NO;
}

@end
