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

  containerPortal = [[currentContainer objects] objectForKey: containerPortal];
  if([containerPortal isKindOfClass: [PBXFileReference class]])
    {
      puts([[NSString stringWithFormat: @"=== Proxy Reading %s%@%s", CYAN, [containerPortal path], RESET] cString]);
      char *dir = getcwd(NULL, 0);
      PBXCoder *coder = [[PBXCoder alloc] initWithProjectFile: [containerPortal path]];
      chdir([[coder projectRoot] cString]);
      PBXContainer *container = [coder unarchive];
      [container setFilename: [containerPortal path]];
      BOOL result = [container build];
      chdir(dir);
      free(dir);

      return result;
    }
  else
    {
      return YES;
    }

  return NO;
}

@end
