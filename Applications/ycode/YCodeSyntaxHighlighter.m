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
#include <math.h>

static NSRegularExpression *YCodeTokenPattern(NSString *pattern)
{
    if (![pattern length]) return nil;
    NSError *error = nil;
    NSRegularExpression *regex = [NSRegularExpression regularExpressionWithPattern:pattern
        options:NSRegularExpressionAnchorsMatchLines error:&error];
    if (error) NSLog(@"Invalid syntax highlighting pattern: %@", error);
    return regex;
}

static NSString *YCodeWordPattern(NSArray *words)
{
    NSMutableArray *escaped = [NSMutableArray array];
    {
      NSEnumerator *wordEnumerator = [words objectEnumerator];
      NSString *word;
      while ((word = [wordEnumerator nextObject]) != nil)
        [escaped addObject:[NSRegularExpression escapedPatternForString:word]];
    }
    return [escaped count] ? [NSString stringWithFormat:
        @"(?<![A-Za-z0-9_])(?:%@)(?![A-Za-z0-9_])", [escaped componentsJoinedByString:@"|"]] : nil;
}

@implementation YCodeSyntaxHighlighter

// Store RGB components as property-list values, without archiving AppKit objects.
+ (NSArray *)colorPreferenceKeys
{
    return [NSArray arrayWithObjects:@"background", @"text", @"keyword", @"string",
        @"comment", @"number", @"preprocessor", @"type", @"symbol", @"constant", @"cursor", nil];
}

+ (NSColor *)savedColorForKey:(NSString *)key
{
    id components = [[[NSUserDefaults standardUserDefaults] dictionaryForKey:@"YCodeEditorColors"] objectForKey:key];
    if (![components isKindOfClass:[NSArray class]] || [components count] != 3) return nil;
    NSUInteger i;
    for (i = 0; i < 3; i++) {
        id value = [components objectAtIndex:i];
        if (![value isKindOfClass:[NSNumber class]] || !isfinite([value doubleValue]) ||
            [value doubleValue] < 0 || [value doubleValue] > 1) return nil;
    }
    return [NSColor colorWithDeviceRed:[[components objectAtIndex:0] doubleValue]
        green:[[components objectAtIndex:1] doubleValue]
        blue:[[components objectAtIndex:2] doubleValue] alpha:1];
}

+ (NSColor *)preferredColorForKey:(NSString *)key
{
    NSColor *saved = [self savedColorForKey:key];
    if (saved) return saved;
    if ([key isEqual:@"cursor"]) return [NSColor redColor];
    if ([key isEqual:@"background"]) return [NSColor whiteColor];
    if ([key isEqual:@"text"]) return [self plainTextColorForBackground:[self preferredColorForKey:@"background"]];
    static const CGFloat defaults[8][3] = {
        {0.67, 0.20, 0.89}, {0.77, 0.10, 0.08}, {0.42, 0.48, 0.53},
        {0.11, 0.28, 0.80}, {0.64, 0.45, 0.14}, {0.15, 0.54, 0.61},
        {0.12, 0.40, 0.64}, {0.60, 0.32, 0.12}
    };
    NSUInteger index = [[self colorPreferenceKeys] indexOfObject:key];
    if (index == NSNotFound || index < 2) return nil;
    return [NSColor colorWithDeviceRed:defaults[index - 2][0]
        green:defaults[index - 2][1] blue:defaults[index - 2][2] alpha:1];
}

+ (void)setPreferredColor:(NSColor *)color forKey:(NSString *)key
{
    if (![[self colorPreferenceKeys] containsObject:key]) return;
    NSColor *rgb = [color colorUsingColorSpaceName:NSDeviceRGBColorSpace];
    if (!rgb) return;
    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
    NSMutableDictionary *colors = [NSMutableDictionary dictionaryWithDictionary:
        [defaults dictionaryForKey:@"YCodeEditorColors"] ?: [NSDictionary dictionary]];
    [colors setObject:[NSArray arrayWithObjects:[NSNumber numberWithDouble:[rgb redComponent]],
        [NSNumber numberWithDouble:[rgb greenComponent]], [NSNumber numberWithDouble:[rgb blueComponent]], nil] forKey:key];
    [defaults setObject:colors forKey:@"YCodeEditorColors"];
    [defaults synchronize];
    [[NSNotificationCenter defaultCenter] postNotificationName:@"YCodeEditorColorsDidChange" object:nil];
}

+ (void)resetColorPreferences
{
    [[NSUserDefaults standardUserDefaults] removeObjectForKey:@"YCodeEditorColors"];
    [[NSUserDefaults standardUserDefaults] synchronize];
    [[NSNotificationCenter defaultCenter] postNotificationName:@"YCodeEditorColorsDidChange" object:nil];
}

- (void)loadPreferredColors
{
    ASSIGN(_keywordColor, [[self class] preferredColorForKey:@"keyword"]);
    ASSIGN(_stringColor, [[self class] preferredColorForKey:@"string"]);
    ASSIGN(_commentColor, [[self class] preferredColorForKey:@"comment"]);
    ASSIGN(_numberColor, [[self class] preferredColorForKey:@"number"]);
    ASSIGN(_preprocessorColor, [[self class] preferredColorForKey:@"preprocessor"]);
    ASSIGN(_typeColor, [[self class] preferredColorForKey:@"type"]);
    ASSIGN(_symbolColor, [[self class] preferredColorForKey:@"symbol"]);
    ASSIGN(_constantColor, [[self class] preferredColorForKey:@"constant"]);
}

- (id)initWithFileExtension:(NSString *)extension
{
    self = [super init];
    if (self) {
        [self loadPreferredColors];
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
    RELEASE(_symbolColor);
    RELEASE(_constantColor);
    RELEASE(_keywordPattern);
    RELEASE(_typePattern);
    RELEASE(_symbolPattern);
    RELEASE(_constantPattern);
    RELEASE(_literalPattern);
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
    [self setupForLanguage:[self language]];
}

- (NSString *)language
{
    NSString *extension = [_fileExtension lowercaseString];
    if ([_fileExtension isEqual:@"C"]) return @"cpp";
    if ([[NSArray arrayWithObjects:@"m", @"mm", @"h", nil] containsObject:extension]) return @"objc";
    if ([extension isEqual:@"c"]) return @"c";
    if ([[NSArray arrayWithObjects:@"cpp", @"cc", @"cp", @"cxx", @"c++", @"hpp", @"hh", @"hxx", @"h++", nil] containsObject:extension]) return @"cpp";
    if ([[NSArray arrayWithObjects:@"js", @"jsx", @"mjs", @"cjs", @"ts", @"tsx", nil] containsObject:extension]) return @"javascript";
    if ([[NSArray arrayWithObjects:@"py", @"pyw", nil] containsObject:extension]) return @"python";
    if ([extension isEqual:@"swift"]) return @"swift";
    if ([[NSArray arrayWithObjects:@"make", @"mk", @"makefile", @"gnumakefile", nil] containsObject:extension]) return @"make";
    if ([extension isEqual:@"cmake"]) return @"cmake";
    if ([[NSArray arrayWithObjects:@"sh", @"bash", @"zsh", nil] containsObject:extension]) return @"shell";
    if ([[NSArray arrayWithObjects:@"json", @"jsonc", nil] containsObject:extension]) return @"json";
    if ([[NSArray arrayWithObjects:@"plist", @"pbxproj", @"xcworkspacedata", @"strings", @"pcproj", @"project", nil] containsObject:extension]) return @"plist";
    if ([[NSArray arrayWithObjects:@"xml", @"xib", @"html", @"htm", @"svg", @"xcscheme", @"gsmarkup", nil] containsObject:extension]) return @"xml";
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
    [_textView setBackgroundColor:[[self class] preferredColorForKey:@"background"]];
    [_textView setInsertionPointColor:[[self class] preferredColorForKey:@"cursor"]];
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

- (NSColor *)symbolColor { return _symbolColor; }
- (NSColor *)constantColor { return _constantColor; }

#pragma mark - Highlighting Operations

+ (NSColor *)plainTextColorForBackground:(NSColor *)background
{
    NSColor *saved = [self savedColorForKey:@"text"];
    if (saved) return saved;
    NSColor *rgb = [background colorUsingColorSpaceName:NSDeviceRGBColorSpace];
    if (!rgb) {
        rgb = [[NSColor textBackgroundColor] colorUsingColorSpaceName:NSDeviceRGBColorSpace];
    }
    return [NSColor colorWithDeviceRed:1.0 - [rgb redComponent]
                                green:1.0 - [rgb greenComponent]
                                 blue:1.0 - [rgb blueComponent]
                                alpha:1.0];
}

- (void)applyPlainTextColorInRange:(NSRange)range
{
    NSColor *color = [[self class] plainTextColorForBackground:[_textView backgroundColor]];
    [[_textView textStorage] addAttribute:NSForegroundColorAttributeName value:color range:range];
    NSMutableDictionary *attributes = [[_textView typingAttributes] mutableCopy];
    [attributes setObject:color forKey:NSForegroundColorAttributeName];
    [_textView setTypingAttributes:attributes];
    RELEASE(attributes);
    [_textView setInsertionPointColor:[[self class] preferredColorForKey:@"cursor"]];
}

- (void)highlightText
{
    if (!_textView) {
        return;
    }
    
    NSString *text = [_textView string];
    NSRange fullRange = NSMakeRange(0, [text length]);
    
    [self highlightRange:fullRange];
}

- (void)applyPattern:(NSRegularExpression *)pattern color:(NSColor *)color
                text:(NSString *)text range:(NSRange)range
{
    // Match with full lexical context, but only change the requested characters.
    {
      NSEnumerator *matchEnumerator = [[pattern matchesInString:text options:0
        range:NSMakeRange(0, [text length])] objectEnumerator];
      NSTextCheckingResult *match;
      while ((match = [matchEnumerator nextObject]) != nil)
        {
          NSRange painted = NSIntersectionRange([match range], range);
          if (painted.length)
              [[_textView textStorage] addAttribute:NSForegroundColorAttributeName value:color range:painted];
        }
    }
}

- (void)highlightRange:(NSRange)range
{
    if (!_textView) return;
    NSString *text = [_textView string];
    if (range.location > [text length] || range.length > [text length] - range.location) return;
    NSString *language = [self language];
    BOOL highlightKeys = [language isEqual:@"json"] || [language isEqual:@"plist"];
    NSTextStorage *storage = [_textView textStorage];
    [storage beginEditing];
    @try {
        [self applyPlainTextColorInRange:range];
        [self applyPattern:_preprocessorPattern color:_preprocessorColor text:text range:range];
        [self applyPattern:_symbolPattern color:_symbolColor text:text range:range];
        [self applyPattern:_constantPattern color:_constantColor text:text range:range];
        [self applyPattern:_typePattern color:_typeColor text:text range:range];
        [self applyPattern:_numberPattern color:_numberColor text:text range:range];
        [self applyPattern:_keywordPattern color:_keywordColor text:text range:range];
        // One left-to-right lexical pass prevents comment markers in strings,
        // or strings inside comments, from winning over their enclosing token.
        {
          NSEnumerator *matchEnumerator = [[_literalPattern matchesInString:text options:0
            range:NSMakeRange(0, [text length])] objectEnumerator];
          NSTextCheckingResult *match;
          while ((match = [matchEnumerator nextObject]) != nil)
            {
              NSRange token = [match range];
              NSRange painted = NSIntersectionRange(token, range);
              if (!painted.length) continue;
              BOOL comment = [match rangeAtIndex:1].location != NSNotFound;
              NSColor *color = comment ? _commentColor : _stringColor;
              if (!comment && highlightKeys) {
                  NSUInteger next = NSMaxRange(token);
                  while (next < [text length] && [[NSCharacterSet whitespaceAndNewlineCharacterSet]
                      characterIsMember:[text characterAtIndex:next]]) next++;
                  if (next < [text length] && ([text characterAtIndex:next] == ':' || [text characterAtIndex:next] == '='))
                      color = _symbolColor;
              }
              [storage addAttribute:NSForegroundColorAttributeName value:color range:painted];
            }
        }
    }
    @finally { [storage endEditing]; }
}

- (void)removeHighlighting
{
    if (!_textView) {
        return;
    }
    
    NSString *text = [_textView string];
    NSRange fullRange = NSMakeRange(0, [text length]);
    [self applyPlainTextColorInRange:fullRange];
}

#pragma mark - Language-Specific Setup

- (void)setupForLanguage:(NSString *)language
{
    DESTROY(_keywords); DESTROY(_types);
    DESTROY(_numberPattern);
    DESTROY(_preprocessorPattern); DESTROY(_keywordPattern); DESTROY(_typePattern);
    DESTROY(_symbolPattern); DESTROY(_constantPattern); DESTROY(_literalPattern);
    if ([language isEqual:@"plain"]) return;

    if ([language isEqual:@"objc"]) [self setupObjectiveC];
    else if ([language isEqual:@"c"]) [self setupC];
    else if ([language isEqual:@"cpp"]) [self setupCPlusPlus];
    else if ([language isEqual:@"javascript"]) [self setupJavaScript];
    else if ([language isEqual:@"python"]) [self setupPython];
    else if ([language isEqual:@"swift"]) [self setupSwift];

    NSString *strings = @"@?\"(?:\\\\[\\s\\S]|[^\"\\\\\\r\\n])*(?:\"|$)|'(?:\\\\[\\s\\S]|[^'\\\\\\r\\n])*(?:'|$)";
    NSString *comments = @"/\\*[\\s\\S]*?(?:\\*/|\\z)|//[^\\r\\n]*";
    NSString *preprocessor = @"^[ \\t]*#[ \\t]*[A-Za-z_]+(?:[^\\r\\n\\\\]|\\\\[^\\r\\n]|\\\\\\r?\\n)*";
    NSString *symbols = @"\\b[A-Za-z_]\\w*(?=[ \\t]*(?:\\(|:))|(?<=\\.)[A-Za-z_]\\w*|\\b_[A-Za-z_]\\w*";
    NSString *types = @"\\b[A-Z][A-Za-z0-9_]*[a-z][A-Za-z0-9_]*\\b(?![ \\t]*\\()";
    NSString *constants = @"\\b[A-Z][A-Z0-9_]+\\b";
    NSArray *extraKeywords = nil;
    if ([language isEqual:@"objc"]) {
        symbols = [symbols stringByAppendingString:@"|\\b[A-Za-z_]\\w*(?=[ \\t]*\\])"];
        extraKeywords = [@"instancetype __block __weak __strong __bridge nullable nonnull nonatomic atomic readonly readwrite retain copy assign strong weak @optional @required @available" componentsSeparatedByString:@" "];
        if ([_fileExtension isEqual:@"mm"])
            extraKeywords = [extraKeywords arrayByAddingObjectsFromArray:[@"class namespace template typename using new delete virtual public private protected nullptr constexpr noexcept" componentsSeparatedByString:@" "]];
    } else if ([language isEqual:@"cpp"] || [language isEqual:@"c"]) {
        extraKeywords = [@"inline restrict _Bool _Atomic _Thread_local _Static_assert true false nullptr constexpr noexcept override final decltype static_assert thread_local alignas alignof concept requires co_await co_return co_yield" componentsSeparatedByString:@" "];
    } else if ([language isEqual:@"javascript"]) {
        preprocessor = nil;
        strings = [@"`(?:\\\\[\\s\\S]|[^`\\\\])*(?:`|\\z)|" stringByAppendingString:strings];
        extraKeywords = [@"async await of true false null undefined type declare abstract readonly as keyof infer unknown never" componentsSeparatedByString:@" "];
    } else if ([language isEqual:@"python"]) {
        comments = @"#[^\\r\\n]*";
        preprocessor = @"^[ \\t]*@[A-Za-z_][\\w.]*";
        strings = [@"(?:[rRuUbBfF]{0,2})(?:\"\"\"[\\s\\S]*?(?:\"\"\"|\\z)|'{3}[\\s\\S]*?(?:'{3}|\\z))|" stringByAppendingString:strings];
        extraKeywords = [@"async await nonlocal match case" componentsSeparatedByString:@" "];
    } else if ([language isEqual:@"swift"]) {
        strings = [@"\"\"\"[\\s\\S]*?(?:\"\"\"|\\z)|" stringByAppendingString:strings];
        extraKeywords = [@"actor async await some any isolated nonisolated weak unowned override final open convenience required mutating nonmutating" componentsSeparatedByString:@" "];
    } else if ([language isEqual:@"make"] || [language isEqual:@"shell"] || [language isEqual:@"cmake"]) {
        comments = @"(?<!\\\\)#[^\\r\\n]*";
        preprocessor = nil;
        types = nil;
        constants = @"\\$\\([^\\r\\n)]*\\)|\\$\\{[^\\r\\n}]*\\}|\\$[A-Za-z_][A-Za-z0-9_]*|\\$[@<^?*%+|#0-9]";
        if ([language isEqual:@"make"]) {
            extraKeywords = [@"include -include sinclude ifeq ifneq ifdef ifndef else endif define endef override export unexport vpath private undefine" componentsSeparatedByString:@" "];
            types = @"^[^\\s#:=][^\\r\\n:=]*:(?!=)";
            symbols = @"^[ \\t]*[A-Za-z_][A-Za-z0-9_]*(?=[ \\t]*[?:+!]?=)";
        } else if ([language isEqual:@"shell"]) {
            extraKeywords = [@"if then else elif fi for while until do done case esac in function select time export local readonly return break continue exit source" componentsSeparatedByString:@" "];
        } else {
            extraKeywords = [@"if elseif else endif foreach endforeach while endwhile function endfunction macro endmacro return include find_package add_executable add_library target_link_libraries target_include_directories set option project cmake_minimum_required" componentsSeparatedByString:@" "];
            constants = [constants stringByAppendingString:@"|\\b(?:ON|OFF|TRUE|FALSE|PUBLIC|PRIVATE|INTERFACE|REQUIRED)\\b"];
            comments = @"#\\[\\[[\\s\\S]*?(?:\\]\\]|\\z)|#[^\\r\\n]*";
        }
    } else if ([language isEqual:@"json"] || [language isEqual:@"plist"] || [language isEqual:@"xml"]) {
        extraKeywords = [@"true false null YES NO" componentsSeparatedByString:@" "];
        preprocessor = @"<\\?[\\s\\S]*?\\?>|<!DOCTYPE[^>]*>";
        types = @"</?[A-Za-z_][\\w:.-]*|/?>";
        symbols = @"\\b[A-Za-z_][\\w.-]*(?=[ \\t]*=)";
        comments = [@"<!--[\\s\\S]*?(?:-->|\\z)|" stringByAppendingString:comments];
        if ([language isEqual:@"json"]) { types = nil; preprocessor = nil; symbols = nil; constants = nil; }
        if ([language isEqual:@"xml"]) comments = @"<!--[\\s\\S]*?(?:-->|\\z)";
    }
    if (extraKeywords) {
        NSArray *all = _keywords ? [_keywords arrayByAddingObjectsFromArray:extraKeywords] : extraKeywords;
        ASSIGN(_keywords, all);
    }
    NSString *knownTypes = YCodeWordPattern(_types);
    if (knownTypes) types = types ? [NSString stringWithFormat:@"(?:%@)|(?:%@)", types, knownTypes] : knownTypes;
    _keywordPattern = RETAIN(YCodeTokenPattern(YCodeWordPattern(_keywords)));
    _typePattern = RETAIN(YCodeTokenPattern(types));
    _symbolPattern = RETAIN(YCodeTokenPattern(symbols));
    _constantPattern = RETAIN(YCodeTokenPattern(constants));
    _preprocessorPattern = RETAIN(YCodeTokenPattern(preprocessor));
    _numberPattern = RETAIN(YCodeTokenPattern(@"(?<![\\w.])@?(?:0[xX][0-9a-fA-F]+|0[bB][01]+|(?:[0-9][0-9_]*(?:\\.[0-9_]*)?|\\.[0-9_]+)(?:[eE][+-]?[0-9_]+)?)[uUlLfF]*(?!\\w)"));
    _literalPattern = RETAIN(YCodeTokenPattern([NSString stringWithFormat:@"(%@)|(?:%@)", comments, strings]));
}

- (void)setupObjectiveC
{
    NSArray *objcKeywords = [NSArray arrayWithObjects:@"auto", @"break", @"case", @"char", @"const", @"continue", @"default", @"do",
                              @"double", @"else", @"enum", @"extern", @"float", @"for", @"goto", @"if",
                              @"int", @"long", @"register", @"return", @"short", @"signed", @"sizeof", @"static",
                              @"struct", @"switch", @"typedef", @"union", @"unsigned", @"void", @"volatile", @"while",
                              @"@interface", @"@implementation", @"@end", @"@class", @"@protocol", @"@property",
                              @"@synthesize", @"@dynamic", @"@selector", @"@encode", @"@try", @"@catch", @"@finally",
                              @"@throw", @"@synchronized", @"@autoreleasepool", @"@import", @"@public", @"@private",
                              @"@protected", @"@package", @"self", @"super", @"nil", @"Nil", @"YES", @"NO", nil];
    NSArray *objcTypes = [NSArray arrayWithObjects:@"id", @"Class", @"SEL", @"IMP", @"BOOL", @"NSInteger", @"NSUInteger", @"CGFloat",
                           @"NSString", @"NSArray", @"NSDictionary", @"NSObject", @"NSNumber", nil];
    ASSIGN(_keywords, objcKeywords);
    ASSIGN(_types, objcTypes);
}

- (void)setupC
{
    NSArray *cKeywords = [NSArray arrayWithObjects:@"auto", @"break", @"case", @"char", @"const", @"continue", @"default", @"do",
                           @"double", @"else", @"enum", @"extern", @"float", @"for", @"goto", @"if",
                           @"int", @"long", @"register", @"return", @"short", @"signed", @"sizeof", @"static",
                           @"struct", @"switch", @"typedef", @"union", @"unsigned", @"void", @"volatile", @"while", nil];
    NSArray *cTypes = [NSArray arrayWithObjects:@"size_t", @"ptrdiff_t", @"FILE", @"NULL", nil];
    ASSIGN(_keywords, cKeywords);
    ASSIGN(_types, cTypes);
}

- (void)setupCPlusPlus
{
    NSArray *cppKeywords = [NSArray arrayWithObjects:@"auto", @"break", @"case", @"char", @"const", @"continue", @"default", @"do",
                             @"double", @"else", @"enum", @"extern", @"float", @"for", @"goto", @"if",
                             @"int", @"long", @"register", @"return", @"short", @"signed", @"sizeof", @"static",
                             @"struct", @"switch", @"typedef", @"union", @"unsigned", @"void", @"volatile", @"while",
                             @"class", @"private", @"public", @"protected", @"virtual", @"friend", @"inline",
                             @"operator", @"overload", @"template", @"this", @"new", @"delete", @"namespace",
                             @"using", @"try", @"catch", @"throw", @"const_cast", @"dynamic_cast", @"reinterpret_cast",
                             @"static_cast", @"typeid", @"typename", @"explicit", @"mutable", @"export", nil];
    NSArray *cppTypes = [NSArray arrayWithObjects:@"bool", @"wchar_t", @"string", @"vector", @"map", @"set", @"list", @"deque", nil];
    ASSIGN(_keywords, cppKeywords);
    ASSIGN(_types, cppTypes);
}

- (void)setupJavaScript
{
    NSArray *jsKeywords = [NSArray arrayWithObjects:@"break", @"case", @"catch", @"continue", @"debugger", @"default", @"delete", @"do",
                            @"else", @"finally", @"for", @"function", @"if", @"in", @"instanceof", @"new",
                            @"return", @"switch", @"this", @"throw", @"try", @"typeof", @"var", @"void", @"while",
                            @"with", @"class", @"const", @"enum", @"export", @"extends", @"import", @"super",
                            @"implements", @"interface", @"let", @"package", @"private", @"protected", @"public",
                            @"static", @"yield", nil];
    NSArray *jsTypes = [NSArray arrayWithObjects:@"Array", @"Boolean", @"Date", @"Error", @"Function", @"Number", @"Object", @"RegExp", @"String", nil];
    ASSIGN(_keywords, jsKeywords);
    ASSIGN(_types, jsTypes);
}

- (void)setupPython
{
    NSArray *pythonKeywords = [NSArray arrayWithObjects:@"and", @"as", @"assert", @"break", @"class", @"continue", @"def", @"del", @"elif",
                                @"else", @"except", @"exec", @"finally", @"for", @"from", @"global", @"if", @"import",
                                @"in", @"is", @"lambda", @"not", @"or", @"pass", @"print", @"raise", @"return", @"try",
                                @"while", @"with", @"yield", @"None", @"True", @"False", nil];
    NSArray *pythonTypes = [NSArray arrayWithObjects:@"int", @"float", @"str", @"list", @"dict", @"tuple", @"set", @"bool", nil];
    ASSIGN(_keywords, pythonKeywords);
    ASSIGN(_types, pythonTypes);
}

- (void)setupSwift
{
    NSArray *swiftKeywords = [NSArray arrayWithObjects:@"associatedtype", @"class", @"deinit", @"enum", @"extension", @"func", @"import",
                               @"init", @"inout", @"internal", @"let", @"operator", @"private", @"protocol", @"public",
                               @"static", @"struct", @"subscript", @"typealias", @"var", @"break", @"case", @"continue",
                               @"default", @"defer", @"do", @"else", @"fallthrough", @"for", @"guard", @"if", @"in",
                               @"repeat", @"return", @"switch", @"where", @"while", @"as", @"catch", @"false", @"is",
                               @"nil", @"rethrows", @"super", @"self", @"Self", @"throw", @"throws", @"true", @"try", nil];
    NSArray *swiftTypes = [NSArray arrayWithObjects:@"Int", @"Float", @"Double", @"Bool", @"String", @"Character", @"Array", @"Dictionary", @"Set", nil];
    ASSIGN(_keywords, swiftKeywords);
    ASSIGN(_types, swiftTypes);
}

@end
