#import <Foundation/Foundation.h>

@interface PBXCoder : NSObject
{
  NSString *fileName;
  NSString *projectRoot;
  NSMutableDictionary *dictionary;
  NSMutableDictionary *objects;
  NSMutableDictionary *objectCache;
}

- (id) initWithContentsOfFile: (NSString *)name;

- (id) unarchive;

- (id) unarchiveObjectForKey: (NSString *)key;

- (id) unarchiveFromDictionary: (NSDictionary *)dictionary;

- (NSMutableArray *) resolveArrayMembers: (NSMutableArray *)array;

- (id) applyKeysAndValuesFromDictionary: (NSDictionary *)dictionary
                               toObject: (id)object;

@end
