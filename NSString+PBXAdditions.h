#import <Foundation/NSString.h>

@interface NSString (PBXAdditions)
- (NSString *) stringByEscapingSpecialCharacters;
- (NSString *) stringByCapitalizingFirstCharacter;
@end
