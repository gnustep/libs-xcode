/*
   Project: Ycode

   Copyright (C) 2025 Free Software Foundation

   Author: Gregory Casamento

   Created: 2025-01-15

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

#import "YCodeSyntaxHighlighter.h"

@implementation YCodeSyntaxHighlighter

- (instancetype)initWithFileExtension:(NSString *)extension
{
    self = [super init];
    if (self) {
        // Default color scheme
        _keywordColor = [[NSColor colorWithDeviceRed:0.67 green:0.20 blue:0.89 alpha:1.0] retain]; // Purple
        _stringColor = [[NSColor colorWithDeviceRed:0.77 green:0.10 blue:0.08 alpha:1.0] retain];  // Red
        _commentColor = [[NSColor colorWithDeviceRed:0.42 green:0.48 blue:0.53 alpha:1.0] retain]; // Gray
        _numberColor = [[NSColor colorWithDeviceRed:0.11 green:0.28 blue:0.80 alpha:1.0] retain];  // Blue
        _preprocessorColor = [[NSColor colorWithDeviceRed:0.64 green:0.45 blue:0.14 alpha:1.0] retain]; // Brown
        _typeColor = [[NSColor colorWithDeviceRed:0.15 green:0.54 blue:0.61 alpha:1.0] retain];   // Teal
        
        [self setFileExtension:extension];
    }
    return self;
}

- (void)dealloc
{
    RELEASE(_fileExtension);
    RELEASE(_textView);
    RELEASE(_keywordColor);
    RELEASE(_stringColor);
    RELEASE(_commentColor);
    RELEASE(_numberColor);
    RELEASE(_preprocessorColor);
    RELEASE(_typeColor);
    RELEASE(_keywords);
    RELEASE(_types);
    RELEASE(_stringPattern);
    RELEASE(_commentPattern);
    RELEASE(_numberPattern);
    RELEASE(_preprocessorPattern);
    [super dealloc];
}

#pragma mark - File Extension and Language

- (NSString *)fileExtension
{
    return _fileExtension;
}

- (void)setFileExtension:(NSString *)extension
{
    ASSIGN(_fileExtension, extension);
    NSString *language = [self language];
    if (language) {
        [self setupForLanguage:language];
    }
}

- (NSString *)language
{
    if (!_fileExtension) {
        return nil;
    }
    
    if ([_fileExtension isEqualToString:@"m"] || [_fileExtension isEqualToString:@"mm"]) {
        return @"objc";
    } else if ([_fileExtension isEqualToString:@"h"]) {
        return @"objc"; // Assuming Objective-C headers
    } else if ([_fileExtension isEqualToString:@"c"]) {
        return @"c";
    } else if ([_fileExtension isEqualToString:@"cpp"] || [_fileExtension isEqualToString:@"cc"] || 
               [_fileExtension isEqualToString:@"cxx"]) {
        return @"cpp";
    } else if ([_fileExtension isEqualToString:@"js"]) {
        return @"javascript";
    } else if ([_fileExtension isEqualToString:@"py"]) {
        return @"python";
    } else if ([_fileExtension isEqualToString:@"swift"]) {
        return @"swift";
    }
    
    return @"plain";
}

#pragma mark - Text View Association

- (NSTextView *)textView
{
    return _textView;
}

- (void)setTextView:(NSTextView *)textView
{
    ASSIGN(_textView, textView);
}

#pragma mark - Color Scheme

- (NSColor *)keywordColor
{
    return _keywordColor;
}

- (void)setKeywordColor:(NSColor *)color
{
    ASSIGN(_keywordColor, color);
}

- (NSColor *)stringColor
{
    return _stringColor;
}

- (void)setStringColor:(NSColor *)color
{
    ASSIGN(_stringColor, color);
}

- (NSColor *)commentColor
{
    return _commentColor;
}

- (void)setCommentColor:(NSColor *)color
{
    ASSIGN(_commentColor, color);
}

- (NSColor *)numberColor
{
    return _numberColor;
}

- (void)setNumberColor:(NSColor *)color
{
    ASSIGN(_numberColor, color);
}

- (NSColor *)preprocessorColor
{
    return _preprocessorColor;
}

- (void)setPreprocessorColor:(NSColor *)color
{
    ASSIGN(_preprocessorColor, color);
}

- (NSColor *)typeColor
{
    return _typeColor;
}

- (void)setTypeColor:(NSColor *)color
{
    ASSIGN(_typeColor, color);
}

#pragma mark - Highlighting Operations

- (void)highlightText
{
    if (!_textView) {
        return;
    }
    
    NSString *text = [_textView string];
    NSRange fullRange = NSMakeRange(0, [text length]);
    
    [self highlightRange:fullRange];
}

- (void)highlightRange:(NSRange)range
{
    if (!_textView) {
        return;
    }
    
    NSString *text = [_textView string];
    NSTextStorage *textStorage = [_textView textStorage];
    
    if (range.location + range.length > [text length]) {
        return;
    }
    
    // Remove existing attributes in range
    [textStorage removeAttribute:NSForegroundColorAttributeName range:range];
    
    // Apply syntax highlighting based on language
    NSString *language = [self language];
    
    if ([language isEqualToString:@"objc"] || [language isEqualToString:@"c"] || [language isEqualToString:@"cpp"]) {
        [self highlightCStyleLanguage:text inRange:range textStorage:textStorage];
    } else if ([language isEqualToString:@"javascript"]) {
        [self highlightJavaScript:text inRange:range textStorage:textStorage];
    } else if ([language isEqualToString:@"python"]) {
        [self highlightPython:text inRange:range textStorage:textStorage];
    }
}

- (void)removeHighlighting
{
    if (!_textView) {
        return;
    }
    
    NSString *text = [_textView string];
    NSRange fullRange = NSMakeRange(0, [text length]);
    NSTextStorage *textStorage = [_textView textStorage];
    
    [textStorage removeAttribute:NSForegroundColorAttributeName range:fullRange];
}

#pragma mark - Language-Specific Highlighting

- (void)highlightCStyleLanguage:(NSString *)text inRange:(NSRange)range textStorage:(NSTextStorage *)textStorage
{
    // Highlight comments
    if (_commentPattern) {
        NSArray *matches = [_commentPattern matchesInString:text options:0 range:range];
        for (NSTextCheckingResult *match in matches) {
            [textStorage addAttribute:NSForegroundColorAttributeName
                                value:_commentColor
                                range:[match range]];
        }
    }
    
    // Highlight strings
    if (_stringPattern) {
        NSArray *matches = [_stringPattern matchesInString:text options:0 range:range];
        for (NSTextCheckingResult *match in matches) {
            [textStorage addAttribute:NSForegroundColorAttributeName
                                value:_stringColor
                                range:[match range]];
        }
    }
    
    // Highlight preprocessor directives
    if (_preprocessorPattern) {
        NSArray *matches = [_preprocessorPattern matchesInString:text options:0 range:range];
        for (NSTextCheckingResult *match in matches) {
            [textStorage addAttribute:NSForegroundColorAttributeName
                                value:_preprocessorColor
                                range:[match range]];
        }
    }
    
    // Highlight numbers
    if (_numberPattern) {
        NSArray *matches = [_numberPattern matchesInString:text options:0 range:range];
        for (NSTextCheckingResult *match in matches) {
            [textStorage addAttribute:NSForegroundColorAttributeName
                                value:_numberColor
                                range:[match range]];
        }
    }
    
    // Highlight keywords
    if (_keywords) {
        for (NSString *keyword in _keywords) {
            NSString *pattern = [NSString stringWithFormat:@"\\\\b%@\\\\b", keyword];
            NSRegularExpression *regex = [NSRegularExpression regularExpressionWithPattern:pattern
                                                                                   options:0
                                                                                     error:nil];
            if (regex) {
                NSArray *matches = [regex matchesInString:text options:0 range:range];
                for (NSTextCheckingResult *match in matches) {
                    [textStorage addAttribute:NSForegroundColorAttributeName
                                        value:_keywordColor
                                        range:[match range]];
                }
            }
        }
    }
    
    // Highlight types
    if (_types) {
        for (NSString *type in _types) {
            NSString *pattern = [NSString stringWithFormat:@"\\\\b%@\\\\b", type];
            NSRegularExpression *regex = [NSRegularExpression regularExpressionWithPattern:pattern
                                                                                   options:0
                                                                                     error:nil];
            if (regex) {
                NSArray *matches = [regex matchesInString:text options:0 range:range];
                for (NSTextCheckingResult *match in matches) {
                    [textStorage addAttribute:NSForegroundColorAttributeName
                                        value:_typeColor
                                        range:[match range]];
                }
            }
        }
    }
}

- (void)highlightJavaScript:(NSString *)text inRange:(NSRange)range textStorage:(NSTextStorage *)textStorage
{
    // Similar to C-style highlighting but with JavaScript-specific keywords
    [self highlightCStyleLanguage:text inRange:range textStorage:textStorage];
}

- (void)highlightPython:(NSString *)text inRange:(NSRange)range textStorage:(NSTextStorage *)textStorage
{
    // Python-specific highlighting (simpler comment pattern, different string handling)
    [self highlightCStyleLanguage:text inRange:range textStorage:textStorage];
}

#pragma mark - Language-Specific Setup

- (void)setupForLanguage:(NSString *)language
{
    if ([language isEqualToString:@"objc"]) {
        [self setupObjectiveC];
    } else if ([language isEqualToString:@"c"]) {
        [self setupC];
    } else if ([language isEqualToString:@"cpp"]) {
        [self setupCPlusPlus];
    } else if ([language isEqualToString:@"javascript"]) {
        [self setupJavaScript];
    } else if ([language isEqualToString:@"python"]) {
        [self setupPython];
    } else if ([language isEqualToString:@"swift"]) {
        [self setupSwift];
    }
}

- (void)setupObjectiveC
{
    // Objective-C keywords
    NSArray *objcKeywords = @[@"auto", @"break", @"case", @"char", @"const", @"continue", @"default", @"do",
                              @"double", @"else", @"enum", @"extern", @"float", @"for", @"goto", @"if",
                              @"int", @"long", @"register", @"return", @"short", @"signed", @"sizeof", @"static",
                              @"struct", @"switch", @"typedef", @"union", @"unsigned", @"void", @"volatile", @"while",
                              @"@interface", @"@implementation", @"@end", @"@class", @"@protocol", @"@property",
                              @"@synthesize", @"@dynamic", @"@selector", @"@encode", @"@try", @"@catch", @"@finally",
                              @"@throw", @"@synchronized", @"@autoreleasepool", @"@import", @"@public", @"@private",
                              @"@protected", @"@package", @"self", @"super", @"nil", @"Nil", @"YES", @"NO"];
    
    NSArray *objcTypes = @[@"id", @"Class", @"SEL", @"IMP", @"BOOL", @"NSInteger", @"NSUInteger", @"CGFloat",
                           @"NSString", @"NSArray", @"NSDictionary", @"NSObject", @"NSNumber"];
    
    ASSIGN(_keywords, objcKeywords);
    ASSIGN(_types, objcTypes);
    
    // Regular expressions
    _stringPattern = [[NSRegularExpression regularExpressionWithPattern:@"\\\"[^\\\"]*\\\"|\\'[^\\']*\\'"
                                                                 options:0 error:nil] retain];
    _commentPattern = [[NSRegularExpression regularExpressionWithPattern:@"/\\*[\\s\\S]*?\\*/|//.*?$"
                                                                  options:NSRegularExpressionAnchorsMatchLines error:nil] retain];
    _numberPattern = [[NSRegularExpression regularExpressionWithPattern:@"\\b\\d+(\\.\\d+)?([eE][+-]?\\d+)?[fFdD]?\\b"
                                                                 options:0 error:nil] retain];
    _preprocessorPattern = [[NSRegularExpression regularExpressionWithPattern:@"^\\s*#.*$"
                                                                       options:NSRegularExpressionAnchorsMatchLines error:nil] retain];
}

- (void)setupC
{
    // C keywords
    NSArray *cKeywords = @[@"auto", @"break", @"case", @"char", @"const", @"continue", @"default", @"do",
                           @"double", @"else", @"enum", @"extern", @"float", @"for", @"goto", @"if",
                           @"int", @"long", @"register", @"return", @"short", @"signed", @"sizeof", @"static",
                           @"struct", @"switch", @"typedef", @"union", @"unsigned", @"void", @"volatile", @"while"];
    
    NSArray *cTypes = @[@"size_t", @"ptrdiff_t", @"FILE", @"NULL"];
    
    ASSIGN(_keywords, cKeywords);
    ASSIGN(_types, cTypes);
    
    [self setupCommonCPatterns];
}

- (void)setupCPlusPlus
{
    // C++ keywords (includes C keywords)
    NSArray *cppKeywords = @[@"auto", @"break", @"case", @"char", @"const", @"continue", @"default", @"do",
                             @"double", @"else", @"enum", @"extern", @"float", @"for", @"goto", @"if",
                             @"int", @"long", @"register", @"return", @"short", @"signed", @"sizeof", @"static",
                             @"struct", @"switch", @"typedef", @"union", @"unsigned", @"void", @"volatile", @"while",
                             @"class", @"private", @"public", @"protected", @"virtual", @"friend", @"inline",
                             @"operator", @"overload", @"template", @"this", @"new", @"delete", @"namespace",
                             @"using", @"try", @"catch", @"throw", @"const_cast", @"dynamic_cast", @"reinterpret_cast",
                             @"static_cast", @"typeid", @"typename", @"explicit", @"mutable", @"export"];
    
    NSArray *cppTypes = @[@"bool", @"wchar_t", @"string", @"vector", @"map", @"set", @"list", @"deque"];
    
    ASSIGN(_keywords, cppKeywords);
    ASSIGN(_types, cppTypes);
    
    [self setupCommonCPatterns];
}

- (void)setupCommonCPatterns
{
    _stringPattern = [[NSRegularExpression regularExpressionWithPattern:@"\\\"[^\\\"]*\\\"|\\'[^\\']*\\'"
                                                                 options:0 error:nil] retain];
    _commentPattern = [[NSRegularExpression regularExpressionWithPattern:@"/\\*[\\s\\S]*?\\*/|//.*?$"
                                                                  options:NSRegularExpressionAnchorsMatchLines error:nil] retain];
    _numberPattern = [[NSRegularExpression regularExpressionWithPattern:@"\\b\\d+(\\.\\d+)?([eE][+-]?\\d+)?[fFdDlL]?\\b"
                                                                 options:0 error:nil] retain];
    _preprocessorPattern = [[NSRegularExpression regularExpressionWithPattern:@"^\\s*#.*$"
                                                                       options:NSRegularExpressionAnchorsMatchLines error:nil] retain];
}

- (void)setupJavaScript
{
    NSArray *jsKeywords = @[@"break", @"case", @"catch", @"continue", @"debugger", @"default", @"delete", @"do",
                            @"else", @"finally", @"for", @"function", @"if", @"in", @"instanceof", @"new",
                            @"return", @"switch", @"this", @"throw", @"try", @"typeof", @"var", @"void", @"while",
                            @"with", @"class", @"const", @"enum", @"export", @"extends", @"import", @"super",
                            @"implements", @"interface", @"let", @"package", @"private", @"protected", @"public",
                            @"static", @"yield"];
    
    NSArray *jsTypes = @[@"Array", @"Boolean", @"Date", @"Error", @"Function", @"Number", @"Object", @"RegExp", @"String"];
    
    ASSIGN(_keywords, jsKeywords);
    ASSIGN(_types, jsTypes);
    
    _stringPattern = [[NSRegularExpression regularExpressionWithPattern:@"\\\"[^\\\"]*\\\"|'[^']*'|`[^`]*`"
                                                                 options:0 error:nil] retain];
    _commentPattern = [[NSRegularExpression regularExpressionWithPattern:@"/\\*[\\s\\S]*?\\*/|//.*?$"
                                                                  options:NSRegularExpressionAnchorsMatchLines error:nil] retain];
    _numberPattern = [[NSRegularExpression regularExpressionWithPattern:@"\\b\\d+(\\.\\d+)?([eE][+-]?\\d+)?\\b"
                                                                 options:0 error:nil] retain];
    _preprocessorPattern = nil; // JavaScript doesn't have preprocessor
}

- (void)setupPython
{
    NSArray *pythonKeywords = @[@"and", @"as", @"assert", @"break", @"class", @"continue", @"def", @"del", @"elif",
                                @"else", @"except", @"exec", @"finally", @"for", @"from", @"global", @"if", @"import",
                                @"in", @"is", @"lambda", @"not", @"or", @"pass", @"print", @"raise", @"return", @"try",
                                @"while", @"with", @"yield", @"None", @"True", @"False"];
    
    NSArray *pythonTypes = @[@"int", @"float", @"str", @"list", @"dict", @"tuple", @"set", @"bool"];
    
    ASSIGN(_keywords, pythonKeywords);
    ASSIGN(_types, pythonTypes);
    
    _stringPattern = [[NSRegularExpression regularExpressionWithPattern:@"\\\"\\\"\\\"[\\s\\S]*?\\\"\\\"\\\"|'''[\\s\\S]*?'''|\\\"[^\\\"]*\\\"|'[^']*'"
                                                                 options:0 error:nil] retain];
    _commentPattern = [[NSRegularExpression regularExpressionWithPattern:@"#.*?$"
                                                                  options:NSRegularExpressionAnchorsMatchLines error:nil] retain];
    _numberPattern = [[NSRegularExpression regularExpressionWithPattern:@"\\b\\d+(\\.\\d+)?([eE][+-]?\\d+)?\\b"
                                                                 options:0 error:nil] retain];
    _preprocessorPattern = nil; // Python doesn't have preprocessor
}

- (void)setupSwift
{
    NSArray *swiftKeywords = @[@"associatedtype", @"class", @"deinit", @"enum", @"extension", @"func", @"import",
                               @"init", @"inout", @"internal", @"let", @"operator", @"private", @"protocol", @"public",
                               @"static", @"struct", @"subscript", @"typealias", @"var", @"break", @"case", @"continue",
                               @"default", @"defer", @"do", @"else", @"fallthrough", @"for", @"guard", @"if", @"in",
                               @"repeat", @"return", @"switch", @"where", @"while", @"as", @"catch", @"false", @"is",
                               @"nil", @"rethrows", @"super", @"self", @"Self", @"throw", @"throws", @"true", @"try"];
    
    NSArray *swiftTypes = @[@"Int", @"Float", @"Double", @"Bool", @"String", @"Character", @"Array", @"Dictionary", @"Set"];
    
    ASSIGN(_keywords, swiftKeywords);
    ASSIGN(_types, swiftTypes);
    
    _stringPattern = [[NSRegularExpression regularExpressionWithPattern:@"\\\"[^\\\"]*\\\""
                                                                 options:0 error:nil] retain];
    _commentPattern = [[NSRegularExpression regularExpressionWithPattern:@"/\\*[\\s\\S]*?\\*/|//.*?$"
                                                                  options:NSRegularExpressionAnchorsMatchLines error:nil] retain];
    _numberPattern = [[NSRegularExpression regularExpressionWithPattern:@"\\b\\d+(\\.\\d+)?([eE][+-]?\\d+)?\\b"
                                                                 options:0 error:nil] retain];
    _preprocessorPattern = nil; // Swift doesn't have preprocessor
}

@end