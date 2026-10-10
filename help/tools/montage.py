"""Ghép nhiều ảnh help/img/*.webp thành tờ xem nhanh: python3 montage.py <out.png> id1 id2 ..."""
import sys, os
from PIL import Image, ImageDraw, ImageFont
out, ids = sys.argv[1], sys.argv[2:]
D = os.path.join(os.path.dirname(os.path.abspath(__file__)), '..', 'img')
tw, th = 720, 450
cols = 2 if len(ids) > 1 else 1
rows = (len(ids) + cols - 1) // cols
sheet = Image.new('RGB', (cols * tw, rows * (th + 22)), 'white')
f = ImageFont.truetype('/usr/share/fonts/truetype/dejavu/DejaVuSans-Bold.ttf', 16)
d = ImageDraw.Draw(sheet)
for k, i in enumerate(ids):
    im = Image.open(os.path.join(D, i + '.webp')); im.thumbnail((tw, th))
    x, y = (k % cols) * tw, (k // cols) * (th + 22)
    sheet.paste(im, (x, y + 22)); d.text((x + 4, y + 2), i, fill='black', font=f)
sheet.save(out)
