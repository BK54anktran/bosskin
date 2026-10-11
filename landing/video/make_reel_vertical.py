#!/usr/bin/env python3
"""Bản dọc 9:16 (1080×1920) của video ngắn — cho Facebook Reels / TikTok / YouTube Shorts.
Dùng lại toàn bộ cảnh, nhạc và lồng tiếng của make_reel.py, chỉ sắp lại bố cục: chữ ở trên, thiết bị ở dưới,
chừa vùng an toàn (trên 220 px, dưới ~380 px, cột phải cho nút like/share của app).

  make_reel_vertical.py <thư mục ảnh> <thư mục giọng (script_reel.json)> <file .mp4 ra> [--frames 3,10,20]
"""
import os, subprocess, sys
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import numpy as np
from PIL import Image, ImageDraw, ImageFilter
import make_reel as M          # đọc sys.argv, tính độ dài cảnh theo giọng đọc

W, H = M.W, M.H = 1080, 1920
M.LW, M.LH = 1000, 562        # laptop tràn nhẹ hai mép, màn hình vẫn trọn trong khung
LX = 80
SITE = 'bosskin.io.vn'

def make_bg():
    y, x = np.mgrid[0:H, 0:W].astype(np.float32)
    base = np.zeros((H, W, 3), np.float32) + np.array([7, 11, 22], np.float32)
    g1 = np.exp(-(((x - 850) / 600) ** 2 + ((y - 1150) / 650) ** 2))[..., None]
    g2 = np.exp(-(((x - 100) / 500) ** 2 + ((y - 250) / 420) ** 2))[..., None]
    base += g1 * np.array([28, 60, 150]) + g2 * np.array([10, 40, 70])
    im = Image.fromarray(np.clip(base, 0, 255).astype(np.uint8))
    d = ImageDraw.Draw(im, 'RGBA')
    for gx in range(30, W, 48):
        for gy in range(30, H, 48): d.point((gx, gy), fill=(255, 255, 255, 18))
    return im
BG = M.BG = make_bg()
rise, tl, appear, clamp, ease, track = M.rise, M.tl, M.appear, M.clamp, M.ease, M.track
INK, ACCENT, ACCENT2 = M.INK, M.ACCENT, M.ACCENT2

def place_laptop(fr, images, cam, t, t_in=0.1, x=None, y=960, cursor=None, clicks=()):
    a = appear(t, t_in, 0.7)
    if a <= 0: return
    sc, camv = M.screen_view(images, cam, t, size=(M.LW, M.LH))
    if cursor:
        cx, cy, cw = camv; s = M.LW / cw; px, py = track(cursor, t)
        sc = sc.convert('RGBA'); M.draw_pointer(sc, (px - cx) * s, (py - cy) * s, clicks, t)
    lp = M.laptop(sc)
    x = (W - lp.width) // 2 if x is None else x
    yy = y + (1 - a) * 120
    M.device_glow(fr, x + 60, yy, M.LW + 36, M.LH + 36, 0.55 * a)
    M.paste_alpha(fr, lp, (x, yy), a)

def place_phone(fr, images, t, t_in, x, y, touch=None, pw=330):
    a = appear(t, t_in, 0.7)
    if a <= 0: return
    M.PW = pw
    ph = M.phone(images, t, touch=touch)
    x = (W - ph.width) // 2 if x is None else x
    yy = y + (1 - a) * 120
    M.device_glow(fr, x, yy, ph.width, ph.height, 0.6 * a)
    M.paste_alpha(fr, ph, (x, yy), a)

def body(fr, txt, x, y, t, t0, width=920, size=36):
    f = M.font(size, 'Regular', False); lines, cur = [], ''
    for wd in txt.split():
        n = (cur + ' ' + wd).strip()
        if f.getlength(n) > width and cur: lines.append(cur); cur = wd
        else: cur = n
    lines.append(cur)
    for i, ln in enumerate(lines): rise(fr, tl(ln, size, M.MUTED, 'Regular', False), x, y + i * 50, t, t0 + 0.05 * i, dy=20)

def checks(fr, items, x, y, t, t0, gap=68):
    for i, it in enumerate(items):
        a = appear(t, t0 + i * 0.22, 0.45)
        if a <= 0: continue
        l = Image.new('RGBA', (940, 56), (0, 0, 0, 0)); d = ImageDraw.Draw(l)
        d.ellipse((0, 8, 40, 48), fill=M.GREEN + (40,), outline=M.GREEN + (255,), width=3)
        d.line((11, 28, 18, 35, 30, 20), fill=M.GREEN + (255,), width=5, joint='curve')
        d.text((58, 28), it, font=M.font(36, 'Medium', False), fill=(205, 215, 235, 255), anchor='lm')
        M.paste_alpha(fr, l, (x - (1 - a) * 24, y + i * gap), a)

def feature(kick, l1, l2, txt, items, device, k_t=0.25):
    def f(t, L):
        fr = BG.copy()
        M.kicker(fr, kick, LX, 250, t, k_t)
        M.headline(fr, l1, l2, LX, 325, t, k_t + 0.15, size=86)
        body(fr, txt, LX, 545, t, k_t + 0.5)
        checks(fr, items, LX, 680, t, k_t + 0.9)
        device(fr, t, L)
        return fr
    return f

FULL = M.FULL
def dev_dashboard(fr, t, L):
    place_laptop(fr, [(0, 'd_dashboard')], [(0, FULL), (1.0, FULL), (3.2, (230, 170, 1050)), (L, (520, 170, 1050))], t,
                 cursor=[(0, (1100, 700)), (2.2, (660, 336)), (3.6, (1000, 336)), (L, (1420, 226))])

def dev_checkin(fr, t, L):
    tap = 2.6
    place_phone(fr, [(0, 'p_checkin_before'), (tap + 0.25, 'p_checkin_after')], t, 0.1, None, 930,
                touch=((104, 697), [tap]) if 1.8 < t < tap + 0.9 else None, pw=310)

def dev_shifts(fr, t, L):
    place_laptop(fr, [(0, 'd_shifts'), (2.8, 'd_shift_rotation')],
                 [(0, FULL), (0.6, FULL), (2.4, (380, 190, 1220)), (2.8, (0, 0, 1200)), (L, (60, 20, 1100))], t,
                 cursor=[(0, (1000, 600)), (2.0, (483, 87)), (L, (640, 160))], clicks=[2.45])

def dev_leaves(fr, t, L):
    tc = 2.4
    place_laptop(fr, [(0, 'd_leaves'), (tc + 0.3, 'd_leaves_after')], [(0, FULL), (0.8, FULL), (2.0, (236, 225, 1000)), (L, (236, 225, 1000))], t,
                 cursor=[(0, (900, 650)), (1.8, (450, 300)), (tc - 0.2, (580, 391)), (L, (600, 420))], clicks=[tc])

def dev_payroll(fr, t, L):
    place_laptop(fr, [(0, 'd_payroll9')], [(0, FULL), (0.8, FULL), (2.8, (230, 95, 1000)), (L, (230, 140, 1000))], t, y=930)
    place_phone(fr, [(0, 'p_payslips'), (2.9, 'p_payslip_detail')], t, 1.6, 600, 1110,
                touch=((200, 156), [2.6]) if 2.0 < t < 3.4 else None, pw=230)

_hookbg = None
def r2(t, L):
    global _hookbg
    if _hookbg is None:
        strip = Image.new('RGB', (W, 3 * 900), (0, 0, 0))
        for i, n in enumerate(['d_dashboard', 'p_checkin_after', 'd_payroll9']):
            im = M.img(n); s = max(W / im.width, 900 / im.height)
            im = im.resize((int(im.width * s) + 1, int(im.height * s) + 1)).crop((0, 0, W, 900)); strip.paste(im, (0, i * 900))
        _hookbg = Image.blend(strip.filter(ImageFilter.GaussianBlur(16)), Image.new('RGB', strip.size, (6, 9, 18)), 0.72)
    off = int(track([(0, 0.0), (L, 700.0)], t))
    fr = _hookbg.crop((0, off, W, off + H))
    for i, (txt, col, t0) in enumerate([('Chấm công,', INK, 0.3), ('xếp ca, tính lương...', INK, 0.45),
                                       ('không nên', ACCENT, 1.4), ('phức tạp đến thế.', ACCENT, 1.55)]):
        rise(fr, tl(txt, 84, col), W // 2, 640 + i * 104 + (40 if i >= 2 else 0), t, t0, anchor='c')
    return fr

def r8(t, L):
    fr = BG.copy()
    rise(fr, tl('Tiết kiệm hàng giờ', 80, INK), W // 2, 420, t, 0.2, anchor='c')
    rise(fr, tl('mỗi kỳ chốt công.', 80, ACCENT), W // 2, 512, t, 0.35, anchor='c')
    stats = [('< 1 phút', 'duyệt công cả kỳ cho', '300 nhân viên'), ('8', 'báo cáo Excel có sẵn,', 'xuất trong vài giây'),
             ('2 lớp', 'xác thực bảo vệ', 'tài khoản quản trị')]
    cw, chh, gap = 900, 230, 36; x0 = (W - cw) // 2
    for i, (big, s1, s2) in enumerate(stats):
        a = appear(t, 0.9 + i * 0.25, 0.55)
        if a <= 0: continue
        card = Image.new('RGBA', (cw, chh), (0, 0, 0, 0)); d = ImageDraw.Draw(card)
        d.rounded_rectangle((0, 0, cw - 1, chh - 1), 28, fill=(255, 255, 255, 14), outline=(255, 255, 255, 40), width=2)
        d.text((230, chh // 2), big, font=M.font(84, 'Bold'), fill=ACCENT2 + (255,), anchor='mm')
        d.text((450, chh // 2 - 24), s1, font=M.font(32, 'Medium', False), fill=(205, 215, 235, 255), anchor='lm')
        d.text((450, chh // 2 + 24), s2, font=M.font(32, 'Medium', False), fill=(205, 215, 235, 255), anchor='lm')
        M.paste_alpha(fr, card, (x0 + (1 - a) * 40, 720 + i * (chh + gap)), a)
    return fr

def r9(t, L):
    fr = BG.copy()
    a = appear(t, 0.1, 0.7); size = int(240 * (0.8 + 0.2 * a))
    lg = Image.open(M.LOGO).convert('RGBA').resize((size, size), Image.LANCZOS)
    M.paste_alpha(fr, lg, (W // 2 - size // 2, 470 + (240 - size) // 2), a)
    rise(fr, tl('Quản lý nhân sự', 80, INK), W // 2, 810, t, 0.5, anchor='c')
    rise(fr, tl('gọn nhẹ.', 80, INK), W // 2, 902, t, 0.6, anchor='c')
    rise(fr, tl('Tập trung phát triển.', 80, ACCENT), W // 2, 994, t, 0.75, anchor='c')
    ab = appear(t, 1.4, 0.6)
    if ab > 0:
        bw, bh = 760, 120; l = Image.new('RGBA', (bw, bh), (0, 0, 0, 0)); d = ImageDraw.Draw(l)
        d.rounded_rectangle((0, 0, bw - 1, bh - 1), 60, fill=ACCENT + (255,))
        d.text((bw // 2, bh // 2), 'Đăng ký dùng thử  →', font=M.font(44, 'Bold', False), fill=(255, 255, 255, 255), anchor='mm')
        M.paste_alpha(fr, l, (W // 2 - bw // 2, 1170 + (1 - ab) * 30), ab)
        rise(fr, tl(SITE, 44, (200, 212, 235), 'SemiBold', False), W // 2, 1325, t, 1.6, anchor='c')
        rise(fr, tl('Chấm công · Ca làm · Nghỉ phép · Lương', 32, (150, 165, 195), 'Medium', False), W // 2, 1400, t, 1.75, anchor='c')
    if t > L - 0.8: fr = Image.blend(fr, Image.new('RGB', (W, H), (0, 0, 0)), ease((t - (L - 0.8)) / 0.8))
    return fr

src = {
    'r3_allinone': ('NỀN TẢNG NHÂN SỰ TẤT CẢ TRONG MỘT', 'Đã có BossKin.', 'Mọi thứ trong 1 nơi.',
        'Thay bảng chấm công giấy, file Excel và tin nhắn rời rạc bằng một ứng dụng.',
        ['Biết ngay hôm nay ai có mặt, ai nghỉ', 'Công, ca, phép, lương liên thông', 'Phân quyền theo vai trò, phòng ban'], dev_dashboard),
    'r4_checkin': ('CHẤM CÔNG DI ĐỘNG', 'Chấm công', 'trên điện thoại.', 'Mở app, bấm Check-in. Không cần máy chấm công.',
        ['Định vị GPS quanh văn phòng', 'Mỗi tài khoản gắn đúng 1 máy', 'Chặn vị trí giả lập'], dev_checkin),
    'r5_shifts': ('XẾP CA', 'Xếp ca cả xưởng.', 'Xong trong vài phút.', 'Bảng phân ca theo kỳ lương, nhập và xuất bằng Excel.',
        ['Ca cố định, ca đêm, ca linh hoạt', 'Mẫu xoay ca tự sinh lịch', 'Nhân viên xin đổi ca với nhau'], dev_shifts),
    'r6_leaves': ('NGHỈ PHÉP & ĐƠN TỪ', 'Duyệt đơn', 'trong 1 chạm.', 'Đơn nghỉ, đơn sửa giờ gửi ngay trên app tới người duyệt.',
        ['Sổ phép tự trừ đúng ngày có ca', 'Nghỉ theo ngày hoặc theo giờ', 'Huỷ đơn tự hoàn phép'], dev_leaves),
    'r7_payroll': ('TÍNH LƯƠNG', 'Lương tự tính.', 'Phiếu lương tận tay.', 'Từ ngày công đã chốt và công thức riêng của doanh nghiệp.',
        ['BHXH, BHYT, BHTN, thuế TNCN', 'Duyệt, chi trả, xuất Excel', 'Nhân viên xem phiếu trên điện thoại'], dev_payroll),
}
M.FN.update({k: feature(*v) for k, v in src.items()})
M.FN.update({'r2_hook': r2, 'r8_stats': r8, 'r9_cta': r9})

if __name__ == '__main__':
    OUT = M.OUT
    if len(sys.argv) > 4 and sys.argv[4] == '--frames':
        for tg in [float(x) for x in sys.argv[5].split(',')]: M.frame_at(tg).save(f'{OUT}_{tg:05.1f}.png')
        sys.exit()
    audio = OUT + '.audio.wav'; M.build_audio(audio)
    ff = subprocess.Popen(['ffmpeg', '-y', '-loglevel', 'error', '-f', 'rawvideo', '-pix_fmt', 'rgb24', '-s', f'{W}x{H}', '-r', str(M.FPS),
                           '-i', '-', '-i', audio, '-c:v', 'libx264', '-preset', 'slow', '-crf', '20', '-pix_fmt', 'yuv420p',
                           '-movflags', '+faststart', '-c:a', 'aac', '-b:a', '192k', '-shortest', OUT], stdin=subprocess.PIPE)
    for k in range(int(M.TOTAL * M.FPS)):
        ff.stdin.write(M.frame_at(k / M.FPS).tobytes())
        if k % 150 == 0: print(f'  {k / M.FPS:5.1f}s / {M.TOTAL:.1f}s', flush=True)
    ff.stdin.close(); ff.wait(); os.remove(audio); print('Xong:', OUT)
