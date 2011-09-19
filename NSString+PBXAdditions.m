#import "NSString+PBXAdditions.h"

@implementation NSString (PBXAdditions)
- (NSString *) stringByEscapingSpecialCharacters
{
  return [self stringByReplacingOccurrencesOfString: @" "
					 withString: @"\\ "];
}

- (NSString *) stringByCapitalizingFirstCharacter
{
  unichar c = [self characterAtIndex: 0];
  NSRange range = NSMakeRange(0,1);
  NSString *oneChar = [[NSString stringWithFormat:@"%C",c] uppercaseString];
  NSString *name = [self stringByReplacingCharactersInRange: range withString: oneChar];
  
  return name;
}
@end
