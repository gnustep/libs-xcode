#import "GSXCVisualStudioGenerator.h"
#import "GSXCVSSolution.h"

@implementation GSXCVisualStudioGenerator

- (BOOL) generate
{
  GSXCVSSolution *sln = [[GSXCVSSolution alloc] init]; 
  NSString *solutionString = [sln string];

  NSLog(@"solutionString = %@", solutionString);
  
  return YES;
}

@end
