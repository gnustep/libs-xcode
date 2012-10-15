#import "PBXContainer.h"
#import "PBXCommon.h"
#import "PBXProject.h"
#import "PBXFileReference.h"

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

- (void) collectHeaderFileReferences
{
  NSString *includeDirs = @"";
  NSMutableArray *dirs = [NSMutableArray array];
  NSArray *array = [objects allValues];
  NSEnumerator *en = [array objectEnumerator];
  id obj = nil;

  while((obj = [en nextObject]) != nil)
    {
      if([obj isKindOfClass:[PBXFileReference class]])
	{
	  if([[obj lastKnownFileType] isEqualToString:@"sourcecode.c.h"])
	    {
	      NSString *includePath = [[obj path] stringByDeletingLastPathComponent];
	      if([includePath isEqualToString:@""] == NO)
		{
		  if([dirs containsObject:includePath] == NO)
		    {
		      [dirs addObject:includePath];
		      includeDirs = [includeDirs stringByAppendingFormat: @" -I./%@ ",includePath]; 
		    }
		}
	    }
	}
    }

  [rootObject setContext: [NSDictionary dictionaryWithObject:includeDirs forKey:@"INCLUDE_DIRS"]];
}

- (BOOL) build
{
  [self collectHeaderFileReferences];
  [rootObject setContainer: self];
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
