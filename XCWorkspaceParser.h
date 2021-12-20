#import <Foundation/NSObject.h>
#import <Foundation/NSXMLParser.h>

@class NSString;
@class XCWorkspace;

@interface XCWorkspaceParser : NSObject <NSXMLParserDelegate>
{
  XCWorkspace *_workspace;
}

+ (instancetype) parseWorkspaceFile: (NSString *)file;
+ (instancetype) parseWorkspaceDirectory: (NSString *)dir;
- (instancetype) initWithContentsOfFile: (NSString *)file;

- (XCWorkspace *) workspace;

@end
