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
Mỗi trang có <link rel="canonical">; cuối cùng sinh luôn landing/sitemap.xml (trang chủ + /help/ + từng trang trợ giúp).
    python3 help/tools/build_help.py

Bản tiếng Anh: help/src-en/ (cùng tên file, group = Getting started | Employee | Manager | HR | Accounting | Administration | Support)
→ help/en/*.html (canonical /help/en/…, hreflang vi / en). Chữ khung trang (menu, chân trang…) dịch bằng bảng EN_CHROME bên dưới.
"""
import datetime
import html
import json
import os
import re
import subprocess
from xml.sax.saxutils import escape

import markdown

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.abspath(os.path.join(HERE, '..'))
SRC = os.path.join(ROOT, 'src')
REPO = os.path.abspath(os.path.join(ROOT, '..'))
LANDING = os.path.join(REPO, 'landing')
# Tên miền chính (Vibe Host). Đổi tên miền → sửa ở đây, landing/index.html (canonical, og:url) và landing/robots.txt.
SITE = 'https://bosskin.io.vn'
HELP_URL = SITE + '/help/'
GROUPS = ['Bắt đầu', 'Nhân viên', 'Quản lý', 'Nhân sự', 'Kế toán', 'Quản trị', 'Hỗ trợ']
GROUPS_EN = ['Getting started', 'Employee', 'Manager', 'HR', 'Accounting', 'Administration', 'Support']
GROUP_ICON = {'Bắt đầu': '🚀', 'Nhân viên': '🙋', 'Quản lý': '🧭', 'Nhân sự': '🗂️', 'Kế toán': '💰', 'Quản trị': '⚙️', 'Hỗ trợ': '💬',
              'Getting started': '🚀', 'Employee': '🙋', 'Manager': '🧭', 'HR': '🗂️', 'Accounting': '💰', 'Administration': '⚙️', 'Support': '💬'}
LANG = 'vi'   # đang dựng ngôn ngữ nào (build() đặt)


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
        # bản tiếng Anh dùng ảnh chụp giao diện tiếng Anh (help/img-en/) nếu có, không thì ảnh chung
        src = f'img-en/{sid}.webp' if LANG == 'en' and os.path.exists(os.path.join(ROOT, 'img-en', sid + '.webp')) else f'img/{sid}.webp'
        return (f'\n<figure><a href="{src}" class="zoom"><img src="{src}" alt="{html.escape(cap)}" loading="lazy" '
                f'width="1440" height="900"></a><figcaption>{cap}</figcaption></figure>\n')
    md = re.sub(r'!\[([^\]]*)\]\(img:([\w-]+)\)', fig, md)
    # Ảnh đầu trang thường là phần tử lớn nhất màn đầu (LCP): tải ngay, ưu tiên cao
    md = md.replace('loading="lazy"', 'fetchpriority="high"', 1)
    out = markdown.markdown(md, extensions=['tables', 'attr_list', 'toc', 'sane_lists'],
                            extension_configs={'toc': {'slugify': slug, 'permalink': False}})
    out = re.sub(r'<blockquote>\s*<p><strong>(Lưu ý|Mẹo|Quan trọng|Note|Tip|Important):</strong>',
                 lambda m: f'<blockquote class="note {"warn" if m.group(1) in ("Quan trọng", "Important") else ""}"><p><strong>{m.group(1)}:</strong>', out)
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


def canonical(slug, lang=None):
    base = HELP_URL + ('en/' if (lang or LANG) == 'en' else '')
    return base if slug == 'index' else f'{base}{slug}.html'


# Chữ khung trang (đầu / chân / tìm kiếm…) → bản tiếng Anh; đường dẫn tương đối chuyển cho thư mục help/en/ (thứ tự có ý nghĩa)
EN_CHROME = [
    ('<html lang="vi">', '<html lang="en">'),
    ('Trợ giúp BossKin', 'BossKin Help'),
    ('aria-label="Mở menu"', 'aria-label="Open menu"'),
    ('title="Về trang chủ BossKin"', 'title="Back to the BossKin home page"'),
    ('<a href="../#cai-dat">Cài đặt</a><a href="../#video">Video</a><a href="../#tinh-nang">Tính năng</a><a href="../#vai-tro">Cho ai</a><a href="../#bang-gia">Bảng giá</a><a href="../#hoi-dap">Hỏi đáp</a><a class="on" href="index.html">Trợ giúp</a>',
     '<a href="../#cai-dat">Install</a><a href="../#video">Video</a><a href="../#tinh-nang">Features</a><a href="../#vai-tro">Who it\'s for</a><a href="../#bang-gia">Pricing</a><a href="../#hoi-dap">FAQ</a><a class="on" href="index.html">Help</a>'),
    ('>Đăng nhập<', '>Log in<'),
    ('<a href="../">Trang chủ</a><a href="../#cai-dat">Cài đặt</a><a href="../#video">Video</a><a href="../#tinh-nang">Tính năng</a><a href="../#vai-tro">Cho ai</a><a href="../#bang-gia">Bảng giá</a><a href="../#hoi-dap">Hỏi đáp</a>',
     '<a href="../">Home</a><a href="../#cai-dat">Install</a><a href="../#video">Video</a><a href="../#tinh-nang">Features</a><a href="../#vai-tro">Who it\'s for</a><a href="../#bang-gia">Pricing</a><a href="../#hoi-dap">FAQ</a>'),
    ('Tìm hướng dẫn…  ( / )', 'Search the guides…  ( / )'),
    ('Tìm hướng dẫn… (vd. nghỉ phép, khoá kỳ, phiếu lương)', 'Search the guides… (e.g. leave, lock period, payslip)'),
    ('Phần mềm chấm công, xếp ca, nghỉ phép và tính lương cho doanh nghiệp Việt Nam. Dùng trên điện thoại Android và trình duyệt web, tiếng Việt và tiếng Anh.',
     'Time &amp; attendance, shift scheduling, leave and payroll software for Vietnamese businesses. Works on Android phones and the web browser, in Vietnamese and English.'),
    ('>Đăng ký dùng thử<', '>Request a free trial<'),
    ('>Sản phẩm<', '>Product<'), ('>Video giới thiệu<', '>Intro video<'), ('>Tính năng<', '>Features<'),
    ('>Dành cho ai<', '>Who it\'s for<'), ('>Hỏi đáp<', '>FAQ<'), ('>Hướng dẫn<', '>Guides<'),
    ('>Bắt đầu sử dụng<', '>Getting started<'), ('>Cho nhân viên<', '>For employees<'), ('>Cho quản lý<', '>For managers<'),
    ('>Cho nhân sự<', '>For HR<'), ('>Cho kế toán<', '>For accountants<'), ('>Câu hỏi thường gặp<', '>Frequently asked questions<'),
    ('>Liên hệ<', '>Contact<'),
    ('<b>Trong trang này</b>', '<b>On this page</b>'), ('<b>Dành cho:</b>', '<b>For:</b>'), ('>Trợ giúp</a> ›', '>Help</a> ›'),
    ('Hướng dẫn từng bước kèm ảnh chụp màn hình cho mọi chức năng: chấm công, ca làm, nghỉ phép, hồ sơ nhân sự, hợp đồng, bảng lương và quản trị.\nChọn nhóm theo vai trò của bạn hoặc gõ vào ô tìm kiếm phía trên.',
     'Step-by-step guides with screenshots for every feature: time and attendance, shifts, leave, employee records, contracts, payroll and administration.\nPick the group that matches your role or type in the search box above.'),
    ('🙋 Tôi là nhân viên', '🙋 I\'m an employee'), ('🧭 Tôi quản lý nhóm', '🧭 I manage a team'), ('🗂️ Tôi làm nhân sự', '🗂️ I work in HR'),
    ('💰 Tôi làm kế toán', '💰 I\'m an accountant'), ('⚙️ Tôi quản trị công ty', '⚙️ I administer the company'),
    ('Ảnh minh hoạ dùng dữ liệu của công ty hư cấu "Nội thất An Phát". Tên, số liệu không phải người thật.\nGiao diện có thể khác đôi chút tuỳ quyền của tài khoản: bạn chỉ thấy các mục mình được cấp quyền.',
     'Screenshots use data from a fictional company, "Nội thất An Phát" (An Phat Furniture); names and figures are not real people. The screenshots show the Vietnamese interface — the app itself also runs in English.\nThe interface may differ slightly depending on your account\'s permissions: you only see the sections you have been granted.'),
    ('<span>Để lại thông tin ở mục <a href="../#lien-he" style="text-decoration:underline">Dùng thử</a> để được liên hệ hướng dẫn.</span>',
     '<span>Leave your details in the <a href="../#lien-he" style="text-decoration:underline">Free trial</a> section and we\'ll get in touch.</span>'),
    ('>Đăng nhập BossKin<', '>Log in to BossKin<'),
    ('BossKin. Chấm công đúng · Tính lương nhanh · Quản lý nhẹ nhàng.', 'BossKin. Accurate attendance · Fast payroll · Easy management.'),
    ('>Lên đầu trang ↑<', '>Back to top ↑<'),
    # đường dẫn: help/en/ sâu hơn help/ một cấp; trang giới thiệu tiếng Anh ở /en/
    ('href="../#', 'href="../../en/#'), ('href="../"', 'href="../../en/"'),
    ('src="../site-config.js"', 'src="../../site-config.js"'),
    ('src="img/', 'src="../img/'), ('href="img/', 'href="../img/'),
    ('src="img-en/', 'src="../img-en/'), ('href="img-en/', 'href="../img-en/'),
]


def localize(text):
    if LANG != 'en':
        return text
    for a, b in EN_CHROME:
        text = text.replace(a, b)
    return text


def alt_links(slug):
    """hreflang + nút đổi ngôn ngữ cho trang `slug` (vi ở help/, en ở help/en/)."""
    tail = '' if slug == 'index' else slug + '.html'
    vi, en = HELP_URL + tail, HELP_URL + 'en/' + tail
    links = (f'<link rel="alternate" hreflang="vi" href="{vi}">\n<link rel="alternate" hreflang="en" href="{en}">\n'
             f'<link rel="alternate" hreflang="x-default" href="{vi}">')
    sw = (f'<a class="lang-sw" href="../{tail}" hreflang="vi" lang="vi" data-lang="vi" title="Tiếng Việt">VI</a>' if LANG == 'en'
          else f'<a class="lang-sw" href="en/{tail}" hreflang="en" lang="en" data-lang="en" title="English">EN</a>')
    return links, sw


def page(title, body, pages, current, desc, aside=''):
    alt, sw = alt_links(current)
    return localize(f'''<!doctype html>
<html lang="vi">
<head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1">
<title>{html.escape(title) + ' · ' if title else ''}Trợ giúp BossKin</title>
<meta name="description" content="{html.escape(desc)}">
<link rel="canonical" href="{canonical(current)}">
{alt}
<link rel="icon" href="img/logo-192.png">
<link rel="preconnect" href="https://fonts.googleapis.com"><link rel="preconnect" href="https://fonts.gstatic.com" crossorigin>
<link rel="preload" as="style" href="https://fonts.googleapis.com/css2?family=Be+Vietnam+Pro:wght@400;500;600;700;800&display=swap">
<link href="https://fonts.googleapis.com/css2?family=Be+Vietnam+Pro:wght@400;500;600;700;800&display=swap" rel="stylesheet" media="print" onload="this.media='all'">
<noscript><link href="https://fonts.googleapis.com/css2?family=Be+Vietnam+Pro:wght@400;500;600;700;800&display=swap" rel="stylesheet"></noscript>
<style>{CSS}</style>
</head>
<body{' class="home"' if current == 'index' else ''}>
<header class="top"><div class="top-in">
  <button class="menu-btn" aria-label="Mở menu" onclick="document.body.classList.toggle('nav-open')">☰</button>
  <a class="brand" href="../" title="Về trang chủ BossKin"><img class="logo" src="img/logo-80.png" width="38" height="38" alt="">BossKin</a>
  <nav class="links"><a href="../#cai-dat">Cài đặt</a><a href="../#video">Video</a><a href="../#tinh-nang">Tính năng</a><a href="../#vai-tro">Cho ai</a><a href="../#bang-gia">Bảng giá</a><a href="../#hoi-dap">Hỏi đáp</a><a class="on" href="index.html">Trợ giúp</a></nav>
  <div class="actions">@@SW@@<a class="btn-login js-app" href="/login" hidden>Đăng nhập</a></div>
</div></header>
<div class="wrap">
<nav class="side"><div class="side-site"><a href="../">Trang chủ</a><a href="../#cai-dat">Cài đặt</a><a href="../#video">Video</a><a href="../#tinh-nang">Tính năng</a><a href="../#vai-tro">Cho ai</a><a href="../#bang-gia">Bảng giá</a><a href="../#hoi-dap">Hỏi đáp</a></div>{'' if current == 'index' else SEARCH_BOX}{nav(pages, current)}</nav>
<main class="content">{body}</main>
{aside}
</div>
{FOOTER}
<div id="lightbox" hidden><img alt=""></div>
<script src="../site-config.js"></script>
<script>window.HELP_INDEX = {json.dumps(SEARCH, ensure_ascii=False)};</script>
<script>{JS}</script>
</body>
</html>
''').replace('@@SW@@', sw)


FOOTER = """<footer class="site">
  <div class="foot-grid">
    <div class="foot-brand">
      <a class="brand" href="../"><img class="logo" src="img/logo-80.png" width="38" height="38" alt="">BossKin</a>
      <p>Phần mềm chấm công, xếp ca, nghỉ phép và tính lương cho doanh nghiệp Việt Nam. Dùng trên điện thoại Android và trình duyệt web, tiếng Việt và tiếng Anh.</p>
      <div class="socials">
        <a class="js-soc" data-key="facebookUrl" href="#" target="_blank" rel="noopener" aria-label="Facebook" title="Facebook" hidden><svg viewBox="0 0 24 24" width="18" height="18" fill="currentColor" aria-hidden="true"><path d="M13.5 21v-7.5H16l.4-3H13.5V8.6c0-.9.3-1.5 1.5-1.5h1.6V4.4c-.3 0-1.2-.1-2.3-.1-2.3 0-3.8 1.4-3.8 3.9v2.3H8v3h2.5V21h3z"/></svg></a>
        <a class="js-soc" data-key="tiktokUrl" href="#" target="_blank" rel="noopener" aria-label="TikTok" title="TikTok" hidden><svg viewBox="0 0 24 24" width="18" height="18" fill="currentColor" aria-hidden="true"><path d="M16.6 3c.4 2.1 1.7 3.5 3.9 3.8v3.1a7.2 7.2 0 0 1-3.9-1.2v6.2A5.7 5.7 0 1 1 10.9 9.2v3.2a2.5 2.5 0 1 0 2.5 2.5V3h3.2z"/></svg></a>
        <a class="js-soc" data-key="youtubeUrl" href="#" target="_blank" rel="noopener" aria-label="YouTube" title="YouTube" hidden><svg viewBox="0 0 24 24" width="20" height="20" fill="currentColor" aria-hidden="true"><path d="M21.6 7.2a2.6 2.6 0 0 0-1.8-1.8C18.2 5 12 5 12 5s-6.2 0-7.8.4A2.6 2.6 0 0 0 2.4 7.2 27 27 0 0 0 2 12a27 27 0 0 0 .4 4.8 2.6 2.6 0 0 0 1.8 1.8C5.8 19 12 19 12 19s6.2 0 7.8-.4a2.6 2.6 0 0 0 1.8-1.8A27 27 0 0 0 22 12a27 27 0 0 0-.4-4.8zM10 15V9l5.2 3L10 15z"/></svg></a>
        <a class="js-soc-zalo" href="#" target="_blank" rel="noopener" aria-label="Zalo" title="Zalo" hidden><span class="zalo-txt">Zalo</span></a>
      </div>
      <a class="foot-cta" href="../#lien-he">Đăng ký dùng thử</a>
    </div>
    <div class="foot-col"><h2 class="foot-h">Sản phẩm</h2><ul>
      <li><a href="../#video">Video giới thiệu</a></li><li><a href="../#tinh-nang">Tính năng</a></li>
      <li><a href="../#vai-tro">Dành cho ai</a></li><li><a href="../#hoi-dap">Hỏi đáp</a></li></ul></div>
    <div class="foot-col"><h2 class="foot-h">Hướng dẫn</h2><ul>
      <li><a href="bat-dau.html">Bắt đầu sử dụng</a></li><li><a href="thong-tin-ca-nhan.html">Cho nhân viên</a></li>
      <li><a href="duyet-cho-nhom.html">Cho quản lý</a></li><li><a href="nhan-vien.html">Cho nhân sự</a></li>
      <li><a href="bang-luong.html">Cho kế toán</a></li><li><a href="cau-hoi.html">Câu hỏi thường gặp</a></li></ul></div>
    <div class="foot-col"><h2 class="foot-h">Liên hệ</h2><ul class="foot-contact">
      <li class="js-phone" hidden><span class="ic">☎</span><a href="../#lien-he"></a></li>
      <li class="js-zalo" hidden><span class="ic">💬</span><a href="../#lien-he" target="_blank" rel="noopener"></a></li>
      <li class="js-mail" hidden><span class="ic">✉</span><a href="../#lien-he"></a></li>
      <li class="js-nocontact"><span class="ic">✎</span><span>Để lại thông tin ở mục <a href="../#lien-he" style="text-decoration:underline">Dùng thử</a> để được liên hệ hướng dẫn.</span></li>
      <li class="js-app-row" hidden><span class="ic">➜</span><a class="js-app" href="/login">Đăng nhập BossKin</a></li></ul></div>
  </div>
  <div class="foot-bottom"><div class="foot-bottom-in"><span>© <span class="js-yr"></span> BossKin. Chấm công đúng · Tính lương nhanh · Quản lý nhẹ nhàng.</span><a href="#">Lên đầu trang ↑</a></div></div>
</footer>"""


SEARCH = []
SEARCH_BOX = ('<div class="search"><input id="q" type="search" placeholder="Tìm hướng dẫn…  ( / )" autocomplete="off">'
              '<div id="results"></div></div>')


def main():
    global LANG, SRC, GROUPS
    vi_groups = GROUPS
    pages_by_lang = {}
    for lang, src_dir, out_dir, groups in (('vi', os.path.join(ROOT, 'src'), ROOT, vi_groups),
                                           ('en', os.path.join(ROOT, 'src-en'), os.path.join(ROOT, 'en'), GROUPS_EN)):
        if not os.path.isdir(src_dir):
            continue
        LANG, SRC, GROUPS = lang, src_dir, groups
        os.makedirs(out_dir, exist_ok=True)
        pages_by_lang[lang] = build(out_dir)
    LANG, SRC, GROUPS = 'vi', os.path.join(ROOT, 'src'), vi_groups
    n = write_sitemap(pages_by_lang)
    print({k: len(v) for k, v in pages_by_lang.items()}, 'ngôn ngữ,', n, 'URL trong landing/sitemap.xml')


def build(out_dir):
    SEARCH.clear()
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
        open(os.path.join(out_dir, p['slug'] + '.html'), 'w', encoding='utf-8').write(page(p['title'], body, pages, p['slug'], p.get('summary', ''), aside))
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
    open(os.path.join(out_dir, 'index.html'), 'w', encoding='utf-8').write(
        page('', home, pages, 'index', HOME_DESC_EN if LANG == 'en' else HOME_DESC))
    print(LANG, len(pages), 'trang,', len(SEARCH), 'mục tìm kiếm')
    return pages


HOME_DESC_EN = ('Step-by-step BossKin guides with screenshots: time and attendance, shifts, leave, employee records, contracts, payroll and administration '
                '— by role: employee, manager, HR, accountant.')
HOME_DESC = ('Hướng dẫn sử dụng BossKin từng bước kèm ảnh chụp màn hình: chấm công, ca làm, nghỉ phép, '
             'hồ sơ nhân sự, hợp đồng, bảng lương và quản trị — theo vai trò nhân viên, quản lý, nhân sự, kế toán.')
# Phần dựng chung của mọi trang trợ giúp: đổi một file này là HTML mọi trang đổi theo
TEMPLATE_FILES = [os.path.join(HERE, f) for f in ('build_help.py', 'help.css', 'help.js')]


def lastmod(*paths):
    """Ngày sửa nội dung = commit gần nhất đụng tới các file nguồn; file đang sửa chưa commit → hôm nay."""
    def run(*args):
        return subprocess.run(['git', '-C', REPO, *args], capture_output=True, text=True).stdout.strip()
    if run('status', '--porcelain', '--', *paths):
        return datetime.date.today().isoformat()
    return run('log', '-1', '--format=%cs', '--', *paths) or datetime.date.today().isoformat()


def write_sitemap(pages_by_lang):
    """landing/sitemap.xml theo giao thức sitemaps.org: chỉ URL canonical, công khai (trang chủ vi / en + trợ giúp vi / en).
    Trang đăng nhập / ứng dụng ở app.bosskin.io.vn, API ở api.bosskin.io.vn: tên miền khác, không thuộc sitemap này."""
    landing_mod = lastmod(os.path.join(LANDING, 'index.html'), os.path.join(LANDING, 'i18n', 'en.json'))
    entries = [(SITE + '/', landing_mod), (SITE + '/en/', landing_mod)]
    for lang, pages in pages_by_lang.items():
        d = 'src' if lang == 'vi' else 'src-en'
        src = lambda p: os.path.join(ROOT, d, p['order'])
        entries.append((canonical('index', lang), lastmod(*[src(p) for p in pages], *TEMPLATE_FILES)))
        entries += [(canonical(p['slug'], lang), lastmod(src(p), *TEMPLATE_FILES)) for p in pages]
    body = ''.join(f'  <url>\n    <loc>{escape(u)}</loc>\n    <lastmod>{d}</lastmod>\n  </url>\n' for u, d in entries)
    xml = ('<?xml version="1.0" encoding="UTF-8"?>\n'
           '<urlset xmlns="http://www.sitemaps.org/schemas/sitemap/0.9">\n' + body + '</urlset>\n')
    open(os.path.join(LANDING, 'sitemap.xml'), 'w', encoding='utf-8', newline='\n').write(xml)
    return len(entries)


if __name__ == '__main__':
    main()
