/*
   Copyright (C) 2018, 2019, 2020, 2021 Free Software Foundation, Inc.

   Written by: Gregory John Casamento <greg.casamento@gmail.com>
   Date: 2022
   
   This file is part of the GNUstep XCode Library

   This library is free software; you can redistribute it and/or
   modify it under the terms of the GNU Lesser General Public
   License as published by the Free Software Foundation; either
   version 2 of the License, or (at your option) any later version.
   
   This library is distributed in the hope that it will be useful,
   but WITHOUT ANY WARRANTY; without even the implied warranty of
   MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
   Lesser General Public License for more details.
   
   You should have received a copy of the GNU Lesser General Public
   License along with this library; if not, write to the Free
   Software Foundation, Inc., 51 Franklin Street, Fifth Floor,
   Boston, MA 02110 USA.
*/

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
  ASSIGN(_filename, file);
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
  [_workspace setFilename: _filename];
  return _workspace;
}

- (void) dealloc
{
  RELEASE(_filename);
  RELEASE(_workspace);
  [super dealloc];
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
      ASSIGN(_workspace, [XCWorkspace workspace]);
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
