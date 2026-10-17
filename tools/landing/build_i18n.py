#!/usr/bin/env python3
"""Dựng bản tiếng Anh của trang giới thiệu: landing/en/index.html từ landing/index.html (nguồn tiếng Việt)
+ landing/i18n/en.json (bảng "câu tiếng Việt → câu tiếng Anh", khoá là chữ đã gộp khoảng trắng).

    python3 tools/landing/build_i18n.py          # dựng lại landing/en/index.html
    python3 tools/landing/build_i18n.py --check  # CI: báo lệch / thiếu bản dịch, không ghi file

Sửa chữ ở landing/index.html → thêm/sửa dòng tương ứng trong en.json rồi chạy lại (chữ chưa có bản dịch bị báo).
Phần JS của trang đọc <html lang> để chọn chuỗi vi / en, nên không đi qua bảng này."""
import json
import os
import re
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import chrome

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), '..', '..'))
SRC = os.path.join(ROOT, 'landing', 'index.html')
DICT = os.path.join(ROOT, 'landing', 'i18n', 'en.json')
OUT = os.path.join(ROOT, 'landing', 'en', 'index.html')
SITE = 'https://bosskin.io.vn'

ATTRS = ('alt', 'title', 'aria-label', 'placeholder')
URL_ATTRS = ('src', 'href', 'poster')
TAG = re.compile(r'(<!--.*?-->|<[^>]+>)', re.S)
HAS_VI = re.compile(r'[À-ỹ]')


def norm(t):
    return re.sub(r'\s+', ' ', t).strip()


def esc(t):
    return re.sub(r'&(?!#?\w+;)', '&amp;', t)


def synced_source():
    """index.html với menu đầu trang lấy từ chrome.NAV (một nguồn chung với trang trợ giúp)."""
    html = open(SRC, encoding='utf-8').read()
    html = re.sub(r'(<nav class="links">\s*).*?(\s*</nav>)', lambda m: m.group(1) + chrome.landing_nav() + m.group(2), html, count=1, flags=re.S)
    return re.sub(r'<!--lang-dd-->.*?<!--/lang-dd-->', lambda m: '<!--lang-dd-->' + chrome.lang_dropdown(chrome.ROOT_LANG) + '<!--/lang-dd-->', html, count=1, flags=re.S)


def build():
    en = json.load(open(DICT, encoding='utf-8'))
    html = synced_source()
    html = re.sub(r'<!--lang-dd-->.*?<!--/lang-dd-->', '@@LANGDD@@', html, count=1, flags=re.S)   # tên ngôn ngữ giữ nguyên, không dịch
    missing = []

    def tr(t):
        k = norm(t)
        if k in en:
            return en[k]
        if HAS_VI.search(k):
            missing.append(k)
        return None

    def attr_sub(m):
        name, q, val = m.group(1), m.group(2), m.group(3)
        if name in ATTRS or (name == 'content' and m.group(0).startswith('content')):
            v = tr(val)
            if v is not None:
                return f'{name}={q}{esc(v).replace(q, "&quot;")}{q}'
        if name == 'srcset':
            return f'{name}={q}' + ', '.join('../' + c.strip() for c in val.split(',')) + q
        if name in URL_ATTRS and not re.match(r'(https?:|//|/|#|mailto:|tel:|data:|\.\./)', val) and val:
            return f'{name}={q}../{val}{q}'
        return m.group(0)

    out, skip = [], None
    for part in TAG.split(html):
        if not part:
            continue
        if part.startswith('<!--'):
            out.append(part)
        elif part.startswith('<'):
            m = re.match(r'<(/?)(script|style)\b', part, re.I)
            if m:
                skip = None if m.group(1) else m.group(2).lower()
            if 'src="site-config.js"' in part:
                part = part.replace('src="site-config.js"', 'src="../site-config.js"')
            elif part.startswith('<html'):
                part = part.replace('lang="vi"', 'lang="en"')
            elif part.startswith('<meta') and 'content=' in part:
                part = re.sub(r'(content)=(")([^"]*)"', attr_sub, part)
            else:
                part = re.sub(r'([\w-]+)=(")([^"]*)"', attr_sub, part)
            out.append(part)
        elif skip:
            out.append(part)
        else:
            k = norm(part)
            v = tr(part) if k else None
            if v is None:
                out.append(part)
            else:
                lead = part[:len(part) - len(part.lstrip())]
                trail = part[len(part.rstrip()):]
                out.append(lead + esc(v) + trail)
    res = ''.join(out)
    # <title> nằm trong TAG.split như text bình thường nên đã dịch; trang EN tự trỏ canonical về /en/
    res = res.replace(f'<link rel="canonical" href="{SITE}/">', f'<link rel="canonical" href="{SITE}/en/">')
    res = res.replace(f'<meta property="og:url" content="{SITE}/">', f'<meta property="og:url" content="{SITE}/en/">')
    res = res.replace('content="vi_VN"', 'content="en_US"')
    # trợ giúp có bản tiếng Anh riêng ở help/en/
    res = re.sub(r'href="\.\./help/(?!en/)', 'href="../help/en/', res)
    res = res.replace('@@LANGDD@@', '<!--lang-dd-->' + chrome.lang_dropdown('en') + '<!--/lang-dd-->')
    return res, missing


def main():
    res, missing = build()
    if missing:
        print('✘ chữ tiếng Việt chưa có bản dịch trong landing/i18n/en.json:')
        print('\n'.join('   ' + m[:100] for m in dict.fromkeys(missing)))
        sys.exit(1)
    if '--check' in sys.argv:
        if synced_source() != open(SRC, encoding='utf-8').read():
            sys.exit('✘ menu trong landing/index.html lệch tools/landing/chrome.py — chạy python3 tools/landing/build_i18n.py')
        cur = open(OUT, encoding='utf-8').read() if os.path.isfile(OUT) else ''
        if cur != res:
            sys.exit('✘ landing/en/index.html cũ so với index.html / en.json — chạy python3 tools/landing/build_i18n.py')
        print('✔ landing/en/index.html khớp nguồn')
        return
    src_html = synced_source()   # đọc trước khi mở file để ghi (mở 'w' xoá nội dung)
    open(SRC, 'w', encoding='utf-8', newline='\n').write(src_html)
    os.makedirs(os.path.dirname(OUT), exist_ok=True)
    open(OUT, 'w', encoding='utf-8', newline='\n').write(res)
    print('đã dựng', os.path.relpath(OUT, ROOT))


if __name__ == '__main__':
    main()
