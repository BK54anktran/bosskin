#!/usr/bin/env python3
"""Kiểm landing/sitemap.xml + robots.txt (sinh bởi help/tools/build_help.py).

- XML hợp lệ, đúng namespace sitemaps.org, ≤ 50.000 URL, <lastmod> dạng YYYY-MM-DD, không trùng URL;
- mỗi URL https://bosskin.io.vn/… ứng với một file có thật (landing/ hoặc help/), file đó có canonical đúng bằng URL
  và không có noindex;
- đủ mọi trang trợ giúp trong help/src (thêm trang mà quên dựng lại → báo);
- robots.txt trỏ tới sitemap, không chặn toàn trang; 404.html có noindex.
    python3 tools/ci/check_sitemap.py
"""
import os
import re
import sys
import xml.etree.ElementTree as ET

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), '..', '..'))
SITE = 'https://bosskin.io.vn'
NS = '{http://www.sitemaps.org/schemas/sitemap/0.9}'
errors = []


def read(path):
    return open(os.path.join(ROOT, path), encoding='utf-8').read()


def url_to_file(url):
    path = url[len(SITE):]
    if path == '/':
        return 'landing/index.html'
    if path == '/help/':
        return 'help/index.html'
    m = re.fullmatch(r'/help/([\w-]+\.html)', path)
    return f'help/{m.group(1)}' if m else None


def main():
    try:
        root = ET.fromstring(read('landing/sitemap.xml').encode('utf-8'))
    except (ET.ParseError, FileNotFoundError) as e:
        sys.exit(f'sitemap.xml không đọc được: {e}')
    if root.tag != NS + 'urlset':
        errors.append(f'phần tử gốc phải là <urlset> namespace sitemaps.org, đang là {root.tag}')
    urls = []
    for u in root:
        loc = u.find(NS + 'loc')
        mod = u.find(NS + 'lastmod')
        if u.tag != NS + 'url' or loc is None or not (loc.text or '').strip():
            errors.append(f'<url> thiếu <loc>: {ET.tostring(u)[:80]!r}')
            continue
        url = loc.text.strip()
        urls.append(url)
        if mod is not None and not re.fullmatch(r'\d{4}-\d{2}-\d{2}', mod.text or ''):
            errors.append(f'{url}: lastmod sai định dạng {mod.text!r}')
        if not url.startswith(SITE + '/'):
            errors.append(f'{url}: không thuộc {SITE}')
            continue
        f = url_to_file(url)
        if not f or not os.path.isfile(os.path.join(ROOT, f)):
            errors.append(f'{url}: không có file tương ứng (sẽ 404)')
            continue
        html = read(f)
        canon = re.search(r'<link rel="canonical" href="([^"]+)"', html)
        if not canon or canon.group(1) != url:
            errors.append(f'{url}: canonical của {f} là {canon.group(1) if canon else "(không có)"}')
        if re.search(r'<meta[^>]+name="robots"[^>]+noindex', html, re.I):
            errors.append(f'{url}: {f} có noindex')
    if len(urls) != len(set(urls)):
        errors.append('sitemap có URL trùng')
    if len(urls) > 50000:
        errors.append(f'{len(urls)} URL > 50.000: cần chia sitemap + sitemap index')

    slugs = {re.sub(r'^\d+-', '', f[:-3]) for f in os.listdir(os.path.join(ROOT, 'help', 'src')) if f.endswith('.md')}
    expected = {SITE + '/', SITE + '/help/'} | {f'{SITE}/help/{s}.html' for s in slugs}
    if set(urls) != expected:
        errors.append(f'thiếu: {sorted(expected - set(urls))}; thừa: {sorted(set(urls) - expected)} '
                      '(chạy lại python3 help/tools/build_help.py)')

    robots = read('landing/robots.txt')
    if f'Sitemap: {SITE}/sitemap.xml' not in robots.splitlines():
        errors.append('robots.txt thiếu dòng Sitemap')
    if re.search(r'^Disallow:\s*/\s*$', robots, re.M):
        errors.append('robots.txt chặn toàn trang (Disallow: /)')
    if 'noindex' not in read('landing/404.html'):
        errors.append('404.html thiếu noindex')

    if errors:
        print('\n'.join('✘ ' + e for e in errors))
        sys.exit(1)
    print(f'✔ sitemap.xml: {len(urls)} URL hợp lệ, khớp canonical; robots.txt trỏ đúng sitemap')


if __name__ == '__main__':
    main()
