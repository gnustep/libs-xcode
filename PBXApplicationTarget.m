#import "PBXCommon.h"
#import "PBXApplicationTarget.h"

@implementation PBXApplicationTarget

// Methods....
- (NSString *) productSettingsXML // getter
{
  return productSettingsXML;
}

- (void) setProductSettingsXML: (NSString *)object; // setter
{
  ASSIGN(productSettingsXML,object);
}


@end
