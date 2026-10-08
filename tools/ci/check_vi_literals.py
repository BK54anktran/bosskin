#!/usr/bin/env python3
"""Chặn chuỗi tiếng Việt viết cứng trong code Flutter (frontend/lib/**/*.dart).

Chữ hiển thị phải đi qua l10n (app_vi.arb / app_en.arb); mã lỗi backend dịch ở error_utils.dart.
Code cũ còn chuỗi cứng được ghi trong baseline (số chuỗi theo từng file): CI fail khi một file
có NHIỀU chuỗi hơn baseline hoặc file mới có chuỗi tiếng Việt. Sửa bớt thì chạy --update để hạ baseline.

  python3 tools/ci/check_vi_literals.py           # kiểm tra
  python3 tools/ci/check_vi_literals.py --update  # ghi lại baseline theo hiện trạng
  python3 tools/ci/check_vi_literals.py --list FILE  # liệt kê chuỗi trong một file
"""
import json
import os
import re
import sys

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), '..', '..'))
LIB = os.path.join(ROOT, 'frontend', 'lib')
BASELINE = os.path.join(os.path.dirname(__file__), 'vi_literals_baseline.json')

# Bảng dịch hợp lệ — được phép chứa tiếng Việt
EXCLUDE_DIRS = {os.path.join(LIB, 'l10n')}
EXCLUDE_FILES = {os.path.join(LIB, 'core', 'utils', 'error_utils.dart')}

VI = re.compile('[À-ỹĐđ]')
# Chuỗi Dart: '...', "...", r'...', '''...''', """...""" (không xét lồng ${} phức tạp — đủ cho mục đích đếm)
STRING = re.compile(r"""r?('''[\s\S]*?'''|\"\"\"[\s\S]*?\"\"\"|'(?:[^'\\\n]|\\.)*'|"(?:[^"\\\n]|\\.)*")""")


def strip_comments(src: str) -> str:
    out, i, n = [], 0, len(src)
    while i < n:
        c = src[i]
        if c in '\'"':
            m = STRING.match(src, i)
            if m:
                out.append(m.group(0))
                i = m.end()
                continue
        if src.startswith('//', i):
            j = src.find('\n', i)
            i = n if j < 0 else j
            continue
        if src.startswith('/*', i):
            j = src.find('*/', i + 2)
            i = n if j < 0 else j + 2
            continue
        out.append(c)
        i += 1
    return ''.join(out)


def literals(path: str):
    src = strip_comments(open(path, encoding='utf-8-sig').read())
    return [m.group(0) for m in STRING.finditer(src) if VI.search(m.group(0))]


def scan():
    result = {}
    for dp, dirs, files in os.walk(LIB):
        if any(dp == d or dp.startswith(d + os.sep) for d in EXCLUDE_DIRS):
            continue
        for f in files:
            p = os.path.join(dp, f)
            # *_preview.dart: Flutter widget preview chỉ dùng khi phát triển
            if not f.endswith('.dart') or f.endswith('_preview.dart') or p in EXCLUDE_FILES:
                continue
            n = len(literals(p))
            if n:
                result[os.path.relpath(p, ROOT).replace(os.sep, '/')] = n
    return dict(sorted(result.items()))


def main():
    if len(sys.argv) > 2 and sys.argv[1] == '--list':
        for lit in literals(sys.argv[2]):
            print(lit)
        return 0
    current = scan()
    if '--update' in sys.argv:
        with open(BASELINE, 'w', encoding='utf-8') as fh:
            json.dump(current, fh, ensure_ascii=False, indent=2)
            fh.write('\n')
        print(f'Đã ghi baseline: {sum(current.values())} chuỗi trong {len(current)} file')
        return 0
    baseline = json.load(open(BASELINE, encoding='utf-8')) if os.path.exists(BASELINE) else {}
    bad = [(f, n, baseline.get(f, 0)) for f, n in current.items() if n > baseline.get(f, 0)]
    total, base_total = sum(current.values()), sum(baseline.values())
    if bad:
        print('Chuỗi tiếng Việt viết cứng mới trong code Flutter — chuyển vào l10n (app_vi.arb/app_en.arb):')
        for f, n, b in bad:
            print(f'  {f}: {n} (baseline {b})  → python3 tools/ci/check_vi_literals.py --list {f}')
        return 1
    print(f'OK: {total} chuỗi tiếng Việt cũ (baseline {base_total}), không có chuỗi mới.')
    if total < base_total:
        print('Đã giảm so với baseline — chạy --update để hạ baseline.')
    return 0


if __name__ == '__main__':
    sys.exit(main())
