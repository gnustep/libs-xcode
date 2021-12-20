#import "XCWorkspaceParser.h"
#import "XCWorkspace.h"
#import "XCFileRef.h"

#import <Foundation/NSString.h>
#import <Foundation/NSArray.h>
#import <Foundation/NSXMLParser.h>
#import <Foundation/NSDictionary.h>
#import <Foundation/NSData.h>

@implementation XCWorkspaceParser

- (instancetype) initWithContentsOfFile: (NSString *)file
{
  if ((self = [super init]) != nil)
    {
      NSData *data = [NSData dataWithContentsOfFile: file];
      if (data != nil)
        {
          NSError *error = nil;
          NSXMLParser *parser = [[NSXMLParser alloc] initWithData: data];
          
          [parser setDelegate: self];
          [parser parse];
          
          error = [parser parserError];
          if (error != nil)
            {
              NSLog(@"Error: %@", error);
              return nil;
            }
          
          RELEASE(parser);
        }
      else
        {
          NSLog(@"Unable to read data");
        }
    }

  return self;
}

+ (instancetype) parseWorkspaceFile: (NSString *)file
{
  return AUTORELEASE([[self alloc] initWithContentsOfFile: file]);
}

+ (instancetype) parseWorkspaceDirectory: (NSString *)dir
{
  NSString *datafile = [dir stringByAppendingPathComponent: @"contents.xcworkspacedata"];  
  return [self parseWorkspaceFile: datafile];
}

- (XCWorkspace *) workspace
{
  return _workspace;
}

/** Parser delegate **/

- (void) parserDidStartDocument: (NSXMLParser *)parser
{
  // not needed for this type of file...
}

- (void) parser: (NSXMLParser *)parser
didStartElement: (NSString *)elementName
   namespaceURI: (NSString *)namespaceURI
  qualifiedName: (NSString *)qName
     attributes: (NSDictionary *)attributeDict
{
  if ([elementName isEqualToString: @"Workspace"])
    {
      NSString *v = [attributeDict objectForKey: @"version"];
      _workspace = [XCWorkspace workspace];
      [_workspace setVersion: v];
    }
  else if ([elementName isEqualToString: @"FileRef"])
    {
      XCFileRef *fr = [XCFileRef fileRef];
      NSString *l = [attributeDict objectForKey: @"location"];
      NSArray *a = [_workspace fileRefs];

      [fr setLocation: l];
      a = [a arrayByAddingObject: fr];
      [_workspace setFileRefs: a];
    }
}

-(void) parser: (NSXMLParser *)parser
        foundCharacters: (NSString *)string
{
  // not needed for this type of file...
}

- (void) parser: (NSXMLParser *)parser
  didEndElement: (NSString *)elementName
   namespaceURI: (NSString *)namespaceURI
  qualifiedName: (NSString *)qName
{
}

- (void) parserDidEndDocument: (NSXMLParser *)parser
{
  // not needed for this type of file...
}

@end
