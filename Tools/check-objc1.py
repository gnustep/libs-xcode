#!/usr/bin/env python3
"""Audit GNUstep sources with Clang's AST and compile C sources in GNU99 mode.

This checks source-language compatibility, not legacy-runtime binary linkage.
GNUstep development headers, Clang, and GCC must be installed. Conditional
macOS/Windows code still needs verification on those platforms.
"""

import concurrent.futures
import pathlib
import re
import shlex
import subprocess
import sys


ROOT = pathlib.Path(__file__).resolve().parents[1]
MODERN_EXPRESSIONS = re.compile(
    r'\b(?:ObjCPropertyRefExpr|ObjCSubscriptRefExpr|ObjCArrayLiteral|'
    r'ObjCDictionaryLiteral|ObjCBoxedExpr|ObjCForCollectionStmt|'
    r'ObjCAutoreleasePoolStmt|BlockExpr)\b'
)


def main():
    flags = shlex.split(subprocess.check_output(['gnustep-config', '--objc-flags'], text=True))
    flags = [flag for flag in flags if flag not in ('-MMD', '-MP')]
    includes = ['-I.', '-IXCode', '-IApplications/ycode', '-ITools/buildtool',
                '-IApplications/ycode/Terminal/libvterm/include']
    paths = subprocess.check_output(['git', 'ls-files', '-z'], cwd=ROOT).decode().split('\0')
    paths = [path for path in paths if pathlib.Path(path).suffix in ('.c', '.m')]

    def check(path):
        if path.endswith('.c'):
            command = ['gcc', '-std=gnu99', '-fsyntax-only', *includes, path]
        else:
            command = ['clang', *flags, *includes, '-std=gnu99', '-fno-objc-arc',
                       '-fsyntax-only', '-Xclang', '-ast-dump', path]
        result = subprocess.run(command, cwd=ROOT, text=True, capture_output=True)
        expressions = [line for line in result.stdout.splitlines()
                       if MODERN_EXPRESSIONS.search(line)]
        return path, result.returncode, result.stderr, expressions

    failures = 0
    with concurrent.futures.ThreadPoolExecutor(max_workers=4) as pool:
        for path, status, diagnostics, expressions in pool.map(check, paths):
            if status or expressions:
                failures += 1
                print(path + ': FAILED')
                print(diagnostics + '\n'.join(expressions))
    print('%d translation units audited; %d failures' % (len(paths), failures))
    return bool(failures)


if __name__ == '__main__':
    sys.exit(main())
