// Released under the terms of LGPL2.1, please see COPYING.LIB

#import "GSXCGenerator.h"

@class GSXCVSSolution;
@class NSDictionary;

@interface GSXCVisualStudioGenerator : GSXCGenerator
{
  GSXCVSSolution *_solution;
}

- (NSDictionary *) build;

@end
