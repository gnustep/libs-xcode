/*
    YCodeTextView.m

    Source editing rules adapted from ProjectCenter PCEditorView.

    Copyright (C) 2005-2021 Free Software Foundation
      Saso Kiselkov
      Serg Stoyan
      Riccardo Mottola

    This program is free software; you can redistribute it and/or modify
    it under the terms of the GNU General Public License as published by
    the Free Software Foundation; either version 2 of the License, or
    (at your option) any later version.

    This program is distributed in the hope that it will be useful,
    but WITHOUT ANY WARRANTY; without even the implied warranty of
    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
    GNU General Public License for more details.

    You should have received a copy of the GNU General Public License
    along with this program; if not, write to the Free Software
    Foundation, Inc., 31 Milk Street #960789 Boston, MA 02196 USA
*/

// Editing algorithms adapted from apps-projectcenter/Modules/Editors/ProjectCenter/PCEditorView.m.
#import "YCodeTextView.h"
#import "YCodePreferences.h"
#import "YCodeLanguage.h"

#define EDITOR_TAB_WIDTH 2

/* Locate the header of a possibly multiline control condition. */
static NSInteger
YCodeControlStatementIndex (NSString *string, NSInteger index)
{
  NSInteger target_index = MAX (0, index - 1);
  while (target_index > 0 &&
         [[NSCharacterSet whitespaceAndNewlineCharacterSet]
             characterIsMember: [string characterAtIndex: target_index]])
    target_index--;
  if ([string characterAtIndex: target_index] == ')')
    {
      NSInteger depth = 1, cursor = target_index;
      while (cursor > 0 && depth > 0)
        {
          unichar c = [string characterAtIndex: --cursor];
          if (c == ')')
            depth++;
          else if (c == '(')
            depth--;
        }
      if (depth == 0)
        target_index = cursor;
    }
  return target_index;
}

static BOOL
IsClosingDelimiter (unichar c)
{
  return c == '}' || c == ']' || c == ')';
}

static unichar
OpeningDelimiterForClosingDelimiter (unichar c)
{
  if (c == '}')
    {
      return '{';
    }
  if (c == ']')
    {
      return '[';
    }
  if (c == ')')
    {
      return '(';
    }

  return 0;
}

@interface YCodeTextView (Private)
- (YCodeLanguage *) languageDefinition;
- (NSString *) codeForText: (NSString *)text;
- (void) alignBlockClosingLine;

- (void) insertSpaceFillAlignedAtTabsOfSize: (unsigned int)tabSize;
- (void) performIndentation;
- (NSUInteger) editorTabWidth;
- (NSUInteger) editorIndentWidth;
- (BOOL) editorUsesTabs;
- (void) loadIndentSettingsIfNeeded;
- (void) tabPreferencesChanged: (NSNotification *)notification;
- (NSString *) clangFormatPathForFilePath: (NSString *)filePath;
- (void) loadIndentSettingsFromClangFormatAtPath: (NSString *)path;
- (NSString *) indentStringForColumnCount: (NSUInteger)columns;
- (NSInteger) leadingWhitespaceLengthOfLineAtIndex: (NSInteger)index
                                        forString: (NSString *)string;
- (NSUInteger) indentColumnsForLineAtIndex: (NSUInteger)index
                                forString: (NSString *)string;
- (NSInteger) indentForLineAtIndex: (NSInteger)index
                        forString: (NSString *)string;
- (NSInteger) indentAfterNewlineAtIndex: (NSInteger)index
                             forString: (NSString *)string;
- (NSInteger) indentForClosingDelimiterAtIndex: (NSInteger)index
                                    forString: (NSString *)string;
- (BOOL) lineBeforeIndexIsControlStatement: (NSInteger)index
                                forString: (NSString *)string;
- (NSInteger) lineStartIndexForIndex: (NSInteger)index
                          forString: (NSString *)string;
- (NSInteger) lineEndIndexForIndex: (NSInteger)index
                        forString: (NSString *)string;
- (void) shiftSelectedLinesForward: (BOOL)forward;
- (NSUInteger) indexByMovingSelectionEdge: (NSUInteger)index
                               direction: (NSInteger)direction
                                inString: (NSString *)string;
- (NSRange) selectionRangeWithAnchor: (NSUInteger)anchor point: (NSUInteger)point;
- (NSUInteger) movementOriginForSelection;
- (NSUInteger) movementEndForSelection;
- (void) setSelectionWithAnchor: (NSUInteger)anchor point: (NSUInteger)point;

@end

@implementation YCodeTextView

- (YCodeLanguage *) languageDefinition
{
  return [[YCodeLanguageRegistry sharedRegistry]
      languageForFile: _filePath ? _filePath : @"m"];
}

- (NSString *) codeForText: (NSString *)text
{
  YCodeLanguage *language = [self languageDefinition];
  return language ? [language codeByMaskingLiterals: text] : text;
}

- (id) initWithFrame: (NSRect)frame textContainer: (NSTextContainer *)container
{
  self = [super initWithFrame: frame textContainer: container];
  if (self)
    {
      _matchingDelimiterRange = NSMakeRange (NSNotFound, 0);
      NSNotificationCenter *center = [NSNotificationCenter defaultCenter];
      [center addObserver: self
                 selector: @selector (updateMatchingDelimiter:)
                     name: NSTextViewDidChangeSelectionNotification
                   object: self];
      [center addObserver: self
                 selector: @selector (delimiterTextChanged:)
                     name: NSTextStorageDidProcessEditingNotification
                   object: [self textStorage]];
      [center addObserver: self
                 selector: @selector (updateMatchingDelimiter:)
                     name: @"YCodeMatchingDelimitersDidChange"
                   object: nil];
    }
  return self;
}

- (void) delimiterTextChanged: (NSNotification *)notification
{
  if (!([[self textStorage] editedMask] & NSTextStorageEditedCharacters))
    return;
  DESTROY (_delimiterMatches);
  [NSObject cancelPreviousPerformRequestsWithTarget: self
                                           selector: @selector
                                           (updateMatchingDelimiter:)
                                             object: nil];
  [self performSelector: @selector (updateMatchingDelimiter:)
             withObject: nil
             afterDelay: 0];
}

- (void) updateMatchingDelimiter: (NSNotification *)notification
{
  NSString *text = [self string];
  NSLayoutManager *layout = [self layoutManager];
  [layout removeTemporaryAttribute: NSBackgroundColorAttributeName
                 forCharacterRange: NSMakeRange (0, [text length])];
  _matchingDelimiterRange = NSMakeRange (NSNotFound, 0);
  [self setNeedsDisplay: YES];
  NSRange selection = [self selectedRange];
  if (![YCodePreferences highlightMatchingDelimiters] || selection.length
      || selection.location > [text length])
    return;
  if (!_delimiterMatches)
    {
      NSString *code = [self codeForText: text];
      NSMutableDictionary *matches = [NSMutableDictionary dictionary];
      NSMutableArray *stack = [NSMutableArray array];
      NSUInteger i;
      for (i = 0; i < [code length]; i++)
        {
          unichar c = [code characterAtIndex: i];
          if (c == '(' || c == '[' || c == '{')
            [stack addObject: [NSNumber numberWithUnsignedInteger: i]];
          else if (c == ')' || c == ']' || c == '}')
            {
              NSNumber *opening = [stack lastObject];
              if (!opening)
                continue;
              unichar start =
                  [code characterAtIndex: [opening unsignedIntegerValue]];
              if ((start == '(' && c == ')') || (start == '[' && c == ']')
                  || (start == '{' && c == '}'))
                {
                  NSNumber *closing = [NSNumber numberWithUnsignedInteger: i];
                  [matches setObject: closing forKey: opening];
                  [matches setObject: opening forKey: closing];
                  [stack removeLastObject];
                }
              else
                [stack removeAllObjects];
            }
        }
      _delimiterMatches = [matches copy];
    }
  // Prefer the delimiter immediately before the caret, then the one after it.
  NSNumber *match = nil;
  if (selection.location)
    match = [_delimiterMatches
        objectForKey: [NSNumber
                         numberWithUnsignedInteger: selection.location - 1]];
  if (!match)
    match = [_delimiterMatches
        objectForKey: [NSNumber numberWithUnsignedInteger: selection.location]];
  if (match)
    {
      _matchingDelimiterRange = NSMakeRange ([match unsignedIntegerValue], 1);
      NSColor *color = [NSColor colorWithCalibratedRed: 1.0
                                                 green: 0.75
                                                  blue: 0.15
                                                 alpha: 0.55];
      [layout addTemporaryAttributes:
                  [NSDictionary
                      dictionaryWithObject: color
                                    forKey: NSBackgroundColorAttributeName]
                   forCharacterRange: NSMakeRange ([match unsignedIntegerValue],
                                                  1)];
    }
  [self setNeedsDisplay: YES];
}

#ifdef GNUSTEP
- (void) drawViewBackgroundInRect: (NSRect)rect
{
  [super drawViewBackgroundInRect: rect];
  // GNUstep's layout manager stores temporary background attributes but its
  // background renderer only reads attributes from the text storage.
  if (!_matchingDelimiterRange.length
      || NSMaxRange (_matchingDelimiterRange) > [[self string] length])
    return;
  NSUInteger count = 0;
  NSRect *rects = [[self layoutManager]
        rectArrayForCharacterRange: _matchingDelimiterRange
      withinSelectedCharacterRange: NSMakeRange (NSNotFound, 0)
                   inTextContainer: [self textContainer]
                         rectCount: &count];
  NSPoint origin = [self textContainerOrigin];
  [[NSColor colorWithCalibratedRed: 1.0 green: 0.75 blue: 0.15 alpha: 0.55] set];
  NSUInteger i;
  for (i = 0; i < count; i++)
    {
      NSRect highlight = NSOffsetRect (rects[i], origin.x, origin.y);
      if (NSIntersectsRect (highlight, rect))
        NSRectFillUsingOperation (highlight, NSCompositeSourceOver);
    }
}
#endif

- (NSUInteger) editorTabWidth
{
  [self loadIndentSettingsIfNeeded];

  return editorTabWidth;
}

- (NSUInteger) editorIndentWidth
{
  [self loadIndentSettingsIfNeeded];

  return editorIndentWidth;
}

- (BOOL) editorUsesTabs
{
  [self loadIndentSettingsIfNeeded];

  return editorUsesTabs;
}

- (void) tabPreferencesChanged: (NSNotification *)notification
{
  editorIndentSettingsLoaded = NO;
  [self updateEditorParagraphStyle];
  [self setNeedsDisplay: YES];
  [[[self enclosingScrollView] horizontalRulerView] setNeedsDisplay: YES];
}

- (void) loadIndentSettingsIfNeeded
{
  NSString *filePath;
  NSString *clangFormatPath;

  if (editorIndentSettingsLoaded)
    {
      return;
    }

  editorIndentSettingsLoaded = YES;
  [[NSNotificationCenter defaultCenter] removeObserver: self
                                                  name: @"YCodeTabsDidChange"
                                                object: nil];
  [[NSNotificationCenter defaultCenter]
      addObserver: self
         selector: @selector (tabPreferencesChanged:)
             name: @"YCodeTabsDidChange"
           object: nil];
  editorIndentWidth = [YCodePreferences tabWidth];
  editorTabWidth = [YCodePreferences tabWidth];
  editorUsesTabs = ![YCodePreferences useSpacesForTabs];

  filePath = _filePath;
  if (filePath == nil || ![YCodePreferences useProjectIndentation])
    {
      return;
    }

  clangFormatPath = [self clangFormatPathForFilePath: filePath];
  if (clangFormatPath != nil)
    {
      [self loadIndentSettingsFromClangFormatAtPath: clangFormatPath];
    }
}

- (NSString *) clangFormatPathForFilePath: (NSString *)filePath
{
  NSFileManager *fm;
  NSString *directory;

  fm = [NSFileManager defaultManager];
  directory = [filePath stringByDeletingLastPathComponent];
  while ([directory length] > 0)
    {
      NSString *candidate;
      NSString *parent;

      candidate = [directory stringByAppendingPathComponent: @".clang-format"];
      if ([fm isReadableFileAtPath: candidate])
        {
          return candidate;
        }

      parent = [directory stringByDeletingLastPathComponent];
      if ([parent isEqualToString: directory])
        {
          break;
        }
      directory = parent;
    }

  return nil;
}

- (void) loadIndentSettingsFromClangFormatAtPath: (NSString *)path
{
  NSString *contents;
  NSArray *lines;
  NSEnumerator *e;
  NSString *line;

  contents = [NSString stringWithContentsOfFile: path];
  if (contents == nil)
    {
      return;
    }

  lines = [contents componentsSeparatedByString: @"\n"];
  e = [lines objectEnumerator];
  while ((line = [e nextObject]) != nil)
    {
      NSRange commentRange;
      NSRange separatorRange;
      NSString *key;
      NSString *value;
      NSInteger number;

      commentRange = [line rangeOfString: @"#"];
      if (commentRange.location != NSNotFound)
        {
          line = [line substringToIndex: commentRange.location];
        }

      separatorRange = [line rangeOfString: @":"];
      if (separatorRange.location == NSNotFound)
        {
          continue;
        }

      key = [[line substringToIndex: separatorRange.location]
          stringByTrimmingCharactersInSet:
              [NSCharacterSet whitespaceAndNewlineCharacterSet]];
      value = [[line substringFromIndex: NSMaxRange (separatorRange)]
          stringByTrimmingCharactersInSet:
              [NSCharacterSet whitespaceAndNewlineCharacterSet]];
      if ([value hasPrefix: @"\""] && [value hasSuffix: @"\""] &&
          [value length] >= 2)
        {
          value =
              [value substringWithRange: NSMakeRange (1, [value length] - 2)];
        }

      number = [value integerValue];
      if ([key isEqualToString: @"IndentWidth"] && number > 0)
        {
          editorIndentWidth = number;
        }
      else if ([key isEqualToString: @"TabWidth"] && number > 0)
        {
          editorTabWidth = number;
        }
      else if ([key isEqualToString: @"UseTab"])
        {
          editorUsesTabs
              = !([value caseInsensitiveCompare: @"Never"] == NSOrderedSame ||
                  [value caseInsensitiveCompare: @"false"] == NSOrderedSame ||
                  [value caseInsensitiveCompare: @"No"] == NSOrderedSame);
        }
    }
}

- (NSString *) indentStringForColumnCount: (NSUInteger)columns
{
  NSMutableString *indentString;
  NSUInteger tabWidth;

  indentString = [NSMutableString string];
  tabWidth = [self editorTabWidth];
  if (tabWidth == 0)
    {
      tabWidth = EDITOR_TAB_WIDTH;
    }

  if ([self editorUsesTabs])
    {
      while (columns >= tabWidth)
        {
          [indentString appendString: @"\t"];
          columns -= tabWidth;
        }
    }
  while (columns > 0)
    {
      [indentString appendString: @" "];
      columns--;
    }

  return indentString;
}

- (NSInteger) leadingWhitespaceLengthOfLineAtIndex: (NSInteger)index
                                        forString: (NSString *)string
{
  NSInteger line_start;
  NSInteger offset;
  NSInteger string_length;

  line_start = [self lineStartIndexForIndex: index forString: string];
  string_length = [string length];

  for (offset = line_start; offset < string_length; offset++)
    {
      unichar c = [string characterAtIndex: offset];

      if (c != ' ' && c != '\t')
        {
          break;
        }
    }

  return offset - line_start;
}

- (NSUInteger) indentColumnsForLineAtIndex: (NSUInteger)index
                                forString: (NSString *)string
{
  NSUInteger start = [self lineStartIndexForIndex: index forString: string];
  NSUInteger length = [self leadingWhitespaceLengthOfLineAtIndex: index
                                                       forString: string];
  NSUInteger columns = 0;
  NSUInteger tabWidth = [self editorTabWidth];
  NSUInteger i;
  for (i = start; i < start + length; i++)
    columns += [string characterAtIndex: i] == '\t'
                   ? tabWidth - columns % tabWidth
                   : 1;
  return columns;
}

- (NSInteger) indentForLineAtIndex: (NSInteger)index forString: (NSString *)string
{
  if (![[[self languageDefinition] indentationStyle] isEqual: @"braces"])
    return [self indentColumnsForLineAtIndex: index forString: string];
  NSInteger depth = 0;
  NSString *code = [self codeForText: string];
  NSInteger offset;
  index = MIN (index, (NSInteger)[string length]);
  for (offset = index - 1; offset >= 0; offset--)
    {
      unichar c = [code characterAtIndex: offset];
      if (c == '}')
        depth++;
      else if (c == '{')
        {
          if (depth == 0)
            {
              NSInteger indent = [self indentColumnsForLineAtIndex: offset
                                                         forString: string];
              if ([self lineStartIndexForIndex: offset forString: string] ==
                  [self lineStartIndexForIndex: index forString: string])
                return indent;
              return indent + [YCodePreferences controlIndentWidth];
            }
          depth--;
        }
    }
  // In the absence of an enclosing delimiter, retain the last nonblank indent.
  for (offset = index - 1; offset >= 0; offset--)
    if (![[NSCharacterSet whitespaceAndNewlineCharacterSet]
            characterIsMember: [string characterAtIndex: offset]])
      return [self indentColumnsForLineAtIndex: offset forString: string];
  return 0;
}

- (NSInteger) indentAfterNewlineAtIndex: (NSInteger)index
                             forString: (NSString *)string
{
  NSInteger offset = [self indentForLineAtIndex: index forString: string];
  NSString *code = [self codeForText: [string substringToIndex: index]];
  NSString *line = [[code
      substringFromIndex: [self lineStartIndexForIndex: index forString: string]]
      stringByTrimmingCharactersInSet: [NSCharacterSet whitespaceCharacterSet]];

  NSString *style = [[self languageDefinition] indentationStyle];
  if ([style isEqual: @"colon"] || [style isEqual: @"blocks"])
    {
      NSRegularExpression *rule =
          [[self languageDefinition] patternForToken: @"indentAfter"];
      if ([rule firstMatchInString: line
                           options: 0
                             range: NSMakeRange (0, [line length])])
        offset += [YCodePreferences controlIndentWidth];
      return offset;
    }
  if (![style isEqual: @"braces"])
    return offset;
  if ([line hasSuffix: @"{"])
    offset = [self indentColumnsForLineAtIndex: index forString: string] +
             [YCodePreferences controlIndentWidth];
  else if ([line hasPrefix: @"}"])
    {
      NSInteger columns = [self indentColumnsForLineAtIndex: index
                                                  forString: string];
      offset = MAX (0, columns
                           - (NSInteger)[YCodePreferences controlIndentWidth]);
    }
  else if ([self lineBeforeIndexIsControlStatement: index forString: code])
    offset = [self indentColumnsForLineAtIndex: YCodeControlStatementIndex (
                                                   code, index)
                                     forString: string]
             + [YCodePreferences controlIndentWidth];

  return offset;
}

- (NSInteger) indentForClosingDelimiterAtIndex: (NSInteger)index
                                    forString: (NSString *)string
{
  NSInteger offset;
  NSInteger level;
  NSInteger string_length;
  unichar closing_delimiter;
  unichar opening_delimiter;

  string_length = [string length];
  if (string_length == 0 || index < 0 || index >= string_length)
    {
      return 0;
    }

  closing_delimiter = [string characterAtIndex: index];
  opening_delimiter = OpeningDelimiterForClosingDelimiter (closing_delimiter);
  if (opening_delimiter == 0)
    {
      return 0;
    }

  NSString *code = [self codeForText: string];
  level = 0;
  for (offset = index - 1; offset >= 0; offset--)
    {
      unichar c = [code characterAtIndex: offset];

      if (c == closing_delimiter)
        {
          level++;
        }
      else if (c == opening_delimiter)
        {
          if (level == 0)
            {
              return [self indentColumnsForLineAtIndex: offset
                                             forString: string];
            }
          level--;
        }
      else if (IsClosingDelimiter (c))
        {
          unichar other_opening_delimiter;

          other_opening_delimiter = OpeningDelimiterForClosingDelimiter (c);
          while (offset > 0)
            {
              offset--;
              c = [code characterAtIndex: offset];
              if (c == other_opening_delimiter)
                {
                  break;
                }
            }
        }
    }

  return 0;
}

- (BOOL) lineBeforeIndexIsControlStatement: (NSInteger)index
                                forString: (NSString *)string
{
  NSArray *keywords;
  NSInteger line_start;
  NSInteger line_end;
  NSInteger string_length;
  NSInteger target_index;
  NSString *line;
  NSString *keyword;
  NSEnumerator *e;

  if (![[[self languageDefinition] indentationStyle] isEqual: @"braces"])
    return NO;
  string = [self codeForText: string];
  string_length = [string length];
  if (string_length == 0 || index <= 0)
    {
      return NO;
    }

  if (index > string_length)
    {
      index = string_length;
    }

  target_index = index - 1;
  if (target_index < 0)
    {
      return NO;
    }

  target_index = YCodeControlStatementIndex (string, index);
  line_start = [self lineStartIndexForIndex: target_index forString: string];
  line_end = index;
  if (line_end <= line_start)
    {
      return NO;
    }

  line = [[string
      substringWithRange: NSMakeRange (line_start, line_end - line_start)]
      stringByTrimmingCharactersInSet: [NSCharacterSet
                                          whitespaceAndNewlineCharacterSet]];
  if ([line length] == 0 || [line hasSuffix: @";"] || [line hasSuffix: @"{"])
    {
      return NO;
    }

  if ([[[self languageDefinition] standaloneControls] containsObject: line])
    return YES;
  if ([line hasPrefix: @"else "] || [line hasPrefix: @"else\t"])
    line = [[line substringFromIndex: 4]
        stringByTrimmingCharactersInSet: [NSCharacterSet
                                            whitespaceAndNewlineCharacterSet]];
  keywords = [[self languageDefinition] controlKeywords];
  e = [keywords objectEnumerator];
  while ((keyword = [e nextObject]) != nil)
    {
      if (![line hasPrefix: keyword])
        continue;
      NSString *condition = [[line substringFromIndex: [keyword length]]
          stringByTrimmingCharactersInSet:
              [NSCharacterSet whitespaceAndNewlineCharacterSet]];
      if (![condition hasPrefix: @"("])
        continue;
      NSInteger depth = 0;
      NSUInteger i;
      for (i = 0; i < [condition length]; i++)
        {
          unichar c = [condition characterAtIndex: i];
          if (c == '(')
            depth++;
          else if (c == ')')
            {
              depth--;
              if (depth == 0)
                return i == [condition length] - 1;
            }
        }
    }

  return NO;
}

- (void) shiftSelectedLinesForward: (BOOL)forward
{
  NSString *string;
  NSRange selected_range;
  NSUInteger line_start;
  NSUInteger line_end;
  NSUInteger contents_end;
  NSUInteger edit_end_index;
  NSRange edit_range;
  NSMutableString *replacement;
  NSUInteger cursor;
  NSUInteger tab_width;

  selected_range = [self selectedRange];
  if (selected_range.length == 0)
    {
      if (forward)
        {
          string = [self string];
          if ([string length] == 0)
            {
              [self
                  insertSpaceFillAlignedAtTabsOfSize: [self editorIndentWidth]];
            }
          else
            {
              [self performIndentation];
            }
          return;
        }
    }

  string = [self string];
  if ([string length] == 0)
    {
      return;
    }

  [string getLineStart: &line_start
                   end: NULL
           contentsEnd: NULL
              forRange: NSMakeRange (selected_range.location, 0)];

  edit_end_index = NSMaxRange (selected_range);
  if (edit_end_index > selected_range.location
      && edit_end_index <= [string length] &&
      [string characterAtIndex: edit_end_index - 1] == '\n')
    {
      edit_end_index--;
    }
  if (edit_end_index > [string length])
    {
      edit_end_index = [string length];
    }

  [string getLineStart: NULL
                   end: &line_end
           contentsEnd: NULL
              forRange: NSMakeRange (edit_end_index, 0)];
  edit_range = NSMakeRange (line_start, line_end - line_start);
  replacement = [[NSMutableString alloc]
      initWithCapacity: edit_range.length + [self editorIndentWidth]];
  tab_width = [self editorIndentWidth];

  cursor = line_start;
  while (cursor < line_end)
    {
      NSUInteger next_line_start;
      NSUInteger line_length;

      [string getLineStart: NULL
                       end: &next_line_start
               contentsEnd: &contents_end
                  forRange: NSMakeRange (cursor, 0)];
      if (next_line_start <= cursor)
        {
          break;
        }
      line_length = next_line_start - cursor;

      NSUInteger whitespace =
          [self leadingWhitespaceLengthOfLineAtIndex: cursor forString: string];
      NSUInteger columns = [self indentColumnsForLineAtIndex: cursor
                                                   forString: string];
      columns = forward ? columns + tab_width
                        : (columns > tab_width ? columns - tab_width : 0);
      [replacement appendString: [self indentStringForColumnCount: columns]];
      [replacement
          appendString: [string
                           substringWithRange: NSMakeRange (cursor + whitespace,
                                                           line_length
                                                               - whitespace)]];

      cursor = next_line_start;
    }

  if (![[string substringWithRange: edit_range] isEqualToString: replacement] &&
      [self shouldChangeTextInRange: edit_range replacementString: replacement])
    {
      NSUInteger oldWhitespace =
          [self leadingWhitespaceLengthOfLineAtIndex: line_start
                                           forString: string];
      [[self textStorage] replaceCharactersInRange: edit_range
                                        withString: replacement];
      if (selected_range.length == 0)
        {
          NSUInteger newWhitespace =
              [self leadingWhitespaceLengthOfLineAtIndex: 0
                                               forString: replacement];
          NSUInteger column = selected_range.location - line_start;
          NSUInteger cursor = column < oldWhitespace
                                  ? MIN (column, newWhitespace)
                                  : column - oldWhitespace + newWhitespace;
          [self setSelectedRange: NSMakeRange (line_start + cursor, 0)];
        }
      else
        [self setSelectedRange: NSMakeRange (line_start, [replacement length])];
      [self didChangeText];
    }

  [replacement release];
}

- (NSUInteger) indexByMovingSelectionEdge: (NSUInteger)index
                               direction: (NSInteger)direction
                                inString: (NSString *)string
{
  NSUInteger string_length;
  NSUInteger line_start;
  NSUInteger line_end;
  NSUInteger target_line_start;
  NSUInteger target_contents_end;
  NSUInteger column;

  string_length = [string length];
  if (string_length == 0)
    {
      return 0;
    }

  if (index > string_length)
    {
      index = string_length;
    }

  [string getLineStart: &line_start
                   end: &line_end
           contentsEnd: NULL
              forRange: NSMakeRange (index, 0)];
  column = index - line_start;

  if (direction < 0)
    {
      if (line_start == 0)
        {
          return index;
        }

      [string getLineStart: &target_line_start
                       end: NULL
               contentsEnd: &target_contents_end
                  forRange: NSMakeRange (line_start - 1, 0)];
    }
  else
    {
      if (line_end >= string_length
          && (string_length == 0 ||
              [string characterAtIndex: string_length - 1] != '\n'
              || line_start == string_length))
        {
          return index;
        }

      [string getLineStart: &target_line_start
                       end: NULL
               contentsEnd: &target_contents_end
                  forRange: NSMakeRange (line_end, 0)];
    }

  if (column > target_contents_end - target_line_start)
    {
      column = target_contents_end - target_line_start;
    }

  return target_line_start + column;
}

- (NSRange) selectionRangeWithAnchor: (NSUInteger)anchor point: (NSUInteger)point
{
  if (point < anchor)
    {
      return NSMakeRange (point, anchor - point);
    }

  return NSMakeRange (anchor, point - anchor);
}

- (NSUInteger) movementOriginForSelection
{
  NSRange range = [self selectedRange];

  if ([self selectionAffinity] == NSSelectionAffinityUpstream)
    {
      return range.location;
    }

  return NSMaxRange (range);
}

- (NSUInteger) movementEndForSelection
{
  NSRange range = [self selectedRange];

  if ([self selectionAffinity] == NSSelectionAffinityDownstream)
    {
      return range.location;
    }

  return NSMaxRange (range);
}

- (void) setSelectionWithAnchor: (NSUInteger)anchor point: (NSUInteger)point
{
  NSSelectionAffinity affinity;
  NSRange range;

  range = [self selectionRangeWithAnchor: anchor point: point];
  affinity = (anchor < point) ? NSSelectionAffinityDownstream
                              : NSSelectionAffinityUpstream;

  [self setSelectedRange: range affinity: affinity stillSelecting: YES];
  [self scrollRangeToVisible: NSMakeRange (point, 0)];
}

/**
 * Makes the receiver insert as many spaces at the current insertion
 * location as are required to reach the nearest tab-character boundary.
 *
 * @argument tabSize Specifies how many spaces represent one tab.
 */
- (void) insertSpaceFillAlignedAtTabsOfSize: (unsigned int)tabSize
{
  NSString *string = [self string];
  NSUInteger location = [self selectedRange].location;
  NSUInteger start = [self lineStartIndexForIndex: location forString: string];
  NSUInteger columns = 0;
  NSUInteger tabWidth = [self editorTabWidth];
  NSUInteger i;
  for (i = start; i < location; i++)
    columns += [string characterAtIndex: i] == '\t'
                   ? tabWidth - columns % tabWidth
                   : 1;
  NSUInteger skip = tabSize - columns % tabSize;
  if ([self editorUsesTabs] && skip == tabSize)
    [super insertText: @"\t"];
  else
    [super insertText: [@"" stringByPaddingToLength: skip
                                        withString: @" "
                                   startingAtIndex: 0]];
}

// Go backward to first '\n' char or start of file
- (NSInteger) lineStartIndexForIndex: (NSInteger)index
                          forString: (NSString *)string
{
  NSUInteger start;
  index = MAX (0, MIN (index, (NSInteger)[string length]));
  [string getLineStart: &start
                   end: NULL
           contentsEnd: NULL
              forRange: NSMakeRange (index, 0)];
  return start;
}

- (NSInteger) lineEndIndexForIndex: (NSInteger)index forString: (NSString *)string
{
  NSUInteger end;
  index = MAX (0, MIN (index, (NSInteger)[string length]));
  [string getLineStart: NULL
                   end: NULL
           contentsEnd: &end
              forRange: NSMakeRange (index, 0)];
  return end;
}

- (void) performIndentation
{
  NSString *string = [self string];
  NSRange selection = [self selectedRange];
  NSUInteger start = [self lineStartIndexForIndex: selection.location
                                        forString: string];
  NSUInteger length =
      [self leadingWhitespaceLengthOfLineAtIndex: selection.location
                                       forString: string];
  NSUInteger first = start + length;
  unichar c = first < [string length] ? [string characterAtIndex: first] : 0;
  NSInteger columns = [self indentForLineAtIndex: start forString: string];
  if (IsClosingDelimiter (c))
    columns = [self indentForClosingDelimiterAtIndex: first forString: string];
  else if ([self lineBeforeIndexIsControlStatement: start forString: string])
    columns =
        [self indentColumnsForLineAtIndex: YCodeControlStatementIndex (
                                              [self codeForText: string], start)
                                forString: string]
        + [YCodePreferences controlIndentWidth];
  NSString *indent = [self lineBeforeIndexIsControlStatement: start
                                                   forString: string]
                             && !IsClosingDelimiter (c)
                         ? [@"" stringByPaddingToLength: MAX (0, columns)
                                             withString: @" "
                                        startingAtIndex: 0]
                         : [self indentStringForColumnCount: MAX (0, columns)];
  NSRange whitespace = NSMakeRange (start, length);
  if ([[string substringWithRange: whitespace] isEqualToString: indent])
    return;
  if ([self shouldChangeTextInRange: whitespace replacementString: indent])
    {
      [[self textStorage] replaceCharactersInRange: whitespace
                                        withString: indent];
      NSUInteger cursor = selection.location < first
                              ? start + [indent length]
                              : selection.location - length + [indent length];
      [self setSelectedRange: NSMakeRange (cursor, 0)];
      [self didChangeText];
    }
}

- (void) dealloc
{
  [[NSNotificationCenter defaultCenter] removeObserver: self];
  [NSObject cancelPreviousPerformRequestsWithTarget: self];
  RELEASE (_delimiterMatches);
  RELEASE (_filePath);
  [super dealloc];
}

- (void) setFilePath: (NSString *)path
{
  ASSIGN (_filePath, path);
  DESTROY (_delimiterMatches);
  [self updateMatchingDelimiter: nil];
  editorIndentSettingsLoaded = NO;
  [self updateEditorParagraphStyle];
}

- (void) setEditorTabWidth: (NSUInteger)width
{
  [self loadIndentSettingsIfNeeded];
  editorTabWidth = MAX (1, width);
  [self updateEditorParagraphStyle];
}

- (void) setEditorUsesTabs: (BOOL)usesTabs
{
  [self loadIndentSettingsIfNeeded];
  editorUsesTabs = usesTabs;
  [self updateEditorParagraphStyle];
}

- (void) setFont: (NSFont *)font
{
  [super setFont: font];
  [self updateEditorParagraphStyle];
}

- (void) viewDidMoveToSuperview
{
  [super viewDidMoveToSuperview];
  NSNotificationCenter *center = [NSNotificationCenter defaultCenter];
  [center removeObserver: self
                    name: NSViewFrameDidChangeNotification
                  object: nil];
  NSView *clip = [self superview];
  if ([clip isKindOfClass: [NSClipView class]])
    {
      [clip setPostsFrameChangedNotifications: YES];
      [center addObserver: self
                 selector: @selector (viewportDidResize:)
                     name: NSViewFrameDidChangeNotification
                   object: clip];
      [self sizeToFit];
    }
}

- (void) viewportDidResize: (NSNotification *)notification
{
  [self sizeToFit];
}

- (void) sizeToFit
{
  if (_fittingViewport)
    return;
  _fittingViewport = YES;
  NSView *clip = [self superview];
  if ([clip isKindOfClass: [NSClipView class]])
    [self setMinSize: [clip bounds].size];
  [super sizeToFit];
  _fittingViewport = NO;
}

- (CGFloat) editorCharacterWidth
{
  CGFloat width;

  width = [[self font] widthOfString: @"8"];
  if (width <= 0.0)
    {
      width = [[NSFont userFixedPitchFontOfSize: 0.0] widthOfString: @"8"];
    }
  if (width <= 0.0)
    {
      width = 8.0;
    }

  return width;
}

- (NSParagraphStyle *) editorParagraphStyle
{
  NSMutableParagraphStyle *style;

  style = [[[NSParagraphStyle defaultParagraphStyle] mutableCopy] autorelease];
  [style setTabStops: [NSArray array]];
  [style setDefaultTabInterval: [self editorCharacterWidth] *
                               [self editorTabWidth]];

  return style;
}

- (void) updateEditorParagraphStyle
{
  NSParagraphStyle *style;
  NSMutableDictionary *typingAttributes;
  NSTextStorage *storage;
  NSUInteger length;

  style = [self editorParagraphStyle];
  [self setDefaultParagraphStyle: style];

  typingAttributes = [[[self typingAttributes] mutableCopy] autorelease];
  if (typingAttributes == nil)
    {
      typingAttributes = [NSMutableDictionary dictionary];
    }
  [typingAttributes setObject: style forKey: NSParagraphStyleAttributeName];
  [self setTypingAttributes: typingAttributes];

  storage = [self textStorage];
  length = [storage length];
  if (length > 0)
    {
      [storage addAttribute: NSParagraphStyleAttributeName
                      value: style
                      range: NSMakeRange (0, length)];
    }
}

- (void) cancelOperation: (id)sender
{
  // ignore ESC char
}

- (void) insertNewline: (id)sender
{
  [self alignBlockClosingLine];
  NSInteger location = [self selectedRange].location;
  int offset = [self indentAfterNewlineAtIndex: location
                                     forString: [self string]];
  NSMutableString *replacement;

  replacement = [NSMutableString stringWithString: @"\n"];
  NSString *code =
      [self codeForText: [[self string] substringToIndex: location]];
  NSString *line = [[code
      substringFromIndex: [self lineStartIndexForIndex: location forString: code]]
      stringByTrimmingCharactersInSet: [NSCharacterSet whitespaceCharacterSet]];
  BOOL spaces =
      [[[self languageDefinition] indentationStyle] isEqual: @"colon"] ||
      [[[self languageDefinition] indentationStyle] isEqual: @"blocks"] ||
      [line hasSuffix: @"{"] ||
      [self lineBeforeIndexIsControlStatement: location forString: code]
      || ([line hasPrefix: @"}"] && ![line hasSuffix: @"{"]);
  [replacement appendString: spaces ? [@"" stringByPaddingToLength: offset
                                                       withString: @" "
                                                  startingAtIndex: 0]
                                   : [self indentStringForColumnCount: offset]];
  [self insertText: replacement];
}

- (void) insertText: (id)insertString
{
  NSString *text;
  NSString *string;
  NSRange selected_range;
  NSInteger line_start;
  NSInteger offset;
  BOOL should_indent;

  text = nil;
  if ([insertString isKindOfClass: [NSString class]])
    {
      text = insertString;
    }
  else if ([insertString respondsToSelector: @selector (string)])
    {
      text = [insertString string];
    }

  selected_range = [self selectedRange];
  should_indent = NO;
  if (![[[self languageDefinition] indentationStyle] isEqual: @"preserve"] &&
      [self languageDefinition] != nil && text != nil && [text length] == 1
      && IsClosingDelimiter ([text characterAtIndex: 0]))
    {
      string = [self string];
      line_start = [self lineStartIndexForIndex: selected_range.location
                                      forString: string];
      should_indent = YES;
      for (offset = line_start; offset < selected_range.location; offset++)
        {
          if (![[NSCharacterSet whitespaceCharacterSet]
                  characterIsMember: [string characterAtIndex: offset]])
            {
              should_indent = NO;
              break;
            }
        }
    }

  [super insertText: insertString];
  [self alignBlockClosingLine];

  if (should_indent)
    {
      [self performIndentation];
    }
}

/* Block languages align a closing/middle keyword with its opening line.
 * Derive the target from preceding code, so repeated edits never dedent twice. */
- (void) alignBlockClosingLine
{
  YCodeLanguage *language = [self languageDefinition];
  if (![[language indentationStyle] isEqual: @"blocks"])
    return;
  NSRange selection = [self selectedRange];
  if (selection.length)
    return;
  NSString *text = [self string];
  NSString *code = [self codeForText: text];
  NSUInteger start = [self lineStartIndexForIndex: selection.location
                                        forString: text];
  NSString *line = [code
      substringWithRange: NSMakeRange (start, selection.location - start)];
  NSRegularExpression *closing = [language patternForToken: @"indentBefore"];
  if (![closing firstMatchInString: line
                           options: 0
                             range: NSMakeRange (0, [line length])])
    return;
  NSRegularExpression *opening = [language patternForToken: @"indentAfter"];
  NSMutableArray *stack = [NSMutableArray array];
  NSUInteger i = 0;
  while (i < start)
    {
      NSRange range = [code lineRangeForRange: NSMakeRange (i, 0)];
      NSString *previous = [[code substringWithRange: range]
          stringByTrimmingCharactersInSet: [NSCharacterSet
                                              newlineCharacterSet]];
      if ([closing firstMatchInString: previous
                              options: 0
                                range: NSMakeRange (0, [previous length])]
          && [stack count])
        [stack removeLastObject];
      if ([opening firstMatchInString: previous
                              options: 0
                                range: NSMakeRange (0, [previous length])])
        [stack
            addObject: [NSNumber numberWithUnsignedInteger:
                                    [self indentColumnsForLineAtIndex: i
                                                            forString: text]]];
      i = NSMaxRange (range);
    }
  if (![stack count])
    return;
  NSUInteger columns = [[stack lastObject] unsignedIntegerValue];
  NSUInteger length = [self leadingWhitespaceLengthOfLineAtIndex: start
                                                       forString: text];
  NSString *indent = [@"" stringByPaddingToLength: columns
                                       withString: @" "
                                  startingAtIndex: 0];
  NSRange range = NSMakeRange (start, length);
  if ([[text substringWithRange: range] isEqual: indent])
    return;
  if ([self shouldChangeTextInRange: range replacementString: indent])
    {
      [[self textStorage] replaceCharactersInRange: range withString: indent];
      [self didChangeText];
      [self setSelectedRange: NSMakeRange (selection.location - length +
                                              [indent length],
                                          0)];
    }
}

- (BOOL) validateMenuItem: (NSMenuItem *)item
{
  if ([item action] == @selector (toggleLineComment:))
    return [self isEditable] &&
           [[[self languageDefinition] lineComment] length] > 0;
  return [super validateMenuItem: item];
}

- (IBAction) toggleLineComment: (id)sender
{
  NSString *marker = [[self languageDefinition] lineComment];
  if (![self isEditable] || ![marker length])
    return;
  NSString *text = [self string];
  NSRange selection = [self selectedRange];
  /* A selection ending at column zero does not include the following line. */
  NSRange selectedLines = selection;
  if (selectedLines.length)
    selectedLines.length--;
  NSRange range = [text lineRangeForRange: selectedLines];
  NSString *original = [text substringWithRange: range];
  NSMutableArray *lines = [NSMutableArray array];
  NSUInteger offset = 0;
  BOOL allCommented = YES, anyContent = NO;
  while (offset < [original length])
    {
      NSRange lineRange = [original lineRangeForRange: NSMakeRange (offset, 0)];
      NSString *line = [original substringWithRange: lineRange];
      [lines addObject: line];
      NSString *trimmed =
          [line stringByTrimmingCharactersInSet:
                    [NSCharacterSet whitespaceAndNewlineCharacterSet]];
      if ([trimmed length])
        {
          anyContent = YES;
          if (![trimmed hasPrefix: marker])
            allCommented = NO;
        }
      offset = NSMaxRange (lineRange);
    }
  if (!anyContent)
    return;
  NSMutableString *replacement = [NSMutableString string];
  NSEnumerator *e = [lines objectEnumerator];
  NSString *line;
  while ((line = [e nextObject]))
    {
      NSUInteger i = 0;
      while (i < [line length]
             && ([line characterAtIndex: i] == ' ' ||
                 [line characterAtIndex: i] == '\t'))
        i++;
      NSString *rest = [line substringFromIndex: i];
      [replacement appendString: [line substringToIndex: i]];
      if ([[rest stringByTrimmingCharactersInSet: [NSCharacterSet
                                                     newlineCharacterSet]]
              length])
        {
          if (allCommented)
            {
              rest = [rest substringFromIndex: [marker length]];
              if ([rest hasPrefix: @" "])
                rest = [rest substringFromIndex: 1];
            }
          else
            [replacement appendFormat: @"%@ ", marker];
        }
      [replacement appendString: rest];
    }
  if ([self shouldChangeTextInRange: range replacementString: replacement])
    {
      [[self textStorage] replaceCharactersInRange: range
                                        withString: replacement];
      [self didChangeText];
      [self
          setSelectedRange: NSMakeRange (range.location, [replacement length])];
      [[self undoManager]
          setActionName: allCommented ? @"Uncomment Lines" : @"Comment Lines"];
    }
}

- (IBAction) convertTabsToSpaces: (id)sender
{
  if (![self isEditable])
    return;
  NSString *text = [self string];
  if ([text rangeOfString: @"\t"].location == NSNotFound)
    return;
  NSMutableString *result = [NSMutableString string];
  NSRange selection = [self selectedRange];
  NSUInteger newStart = 0, newEnd = 0, column = 0, i;
  NSUInteger width = [self editorTabWidth];
  for (i = 0; i <= [text length]; i++)
    {
      if (i == selection.location)
        newStart = [result length];
      if (i == NSMaxRange (selection))
        newEnd = [result length];
      if (i == [text length])
        break;
      unichar c = [text characterAtIndex: i];
      if (c == '\t')
        {
          NSUInteger spaces = width - column % width;
          [result appendString: [@"" stringByPaddingToLength: spaces
                                                 withString: @" "
                                            startingAtIndex: 0]];
          column += spaces;
        }
      else
        {
          [result appendString: [text substringWithRange: NSMakeRange (i, 1)]];
          if (c == '\n' || c == '\r')
            column = 0;
          else
            column++;
        }
    }
  NSUndoManager *undo = [self undoManager];
  [undo beginUndoGrouping];
  NSRange range = NSMakeRange (0, [text length]);
  if ([self shouldChangeTextInRange: range replacementString: result])
    {
      [[self textStorage] replaceCharactersInRange: range withString: result];
      [self setSelectedRange: NSMakeRange (newStart, newEnd - newStart)];
      [self didChangeText];
      [undo setActionName: @"Convert Tabs to Spaces"];
    }
  [undo endUndoGrouping];
}

- (void) insertTab: (id)sender
{
  [self shiftSelectedLinesForward: YES];
}

- (void) insertBacktab: (id)sender
{
  [self shiftSelectedLinesForward: NO];
}

- (void) moveUpAndModifySelection: (id)sender
{
  NSString *string;
  NSUInteger anchor;
  NSUInteger point;

  string = [self string];
  anchor = [self movementEndForSelection];
  point = [self indexByMovingSelectionEdge: [self movementOriginForSelection]
                                 direction: -1
                                  inString: string];
  [self setSelectionWithAnchor: anchor point: point];
}

- (void) moveDownAndModifySelection: (id)sender
{
  NSString *string;
  NSUInteger anchor;
  NSUInteger point;

  string = [self string];
  anchor = [self movementEndForSelection];
  point = [self indexByMovingSelectionEdge: [self movementOriginForSelection]
                                 direction: 1
                                  inString: string];
  [self setSelectionWithAnchor: anchor point: point];
}

- (void) moveBackwardAndModifySelection: (id)sender
{
  NSUInteger anchor;
  NSUInteger point;

  anchor = [self movementEndForSelection];
  point = [self movementOriginForSelection];
  if (point > 0)
    {
      point--;
    }

  [self setSelectionWithAnchor: anchor point: point];
}

- (void) moveForwardAndModifySelection: (id)sender
{
  NSUInteger anchor;
  NSUInteger point;
  NSUInteger length;

  anchor = [self movementEndForSelection];
  point = [self movementOriginForSelection];
  length = [[self string] length];
  if (point < length)
    {
      point++;
    }

  [self setSelectionWithAnchor: anchor point: point];
}

- (void) moveLeftAndModifySelection: (id)sender
{
  [self moveBackwardAndModifySelection: sender];
}

- (void) moveRightAndModifySelection: (id)sender
{
  [self moveForwardAndModifySelection: sender];
}

@end
