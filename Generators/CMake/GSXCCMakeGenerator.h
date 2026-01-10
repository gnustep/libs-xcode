#import "GSXCGenerator.h"

@interface GSXCCMakeGenerator : GSXCGenerator
{
  NSString *_projectType;
  NSString *_projectName;
  NSString *_bundleExtension;
  BOOL _append;
}
@end
