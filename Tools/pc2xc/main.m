/*
   Project: pc2xc

   Author: Gregory John Casamento,,,

   Created: 2023-10-16 23:37:42 -0400 by heron
*/

#import <Foundation/Foundation.h>

#import <XCode/XCode.h>
#import <XCode/xcsystem.h>

NSMutableArray *buildFileReferences(NSArray *allFiles,
				    NSString *ext)
{
  NSMutableArray *result = [NSMutableArray array];
  NSEnumerator *en = [allFiles objectEnumerator];
  NSString *filename = nil;

  while ((filename = [en nextObject]) != nil)
    {
      if (ext != nil)
	{
	  filename = [filename stringByAppendingPathExtension: ext];
	}
      
      PBXFileReference *fileRef = AUTORELEASE([[PBXFileReference alloc] initWithPath: filename]);
      [result addObject: fileRef];      
    }

  return result;
}

NSString *typeForProjectType(NSString *projectType)
{
  NSString *result = @"";

  if ([projectType isEqualToString: @"Application"])
    {
      result = @"com.apple.product-type.application";
    }
  else if ([projectType isEqualToString: @"Tool"])
    {
      result = @"com.apple.product-type.tool";
    }
  else if ([projectType isEqualToString: @"Library"])
    {
      result = @"com.apple.product-type.library";
    }
  else if ([projectType isEqualToString: @"Framework"])
    {
      result = @"com.apple.product-type.framework";
    }

  return result;
}

PBXGroup *productReferenceGroup(NSString *projectName,
				NSString *projectType)
{
  PBXGroup *group = AUTORELEASE([[PBXGroup alloc] init]);
  NSString *type = typeForProjectType(projectType);
  NSString *ext = [PBXFileReference extForFileType: type];
  NSString *path = (ext == nil || [ext isEqualToString: @""]) ? projectName :
    [projectName stringByAppendingPathExtension: ext];
  PBXFileReference *productFileRef = AUTORELEASE([[PBXFileReference alloc] initWithPath: path]);
  NSMutableArray *children = [NSMutableArray arrayWithObject: productFileRef];
  
  [group setChildren: children];
  [group setName: @"Products"];
  
  return group;
}

PBXGroup *mainGroupBuild(NSArray *files, PBXGroup *productReferenceGroup)
{
  PBXGroup *mainGroup = AUTORELEASE([[PBXGroup alloc] init]);
  NSMutableArray *buildGroupFiles = buildFileReferences(files, nil);
  PBXGroup *buildFileGroup = AUTORELEASE([[PBXGroup alloc] init]);
  [buildFileGroup setChildren: buildGroupFiles];
  
  NSMutableArray *mainGroupChildren = [NSMutableArray arrayWithObjects: buildFileGroup,
						      productReferenceGroup, nil];
  [mainGroup setChildren: mainGroupChildren];

  return mainGroup;
}

void buildPhase(NSArray *items, PBXBuildPhase *phase)
{
  NSMutableArray *sources = [NSMutableArray arrayWithCapacity: [items count]]; 
  NSEnumerator *en = [items objectEnumerator];
  NSString *item = nil;
  
  while ((item = [en nextObject]) != nil)
    {
      PBXFileReference *fileRef = AUTORELEASE([[PBXFileReference alloc] initWithPath: item]);
      PBXBuildFile *buildFile = AUTORELEASE([[PBXBuildFile alloc] init]);
      [buildFile setFileRef: fileRef];
      [sources addObject: buildFile];
    }

  [phase setFiles: sources];
}

NSMutableArray *buildTargets(NSString *projectName,
			     NSString *projectType,
			     NSArray *files,
			     NSArray *headers,
			     NSArray *resources,
			     NSArray *frameworks,
			     PBXGroup *prodRefGroup)
{
  NSMutableArray *result = [NSMutableArray array];
  PBXNativeTarget *target = AUTORELEASE([[PBXNativeTarget alloc] init]);

  PBXSourcesBuildPhase *sourcePhase = AUTORELEASE([[PBXSourcesBuildPhase alloc] init]);
  buildPhase(files, sourcePhase);

  PBXResourcesBuildPhase *resourcePhase = AUTORELEASE([[PBXResourcesBuildPhase alloc] init]);
  buildPhase(resources, resourcePhase);

  // PBXFrameworksBuildPhase *frameworksPhase = AUTORELEASE([[PBXFrameworksBuildPhase alloc] init]);
  // buildPhase(frameworks, frameworksPhase);  

  PBXFileReference *productRef = [[prodRefGroup children] objectAtIndex: 0];
  NSMutableArray *phases = [NSMutableArray arrayWithObjects: sourcePhase, resourcePhase, nil]; // frameworksPhase, nil];

  [target setBuildPhases: phases];
  [target setName: projectName];
  [target setProductName: [productRef path]];
  [target setProductType: projectType];
  
  [result addObject: target];
  
  return result;
}


PBXContainer *buildContainer(NSString *projectName,
			     NSString *projectType,
			     NSArray *files,
			     NSArray *headers,
			     NSArray *resources,
			     NSArray *other,
			     NSArray *frameworks)
{
  NSMutableArray *allFiles = [NSMutableArray arrayWithArray: files];
  PBXProject *project = AUTORELEASE([[PBXProject alloc] init]);
  PBXContainer *container = AUTORELEASE([[PBXContainer alloc] initWithRootObject: project]);
  XCBuildConfiguration *buildConfigDebug = AUTORELEASE([[XCBuildConfiguration alloc] init]);
  XCBuildConfiguration *buildConfigRelease = AUTORELEASE([[XCBuildConfiguration alloc] initWithName: @"Release"]);
  NSMutableArray *configArray = [NSMutableArray arrayWithObjects: buildConfigDebug, buildConfigRelease, nil];
  XCConfigurationList *configList = AUTORELEASE([[XCConfigurationList alloc] initWithConfigurations: configArray]);
  NSString *type = typeForProjectType(projectType);
  
  // Add all files to the main group...
  [allFiles addObjectsFromArray: other];
  [allFiles addObjectsFromArray: resources];

  // Set up groups...
  PBXGroup *productRefGroup = productReferenceGroup(projectName, projectType); // AUTORELEASE([[PBXGroup alloc] init]);
  PBXGroup *mainGroup = mainGroupBuild(allFiles, productRefGroup); // AUTORELEASE([[PBXGroup alloc] init]);
  NSMutableArray *targets = buildTargets(projectName, type, allFiles, headers, resources, frameworks, productRefGroup);
  
  [project setMainGroup: mainGroup];
  [project setProductRefGroup: productRefGroup];
  [project setBuildConfigurationList: configList];
  // [project setContainer: container];
  [project setTargets: targets];
  
  return container;
}


PBXContainer *convertPBProject(NSDictionary *proj)
{
  NSString *projectType = [proj objectForKey: @"PROJECTTYPE"];
  NSString *projectName = [proj objectForKey: @"PROJECTNAME"];
  NSDictionary *filesTable = [proj objectForKey: @"FILESTABLE"];
  NSArray *files = [filesTable objectForKey: @"CLASSES"];
  NSArray *headers = [filesTable objectForKey: @"H_FILES"];
  NSArray *resources = [filesTable objectForKey: @"INTERFACES"];
  NSArray *other = [filesTable objectForKey: @"OTHER_LINKED"];
  NSArray *frameworks = [filesTable objectForKey: @"FRAMEWORKS"];
  NSArray *images = [filesTable objectForKey: @"IMAGES"];
  NSMutableArray *allResources = [NSMutableArray arrayWithArray: resources];

  [allResources addObjectsFromArray: images];
  return buildContainer(projectName, projectType, files, headers, allResources, other, frameworks);
}

PBXContainer *convertPCProject(NSDictionary *proj)
{
  NSString *projectType = [proj objectForKey: @"PROJECT_TYPE"];
  NSString *projectName = [proj objectForKey: @"PROJECT_NAME"];
  NSArray *files = [proj objectForKey: @"CLASS_FILES"];
  NSArray *headers = [proj objectForKey: @"HEADER_FILES"];
  NSArray *resources = [proj objectForKey: @"LOCALIZED_RESOURCES"];
  NSArray *other = [proj objectForKey: @"OTHER_SOURCES"];
  NSArray *frameworks = [proj objectForKey: @"LIBRARIES"];
  NSArray *images = [proj objectForKey: @"IMAGES"];
  NSMutableArray *allResources = [NSMutableArray arrayWithArray: resources];

  [allResources addObjectsFromArray: images];
  
  return buildContainer(projectName, projectType, files, headers, allResources, other, frameworks);
}

BOOL buildXCodeProj(PBXContainer *container, NSString *dn)
{
  NSError *error = nil;
  NSString *directoryName = [dn stringByAppendingPathExtension: @"xcodeproj"];
  NSString *fn = [directoryName stringByAppendingPathComponent: @"project.pbxproj"];
  NSFileManager *fm = [NSFileManager defaultManager];
  BOOL created = [fm createDirectoryAtPath: directoryName
		     withIntermediateDirectories: YES
				attributes: NULL
				     error: &error];
  BOOL result = NO;
  
  if (created)
    {
      xcprintf("=== Saving Project %s%s%s%s -> %s%s%s\n",
	       BOLD, YELLOW, [fn cString], RESET, GREEN,
	       [dn cString], RESET);

      // [container save]; // Setup to save...
  
      // Save the project...
      if (created && !error)
	{
	  id dictionary = [PBXCoder archiveWithRootObject: container];
	  
	  result = [dictionary writeToFile: fn atomically: YES];
	  if (result)
	    {
	      xcprintf("=== Done Saving Project %s%s%s%s\n",
		       BOLD, GREEN, [dn cString], RESET);
	    }
	  else
	    {
	      xcprintf("=== Error Saving Project %s%s%s%s\n",
		       BOLD, GREEN, [dn cString], RESET);
	    }
	}
    }
  
  return result;
}

int main(int argc, const char *argv[])
{
  id pool = [[NSAutoreleasePool alloc] init];

  if (argc > 1)
    {
      NSString *input = [NSString stringWithUTF8String: argv[1]];
      NSString *output = [NSString stringWithUTF8String: argv[2]];
      PBXContainer *container = nil;
      
      if ([[input lastPathComponent] isEqualToString: @"PB.project"])
	{
	  NSDictionary *proj = [NSDictionary dictionaryWithContentsOfFile: input];

	  xcprintf("== Parsing an old style NeXT project: %s -> %s\n",
		   [input UTF8String], [output UTF8String]);
	  container = convertPBProject(proj);
	}
      else if ([[input pathExtension] isEqualToString: @"pcproj"])
	{
	  NSString *path = [input stringByAppendingPathComponent: @"PC.project"];
	  NSDictionary *proj = [NSDictionary dictionaryWithContentsOfFile: path];	  

	  printf("== Parsing a ProjectCenter project: %s -> %s\n",
		 [input UTF8String], [output UTF8String]);
	  container = convertPCProject(proj);
	}
      else
	{
	  xcprintf("== Unknown project type");
	}

      if (container == nil)
	{
	  xcprintf("== Unable to parse project file %@", input);
	  return 255;
	}
      else
	{
	  BOOL result = buildXCodeProj(container, output);
	  if (result == NO)
	    {
	      return 255;
	    }
	}
    }
  else
    {
      xcprintf("== Not enough arguments");
    }
			    
  [pool release];

  return 0;
}

