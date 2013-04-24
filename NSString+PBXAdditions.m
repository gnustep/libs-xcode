#import <Foundation/NSArray.h>
#import "NSString+PBXAdditions.h"

@implementation NSString (PBXAdditions)
- (NSString *) firstPathComponent
{
  NSString *result = nil;
  if ([[self pathComponents] count] >= 2)
    {
      result = [[self pathComponents] objectAtIndex:1];
    }
  return result;
}

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

- (NSString *) stringByDeletingFirstPathComponent
{
  NSString *firstPathComponent = [self firstPathComponent];
  NSString *result = nil;
  if (nil != firstPathComponent)
    {
      NSMutableArray *pathComponents = [NSMutableArray arrayWithArray:[self pathComponents]];
      
      if ([[pathComponents objectAtIndex:0] isEqualToString:@"/"])
	{
	  [pathComponents removeObjectAtIndex:0];
	}

      [pathComponents removeObject:firstPathComponent];      
      result = [@"/" stringByAppendingPathComponent:
		   [pathComponents componentsJoinedByString:@"/"]];
    }
  return result;
}
@end
