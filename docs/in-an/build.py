#!/usr/bin/env python3
"""Xuất bộ tài liệu in ra PDF (Chromium qua Playwright) + ảnh xem trước PNG.
Kịch bản bán hàng: kich-ban-ban-hang.md (bản gốc, sửa ở đây) → pdf/kich-ban-ban-hang.pdf + .docx (cần pandoc).

  pip install playwright markdown && python -m playwright install chromium
  python docs/in-an/build.py            → docs/in-an/pdf/*.pdf, *.docx, anh/*.png (ảnh từng trang, 200 dpi — cần pdftoppm), preview/*.png
Biến CHROMIUM_PATH: dùng Chromium có sẵn thay vì bản Playwright tải về.
"""
import glob, os, pathlib, re, shutil, subprocess
import markdown
from playwright.sync_api import sync_playwright

HERE = pathlib.Path(__file__).resolve().parent
DOCS = ['poster-a3', 'poster-bang-gia-a3', 'to-gioi-thieu-a4', 'phieu-dang-ky-a4', 'kich-ban-ban-hang']
(HERE / 'pdf').mkdir(exist_ok=True)
(HERE / 'preview').mkdir(exist_ok=True)


def build_script():
    """kich-ban-ban-hang.md → .html (để in PDF) + .docx (Word, sửa được)."""
    md = (HERE / 'kich-ban-ban-hang.md').read_text(encoding='utf-8')
    body = markdown.markdown(md, extensions=['tables'])
    body = re.sub(r'<li>\[ \] ', '<li class="task">', body)
    (HERE / 'kich-ban-ban-hang.html').write_text(SCRIPT_TPL.replace('{{body}}', body), encoding='utf-8')
    if shutil.which('pandoc'):
        subprocess.run(['pandoc', '-f', 'gfm', '-o', str(HERE / 'pdf' / 'kich-ban-ban-hang.docx'),
                        str(HERE / 'kich-ban-ban-hang.md')], check=True)
    else:
        print('bỏ qua .docx: chưa cài pandoc')


SCRIPT_TPL = """<!doctype html><html lang="vi"><head><meta charset="utf-8"><title>Kịch bản bán hàng BossKin</title>
<link rel="stylesheet" href="common.css"><style>
@page { size: A4; margin: 14mm 15mm 14mm; }
body { font-size: 10pt; line-height: 1.5; color: var(--ink); }
h1 { font-size: 19pt; color: var(--navy); font-weight: 800; }
h1 + p { color: var(--muted); font-size: 9pt; margin-top: 1mm; border-bottom: .5mm solid var(--navy); padding-bottom: 3mm; }
h2 { font-size: 13pt; color: #fff; background: var(--navy-2); border-radius: 1.5mm; padding: 1.5mm 3mm; margin: 6mm 0 3mm; break-after: avoid; }
p, ul, ol, blockquote, table { margin-top: 2.2mm; }
ul, ol { padding-left: 6mm; } li { margin-top: .8mm; }
li.task { list-style: none; margin-left: -5mm; } li.task::before { content: '\\2610'; margin-right: 2mm; font-size: 11pt; }
blockquote { border-left: 1mm solid var(--blue); background: var(--soft); padding: 2mm 3.5mm; border-radius: 0 1.5mm 1.5mm 0; font-style: italic; }
table { border-collapse: collapse; width: 100%; font-size: 8.8pt; }
th { background: #e8effd; color: var(--navy); text-align: left; }
th, td { border: .3mm solid var(--line); padding: 1.6mm 2mm; vertical-align: top; }
tr { break-inside: avoid; }
code { font-family: inherit; font-weight: 600; color: var(--blue-d); }
</style></head><body>{{body}}</body></html>"""


def chromium_path():
    p = os.environ.get('CHROMIUM_PATH')
    if p: return p
    found = sorted(glob.glob('/opt/pw-browsers/chromium-*/chrome-linux*/chrome'))
    return found[-1] if found else None


build_script()

with sync_playwright() as pw:
    browser = pw.chromium.launch(executable_path=chromium_path())
    for name in DOCS:
        src = HERE / f'{name}.html'
        if not src.exists(): continue
        page = browser.new_page(device_scale_factor=2)
        page.goto(src.as_uri())
        page.wait_for_load_state('networkidle')
        page.evaluate('document.fonts.ready')
        page.pdf(path=str(HERE / 'pdf' / f'{name}.pdf'), prefer_css_page_size=True, print_background=True)
        page.emulate_media(media='print')
        page.set_viewport_size({'width': 1123 if 'a3' in name else 794, 'height': 800})
        page.screenshot(path=str(HERE / 'preview' / f'{name}.png'), full_page=True)
        page.close()
        print('ok', name)
    browser.close()


# Ảnh PNG từng trang (gửi Zalo / Facebook / Canva): anh/<tên>-<trang>.png, 200 dpi
if shutil.which('pdftoppm'):
    (HERE / 'anh').mkdir(exist_ok=True)
    for old in (HERE / 'anh').glob('*.png'):
        old.unlink()
    for name in DOCS:
        pdf = HERE / 'pdf' / f'{name}.pdf'
        if pdf.exists():
            subprocess.run(['pdftoppm', '-r', '200', '-png', str(pdf), str(HERE / 'anh' / name)], check=True)
    print('ok ảnh:', len(list((HERE / 'anh').glob('*.png'))), 'trang')
else:
    print('bỏ qua ảnh PNG: chưa cài pdftoppm (poppler)')
