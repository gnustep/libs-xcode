#import "PBXCommon.h"
#import "PBXReferenceProxy.h"

@implementation PBXReferenceProxy

// Methods....
- (NSString *) sourceTree // getter
{
  return sourceTree;
}

- (void) setSourceTree: (NSString *)object; // setter
{
  ASSIGN(sourceTree,object);
}

- (NSString *) fileType // getter
{
  return fileType;
}

- (void) setFileType: (NSString *)object; // setter
{
  ASSIGN(fileType,object);
}

- (PBXContainerItemProxy *) remoteRef // getter
{
  return remoteRef;
}

- (void) setRemoteRef: (PBXContainerItemProxy *)object; // setter
{
  ASSIGN(remoteRef,object);
}

- (NSString *) path // getter
{
  return path;
}

- (void) setPath: (NSString *)object; // setter
{
  ASSIGN(path,object);
}


@end