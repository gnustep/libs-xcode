#import "GSXCVisualStudioGenerator.h"
#import "GSXCVSSolution.h"

@implementation GSXCVisualStudioGenerator

- (BOOL) generate
{
  GSXCVSSolution *sln = [[GSXCVSSolution alloc] init]; 
  NSString *solutionString = [sln string];
  NSString *projectString = [[sln project] string];
  NSLog(@"solutionString = %@", solutionString);
  NSLog(@"projectString = %@", projectString);
  
  return YES;
}

@end
