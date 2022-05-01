// Released under the LGPLv2.1, See COPYING.LIB for more information

#import "GSXCVisualStudioGenerator.h"
#import "GSXCVSSolution.h"
#import "GSXCCommon.h"

@implementation GSXCVisualStudioGenerator

- (instancetype) init
{
  self = [super init];
  if (self != nil)
    {
      NSDictionary *dict = [self build];
      _solution = [[GSXCVSSolution alloc] initWithDictionary: dict
                                                   andTarget: nil];
    }
  return self;
}

- (instancetype) initWithTarget: (PBXAbstractTarget *)target
{
  self = [super initWithTarget: target];
  if(self != nil)
    {
      NSDictionary *dict = [self build];
      _solution = [[GSXCVSSolution alloc] initWithDictionary: dict
                                                   andTarget: target];
    }
  return self;
}

- (void) dealloc
{
  RELEASE(_solution);
  [super dealloc];
}

- (NSDictionary *) build
{
  GSXCBuildContext *ctx = [GSXCBuildContext sharedBuildContext];
  return [ctx currentContext];
}

- (BOOL) generate
{
  NSString *solutionString = [_solution string];
  NSString *projectString = [[_solution project] string];
  NSLog(@"solutionString = %@", solutionString);
  NSLog(@"projectString = %@", projectString);
  
  return YES;
}

@end
