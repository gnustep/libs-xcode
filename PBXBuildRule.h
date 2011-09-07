#import <Foundation/Foundation.h>

// Local includes
#import "PBXCoder.h"


@interface PBXBuildRule : NSObject
{
  NSString *fileType;
  NSString *isEditable;
  NSMutableArray *outputFiles;
  NSString *compilerSpec;
}

// Methods....
- (NSString *) fileType; // getter
- (void) setFileType: (NSString *)object; // setter
- (NSString *) isEditable; // getter
- (void) setIsEditable: (NSString *)object; // setter
- (NSMutableArray *) outputFiles; // getter
- (void) setOutputFiles: (NSMutableArray *)object; // setter
- (NSString *) compilerSpec; // getter
- (void) setCompilerSpec: (NSString *)object; // setter

@end