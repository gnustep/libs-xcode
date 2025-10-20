#import <Foundation/Foundation.h>

// Local includes
#import "PBXGroup.h"

@class PBXNativeTarget;

@interface PBXFileSystemSynchronizedRootGroup : PBXGroup
{
  PBXNativeTarget *_target;
}

/**
 * Returns the synchronized children for this group by scanning the file system.
 */
- (NSMutableArray *) synchronizedChildren;

/**
 * Refreshes the synchronized children by rescanning the file system.
 */
- (void) refreshChildren;

/**
 * Sets the target for this group.
 */
- (void) setTarget: (PBXNativeTarget *)target;

/**
 * Gets the target for this group.
 */
- (PBXNativeTarget *) target;

/**
 * Builds the files in this synchronized group.
 */
- (BOOL) build;

/**
 * Generates output for the files in this synchronized group.
 */
- (BOOL) generate;

@end
