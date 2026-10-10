#!/usr/bin/env python3
"""Dựng trang trợ giúp tĩnh từ help/src/*.md → help/*.html.

Mỗi file src có phần đầu:
    ---
    title: Tiêu đề trang
    group: Nhóm trên menu (Bắt đầu | Nhân viên | Quản lý | Nhân sự | Kế toán | Quản trị)
    who: Ai dùng (một dòng)
    summary: Một câu mô tả
    ---
Nội dung Markdown; ảnh chụp viết  ![Chú thích](img:id)  → <figure> có phóng to; khối  > **Lưu ý:** …  thành hộp lưu ý.
    python3 help/tools/build_help.py
"""
import html
import json
import os
import re

import markdown

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.abspath(os.path.join(HERE, '..'))
SRC = os.path.join(ROOT, 'src')
GROUPS = ['Bắt đầu', 'Nhân viên', 'Quản lý', 'Nhân sự', 'Kế toán', 'Quản trị', 'Hỗ trợ']
GROUP_ICON = {'Bắt đầu': '🚀', 'Nhân viên': '🙋', 'Quản lý': '🧭', 'Nhân sự': '🗂️', 'Kế toán': '💰', 'Quản trị': '⚙️', 'Hỗ trợ': '💬'}


def parse(path):
    raw = open(path, encoding='utf-8').read()
    m = re.match(r'---\n(.*?)\n---\n(.*)', raw, re.S)
    meta = dict(re.findall(r'^(\w+):\s*(.*)$', m.group(1), re.M))
    meta['body'] = m.group(2)
    meta['slug'] = re.sub(r'^\d+-', '', os.path.basename(path)[:-3])
    meta['order'] = os.path.basename(path)
    return meta


def render_body(md):
    def fig(m):
        cap, sid = m.group(1), m.group(2)
        src = f'img/{sid}.webp'
        return (f'\n<figure><a href="{src}" class="zoom"><img src="{src}" alt="{html.escape(cap)}" loading="lazy" '
                f'width="1440" height="900"></a><figcaption>{cap}</figcaption></figure>\n')
    md = re.sub(r'!\[([^\]]*)\]\(img:([\w-]+)\)', fig, md)
    out = markdown.markdown(md, extensions=['tables', 'attr_list', 'toc', 'sane_lists'],
                            extension_configs={'toc': {'slugify': slug, 'permalink': False}})
    out = re.sub(r'<blockquote>\s*<p><strong>(Lưu ý|Mẹo|Quan trọng):</strong>',
                 lambda m: f'<blockquote class="note {"warn" if m.group(1) == "Quan trọng" else ""}"><p><strong>{m.group(1)}:</strong>', out)
    return out


def slug(s, sep='-'):
    import unicodedata
    s = unicodedata.normalize('NFD', s.replace('đ', 'd').replace('Đ', 'D'))
    s = ''.join(c for c in s if not unicodedata.combining(c)).lower()
    return re.sub(r'[^a-z0-9]+', sep, s).strip(sep)


def plain(htmltext):
    return re.sub(r'\s+', ' ', html.unescape(re.sub(r'<[^>]+>', ' ', htmltext))).strip()


CSS = open(os.path.join(HERE, 'help.css'), encoding='utf-8').read()
JS = open(os.path.join(HERE, 'help.js'), encoding='utf-8').read()


def nav(pages, current):
    parts = []
    for g in GROUPS:
        items = [p for p in pages if p['group'] == g]
        if not items: continue
        parts.append(f'<div class="nav-group"><div class="nav-h">{g}</div>')
        for p in items:
            cls = ' class="on"' if p['slug'] == current else ''
            parts.append(f'<a href="{p["slug"]}.html"{cls}>{html.escape(p["title"])}</a>')
        parts.append('</div>')
    return '\n'.join(parts)


def page(title, body, pages, current, desc, aside=''):
    return f'''<!doctype html>
<html lang="vi">
<head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1">
<title>{html.escape(title) + ' · ' if title else ''}Trợ giúp BossKin</title>
<meta name="description" content="{html.escape(desc)}">
<link rel="icon" href="img/logo-192.png">
<link rel="preconnect" href="https://fonts.googleapis.com"><link rel="preconnect" href="https://fonts.gstatic.com" crossorigin>
<link href="https://fonts.googleapis.com/css2?family=Be+Vietnam+Pro:wght@400;500;600;700;800&display=swap" rel="stylesheet">
<style>{CSS}</style>
</head>
<body{' class="home"' if current == 'index' else ''}>
<header class="top"><div class="top-in">
  <button class="menu-btn" aria-label="Mở menu" onclick="document.body.classList.toggle('nav-open')">☰</button>
  <a class="brand" href="../" title="Về trang chủ BossKin"><img class="logo" src="img/logo-80.png" width="38" height="38" alt="">BossKin</a>
  <nav class="links"><a href="../#video">Video</a><a href="../#tinh-nang">Tính năng</a><a href="../#vai-tro">Cho ai</a><a href="../#hoi-dap">Hỏi đáp</a><a class="on" href="index.html">Trợ giúp</a></nav>
  <div class="actions"><a class="btn-login js-app" href="/login" hidden>Đăng nhập</a></div>
</div></header>
<div class="wrap">
<nav class="side">{'' if current == 'index' else SEARCH_BOX}{nav(pages, current)}</nav>
<main class="content">{body}</main>
{aside}
</div>
<div id="lightbox" hidden><img alt=""></div>
<script>/* Giống window.BOSSKIN.appUrl ở landing/index.html: '' = ẩn nút Đăng nhập */
window.HELP_APP_URL = location.port === '8099' ? 'http://localhost:3000/login' : '';
window.HELP_INDEX = {json.dumps(SEARCH, ensure_ascii=False)};</script>
<script>{JS}</script>
</body>
</html>
'''


SEARCH = []
SEARCH_BOX = ('<div class="search"><input id="q" type="search" placeholder="Tìm hướng dẫn…  ( / )" autocomplete="off">'
              '<div id="results"></div></div>')


def main():
    files = sorted(f for f in os.listdir(SRC) if f.endswith('.md'))
    pages = [parse(os.path.join(SRC, f)) for f in files]
    for p in pages:
        p['html'] = render_body(p['body'])
        for h in re.finditer(r'<h2 id="([^"]+)">(.*?)</h2>(.*?)(?=<h2 |\Z)', p['html'], re.S):
            SEARCH.append({'t': plain(h.group(2)), 'p': p['title'], 'u': f'{p["slug"]}.html#{h.group(1)}',
                           'x': plain(h.group(3))[:400]})
        SEARCH.append({'t': p['title'], 'p': p['group'], 'u': f'{p["slug"]}.html', 'x': p.get('summary', '')})
    for p in pages:
        toc = re.findall(r'<h2 id="([^"]+)">(.*?)</h2>', p['html'])
        toc_html = ''
        if len(toc) > 1:
            toc_html = '<div class="toc"><b>Trong trang này</b>' + ''.join(
                f'<a href="#{i}">{plain(t)}</a>' for i, t in toc) + '</div>'
        idx = pages.index(p)
        prev_ = pages[idx - 1] if idx > 0 else None
        next_ = pages[idx + 1] if idx + 1 < len(pages) else None
        pager = '<div class="pager">' + (f'<a href="{prev_["slug"]}.html">← {html.escape(prev_["title"])}</a>' if prev_ else '<span></span>') + \
                (f'<a href="{next_["slug"]}.html">{html.escape(next_["title"])} →</a>' if next_ else '') + '</div>'
        body = (f'<div class="crumb"><a href="index.html">Trợ giúp</a> › {p["group"]}</div>'
                f'<h1>{html.escape(p["title"])}</h1><p class="lead">{p.get("summary", "")}</p>'
                f'<p class="who"><b>Dành cho:</b> {p.get("who", "")}</p>{toc_html}{p["html"]}{pager}')
        aside = ('<aside class="toc-side"><b>Trong trang này</b>' + ''.join(f'<a href="#{i}">{plain(t)}</a>' for i, t in toc) + '</aside>') if len(toc) > 1 else ''
        open(os.path.join(ROOT, p['slug'] + '.html'), 'w', encoding='utf-8').write(page(p['title'], body, pages, p['slug'], p.get('summary', ''), aside))
    # Trang chủ
    cards = []
    for g in GROUPS:
        items = [p for p in pages if p['group'] == g]
        if not items: continue
        links = ''.join(f'<li><a href="{p["slug"]}.html">{html.escape(p["title"])}</a><span>{html.escape(p.get("summary", ""))}</span></li>' for p in items)
        cards.append(f'<section class="card"><h2><span class="gi">{GROUP_ICON[g]}</span>{g}</h2><ul>{links}</ul></section>')
    home = f'''<div class="hero"><h1>Trợ giúp BossKin</h1>
<p class="lead">Hướng dẫn từng bước kèm ảnh chụp màn hình cho mọi chức năng: chấm công, ca làm, nghỉ phép, hồ sơ nhân sự, hợp đồng, bảng lương và quản trị.
Chọn nhóm theo vai trò của bạn hoặc gõ vào ô tìm kiếm phía trên.</p>
<div class="hero-search">{SEARCH_BOX.replace('Tìm hướng dẫn…  ( / )', 'Tìm hướng dẫn… (vd. nghỉ phép, khoá kỳ, phiếu lương)')}</div>
<div class="roles">
<a href="thong-tin-ca-nhan.html">🙋 Tôi là nhân viên</a><a href="duyet-cho-nhom.html">🧭 Tôi quản lý nhóm</a>
<a href="nhan-vien.html">🗂️ Tôi làm nhân sự</a><a href="bang-luong.html">💰 Tôi làm kế toán</a><a href="phan-quyen.html">⚙️ Tôi quản trị công ty</a></div></div>
<div class="grid">{''.join(cards)}</div>
<p class="foot">Ảnh minh hoạ dùng dữ liệu của công ty hư cấu "Nội thất An Phát". Tên, số liệu không phải người thật.
Giao diện có thể khác đôi chút tuỳ quyền của tài khoản: bạn chỉ thấy các mục mình được cấp quyền.</p>'''
    open(os.path.join(ROOT, 'index.html'), 'w', encoding='utf-8').write(page('', home, pages, 'index', 'Hướng dẫn sử dụng BossKin'))
    print(len(pages), 'trang,', len(SEARCH), 'mục tìm kiếm')


if __name__ == '__main__':
    main()
