#!/usr/bin/env python3
"""Format tracked C/Objective-C sources using GNU and GNUstep conventions.

Requires clang-format 19. With --check, report differences without writing.
Comments and string literals are preserved, including embedded source fixtures.
"""

import argparse
import pathlib
import re
import subprocess
import sys


ROOT = pathlib.Path(__file__).resolve().parents[1]
# Match comments and literals before punctuation so their contents stay opaque.
TOKEN = re.compile(
    r'/\*.*?\*/|//[^\n]*|@?"(?:\\.|[^"\\])*"|'
    r"'(?:\\.|[^'\\])*'|[A-Za-z_]\w*|\d+(?:\.\d+)?|"
    r'>>=|<<=|\.\.\.|->|\+\+|--|&&|\|\||==|!=|<=|>=|<<|>>|'
    r'\+=|-=|\*=|/=|%=|&=|\|=|\^=|##|[^\s]',
    re.DOTALL,
)


def tokens(source):
    return list(TOKEN.finditer(source))


def source_tokens(source):
    # Line splices are removed by the C preprocessor before tokenization.
    return [match.group().rstrip() if match.group().startswith('//') else match.group()
            for match in tokens(re.sub(r'\\\n', '', source))]


def prepare_directives(source):
    # Some old files put #import immediately after the license's closing */.
    # Put the directive on its own line before clang-format parses it.
    insertions = []
    for token in tokens(source):
        if token.group() == '#':
            start = source.rfind('\n', 0, token.start()) + 1
            if source[start:token.start()].strip().endswith('*/'):
                insertions.append(token.start())
    for position in reversed(insertions):
        source = source[:position].rstrip(' \t') + '\n\n' + source[position:]
    return source


def objc_spacing(source):
    """Add GNUstep spaces without editing comments, strings, or C tokens."""
    lexical = tokens(source)
    insertions = set()
    selector_colons = set()
    for index, token in enumerate(lexical):
        if (token.group() == '@' and index + 2 < len(lexical)
                and lexical[index + 1].group() == 'selector'
                and lexical[index + 2].group() == '('):
            for part in lexical[index + 3:]:
                if part.group() == ')':
                    break
                if part.group() == ':':
                    selector_colons.add(part.start())
    for index, token in enumerate(lexical):
        if (token.group() == ':' and token.start() not in selector_colons
                and index + 1 < len(lexical)):
            if token.end() == lexical[index + 1].start():
                insertions.add(token.end())
        # A method declaration/definition starts with + or - and a return type.
        if token.group() not in ('+', '-'):
            continue
        line_start = source.rfind('\n', 0, token.start()) + 1
        if source[line_start:token.start()].strip():
            continue
        if index + 1 >= len(lexical) or lexical[index + 1].group() != '(':
            continue
        depth = 0
        for next_index in range(index + 1, len(lexical)):
            following = lexical[next_index]
            if following.group() == '(':
                depth += 1
            elif following.group() == ')':
                depth -= 1
                if depth == 0:
                    if (next_index + 1 < len(lexical)
                            and following.end() == lexical[next_index + 1].start()
                            and re.fullmatch(r'[A-Za-z_]\w*', lexical[next_index + 1].group())):
                        insertions.add(following.end())
                    break
    for position in sorted(insertions, reverse=True):
        source = source[:position] + ' ' + source[position:]
    return source


def objc_block_spacing(source):
    """Keep a blank line after ivar blocks and method bodies in Ycode."""
    lexical = tokens(source)
    scope = None
    depth = 0
    insertions = []
    for index, token in enumerate(lexical):
        word = token.group()
        if word == '@' and index + 1 < len(lexical):
            directive = lexical[index + 1].group()
            if directive in ('interface', 'implementation'):
                scope = directive
            elif directive == 'end':
                scope = None
        if word == '{':
            depth += 1
        elif word == '}':
            depth -= 1
            if scope is not None and depth == 0:
                end = source.find('\n', token.end())
                if end != -1 and end + 1 < len(source):
                    # Do not split a continued preprocessor macro.
                    if source[token.end():end].rstrip().endswith('\\'):
                        continue
                    next_end = source.find('\n', end + 1)
                    if next_end == -1:
                        next_end = len(source)
                    if source[end + 1:next_end].strip():
                        insertions.append(end + 1)
    for position in reversed(insertions):
        source = source[:position] + '\n' + source[position:]
    return source


def modern_objc(source):
    """Reject modern syntax tokens, ignoring comments and literal contents.

    This lexical guard complements compiler checks; it does not type-check
    property access or distinguish object subscripting from C array access.
    """
    lexical = tokens(source)
    directives = {'property', 'synthesize', 'dynamic', 'autoreleasepool',
                  'optional', 'required', 'package', 'available'}
    qualifiers = {'instancetype', '__weak', '__strong', '__unsafe_unretained',
                  '__bridge', '__bridge_retained', '__bridge_transfer', '__block'}
    errors = []
    for index, token in enumerate(lexical):
        word = token.group()
        if word in qualifiers:
            errors.append((token.start(), word))
        if word == '@' and index + 1 < len(lexical):
            following = lexical[index + 1].group()
            if (following in directives or following in ('[', '{', '(', 'YES', 'NO', 'true', 'false')
                    or following[0].isdigit() or following.startswith("'")):
                errors.append((token.start(), '@' + following))
            if following == 'interface':
                declaration = [item.group() for item in lexical[index + 2:index + 5]]
                if len(declaration) == 3 and declaration[1:] == ['(', ')']:
                    errors.append((token.start(), 'class extension'))
    return errors


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--check', action='store_true')
    args = parser.parse_args()
    version = subprocess.check_output(['clang-format', '--version'], text=True)
    if not re.search(r'version 19\.', version):
        parser.error('clang-format 19 is required')
    paths = subprocess.check_output(['git', 'ls-files', '-z'], cwd=ROOT).decode().split('\0')
    paths = [path for path in paths if pathlib.Path(path).suffix in ('.c', '.h', '.m')]
    failures = 0
    changed = 0
    for name in paths:
        path = ROOT / name
        source = path.read_text()
        for position, construct in modern_objc(source):
            print('%s:%d: modern Objective-C construct %s' %
                  (name, source.count('\n', 0, position) + 1, construct))
            failures += 1
        result = subprocess.run(
            ['clang-format', '--style=file', '--assume-filename=' + str(path)],
            input=prepare_directives(source), text=True, capture_output=True, check=True,
        ).stdout
        if path.suffix in ('.h', '.m'):
            result = objc_spacing(result)
            if name.startswith('Applications/ycode/'):
                result = objc_block_spacing(result)
        # Formatting must not change tokens, comments, or literal contents.
        if source_tokens(source) != source_tokens(result):
            print(name + ': refused: formatter changed source tokens')
            failures += 1
            continue
        if source != result:
            changed += 1
            if args.check:
                print(name + ': formatting differs')
            else:
                path.write_text(result)
    print('%d source files checked; %d %s; %d syntax/token errors' %
          (len(paths), changed, 'need formatting' if args.check else 'formatted', failures))
    return 1 if failures or (args.check and changed) else 0


if __name__ == '__main__':
    sys.exit(main())
