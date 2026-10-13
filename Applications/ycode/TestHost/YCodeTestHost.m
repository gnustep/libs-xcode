/*
   Project: Ycode

   Copyright (C) 2025 Free Software Foundation

   Author: Gregory Casamento

   Created: 2025-01-15

   This application is free software; you can redistribute it and/or
   modify it under the terms of the GNU General Public
   License as published by the Free Software Foundation; either
   version 2 of the License, or (at your option) any later version.

   This application is distributed in the hope that it will be useful,
   but WITHOUT ANY WARRANTY; without even the implied warranty of
   MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
   Library General Public License for more details.

   You should have received a copy of the GNU General Public
   License along with this library; if not, write to the Free
   Software Foundation, Inc., 59 Temple Place, Suite 330, Boston, MA 02111 USA.
*/

#import <Foundation/Foundation.h>
#include <stdlib.h>
#include <stdio.h>
#import <objc/runtime.h>

/* Keep XCTest optional: the test bundle supplies the runner at runtime. */
@interface NSObject (YCodeXCTestRunner)
+ (id)sharedRunner;
- (BOOL)runAll;
+ (NSArray *)testInvocations;
+ (id)testCaseWithInvocation:(NSInvocation *)invocation;
+ (void)setUp;
+ (void)tearDown;
- (void)invokeTest;
- (NSUInteger)failureCount;
- (NSString *)name;
@end

@interface YCodeTestHost : NSObject
- (void)runTests;
- (BOOL)runLegacyTests;
@end

@implementation YCodeTestHost
- (id)init
{
    self = [super init];
    if (self) [self performSelector:@selector(runTests) withObject:nil afterDelay:0];
    return self;
}

/* Older GNUstep XCTest installations put GSXCTestRunner only in the
 * standalone executable. Use their public XCTestCase lifecycle in that case. */
- (BOOL)runLegacyTests
{
    Class base = NSClassFromString(@"XCTestCase");
    if (![base respondsToSelector:@selector(testInvocations)]) {
        NSLog(@"XCTest: Test discovery is unavailable.");
        return NO;
    }
    int capacity, count = 0, index;
    Class *classes = NULL;
    do {
        capacity = objc_getClassList(NULL, 0);
        free(classes);
        classes = calloc(MAX(capacity, 1), sizeof(Class));
        if (!classes) return NO;
        count = objc_getClassList(classes, capacity);
    } while (count > capacity);
    NSMutableArray *names = [NSMutableArray array];
    for (index = 0; index < count; index++) {
        Class parent;
        for (parent = class_getSuperclass(classes[index]); parent; parent = class_getSuperclass(parent))
            if (parent == base) { [names addObject:NSStringFromClass(classes[index])]; break; }
    }
    free(classes);
    NSEnumerator *enumerator = [[names sortedArrayUsingSelector:@selector(compare:)] objectEnumerator];
    NSString *name;
    NSUInteger executed = 0, failures = 0;
    while ((name = [enumerator nextObject]) != nil) {
        Class testClass = NSClassFromString(name);
        NSArray *invocations = [testClass testInvocations];
        if (![invocations count]) continue;
        @try {
            [testClass setUp];
            NSEnumerator *tests = [invocations objectEnumerator];
            NSInvocation *invocation;
            while ((invocation = [tests nextObject]) != nil) {
                NSAutoreleasePool *pool = [NSAutoreleasePool new];
                id test = [testClass testCaseWithInvocation:invocation];
                NSLog(@"Test Case '%@' started.", [test name]);
                [test invokeTest];
                executed++;
                BOOL failed = [test failureCount] > 0;
                if (failed) failures++;
                NSLog(@"Test Case '%@' %@.", [test name], failed ? @"failed" : @"passed");
                [pool drain];
            }
        }
        @catch (NSException *exception) {
            failures++;
            NSLog(@"XCTest: %@ FAILED: %@", name, exception);
        }
        @finally {
            @try { [testClass tearDown]; }
            @catch (NSException *exception) {
                failures++;
                NSLog(@"XCTest: %@ tearDown FAILED: %@", name, exception);
            }
        }
    }
    NSLog(@"XCTest: %lu tests executed, %lu failures", (unsigned long)executed, (unsigned long)failures);
    return executed > 0 && failures == 0;
}

- (void)runTests
{
    NSAutoreleasePool *pool = [NSAutoreleasePool new];
    BOOL success = NO;
    NSString *path = [[NSUserDefaults standardUserDefaults] stringForKey:@"YCodeTestBundle"];
    @try {
        NSBundle *bundle = [NSBundle bundleWithPath:path];
        NSError *error = nil;
        if (!bundle || ![bundle loadAndReturnError:&error]) {
            NSLog(@"XCTest: Could not load hosted test bundle %@: %@", path, error);
        } else {
            Class runner = NSClassFromString(@"GSXCTestRunner");
            if ([runner respondsToSelector:@selector(sharedRunner)])
                success = [[runner sharedRunner] runAll];
            else success = [self runLegacyTests];
        }
    }
    @catch (NSException *exception) {
        NSLog(@"XCTest: Hosted test execution failed: %@", exception);
    }
    [pool drain];
    fflush(NULL);
    exit(success ? 0 : 1);
}
@end
