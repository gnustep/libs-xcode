#import <XCTest/XCTest.h>
#import "Calc.h"

@interface CalcTests : XCTestCase
@end

@implementation CalcTests

- (void) testAdds
{
  XCTAssertEqual([Calc add: 2 to: 3], (NSInteger)5);
}

- (void) testAddsNegatives
{
  XCTAssertEqual([Calc add: -2 to: -3], (NSInteger)-5);
}

- (void) testKnownBroken
{
  if (getenv("CALC_TESTS_FAIL"))
    {
      XCTAssertEqual([Calc add: 2 to: 2], (NSInteger)5, @"deliberately wrong");
    }
}

@end
