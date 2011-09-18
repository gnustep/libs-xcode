#import "PBXCommon.h"
#import "PBXProject.h"
#import "PBXNativeTarget.h"
#import "GSXCBuildContext.h"

@implementation PBXProject

// Methods....
- (NSString *) developmentRegion // getter
{
  return developmentRegion;
}

- (void) setDevelopmentRegion: (NSString *)object; // setter
{
  ASSIGN(developmentRegion,object);
}

- (NSMutableArray *) knownRegions // getter
{
  return knownRegions;
}

- (void) setKnownRegions: (NSMutableArray *)object; // setter
{
  ASSIGN(knownRegions,object);
}

- (NSString *) compatibilityVersion // getter
{
  return compatibilityVersion;
}

- (void) setCompatibilityVersion: (NSString *)object; // setter
{
  ASSIGN(compatibilityVersion,object);
}

- (NSMutableArray *) projectReferences // getter
{
  return projectReferences;
}

- (void) setProjectReferences: (NSMutableArray *)object; // setter
{
  ASSIGN(projectReferences,object);
}

- (NSMutableArray *) targets // getter
{
  return targets;
}

- (void) setTargets: (NSMutableArray *)object; // setter
{
  ASSIGN(targets,object);
}

- (NSString *) projectDirPath // getter
{
  return projectDirPath;
}

- (void) setProjectDirPath: (NSString *)object; // setter
{
  ASSIGN(projectDirPath,object);
}

- (NSString *) projectRoot // getter
{
  return projectRoot;
}

- (void) setProjectRoot: (NSString *)object; // setter
{
  ASSIGN(projectRoot,object);
}

- (XCConfigurationList *) buildConfigurationList // getter
{
  return buildConfigurationList;
}

- (void) setBuildConfigurationList: (XCConfigurationList *)object; // setter
{
  ASSIGN(buildConfigurationList,object);
}

- (PBXGroup *) mainGroup // getter
{
  return mainGroup;
}

- (void) setMainGroup: (PBXGroup *)object; // setter
{
  ASSIGN(mainGroup,object);
}

- (NSString *) hasScannedForEncodings // getter
{
  return hasScannedForEncodings;
}

- (void) setHasScannedForEncodings: (NSString *)object; // setter
{
  ASSIGN(hasScannedForEncodings,object);
}

- (PBXGroup *) productRefGroup // getter
{
  return productRefGroup;
}

- (void) setProductRefGroup: (PBXGroup *)object; // setter
{
  ASSIGN(productRefGroup,object);
}

- (void) _sourceRootFromMainGroup
{
  PBXGroup *sourceGroup = [[mainGroup children] objectAtIndex: 0]; // get first group, which is the source group.
  NSString *sourceRoot = [sourceGroup path];
  
  if(sourceRoot == nil)
    {
      sourceRoot = @"";
    }

  setenv("SOURCE_ROOT",[sourceRoot cString],1);
  NSLog(@"\tSOURCE_ROOT = %@",sourceRoot);
}

- (BOOL) build
{
  NSLog(@"=== Building Project");
  [buildConfigurationList applyDefaultConfiguration];

  [self _sourceRootFromMainGroup];

  GSXCBuildContext *context = [GSXCBuildContext sharedBuildContext];
  NSEnumerator *en = [targets objectEnumerator];
  id target = nil;
  BOOL result = YES;
  while((target = [en nextObject]) != nil && result)
    {
      [context contextDictionaryForName: [target name]];
      [context setObject: mainGroup 
		  forKey: @"MAIN_GROUP"]; 
      result = [target build];
      [context popCurrentContext];
    }
  NSLog(@"=== Completed Building Project");
  return result;
}

- (BOOL) clean
{
  NSLog(@"=== Cleaning Project");
  [buildConfigurationList applyDefaultConfiguration];

  GSXCBuildContext *context = [GSXCBuildContext sharedBuildContext];
  NSEnumerator *en = [targets objectEnumerator];
  id target = nil;
  BOOL result = YES;
  while((target = [en nextObject]) != nil && result)
    {
      [context contextDictionaryForName: [target name]];
      [context setObject: mainGroup 
		  forKey: @"MAIN_GROUP"]; 
      result = [target clean];
      [context popCurrentContext];
    }
  NSLog(@"=== Completed Cleaning Project");
  return result;  
}

- (BOOL) install
{
  NSLog(@"=== Installing Project");
  [buildConfigurationList applyDefaultConfiguration];

  GSXCBuildContext *context = [GSXCBuildContext sharedBuildContext];
  NSEnumerator *en = [targets objectEnumerator];
  id target = nil;
  BOOL result = YES;
  while((target = [en nextObject]) != nil && result)
    {
      [context contextDictionaryForName: [target name]];
      [context setObject: mainGroup 
		  forKey: @"MAIN_GROUP"]; 
      result = [target install];
      [context popCurrentContext];
    }
  NSLog(@"=== Completed Installing Project");
  return result;  
}
@end
