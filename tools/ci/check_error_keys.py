#!/usr/bin/env python3
"""Mọi mã lỗi backend ("error.module.reason") phải có bản dịch vi + en trong frontend/lib/core/utils/error_utils.dart.

Cùng quy tắc với frontend/test/error_translations_test.dart (chạy khi frontend đổi); script này chạy ở CI
backend để bắt trường hợp thêm mã lỗi mới mà quên bản dịch. Tra theo tiền tố như error_utils (error.a.b.c → error.a.b).

  python3 tools/ci/check_error_keys.py
"""
import glob
import os
import re
import sys

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), '..', '..'))
KEY = re.compile(r'"(error\.[a-z0-9_]+(?:\.[a-z0-9_]+)+)(?=[|"])')
EXAMPLES = {'error.x.y'}  # ví dụ trong chú thích


def section(src, start, end=None):
    i = src.index(start)
    j = src.index(end, i) if end else src.index('};', i)
    return src[i:j]


def has(sec, key):
    while True:
        if "'%s':" % key in sec:
            return True
        dot = key.rfind('.')
        if dot <= len('error.'):
            return False
        key = key[:dot]


def main():
    keys = set()
    for f in glob.glob(os.path.join(ROOT, 'backend/src/main/java/**/*.java'), recursive=True):
        with open(f, encoding='utf-8') as fh:
            keys.update(KEY.findall(fh.read()))
    keys -= EXAMPLES
    with open(os.path.join(ROOT, 'frontend/lib/core/utils/error_utils.dart'), encoding='utf-8') as fh:
        src = fh.read()
    vi = section(src, 'const _viMessages', 'const _enMessages')
    en = section(src, 'const _enMessages')
    missing = sorted(k for k in keys if not has(vi, k) or not has(en, k))
    if missing:
        print('Thiếu bản dịch mã lỗi (vi/en) trong error_utils.dart:')
        for k in missing:
            print('  ' + k)
        return 1
    print(f'OK: {len(keys)} mã lỗi backend đều có bản dịch vi + en.')
    return 0


if __name__ == '__main__':
    sys.exit(main())
