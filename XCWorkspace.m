#import "XCWorkspace.h"
#import "XCFileRef.h"

#import <Foundation/NSString.h>
#import <Foundation/NSArray.h>
#import <Foundation/NSEnumerator.h>

#import <Foundation/NSXMLDocument.h>

@implementation XCWorkspace

+ (XCWorkspace *) workspace
{
  return AUTORELEASE([[self alloc] init]);
}

- (instancetype) init
{
  self = [super init];

  if (self != nil)
    {
      [self setFileRefs: [NSArray array]];
      [self setVersion: nil];
    }

  return self;
}

- (NSString *) version
{
  return _version;
}

- (void) setVersion: (NSString *)v
{
  ASSIGN(_version, v);
}

- (NSArray *) fileRefs
{
  return _fileRefs;
}

- (void) setFileRefs: (NSArray *)refs
{
  ASSIGN(_fileRefs, refs);
}

- (NSString *) filename
{
  return _filename;
}

- (void) setFilename: (NSString *)filename
{
  ASSIGN(_filename, filename);
}

- (BOOL) build
{
  NSEnumerator *en = [_fileRefs reverseObjectEnumerator];
  XCFileRef *ref = nil;

  printf("@@@ Building workspace.. %s\n", [[[self filename] stringByDeletingLastPathComponent] cString]);
  while ((ref = [en nextObject]) != nil)
    {
      BOOL s = [ref build];
      if (s == NO)
        {
          return NO;
        }
    }
  printf("@@@ Workspace build complete\n");
  
  return YES;
}

@end
