#!/usr/bin/env python3
"""Xuất bộ tài liệu in ra PDF (Chromium qua Playwright) + ảnh xem trước PNG.

  pip install playwright && python -m playwright install chromium
  python docs/in-an/build.py            → docs/in-an/pdf/*.pdf, preview/*.png
Biến CHROMIUM_PATH: dùng Chromium có sẵn thay vì bản Playwright tải về.
"""
import glob, os, pathlib
from playwright.sync_api import sync_playwright

HERE = pathlib.Path(__file__).resolve().parent
DOCS = ['poster-a3', 'to-gioi-thieu-a4', 'phieu-dang-ky-a4']
(HERE / 'pdf').mkdir(exist_ok=True)
(HERE / 'preview').mkdir(exist_ok=True)


def chromium_path():
    p = os.environ.get('CHROMIUM_PATH')
    if p: return p
    found = sorted(glob.glob('/opt/pw-browsers/chromium-*/chrome-linux*/chrome'))
    return found[-1] if found else None


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
