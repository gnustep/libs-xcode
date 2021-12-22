#import <Foundation/NSArray.h>
#import <Foundation/NSCharacterSet.h>
#import <Foundation/NSDebug.h>
#import <Foundation/NSDictionary.h>

#import "NSString+PBXAdditions.h"
#import <unistd.h>

extern char **environ;

@implementation NSString (PBXAdditions)

- (NSString *) firstPathComponent
{
  NSArray *components = [self pathComponents];
  return ([components count] > 0)?[components objectAtIndex: 0]:@"";
}

- (NSString *) stringByEscapingSpecialCharacters
{
  NSString *result = nil;

  result = [self stringByReplacingOccurrencesOfString: @" "
						     withString: @"_"];
  result = [self stringByReplacingOccurrencesOfString: @"("
                                           withString: @"\\)"];
  result = [self stringByReplacingOccurrencesOfString: @")"
                                           withString: @"\\)"];
  result = [self stringByReplacingOccurrencesOfString: @"["
                                           withString: @"\\["];
  result = [self stringByReplacingOccurrencesOfString: @"]"
                                           withString: @"\\]"];
  result = [self stringByReplacingOccurrencesOfString: @"{"
                                           withString: @"\\{"];
  result = [self stringByReplacingOccurrencesOfString: @"}"
                                           withString: @"\\}"];

  return result;
}

- (NSString *) stringByEliminatingSpecialCharacters
{
  NSString *cs = @"()[]/\\| ";
  NSString *result = @"";
  NSUInteger l = [self length];
  NSUInteger i = 0;

  for (i = 0; i < l; i++)
    {
      NSString *c = [NSString stringWithFormat: @"%c",[self characterAtIndex: i]];
      if ([cs containsString: c])
        {
          continue;
        }
      result = [result stringByAppendingString: c];
    }

  return result;
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
  NSArray *components = [self pathComponents];
  NSString *firstComponent = [self firstPathComponent];
  NSString *result = @"";
  NSEnumerator *en = [components objectEnumerator];
  NSString *c = nil;

  while ((c = [en nextObject]) != nil)
    {
      if ([c isEqualToString: firstComponent])
        continue;
      
      result = [result stringByAppendingPathComponent: c];
    }
  
  return result;
}

- (NSString *) stringByReplacingEnvironmentVariablesWithValues
{
  NSString *result = nil;
  NSMutableDictionary *dict = [NSMutableDictionary dictionary];

  result = [NSString stringWithString: self]; // autoreleased copy
  
  // Get env vars...
  char **env = NULL;
  for (env = environ; *env != 0; env++)
    {
      char *thisEnv = *env;
      NSString *envStr = [NSString stringWithCString: thisEnv encoding: NSUTF8StringEncoding];
      NSArray *components = [envStr componentsSeparatedByString: @"="];
      [dict setObject: [components lastObject]
               forKey: [components firstObject]];
    }

  // Replace all variables in the plist with the values...
  NSArray *keys = [dict allKeys];
  NSEnumerator *en = [keys objectEnumerator];
  NSString *k = nil;
  while ((k = [en nextObject]) != nil)
    {
      NSString *v = [dict objectForKey: k];
      result = [result stringByReplacingOccurrencesOfString: [NSString stringWithFormat: @"$(%@)",k]
                                                 withString: v];
    }

  return result;
}

- (NSString *) stringByAddingQuotationMarks
{
  return [NSString stringWithFormat: @"\"%@\"", self];
}

@end
