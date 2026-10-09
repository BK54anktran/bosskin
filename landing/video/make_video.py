#!/usr/bin/env python3
"""Dựng video giới thiệu BossKin từ ảnh chụp màn hình + lồng tiếng.

  make_video.py <thư mục ảnh (capture_*.py)> <thư mục lồng tiếng (tts.py: *.mp3, *.srt)> <file .mp4 ra>

Chuyển động (zoom, con trỏ, chuyển cảnh) dựng ở đây nên video mượt bất kể máy chụp chậm.
Toạ độ trong cảnh là toạ độ CSS của ảnh chụp: máy tính 1600x900, điện thoại 390x844 (ảnh @2x).
"""
import json, math, os, re, subprocess, sys, wave
import numpy as np
from PIL import Image, ImageDraw, ImageFilter, ImageFont

CAP, VO, OUT = sys.argv[1], sys.argv[2], sys.argv[3]
HERE = os.path.dirname(os.path.abspath(__file__))
LOGO = os.path.join(HERE, '..', '..', 'frontend', 'assets', 'images', 'bosskin_icons', 'round_512x512.png')
W, H, FPS = 1920, 1080, 30
FONT_DIR = '/usr/share/fonts/opentype/inter/'
NAVY, NAVY2 = (11, 22, 48), (22, 46, 96)
BLUE, SKY, GREEN, WHITE = (37, 99, 235), (95, 169, 210), (16, 185, 129), (255, 255, 255)

_fonts = {}
def font(size, weight='SemiBold', display=False):
    k = (size, weight, display)
    if k not in _fonts:
        _fonts[k] = ImageFont.truetype(f'{FONT_DIR}{"InterDisplay" if display else "Inter"}-{weight}.otf', size)
    return _fonts[k]

def ease(t):                      # easeInOutCubic
    t = max(0.0, min(1.0, t))
    return 4 * t * t * t if t < .5 else 1 - (-2 * t + 2) ** 3 / 2

def track(keys, t):
    """keys: [(time, value)], value = số hoặc tuple; nội suy có ease giữa các mốc."""
    if t <= keys[0][0]: return keys[0][1]
    for (t0, v0), (t1, v1) in zip(keys, keys[1:]):
        if t <= t1:
            u = ease((t - t0) / max(t1 - t0, 1e-6))
            if isinstance(v0, tuple): return tuple(a + (b - a) * u for a, b in zip(v0, v1))
            return v0 + (v1 - v0) * u
    return keys[-1][1]

_img = {}
def img(name):
    if name not in _img: _img[name] = Image.open(f'{CAP}/{name}.png').convert('RGB')
    return _img[name]

def gradient(c0, c1, w=W, h=H, diag=True):
    y, x = np.mgrid[0:h, 0:w]
    u = ((x / w + y / h) / 2) if diag else (y / h)
    a = np.array(c0)[None, None] * (1 - u[..., None]) + np.array(c1)[None, None] * u[..., None]
    return Image.fromarray(a.astype(np.uint8))

BG = gradient(NAVY, NAVY2)
glow = Image.new('L', (W, H), 0); ImageDraw.Draw(glow).ellipse((1100, -300, 2300, 800), fill=90)
BG = Image.composite(Image.new('RGB', (W, H), (40, 90, 190)), BG, glow.filter(ImageFilter.GaussianBlur(220)))

def rounded(im, r):
    m = Image.new('L', im.size, 0); ImageDraw.Draw(m).rounded_rectangle((0, 0, im.width - 1, im.height - 1), r, fill=255)
    return m

def shadow_paste(base, im, x, y, r=28, blur=30, alpha=110, offset=18):
    sh = Image.new('L', (im.width + blur * 4, im.height + blur * 4), 0)
    ImageDraw.Draw(sh).rounded_rectangle((blur * 2, blur * 2, blur * 2 + im.width, blur * 2 + im.height), r, fill=alpha)
    sh = sh.filter(ImageFilter.GaussianBlur(blur))
    base.paste(Image.new('RGB', sh.size, (0, 0, 0)), (int(x) - blur * 2, int(y) - blur * 2 + offset), sh)
    base.paste(im, (int(x), int(y)), rounded(im, r))

# ── phần tử phủ ──────────────────────────────────────────────────────────────
def cursor_sprite():
    s = Image.new('RGBA', (96, 96), (0, 0, 0, 0)); d = ImageDraw.Draw(s)
    pts = [(8, 4), (8, 76), (26, 60), (40, 90), (54, 84), (40, 54), (64, 54)]
    d.polygon(pts, fill=(255, 255, 255, 255)); d.polygon([(x * .82 + 3, y * .82 + 4) for x, y in pts], fill=(17, 17, 17, 255))
    return s.resize((36, 36), Image.LANCZOS)
CURSOR = cursor_sprite()

def draw_cursor(fr, x, y, clicks, t, touch=False):
    d = ImageDraw.Draw(fr, 'RGBA')
    for tc in clicks:
        u = (t - tc) / 0.55
        if 0 <= u <= 1:
            r = 14 + 46 * u; a = int(150 * (1 - u))
            d.ellipse((x - r, y - r, x + r, y + r), fill=(37, 99, 235, a // 2), outline=(255, 255, 255, a), width=3)
    pressed = any(0 <= t - tc < 0.15 for tc in clicks)
    if touch:
        r = 22 if not pressed else 18
        d.ellipse((x - r, y - r, x + r, y + r), fill=(20, 20, 20, 70), outline=(255, 255, 255, 230), width=3)
    else:
        sp = CURSOR if not pressed else CURSOR.resize((31, 31))
        fr.paste(sp, (int(x) - 3, int(y) - 2), sp)

def pill(fr, text, x, y, alpha=1.0, size=34, dot=BLUE, bg=(255, 255, 255), fg=(15, 23, 42)):
    if alpha <= 0: return
    f = font(size, 'SemiBold'); tw = f.getlength(text); h = size + 30
    layer = Image.new('RGBA', (int(tw) + h + 40, h), (0, 0, 0, 0)); d = ImageDraw.Draw(layer)
    d.rounded_rectangle((0, 0, layer.width - 1, h - 1), h // 2, fill=bg + (int(235 * alpha),))
    d.ellipse((22, h // 2 - 8, 38, h // 2 + 8), fill=dot + (int(255 * alpha),))
    d.text((52, h // 2), text, font=f, fill=fg + (int(255 * alpha),), anchor='lm')
    fr.paste(layer, (int(x), int(y)), layer)

def subtitle(fr, text):
    if not text: return
    f = font(40, 'Medium'); lines = wrap(text, f, 1500)
    lh = 54; h = lh * len(lines) + 28; w = int(max(f.getlength(l) for l in lines)) + 64
    x, y = (W - w) // 2, H - h - 46
    layer = Image.new('RGBA', (w, h), (0, 0, 0, 0)); d = ImageDraw.Draw(layer)
    d.rounded_rectangle((0, 0, w - 1, h - 1), 18, fill=(8, 14, 32, 190))
    for i, l in enumerate(lines):
        d.text((w // 2, 14 + lh * i + lh // 2), l, font=f, fill=(255, 255, 255, 255), anchor='mm')
    fr.paste(layer, (x, y), layer)

def wrap(text, f, maxw):
    words, lines, cur = text.split(), [], ''
    for wd in words:
        nxt = (cur + ' ' + wd).strip()
        if f.getlength(nxt) > maxw and cur: lines.append(cur); cur = wd
        else: cur = nxt
    return lines + [cur] if cur else lines

def chip(fr, text, x, y, alpha, icon_color=GREEN, size=36):
    if alpha <= 0: return
    dx = int((1 - alpha) * 40)
    f = font(size, 'SemiBold'); h = 84; w = int(f.getlength(text)) + 120
    layer = Image.new('RGBA', (w, h), (0, 0, 0, 0)); d = ImageDraw.Draw(layer)
    d.rounded_rectangle((0, 0, w - 1, h - 1), 22, fill=(255, 255, 255, int(28 * alpha)), outline=(255, 255, 255, int(70 * alpha)), width=2)
    d.ellipse((24, h // 2 - 18, 60, h // 2 + 18), fill=icon_color + (int(255 * alpha),))
    d.line((33, h // 2, 40, h // 2 + 8, 52, h // 2 - 8), fill=(255, 255, 255, int(255 * alpha)), width=5)
    d.text((80, h // 2), text, font=f, fill=(255, 255, 255, int(255 * alpha)), anchor='lm')
    fr.paste(layer, (int(x) + dx, int(y)), layer)

# ── khung cảnh ───────────────────────────────────────────────────────────────
CW, CH = 1712, 963                       # khung cửa sổ app trong video
WX, WY = (W - CW) // 2, 104
_WIN_BASE = None; _WIN_MASK = None
def window_base():
    global _WIN_BASE, _WIN_MASK
    if _WIN_BASE is None:
        base = BG.copy(); blur = 30
        sh = Image.new('L', (CW + blur * 4, CH + blur * 4), 0)
        ImageDraw.Draw(sh).rounded_rectangle((blur * 2, blur * 2, blur * 2 + CW, blur * 2 + CH), 20, fill=140)
        base.paste((0, 0, 0), (WX - blur * 2, WY - blur * 2 + 16), sh.filter(ImageFilter.GaussianBlur(blur)))
        _WIN_BASE = base; _WIN_MASK = rounded(Image.new('RGB', (CW, CH)), 20)
    return _WIN_BASE.copy(), _WIN_MASK

def desktop_frame(images, cam, t, xfade=0.35):
    """images: [(t_bắt_đầu, tên ảnh)], cam: [(t, (x, y, w))] toạ độ CSS (khung 16:9)."""
    cx, cy, cw = track(cam, t); ch = cw * 9 / 16
    def render(name):
        im = img(name); s = im.width / 1600
        return im.resize((CW, CH), Image.BILINEAR, box=(cx * s, cy * s, (cx + cw) * s, (cy + ch) * s), reducing_gap=2.0)
    starts = [t0 for t0, _ in images]
    idx = max([i for i, t0 in enumerate(starts) if t0 <= t] or [0])
    content = render(images[idx][1])
    if idx > 0 and t - starts[idx] < xfade:
        content = Image.blend(render(images[idx - 1][1]), content, ease((t - starts[idx]) / xfade))
    fr, mask = window_base()
    fr.paste(content, (WX, WY), mask)
    return fr, (cx, cy, cw)

def to_screen(pt, camv):
    cx, cy, cw = camv; s = CW / cw
    return (WX + (pt[0] - cx) * s, WY + (pt[1] - cy) * s)

def scene_title(fr, text, a):
    if a <= 0: return
    d = ImageDraw.Draw(fr, 'RGBA'); x = WX + 6 - int((1 - a) * 24)
    d.ellipse((x, 40, x + 18, 58), fill=SKY + (int(255 * a),))
    d.text((x + 34, 49), text, font=font(42, 'Bold', True), fill=(255, 255, 255, int(255 * a)), anchor='lm')
    lg = _small_logo()
    fr.paste(lg, (WX + CW - lg.width, 26), lg)
_SL = None
def _small_logo():
    global _SL
    if _SL is None:
        lg = Image.open(LOGO).convert('RGBA').resize((52, 52), Image.LANCZOS)
        _SL = Image.new('RGBA', (52 + 12 + 200, 52), (0, 0, 0, 0)); _SL.paste(lg, (0, 0), lg)
        ImageDraw.Draw(_SL).text((64, 26), 'BossKin', font=font(32, 'Bold', True), fill=(255, 255, 255, 230), anchor='lm')
        bb = _SL.getbbox(); _SL = _SL.crop((0, 0, bb[2], 52))
    return _SL

PHONE_W = 430
STATUS = 40
def phone(images, t, xfade=0.35):
    """Ảnh điện thoại trong khung máy (có thanh trạng thái), trả RGBA."""
    cur_i = max([i for i, (t0, _) in enumerate(images) if t0 <= t] or [0])
    def scr(name): return img(name).resize((PHONE_W, int(PHONE_W * 844 / 390)), Image.LANCZOS)
    s = scr(images[cur_i][1])
    if cur_i > 0 and t - images[cur_i][0] < xfade:
        s = Image.blend(scr(images[cur_i - 1][1]), s, ease((t - images[cur_i][0]) / xfade))
    full = Image.new('RGB', (s.width, s.height + STATUS), (255, 255, 255)); full.paste(s, (0, STATUS))
    d = ImageDraw.Draw(full)
    d.text((34, STATUS // 2 + 2), '10:21', font=font(17, 'SemiBold'), fill=(15, 23, 42), anchor='lm')
    for i in range(4): d.rectangle((s.width - 92 + i * 7, 24 - i * 3, s.width - 87 + i * 7, 27), fill=(15, 23, 42))
    d.rounded_rectangle((s.width - 52, 15, s.width - 26, 28), 3, outline=(15, 23, 42), width=2)
    d.rectangle((s.width - 49, 18, s.width - 33, 25), fill=(15, 23, 42))
    bez = 16; fw, fh = full.width + bez * 2, full.height + bez * 2
    fr = Image.new('RGBA', (fw, fh), (0, 0, 0, 0)); dd = ImageDraw.Draw(fr)
    dd.rounded_rectangle((0, 0, fw - 1, fh - 1), 62, fill=(12, 14, 20, 255), outline=(70, 78, 96, 255), width=3)
    fr.paste(full, (bez, bez), rounded(full, 48))
    dd.rounded_rectangle((fw // 2 - 50, bez + 9, fw // 2 + 50, bez + 33), 12, fill=(12, 14, 20, 255))
    return fr

def phone_pt(pt, px, py):
    s = PHONE_W / 390
    return (px + 16 + pt[0] * s, py + 16 + STATUS + pt[1] * s)

def heading(fr, text, x, y, alpha=1, size=64, sub=None):
    if alpha <= 0: return
    d = ImageDraw.Draw(fr, 'RGBA'); dy = int((1 - alpha) * 24)
    d.text((x, y + dy), text, font=font(size, 'Bold', True), fill=(255, 255, 255, int(255 * alpha)))
    if sub: d.text((x, y + dy + size + 22), sub, font=font(32, 'Regular'), fill=(190, 205, 235, int(255 * alpha)))

def fade_in(t, t0, dur=0.45): return ease((t - t0) / dur)

# ── lồng tiếng + phụ đề ──────────────────────────────────────────────────────
cfg = json.load(open(os.path.join(HERE, 'script.json'), encoding='utf-8'))
def dur(path):
    return float(subprocess.check_output(['ffprobe', '-v', 'error', '-show_entries', 'format=duration', '-of', 'csv=p=0', path]))
def srt(path):
    cues = []
    for blk in open(path, encoding='utf-8').read().strip().split('\n\n'):
        ls = blk.strip().split('\n')
        m = re.findall(r'(\d+):(\d+):(\d+),(\d+)', ls[1])
        a, b = [int(h) * 3600 + int(mi) * 60 + int(s) + int(ms) / 1000 for h, mi, s, ms in m]
        text = ' '.join(ls[2:])
        parts = split_cue(text)                      # câu dài → chia đoạn theo số ký tự
        total = sum(len(p) for p in parts); acc = a
        for p in parts:
            d = (b - a) * len(p) / total; cues.append((acc, acc + d, p)); acc += d
    return cues
def split_cue(text, maxc=64):
    if len(text) <= maxc: return [text]
    chunks, cur = [], ''
    for piece in re.split(r'(?<=[,:])\s+', text):
        if cur and len(cur) + len(piece) + 1 > maxc: chunks.append(cur); cur = piece
        else: cur = (cur + ' ' + piece).strip()
    if cur: chunks.append(cur)
    out = []
    for c in chunks:
        while len(c) > maxc + 20:
            cut = c.rfind(' ', 0, len(c) // 2 + 10); out.append(c[:cut]); c = c[cut + 1:]
        out.append(c)
    return out

LEAD = {'s1_intro': 0.7, 's9_cta': 0.5}
TAIL = {'s1_intro': 0.9, 's6_approve': 1.0, 's9_cta': 2.6}
scenes = []
t = 0.0
for s in cfg['scenes']:
    vo = f'{VO}/{s["id"]}.mp3'; d = dur(vo); lead = LEAD.get(s['id'], 0.45)
    length = lead + d + TAIL.get(s['id'], 0.8)
    cues = [(t + lead + a, t + lead + b, txt) for a, b, txt in srt(f'{VO}/{s["id"]}.srt')]
    sent = [t + lead + a for a, _, _ in srt(f'{VO}/{s["id"]}.srt')]
    scenes.append(dict(id=s['id'], title=s['title'], start=t, len=length, lead=lead, vo=vo, vodur=d, cues=cues))
    t += length
TOTAL = t
CUES = [c for s in scenes for c in s['cues']]
print(f'Tổng thời lượng {TOTAL:.1f}s')

def sentence_starts(sc):
    """Mốc bắt đầu từng câu (theo SRT gốc của tts), tính từ đầu cảnh."""
    out = []
    for blk in open(f'{VO}/{sc["id"]}.srt', encoding='utf-8').read().strip().split('\n\n'):
        h, mi, se, ms = re.findall(r'(\d+):(\d+):(\d+),(\d+)', blk.split('\n')[1])[0]
        out.append(sc['lead'] + int(h) * 3600 + int(mi) * 60 + int(se) + int(ms) / 1000)
    return out

# ── từng cảnh: hàm (t trong cảnh) → khung hình ───────────────────────────────
def s1(sc, t):
    fr = BG.copy(); d = ImageDraw.Draw(fr, 'RGBA')
    pains = [('Bảng chấm công rời rạc', 0.7), ('Đối chiếu ngày nghỉ thủ công', 2.0), ('Tính lương bằng Excel', 3.4)]
    t_logo = 5.9
    out = 1 - fade_in(t, t_logo - 0.5, 0.5)
    for i, (txt, t0) in enumerate(pains):
        a = fade_in(t, t0) * out
        if a <= 0: continue
        y = 330 + i * 130; x = 260 + int((1 - fade_in(t, t0)) * -30)
        f = font(64, 'SemiBold', True)
        d.text((x, y), txt, font=f, fill=(255, 255, 255, int(235 * a)))
        st = fade_in(t, t0 + 0.9, 0.5)                    # gạch ngang
        if st > 0:
            wtxt = f.getlength(txt)
            d.line((x - 6, y + 42, x - 6 + (wtxt + 12) * st, y + 42), fill=(239, 68, 68, int(255 * a)), width=7)
        d.text((x - 80, y + 4), '?', font=font(64, 'Bold', True), fill=(95, 169, 210, int(255 * a)))
    if t >= t_logo - 0.5:
        a = fade_in(t, t_logo - 0.2, 0.6)
        # ảnh sản phẩm phía sau
        dash = img('d_dashboard').resize((860, 484), Image.LANCZOS)
        y = 300 + int((1 - a) * 80)
        if a > 0:
            card = Image.blend(Image.new('RGB', dash.size, NAVY), dash, a)
            shadow_paste(fr, card, 900, y + 40, r=18)
            ph = phone([(0, 'p_checkin_after')], 0); ph = ph.resize((250, int(250 * ph.height / ph.width)), Image.LANCZOS)
            phb = Image.new('RGBA', ph.size, (0, 0, 0, 0)); phb = Image.blend(phb, ph, a)
            fr.paste(phb, (1630, y - 20 - int((1 - a) * 60)), phb)
        lg = Image.open(LOGO).convert('RGBA').resize((210, 210), Image.LANCZOS)
        la = Image.new('RGBA', lg.size, (0, 0, 0, 0)); la = Image.blend(la, lg, a)
        fr.paste(la, (200, 330), la)
        d = ImageDraw.Draw(fr, 'RGBA')
        d.text((200, 575 + int((1 - a) * 20)), 'BossKin', font=font(110, 'Bold', True), fill=(255, 255, 255, int(255 * a)))
        d.text((204, 715 + int((1 - a) * 20)), 'Chấm công · Ca làm · Nghỉ phép · Lương', font=font(34, 'Medium'),
               fill=(190, 210, 240, int(255 * a)))
    return fr

def desk_scene(images, cam, cursor, clicks, title_text):
    def f(sc, t):
        fr, camv = desktop_frame(images, cam, t)
        if cursor:
            x, y = to_screen(track(cursor, t), camv)
            draw_cursor(fr, x, y, [to_t for to_t in clicks], t)
        scene_title(fr, title_text, 1.0)
        return fr
    return f

FULL = (0, 0, 1600)
def build():
    S = {s['id']: s for s in scenes}
    f = {}
    f['s1_intro'] = s1
    ss = sentence_starts(S['s2_dashboard'])
    f['s2_dashboard'] = desk_scene(
        [(0, 'd_dashboard')],
        [(0, FULL), (1.0, FULL), (3.0, (235, 175, 1000)), (5.0, (590, 175, 1000)), (7.0, (590, 175, 1000)), (8.4, FULL)],
        [(0, (900, 700)), (1.6, (660, 336)), (2.8, (660, 336)), (3.6, (1000, 336)), (4.3, (1300, 336)), (5.3, (1420, 226)), (8.5, (1420, 226))],
        [], S['s2_dashboard']['title'])

    def s3(sc, t):
        fr = BG.copy()
        ss = sentence_starts(sc)
        ph_imgs = [(0, 'p_checkin_before'), (5.0, 'p_checkin_after')]
        ph = phone(ph_imgs, t)
        a = fade_in(t, 0.0, 0.6); px, py = 300, 70 + int((1 - a) * 60)
        sh = Image.new('L', (ph.width + 120, ph.height + 120), 0)
        ImageDraw.Draw(sh).rounded_rectangle((60, 60, 60 + ph.width, 60 + ph.height), 64, fill=120)
        fr.paste((0, 0, 0), (px - 60, py - 40), sh.filter(ImageFilter.GaussianBlur(30)))
        fr.paste(ph, (px, py), ph)
        tx, ty = phone_pt((104, 697), px, py)
        cur = track([(0, (tx + 140, ty + 160)), (3.6, (tx + 140, ty + 160)), (4.6, (tx, ty)), (6.0, (tx, ty)), (7.0, (tx + 120, ty + 200))], t)
        if 3.3 < t < 6.0: draw_cursor(fr, cur[0], cur[1], [4.75], t, touch=True)
        heading(fr, 'Chấm công trên điện thoại', 900, 250, fade_in(t, 0.3), 66,
                'Mở app, bấm Check-in — xong trong 3 giây')
        chip(fr, 'Định vị GPS, bán kính 150 m quanh văn phòng', 900, 470, fade_in(t, ss[1] + 0.6))
        chip(fr, 'Chỉ nhận đúng chiếc máy đã đăng ký', 900, 580, fade_in(t, ss[1] + 3.4), BLUE)
        chip(fr, 'Không thể chấm công hộ', 900, 690, fade_in(t, ss[1] + 6.0), (239, 68, 68))
        return fr
    f['s3_checkin'] = s3

    sc4 = S['s4_shifts']; ss4 = sentence_starts(sc4)
    f['s4_shifts'] = desk_scene(
        [(0, 'd_shifts'), (4.1, 'd_shift_rotation'), (ss4[1] + 0.2, 'd_swaps')],
        [(0, FULL), (0.6, FULL), (3.2, (380, 190, 1220)), (3.7, (0, 0, 1200)), (4.1, (0, 0, 1200)), (ss4[1], (100, 30, 1100)),
         (ss4[1] + 0.2, (230, 20, 1370)), (sc4['len'], (230, 20, 1370))],
        [(0, (1100, 600)), (2.6, (900, 400)), (3.7, (483, 87)), (4.4, (483, 87)), (5.2, (700, 150)),
         (ss4[1] + 1.2, (1300, 230)), (ss4[1] + 2.2, (1526, 248)), (sc4['len'], (1526, 248))],
        [3.85], sc4['title'])

    sc5 = S['s5_leaves']; ss5 = sentence_starts(sc5)
    tc5 = ss5[1] + 0.9
    f['s5_leaves'] = desk_scene(
        [(0, 'd_leaves'), (tc5 + 0.3, 'd_leaves_after')],
        [(0, FULL), (0.8, FULL), (2.6, (236, 225, 1000)), (sc5['len'] - 1.2, (236, 225, 1000)), (sc5['len'], (150, 120, 1250))],
        [(0, (900, 650)), (2.4, (450, 300)), (tc5 - 0.3, (580, 391)), (sc5['len'], (600, 420))],
        [tc5], sc5['title'])

    sc6 = S['s6_approve']
    f['s6_approve'] = desk_scene(
        [(0, 'd_attendance'), (1.6, 'd_bulk_dialog'), (3.9, 'd_bulk_result'), (5.6, 'd_attendance_after')],
        [(0, FULL), (0.4, (500, 0, 1100)), (1.6, (500, 0, 1100)), (2.1, (400, 240, 800)), (5.4, (400, 240, 800)),
         (5.6, (700, 0, 900)), (sc6['len'], (700, 0, 900))],
        [(0, (800, 500)), (1.2, (1083, 91)), (1.9, (1083, 91)), (3.4, (998, 564)), (5.5, (998, 564)), (6.3, (1232, 91)), (sc6['len'], (1232, 91))],
        [1.35, 3.6], sc6['title'])

    sc7 = S['s7_payroll']; ss7 = sentence_starts(sc7)
    t_ph = ss7[1] - 0.3
    base7 = desk_scene(
        [(0, 'd_payroll9')],
        [(0, FULL), (0.6, FULL), (2.6, (230, 95, 1000)), (t_ph, (230, 140, 1000)), (sc7['len'], (230, 140, 1000))],
        [(0, (900, 600)), (2.2, (980, 300)), (3.4, (1060, 305)), (4.8, (980, 490)), (t_ph, (1060, 490))],
        [], sc7['title'])
    def s7(sc, t):
        fr = base7(sc, t)
        if t > t_ph:
            a = fade_in(t, t_ph, 0.6)
            dim = Image.new('RGB', fr.size, NAVY); fr = Image.blend(fr, dim, 0.84 * a)
            ph = phone([(0, 'p_payslips'), (t_ph + 1.6, 'p_payslip_detail')], t)
            px = 1300 + int((1 - a) * 500); py = 60
            fr.paste(ph, (px, py), ph)
            tx, ty = phone_pt((200, 156), px, py)
            if t_ph + 0.6 < t < t_ph + 2.4: draw_cursor(fr, tx, ty, [t_ph + 1.3], t, touch=True)
            heading(fr, 'Phiếu lương trên điện thoại', 160, 380, fade_in(t, t_ph + 0.4), 60,
                    'Ngày công, khấu trừ, thực nhận — rõ ràng từng dòng')
        return fr
    f['s7_payroll'] = s7

    sc8 = S['s8_security']; L = sc8['len']; ss8 = sentence_starts(sc8)
    t_users, t_audit, t_2fa = ss8[1], ss8[1] + 2.6, ss8[1] + 5.0
    f['s8_security'] = desk_scene(
        [(0, 'd_reports'), (t_users, 'd_users'), (t_audit, 'd_audit'), (t_2fa, 'd_profile_2fa')],
        [(0, (380, 60, 1100)), (t_users - 0.1, (440, 90, 980)), (t_users, (110, 50, 1100)), (t_audit - 0.1, (110, 110, 1000)),
         (t_audit, (110, 40, 1000)), (t_2fa - 0.1, (110, 60, 950)), (t_2fa, (470, 230, 960)), (L, (520, 260, 860))],
        [(0, (1300, 600)), (1.4, (1279, 466)), (t_users - 0.3, (1279, 466)), (t_users + 0.6, (900, 400)), (t_audit, (700, 300)),
         (t_audit + 1.2, (500, 160)), (t_2fa + 0.4, (900, 600)), (t_2fa + 1.6, (1170, 421)), (L, (1170, 421))],
        [1.6, t_2fa + 1.9], sc8['title'])

    def s9(sc, t):
        fr = BG.copy(); d = ImageDraw.Draw(fr, 'RGBA')
        a = fade_in(t, 0.1, 0.7)
        lg = Image.open(LOGO).convert('RGBA').resize((240, 240), Image.LANCZOS)
        la = Image.blend(Image.new('RGBA', lg.size, (0, 0, 0, 0)), lg, a)
        fr.paste(la, (W // 2 - 120, 150 + int((1 - a) * 30)), la)
        d.text((W // 2, 470), 'BossKin', font=font(120, 'Bold', True), fill=(255, 255, 255, int(255 * a)), anchor='mm')
        items = ['Chấm công đúng', 'Tính lương nhanh', 'Quản lý nhẹ nhàng']
        ss9 = sentence_starts(sc)
        f9 = font(46, 'SemiBold'); gap = 70
        widths = [f9.getlength(s) for s in items]; total = sum(widths) + gap * 2 * (len(items) - 1)
        x = W / 2 - total / 2
        for i, (s, wdt) in enumerate(zip(items, widths)):
            ai = fade_in(t, ss9[0] + 0.9 + i * 0.9)
            d.text((x, 590), s, font=f9, fill=(255, 255, 255, int(255 * ai)), anchor='lm')
            if i < len(items) - 1:
                d.ellipse((x + wdt + gap - 7, 583, x + wdt + gap + 7, 597), fill=SKY + (int(255 * ai),))
            x += wdt + gap * 2
        ab = fade_in(t, ss9[1])
        if ab > 0:
            txt = 'Liên hệ dùng thử ngay hôm nay'; fb = font(44, 'Bold'); bw = int(fb.getlength(txt)) + 120
            bx, by = W // 2 - bw // 2, 700 + int((1 - ab) * 20)
            d.rounded_rectangle((bx, by, bx + bw, by + 96), 48, fill=BLUE + (int(255 * ab),))
            d.text((W // 2, by + 48), txt, font=fb, fill=(255, 255, 255, int(255 * ab)), anchor='mm')
        return fr
    f['s9_cta'] = s9
    return f

# ── âm thanh: lồng tiếng theo mốc + nhạc nền tổng hợp nhẹ ────────────────────
def music(total, sr=44100):
    n = int(total * sr); tt = np.arange(n) / sr
    bpm = 96; beat = 60 / bpm; bar = beat * 4
    prog = [[60, 64, 67, 71], [57, 60, 64, 67], [53, 57, 60, 64], [55, 59, 62, 67]]   # Cmaj7 Am7 Fmaj7 G
    hz = lambda m: 440 * 2 ** ((m - 69) / 12)
    pad = np.zeros(n); arp = np.zeros(n)
    nb = int(total / bar) + 1
    for b in range(nb):
        ch = prog[b % 4]; t0 = b * bar; i0, i1 = int(t0 * sr), min(n, int((t0 + bar + 0.6) * sr))
        if i0 >= n: break
        seg = tt[i0:i1] - t0
        env = np.minimum(1, seg / 0.8) * np.minimum(1, np.maximum(0, (bar + 0.6 - seg) / 0.8))
        for m in ch:
            f0 = hz(m - 12)
            pad[i0:i1] += env * (np.sin(2 * np.pi * f0 * seg) + 0.3 * np.sin(2 * np.pi * f0 * 1.003 * seg)) * 0.12
        for k in range(8):                                 # rải hợp âm nốt móc đơn
            ts = t0 + k * beat / 2; j0 = int(ts * sr); j1 = min(n, j0 + int(0.9 * sr))
            if j0 >= n: break
            m = ch[[0, 1, 2, 3, 2, 1, 2, 3][k]] + 12; s2 = tt[j0:j1] - ts
            arp[j0:j1] += np.exp(-s2 * 5) * np.sin(2 * np.pi * hz(m) * s2) * 0.08
    mix = pad + arp
    k = 18; mix = np.convolve(mix, np.ones(k) / k, mode='same')        # làm mềm
    fade = np.minimum(1, tt / 1.5) * np.minimum(1, (total - tt) / 2.5)
    return (mix * fade / (np.abs(mix).max() + 1e-9) * 0.9).astype(np.float32)

def build_audio(path):
    sr = 44100
    bed = music(TOTAL, sr)
    tmp = path + '.bed.wav'
    with wave.open(tmp, 'wb') as w:
        w.setnchannels(1); w.setsampwidth(2); w.setframerate(sr)
        w.writeframes((bed * 32767).astype(np.int16).tobytes())
    inputs = ['-i', tmp]; filt = []
    for i, s in enumerate(scenes):
        inputs += ['-i', s['vo']]
        ms = int((s['start'] + s['lead']) * 1000)
        filt.append(f'[{i + 1}:a]aresample={sr},adelay={ms}|{ms},apad[v{i}]')
    vs = ''.join(f'[v{i}]' for i in range(len(scenes)))
    filt.append(f'{vs}amix=inputs={len(scenes)}:normalize=0:duration=longest,atrim=0:{TOTAL:.2f},volume=1.6[vo]')
    filt.append(f'[0:a]volume=0.13[bed]')
    filt.append('[bed][vo]sidechaincompress=threshold=0.03:ratio=6:attack=20:release=400[duck]')
    filt.append('[duck][vo]amix=inputs=2:normalize=0,alimiter=limit=0.95,atrim=0:%.2f[out]' % TOTAL)
    # sidechaincompress dùng [vo] hai lần → tách luồng
    filt[-4] = filt[-4].replace('[vo]', '[voa]')
    filt.insert(-3, '[voa]asplit=2[vo][vosc]')
    filt[-2] = filt[-2].replace('[bed][vo]', '[bed][vosc]')
    subprocess.run(['ffmpeg', '-y', '-loglevel', 'error', *inputs, '-filter_complex', ';'.join(filt), '-map', '[out]',
                    '-ac', '2', '-ar', str(sr), path], check=True)
    os.remove(tmp)

def main():
    fns = build()
    audio = OUT + '.audio.wav'; build_audio(audio)
    ff = subprocess.Popen(['ffmpeg', '-y', '-loglevel', 'error', '-f', 'rawvideo', '-pix_fmt', 'rgb24', '-s', f'{W}x{H}',
                           '-r', str(FPS), '-i', '-', '-i', audio, '-c:v', 'libx264', '-preset', 'slow', '-crf', '20',
                           '-pix_fmt', 'yuv420p', '-movflags', '+faststart', '-c:a', 'aac', '-b:a', '160k', '-shortest', OUT],
                          stdin=subprocess.PIPE)
    nframes = int(TOTAL * FPS); prev_last = None; XF = 0.4
    for k in range(nframes):
        tg = k / FPS
        si = max(i for i, s in enumerate(scenes) if s['start'] <= tg + 1e-9)
        sc = scenes[si]; tl = tg - sc['start']
        fr = fns[sc['id']](sc, tl)
        if si > 0 and tl < XF:                          # chuyển cảnh mờ dần
            ps = scenes[si - 1]
            pf = fns[ps['id']](ps, ps['len'] - 1 / FPS)
            fr = Image.blend(pf, fr, ease(tl / XF))
        cue = next((c[2] for c in CUES if c[0] <= tg < c[1]), None)
        subtitle(fr, cue)
        ff.stdin.write(fr.tobytes())
        if k % 150 == 0: print(f'  {tg:5.1f}s / {TOTAL:.1f}s', flush=True)
    ff.stdin.close(); ff.wait(); os.remove(audio)
    def ts(x): return f'{int(x // 3600):02d}:{int(x % 3600 // 60):02d}:{x % 60:06.3f}'
    with open(os.path.splitext(OUT)[0] + '.vtt', 'w', encoding='utf-8') as fv:
        fv.write('WEBVTT\n\n' + '\n'.join(f'{ts(a)} --> {ts(b)}\n{txt}\n' for a, b, txt in CUES))
    print('Xong:', OUT)

if __name__ == '__main__':
    if len(sys.argv) > 4 and sys.argv[4] == '--frames':      # xuất vài khung để duyệt
        fns = build()
        for tg in [float(x) for x in sys.argv[5].split(',')]:
            si = max(i for i, s in enumerate(scenes) if s['start'] <= tg); sc = scenes[si]
            fr = fns[sc['id']](sc, tg - sc['start']); subtitle(fr, next((c[2] for c in CUES if c[0] <= tg < c[1]), None))
            fr.save(f'{OUT}_{tg:05.1f}.png')
    else:
        main()
