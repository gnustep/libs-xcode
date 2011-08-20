#import "PBXContainer.h"

@implementation PBXContainer

- (void) applyKeysAndValuesFromDictionary: (NSDictionary *)dictionary
{
  NSEnumerator *en = [dictionary keyEnumerator];
  NSString *key = nil;
  while((key = [en nextObject]) != nil)
    {
      id value = [dictionary objectForKey: key];
      [self setValue: value
	      forKey: key];
    }
}

- (id) initWithContentsOfFile: (NSString *)fileName
{
  if((self = [super init]) != nil)
     {
       NSDictionary *dict = 
	 [NSDictionary dictionaryWithContentsOfFile: fileName];
       [self applyKeysAndValuesFromDictionary: dict];
     }
  return self;
}

/*
- (id) initWithPBXCoder: (PBXCoder *)coder
{
  if((self = [super init]) != nil)
    {
      // archiveVersion = [coder decodeObjectForKey: @"archiveVersion"];
      // classes = [coder decodeObjectForKey: @"classes"];
    }
  return self;
}
*/

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
@end
