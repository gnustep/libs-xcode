#import <Foundation/Foundation.h>

// Local includes
#import "PBXCoder.h"
#import "PBXAbstractBuildPhase.h"

@interface PBXCopyFilesBuildPhase : PBXAbstractBuildPhase
{
  NSString *dstPath;
  NSString *dstSubfolderSpec;
}

// Methods....
- (NSString *) dstPath; // getter
- (void) setDstPath: (NSString *)object; // setter
- (NSString *) dstSubfolderSpec; // getter
- (void) setDstSubfolderSpec: (NSString *)object; // setter

@end
