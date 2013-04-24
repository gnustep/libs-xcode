#import <Foundation/NSString.h>

@interface NSString (PBXAdditions)
- (NSString *) firstPathComponent;
- (NSString *) stringByEscapingSpecialCharacters;
- (NSString *) stringByCapitalizingFirstCharacter;
- (NSString *) stringByDeletingFirstPathComponent;
@end
