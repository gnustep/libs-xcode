/*
   Project: pcpg

   Copyright (C) 2011 Free Software Foundation

   Author: Gregory John Casamento

   Created: 2011-08-16 14:15:42 -0400 by heron

   This application is free software; you can redistribute it and/or
   modify it under the terms of the GNU General Public
   License as published by the Free Software Foundation; either
   version 2 of the License, or (at your option) any later version.

   This application is distributed in the hope that it will be useful,
   but WITHOUT ANY WARRANTY; without even the implied warranty of
   MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
   Library General Public License for more details.

   You should have received a copy of the GNU General Public
   License along with this library; if not, write to the Free
   Software Foundation, Inc., 59 Temple Place, Suite 330, Boston, MA 02111 USA.
*/

#import "PLCPG.h"

@interface NSString (PLCPG)
- (NSString *) stringByUpperCasingFirstCharacter;
@end

@implementation NSString (PLCPG)
- (NSString *) stringByUpperCasingFirstCharacter
{
  unichar c = [self characterAtIndex: 0];
  NSString *oneChar = [[NSString stringWithFormat: @"%C",c] uppercaseString];
  NSString *newString = [self stringByReplacingCharactersInRange: NSMakeRange(0,1) withString: oneChar];
  return newString;
}
@end

@implementation PLCPG

- (id) initWithPlist: (NSString *)plistName
{
  if((self = [super init]) != nil)
  {
    plist = [[NSDictionary alloc] initWithContentsOfFile: plistName];
    dictionary = [plist objectForKey: @"objects"];
    classes = [[NSMutableDictionary alloc] initWithCapacity: 10];
    classNameMap = [[NSMutableDictionary alloc] initWithObjectsAndKeys: 
						  @"NSString", @"NSConstantString", 
						@"NSString", @"GSMutableString",
						@"NSMutableArray", @"GSMutableArray",
						@"NSMutableDictionary", @"GSMutableDictionary",
					 nil];
  }
  return self;
}

/*
- (void) dealloc
{
  [plist release];
  [dictionary release];
  [classes release];
  [classNameMap release];
  [super dealloc];
}
*/

- (NSString *) remapClassName: (NSString *)className
{
  NSString *newClassName = [classNameMap objectForKey: className];
  return (newClassName == nil) ? className : newClassName;
}

- (void) collectClassDetails
{
  NSEnumerator *en = [dictionary keyEnumerator];
  NSString *key = nil;
  while((key = [en nextObject]) != nil)
  {
    id obj = [dictionary objectForKey: key];
    if([obj isKindOfClass: [NSDictionary class]])
      {
	NSString *className = [obj objectForKey: @"isa"];
	if(className == nil)
	  {
	    continue;
	  }

	NSMutableDictionary *classInfo = [classes objectForKey: className];
	if(classInfo == nil)
	  {
	    NSEnumerator *cen = [obj keyEnumerator];
	    id ckey = nil;

	    classInfo = [NSMutableDictionary dictionaryWithCapacity:10];
	    [classes setObject: classInfo forKey: className];
	    while((ckey = [cen nextObject]) != nil)
	      {
		if([ckey isEqualToString: @"isa"] == NO)
		  {
		    id cobj = [obj objectForKey: ckey];
		    if([cobj isKindOfClass: [NSString class]])
		      {
			id ref = [dictionary objectForKey: cobj]; 

			// if cobj is a string, it might be a key.. so check.
			if([ref isKindOfClass: [NSDictionary class]])
			  {
			    NSString *refClassName = [ref objectForKey: @"isa"];
			    [classInfo setObject: refClassName forKey: ckey];
			  }
			else
			  {			    
			    NSString *className = NSStringFromClass([cobj class]);
			    className = [self remapClassName: className];
			    [classInfo setObject: className forKey: ckey];
			  }
		      }
		    else
		      {
			NSString *className = NSStringFromClass([cobj class]);
			className = [self remapClassName: className];
			[classInfo setObject: className forKey: ckey];
		      }
		  }
	      }
	  }
      }
  }
}

- (void) createHeaderForClassNamed: (NSString *)className
{
  NSString *classFileFormat =
    @"#import <Foundation/Foundation.h>\n\n"
    @"// Local includes\n"
    @"#import \"PBXCoder.h\"\n"
    @"%@\n\n@interface %@ : NSObject\n"
    @"{\n%@}\n\n// Methods....\n%@\n"
    @"@end";
  NSDictionary *classInfo = [classes objectForKey: className];
  NSEnumerator *en = [classInfo keyEnumerator];
  NSString *ivarString = @"";
  NSString *includeString = @"";
  NSString *methodString = @"";

  NSString *ivarName = nil;
  while((ivarName = [en nextObject]) != nil)
    {
      NSString *type = [classInfo objectForKey: ivarName];

      // Map certain types...
      if ([type isEqualToString: @"GSCInlineString"])
	{
	  type = @"NSString";
	}
      
      ivarString = [ivarString stringByAppendingString: [NSString stringWithFormat: @"\t%@ *_%@;\n",type, ivarName]];
      if(![type isEqualToString: @"NSString"] &&
	 ![type isEqualToString: @"NSMutableArray"] &&
	 ![type isEqualToString: @"NSArray"] &&
	 ![type isEqualToString: @"NSDictionary"] &&
	 ![type isEqualToString: @"NSMutableDictionary"])
	{
	  includeString = [includeString stringByAppendingString: [NSString stringWithFormat: @"#import \"%@.h\"\n", type]];
	}

      methodString = [methodString stringByAppendingString: [NSString stringWithFormat: @"- (%@ *) %@; // getter\n",type,ivarName]];
      NSString *name = [ivarName stringByUpperCasingFirstCharacter];
      methodString = [methodString stringByAppendingString: [NSString stringWithFormat: @"- (void) set%@: (%@ *)object; // setter\n",name,type]];
    }
    
  NSString *classFileName = [className stringByAppendingString: @".h"];
  NSString *classFile = [NSString stringWithFormat: classFileFormat, includeString, className, ivarString, methodString];
  NSError *error = nil;
  [classFile writeToFile: classFileName 
	      atomically: NO 
		encoding: NSASCIIStringEncoding 
		   error: &error];
}

- (void) createSourceForClassNamed: (NSString *)className
{
  NSString *classFileFormat = @"#import \"PBXCommon.h\"\n#import \"%@.h\"\n\n@implementation %@\n\n// Methods....\n%@\n@end";
  NSString *methodString = @"";
  NSDictionary *classInfo = [classes objectForKey: className];
  NSEnumerator *en = [classInfo keyEnumerator];

  NSString *ivarName = nil;
  while((ivarName = [en nextObject]) != nil)
    {
      NSString *type = [classInfo objectForKey: ivarName];

      // Map certain types...
      if ([type isEqualToString: @"GSCInlineString"])
	{
	  type = @"NSString";
	}
      
      methodString = [methodString stringByAppendingString: [NSString stringWithFormat: @"- (%@ *) %@ // getter\n{\n\treturn _%@;\n}\n\n",
								      type,ivarName,ivarName]];
      NSString *name = [ivarName stringByUpperCasingFirstCharacter];
      methodString = [methodString stringByAppendingString: [NSString stringWithFormat: 
								      @"- (void) set%@: (%@ *)object; // setter\n{\n\tASSIGN(_%@, object);\n}\n\n",
								      name,type,ivarName]];
    }
  
  NSString *classFileName = [className stringByAppendingString: @".m"];
  NSString *classFile = [NSString stringWithFormat: classFileFormat, className, className, methodString];
  NSError *error = nil;
  
  [classFile writeToFile: classFileName atomically: NO encoding: NSASCIIStringEncoding error: &error];
}

- (void) createHeaderAndSourceFileForClassNamed: (NSString *)className
{
  [self createHeaderForClassNamed: className];
  [self createSourceForClassNamed: className];
}

- (void) generateClassCode
{
  NSLog(@"%@",classes);
  NSEnumerator *en = [classes keyEnumerator];
  id cls = nil;

  while((cls = [en nextObject]) != nil)
    {
      [self createHeaderAndSourceFileForClassNamed: cls];
    }
}

- (void) generate
{
  [self collectClassDetails];
  [self generateClassCode];
}

@end
