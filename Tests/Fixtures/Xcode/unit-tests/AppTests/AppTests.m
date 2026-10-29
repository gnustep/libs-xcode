#import <AppKit/AppKit.h>
#import <XCTest/XCTest.h>

@interface AppTests : XCTestCase
@end

@implementation AppTests

- (void) testRunsInsideTheApp
{
  XCTAssertNotNil(NSApp);
  XCTAssertEqualObjects(NSStringFromClass([[NSApp delegate] class]), @"AppDelegate");
  XCTAssertEqualObjects([(NSObject *)[NSApp delegate] valueForKey: @"launched"], [NSNumber numberWithBool: YES]);
}

@end
