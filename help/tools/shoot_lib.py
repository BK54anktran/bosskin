"""Thư viện chụp màn hình cho trang trợ giúp BossKin (Playwright + cây semantics của Flutter web).

Flutter web vẽ lên canvas nên không có DOM thường. Bật semantics (bấm flt-semantics-placeholder) thì mỗi nút / ô nhập
có một phần tử <flt-semantics> mang aria-label → tìm được theo chữ hiển thị, lấy toạ độ để bấm và để vẽ khung đánh dấu.

Ảnh lưu WebP ở help/img/<id>.webp; khung đỏ + số thứ tự bước vẽ bằng Pillow lên ảnh gốc.
"""
import asyncio
import difflib
import hashlib
import io
import json
import os
import re
import unicodedata

import pytesseract

from PIL import Image, ImageDraw, ImageFont
from playwright.async_api import async_playwright

WEB = os.environ.get('HELP_WEB', 'http://localhost:3000')
PW = os.environ.get('HELP_PW', 'AnPhat2026demo')
W, H, DPR = 1440, 900, 1.5
HERE = os.path.dirname(os.path.abspath(__file__))
OUT = os.environ.get('HELP_IMG', os.path.join(HERE, '..', 'img'))
RAW = os.path.join(HERE, '.raw')
FONT = '/usr/share/fonts/truetype/dejavu/DejaVuSans-Bold.ttf'
RED = (229, 57, 53)

_FIND_JS = r"""
([needle, role, nth, exact]) => {
const labelOf = e => {
  const own = e.getAttribute('aria-label') || e.getAttribute('placeholder') || '';
  if (own) return own;
  const direct = Array.from(e.childNodes).filter(c => c.nodeType === 3).map(c => c.textContent).join(' ').trim();
  if (direct) return direct;
  if (!e.querySelector('flt-semantics')) return (e.textContent || '').trim();
  return '';
};

  const norm = s => (s || '').replace(/\s+/g, ' ').trim().toLowerCase();
  const n = norm(needle);
  const els = Array.from(document.querySelectorAll('flt-semantics, flt-semantics input, flt-semantics textarea, input, textarea'));
  const cands = [];
  for (const e of els) {
    const r = e.getBoundingClientRect();
    if (r.width < 2 || r.height < 2) continue;
    if (r.bottom < 0 || r.top > window.innerHeight || r.right < 0 || r.left > window.innerWidth) continue;
    if (role && (e.getAttribute('role') || (e.tagName === 'INPUT' || e.tagName === 'TEXTAREA' ? 'textbox' : '')) !== role) continue;
    let txt = labelOf(e);
    const t = norm(txt);
    if (!t) continue;
    const score = t === n ? 0 : (!exact && t.startsWith(n) ? 1 : (!exact && t.includes(n) ? 2 : -1));
    if (score < 0) continue;
    cands.push({score, area: r.width * r.height, x: r.left, y: r.top, w: r.width, h: r.height, label: txt.slice(0, 80)});
  }
  cands.sort((a, b) => a.score - b.score || a.y - b.y || a.x - b.x || a.area - b.area);
  return cands[nth] || null;
}
"""

_DUMP_JS = r"""
() => { const labelOf = e => {
  const own = e.getAttribute('aria-label') || e.getAttribute('placeholder') || '';
  if (own) return own;
  const direct = Array.from(e.childNodes).filter(c => c.nodeType === 3).map(c => c.textContent).join(' ').trim();
  if (direct) return direct;
  if (!e.querySelector('flt-semantics')) return (e.textContent || '').trim();
  return '';
};
 return Array.from(document.querySelectorAll('flt-semantics, flt-semantics input')).map(e => {
  const r = e.getBoundingClientRect();
  const own = labelOf(e);
  return {role: e.getAttribute('role') || e.tagName.toLowerCase(), label: (own || '').replace(/\s+/g, ' ').trim().slice(0, 70),
          x: Math.round(r.left), y: Math.round(r.top), w: Math.round(r.width), h: Math.round(r.height)};
}).filter(o => o.label && o.w > 2 && o.h > 2 && o.y < window.innerHeight && o.y + o.h > 0) }
"""


_OCR_CACHE = {}


def _norm(s):
    s = unicodedata.normalize('NFD', s.replace('đ', 'd').replace('Đ', 'D'))
    s = ''.join(c for c in s if not unicodedata.combining(c)).lower()
    return re.sub(r'[^a-z0-9]', '', s)


def ocr_boxes(png_bytes, needle, region=None):
    """Tìm cụm chữ trên ảnh (OCR tiếng Việt, so khớp bỏ dấu, bỏ khoảng trắng). Trả list box toạ độ CSS."""
    im = Image.open(io.BytesIO(png_bytes))
    s = im.width / W
    ox = oy = 0
    if region:
        x, y, w, h = region
        im = im.crop((int(x * s), int(y * s), int((x + w) * s), int((y + h) * s))); ox, oy = x, y
    key = hashlib.md5(png_bytes).hexdigest() + str(region)
    d = _OCR_CACHE.get(key)
    if d is None:
        d = pytesseract.image_to_data(im.convert('L'), lang='vie', config='--psm 3', output_type=pytesseract.Output.DICT)
        _OCR_CACHE.clear(); _OCR_CACHE[key] = d
    n = _norm(needle)
    groups = {}
    for i in range(len(d['text'])):
        if d['text'][i].strip():
            groups.setdefault((d['block_num'][i], d['par_num'][i], d['line_num'][i]), []).append(i)
    lines = [sorted(v, key=lambda i: d['left'][i]) for v in groups.values()]
    out = []
    for ln in lines:
        txt, idx = '', []
        for i in ln:
            w = _norm(d['text'][i]); txt += w; idx += [i] * len(w)
        hits = []
        start = txt.find(n)
        while start >= 0 and n:
            hits.append((start, len(n))); start = txt.find(n, start + 1)
        if not hits and len(n) >= 5:
            best = None
            for L_ in (len(n) - 1, len(n), len(n) + 1):
                for st in range(0, max(1, len(txt) - L_ + 1)):
                    r = difflib.SequenceMatcher(None, n, txt[st:st + L_]).ratio()
                    if r >= 0.82 and (best is None or r > best[0]): best = (r, st, L_)
            if best: hits.append((best[1], best[2]))
        for start, ln_ in hits:
            sel = sorted(set(idx[start:start + ln_]))
            x0 = min(d['left'][i] for i in sel); y0 = min(d['top'][i] for i in sel)
            x1 = max(d['left'][i] + d['width'][i] for i in sel); y1 = max(d['top'][i] + d['height'][i] for i in sel)
            out.append({'x': x0 / s + ox - 5, 'y': y0 / s + oy - 5, 'w': (x1 - x0) / s + 10, 'h': (y1 - y0) / s + 10, 'label': needle})
    out.sort(key=lambda b: (round(b['y'] / 6), b['x']))
    return out


class Shooter:
    def __init__(self, page):
        self.page = page
        self.manifest = {}

    # ── điều hướng ────────────────────────────────────────────────────────
    async def semantics(self):
        await self.page.evaluate("() => { const e = document.querySelector('flt-semantics-placeholder'); if (e) e.click(); }")
        await self.page.wait_for_timeout(700)

    async def goto(self, route, wait=3500):
        await self.page.goto(WEB + route, wait_until='networkidle')
        await self.page.wait_for_timeout(wait)
        await self.semantics()

    async def login(self, email, pw=PW):
        await self.page.context.clear_cookies()
        await self.page.goto(WEB + '/login', wait_until='networkidle')
        await self.page.evaluate('() => { try { localStorage.clear(); sessionStorage.clear(); indexedDB.deleteDatabase("bosskin"); } catch (e) {} }')
        await self.page.goto(WEB + '/login', wait_until='networkidle')
        await self.page.wait_for_timeout(3500)
        await self.semantics()
        await self.type('Email', email, role='textbox')
        await self.type('Mật khẩu', pw, role='textbox')
        await self.page.keyboard.press('Enter')
        await self.page.wait_for_timeout(5000)
        await self.semantics()

    # ── tìm / bấm ─────────────────────────────────────────────────────────
    async def find(self, label, role=None, nth=0, exact=False, timeout=4000, region=None, ocr=None):
        """Tìm theo semantics (nhãn của Flutter); không thấy thì OCR chữ trên màn hình.
        ocr=True: chỉ OCR (dùng cho chữ trong danh sách / menu không có nhãn riêng)."""
        if not ocr:
            for _ in range(max(1, timeout // 400)):
                box = await self.page.evaluate(_FIND_JS, [label, role, nth, exact])
                if box and not region: return box
                if box and region:
                    x, y, w, h = region
                    if x <= box['x'] <= x + w and y <= box['y'] <= y + h: return box
                if ocr is False: break
                await self.page.wait_for_timeout(400)
                await self.semantics()
                if box is None and _ >= 2: break
        if ocr is not False:
            for _ in range(3):
                boxes = ocr_boxes(await self.page.screenshot(), label, region)
                if len(boxes) > nth: return boxes[nth]
                await self.page.wait_for_timeout(800)
        raise RuntimeError(f'Không thấy "{label}" (role={role})')

    def box(self, x, y, w, h, label=''):
        return {'x': x, 'y': y, 'w': w, 'h': h, 'label': label}

    async def click(self, label, role=None, nth=0, exact=False, wait=1500, dx=0.5, dy=0.5, region=None, ocr=None):
        b = label if isinstance(label, dict) else await self.find(label, role, nth, exact, region=region, ocr=ocr)
        await self.page.mouse.click(b['x'] + b['w'] * dx, b['y'] + b['h'] * dy)
        await self.page.wait_for_timeout(wait)
        await self.semantics()
        return b

    async def type(self, label, text, role='textbox', nth=0, clear=True):
        b = await self.click(label, role=role, nth=nth, wait=300)
        if clear:
            await self.page.keyboard.press('Control+A')
            await self.page.keyboard.press('Backspace')
        await self.page.keyboard.type(text, delay=8)
        await self.page.wait_for_timeout(300)
        return b

    async def scroll(self, dy, x=900, y=500):
        await self.page.mouse.move(x, y)
        steps = max(1, abs(dy) // 200)
        for _ in range(steps):
            await self.page.mouse.wheel(0, 200 if dy > 0 else -200)
            await self.page.wait_for_timeout(80)
        await self.page.wait_for_timeout(700)
        await self.semantics()

    async def esc(self, wait=800):
        await self.page.keyboard.press('Escape')
        await self.page.wait_for_timeout(wait)
        await self.semantics()

    async def dump(self, name=None):
        items = await self.page.evaluate(_DUMP_JS)
        if name:
            os.makedirs(RAW, exist_ok=True)
            with open(os.path.join(RAW, name + '.json'), 'w', encoding='utf-8') as f:
                json.dump(items, f, ensure_ascii=False, indent=0)
        return items

    # ── chụp ──────────────────────────────────────────────────────────────
    async def shot(self, sid, marks=(), wait=600, clip=None, caption=None):
        """marks: list nhãn (str) / (nhãn, role) / dict box; vẽ khung + số 1, 2, 3… theo thứ tự."""
        await self.page.wait_for_timeout(wait)
        boxes = []
        for m in marks:
            if isinstance(m, dict): boxes.append(m)
            elif isinstance(m, tuple) and isinstance(m[-1], dict): boxes.append(await self.find(*m[:-1], **m[-1]))
            elif isinstance(m, tuple): boxes.append(await self.find(*m))
            else: boxes.append(await self.find(m))
        os.makedirs(RAW, exist_ok=True); os.makedirs(OUT, exist_ok=True)
        raw = os.path.join(RAW, sid + '.png')
        await self.page.screenshot(path=raw)
        annotate(raw, os.path.join(OUT, sid + '.webp'), boxes, clip)
        self.manifest[sid] = {'caption': caption, 'marks': [b.get('label', '') for b in boxes]}
        print('  ảnh', sid, '·', len(boxes), 'đánh dấu')


def annotate(src, dst, boxes, clip=None):
    im = Image.open(src).convert('RGB')
    s = im.width / W
    d = ImageDraw.Draw(im)
    font = ImageFont.truetype(FONT, int(15 * s))
    for i, b in enumerate(boxes, 1):
        pad = 4 * s
        x0, y0 = b['x'] * s - pad, b['y'] * s - pad
        x1, y1 = (b['x'] + b['w']) * s + pad, (b['y'] + b['h']) * s + pad
        d.rounded_rectangle([x0, y0, x1, y1], radius=int(8 * s), outline=RED, width=int(3 * s))
        if len(boxes) > 1 or True:
            r = 13 * s
            cx, cy = x0, y0
            cx = max(r + 2, cx); cy = max(r + 2, cy)
            d.ellipse([cx - r, cy - r, cx + r, cy + r], fill=RED, outline=(255, 255, 255), width=int(2 * s))
            t = str(i)
            tw = d.textlength(t, font=font)
            d.text((cx - tw / 2, cy - 9.5 * s), t, fill=(255, 255, 255), font=font)
    if clip:
        x, y, w, h = clip
        im = im.crop((int(x * s), int(y * s), int((x + w) * s), int((y + h) * s)))
    im.save(dst, 'WEBP', quality=82, method=6)


async def run(job):
    """job(sh) — hàm async nhận Shooter."""
    async with async_playwright() as p:
        b = await p.chromium.launch(args=['--no-proxy-server', '--hide-scrollbars'])
        ctx = await b.new_context(viewport={'width': W, 'height': H}, device_scale_factor=DPR, locale='vi-VN',
                                  timezone_id='Asia/Ho_Chi_Minh', geolocation={'latitude': 10.7769, 'longitude': 106.7009},
                                  permissions=['geolocation'])
        page = await ctx.new_page()
        sh = Shooter(page)
        try:
            await job(sh)
        finally:
            os.makedirs(OUT, exist_ok=True); mf = os.path.join(OUT, 'manifest.json')
            old = json.load(open(mf, encoding='utf-8')) if os.path.exists(mf) else {}
            old.update(sh.manifest)
            json.dump(old, open(mf, 'w', encoding='utf-8'), ensure_ascii=False, indent=1, sort_keys=True)
            await b.close()
