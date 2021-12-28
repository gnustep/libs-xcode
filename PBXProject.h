#import <Foundation/Foundation.h>

// Local includes
#import "PBXCoder.h"
#import "XCConfigurationList.h"
#import "PBXGroup.h"
#import "PBXGroup.h"

@class PBXContainer;

@interface PBXProject : NSObject
{
  NSString *developmentRegion;
  NSMutableArray *knownRegions;
  NSString *compatibilityVersion;
  NSMutableArray *projectReferences;
  NSMutableArray *_targets;
  NSString *projectDirPath;
  NSString *projectRoot;
  XCConfigurationList *buildConfigurationList;
  PBXGroup *mainGroup;
  NSString *hasScannedForEncodings;
  PBXGroup *productRefGroup;
  PBXContainer *container;
  NSDictionary *attributes;
  NSDictionary *ctx;

  NSString *_filename;
  NSMutableArray *_arrangedTargets;
}

// Methods....
- (NSString *) developmentRegion; // getter
- (void) setDevelopmentRegion: (NSString *)object; // setter
- (NSMutableArray *) knownRegions; // getter
- (void) setKnownRegions: (NSMutableArray *)object; // setter
- (NSString *) compatibilityVersion; // getter
- (void) setCompatibilityVersion: (NSString *)object; // setter
- (NSMutableArray *) projectReferences; // getter
- (void) setProjectReferences: (NSMutableArray *)object; // setter
- (NSMutableArray *) targets; // getter
- (void) setTargets: (NSMutableArray *)object; // setter
- (NSString *) projectDirPath; // getter
- (void) setProjectDirPath: (NSString *)object; // setter
- (NSString *) projectRoot; // getter
- (void) setProjectRoot: (NSString *)object; // setter
- (XCConfigurationList *) buildConfigurationList; // getter
- (void) setBuildConfigurationList: (XCConfigurationList *)object; // setter
- (PBXGroup *) mainGroup; // getter
- (void) setMainGroup: (PBXGroup *)object; // setter
- (NSString *) hasScannedForEncodings; // getter
- (void) setHasScannedForEncodings: (NSString *)object; // setter
- (PBXGroup *) productRefGroup; // getter
- (void) setProductRefGroup: (PBXGroup *)object; // setter
- (PBXContainer *) container;
- (void) setContainer: (PBXContainer *)container;
- (void) setContext: (NSDictionary *)ctx;
- (void) setFilename: (NSString *)fn;
- (NSString *) filename;

// calculate dependencies
- (void) plan;

// build
- (BOOL) build;
- (BOOL) clean;
- (BOOL) install;
- (BOOL) generate;
@end
