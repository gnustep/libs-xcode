#import <stdlib.h>
#import "PBXCommon.h"
#import "PBXNativeTarget.h"

@implementation PBXNativeTarget

// Methods....
- (PBXFileReference *) productReference // getter
{
  return productReference;
}

- (void) setProductReference: (PBXFileReference *)object; // setter
{
  ASSIGN(productReference,object);
}

- (NSString *) productInstallPath // getter
{
  return productInstallPath;
}

- (void) setProductInstallPath: (NSString *)object; // setter
{
  ASSIGN(productInstallPath,object);
}

- (NSString *) productType // getter
{
  return productType;
}

- (void) setProductType: (NSString *)object; // setter
{
  ASSIGN(productType,object);
}

- (NSMutableArray *) buildRules // getter
{
  return buildRules;
}

- (void) setBuildRules: (NSMutableArray *)object; // setter
{
  ASSIGN(buildRules,object);
}

- (void) _productWrapper
{
  NSString *buildDir = [NSString stringWithCString: getenv("BUILT_PRODUCTS_DIR")];
  NSString *fullPath = [buildDir stringByAppendingPathComponent: [productReference path]];
  NSError *error = nil;

  [[NSFileManager defaultManager] createDirectoryAtPath:fullPath
			    withIntermediateDirectories:YES
					     attributes:nil
						  error:&error];

  setenv("PRODUCT_OUTPUT_DIR",[fullPath cString],1);
  setenv("PRODUCT_NAME",[name cString],1);
  setenv("EXECUTABLE_NAME",[name cString],1);
}

- (BOOL) build
{
  BOOL result = YES;
  NSEnumerator *en = nil;

  [buildConfigurationList applyDefaultConfiguration];

  id dependency = nil;
  en = [dependencies objectEnumerator];
  while((dependency = [en nextObject]) != nil && result)
    {
      result = [dependency build];
    }

  [self _productWrapper];

  id phase = nil;
  en = [buildPhases objectEnumerator];
  while((phase = [en nextObject]) != nil && result)
    {
      result = [phase build];
    }
  return result;
}

@end
