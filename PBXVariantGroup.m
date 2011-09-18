#import "PBXCommon.h"
#import "PBXVariantGroup.h"
#import "PBXGroup.h"
#import "PBXFileReference.h"
#import "GSXCBuildContext.h"

@implementation PBXVariantGroup

// Methods....
- (NSString *) sourceTree // getter
{
  return sourceTree;
}

- (void) setSourceTree: (NSString *)object; // setter
{
  ASSIGN(sourceTree,object);
}

- (NSString *) path // getter
{
  return path;
}

- (void) setPath: (NSString *)object; // setter
{
  ASSIGN(path,object);
}

- (NSMutableArray *) children // getter
{
  return children;
}

- (void) setChildren: (NSMutableArray *)object; // setter
{
  ASSIGN(children,object);
}

- (NSString *) name // getter
{
  return name;
}

- (void) setName: (NSString *)object; // setter
{
  ASSIGN(name,object);
}

- (NSString *) resolvePathFor: (id)object 
		    withGroup: (PBXGroup *)group
			found: (BOOL *)found
{
  NSString *result = @"";
  NSArray *chldren = [group children];
  NSEnumerator *en = [chldren objectEnumerator];
  id file = nil;
  while((file = [en nextObject]) != nil && *found == NO)
    {
      if(file == self) // have we found ourselves??
	{
	  PBXFileReference *fileRef = [[file children] objectAtIndex: 0]; // FIXME: Assume english for now...
	  NSString *filePath = ([fileRef path] == nil)?@"":[fileRef path];
	  result = filePath;
	  *found = YES;
	  break;
	}
      else if([file isKindOfClass: [PBXGroup class]])
	{
	  NSString *filePath = ([file path] == nil)?@"":[file path];
	  result = [filePath stringByAppendingPathComponent: 
				      [self resolvePathFor: object 
						 withGroup: file
						     found: found]];
	}
    }
  return result;
}

- (NSString *) buildPath
{
  PBXGroup *mainGroup = [[GSXCBuildContext sharedBuildContext] objectForKey: @"MAIN_GROUP"];
  BOOL found = NO;
  NSString *result = nil;
  
  // Resolve path for the current file reference...
  result = [self resolvePathFor: self 
		      withGroup: mainGroup
			  found: &found];
  
  return result;
}

@end
