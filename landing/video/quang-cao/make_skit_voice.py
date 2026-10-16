#!/usr/bin/env python3
"""Giọng thoại cho một kịch bản skits/<slug>.json (8 câu: 4 cãi vã + 4 dẫn chuyện). Ghi vo-skit/<slug>/N.mp3 và thêm segments/total vào chính file đó.
  python3 make_skit_voice.py <slug>      (gTTS: pip install gTTS ; trên cloud đặt SSL_CERT_FILE=/root/.ccr/ca-bundle.crt REQUESTS_CA_BUNDLE=...)"""
import json, os, subprocess, sys
from gtts import gTTS
HERE = os.path.dirname(os.path.abspath(__file__)); slug = sys.argv[1]
P = f'{HERE}/skits/{slug}.json'; spec = json.load(open(P, encoding='utf-8'))
PITCH = {'nv': 1.16, 'sep': 0.84, 'dan': 1.0}; GAP, TAIL, SPEED = 0.2, 0.3, 1.18
d_out = f'{HERE}/vo-skit/{slug}'; os.makedirs(d_out, exist_ok=True)
segs, t = [], 0.0
for i, ln in enumerate(spec['lines'], 1):
    raw, out = f'{d_out}/raw{i}.mp3', f'{d_out}/{i}.mp3'
    gTTS(ln['text'], lang='vi').save(raw)
    p = PITCH[ln['who']]
    af = f'aresample=44100,atempo={SPEED}' if p == 1.0 else f'asetrate={int(24000 * p)},aresample=44100,atempo={SPEED / p:.4f}'
    subprocess.run(['ffmpeg', '-v', 'error', '-y', '-i', raw, '-af', af, out], check=True); os.remove(raw)
    d = float(subprocess.check_output(['ffprobe', '-v', 'error', '-show_entries', 'format=duration', '-of', 'csv=p=0', out]))
    segs.append({'who': ln['who'], 'text': ln['text'], 'start': round(t, 3), 'voice': round(d, 3), 'len': round(d + TAIL, 3)})
    t += d + TAIL + (GAP if i < len(spec['lines']) else 0)
spec['segments'] = segs; spec['total'] = round(segs[-1]['start'] + segs[-1]['len'] + 0.3, 3)
json.dump(spec, open(P, 'w', encoding='utf-8'), ensure_ascii=False, indent=1)
print(slug, 'tổng', spec['total'], 's')
