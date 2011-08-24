#import <Foundation/Foundation.h>

// Local includes
#import "PBXCoder.h"
#import "PBXAbstractBuildPhase.h"

@interface PBXShellScriptBuildPhase : PBXAbstractBuildPhase
{
  NSString *shellPath;
  NSString *shellScript;
  NSMutableArray *inputPaths;
  NSMutableArray *outputPaths;
  NSString *name;
}

// Methods....
- (NSString *) shellPath; // getter
- (void) setShellPath: (NSString *)object; // setter
- (NSString *) shellScript; // getter
- (void) setShellScript: (NSString *)object; // setter
- (NSMutableArray *) inputPaths; // getter
- (void) setInputPaths: (NSMutableArray *)object; // setter
- (NSMutableArray *) outputPaths; // getter
- (void) setOutputPaths: (NSMutableArray *)object; // setter
- (NSString *) name; // getter
- (void) setName: (NSString *)object; // setter

// build...
- (BOOL) build;
@end
