#import "PBXContainer.h"
#import "PBXCommon.h"

@implementation PBXContainer

- (void) dealloc
{
  RELEASE(archiveVersion);
  RELEASE(classes);
  RELEASE(objectVersion);
  RELEASE(objects);
  [super dealloc];
}

- (void) setArchiveVersion: (NSString *)version
{
  ASSIGN(archiveVersion,version);
}

- (NSString *) archiveVersion
{
  return archiveVersion;
}

- (void) setClasses: (NSMutableDictionary *)dict
{
  ASSIGN(classes,dict);
}

- (NSMutableDictionary *) classes
{
  return classes;
}

- (void) setObjectVersion: (NSString *)version
{
  ASSIGN(objectVersion,version);
}

- (NSString *) objectVersion
{
  return objectVersion;
}

- (void) setObjects: (NSMutableDictionary *)dict
{
  ASSIGN(objects,dict);
}

- (NSMutableDictionary *) objects
{
  return objects;
}

- (id) rootObject
{
  return rootObject;
}

- (void) setRootObject: (id)object
{
  ASSIGN(rootObject, object);
}

- (BOOL) build
{
  return [rootObject build];
}

- (BOOL) clean
{
  return [rootObject clean];
}

- (BOOL) install
{
  return [rootObject install];
}
@end
