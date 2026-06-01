Pod::Spec.new do |s|
  s.name = 'XCode'
  s.version = '0.5.0'
  s.summary = 'GNUstep Xcode project parsing and build library.'
  s.description = <<-DESC
The GNUstep Xcode Library parses Xcode projects and can drive builds for
Xcode project files.
  DESC
  s.homepage = 'https://github.com/gnustep/libs-xcode'
  s.license = { :type => 'LGPL-2.0-or-later', :text => File.read('COPYING.LIB') }
  s.author = { 'GNUstep' => 'bug-gnustep@gnu.org' }
  s.source = { :git => 'https://github.com/gnustep/libs-xcode.git', :tag => s.version.to_s }

  s.osx.deployment_target = '10.13'
  s.requires_arc = false
  s.frameworks = 'Foundation'

  s.source_files = 'XCode/*.{h,m}'
  s.exclude_files = 'XCode/setenv.m'
  s.public_header_files = 'XCode/*.h'
  s.header_mappings_dir = 'XCode'

  s.resource_bundles = {
    'XCode' => [
      'XCode/Resources/Framework-mapping.plist',
      'XCode/Resources/language-codes.plist',
      'XCode/Resources/create-dummy-class.sh'
    ]
  }
end
