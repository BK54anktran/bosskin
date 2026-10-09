#!/usr/bin/env python3
"""Video ngắn BossKin phong cách quảng cáo SaaS (~50 giây, 16:9): nền tối, chữ to 2 dòng, giao diện thật trong
khung laptop / điện thoại, nhạc nền sôi động + lồng tiếng.

  make_reel.py <thư mục ảnh (capture_*.py)> <thư mục giọng (tts.py với script_reel.json)> <file .mp4 ra> [--frames 3,10,20]
"""
import json, math, os, re, subprocess, sys, wave
import numpy as np
from PIL import Image, ImageDraw, ImageFilter, ImageFont

CAP, VO, OUT = sys.argv[1], sys.argv[2], sys.argv[3]
HERE = os.path.dirname(os.path.abspath(__file__))
LOGO = os.path.join(HERE, '..', '..', 'frontend', 'assets', 'images', 'bosskin_icons', 'round_512x512.png')
W, H, FPS = 1920, 1080, 30
FD = '/usr/share/fonts/opentype/inter/'
INK, MUTED = (240, 245, 255), (150, 165, 195)
ACCENT, ACCENT2, GREEN = (79, 140, 255), (125, 211, 252), (52, 211, 153)

_f = {}
def font(size, w='Bold', display=True):
    k = (size, w, display)
    if k not in _f: _f[k] = ImageFont.truetype(f'{FD}{"InterDisplay" if display else "Inter"}-{w}.otf', size)
    return _f[k]

def clamp(x): return max(0.0, min(1.0, x))
def ease(t): t = clamp(t); return 4 * t ** 3 if t < .5 else 1 - (-2 * t + 2) ** 3 / 2
def ease_out(t): t = clamp(t); return 1 - (1 - t) ** 3
def back_out(t):
    t = clamp(t); c1 = 1.70158; c3 = c1 + 1
    return 1 + c3 * (t - 1) ** 3 + c1 * (t - 1) ** 2
def appear(t, t0, d=0.5): return ease_out((t - t0) / d)
def track(keys, t):
    if t <= keys[0][0]: return keys[0][1]
    for (t0, v0), (t1, v1) in zip(keys, keys[1:]):
        if t <= t1:
            u = ease((t - t0) / max(t1 - t0, 1e-6))
            return tuple(a + (b - a) * u for a, b in zip(v0, v1)) if isinstance(v0, tuple) else v0 + (v1 - v0) * u
    return keys[-1][1]

_img = {}
def img(name):
    if name not in _img: _img[name] = Image.open(f'{CAP}/{name}.png').convert('RGB')
    return _img[name]

# ── nền tối có quầng sáng xanh ───────────────────────────────────────────────
def make_bg():
    y, x = np.mgrid[0:H, 0:W].astype(np.float32)
    base = np.zeros((H, W, 3), np.float32) + np.array([7, 11, 22], np.float32)
    g1 = np.exp(-(((x - 1500) / 700) ** 2 + ((y - 250) / 520) ** 2))[..., None]
    g2 = np.exp(-(((x - 250) / 600) ** 2 + ((y - 1000) / 420) ** 2))[..., None]
    base += g1 * np.array([28, 60, 150]) + g2 * np.array([10, 40, 70])
    im = Image.fromarray(np.clip(base, 0, 255).astype(np.uint8))
    d = ImageDraw.Draw(im, 'RGBA')                    # lưới chấm mờ
    for gx in range(40, W, 48):
        for gy in range(40, H, 48):
            d.point((gx, gy), fill=(255, 255, 255, 18))
    return im
BG = make_bg()

def rounded_mask(size, r):
    m = Image.new('L', size, 0); ImageDraw.Draw(m).rounded_rectangle((0, 0, size[0] - 1, size[1] - 1), r, fill=255); return m

def paste_alpha(base, layer, xy, alpha):
    if alpha <= 0: return
    if alpha < 1:
        a = layer.getchannel('A').point(lambda v: int(v * alpha)); layer = layer.copy(); layer.putalpha(a)
    base.paste(layer, (int(xy[0]), int(xy[1])), layer)

# ── chữ ──────────────────────────────────────────────────────────────────────
def text_layer(txt, f, color):
    bb = f.getbbox(txt); w, h = bb[2] + 8, bb[3] + 12
    l = Image.new('RGBA', (w, h), (0, 0, 0, 0)); ImageDraw.Draw(l).text((0, 0), txt, font=f, fill=color + (255,))
    return l
_tl = {}
def tl(txt, size, color, w='Bold', display=True):
    k = (txt, size, color, w, display)
    if k not in _tl: _tl[k] = text_layer(txt, font(size, w, display), color)
    return _tl[k]

def rise(fr, layer, x, y, t, t0, d=0.55, dy=36, anchor='l'):
    a = appear(t, t0, d)
    if a <= 0: return
    xx = x - (layer.width // 2 if anchor == 'c' else 0)
    paste_alpha(fr, layer, (xx, y + (1 - a) * dy), a)

def kicker(fr, txt, x, y, t, t0):
    a = appear(t, t0, 0.45)
    if a <= 0: return
    f = font(22, 'SemiBold', False); w = int(f.getlength(txt)) + 64; h = 46
    l = Image.new('RGBA', (w, h), (0, 0, 0, 0)); d = ImageDraw.Draw(l)
    d.rounded_rectangle((0, 0, w - 1, h - 1), 23, fill=ACCENT + (38,), outline=ACCENT + (150,), width=2)
    d.polygon([(22, 15), (32, 23), (22, 31)], fill=ACCENT2 + (255,))
    d.text((44, h // 2), txt, font=f, fill=ACCENT2 + (255,), anchor='lm')
    paste_alpha(fr, l, (x - (1 - a) * 20, y), a)

def checks(fr, items, x, y, t, t0, gap=58):
    for i, it in enumerate(items):
        a = appear(t, t0 + i * 0.22, 0.45)
        if a <= 0: continue
        l = Image.new('RGBA', (760, 46), (0, 0, 0, 0)); d = ImageDraw.Draw(l)
        d.ellipse((0, 7, 32, 39), fill=GREEN + (40,), outline=GREEN + (255,), width=2)
        d.line((9, 23, 14, 29, 24, 16), fill=GREEN + (255,), width=4, joint='curve')
        d.text((48, 23), it, font=font(28, 'Medium', False), fill=(205, 215, 235, 255), anchor='lm')
        paste_alpha(fr, l, (x - (1 - a) * 24, y + i * gap), a)

def headline(fr, l1, l2, x, y, t, t0, size=70):
    rise(fr, tl(l1, size, INK), x, y, t, t0)
    rise(fr, tl(l2, size, ACCENT), x, y + int(size * 1.12), t, t0 + 0.15)

def body(fr, txt, x, y, t, t0, width=700):
    f = font(29, 'Regular', False); words = txt.split(); lines, cur = [], ''
    for wd in words:
        n = (cur + ' ' + wd).strip()
        if f.getlength(n) > width and cur: lines.append(cur); cur = wd
        else: cur = n
    lines.append(cur)
    for i, ln in enumerate(lines): rise(fr, tl(ln, 29, MUTED, 'Regular', False), x, y + i * 42, t, t0 + 0.05 * i, dy=20)

# ── khung thiết bị ───────────────────────────────────────────────────────────
LW, LH = 880, 495           # màn hình laptop (16:9)
def laptop(screen):
    bz = 18; base_h = 30
    lw, lh = LW + bz * 2, LH + bz * 2
    l = Image.new('RGBA', (lw + 120, lh + base_h + 40), (0, 0, 0, 0)); d = ImageDraw.Draw(l)
    ox = 60
    d.rounded_rectangle((ox, 0, ox + lw, lh), 26, fill=(18, 20, 28, 255), outline=(70, 78, 98, 255), width=2)
    l.paste(screen, (ox + bz, bz), rounded_mask(screen.size, 8))
    d.ellipse((ox + lw // 2 - 4, 6, ox + lw // 2 + 4, 14), fill=(50, 54, 66, 255))
    d.polygon([(0, lh + 4), (lw + 120, lh + 4), (lw + 90, lh + base_h), (30, lh + base_h)], fill=(62, 68, 84, 255))
    d.rectangle((0, lh, lw + 120, lh + 6), fill=(92, 100, 120, 255))
    d.rounded_rectangle((lw // 2 + ox - 90, lh, lw // 2 + ox + 90, lh + 9), 4, fill=(40, 44, 56, 255))
    return l

def screen_view(images, cam, t, xfade=0.35, size=(LW, LH)):
    cx, cy, cw = track(cam, t); ch = cw * 9 / 16
    def render(n):
        im = img(n); s = im.width / 1600
        return im.resize(size, Image.BILINEAR, box=(cx * s, cy * s, (cx + cw) * s, (cy + ch) * s), reducing_gap=2.0)
    idx = max([i for i, (t0, _) in enumerate(images) if t0 <= t] or [0])
    sc = render(images[idx][1])
    if idx > 0 and t - images[idx][0] < xfade:
        sc = Image.blend(render(images[idx - 1][1]), sc, ease((t - images[idx][0]) / xfade))
    return sc, (cx, cy, cw)

CURSOR = None
def cursor_img():
    global CURSOR
    if CURSOR is None:
        s = Image.new('RGBA', (96, 96), (0, 0, 0, 0)); d = ImageDraw.Draw(s)
        pts = [(8, 4), (8, 76), (26, 60), (40, 90), (54, 84), (40, 54), (64, 54)]
        d.polygon(pts, fill=(255, 255, 255, 255)); d.polygon([(x * .82 + 3, y * .82 + 4) for x, y in pts], fill=(17, 17, 17, 255))
        CURSOR = s.resize((30, 30), Image.LANCZOS)
    return CURSOR

def draw_pointer(layer, x, y, clicks, t, touch=False):
    d = ImageDraw.Draw(layer, 'RGBA')
    for tc in clicks:
        u = (t - tc) / 0.5
        if 0 <= u <= 1:
            r = 10 + 40 * u; a = int(170 * (1 - u))
            d.ellipse((x - r, y - r, x + r, y + r), outline=ACCENT2 + (a,), width=3)
    if touch:
        d.ellipse((x - 20, y - 20, x + 20, y + 20), fill=(20, 20, 20, 70), outline=(255, 255, 255, 230), width=3)
    else:
        layer.paste(cursor_img(), (int(x) - 3, int(y) - 2), cursor_img())

PW = 360
def phone(images, t, xfade=0.35, touch=None):
    idx = max([i for i, (t0, _) in enumerate(images) if t0 <= t] or [0])
    def scr(n): return img(n).resize((PW, int(PW * 844 / 390)), Image.LANCZOS)
    s = scr(images[idx][1])
    if idx > 0 and t - images[idx][0] < xfade: s = Image.blend(scr(images[idx - 1][1]), s, ease((t - images[idx][0]) / xfade))
    st = 34; full = Image.new('RGB', (PW, s.height + st), (255, 255, 255)); full.paste(s, (0, st))
    d = ImageDraw.Draw(full); d.text((28, st // 2 + 1), '10:21', font=font(15, 'SemiBold', False), fill=(15, 23, 42), anchor='lm')
    d.rounded_rectangle((PW - 46, 12, PW - 22, 23), 3, outline=(15, 23, 42), width=2); d.rectangle((PW - 43, 15, PW - 29, 20), fill=(15, 23, 42))
    bz = 14; fw, fh = PW + bz * 2, full.height + bz * 2
    l = Image.new('RGBA', (fw, fh), (0, 0, 0, 0)); dd = ImageDraw.Draw(l)
    dd.rounded_rectangle((0, 0, fw - 1, fh - 1), 54, fill=(14, 16, 22, 255), outline=(80, 88, 108, 255), width=3)
    l.paste(full, (bz, bz), rounded_mask(full.size, 42))
    dd.rounded_rectangle((fw // 2 - 44, bz + 8, fw // 2 + 44, bz + 29), 11, fill=(14, 16, 22, 255))
    if touch:
        (px, py), clicks = touch
        draw_pointer(l, bz + px * PW / 390, bz + st + py * PW / 390, clicks, t, touch=True)
    return l

_glow = {}
def device_glow(fr, x, y, w, h, a):
    k = (w, h)
    if k not in _glow:
        g = Image.new('L', (w + 300, h + 300), 0)
        ImageDraw.Draw(g).rounded_rectangle((150, 150, 150 + w, 150 + h), 40, fill=120)
        _glow[k] = g.filter(ImageFilter.GaussianBlur(70))
    g = _glow[k].point(lambda v: int(v * a))
    fr.paste(ACCENT, (int(x) - 150, int(y) - 150), g)

def place_laptop(fr, images, cam, t, t_in=0.1, x=830, y=300, cursor=None, clicks=()):
    a = appear(t, t_in, 0.7)
    if a <= 0: return
    sc, camv = screen_view(images, cam, t)
    if cursor:
        cx, cy, cw = camv; s = LW / cw; px, py = track(cursor, t)
        sc = sc.convert('RGBA'); draw_pointer(sc, (px - cx) * s, (py - cy) * s, clicks, t)
    lp = laptop(sc)
    xx = x + (1 - a) * 140
    device_glow(fr, xx + 60, y, LW + 36, LH + 36, 0.55 * a)
    paste_alpha(fr, lp, (xx, y), a)

def place_phone(fr, images, t, t_in, x, y, touch=None):
    a = appear(t, t_in, 0.7)
    if a <= 0: return
    ph = phone(images, t, touch=touch)
    yy = y + (1 - a) * 120
    device_glow(fr, x, yy, ph.width, ph.height, 0.6 * a)
    paste_alpha(fr, ph, (x, yy), a)

# ── lồng tiếng → độ dài cảnh ─────────────────────────────────────────────────
cfg = json.load(open(os.path.join(HERE, 'script_reel.json'), encoding='utf-8'))
def dur(p): return float(subprocess.check_output(['ffprobe', '-v', 'error', '-show_entries', 'format=duration', '-of', 'csv=p=0', p]))
MIN = {'r1_logo': 3.0, 'r5_shifts': 5.2, 'r8_stats': 5.4, 'r9_cta': 7.6}
scenes, t = [], 0.0
for s in cfg['scenes']:
    vo = f'{VO}/{s["id"]}.mp3'; d = dur(vo) if s['vo'] and os.path.exists(vo) else 0
    lead = 0.35
    length = max(MIN.get(s['id'], 0), lead + d + 0.85)
    scenes.append(dict(id=s['id'], start=t, len=length, lead=lead, vo=vo if d else None))
    t += length
TOTAL = t
print(f'Tổng {TOTAL:.1f}s')

FULL = (0, 0, 1600)
LX, LY = 120, 300          # cột chữ bên trái

def r1(t, L):
    a = clamp(t / 0.3)
    fr = Image.new('RGB', (W, H), (244, 247, 252))
    g = Image.new('L', (W, H), 0); ImageDraw.Draw(g).ellipse((W // 2 - 700, H // 2 - 500, W // 2 + 700, H // 2 + 500), fill=255)
    fr = Image.composite(Image.new('RGB', (W, H), (255, 255, 255)), fr, g.filter(ImageFilter.GaussianBlur(200))) if not hasattr(r1, 'bg') else r1.bg
    r1.bg = fr; fr = fr.copy()
    s = back_out((t - 0.15) / 0.8); size = int(340 * max(0.01, 0.55 + 0.45 * s))
    lg = Image.open(LOGO).convert('RGBA').resize((size, size), Image.LANCZOS)
    paste_alpha(fr, lg, (W // 2 - size // 2, H // 2 - size // 2 - 30), clamp((t - 0.1) / 0.4))
    rise(fr, tl('Nền tảng chấm công & tính lương', 34, (60, 80, 120), 'Medium', False), W // 2, H // 2 + 190, t, 1.0, anchor='c')
    if t > L - 0.45:                              # chuyển sang nền tối
        fr = Image.blend(fr, BG, ease((t - (L - 0.45)) / 0.45))
    return fr

_hookbg = None
def r2(t, L):
    global _hookbg
    if _hookbg is None:
        strip = Image.new('RGB', (3 * 760, H), (0, 0, 0))
        for i, n in enumerate(['d_dashboard', 'p_checkin_after', 'd_payroll9']):
            im = img(n); im = im.resize((760, int(im.height * 760 / im.width))).crop((0, 200, 760, 200 + H)) if n.startswith('p') else im.resize((1920, 1080)).crop((0, 0, 760, H))
            strip.paste(im, (i * 760, 0))
        _hookbg = strip.filter(ImageFilter.GaussianBlur(16))
        _hookbg = Image.blend(_hookbg, Image.new('RGB', _hookbg.size, (6, 9, 18)), 0.72)
    off = int(track([(0, 0.0), (L, 260.0)], t))
    fr = _hookbg.crop((off, 0, off + W, H)) if _hookbg.width >= off + W else _hookbg.resize((W + 300, H)).crop((off, 0, off + W, H))
    d = ImageDraw.Draw(fr, 'RGBA')
    for i in (1, 2): d.line((W * i // 3 - off // 3, 0, W * i // 3 - off // 3, H), fill=(255, 255, 255, 16), width=2)
    rise(fr, tl('Chấm công, xếp ca, tính lương', 76, INK), W // 2, 420, t, 0.3, anchor='c')
    rise(fr, tl('không nên phức tạp đến thế.', 76, ACCENT), W // 2, 515, t, 1.4, anchor='c')
    return fr

def feature(kick, l1, l2, txt, items, device, k_t=0.25):
    def f(t, L):
        fr = BG.copy()
        kicker(fr, kick, LX, LY - 90, t, k_t)
        headline(fr, l1, l2, LX, LY, t, k_t + 0.15)
        body(fr, txt, LX, LY + 185, t, k_t + 0.5, width=640)
        checks(fr, items, LX, LY + 305, t, k_t + 0.9)
        device(fr, t, L)
        return fr
    return f

def dev_dashboard(fr, t, L):
    place_laptop(fr, [(0, 'd_dashboard')], [(0, FULL), (1.0, FULL), (3.2, (230, 170, 1050)), (L, (520, 170, 1050))], t,
                 cursor=[(0, (1100, 700)), (2.2, (660, 336)), (3.6, (1000, 336)), (L, (1420, 226))])

def dev_checkin(fr, t, L):
    tap = 2.6
    place_phone(fr, [(0, 'p_checkin_before'), (tap + 0.25, 'p_checkin_after')], t, 0.1, 1180, 150,
                touch=((104, 697), [tap]) if 1.8 < t < tap + 0.9 else None)

def dev_shifts(fr, t, L):
    place_laptop(fr, [(0, 'd_shifts'), (2.8, 'd_shift_rotation')],
                 [(0, FULL), (0.6, FULL), (2.4, (380, 190, 1220)), (2.8, (0, 0, 1200)), (L, (60, 20, 1100))], t,
                 cursor=[(0, (1000, 600)), (2.0, (483, 87)), (L, (640, 160))], clicks=[2.45])

def dev_leaves(fr, t, L):
    tc = 2.4
    place_laptop(fr, [(0, 'd_leaves'), (tc + 0.3, 'd_leaves_after')], [(0, FULL), (0.8, FULL), (2.0, (236, 225, 1000)), (L, (236, 225, 1000))], t,
                 cursor=[(0, (900, 650)), (1.8, (450, 300)), (tc - 0.2, (580, 391)), (L, (600, 420))], clicks=[tc])

def dev_payroll(fr, t, L):
    place_laptop(fr, [(0, 'd_payroll9')], [(0, FULL), (0.8, FULL), (2.8, (230, 95, 1000)), (L, (230, 140, 1000))], t, x=740, y=300)
    place_phone(fr, [(0, 'p_payslips'), (2.9, 'p_payslip_detail')], t, 1.6, 1500, 190,
                touch=((200, 156), [2.6]) if 2.0 < t < 3.4 else None)

def r8(t, L):
    fr = BG.copy()
    rise(fr, tl('Tiết kiệm hàng giờ', 82, INK), W // 2, 230, t, 0.2, anchor='c')
    rise(fr, tl('mỗi kỳ chốt công.', 82, ACCENT), W // 2, 322, t, 0.35, anchor='c')
    stats = [('< 1 phút', 'duyệt công cả kỳ cho', '300 nhân viên'), ('8', 'báo cáo Excel', 'có sẵn, xuất trong vài giây'),
             ('2 lớp', 'xác thực bảo vệ', 'tài khoản quản trị')]
    cw, chh, gap = 470, 300, 50; x0 = (W - (3 * cw + 2 * gap)) // 2
    for i, (big, s1, s2) in enumerate(stats):
        a = appear(t, 0.9 + i * 0.25, 0.55)
        if a <= 0: continue
        card = Image.new('RGBA', (cw, chh), (0, 0, 0, 0)); d = ImageDraw.Draw(card)
        d.rounded_rectangle((0, 0, cw - 1, chh - 1), 28, fill=(255, 255, 255, 14), outline=(255, 255, 255, 40), width=2)
        d.text((cw // 2, 110), big, font=font(88, 'Bold'), fill=ACCENT2 + (255,), anchor='mm')
        d.text((cw // 2, 200), s1, font=font(28, 'Medium', False), fill=(205, 215, 235, 255), anchor='mm')
        d.text((cw // 2, 240), s2, font=font(28, 'Medium', False), fill=(205, 215, 235, 255), anchor='mm')
        paste_alpha(fr, card, (x0 + i * (cw + gap), 520 + (1 - a) * 40), a)
    return fr

def r9(t, L):
    fr = BG.copy()
    a = appear(t, 0.1, 0.7); size = int(200 * (0.8 + 0.2 * a))
    lg = Image.open(LOGO).convert('RGBA').resize((size, size), Image.LANCZOS)
    paste_alpha(fr, lg, (W // 2 - size // 2, 170 + (200 - size) // 2), a)
    rise(fr, tl('Quản lý nhân sự gọn nhẹ.', 76, INK), W // 2, 420, t, 0.5, anchor='c')
    rise(fr, tl('Tập trung phát triển.', 76, ACCENT), W // 2, 510, t, 0.65, anchor='c')
    ab = appear(t, 1.4, 0.6)
    if ab > 0:
        bw, bh = 940, 96; l = Image.new('RGBA', (bw, bh), (0, 0, 0, 0)); d = ImageDraw.Draw(l)
        d.rounded_rectangle((0, 0, bw - 1, bh - 1), 48, fill=(255, 255, 255, 18), outline=(255, 255, 255, 60), width=2)
        d.text((44, bh // 2), 'Chấm công · Ca làm · Nghỉ phép · Lương', font=font(28, 'Medium', False), fill=(200, 212, 235, 255), anchor='lm')
        d.rounded_rectangle((bw - 250, 10, bw - 10, bh - 10), 38, fill=ACCENT + (255,))
        d.text((bw - 130, bh // 2), 'Dùng thử  →', font=font(30, 'Bold', False), fill=(255, 255, 255, 255), anchor='mm')
        paste_alpha(fr, l, (W // 2 - bw // 2, 660 + (1 - ab) * 30), ab)
    if t > L - 0.8: fr = Image.blend(fr, Image.new('RGB', (W, H), (0, 0, 0)), ease((t - (L - 0.8)) / 0.8))
    return fr

FN = {
    'r1_logo': r1, 'r2_hook': r2,
    'r3_allinone': feature('NỀN TẢNG NHÂN SỰ TẤT CẢ TRONG MỘT', 'Đã có BossKin.', 'Mọi thứ trong 1 nơi.',
        'Thay bảng chấm công giấy, file Excel và tin nhắn rời rạc bằng một ứng dụng.',
        ['Biết ngay hôm nay ai có mặt, ai nghỉ', 'Công, ca, phép, lương liên thông', 'Phân quyền theo vai trò, phòng ban'], dev_dashboard),
    'r4_checkin': feature('CHẤM CÔNG DI ĐỘNG', 'Chấm công', 'trên điện thoại.',
        'Mở app, bấm Check-in. Không cần máy chấm công.',
        ['Định vị GPS quanh văn phòng', 'Mỗi tài khoản gắn đúng 1 máy', 'Chặn vị trí giả lập'], dev_checkin),
    'r5_shifts': feature('XẾP CA', 'Xếp ca cả xưởng.', 'Xong trong vài phút.',
        'Bảng phân ca theo kỳ lương, nhập và xuất bằng Excel.',
        ['Ca cố định, ca đêm, ca linh hoạt', 'Mẫu xoay ca tự sinh lịch', 'Nhân viên xin đổi ca với nhau'], dev_shifts),
    'r6_leaves': feature('NGHỈ PHÉP & ĐƠN TỪ', 'Duyệt đơn', 'trong 1 chạm.',
        'Đơn nghỉ, đơn sửa giờ gửi ngay trên app tới người duyệt.',
        ['Sổ phép tự trừ đúng ngày có ca', 'Nghỉ theo ngày hoặc theo giờ', 'Huỷ đơn tự hoàn phép'], dev_leaves),
    'r7_payroll': feature('TÍNH LƯƠNG', 'Lương tự tính.', 'Phiếu lương tận tay.',
        'Từ ngày công đã chốt và công thức riêng của doanh nghiệp.',
        ['BHXH, BHYT, BHTN, thuế TNCN', 'Duyệt, chi trả, xuất Excel', 'Nhân viên xem phiếu trên điện thoại'], dev_payroll),
    'r8_stats': r8, 'r9_cta': r9,
}

# ── nhạc nền tổng hợp (112 bpm: trống, bass, hợp âm rải) ─────────────────────
def music(total, sr=44100):
    n = int(total * sr); out = np.zeros(n, np.float32)
    bpm = 112; beat = 60 / bpm; bar = beat * 4
    hz = lambda m: 440 * 2 ** ((m - 69) / 12)
    prog = [[57, 60, 64], [53, 57, 60], [48, 52, 55], [55, 59, 62]]       # Am F C G
    rng = np.random.default_rng(3)
    def add(sig, at, gain):
        i = int(at * sr)
        if i >= n: return
        j = min(n, i + len(sig)); out[i:j] += sig[:j - i] * gain
    tt = lambda d: np.arange(int(d * sr)) / sr
    k = tt(0.35); kick = np.sin(2 * np.pi * (45 * k + 90 * (1 - np.exp(-k * 30)) / 30)) * np.exp(-k * 9)
    c = tt(0.2); clap = rng.standard_normal(len(c)) * np.exp(-c * 25); clap = np.convolve(clap, np.ones(6) / 6, 'same')
    h = tt(0.06); hat = np.diff(rng.standard_normal(len(h) + 1)) * np.exp(-h * 70)
    intro = 3.0                                     # cảnh logo: chỉ pad nhẹ
    nbars = int(total / bar) + 1
    for b in range(nbars):
        t0 = b * bar; ch = prog[b % 4]
        seg = tt(bar + 0.3); env = np.minimum(1, seg / 0.4) * np.minimum(1, np.maximum(0, (bar + 0.3 - seg) / 0.4))
        pad = sum(np.sin(2 * np.pi * hz(m) * seg) + 0.4 * np.sin(2 * np.pi * hz(m) * 1.004 * seg) for m in ch) * env
        add(pad, t0, 0.05)
        if t0 < intro - 0.01: continue
        for q in range(4):
            add(kick, t0 + q * beat, 0.9)
            if q in (1, 3): add(clap, t0 + q * beat, 0.35)
        for e in range(8): add(hat, t0 + e * beat / 2 + beat / 4, 0.18)
        bs = tt(beat * 0.9)
        for q in range(4):
            add(np.sign(np.sin(2 * np.pi * hz(ch[0] - 24) * bs)) * np.exp(-bs * 3) * 0.6 + np.sin(2 * np.pi * hz(ch[0] - 24) * bs) * np.exp(-bs * 3),
                t0 + q * beat, 0.16)
        for e in range(8):
            m = ch[[0, 1, 2, 1, 0, 2, 1, 2][e]] + 12; s2 = tt(0.5)
            add(np.sin(2 * np.pi * hz(m) * s2) * np.exp(-s2 * 7), t0 + e * beat / 2, 0.08)
    out = np.convolve(out, np.ones(4) / 4, 'same')
    tg = np.arange(n) / sr; out *= np.minimum(1, tg / 0.8) * np.minimum(1, (total - tg) / 1.8)
    return out / (np.abs(out).max() + 1e-9) * 0.9

def build_audio(path):
    sr = 44100; bed = music(TOTAL, sr); tmp = path + '.bed.wav'
    with wave.open(tmp, 'wb') as w:
        w.setnchannels(1); w.setsampwidth(2); w.setframerate(sr); w.writeframes((bed * 32767).astype(np.int16).tobytes())
    ins, filt, k = ['-i', tmp], [], 0
    for s in scenes:
        if not s['vo']: continue
        k += 1; ins += ['-i', s['vo']]; ms = int((s['start'] + s['lead']) * 1000)
        filt.append(f'[{k}:a]aresample={sr},adelay={ms}|{ms},apad[v{k}]')
    filt.append(''.join(f'[v{i}]' for i in range(1, k + 1)) + f'amix=inputs={k}:normalize=0,atrim=0:{TOTAL:.2f},volume=1.7,asplit=2[vo][vosc]')
    filt.append('[0:a]volume=0.30[bed]')
    filt.append('[bed][vosc]sidechaincompress=threshold=0.04:ratio=5:attack=15:release=350[duck]')
    filt.append(f'[duck][vo]amix=inputs=2:normalize=0,alimiter=limit=0.95,atrim=0:{TOTAL:.2f}[out]')
    subprocess.run(['ffmpeg', '-y', '-loglevel', 'error', *ins, '-filter_complex', ';'.join(filt), '-map', '[out]', '-ac', '2', '-ar', str(sr), path], check=True)
    os.remove(tmp)

def frame_at(tg):
    si = max(i for i, s in enumerate(scenes) if s['start'] <= tg + 1e-9); sc = scenes[si]; tl_ = tg - sc['start']
    fr = FN[sc['id']](tl_, sc['len'])
    XF = 0.3
    if si > 1 and tl_ < XF:                         # cảnh logo tự chuyển nền, các cảnh sau mờ chéo
        ps = scenes[si - 1]; fr = Image.blend(FN[ps['id']](ps['len'] - 1 / FPS, ps['len']), fr, ease(tl_ / XF))
    return fr

if __name__ == '__main__':
    if len(sys.argv) > 4 and sys.argv[4] == '--frames':
        for tg in [float(x) for x in sys.argv[5].split(',')]: frame_at(tg).save(f'{OUT}_{tg:05.1f}.png')
        sys.exit()
    audio = OUT + '.audio.wav'; build_audio(audio)
    ff = subprocess.Popen(['ffmpeg', '-y', '-loglevel', 'error', '-f', 'rawvideo', '-pix_fmt', 'rgb24', '-s', f'{W}x{H}', '-r', str(FPS),
                           '-i', '-', '-i', audio, '-c:v', 'libx264', '-preset', 'slow', '-crf', '19', '-pix_fmt', 'yuv420p',
                           '-movflags', '+faststart', '-c:a', 'aac', '-b:a', '192k', '-shortest', OUT], stdin=subprocess.PIPE)
    for k in range(int(TOTAL * FPS)):
        ff.stdin.write(frame_at(k / FPS).tobytes())
        if k % 150 == 0: print(f'  {k / FPS:5.1f}s / {TOTAL:.1f}s', flush=True)
    ff.stdin.close(); ff.wait(); os.remove(audio); print('Xong:', OUT)
