#!/usr/bin/env python3
"""Một bài đăng mạng xã hội 9:16 (1080×1920) từ file mô tả JSON: ảnh .jpg + video ngắn .mp4 (chữ hiện dần,
giao diện thật trong laptop/điện thoại hoặc con số lớn, nhạc nền, lồng tiếng nếu có, cảnh kêu gọi dùng thử ở cuối).

  make_post.py <spec.json> <thư mục ra>          → <ra>/<slug>.jpg, <ra>/<slug>.mp4

spec.json:
{ "slug": "2026-10-10-bhxh",
  "kicker": "BẢO HIỂM XÃ HỘI",
  "lines": [["Lương đóng BHXH", 0], ["tính thế nào?", 1]],      # 0 = trắng, 1 = xanh nhấn; 2–3 dòng, ≤ 16 ký tự/dòng
  "body": "Một câu giải thích ngắn.",
  "bullets": ["Ý 1", "Ý 2", "Ý 3"],                             # 0–3 ý, ≤ 34 ký tự
  "visual": {"type": "laptop", "shot": "d_payroll9", "cam": [150, 60, 1150]}
         | {"type": "phone", "shot": "p_checkin_after"}
         | {"type": "stat", "big": "10,5%", "label": "người lao động đóng BHXH, BHYT, BHTN"},
  "voice": "đường dẫn mp3 (tuỳ chọn)" }
Ảnh giao diện: landing/video/shots/<shot>.webp (d_* = màn hình máy tính 3200 px, p_* = điện thoại).
"""
import json, os, subprocess, sys, wave
HERE = os.path.dirname(os.path.abspath(__file__))
SPEC, OUTDIR = sys.argv[1], sys.argv[2]
sys.argv = [sys.argv[0], os.path.join(HERE, 'shots'), '/nonexistent', '/tmp/unused']
sys.path.insert(0, HERE)
import numpy as np
from PIL import Image, ImageDraw
import make_reel_vertical as V
M = V.M
W, H, FPS = 1080, 1920, 30

def _img(name):
    if name not in M._img: M._img[name] = Image.open(os.path.join(HERE, 'shots', name + '.webp')).convert('RGB')
    return M._img[name]
M.img = _img

sp = json.load(open(SPEC, encoding='utf-8'))
os.makedirs(OUTDIR, exist_ok=True)
OUT = os.path.join(OUTDIR, sp['slug'])
def dur(p): return float(subprocess.check_output(['ffprobe', '-v', 'error', '-show_entries', 'format=duration', '-of', 'csv=p=0', p]))
VOICE = sp.get('voice') if sp.get('voice') and os.path.exists(sp['voice']) else None
VD = dur(VOICE) if VOICE else 0
CTA = 3.2
MAIN = max(9.0, 0.6 + VD + 0.8 - CTA + 1.0) if VOICE else 9.0
TOTAL = MAIN + CTA
logo = Image.open(M.LOGO).convert('RGBA')

def brand(fr):
    lg = logo.resize((80, 80), Image.LANCZOS); fr.paste(lg, (80, 230), lg)
    ImageDraw.Draw(fr).text((178, 270), 'BossKin', font=M.font(44, 'Bold'), fill=M.INK, anchor='lm')

def main_frame(t):
    fr = V.BG.copy(); brand(fr)
    M.kicker(fr, sp.get('kicker', ''), 80, 350, t, 0.15) if sp.get('kicker') else None
    y = 430
    for i, (txt, acc) in enumerate(sp['lines']):
        M.rise(fr, M.tl(txt, 100, M.ACCENT if acc else M.INK), 80, y, t, 0.3 + i * 0.15); y += 116
    y += 34
    if sp.get('body'):
        V.body(fr, sp['body'], 80, y, t, 0.8, width=920, size=38)
        f = M.font(38, 'Regular', False); n = 1; cur = ''
        for wd in sp['body'].split():
            nn = (cur + ' ' + wd).strip()
            if f.getlength(nn) > 920 and cur: n += 1; cur = wd
            else: cur = nn
        y += n * 50 + 30
    if sp.get('bullets'):
        V.checks(fr, sp['bullets'], 80, y, t, 1.2); y += len(sp['bullets']) * 68 + 20
    v = sp.get('visual') or {}
    top = max(y + 40, 900)
    if v.get('type') == 'laptop':
        cx, cy, cw = v.get('cam', [0, 0, 1600])
        cam = [(0, (cx, cy, cw)), (MAIN, (cx + cw * 0.06, cy + cw * 0.03, cw * 0.88))]
        V.place_laptop(fr, [(0, v['shot'])], cam, t, t_in=0.4, y=top)
    elif v.get('type') == 'phone':
        V.place_phone(fr, [(0, v['shot'])], t, 0.4, None, top, pw=min(300, int((1520 - top - 62) / 2.164)))
    elif v.get('type') == 'stat':
        a = M.appear(t, 0.9, 0.6)
        if a > 0:
            cw, chh = 920, 420; card = Image.new('RGBA', (cw, chh), (0, 0, 0, 0)); d = ImageDraw.Draw(card)
            d.rounded_rectangle((0, 0, cw - 1, chh - 1), 36, fill=(255, 255, 255, 16), outline=(255, 255, 255, 50), width=2)
            d.text((cw // 2, 170), v['big'], font=M.font(170, 'Bold'), fill=M.ACCENT2 + (255,), anchor='mm')
            f = M.font(38, 'Medium', False); words = v.get('label', '').split(); lines, cur = [], ''
            for wd in words:
                nn = (cur + ' ' + wd).strip()
                if f.getlength(nn) > cw - 80 and cur: lines.append(cur); cur = wd
                else: cur = nn
            lines.append(cur)
            for i, ln in enumerate(lines[:2]): d.text((cw // 2, 310 + i * 50), ln, font=f, fill=(205, 215, 235, 255), anchor='mm')
            M.paste_alpha(fr, card, (80, top + 20 + (1 - a) * 40), a)
    return fr

def cta_frame(t):
    fr = V.BG.copy()
    a = M.appear(t, 0.05, 0.5); s = int(220 * (0.85 + 0.15 * a)); lg = logo.resize((s, s), Image.LANCZOS)
    M.paste_alpha(fr, lg, (W // 2 - s // 2, 520 + (220 - s) // 2), a)
    M.rise(fr, M.tl('Chấm công đúng,', 84, M.INK), W // 2, 800, t, 0.2, anchor='c')
    M.rise(fr, M.tl('tính lương nhanh.', 84, M.ACCENT), W // 2, 900, t, 0.3, anchor='c')
    ab = M.appear(t, 0.6, 0.5)
    if ab > 0:
        bw, bh = 760, 116; l = Image.new('RGBA', (bw, bh), (0, 0, 0, 0)); d = ImageDraw.Draw(l)
        d.rounded_rectangle((0, 0, bw - 1, bh - 1), 58, fill=M.ACCENT + (255,))
        d.text((bw // 2, bh // 2), 'bosskin.io.vn', font=M.font(46, 'Bold', False), fill=(255, 255, 255, 255), anchor='mm')
        M.paste_alpha(fr, l, (W // 2 - bw // 2, 1060 + (1 - ab) * 30), ab)
        M.rise(fr, M.tl('Đăng ký dùng thử · Zalo 0865 854 002', 36, (200, 212, 235), 'Medium', False), W // 2, 1210, t, 0.75, anchor='c')
    if t > CTA - 0.5: fr = Image.blend(fr, Image.new('RGB', (W, H), (0, 0, 0)), M.ease((t - (CTA - 0.5)) / 0.5))
    return fr

def frame(tg):
    if tg < MAIN: return main_frame(tg)
    fr = cta_frame(tg - MAIN)
    if tg - MAIN < 0.35: fr = Image.blend(main_frame(MAIN), fr, M.ease((tg - MAIN) / 0.35))
    return fr

main_frame(99).convert('RGB').save(OUT + '.jpg', quality=92)

sr = 44100; bed = M.music(TOTAL, sr); tmp = OUT + '.bed.wav'
with wave.open(tmp, 'wb') as w:
    w.setnchannels(1); w.setsampwidth(2); w.setframerate(sr); w.writeframes((bed * 32767).astype(np.int16).tobytes())
audio = OUT + '.mix.wav'
if VOICE:
    filt = (f'[1:a]aresample={sr},adelay=600|600,apad,volume=1.7,asplit=2[vo][sc];[0:a]volume=0.30[bed];'
            f'[bed][sc]sidechaincompress=threshold=0.04:ratio=5:attack=15:release=350[duck];'
            f'[duck][vo]amix=inputs=2:normalize=0,alimiter=limit=0.95,atrim=0:{TOTAL:.2f}[out]')
    subprocess.run(['ffmpeg', '-y', '-loglevel', 'error', '-i', tmp, '-i', VOICE, '-filter_complex', filt, '-map', '[out]', '-ac', '2', audio], check=True)
else:
    subprocess.run(['ffmpeg', '-y', '-loglevel', 'error', '-i', tmp, '-af', 'volume=0.6', '-ac', '2', audio], check=True)
os.remove(tmp)
ff = subprocess.Popen(['ffmpeg', '-y', '-loglevel', 'error', '-f', 'rawvideo', '-pix_fmt', 'rgb24', '-s', f'{W}x{H}', '-r', str(FPS),
                       '-i', '-', '-i', audio, '-c:v', 'libx264', '-preset', 'medium', '-crf', '21', '-pix_fmt', 'yuv420p',
                       '-movflags', '+faststart', '-c:a', 'aac', '-b:a', '160k', '-shortest', OUT + '.mp4'], stdin=subprocess.PIPE)
for k in range(int(TOTAL * FPS)): ff.stdin.write(frame(k / FPS).convert('RGB').tobytes())
ff.stdin.close(); ff.wait(); os.remove(audio)
print(json.dumps({'jpg': OUT + '.jpg', 'mp4': OUT + '.mp4', 'seconds': round(TOTAL, 1)}))
