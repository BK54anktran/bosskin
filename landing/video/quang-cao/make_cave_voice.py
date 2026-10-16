#!/usr/bin/env python3
"""Giọng thoại cho video "Cãi vã lương → BossKin" (kịch bản trong LINES). Dùng gTTS (HTTPS thường, chạy được trên cloud;
giọng Microsoft cần WebSocket nên bị proxy chặn). Mỗi vai một tông (nhân viên cao, sếp trầm, dẫn chuyện giữ nguyên).
Ghi vo-cave/N.mp3 và src/cave-timings.json (thời điểm + độ dài từng đoạn) cho Remotion.
  python3 make_cave_voice.py     (cần: pip install gTTS ; ffmpeg ; SSL_CERT_FILE=/root/.ccr/ca-bundle.crt trên cloud)"""
import json, os, subprocess, sys
ENGINE = os.environ.get('ENGINE', 'gtts')   # gtts | piper (piper: giọng thần kinh offline, cần PIPER_MODEL=<file .onnx> + pip install piper-tts)
PIPER_MODEL = os.environ.get('PIPER_MODEL', '')
if ENGINE == 'gtts': from gtts import gTTS
HERE = os.path.dirname(os.path.abspath(__file__))
LINES = [  # (vai, lời)
    ('nv',  'Sếp ơi, lương em bị thiếu rồi!'),
    ('sep', 'Anh tính đúng rồi, đừng cãi!'),
    ('nv',  'Em làm hai mươi sáu công, sao tính hai mươi bốn?'),
    ('sep', 'Anh ghi sổ tay hết, em nhớ nhầm đấy.'),
    ('dan', 'Không có số liệu, thì chỉ còn cãi nhau.'),
    ('dan', 'BossKin chấm công bằng điện thoại, công lương tự tính.'),
    ('dan', 'Nhân viên tự xem công và lương. Minh bạch hai bên.'),
    ('dan', 'Chỉ từ năm nghìn đồng một nhân viên. Dùng thử miễn phí một tháng. Hỗ trợ cả ngày lẫn đêm.'),
]
PITCH = {'nv': 1.16, 'sep': 0.84, 'dan': 1.0}
GAP, TAIL = 0.2, 0.3
SPEED = 1.18 if ENGINE == 'gtts' else 1.08   # tăng tốc chung
SR_IN = 24000 if ENGINE == 'gtts' else 22050
VODIR = 'vo-cave' if ENGINE == 'gtts' else f'vo-cave-{ENGINE}'   # nghỉ giữa các câu, đuôi mỗi đoạn
os.makedirs(f'{HERE}/{VODIR}', exist_ok=True)
segs, t = [], 0.0
for i, (who, text) in enumerate(LINES, 1):
    raw = f'{HERE}/{VODIR}/raw{i}.' + ('mp3' if ENGINE == 'gtts' else 'wav'); out = f'{HERE}/{VODIR}/{i}.mp3'
    if ENGINE == 'gtts': gTTS(text, lang='vi').save(raw)
    else: subprocess.run([sys.executable, '-m', 'piper', '-m', PIPER_MODEL, '-f', raw], input=text.encode(), check=True)
    p = PITCH[who]
    af = f'aresample=44100,atempo={SPEED}' if p == 1.0 else f'asetrate={int(SR_IN * p)},aresample=44100,atempo={SPEED / p:.4f}'
    subprocess.run(['ffmpeg', '-v', 'error', '-y', '-i', raw, '-af', af, out], check=True)
    os.remove(raw)
    d = float(subprocess.check_output(['ffprobe', '-v', 'error', '-show_entries', 'format=duration', '-of', 'csv=p=0', out]))
    segs.append({'who': who, 'text': text, 'start': round(t, 3), 'voice': round(d, 3), 'len': round(d + TAIL, 3)})
    t += d + TAIL + (GAP if i < len(LINES) else 0) - 0.0
    print(i, who, round(d, 2), 'bắt đầu', segs[-1]['start'])
total = round(segs[-1]['start'] + segs[-1]['len'] + 0.3, 3)
json.dump({'total': total, 'segments': segs}, open(f'{HERE}/src/cave-timings.json', 'w', encoding='utf-8'), ensure_ascii=False, indent=1)
print('tổng', total, 'giây')
