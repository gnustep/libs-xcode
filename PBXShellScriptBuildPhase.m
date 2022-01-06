#import <Foundation/NSDictionary.h>

#import "PBXCommon.h"
#import "PBXShellScriptBuildPhase.h"
#import "NSString+PBXAdditions.h"

@implementation PBXShellScriptBuildPhase

// Methods....
- (NSString *) shellPath // getter
{
  return shellPath;
}

- (void) setShellPath: (NSString *)object; // setter
{
  ASSIGN(shellPath,object);
}

- (NSString *) shellScript // getter
{
  return shellScript;
}

- (void) setShellScript: (NSString *)object; // setter
{
  ASSIGN(shellScript,object);
}

- (NSMutableArray *) inputPaths // getter
{
  return inputPaths;
}

- (void) setInputPaths: (NSMutableArray *)object; // setter
{
  ASSIGN(inputPaths,object);
}

- (NSMutableArray *) outputPaths // getter
{
  return outputPaths;
}

- (void) setOutputPaths: (NSMutableArray *)object; // setter
{
  ASSIGN(outputPaths,object);
}

- (NSString *) name // getter
{
  return name;
}

- (void) setName: (NSString *)object; // setter
{
  ASSIGN(name,object);
}

- (NSString *) preprocessScript
{
  NSDictionary *plistFile = [NSDictionary dictionaryWithContentsOfFile: @"buildtool.plist"];
  NSDictionary *searchReplace = [plistFile objectForKey: @"searchReplace"];
  NSEnumerator *en = [searchReplace keyEnumerator];
  NSString *key = nil;
  NSString *result = nil;
  
  ASSIGNCOPY(result, shellScript);
  
  while ((key = [en nextObject]) != nil)
    {
      NSString *v = [searchReplace objectForKey: key];
      NSError *error = NULL;
      BOOL done = NO;
      NSRegularExpression *regex = [NSRegularExpression
                                     regularExpressionWithPattern: key
                                                          options: 0
                                                            error: &error];

      // Iterate through all of the matches, but after each change start over because the ranges
      // will shift as a result of the substitution.  When there are no matches left, exit.
      while (done == NO)
        {
          NSTextCheckingResult *match = [regex firstMatchInString: result
                                                          options: 0
                                                            range: NSMakeRange(0, [key length])];
          if (match != nil)
            {
              NSRange matchRange = [match range];
              result = [result stringByReplacingCharactersInRange: matchRange
                                                       withString: v];
            }
          else
            {
              done = YES;
            }
        }
    }

  return result;
}

- (BOOL) build
{
  NSError *error = nil;
  NSString *fileName = [NSString stringWithFormat: @"script_%lu",[shellScript hash]];
  NSString *tmpFilename = [NSString stringWithFormat: @"/tmp/%@", fileName];
  NSString *command = [NSString stringWithFormat: @"%@ %@",shellPath,tmpFilename];
  BOOL result = NO;
  NSString *processedScript = [self preprocessScript];

  processedScript = [processedScript stringByReplacingEnvironmentVariablesWithValues];
  puts([[NSString stringWithFormat: @"=== Executing Script Build Phase... %s%@%s",
                  CYAN, name, RESET] cString]);
  puts([[NSString stringWithFormat: @"=== \t%s%@%s", RED, command, RESET] cString]);
    
  [processedScript writeToFile: tmpFilename
                    atomically: YES
                      encoding: NSASCIIStringEncoding
                         error: &error];
  
  result = system([command cString]);
  puts([[NSString stringWithFormat: @"=== Done Executing Script Build Phase... %s%@%s",
                  CYAN, name, RESET] cString]);

  return result;
}
@end
