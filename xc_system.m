#import "xc_system.h"
#import <GNUstepBase/NSTask+GNUstepBase.h>

NSInteger xc_system(NSString *compiler,
                    NSString *errorOutPath,
                    NSString *compilePath,
                    NSString *objCflags,
                    NSString *configString,
                    NSString *headerSearchPaths,
                    NSString *outputPath)
{
  NSTask *task = [[NSTask alloc] init];
  NSMutableArray *args = [[NSMutableArray alloc] init];
  [task setLaunchPath: compiler];
  
  NSLog(@"Called xc_system(...)");
  
  return 0;
}
