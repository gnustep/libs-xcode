#import <Foundation/Foundation.h>

@interface GSXCBuildContext : NSObject
{
  NSMutableDictionary *contextDictionary;
  NSMutableDictionary *currentContext;
  NSMutableArray *stack;
}

+ (id) sharedBuildContext;
- (NSMutableDictionary *) currentContext;
- (NSMutableDictionary *) contextDictionaryForName: (NSString *)name;
- (NSMutableDictionary *) popCurrentContext;
- (void) setObject: (id)object forKey: (id)key;
- (id) objectForKey: (id)key;
- (void) addEntriesFromDictionary: (NSDictionary *)dict;
@end
