#import "PBXCommon.h"
#import "PBXBuildRule.h"

@implementation PBXBuildRule

// Methods....
- (NSString *) fileType // getter
{
  return fileType;
}

- (void) setFileType: (NSString *)object; // setter
{
  ASSIGN(fileType,object);
}

- (NSString *) isEditable // getter
{
  return isEditable;
}

- (void) setIsEditable: (NSString *)object; // setter
{
  ASSIGN(isEditable,object);
}

- (NSMutableArray *) outputFiles // getter
{
  return outputFiles;
}

- (void) setOutputFiles: (NSMutableArray *)object; // setter
{
  ASSIGN(outputFiles,object);
}

- (NSString *) compilerSpec // getter
{
  return compilerSpec;
}

- (void) setCompilerSpec: (NSString *)object; // setter
{
  ASSIGN(compilerSpec,object);
}


@end