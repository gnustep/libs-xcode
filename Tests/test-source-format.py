#!/usr/bin/env python3
"""Regression checks for formatting safeguards and Objective-C syntax guards."""

import pathlib
import runpy
import unittest


TOOLS = runpy.run_path(str(pathlib.Path(__file__).resolve().parents[1] / 'Tools/format-source.py'))


class SourceFormatTests(unittest.TestCase):
    def test_method_and_selector_spacing(self):
        source = '- (id)initWithName:(NSString *)name\n{\n  return [self setName:name];\n}\n'
        expected = '- (id) initWithName: (NSString *)name\n{\n  return [self setName: name];\n}\n'
        self.assertEqual(TOOLS['objc_spacing'](source), expected)
        self.assertEqual(TOOLS['source_tokens'](source), TOOLS['source_tokens'](expected))

    def test_literal_and_comment_contents_are_preserved(self):
        source = '// @property foo:bar\n/* @autoreleasepool */\nNSString *s = @"@property foo:bar";\n'
        self.assertEqual(TOOLS['objc_spacing'](source), source)
        self.assertEqual(TOOLS['modern_objc'](source), [])

    def test_selector_literals_keep_their_spelling(self):
        source = '@selector(setObject:forKey:)'
        self.assertEqual(TOOLS['objc_spacing'](source), source)

    def test_modern_syntax_is_rejected(self):
        for source in ('@property int value;', '@autoreleasepool {}', '@[value]',
                       '@{key: value}', '@(value)', '@42', '@YES', '__weak id value;',
                       '@optional', '- (instancetype)init;', '@interface Example ()\n@end'):
            with self.subTest(source=source):
                self.assertTrue(TOOLS['modern_objc'](source))

    def test_legacy_syntax_and_struct_access_are_allowed(self):
        source = '@interface Example : NSObject\n- (id) init;\n@end\nrect.size.width = 2;'
        self.assertEqual(TOOLS['modern_objc'](source), [])

    def test_macro_line_splices_do_not_change_tokens(self):
        self.assertEqual(TOOLS['source_tokens']('#define VALUE (1 + 2)\n'),
                         TOOLS['source_tokens']('#define VALUE (1 + \\\n  2)\n'))

    def test_directive_after_license_is_separated(self):
        source = '/* License */ #import <Foundation/Foundation.h>\n'
        expected = '/* License */\n\n#import <Foundation/Foundation.h>\n'
        self.assertEqual(TOOLS['prepare_directives'](source), expected)
        self.assertEqual(TOOLS['source_tokens'](source), TOOLS['source_tokens'](expected))


if __name__ == '__main__':
    unittest.main()
